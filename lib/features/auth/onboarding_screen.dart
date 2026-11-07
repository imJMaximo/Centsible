import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import '../../core/widgets/common.dart';
import '../../data/models/wallet.dart';
import 'auth_view_model.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  String _currency = 'PHP';
  final _name = TextEditingController(text: 'Household Budget');
  final Set<WalletType> _wallets = {WalletType.cash, WalletType.bank, WalletType.ewallet};

  static const _walletInfo = {
    WalletType.cash: ('Cash on hand', 'Money in your wallet'),
    WalletType.bank: ('Bank account', 'e.g. BPI Savings'),
    WalletType.ewallet: ('E-wallet', 'e.g. GCash, Maya'),
    WalletType.card: ('Credit card', 'Tracks what you owe and statement dates'),
  };

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _finish() {
    final name = _name.text.trim().isEmpty ? 'My book' : _name.text.trim();
    ref.read(authViewModelProvider.notifier).finishOnboarding(bookName: name, currency: _currency, starterWallets: _wallets);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bookName = _name.text.trim().isEmpty ? 'my book' : _name.text.trim();
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(child: Container(height: 4, decoration: BoxDecoration(color: context.scheme.primary, borderRadius: BorderRadius.circular(2)))),
                ],
              ]),
              const SizedBox(height: 14),
              Text('Set up your main book', style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Three quick choices. You can change all of them later.', style: TextStyle(color: c.muted)),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(24, 12, 24, 24), children: [
              const SectionLabel('1 · Default currency'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 3.2,
                children: [
                  for (final cur in kCurrencies.values)
                    SelectChip(
                      tall: true,
                      label: cur.code,
                      leading: Text(cur.symbol, style: figureStyle(18)),
                      selected: _currency == cur.code,
                      onTap: () => setState(() => _currency = cur.code),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              const SectionLabel('2 · Name your main book'),
              TextField(controller: _name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 10),
              ChipWrap(children: [
                for (final n in ['Household Budget', 'Personal', 'Side hustle'])
                  ActionChip(label: Text(n), onPressed: () => _name.text = n),
              ]),
              const SizedBox(height: 22),
              const SectionLabel('3 · Starter wallets', trailing: 'optional'),
              RowGroup(children: [
                for (final t in WalletType.values)
                  CheckboxListTile(
                    value: _wallets.contains(t),
                    onChanged: (v) => setState(() => v == true ? _wallets.add(t) : _wallets.remove(t)),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(_walletInfo[t]!.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(_walletInfo[t]!.$2),
                  ),
              ]),
              const SizedBox(height: 10),
              Text('We also add 19 starter categories (Salary, Food, Utilities…). Edit them anytime.',
                  style: context.text.bodySmall?.copyWith(color: c.muted)),
            ]),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.scheme.surface,
              border: Border(top: BorderSide(color: context.scheme.outlineVariant)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: FilledButton(onPressed: _finish, child: Text('Start $bookName in $_currency')),
            ),
          ),
        ]),
      ),
    );
  }
}
