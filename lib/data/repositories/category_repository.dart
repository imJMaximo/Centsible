import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_seed.dart';
import '../models/category.dart';

class CategoryRepository extends Notifier<List<Category>> {
  var _seq = 0;

  @override
  List<Category> build() => MockSeed.categories();

  Category? byId(String? id) => id == null ? null : state.where((c) => c.id == id).firstOrNull;

  /// Active categories of one kind in a book, in display order.
  List<Category> forBook(String bookId, CategoryKind kind, {bool archived = false}) =>
      state.where((c) => c.bookId == bookId && c.kind == kind && c.archived == archived).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  void seedFor(String bookId) {
    state = [
      ...state,
      for (final (i, n) in kSeedIncome.indexed)
        Category(id: MockSeed.catId(bookId, CategoryKind.income, n), bookId: bookId, kind: CategoryKind.income, name: n, sortOrder: i),
      for (final (i, n) in kSeedExpense.indexed)
        Category(id: MockSeed.catId(bookId, CategoryKind.expense, n), bookId: bookId, kind: CategoryKind.expense, name: n, sortOrder: i),
    ];
  }

  void add(String bookId, CategoryKind kind, String name) {
    final max = forBook(bookId, kind).fold<int>(-1, (a, c) => c.sortOrder > a ? c.sortOrder : a);
    state = [...state, Category(id: 'cat-new-${++_seq}', bookId: bookId, kind: kind, name: name, sortOrder: max + 1)];
  }

  void _replace(Category c) => state = [for (final x in state) x.id == c.id ? c : x];

  void rename(String id, String name) => _replace(byId(id)!.copyWith(name: name));

  void setArchived(String id, bool archived) {
    final c = byId(id)!;
    final order = archived ? c.sortOrder : forBook(c.bookId, c.kind).length;
    _replace(c.copyWith(archived: archived, sortOrder: order));
  }

  /// Moves a category one slot up (-1) or down (+1).
  void move(String id, int delta) {
    final c = byId(id)!;
    final list = forBook(c.bookId, c.kind);
    final i = list.indexWhere((x) => x.id == id), j = i + delta;
    if (j < 0 || j >= list.length) return;
    list.insert(j, list.removeAt(i));
    final orders = {for (final (k, x) in list.indexed) x.id: k};
    state = [for (final x in state) orders.containsKey(x.id) ? x.copyWith(sortOrder: orders[x.id]) : x];
  }
}

final categoryRepositoryProvider = NotifierProvider<CategoryRepository, List<Category>>(CategoryRepository.new);
