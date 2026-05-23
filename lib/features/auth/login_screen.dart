import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/glossy_text.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onGoogleSignIn});

  final Future<void> Function() onGoogleSignIn;

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
    if (email.isEmpty || !email.contains('@') || password.length < 8) {
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
      final auth = Supabase.instance.client.auth;
      final response = _creatingAccount
          ? await auth.signUp(email: email, password: password)
          : await auth.signInWithPassword(email: email, password: password);

      if (!mounted) return;
      if (response.session == null && _creatingAccount) {
        setState(() {
          _message = 'Account created. Sign in with this email and password.';
          _creatingAccount = false;
        });
        return;
      }
      if (response.session == null) {
        setState(() {
          _message = 'Sign-in failed. Check email and password.';
        });
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Sign-in failed. Try again.';
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
