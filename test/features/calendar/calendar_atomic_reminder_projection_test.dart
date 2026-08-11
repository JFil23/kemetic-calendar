import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/reminders/reminder_rule.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart' as picker;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
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

  test(
    'hydration projects before complete commit and startup sync is non-mutating',
    () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final projection = source.indexOf(
        'final projectedReminderCount = _projectReminderMembershipForHydration(',
      );
      final completeCommit = source.indexOf(
        'commitVisibleCalendarState(\n        CalendarHydrationPublicationPhase.complete,',
        projection,
      );
      expect(projection, isNonNegative);
      expect(completeCommit, greaterThan(projection));

      final startupSync = source.substring(
        source.indexOf("source: 'startup_backfill:\$reason'"),
        source.indexOf("debugReason: 'startup_backfill_complete'"),
      );
      expect(startupSync, contains('updateLocalCache: false'));
    },
  );
}

class _RejectingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(const <int>[]),
      500,
      request: request,
    );
  }
}
