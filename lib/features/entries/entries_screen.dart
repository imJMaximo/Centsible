import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/entry_tile.dart';
import '../../data/mock/mock_seed.dart';
import '../../data/repositories/auth_repository.dart';
import 'entries_view_model.dart';

class EntriesScreen extends ConsumerStatefulWidget {
  const EntriesScreen({super.key});

  @override
  ConsumerState<EntriesScreen> createState() => _EntriesScreenState();
}

class _EntriesScreenState extends ConsumerState<EntriesScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(entriesUiProvider);
    final f = ref.watch(entriesViewModelProvider);
    final vm = ref.read(entriesViewModelProvider.notifier);
    final today = ref.watch(todayProvider);
    final c = context.colors;

    const typeLabels = {
      EntryFilter.all: 'All',
      EntryFilter.income: 'Income',
      EntryFilter.expense: 'Expense',
      EntryFilter.transfer: 'Transfer',
      EntryFilter.pending: 'Pending',
    };

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Entries', style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('${ui.book.name} · ${ui.total}', style: context.text.bodySmall?.copyWith(color: c.muted)),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                onChanged: vm.setQuery,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search category, note, wallet',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: f.query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            vm.setQuery('');
                          },
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final t in EntryFilter.values) ...[
                    SelectChip(label: typeLabels[t]!, selected: f.type == t, onTap: () => vm.setType(t)),
                    const SizedBox(width: 6),
                  ],
                ]),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 40,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  SelectChip(label: 'Everyone', selected: f.memberId == null, onTap: () => vm.setMember(null)),
                  for (final m in ui.members) ...[
                    const SizedBox(width: 6),
                    SelectChip(
                      label: m.userId == MockSeed.meId ? 'Added by you' : m.name.split(' ').first,
                      selected: f.memberId == m.userId,
                      onTap: () => vm.setMember(m.userId),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
          Expanded(
            child: ui.groups.isEmpty
                ? ListView(children: [
                    EmptyState(
                      title: f.isDefault ? 'No entries yet' : 'No entries match',
                      body: f.isDefault ? 'Tap + to add your first income or expense.' : 'Try another filter or clear your search.',
                      action: f.isDefault
                          ? null
                          : OutlinedButton(
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                              onPressed: () {
                                _search.clear();
                                vm.reset();
                              },
                              child: const Text('Reset filters'),
                            ),
                    ),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                    itemCount: ui.groups.length,
                    itemBuilder: (context, i) {
                      final g = ui.groups[i];
                      final net = g.netByCurrency.entries.map((e) => formatSigned(e.value, e.key)).join('  ');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                            child: Row(children: [
                              Text(relativeDay(g.day, today),
                                  style: context.text.labelMedium?.copyWith(color: c.muted, fontWeight: FontWeight.w700)),
                              const Spacer(),
                              Text(net, style: context.text.labelMedium?.copyWith(color: c.muted, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                          RowGroup(children: [for (final e in g.entries) EntryTile(entry: e, today: today)]),
                        ]),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
