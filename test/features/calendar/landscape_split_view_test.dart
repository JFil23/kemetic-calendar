import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/landscape_month_view.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show KemeticMath;
import 'package:mobile/data/flow_appearance.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/maat_flow_visual_test_fonts.dart';
import '../../support/maat_flow_visual_goldens.dart';

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
  setUpAll(loadMaatFlowVisualTestFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CalendarEventDetailSheetCoordinator.debugResetForTests();
  });
  testWidgets('approved landscape split surface at phone size', (tester) async {
    tester.view.physicalSize = const Size(852, 393);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(
      left: 52,
      right: 44,
      bottom: 21,
    );
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
              notesForDay: fixtureNotes,
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
    await expectLater(
      find.byKey(const ValueKey('fixture')),
      matchesGoldenFile(
        '${platformVisualGoldenRoot('../../visual_reference/landscape')}'
        '/approved-split-852x393.png',
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
