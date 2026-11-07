import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/feedback.dart';
import 'auth_view_model.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _showPw = false;
  bool _terms = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  AuthViewModel get _vm => ref.read(authViewModelProvider.notifier);

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!looksLikeEmail(email)) return showToast(context, 'Enter a valid email address');
    if (_signUp) {
      if (!passwordRule.hasMatch(_password.text)) return showToast(context, 'Use 8+ characters with a letter and a digit');
      if (!_terms) return showToast(context, 'Please accept the Terms first');
      await _vm.signUp(email, _password.text);
    } else {
      if (_password.text.isEmpty) return showToast(context, 'Enter your password');
      await _vm.signIn(email, _password.text);
    }
  }

  Future<void> _google() async {
    if (_signUp && !_terms) return showToast(context, 'Please accept the Terms first');
    await _vm.google(signUp: _signUp);
  }

  void _forgot() {
    final ctrl = TextEditingController(text: _email.text);
    showAppSheet<void>(
      context,
      title: 'Reset your password',
      subtitle: 'We’ll email you a link to set a new password.',
      builder: (sheet) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: ctrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () async {
            if (!looksLikeEmail(ctrl.text)) return showToast(context, 'Enter a valid email address');
            Navigator.pop(sheet);
            await _vm.resetPassword(ctrl.text);
            if (mounted) showToast(context, 'Reset link sent — check your inbox');
          },
          child: const Text('Send reset link'),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authViewModelProvider);
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          children: [
            const Align(alignment: Alignment.centerLeft, child: BrandMark()),
            const SizedBox(height: 22),
            const _HeroCard(),
            const SizedBox(height: 22),
            Text(_signUp ? 'Start a book. Keep the change.' : 'Make cents of every peso.',
                style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6)),
            const SizedBox(height: 6),
            Text('Shared books, receivables and payables — even offline.',
                style: context.text.bodyMedium?.copyWith(color: c.muted)),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: busy ? null : _google,
              icon: const _GoogleGlyph(),
              label: Text(_signUp ? 'Sign up with Google' : 'Continue with Google'),
            ),
            const SizedBox(height: 18),
            Row(children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or with email', style: context.text.labelMedium?.copyWith(color: c.muted)),
              ),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 18),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email', hintText: 'you@example.com'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              obscureText: !_showPw,
              autofillHints: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: '8+ characters, a letter and a digit',
                suffixIcon: TextButton(
                  onPressed: () => setState(() => _showPw = !_showPw),
                  child: Text(_showPw ? 'Hide' : 'Show'),
                ),
              ),
            ),
            if (_signUp)
              CheckboxListTile(
                value: _terms,
                onChanged: (v) => setState(() => _terms = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('I agree to the Terms and Privacy Policy'),
              ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(_signUp ? 'Create account' : 'Sign in'),
            ),
            if (!_signUp) Center(child: TextButton(onPressed: _forgot, child: const Text('Forgot password?'))),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_signUp ? 'Already have an account?' : 'New to Centsible?', style: TextStyle(color: c.muted)),
              TextButton(
                onPressed: () => setState(() => _signUp = !_signUp),
                child: Text(_signUp ? 'Sign in' : 'Create an account'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 140,
      child: Stack(children: [
        Positioned(
          left: 18,
          top: 18,
          child: Transform.rotate(
            angle: -0.1,
            child: Container(
              width: 230,
              height: 108,
              decoration: BoxDecoration(color: c.selectedBg, borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
        Positioned(
          left: 70,
          top: 6,
          child: Container(
            width: 250,
            height: 118,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: context.scheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x1A10201B), blurRadius: 30, offset: Offset(0, 10))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('CASH · MTD', style: context.text.labelSmall?.copyWith(color: c.muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('₱91,819.50', style: figureStyle(28)),
              const SizedBox(height: 6),
              Row(children: [
                StatusPill('+ ₱62,000', fg: c.income, bg: c.incomeBg),
                const SizedBox(width: 6),
                StatusPill('− ₱18,430', fg: c.expense, bg: c.expenseBg),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: context.scheme.onSurface, width: 2)),
        child: Text('G', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: context.scheme.onSurface)),
      );
}
