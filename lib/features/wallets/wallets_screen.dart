import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/wallet.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../entries/entries_view_model.dart';
import 'wallets_view_model.dart';

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(walletsUiProvider);
    final book = ref.watch(activeBookProvider);
    final main = ui.assetTotals[book.defaultCurrency] ?? 0;
    final others = ui.assetTotals.entries.where((e) => e.key != book.defaultCurrency && e.value != 0).toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
          Row(children: [
            Text('Wallets', style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const Spacer(),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => _addWallet(context, ref, book.id, book.defaultCurrency),
              icon: const Icon(Icons.add),
              label: const Text('Add wallet'),
            ),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF0E3B32), borderRadius: BorderRadius.circular(24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cash across asset wallets · ${book.defaultCurrency}',
                  style: context.text.bodySmall?.copyWith(color: const Color(0xFFBFE3D7), fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(formatMoney(main, book.defaultCurrency), style: figureStyle(32, color: Colors.white)),
              for (final o in others)
                Text('+ ${formatMoney(o.value, o.key)} in ${o.key}', style: figureStyle(15, color: Colors.white)),
              const SizedBox(height: 8),
              Text('Card debt is tracked separately and never subtracted here.',
                  style: context.text.bodySmall?.copyWith(color: const Color(0xFFBFE3D7))),
            ]),
          ),
          const SizedBox(height: 18),
          const SectionLabel('Assets'),
          if (ui.assets.isEmpty)
            const SectionCard(child: Text('No asset wallets yet. Add cash, a bank account or an e-wallet.'))
          else
            RowGroup(children: [
              for (final v in ui.assets)
                ListRow(
                  leading: _WalletIcon(v.wallet),
                  title: v.wallet.name,
                  subtitle: '${v.wallet.type.label}${v.wallet.isDefault ? ' · default' : ''}',
                  trailing: Text(formatMoney(v.balance, v.wallet.currency), style: figureStyle(15)),
                  onTap: () {
                    ref.read(entriesViewModelProvider.notifier).setQuery(v.wallet.name);
                    context.go(Routes.entries);
                  },
                ),
            ]),
          const SizedBox(height: 18),
          const SectionLabel('Liabilities'),
          if (ui.cards.isEmpty) const SectionCard(child: Text('No credit cards. Add one to track statements and due dates.')),
          for (final v in ui.cards) ...[
            _CardTile(view: v),
            const SizedBox(height: 10),
          ],
        ]),
      ),
    );
  }

  void _addWallet(BuildContext context, WidgetRef ref, String bookId, String currency) {
    final name = TextEditingController();
    final amount = TextEditingController();
    var type = WalletType.ewallet;
    showAppSheet<void>(
      context,
      title: 'New wallet',
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Maya, UnionBank')),
          const SizedBox(height: 14),
          ChipWrap(children: [
            for (final t in WalletType.values) SelectChip(label: t.label, selected: type == t, onTap: () => set(() => type = t)),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: type == WalletType.card ? 'Amount owed today' : 'Opening balance',
              prefixText: '${currencySymbol(currency)} ',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final n = name.text.trim();
              if (n.isEmpty) return showToast(context, 'Give the wallet a name');
              ref.read(walletRepositoryProvider.notifier).add(
                    bookId: bookId,
                    name: n,
                    type: type,
                    currency: currency,
                    opening: parseMinor(amount.text) ?? 0,
                  );
              Navigator.pop(sheet);
              showToast(context, '$n added');
            },
            child: const Text('Save wallet'),
          ),
        ]),
      ),
    );
  }
}

class _WalletIcon extends StatelessWidget {
  const _WalletIcon(this.w);
  final Wallet w;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (w.type) {
      WalletType.cash => (const Color(0xFFF5D9A8), const Color(0xFF5C4310)),
      WalletType.bank => (const Color(0xFFCFE6DE), const Color(0xFF0A4F41)),
      WalletType.ewallet => (const Color(0xFFD7E1F5), const Color(0xFF1E3F78)),
      WalletType.card => (const Color(0xFFD7E1F5), const Color(0xFF2457A6)),
    };
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(w.name[0], style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 15)),
    );
  }
}

class _CardTile extends ConsumerWidget {
  const _CardTile({required this.view});
  final WalletView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = view.wallet;
    final c = context.colors;
    final pct = w.creditLimit > 0 ? view.balance / w.creditLimit : 0.0;
    return Material(
      color: context.scheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/wallets/${w.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 40, height: 28, decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(6))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(w.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('Statement on the ${w.statementDay} · due the ${w.dueDay}', style: context.text.bodySmall?.copyWith(color: c.muted)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(formatMoney(view.balance, w.currency), style: figureStyle(15, color: c.card)),
                Text('owed', style: context.text.bodySmall?.copyWith(color: c.muted)),
              ]),
            ]),
            const SizedBox(height: 12),
            ShareBar(fraction: pct, color: c.card),
            const SizedBox(height: 6),
            Text(
              w.creditLimit > 0 ? '${(pct * 100).round()}% of ${formatMoney(w.creditLimit, w.currency)} limit used' : 'No limit set',
              style: context.text.bodySmall?.copyWith(color: c.muted),
            ),
          ]),
        ),
      ),
    );
  }
}
