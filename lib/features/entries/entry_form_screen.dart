import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/calculator.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/category.dart';
import '../../data/models/entry.dart';
import '../../data/models/wallet.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import 'entry_form_view_model.dart';

class EntryFormScreen extends ConsumerStatefulWidget {
  const EntryFormScreen({super.key, this.editId, this.initialType});

  final String? editId;
  final String? initialType; // 'income' | 'expense'

  @override
  ConsumerState<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends ConsumerState<EntryFormScreen> {
  late final EntryDraft d;
  late final TextEditingController _amount;
  final _note = TextEditingController();
  final _who = TextEditingController();
  bool _catOpen = false;
  int _fileSeq = 1;

  bool get _editing => widget.editId != null;

  @override
  void initState() {
    super.initState();
    final today = ref.read(todayProvider);
    final existing = _editing ? ref.read(entryRepositoryProvider.notifier).byId(widget.editId!) : null;
    if (existing != null) {
      d = EntryDraft.fromEntry(existing);
    } else {
      final book = ref.read(activeBookProvider);
      final defaultWallet = ref
          .read(walletRepositoryProvider)
          .where((w) => w.bookId == book.id && w.isDefault)
          .firstOrNull;
      d = EntryDraft(
        bookId: book.id,
        date: today,
        currency: book.defaultCurrency,
        isIncome: widget.initialType == 'income',
        walletId: defaultWallet?.id,
        dueDate: today.add(const Duration(days: 14)),
      );
    }
    _amount = TextEditingController(text: d.amountMinor == null ? '' : (d.amountMinor! / 100).toStringAsFixed(2));
    _note.text = d.note;
    _who.text = d.counterparty;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _who.dispose();
    super.dispose();
  }

  // ── Keypad ──
  void _press(String k) {
    final a = _amount.text;
    setState(() {
      if (k == 'C') {
        _amount.text = '';
      } else if (k == '=') {
        final v = evaluateAmount(a);
        if (v == null || v <= 0) {
          showToast(context, 'Nothing to calculate yet');
        } else {
          _amount.text = (v / 100).toStringAsFixed(2);
        }
      } else if (a.isNotEmpty) {
        _amount.text = hasOperator(a[a.length - 1]) ? a.substring(0, a.length - 1) + k : a + k;
      }
    });
  }

  void _sync() {
    d.amountMinor = evaluateAmount(_amount.text);
    d.note = _note.text;
    d.counterparty = _who.text;
  }

  Future<void> _pickDate({required bool due}) async {
    final today = ref.read(todayProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: due ? (d.dueDate ?? today) : d.date,
      firstDate: DateTime(today.year - 5),
      lastDate: DateTime(today.year + 5),
    );
    if (picked != null) setState(() => due ? d.dueDate = picked : d.date = picked);
  }

  void _addAttachment() {
    if (d.attachments.length >= 5) return showToast(context, 'Up to 5 attachments per entry');
    const sources = [
      (Icons.photo_camera_outlined, 'Camera', 'Snap a receipt', 'receipt', 'jpg', 640000),
      (Icons.photo_library_outlined, 'Photo library', 'JPG or PNG', 'photo', 'png', 820000),
      (Icons.description_outlined, 'Files', 'docx, pdf, xlsx, txt, pptx', 'document', 'pdf', 210000),
    ];
    showAppSheet<void>(
      context,
      title: 'Add attachment',
      subtitle: 'Mock picker — the real app uses image_picker and file_picker.',
      builder: (sheet) => Column(children: [
        for (final (icon, label, note, stem, ext, size) in sources)
          ListTile(
            leading: Icon(icon),
            title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(note),
            onTap: () {
              Navigator.pop(sheet);
              final name = '$stem-${_fileSeq++}.$ext';
              setState(() => d.attachments.add(Attachment(name: name, sizeBytes: size)));
              showToast(context, 'Attached $name');
            },
          ),
      ]),
    );
  }

  void _save({required bool another}) {
    _sync();
    final vm = ref.read(entryFormViewModelProvider.notifier);
    final problem = vm.validate(d);
    if (problem != null) return showToast(context, problem);
    vm.save(d);
    final saved = formatMoney(d.amountMinor!, d.currency);
    if (another) {
      // Keep type, date, wallet and currency.
      setState(() {
        _amount.clear();
        _note.clear();
        _who.clear();
        d.attachments.clear();
        _catOpen = false;
      });
      showToast(context, 'Saved $saved — add the next one');
    } else {
      showToast(context, _editing ? 'Entry updated' : 'Saved $saved');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final book = ref.watch(bookRepositoryProvider.select((b) => b.byId(d.bookId)))!;
    final memberCount = ref.watch(bookRepositoryProvider.select((b) => b.members[d.bookId]?.length ?? 1));
    final wallets = ref.watch(walletRepositoryProvider).where((w) => w.bookId == d.bookId).toList();
    final cats = ref.read(categoryRepositoryProvider.notifier).forBook(
          d.bookId,
          d.isIncome ? CategoryKind.income : CategoryKind.expense,
        );
    ref.watch(categoryRepositoryProvider);
    final today = ref.watch(todayProvider);
    final value = evaluateAmount(_amount.text);
    final transfer = d.treatment == Treatment.transfer;
    final toWallet = wallets.where((w) => w.id == d.toWalletId).firstOrNull;
    final fromWallet = wallets.where((w) => w.id == d.fromWalletId).firstOrNull;
    final isCardPayment = transfer && toWallet?.isLiability == true;
    final bookCurrencies = {book.defaultCurrency, ...wallets.map((w) => w.currency)}.toList();
    final selectedCat = cats.where((x) => x.id == d.categoryId).firstOrNull;
    d.amountMinor = value;
    final valid = ref.read(entryFormViewModelProvider.notifier).validate(d) == null;

    final help = switch (d.treatment) {
      Treatment.regular => d.isIncome ? 'Money received. Counts toward cash right away.' : 'Money spent. Counts toward cash right away.',
      Treatment.accrual => d.isIncome
          ? 'Money you expect but haven’t received yet. Kept out of cash until you mark it settled.'
          : 'Money you owe but haven’t paid yet. Kept out of cash until you mark it settled.',
      Treatment.transfer => 'Moves money between your wallets. Never counted as income or expense.',
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => context.pop()),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_editing ? 'Edit entry' : (isCardPayment ? 'Card payment' : 'New entry'),
              style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          Text.rich(
            TextSpan(text: 'Adding to ', children: [
              TextSpan(text: book.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              if (memberCount > 1) TextSpan(text: ' · shared with ${memberCount - 1}'),
            ]),
            style: context.text.bodySmall?.copyWith(color: c.muted),
          ),
        ]),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          PillSegment<bool>(
            expand: true,
            options: const [(true, 'Income'), (false, 'Expense')],
            selected: d.isIncome,
            colorFor: (v) => v ? c.income : c.expense,
            onChanged: (v) => setState(() {
              if (v == d.isIncome) return;
              d.isIncome = v;
              d.categoryId = null;
              d.treatment = Treatment.regular;
              _catOpen = false;
            }),
          ),
          const SizedBox(height: 18),
          // ── Amount ──
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('AMOUNT', style: context.text.labelMedium?.copyWith(color: c.muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(children: [
                Tooltip(
                  message: 'Change currency',
                  child: ActionChip(
                    label: Text('${currencySymbol(d.currency)} ${d.currency}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    onPressed: transfer || bookCurrencies.length < 2
                        ? null
                        : () => setState(() {
                              final i = bookCurrencies.indexOf(d.currency);
                              d.currency = bookCurrencies[(i + 1) % bookCurrencies.length];
                              final w = wallets.where((w) => w.id == d.walletId).firstOrNull;
                              if (w != null && w.currency != d.currency) d.walletId = null;
                            }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    style: figureStyle(30),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ]),
              if (hasOperator(_amount.text) && (value ?? 0) > 0)
                Text('= ${formatMoney(value!, d.currency)}', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(children: [
                for (final (k, label) in [('+', 'Add'), ('-', 'Subtract'), ('×', 'Multiply'), ('÷', 'Divide'), ('=', 'Equals'), ('C', 'Clear')]) ...[
                  Expanded(
                    child: Semantics(
                      label: label,
                      button: true,
                      excludeSemantics: true,
                      child: Material(
                        color: k == '=' ? c.selectedBg : c.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _press(k),
                          child: SizedBox(
                            height: 44,
                            child: Center(
                              child: Text(k == '-' ? '−' : k, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (k != 'C') const SizedBox(width: 6),
                ],
              ]),
            ]),
          ),
          const SizedBox(height: 18),
          // ── Treatment ──
          SectionLabel(d.isIncome ? 'Is it a receivable, a transfer, or neither?' : 'Is it a payable, a transfer, or neither?'),
          ChipWrap(children: [
            for (final (t, label) in [
              (Treatment.regular, 'Neither'),
              (Treatment.accrual, d.isIncome ? 'Receivable' : 'Payable'),
              (Treatment.transfer, 'Transfer'),
            ])
              SelectChip(
                label: label,
                selected: d.treatment == t,
                onTap: () => setState(() {
                  d.treatment = t;
                  _catOpen = false;
                  if (t == Treatment.transfer) {
                    final assets = wallets.where((w) => !w.isLiability).toList();
                    d.fromWalletId ??= assets.firstOrNull?.id;
                    d.toWalletId ??= assets.where((w) => w.id != d.fromWalletId).firstOrNull?.id;
                  }
                }),
              ),
          ]),
          const SizedBox(height: 8),
          Text(help, style: context.text.bodySmall?.copyWith(color: c.muted, height: 1.45)),
          const SizedBox(height: 18),
          // ── Date ──
          const SectionLabel('Date'),
          ChipWrap(children: [
            SelectChip(label: 'Today', selected: sameDay(d.date, today), onTap: () => setState(() => d.date = today)),
            SelectChip(
              label: 'Yesterday',
              selected: sameDay(d.date, today.subtract(const Duration(days: 1))),
              onTap: () => setState(() => d.date = today.subtract(const Duration(days: 1))),
            ),
            SelectChip(
              label: fullDate(d.date),
              leading: const Icon(Icons.calendar_today_outlined, size: 16),
              selected: false,
              onTap: () => _pickDate(due: false),
            ),
          ]),
          const SizedBox(height: 18),
          // ── Category ──
          if (!transfer) ...[
            const SectionLabel('Category'),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: () => setState(() => _catOpen = !_catOpen),
              child: Row(children: [
                Expanded(
                  child: Text(selectedCat?.name ?? 'Choose a category',
                      style: TextStyle(color: selectedCat == null ? c.muted : null)),
                ),
                Icon(_catOpen ? Icons.expand_less : Icons.expand_more),
              ]),
            ),
            if (_catOpen) ...[
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 2.4,
                children: [
                  for (final cat in cats)
                    SelectChip(
                      label: cat.name,
                      selected: cat.id == d.categoryId,
                      onTap: () => setState(() {
                        d.categoryId = cat.id;
                        _catOpen = false;
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),
          ],
          // ── Accrual ──
          if (d.treatment == Treatment.accrual) ...[
            const SectionLabel('Due date'),
            SelectChip(
              label: d.dueDate == null ? 'Pick a date' : fullDate(d.dueDate!),
              leading: const Icon(Icons.event_outlined, size: 16),
              selected: d.dueDate != null,
              onTap: () => _pickDate(due: true),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _who,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: d.isIncome ? 'Who owes you' : 'Who you owe', hintText: 'Name'),
            ),
            const SizedBox(height: 18),
          ],
          // ── Wallet ──
          if (d.treatment == Treatment.regular) ...[
            const SectionLabel('Wallet', trailing: 'optional'),
            ChipWrap(children: [
              SelectChip(label: 'None', selected: d.walletId == null, onTap: () => setState(() => d.walletId = null)),
              for (final w in wallets)
                SelectChip(
                  label: w.currency == book.defaultCurrency ? w.name : '${w.name} · ${w.currency}',
                  selected: d.walletId == w.id,
                  onTap: () => setState(() {
                    d.walletId = w.id;
                    d.currency = w.currency; // an entry in a wallet uses that wallet's currency
                  }),
                ),
            ]),
            if (!d.isIncome && wallets.where((w) => w.id == d.walletId).firstOrNull?.isLiability == true) ...[
              const SizedBox(height: 8),
              Text('Credit card: counts as an expense now, but won’t touch cash until you pay the card.',
                  style: context.text.bodySmall?.copyWith(color: c.info)),
            ],
            const SizedBox(height: 18),
          ],
          // ── Transfer ──
          if (transfer) ...[
            _walletPicker('From wallet', wallets.where((w) => !w.isLiability).toList(), d.fromWalletId, (id) {
              d.fromWalletId = id;
              final from = wallets.firstWhere((w) => w.id == id);
              if (toWallet != null && toWallet.currency != from.currency) d.toWalletId = null;
            }),
            const SizedBox(height: 14),
            _walletPicker(
              'To wallet',
              wallets.where((w) => fromWallet == null || w.currency == fromWallet.currency).toList(),
              d.toWalletId,
              (id) => d.toWalletId = id,
            ),
            if (d.fromWalletId != null && d.fromWalletId == d.toWalletId) ...[
              const SizedBox(height: 8),
              Text('From and To must be different wallets.', style: TextStyle(color: c.expense, fontWeight: FontWeight.w600)),
            ],
            if (isCardPayment) ...[
              const SizedBox(height: 8),
              Text('Card payment: lowers cash and card debt, not your expenses.', style: context.text.bodySmall?.copyWith(color: c.info)),
            ],
            const SizedBox(height: 18),
          ],
          // ── Notes & attachments ──
          TextField(
            controller: _note,
            maxLines: 3,
            minLines: 2,
            decoration: const InputDecoration(labelText: 'Notes', hintText: 'What was it for?', alignLabelWithHint: true),
          ),
          const SizedBox(height: 18),
          SectionLabel('Attachments', trailing: '${d.attachments.length} of 5'),
          ChipWrap(children: [
            for (final (i, a) in d.attachments.indexed)
              InputChip(
                avatar: Text(a.ext, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                label: Text(a.name),
                deleteButtonTooltipMessage: 'Remove attachment',
                onDeleted: () {
                  setState(() => d.attachments.removeAt(i));
                  showToast(context, 'Removed ${a.name}');
                },
              ),
            ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('Add'), onPressed: _addAttachment),
          ]),
          const SizedBox(height: 6),
          Text('docx · pdf · xlsx · txt · pptx · jpg · png — up to 10 MB each', style: context.text.bodySmall?.copyWith(color: c.muted)),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(color: context.scheme.surface, border: Border(top: BorderSide(color: context.scheme.outlineVariant))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              if (!_editing) ...[
                Expanded(child: OutlinedButton(onPressed: () => _save(another: true), child: const Text('Add another'))),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton(
                  style: valid ? null : FilledButton.styleFrom(backgroundColor: context.scheme.primary.withValues(alpha: 0.45)),
                  onPressed: () => _save(another: false),
                  child: Text(_editing ? 'Save changes' : 'Save entry'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _walletPicker(String label, List<Wallet> options, String? selected, ValueChanged<String> onPick) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionLabel(label),
        ChipWrap(children: [
          for (final w in options)
            SelectChip(
              label: w.isLiability ? '${w.name} (card)' : w.name,
              selected: w.id == selected,
              onTap: () => setState(() => onPick(w.id)),
            ),
        ]),
      ]);
}
