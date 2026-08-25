import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';

void main() {
  late SkyCatalog catalog;
  const resolver = TurningMeaningResolver();

  setUpAll(() {
    catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
  });

  test('first ten meanings resolve by canonical identity with exact copy', () {
    for (final entry in _expectedMeanings.entries.toList().reversed) {
      final event = catalog.byId(entry.key);
      expect(event, isNotNull, reason: 'missing canonical event ${entry.key}');
      final canonicalEvent = event!;

      _expectMeaning(resolver.forEvent(canonicalEvent), entry.value);
      _expectMeaning(
        resolver.forNight(catalog.observingNight(canonicalEvent)),
        entry.value,
      );
    }
  });

  test('Aug eclipse companion aliases to one ENDURE meaning', () {
    final anchor = catalog.byId('full-moon-2026-08-28')!;
    final companion = catalog.byId('lunar-eclipse-2026-08-28')!;
    final nights = catalog.upcomingNights(
      nowUtc: DateTime.utc(2026, 8, 27),
      untilUtc: DateTime.utc(2026, 8, 29),
    );

    expect(nights, hasLength(1));
    expect(nights.single.anchor.id, anchor.id);
    expect(nights.single.companion?.id, companion.id);
    _expectMeaning(
      resolver.forNight(nights.single),
      _expectedMeanings[anchor.id]!,
    );
    _expectMeaning(resolver.forEvent(anchor), _expectedMeanings[anchor.id]!);
    _expectMeaning(resolver.forEvent(companion), _expectedMeanings[anchor.id]!);
  });

  test('event 11 retains the controlled domain-function fallback', () {
    final event = catalog.byId('mars-jupiter-conjunction-2026-11-16')!;
    final meaning = resolver.forEvent(event);

    expect(meaning.observation, 'Mars/Jupiter Conjunction');
    expect(meaning.significanceLabel, 'ATTEND');
    expect(
      meaning.personalQuestion,
      'What do you want to be present for when it happens?',
    );
  });

  test('catalog function metadata remains unchanged', () {
    const expectedFunctions = <String, String>{
      'full-moon-2026-08-28': 'reveal',
      'lunar-eclipse-2026-08-28': 'reconsider',
      'autumn-equinox-2026': 'measure',
      'full-moon-2026-09-26': 'reveal',
      'saturn-opposition-2026-10-04': 'attend',
      'mercury-elongation-2026-10-12': 'attend',
      'orionids-2026': 'attend',
      'full-moon-2026-10-26': 'reveal',
      'southern-taurids-2026': 'attend',
      'northern-taurids-2026': 'attend',
      'leonids-2026': 'attend',
    };

    for (final entry in expectedFunctions.entries) {
      expect(catalog.byId(entry.key)?.function.wireName, entry.value);
    }
  });
}

void _expectMeaning(TurningMeaning actual, _ExpectedMeaning expected) {
  expect(actual.observation, expected.observation);
  expect(actual.significanceLabel, expected.purpose);
  expect(actual.personalQuestion, expected.question);
}

class _ExpectedMeaning {
  const _ExpectedMeaning({
    required this.observation,
    required this.purpose,
    required this.question,
  });

  final String observation;
  final String purpose;
  final String question;
}

const _expectedMeanings = <String, _ExpectedMeaning>{
  'full-moon-2026-08-28': _ExpectedMeaning(
    observation:
        'The Moon passes through Earth’s shadow without leaving its course.',
    purpose: 'ENDURE',
    question: 'What do you want to stay true to when conditions change?',
  ),
  'autumn-equinox-2026': _ExpectedMeaning(
    observation:
        'Day and night come nearly even. Then the balance begins to turn.',
    purpose: 'BALANCE',
    question: 'What do you want to make more room for so it can grow?',
  ),
  'full-moon-2026-09-26': _ExpectedMeaning(
    observation:
        'For several nights, the Moon rises soon after sunset, extending the evening light.',
    purpose: 'GATHER',
    question:
        'What can you finish now so your work becomes something you can actually use or enjoy?',
  ),
  'saturn-opposition-2026-10-04': _ExpectedMeaning(
    observation:
        'Saturn rises at sunset and remains visible through the night.',
    purpose: 'PRACTICE',
    question: 'What will you practice until it becomes part of who you are?',
  ),
  'mercury-elongation-2026-10-12': _ExpectedMeaning(
    observation:
        'Mercury briefly becomes visible after sunset before slipping back into the Sun’s glare.',
    purpose: 'ACT',
    question: 'What needs doing while the window is open?',
  ),
  'orionids-2026': _ExpectedMeaning(
    observation:
        'Earth crosses debris left behind by Halley’s Comet; an old passage becomes visible again in the present.',
    purpose: 'RENEW',
    question:
        'What unfinished thing from your past will you pick back up and move forward?',
  ),
  'full-moon-2026-10-26': _ExpectedMeaning(
    observation:
        'The Moon reaches full illumination again and carries bright light through the night.',
    purpose: 'CELEBRATE',
    question:
        'What are you doing right now that deserves a milestone—and how will you mark it?',
  ),
  'southern-taurids-2026': _ExpectedMeaning(
    observation:
        'The Southern Taurids bring fewer meteors, but some burn exceptionally bright.',
    purpose: 'POSSIBILITY',
    question: 'What small possibility are you ready to give a real chance?',
  ),
  'northern-taurids-2026': _ExpectedMeaning(
    observation:
        'The Northern and Southern Taurids appear separately, but belong to the same larger family.',
    purpose: 'CONNECT',
    question:
        'What could become possible if two parts of your life worked together?',
  ),
  'leonids-2026': _ExpectedMeaning(
    observation:
        'Leonids flash across the sky at exceptional speed; the brightest can leave glowing trails behind.',
    purpose: 'IMPACT',
    question:
        'What do you want to set in motion that could outlast this moment?',
  ),
};
