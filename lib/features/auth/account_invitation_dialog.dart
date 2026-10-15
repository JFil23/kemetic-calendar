import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'login_screen.dart';

/// A dismissible housing for the existing account form and auth behavior.
class AccountInvitationDialog extends StatelessWidget {
  const AccountInvitationDialog({
    super.key,
    required this.onGoogleSignIn,
    required this.onDismiss,
    this.emailAuthClient,
  });

  final Future<void> Function() onGoogleSignIn;
  final VoidCallback onDismiss;
  final EmailAuthClient? emailAuthClient;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.black,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: Color(0xff63522b)),
    ),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      width: 460,
      height: math.min(700, MediaQuery.sizeOf(context).height - 32),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Keep exploring',
              onPressed: onDismiss,
              icon: const Icon(Icons.close, color: Color(0xffd4af37)),
            ),
          ),
          Expanded(
            child: LoginScreen(
              onGoogleSignIn: onGoogleSignIn,
              emailAuthClient: emailAuthClient,
              initiallyCreatingAccount: true,
            ),
          ),
          TextButton(
            onPressed: onDismiss,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xffd4af37),
            ),
            child: const Text('Keep exploring'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
