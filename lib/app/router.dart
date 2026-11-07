import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/auth_repository.dart';
import '../features/accruals/accruals_screen.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/auth/verify_email_screen.dart';
import '../features/books/books_screen.dart';
import '../features/books/categories_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/entries/entries_screen.dart';
import '../features/entries/entry_detail_screen.dart';
import '../features/entries/entry_form_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/wallets/card_detail_screen.dart';
import '../features/wallets/wallets_screen.dart';
import 'shell.dart';

abstract final class Routes {
  static const signIn = '/sign-in';
  static const verify = '/verify-email';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const entries = '/entries';
  static const newEntry = '/entries/new';
  static const wallets = '/wallets';
  static const account = '/account';
  static const accruals = '/accruals';
  static const books = '/books';
  static const categories = '/books/categories';
}

final routerProvider = Provider<GoRouter>((ref) {
  // Bridge auth changes into go_router's refreshListenable.
  final authTick = ValueNotifier<AuthStatus>(ref.read(authRepositoryProvider).status);
  ref.listen(authRepositoryProvider, (_, next) => authTick.value = next.status);
  ref.onDispose(authTick.dispose);

  return GoRouter(
    initialLocation: Routes.signIn,
    refreshListenable: authTick,
    redirect: (context, state) {
      final status = ref.read(authRepositoryProvider).status;
      final loc = state.matchedLocation;
      final target = switch (status) {
        AuthStatus.signedOut => Routes.signIn,
        AuthStatus.unverified => Routes.verify,
        AuthStatus.needsOnboarding => Routes.onboarding,
        AuthStatus.ready => null,
      };
      if (target != null) return loc == target ? null : target;
      // Signed in: keep people out of the auth flow.
      if (loc == Routes.signIn || loc == Routes.verify || loc == Routes.onboarding) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(path: Routes.verify, builder: (_, _) => const VerifyEmailScreen()),
      GoRoute(path: Routes.onboarding, builder: (_, _) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: Routes.home, builder: (_, _) => const DashboardScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.entries, builder: (_, _) => const EntriesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.wallets, builder: (_, _) => const WalletsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.account, builder: (_, _) => const SettingsScreen())]),
        ],
      ),
      GoRoute(
        path: Routes.newEntry,
        pageBuilder: (_, s) => MaterialPage(
          fullscreenDialog: true,
          child: EntryFormScreen(initialType: s.uri.queryParameters['type']),
        ),
      ),
      GoRoute(path: '/entries/:id', builder: (_, s) => EntryDetailScreen(entryId: s.pathParameters['id']!)),
      GoRoute(
        path: '/entries/:id/edit',
        pageBuilder: (_, s) => MaterialPage(fullscreenDialog: true, child: EntryFormScreen(editId: s.pathParameters['id'])),
      ),
      GoRoute(
        path: Routes.accruals,
        builder: (_, s) => AccrualsScreen(initialTab: s.uri.queryParameters['tab'] == 'pay' ? 1 : 0),
      ),
      GoRoute(path: '/wallets/:id', builder: (_, s) => CardDetailScreen(walletId: s.pathParameters['id']!)),
      GoRoute(path: Routes.books, builder: (_, _) => const BooksScreen()),
      GoRoute(path: Routes.categories, builder: (_, s) => CategoriesScreen(bookId: s.uri.queryParameters['book'])),
    ],
  );
});
