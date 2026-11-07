import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_seed.dart';
import '../models/book.dart';

class BooksState {
  const BooksState({required this.books, required this.members, required this.invitations, required this.mainBookId});

  final List<Book> books;
  final Map<String, List<BookMember>> members;
  final Map<String, List<Invitation>> invitations;

  /// Per-user main book (book_members.is_main for the current user).
  final String mainBookId;

  List<Book> get active => books.where((b) => !b.archived).toList();
  Book? byId(String id) => books.where((b) => b.id == id).firstOrNull;

  MemberRole roleOf(String bookId, String userId) =>
      (members[bookId] ?? const []).where((m) => m.userId == userId).firstOrNull?.role ?? MemberRole.viewer;

  BooksState copyWith({
    List<Book>? books,
    Map<String, List<BookMember>>? members,
    Map<String, List<Invitation>>? invitations,
    String? mainBookId,
  }) =>
      BooksState(
        books: books ?? this.books,
        members: members ?? this.members,
        invitations: invitations ?? this.invitations,
        mainBookId: mainBookId ?? this.mainBookId,
      );
}

/// In-memory stand-in for the Drift tables books / book_members / book_invitations.
class BookRepository extends Notifier<BooksState> {
  var _seq = 0;

  @override
  BooksState build() => BooksState(
        books: MockSeed.books,
        members: {for (final e in MockSeed.members.entries) e.key: List.of(e.value)},
        invitations: {for (final e in MockSeed.invitations.entries) e.key: List.of(e.value)},
        mainBookId: MockSeed.household,
      );

  String createBook(String name, String currency, {required String ownerName, required String ownerEmail}) {
    final id = 'book-${++_seq}';
    state = state.copyWith(
      books: [...state.books, Book(id: id, name: name, defaultCurrency: currency, colorIndex: state.books.length % 4)],
      members: {
        ...state.members,
        id: [BookMember(userId: MockSeed.meId, name: '$ownerName (you)', email: ownerEmail, role: MemberRole.owner)],
      },
      invitations: {...state.invitations, id: []},
    );
    return id;
  }

  void setMain(String bookId) => state = state.copyWith(mainBookId: bookId);

  void archive(String bookId) => state = state.copyWith(
        books: [for (final b in state.books) b.id == bookId ? b.copyWith(archived: true) : b],
      );

  void leave(String bookId) => state = state.copyWith(
        books: state.books.where((b) => b.id != bookId).toList(),
        members: {...state.members}..remove(bookId),
      );

  void _setMembers(String bookId, List<BookMember> list) =>
      state = state.copyWith(members: {...state.members, bookId: list});

  void setRole(String bookId, String userId, MemberRole role) => _setMembers(bookId, [
        for (final m in state.members[bookId] ?? <BookMember>[]) m.userId == userId ? m.copyWith(role: role) : m,
      ]);

  void removeMember(String bookId, String userId) =>
      _setMembers(bookId, (state.members[bookId] ?? []).where((m) => m.userId != userId).toList());

  void transferOwnership(String bookId, String toUserId) => _setMembers(bookId, [
        for (final m in state.members[bookId] ?? <BookMember>[])
          m.userId == toUserId
              ? m.copyWith(role: MemberRole.owner)
              : m.userId == MockSeed.meId
                  ? m.copyWith(role: MemberRole.editor)
                  : m,
      ]);

  /// Returns false when that email already has a live invite (it's updated instead).
  bool invite(String bookId, String email, MemberRole role, DateTime today) {
    final list = List.of(state.invitations[bookId] ?? <Invitation>[]);
    final i = list.indexWhere((x) => x.email == email);
    final inv = Invitation(email: email, role: role, expiresAt: today.add(const Duration(days: 14)));
    if (i >= 0) {
      list[i] = inv;
    } else {
      list.add(inv);
    }
    state = state.copyWith(invitations: {...state.invitations, bookId: list});
    return i < 0;
  }

  void revokeInvite(String bookId, String email) => state = state.copyWith(invitations: {
        ...state.invitations,
        bookId: (state.invitations[bookId] ?? []).where((x) => x.email != email).toList(),
      });
}

final bookRepositoryProvider = NotifierProvider<BookRepository, BooksState>(BookRepository.new);

/// The book the user is currently viewing; defaults to their main book.
class ActiveBook extends Notifier<String> {
  @override
  String build() => ref.read(bookRepositoryProvider).mainBookId;

  void select(String id) => state = id;
}

final activeBookIdProvider = NotifierProvider<ActiveBook, String>(ActiveBook.new);

final activeBookProvider = Provider<Book>((ref) {
  final books = ref.watch(bookRepositoryProvider);
  final id = ref.watch(activeBookIdProvider);
  return books.byId(id) ?? books.byId(books.mainBookId) ?? books.active.first;
});
