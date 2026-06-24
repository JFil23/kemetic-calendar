import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';

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
  });

  testWidgets('initial prompt remains absent for unsupported Ma’at details', (
    tester,
  ) async {
    await _pumpTemplateDetail(tester, 'the-weighing');

    expect(find.byKey(kMaatFlowInitialPromptSectionKey), findsNothing);
    expect(find.text('Begin reflection'), findsNothing);
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
    expect(scaffold, contains('initialPromptSpec == null'));
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
