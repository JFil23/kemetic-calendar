import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show KemeticMath;
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/landscape_month_view.dart';
import 'package:mobile/features/calendar/landscape_timeline_viewport.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/calendar/presentation/instrument_event_presentation_frame.dart';
import 'package:mobile/widgets/calendar_floating_shortcuts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/maat_flow_visual_test_fonts.dart';
import 'landscape_split_view_test.dart' show fixtureFlows, fixtureNotes;

final fixtureNow = DateTime(2026, 9, 28, 8, 30);

Future<void> pumpLandscape(
  WidgetTester tester, {
  int? year,
  int? month,
  int? day,
  Size size = const Size(852, 393),
  ValueNotifier<int>? dataVersion,
  List<NoteData> Function(int, int, int)? notes,
  Map<int, FlowData> flows = const {},
  void Function(int, int, int)? onDay,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final k = KemeticMath.fromGregorian(fixtureNow);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: LandscapeMonthView(
          initialKy: year ?? k.kYear,
          initialKm: month ?? k.kMonth,
          initialKd: day ?? k.kDay,
          showGregorian: true,
          clock: () => fixtureNow,
          dataVersion: dataVersion,
          notesForDay: notes ?? (_, _, _) => const [],
          flowIndex: flows,
          getMonthName: (_) => 'must use canonical metadata',
          onVisibleDayChanged: onDay,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

LandscapeTimeline timeline(WidgetTester tester) =>
    tester.widget<LandscapeTimeline>(find.byType(LandscapeTimeline));
ScrollController days(WidgetTester tester) =>
    timeline(tester).horizontalDetails.controller!;
ScrollController hours(WidgetTester tester) =>
    timeline(tester).verticalDetails.controller!;
ListView ledger(WidgetTester tester) =>
    tester.widget<ListView>(find.byKey(const ValueKey('landscape-ledger')));

void main() {
  setUpAll(loadMaatFlowVisualTestFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CalendarEventDetailSheetCoordinator.debugResetForTests();
  });
  tearDown(CalendarEventDetailSheetCoordinator.debugResetForTests);

  testWidgets('three continuous days cross short epagomenal months and years', (
    tester,
  ) async {
    for (final year in [2, 3]) {
      final lastDay = KemeticMath.isLeapKemeticYear(year) ? 6 : 5;
      ({int y, int m, int d})? visible;
      await pumpLandscape(
        tester,
        year: year,
        month: 13,
        day: lastDay,
        onDay: (y, m, d) => visible = (y: y, m: m, d: d),
      );
      final dayScroll = days(tester);
      final initialOffset = dayScroll.offset;
      dayScroll.jumpTo(initialOffset + timeline(tester).columnWidth);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(visible, (y: year + 1, m: 1, d: 1));
      expect(
        find.text(getMonthById(13).displayShort.toUpperCase()),
        findsOneWidget,
      );
      dayScroll.jumpTo(initialOffset);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(visible, (y: year, m: 13, d: lastDay));
      expect(
        find.text(getMonthById(13).displayShort.toUpperCase()),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets(
    'Today is inside the calendar pane and resets both linked views',
    (tester) async {
      await pumpLandscape(tester, notes: fixtureNotes, flows: fixtureFlows);
      final dayScroll = days(tester);
      final start = dayScroll.offset;
      final ledgerStart = ledger(tester).controller!.offset;
      await tester.drag(
        find.byKey(const ValueKey('landscape-ledger')),
        const Offset(0, -130),
      );
      await tester.pump(const Duration(seconds: 1));
      dayScroll.jumpTo(start + timeline(tester).columnWidth * 2);
      await tester.pump();
      await tester.pump();
      final button = tester.getRect(
        find.byKey(const ValueKey('landscape-today')),
      );
      final pane = tester.getRect(
        find.byKey(const ValueKey('landscape-calendar-pane')),
      );
      expect(button.left, closeTo(pane.left + 28, .01));
      expect(button.bottom, closeTo(pane.bottom - 28, .01));
      expect(find.byType(CalendarFloatingTodayButton), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('landscape-today')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(dayScroll.offset, closeTo(start, .01));
      expect(ledger(tester).controller!.offset, closeTo(ledgerStart, .01));
      expect(hours(tester).offset, closeTo((8 * 60 + 30 - 81) / 60 * 58, .01));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'live data replaces both projections without losing the viewport',
    (tester) async {
      final version = ValueNotifier(0);
      addTearDown(version.dispose);
      var title = 'Before edit';
      await pumpLandscape(
        tester,
        dataVersion: version,
        notes: (y, m, d) => d == 13
            ? [
                NoteData(
                  clientEventId: 'same-event',
                  title: title,
                  allDay: false,
                  start: const TimeOfDay(hour: 8, minute: 0),
                  end: const TimeOfDay(hour: 9, minute: 0),
                ),
              ]
            : const [],
      );
      final offset = days(tester).offset;
      title = 'After edit';
      version.value++;
      await tester.pump();
      await tester.pump();
      expect(find.text('Before edit'), findsNothing);
      expect(find.text('After edit'), findsWidgets);
      expect(days(tester).offset, offset);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'short painted events share nonoverlapping lanes and retain full color in the past',
    (tester) async {
      await pumpLandscape(
        tester,
        notes: (y, m, d) => d == 13
            ? [
                for (var i = 0; i < 2; i++)
                  NoteData(
                    clientEventId: 'overlap-$i',
                    title: 'Overlap $i',
                    allDay: false,
                    start: TimeOfDay(hour: 8, minute: i * 15),
                    end: TimeOfDay(hour: 8, minute: i * 15 + 10),
                  ),
              ]
            : const [],
      );
      final faces = find.byType(CalendarDayEventBlock);
      expect(faces, findsNWidgets(2));
      final a = tester.getRect(faces.at(0));
      final b = tester.getRect(faces.at(1));
      expect(a.right <= b.left || b.right <= a.left, isTrue);
      for (final face in tester.widgetList<CalendarDayEventBlock>(faces)) {
        expect(face.isPreview, isFalse);
      }
      expect(
        find.ancestor(of: faces, matching: find.byType(Opacity)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('all-day events remain in their pinned lane while hours scroll', (
    tester,
  ) async {
    await pumpLandscape(
      tester,
      notes: (y, m, d) => d == 13
          ? const [
              NoteData(
                clientEventId: 'all-day',
                title: 'All-day event',
                allDay: true,
              ),
            ]
          : const [],
    );
    final header = find.byType(LandscapeTimeline);
    final chip = find.descendant(
      of: header,
      matching: find.text('All-day event'),
    );
    final position = tester.getRect(chip);
    hours(tester).jumpTo(900);
    await tester.pump();
    expect(tester.getRect(chip), position);
    expect(find.byType(CalendarDayEventBlock), findsNothing);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.byType(CalendarEventDetailSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'a short landscape native instrument scrolls its full composition after resizing',
    (tester) async {
      tester.view.physicalSize = const Size(852, 393);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: MaatDayViewSheetHost(
                flow: MaatDayViewFlow.djed,
                trailing: const Icon(Icons.more_vert),
                footer: const Text('Native actions'),
                body: InstrumentEventPresentationFrame(
                  decoration: const BoxDecoration(color: Colors.black),
                  instrument: const ColoredBox(
                    key: ValueKey('natural-art'),
                    color: Colors.amber,
                  ),
                  instrumentFooter: const SizedBox.shrink(),
                  inputBuilder: (_, _, _) => const SizedBox.shrink(),
                  body: const SizedBox(
                    height: 400,
                    child: Text('Full native body'),
                  ),
                  completion: const Text('Native completion'),
                  bodyScrollKey: const ValueKey('native-scroll'),
                  lowerSheetKey: const ValueKey('native-lower'),
                  graphicSpace: const MaatDayViewGraphicSpace.fixed(
                    height: 240,
                  ),
                  foregroundStyle: const MaatDayViewForegroundStyle.color(
                    color: Colors.black,
                    borderColor: Colors.amber,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.getSize(find.byKey(const ValueKey('natural-art'))).height,
        240,
      );
      await tester.drag(
        find.byType(InstrumentEventSheetTopBar),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('natural-art'))).height,
        240,
      );
      await tester.drag(
        find.byKey(const ValueKey('native-scroll')),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      expect(find.text('Native completion').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('native event faces fit narrow overlap lanes', (tester) async {
    tester.view.physicalSize = const Size(1200, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [52.0, 76.0, 160.0]) {
      final events = calendarEventsForNotes(
        notes: [
          for (final id in fixtureFlows.keys)
            NoteData(
              title: 'A long event title',
              allDay: false,
              flowId: id,
              start: const TimeOfDay(hour: 8, minute: 0),
              end: const TimeOfDay(hour: 8, minute: 15),
            ),
        ],
        flowIndex: fixtureFlows,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                for (final event in events)
                  CalendarDayEventBlock(
                    event: event,
                    flow: fixtureFlows[event.flowId],
                    ky: 2,
                    km: 7,
                    kd: 1,
                    width: width,
                    height: 60,
                    clock: () => fixtureNow,
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: 'lane width $width');
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets(
    'a portrait keyboard does not select landscape sheet composition',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      bool? landscape;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(390, 220)),
            child: Builder(
              builder: (context) {
                landscape = calendarEventSheetUsesLandscape(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(landscape, isFalse);
    },
  );
}
