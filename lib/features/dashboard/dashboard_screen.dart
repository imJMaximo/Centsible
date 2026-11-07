import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/category.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import 'dashboard_view_model.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(dashboardUiProvider);
    final f = ref.watch(dashboardViewModelProvider);
    final vm = ref.read(dashboardViewModelProvider.notifier);
    final user = ref.watch(currentUserProvider);
    final s = ui.summary;
    final c = context.colors;
    String m(int v) => formatMoney(v, ui.currency);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _bookSwitcher(context, ref),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(ui.isMain ? 'MAIN BOOK' : 'SUB-BOOK',
                          style: context.text.labelSmall?.copyWith(color: c.muted, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      Row(children: [
                        Flexible(
                          child: Text(ui.book.name,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                        const Icon(Icons.expand_more),
                      ]),
                    ]),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Account settings',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.go(Routes.account),
                  child: Avatar(user.initials, size: 44),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              PillSegment<RangeKind>(
                options: const [(RangeKind.mtd, 'MTD'), (RangeKind.ytd, 'YTD')],
                selected: f.range,
                onChanged: vm.setRange,
              ),
              const Spacer(),
              if (ui.currencies.length > 1)
                Wrap(spacing: 6, children: [
                  for (final cur in ui.currencies)
                    SelectChip(label: '${currencySymbol(cur)} $cur', selected: cur == ui.currency, onTap: () => vm.setCurrency(cur)),
                ]),
            ]),
            const SizedBox(height: 14),
            _CashCard(ui: ui),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _FlowTile(
                  label: 'Income',
                  value: '+ ${m(s.income)}',
                  icon: Icons.arrow_upward,
                  fg: c.income,
                  bg: c.incomeBg,
                  onTap: () => context.go(Routes.entries),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FlowTile(
                  label: 'Expenses',
                  value: '− ${m(s.expenses)}',
                  icon: Icons.arrow_downward,
                  fg: c.expense,
                  bg: c.expenseBg,
                  onTap: () => context.go(Routes.entries),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            SectionCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Outstanding', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('Not counted in cash', style: context.text.bodySmall?.copyWith(color: c.muted)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _OutstandingTile(
                      label: 'Receivable',
                      value: m(s.receivable),
                      note: s.openReceivables.isEmpty
                          ? 'Nothing owed to you'
                          : '${s.openReceivables.length} open${ui.dueThisWeek > 0 ? ' · ${ui.dueThisWeek} due this week' : ''}',
                      fg: c.info,
                      bg: c.infoBg,
                      onTap: () => context.push(Routes.accruals),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _OutstandingTile(
                      label: 'Payable',
                      value: m(s.payable),
                      note: s.openPayables.isEmpty ? 'Nothing owed' : '${s.openPayables.length} open',
                      fg: c.pending,
                      bg: c.pendingBg,
                      onTap: () => context.push('${Routes.accruals}?tab=pay'),
                    ),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            SectionCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Text(f.showAll ? 'All categories' : 'Top 5', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  PillSegment<CategoryKind>(
                    compact: true,
                    options: const [(CategoryKind.expense, 'Expenses'), (CategoryKind.income, 'Income')],
                    selected: f.topKind,
                    onChanged: vm.setTopKind,
                  ),
                ]),
                const SizedBox(height: 14),
                if (ui.top.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('No ${f.topKind == CategoryKind.income ? 'income' : 'expenses'} in this range yet.',
                        textAlign: TextAlign.center, style: TextStyle(color: c.muted)),
                  ),
                for (final row in ui.top) ...[
                  Row(children: [
                    Expanded(child: Text(row.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text('${(row.share * 100).round()}%', style: context.text.bodySmall?.copyWith(color: c.muted)),
                    const SizedBox(width: 10),
                    Text(m(row.amount), style: figureStyle(14)),
                  ]),
                  const SizedBox(height: 6),
                  ShareBar(fraction: row.share, color: f.topKind == CategoryKind.income ? c.income : c.expenseBar),
                  const SizedBox(height: 12),
                ],
                if (ui.hasMoreTop)
                  TextButton(onPressed: vm.toggleAll, child: Text(f.showAll ? 'Show top 5 only' : 'See all categories')),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  void _bookSwitcher(BuildContext context, WidgetRef ref) {
    final books = ref.read(bookRepositoryProvider);
    final active = ref.read(activeBookIdProvider);
    showAppSheet<void>(
      context,
      title: 'Switch book',
      builder: (sheet) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final b in books.active) ...[
          _BookOption(
            name: b.name,
            meta: _bookMeta(books.mainBookId == b.id, books.members[b.id]?.length ?? 1),
            colorIndex: b.colorIndex,
            selected: b.id == active,
            onTap: () {
              Navigator.pop(sheet);
              ref.read(dashboardViewModelProvider.notifier).switchBook(b.id);
              showToast(context, 'Now viewing ${b.name}');
            },
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        OutlinedButton(
          onPressed: () {
            Navigator.pop(sheet);
            context.push(Routes.books);
          },
          child: const Text('Manage books & members'),
        ),
      ]),
    );
  }

  static String _bookMeta(bool main, int members) =>
      '${main ? 'Main' : 'Sub-book'} · ${members > 1 ? 'shared with ${members - 1}' : 'only you'}';
}

class _CashCard extends ConsumerWidget {
  const _CashCard({required this.ui});
  final DashboardUiState ui;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ui.summary;
    final r = ui.range;
    final rangeText = '${shortDate(r.start)} – ${shortDate(r.end)}, ${r.end.year}';
    final openingDate = r.start.subtract(const Duration(days: 1));
    final hasWallets = ref.watch(walletRepositoryProvider).any((w) => w.bookId == ui.book.id);
    const fg = Colors.white;
    const fgMuted = Color(0xFFBFE3D7);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF0E3B32), borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('CASH · $rangeText'.toUpperCase(),
              style: context.text.labelSmall?.copyWith(color: fgMuted, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
          const Spacer(),
          StatusPill(ui.currency, fg: fg, bg: Colors.white24),
        ]),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(formatMoney(s.closing, ui.currency), style: figureStyle(38, color: fg)),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _kv(context, 'Opening · ${openingDate.year == r.end.year ? shortDate(openingDate) : '${shortDate(openingDate)}, ${openingDate.year}'}',
                formatMoney(s.opening, ui.currency), fgMuted, fg),
          ),
          Expanded(child: _kv(context, 'Net movement', formatSigned(s.net, ui.currency), fgMuted, fg)),
        ]),
        if (!hasWallets) ...[
          const SizedBox(height: 12),
          Text('Add a wallet to set your opening balance.', style: context.text.bodySmall?.copyWith(color: fgMuted)),
        ],
      ]),
    );
  }

  Widget _kv(BuildContext context, String k, String v, Color kc, Color vc) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: context.text.bodySmall?.copyWith(color: kc)),
        const SizedBox(height: 2),
        Text(v, style: figureStyle(16, color: vc)),
      ]);
}

class _FlowTile extends StatelessWidget {
  const _FlowTile({required this.label, required this.value, required this.icon, required this.fg, required this.bg, required this.onTap});
  final String label, value;
  final IconData icon;
  final Color fg, bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
                  child: Icon(icon, size: 16, color: fg),
                ),
                const SizedBox(width: 8),
                Text(label, style: context.text.labelLarge?.copyWith(color: context.colors.muted, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
              FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: figureStyle(17, color: fg))),
            ]),
          ),
        ),
      );
}

class _OutstandingTile extends StatelessWidget {
  const _OutstandingTile({required this.label, required this.value, required this.note, required this.fg, required this.bg, required this.onTap});
  final String label, value, note;
  final Color fg, bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$label ›', style: context.text.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: figureStyle(17, color: fg))),
              const SizedBox(height: 4),
              Text(note, style: context.text.bodySmall?.copyWith(color: fg)),
            ]),
          ),
        ),
      );
}

class _BookOption extends StatelessWidget {
  const _BookOption({required this.name, required this.meta, required this.colorIndex, required this.selected, required this.onTap});
  final String name, meta;
  final int colorIndex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? context.colors.selectedBg.withValues(alpha: 0.4) : context.scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? context.scheme.primary : context.scheme.outlineVariant, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              BookTile(name: name, colorIndex: colorIndex, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(meta, style: context.text.bodySmall?.copyWith(color: context.colors.muted)),
                ]),
              ),
              if (selected) StatusPill('VIEWING', fg: context.colors.selected, bg: context.colors.selectedBg),
            ]),
          ),
        ),
      );
}
