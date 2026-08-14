import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/features/calendar/calendar_hydration_diagnostics.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/reminders/reminder_rule.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart' as picker;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'calendar_atomic_reminder_projection_test.',
    );
    Hive.init(hiveDirectory.path);
    const appLinksMessages = MethodChannel('com.llfbandit.app_links/messages');
    const appLinksEvents = MethodChannel('com.llfbandit.app_links/events');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(appLinksMessages, (_) async => null);
    messenger.setMockMethodCallHandler(appLinksEvents, (_) async {
      scheduleMicrotask(
        () =>
            messenger.handlePlatformMessage(appLinksEvents.name, null, (_) {}),
      );
      return null;
    });
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app:has_seen_onboarding': true,
      'app:onboarding:completed': true,
    });
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
    await hiveDirectory.delete(recursive: true);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app:has_seen_onboarding': true,
      'app:onboarding:completed': true,
    });
  });

  tearDown(() {
    CalendarPage.debugReminderSyncTodayForTesting = null;
    CalendarPage.debugReminderSyncWindowEndForTesting = null;
  });

  Future<CalendarPageState> pumpCalendar(WidgetTester tester) async {
    final key = GlobalKey<CalendarPageState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CalendarPage(key: key)),
      ),
    );
    await tester.pump();
    return key.currentState!;
  }

  Future<void> disposeCalendar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  }

  List<String> signature(CalendarPageState state, int ky, int km, int kd) {
    final values = state
        .notesForDayForTesting(ky, km, kd)
        .map(
          (note) =>
              '${note.clientEventId}|${note.title}|${note.isReminder}|${note.flowId}',
        )
        .toList();
    values.sort();
    return values;
  }

  testWidgets(
    'complete projection contains reminder and post-complete producers preserve membership',
    (tester) async {
      final day = DateTime(2026, 8, 11, 20);
      final kDay = picker.KemeticMath.fromGregorian(day);
      final rule = ReminderRule(
        id: 'atomic-reminder',
        title: 'Journal every day',
        startLocal: day,
        allDay: false,
        color: const Color(0xff8b6dd8),
      );
      CalendarPage.debugReminderSyncTodayForTesting = DateUtils.dateOnly(day);
      CalendarPage.debugReminderSyncWindowEndForTesting = DateUtils.dateOnly(
        day,
      );

      final state = await pumpCalendar(tester);
      state.debugAddNote(
        kDay.kYear,
        kDay.kMonth,
        kDay.kDay,
        'Existing event',
        null,
        clientEventId: 'existing-cid',
      );

      expect(
        state.debugProjectReminderMembershipForTesting(rule: rule, flowId: 77),
        1,
      );
      final afterComplete = signature(
        state,
        kDay.kYear,
        kDay.kMonth,
        kDay.kDay,
      );
      expect(
        afterComplete,
        contains(
          'reminder:atomic-reminder:2026-08-11|Journal every day|true|77',
        ),
      );

      expect(
        await state.debugRunPostCompleteReminderRegenForTesting(),
        isFalse,
      );
      expect(
        signature(state, kDay.kYear, kDay.kMonth, kDay.kDay),
        afterComplete,
      );

      expect(
        state.debugRunPostCompleteReminderSyncProjectionForTesting(
          rule: rule,
          flowId: 77,
        ),
        isFalse,
      );
      expect(
        signature(state, kDay.kYear, kDay.kMonth, kDay.kDay),
        afterComplete,
      );
      await disposeCalendar(tester);
    },
  );

  testWidgets(
    'disk warm restore projects reminder membership before its first publication',
    (tester) async {
      const userId = '27d63169-a28a-4550-a0a0-8fee0e8e7b95';
      final today = DateUtils.dateOnly(DateTime.now());
      final staleEnd = today.subtract(const Duration(days: 1));
      final start = today.subtract(const Duration(days: 30));
      final kDay = picker.KemeticMath.fromGregorian(today);
      final dayKey = '${kDay.kYear}-${kDay.kMonth}-${kDay.kDay}';

      Map<String, dynamic> rulePayload({
        required String id,
        required String title,
        required int hour,
        bool active = true,
        bool includeEnd = true,
        DateTime? endLocal,
      }) => <String, dynamic>{
        'id': id,
        'title': title,
        'startLocal': DateTime(
          start.year,
          start.month,
          start.day,
          hour,
        ).toIso8601String(),
        if (includeEnd) 'endLocal': endLocal?.toIso8601String(),
        'allDay': false,
        'color': const Color(0xff8b6dd8).toARGB32(),
        'active': active,
        'repeat': const ReminderRepeat(
          kind: ReminderRepeatKind.everyNDays,
          interval: 1,
        ).toJson(),
        'alertOffsetMinutes': -1,
      };

      Map<String, dynamic> flowPayload({
        required int id,
        required Map<String, dynamic> rule,
        DateTime? flowEnd,
        bool active = true,
        bool hidden = false,
      }) => <String, dynamic>{
        'id': id,
        'name': rule['title'],
        'color': const Color(0xff8b6dd8).toARGB32(),
        'active': active,
        'isSaved': false,
        'start': rule['startLocal'],
        'end': flowEnd?.toIso8601String(),
        'rules': const <Object?>[],
        'notes': jsonEncode(rule),
        'isHidden': hidden,
        'isReminder': true,
        'reminderUuid': rule['id'],
      };

      final journalRule = rulePayload(
        id: '11111111-1111-4111-8111-111111111111',
        title: 'journal every day',
        hour: 7,
      );
      final canonicalRule = rulePayload(
        id: '22222222-2222-4222-8222-222222222222',
        title: 'Canonical reminder',
        hour: 8,
      );
      final expiredRule = rulePayload(
        id: '33333333-3333-4333-8333-333333333333',
        title: 'Explicitly expired reminder',
        hour: 9,
        endLocal: staleEnd,
      );
      final legacyExpiredRule = rulePayload(
        id: '44444444-4444-4444-8444-444444444444',
        title: 'Legacy expired reminder',
        hour: 10,
        includeEnd: false,
      );
      final inactiveRule = rulePayload(
        id: '55555555-5555-4555-8555-555555555555',
        title: 'Inactive reminder',
        hour: 11,
      );
      final hiddenRule = rulePayload(
        id: '66666666-6666-4666-8666-666666666666',
        title: 'Hidden reminder',
        hour: 12,
      );
      final endedRule = rulePayload(
        id: '77777777-7777-4777-8777-777777777777',
        title: 'Ended reminder',
        hour: 13,
      );
      final canonicalCid = 'reminder:${canonicalRule['id']}:${_dateKey(today)}';

      SharedPreferences.setMockInitialValues(<String, Object>{
        'app:has_seen_onboarding': true,
        'app:onboarding:completed': true,
        'calendar:user_scoped_prefs_v1:$userId': true,
        'calendar:cid_migration_done:$userId': true,
        'reminder:ended_ids:$userId': <String>[endedRule['id'] as String],
        'calendar:warm_start:v1:$userId': jsonEncode(<String, Object?>{
          'userId': userId,
          'savedAt': DateTime.now().toUtc().toIso8601String(),
          'nextFlowId': 85,
          'flows': <Map<String, dynamic>>[
            flowPayload(id: 77, rule: journalRule, flowEnd: staleEnd),
            flowPayload(id: 78, rule: canonicalRule),
            flowPayload(id: 79, rule: expiredRule),
            flowPayload(id: 80, rule: legacyExpiredRule, flowEnd: staleEnd),
            flowPayload(id: 81, rule: inactiveRule, active: false),
            flowPayload(id: 82, rule: hiddenRule, hidden: true),
            flowPayload(id: 83, rule: endedRule),
          ],
          'notes': <String, Object?>{
            dayKey: <Map<String, Object?>>[
              <String, Object?>{
                'id': 'canonical-db-id',
                'clientEventId': canonicalCid,
                'title': canonicalRule['title'],
                'allDay': false,
                'startMinutes': 8 * 60,
                'endMinutes': 8 * 60 + 30,
                'flowId': 78,
                'isReminder': true,
                'reminderId': canonicalRule['id'],
                'alertOffsetMinutes': -1,
              },
            ],
          },
          'flowTotalEventCounts': const <String, int>{},
          'flowRemainingEventCounts': const <String, int>{},
        }),
      });

      final diagnostics = CalendarHydrationDiagnostics.instance;
      diagnostics.debugReset();
      await Supabase.instance.client.auth.recoverSession(_sessionJson(userId));
      CalendarPage.debugReminderSyncTodayForTesting = today;
      CalendarPage.debugReminderSyncWindowEndForTesting = today;

      final state = await pumpCalendar(tester);
      List<dynamic> notes = const [];
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (attempt % 5 == 4) {
          // Snapshot-store and SharedPreferences restores cross real async I/O
          // boundaries. Yield wall time as well as advancing the fake clock so
          // this test observes the same fallback path as an actual startup.
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
        }
        notes = state.notesForDayForTesting(kDay.kYear, kDay.kMonth, kDay.kDay);
        if (notes.any((note) => note.title == 'journal every day')) break;
      }

      final journalNotes = notes
          .where((note) => note.title == 'journal every day')
          .toList();
      expect(journalNotes, hasLength(1));
      expect(
        journalNotes.single.clientEventId,
        'reminder:${journalRule['id']}:${_dateKey(today)}',
      );

      final canonicalNotes = notes
          .where((note) => note.title == 'Canonical reminder')
          .toList();
      expect(canonicalNotes, hasLength(1));
      expect(canonicalNotes.single.id, 'canonical-db-id');
      expect(canonicalNotes.single.clientEventId, canonicalCid);

      for (final absentTitle in <String>[
        'Explicitly expired reminder',
        'Legacy expired reminder',
        'Inactive reminder',
        'Hidden reminder',
        'Ended reminder',
      ]) {
        expect(notes.where((note) => note.title == absentTitle), isEmpty);
      }

      await diagnostics.debugClose(HydrationTraceCloseReason.navigation);
      final commits = (diagnostics.lastCompletedTrace!['commits'] as List)
          .whereType<Map>()
          .map((entry) => Map<String, Object?>.from(entry))
          .toList();
      final warmCommit = commits.firstWhere(
        (entry) => entry['origin_class'] == 'warm_cache',
      );
      expect(warmCommit['reminder_count'], 2);

      await disposeCalendar(tester);
    },
  );

  test(
    'hydration projects before complete commit and startup sync is non-mutating',
    () {
      final source = _calendarHydrationSource();
      final hydrationStart = source.indexOf(
        'Future<_CalendarHydrationPassResult> _executeHydrationRequest({',
      );
      final projection = source.indexOf(
        'final projectedReminderCount = _projectReminderMembershipForHydration(',
        hydrationStart,
      );
      final completeCommit = source.indexOf(
        'commitVisibleCalendarState(\n        CalendarHydrationPublicationPhase.complete,',
        projection,
      );
      expect(projection, isNonNegative);
      expect(completeCommit, greaterThan(projection));

      final startupSync = source.substring(
        source.indexOf('Future<void> _runBackgroundHydration({'),
        source.indexOf('Future<void> _refreshHydrationAccounting()'),
      );
      expect(startupSync, contains('updateLocalCache: false'));
      expect(
        startupSync.indexOf('updateLocalCache: false'),
        lessThan(startupSync.indexOf('CalendarHydrationIntentKind.filing')),
      );
    },
  );

  test('disk warm restore projects before commit and notification', () {
    final source = _calendarHydrationSource();
    final restoreStart = source.indexOf(
      'Future<void> _restoreWarmStartCacheIfAvailable({',
    );
    final restoreEnd = source.indexOf(
      'Future<void> _refreshCalendarStateFromServer() async {',
      restoreStart,
    );
    final restore = source.substring(restoreStart, restoreEnd);
    final projection = restore.indexOf(
      'final projectedReminderCount = _projectReminderMembershipForHydration(',
    );
    final commit = restore.indexOf(
      '_hydrationController.restoreCache(',
      projection,
    );
    final diagnostic = restore.indexOf(
      'diagnostics.recordWarmCacheCommit(',
      commit,
    );
    final notification = restore.indexOf(
      '_notifyDayViewDataChanged(scheduleCacheSave: false);',
      diagnostic,
    );

    expect(projection, isNonNegative);
    expect(commit, greaterThan(projection));
    expect(diagnostic, greaterThan(commit));
    expect(notification, greaterThan(diagnostic));
  });
}

String _calendarHydrationSource() =>
    File('lib/features/calendar/calendar_page.dart').readAsStringSync() +
    File(
      'lib/features/calendar/hydration/calendar_hydration_engine.dart',
    ).readAsStringSync();

class _RejectingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path == '/auth/v1/user') {
      return http.StreamedResponse(
        Stream<List<int>>.value(utf8.encode(jsonEncode(_userJson()))),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
        request: request,
      );
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(const <int>[]),
      500,
      request: request,
    );
  }
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

Map<String, Object?> _userJson([String? id]) => <String, Object?>{
  'id': id ?? '27d63169-a28a-4550-a0a0-8fee0e8e7b95',
  'app_metadata': <String, Object?>{
    'provider': 'email',
    'providers': <String>['email'],
  },
  'user_metadata': const <String, Object?>{},
  'aud': 'authenticated',
  'email': 'warm-reminder-owner@example.com',
  'phone': '',
  'created_at': '2026-01-01T00:00:00.000000Z',
  'email_confirmed_at': '2026-01-01T00:00:00.000000Z',
  'role': 'authenticated',
  'updated_at': '2026-01-01T00:00:00.000000Z',
};

String _sessionJson(String userId) {
  final expiresAt =
      DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/
      1000;
  return jsonEncode(<String, Object?>{
    'access_token': 'test-access-token-$expiresAt',
    'expires_in': 31536000,
    'refresh_token': 'test-refresh-token',
    'token_type': 'bearer',
    'user': _userJson(userId),
    'expiresAt': expiresAt,
  });
}
