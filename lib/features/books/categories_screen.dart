import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/feedback.dart';
import '../../data/models/category.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/category_repository.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key, this.bookId});
  final String? bookId;

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  CategoryKind _kind = CategoryKind.expense;
  final _draft = TextEditingController();

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(categoryRepositoryProvider);
    final repo = ref.read(categoryRepositoryProvider.notifier);
    final books = ref.watch(bookRepositoryProvider);
    final String bookId = widget.bookId ?? ref.watch(activeBookIdProvider);
    final book = books.byId(bookId);
    final list = repo.forBook(bookId, _kind);
    final archived = repo.forBook(bookId, _kind, archived: true);
    final c = context.colors;
    final dot = _kind == CategoryKind.income ? c.income : c.expenseBar;

    void add() {
      final v = _draft.text.trim();
      if (v.isEmpty) return showToast(context, 'Type a name first');
      if (list.any((x) => x.name.toLowerCase() == v.toLowerCase())) return showToast(context, '$v already exists');
      repo.add(bookId, _kind, v);
      _draft.clear();
      showToast(context, '$v added');
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Categories'),
          Text(book?.name ?? '', style: context.text.bodySmall?.copyWith(color: c.muted)),
        ]),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
        PillSegment<CategoryKind>(
          expand: true,
          options: const [(CategoryKind.income, 'Income'), (CategoryKind.expense, 'Expense')],
          selected: _kind,
          onChanged: (k) => setState(() => _kind = k),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _draft,
              onSubmitted: (_) => add(),
              decoration: InputDecoration(
                labelText: 'New category name',
                hintText: _kind == CategoryKind.income ? 'New income category' : 'New expense category',
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(72, 52)), onPressed: add, child: const Text('Add')),
        ]),
        const SizedBox(height: 14),
        RowGroup(children: [
          for (final (i, cat) in list.indexed)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 4),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(alignment: Alignment.centerLeft, foregroundColor: context.scheme.onSurface),
                    onPressed: () => _rename(cat),
                    child: Text(cat.name),
                  ),
                ),
                IconButton(tooltip: 'Move up', onPressed: i == 0 ? null : () => repo.move(cat.id, -1), icon: const Icon(Icons.arrow_upward, size: 20)),
                IconButton(
                  tooltip: 'Move down',
                  onPressed: i == list.length - 1 ? null : () => repo.move(cat.id, 1),
                  icon: const Icon(Icons.arrow_downward, size: 20),
                ),
                IconButton(
                  tooltip: 'Archive category',
                  onPressed: () {
                    repo.setArchived(cat.id, true);
                    showToast(context, '${cat.name} archived');
                  },
                  icon: const Icon(Icons.archive_outlined, size: 20),
                ),
              ]),
            ),
        ]),
        const SizedBox(height: 8),
        Text('Tap a name to rename it. Archived categories keep their past entries.', style: context.text.bodySmall?.copyWith(color: c.muted)),
        if (archived.isNotEmpty) ...[
          const SizedBox(height: 18),
          const SectionLabel('Archived'),
          RowGroup(children: [
            for (final cat in archived)
              ListRow(
                title: cat.name,
                trailing: TextButton(
                  onPressed: () {
                    repo.setArchived(cat.id, false);
                    showToast(context, '${cat.name} restored');
                  },
                  child: const Text('Restore'),
                ),
              ),
          ]),
        ],
      ]),
    );
  }

  void _rename(Category cat) {
    final ctrl = TextEditingController(text: cat.name);
    showAppSheet<void>(
      context,
      title: 'Rename category',
      builder: (sheet) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            final v = ctrl.text.trim();
            if (v.isEmpty) return showToast(context, 'Name can’t be empty');
            ref.read(categoryRepositoryProvider.notifier).rename(cat.id, v);
            Navigator.pop(sheet);
            showToast(context, 'Renamed to $v');
          },
          child: const Text('Save'),
        ),
      ]),
    );
  }
}
