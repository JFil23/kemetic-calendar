import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final saved in <bool>[false, true]) {
    testWidgets(
      '${saved ? 'Saved Flows' : 'My Flows'} pointer interaction stays anchored in both directions',
      (tester) async {
        await _pumpDetail(tester, saved: saved, longDetails: true);

        final flowId = saved ? 71 : 72;
        final firstInlineIndex = saved ? 1 : 3;
        final secondInlineIndex = firstInlineIndex + 1;
        final firstInline = _dayTap(
          '$flowId:preview-$flowId-$firstInlineIndex',
        );
        final secondInline = _dayTap(
          '$flowId:preview-$flowId-$secondInlineIndex',
        );

        await _revealWithPointer(tester, firstInline);
        expect(
          find.descendant(
            of: _dayRow('$flowId:preview-$flowId-$firstInlineIndex'),
            matching: _expandedCards(),
          ),
          findsNothing,
        );
        await tester.timedDrag(
          find.byType(Scrollable).first,
          const Offset(0, -80),
          const Duration(milliseconds: 240),
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: _dayRow('$flowId:preview-$flowId-$firstInlineIndex'),
            matching: _expandedCards(),
          ),
          findsNothing,
        );

        await _revealWithPointer(
          tester,
          firstInline,
          towardEndWhenVirtualized: false,
        );
        await _tapAndRequireAnchor(tester, firstInline);
        expect(
          find.descendant(
            of: _dayRow('$flowId:preview-$flowId-$firstInlineIndex'),
            matching: _expandedCards(),
          ),
          findsOneWidget,
        );

        await _revealWithPointer(tester, secondInline);
        await _tapAndRequireAnchor(tester, secondInline);
        expect(
          find.descendant(
            of: _dayRow('$flowId:preview-$flowId-$firstInlineIndex'),
            matching: _expandedCards(),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: _dayRow('$flowId:preview-$flowId-$secondInlineIndex'),
            matching: _expandedCards(),
          ),
          findsOneWidget,
        );

        await _revealWithPointer(
          tester,
          firstInline,
          towardEndWhenVirtualized: false,
        );
        await _tapAndRequireAnchor(tester, firstInline);
        expect(
          find.descendant(
            of: _dayRow('$flowId:preview-$flowId-$firstInlineIndex'),
            matching: _expandedCards(),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _dayRow('$flowId:preview-$flowId-$secondInlineIndex'),
            matching: _expandedCards(),
          ),
          findsNothing,
        );

        await _tapAndRequireAnchor(tester, firstInline);
        expect(
          find.descendant(
            of: _dayRow('$flowId:preview-$flowId-$firstInlineIndex'),
            matching: _expandedCards(),
          ),
          findsNothing,
        );

        final longIndex = 4;
        final longTap = _dayTap('$flowId:preview-$flowId-$longIndex');
        final longRow = _dayRow('$flowId:preview-$flowId-$longIndex');
        await _revealWithPointer(tester, longTap);
        await _tapAndRequireAnchor(tester, longTap);
        expect(
          find.descendant(of: longRow, matching: _expandedCards()),
          findsOneWidget,
        );
        await _revealBlockBottomWithPointer(tester, longRow);
        final viewport = tester.getRect(find.byType(Scrollable).first);
        expect(
          tester.getRect(longRow).bottom,
          lessThanOrEqualTo(viewport.bottom),
        );
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await _pumpDetail(
          tester,
          saved: saved,
          longDetails: true,
          previewKey: ValueKey<String>('reentered-$saved'),
        );
        await _revealWithPointer(tester, firstInline);
        expect(
          find.descendant(
            of: _dayRow('$flowId:preview-$flowId-$firstInlineIndex'),
            matching: _expandedCards(),
          ),
          findsNothing,
        );
      },
    );
  }
}

Finder _dayTap(String key) =>
    find.byKey(ValueKey<String>('my_flow_day_tap_$key'));

Finder _dayRow(String key) =>
    find.byKey(ValueKey<String>('my_flow_day_row_$key'));

Finder _expandedCards() => find.byWidgetPredicate(
  (widget) => widget.runtimeType.toString() == '_MyFlowDayContentCard',
);

Future<void> _pumpDetail(
  WidgetTester tester, {
  required bool saved,
  required bool longDetails,
  Key? previewKey,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: buildMyFlowDetailPreviewForTesting(
        saved: saved,
        longDetails: longDetails,
        previewKey: previewKey,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapAndRequireAnchor(WidgetTester tester, Finder target) async {
  final before = tester.getTopLeft(target).dy;
  await tester.tap(target);
  for (var frame = 0; frame < 20; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      tester.getTopLeft(target).dy,
      closeTo(before, 1.0),
      reason: 'the tapped row moved during frame $frame',
    );
  }
  await tester.pumpAndSettle();
  expect(tester.getTopLeft(target).dy, closeTo(before, 1.0));
}

Future<void> _revealWithPointer(
  WidgetTester tester,
  Finder target, {
  bool towardEndWhenVirtualized = true,
}) async {
  final scrollable = find.byType(Scrollable).first;
  for (var step = 0; step < 48; step++) {
    final viewport = tester.getRect(scrollable);
    if (target.evaluate().isNotEmpty) {
      final rect = tester.getRect(target);
      if (rect.top >= viewport.top + 8 && rect.bottom <= viewport.bottom - 8) {
        return;
      }
      await tester.timedDrag(
        scrollable,
        Offset(0, rect.top < viewport.top ? 220 : -220),
        const Duration(milliseconds: 240),
      );
    } else {
      await tester.timedDrag(
        scrollable,
        Offset(0, towardEndWhenVirtualized ? -220 : 220),
        const Duration(milliseconds: 240),
      );
    }
    await tester.pumpAndSettle();
  }
  fail('Could not reveal ${target.describeMatch(Plurality.one)}.');
}

Future<void> _revealBlockBottomWithPointer(
  WidgetTester tester,
  Finder block,
) async {
  final scrollable = find.byType(Scrollable).first;
  for (var step = 0; step < 72; step++) {
    final viewport = tester.getRect(scrollable);
    if (block.evaluate().isNotEmpty) {
      final rect = tester.getRect(block);
      if (rect.bottom > viewport.top && rect.bottom <= viewport.bottom) return;
    }
    await tester.timedDrag(
      scrollable,
      const Offset(0, -220),
      const Duration(milliseconds: 240),
    );
    await tester.pumpAndSettle();
  }
  fail('Could not reach the expanded long-card bottom.');
}
