import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/landscape_month_view.dart';
import 'package:mobile/features/calendar/landscape_timeline_viewport.dart';
import 'package:mobile/features/calendar/presentation/instrument_event_presentation_frame.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show KemeticMath;
import 'package:mobile/data/flow_appearance.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../support/maat_flow_visual_test_fonts.dart';
import '../../support/maat_flow_visual_goldens.dart';
import '../../support/landscape_pinch_test_gesture.dart';

const fixtureFlows = <int, FlowData>{
  1: FlowData(
    id: 1,
    name: 'The Offering Table',
    color: Color(0xFFDDB787),
    active: true,
    notes: 'maat=the-offering-table',
  ),
  2: FlowData(
    id: 2,
    name: 'The Djed',
    color: Color(0xFFE0873C),
    active: true,
    notes: 'maat=the-djed',
  ),
  3: FlowData(
    id: 3,
    name: 'The Reading House',
    color: Color(0xFF7FD9BC),
    active: true,
    notes: 'maat=the-reading-house',
  ),
  4: FlowData(
    id: 4,
    name: '10-day Spanish practice',
    color: Color(0xFF6F93A8),
    active: true,
    appearance: FlowAppearance(
      signKind: FlowSignKind.papyrus,
      signLabel: 'Study',
      accentArgb: 0xFF6F93A8,
    ),
  ),
  5: FlowData(
    id: 5,
    name: 'Follow the Sky',
    color: Color(0xFF6876D8),
    active: true,
    notes: 'maat=follow-the-sky',
  ),
  6: FlowData(
    id: 6,
    name: 'The Kꜣr',
    color: Color(0xFFCFAC55),
    active: true,
    notes: 'maat=the-kar',
  ),
};

List<NoteData> fixtureNotes(int ky, int km, int kd) {
  final date = KemeticMath.toGregorian(ky, km, kd);
  if (date.isBefore(DateTime.utc(2026, 9, 25)) ||
      date.isAfter(DateTime.utc(2026, 10, 5))) {
    return const [];
  }
  return [
    NoteData(
      clientEventId: 'offering-$kd',
      title: 'Day 8: The Way',
      allDay: false,
      start: const TimeOfDay(hour: 8, minute: 0),
      end: const TimeOfDay(hour: 8, minute: 15),
      flowId: 1,
    ),
    NoteData(
      clientEventId: 'djed-$kd',
      title: 'Djed 2: Set the foundation',
      allDay: false,
      start: const TimeOfDay(hour: 9, minute: 0),
      end: const TimeOfDay(hour: 9, minute: 15),
      flowId: 2,
    ),
    NoteData(
      clientEventId: 'reading-$kd',
      calendarId: 'reading-house-fixture',
      behaviorPayload: const {
        'kind': 'maat_reading_house_sitting',
        'flow_key': 'the-reading-house',
        'event_number': 2,
      },
      title: 'Reading House 2: Hold the passage',
      allDay: false,
      start: const TimeOfDay(hour: 10, minute: 0),
      end: const TimeOfDay(hour: 10, minute: 30),
      flowId: 3,
    ),
    NoteData(
      clientEventId: 'spanish-$kd',
      title: 'Evening Reflection',
      allDay: false,
      start: const TimeOfDay(hour: 11, minute: 0),
      end: const TimeOfDay(hour: 11, minute: 30),
      flowId: 4,
    ),
    if (kd.isEven)
      NoteData(
        clientEventId: 'moon-$kd',
        behaviorPayload: const {
          'kind': 'track_sky_v2',
          'skyEventId': 'full-moon-2026-09-26',
          'trackSkySchemaVersion': 2,
        },
        title: 'Full Moon',
        allDay: false,
        start: const TimeOfDay(hour: 11, minute: 0),
        end: const TimeOfDay(hour: 12, minute: 0),
        flowId: 5,
      ),
    NoteData(
      clientEventId: 'kar-$kd',
      title: 'Walk the kꜣr',
      allDay: false,
      start: const TimeOfDay(hour: 12, minute: 0),
      end: const TimeOfDay(hour: 13, minute: 0),
      flowId: 6,
    ),
  ];
}

void main() {
  setUpAll(() async {
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
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'anon-key-0123456789012345678901234567890123456789',
      httpClient: _EmptySupabaseClient(),
    );
    await loadMaatFlowVisualTestFonts();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CalendarEventDetailSheetCoordinator.debugResetForTests();
  });
  testWidgets('approved landscape split surface at phone size', (tester) async {
    await pumpSplitFixture(tester);
    final calendarPane = tester.getRect(
      find.byKey(const ValueKey('landscape-calendar-pane')),
    );
    expect(calendarPane.left, 852 / 3 - 48);
    expect(calendarPane.right, 852 - 44);
    await expectLater(
      find.byKey(const ValueKey('fixture')),
      matchesGoldenFile(
        '${platformVisualGoldenRoot('../../visual_reference/landscape')}'
        '/approved-split-852x393.png',
      ),
    );
    final timeline = tester.widget<LandscapeTimeline>(
      find.byType(LandscapeTimeline),
    );
    timeline.verticalDetails.controller!.jumpTo(8 * 58);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    for (final flowId in [1, 2, 3, 4, 5, 6]) {
      final face = find
          .byWidgetPredicate(
            (w) => w is CalendarDayEventBlock && w.event.flowId == flowId,
          )
          .hitTestable()
          .first;
      await tester.tap(face);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CalendarEventDetailSheet), findsOneWidget);
      final pane = tester.getRect(
        find.byKey(const ValueKey('landscape-calendar-pane')),
      );
      final sheet = tester.getRect(find.byType(BottomSheet));
      expect(sheet.left, pane.left);
      expect(sheet.right, pane.right);
      expect(sheet.bottom, lessThanOrEqualTo(pane.bottom));
      expect(tester.getRect(find.byType(ModalBarrier).last), pane);
      if (flowId != 4) {
        expect(
          find.byType(MaatDayViewSheetHost),
          findsOneWidget,
          reason: 'Native flow $flowId',
        );
        expect(
          tester
              .widget<InstrumentEventSheetHost>(
                find.byType(InstrumentEventSheetHost),
              )
              .initialExtent,
          flowId == 1 || flowId == 6 ? .71 : .58,
        );
      }
      if (flowId == 2 || flowId == 4) {
        await expectLater(
          find.byKey(const ValueKey('fixture')),
          matchesGoldenFile(
            '${platformVisualGoldenRoot('../../visual_reference/landscape')}/pane-flow-$flowId-852x393.png',
          ),
        );
      }
      await tester.tapAt(Offset(pane.left + 8, pane.top + 8));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CalendarEventDetailSheet), findsNothing);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('landscape time zoom at intermediate scale', (tester) async {
    await pumpSplitFixture(tester);
    await pinchLandscapeTime(tester, factor: .6);
    await tester.pump(const Duration(milliseconds: 500));
    await expectLater(
      find.byKey(const ValueKey('fixture')),
      matchesGoldenFile(
        '${platformVisualGoldenRoot('../../visual_reference/landscape')}/zoom-intermediate-852x393.png',
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('landscape time zoom shows the full day', (tester) async {
    await pumpSplitFixture(tester, includeDayEdges: true);
    await pinchLandscapeTime(tester, factor: .1);
    await tester.pump(const Duration(milliseconds: 500));
    final timeline = tester.widget<LandscapeTimeline>(
      find.byType(LandscapeTimeline),
    );
    final midnight = find
        .byWidgetPredicate(
          (w) => w is CalendarDayEventBlock && w.event.title == 'Start of day',
        )
        .hitTestable()
        .first;
    final late = find
        .byWidgetPredicate(
          (w) =>
              w is CalendarDayEventBlock && w.event.title == 'Late reflection',
        )
        .hitTestable()
        .first;
    expect(
      tester.getTopLeft(midnight).dy,
      closeTo(
        tester.getTopLeft(find.byType(LandscapeTimeline)).dy +
            timeline.headerHeight,
        .01,
      ),
    );
    expect(
      tester.getBottomRight(late).dy,
      lessThanOrEqualTo(
        tester.getTopLeft(find.byKey(const ValueKey('landscape-today'))).dy - 8,
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('fixture')),
      matchesGoldenFile(
        '${platformVisualGoldenRoot('../../visual_reference/landscape')}/zoom-full-day-852x393.png',
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _EmptySupabaseClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final isModerationRpc = request.url.path.endsWith(
      '/rpc/reading_house_can_moderate_calendar',
    );
    final body = isModerationRpc ? 'false' : '[]';
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
      request: request,
      headers: const <String, String>{
        'content-type': 'application/json; charset=utf-8',
      },
    );
  }
}

Future<void> pumpSplitFixture(
  WidgetTester tester, {
  bool includeDayEdges = false,
}) async {
  tester.view.physicalSize = const Size(852, 393);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(left: 52, right: 44, bottom: 21);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final now = DateTime(2026, 9, 28, 8, 30);
  final k = KemeticMath.fromGregorian(now);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark().copyWith(
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Inter'),
      ),
      home: Scaffold(
        body: RepaintBoundary(
          key: const ValueKey('fixture'),
          child: LandscapeMonthView(
            initialKy: k.kYear,
            initialKm: k.kMonth,
            initialKd: k.kDay,
            showGregorian: true,
            clock: () => now,
            notesForDay: (y, m, d) => [
              ...fixtureNotes(y, m, d),
              if (includeDayEdges) ...[
                NoteData(
                  clientEventId: 'midnight-$d',
                  title: 'Start of day',
                  allDay: false,
                  start: const TimeOfDay(hour: 0, minute: 0),
                  end: const TimeOfDay(hour: 1, minute: 0),
                ),
                NoteData(
                  clientEventId: 'late-$d',
                  title: 'Late reflection',
                  allDay: false,
                  start: const TimeOfDay(hour: 23, minute: 0),
                  end: const TimeOfDay(hour: 23, minute: 59),
                ),
              ],
            ],
            flowIndex: fixtureFlows,
            getMonthName: (_) => 'Unused',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  expect(tester.takeException(), isNull);
}
