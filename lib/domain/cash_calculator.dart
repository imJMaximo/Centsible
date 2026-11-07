import '../data/models/entry.dart';
import '../data/models/wallet.dart';

/// Inclusive date range [start, end] (dates only).
class DateRange {
  const DateRange(this.start, this.end);
  final DateTime start;
  final DateTime end;

  bool contains(DateTime d) => !d.isBefore(start) && !d.isAfter(end);

  static DateRange mtd(DateTime today) => DateRange(DateTime(today.year, today.month, 1), today);
  static DateRange ytd(DateTime today) => DateRange(DateTime(today.year, 1, 1), today);
}

class CategoryTotal {
  const CategoryTotal(this.categoryId, this.amount);
  final String categoryId;
  final int amount;
}

class CashSummary {
  const CashSummary({
    required this.opening,
    required this.income,
    required this.expenses,
    required this.closing,
    required this.receivable,
    required this.payable,
    required this.openReceivables,
    required this.openPayables,
    required this.incomeByCategory,
    required this.expenseByCategory,
  });

  final int opening, income, expenses, closing, receivable, payable;
  final List<Entry> openReceivables, openPayables;
  final List<CategoryTotal> incomeByCategory, expenseByCategory;

  int get net => closing - opening;
}

/// Pure implementation of the plan's "Dashboard calculations" section.
///
/// Cash lives in asset wallets. An entry moves cash when it has a cash_date and
/// touches an asset wallet (or no wallet at all). Card spending is an expense
/// right away but moves no cash; paying the card (a transfer asset → liability)
/// is what lowers cash. Transfers are never income or expense.
class CashCalculator {
  const CashCalculator({required this.entries, required this.wallets});

  final List<Entry> entries;
  final List<Wallet> wallets;

  Wallet? _wallet(String? id) => id == null ? null : wallets.where((w) => w.id == id).firstOrNull;
  bool _isAsset(String? walletId) => _wallet(walletId)?.isLiability != true;

  /// Signed effect of an entry on total cash.
  int cashEffect(Entry e) {
    if (e.cashDate == null) return 0;
    switch (e.type) {
      case EntryType.income:
        return _isAsset(e.effectiveWalletId) ? e.amount : 0;
      case EntryType.expense:
        return _isAsset(e.effectiveWalletId) ? -e.amount : 0;
      case EntryType.transfer:
        final fromAsset = _isAsset(e.walletId), toAsset = _isAsset(e.toWalletId);
        if (fromAsset && !toAsset) return -e.amount; // card payment
        if (!fromAsset && toAsset) return e.amount; // cash advance
        return 0;
    }
  }

  CashSummary summarize({required String bookId, required String currency, required DateRange range}) {
    final book = entries.where((e) => e.bookId == bookId && e.currency == currency).toList();
    final assetOpening = wallets
        .where((w) => w.bookId == bookId && w.currency == currency && !w.isLiability)
        .fold<int>(0, (a, w) => a + w.openingBalance);

    var opening = assetOpening, movement = 0, income = 0, expenses = 0;
    final inc = <String, int>{}, exp = <String, int>{};

    for (final e in book) {
      final cd = e.cashDate;
      if (cd == null) continue;
      if (cd.isBefore(range.start)) {
        opening += cashEffect(e);
      } else if (!cd.isAfter(range.end)) {
        movement += cashEffect(e);
        if (e.type == EntryType.income) {
          income += e.amount;
          inc.update(e.categoryId ?? '', (v) => v + e.amount, ifAbsent: () => e.amount);
        } else if (e.type == EntryType.expense) {
          expenses += e.amount;
          exp.update(e.categoryId ?? '', (v) => v + e.amount, ifAbsent: () => e.amount);
        }
      }
    }

    bool openAt(Entry e) =>
        !e.entryDate.isAfter(range.end) && (e.status == EntryStatus.pending || (e.settledAt?.isAfter(range.end) ?? true));
    final recv = book.where((e) => e.accrual == Accrual.receivable && openAt(e)).toList();
    final pay = book.where((e) => e.accrual == Accrual.payable && openAt(e)).toList();

    List<CategoryTotal> sorted(Map<String, int> m) =>
        (m.entries.map((x) => CategoryTotal(x.key, x.value)).toList()..sort((a, b) => b.amount.compareTo(a.amount)));

    return CashSummary(
      opening: opening,
      income: income,
      expenses: expenses,
      closing: opening + movement,
      receivable: recv.fold(0, (a, e) => a + e.amount),
      payable: pay.fold(0, (a, e) => a + e.amount),
      openReceivables: recv,
      openPayables: pay,
      incomeByCategory: sorted(inc),
      expenseByCategory: sorted(exp),
    );
  }

  /// Currencies that have any entry or wallet in the book.
  List<String> currenciesFor(String bookId, String defaultCurrency) {
    final set = <String>{defaultCurrency};
    for (final w in wallets.where((w) => w.bookId == bookId)) {
      set.add(w.currency);
    }
    for (final e in entries.where((e) => e.bookId == bookId)) {
      set.add(e.currency);
    }
    return [defaultCurrency, ...set.where((c) => c != defaultCurrency)];
  }

  /// Asset wallets: current balance. Liabilities: current amount owed.
  int walletBalance(Wallet w) {
    var bal = w.openingBalance;
    final sign = w.isLiability ? -1 : 1;
    for (final e in entries) {
      if (e.cashDate == null) continue;
      switch (e.type) {
        case EntryType.income:
          if (e.effectiveWalletId == w.id) bal += sign * e.amount;
        case EntryType.expense:
          if (e.effectiveWalletId == w.id) bal -= sign * e.amount;
        case EntryType.transfer:
          if (e.walletId == w.id) bal -= sign * e.amount;
          if (e.toWalletId == w.id) bal += sign * e.amount;
      }
    }
    return bal;
  }
}
