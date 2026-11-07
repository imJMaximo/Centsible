import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/mock/mock_seed.dart';
import '../../data/models/entry.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../dates.dart';
import '../money.dart';
import 'common.dart';

/// +, − or ⇄ in a tinted square.
class EntryTypeIcon extends StatelessWidget {
  const EntryTypeIcon(this.type, {super.key, this.size = 38});
  final EntryType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (glyph, bg, fg) = switch (type) {
      EntryType.income => ('+', c.incomeBg, c.income),
      EntryType.expense => ('−', c.expenseBg, c.expense),
      EntryType.transfer => ('⇄', c.surfaceMuted, c.muted),
    };
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(glyph, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 18)),
    );
  }
}

/// Human labels for an entry, resolved against categories and wallets.
class EntryLabels {
  EntryLabels(WidgetRef ref, Entry e, DateTime today)
      : title = _title(ref, e),
        subtitle = _subtitle(ref, e, today);

  final String title;
  final String subtitle;

  static String _title(WidgetRef ref, Entry e) {
    if (e.type == EntryType.transfer) {
      final w = ref.read(walletRepositoryProvider.notifier);
      final to = w.byId(e.toWalletId);
      return to?.isLiability == true ? 'Card payment' : '${w.byId(e.walletId)?.name ?? '?'} → ${to?.name ?? '?'}';
    }
    return ref.read(categoryRepositoryProvider.notifier).byId(e.categoryId)?.name ?? 'Uncategorised';
  }

  static String _subtitle(WidgetRef ref, Entry e, DateTime today) {
    final w = ref.read(walletRepositoryProvider.notifier);
    final where = switch (e) {
      Entry(type: EntryType.transfer) => 'Transfer',
      Entry(isPending: true) =>
        '${e.accrual == Accrual.receivable ? 'Receivable' : 'Payable'} · due ${shortDate(e.dueDate ?? today)}',
      Entry(isAccrual: true) => 'Settled into ${w.byId(e.settledWalletId)?.name ?? 'wallet'}',
      _ => w.byId(e.walletId)?.name ?? 'No wallet',
    };
    final by = e.createdBy == MockSeed.meId ? 'you' : (MockSeed.userNames[e.createdBy] ?? e.createdBy);
    return [where, if (e.note.isNotEmpty) e.note, by].join(' · ');
  }
}

class EntryTile extends ConsumerWidget {
  const EntryTile({super.key, required this.entry, required this.today});
  final Entry entry;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild if categories/wallets get renamed.
    ref.watch(categoryRepositoryProvider);
    ref.watch(walletRepositoryProvider);
    final labels = EntryLabels(ref, entry, today);
    final c = context.colors;
    final amountColor = entry.isPending
        ? c.muted
        : switch (entry.type) { EntryType.income => c.income, EntryType.expense => c.expense, _ => c.muted };
    final prefix = switch (entry.type) { EntryType.income => '+ ', EntryType.expense => '− ', _ => '' };

    return InkWell(
      onTap: () => context.push('/entries/${entry.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          EntryTypeIcon(entry.type),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(labels.title, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(labels.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: c.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$prefix${formatMoney(entry.amount, entry.currency)}', style: figureStyle(15, color: amountColor)),
            if (entry.isPending) ...[
              const SizedBox(height: 3),
              StatusPill('PENDING', fg: c.pending, bg: c.pendingBg),
            ],
          ]),
        ]),
      ),
    );
  }
}
