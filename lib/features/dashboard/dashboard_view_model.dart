import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/book.dart';
import '../../data/models/category.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../domain/cash_calculator.dart';

enum RangeKind { mtd, ytd }

class DashboardFilters {
  const DashboardFilters({this.range = RangeKind.mtd, this.currency, this.topKind = CategoryKind.expense, this.showAll = false});
  final RangeKind range;
  final String? currency; // null → the book's default
  final CategoryKind topKind;
  final bool showAll;

  DashboardFilters copyWith({RangeKind? range, String? currency, CategoryKind? topKind, bool? showAll}) => DashboardFilters(
        range: range ?? this.range,
        currency: currency ?? this.currency,
        topKind: topKind ?? this.topKind,
        showAll: showAll ?? this.showAll,
      );
}

class DashboardViewModel extends Notifier<DashboardFilters> {
  @override
  DashboardFilters build() {
    ref.watch(activeBookIdProvider); // reset currency when the book changes
    return const DashboardFilters();
  }

  void setRange(RangeKind r) => state = state.copyWith(range: r);
  void setCurrency(String c) => state = state.copyWith(currency: c);
  void setTopKind(CategoryKind k) => state = state.copyWith(topKind: k, showAll: false);
  void toggleAll() => state = state.copyWith(showAll: !state.showAll);
  void switchBook(String id) => ref.read(activeBookIdProvider.notifier).select(id);
}

final dashboardViewModelProvider = NotifierProvider<DashboardViewModel, DashboardFilters>(DashboardViewModel.new);

class TopRow {
  const TopRow(this.name, this.amount, this.share);
  final String name;
  final int amount;
  final double share;
}

class DashboardUiState {
  const DashboardUiState({
    required this.book,
    required this.isMain,
    required this.currency,
    required this.currencies,
    required this.range,
    required this.summary,
    required this.top,
    required this.hasMoreTop,
    required this.dueThisWeek,
  });

  final Book book;
  final bool isMain;
  final String currency;
  final List<String> currencies;
  final DateRange range;
  final CashSummary summary;
  final List<TopRow> top;
  final bool hasMoreTop;
  final int dueThisWeek;
}

final dashboardUiProvider = Provider<DashboardUiState>((ref) {
  final f = ref.watch(dashboardViewModelProvider);
  final book = ref.watch(activeBookProvider);
  final mainId = ref.watch(bookRepositoryProvider.select((b) => b.mainBookId));
  final today = ref.watch(todayProvider);
  final calc = CashCalculator(entries: ref.watch(entryRepositoryProvider), wallets: ref.watch(walletRepositoryProvider));
  final cats = ref.watch(categoryRepositoryProvider);

  final currencies = calc.currenciesFor(book.id, book.defaultCurrency);
  final currency = currencies.contains(f.currency) ? f.currency! : currencies.first;
  final range = f.range == RangeKind.mtd ? DateRange.mtd(today) : DateRange.ytd(today);
  final s = calc.summarize(bookId: book.id, currency: currency, range: range);

  final source = f.topKind == CategoryKind.income ? s.incomeByCategory : s.expenseByCategory;
  final total = f.topKind == CategoryKind.income ? s.income : s.expenses;
  String name(String id) => cats.where((c) => c.id == id).firstOrNull?.name ?? 'Other';
  final rows = [for (final t in source) TopRow(name(t.categoryId), t.amount, total == 0 ? 0 : t.amount / total)];

  final weekEnd = today.add(const Duration(days: 7));
  final dueSoon = s.openReceivables.where((e) => e.dueDate != null && !e.dueDate!.isBefore(today) && !e.dueDate!.isAfter(weekEnd)).length;

  return DashboardUiState(
    book: book,
    isMain: book.id == mainId,
    currency: currency,
    currencies: currencies,
    range: range,
    summary: s,
    top: f.showAll ? rows : rows.take(5).toList(),
    hasMoreTop: rows.length > 5,
    dueThisWeek: dueSoon,
  );
});
