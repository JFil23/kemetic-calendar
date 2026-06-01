import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/calendar/speech_resolver.dart';

void main() {
  group('SpeechResolver', () {
    test('builds natural spoken cue phrases for decans', () {
      final spoken = SpeechResolver.decan(
        decanId: 1,
        displayName: 'tpy-ꜥ sbꜣw',
        englishCue: 'Foremost of the Stars',
      );

      expect(spoken, 'Tepi-a Sebau, the Foremost of the Stars');
    });

    test('preserves explicit articles in cues', () {
      final spoken = SpeechResolver.decan(
        decanId: 34,
        displayName: 'msḥtjw ḫt',
        englishCue: 'The Crocodiles of the Offering',
      );

      expect(spoken, 'Meshetyu Khet, The Crocodiles of the Offering');
    });

    test('exposes the same prose formatter for generic labels', () {
      final spoken = SpeechResolver.prose(
        base: 'Hree-ib Sebau',
        englishCue: '"Heart of the Stars".',
      );

      expect(spoken, 'Hree-ib Sebau, the Heart of the Stars');
    });

    test('keeps month speech names intact when no cue exists', () {
      final spoken = SpeechResolver.month(month: getMonthById(1));

      expect(spoken, 'Thoth, Jehuty');
    });
  });
}
