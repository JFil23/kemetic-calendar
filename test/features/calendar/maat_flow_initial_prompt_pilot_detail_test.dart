import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/dawn_house_rite_flow.dart';

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
