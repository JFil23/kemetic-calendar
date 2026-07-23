import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/share_repo.dart';
import 'package:mobile/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _guidanceFetchPath = '/functions/v1/fetch_maat_guidance_pending';

var _guidanceFetchCount = 0;
var _scheduledGuidanceRefreshCount = 0;

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

void _resetAppLinksChannels() {
  const messages = MethodChannel('com.llfbandit.app_links/messages');
  const events = MethodChannel('com.llfbandit.app_links/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(messages, null);
  messenger.setMockMethodCallHandler(events, null);
}

http.Response _mockResponse(http.BaseRequest request) {
  if (request.url.path.endsWith(_guidanceFetchPath)) {
    _guidanceFetchCount += 1;
    return http.Response(
      jsonEncode(<String, Object?>{'delivery': null}),
      200,
      headers: const {'content-type': 'application/json'},
      request: request,
    );
  }
  if (request.url.path.endsWith('/auth/v1/logout')) {
    return http.Response('', 204, request: request);
  }
  return http.Response(
    jsonEncode(<String, Object?>{}),
    200,
    headers: const {'content-type': 'application/json'},
    request: request,
  );
}

Future<void> _recoverSession(String userId) async {
  final expiresAt =
      DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/
      1000;
  await Supabase.instance.client.auth.recoverSession(
    jsonEncode(<String, Object?>{
      'access_token': 'test-access-token-$userId-$expiresAt',
      'expires_in': 31536000,
      'refresh_token': 'test-refresh-token-$userId',
      'token_type': 'bearer',
      'user': <String, Object?>{
        'id': userId,
        'app_metadata': <String, Object?>{
          'provider': 'email',
          'providers': <String>['email'],
        },
        'user_metadata': <String, Object?>{},
        'aud': 'authenticated',
        'email': '$userId@example.com',
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

GoRouter _router() {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Text('Calendar route')),
      ),
    ],
  );
}

Future<void> _pumpShell(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => app.buildGlobalFloatingMenuShellForTesting(
        router: router,
        child: child ?? const SizedBox.shrink(),
        onSignedInGuidanceRefreshTimerFired: () {
          _scheduledGuidanceRefreshCount += 1;
        },
      ),
    ),
  );
  await tester.pump();
  await _flushMockNetwork(tester);
  await tester.pump();
}

Future<void> _flushMockNetwork(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 8; i += 1) {
      await Future<void>.delayed(Duration.zero);
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _mockAppLinksChannels();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'anon-key-0123456789012345678901234567890123456789',
      httpClient: MockClient((request) async => _mockResponse(request)),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ShareRepo.debugDisableUnreadTrackingForTesting = true;
    app.resetGlobalFloatingMenuShellForTesting();
    _guidanceFetchCount = 0;
    _scheduledGuidanceRefreshCount = 0;
  });

  tearDown(() {
    ShareRepo.debugDisableUnreadTrackingForTesting = false;
    app.resetGlobalFloatingMenuShellForTesting();
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
    _resetAppLinksChannels();
  });

  testWidgets(
    'GLOBAL-SHELL-AUTH-TIMER-001 mounted authenticated shell performs one delayed guidance refresh',
    (tester) async {
      await tester.runAsync(
        () => _recoverSession('11111111-1111-4111-8111-111111111111'),
      );
      expect(
        Supabase.instance.client.auth.currentUser?.id,
        '11111111-1111-4111-8111-111111111111',
      );

      final router = _router();
      addTearDown(router.dispose);
      await _pumpShell(tester, router);

      expect(_guidanceFetchCount, 1);
      expect(_scheduledGuidanceRefreshCount, 0);
      await tester.pump(const Duration(milliseconds: 1999));
      expect(_scheduledGuidanceRefreshCount, 0);

      await tester.pump(const Duration(milliseconds: 1));
      await _flushMockNetwork(tester);
      await tester.pump();
      expect(_scheduledGuidanceRefreshCount, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'GLOBAL-SHELL-AUTH-TIMER-002 disposing authenticated shell cancels its delayed refresh and leaves no pending work',
    (tester) async {
      await tester.runAsync(
        () => _recoverSession('22222222-2222-4222-8222-222222222222'),
      );
      expect(
        Supabase.instance.client.auth.currentUser?.id,
        '22222222-2222-4222-8222-222222222222',
      );

      final router = _router();
      addTearDown(router.dispose);
      await _pumpShell(tester, router);
      expect(_guidanceFetchCount, 1);
      expect(_scheduledGuidanceRefreshCount, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(_scheduledGuidanceRefreshCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GLOBAL-SHELL-AUTH-TIMER-003 repeated auth then sign-out leaves no delayed refresh or shell-owned work',
    (tester) async {
      await tester.runAsync(
        () => _recoverSession('33333333-3333-4333-8333-333333333333'),
      );
      final router = _router();
      addTearDown(router.dispose);
      await _pumpShell(tester, router);
      expect(_guidanceFetchCount, 1);

      await tester.runAsync(
        () => _recoverSession('44444444-4444-4444-8444-444444444444'),
      );
      await tester.pump();
      await _flushMockNetwork(tester);
      await tester.pump();
      expect(
        Supabase.instance.client.auth.currentUser?.id,
        '44444444-4444-4444-8444-444444444444',
      );
      expect(_guidanceFetchCount, greaterThanOrEqualTo(1));

      await tester.runAsync(
        () => Supabase.instance.client.auth.signOut(scope: SignOutScope.local),
      );
      await tester.pump();
      expect(Supabase.instance.client.auth.currentSession, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(_scheduledGuidanceRefreshCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
