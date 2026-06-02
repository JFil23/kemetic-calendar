import 'dart:async';
import 'dart:io';

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

    testWidgets('shows tappable Terms and Privacy links on signup', (
      tester,
    ) async {
      await _pumpLoginScreen(tester, auth: _FakeEmailAuthClient());
      await _switchToCreateAccount(tester);

      expect(find.text('Terms'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(
        find.text('By creating an account, you agree to the '),
        findsOneWidget,
      );
      expect(find.text(' and acknowledge the '), findsOneWidget);

      final termsButton = tester.widget<TextButton>(
        find.byKey(const ValueKey('signup_terms_link')),
      );
      final privacyButton = tester.widget<TextButton>(
        find.byKey(const ValueKey('signup_privacy_policy_link')),
      );
      expect(termsButton.onPressed, isNotNull);
      expect(privacyButton.onPressed, isNotNull);
    });

    testWidgets('sends password reset email from forgot password action', (
      tester,
    ) async {
      final auth = _FakeEmailAuthClient();

      await _pumpLoginScreen(tester, auth: auth);
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'person@example.com',
      );
      await tester.tap(find.text('Forgot password?'));
      await tester.pump();

      expect(auth.calls, [
        const _EmailAuthCall(
          kind: _EmailAuthCallKind.sendPasswordResetEmail,
          email: 'person@example.com',
        ),
      ]);
      expect(find.text(passwordResetEmailSentMessage), findsOneWidget);
    });

    testWidgets('shows readable password reset email failures', (tester) async {
      final auth = _FakeEmailAuthClient(
        passwordResetEmailError: TimeoutException('timed out'),
      );

      await _pumpLoginScreen(tester, auth: auth);
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'person@example.com',
      );
      await tester.tap(find.text('Forgot password?'));
      await tester.pump();

      expect(
        find.text('Network error. Check your connection and try again.'),
        findsOneWidget,
      );
      final forgotPasswordButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Forgot password?'),
      );
      expect(forgotPasswordButton.onPressed, isNotNull);
    });

    testWidgets('requires email before sending a password reset email', (
      tester,
    ) async {
      final auth = _FakeEmailAuthClient();

      await _pumpLoginScreen(tester, auth: auth);
      await tester.tap(find.text('Forgot password?'));
      await tester.pump();

      expect(auth.calls, isEmpty);
      expect(find.text('Enter your email address first.'), findsOneWidget);
    });
  });

  group('PasswordRecoveryScreen', () {
    testWidgets('updates password and continues into the app', (tester) async {
      var continued = false;
      final auth = _FakeEmailAuthClient();

      await _pumpPasswordRecoveryScreen(
        tester,
        auth: auth,
        onPasswordUpdated: () async {
          continued = true;
        },
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'New password'),
        'newpassword123',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm password'),
        'newpassword123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Update password'));
      await tester.pump();

      expect(auth.calls, [
        const _EmailAuthCall(
          kind: _EmailAuthCallKind.updatePassword,
          password: 'newpassword123',
        ),
      ]);
      expect(find.text(passwordUpdatedMessage), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Continue'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pump();

      expect(continued, isTrue);
    });

    testWidgets('shows readable update password failures', (tester) async {
      final auth = _FakeEmailAuthClient(
        updatePasswordError: const AuthException(
          'Password should be at least 12 characters',
          code: 'weak_password',
        ),
      );

      await _pumpPasswordRecoveryScreen(tester, auth: auth);
      await tester.enterText(
        find.widgetWithText(TextField, 'New password'),
        'newpassword123',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm password'),
        'newpassword123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Update password'));
      await tester.pump();

      expect(find.text('Use a stronger password.'), findsOneWidget);
      final updateButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Update password'),
      );
      expect(updateButton.onPressed, isNotNull);
    });

    testWidgets('validates matching passwords before updating', (tester) async {
      final auth = _FakeEmailAuthClient();

      await _pumpPasswordRecoveryScreen(tester, auth: auth);
      await tester.enterText(
        find.widgetWithText(TextField, 'New password'),
        'newpassword123',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm password'),
        'different123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Update password'));
      await tester.pump();

      expect(auth.calls, isEmpty);
      expect(find.text('Passwords do not match.'), findsOneWidget);
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

  group('auth redirect guard', () {
    test('recovery and OAuth use the registered native callback', () async {
      final loginSource = await File(
        'lib/features/auth/login_screen.dart',
      ).readAsString();
      final mainSource = await File('lib/main.dart').readAsString();
      final androidManifest = await File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsString();
      final iosInfoPlist = await File('ios/Runner/Info.plist').readAsString();

      expect(loginSource, contains('resetPasswordForEmail('));
      expect(loginSource, contains('redirectTo: authRedirectTo()'));
      expect(
        loginSource,
        contains("nativeAuthRedirectUrl = 'kemet.app://login-callback'"),
      );
      expect(mainSource, contains('authRedirectTo()'));
      expect(androidManifest, contains('android:scheme="kemet.app"'));
      expect(androidManifest, contains('android:host="login-callback"'));
      expect(iosInfoPlist, contains('<string>kemet.app</string>'));
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

Future<void> _pumpPasswordRecoveryScreen(
  WidgetTester tester, {
  required EmailAuthClient auth,
  Future<void> Function()? onPasswordUpdated,
  Future<void> Function()? onCancel,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: PasswordRecoveryScreen(
        emailAuthClient: auth,
        onPasswordUpdated: onPasswordUpdated ?? () async {},
        onCancel: onCancel ?? () async {},
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
    this.passwordResetEmailError,
    this.updatePasswordError,
  });

  final EmailAuthResult createAccountResult;
  final EmailAuthResult signInResult;
  final Object? signInError;
  final Object? passwordResetEmailError;
  final Object? updatePasswordError;
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

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    calls.add(
      _EmailAuthCall(
        kind: _EmailAuthCallKind.sendPasswordResetEmail,
        email: email,
      ),
    );
    final error = passwordResetEmailError;
    if (error != null) throw error;
  }

  @override
  Future<void> updatePassword({required String password}) async {
    calls.add(
      _EmailAuthCall(
        kind: _EmailAuthCallKind.updatePassword,
        password: password,
      ),
    );
    final error = updatePasswordError;
    if (error != null) throw error;
  }
}

enum _EmailAuthCallKind {
  createAccount,
  signIn,
  sendPasswordResetEmail,
  updatePassword,
}

class _EmailAuthCall {
  const _EmailAuthCall({required this.kind, this.email, this.password});

  final _EmailAuthCallKind kind;
  final String? email;
  final String? password;

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
