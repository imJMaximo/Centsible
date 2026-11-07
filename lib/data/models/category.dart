enum CategoryKind { income, expense }

class Category {
  const Category({
    required this.id,
    required this.bookId,
    required this.kind,
    required this.name,
    required this.sortOrder,
    this.archived = false,
  });

  final String id;
  final String bookId;
  final CategoryKind kind;
  final String name;
  final int sortOrder;
  final bool archived;

  Category copyWith({String? name, int? sortOrder, bool? archived}) => Category(
        id: id,
        bookId: bookId,
        kind: kind,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
        archived: archived ?? this.archived,
      );
}

const kSeedIncome = ['Salary', 'Business', 'Investment', 'Freelance', 'Gift', 'Refund', 'Other'];
const kSeedExpense = [
  'Food', 'Transportation', 'Utilities', 'Rent', 'Groceries', 'Health',
  'Education', 'Shopping', 'Entertainment', 'Insurance', 'Debt Payment', 'Other',
];
