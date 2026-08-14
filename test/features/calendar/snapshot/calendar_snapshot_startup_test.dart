import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/features/calendar/calendar_epoch_viewport.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/snapshot/calendar_snapshot_models.dart';
import 'package:mobile/features/calendar/snapshot/calendar_snapshot_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _userId = '451ec6cb-d4c1-438e-95e9-a6713849a67a';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'calendar_snapshot_startup_test.',
    );
    Hive.init(hiveDirectory.path);
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'test-anon-key',
      httpClient: _RejectingClient(),
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: false,
      ),
    );
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app:has_seen_onboarding': true,
      'app:onboarding:completed': true,
    });
    await Supabase.instance.client.auth.recoverSession(_sessionJson());
    await calendarSnapshotStore.deleteUserScope(_userId);
  });

  testWidgets(
    'shadow snapshot cannot delay or replace production startup authority',
    (tester) async {
      final today = KemeticMath.fromGregorian(DateTime.now());
      final dayKey = '${today.kYear}-${today.kMonth}-${today.kDay}';
      await tester.runAsync(() async {
        await calendarSnapshotStore.commit(
          CalendarSnapshotCommit(
            userScope: _userId,
            serverRevision: 'shadow-server-1',
            overlayRevision: 'shadow-overlay-1',
            catalogFingerprint: 'shadow-catalog-1',
            origin: 'shadow_startup_test',
            committedAtUtc: DateTime.now().toUtc(),
            lastSuccessfulRefreshAtUtc: DateTime.now().toUtc(),
            coverage: <CalendarSnapshotCoverageInterval>[
              CalendarSnapshotCoverageInterval(
                startUtc: DateTime.now().toUtc().subtract(
                  const Duration(days: 30),
                ),
                endUtc: DateTime.now().toUtc().add(const Duration(days: 30)),
              ),
            ],
            eventsByDay: <String, List<Map<String, Object?>>>{
              dayKey: <Map<String, Object?>>[
                _note('shadow-event', 'Unpromoted snapshot event'),
              ],
            },
            flows: const <Map<String, Object?>>[],
            calendarMetadata: const <String, Object?>{
              'personalCalendarId': null,
              'hiddenCalendarIds': <String>[],
              'calendars': <Object?>[],
            },
          ),
          requireGenerationMatch: true,
        );
      });

      final key = GlobalKey<CalendarPageState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CalendarPage(key: key)),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      for (var attempt = 0; attempt < 80; attempt++) {
        await tester.pump(const Duration(milliseconds: 25));
        if (find.byType(CalendarEpochScrollView).evaluate().isNotEmpty) break;
      }

      expect(find.byType(CalendarEpochScrollView), findsOneWidget);
      expect(
        key.currentState!
            .notesForDayForTesting(today.kYear, today.kMonth, today.kDay)
            .map((note) => note.clientEventId),
        isNot(contains('shadow-event')),
        reason: 'write-side shadow data is not a startup presentation owner',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    },
  );
}

Map<String, Object?> _note(String cid, String title) => <String, Object?>{
  'id': null,
  'clientEventId': cid,
  'calendarId': null,
  'calendarName': null,
  'title': title,
  'detail': null,
  'location': null,
  'allDay': true,
  'startMinutes': null,
  'endMinutes': null,
  'flowId': null,
  'manualColor': null,
  'resolvedColor': 0xFFE0B95A,
  'category': null,
  'isReminder': false,
  'reminderId': null,
  'alertOffsetMinutes': null,
  'actionId': null,
  'behaviorPayload': null,
};

String _sessionJson() {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final header = base64Url.encode(utf8.encode('{"alg":"none","typ":"JWT"}'));
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, Object?>{
        'sub': _userId,
        'email': 'snapshot-startup@example.com',
        'aud': 'authenticated',
        'role': 'authenticated',
        'iat': now,
        'exp': now + 3600,
      }),
    ),
  );
  return jsonEncode(<String, Object?>{
    'access_token': '$header.$payload.',
    'refresh_token': 'test-refresh-token',
    'expires_in': 3600,
    'expires_at': now + 3600,
    'token_type': 'bearer',
    'user': <String, Object?>{
      'id': _userId,
      'email': 'snapshot-startup@example.com',
      'aud': 'authenticated',
      'role': 'authenticated',
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'created_at': '2026-01-01T00:00:00.000Z',
    },
  });
}

final class _RejectingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(
        utf8.encode(jsonEncode(<String, Object?>{'message': 'offline'})),
      ),
      503,
      request: request,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }
}
