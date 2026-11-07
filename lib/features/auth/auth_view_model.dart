import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/wallet.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/wallet_repository.dart';

/// Orchestrates sign-in, verification and onboarding across repositories.
/// State = "an auth call is in flight".
class AuthViewModel extends Notifier<bool> {
  @override
  bool build() => false;

  AuthRepository get _auth => ref.read(authRepositoryProvider.notifier);

  Future<void> _run(Future<void> Function() f) async {
    state = true;
    try {
      await f();
    } finally {
      state = false;
    }
  }

  Future<void> google({required bool signUp}) => _run(() => _auth.signInWithGoogle(isNewAccount: signUp));
  Future<void> signIn(String email, String pw) => _run(() => _auth.signInWithEmail(email, pw));
  Future<void> signUp(String email, String pw) => _run(() => _auth.signUpWithEmail(email, pw));
  Future<void> resetPassword(String email) => _auth.sendPasswordReset(email);
  Future<void> resend() => _auth.resendVerification();
  void changeEmail(String email) => _auth.changeUnverifiedEmail(email);
  Future<void> checkVerified() => _run(_auth.refreshVerification);
  void signOut() => _auth.signOut();

  /// Creates the user's main book with seed categories and starter wallets.
  void finishOnboarding({required String bookName, required String currency, required Set<WalletType> starterWallets}) {
    final user = ref.read(currentUserProvider);
    final books = ref.read(bookRepositoryProvider.notifier);
    final id = books.createBook(bookName, currency, ownerName: user.name.split(' ').first, ownerEmail: user.email);
    books.setMain(id);
    ref.read(categoryRepositoryProvider.notifier).seedFor(id);
    final wallets = ref.read(walletRepositoryProvider.notifier);
    const names = {
      WalletType.cash: 'Cash on hand',
      WalletType.bank: 'Bank account',
      WalletType.ewallet: 'E-wallet',
      WalletType.card: 'Credit card',
    };
    for (final t in WalletType.values.where(starterWallets.contains)) {
      wallets.add(bookId: id, name: names[t]!, type: t, currency: currency);
    }
    ref.read(activeBookIdProvider.notifier).select(id);
    ref.read(authRepositoryProvider.notifier).completeOnboarding();
  }
}

final authViewModelProvider = NotifierProvider<AuthViewModel, bool>(AuthViewModel.new);

final passwordRule = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$');
bool looksLikeEmail(String v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
