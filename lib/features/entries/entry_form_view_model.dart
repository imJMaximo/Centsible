import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_seed.dart';
import '../../data/models/entry.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/wallet_repository.dart';

enum Treatment { regular, accrual, transfer }

/// Everything the entry form edits, before it becomes an [Entry].
class EntryDraft {
  EntryDraft({
    required this.bookId,
    required this.date,
    required this.currency,
    this.id,
    this.isIncome = false,
    this.treatment = Treatment.regular,
    this.amountMinor,
    this.categoryId,
    this.walletId,
    this.fromWalletId,
    this.toWalletId,
    this.dueDate,
    this.counterparty = '',
    this.note = '',
    List<Attachment>? attachments,
  }) : attachments = attachments ?? [];

  final String? id;
  final String bookId;
  bool isIncome;
  Treatment treatment;
  int? amountMinor;
  String currency;
  DateTime date;
  String? categoryId;
  String? walletId;
  String? fromWalletId;
  String? toWalletId;
  DateTime? dueDate;
  String counterparty;
  String note;
  final List<Attachment> attachments;

  factory EntryDraft.fromEntry(Entry e) => EntryDraft(
        id: e.id,
        bookId: e.bookId,
        date: e.entryDate,
        currency: e.currency,
        isIncome: e.type == EntryType.income,
        treatment: e.type == EntryType.transfer
            ? Treatment.transfer
            : e.isAccrual
                ? Treatment.accrual
                : Treatment.regular,
        amountMinor: e.amount,
        categoryId: e.categoryId,
        walletId: e.type == EntryType.transfer ? null : e.walletId,
        fromWalletId: e.type == EntryType.transfer ? e.walletId : null,
        toWalletId: e.toWalletId,
        dueDate: e.dueDate,
        counterparty: e.counterparty ?? '',
        note: e.note,
        attachments: List.of(e.attachments),
      );
}

/// Validates a draft against the plan's rules and writes it locally.
class EntryFormViewModel extends Notifier<void> {
  @override
  void build() {}

  /// Null when valid, else the first problem to show the user.
  String? validate(EntryDraft d) {
    if ((d.amountMinor ?? 0) <= 0) return 'Enter an amount first';
    switch (d.treatment) {
      case Treatment.transfer:
        if (d.fromWalletId == null || d.toWalletId == null) return 'Pick a from and a to wallet';
        if (d.fromWalletId == d.toWalletId) return 'Pick two different wallets';
      case Treatment.accrual:
        if (d.categoryId == null) return 'Choose a category';
        if (d.dueDate == null) return 'Set a due date';
      case Treatment.regular:
        if (d.categoryId == null) return 'Choose a category';
    }
    return null;
  }

  /// Returns the saved entry id.
  String save(EntryDraft d) {
    assert(validate(d) == null);
    final repo = ref.read(entryRepositoryProvider.notifier);
    final existing = d.id == null ? null : repo.byId(d.id!);
    final today = ref.read(todayProvider);
    final me = MockSeed.meId;
    final transfer = d.treatment == Treatment.transfer;
    final accrual = d.treatment == Treatment.accrual;
    final wallets = ref.read(walletRepositoryProvider.notifier);
    final currency = transfer ? (wallets.byId(d.fromWalletId)?.currency ?? d.currency) : d.currency;

    final entry = Entry(
      id: existing?.id ?? repo.nextId(),
      bookId: d.bookId,
      createdBy: existing?.createdBy ?? me,
      type: transfer ? EntryType.transfer : (d.isIncome ? EntryType.income : EntryType.expense),
      entryDate: d.date,
      amount: d.amountMinor!,
      currency: currency,
      walletId: transfer ? d.fromWalletId : (accrual ? null : d.walletId),
      toWalletId: transfer ? d.toWalletId : null,
      categoryId: transfer ? null : d.categoryId,
      accrual: accrual ? (d.isIncome ? Accrual.receivable : Accrual.payable) : Accrual.none,
      status: accrual ? (existing?.status ?? EntryStatus.pending) : EntryStatus.settled,
      dueDate: accrual ? d.dueDate : null,
      settledAt: accrual ? existing?.settledAt : null,
      settledWalletId: accrual ? existing?.settledWalletId : null,
      counterparty: accrual && d.counterparty.trim().isNotEmpty ? d.counterparty.trim() : null,
      note: d.note.trim(),
      attachments: List.of(d.attachments),
      activity: [
        ...?existing?.activity,
        ActivityItem(existing == null ? 'You created this entry' : 'You edited this entry', today),
      ],
    );
    repo.upsert(entry);
    return entry.id;
  }
}

final entryFormViewModelProvider = NotifierProvider<EntryFormViewModel, void>(EntryFormViewModel.new);
