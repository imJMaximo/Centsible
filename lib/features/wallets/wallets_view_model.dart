import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../data/models/entry.dart';
import '../../data/models/wallet.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../domain/cash_calculator.dart';

class WalletView {
  const WalletView(this.wallet, this.balance);
  final Wallet wallet;

  /// Asset: balance. Liability: amount owed.
  final int balance;
}

class WalletsUiState {
  const WalletsUiState({required this.assets, required this.cards, required this.assetTotals});
  final List<WalletView> assets;
  final List<WalletView> cards;
  final Map<String, int> assetTotals;
}

final walletsUiProvider = Provider<WalletsUiState>((ref) {
  final book = ref.watch(activeBookProvider);
  final wallets = ref.watch(walletRepositoryProvider);
  final calc = CashCalculator(entries: ref.watch(entryRepositoryProvider), wallets: wallets);
  final mine = wallets.where((w) => w.bookId == book.id).map((w) => WalletView(w, calc.walletBalance(w))).toList();
  final assets = mine.where((v) => !v.wallet.isLiability).toList();
  final totals = <String, int>{book.defaultCurrency: 0};
  for (final v in assets) {
    totals.update(v.wallet.currency, (x) => x + v.balance, ifAbsent: () => v.balance);
  }
  return WalletsUiState(assets: assets, cards: mine.where((v) => v.wallet.isLiability).toList(), assetTotals: totals);
});

final walletViewProvider = Provider.family<WalletView?, String>((ref, id) {
  final wallets = ref.watch(walletRepositoryProvider);
  final w = wallets.where((x) => x.id == id).firstOrNull;
  if (w == null) return null;
  return WalletView(w, CashCalculator(entries: ref.watch(entryRepositoryProvider), wallets: wallets).walletBalance(w));
});

/// Day [day] of [month], clamped to the month's last day (29–31 rule).
DateTime clampedDay(int year, int month, int day) {
  final last = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day > last ? last : day);
}

/// Next due date on or after [today].
DateTime nextDueDate(int dueDay, DateTime today) {
  final thisMonth = clampedDay(today.year, today.month, dueDay);
  return thisMonth.isBefore(today) ? clampedDay(today.year, today.month + 1, dueDay) : thisMonth;
}

class CardActions extends Notifier<void> {
  @override
  void build() {}

  /// Pays the card from an asset wallet: saved as a transfer (lowers cash and
  /// card debt, never an expense).
  void pay(Wallet card, {required String fromWalletId, required int amount}) {
    final today = ref.read(todayProvider);
    final repo = ref.read(entryRepositoryProvider.notifier);
    repo.upsert(Entry(
      id: repo.nextId(),
      bookId: card.bookId,
      type: EntryType.transfer,
      entryDate: today,
      amount: amount,
      currency: card.currency,
      createdBy: 'me',
      walletId: fromWalletId,
      toWalletId: card.id,
      note: 'Card payment',
      activity: [ActivityItem('You paid ${card.name}', today)],
    ));
    final left = card.statementBalance - amount;
    ref.read(walletRepositoryProvider.notifier).update(card.copyWith(statementBalance: left < 0 ? 0 : left));
  }

  void saveCycle(Wallet card, int statementDay, int dueDay) =>
      ref.read(walletRepositoryProvider.notifier).update(card.copyWith(statementDay: statementDay, dueDay: dueDay));

  void setReminder(Wallet card, bool on) => ref.read(walletRepositoryProvider.notifier).update(card.copyWith(reminderOn: on));

  String cycleLabel(Wallet card, DateTime today) {
    final close = clampedDay(today.year, today.month - 1, card.statementDay);
    final open = clampedDay(close.year, close.month - 1, card.statementDay).add(const Duration(days: 1));
    return '${shortDate(open)} – ${shortDate(close)}';
  }
}

final cardActionsProvider = NotifierProvider<CardActions, void>(CardActions.new);
