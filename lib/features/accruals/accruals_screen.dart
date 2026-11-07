import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/entry.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/entry_repository.dart';
import 'settle_sheet.dart';

/// Receivables & payables for the active book, grouped per currency.
final accrualsProvider = Provider.family<List<Entry>, Accrual>((ref, kind) {
  final book = ref.watch(activeBookIdProvider);
  return ref.watch(entryRepositoryProvider).where((e) => e.bookId == book && e.accrual == kind).toList()
    ..sort((a, b) => (a.dueDate ?? a.entryDate).compareTo(b.dueDate ?? b.entryDate));
});

class AccrualsScreen extends ConsumerStatefulWidget {
  const AccrualsScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  ConsumerState<AccrualsScreen> createState() => _AccrualsScreenState();
}

class _AccrualsScreenState extends ConsumerState<AccrualsScreen> {
  late int _tab = widget.initialTab;
  bool _showSettled = false;

  @override
  Widget build(BuildContext context) {
    final recv = _tab == 0;
    final kind = recv ? Accrual.receivable : Accrual.payable;
    final all = ref.watch(accrualsProvider(kind));
    final today = ref.watch(todayProvider);
    final c = context.colors;
    final open = all.where((e) => e.isPending).toList();
    final shown = _showSettled ? all : open;
    final totals = <String, int>{};
    for (final e in open) {
      totals.update(e.currency, (v) => v + e.amount, ifAbsent: () => e.amount);
    }
    final overdue = open.where((e) => e.dueDate != null && e.dueDate!.isBefore(today)).length;
    final book = ref.watch(activeBookProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Owed & owing'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('${Routes.newEntry}?type=${recv ? 'income' : 'expense'}'),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
        PillSegment<int>(
          expand: true,
          options: const [(0, 'Receivable'), (1, 'Payable')],
          selected: _tab,
          onChanged: (v) => setState(() => _tab = v),
        ),
        const SizedBox(height: 14),
        SectionCard(
          color: recv ? c.infoBg : c.pendingBg,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(recv ? 'Others owe you' : 'You owe', style: TextStyle(color: recv ? c.info : c.pending, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            if (totals.isEmpty)
              Text(formatMoney(0, book.defaultCurrency), style: figureStyle(30, color: recv ? c.info : c.pending))
            else
              for (final t in totals.entries) Text(formatMoney(t.value, t.key), style: figureStyle(30, color: recv ? c.info : c.pending)),
            const SizedBox(height: 4),
            Text(
              '${open.length} open · ${overdue > 0 ? '$overdue overdue' : 'none overdue'} · not counted in cash',
              style: context.text.bodySmall?.copyWith(color: recv ? c.info : c.pending),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        if (shown.isEmpty) const EmptyState(title: 'All settled', body: 'Nothing outstanding here.'),
        for (final e in shown) ...[
          _AccrualCard(entry: e, today: today),
          const SizedBox(height: 10),
        ],
        TextButton(
          onPressed: () => setState(() => _showSettled = !_showSettled),
          child: Text(_showSettled ? 'Hide settled' : 'Show settled'),
        ),
      ]),
    );
  }
}

class _AccrualCard extends ConsumerWidget {
  const _AccrualCard({required this.entry, required this.today});
  final Entry entry;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = entry;
    final c = context.colors;
    final recv = e.accrual == Accrual.receivable;
    final cat = ref.watch(categoryRepositoryProvider.select((_) => ref.read(categoryRepositoryProvider.notifier).byId(e.categoryId)));
    final days = e.dueDate == null ? 0 : daysBetween(today, e.dueDate!);
    final isOverdue = e.isPending && days < 0;
    final dueText = !e.isPending
        ? '${recv ? 'Received' : 'Paid'} ${shortDate(e.settledAt!)}'
        : isOverdue
            ? 'Overdue · was due ${shortDate(e.dueDate!)}'
            : 'Due ${dayDate(e.dueDate ?? today)}';

    return Opacity(
      opacity: e.isPending ? 1 : 0.7,
      child: SectionCard(
        border: Border.all(color: isOverdue ? const Color(0xFFE0A23A) : Colors.transparent, width: 2),
        padding: EdgeInsets.zero,
        child: Column(children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            onTap: () => context.push('/entries/${e.id}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(e.counterparty ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                  Text(formatMoney(e.amount, e.currency), style: figureStyle(16)),
                ]),
                const SizedBox(height: 2),
                Text([cat?.name ?? '', if (e.note.isNotEmpty) e.note].join(' · '), style: context.text.bodySmall?.copyWith(color: c.muted)),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(children: [
              StatusPill(
                dueText,
                fg: !e.isPending ? c.selected : isOverdue ? const Color(0xFF7A4A00) : c.muted,
                bg: !e.isPending ? c.incomeBg : isOverdue ? c.pendingBg : c.surfaceMuted,
              ),
              const Spacer(),
              if (e.isPending)
                TextButton(onPressed: () => showSettleSheet(context, ref, e), child: Text(recv ? 'Mark received' : 'Mark paid'))
              else
                TextButton(
                  onPressed: () {
                    ref.read(entryRepositoryProvider.notifier).unsettle(e.id, on: today, byName: 'You');
                    showToast(context, 'Moved back to open');
                  },
                  child: const Text('Undo'),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
