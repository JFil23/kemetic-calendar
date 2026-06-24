import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/maat_flow_response_draft_store.dart';
import 'package:mobile/features/calendar/maat_flow_response_journal_blocks.dart';
import 'package:mobile/features/calendar/maat_flow_response_models.dart';
import 'package:mobile/features/calendar/maat_flow_response_resolver.dart';
import 'package:mobile/features/calendar/moon_return_flow.dart';
import 'package:mobile/features/calendar/the_course_flow.dart';
import 'package:mobile/features/calendar/the_decan_watch_flow.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';

void main() {
  test(
    'Moon Return initial prompt draft hydrates Day Sheet response specs',
    () {
      final store = MaatFlowResponseDraftStore();
      const text = 'I set down resentment.';
      final prompt = _prompt(kMoonReturnFlowKey);
      final sheet = _sheet(kMoonReturnFlowKey);

      store.rememberValue(
        flowKey: prompt.flowKey,
        value: MaatFlowResponseValue.text(
          specId: 'moon-return-set-down',
          text: text,
        ),
      );

      expect(_textValue(store.valuesForSpecs(sheet)), text);

      store.rememberValue(
        flowKey: sheet.single.flowKey,
        value: MaatFlowResponseValue.text(
          specId: 'moon-return-set-down',
          text: 'I set down the old argument.',
        ),
      );

      expect(
        _textValue(store.valuesForSpecs(prompt.fields)),
        'I set down the old argument.',
      );
    },
  );

  test('Course initial prompt draft hydrates Day Sheet response specs', () {
    final store = MaatFlowResponseDraftStore();
    final prompt = _prompt(kTheCourseFlowKey);
    final sheet = _sheet(kTheCourseFlowKey);

    store.rememberValue(
      flowKey: prompt.flowKey,
      value: MaatFlowResponseValue.text(
        specId: 'course-hour-action',
        text: 'Make the call before noon.',
      ),
    );

    expect(
      _textValue(store.valuesForSpecs(sheet)),
      'Make the call before noon.',
    );

    store.rememberValue(
      flowKey: sheet.single.flowKey,
      value: MaatFlowResponseValue.text(
        specId: 'course-hour-action',
        text: 'Write the answer plainly.',
      ),
    );

    expect(
      _textValue(store.valuesForSpecs(prompt.fields)),
      'Write the answer plainly.',
    );
  });

  test('Offering Table prompt shares chip and text drafts with Day Sheet', () {
    final store = MaatFlowResponseDraftStore();
    final prompt = _prompt(kOfferingTableFlowKey);
    final sheet = _sheet(kOfferingTableFlowKey);

    store.rememberValue(
      flowKey: prompt.flowKey,
      value: MaatFlowResponseValue.chips(
        specId: 'offering-table-fed',
        optionIds: <String>['water', 'care'],
      ),
    );
    store.rememberValue(
      flowKey: prompt.flowKey,
      value: MaatFlowResponseValue.text(
        specId: 'offering-table-provided',
        text: 'a clean cup and an answered message',
        multiline: true,
      ),
    );

    final sheetValues = store.valuesForSpecs(sheet);
    expect(sheetValues['offering-table-fed']?.optionIds, <String>[
      'water',
      'care',
    ]);
    expect(
      sheetValues['offering-table-provided']?.text,
      'a clean cup and an answered message',
    );

    store.rememberValue(
      flowKey: sheet.first.flowKey,
      value: MaatFlowResponseValue.text(
        specId: 'offering-table-provided',
        text: 'water, care, and rest',
        multiline: true,
      ),
    );

    expect(
      store.valuesForSpecs(prompt.fields)['offering-table-provided']?.text,
      'water, care, and rest',
    );
  });

  test(
    'Decan Watch prompt shares visibility, sky note, and bearing drafts',
    () {
      final store = MaatFlowResponseDraftStore();
      final prompt = _prompt(kDecanWatchFlowKey);
      final sheet = _sheet(kDecanWatchFlowKey);

      store.rememberValue(
        flowKey: prompt.flowKey,
        value: MaatFlowResponseValue.choice(
          specId: kDecanWatchResponseVisibilitySpecId,
          optionId: kDecanWatchVisibilityOutside,
        ),
      );
      store.rememberValue(
        flowKey: prompt.flowKey,
        value: MaatFlowResponseValue.text(
          specId: kDecanWatchResponseSkyNoteSpecId,
          text: 'a clear western glow',
          multiline: true,
        ),
      );
      store.rememberValue(
        flowKey: prompt.flowKey,
        value: MaatFlowResponseValue.text(
          specId: kDecanWatchResponseBearingSpecId,
          text: 'steadiness',
          multiline: true,
        ),
      );

      final sheetValues = store.valuesForSpecs(sheet);
      expect(
        sheetValues[kDecanWatchResponseVisibilitySpecId]?.optionIds,
        <String>[kDecanWatchVisibilityOutside],
      );
      expect(
        sheetValues[kDecanWatchResponseSkyNoteSpecId]?.text,
        'a clear western glow',
      );
      expect(sheetValues[kDecanWatchResponseBearingSpecId]?.text, 'steadiness');

      store.rememberValue(
        flowKey: sheet.first.flowKey,
        value: MaatFlowResponseValue.text(
          specId: kDecanWatchResponseSkyNoteSpecId,
          text: 'clouds opening in the west',
          multiline: true,
        ),
      );

      expect(
        store
            .valuesForSpecs(prompt.fields)[kDecanWatchResponseSkyNoteSpecId]
            ?.text,
        'clouds opening in the west',
      );
    },
  );

  test('draft sharing does not journal before completion', () {
    final draftStore = File(
      'lib/features/calendar/maat_flow_response_draft_store.dart',
    ).readAsStringSync();
    expect(draftStore, isNot(contains('Journal')));
    expect(draftStore, isNot(contains('completion')));

    final detailSource = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();
    final initialPromptSlot = _sourceBetween(
      detailSource,
      start: 'Widget _buildMaatFlowInitialPromptSlot',
      end: 'List<Widget> _buildMaatFlowOverviewZones',
    );
    expect(
      initialPromptSlot,
      contains('_initialPromptDraftValuesForFlow(spec.flowKey)'),
    );
    expect(detailSource, contains('kMaatFlowResponseDraftStore.rememberValue'));
    expect(initialPromptSlot, isNot(contains('onWriteJournalResponse')));
    expect(
      initialPromptSlot,
      isNot(contains('buildMaatJournalResponseBlocksForPolicy')),
    );

    final dayViewSource = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();
    final responseChangeHandler = _sourceBetween(
      dayViewSource,
      start: 'void _handleResponseChanged',
      end: 'Future<void> _syncResponseBlocks',
    );
    expect(
      responseChangeHandler,
      contains('_rememberInitialPromptDraftValue(value)'),
    );
    expect(responseChangeHandler, isNot(contains('_syncResponseBlocks')));
    expect(responseChangeHandler, isNot(contains('onRecordCompletion')));
  });

  test(
    'completion still turns hydrated draft values into one journal block',
    () {
      final store = MaatFlowResponseDraftStore();
      final sheet = _sheet(kMoonReturnFlowKey);
      store.rememberValue(
        flowKey: kMoonReturnFlowKey,
        value: MaatFlowResponseValue.text(
          specId: 'moon-return-set-down',
          text: 'I set down resentment.',
        ),
      );

      final previews = buildMaatFlowResponseJournalPreviews(
        specs: sheet,
        values: store.valuesForSpecs(sheet),
        completionStatus: CompletionStatus.observed,
        sourceIdForSpec: (_) => 'moon-return-source',
      );
      final blocks = buildMaatJournalResponseBlocksForPolicy(
        sourceIds: <String>['moon-return-source'],
        previews: previews,
        localDate: DateTime(2026, 6, 23),
      );

      expect(blocks, hasLength(1));
      expect(blocks.single.text, contains('I set down resentment.'));
    },
  );
}

MaatFlowInitialPromptSpec _prompt(String flowKey) {
  final spec = resolveMaatFlowInitialPromptSpec(flowKey: flowKey);
  expect(spec, isNotNull);
  return spec!;
}

List<MaatFlowResponseSpec> _sheet(String flowKey) {
  final specs = resolveMaatFlowResponseSpecs(
    flowKey: flowKey,
    surface: MaatFlowResponseSurface.calendarSheet,
    eventKey: flowKey == kMoonReturnFlowKey ? 'new' : null,
  );
  expect(specs, isNotEmpty);
  return specs;
}

String? _textValue(Map<String, MaatFlowResponseValue> values) {
  expect(values, hasLength(1));
  return values.values.single.text;
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
