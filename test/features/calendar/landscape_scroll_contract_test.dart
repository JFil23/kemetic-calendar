import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/landscape_timeline_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/maat_flow_visual_test_fonts.dart';
import 'landscape_split_behavior_test.dart'
    show pumpLandscape, timeline, days, hours, ledger;

List<NoteData> dailyNotes(int y, int m, int d) => [
  for (final h in [8, 12, 18])
    NoteData(
      clientEventId: '$y-$m-$d-$h',
      title: 'Day $d at $h',
      allDay: false,
      start: TimeOfDay(hour: h, minute: 0),
      end: TimeOfDay(hour: h + 1, minute: 0),
    ),
];
Finder listRow(String title) => find.descendant(
  of: find.byKey(const ValueKey('landscape-ledger')),
  matching: find.text(title),
);
Finder block(String title) => find.byWidgetPredicate(
  (w) => w is CalendarDayEventBlock && w.event.title == title,
);

void main() {
  setUpAll(loadMaatFlowVisualTestFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CalendarEventDetailSheetCoordinator.debugResetForTests();
  });
  tearDown(CalendarEventDetailSheetCoordinator.debugResetForTests);

  testWidgets(
    'one diagonal gesture keeps both axes and momentum, without reloading notes or reporting dates mid-drag',
    (tester) async {
      var reads = 0;
      final reports = <int>[];
      await pumpLandscape(
        tester,
        notes: (y, m, d) {
          reads++;
          return dailyNotes(y, m, d);
        },
        onDay: (_, _, d) => reports.add(d),
      );
      await tester.pumpAndSettle();
      final initialReads = reads;
      final x = days(tester).offset, y = hours(tester).offset;
      final header = find.descendant(
        of: find.byType(LandscapeTimeline),
        matching: find.text('13'),
      );
      final headerStart = tester.getTopLeft(header);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(LandscapeTimeline)),
      );
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(-12, -7));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(days(tester).offset, greaterThan(x + 90));
      expect(hours(tester).offset, greaterThan(y + 45));
      expect(tester.getTopLeft(header).dy, headerStart.dy);
      expect(
        tester.getTopLeft(header).dx,
        closeTo(headerStart.dx - (days(tester).offset - x), .01),
      );
      // Even a pause with the finger held must not rebuild the parent route.
      await tester.pump(const Duration(milliseconds: 300));
      expect(reports, isEmpty);
      await gesture.moveBy(
        const Offset(-20, -12),
        timeStamp: const Duration(milliseconds: 520),
      );
      await tester.pump(const Duration(milliseconds: 16));
      final releaseX = days(tester).offset;
      await gesture.up(timeStamp: const Duration(milliseconds: 530));
      await tester.pump(const Duration(milliseconds: 32));
      expect(days(tester).offset, greaterThanOrEqualTo(releaseX));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 200));
      expect(reports, hasLength(1));
      expect(
        reads,
        initialReads,
        reason:
            'Scroll frames reuse projected events in the loaded date window',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('trackpad wheel moves both axes together', (tester) async {
    await pumpLandscape(tester, notes: dailyNotes);
    final x = days(tester).offset, y = hours(tester).offset;
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byType(LandscapeTimeline)),
        scrollDelta: const Offset(60, 90),
      ),
    );
    await tester.pumpAndSettle();
    expect(days(tester).offset, closeTo(x + 60, .01));
    expect(hours(tester).offset, closeTo(y + 90, .01));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'vertical focus animates the list; pointer contact unlinks it; Today centers and relinks',
    (tester) async {
      await pumpLandscape(tester, notes: dailyNotes);
      await tester.pumpAndSettle();
      final startX = days(tester).offset;
      final startList = ledger(tester).controller!.offset;
      days(tester).jumpTo(startX + timeline(tester).columnWidth);
      hours(tester).jumpTo(12 * 58);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 100));
      final during = ledger(tester).controller!.offset;
      await tester.pumpAndSettle();
      final end = ledger(tester).controller!.offset;
      expect(during, greaterThan(startList));
      expect(during, lessThan(end));
      // 12:00 + 81-minute focus finds the 18:00 event after noon has ended.
      expect(tester.getTopLeft(listRow('Day 13 at 18')).dy, closeTo(24, 1));
      final contact = await tester.startGesture(const Offset(20, 150));
      await contact.up();
      await tester.pump();
      final independent = ledger(tester).controller!.offset;
      days(tester).jumpTo(days(tester).offset + timeline(tester).columnWidth);
      hours(tester).jumpTo(16 * 58);
      await tester.pumpAndSettle();
      expect(ledger(tester).controller!.offset, independent);
      await tester.tap(find.byKey(const ValueKey('landscape-today')));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(days(tester).offset, closeTo(startX, .01));
      expect(hours(tester).offset, closeTo((8 * 60 + 30 - 81) / 60 * 58, .01));
      expect(ledger(tester).controller!.offset, closeTo(startList, .01));
      await tester.pump(const Duration(milliseconds: 500));
      days(tester).jumpTo(startX + timeline(tester).columnWidth);
      hours(tester).jumpTo(12 * 58);
      await tester.pumpAndSettle();
      expect(ledger(tester).controller!.offset, greaterThan(startList));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'list locates before opening; sheets preserve calendar scroll and permit independent list use',
    (tester) async {
      await pumpLandscape(tester, notes: dailyNotes);
      await tester.pumpAndSettle();
      final x = days(tester).offset;
      await tester.tap(listRow('Day 13 at 12'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarEventDetailSheet), findsNothing);
      expect(
        days(tester).offset,
        x,
        reason: 'Do not move an already-visible date',
      );
      expect(hours(tester).offset, closeTo(12 * 58 - 22, .01));
      expect(block('Day 13 at 12').hitTestable(), findsOneWidget);
      await tester.tap(listRow('Day 13 at 12'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarEventDetailSheet), findsOneWidget);
      final pane = tester.getRect(
        find.byKey(const ValueKey('landscape-calendar-pane')),
      );
      expect(tester.getRect(find.byType(BottomSheet)).left, pane.left);
      expect(tester.getRect(find.byType(ModalBarrier).last), pane);
      final before = ledger(tester).controller!.offset;
      await tester.drag(
        find.byKey(const ValueKey('landscape-ledger')),
        const Offset(0, -80),
      );
      await tester.pumpAndSettle();
      expect(ledger(tester).controller!.offset, greaterThan(before));
      expect(find.byType(CalendarEventDetailSheet), findsOneWidget);
      final y = hours(tester).offset;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CalendarEventDetailSheet), findsNothing);
      expect(find.byType(LandscapeTimeline), findsOneWidget);
      expect(days(tester).offset, x);
      expect(hours(tester).offset, y);
      await tester.tap(block('Day 13 at 12'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarEventDetailSheet), findsOneWidget);
      expect(days(tester).offset, x);
      expect(hours(tester).offset, y);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'proximity snap leaves distant partial days free and only aligns nearby boundaries',
    (tester) async {
      await pumpLandscape(tester, notes: dailyNotes);
      final start = days(tester).offset, width = timeline(tester).columnWidth;
      days(tester).jumpTo(start + width * .4);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 200));
      expect(days(tester).offset, closeTo(start + width * .4, .01));
      days(tester).jumpTo(start + width * .94);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(days(tester).offset, closeTo(start + width, .01));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
