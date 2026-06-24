import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';

void main() {
  tearDown(resetMaatFlowJoinedStateForTesting);

  testWidgets(
    'initial prompt no-op leaves flow details and join buttons unchanged',
    (tester) async {
      for (final templateKey in const <String>[
        'the-moon-return',
        'the-course',
        'the-offering-table',
        'the-decan-watch',
      ]) {
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

        expect(
          find.byKey(kMaatFlowInitialPromptSectionKey),
          findsNothing,
          reason: templateKey,
        );
        expect(
          find.text('Begin reflection'),
          findsNothing,
          reason: templateKey,
        );
        expect(find.byType(ElevatedButton), findsWidgets, reason: templateKey);
      }
    },
  );

  testWidgets(
    'initial prompt no-op leaves Flow Studio installed and uninstalled states unchanged',
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

  testWidgets('initial prompt no-op leaves landscape detail layout untouched', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: buildMaatFlowTemplateDetailPreviewForTesting(
          templateKey: 'the-offering-table',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(kMaatFlowInitialPromptSectionKey), findsNothing);
    expect(find.text('Join Flow'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'initial prompt no-op wiring does not touch Day View or journal paths',
    () {
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

      final dayViewSource = File(
        'lib/features/calendar/day_view.dart',
      ).readAsStringSync();
      final journalSource = File(
        'lib/features/journal/journal_controller.dart',
      ).readAsStringSync();

      expect(dayViewSource, isNot(contains('MaatFlowInitialPrompt')));
      expect(journalSource, isNot(contains('MaatFlowInitialPrompt')));
    },
  );
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
