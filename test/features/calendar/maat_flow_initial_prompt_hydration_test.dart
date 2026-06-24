import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/dawn_house_rite_flow.dart';
import 'package:mobile/features/calendar/evening_threshold_rite_flow.dart';
import 'package:mobile/features/calendar/maat_decan_flow.dart';
import 'package:mobile/features/calendar/maat_flow_response_draft_store.dart';
import 'package:mobile/features/calendar/maat_flow_response_journal_blocks.dart';
import 'package:mobile/features/calendar/maat_flow_response_models.dart';
import 'package:mobile/features/calendar/maat_flow_response_resolver.dart';
import 'package:mobile/features/calendar/moon_return_flow.dart';
import 'package:mobile/features/calendar/the_course_flow.dart';
import 'package:mobile/features/calendar/the_decan_watch_flow.dart';
import 'package:mobile/features/calendar/the_djed_flow.dart';
import 'package:mobile/features/calendar/the_kept_word_flow.dart';
import 'package:mobile/features/calendar/the_open_hand_flow.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/the_tending_flow.dart';
import 'package:mobile/features/calendar/the_wag_flow.dart';

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

  test(
    'Dawn House Rite initial prompt draft hydrates Day Sheet response specs',
    () {
      final store = MaatFlowResponseDraftStore();
      final prompt = _prompt(kDawnHouseRiteFlowKey);
      final sheet = _sheet(kDawnHouseRiteFlowKey);

      store.rememberValue(
        flowKey: prompt.flowKey,
        value: MaatFlowResponseValue.text(
          specId: 'dawn-house-order-act',
          text: 'clear the table before sunrise',
        ),
      );

      expect(
        _textValue(store.valuesForSpecs(sheet)),
        'clear the table before sunrise',
      );

      store.rememberValue(
        flowKey: sheet.single.flowKey,
        value: MaatFlowResponseValue.text(
          specId: 'dawn-house-order-act',
          text: 'wash the cup and return the cloth',
        ),
      );

      expect(
        _textValue(store.valuesForSpecs(prompt.fields)),
        'wash the cup and return the cloth',
      );
    },
  );

  test('Closing initial prompt draft hydrates Day Sheet response specs', () {
    final store = MaatFlowResponseDraftStore();
    final prompt = _prompt(kEveningThresholdRiteFlowKey);
    final sheet = _sheet(kEveningThresholdRiteFlowKey);

    store.rememberValue(
      flowKey: prompt.flowKey,
      value: MaatFlowResponseValue.text(
        specId: 'closing-release-tonight',
        text: 'the unfinished worry',
        multiline: true,
      ),
    );

    expect(_textValue(store.valuesForSpecs(sheet)), 'the unfinished worry');

    store.rememberValue(
      flowKey: sheet.single.flowKey,
      value: MaatFlowResponseValue.text(
        specId: 'closing-release-tonight',
        text: 'the old loop',
        multiline: true,
      ),
    );

    expect(_textValue(store.valuesForSpecs(prompt.fields)), 'the old loop');
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
    'First Arrangement prompt shares chip and text drafts with Day Sheet',
    () {
      final store = MaatFlowResponseDraftStore();
      final prompt = _prompt(kFirstArrangementFlowKey);
      final sheet = _sheet(kFirstArrangementFlowKey);

      store.rememberValue(
        flowKey: prompt.flowKey,
        value: MaatFlowResponseValue.chips(
          specId: 'first-arrangement-ordered',
          optionIds: <String>['cleared', 'made_visible'],
        ),
      );
      store.rememberValue(
        flowKey: prompt.flowKey,
        value: MaatFlowResponseValue.text(
          specId: 'first-arrangement-space-changed',
          text: 'the entry shelf',
          multiline: true,
        ),
      );

      final sheetValues = store.valuesForSpecs(sheet);
      expect(sheetValues['first-arrangement-ordered']?.optionIds, <String>[
        'cleared',
        'made_visible',
      ]);
      expect(
        sheetValues['first-arrangement-space-changed']?.text,
        'the entry shelf',
      );

      store.rememberValue(
        flowKey: sheet.first.flowKey,
        value: MaatFlowResponseValue.text(
          specId: 'first-arrangement-space-changed',
          text: 'the desk and tray',
          multiline: true,
        ),
      );

      expect(
        store
            .valuesForSpecs(prompt.fields)['first-arrangement-space-changed']
            ?.text,
        'the desk and tray',
      );
    },
  );

  test('Living Pattern prompt shares chip and text drafts with Day Sheet', () {
    final store = MaatFlowResponseDraftStore();
    final prompt = _prompt(kLivingPatternFlowKey);
    final sheet = _sheet(kLivingPatternFlowKey);

    store.rememberValue(
      flowKey: prompt.flowKey,
      value: MaatFlowResponseValue.chips(
        specId: 'living-pattern-observed',
        optionIds: <String>['growth', 'return'],
      ),
    );
    store.rememberValue(
      flowKey: prompt.flowKey,
      value: MaatFlowResponseValue.text(
        specId: 'living-pattern-principle',
        text: 'patient timing',
        multiline: true,
      ),
    );

    final sheetValues = store.valuesForSpecs(sheet);
    expect(sheetValues['living-pattern-observed']?.optionIds, <String>[
      'growth',
      'return',
    ]);
    expect(sheetValues['living-pattern-principle']?.text, 'patient timing');

    store.rememberValue(
      flowKey: sheet.first.flowKey,
      value: MaatFlowResponseValue.text(
        specId: 'living-pattern-principle',
        text: 'cyclical attention',
        multiline: true,
      ),
    );

    expect(
      store.valuesForSpecs(prompt.fields)['living-pattern-principle']?.text,
      'cyclical attention',
    );
  });

  test('House of Life prompt shares chip and text drafts with Day Sheet', () {
    final store = MaatFlowResponseDraftStore();
    final prompt = _prompt(kHouseOfLifeFlowKey);
    final sheet = _sheet(kHouseOfLifeFlowKey);

    store.rememberValue(
      flowKey: prompt.flowKey,
      value: MaatFlowResponseValue.chips(
        specId: 'house-of-life-clearer',
        optionIds: <String>['question', 'source'],
      ),
    );
    store.rememberValue(
      flowKey: prompt.flowKey,
      value: MaatFlowResponseValue.text(
        specId: 'house-of-life-learned',
        text: 'copying the source note',
        multiline: true,
      ),
    );

    final sheetValues = store.valuesForSpecs(sheet);
    expect(sheetValues['house-of-life-clearer']?.optionIds, <String>[
      'question',
      'source',
    ]);
    expect(
      sheetValues['house-of-life-learned']?.text,
      'copying the source note',
    );

    store.rememberValue(
      flowKey: sheet.first.flowKey,
      value: MaatFlowResponseValue.text(
        specId: 'house-of-life-learned',
        text: 'transmitting the useful note',
        multiline: true,
      ),
    );

    expect(
      store.valuesForSpecs(prompt.fields)['house-of-life-learned']?.text,
      'transmitting the useful note',
    );
  });

  test('Hotep prompt shares offer-safe drafts with Day Sheet', () {
    final store = MaatFlowResponseDraftStore();
    final prompt = _prompt(kHotepFlowKey);
    final sheet = _sheet(kHotepFlowKey);

    expect(
      sheet.every((spec) => spec.offerJournalInclusionDefault == false),
      isTrue,
    );

    store.rememberValue(
      flowKey: prompt.flowKey,
      value: MaatFlowResponseValue.chips(
        specId: 'hotep-cooled',
        optionIds: <String>['given', 'settled'],
      ),
    );
    store.rememberValue(
      flowKey: prompt.flowKey,
      value: MaatFlowResponseValue.text(
        specId: 'hotep-enough-tonight',
        text: 'private obligation detail.',
        multiline: true,
      ),
    );

    final sheetValues = store.valuesForSpecs(sheet);
    expect(sheetValues['hotep-cooled']?.optionIds, <String>[
      'given',
      'settled',
    ]);
    expect(
      sheetValues['hotep-enough-tonight']?.text,
      'private obligation detail.',
    );

    store.rememberValue(
      flowKey: sheet.first.flowKey,
      value: MaatFlowResponseValue.text(
        specId: 'hotep-enough-tonight',
        text: 'updated private obligation detail.',
        multiline: true,
      ),
    );

    expect(
      store.valuesForSpecs(prompt.fields)['hotep-enough-tonight']?.text,
      'updated private obligation detail.',
    );
  });

  test('Open Hand prompt shares offered provision drafts with Day Sheet', () {
    _expectChipTextDraftSharing(
      flowKey: kTheOpenHandFlowKey,
      chipSpecId: 'open-hand-given',
      initialOptions: <String>['time', 'attention'],
      updatedOptions: <String>['time', 'attention', 'labor'],
      textSpecId: 'open-hand-moved',
      initialText: 'where need was visible',
      updatedText: 'one concrete act of help',
    );
  });

  test('Djed prompt shares offered restoration drafts with Day Sheet', () {
    _expectChipTextDraftSharing(
      flowKey: kTheDjedFlowKey,
      chipSpecId: 'djed-stood-upright',
      initialOptions: <String>['practice'],
      updatedOptions: <String>['practice', 'rest'],
      textSpecId: 'djed-restored',
      initialText: 'an evening practice',
      updatedText: 'one restored load-bearing habit',
    );
  });

  test('Tending prompt shares default-off care drafts with Day Sheet', () {
    _expectChipTextDraftSharing(
      flowKey: kTheTendingFlowKey,
      chipSpecId: 'tending-care-specific',
      initialOptions: <String>['seen', 'repaired'],
      updatedOptions: <String>['seen', 'repaired', 'cleaned'],
      textSpecId: 'tending-act-completed',
      initialText: 'calling before the day closed',
      updatedText: 'clearing one practical obstacle',
      expectedDefaultOff: true,
    );
  });

  test(
    'Kept Word prompt shares default-off agreement drafts with Day Sheet',
    () {
      _expectChoiceTextDraftSharing(
        flowKey: kKeptWordFlowKey,
        choiceSpecId: 'kept-word-status',
        initialOption: 'renegotiated',
        updatedOption: 'still_in_process',
        textSpecId: 'kept-word-remembered',
        initialText: 'the repaired conversation belongs in memory',
        updatedText: 'the next repair step is named',
        expectedDefaultOff: true,
      );
    },
  );

  test('Wag prompt shares default-off memory drafts with Day Sheet', () {
    _expectChipTextDraftSharing(
      flowKey: kTheWagFlowKey,
      chipSpecId: 'wag-remembered',
      initialOptions: <String>['table', 'legacy'],
      updatedOptions: <String>['story'],
      textSpecId: 'wag-carried',
      initialText: 'one remembered gift',
      updatedText: 'the updated remembered story',
      expectedDefaultOff: true,
    );
  });

  test('Khat prompt shares default-off body-care drafts with Day Sheet', () {
    _expectChipTextDraftSharing(
      flowKey: kKhatFlowKey,
      chipSpecId: 'khat-body-asked',
      initialOptions: <String>['water', 'rest'],
      updatedOptions: <String>['care'],
      textSpecId: 'khat-care-given',
      initialText: 'five slow breaths',
      updatedText: 'the updated body-care note',
      expectedDefaultOff: true,
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

void _expectChipTextDraftSharing({
  required String flowKey,
  required String chipSpecId,
  required List<String> initialOptions,
  required List<String> updatedOptions,
  required String textSpecId,
  required String initialText,
  required String updatedText,
  bool expectedDefaultOff = false,
}) {
  final store = MaatFlowResponseDraftStore();
  final prompt = _prompt(flowKey);
  final sheet = _sheet(flowKey);

  if (expectedDefaultOff) {
    expect(
      sheet.every((spec) => spec.offerJournalInclusionDefault == false),
      isTrue,
    );
  }

  store.rememberValue(
    flowKey: prompt.flowKey,
    value: MaatFlowResponseValue.chips(
      specId: chipSpecId,
      optionIds: initialOptions,
    ),
  );
  store.rememberValue(
    flowKey: prompt.flowKey,
    value: MaatFlowResponseValue.text(
      specId: textSpecId,
      text: initialText,
      multiline: true,
    ),
  );

  final sheetValues = store.valuesForSpecs(sheet);
  expect(sheetValues[chipSpecId]?.optionIds, initialOptions);
  expect(sheetValues[textSpecId]?.text, initialText);

  store.rememberValue(
    flowKey: sheet.first.flowKey,
    value: MaatFlowResponseValue.chips(
      specId: chipSpecId,
      optionIds: updatedOptions,
    ),
  );
  store.rememberValue(
    flowKey: sheet.first.flowKey,
    value: MaatFlowResponseValue.text(
      specId: textSpecId,
      text: updatedText,
      multiline: true,
    ),
  );

  final promptValues = store.valuesForSpecs(prompt.fields);
  expect(promptValues[chipSpecId]?.optionIds, updatedOptions);
  expect(promptValues[textSpecId]?.text, updatedText);
}

void _expectChoiceTextDraftSharing({
  required String flowKey,
  required String choiceSpecId,
  required String initialOption,
  required String updatedOption,
  required String textSpecId,
  required String initialText,
  required String updatedText,
  bool expectedDefaultOff = false,
}) {
  final store = MaatFlowResponseDraftStore();
  final prompt = _prompt(flowKey);
  final sheet = _sheet(flowKey);

  if (expectedDefaultOff) {
    expect(
      sheet.every((spec) => spec.offerJournalInclusionDefault == false),
      isTrue,
    );
  }

  store.rememberValue(
    flowKey: prompt.flowKey,
    value: MaatFlowResponseValue.choice(
      specId: choiceSpecId,
      optionId: initialOption,
    ),
  );
  store.rememberValue(
    flowKey: prompt.flowKey,
    value: MaatFlowResponseValue.text(
      specId: textSpecId,
      text: initialText,
      multiline: true,
    ),
  );

  final sheetValues = store.valuesForSpecs(sheet);
  expect(sheetValues[choiceSpecId]?.optionIds, <String>[initialOption]);
  expect(sheetValues[textSpecId]?.text, initialText);

  store.rememberValue(
    flowKey: sheet.first.flowKey,
    value: MaatFlowResponseValue.choice(
      specId: choiceSpecId,
      optionId: updatedOption,
    ),
  );
  store.rememberValue(
    flowKey: sheet.first.flowKey,
    value: MaatFlowResponseValue.text(
      specId: textSpecId,
      text: updatedText,
      multiline: true,
    ),
  );

  final promptValues = store.valuesForSpecs(prompt.fields);
  expect(promptValues[choiceSpecId]?.optionIds, <String>[updatedOption]);
  expect(promptValues[textSpecId]?.text, updatedText);
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
