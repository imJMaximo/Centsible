enum WalletClass { asset, liability }

enum WalletType {
  cash('Cash'),
  bank('Bank'),
  ewallet('E-wallet'),
  card('Credit card');

  const WalletType(this.label);
  final String label;

  WalletClass get walletClass => this == WalletType.card ? WalletClass.liability : WalletClass.asset;
}

class Wallet {
  const Wallet({
    required this.id,
    required this.bookId,
    required this.name,
    required this.type,
    required this.currency,
    this.openingBalance = 0,
    this.isDefault = false,
    this.creditLimit = 0,
    this.statementDay = 18,
    this.dueDay = 8,
    this.statementBalance = 0,
    this.reminderOn = true,
  });

  final String id;
  final String bookId;
  final String name;
  final WalletType type;
  final String currency;

  /// For assets: balance at creation. For liabilities: amount owed at creation.
  final int openingBalance;
  final bool isDefault;

  // Credit-card only.
  final int creditLimit;
  final int statementDay;
  final int dueDay;

  /// Last statement's unpaid balance (mock: stored; real app: derived from cycles).
  final int statementBalance;
  final bool reminderOn;

  WalletClass get walletClass => type.walletClass;
  bool get isLiability => walletClass == WalletClass.liability;

  Wallet copyWith({int? statementDay, int? dueDay, int? statementBalance, bool? reminderOn}) => Wallet(
        id: id,
        bookId: bookId,
        name: name,
        type: type,
        currency: currency,
        openingBalance: openingBalance,
        isDefault: isDefault,
        creditLimit: creditLimit,
        statementDay: statementDay ?? this.statementDay,
        dueDay: dueDay ?? this.dueDay,
        statementBalance: statementBalance ?? this.statementBalance,
        reminderOn: reminderOn ?? this.reminderOn,
      );
}
