import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/glossy_text.dart';

const String emailConfirmationRequiredMessage =
    'Check your email to confirm your account, then sign in.';
const String passwordResetEmailSentMessage =
    'Check your email for a password reset link.';
const String passwordUpdatedMessage = 'Password updated.';

abstract class EmailAuthClient {
  Future<EmailAuthResult> createAccount({
    required String email,
    required String password,
  });

  Future<EmailAuthResult> signIn({
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> updatePassword({required String password});
}

class EmailAuthResult {
  const EmailAuthResult({required this.hasSession});

  final bool hasSession;
}

class SupabaseEmailAuthClient implements EmailAuthClient {
  const SupabaseEmailAuthClient();

  static const Duration _requestTimeout = Duration(seconds: 30);

  @override
  Future<EmailAuthResult> createAccount({
    required String email,
    required String password,
  }) async {
    final response = await Supabase.instance.client.auth
        .signUp(
          email: email,
          password: password,
          emailRedirectTo: _authRedirectTo(),
        )
        .timeout(_requestTimeout);
    return EmailAuthResult(hasSession: response.session != null);
  }

  @override
  Future<EmailAuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final response = await Supabase.instance.client.auth
        .signInWithPassword(email: email, password: password)
        .timeout(_requestTimeout);
    return EmailAuthResult(hasSession: response.session != null);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    await Supabase.instance.client.auth
        .resetPasswordForEmail(email, redirectTo: _authRedirectTo())
        .timeout(_requestTimeout);
  }

  @override
  Future<void> updatePassword({required String password}) async {
    await Supabase.instance.client.auth
        .updateUser(UserAttributes(password: password))
        .timeout(_requestTimeout);
  }
}

String _authRedirectTo() {
  if (kIsWeb) {
    return Uri.base
        .removeFragment()
        .replace(queryParameters: const {})
        .toString();
  }
  return 'kemet.app://login-callback';
}

@visibleForTesting
String emailAuthMessageForAuthException(
  AuthException error, {
  required bool creatingAccount,
}) {
  final code = error.code?.toLowerCase();
  final message = error.message.trim();
  final normalized = message.toLowerCase();

  if (code == 'email_not_confirmed' ||
      normalized.contains('email not confirmed') ||
      normalized.contains('email address not confirmed') ||
      normalized.contains('not confirmed')) {
    return 'Confirm your email address before signing in.';
  }

  if (code == 'invalid_credentials' ||
      normalized.contains('invalid login credentials') ||
      normalized.contains('invalid credentials')) {
    return 'Email or password is incorrect.';
  }

  if (code == 'user_already_exists' ||
      code == 'email_exists' ||
      normalized.contains('already registered') ||
      normalized.contains('already exists') ||
      normalized.contains('user already')) {
    return 'An account already exists for this email. Sign in instead.';
  }

  if (code == 'weak_password' ||
      (normalized.contains('password') &&
          (normalized.contains('weak') ||
              normalized.contains('short') ||
              normalized.contains('at least')))) {
    return 'Use a stronger password.';
  }

  if (normalized.contains('invalid email') ||
      normalized.contains('email address is invalid') ||
      (normalized.contains('email') && normalized.contains('valid'))) {
    return 'Enter a valid email address.';
  }

  if (message.isNotEmpty) {
    return message;
  }

  return creatingAccount
      ? 'Could not create the account. Try again.'
      : 'Sign-in failed. Try again.';
}

@visibleForTesting
String emailAuthMessageForUnexpectedError(Object error) {
  if (_looksLikeNetworkError(error)) {
    return 'Network error. Check your connection and try again.';
  }
  return 'Sign-in failed. Try again.';
}

@visibleForTesting
String passwordResetMessageForUnexpectedError(Object error) {
  if (_looksLikeNetworkError(error)) {
    return 'Network error. Check your connection and try again.';
  }
  return 'Password reset failed. Try again.';
}

bool _looksLikeNetworkError(Object error) {
  if (error is TimeoutException) return true;
  final normalized = error.toString().toLowerCase();
  return normalized.contains('network') ||
      normalized.contains('clientexception') ||
      normalized.contains('socketexception') ||
      normalized.contains('failed host lookup') ||
      normalized.contains('connection refused') ||
      normalized.contains('connection closed') ||
      normalized.contains('timed out') ||
      normalized.contains('xmlhttprequest');
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onGoogleSignIn,
    EmailAuthClient? emailAuthClient,
  }) : emailAuthClient = emailAuthClient ?? const SupabaseEmailAuthClient();

  final Future<void> Function() onGoogleSignIn;
  final EmailAuthClient emailAuthClient;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _creatingAccount = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!_looksLikeEmail(email) || password.length < 8) {
      setState(() {
        _message = 'Enter a valid email and password (8+ characters).';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final creatingAccount = _creatingAccount;
      final response = creatingAccount
          ? await widget.emailAuthClient.createAccount(
              email: email,
              password: password,
            )
          : await widget.emailAuthClient.signIn(
              email: email,
              password: password,
            );

      if (!mounted) return;
      if (response.hasSession) {
        setState(() {
          _message = null;
          if (creatingAccount) {
            _creatingAccount = false;
          }
        });
        return;
      }
      if (creatingAccount) {
        setState(() {
          _message = emailConfirmationRequiredMessage;
          _creatingAccount = false;
        });
        return;
      }

      setState(() {
        _message =
            'Sign-in did not complete. Confirm your email, then try again.';
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      final creatingAccount = _creatingAccount;
      setState(() {
        _message = emailAuthMessageForAuthException(
          error,
          creatingAccount: creatingAccount,
        );
        if (creatingAccount &&
            _message ==
                'An account already exists for this email. Sign in instead.') {
          _creatingAccount = false;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = emailAuthMessageForUnexpectedError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  bool _looksLikeEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = _emailController.text.trim();
    if (!_looksLikeEmail(email)) {
      setState(() {
        _message = 'Enter your email address first.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      await widget.emailAuthClient.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() {
        _message = passwordResetEmailSentMessage;
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = emailAuthMessageForAuthException(
          error,
          creatingAccount: false,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = passwordResetMessageForUnexpectedError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _submitGoogleAuth() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      await widget.onGoogleSignIn();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final topPadding = ((constraints.maxHeight - 560) / 2).clamp(
              24.0,
              160.0,
            );

            return ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(24, topPadding, 24, 24),
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          KemeticGold.text(
                            'ḥꜣw',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Remember who you're becoming",
                            textAlign: TextAlign.center,
                            style: textTheme.titleMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 28),
                          TextField(
                            controller: _emailController,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            enabled: !_busy,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            autofillHints: _creatingAccount
                                ? const [AutofillHints.newPassword]
                                : const [AutofillHints.password],
                            decoration: const InputDecoration(
                              labelText: 'Password',
                            ),
                            onSubmitted: (_) {
                              if (!_busy) {
                                _submitEmailAuth();
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _busy ? null : _submitEmailAuth,
                              style: FilledButton.styleFrom(
                                backgroundColor: KemeticGold.base,
                                foregroundColor: Colors.black,
                              ),
                              child: Text(
                                _creatingAccount ? 'Create account' : 'Sign in',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () {
                                      setState(() {
                                        _creatingAccount = !_creatingAccount;
                                        _message = null;
                                      });
                                    },
                              child: KemeticGold.text(
                                _creatingAccount
                                    ? 'Already have an account? Sign in'
                                    : 'New here? Create an account',
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          if (!_creatingAccount)
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: _busy
                                    ? null
                                    : _sendPasswordResetEmail,
                                child: const Text('Forgot password?'),
                              ),
                            ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(child: Divider(color: Colors.white24)),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'or',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                ),
                                Expanded(child: Divider(color: Colors.white24)),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _submitGoogleAuth,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: KemeticGold.base,
                                side: BorderSide(
                                  color: KemeticGold.base.withValues(
                                    alpha: 0.65,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.login),
                              label: const Text('Continue with Google'),
                            ),
                          ),
                          if (_message != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _message!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({
    super.key,
    required this.onPasswordUpdated,
    required this.onCancel,
    EmailAuthClient? emailAuthClient,
  }) : emailAuthClient = emailAuthClient ?? const SupabaseEmailAuthClient();

  final Future<void> Function() onPasswordUpdated;
  final Future<void> Function() onCancel;
  final EmailAuthClient emailAuthClient;

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _busy = false;
  bool _passwordUpdated = false;
  String? _message;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    if (password.length < 8) {
      setState(() {
        _message = 'Enter a new password with at least 8 characters.';
      });
      return;
    }
    if (password != confirmPassword) {
      setState(() {
        _message = 'Passwords do not match.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      await widget.emailAuthClient.updatePassword(password: password);
      if (!mounted) return;
      setState(() {
        _passwordUpdated = true;
        _message = passwordUpdatedMessage;
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = emailAuthMessageForAuthException(
          error,
          creatingAccount: true,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = passwordResetMessageForUnexpectedError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _continueAfterUpdate() async {
    setState(() {
      _busy = true;
    });
    try {
      await widget.onPasswordUpdated();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final topPadding = ((constraints.maxHeight - 420) / 2).clamp(
              24.0,
              160.0,
            );

            return ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(24, topPadding, 24, 24),
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        KemeticGold.text(
                          'Set a new password',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Choose a new password for your account.',
                          textAlign: TextAlign.center,
                          style: textTheme.titleMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 28),
                        TextField(
                          controller: _passwordController,
                          enabled: !_busy && !_passwordUpdated,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: const InputDecoration(
                            labelText: 'New password',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmPasswordController,
                          enabled: !_busy && !_passwordUpdated,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: const InputDecoration(
                            labelText: 'Confirm password',
                          ),
                          onSubmitted: (_) {
                            if (!_busy && !_passwordUpdated) {
                              _updatePassword();
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _busy
                                ? null
                                : _passwordUpdated
                                ? _continueAfterUpdate
                                : _updatePassword,
                            style: FilledButton.styleFrom(
                              backgroundColor: KemeticGold.base,
                              foregroundColor: Colors.black,
                            ),
                            child: Text(
                              _passwordUpdated ? 'Continue' : 'Update password',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: _busy ? null : widget.onCancel,
                            child: KemeticGold.text(
                              'Back to sign in',
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _message!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
