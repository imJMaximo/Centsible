import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/feedback.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_view_model.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  Timer? _timer;
  int _left = 0;
  int _sends = 0;
  bool _editing = false;
  final _draft = TextEditingController();

  @override
  void dispose() {
    _timer?.cancel();
    _draft.dispose();
    super.dispose();
  }

  /// 60 s cooldown, backing off to 5 minutes after three sends (per the plan).
  void _startCooldown() {
    setState(() {
      _sends++;
      _left = _sends > 3 ? 300 : 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _left = (_left - 1).clamp(0, 999));
      if (_left == 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    if (_left > 0) return showToast(context, 'You can resend in $_left seconds');
    await ref.read(authViewModelProvider.notifier).resend();
    _startCooldown();
    if (mounted) showToast(context, 'Verification email sent');
  }

  void _saveEmail() {
    final v = _draft.text.trim().toLowerCase();
    if (!looksLikeEmail(v)) return showToast(context, 'Enter a valid email address');
    ref.read(authViewModelProvider.notifier).changeEmail(v);
    setState(() => _editing = false);
    _startCooldown();
    showToast(context, 'Link sent to $v');
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(currentUserProvider).email;
    final busy = ref.watch(authViewModelProvider);
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const BrandMark(size: 32),
        actions: [
          TextButton(onPressed: () => ref.read(authViewModelProvider.notifier).signOut(), child: const Text('Sign out')),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: c.selectedBg, borderRadius: BorderRadius.circular(32)),
              child: Icon(Icons.mail_outline, size: 46, color: context.scheme.primary),
            ),
          ),
          const SizedBox(height: 20),
          Text('Check your inbox', style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text('We sent a verification link to', style: context.text.bodyLarge?.copyWith(color: c.muted)),
          const SizedBox(height: 10),
          if (!_editing)
            SectionCard(
              padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
              border: Border.all(color: context.scheme.outlineVariant),
              child: Row(children: [
                Expanded(child: Text(email, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () => setState(() {
                    _editing = true;
                    _draft.text = email;
                  }),
                  child: const Text('Change email'),
                ),
              ]),
            )
          else
            SectionCard(
              border: Border.all(color: context.scheme.outlineVariant),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(controller: _draft, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'New email address')),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Cancel')),
                  FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: _saveEmail, child: const Text('Save & resend')),
                ]),
              ]),
            ),
          const SizedBox(height: 10),
          Text('Open it on any device. Books, entries and invitations unlock once your email is verified.',
              style: context.text.bodyMedium?.copyWith(color: c.muted, height: 1.5)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : () => ref.read(authViewModelProvider.notifier).checkVerified(),
            child: Text(busy ? 'Checking…' : 'I’ve verified — continue'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _resend, child: Text(_left > 0 ? 'Resend in ${_left}s' : 'Resend email')),
          if (_sends > 0) ...[
            const SizedBox(height: 16),
            SectionCard(
              color: c.pendingBg,
              child: Row(children: [
                Icon(Icons.info_outline, size: 18, color: c.pending),
                const SizedBox(width: 10),
                Expanded(child: Text('Not seeing it? Check your spam or promotions folder.', style: TextStyle(color: c.pending))),
              ]),
            ),
          ],
          const SizedBox(height: 32),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: context.scheme.primary, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('Checking automatically every few seconds', style: context.text.bodySmall?.copyWith(color: c.muted)),
          ]),
        ],
      ),
    );
  }
}
