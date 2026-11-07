import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_seed.dart';
import '../models/entry.dart';

/// In-memory stand-in for the Drift `entries` table + outbox. Writes are
/// immediate (local-first); a real implementation would also enqueue sync.
class EntryRepository extends Notifier<List<Entry>> {
  var _seq = 0;

  @override
  List<Entry> build() => MockSeed.entries();

  Entry? byId(String id) => state.where((e) => e.id == id).firstOrNull;

  String nextId() => 'local-${++_seq}';

  void upsert(Entry e) {
    final exists = state.any((x) => x.id == e.id);
    state = exists ? [for (final x in state) x.id == e.id ? e : x] : [...state, e];
  }

  void delete(String id) => state = state.where((e) => e.id != id).toList();

  void settle(String id, {required String walletId, required DateTime on, required String byName}) {
    final e = byId(id)!;
    final verb = e.accrual == Accrual.receivable ? 'received' : 'paid';
    upsert(e.copyWith(
      status: EntryStatus.settled,
      settledAt: on,
      settledWalletId: walletId,
      activity: [...e.activity, ActivityItem('$byName marked it $verb', on)],
    ));
  }

  void unsettle(String id, {required DateTime on, required String byName}) {
    final e = byId(id)!;
    upsert(e.copyWith(
      status: EntryStatus.pending,
      clearSettlement: true,
      activity: [...e.activity, ActivityItem('$byName moved it back to pending', on)],
    ));
  }
}

final entryRepositoryProvider = NotifierProvider<EntryRepository, List<Entry>>(EntryRepository.new);
