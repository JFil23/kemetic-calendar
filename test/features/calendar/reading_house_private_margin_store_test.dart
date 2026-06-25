import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/maat_flow_response_models.dart';
import 'package:mobile/features/calendar/reading_house_private_margin_store.dart';
import 'package:mobile/features/calendar/the_reading_house_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('private margin values round-trip in SharedPreferences only', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final store = ReadingHousePrivateMarginStore(prefs: prefs);

    await store.saveValues(
      flowId: 42,
      eventNumber: 2,
      values: <String, MaatFlowResponseValue>{
        kReadingHousePrivateReflectionSpecId: MaatFlowResponseValue.text(
          specId: kReadingHousePrivateReflectionSpecId,
          text: 'private paragraph',
          multiline: true,
        ),
        kReadingHouseShortNoteSpecId: MaatFlowResponseValue.text(
          specId: kReadingHouseShortNoteSpecId,
          text: 'p. 17',
        ),
        kReadingHouseSitWithoutWritingSpecId: MaatFlowResponseValue.checkbox(
          specId: kReadingHouseSitWithoutWritingSpecId,
          checked: true,
        ),
        kReadingHousePositionSpecId: MaatFlowResponseValue.choice(
          specId: kReadingHousePositionSpecId,
          optionId: kReadingHousePositionCarrying,
        ),
      },
    );

    final values = await store.loadValues(flowId: 42, eventNumber: 2);
    expect(
      values[kReadingHousePrivateReflectionSpecId]?.text,
      'private paragraph',
    );
    expect(values[kReadingHouseShortNoteSpecId]?.text, 'p. 17');
    expect(values[kReadingHouseSitWithoutWritingSpecId]?.checked, isTrue);
    expect(values[kReadingHousePositionSpecId]?.optionIds, <String>[
      kReadingHousePositionCarrying,
    ]);
    expect(
      prefs.getKeys(),
      contains('reading_house_42_private_margin_event_2'),
    );
  });

  test('completion metadata carries flags but not private text', () {
    final metadata = readingHousePrivateMarginCompletionMetadata(
      <String, MaatFlowResponseValue>{
        kReadingHousePrivateReflectionSpecId: MaatFlowResponseValue.text(
          specId: kReadingHousePrivateReflectionSpecId,
          text: 'do not send this',
          multiline: true,
        ),
        kReadingHouseShortNoteSpecId: MaatFlowResponseValue.text(
          specId: kReadingHouseShortNoteSpecId,
          text: 'also private',
        ),
        kReadingHousePositionSpecId: MaatFlowResponseValue.choice(
          specId: kReadingHousePositionSpecId,
          optionId: kReadingHousePositionNotYet,
        ),
      },
    );

    expect(metadata['reader_sitting_phase'], 'enabled');
    expect(metadata['reading_position'], kReadingHousePositionNotYet);
    expect(metadata['writing_required'], isFalse);
    expect(metadata['shared_fragments_phase'], 'future');
    expect(metadata.toString(), isNot(contains('do not send this')));
    expect(metadata.toString(), isNot(contains('also private')));
    final margin = metadata['private_margin'] as Map<String, dynamic>;
    expect(margin['private_reflection_recorded'], isTrue);
    expect(margin['short_note_recorded'], isTrue);
    expect(margin['storage'], 'local_only');
  });

  test('empty values clear the stored private margin', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'reading_house_7_private_margin_event_1': '{"stale":"value"}',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = ReadingHousePrivateMarginStore(prefs: prefs);

    await store.saveValues(
      flowId: 7,
      eventNumber: 1,
      values: const <String, MaatFlowResponseValue>{},
    );

    expect(prefs.getString('reading_house_7_private_margin_event_1'), isNull);
  });
}
