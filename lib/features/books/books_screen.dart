import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/feedback.dart';
import '../../data/mock/mock_seed.dart';
import '../../data/models/book.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../auth/auth_view_model.dart';

class BooksScreen extends ConsumerStatefulWidget {
  const BooksScreen({super.key});

  @override
  ConsumerState<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends ConsumerState<BooksScreen> {
  late String _sel = ref.read(activeBookIdProvider);
  final _email = TextEditingController();
  MemberRole _inviteRole = MemberRole.editor;

  BookRepository get _repo => ref.read(bookRepositoryProvider.notifier);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(bookRepositoryProvider);
    final c = context.colors;
    final today = ref.watch(todayProvider);
    final book = s.byId(_sel) ?? s.byId(s.mainBookId)!;
    if (book.id != _sel) _sel = book.id;
    final members = s.members[book.id] ?? const <BookMember>[];
    final invites = s.invitations[book.id] ?? const <Invitation>[];
    final myRole = s.roleOf(book.id, MockSeed.meId);
    final isOwner = myRole == MemberRole.owner;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Books & members'),
        actions: [
          TextButton.icon(onPressed: _newBook, icon: const Icon(Icons.add), label: const Text('New book')),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
        for (final b in s.active) ...[
          _BookCard(
            book: b,
            selected: b.id == book.id,
            isMain: s.mainBookId == b.id,
            meta: _meta(s, b),
            onSelect: () => setState(() => _sel = b.id),
            onMakeMain: () {
              _repo.setMain(b.id);
              showToast(context, '${b.name} is now your main book');
            },
          ),
          const SizedBox(height: 10),
        ],
        Text('Main is your personal default. People you share with keep their own main book.',
            style: context.text.bodySmall?.copyWith(color: c.muted)),
        const SizedBox(height: 22),
        SectionLabel('${book.name} · members'),
        RowGroup(children: [
          for (final (i, m) in members.indexed)
            ListRow(
              leading: Avatar(m.initials, index: i),
              title: m.name,
              subtitle: m.email,
              trailing: _RoleChip(role: m.role, onTap: () => _editMember(book, m, myRole)),
            ),
        ]),
        if (invites.isNotEmpty) ...[
          const SizedBox(height: 14),
          const SectionLabel('Pending invitations'),
          RowGroup(children: [
            for (final inv in invites)
              ListRow(
                title: inv.email,
                subtitle: '${inv.role.label} · expires in ${inv.expiresAt.difference(today).inDays} days',
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (isOwner) ...[
                    TextButton(onPressed: () => showToast(context, 'Invitation re-sent to ${inv.email}'), child: const Text('Resend')),
                    TextButton(
                      onPressed: () {
                        _repo.revokeInvite(book.id, inv.email);
                        showToast(context, 'Invitation revoked');
                      },
                      child: Text('Revoke', style: TextStyle(color: c.expense)),
                    ),
                  ],
                ]),
              ),
          ]),
        ],
        const SizedBox(height: 14),
        if (isOwner)
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Invite by email', hintText: 'name@example.com'),
              ),
              const SizedBox(height: 10),
              Row(children: [
                PillSegment<MemberRole>(
                  options: const [(MemberRole.editor, 'Editor'), (MemberRole.viewer, 'Viewer')],
                  selected: _inviteRole,
                  onChanged: (r) => setState(() => _inviteRole = r),
                ),
                const Spacer(),
                FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => _invite(book, members), child: const Text('Send invite')),
              ]),
              const SizedBox(height: 10),
              Text('Everyone in a book sees every entry, note and attachment. Editors add and change entries; viewers can only look.',
                  style: context.text.bodySmall?.copyWith(color: c.muted, height: 1.45)),
            ]),
          )
        else
          SectionCard(
            color: c.surfaceMuted,
            child: Text('You’re ${myRole == MemberRole.editor ? 'an editor' : 'a viewer'} here. Only the owner can invite or remove people.'),
          ),
        const SizedBox(height: 14),
        if (isOwner) ...[
          OutlinedButton(onPressed: () => _transfer(book, members), child: const Text('Transfer ownership')),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: c.expense),
            onPressed: () => _archiveOrLeave(book, s.mainBookId, archive: true),
            child: const Text('Archive book'),
          ),
        ] else
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: c.expense),
            onPressed: () => _archiveOrLeave(book, s.mainBookId, archive: false),
            child: const Text('Leave this book'),
          ),
        const SizedBox(height: 14),
        RowGroup(children: [
          ListRow(title: 'Manage categories', subtitle: book.name, onTap: () => context.push('${Routes.categories}?book=${book.id}')),
        ]),
      ]),
    );
  }

  String _meta(BooksState s, Book b) {
    final n = s.members[b.id]?.length ?? 1;
    return '${s.roleOf(b.id, MockSeed.meId).label} · ${n > 1 ? '$n members' : 'only you'} · ${b.defaultCurrency}';
  }

  void _invite(Book book, List<BookMember> members) {
    final v = _email.text.trim().toLowerCase();
    if (!looksLikeEmail(v)) return showToast(context, 'Enter a valid email address');
    if (members.any((m) => m.email == v)) return showToast(context, '$v is already a member');
    final isNew = _repo.invite(book.id, v, _inviteRole, ref.read(todayProvider));
    _email.clear();
    showToast(context, isNew ? 'Invite sent to $v' : 'Updated invite to ${_inviteRole.label.toLowerCase()}');
  }

  void _editMember(Book book, BookMember m, MemberRole myRole) {
    if (myRole != MemberRole.owner) return showToast(context, 'Only the owner can change roles');
    if (m.role == MemberRole.owner) return showToast(context, 'To step down, use Transfer ownership');
    showAppSheet<void>(
      context,
      title: m.name,
      builder: (sheet) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final r in [MemberRole.editor, MemberRole.viewer]) ...[
          SelectChip(
            tall: true,
            label: r == MemberRole.editor ? 'Editor — can add and change entries' : 'Viewer — can only look',
            selected: m.role == r,
            onTap: () {
              _repo.setRole(book.id, m.userId, r);
              Navigator.pop(sheet);
              showToast(context, '${m.name} is now ${r.label.toLowerCase()}');
            },
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: context.colors.expense),
          onPressed: () {
            _repo.removeMember(book.id, m.userId);
            Navigator.pop(sheet);
            showToast(context, '${m.name} removed · their entries stay');
          },
          child: const Text('Remove from book · their entries stay'),
        ),
      ]),
    );
  }

  void _transfer(Book book, List<BookMember> members) {
    final others = members.where((m) => m.userId != MockSeed.meId).toList();
    showAppSheet<void>(
      context,
      title: 'Transfer ownership',
      subtitle: 'You’ll stay in the book as an editor.',
      builder: (sheet) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (others.isEmpty) const Text('Invite someone first — there’s nobody to hand this book to.'),
        for (final m in others) ...[
          OutlinedButton(
            onPressed: () {
              _repo.transferOwnership(book.id, m.userId);
              Navigator.pop(sheet);
              showToast(context, '${m.name} now owns ${book.name}');
            },
            child: Text('Make ${m.name} the owner'),
          ),
          const SizedBox(height: 8),
        ],
      ]),
    );
  }

  Future<void> _archiveOrLeave(Book book, String mainId, {required bool archive}) async {
    if (book.id == mainId) {
      return showToast(context, 'Set another main book before ${archive ? 'archiving' : 'leaving'} this one');
    }
    final ok = await confirmAction(
      context,
      title: '${archive ? 'Archive' : 'Leave'} ${book.name}?',
      body: archive
          ? 'It disappears for every member. You can restore it from Settings within 30 days.'
          : 'You lose access right away. Entries you added stay in the book.',
      confirmLabel: archive ? 'Archive' : 'Leave',
    );
    if (!ok || !mounted) return;
    archive ? _repo.archive(book.id) : _repo.leave(book.id);
    if (ref.read(activeBookIdProvider) == book.id) ref.read(activeBookIdProvider.notifier).select(mainId);
    setState(() => _sel = mainId);
    showToast(context, archive ? '${book.name} archived' : 'You left ${book.name}');
  }

  void _newBook() {
    final name = TextEditingController();
    var currency = ref.read(currentUserProvider).defaultCurrency;
    showAppSheet<void>(
      context,
      title: 'New book',
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Wedding fund')),
          const SizedBox(height: 14),
          ChipWrap(children: [
            for (final k in ['PHP', 'USD', 'EUR', 'JPY']) SelectChip(label: k, selected: currency == k, onTap: () => set(() => currency = k)),
          ]),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final n = name.text.trim();
              if (n.isEmpty) return showToast(context, 'Name the book first');
              final user = ref.read(currentUserProvider);
              final id = _repo.createBook(n, currency, ownerName: user.name.split(' ').first, ownerEmail: user.email);
              ref.read(categoryRepositoryProvider.notifier).seedFor(id);
              Navigator.pop(sheet);
              setState(() => _sel = id);
              showToast(context, '$n created');
            },
            child: const Text('Create book'),
          ),
        ]),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book, required this.selected, required this.isMain, required this.meta, required this.onSelect, required this.onMakeMain});
  final Book book;
  final bool selected, isMain;
  final String meta;
  final VoidCallback onSelect, onMakeMain;

  @override
  Widget build(BuildContext context) => Material(
        color: context.scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: selected ? context.scheme.primary : Colors.transparent, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(children: [
              BookTile(name: book.name, colorIndex: book.colorIndex),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(book.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(meta, style: context.text.bodySmall?.copyWith(color: context.colors.muted)),
                ]),
              ),
              if (isMain)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: StatusPill('MAIN', fg: Colors.white, bg: context.scheme.primary),
                )
              else
                TextButton(onPressed: onMakeMain, child: const Text('Set as main')),
            ]),
          ),
        ),
      );
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role, required this.onTap});
  final MemberRole role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (fg, bg) = switch (role) {
      MemberRole.owner => (Colors.white, const Color(0xFF0E3B32)),
      MemberRole.editor => (c.selected, c.incomeBg),
      MemberRole.viewer => (c.muted, c.surfaceMuted),
    };
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Text(role.label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ),
    );
  }
}
