import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('LoginScreen email auth', () {
    testWidgets('creates an email account when Supabase returns a session', (
      tester,
    ) async {
      final auth = _FakeEmailAuthClient(
        createAccountResult: const EmailAuthResult(hasSession: true),
      );

      await _pumpLoginScreen(tester, auth: auth);
      await _switchToCreateAccount(tester);
      await _enterCredentials(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pump();

      expect(auth.calls, [
        const _EmailAuthCall(
          kind: _EmailAuthCallKind.createAccount,
          email: 'person@example.com',
          password: 'password123',
        ),
      ]);
      expect(find.text(emailConfirmationRequiredMessage), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    });

    testWidgets('shows confirmation guidance when signup returns no session', (
      tester,
    ) async {
      final auth = _FakeEmailAuthClient(
        createAccountResult: const EmailAuthResult(hasSession: false),
      );

      await _pumpLoginScreen(tester, auth: auth);
      await _switchToCreateAccount(tester);
      await _enterCredentials(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pump();

      expect(find.text(emailConfirmationRequiredMessage), findsOneWidget);
      final signInButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Sign in'),
      );
      expect(signInButton.onPressed, isNotNull);
    });

    testWidgets('signs in with email and password when credentials are valid', (
      tester,
    ) async {
      final auth = _FakeEmailAuthClient(
        signInResult: const EmailAuthResult(hasSession: true),
      );

      await _pumpLoginScreen(tester, auth: auth);
      await _enterCredentials(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();

      expect(auth.calls, [
        const _EmailAuthCall(
          kind: _EmailAuthCallKind.signIn,
          email: 'person@example.com',
          password: 'password123',
        ),
      ]);
      expect(find.text('Email or password is incorrect.'), findsNothing);
      expect(find.text(emailConfirmationRequiredMessage), findsNothing);
    });

    testWidgets('shows readable email/password login failures', (tester) async {
      final auth = _FakeEmailAuthClient(
        signInError: const AuthException(
          'Invalid login credentials',
          code: 'invalid_credentials',
        ),
      );

      await _pumpLoginScreen(tester, auth: auth);
      await _enterCredentials(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();

      expect(find.text('Email or password is incorrect.'), findsOneWidget);
      final signInButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Sign in'),
      );
      expect(signInButton.onPressed, isNotNull);
    });

    testWidgets('keeps Google sign-in visible and callable', (tester) async {
      var googleCalls = 0;
      await _pumpLoginScreen(
        tester,
        auth: _FakeEmailAuthClient(),
        onGoogleSignIn: () async {
          googleCalls += 1;
        },
      );

      expect(find.text('Continue with Google'), findsOneWidget);

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      expect(googleCalls, 1);
    });
  });

  group('email auth error messages', () {
    test('maps unconfirmed email errors', () {
      expect(
        emailAuthMessageForAuthException(
          const AuthException(
            'Email not confirmed',
            code: 'email_not_confirmed',
          ),
          creatingAccount: false,
        ),
        'Confirm your email address before signing in.',
      );
    });

    test('maps duplicate email errors', () {
      expect(
        emailAuthMessageForAuthException(
          const AuthException('User already registered'),
          creatingAccount: true,
        ),
        'An account already exists for this email. Sign in instead.',
      );
    });

    test('maps weak password errors', () {
      expect(
        emailAuthMessageForAuthException(
          const AuthException('Password should be at least 12 characters'),
          creatingAccount: true,
        ),
        'Use a stronger password.',
      );
    });

    test('maps invalid email errors', () {
      expect(
        emailAuthMessageForAuthException(
          const AuthException('Email address is invalid'),
          creatingAccount: true,
        ),
        'Enter a valid email address.',
      );
    });

    test('maps network failures', () {
      expect(
        emailAuthMessageForUnexpectedError(TimeoutException('timed out')),
        'Network error. Check your connection and try again.',
      );
    });
  });
}

Future<void> _pumpLoginScreen(
  WidgetTester tester, {
  required EmailAuthClient auth,
  Future<void> Function()? onGoogleSignIn,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: LoginScreen(
        emailAuthClient: auth,
        onGoogleSignIn: onGoogleSignIn ?? () async {},
      ),
    ),
  );
}

Future<void> _switchToCreateAccount(WidgetTester tester) async {
  await tester.tap(find.text('New here? Create an account'));
  await tester.pump();
}

Future<void> _enterCredentials(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Email'),
    'person@example.com',
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Password'),
    'password123',
  );
}

class _FakeEmailAuthClient implements EmailAuthClient {
  _FakeEmailAuthClient({
    this.createAccountResult = const EmailAuthResult(hasSession: true),
    this.signInResult = const EmailAuthResult(hasSession: true),
    this.signInError,
  });

  final EmailAuthResult createAccountResult;
  final EmailAuthResult signInResult;
  final Object? signInError;
  final List<_EmailAuthCall> calls = [];

  @override
  Future<EmailAuthResult> createAccount({
    required String email,
    required String password,
  }) async {
    calls.add(
      _EmailAuthCall(
        kind: _EmailAuthCallKind.createAccount,
        email: email,
        password: password,
      ),
    );
    return createAccountResult;
  }

  @override
  Future<EmailAuthResult> signIn({
    required String email,
    required String password,
  }) async {
    calls.add(
      _EmailAuthCall(
        kind: _EmailAuthCallKind.signIn,
        email: email,
        password: password,
      ),
    );
    final error = signInError;
    if (error != null) throw error;
    return signInResult;
  }
}

enum _EmailAuthCallKind { createAccount, signIn }

class _EmailAuthCall {
  const _EmailAuthCall({
    required this.kind,
    required this.email,
    required this.password,
  });

  final _EmailAuthCallKind kind;
  final String email;
  final String password;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _EmailAuthCall &&
            other.kind == kind &&
            other.email == email &&
            other.password == password;
  }

  @override
  int get hashCode => Object.hash(kind, email, password);
}
