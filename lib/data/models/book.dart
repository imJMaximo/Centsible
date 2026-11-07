enum MemberRole {
  owner('Owner'),
  editor('Editor'),
  viewer('Viewer');

  const MemberRole(this.label);
  final String label;

  bool get canWrite => this != MemberRole.viewer;
}

class Book {
  const Book({
    required this.id,
    required this.name,
    required this.defaultCurrency,
    this.colorIndex = 0,
    this.archived = false,
  });

  final String id;
  final String name;
  final String defaultCurrency;
  final int colorIndex;
  final bool archived;

  Book copyWith({String? name, bool? archived}) => Book(
        id: id,
        name: name ?? this.name,
        defaultCurrency: defaultCurrency,
        colorIndex: colorIndex,
        archived: archived ?? this.archived,
      );
}

/// A row of book_members: who is in a book and with which role.
class BookMember {
  const BookMember({required this.userId, required this.name, required this.email, required this.role});

  final String userId;
  final String name;
  final String email;
  final MemberRole role;

  String get initials {
    final p = name.replaceAll('(you)', '').trim().split(' ');
    return (p.length > 1 ? p[0][0] + p[1][0] : p[0].substring(0, 1)).toUpperCase();
  }

  BookMember copyWith({MemberRole? role}) =>
      BookMember(userId: userId, name: name, email: email, role: role ?? this.role);
}

class Invitation {
  const Invitation({required this.email, required this.role, required this.expiresAt});

  final String email;
  final MemberRole role;
  final DateTime expiresAt;
}
