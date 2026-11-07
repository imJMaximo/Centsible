import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_seed.dart';
import '../models/user.dart';

enum AuthStatus { signedOut, unverified, needsOnboarding, ready }

class AuthState {
  const AuthState({required this.status, this.user});
  final AuthStatus status;
  final AppUser? user;
}

/// Mock of the Firebase Auth-backed repository. Swap the bodies for
/// firebase_auth / google_sign_in calls; the ViewModels stay the same.
class AuthRepository extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState(status: AuthStatus.signedOut);

  AppUser get _user => state.user ?? MockSeed.me;

  Future<void> _latency() => Future<void>.delayed(const Duration(milliseconds: 450));

  /// Google returns a verified email, so there's no verification gate.
  Future<void> signInWithGoogle({bool isNewAccount = false}) async {
    await _latency();
    state = AuthState(status: isNewAccount ? AuthStatus.needsOnboarding : AuthStatus.ready, user: MockSeed.me);
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _latency();
    state = AuthState(status: AuthStatus.ready, user: MockSeed.me.copyWith(hasPassword: true));
  }

  Future<void> signUpWithEmail(String email, String password) async {
    await _latency();
    state = AuthState(
      status: AuthStatus.unverified,
      user: MockSeed.me.copyWith(email: email.trim().toLowerCase(), emailVerified: false, googleLinked: false, hasPassword: true),
    );
  }

  Future<void> sendPasswordReset(String email) => _latency();

  Future<void> resendVerification() => _latency();

  void changeUnverifiedEmail(String email) =>
      state = AuthState(status: state.status, user: _user.copyWith(email: email.trim().toLowerCase()));

  /// Mock "reload user": treat the link as opened.
  Future<void> refreshVerification() async {
    await _latency();
    state = AuthState(status: AuthStatus.needsOnboarding, user: _user.copyWith(emailVerified: true));
  }

  void completeOnboarding() => state = AuthState(status: AuthStatus.ready, user: _user);

  void signOut() => state = const AuthState(status: AuthStatus.signedOut);

  // ── Account settings ──
  void updateName(String name) => state = AuthState(status: state.status, user: _user.copyWith(name: name));
  void requestEmailChange(String email) =>
      state = AuthState(status: state.status, user: _user.copyWith(pendingEmail: email));
  void setPassword() => state = AuthState(status: state.status, user: _user.copyWith(hasPassword: true));
  void setDefaultCurrency(String code) =>
      state = AuthState(status: state.status, user: _user.copyWith(defaultCurrency: code));
}

final authRepositoryProvider = NotifierProvider<AuthRepository, AuthState>(AuthRepository.new);

final currentUserProvider = Provider<AppUser>((ref) => ref.watch(authRepositoryProvider).user ?? MockSeed.me);

/// The mock clock. The real app would use DateTime.now().
final todayProvider = Provider<DateTime>((_) => MockSeed.today);
