enum EntryType { income, expense, transfer }

enum Accrual { none, receivable, payable }

enum EntryStatus { settled, pending }

class Attachment {
  const Attachment({required this.name, required this.sizeBytes});

  final String name;
  final int sizeBytes;

  String get ext => name.contains('.') ? name.split('.').last.toUpperCase() : 'FILE';
  String get sizeLabel => sizeBytes >= 1 << 20
      ? '${(sizeBytes / (1 << 20)).toStringAsFixed(1)} MB'
      : '${(sizeBytes / 1024).round()} KB';
}

class ActivityItem {
  const ActivityItem(this.text, this.at);
  final String text;
  final DateTime at;
}

/// Mirrors the `entries` table in the plan.
class Entry {
  const Entry({
    required this.id,
    required this.bookId,
    required this.type,
    required this.entryDate,
    required this.amount,
    required this.currency,
    required this.createdBy,
    this.walletId,
    this.toWalletId,
    this.categoryId,
    this.accrual = Accrual.none,
    this.status = EntryStatus.settled,
    this.dueDate,
    this.settledAt,
    this.settledWalletId,
    this.counterparty,
    this.note = '',
    this.attachments = const [],
    this.activity = const [],
  });

  final String id;
  final String bookId;
  final EntryType type;
  final DateTime entryDate;

  /// Positive minor units; the sign comes from [type].
  final int amount;
  final String currency;
  final String createdBy;
  final String? walletId;
  final String? toWalletId;
  final String? categoryId;
  final Accrual accrual;
  final EntryStatus status;
  final DateTime? dueDate;
  final DateTime? settledAt;
  final String? settledWalletId;
  final String? counterparty;
  final String note;
  final List<Attachment> attachments;
  final List<ActivityItem> activity;

  bool get isAccrual => accrual != Accrual.none;
  bool get isPending => isAccrual && status == EntryStatus.pending;

  /// The plan's generated column: entry date for normal entries, settlement
  /// date for settled accruals, null while an accrual is pending.
  DateTime? get cashDate {
    if (!isAccrual) return entryDate;
    return status == EntryStatus.settled ? settledAt : null;
  }

  /// The wallet money actually moved through.
  String? get effectiveWalletId => isAccrual ? settledWalletId : walletId;

  Entry copyWith({
    EntryType? type,
    DateTime? entryDate,
    int? amount,
    String? currency,
    String? walletId,
    bool clearWallet = false,
    String? toWalletId,
    String? categoryId,
    Accrual? accrual,
    EntryStatus? status,
    DateTime? dueDate,
    DateTime? settledAt,
    bool clearSettlement = false,
    String? settledWalletId,
    String? counterparty,
    String? note,
    List<Attachment>? attachments,
    List<ActivityItem>? activity,
  }) =>
      Entry(
        id: id,
        bookId: bookId,
        createdBy: createdBy,
        type: type ?? this.type,
        entryDate: entryDate ?? this.entryDate,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        walletId: clearWallet ? null : (walletId ?? this.walletId),
        toWalletId: toWalletId ?? this.toWalletId,
        categoryId: categoryId ?? this.categoryId,
        accrual: accrual ?? this.accrual,
        status: status ?? this.status,
        dueDate: dueDate ?? this.dueDate,
        settledAt: clearSettlement ? null : (settledAt ?? this.settledAt),
        settledWalletId: clearSettlement ? null : (settledWalletId ?? this.settledWalletId),
        counterparty: counterparty ?? this.counterparty,
        note: note ?? this.note,
        attachments: attachments ?? this.attachments,
        activity: activity ?? this.activity,
      );
}
