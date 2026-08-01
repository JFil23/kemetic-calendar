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
      await binding.takeScreenshot('${capture.$2}-collapsed');

      await tester.tap(tap);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('${capture.$2}-expanded');
      expect(tester.takeException(), isNull);
    }
  });
}

Finder _eventTaps() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> &&
      key.value.startsWith('maat_flow_event_tap_');
});

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
