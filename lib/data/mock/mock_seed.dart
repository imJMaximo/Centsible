import '../../core/money.dart';
import '../models/book.dart';
import '../models/category.dart';
import '../models/entry.dart';
import '../models/user.dart';
import '../models/wallet.dart';

/// Deterministic mock data for the front-end draft.
///
/// The numbers reproduce the plan's worked example for Household Budget, MTD,
/// PHP: opening ₱48,250.00 + income ₱62,000.00 − expenses ₱18,430.50 =
/// closing ₱91,819.50 — and the YTD view closes at the same figure.
/// `test/cash_calculator_test.dart` pins that.
abstract final class MockSeed {
  /// The mock "today". Every relative label (Today, due in 5 days…) uses this.
  static final today = DateTime(2026, 11, 7);

  static const meId = 'me';

  static const me = AppUser(
    id: meId,
    name: 'Jamie Maximo',
    email: 'jamie@example.com',
    emailVerified: true,
    googleLinked: true,
    hasPassword: false,
  );

  // ── Books & members ────────────────────────────────────────────────────
  static const household = 'household';
  static const personal = 'personal';
  static const studio = 'studio';

  static const books = [
    Book(id: household, name: 'Household Budget', defaultCurrency: 'PHP', colorIndex: 0),
    Book(id: personal, name: 'Personal', defaultCurrency: 'PHP', colorIndex: 1),
    Book(id: studio, name: 'Freelance Studio', defaultCurrency: 'USD', colorIndex: 2),
  ];

  static const _jamie = BookMember(userId: meId, name: 'Jamie (you)', email: 'jamie@example.com', role: MemberRole.owner);
  static const _alex = BookMember(userId: 'alex', name: 'Alex Reyes', email: 'alex@example.com', role: MemberRole.editor);
  static const _mia = BookMember(userId: 'mia', name: 'Mia Santos', email: 'mia@example.com', role: MemberRole.viewer);
  static const _sam = BookMember(userId: 'sam', name: 'Sam Rivera', email: 'sam@example.com', role: MemberRole.owner);

  static final members = <String, List<BookMember>>{
    household: [_jamie, _alex, _mia],
    personal: [_jamie],
    studio: [_sam, _jamie.copyWith(role: MemberRole.editor), _alex],
  };

  static final invitations = <String, List<Invitation>>{
    household: [Invitation(email: 'lola.cruz@example.com', role: MemberRole.viewer, expiresAt: DateTime(2026, 11, 21))],
    personal: [],
    studio: [],
  };

  static const userNames = {'me': 'You', 'alex': 'Alex', 'mia': 'Mia', 'sam': 'Sam'};

  // ── Wallets ────────────────────────────────────────────────────────────
  static const wCash = 'w-cash', wBpi = 'w-bpi', wGcash = 'w-gcash', wCard = 'w-card', wPayo = 'w-payo';

  static final wallets = [
    Wallet(id: wCash, bookId: household, name: 'Cash on hand', type: WalletType.cash, currency: 'PHP', openingBalance: minor(2000)),
    Wallet(id: wBpi, bookId: household, name: 'BPI Savings', type: WalletType.bank, currency: 'PHP', openingBalance: minor(17000), isDefault: true),
    Wallet(id: wGcash, bookId: household, name: 'GCash', type: WalletType.ewallet, currency: 'PHP', openingBalance: minor(1000)),
    const Wallet(id: wPayo, bookId: household, name: 'Payoneer', type: WalletType.ewallet, currency: 'USD'),
    Wallet(
      id: wCard, bookId: household, name: 'BPI Gold Card', type: WalletType.card, currency: 'PHP',
      openingBalance: minor(12480), creditLimit: minor(50000), statementDay: 18, dueDay: 8,
      statementBalance: minor(9850),
    ),
    Wallet(id: 'w-pcash', bookId: personal, name: 'Personal cash', type: WalletType.cash, currency: 'PHP', openingBalance: minor(5000), isDefault: true),
    Wallet(id: 'w-spay', bookId: studio, name: 'Studio Payoneer', type: WalletType.ewallet, currency: 'USD', openingBalance: minor(500), isDefault: true),
    Wallet(id: 'w-sbpi', bookId: studio, name: 'Studio BPI', type: WalletType.bank, currency: 'PHP', openingBalance: minor(10000)),
  ];

  // ── Categories ─────────────────────────────────────────────────────────
  static String catId(String book, CategoryKind kind, String name) => '$book-${kind.name}-$name';

  static List<Category> categories() => [
        for (final b in books) ...[
          for (final (i, n) in kSeedIncome.indexed)
            Category(id: catId(b.id, CategoryKind.income, n), bookId: b.id, kind: CategoryKind.income, name: n, sortOrder: i),
          for (final (i, n) in kSeedExpense.indexed)
            Category(id: catId(b.id, CategoryKind.expense, n), bookId: b.id, kind: CategoryKind.expense, name: n, sortOrder: i),
        ],
      ];

  // ── Entries ────────────────────────────────────────────────────────────
  static List<Entry> entries() {
    final out = <Entry>[];
    var seq = 0;
    String id() => 'e${(++seq).toString().padLeft(4, '0')}';

    void inc(String book, DateTime d, num amt, String cat, String? wallet,
        {String cur = 'PHP', String by = meId, String note = ''}) {
      out.add(Entry(
        id: id(), bookId: book, type: EntryType.income, entryDate: d, amount: minor(amt), currency: cur,
        createdBy: by, walletId: wallet, categoryId: catId(book, CategoryKind.income, cat), note: note,
        activity: [ActivityItem('${userNames[by]} created this entry', d)],
      ));
    }

    void exp(String book, DateTime d, num amt, String cat, String? wallet,
        {String cur = 'PHP', String by = meId, String note = ''}) {
      out.add(Entry(
        id: id(), bookId: book, type: EntryType.expense, entryDate: d, amount: minor(amt), currency: cur,
        createdBy: by, walletId: wallet, categoryId: catId(book, CategoryKind.expense, cat), note: note,
        activity: [ActivityItem('${userNames[by]} created this entry', d)],
      ));
    }

    void xfer(String book, DateTime d, num amt, String from, String to, {String by = meId, String note = ''}) {
      out.add(Entry(
        id: id(), bookId: book, type: EntryType.transfer, entryDate: d, amount: minor(amt), currency: 'PHP',
        createdBy: by, walletId: from, toWalletId: to, note: note,
        activity: [ActivityItem('${userNames[by]} created this transfer', d)],
      ));
    }

    // Household · PHP · Jan–Oct 2026 — a repeating month plus a few one-offs.
    for (var m = 1; m <= 10; m++) {
      DateTime d(int day) => DateTime(2026, m, day);
      inc(household, d(1), 52000, 'Salary', wBpi, note: 'Monthly payroll');
      exp(household, d(1), 9000, 'Rent', wBpi);
      exp(household, d(5), 9600, 'Education', wBpi, note: 'Tuition installment');
      xfer(household, d(7), m == 10 ? 18191 : 18500, wBpi, wCash, note: 'ATM withdrawal');
      exp(household, d(8), 5500, 'Groceries', wCash);
      xfer(household, d(9), m == 10 ? 9850 : 8000, wBpi, wGcash, note: 'Top-up');
      exp(household, d(10), 5500, 'Transportation', wGcash, note: 'Fuel and fares');
      exp(household, d(12), 2000, 'Health', wCash);
      exp(household, d(15), 5000, 'Utilities', wBpi, note: 'Electric, water, internet');
      exp(household, d(18), 5000, 'Food', wCash);
      exp(household, d(20), 4800, 'Insurance', wBpi);
      exp(household, d(22), 5500, 'Groceries', wCash);
      exp(household, d(25), 1400, 'Shopping', wGcash);
      exp(household, d(27), 800, 'Entertainment', wGcash);
      if (m.isEven && m < 10) inc(household, d(14), 6200, 'Freelance', wBpi, note: 'Design retainer');
      if (m == 3 || m == 9) inc(household, d(16), 4000, 'Investment', wBpi, note: 'Dividends');
    }
    inc(household, DateTime(2026, 5, 19), 5000, 'Business', wBpi, note: 'Weekend market stall');
    inc(household, DateTime(2026, 7, 4), 3000, 'Gift', wCash, note: 'Birthday');
    inc(household, DateTime(2026, 10, 30), 450, 'Refund', wGcash, note: 'Returned order');

    // Household · USD (Payoneer).
    for (final m in [3, 5, 7, 9]) {
      inc(household, DateTime(2026, m, 12), 425, 'Freelance', wPayo, cur: 'USD', note: 'Overseas client');
    }
    exp(household, DateTime(2026, 6, 20), 270, 'Shopping', wPayo, cur: 'USD');
    exp(household, DateTime(2026, 8, 22), 190, 'Entertainment', wPayo, cur: 'USD');

    // Household · November (MTD) — matches the prototype's Entries screen.
    DateTime n(int day) => DateTime(2026, 11, day);
    inc(household, n(1), 52000, 'Salary', wBpi, note: 'November payroll');
    exp(household, n(1), 9000, 'Rent', wBpi);
    inc(household, n(2), 2000, 'Investment', wBpi, note: 'Dividend payout');
    exp(household, n(3), 1650, 'Transportation', wGcash, note: 'Fuel');
    inc(household, n(3), 1000, 'Refund', wGcash, note: 'Online order refund');
    exp(household, n(4), 2150, 'Groceries', wCash, by: 'alex', note: 'Midweek top-up');
    exp(household, n(4), 350, 'Health', wCash, note: 'Pharmacy');
    inc(household, n(4), 300, 'Gift', wCash, by: 'alex', note: 'From Tita Nena');
    exp(household, n(5), 2410, 'Utilities', wBpi, by: 'alex', note: 'Electric bill');
    inc(household, n(6), 6500, 'Freelance', wBpi, by: 'alex', note: 'Logo project');
    exp(household, n(6), 1200, 'Food', wCash, note: 'Dinner out');
    inc(household, n(6), 200, 'Other', wCash, note: 'Sold old books');
    exp(household, n(7), 1670.50, 'Groceries', wCash, note: 'Weekly market run');
    xfer(household, n(7), 2000, wBpi, wGcash);
    inc(household, n(3), 450, 'Freelance', wPayo, cur: 'USD', note: 'Overseas client');
    exp(household, n(4), 59.99, 'Shopping', wPayo, cur: 'USD', note: 'Software license');
    exp(household, n(6), 30, 'Entertainment', wPayo, cur: 'USD', note: 'Streaming');

    // Household · receivables & payables.
    Entry accrual(DateTime d, num amt, CategoryKind kind, String cat, String who, DateTime due,
            {String cur = 'PHP', String note = '', DateTime? settled, String? settledWallet, List<Attachment> files = const [], List<ActivityItem>? act}) =>
        Entry(
          id: id(), bookId: household,
          type: kind == CategoryKind.income ? EntryType.income : EntryType.expense,
          accrual: kind == CategoryKind.income ? Accrual.receivable : Accrual.payable,
          status: settled == null ? EntryStatus.pending : EntryStatus.settled,
          entryDate: d, amount: minor(amt), currency: cur, createdBy: meId,
          categoryId: catId(household, kind, cat), counterparty: who, dueDate: due, note: note,
          settledAt: settled, settledWalletId: settledWallet, attachments: files,
          activity: act ?? [ActivityItem('You created this ${kind == CategoryKind.income ? 'receivable' : 'payable'}', d)],
        );

    out.addAll([
      accrual(DateTime(2026, 10, 10), 8000, CategoryKind.income, 'Freelance', 'Acme Corp', DateTime(2026, 10, 25),
          note: 'Invoice #029', settled: DateTime(2026, 10, 28), settledWallet: wBpi),
      accrual(DateTime(2026, 10, 20), 3000, CategoryKind.income, 'Other', 'Ben (cousin)', DateTime(2026, 11, 2), note: 'Short-term loan'),
      accrual(n(5), 12000, CategoryKind.income, 'Freelance', 'Northwind Studio', DateTime(2026, 11, 12),
          note: 'Website redesign, phase 1 · Client invoice #031',
          files: const [Attachment(name: 'invoice-031.pdf', sizeBytes: 188416), Attachment(name: 'contract.docx', sizeBytes: 43008)],
          act: [ActivityItem('You created this receivable', n(5)), ActivityItem('Alex attached contract.docx', n(6))]),
      accrual(n(2), 300, CategoryKind.income, 'Freelance', 'Lumen Labs', DateTime(2026, 11, 25), cur: 'USD', note: 'Invoice #U-07'),
      accrual(n(2), 1800, CategoryKind.expense, 'Utilities', 'Fiber internet', DateTime(2026, 11, 15), note: 'November bill'),
      accrual(n(4), 2500, CategoryKind.expense, 'Health', 'Dental clinic', DateTime(2026, 11, 20), note: 'Balance after visit'),
      accrual(n(6), 2500, CategoryKind.expense, 'Other', 'Mia Santos', DateTime(2026, 11, 30), note: 'Concert tickets'),
    ]);

    // Personal.
    inc(personal, DateTime(2026, 10, 15), 2000, 'Gift', 'w-pcash', note: 'Pasalubong money');
    exp(personal, n(2), 450, 'Food', 'w-pcash', note: 'Coffee and pastries');
    exp(personal, n(4), 1299, 'Shopping', 'w-pcash', note: 'Running shoes (sale)');

    // Freelance Studio.
    inc(studio, DateTime(2026, 10, 3), 1800, 'Freelance', 'w-spay', cur: 'USD', by: 'sam', note: 'Brand kit');
    exp(studio, DateTime(2026, 10, 9), 120, 'Other', 'w-spay', cur: 'USD', by: 'sam', note: 'Font licenses');
    inc(studio, n(3), 1200, 'Freelance', 'w-spay', cur: 'USD', by: 'sam', note: 'Landing page');
    exp(studio, n(5), 49, 'Other', 'w-spay', cur: 'USD', note: 'Design tool seat');
    exp(studio, n(6), 3500, 'Utilities', 'w-sbpi', by: 'alex', note: 'Co-working day passes');

    return out;
  }
}
