import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/maat_flow_palette.dart';
import 'package:mobile/features/calendar/maat_flow_visual_tokens.dart';

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
    const templateCount = 33;

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

  test('Ma’at Flow surface bundles and uses Cormorant Garamond', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final webHeaders = File('web/_headers').readAsStringSync();
    final source = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();
    const fontAssets = [
      'ios/Runner/Fonts/CormorantGaramond-Regular.ttf',
      'ios/Runner/Fonts/CormorantGaramond-Italic.ttf',
      'ios/Runner/Fonts/CormorantGaramond-Medium.ttf',
      'ios/Runner/Fonts/CormorantGaramond-MediumItalic.ttf',
      'ios/Runner/Fonts/CormorantGaramond-SemiBold.ttf',
    ];

    expect(MaatFlowListTokens.fontFamily, 'CormorantGaramond');
    expect(MaatFlowListTokens.fontFallback, contains('GentiumPlus'));
    expect(pubspec, contains('family: CormorantGaramond'));
    expect(
      webHeaders.indexOf('/assets/*\n'),
      lessThan(webHeaders.indexOf('/assets/FontManifest.json\n')),
    );
    expect(
      webHeaders,
      contains(
        '/assets/FontManifest.json\n'
        '  ! Cache-Control\n'
        '  Cache-Control: no-cache, must-revalidate',
      ),
    );
    expect(
      webHeaders,
      contains(
        '/assets/ios/Runner/Fonts/*\n'
        '  ! Cache-Control\n'
        '  Cache-Control: no-cache, must-revalidate',
      ),
    );
    for (final asset in fontAssets) {
      expect(pubspec, contains('asset: $asset'));
      expect(File(asset).existsSync(), isTrue, reason: 'Missing $asset');
    }
    for (final marker in [
      'Privacy note: private reflections and names are never included in notification previews.',
      'No Ma’at flows yet.',
      'Widget _buildDateModeTitle',
      'Widget _buildEventBadge',
    ]) {
      expect(
        _methodOrLocalSource(source, marker),
        contains('fontFamily: MaatFlowListTokens.fontFamily'),
        reason: '$marker must not fall back to the app theme font.',
      );
    }
  });

  test('Ma’at Flow list renders custom glyph rings instead of dots', () {
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

    expect(listPage, contains('class _MaatFlowIcon'));
    expect(listPage, contains('class _MaatFlowIconPainter'));
    expect(listPage, contains('canvas.drawArc('));
    expect(listPage, contains('_MaatFlowCardStatus.joined('));
    expect(listPage, contains('template.subtitle'));
    expect(listPage, isNot(contains('_maatFlowTemplateDurationLabel(t)')));
    expect(listPage, isNot(contains('Tap for details')));
    expect(listPage, isNot(contains('maatDecanDefinition.tagline')));
    expect(recommendationCard, contains('MaatFlowGlyph(glyph: template.glyph'));
    expect(listPage, isNot(contains('shape: BoxShape.circle')));
    expect(recommendationCard, isNot(contains('shape: BoxShape.circle')));
    expect(listPage, isNot(contains('_glossFromColor(t.color)')));
    expect(
      recommendationCard,
      isNot(contains('_glossFromColor(template.color)')),
    );
  });

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
    'Ma’at Flow list uses joined-only glow and joined-only progress rings',
    () {
      final source = File(
        'lib/features/calendar/calendar_maat_flows.dart',
      ).readAsStringSync();
      final listPage = _sourceBetween(
        source,
        'class _MaatFlowsListPageState',
        '/* ───────────────────────── First Ma',
      );
      final card = _sourceBetween(
        source,
        'class _MaatFlowCard extends StatelessWidget',
        'class _MaatFlowSubtitleParts',
      );
      final painter = _sourceBetween(
        source,
        'class _MaatFlowIconPainter extends CustomPainter',
        '/* ───────────────────────── First Ma',
      );

      expect(listPage, contains('_MaatFlowCardGlowLine('));
      expect(
        listPage,
        contains('if (status.joined) const _MaatFlowCardSurfaceLight()'),
      );
      expect(listPage, contains('_maatFlowListPaletteFor(template)'));
      expect(listPage, contains('_MaatFlowCardBaseLayer(joined:'));
      expect(listPage, contains('_MaatFlowCardColorWash('));
      expect(listPage, contains('_MaatFlowCardStripe('));
      expect(listPage, contains('Opacity(opacity: 0.88'));
      expect(card, isNot(contains('if (!status.joined) const _MaatFlowCard')));
      expect(listPage, isNot(contains('_MaatFlowCardGleam')));
      expect(
        painter,
        contains('if (paintBackground && joined && progress != null)'),
      );
      expect(painter, contains('MaatFlowListTokens.progressTrack'));
      expect(
        painter,
        contains('canvas.scale(MaatFlowListTokens.iconGlyphScale)'),
      );
      expect(painter, contains('listAccent'));
      expect(
        painter,
        contains('accent.withValues(alpha: joined ? 0.30 : 0.14)'),
      );
      expect(listPage, isNot(contains('_inactiveRing')));
      expect(listPage, isNot(contains('_ringTrack')));
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
      _methodOrLocalSource(
        source,
        'Privacy note: private reflections and names are never included in notification previews.',
      ),
      allOf(
        contains('color: Colors.white38'),
        contains('fontFamily: MaatFlowListTokens.fontFamily'),
      ),
      reason: 'Footer privacy copy should be low-emphasis.',
    );
    expect(_countOccurrences(source, 'const _MaatFlowPrivacyFooter(),'), 11);
    _expectFooterAfter(source, '...kTheTendingEvents.map(');
    _expectFooterAfter(source, '...kKeptWordEvents.map(');
    _expectFooterAfter(source, '...kWagEvents.map(');
    _expectFooterAfter(source, '...preview.map(');
    _expectFooterAfter(source, '...definition.events.map(');
    _expectFooterAfter(source, '...kOpenHandEvents.map(');
    _expectFooterAfter(source, '...kDjedEvents.map(');
    _expectFooterAfter(source, '...kDaysOutsideEvents.map(');
    _expectFooterAfter(
      source,
      '(occurrence) => _buildMoonReturnOccurrenceTile(context, occurrence)',
    );
    _expectFooterAfter(source, '_buildReadingHouseSittingTile(');
  });

  test('all Ma’at Flow detail branches use the shared detail scaffold', () {
    final source = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();
    final detailState = source.substring(
      source.indexOf('class _MaatFlowTemplateDetailPageState'),
    );
    const scaffoldBuilders = [
      '_buildEnrollmentUnavailableScaffold',
      '_buildTrackSkyScaffold',
      '_buildDawnHouseRiteScaffold',
      '_buildEveningThresholdRiteScaffold',
      '_buildTheWeighingScaffold',
      '_buildTheTendingScaffold',
      '_buildKeptWordScaffold',
      '_buildWagScaffold',
      '_buildDecanWatchScaffold',
      '_buildMaatDecanFlowScaffold',
      '_buildOpenHandScaffold',
      '_buildDjedScaffold',
      '_buildDaysOutsideYearScaffold',
      '_buildMoonReturnScaffold',
      '_buildCourseScaffold',
      '_buildOfferingTableScaffold',
      '_buildSequenceScaffold',
    ];

    expect(detailState, isNot(contains('backgroundColor: _bg')));
    for (final builder in scaffoldBuilders) {
      expect(
        _methodSource(source, builder),
        contains('return _buildMaatFlowDetailScaffold('),
        reason: '$builder should render through the shared detail scaffold.',
      );
    }
  });

  test('The Weighing detail restructure preserves control handlers', () {
    final source = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();
    final scaffold = _sourceBetween(
      source,
      'Widget _buildTheWeighingScaffold(BuildContext context)',
      'Widget _buildTheTendingEventTile',
    );
    final overviewZones = _sourceBetween(
      source,
      'List<Widget> _buildMaatFlowOverviewZones',
      'Widget _buildMaatFlowDetailHero',
    );
    final startDateRow = _sourceBetween(
      source,
      'Widget _buildStartDateRow',
      'Widget _buildDetailChoiceChips',
    );
    final descriptionToggle = _sourceBetween(
      source,
      'Widget _buildFullDescriptionToggle',
      '_MaatFlowDetailContent _detailContentForTemplate',
    );
    final sittingTile = _sourceBetween(
      source,
      'Widget _buildMaatFlowSittingTile',
      'Widget _buildMaatFlowDetailSections',
    );

    expect(scaffold, contains('_buildMaatFlowDetailScaffold'));
    expect(scaffold, contains('joinButton: _buildTemplateStickyJoinButton'));
    expect(scaffold, contains('_joinTheWeighingFlow(selectedStart)'));
    expect(scaffold, contains('_buildStartDateRow('));
    expect(scaffold, contains('selectedStart'));
    expect(
      scaffold,
      contains(
        "'Start: \${_dateLabel(context, selectedStart)} at \$firstTime'",
      ),
    );
    expect(scaffold, contains('_buildDetailChoiceChips<TheWeighingLens>'));
    expect(scaffold, contains('_theWeighingLens = lens'));
    expect(scaffold, contains('_buildTheWeighingEventTile(context, event)'));
    expect(overviewZones, contains('_buildFullDescriptionToggle'));
    expect(startDateRow, contains('onPressed: _pickDate'));
    expect(descriptionToggle, contains('_descriptionExpanded ='));
    expect(sittingTile, contains('ExpansionTile'));
  });

  test('Ma’at Flow detail uses shared palette and surface contract', () {
    final source = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();
    final calendarPageSource = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final paletteSource = File(
      'lib/features/calendar/maat_flow_palette.dart',
    ).readAsStringSync();
    final detailScaffold = _sourceBetween(
      source,
      'Widget _buildMaatFlowDetailScaffold',
      'List<Widget> _buildMaatFlowOverviewZones',
    );
    final overviewZones = _sourceBetween(
      source,
      'List<Widget> _buildMaatFlowOverviewZones',
      'Widget _buildMaatFlowDetailHero',
    );
    final hero = _sourceBetween(
      source,
      'Widget _buildMaatFlowDetailHero',
      'Widget _buildAtAGlanceChips',
    );
    final chips = _sourceBetween(
      source,
      'Widget _buildAtAGlanceChips',
      'Widget _buildMaatFlowArc',
    );
    final arc = _sourceBetween(
      source,
      'Widget _buildMaatFlowArc',
      'Widget _buildMaatFlowArcCard',
    );
    final sittingTile = _sourceBetween(
      source,
      'Widget _buildMaatFlowSittingTile',
      'Widget _buildMaatFlowDetailSections',
    );
    final expandableTile = _sourceBetween(
      source,
      'Widget _buildExpandableFlowEventTile',
      'Widget _buildMaatFlowSittingTile',
    );
    final scaffold = _sourceBetween(
      source,
      'Widget _buildTheWeighingScaffold(BuildContext context)',
      'Widget _buildTheTendingEventTile',
    );

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
    expect(calendarPageSource, contains("import 'maat_flow_palette.dart';"));
    expect(source, contains('MaatFlowPalette get _palette'));
    expect(
      source,
      contains('class _MaatFlowGlyphTile extends StatelessWidget'),
    );
    expect(source, isNot(contains('class _MaatFlowWeighingMaterialSurface')));
    expect(source, isNot(contains('class _TheWeighingGlyphTile')));
    expect(
      detailScaffold,
      contains('final embedded = widget.embeddedInOnboarding;'),
    );
    expect(detailScaffold, contains('final scrollBottomPadding ='));
    expect(detailScaffold, contains('ctaHeight +'));
    expect(detailScaffold, contains('(embedded ? 0 : media.padding.bottom) +'));
    expect(detailScaffold, contains('(embedded ? 18 : 24);'));
    expect(detailScaffold, contains('final bodyPadding = embedded'));
    expect(detailScaffold, contains('final ctaPadding = embedded'));
    expect(overviewZones, contains('fontSize: 16'));
    expect(
      overviewZones,
      contains('_buildMaatFlowArc(content.arcBlocks, palette: palette)'),
    );
    expect(hero, contains('fontSize: 30'));
    expect(hero, contains('fontSize: 16'));
    expect(hero, contains('detailPalette: palette'));
    expect(hero, contains('MaatFlowPalette.gold'));
    expect(hero, contains('MaatFlowPalette.silverHi'));
    expect(chips, contains('MaatFlowSurface('));
    expect(chips, contains('showCrown: true'));
    expect(chips, contains('washOpacity: 0.10'));
    expect(arc, contains('constraints.maxWidth < 330'));
    expect(arc, contains('height: 132'));
    expect(arc, contains('MaatFlowSurface('));
    expect(arc, contains('_MaatFlowArcDivider(palette: palette)'));
    expect(arc, contains('_MaatFlowArcChevron(palette: palette)'));
    expect(sittingTile, contains('MaatFlowSurface('));
    expect(sittingTile, contains('MaatFlowPalette.separator'));
    expect(sittingTile, contains('_buildMaatFlowDetailSections(detailText)'));
    expect(expandableTile, contains('MaatFlowSurface('));
    expect(scaffold, contains('leading: _MaatFlowGlyphTile('));
  });

  test('Evening Threshold empty join uses prompted scroll-focus nudge', () {
    final source = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();
    final stateFields = _sourceBetween(
      source,
      'class _MaatFlowTemplateDetailPageState',
      'Future<void> _completeJoin(int id) async',
    );
    final joinMethod = _sourceBetween(
      source,
      'Future<void> _joinEveningThresholdFlow',
      'Future<void> _joinEveningThresholdRiteFlow',
    );
    final emptyCarryBranch = _sourceBetween(
      joinMethod,
      'if (initialCarry.isEmpty) {',
      'setState(() {\n      _eveningThresholdJoinInFlight = true;',
    );
    final scaffold = _sourceBetween(
      source,
      'Widget _buildEveningThresholdScaffold(BuildContext context)',
      'Widget _buildEveningThresholdRiteScaffold(BuildContext context)',
    );
    final fieldAndPrompt = _sourceBetween(
      scaffold,
      'AnimatedContainer(',
      'const _MaatFlowDetailSectionLabel(\'TIMEZONE\')',
    );

    expect(stateFields, contains('FocusNode _eveningThresholdCarryFocusNode'));
    expect(stateFields, contains('GlobalKey _eveningThresholdCarryFieldKey'));
    expect(stateFields, contains('bool _eveningThresholdCarryPrompted'));
    expect(stateFields, contains('bool _eveningThresholdCarryHintVisible'));

    expect(emptyCarryBranch, contains('_eveningThresholdCarryPrompted = true'));
    expect(
      emptyCarryBranch,
      contains('_eveningThresholdCarryHintVisible = true'),
    );
    expect(emptyCarryBranch, contains('Scrollable.ensureVisible('));
    expect(
      emptyCarryBranch,
      contains('_eveningThresholdCarryFocusNode.requestFocus();'),
    );
    expect(
      emptyCarryBranch.indexOf('Scrollable.ensureVisible('),
      lessThan(
        emptyCarryBranch.indexOf(
          '_eveningThresholdCarryFocusNode.requestFocus();',
        ),
      ),
    );
    expect(emptyCarryBranch, isNot(contains('ScaffoldMessenger.of(context)')));
    expect(emptyCarryBranch, isNot(contains('showSnackBar')));
    expect(emptyCarryBranch, isNot(contains('SnackBar')));
    expect(source, isNot(contains('Name what you carry today first.')));

    expect(scaffold, contains('onPressed: _eveningThresholdJoinInFlight'));
    expect(scaffold, isNot(contains('!initialCarryReady')));
    expect(
      scaffold,
      contains(': () => _joinEveningThresholdFlow(selectedStart)'),
    );
    expect(scaffold, isNot(contains('initialCarry.isEmpty ? null')));

    expect(fieldAndPrompt, contains('TextField('));
    expect(fieldAndPrompt, contains('key: _eveningThresholdCarryFieldKey'));
    expect(
      fieldAndPrompt,
      contains('focusNode: _eveningThresholdCarryFocusNode'),
    );
    expect(fieldAndPrompt, contains('cursorColor: MaatFlowPalette.gold'));
    expect(fieldAndPrompt, contains('TextSelectionTheme('));
    expect(fieldAndPrompt, contains('selectionColor: MaatFlowPalette.gold'));
    expect(fieldAndPrompt, isNot(contains('_palette.accent')));
    expect(fieldAndPrompt, contains('AnimatedOpacity('));
    expect(fieldAndPrompt, contains('height: 42'));
    expect(
      fieldAndPrompt,
      contains('Name what you carry today before this flow begins.'),
    );
    expect(fieldAndPrompt, contains('value.trim().isEmpty'));
    expect(fieldAndPrompt, contains('_eveningThresholdCarryPrompted = false'));
    expect(
      fieldAndPrompt,
      contains('_eveningThresholdCarryHintVisible = false'),
    );
    expect(fieldAndPrompt, isNot(contains('validator')));
    expect(fieldAndPrompt, isNot(contains('errorBorder')));
    expect(fieldAndPrompt, isNot(contains('focusedErrorBorder')));
    expect(fieldAndPrompt, isNot(contains('forceErrorText')));
    expect(fieldAndPrompt, isNot(contains('errorText')));
  });

  test('onboarding decan arc stays horizontal on narrow PWA widths', () {
    final source = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();
    final arc = _sourceBetween(
      source,
      'Widget _buildMaatFlowArc',
      'Widget _buildMaatFlowArcCard',
    );

    expect(arc, contains('!widget.embeddedInOnboarding'));
    expect(arc, contains('constraints.maxWidth < 330'));
    expect(arc, contains('return Column('));
    expect(arc, contains('return MaatFlowSurface('));
    expect(
      arc,
      contains(
        '!widget.embeddedInOnboarding &&\n'
        '            (constraints.maxWidth < 330 || textScale > 1.3)',
      ),
    );
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

String _methodSource(String source, String methodName) {
  final declaration = RegExp(
    r'\n  [A-Za-z_][A-Za-z0-9_<>,? ]+\s+' + RegExp.escape(methodName) + r'\(',
  ).firstMatch(source);
  if (declaration == null) fail('Missing method: $methodName');

  final memberPattern = RegExp(
    r'\n  [A-Za-z_][A-Za-z0-9_<>,? ]*\s+_[A-Za-z0-9]+(?:<[^>]+>)?\(',
  );
  var end = source.length;
  for (final match in memberPattern.allMatches(source, declaration.end)) {
    end = match.start;
    break;
  }
  return source.substring(declaration.start, end);
}

String _methodOrLocalSource(String source, String marker) {
  final index = source.indexOf(marker);
  expect(index, isNonNegative, reason: 'Missing marker: $marker');
  if (marker.startsWith('Widget ')) {
    final methodName = marker.split(' ').last;
    return _methodSource(source, methodName);
  }
  final start = (index - 240).clamp(0, source.length);
  final end = (index + 420).clamp(0, source.length);
  return source.substring(start, end);
}
