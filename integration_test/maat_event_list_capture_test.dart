import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture three contextual Ma’at event-list palettes', (
    tester,
  ) async {
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }

    for (final capture in const <(String, String)>[
      ('track-the-sky', 'follow-the-sky'),
      ('the-offering-table', 'offering-table'),
      ('the-weighing', 'the-weighing'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: buildMaatFlowTemplateDetailPreviewForTesting(
            templateKey: capture.$1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tap = _eventTaps().first;
      await _reveal(tester, tap);
      await binding.takeScreenshot('${capture.$2}-expanded');

      await tester.tap(tap);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('${capture.$2}-collapsed');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'record tap-bounded off-screen cleanup, anchoring, and page reset',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: buildMaatFlowTemplateDetailPreviewForTesting(
            templateKey: 'track-the-sky',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_expandedCards(), findsOneWidget);
      await _recordingPause();

      final scrollable = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(scrollable).position;
      final rows = _eventRows();
      final taps = _eventTaps();
      final firstRow = rows.at(0);
      final secondRow = rows.at(1);
      final secondTap = taps.at(1);
      final viewport = tester.getRect(scrollable);
      await _positionBlockBottom(
        tester,
        block: firstRow,
        screenY: viewport.top + 2,
        scrollable: scrollable,
      );
      expect(tester.getRect(firstRow).top, lessThan(viewport.top));
      expect(tester.getRect(firstRow).bottom, greaterThan(viewport.top));
      final partialSecondTop = tester.getTopLeft(secondRow).dy;
      final partialPixels = position.pixels;
      await tester.tap(secondTap);
      await _pumpFramesForRecording(
        tester,
        trackedRow: secondRow,
        position: position,
        expectedTop: partialSecondTop,
        expectedPixels: partialPixels,
      );
      expect(
        find.descendant(of: firstRow, matching: _expandedCards()),
        findsOneWidget,
        reason: 'a partially visible complete block must remain expanded',
      );
      expect(_expandedCards(), findsNWidgets(2));
      await _recordingPause();

      final cleanupRow = rows.at(5);
      final cleanupTap = taps.at(5);
      await _positionBlockFullyAbove(
        tester,
        block: firstRow,
        target: cleanupRow,
        scrollable: scrollable,
      );
      expect(tester.getRect(firstRow).bottom, lessThanOrEqualTo(viewport.top));
      expect(_expandedCards(), findsNWidgets(2));
      final cleanupTop = tester.getTopLeft(cleanupRow).dy;
      await tester.tap(cleanupTap);
      await _pumpFramesForRecording(
        tester,
        trackedRow: cleanupRow,
        position: position,
        expectedTop: cleanupTop,
      );
      expect(
        find.descendant(of: firstRow, matching: _expandedCards()),
        findsNothing,
        reason: 'a fully off-screen block retires on the next opening tap',
      );
      expect(
        find.descendant(of: cleanupRow, matching: _expandedCards()),
        findsOneWidget,
      );
      await _recordingPause();

      final longRow = rows.at(7);
      final longTap = taps.at(7);
      await _positionBlockFullyAbove(
        tester,
        block: cleanupRow,
        target: longRow,
        scrollable: scrollable,
      );
      final longTop = tester.getTopLeft(longRow).dy;
      await tester.tap(longTap);
      await _pumpFramesForRecording(
        tester,
        trackedRow: longRow,
        position: position,
        expectedTop: longTop,
      );
      expect(
        find.descendant(of: cleanupRow, matching: _expandedCards()),
        findsNothing,
      );
      expect(
        find.descendant(of: longRow, matching: _expandedCards()),
        findsOneWidget,
      );
      await _recordingPause();

      final collapseTop = tester.getTopLeft(longRow).dy;
      final collapsePixels = position.pixels;
      await tester.tap(longTap);
      await _pumpFramesForRecording(
        tester,
        trackedRow: longRow,
        position: position,
        expectedTop: collapseTop,
        expectedPixels: collapsePixels,
      );
      expect(
        find.descendant(of: longRow, matching: _expandedCards()),
        findsNothing,
      );
      await _recordingPause();

      final reopenTop = tester.getTopLeft(longRow).dy;
      final reopenPixels = position.pixels;
      await tester.tap(longTap);
      await _pumpFramesForRecording(
        tester,
        trackedRow: longRow,
        position: position,
        expectedTop: reopenTop,
        expectedPixels: reopenPixels,
      );
      expect(
        find.descendant(of: longRow, matching: _expandedCards()),
        findsOneWidget,
      );
      await _recordingPause();

      final longCard = find.descendant(of: longRow, matching: _expandedCards());
      for (
        var step = 0;
        step < 18 && tester.getRect(longCard).bottom > viewport.bottom - 8;
        step++
      ) {
        await tester.timedDrag(
          scrollable,
          const Offset(0, -220),
          const Duration(milliseconds: 420),
        );
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
      expect(
        tester.getRect(longCard).bottom,
        lessThanOrEqualTo(viewport.bottom - 7),
      );
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      final bottomCta = find.byWidget(scaffold.bottomNavigationBar!);
      expect(
        tester.getRect(bottomCta).top,
        greaterThanOrEqualTo(viewport.bottom),
      );
      expect(
        find.descendant(of: longRow, matching: _expandedCards()),
        findsOneWidget,
      );
      await _recordingPause();

      await _reveal(tester, firstRow);
      expect(
        tester.getRect(longRow).top,
        greaterThanOrEqualTo(viewport.bottom),
      );
      final reverseTop = tester.getTopLeft(firstRow).dy;
      final reversePixels = position.pixels;
      await tester.tap(taps.at(0));
      await _pumpFramesForRecording(
        tester,
        trackedRow: firstRow,
        position: position,
        expectedTop: reverseTop,
        expectedPixels: reversePixels,
      );
      expect(
        find.descendant(of: longRow, matching: _expandedCards()),
        findsNothing,
        reason: 'off-screen cleanup below must not move the viewport',
      );
      expect(
        find.descendant(of: firstRow, matching: _expandedCards()),
        findsOneWidget,
      );
      await _recordingPause();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: buildMaatFlowTemplateDetailPreviewForTesting(
            templateKey: 'track-the-sky',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_expandedCards(), findsOneWidget);
      expect(
        find.descendant(of: _eventRows().first, matching: _expandedCards()),
        findsOneWidget,
      );
      await _recordingPause();
      expect(tester.takeException(), isNull);
    },
  );
}

Finder _eventTaps() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> &&
      key.value.startsWith('maat_flow_event_tap_');
});

Finder _eventRows() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> &&
      key.value.startsWith('maat_flow_event_row_');
});

Finder _expandedCards() => find.byWidgetPredicate(
  (widget) => widget.runtimeType.toString() == '_MyFlowDayContentCard',
);

Future<void> _reveal(WidgetTester tester, Finder target) async {
  final scrollable = find.ancestor(
    of: target,
    matching: find.byType(Scrollable),
  );
  final position = tester.state<ScrollableState>(scrollable).position;
  final viewport = tester.getRect(scrollable);
  final targetRect = tester.getRect(target);
  final pixels = (position.pixels + targetRect.top - viewport.top - 96).clamp(
    position.minScrollExtent,
    position.maxScrollExtent,
  );
  position.jumpTo(pixels);
  await tester.pumpAndSettle();
}

Future<void> _positionAtViewportBottom(
  WidgetTester tester,
  Finder target,
  Finder scrollable,
) async {
  final position = tester.state<ScrollableState>(scrollable).position;
  final viewport = tester.getRect(scrollable);
  final targetRect = tester.getRect(target);
  final pixels = (position.pixels + targetRect.bottom - viewport.bottom + 12)
      .clamp(position.minScrollExtent, position.maxScrollExtent);
  position.jumpTo(pixels);
  await tester.pumpAndSettle();
}

Future<void> _positionBlockFullyAbove(
  WidgetTester tester, {
  required Finder block,
  required Finder target,
  required Finder scrollable,
}) async {
  await _positionAtViewportBottom(tester, target, scrollable);
  final position = tester.state<ScrollableState>(scrollable).position;
  final viewport = tester.getRect(scrollable);
  final blockRect = tester.getRect(block);
  if (blockRect.bottom > viewport.top) {
    position.jumpTo(
      (position.pixels + blockRect.bottom - viewport.top + 1).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
    await tester.pumpAndSettle();
  }
  expect(tester.getRect(target).top, lessThan(viewport.bottom));
}

Future<void> _positionBlockBottom(
  WidgetTester tester, {
  required Finder block,
  required double screenY,
  required Finder scrollable,
}) async {
  final position = tester.state<ScrollableState>(scrollable).position;
  final blockRect = tester.getRect(block);
  position.jumpTo(
    (position.pixels + blockRect.bottom - screenY).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _recordingPause() =>
    Future<void>.delayed(const Duration(milliseconds: 600));

Future<void> _pumpFramesForRecording(
  WidgetTester tester, {
  required Finder trackedRow,
  required ScrollPosition position,
  required double expectedTop,
  double? expectedPixels,
  int frameCount = 28,
}) async {
  for (var frame = 0; frame < frameCount; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
    await Future<void>.delayed(const Duration(milliseconds: 16));
    expect(tester.getTopLeft(trackedRow).dy, closeTo(expectedTop, 1));
    if (expectedPixels != null) {
      expect(position.pixels, closeTo(expectedPixels, 0.01));
    }
  }
}
