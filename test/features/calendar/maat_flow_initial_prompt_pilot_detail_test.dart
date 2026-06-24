import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/dawn_house_rite_flow.dart';
import 'package:mobile/features/calendar/evening_threshold_rite_flow.dart';

void main() {
  tearDown(resetMaatFlowJoinedStateForTesting);

  testWidgets('enabled initial prompts render in template details', (
    tester,
  ) async {
    for (final entry in const <(String, String)>[
      ('the-moon-return', 'What do you set down?'),
      ('the-course', 'What action fits this hour?'),
      ('dawn-house-rite', 'What order do you bring into the day?'),
      ('evening-threshold-rite', 'What do you release tonight?'),
      ('the-offering-table', 'What was fed?'),
      ('the-decan-watch', 'What did the sky show?'),
      ('the-first-arrangement', 'What space will you put in order?'),
      ('the-living-pattern', 'What pattern are you watching?'),
      ('the-house-of-life', 'What knowledge are you preserving?'),
      ('hotep', 'What can be enough tonight?'),
      ('the-open-hand', 'What need are you willing to meet?'),
      ('the-djed', 'What must stand upright?'),
      ('the-tending', 'What care needs to become specific?'),
      ('the-kept-word', 'What word or agreement needs attention?'),
      ('the-wag', 'What gift, memory, or legacy will you carry?'),
      ('the-khat', 'What is the body asking for?'),
      ('track-the-sky', 'What change are you watching above?'),
      ('the-weighing', 'What needs to be placed on the scale?'),
      ('the-days-outside-the-year', 'What threshold are you crossing?'),
      ('the-fair-hearing', 'What must be heard before deciding?'),
      ('the-boundary-stone', 'What marker needs restoring?'),
      ('the-open-mouth', 'What word needs discipline?'),
      ('the-shore', 'What exchange needs honest measure?'),
      ('the-living-text', 'What line is asking to live through you?'),
      ('the-clearing', 'What heat needs space before response?'),
      ('het-heru', 'What hot force needs cooling?'),
      ('the-autobiography', 'What part of your record needs naming?'),
      ('the-true-name', 'What false account is ready to lose power?'),
      ('the-living-record', 'What record will you make living?'),
      ('the-oracle', 'What question are you carrying?'),
      ('the-wandering', 'What remains with you?'),
    ]) {
      await _pumpTemplateDetail(tester, entry.$1);

      expect(
        find.byKey(kMaatFlowInitialPromptSectionKey),
        findsOneWidget,
        reason: entry.$1,
      );
      expect(find.text('Begin reflection'), findsOneWidget, reason: entry.$1);
      expect(find.text(entry.$2), findsOneWidget, reason: entry.$1);
      expect(find.byType(ElevatedButton), findsWidgets, reason: entry.$1);
    }

    await _pumpTemplateDetail(tester, 'the-offering-table');
    expect(find.text('What did you provide today?'), findsOneWidget);

    await _pumpTemplateDetail(tester, 'hotep');
    expect(find.text('What did you let be enough tonight?'), findsOneWidget);

    await _pumpTemplateDetail(tester, 'the-kept-word');
    expect(
      find.text('What word, repair, or conversation needs to be remembered?'),
      findsOneWidget,
    );

    await _pumpTemplateDetail(tester, 'the-khat');
    expect(find.text('What care did you give the body?'), findsOneWidget);

    await _pumpTemplateDetail(tester, 'the-weighing');
    expect(
      find.text('What record, number, or correction needs to be witnessed?'),
      findsOneWidget,
    );

    await _pumpTemplateDetail(tester, 'the-oracle');
    expect(find.text('What shape did the sign take?'), findsOneWidget);

    await _pumpTemplateDetail(tester, 'the-living-record');
    expect(
      find.text(
        'What did you record, apply, or carry into the physical world?',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Ma’at detail pages show the flow name only once', (
    tester,
  ) async {
    for (final entry in const <(String, String)>[
      ('track-the-sky', 'Follow the sky'),
      ('dawn-house-rite', 'Dawn House Rite'),
      ('the-true-name', 'The True Name'),
    ]) {
      await _pumpTemplateDetail(tester, entry.$1);

      expect(find.byTooltip('Back'), findsOneWidget, reason: entry.$1);
      expect(find.text(entry.$2), findsOneWidget, reason: entry.$1);
    }
  });

  testWidgets('initial prompt remains absent for unsupported Ma’at details', (
    tester,
  ) async {
    await _pumpTemplateDetail(tester, 'evening_threshold');

    expect(find.byKey(kMaatFlowInitialPromptSectionKey), findsNothing);
    expect(find.text('Begin reflection'), findsNothing);
    expect(find.text('Join Flow'), findsOneWidget);
  });

  testWidgets('Dawn House detail puts entry field high and removes timezone UI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpTemplateDetail(tester, 'dawn-house-rite');

    expect(
      find.text(
        'Morning intention and purification ritual. Commit one purifying act and speak one mantra before the day begins.',
      ),
      findsOneWidget,
    );
    expect(find.text('What order do you bring into the day?'), findsOneWidget);
    expect(find.text('TIMEZONE'), findsNothing);
    expect(find.textContaining('Estimated from'), findsNothing);

    final promptTop = tester
        .getTopLeft(find.byKey(kMaatFlowInitialPromptSectionKey))
        .dy;
    final arcTop = tester.getTopLeft(find.text('THREE-DECAN ARC')).dy;
    final startTop = tester.getTopLeft(find.textContaining('Start:')).dy;

    expect(promptTop, lessThan(arcTop));
    expect(promptTop, lessThan(startTop));
  });

  testWidgets('Dawn House discreet explainer opens from info bubble only', (
    tester,
  ) async {
    await _pumpTemplateDetail(tester, 'dawn-house-rite');

    const explainer =
        'Changes wording only. Turn this on when the rite needs to look ordinary in public or shared space';
    expect(find.textContaining(explainer), findsNothing);

    await tester.ensureVisible(find.byTooltip('About Discreet mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('About Discreet mode'));
    await tester.pumpAndSettle();
    expect(find.textContaining(explainer), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.textContaining(explainer), findsNothing);
  });

  testWidgets(
    'Dawn House full description is collapsed, shorter, and Kemetic',
    (tester) async {
      const bannedPlaceName =
          'Egy'
          'pt';
      expect(kDawnHouseRiteOverview, contains('Kemetic'));
      expect(kDawnHouseRiteOverview, isNot(contains(bannedPlaceName)));
      expect(kDawnHouseRiteOverview.length, lessThan(420));

      await _pumpTemplateDetail(tester, 'dawn-house-rite');

      expect(
        tester
            .widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade))
            .crossFadeState,
        CrossFadeState.showFirst,
      );

      await tester.ensureVisible(find.text('FULL DESCRIPTION'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('FULL DESCRIPTION'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade))
            .crossFadeState,
        CrossFadeState.showSecond,
      );
      expect(
        find.textContaining('The Dawn House Rite rests on a clear Kemetic'),
        findsOneWidget,
      );
      expect(find.textContaining(bannedPlaceName), findsNothing);
    },
  );

  test('Dawn House practice warning stays after the outline', () {
    final detailSource = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();
    final dawnHouseScaffold = _sourceBetween(
      detailSource,
      start: 'Widget _buildDawnHouseRiteScaffold',
      end: 'Widget _buildEveningThresholdEventTile',
    );
    final outlineIndex = dawnHouseScaffold.indexOf('kDawnHouseRiteDays.map');
    final warningIndex = dawnHouseScaffold.indexOf(
      '_MaatFlowPracticeDisclaimerFooter',
    );

    expect(outlineIndex, isNonNegative);
    expect(warningIndex, isNonNegative);
    expect(warningIndex, greaterThan(outlineIndex));
  });

  testWidgets('Dawn House practice warning text renders', (tester) async {
    await _pumpTemplateDetail(tester, 'dawn-house-rite');

    expect(find.byKey(kMaatFlowPracticeDisclaimerFooterKey), findsWidgets);
  });

  testWidgets(
    'The Closing detail puts entry field high and removes timezone UI',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpTemplateDetail(tester, 'evening-threshold-rite');

      expect(
        find.text(
          'Evening release ritual. Close one loop, settle the house, and leave the day at the threshold.',
        ),
        findsOneWidget,
      );
      expect(find.text('What do you release tonight?'), findsOneWidget);
      expect(find.text('TIMEZONE'), findsNothing);
      expect(find.textContaining('Estimated from'), findsNothing);

      final promptTop = tester
          .getTopLeft(find.byKey(kMaatFlowInitialPromptSectionKey))
          .dy;
      final arcTop = tester.getTopLeft(find.text('THREE-DECAN ARC')).dy;
      final startTop = tester.getTopLeft(find.textContaining('Start:')).dy;

      expect(promptTop, lessThan(arcTop));
      expect(promptTop, lessThan(startTop));
    },
  );

  testWidgets('The Closing discreet explainer opens from info bubble only', (
    tester,
  ) async {
    await _pumpTemplateDetail(tester, 'evening-threshold-rite');

    const explainer =
        'Changes wording only. Turn this on when the rite needs to look ordinary in public or shared space';
    expect(find.textContaining(explainer), findsNothing);

    await tester.ensureVisible(find.byTooltip('About Discreet mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('About Discreet mode'));
    await tester.pumpAndSettle();
    expect(find.textContaining(explainer), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.textContaining(explainer), findsNothing);
  });

  test('all discreet mode rows expose the lightweight info affordance', () {
    final source = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();
    final switchSurface = _sourceBetween(
      source,
      start: 'Widget _buildMaatFlowSwitchSurface',
      end: 'Widget _buildMaatFlowInfoGlyph',
    );
    final infoGlyph = _sourceBetween(
      source,
      start: 'Widget _buildMaatFlowInfoGlyph',
      end: 'Widget _buildMaatFlowDetailSection',
    );

    expect(source.split("title: 'Discreet mode'").length - 1, 2);
    expect(source.split("infoTooltip: 'About Discreet mode'").length - 1, 2);
    expect(switchSurface, contains('_buildMaatFlowInfoGlyph'));
    expect(switchSurface, isNot(contains('Icons.info_outline')));
    expect(infoGlyph, contains("Text(\n            'i'"));
    expect(infoGlyph, contains('fontWeight: FontWeight.w400'));
    expect(infoGlyph, contains('width: 1.15'));
  });

  testWidgets(
    'The Closing full description is collapsed, shorter, and Kemetic',
    (tester) async {
      const bannedPlaceName =
          'Egy'
          'pt';
      expect(kEveningThresholdRiteOverview, contains('Kemetic'));
      expect(kEveningThresholdRiteOverview, isNot(contains(bannedPlaceName)));
      expect(kEveningThresholdRiteOverview.length, lessThan(520));

      await _pumpTemplateDetail(tester, 'evening-threshold-rite');

      expect(
        tester
            .widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade))
            .crossFadeState,
        CrossFadeState.showFirst,
      );

      await tester.ensureVisible(find.text('FULL DESCRIPTION'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('FULL DESCRIPTION'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade))
            .crossFadeState,
        CrossFadeState.showSecond,
      );
      expect(
        find.textContaining(
          'The Closing is a thirty-day evening flow rooted in the Kemetic',
        ),
        findsOneWidget,
      );
      expect(find.textContaining(bannedPlaceName), findsNothing);
    },
  );

  test('The Closing practice warning stays after the outline', () {
    final detailSource = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();
    final closingScaffold = _sourceBetween(
      detailSource,
      start: 'Widget _buildEveningThresholdRiteScaffold',
      end: 'Widget _buildTheWeighingEventTile',
    );
    final outlineIndex = closingScaffold.indexOf(
      'kEveningThresholdRiteDays.map',
    );
    final warningIndex = closingScaffold.indexOf(
      '_MaatFlowPracticeDisclaimerFooter',
    );

    expect(outlineIndex, isNonNegative);
    expect(warningIndex, isNonNegative);
    expect(warningIndex, greaterThan(outlineIndex));
  });

  testWidgets('The Closing practice warning text renders', (tester) async {
    await _pumpTemplateDetail(tester, 'evening-threshold-rite');

    expect(find.byKey(kMaatFlowPracticeDisclaimerFooterKey), findsWidgets);
  });

  testWidgets('core Ma’at details use the simplified high-entry layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const bannedPlaceName =
        'Egy'
        'pt';
    for (final detail in const <_CoreDetailLayoutCase>[
      _CoreDetailLayoutCase(
        key: 'track-the-sky',
        prompt: 'What change are you watching above?',
        shortDescription:
            'Sky observation flow. Track visible sky events and keep one clear line of witness when the sky changes.',
        fullDescriptionSnippet:
            'Follow the Sky places major visible sky events',
      ),
      _CoreDetailLayoutCase(
        key: 'the-weighing',
        prompt: 'What needs to be placed on the scale?',
        shortDescription:
            'Reckoning practice. Put one material, spoken, or conduct record on the scale and name one correction.',
        fullDescriptionSnippet:
            'The Weighing is a thirty-day Ma’at reckoning flow',
      ),
      _CoreDetailLayoutCase(
        key: 'the-offering-table',
        prompt: 'What was fed?',
        shortDescription:
            'Provision ritual. Begin with water, then feed what needs food, rest, or care.',
        fullDescriptionSnippet:
            'The Offering Table is a thirty-day provision flow',
      ),
      _CoreDetailLayoutCase(
        key: 'the-tending',
        prompt: 'What care needs to become specific?',
        shortDescription:
            'Specific care practice. Name who or what needs tending and complete one concrete act of care.',
        fullDescriptionSnippet: 'The Tending is a thirty-day care flow',
      ),
      _CoreDetailLayoutCase(
        key: 'the-kept-word',
        prompt: 'What word or agreement needs attention?',
        shortDescription:
            'Agreement practice. Name one word, repair, or conversation that needs clearer order.',
        fullDescriptionSnippet: 'The Kept Word is a thirty-day agreement flow',
      ),
      _CoreDetailLayoutCase(
        key: 'the-course',
        prompt: 'What action fits this hour?',
        shortDescription:
            'Time-orientation practice. Locate yourself in the day, decan, and season, then choose one fitting action.',
        fullDescriptionSnippet:
            'The Course is a thirty-day time-orientation flow',
      ),
      _CoreDetailLayoutCase(
        key: 'the-moon-return',
        prompt: 'What do you set down?',
        shortDescription:
            'Lunar release and return practice. Set something down at the new moon and notice what fills at the full.',
        fullDescriptionSnippet:
            'The Moon Return follows the lunar rhythm of emptying and fullness',
      ),
      _CoreDetailLayoutCase(
        key: 'the-wag',
        prompt: 'What gift, memory, or legacy will you carry?',
        shortDescription:
            'Ancestor remembrance cycle. Keep the table, carry a gift or memory, and return with what remains.',
        fullDescriptionSnippet: 'The Wag is an annual Kemetic ancestor flow',
      ),
      _CoreDetailLayoutCase(
        key: 'the-decan-watch',
        prompt: 'What did the sky show?',
        shortDescription:
            'Night-sky boundary practice. Watch the decan opening honestly and carry one bearing into the next ten days.',
        fullDescriptionSnippet: 'The Decan Watch meets each ten-day boundary',
      ),
      _CoreDetailLayoutCase(
        key: 'the-days-outside-the-year',
        prompt: 'What threshold are you crossing?',
        shortDescription:
            'Year-threshold practice. Close the old year, receive the outside days, and open Wep Ronpet cleanly.',
        fullDescriptionSnippet:
            'The Days Outside the Year is an annual threshold flow',
      ),
      _CoreDetailLayoutCase(
        key: 'the-open-hand',
        prompt: 'What need are you willing to meet?',
        shortDescription:
            'Outward provision practice. Meet one visible need with time, care, skill, resource, or protection.',
        fullDescriptionSnippet:
            'The Open Hand is a thirty-day outward provision flow',
      ),
      _CoreDetailLayoutCase(
        key: 'the-djed',
        prompt: 'What must stand upright?',
        shortDescription:
            'Stability practice. Name what must stand upright and restore one load-bearing part of life.',
        fullDescriptionSnippet: 'The Djed is a thirty-day stability flow',
      ),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _pumpTemplateDetail(tester, detail.key);

      expect(find.text(detail.shortDescription), findsOneWidget);
      expect(find.text(detail.prompt), findsOneWidget);
      expect(find.text('TIMEZONE'), findsNothing, reason: detail.key);
      expect(find.text('PREVIEW TIMEZONE'), findsNothing, reason: detail.key);
      expect(find.textContaining('Estimated from'), findsNothing);
      expect(find.textContaining('Choose your U.S. timezone'), findsNothing);

      final promptTop = tester
          .getTopLeft(find.byKey(kMaatFlowInitialPromptSectionKey))
          .dy;
      final arcTop = tester.getTopLeft(find.text('THREE-DECAN ARC')).dy;
      expect(promptTop, lessThan(arcTop), reason: detail.key);

      expect(
        tester
            .widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade))
            .crossFadeState,
        CrossFadeState.showFirst,
        reason: detail.key,
      );

      await tester.ensureVisible(find.text('FULL DESCRIPTION'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('FULL DESCRIPTION'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.textContaining(detail.fullDescriptionSnippet),
        findsOneWidget,
      );
      expect(find.textContaining(bannedPlaceName), findsNothing);
    }
  });

  testWidgets('decan Ma’at details use the simplified high-entry layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 2100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const bannedPlaceName =
        'Egy'
        'pt';
    for (final detail in const <_CoreDetailLayoutCase>[
      _CoreDetailLayoutCase(
        key: 'the-fair-hearing',
        prompt: 'What must be heard before deciding?',
        shortDescription:
            'Fairness practice. Hear fully before deciding, keep the measure even, and pronounce what is clear.',
        fullDescriptionSnippet: 'A 30-day practice of fair judgment',
      ),
      _CoreDetailLayoutCase(
        key: 'the-first-arrangement',
        prompt: 'What space will you put in order?',
        shortDescription:
            'Space-order practice. Choose one physical space, see what belongs, and put it back into order.',
        fullDescriptionSnippet: 'A 30-day space-order practice',
      ),
      _CoreDetailLayoutCase(
        key: 'the-living-pattern',
        prompt: 'What pattern are you watching?',
        shortDescription:
            'Observation practice. Watch one natural pattern patiently and carry its principle into action.',
        fullDescriptionSnippet: 'A 30-day observation practice',
      ),
      _CoreDetailLayoutCase(
        key: 'the-house-of-life',
        prompt: 'What knowledge are you preserving?',
        shortDescription:
            'Knowledge practice. Learn accurately, preserve one useful note, and transmit it with care.',
        fullDescriptionSnippet: 'A 30-day scribal practice',
      ),
      _CoreDetailLayoutCase(
        key: 'the-boundary-stone',
        prompt: 'What marker needs restoring?',
        shortDescription:
            'Boundary practice. Name what moved, restore one marker, and return measure to its place.',
        fullDescriptionSnippet: 'A 30-day boundary practice',
      ),
      _CoreDetailLayoutCase(
        key: 'hotep',
        prompt: 'What can be enough tonight?',
        shortDescription:
            'Evening peace practice. Name what was given, release what is enough, and cool the heart before sleep.',
        fullDescriptionSnippet: 'A 30-day evening peace practice',
      ),
      _CoreDetailLayoutCase(
        key: 'the-open-mouth',
        prompt: 'What word needs discipline?',
        shortDescription:
            'Speech practice. Govern one word, repair what needs repair, and let speech serve Ma’at.',
        fullDescriptionSnippet: 'A 30-day speech practice',
      ),
      _CoreDetailLayoutCase(
        key: 'the-living-record',
        prompt: 'What record will you make living?',
        shortDescription:
            'Record practice. Turn one decan into a living record across calendar, journal, and body.',
        fullDescriptionSnippet: 'A 30-day record practice',
      ),
      _CoreDetailLayoutCase(
        key: 'het-heru',
        prompt: 'What hot force needs cooling?',
        shortDescription:
            'Cooling practice. Meet the hot force with beauty, joy, rest, or feast until it returns.',
        fullDescriptionSnippet: 'A 30-day cooling practice',
      ),
      _CoreDetailLayoutCase(
        key: 'the-shore',
        prompt: 'What exchange needs honest measure?',
        shortDescription:
            'Exchange practice. Bring one gift, labor, or return closer to honest measure.',
        fullDescriptionSnippet: 'A 30-day exchange practice',
      ),
      _CoreDetailLayoutCase(
        key: 'the-autobiography',
        prompt: 'What part of your record needs naming?',
        shortDescription:
            'Life-record practice. Name one capacity, work, gift, or claim with clearer evidence.',
        fullDescriptionSnippet: 'A 30-day life-record practice',
      ),
      _CoreDetailLayoutCase(
        key: 'the-true-name',
        prompt: 'What false account is ready to lose power?',
        shortDescription:
            'Private naming practice. Measure a false account against the record and stand closer to the accurate name.',
        fullDescriptionSnippet: 'A 30-day private naming practice',
      ),
      _CoreDetailLayoutCase(
        key: 'the-living-text',
        prompt: 'What line is asking to live through you?',
        shortDescription:
            'Library practice. Let one line become question, insight, application, or living mark.',
        fullDescriptionSnippet: 'A 30-day Library practice',
      ),
      _CoreDetailLayoutCase(
        key: 'the-clearing',
        prompt: 'What heat needs space before response?',
        shortDescription:
            'Temperance practice. Make space before response and act from the cleared place.',
        fullDescriptionSnippet: 'A 30-day temperance practice',
      ),
      _CoreDetailLayoutCase(
        key: 'the-wandering',
        prompt: 'What remains with you?',
        shortDescription:
            'Grief accompaniment. Honor what was lost and notice one thing that remains.',
        fullDescriptionSnippet: 'A 30-day evening grief accompaniment',
      ),
      _CoreDetailLayoutCase(
        key: 'the-khat',
        prompt: 'What is the body asking for?',
        shortDescription:
            'Body-care practice. Listen to what the body asks and answer with one concrete act of care.',
        fullDescriptionSnippet: 'A 30-day body-care practice',
      ),
      _CoreDetailLayoutCase(
        key: 'the-oracle',
        prompt: 'What question are you carrying?',
        shortDescription:
            'Dream-question practice. Carry one question, receive without forcing meaning, and test through grounded action.',
        fullDescriptionSnippet: 'A 30-day dream-question practice',
      ),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _pumpTemplateDetail(tester, detail.key);

      expect(find.text(detail.shortDescription), findsOneWidget);
      expect(find.text(detail.prompt), findsOneWidget);
      expect(find.text('TIMEZONE'), findsNothing, reason: detail.key);
      expect(find.text('PREVIEW TIMEZONE'), findsNothing, reason: detail.key);
      expect(find.textContaining('Estimated from'), findsNothing);
      expect(find.textContaining('Choose your U.S. timezone'), findsNothing);

      final promptTop = tester
          .getTopLeft(find.byKey(kMaatFlowInitialPromptSectionKey))
          .dy;
      final arcTop = tester.getTopLeft(find.text('THREE-DECAN ARC')).dy;
      expect(promptTop, lessThan(arcTop), reason: detail.key);

      expect(
        tester
            .widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade))
            .crossFadeState,
        CrossFadeState.showFirst,
        reason: detail.key,
      );

      await tester.ensureVisible(find.text('FULL DESCRIPTION'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('FULL DESCRIPTION'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.textContaining(detail.fullDescriptionSnippet),
        findsOneWidget,
      );
      expect(find.textContaining(bannedPlaceName), findsNothing);
    }
  });

  test('core Ma’at detail footer notes stay below outlines', () {
    final detailSource = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();

    for (final order in const <_CoreFooterOrderCase>[
      _CoreFooterOrderCase(
        start: 'Widget _buildTrackSkyScaffold',
        end: 'Widget _buildDawnHouseRiteDayTile',
        outlineMarker: '_buildMaatFlowOverviewZones',
        footerMarker: '_MaatFlowPracticeDisclaimerFooter',
      ),
      _CoreFooterOrderCase(
        start: 'Widget _buildTheWeighingScaffold',
        end: 'Widget _buildTheTendingEventTile',
        outlineMarker: 'kTheWeighingEvents.map',
        footerMarker: '_MaatFlowPrivacyFooter',
      ),
      _CoreFooterOrderCase(
        start: 'Widget _buildTheTendingScaffold',
        end: 'Widget _buildKeptWordEventTile',
        outlineMarker: 'kTheTendingEvents.map',
        footerMarker: '_MaatFlowPrivacyFooter',
      ),
      _CoreFooterOrderCase(
        start: 'Widget _buildKeptWordScaffold',
        end: 'Widget _buildCourseEventTile',
        outlineMarker: 'kKeptWordEvents.map',
        footerMarker: '_MaatFlowPrivacyFooter',
      ),
      _CoreFooterOrderCase(
        start: 'Widget _buildWagScaffold',
        end: 'Widget _buildDecanWatchScaffold',
        outlineMarker: 'kWagEvents.map',
        footerMarker: '_MaatFlowPrivacyFooter',
      ),
      _CoreFooterOrderCase(
        start: 'Widget _buildDecanWatchScaffold',
        end: 'Widget _buildOpenHandEventTile',
        outlineMarker: 'preview.map',
        footerMarker: '_MaatFlowPrivacyFooter',
      ),
      _CoreFooterOrderCase(
        start: 'Widget _buildOpenHandScaffold',
        end: 'DjedEnrollmentWindow? _resolveDjedPreviewWindow',
        outlineMarker: 'kOpenHandEvents.map',
        footerMarker: '_MaatFlowPrivacyFooter',
      ),
      _CoreFooterOrderCase(
        start: 'Widget _buildDjedScaffold',
        end:
            'DaysOutsideYearEnrollmentWindow? _resolveDaysOutsideYearPreviewWindow',
        outlineMarker: 'kDjedEvents.map',
        footerMarker: '_MaatFlowPrivacyFooter',
      ),
      _CoreFooterOrderCase(
        start: 'Widget _buildDaysOutsideYearScaffold',
        end: 'Widget _buildMoonReturnScaffold',
        outlineMarker: 'kDaysOutsideEvents.map',
        footerMarker: '_MaatFlowPrivacyFooter',
      ),
      _CoreFooterOrderCase(
        start: 'Widget _buildMoonReturnScaffold',
        end: 'Widget _buildCourseScaffold',
        outlineMarker: 'preview.map',
        footerMarker: '_MaatFlowPrivacyFooter',
      ),
      _CoreFooterOrderCase(
        start: 'Widget _buildCourseScaffold',
        end: 'Widget _buildOfferingTableDayTile',
        outlineMarker: 'kTheCourseEvents.map',
        footerMarker: '_MaatFlowPracticeDisclaimerFooter',
      ),
      _CoreFooterOrderCase(
        start: 'Widget _buildOfferingTableScaffold',
        end: 'Widget _buildSequenceScaffold',
        outlineMarker: 'kOfferingTableDays',
        footerMarker: '_MaatFlowPracticeDisclaimerFooter',
      ),
    ]) {
      final scaffold = _sourceBetween(
        detailSource,
        start: order.start,
        end: order.end,
      );
      final outlineIndex = scaffold.indexOf(order.outlineMarker);
      final footerIndex = scaffold.indexOf(order.footerMarker);

      expect(outlineIndex, isNonNegative, reason: order.start);
      expect(footerIndex, isNonNegative, reason: order.start);
      expect(footerIndex, greaterThan(outlineIndex), reason: order.start);
    }
  });

  test('decan Ma’at detail footer notes stay below nine sittings', () {
    final detailSource = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();
    final scaffold = _sourceBetween(
      detailSource,
      start: 'Widget _buildMaatDecanFlowScaffold',
      end: 'Widget _buildOpenHandScaffold',
    );

    final outlineIndex = scaffold.indexOf('definition.events.map');
    final selectedWindowIndex = scaffold.indexOf('Selected decan opening');
    final timingIndex = scaffold.indexOf('Morning sittings use dawn');
    final routingIndex = scaffold.indexOf(
      '_buildMaatFlowNotice(definition.routingSummary)',
    );
    final safetyIndex = scaffold.indexOf('definition.safetyNote');
    final footerIndex = scaffold.indexOf('_MaatFlowPrivacyFooter');

    expect(outlineIndex, isNonNegative);
    expect(selectedWindowIndex, greaterThan(outlineIndex));
    expect(timingIndex, greaterThan(outlineIndex));
    expect(routingIndex, greaterThan(outlineIndex));
    expect(safetyIndex, greaterThan(outlineIndex));
    expect(footerIndex, greaterThan(outlineIndex));
  });

  testWidgets('legacy Evening Threshold remains separate from Closing layout', (
    tester,
  ) async {
    await _pumpTemplateDetail(tester, 'evening_threshold');

    expect(find.byKey(kMaatFlowInitialPromptSectionKey), findsNothing);
    expect(find.text('What do you release tonight?'), findsNothing);
    expect(
      find.text(
        'Evening release ritual. Close one loop, settle the house, and leave the day at the threshold.',
      ),
      findsNothing,
    );
    expect(find.text('Join Flow'), findsOneWidget);
  });

  testWidgets('initial prompt survives rebuild and orientation change', (
    tester,
  ) async {
    await _pumpTemplateDetail(tester, 'the-offering-table');
    expect(find.byKey(kMaatFlowInitialPromptSectionKey), findsOneWidget);
    expect(find.text('What was fed?'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: buildMaatFlowTemplateDetailPreviewForTesting(
          templateKey: 'the-offering-table',
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(kMaatFlowInitialPromptSectionKey), findsOneWidget);

    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpTemplateDetail(tester, 'the-offering-table');
    expect(find.byKey(kMaatFlowInitialPromptSectionKey), findsOneWidget);
    expect(find.text('What was fed?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'initial prompt draft hydrates after closing and reopening detail',
    (tester) async {
      const fieldKey = ValueKey<String>(
        'maat-flow-response-field:moon-return-set-down',
      );

      await _pumpTemplateDetail(tester, 'the-moon-return');
      await tester.ensureVisible(find.byKey(fieldKey));
      await tester.enterText(find.byKey(fieldKey), 'I set down resentment.');
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      await _pumpTemplateDetail(tester, 'the-moon-return');
      await tester.ensureVisible(find.byKey(fieldKey));

      final field = tester.widget<TextFormField>(find.byKey(fieldKey));
      expect(field.controller?.text, 'I set down resentment.');
    },
  );

  testWidgets(
    'initial prompt leaves Flow Studio installed and uninstalled states unchanged',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: buildMaatFlowsListPreviewForTesting(
            joinedKeys: const <String>{'the-course'},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(kMaatFlowInitialPromptSectionKey), findsNothing);
      expect(find.text("Ma'at Flows"), findsOneWidget);
      expect(find.text('active'), findsWidgets);
      expect(find.text('NOT YET JOINED'), findsOneWidget);
    },
  );

  test('initial prompt draft wiring stays separate from journal writes', () {
    final detailSource = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();
    final scaffold = _sourceBetween(
      detailSource,
      start: 'Widget _buildMaatFlowDetailScaffold',
      end: 'List<Widget> _buildMaatFlowOverviewZones',
    );

    expect(scaffold, contains('resolveMaatFlowInitialPromptSpec'));
    expect(scaffold, contains('flowKey: widget.template.key'));
    expect(scaffold, contains('appendInitialPrompt'));
    expect(scaffold, contains('_buildCurrentInitialPromptSlot'));
    expect(scaffold, contains('_buildMaatFlowInitialPromptSlot'));
    expect(detailSource, contains('kMaatFlowResponseDraftStore.rememberValue'));
    expect(scaffold, isNot(contains('onWriteJournalResponse')));
    expect(
      scaffold,
      isNot(contains('buildMaatJournalResponseBlocksForPolicy')),
    );

    final dayViewSource = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();
    final journalSource = File(
      'lib/features/journal/journal_controller.dart',
    ).readAsStringSync();
    final changeHandler = _sourceBetween(
      dayViewSource,
      start: 'void _handleResponseChanged',
      end: 'Future<void> _syncResponseBlocks',
    );

    expect(changeHandler, contains('_rememberInitialPromptDraftValue(value)'));
    expect(changeHandler, isNot(contains('_syncResponseBlocks')));
    expect(changeHandler, isNot(contains('onWriteJournalResponse')));
    expect(journalSource, isNot(contains('MaatFlowInitialPrompt')));
  });
}

class _CoreDetailLayoutCase {
  const _CoreDetailLayoutCase({
    required this.key,
    required this.prompt,
    required this.shortDescription,
    required this.fullDescriptionSnippet,
  });

  final String key;
  final String prompt;
  final String shortDescription;
  final String fullDescriptionSnippet;
}

class _CoreFooterOrderCase {
  const _CoreFooterOrderCase({
    required this.start,
    required this.end,
    required this.outlineMarker,
    required this.footerMarker,
  });

  final String start;
  final String end;
  final String outlineMarker;
  final String footerMarker;
}

Future<void> _pumpTemplateDetail(
  WidgetTester tester,
  String templateKey,
) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: buildMaatFlowTemplateDetailPreviewForTesting(
        templateKey: templateKey,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

String _sourceBetween(
  String source, {
  required String start,
  required String end,
}) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: start);
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: end);
  return source.substring(startIndex, endIndex);
}
