import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/features/calendar/calendar_geometry_snapshot.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
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
    CalendarPage.debugCalendarTodayForTesting = null;
  });

  testWidgets(
    'production year publishes all 13 sections and mounts Heriu anchors',
    (tester) async {
      // The pre-existing narrow-phone Heriu header overflow is a separately
      // tracked paint defect; this geometry test isolates section ownership.
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final current = KemeticMath.fromGregorian(DateTime(2026, 8, 13));
      var sixDayYear = current.kYear;
      while (!KemeticMath.isLeapKemeticYear(sixDayYear)) {
        sixDayYear++;
      }
      CalendarPage.debugCalendarTodayForTesting = KemeticMath.toGregorian(
        sixDayYear,
        13,
        6,
      );

      final pageKey = GlobalKey<CalendarPageState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CalendarPage(key: pageKey)),
        ),
      );
      pageKey.currentState!.debugShowCalendarShellForTesting();
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      final state = pageKey.currentState;
      expect(state, isNotNull);
      final collector = state!.debugCalendarGeometryCollector;
      expect(
        collector.debugRejectedPublicationCount,
        0,
        reason: _candidateDescription(
          collector.debugLastCandidate,
          collector.debugLastRejection,
        ),
      );
      final currentYearSections = collector.snapshot!.sections
          .where((section) => section.month.year == sixDayYear)
          .toList(growable: false);

      expect(currentYearSections, hasLength(13));
      expect(
        currentYearSections.map((section) => section.month.month),
        orderedEquals(List<int>.generate(13, (index) => index + 1)),
      );
      expect(keyForMonth(sixDayYear, 13).currentContext, isNotNull);
      expect(keyForMonthHeader(sixDayYear, 13).currentContext, isNotNull);

      var fiveDayYear = sixDayYear - 1;
      while (KemeticMath.isLeapKemeticYear(fiveDayYear)) {
        fiveDayYear--;
      }
      state.debugHandlePortraitMonthChangedForTesting(
        kYear: fiveDayYear,
        kMonth: 13,
        currentDay: 30,
      );
      expect(state.debugLastViewDay, 5);
      await tester.pump();
      state.debugHandlePortraitMonthChangedForTesting(
        kYear: sixDayYear,
        kMonth: 13,
        currentDay: 30,
      );
      expect(state.debugLastViewDay, 6);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'year section keeps following-month ownership and passive authority',
    () {
      final grid = File(
        'lib/features/calendar/calendar_grid_widgets.dart',
      ).readAsStringSync();
      final page = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();

      expect(grid, contains('kMonth <= CalendarSectionIndex.monthsPerYear'));
      expect(grid, contains('month: MonthRef(year: kYear, month: kMonth)'));
      expect(
        grid.indexOf('const _GoldDivider()'),
        lessThan(grid.indexOf('if (seasonHeader != null)')),
      );
      expect(
        grid.indexOf('if (seasonHeader != null)'),
        lessThan(grid.indexOf('_buildMonthBody(kMonth, tm, td)')),
      );
      expect(grid, isNot(contains('children: const [_GoldDivider()]')));

      expect(grid, contains('anchorKey: monthAnchorKeyProvider?.call(kMonth)'));
      expect(
        grid,
        contains('monthHeaderKey: monthHeaderKeyProvider?.call(kMonth)'),
      );
      expect(grid, contains('dayAnchorKeyProvider: dayAnchorKeyProvider'));
      expect(grid, contains('highlightAnchorKey: dayAnchorKeyProvider?.call('));

      expect(
        page,
        contains('final centered = _computeCenteredMonthPrecisely()'),
      );
      expect(page, isNot(contains('_calendarGeometryCollector.snapshot')));
    },
  );
}

String _candidateDescription(
  List<CalendarSectionGeometry> sections,
  Object? rejection,
) {
  final buffer = StringBuffer('rejection=$rejection');
  for (final section in sections) {
    buffer.write(
      '\n${section.month}: '
      '${section.extent.leading}..${section.extent.trailing}',
    );
  }
  return buffer.toString();
}

class _RejectingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable(const []),
      500,
      request: request,
    );
  }
}
