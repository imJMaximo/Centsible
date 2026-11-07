import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/book.dart';
import '../../data/models/entry.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/wallet_repository.dart';

enum EntryFilter { all, income, expense, transfer, pending }

class EntriesFilters {
  const EntriesFilters({this.type = EntryFilter.all, this.memberId, this.query = ''});
  final EntryFilter type;
  final String? memberId; // null → everyone
  final String query;

  bool get isDefault => type == EntryFilter.all && memberId == null && query.isEmpty;
}

class EntriesViewModel extends Notifier<EntriesFilters> {
  @override
  EntriesFilters build() {
    ref.watch(activeBookIdProvider);
    return const EntriesFilters();
  }

  void setType(EntryFilter t) => state = EntriesFilters(type: t, memberId: state.memberId, query: state.query);
  void setMember(String? id) => state = EntriesFilters(type: state.type, memberId: id, query: state.query);
  void setQuery(String q) => state = EntriesFilters(type: state.type, memberId: state.memberId, query: q);
  void reset() => state = const EntriesFilters();
}

final entriesViewModelProvider = NotifierProvider<EntriesViewModel, EntriesFilters>(EntriesViewModel.new);

class DayGroup {
  const DayGroup(this.day, this.entries, this.netByCurrency);
  final DateTime day;
  final List<Entry> entries;
  final Map<String, int> netByCurrency;
}

class EntriesUiState {
  const EntriesUiState({required this.book, required this.members, required this.groups, required this.total});
  final Book book;
  final List<BookMember> members;
  final List<DayGroup> groups;
  final int total;
}

final entriesUiProvider = Provider<EntriesUiState>((ref) {
  final f = ref.watch(entriesViewModelProvider);
  final book = ref.watch(activeBookProvider);
  final members = ref.watch(bookRepositoryProvider.select((b) => b.members[book.id] ?? const <BookMember>[]));
  final cats = ref.watch(categoryRepositoryProvider);
  final wallets = ref.watch(walletRepositoryProvider);
  final all = ref.watch(entryRepositoryProvider).where((e) => e.bookId == book.id);

  String haystack(Entry e) => [
        cats.where((c) => c.id == e.categoryId).firstOrNull?.name ?? '',
        e.note,
        e.counterparty ?? '',
        wallets.where((w) => w.id == e.walletId || w.id == e.toWalletId || w.id == e.settledWalletId).map((w) => w.name).join(' '),
      ].join(' ').toLowerCase();

  final q = f.query.trim().toLowerCase();
  final kept = all.where((e) {
    final typeOk = switch (f.type) {
      EntryFilter.all => true,
      EntryFilter.pending => e.isPending,
      EntryFilter.income => e.type == EntryType.income,
      EntryFilter.expense => e.type == EntryType.expense,
      EntryFilter.transfer => e.type == EntryType.transfer,
    };
    return typeOk && (f.memberId == null || e.createdBy == f.memberId) && (q.isEmpty || haystack(e).contains(q));
  }).toList()
    ..sort((a, b) => b.entryDate.compareTo(a.entryDate));

  final groups = <DayGroup>[];
  for (final e in kept) {
    if (groups.isEmpty || groups.last.day != e.entryDate) {
      groups.add(DayGroup(e.entryDate, [], {}));
    }
    final g = groups.last;
    g.entries.add(e);
    if (!e.isPending && e.type != EntryType.transfer) {
      final signed = e.type == EntryType.income ? e.amount : -e.amount;
      g.netByCurrency.update(e.currency, (v) => v + signed, ifAbsent: () => signed);
    }
  }
  return EntriesUiState(book: book, members: members, groups: groups, total: kept.length);
});
