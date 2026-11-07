import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/entry_tile.dart';
import '../../core/widgets/feedback.dart';
import '../../data/mock/mock_seed.dart';
import '../../data/models/entry.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../accruals/settle_sheet.dart';

final entryByIdProvider = Provider.family<Entry?, String>(
  (ref, id) => ref.watch(entryRepositoryProvider).where((e) => e.id == id).firstOrNull,
);

class EntryDetailScreen extends ConsumerWidget {
  const EntryDetailScreen({super.key, required this.entryId});
  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(entryByIdProvider(entryId));
    if (e == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(title: 'Entry not found', body: 'It may have been deleted by another member.'));
    }
    final c = context.colors;
    final today = ref.watch(todayProvider);
    final books = ref.watch(bookRepositoryProvider);
    final canWrite = books.roleOf(e.bookId, MockSeed.meId).canWrite;
    final book = books.byId(e.bookId);
    final wallets = ref.read(walletRepositoryProvider.notifier);
    ref.watch(walletRepositoryProvider);
    final cat = ref.watch(categoryRepositoryProvider.select((_) => ref.read(categoryRepositoryProvider.notifier).byId(e.categoryId)));
    final labels = EntryLabels(ref, e, today);
    final recv = e.accrual == Accrual.receivable;

    final (statusText, statusFg, statusBg) = switch (e) {
      Entry(isPending: true) => () {
          final days = daysBetween(today, e.dueDate ?? today);
          final when = days < 0 ? 'OVERDUE ${-days} DAYS' : days == 0 ? 'DUE TODAY' : 'DUE IN $days DAYS';
          return ('PENDING · $when', c.pending, c.pendingBg);
        }(),
      Entry(isAccrual: true) => (recv ? 'RECEIVED' : 'PAID', c.selected, c.incomeBg),
      Entry(type: EntryType.transfer) => ('TRANSFER', c.muted, c.surfaceMuted),
      Entry(type: EntryType.income) => ('INCOME', c.income, c.incomeBg),
      _ => ('EXPENSE', c.expense, c.expenseBg),
    };
    final amountColor = switch (e.type) { EntryType.income => c.income, EntryType.expense => c.expense, _ => context.scheme.onSurface };
    final prefix = switch (e.type) { EntryType.income => '+ ', EntryType.expense => '− ', _ => '' };

    final details = <(String, String)>[
      ('Type', [
        switch (e.type) { EntryType.income => 'Income', EntryType.expense => 'Expense', EntryType.transfer => 'Transfer' },
        if (e.isAccrual) recv ? 'Receivable' : 'Payable',
      ].join(' · ')),
      if (cat != null) ('Category', cat.name),
      ('Entry date', fullDate(e.entryDate)),
      if (e.dueDate != null) ('Due', fullDate(e.dueDate!)),
      if (e.counterparty != null) (recv ? 'Who owes you' : 'Who you owe', e.counterparty!),
      if (e.type == EntryType.transfer) ...[
        ('From', wallets.byId(e.walletId)?.name ?? '—'),
        ('To', wallets.byId(e.toWalletId)?.name ?? '—'),
      ] else
        ('Wallet', e.isAccrual
            ? (e.settledWalletId == null ? (recv ? 'Not yet received' : 'Not yet paid') : wallets.byId(e.settledWalletId)!.name)
            : wallets.byId(e.walletId)?.name ?? 'None'),
      if (e.settledAt != null) ('Settled on', fullDate(e.settledAt!)),
      ('Currency', e.currency),
      if (e.note.isNotEmpty) ('Notes', e.note),
      ('Added by', e.createdBy == MockSeed.meId ? 'You' : MockSeed.userNames[e.createdBy] ?? e.createdBy),
      ('Book', book?.name ?? '—'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entry'),
        actions: [
          if (canWrite) ...[
            IconButton(tooltip: 'Edit entry', icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/entries/${e.id}/edit')),
            IconButton(
              tooltip: 'Delete entry',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final files = e.attachments.length;
                final ok = await confirmAction(
                  context,
                  title: 'Delete this entry?',
                  body: 'It disappears for everyone in ${book?.name ?? 'this book'}'
                      '${files > 0 ? ', along with its $files attachment${files == 1 ? '' : 's'}' : ''}.',
                  confirmLabel: 'Delete',
                );
                if (!ok || !context.mounted) return;
                ref.read(entryRepositoryProvider.notifier).delete(e.id);
                showToast(context, 'Entry deleted');
                context.pop();
              },
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
        SectionCard(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StatusPill(statusText, fg: statusFg, bg: statusBg),
            const SizedBox(height: 12),
            Text('$prefix${formatMoney(e.amount, e.currency)}', style: figureStyle(34, color: e.isPending ? c.muted : amountColor)),
            const SizedBox(height: 4),
            Text([labels.title, if (e.note.isNotEmpty) e.note].join(' · '), style: TextStyle(color: c.muted)),
            if (e.isAccrual && canWrite) ...[
              const SizedBox(height: 16),
              if (e.isPending)
                FilledButton(
                  onPressed: () => showSettleSheet(context, ref, e),
                  child: Text(recv ? 'Mark as received' : 'Mark as paid'),
                )
              else
                SectionCard(
                  color: c.incomeBg,
                  padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        '${recv ? 'Received into' : 'Paid from'} ${wallets.byId(e.settledWalletId)?.name ?? 'wallet'} · '
                        '${shortDate(e.settledAt!)}. Now counts as cash.',
                        style: TextStyle(color: c.selected, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(entryRepositoryProvider.notifier).unsettle(e.id, on: today, byName: 'You');
                        showToast(context, 'Back to pending');
                      },
                      child: const Text('Undo'),
                    ),
                  ]),
                ),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        RowGroup(children: [
          for (final (k, v) in details)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 120, child: Text(k, style: TextStyle(color: c.muted))),
                Expanded(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
              ]),
            ),
        ]),
        if (e.attachments.isNotEmpty) ...[
          const SizedBox(height: 18),
          SectionLabel('Attachments · ${e.attachments.length}'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.15,
            children: [for (final a in e.attachments) _AttachmentCard(a)],
          ),
        ],
        const SizedBox(height: 18),
        const SectionLabel('Activity'),
        SectionCard(
          child: Column(children: [
            for (final a in e.activity)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: context.scheme.primary, shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(a.text)),
                  Text(shortDate(a.at), style: context.text.bodySmall?.copyWith(color: c.muted)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard(this.a);
  final Attachment a;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (fg, bg) = a.ext == 'PDF' ? (c.expense, c.expenseBg) : a.ext == 'DOCX' ? (c.info, c.infoBg) : (c.selected, c.selectedBg);
    return Material(
      color: context.scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showDialog<void>(
          context: context,
          builder: (d) => AlertDialog(
            title: Text(a.name),
            content: Container(
              height: 220,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              child: Text(a.ext, style: figureStyle(28, color: fg)),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Close'))],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                child: Text(a.ext, style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 8),
            Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${a.sizeLabel} · tap to open', style: context.text.bodySmall?.copyWith(color: c.muted)),
          ]),
        ),
      ),
    );
  }
}
