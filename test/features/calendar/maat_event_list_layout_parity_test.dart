import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:mobile/features/calendar/maat_flow_visual_tokens.dart';

void main() {
  test('Ma’at cleanup is bounded to an idle opening tap', () {
    final source = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();
    final expansionSource = source.substring(
      source.indexOf('Widget _buildExpandableFlowEventTile'),
      source.indexOf('_MyFlowCardPalette _maatEventCardPalette'),
    );

    expect(source, contains('final Set<String> _expandedMaatEventKeys'));
    expect(
      source,
      contains('final Map<String, GlobalKey> _maatEventBlockKeys'),
    );
    expect(
      source,
      contains('final Map<String, GlobalKey> _maatEventDetailKeys'),
    );
    expect(
      expansionSource,
      contains('_expandedMaatEventKeys.remove(eventKey)'),
    );
    expect(expansionSource, contains('_expandedMaatEventKeys.add(eventKey)'));
    expect(expansionSource, contains('_offscreenMaatEventsForTap'));
    expect(expansionSource, contains('tapStartedWhileScrolling'));
    expect(expansionSource, contains('isScrollingNotifier.value'));
    expect(expansionSource, contains('blockRect.bottom <= viewportRect.top'));
    expect(expansionSource, contains('blockRect.top >= viewportRect.bottom'));
    expect(
      RegExp(r'correctBy\(').allMatches(expansionSource).length,
      1,
      reason: 'only the synchronous tap-time anchor correction is allowed',
    );
    for (final forbidden in <String>[
      'ensureVisible',
      'animateTo',
      'jumpTo(',
      'ScrollController',
      'addPostFrameCallback',
      'Timer(',
      'Future.delayed',
      'RenderAbstractViewport',
      'ScrollNotification',
      'addListener(',
    ]) {
      expect(
        expansionSource,
        isNot(contains(forbidden)),
        reason: 'Ma’at expansion must not use $forbidden',
      );
    }
    expect(source, isNot(contains('_outgoingExpandedMaatEventKey')));
    expect(source, isNot(contains('_maatEventRetirement')));
  });

  testWidgets('all 33 Ma’at details use tap-bounded multi-expansion state', (
    tester,
  ) async {
    for (final entry in _expectedAccents.entries) {
      // Follow the Sky V2 replaces expandable Ma’at event rows with its own
      // Course / Next Turning surface — assert that path separately below.
      if (entry.key == 'track-the-sky') continue;

      await _pumpFlow(tester, entry.key);

      final rows = _eventRows();
      final taps = _eventTaps();
      expect(rows, findsWidgets, reason: '${entry.key} needs event rows');
      expect(
        taps.evaluate().length,
        rows.evaluate().length,
        reason: '${entry.key} should use one shared tap target per row',
      );

      final ink = tester.widget<InkWell>(taps.first);
      expect(
        ink.splashColor,
        entry.value.withValues(alpha: 0.05),
        reason: '${entry.key} must retain its contextual Ma’at accent',
      );
      expect(
        find.descendant(of: rows.first, matching: find.byType(ExpansionTile)),
        findsNothing,
      );
      final expandedCards = _expandedCards();
      expect(
        expandedCards,
        findsOneWidget,
        reason: '${entry.key} should open its first event',
      );
      expect(
        find.descendant(of: rows.first, matching: expandedCards),
        findsOneWidget,
        reason: '${entry.key} should expand only its first event',
      );
      for (final laterRow in rows.evaluate().skip(1)) {
        expect(
          find.descendant(
            of: find.byWidget(laterRow.widget),
            matching: expandedCards,
          ),
          findsNothing,
          reason: '${entry.key} later events should begin collapsed',
        );
      }

      final secondRow = rows.at(1);
      final secondTap = taps.at(1);
      final scrollable = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(scrollable).position;
      await _positionAtViewportBottom(tester, secondRow, scrollable);
      final beforePixels = position.pixels;
      final beforeTop = tester.getTopLeft(secondRow).dy;
      final viewport = tester.getRect(scrollable);
      final firstWasVisible = tester.getRect(rows.first).overlaps(viewport);

      await tester.tap(secondTap);
      await tester.pumpAndSettle();

      expect(
        _expandedCards(),
        findsNWidgets(firstWasVisible ? 2 : 1),
        reason:
            '${entry.key} should retain only expanded blocks that remain visible',
      );
      if (firstWasVisible) {
        expect(position.pixels, closeTo(beforePixels, 0.01));
      }
      expect(tester.getTopLeft(secondRow).dy, closeTo(beforeTop, 0.01));
      expect(
        find.descendant(of: rows.first, matching: _expandedCards()),
        firstWasVisible ? findsOneWidget : findsNothing,
      );
      expect(
        find.descendant(of: secondRow, matching: _expandedCards()),
        findsOneWidget,
      );

      await tester.tap(secondTap);
      await tester.pumpAndSettle();
      expect(_expandedCards(), findsNWidgets(firstWasVisible ? 1 : 0));
      expect(tester.takeException(), isNull, reason: entry.key);
    }
  });

  testWidgets('Follow the Sky V2 uses Ma’at shell with Course and Next Turning', (
    tester,
  ) async {
    await _pumpFlow(tester, 'track-the-sky');

    expect(find.byType(FollowSkyDetailPage), findsOneWidget);
    expect(_eventRows(), findsNothing);
    expect(find.byKey(kMaatFlowInitialPromptSectionKey), findsNothing);
    expect(find.text('ONE THING TO CARRY'), findsOneWidget);
    expect(find.text('NEXT TURNING'), findsOneWidget);
    expect(find.text('Join Flow'), findsOneWidget);
    expect(
      find.text("Sky · Track the year's astronomical events in Kemetic time"),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'first Ma’at event content is visible immediately without a tap',
    (tester) async {
      await _pumpFlow(tester, 'the-weighing');

      final firstRow = _eventRows().first;
      final card = find.descendant(of: firstRow, matching: _expandedCards());
      expect(card, findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.text('Weighing 1: Open the Material Ledger'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('DAY 1')),
        findsOneWidget,
      );
    },
  );

  testWidgets('Ma’at rows and expanded cards use My Flows geometry', (
    tester,
  ) async {
    await _pumpFlow(tester, 'the-weighing');

    final firstRow = _eventRows().first;
    final firstTap = _eventTaps().first;
    final rowTexts = tester
        .widgetList<Text>(
          find.descendant(of: firstRow, matching: find.byType(Text)),
        )
        .toList(growable: false);
    final day = rowTexts.firstWhere((text) => text.data == 'DAY\n1');
    const firstTitle = 'Weighing 1: Open the Material Ledger';
    final title = rowTexts.firstWhere((text) => text.data == firstTitle);
    final metadata = rowTexts.firstWhere(
      (text) => text.data?.contains('30 minutes after dawn') ?? false,
    );

    expect(day.style?.fontSize, 12);
    expect(day.style?.letterSpacing, 2.2);
    expect(title.maxLines, 2);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(title.style?.fontFamily, MaatFlowListTokens.fontFamily);
    expect(title.style?.fontSize, 22);
    expect(title.style?.fontStyle, FontStyle.italic);
    expect(metadata.maxLines, 1);
    expect(metadata.style?.fontSize, 15);
    expect(
      tester
          .widgetList<SizedBox>(
            find.ancestor(
              of: find.text('DAY\n1'),
              matching: find.byType(SizedBox),
            ),
          )
          .any((box) => box.width == 82),
      isTrue,
    );
    final card = _expandedCards();
    expect(card, findsOneWidget);
    expect(tester.getSize(card).width, tester.getSize(firstRow).width);
    final cardTexts = tester
        .widgetList<Text>(
          find.descendant(of: card, matching: find.byType(Text)),
        )
        .toList(growable: false);
    expect(cardTexts[0].data, 'DAY 1');
    expect(cardTexts[0].style?.fontSize, 13);
    expect(cardTexts[0].style?.letterSpacing, 3.1);
    expect(cardTexts[1].data, firstTitle);
    expect(cardTexts[1].maxLines, isNull);
    expect(cardTexts[1].style?.fontSize, 30);
    expect(cardTexts[2].style?.fontSize, 17);
    expect(cardTexts[2].style?.fontStyle, FontStyle.italic);

    final cardContainers = tester.widgetList<Container>(
      find.descendant(of: card, matching: find.byType(Container)),
    );
    expect(
      cardContainers.any(
        (container) =>
            container.decoration is BoxDecoration &&
            (container.decoration! as BoxDecoration).borderRadius ==
                BorderRadius.circular(20),
      ),
      isTrue,
    );
    expect(
      cardContainers.any(
        (container) =>
            container.constraints?.minWidth == 4 &&
            container.constraints?.maxWidth == 4 &&
            container.color == const Color(0xFFB8A88A).withValues(alpha: 0.58),
      ),
      isTrue,
    );
    expect(
      tester
          .widgetList<Padding>(
            find.descendant(of: card, matching: find.byType(Padding)),
          )
          .any(
            (padding) =>
                padding.padding == const EdgeInsets.fromLTRB(28, 28, 24, 28),
          ),
      isTrue,
    );
    expect(
      cardTexts.any(
        (text) => text.style?.fontSize == 22 && text.maxLines == null,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);

    await _reveal(tester, firstTap);
    await tester.tap(firstTap);
    await tester.pumpAndSettle();
    expect(_expandedCards(), findsNothing);

    await tester.tap(firstTap);
    await tester.pumpAndSettle();
    expect(_expandedCards(), findsOneWidget);
  });

  testWidgets(
    'idle opening collapses a fully off-screen block and anchors the tapped row',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpFlow(tester, 'the-offering-table');

      final rows = _eventRows();
      final taps = _eventTaps();
      final firstRow = rows.at(0);
      final lowerRow = rows.at(5);
      final lowerTap = taps.at(5);
      final scrollable = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(scrollable).position;

      await _positionBlockFullyAbove(
        tester,
        block: firstRow,
        target: lowerRow,
        scrollable: scrollable,
      );
      final viewport = tester.getRect(scrollable);
      expect(tester.getRect(firstRow).bottom, lessThanOrEqualTo(viewport.top));
      final beforeLowerTop = tester.getTopLeft(lowerRow).dy;
      final beforePixels = position.pixels;

      await tester.tap(lowerTap);
      await tester.pump();
      final lowerOpening = await _sampleMotion(
        tester,
        position: position,
        trackedRow: lowerRow,
      );

      expect(_expandedCards(), findsOneWidget);
      expect(
        find.descendant(of: firstRow, matching: _expandedCards()),
        findsNothing,
      );
      expect(
        find.descendant(of: lowerRow, matching: _expandedCards()),
        findsOneWidget,
      );
      expect(position.pixels, lessThan(beforePixels));
      expect(position.isScrollingNotifier.value, isFalse);
      expect(
        lowerOpening.map((sample) => sample.rowTop),
        everyElement(closeTo(beforeLowerTop, 0.1)),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a partially visible expanded block remains open on the next opening tap',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpFlow(tester, 'the-offering-table');
      final rows = _eventRows();
      final taps = _eventTaps();
      final firstRow = rows.at(0);
      final secondRow = rows.at(1);
      final scrollable = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(scrollable).position;
      final viewport = tester.getRect(scrollable);

      await _positionBlockBottom(
        tester,
        block: firstRow,
        screenY: viewport.top + 1,
        scrollable: scrollable,
      );
      expect(tester.getRect(firstRow).bottom, greaterThan(viewport.top));
      expect(tester.getRect(firstRow).top, lessThan(viewport.top));
      expect(tester.getRect(secondRow).top, lessThan(viewport.bottom));
      final beforePixels = position.pixels;
      final beforeSecondTop = tester.getTopLeft(secondRow).dy;

      await tester.tap(taps.at(1));
      await tester.pump();
      final opening = await _sampleMotion(
        tester,
        position: position,
        trackedRow: secondRow,
      );

      expect(_expandedCards(), findsNWidgets(2));
      expect(
        find.descendant(of: firstRow, matching: _expandedCards()),
        findsOneWidget,
      );
      expect(position.pixels, closeTo(beforePixels, 0.01));
      expect(
        opening.map((sample) => sample.rowTop),
        everyElement(closeTo(beforeSecondTop, 0.1)),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an off-screen expanded block below collapses without offset correction',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpFlow(tester, 'the-offering-table');
      final rows = _eventRows();
      final taps = _eventTaps();
      final firstRow = rows.at(0);
      final lowerRow = rows.at(8);
      final scrollable = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(scrollable).position;

      await _positionBlockFullyAbove(
        tester,
        block: firstRow,
        target: lowerRow,
        scrollable: scrollable,
      );
      await tester.tap(taps.at(8));
      await tester.pumpAndSettle();
      expect(_expandedCards(), findsOneWidget);
      expect(
        find.descendant(of: lowerRow, matching: _expandedCards()),
        findsOneWidget,
      );

      await _reveal(tester, firstRow);
      expect(
        tester.getRect(lowerRow).top,
        greaterThanOrEqualTo(tester.getRect(scrollable).bottom),
      );
      final beforePixels = position.pixels;
      final beforeFirstTop = tester.getTopLeft(firstRow).dy;

      await tester.tap(taps.at(0));
      await tester.pump();
      final opening = await _sampleMotion(
        tester,
        position: position,
        trackedRow: firstRow,
      );

      expect(_expandedCards(), findsOneWidget);
      expect(
        find.descendant(of: lowerRow, matching: _expandedCards()),
        findsNothing,
      );
      expect(position.pixels, closeTo(beforePixels, 0.01));
      expect(
        opening.map((sample) => sample.rowTop),
        everyElement(closeTo(beforeFirstTop, 0.1)),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a tap begun during scroll opens without cleanup until a later idle tap',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpFlow(tester, 'the-offering-table');
      final rows = _eventRows();
      final taps = _eventTaps();
      final firstRow = rows.at(0);
      final lowerRow = rows.at(5);
      final lowerTap = taps.at(5);
      final scrollable = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(scrollable).position;

      await _positionBlockFullyAbove(
        tester,
        block: firstRow,
        target: lowerRow,
        scrollable: scrollable,
      );
      unawaited(
        position.animateTo(
          position.pixels + 6,
          duration: const Duration(milliseconds: 400),
          curve: Curves.linear,
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(position.isScrollingNotifier.value, isTrue);
      final pointerListener = tester.widget<Listener>(
        find.ancestor(of: lowerTap, matching: find.byType(Listener)).first,
      );
      pointerListener.onPointerDown!(const PointerDownEvent());
      position.jumpTo(position.pixels);
      tester.widget<InkWell>(lowerTap).onTap!();
      await tester.pumpAndSettle();

      expect(_expandedCards(), findsNWidgets(2));
      expect(
        find.descendant(of: firstRow, matching: _expandedCards()),
        findsOneWidget,
        reason: 'the tap that began during motion must not run cleanup',
      );
      expect(
        find.descendant(of: lowerRow, matching: _expandedCards()),
        findsOneWidget,
      );

      final idleRow = rows.at(6);
      await _positionBlockFullyAbove(
        tester,
        block: lowerRow,
        target: idleRow,
        scrollable: scrollable,
      );
      final idleTop = tester.getTopLeft(idleRow).dy;
      await tester.tap(taps.at(6));
      await tester.pumpAndSettle();

      expect(_expandedCards(), findsOneWidget);
      expect(
        find.descendant(of: idleRow, matching: _expandedCards()),
        findsOneWidget,
      );
      expect(tester.getTopLeft(idleRow).dy, closeTo(idleTop, 0.1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rapid multi-expansion persists and manual collapse changes one card',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 9000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpFlow(tester, 'the-offering-table');

      final rows = _eventRows();
      final taps = _eventTaps();
      final scrollable = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(scrollable).position;

      for (var index = 1; index <= 3; index++) {
        await tester.tap(taps.at(index));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();

      expect(_expandedCards(), findsNWidgets(4));
      for (var index = 0; index <= 3; index++) {
        expect(
          find.descendant(of: rows.at(index), matching: _expandedCards()),
          findsOneWidget,
        );
      }

      final collapsedRow = rows.at(2);
      final beforePixels = position.pixels;
      final beforeTop = tester.getTopLeft(collapsedRow).dy;
      await tester.tap(taps.at(2));
      await tester.pump();
      final collapse = await _sampleMotion(
        tester,
        position: position,
        trackedRow: collapsedRow,
      );

      expect(_expandedCards(), findsNWidgets(3));
      expect(
        find.descendant(of: collapsedRow, matching: _expandedCards()),
        findsNothing,
      );
      for (final index in <int>[0, 1, 3]) {
        expect(
          find.descendant(of: rows.at(index), matching: _expandedCards()),
          findsOneWidget,
        );
      }
      expect(
        collapse.map((sample) => sample.pixels),
        everyElement(closeTo(beforePixels, 0.01)),
      );
      expect(
        collapse.map((sample) => sample.rowTop),
        everyElement(closeTo(beforeTop, 0.1)),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('leaving and reopening resets to only the first event', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 9000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpFlow(tester, 'the-offering-table');

    for (final index in <int>[1, 2]) {
      final tap = _eventTaps().at(index);
      await _reveal(tester, tap);
      await tester.tap(tap);
      await tester.pumpAndSettle();
    }
    expect(_expandedCards(), findsNWidgets(3));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await _pumpFlow(tester, 'the-offering-table');

    expect(_expandedCards(), findsOneWidget);
    expect(
      find.descendant(of: _eventRows().first, matching: _expandedCards()),
      findsOneWidget,
    );
    for (final laterRow in _eventRows().evaluate().skip(1)) {
      expect(
        find.descendant(
          of: find.byWidget(laterRow.widget),
          matching: _expandedCards(),
        ),
        findsNothing,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('long expanded cards remain reachable above Join Flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpFlow(tester, 'the-offering-table');

    final row = _eventRows().at(7);
    final tap = _eventTaps().at(7);
    final scrollable = find.byType(Scrollable).first;
    final position = tester.state<ScrollableState>(scrollable).position;
    await _positionAtViewportBottom(tester, row, scrollable);
    final anchoredTop = tester.getTopLeft(row).dy;

    await tester.tap(tap);
    await tester.pump();
    final opening = await _sampleMotion(
      tester,
      position: position,
      trackedRow: row,
    );
    expect(_expandedCards(), findsOneWidget);
    expect(position.isScrollingNotifier.value, isFalse);
    expect(
      opening.map((sample) => sample.rowTop),
      everyElement(closeTo(anchoredTop, 0.1)),
    );

    final card = find.descendant(of: row, matching: _expandedCards());
    final viewport = tester.getRect(scrollable);
    expect(tester.getSize(card).height, greaterThan(viewport.height * 0.75));
    final cardRect = tester.getRect(card);
    final revealCardBottom =
        position.pixels + cardRect.bottom - viewport.bottom + 8;
    position.jumpTo(
      revealCardBottom.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final bottomCta = find.byWidget(scaffold.bottomNavigationBar!);
    expect(tester.getRect(card).bottom, lessThanOrEqualTo(viewport.bottom - 7));
    expect(tester.getRect(card).bottom, greaterThan(viewport.top));
    expect(
      tester.getRect(bottomCta).top,
      greaterThanOrEqualTo(viewport.bottom),
    );
    expect(_expandedCards(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow layouts wrap full event copy and preserve the lead-in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpFlow(tester, 'the-weighing');
    const overview =
        'The Weighing is a thirty-day Ma’at reckoning flow with nine sittings '
        'across material records, spoken records, and conduct. It asks the user '
        'to place one real thing on the scale, name one gap, and choose one '
        'correction without turning the practice into shame, confession, or '
        'self-punishment.';

    await _reveal(tester, find.text('FULL DESCRIPTION'));
    await tester.tap(find.text('FULL DESCRIPTION'));
    await tester.pumpAndSettle();
    expect(find.text(overview), findsOneWidget);

    final card = _expandedCards();
    expect(card, findsOneWidget);
    final fullTitle = tester.widget<Text>(
      find.descendant(
        of: card,
        matching: find.text('Weighing 1: Open the Material Ledger'),
      ),
    );
    expect(fullTitle.maxLines, isNull);
    expect(
      tester
          .widgetList<Text>(
            find.descendant(of: card, matching: find.byType(Text)),
          )
          .where((text) => text.style?.fontSize == 22)
          .every((text) => text.maxLines == null),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty Ma’at event lists keep selection empty and remain safe', (
    tester,
  ) async {
    await _pumpFlow(tester, 'the-weighing', emptyEvents: true);

    expect(_eventRows(), findsNothing);
    expect(_eventTaps(), findsNothing);
    expect(_expandedCards(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('entering another Ma’at flow selects that flow first event', (
    tester,
  ) async {
    await _pumpFlow(tester, 'the-weighing');
    expect(
      find.descendant(of: _eventRows().first, matching: _expandedCards()),
      findsOneWidget,
    );

    await _pumpFlow(tester, 'the-offering-table');
    final firstRowKey = _eventRows().first.evaluate().single.widget.key;
    expect(
      firstRowKey,
      const ValueKey<String>(
        'maat_flow_event_row_the-offering-table:1:Day 1: The First Water',
      ),
    );
    expect(
      find.descendant(of: _eventRows().first, matching: _expandedCards()),
      findsOneWidget,
    );
    expect(find.text('DAY 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('My Flows lead card and keyed row behavior remain unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: buildMyFlowDetailPreviewForTesting(saved: true),
      ),
    );
    await tester.pumpAndSettle();

    final leadCard = find.byKey(
      const ValueKey<String>('my_flow_day_card_71:preview-71-0'),
    );
    await _scrollUntilBuilt(tester, leadCard);
    final secondTap = find.byKey(
      const ValueKey<String>('my_flow_day_tap_71:preview-71-1'),
    );
    await _scrollUntilBuilt(tester, secondTap);
    await tester.ensureVisible(secondTap);
    await tester.pumpAndSettle();
    await tester.tap(secondTap);
    await tester.pumpAndSettle();
    expect(find.text('DAY 2'), findsOneWidget);

    await tester.tap(secondTap);
    await tester.pumpAndSettle();
    expect(find.text('DAY 2'), findsNothing);
  });
}

Finder _eventRows() => find.byWidgetPredicate(
  (widget) => _hasValueKeyPrefix(widget, 'maat_flow_event_row_'),
);

Finder _eventTaps() => find.byWidgetPredicate(
  (widget) => _hasValueKeyPrefix(widget, 'maat_flow_event_tap_'),
);

Finder _expandedCards() => find.byWidgetPredicate(
  (widget) => widget.runtimeType.toString() == '_MyFlowDayContentCard',
);

bool _hasValueKeyPrefix(Widget widget, String prefix) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith(prefix);
}

Future<void> _pumpFlow(
  WidgetTester tester,
  String templateKey, {
  bool emptyEvents = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: buildMaatFlowTemplateDetailPreviewForTesting(
        templateKey: templateKey,
        emptyEvents: emptyEvents,
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  final scrollable = find.ancestor(
    of: target,
    matching: find.byType(Scrollable),
  );
  final position = tester.state<ScrollableState>(scrollable).position;
  final viewport = tester.getRect(scrollable);
  final targetRect = tester.getRect(target);
  final pixels = (position.pixels + targetRect.top - viewport.top - 72).clamp(
    position.minScrollExtent,
    position.maxScrollExtent,
  );
  position.jumpTo(pixels);
  await tester.pump();
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
  await tester.pump();
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
    await tester.pump();
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
  await tester.pump();
}

Future<List<({double pixels, double rowTop})>> _sampleMotion(
  WidgetTester tester, {
  required ScrollPosition position,
  required Finder trackedRow,
  int frameCount = 20,
}) async {
  final samples = <({double pixels, double rowTop})>[];
  for (var frame = 0; frame < frameCount; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
    samples.add((
      pixels: position.pixels,
      rowTop: tester.getTopLeft(trackedRow).dy,
    ));
  }
  return samples;
}

Future<void> _scrollUntilBuilt(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 12 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -360));
    await tester.pumpAndSettle();
  }
  expect(target, findsOneWidget);
}

const Map<String, Color> _expectedAccents = <String, Color>{
  'track-the-sky': Color(0xFF6876D8),
  'dawn-house-rite': Color(0xFFEFA25C),
  'evening_threshold': Color(0xFFC2673F),
  'evening-threshold-rite': Color(0xFF6F58D9),
  'the-weighing': Color(0xFFB8A88A),
  'the-offering-table': Color(0xFF4A8F7A),
  'the-tending': Color(0xFF7A6B9E),
  'the-kept-word': Color(0xFF8B7355),
  'the-course': Color(0xFFE8B84A),
  'the-moon-return': Color(0xFF8FA8FF),
  'the-wag': Color(0xFF9C6B4E),
  'the-decan-watch': Color(0xFF2F4A75),
  'the-days-outside-the-year': Color(0xFF6A5A86),
  'the-open-hand': Color(0xFFB58F42),
  'the-djed': Color(0xFF6E8A72),
  'the-reading-house': Color(0xFF4FA58D),
  'the-fair-hearing': Color(0xFFC49A4A),
  'the-house-of-life': Color(0xFF4F8FA8),
  'the-boundary-stone': Color(0xFF8A7962),
  'hotep': Color(0xFF5E89A8),
  'the-open-mouth': Color(0xFFB36B5C),
  'the-living-record': Color(0xFF7E8FA8),
  'het-heru': Color(0xFFD19A3A),
  'the-shore': Color(0xFF3C8F93),
  'the-autobiography': Color(0xFFA98950),
  'the-first-arrangement': Color(0xFF6E8E68),
  'the-living-pattern': Color(0xFF4B8A6F),
  'the-true-name': Color(0xFF8A637A),
  'the-living-text': Color(0xFF6F7F99),
  'the-clearing': Color(0xFF8FA76B),
  'the-wandering': Color(0xFF5D728A),
  'the-khat': Color(0xFF9A735F),
  'the-oracle': Color(0xFF7C6EA6),
};
