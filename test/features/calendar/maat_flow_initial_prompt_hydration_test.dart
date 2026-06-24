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
import 'package:mobile/features/calendar/the_days_outside_year_flow.dart';
import 'package:mobile/features/calendar/the_decan_watch_flow.dart';
import 'package:mobile/features/calendar/the_djed_flow.dart';
import 'package:mobile/features/calendar/the_kept_word_flow.dart';
import 'package:mobile/features/calendar/the_open_hand_flow.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/the_tending_flow.dart';
import 'package:mobile/features/calendar/the_wag_flow.dart';
import 'package:mobile/features/calendar/the_weighing_flow.dart';

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

  test('Follow the Sky prompt shares sky witness drafts with Day Sheet', () {
    _expectChipTextDraftSharing(
      flowKey: 'track-the-sky',
      chipSpecId: 'follow-sky-shown',
      initialOptions: <String>['horizon', 'change'],
      updatedOptions: <String>['moon', 'planet'],
      textSpecId: 'follow-sky-changed',
      initialText: 'western horizon change',
      updatedText: 'updated sky line',
    );
  });

  test('Weighing prompt shares default-off scale drafts with Day Sheet', () {
    _expectChipTextDraftSharing(
      flowKey: kTheWeighingFlowKey,
      chipSpecId: 'weighing-scale-revealed',
      initialOptions: <String>['record', 'correction'],
      updatedOptions: <String>['truth'],
      textSpecId: 'weighing-record-witnessed',
      initialText: 'private ledger detail',
      updatedText: 'updated correction detail',
      expectedDefaultOff: true,
    );
  });

  test(
    'Days Outside prompt shares threshold receipt drafts with Day Sheet',
    () {
      _expectTextDraftSharing(
        flowKey: kDaysOutsideTheYearFlowKey,
        specId: 'days-outside-receipt',
        initialText: 'I survived the old year with clarity.',
        updatedText: 'I carried one clear receipt across the threshold.',
        eventKey: 'event-1',
      );
    },
  );

  test(
    'Fair Hearing prompt shares default-off measure drafts with Day Sheet',
    () {
      _expectChipTextDraftSharing(
        flowKey: kFairHearingFlowKey,
        chipSpecId: 'fair-hearing-heard-before-deciding',
        initialOptions: <String>['heard_fully', 'same_measure'],
        updatedOptions: <String>['heard_fully', 'same_measure', 'repaired'],
        textSpecId: 'fair-hearing-remembered',
        initialText: 'private decision detail',
        updatedText: 'updated private decision detail',
        expectedDefaultOff: true,
      );
    },
  );

  test(
    'Boundary Stone prompt shares default-off restoration drafts with Day Sheet',
    () {
      _expectChipTextDraftSharing(
        flowKey: kBoundaryStoneFlowKey,
        chipSpecId: 'boundary-stone-marker-restored',
        initialOptions: <String>['labor', 'ownership'],
        updatedOptions: <String>['labor', 'ownership', 'returned'],
        textSpecId: 'boundary-stone-restored',
        initialText: 'private boundary detail',
        updatedText: 'updated boundary detail',
        expectedDefaultOff: true,
      );
    },
  );

  test('Open Mouth prompt shares default-off speech drafts with Day Sheet', () {
    _expectChipTextDraftSharing(
      flowKey: kOpenMouthFlowKey,
      chipSpecId: 'open-mouth-word-disciplined',
      initialOptions: <String>['silence', 'repair'],
      updatedOptions: <String>['silence', 'repair', 'truth'],
      textSpecId: 'open-mouth-governed',
      initialText: 'private speech detail',
      updatedText: 'updated speech detail',
      expectedDefaultOff: true,
    );
  });

  test('Shore prompt shares default-off exchange drafts with Day Sheet', () {
    _expectChipTextDraftSharing(
      flowKey: kTheShoreFlowKey,
      chipSpecId: 'shore-exchange-honest',
      initialOptions: <String>['offer', 'measure'],
      updatedOptions: <String>['offer', 'measure', 'accounted'],
      textSpecId: 'shore-exchange-measured',
      initialText: 'private exchange detail',
      updatedText: 'updated exchange measure',
      expectedDefaultOff: true,
    );
  });

  test('Living Text prompt shares reading drafts with Day Sheet', () {
    _expectChipTextDraftSharing(
      flowKey: kLivingTextFlowKey,
      chipSpecId: 'living-text-added',
      initialOptions: <String>['question', 'application'],
      updatedOptions: <String>['question', 'application'],
      textSpecId: 'living-text-applied',
      initialText: 'copying a line into practice',
      updatedText: 'testing a line in action',
    );
  });

  test('Clearing prompt shares default-off response drafts with Day Sheet', () {
    _expectChipTextDraftSharing(
      flowKey: kClearingFlowKey,
      chipSpecId: 'clearing-cleared',
      initialOptions: <String>['heat', 'pause'],
      updatedOptions: <String>['heat', 'pause', 'breath'],
      textSpecId: 'clearing-waited-response',
      initialText: 'private heated response detail',
      updatedText: 'updated cleared response',
      expectedDefaultOff: true,
    );
  });

  test('Het-Heru prompt shares default-off cooling drafts with Day Sheet', () {
    _expectChipTextDraftSharing(
      flowKey: kHetHeruFlowKey,
      chipSpecId: 'het-heru-force-cooled',
      initialOptions: <String>['music', 'beauty'],
      updatedOptions: <String>['music', 'beauty', 'food'],
      textSpecId: 'het-heru-joy-returned',
      initialText: 'private hot-force detail',
      updatedText: 'updated joy return',
      expectedDefaultOff: true,
    );
  });

  test(
    'Autobiography prompt shares default-off record drafts with Day Sheet',
    () {
      _expectChipTextDraftSharing(
        flowKey: kTheAutobiographyFlowKey,
        chipSpecId: 'autobiography-record-clearer',
        initialOptions: <String>['capacity', 'evidence'],
        updatedOptions: <String>['capacity', 'evidence', 'named'],
        textSpecId: 'autobiography-remembered',
        initialText: 'private identity record detail',
        updatedText: 'updated record evidence',
        expectedDefaultOff: true,
      );
    },
  );

  test('True Name prompt shares strict default-off drafts with Day Sheet', () {
    _expectChipTextDraftSharing(
      flowKey: kTrueNameFlowKey,
      chipSpecId: 'true-name-account-lost-power',
      initialOptions: <String>['false_account', 'accurate_account'],
      updatedOptions: <String>[
        'false_account',
        'accurate_account',
        'true_name',
      ],
      textSpecId: 'true-name-accurate-account',
      initialText: 'private raw identity claim',
      updatedText: 'updated accurate account',
      expectedDefaultOff: true,
    );
  });

  test(
    'Living Record prompt shares default-off record drafts with Day Sheet',
    () {
      _expectChipTextDraftSharing(
        flowKey: kLivingRecordFlowKey,
        chipSpecId: 'living-record-made-living',
        initialOptions: <String>['day_card', 'journal'],
        updatedOptions: <String>['day_card', 'journal', 'closed'],
        textSpecId: 'living-record-carried-forward',
        initialText: 'a line carried into the planner',
        updatedText: 'a closed record carried forward',
        expectedDefaultOff: true,
      );
    },
  );

  test(
    'Oracle prompt shares strict default-off sign drafts with Day Sheet',
    () {
      final store = MaatFlowResponseDraftStore();
      final prompt = _prompt(kOracleFlowKey);
      final sheet = _sheet(kOracleFlowKey);

      expect(
        sheet.every((spec) => spec.offerJournalInclusionDefault == false),
        isTrue,
      );

      store.rememberValue(
        flowKey: prompt.flowKey,
        value: MaatFlowResponseValue.text(
          specId: 'oracle-question-carried',
          text: 'What should stay grounded?',
        ),
      );
      store.rememberValue(
        flowKey: prompt.flowKey,
        value: MaatFlowResponseValue.chips(
          specId: 'oracle-sign-shape',
          optionIds: <String>['dream', 'image'],
        ),
      );
      store.rememberValue(
        flowKey: prompt.flowKey,
        value: MaatFlowResponseValue.text(
          specId: 'oracle-received',
          text: 'private dream detail',
          multiline: true,
        ),
      );

      final sheetValues = store.valuesForSpecs(sheet);
      expect(
        sheetValues['oracle-question-carried']?.text,
        'What should stay grounded?',
      );
      expect(sheetValues['oracle-sign-shape']?.optionIds, <String>[
        'dream',
        'image',
      ]);
      expect(sheetValues['oracle-received']?.text, 'private dream detail');

      store.rememberValue(
        flowKey: sheet.first.flowKey,
        value: MaatFlowResponseValue.chips(
          specId: 'oracle-sign-shape',
          optionIds: <String>['dream', 'action'],
        ),
      );
      store.rememberValue(
        flowKey: sheet.first.flowKey,
        value: MaatFlowResponseValue.text(
          specId: 'oracle-received',
          text: 'updated private sign detail',
          multiline: true,
        ),
      );

      final promptValues = store.valuesForSpecs(prompt.fields);
      expect(promptValues['oracle-sign-shape']?.optionIds, <String>[
        'dream',
        'action',
      ]);
      expect(
        promptValues['oracle-received']?.text,
        'updated private sign detail',
      );
    },
  );

  test(
    'Wandering prompt shares strict default-off grief drafts with Day Sheet',
    () {
      _expectChipTextDraftSharing(
        flowKey: kWanderingFlowKey,
        chipSpecId: 'wandering-remains',
        initialOptions: <String>['loss', 'support'],
        updatedOptions: <String>['absence', 'return'],
        textSpecId: 'wandering-found',
        initialText: 'private grief detail',
        updatedText: 'updated grief detail',
        expectedDefaultOff: true,
      );
    },
  );

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

List<MaatFlowResponseSpec> _sheet(String flowKey, {String? eventKey}) {
  final specs = resolveMaatFlowResponseSpecs(
    flowKey: flowKey,
    surface: MaatFlowResponseSurface.calendarSheet,
    eventKey: eventKey ?? (flowKey == kMoonReturnFlowKey ? 'new' : null),
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

void _expectTextDraftSharing({
  required String flowKey,
  required String specId,
  required String initialText,
  required String updatedText,
  String? eventKey,
}) {
  final store = MaatFlowResponseDraftStore();
  final prompt = _prompt(flowKey);
  final sheet = _sheet(flowKey, eventKey: eventKey);

  store.rememberValue(
    flowKey: prompt.flowKey,
    value: MaatFlowResponseValue.text(
      specId: specId,
      text: initialText,
      multiline: true,
    ),
  );

  expect(store.valuesForSpecs(sheet)[specId]?.text, initialText);

  store.rememberValue(
    flowKey: sheet.first.flowKey,
    value: MaatFlowResponseValue.text(
      specId: specId,
      text: updatedText,
      multiline: true,
    ),
  );

  expect(store.valuesForSpecs(prompt.fields)[specId]?.text, updatedText);
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
