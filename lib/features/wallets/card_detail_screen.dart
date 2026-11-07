import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/wallet.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import 'wallets_view_model.dart';

class CardDetailScreen extends ConsumerStatefulWidget {
  const CardDetailScreen({super.key, required this.walletId});
  final String walletId;

  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends ConsumerState<CardDetailScreen> {
  bool _allHistory = false;

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(walletViewProvider(widget.walletId));
    if (view == null) return Scaffold(appBar: AppBar(), body: const EmptyState(title: 'Card not found', body: ''));
    final w = view.wallet;
    final c = context.colors;
    final today = ref.watch(todayProvider);
    final actions = ref.read(cardActionsProvider.notifier);
    String m(int v) => formatMoney(v, w.currency);

    final outstanding = view.balance;
    final unbilled = outstanding > w.statementBalance ? outstanding - w.statementBalance : 0;
    final due = nextDueDate(w.dueDay, today);
    final daysToDue = daysBetween(today, due);
    final dueLine = w.statementBalance > 0
        ? '${daysToDue == 0 ? 'Due today' : daysToDue == 1 ? 'Due tomorrow' : 'Due in $daysToDue days'} · ${dayDate(due)}'
        : 'Paid in full · next statement on the ${ordinal(w.statementDay)}';
    final pct = w.creditLimit > 0 ? outstanding / w.creditLimit : 0.0;

    // Mock statement history: the last six closed cycles.
    final history = [
      for (var i = 1; i <= 6; i++)
        (
          '${shortDate(clampedDay(today.year, today.month - i - 1, w.statementDay).add(const Duration(days: 1)))} – '
              '${shortDate(clampedDay(today.year, today.month - i, w.statementDay))}',
          minor([8420, 11075.5, 7310, 9940, 6205.25, 10380][i - 1]),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(w.name),
        actions: [
          IconButton(tooltip: 'Card settings', icon: const Icon(Icons.tune), onPressed: () => _settings(w)),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFF1E3F78), borderRadius: BorderRadius.circular(24)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StatusPill(dueLine, fg: Colors.white, bg: Colors.white24),
            const SizedBox(height: 12),
            Text(m(w.statementBalance), style: figureStyle(34, color: Colors.white)),
            Text('Last statement · ${actions.cycleLabel(w, today)}', style: const TextStyle(color: Color(0xFFC9D8F5))),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF1E3F78)),
              onPressed: outstanding > 0 ? () => _pay(w, outstanding) : null,
              child: const Text('Pay card'),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        RowGroup(children: [
          ListRow(title: 'Current outstanding', trailing: Text(m(outstanding), style: figureStyle(15))),
          ListRow(title: 'Unbilled this cycle', trailing: Text(m(unbilled), style: figureStyle(15))),
        ]),
        const SizedBox(height: 14),
        SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Text('Credit used', style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(w.creditLimit > 0 ? '${(pct * 100).round()}% of ${m(w.creditLimit)}' : 'No limit set', style: TextStyle(color: c.muted)),
            ]),
            const SizedBox(height: 10),
            ShareBar(fraction: pct, color: c.card),
            const SizedBox(height: 10),
            Text('Statement closes on the ${ordinal(w.statementDay)} · payment due on the ${ordinal(w.dueDay)}',
                style: context.text.bodySmall?.copyWith(color: c.muted)),
          ]),
        ),
        const SizedBox(height: 14),
        SectionCard(
          padding: EdgeInsets.zero,
          child: SwitchListTile(
            value: w.reminderOn,
            onChanged: (v) {
              actions.setReminder(w, v);
              showToast(context, v ? 'Reminder on' : 'Reminder off');
            },
            title: const Text('Due-date reminder', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('3 days before and on the due date'),
          ),
        ),
        const SizedBox(height: 18),
        const SectionLabel('Statement history'),
        RowGroup(children: [
          for (final (period, amt) in _allHistory ? history : history.take(3))
            ListRow(title: period, subtitle: 'Paid in full', trailing: Text(m(amt), style: figureStyle(14))),
        ]),
        TextButton(
          onPressed: () => setState(() => _allHistory = !_allHistory),
          child: Text(_allHistory ? 'Show fewer' : 'Show 6 months'),
        ),
      ]),
    );
  }

  void _pay(Wallet card, int outstanding) {
    final sources = ref
        .read(walletRepositoryProvider)
        .where((x) => x.bookId == card.bookId && !x.isLiability && x.currency == card.currency)
        .toList();
    var option = card.statementBalance > 0 ? 0 : 1;
    var from = (sources.where((s) => s.isDefault).firstOrNull ?? sources.firstOrNull)?.id;
    final custom = TextEditingController();
    String m(int v) => formatMoney(v, card.currency);

    showAppSheet<void>(
      context,
      title: 'Card payment',
      subtitle: 'Saved as a transfer — lowers cash and card debt, not your expenses.',
      builder: (sheet) => StatefulBuilder(builder: (sheet, set) {
        int amount() => switch (option) { 0 => card.statementBalance, 1 => outstanding, _ => parseMinor(custom.text) ?? 0 };
        Widget opt(int i, String label, String? value) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SelectChip(
                tall: true,
                label: value == null ? label : '$label · $value',
                selected: option == i,
                onTap: () => set(() => option = i),
              ),
            );
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          opt(0, 'Last statement balance', m(card.statementBalance)),
          opt(1, 'Current outstanding', m(outstanding)),
          opt(2, 'Custom amount', null),
          if (option == 2)
            TextField(
              controller: custom,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Custom amount', prefixText: '${currencySymbol(card.currency)} '),
            ),
          const SizedBox(height: 12),
          const SectionLabel('Pay from'),
          ChipWrap(children: [
            for (final s in sources) SelectChip(label: s.name, selected: s.id == from, onTap: () => set(() => from = s.id)),
          ]),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final a = amount() > outstanding ? outstanding : amount();
              if (a <= 0) return showToast(context, 'Enter an amount to pay');
              if (from == null) return showToast(context, 'Pick a wallet to pay from');
              ref.read(cardActionsProvider.notifier).pay(card, fromWalletId: from!, amount: a);
              Navigator.pop(sheet);
              showToast(context, 'Paid ${m(a)} from ${sources.firstWhere((s) => s.id == from).name}');
            },
            child: const Text('Confirm payment'),
          ),
        ]);
      }),
    );
  }

  void _settings(Wallet card) {
    final stmt = TextEditingController(text: '${card.statementDay}');
    final due = TextEditingController(text: '${card.dueDay}');
    showAppSheet<void>(
      context,
      title: 'Card settings',
      builder: (sheet) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: TextField(controller: stmt, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Statement day'))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: due, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Due day'))),
        ]),
        const SizedBox(height: 8),
        Text('Day 29–31 falls back to the last day in shorter months.', style: sheet.text.bodySmall?.copyWith(color: sheet.colors.muted)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            final a = int.tryParse(stmt.text), b = int.tryParse(due.text);
            bool ok(int? x) => x != null && x >= 1 && x <= 31;
            if (!ok(a) || !ok(b)) return showToast(context, 'Use days between 1 and 31');
            ref.read(cardActionsProvider.notifier).saveCycle(card, a!, b!);
            Navigator.pop(sheet);
            showToast(context, 'Card settings saved');
          },
          child: const Text('Save'),
        ),
      ]),
    );
  }
}
