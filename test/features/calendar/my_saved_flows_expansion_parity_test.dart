import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';

void main() {
  test('My Flows and Saved Flows share one detail accordion authority', () {
    final source = File(
      'lib/features/calendar/calendar_flow_pages.dart',
    ).readAsStringSync();

    expect(source, contains('FlowListTab _tab = FlowListTab.active;'));
    expect(
      source,
      contains(
        'final mode = _tab == FlowListTab.active\n'
        '        ? _FlowPreviewMode.active\n'
        '        : _FlowPreviewMode.saved;',
      ),
    );
    expect(source, contains('builder: (_) => _FlowPreviewPage('));
    expect(source, contains('useMySavedExpansionParity: true'));
    expect(source, contains('Widget _buildDashboardExpandableRow({'));
    expect(
      source,
      contains('final List<String> _expandedDayKeys = <String>[];'),
    );
    expect(source, contains('_seedDashboardExpansion('));
    expect(source, contains('..add(hero.key);'));
    expect(source, isNot(contains('class _SavedFlowPreviewPage')));
  });

  test('parity authority never initiates automatic scrolling', () {
    final source = File(
      'lib/features/calendar/calendar_flow_pages.dart',
    ).readAsStringSync();
    final start = source.indexOf('  void _handleDashboardDayTap({');
    final end = source.indexOf('\n  @override\n  Widget build(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final authority = source.substring(start, end);

    expect(authority, isNot(contains('ensureVisible')));
    expect(authority, isNot(contains('animateTo')));
    expect(authority, isNot(contains('jumpTo')));
    expect(authority, isNot(contains('Timer')));
    expect(authority, contains('position.correctBy(-removedHeightAbove)'));
  });

  for (final saved in <bool>[false, true]) {
    testWidgets(
      '${saved ? 'Saved Flows' : 'My Flows'} starts with one lead expansion and never exceeds two cards',
      (tester) async {
        await _pumpDetail(tester, saved: saved);
        final flowId = saved ? 71 : 72;
        final leadIndex = saved ? 0 : 2;
        final firstInlineIndex = saved ? 1 : 3;
        final secondInlineIndex = firstInlineIndex + 1;
        final firstInline = _dayTap(
          '$flowId:preview-$flowId-$firstInlineIndex',
        );
        await _reveal(tester, firstInline);
        expect(_expandedCards(), findsOneWidget);
        await tester.tap(firstInline);
        await tester.pumpAndSettle();
        expect(_expandedCards(), findsNWidgets(2));

        final secondInline = _dayTap(
          '$flowId:preview-$flowId-$secondInlineIndex',
        );
        await _reveal(tester, secondInline);
        await tester.tap(secondInline);
        await tester.pumpAndSettle();

        expect(_expandedCards(), findsNWidgets(2));
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
          findsOneWidget,
        );
        final leadTap = _dayTap('$flowId:preview-$flowId-$leadIndex');
        await _reveal(tester, leadTap, towardEndWhenVirtualized: false);
        expect(
          find.descendant(
            of: _dayRow('$flowId:preview-$flowId-$leadIndex'),
            matching: _expandedCards(),
          ),
          findsNothing,
        );
      },
    );
  }

  testWidgets('Today lead and Upcoming rows share one global two-event queue', (
    tester,
  ) async {
    await _pumpDetail(tester, physicalQueueTitles: true);
    const leadKey = '72:preview-72-2';
    const mindfulnessKey = '72:preview-72-4';
    const mealsKey = '72:preview-72-5';
    final leadTap = _dayTap(leadKey);
    final mindfulness = _dayTap(mindfulnessKey);
    final meals = _dayTap(mealsKey);

    await _reveal(tester, leadTap);
    expect(find.text('Limit Screen Time'), findsOneWidget);
    expect(_expandedCards(), findsOneWidget);
    expect(
      find.descendant(of: _dayRow(leadKey), matching: _expandedCards()),
      findsOneWidget,
    );

    await _reveal(tester, mindfulness);
    await tester.tap(mindfulness);
    await tester.pumpAndSettle();
    expect(_expandedCards(), findsNWidgets(2));

    await _reveal(tester, meals);
    final anchoredY = tester.getTopLeft(meals).dy;
    await tester.tap(meals);
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        _expandedCards().evaluate().length,
        lessThanOrEqualTo(2),
        reason: 'the complete page exceeded two cards at frame $frame',
      );
      expect(
        tester.getTopLeft(meals).dy,
        closeTo(anchoredY, 1.0),
        reason: 'the tapped Upcoming row moved at frame $frame',
      );
    }
    await tester.pumpAndSettle();

    expect(_expandedCards(), findsNWidgets(2));
    expect(
      find.descendant(of: _dayRow(leadKey), matching: _expandedCards()),
      findsNothing,
    );
    expect(
      find.descendant(of: _dayRow(mindfulnessKey), matching: _expandedCards()),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _dayRow(mealsKey), matching: _expandedCards()),
      findsOneWidget,
    );

    await _reveal(tester, leadTap, towardEndWhenVirtualized: false);
    expect(find.text('Limit Screen Time'), findsOneWidget);
    expect(
      find.descendant(of: _dayRow(leadKey), matching: _expandedCards()),
      findsNothing,
      reason: 'Limit Screen Time must remain retired after scrolling back',
    );
  });

  testWidgets('Saved Flows replacement keeps the tapped row anchored', (
    tester,
  ) async {
    await _pumpDetail(tester, saved: true);

    final second = _dayTap('71:preview-71-1');
    await _reveal(tester, second);
    await tester.tap(second);
    await tester.pumpAndSettle();

    final third = _dayTap('71:preview-71-2');
    await _reveal(tester, third);
    final before = tester.getTopLeft(third).dy;

    await tester.tap(third);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(third).dy,
      closeTo(before, 1.0),
      reason: 'replacing the prior expanded row must not move the tapped row',
    );
  });

  testWidgets('My Flows replacement keeps the tapped row anchored', (
    tester,
  ) async {
    await _pumpDetail(tester);

    final fourth = _dayTap('72:preview-72-3');
    await _reveal(tester, fourth);
    await tester.tap(fourth);
    await tester.pumpAndSettle();

    final fifth = _dayTap('72:preview-72-4');
    await _reveal(tester, fifth);
    final before = tester.getTopLeft(fifth).dy;

    await tester.tap(fifth);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(fifth).dy,
      closeTo(before, 1.0),
      reason: 'active-flow replacement must preserve the tapped coordinate',
    );
  });

  testWidgets('manual collapse changes only the tapped card in place', (
    tester,
  ) async {
    await _pumpDetail(tester, saved: true);
    final second = _dayTap('71:preview-71-1');
    await _reveal(tester, second);
    await tester.tap(second);
    await tester.pumpAndSettle();
    expect(_expandedCards(), findsNWidgets(2));
    final before = tester.getTopLeft(second).dy;

    await tester.tap(second);
    await tester.pumpAndSettle();

    expect(_expandedCards(), findsOneWidget);
    expect(tester.getTopLeft(second).dy, closeTo(before, 1.0));
  });

  testWidgets('reverse-direction replacement remains anchored', (tester) async {
    await _pumpDetail(tester, saved: true);
    final fifth = _dayTap('71:preview-71-4');
    await _reveal(tester, fifth);
    await tester.tap(fifth);
    await tester.pumpAndSettle();

    final second = _dayTap('71:preview-71-1');
    await _reveal(tester, second);
    final before = tester.getTopLeft(second).dy;
    await tester.tap(second);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(second).dy, closeTo(before, 1.0));
    expect(
      find.descendant(
        of: _dayRow('71:preview-71-1'),
        matching: _expandedCards(),
      ),
      findsOneWidget,
    );
    await _reveal(tester, fifth);
    expect(
      find.descendant(
        of: _dayRow('71:preview-71-4'),
        matching: _expandedCards(),
      ),
      findsOneWidget,
    );
    expect(_expandedCards().evaluate().length, lessThanOrEqualTo(2));
  });

  testWidgets('scrolling alone does not change expansion authority', (
    tester,
  ) async {
    await _pumpDetail(tester, saved: true);
    final second = _dayTap('71:preview-71-1');
    await _reveal(tester, second);
    await tester.tap(second);
    await tester.pumpAndSettle();
    expect(_expandedCards(), findsNWidgets(2));

    await tester.drag(find.byType(ListView).first, const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(_expandedCards(), findsNWidgets(2));
    expect(
      find.descendant(
        of: _dayRow('71:preview-71-1'),
        matching: _expandedCards(),
      ),
      findsOneWidget,
    );
  });

  testWidgets('switching flows resets to only the new lead expansion', (
    tester,
  ) async {
    await _pumpDetail(tester, saved: true, includeSecondFlow: true);
    final second = _dayTap('71:preview-71-1');
    await _reveal(tester, second);
    await tester.tap(second);
    await tester.pumpAndSettle();
    expect(_expandedCards(), findsNWidgets(2));

    await tester.drag(find.byType(PageView), const Offset(-390, 0));
    await tester.pumpAndSettle();

    expect(find.text('Second Saved Template'), findsOneWidget);
    expect(_expandedCards(), findsOneWidget);
  });

  testWidgets('re-entry and independent page lifetimes cannot leak state', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      saved: true,
      previewKey: const ValueKey<String>('account-a-flow-71'),
    );
    final second = _dayTap('71:preview-71-1');
    await _reveal(tester, second);
    await tester.tap(second);
    await tester.pumpAndSettle();
    expect(_expandedCards(), findsNWidgets(2));

    await _pumpDetail(
      tester,
      saved: true,
      previewKey: const ValueKey<String>('account-b-flow-71'),
    );
    expect(_expandedCards(), findsOneWidget);
  });

  testWidgets('empty and one-event flows remain safe', (tester) async {
    await _pumpDetail(
      tester,
      saved: true,
      eventCount: 0,
      previewKey: const ValueKey<String>('empty-flow-preview'),
    );
    expect(find.text('No days or notes for this flow yet.'), findsOneWidget);
    expect(_expandedCards(), findsNothing);
    expect(tester.takeException(), isNull);

    await _pumpDetail(
      tester,
      saved: true,
      eventCount: 1,
      previewKey: const ValueKey<String>('one-event-flow-preview'),
    );
    expect(_expandedCards(), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('my_flow_day_card_71:preview-71-0')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('long expanded details remain reachable above the action panel', (
    tester,
  ) async {
    await _pumpDetail(tester, saved: true, longDetails: true);
    final fifth = _dayTap('71:preview-71-4');
    await _reveal(tester, fifth);
    await tester.tap(fifth);
    await tester.pumpAndSettle();

    final tail = find.byWidgetPredicate(
      (widget) =>
          widget is RichText &&
          widget.text.toPlainText().contains('LONG DETAIL TAIL IS REACHABLE'),
    );
    await _revealBottom(tester, tail);
    final listRect = tester.getRect(find.byType(ListView).first);
    final tailRect = tester.getRect(tail);
    expect(tailRect.bottom, greaterThan(listRect.top));
    expect(tailRect.bottom, lessThanOrEqualTo(listRect.bottom));
    expect(find.text('Import Flow'), findsOneWidget);
  });
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
  bool saved = false,
  bool longDetails = false,
  bool physicalQueueTitles = false,
  bool includeSecondFlow = false,
  int eventCount = 6,
  Key? previewKey,
}) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: buildMyFlowDetailPreviewForTesting(
        saved: saved,
        longDetails: longDetails,
        physicalQueueTitles: physicalQueueTitles,
        includeSecondFlow: includeSecondFlow,
        eventCount: eventCount,
        previewKey: previewKey,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _reveal(
  WidgetTester tester,
  Finder target, {
  bool towardEndWhenVirtualized = true,
}) async {
  final list = find.byType(ListView).first;
  final viewport = tester.getRect(list);
  for (var i = 0; i < 36; i++) {
    final matches = target.evaluate();
    if (matches.isNotEmpty) {
      final rect = tester.getRect(target);
      if (rect.top >= viewport.top + 8 && rect.bottom <= viewport.bottom - 8) {
        return;
      }
      final direction = rect.top < viewport.top ? 280.0 : -280.0;
      await tester.drag(list, Offset(0, direction));
    } else {
      await tester.drag(list, Offset(0, towardEndWhenVirtualized ? -280 : 280));
    }
    await tester.pumpAndSettle();
  }
  fail('Could not reveal ${target.describeMatch(Plurality.one)}.');
}

Future<void> _revealBottom(WidgetTester tester, Finder target) async {
  final list = find.byType(ListView).first;
  final viewport = tester.getRect(list);
  for (var i = 0; i < 60; i++) {
    final matches = target.evaluate();
    if (matches.isNotEmpty) {
      final rect = tester.getRect(target);
      if (rect.bottom > viewport.top && rect.bottom <= viewport.bottom) {
        return;
      }
    }
    await tester.drag(list, const Offset(0, -280));
    await tester.pumpAndSettle();
  }
  fail(
    'Could not reveal the bottom of ${target.describeMatch(Plurality.one)}.',
  );
}
