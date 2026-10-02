import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'com.llfbandit.app_links/messages',
      'com.llfbandit.app_links/events',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  setUp(() async {
    await Supabase.instance.client.auth.recoverSession(_session('account-a'));
    SharedPreferences.setMockInitialValues({
      'calendar:warm_start:v1:account-a': jsonEncode({
        'userId': 'account-a',
        'flows': [],
        'notes': {
          '1-1-1': [
            {
              'id': 'private-event',
              'clientEventId': 'manual:private',
              'title': 'Private appointment',
              'detail': 'Reminder: bring insurance card',
              'allDay': true,
              'flowId': -1,
            },
          ],
        },
      }),
    });
    requests.clear();
  });

  Future<BuildContext> host(WidgetTester tester) async {
    late BuildContext result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            result = context;
            return const Scaffold(body: Text('Existing page'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets(
    'detached warm search rejects an account change during its load await',
    (tester) async {
      final context = await host(tester);
      // The uncached SharedPreferences instance yields while loading A's snapshot.
      var completed = false;
      unawaited(
        CalendarPage.openSearchFromAnyContext(
          context,
        ).then((_) => completed = true),
      );
      await Supabase.instance.client.auth.recoverSession(_session('account-b'));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Private appointment'), findsNothing);
      expect(requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final submitted in [false, true]) {
    testWidgets(
      'detached ${submitted ? 'results' : 'suggestions'} hide when the account changes and reject a stale tap',
      (tester) async {
        final context = await host(tester);
        unawaited(CalendarPage.openSearchFromAnyContext(context));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Private');
        if (submitted) {
          await tester.testTextInput.receiveAction(TextInputAction.search);
        }
        await tester.pumpAndSettle();
        expect(find.text('Private appointment'), findsOneWidget);
        final staleTap = tester.widget<ListTile>(find.byType(ListTile)).onTap!;
        await Supabase.instance.client.auth.recoverSession(
          _session('account-b'),
        );
        // Tap the previously visible row before the auth stream's next UI frame.
        staleTap();
        await tester.pumpAndSettle();
        expect(find.text('Private appointment'), findsNothing);
        expect(
          find.text('Account changed. Close search and try again.'),
          findsOneWidget,
        );
        expect(find.byType(TextField), findsOneWidget);
        expect(requests, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        await Supabase.instance.client.auth.recoverSession(
          _session('account-c'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Existing page'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'authored reminder metadata retains its existing search cleanup',
    (tester) async {
      final context = await host(tester);
      unawaited(CalendarPage.openSearchFromAnyContext(context));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'insurance card');
      await tester.pumpAndSettle();
      expect(find.text('No matches found'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Private');
      await tester.pumpAndSettle();
      expect(find.text('Private appointment'), findsOneWidget);
      expect(
        find.textContaining('insurance card', findRichText: true),
        findsNothing,
      );
      expect(requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

String _session(String account) {
  final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return jsonEncode({
    'access_token':
        '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': account, 'exp': exp})}.signature',
    'refresh_token': 'test',
    'token_type': 'bearer',
    'expires_at': exp,
    'expires_in': 3600,
    'user': {
      'id': account,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'fixture@example.com',
      'app_metadata': {},
      'user_metadata': {},
      'created_at': '2026-01-01T00:00:00Z',
    },
  });
}
