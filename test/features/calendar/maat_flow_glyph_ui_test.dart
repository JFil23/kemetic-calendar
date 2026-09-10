import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:mobile/features/calendar/maat_flow_catalog.dart';
import 'package:mobile/features/calendar/maat_flow_identity.dart';
import 'package:mobile/features/calendar/maat_flow_palette.dart';
import 'package:mobile/features/calendar/maat_flow_visual_tokens.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_discovery_view.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';

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
    final templateCount =
        MaatFlowKind.values.length - kArchivedCompatibilityMaatFlowKinds.length;

    expect(
      _countOccurrences(templateList, '_MaatFlowTemplate('),
      templateCount,
    );
    expect(templateList, contains('key: kOracleFlowKey'));
    expect(templateList, contains('key: kReadingHouseFlowKey'));
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

  test('Offering and Follow Sky surfaces consume one canonical glyph each', () {
    final templates = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final activeDetails = File(
      'lib/features/calendar/calendar_active_maat_flows.dart',
    ).readAsStringSync();
    final followHero = File(
      'lib/features/calendar/follow_the_sky/presentation/widgets/'
      'follow_sky_scroll_shell.dart',
    ).readAsStringSync();

    expect(kOfferingTableGlyph, '𓊲');
    expect(kFollowSkyGlyph, '𓇼');
    expect(templates, contains('glyph: kOfferingTableGlyph'));
    expect(templates, contains('glyph: kFollowSkyGlyph'));
    expect(templates, contains('color: const Color(0xFFC08A52)'));
    expect(
      templates,
      contains(
        'Notice what needs to be fed. Name an intention, make one small act '
        'of provision, then drink the water.',
      ),
    );
    expect(templates, contains("glyphSourceWord: 'wdHw'"));
    expect(followHero, contains('glyph: kFollowSkyGlyph'));
    expect(activeDetails, contains('MaatFlowGlyph(glyph: template.glyph'));
    expect(activeDetails, isNot(contains('_drawFallbackGlyph')));
    expect(activeDetails, isNot(contains('void _drawSky(')));
    expect(activeDetails, isNot(contains('void _drawOfferingTable(')));
  });

  test('core-flow discovery bundles and uses Cormorant Garamond', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final source = File(
      'lib/features/calendar/presentation/maat_flow_discovery_view.dart',
    ).readAsStringSync();
    const fontAssets = <String>[
      'ios/Runner/Fonts/CormorantGaramond-Regular.ttf',
      'ios/Runner/Fonts/CormorantGaramond-Italic.ttf',
      'ios/Runner/Fonts/CormorantGaramond-Medium.ttf',
      'ios/Runner/Fonts/CormorantGaramond-MediumItalic.ttf',
      'ios/Runner/Fonts/CormorantGaramond-SemiBold.ttf',
    ];

    expect(MaatFlowListTokens.fontFamily, 'CormorantGaramond');
    expect(MaatFlowListTokens.fontFallback, contains('GentiumPlus'));
    expect(pubspec, contains('family: CormorantGaramond'));
    expect(source, contains('fontFamily: MaatFlowListTokens.fontFamily'));
    for (final asset in fontAssets) {
      expect(pubspec, contains('asset: $asset'));
      expect(File(asset).existsSync(), isTrue, reason: 'Missing $asset');
    }
  });

  testWidgets(
    'core-flow discovery renders canonical glyphs without dot fallback',
    (tester) async {
      for (final data in kCoreMaatFlowDiscoveryFixtures) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 390,
                child: MaatFlowDiscoveryCard(data: data, featured: false),
              ),
            ),
          ),
        );

        final glyph = tester.widget<Text>(find.text(data.glyph));
        expect(glyph.style?.fontFamily, 'Noto Sans Egyptian Hieroglyphs');
        expect(find.byIcon(Icons.circle), findsNothing);
      }
    },
  );

  test('Ma’at Flow list visual tokens match the target card spec', () {
    expect(MaatFlowListTokens.pageBg, const Color(0xFF050504));
    expect(MaatFlowListTokens.joinedCardBg, const Color(0xFF120F08));
    expect(MaatFlowListTokens.joinedCardBorder, const Color(0xCC33270E));
    expect(MaatFlowListTokens.unjoinedCardBg, const Color(0xFF0D0B07));
    expect(MaatFlowListTokens.unjoinedCardBorder, const Color(0x99261E0D));
    expect(MaatFlowListTokens.gold, const Color(0xFFD8B64E));
    expect(MaatFlowListTokens.joinedTitle, const Color(0xFFD4AE43));
    expect(MaatFlowListTokens.unjoinedTitle, const Color(0xFF8A7030));
    expect(MaatFlowListTokens.sectionLabel, const Color(0xFF4A3A1F));
    expect(MaatFlowListTokens.joinedCategory, const Color(0xFF8A7130));
    expect(MaatFlowListTokens.unjoinedCategory, const Color(0xFF675327));
    expect(MaatFlowListTokens.joinedDescription, const Color(0xFF9E9A94));
    expect(MaatFlowListTokens.unjoinedDescription, const Color(0xFF5A5650));
    expect(MaatFlowListTokens.joinedStatus, const Color(0xFF7A6A38));
    expect(MaatFlowListTokens.joinedProgress, const Color(0xFFC8A84A));
    expect(MaatFlowListTokens.joinedChevron, const Color(0xFFA98840));
    expect(MaatFlowListTokens.unjoinedChevron, const Color(0xFF594516));
    expect(MaatFlowListTokens.joinedIconBg, const Color(0xFF191207));
    expect(MaatFlowListTokens.unjoinedIconBg, const Color(0xFF110E08));
    expect(MaatFlowListTokens.joinedIconStroke, const Color(0xFFD4AE43));
    expect(MaatFlowListTokens.unjoinedIconStroke, const Color(0xFF7C6428));
    expect(MaatFlowListTokens.progressTrack, const Color(0xFF34270E));
    expect(MaatFlowListTokens.cardRadius, 17);
    expect(MaatFlowListTokens.cardBorderWidth, 0.5);
    expect(MaatFlowListTokens.cardHorizontalMargin, 12);
    expect(MaatFlowListTokens.joinedCardGap, 12);
    expect(MaatFlowListTokens.unjoinedCardGap, 9);
    expect(MaatFlowListTokens.joinedToUnjoinedGap, 22);
    expect(MaatFlowListTokens.iconSize, 52);
    expect(MaatFlowListTokens.joinedListIconSize, 58);
    expect(MaatFlowListTokens.unjoinedListIconSize, 52);
    expect(MaatFlowListTokens.iconInnerSize, 28);
    expect(MaatFlowListTokens.iconGlyphScale, 1.13);
    expect(MaatFlowListTokens.progressRingRadius, 26);
    expect(MaatFlowListTokens.progressRingStrokeWidth, 1.8);
    expect(MaatFlowListTokens.joinedIconStrokeWidth, 1.35);
    expect(MaatFlowListTokens.unjoinedIconStrokeWidth, 1.2);
    expect(
      MaatFlowListTokens.joinedCardPadding,
      const EdgeInsets.fromLTRB(18, 26, 18, 26),
    );
    expect(
      MaatFlowListTokens.unjoinedCardPadding,
      const EdgeInsets.fromLTRB(18, 18, 16, 17),
    );
    expect(
      MaatFlowListTokens.sectionLabelPadding,
      const EdgeInsets.fromLTRB(12, 0, 12, 14),
    );
  });

  test(
    'core-flow discovery intentionally omits joined and progress state chrome',
    () {
      final source = File(
        'lib/features/calendar/presentation/maat_flow_discovery_view.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('JOINED')));
      expect(source, isNot(contains('NOT YET JOINED')));
      expect(source, isNot(contains('progressRing')));
      expect(source, isNot(contains('completionCounts')));
      expect(source, contains('MaatFlowDiscoveryCard('));
      expect(source, contains('data.arrivalLabel.toUpperCase()'));
    },
  );

  test('five active detail bodies omit disclaimer framing', () {
    final primaryBody = <String>[
      'lib/features/calendar/follow_the_sky/presentation/'
          'follow_sky_detail_page.dart',
      'lib/features/calendar/the_offering_table/presentation/'
          'offering_table_detail_page.dart',
      'lib/features/calendar/the_reading_house/presentation/'
          'reading_house_detail_page.dart',
      'lib/features/calendar/the_djed/presentation/djed_detail_page.dart',
      'lib/features/calendar/the_kar/presentation/kar_detail_surface.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
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

  test(
    'archived compatibility copy is read-only and separate from discovery',
    () {
      final discovery = File(
        'lib/features/calendar/presentation/maat_flow_discovery_view.dart',
      ).readAsStringSync();
      final archived = File(
        'lib/features/calendar/presentation/archived_maat_flow_detail_view.dart',
      ).readAsStringSync();

      expect(discovery, isNot(contains('Privacy note:')));
      expect(discovery, isNot(contains('private reflections')));
      expect(archived, contains('This flow is archived'));
      expect(archived, contains('Historical events'));
      expect(archived, contains('Saved responses'));
      expect(archived, isNot(contains('Join Flow')));
    },
  );

  test('all five active branches route to dedicated detail authorities', () {
    final source = File(
      'lib/features/calendar/calendar_active_maat_flows.dart',
    ).readAsStringSync();
    final state = source.substring(
      source.indexOf('class _ActiveMaatFlowDetailSurfaceState'),
    );

    expect(state, contains('Widget _buildFollowSky()'));
    expect(state, contains('Widget _buildOfferingTable()'));
    expect(state, contains('Widget _buildReadingHouse()'));
    expect(state, contains('Widget _buildDjed()'));
    expect(state, contains('Widget _buildKar()'));
    expect(state, contains("'track-the-sky' => _buildFollowSky()"));
    expect(state, contains('kOfferingTableFlowKey => _buildOfferingTable()'));
    expect(state, contains('kReadingHouseFlowKey => _buildReadingHouse()'));
    expect(state, contains('kTheDjedFlowKey => _buildDjed()'));
    expect(state, contains('kKarFlowKey => _buildKar()'));
    expect(state, isNot(contains('_buildTheWeighingScaffold')));
    expect(state, isNot(contains('_buildWagScaffold')));
  });

  test('The Weighing is archived and routes only to read-only history', () {
    final active = File(
      'lib/features/calendar/calendar_active_maat_flows.dart',
    ).readAsStringSync();
    final archived = File(
      'lib/features/calendar/presentation/archived_maat_flow_detail_view.dart',
    ).readAsStringSync();
    final entry = maatFlowCatalogEntry(MaatFlowKind.theWeighing);

    expect(entry.status, MaatFlowCatalogStatus.archived);
    expect(entry.isDiscoverable, isFalse);
    expect(entry.isJoinable, isFalse);
    expect(entry.isCompatibilitySupported, isTrue);
    expect(active, isNot(contains('_joinTheWeighingFlow')));
    expect(active, isNot(contains('_buildTheWeighingScaffold')));
    expect(active, contains('ArchivedMaatFlowDetailView('));
    expect(archived, contains('This flow is archived'));
    expect(archived, isNot(contains('Join Flow')));
  });

  test('five active details use shared palette and surface contracts', () {
    final active = File(
      'lib/features/calendar/calendar_active_maat_flows.dart',
    ).readAsStringSync();
    final paletteSource = File(
      'lib/features/calendar/maat_flow_palette.dart',
    ).readAsStringSync();
    final shell = File(
      'lib/features/calendar/presentation/maat_flow_detail_shell.dart',
    ).readAsStringSync();
    final follow = File(
      'lib/features/calendar/follow_the_sky/presentation/'
      'follow_sky_detail_page.dart',
    ).readAsStringSync();
    final offering = File(
      'lib/features/calendar/the_offering_table/presentation/'
      'offering_table_detail_page.dart',
    ).readAsStringSync();
    final reading = File(
      'lib/features/calendar/the_reading_house/presentation/'
      'reading_house_detail_page.dart',
    ).readAsStringSync();
    final djed = File(
      'lib/features/calendar/the_djed/presentation/djed_detail_page.dart',
    ).readAsStringSync();
    final archived = File(
      'lib/features/calendar/presentation/archived_maat_flow_detail_view.dart',
    ).readAsStringSync();

    final weighing = MaatFlowPalette.resolve(
      flowId: 'the-weighing',
      accent: Colors.red,
    );
    final standard = MaatFlowPalette.resolve(
      flowId: 'the-course',
      accent: const Color(0xFFE8B84A),
    );

    expect(weighing.isGraphic, isTrue);
    expect(weighing.accent, const Color(0xFFB8A88A));
    expect(weighing.glowColor, const Color(0xFFF5E8CB));
    expect(standard.isGraphic, isFalse);
    expect(standard.accent, const Color(0xFFE8B84A));
    expect(standard.glowColor, const Color(0xFFE8B84A));
    expect(paletteSource, contains('class MaatFlowPalette'));
    expect(
      paletteSource,
      contains('class MaatFlowSurface extends StatelessWidget'),
    );
    expect(
      paletteSource,
      contains("static const Map<String, MaatFlowPalette> _graphicOverrides"),
    );
    expect(paletteSource, contains("'track-the-sky'"));
    expect(paletteSource, contains("'dawn-house-rite'"));
    expect(paletteSource, contains("'evening-threshold-rite'"));
    expect(paletteSource, contains("'the-weighing'"));
    expect(paletteSource, isNot(contains("'the-course'")));
    for (final geometry in const <String>[
      'referenceWidth = 390',
      'referenceHeight = 844',
      'heroHeight = 452',
      'sheetOverlap = 46',
      'heroParallaxFactor = 0.58',
      'heroFadeScrollDistance = 430',
      'bottomContentClearance = 168',
      'sheetRadius = 26',
    ]) {
      expect(shell, contains(geometry), reason: geometry);
    }
    expect(shell, contains('math.min(widthScaledHero, heightScaledHero)'));
    expect(shell, contains('top: -parallax'));
    expect(shell, contains('Opacity(opacity: 1 - fadeT'));
    expect(shell, contains('CustomScrollView('));
    expect(shell, contains('keyboardIsVisible(context)'));
    expect(shell, contains('MaatFlowDetailDock extends StatelessWidget'));

    expect(follow, contains('theme: FollowSkyV11Tokens.detailTheme'));
    expect(follow, contains('hero: FollowSkyHero('));
    expect(follow, contains('bottomDock: FollowSkyV11Dock('));
    expect(offering, contains('theme: OfferingTableDetailTokens.theme'));
    expect(offering, contains('hero: const _OfferingTableHero()'));
    expect(offering, contains('bottomDock: MaatFlowDetailDock('));
    expect(reading, contains('theme: ReadingHouseDetailTokens.theme'));
    expect(reading, contains('hero: const _ReadingHouseHero()'));
    expect(reading, contains('MaatFlowDetailDock('));
    expect(djed, contains('theme: DjedDetailTokens.theme'));
    expect(djed, contains('hero: const _DjedHero()'));
    expect(djed, contains('bottomDock: MaatFlowDetailDock('));
    expect(archived, contains('MaatFlowDetailShell('));
    expect(archived, isNot(contains('Join Flow')));

    expect(active, contains('FollowSkyDetailSurface('));
    expect(active, contains('OfferingTableDetailSurface('));
    expect(active, contains('ReadingHouseDetailSurface('));
    expect(active, contains('DjedDetailSurface('));
    expect(active, contains('ArchivedMaatFlowDetailView('));
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
