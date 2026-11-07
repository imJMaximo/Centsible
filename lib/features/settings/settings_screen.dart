import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/feedback.dart';
import '../../data/mock/mock_seed.dart';
import '../../data/models/book.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/preferences_repository.dart';
import '../auth/auth_view_model.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final prefs = ref.watch(preferencesProvider);
    final books = ref.watch(bookRepositoryProvider);
    final c = context.colors;
    final mainName = books.byId(books.mainBookId)?.name ?? '—';

    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
          Text('Account', style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          SectionCard(
            child: Row(children: [
              Avatar(user.initials, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  Text(user.email, style: TextStyle(color: c.muted)),
                ]),
              ),
              TextButton(onPressed: () => _editName(context, ref, user.name), child: const Text('Edit')),
            ]),
          ),
          const SizedBox(height: 18),
          const SectionLabel('Books'),
          RowGroup(children: [
            ListRow(
              title: 'Books & members',
              subtitle: '${books.active.length} books · main: $mainName',
              onTap: () => context.push(Routes.books),
            ),
            ListRow(title: 'Categories', onTap: () => context.push(Routes.categories)),
            ListRow(title: 'Receivables & payables', onTap: () => context.push(Routes.accruals)),
          ]),
          const SizedBox(height: 18),
          const SectionLabel('Sign-in & security'),
          RowGroup(children: [
            ListRow(
              title: 'Google',
              subtitle: 'Linked sign-in',
              trailing: user.googleLinked
                  ? StatusPill('Connected', fg: c.selected, bg: c.incomeBg)
                  : TextButton(onPressed: () => showToast(context, 'Google linked'), child: const Text('Link')),
            ),
            ListRow(
              title: 'Email',
              subtitle: user.pendingEmail != null ? 'Waiting to confirm ${user.pendingEmail}' : 'Verified · used for invitations',
              trailing: TextButton(onPressed: () => _changeEmail(context, ref), child: const Text('Change')),
            ),
            ListRow(
              title: 'Password',
              subtitle: user.hasPassword ? 'Set · you can also sign in with email' : 'Not set — you sign in with Google',
              trailing: TextButton(
                onPressed: () => _password(context, ref, user.hasPassword),
                child: Text(user.hasPassword ? 'Change' : 'Set a password'),
              ),
            ),
            SwitchListTile(
              value: prefs.appLock,
              onChanged: (v) {
                ref.read(preferencesProvider.notifier).setAppLock(v);
                showToast(context, v ? 'App lock on — local data encrypted' : 'App lock off');
              },
              title: const Text('App lock', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('PIN or biometrics on open'),
            ),
          ]),
          const SizedBox(height: 18),
          const SectionLabel('Preferences'),
          RowGroup(children: [
            ListRow(
              title: 'Default currency',
              trailing: Text('${user.defaultCurrency} ›', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
              onTap: () => _currency(context, ref, user.defaultCurrency),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
                const Expanded(child: Text('Theme', style: TextStyle(fontWeight: FontWeight.w700))),
                PillSegment<ThemeMode>(
                  compact: true,
                  options: const [(ThemeMode.light, 'Light'), (ThemeMode.dark, 'Dark'), (ThemeMode.system, 'System')],
                  selected: prefs.themeMode,
                  onChanged: ref.read(preferencesProvider.notifier).setTheme,
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 18),
          const SectionLabel('Data'),
          RowGroup(children: [
            ListRow(
              title: 'Sync',
              subtitle: 'All changes saved · ${prefs.lastSync}',
              trailing: TextButton(
                onPressed: () {
                  ref.read(preferencesProvider.notifier).markSynced();
                  showToast(context, 'Synced · 0 pending changes');
                },
                child: const Text('Sync now'),
              ),
            ),
            ListRow(
              title: 'Export my data',
              subtitle: 'CSV or JSON, books you own',
              trailing: TextButton(onPressed: () => _export(context, user.email), child: const Text('Export')),
            ),
          ]),
          const SizedBox(height: 22),
          OutlinedButton(onPressed: () => ref.read(authViewModelProvider.notifier).signOut(), child: const Text('Sign out')),
          const SizedBox(height: 6),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: c.expense),
            onPressed: () => _delete(context, ref, books),
            child: const Text('Delete account'),
          ),
        ]),
      ),
    );
  }

  void _editName(BuildContext context, WidgetRef ref, String current) {
    final ctrl = TextEditingController(text: current);
    showAppSheet<void>(
      context,
      title: 'Edit profile',
      builder: (sheet) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Display name', helperText: 'Shown on entries you add')),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            final v = ctrl.text.trim();
            if (v.isEmpty) return showToast(context, 'Name can’t be empty');
            ref.read(authRepositoryProvider.notifier).updateName(v);
            Navigator.pop(sheet);
            showToast(context, 'Profile updated');
          },
          child: const Text('Save'),
        ),
      ]),
    );
  }

  void _changeEmail(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showAppSheet<void>(
      context,
      title: 'Change email',
      subtitle: 'We’ll send a link to the new address. Your current email keeps working until you confirm.',
      builder: (sheet) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: ctrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'New email')),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            final v = ctrl.text.trim().toLowerCase();
            if (!looksLikeEmail(v)) return showToast(context, 'Enter a valid email address');
            ref.read(authRepositoryProvider.notifier).requestEmailChange(v);
            Navigator.pop(sheet);
            showToast(context, 'Verification link sent to $v');
          },
          child: const Text('Send verification link'),
        ),
      ]),
    );
  }

  void _password(BuildContext context, WidgetRef ref, bool hasPw) {
    final a = TextEditingController(), b = TextEditingController();
    showAppSheet<void>(
      context,
      title: hasPw ? 'Change password' : 'Set a password',
      builder: (sheet) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: a, obscureText: true, decoration: const InputDecoration(labelText: 'New password', hintText: '8+ characters, a letter and a digit')),
        const SizedBox(height: 10),
        TextField(controller: b, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm password')),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            if (!passwordRule.hasMatch(a.text)) return showToast(context, 'Use 8+ characters with a letter and a digit');
            if (a.text != b.text) return showToast(context, 'Passwords don’t match');
            ref.read(authRepositoryProvider.notifier).setPassword();
            Navigator.pop(sheet);
            showToast(context, 'Password saved — you can sign in either way');
          },
          child: const Text('Save password'),
        ),
      ]),
    );
  }

  void _currency(BuildContext context, WidgetRef ref, String current) {
    showAppSheet<void>(
      context,
      title: 'Default currency',
      builder: (sheet) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3.2,
        children: [
          for (final cur in kCurrencies.values)
            SelectChip(
              tall: true,
              label: '${cur.symbol} ${cur.code}',
              selected: cur.code == current,
              onTap: () {
                ref.read(authRepositoryProvider.notifier).setDefaultCurrency(cur.code);
                Navigator.pop(sheet);
                showToast(context, 'New books and entries default to ${cur.code}');
              },
            ),
        ],
      ),
    );
  }

  void _export(BuildContext context, String email) {
    var fmt = 'CSV';
    showAppSheet<void>(
      context,
      title: 'Export your data',
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ChipWrap(children: [
            for (final f in ['CSV', 'JSON']) SelectChip(tall: true, label: f, selected: fmt == f, onTap: () => set(() => fmt = f)),
          ]),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              Navigator.pop(sheet);
              showToast(context, 'Preparing $fmt export — we’ll email it to $email');
            },
            child: const Text('Export'),
          ),
        ]),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, BooksState books) async {
    final owned = books.active.where((b) => books.roleOf(b.id, MockSeed.meId) == MemberRole.owner).toList();
    final lines = owned.map((b) {
      final heir = (books.members[b.id] ?? []).where((m) => m.userId != MockSeed.meId).firstOrNull;
      return heir == null ? '${b.name} will be deleted' : '${b.name} will pass to ${heir.name}';
    }).join('; ');
    final ok = await confirmAction(
      context,
      title: 'Delete your account?',
      body: 'You own ${owned.length} book${owned.length == 1 ? '' : 's'}. $lines. This can’t be undone.',
      confirmLabel: 'Delete account',
    );
    if (ok) ref.read(authViewModelProvider.notifier).signOut();
  }
}
