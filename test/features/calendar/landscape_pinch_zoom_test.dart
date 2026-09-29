import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/landscape_timeline_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/landscape_pinch_test_gesture.dart';
import '../../support/maat_flow_visual_test_fonts.dart';
import 'landscape_split_behavior_test.dart'
    show pumpLandscape, timeline, days, hours, ledger;
import 'landscape_scroll_contract_test.dart' show dailyNotes, block;

final timePane = find.byKey(const ValueKey('landscape-time-pinch'));

double hourHeight(WidgetTester tester) => timeline(tester).dayHeight / 24;
double fullDayHeight(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const ValueKey('landscape-today'))).dy -
    8 -
    tester.getTopLeft(find.byType(LandscapeTimeline)).dy -
    timeline(tester).headerHeight;

void main() {
  setUpAll(loadMaatFlowVisualTestFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CalendarEventDetailSheetCoordinator.debugResetForTests();
  });
  tearDown(CalendarEventDetailSheetCoordinator.debugResetForTests);

  testWidgets(
    'touch pinch fits 24 hours above safe area and never exceeds original scale',
    (tester) async {
      tester.view.padding = const FakeViewPadding(
        left: 52,
        right: 44,
        bottom: 21,
      );
      addTearDown(tester.view.resetPadding);
      await pumpLandscape(tester, notes: dailyNotes);
      await tester.pumpAndSettle();
      final x = days(tester).offset;
      final width = timeline(tester).columnWidth;
      final listOffset = ledger(tester).controller!.offset;
      expect(hourHeight(tester), 58);
      await pinchLandscapeTime(tester, factor: .1);
      expect(timeline(tester).dayHeight, fullDayHeight(tester));
      expect(hours(tester).position.maxScrollExtent, 0);
      expect(hours(tester).offset, 0);
      expect(days(tester).offset, x);
      expect(timeline(tester).columnWidth, width);
      expect(ledger(tester).controller!.offset, listOffset);
      expect(find.byType(CalendarEventDetailSheet), findsNothing);
      await pinchLandscapeTime(tester, factor: .1);
      expect(hourHeight(tester), fullDayHeight(tester) / 24);
      for (var i = 0; i < 4; i++) {
        await pinchLandscapeTime(tester, factor: 2);
      }
      expect(hourHeight(tester), 58);
      await pinchLandscapeTime(tester, factor: 2);
      expect(hourHeight(tester), 58);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('time under the pinch stays anchored and list stays still', (
    tester,
  ) async {
    await pumpLandscape(tester, notes: dailyNotes);
    await tester.pumpAndSettle();
    final center = tester.getCenter(timePane);
    final focalY = center.dy - tester.getTopLeft(timePane).dy - 84;
    final beforeMinute =
        (hours(tester).offset + focalY) / hourHeight(tester) * 60;
    final x = days(tester).offset;
    final listOffset = ledger(tester).controller!.offset;
    await pinchLandscapeTime(tester, factor: .65, focalPoint: center);
    expect(hourHeight(tester), inExclusiveRange(20, 58));
    expect(
      (hours(tester).offset + focalY) / hourHeight(tester) * 60,
      closeTo(beforeMinute, .01),
    );
    expect(days(tester).offset, x);
    expect(ledger(tester).controller!.offset, listOffset);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'pinch is scoped to calendar; list and split contacts cannot zoom it',
    (tester) async {
      await pumpLandscape(tester, notes: dailyNotes);
      final left = tester.getRect(
        find.byKey(const ValueKey('landscape-ledger')),
      );
      for (final points in [
        (left.center - const Offset(35, 0), left.center + const Offset(35, 0)),
        (left.center, tester.getCenter(timePane)),
      ]) {
        final a = await tester.createGesture();
        final b = await tester.createGesture();
        await a.down(points.$1);
        await b.down(points.$2);
        await a.moveBy(const Offset(20, -20));
        await b.moveBy(const Offset(-20, 20));
        await tester.pump();
        await a.cancel();
        await b.cancel();
        await tester.pumpAndSettle();
        expect(hourHeight(tester), 58);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'ordinary diagonal scrolling and wheel input survive zoom; full day still scrolls dates',
    (tester) async {
      await pumpLandscape(tester, notes: dailyNotes);
      await pinchLandscapeTime(tester, factor: .65);
      var x = days(tester).offset, y = hours(tester).offset;
      await tester.drag(find.byType(LandscapeTimeline), const Offset(-75, -45));
      await tester.pumpAndSettle();
      expect(days(tester).offset, greaterThan(x));
      expect(hours(tester).offset, greaterThan(y));
      x = days(tester).offset;
      y = hours(tester).offset;
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(timePane),
          scrollDelta: const Offset(30, 40),
        ),
      );
      await tester.pumpAndSettle();
      expect(days(tester).offset, closeTo(x + 30, .01));
      expect(hours(tester).offset, closeTo(y + 40, .01));
      await pinchLandscapeTime(tester, factor: .1);
      x = days(tester).offset;
      await tester.drag(find.byType(LandscapeTimeline), const Offset(-90, -60));
      await tester.pumpAndSettle();
      expect(days(tester).offset, greaterThan(x));
      expect(hours(tester).offset, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'stationary finger cannot open a sheet after pinch; cancel restores scrolling',
    (tester) async {
      var moved = false;
      await pumpLandscape(
        tester,
        notes: dailyNotes,
        onMove: (_, _, _, _, _) async {
          moved = true;
        },
      );
      await tester.pumpAndSettle();
      final target = tester.getCenter(block('Day 13 at 8').hitTestable());
      final a = await tester.createGesture();
      final b = await tester.createGesture();
      await a.down(target + const Offset(120, 0));
      await b.down(target);
      await a.moveBy(const Offset(-10, 0));
      await tester.pump();
      await a.moveBy(const Offset(-50, 0));
      await tester.pump();
      expect(hourHeight(tester), lessThan(58));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
      expect(
        find
            .byType(Opacity)
            .evaluate()
            .where((e) => (e.widget as Opacity).opacity == .35),
        isEmpty,
      );
      await a.up();
      await tester.pump();
      expect(
        timeline(tester).verticalDetails.physics,
        isA<NeverScrollableScrollPhysics>(),
      );
      await b.up();
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump();
      await tester.pump();
      expect(find.byType(CalendarEventDetailSheet), findsNothing);
      expect(timeline(tester).verticalDetails.physics, isNull);
      expect(moved, isFalse);
      final c = await tester.createGesture();
      final d = await tester.createGesture();
      final center = tester.getCenter(timePane);
      await c.down(center - const Offset(70, 0));
      await d.down(center + const Offset(70, 0));
      await c.moveBy(const Offset(10, 0));
      await tester.pump();
      await c.cancel();
      await d.cancel();
      await tester.pump();
      await tester.pump();
      expect(timeline(tester).verticalDetails.physics, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Today and native sheets preserve zoom; full-day fit follows viewport resizing',
    (tester) async {
      await pumpLandscape(tester, notes: dailyNotes);
      final startX = days(tester).offset;
      await pinchLandscapeTime(tester, factor: .1);
      days(tester).jumpTo(startX + timeline(tester).columnWidth * 2);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('landscape-today')));
      await tester.pumpAndSettle();
      expect(days(tester).offset, startX);
      expect(timeline(tester).dayHeight, fullDayHeight(tester));
      await tester.tap(block('Day 13 at 8').hitTestable());
      await tester.pumpAndSettle();
      final pane = tester.getRect(timePane);
      final sheet = tester.getRect(find.byType(BottomSheet));
      expect(sheet.left, pane.left);
      expect(sheet.right, pane.right);
      expect(sheet.height, greaterThan(100));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(timeline(tester).dayHeight, fullDayHeight(tester));
      tester.view.physicalSize = const Size(852, 360);
      await tester.pumpAndSettle();
      expect(timeline(tester).dayHeight, fullDayHeight(tester));
      expect(hours(tester).offset, 0);
      tester.view.physicalSize = const Size(1024, 500);
      await tester.pumpAndSettle();
      expect(timeline(tester).dayHeight, fullDayHeight(tester));
      expect(hours(tester).offset, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('note drag uses zoomed time and still snaps to 15 minutes', (
    tester,
  ) async {
    int? movedMinute;
    await pumpLandscape(
      tester,
      notes: dailyNotes,
      onMove: (_, _, _, event, minute) async {
        movedMinute = minute;
      },
    );
    await pinchLandscapeTime(tester, factor: .65);
    final target = block('Day 13 at 8').hitTestable();
    final drag = await tester.startGesture(tester.getCenter(target));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
    await drag.moveBy(Offset(0, hourHeight(tester) * 1.5));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
    expect(movedMinute, 9 * 60 + 30);
    expect(find.byType(CalendarEventDetailSheet), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('browser scale signals and trackpad pinch use the same bounds', (
    tester,
  ) async {
    await pumpLandscape(tester, notes: dailyNotes);
    final center = tester.getCenter(timePane);
    await tester.sendEventToBinding(
      PointerScaleEvent(position: center, scale: .6),
    );
    await tester.pumpAndSettle();
    expect(hourHeight(tester), closeTo(58 * .6, .001));
    await tester.sendEventToBinding(
      PointerScaleEvent(position: const Offset(20, 100), scale: .5),
    );
    await tester.pumpAndSettle();
    expect(hourHeight(tester), closeTo(58 * .6, .001));
    final trackpad = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await trackpad.panZoomStart(center);
    await trackpad.panZoomUpdate(center, scale: .95);
    await tester.pump();
    await trackpad.panZoomUpdate(center, scale: .1);
    await tester.pump();
    await trackpad.panZoomEnd();
    await tester.pumpAndSettle();
    expect(hours(tester).position.maxScrollExtent, 0);
    expect(timeline(tester).dayHeight, fullDayHeight(tester));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
