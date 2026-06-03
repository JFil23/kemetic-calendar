import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';

void main() {
  test('prebuilt Ma’at Flow templates declare non-empty glyph metadata', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final templateList = _sourceBetween(
      source,
      'final List<_MaatFlowTemplate> _kMaatFlowTemplates = [',
      'CALENDAR PAGE (flows + notes)',
    );
    const templateCount = 31;

    expect(
      _countOccurrences(templateList, '_MaatFlowTemplate('),
      templateCount,
    );
    expect(_countOccurrences(templateList, 'glyph:'), templateCount);
    expect(_countOccurrences(templateList, 'glyphMeaning:'), templateCount);
    expect(_countOccurrences(templateList, 'glyphSourceWord:'), templateCount);
    expect(_countOccurrences(templateList, 'glyphType:'), templateCount);
    expect(_countOccurrences(templateList, 'subtitle:'), templateCount);
    expect(templateList, isNot(contains("glyph: ''")));
    expect(templateList, isNot(contains("subtitle: ''")));
  });

  testWidgets(
    'Ma’at Flow glyph widget renders glyph text without dot fallback',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MaatFlowGlyph(glyph: '𓇼')),
        ),
      );

      expect(find.text('𓇼'), findsOneWidget);
      expect(find.byType(MaatFlowGlyph), findsOneWidget);
    },
  );

  test(
    'Ma’at Flow list and starter rows render glyph widgets instead of dots',
    () {
      final source = File(
        'lib/features/calendar/calendar_maat_flows.dart',
      ).readAsStringSync();
      final listPage = _sourceBetween(
        source,
        'class _MaatFlowsListPageState',
        '/* ───────────────────────── First Ma',
      );
      final recommendationCard = _sourceBetween(
        source,
        'Widget _recommendationCard(StarterMaatFlow suggestion)',
        '@override',
      );

      expect(listPage, contains('leading: MaatFlowGlyph(glyph: t.glyph'));
      expect(listPage, contains('t.subtitle'));
      expect(listPage, isNot(contains('_maatFlowTemplateDurationLabel(t)')));
      expect(listPage, isNot(contains('Tap for details')));
      expect(listPage, isNot(contains('maatDecanDefinition.tagline')));
      expect(
        recommendationCard,
        contains('MaatFlowGlyph(glyph: template.glyph'),
      );
      expect(listPage, isNot(contains('shape: BoxShape.circle')));
      expect(recommendationCard, isNot(contains('shape: BoxShape.circle')));
      expect(listPage, isNot(contains('_glossFromColor(t.color)')));
      expect(
        recommendationCard,
        isNot(contains('_glossFromColor(template.color)')),
      );
    },
  );

  test('Ma’at Flow detail primary body omits disclaimer framing', () {
    final source = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();
    final primaryBody = source.replaceAll(
      'Privacy note: private reflections and names are never included in notification previews.',
      '',
    );
    final banned = RegExp(
      r'(directly attested|historically attested|modern reconstruction|'
      r'privacy notification|notifications carry only|Push notifications|'
      r'Synced calendar|stay on this device|not 1:1)',
      caseSensitive: false,
    );

    expect(primaryBody, isNot(contains(banned)));
    expect(primaryBody, isNot(contains('Privacy:')));
    expect(primaryBody, isNot(contains("text: 'Privacy'")));
  });

  test('privacy footer is low-emphasis and follows event previews', () {
    final source = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('style: TextStyle(color: Colors.white38'),
      reason: 'Footer privacy copy should be low-emphasis.',
    );
    expect(_countOccurrences(source, 'const _MaatFlowPrivacyFooter(),'), 9);
    _expectFooterAfter(source, '...kTheTendingEvents.map(');
    _expectFooterAfter(source, '...kKeptWordEvents.map(');
    _expectFooterAfter(source, '...kWagEvents.map(');
    _expectFooterAfter(source, '...preview.map(');
    _expectFooterAfter(source, '...definition.events.map(');
    _expectFooterAfter(source, '...kOpenHandEvents.map(');
    _expectFooterAfter(source, '...kDjedEvents.map(');
    _expectFooterAfter(source, '...kDaysOutsideEvents.map(');
  });
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'Missing start marker: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: 'Missing end marker: $end');
  return source.substring(startIndex, endIndex);
}

int _countOccurrences(String source, String needle) {
  if (needle.isEmpty) return 0;
  var count = 0;
  var index = 0;
  while (true) {
    index = source.indexOf(needle, index);
    if (index < 0) return count;
    count += 1;
    index += needle.length;
  }
}

void _expectFooterAfter(String source, String marker) {
  final markerIndex = source.indexOf(marker);
  expect(markerIndex, isNonNegative, reason: 'Missing event marker: $marker');
  final footerIndex = source.indexOf(
    'const _MaatFlowPrivacyFooter(),',
    markerIndex,
  );
  expect(footerIndex, isNonNegative, reason: 'Missing footer after $marker');
}
