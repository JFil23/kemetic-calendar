import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/maat_flow_palette.dart';
import 'package:mobile/features/calendar/maat_flow_visual_tokens.dart';

void main() {
  testWidgets('all 33 Ma’at details use the compact contextual event rows', (
    tester,
  ) async {
    for (final entry in _expectedAccents.entries) {
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
      expect(tester.takeException(), isNull, reason: entry.key);
    }
  });

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
    expect(_expandedCards(), findsNothing);

    await _reveal(tester, firstTap);
    await tester.tap(firstTap);
    await tester.pumpAndSettle();

    final card = _expandedCards();
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
  });

  testWidgets('selection, collapse, and automatic reveal remain singular', (
    tester,
  ) async {
    await _pumpFlow(tester, 'the-offering-table');

    final firstTap = _eventTaps().at(0);
    final secondTap = _eventTaps().at(1);
    await _reveal(tester, firstTap);
    await tester.tap(firstTap);
    await tester.pumpAndSettle();
    expect(_expandedCards(), findsOneWidget);

    await _reveal(tester, secondTap);
    await tester.tap(secondTap);
    await tester.pumpAndSettle();
    expect(_expandedCards(), findsOneWidget);
    expect(find.text('DAY 2'), findsOneWidget);

    await _reveal(tester, secondTap);
    await tester.tap(secondTap);
    await tester.pumpAndSettle();
    expect(_expandedCards(), findsNothing);

    final revealRow = _eventRows().at(5);
    final revealTap = _eventTaps().at(5);
    await _reveal(tester, revealRow);
    final scrollable = find.byType(Scrollable).first;
    final position = tester.state<ScrollableState>(scrollable).position;
    final viewport = tester.getRect(scrollable);
    final rowRect = tester.getRect(revealRow);
    final targetTop = viewport.bottom - rowRect.height - 12;
    final positionedPixels = (position.pixels + rowRect.top - targetTop).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    position.jumpTo(positionedPixels);
    await tester.pump();
    final beforeRevealTop = tester.getTopLeft(revealRow).dy;

    await tester.tap(revealTap);
    await tester.pumpAndSettle();
    final afterRevealTop = tester.getTopLeft(revealRow).dy;
    expect(afterRevealTop, lessThan(beforeRevealTop - 40));
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

    final firstTap = _eventTaps().first;
    await _reveal(tester, firstTap);
    await tester.tap(firstTap);
    await tester.pumpAndSettle();
    final card = _expandedCards();
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

Future<void> _pumpFlow(WidgetTester tester, String templateKey) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: buildMaatFlowTemplateDetailPreviewForTesting(
        templateKey: templateKey,
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
