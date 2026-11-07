import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/entry.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/wallet_repository.dart';

/// "Where did the money land?" — settles a receivable/payable into a wallet.
Future<void> showSettleSheet(BuildContext context, WidgetRef ref, Entry e) {
  final recv = e.accrual == Accrual.receivable;
  final today = ref.read(todayProvider);
  final wallets = ref
      .read(walletRepositoryProvider)
      .where((w) => w.bookId == e.bookId && w.currency == e.currency && !w.isLiability)
      .toList();
  var walletId = (wallets.where((w) => w.isDefault).firstOrNull ?? wallets.firstOrNull)?.id;
  var date = today;

  return showAppSheet<void>(
    context,
    title: recv ? 'Where did the money land?' : 'Which wallet paid it?',
    subtitle: 'It counts as cash on the date you ${recv ? 'receive' : 'pay'} it, not the ${recv ? 'invoice' : 'bill'} date.',
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setSheet) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionLabel('Wallet'),
        if (wallets.isEmpty)
          Text('Add a ${e.currency} wallet first.')
        else
          ChipWrap(children: [
            for (final w in wallets)
              SelectChip(label: w.name, selected: w.id == walletId, onTap: () => setSheet(() => walletId = w.id)),
          ]),
        const SizedBox(height: 14),
        SectionLabel(recv ? 'Date received' : 'Date paid'),
        ChipWrap(children: [
          SelectChip(label: 'Today', selected: date == today, onTap: () => setSheet(() => date = today)),
          SelectChip(
            label: 'Yesterday',
            selected: date != today,
            onTap: () => setSheet(() => date = today.subtract(const Duration(days: 1))),
          ),
        ]),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: walletId == null
              ? null
              : () {
                  ref.read(entryRepositoryProvider.notifier).settle(e.id, walletId: walletId!, on: date, byName: 'You');
                  Navigator.pop(sheet);
                  showToast(context, '${recv ? 'Received' : 'Paid'} ${formatMoney(e.amount, e.currency)} · now in cash');
                },
          child: Text(recv ? 'Confirm received' : 'Confirm paid'),
        ),
      ]),
    ),
  );
}
