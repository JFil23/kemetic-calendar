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
    'record stable multi-expansion, manual collapse, and page reset',
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
      await _positionAtViewportBottom(tester, secondRow, scrollable);

      final secondTop = tester.getTopLeft(secondRow).dy;
      final secondPixels = position.pixels;
      await tester.tap(secondTap);
      await _pumpFramesForRecording(
        tester,
        trackedRow: secondRow,
        position: position,
        expectedTop: secondTop,
        expectedPixels: secondPixels,
      );
      expect(_expandedCards(), findsNWidgets(2));
      await _recordingPause();

      final viewport = tester.getRect(scrollable);
      for (
        var step = 0;
        step < 16 && tester.getRect(firstRow).bottom > viewport.top;
        step++
      ) {
        await tester.timedDrag(
          scrollable,
          const Offset(0, -180),
          const Duration(milliseconds: 320),
        );
        await tester.pumpAndSettle();
      }
      expect(tester.getRect(firstRow).bottom, lessThanOrEqualTo(viewport.top));
      expect(
        find.descendant(of: firstRow, matching: _expandedCards()),
        findsOneWidget,
        reason: 'off-screen cards stay expanded until the user closes them',
      );
      expect(_expandedCards(), findsNWidgets(2));
      await _recordingPause();

      final longRow = rows.at(7);
      final longTap = taps.at(7);
      await _positionAtViewportBottom(tester, longRow, scrollable);
      final longTop = tester.getTopLeft(longRow).dy;
      final longPixels = position.pixels;
      await tester.tap(longTap);
      await _pumpFramesForRecording(
        tester,
        trackedRow: longRow,
        position: position,
        expectedTop: longTop,
        expectedPixels: longPixels,
      );
      expect(_expandedCards(), findsNWidgets(3));
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
      expect(_expandedCards(), findsNWidgets(2));
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
      expect(_expandedCards(), findsNWidgets(3));
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
      expect(_expandedCards(), findsNWidgets(3));
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

Future<void> _recordingPause() =>
    Future<void>.delayed(const Duration(milliseconds: 600));

Future<void> _pumpFramesForRecording(
  WidgetTester tester, {
  required Finder trackedRow,
  required ScrollPosition position,
  required double expectedTop,
  required double expectedPixels,
  int frameCount = 28,
}) async {
  for (var frame = 0; frame < frameCount; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
    await Future<void>.delayed(const Duration(milliseconds: 16));
    expect(tester.getTopLeft(trackedRow).dy, closeTo(expectedTop, 1));
    expect(position.pixels, closeTo(expectedPixels, 0.01));
  }
}
