import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _testUserId = 'bfe53d25-40f7-483d-8f2b-8020d1d8cf74';

void _mockAppLinksChannels() {
  const messages = MethodChannel('com.llfbandit.app_links/messages');
  const events = MethodChannel('com.llfbandit.app_links/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(messages, (_) async => null);
  messenger.setMockMethodCallHandler(events, (methodCall) async {
    if (methodCall.method == 'listen') {
      messenger.handlePlatformMessage(
        events.name,
        const StandardMethodCodec().encodeSuccessEnvelope(null),
        (_) {},
      );
    }
    return null;
  });
}

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {}

  await Supabase.initialize(
    url: 'https://example.supabase.co',
    anonKey: 'anon-key-0123456789012345678901234567890123456789',
  );
}

Future<void> _recoverTestSession() async {
  final expiresAt =
      DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/
      1000;
  await Supabase.instance.client.auth.recoverSession(
    jsonEncode(<String, Object?>{
      'access_token': 'launch-shell-test-access-token-$expiresAt',
      'expires_in': 31536000,
      'refresh_token': 'launch-shell-test-refresh-token',
      'token_type': 'bearer',
      'user': <String, Object?>{
        'id': _testUserId,
        'app_metadata': <String, Object?>{
          'provider': 'email',
          'providers': <String>['email'],
        },
        'user_metadata': <String, Object?>{},
        'aud': 'authenticated',
        'email': 'launch-shell-test@example.com',
        'phone': '',
        'created_at': '2026-01-01T00:00:00.000000Z',
        'email_confirmed_at': '2026-01-01T00:00:00.000000Z',
        'role': 'authenticated',
        'updated_at': '2026-01-01T00:00:00.000000Z',
      },
      'expiresAt': expiresAt,
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _mockAppLinksChannels();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _ensureSupabaseInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    app.resetLaunchShellForTesting();
    app.setLaunchShellDetachedOverlayRestoreSuppressedForTesting(true);
    await _recoverTestSession();
  });

  tearDown(app.resetLaunchShellForTesting);

  testWidgets(
    'returning authenticated users see ready route content without launch splash gating',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: app.buildLaunchShellForTesting(
            child: const Scaffold(
              backgroundColor: Colors.black,
              body: Text('Cached calendar ready'),
            ),
          ),
        ),
      );

      expect(find.text('Cached calendar ready'), findsOneWidget);
      expect(
        find.text('ḥꜣw'),
        findsNothing,
        reason:
            'The branded launch overlay must not cover authenticated route '
            'content that is already safe to paint.',
      );
    },
  );
}
