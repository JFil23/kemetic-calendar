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

  test(
    'events 11–30 resolve exact copy by canonical ID independent of position',
    () {
      final reversedCatalog = SkyCatalog(
        schemaVersion: catalog.schemaVersion,
        sourceVersion: catalog.sourceVersion,
        coverageStart: catalog.coverageStart,
        coverageEnd: catalog.coverageEnd,
        events: catalog.events.reversed.toList(growable: false),
      );

      for (final entry in _expectedMeanings11To30.entries.toList().reversed) {
        final event = reversedCatalog.byId(entry.key);
        expect(
          event,
          isNotNull,
          reason: 'missing canonical event ${entry.key}',
        );
        final canonicalEvent = event!;

        _expectMeaning(resolver.forEvent(canonicalEvent), entry.value);
        _expectMeaning(
          resolver.forNight(reversedCatalog.observingNight(canonicalEvent)),
          entry.value,
        );
        _expectMeaning(
          resolver.forCatalogEvent(reversedCatalog, entry.key)!,
          entry.value,
        );
      }
    },
  );

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

    expect(event.function, SkyEventFunction.attend);
    expect(event.function.displayLabel.toUpperCase(), 'ATTEND');
    _expectMeaning(
      resolver.forEvent(event),
      _expectedMeanings11To30[event.id]!,
    );
    expect(resolver.forEvent(event).significanceLabel, 'COMBINE');
  });

  test('Feb eclipse companion aliases to one CORRECT meaning', () {
    final anchor = catalog.byId('full-moon-2027-02-20')!;
    final companion = catalog.byId('lunar-eclipse-2027-02-20')!;
    final nights = catalog.upcomingNights(
      nowUtc: DateTime.utc(2027, 2, 19),
      untilUtc: DateTime.utc(2027, 2, 21),
    ).where((night) => night.anchor.id == anchor.id).toList();
    final expected = _expectedMeanings11To30[anchor.id]!;

    expect(nights, hasLength(1));
    expect(nights.single.anchor.id, anchor.id);
    expect(nights.single.companion?.id, companion.id);
    _expectMeaning(resolver.forNight(nights.single), expected);
    _expectMeaning(resolver.forEvent(anchor), expected);
    _expectMeaning(resolver.forEvent(companion), expected);
    _expectMeaning(resolver.forCatalogEvent(catalog, anchor.id)!, expected);
    _expectMeaning(resolver.forCatalogEvent(catalog, companion.id)!, expected);
  });

  test('repeated kinds retain occurrence-specific meanings', () {
    final mercury2026 = catalog.byId('mercury-elongation-2026-11-20')!;
    final mercury2027 = catalog.byId('mercury-elongation-2027-03-17')!;
    final novemberMoon = catalog.byId('full-moon-2026-11-24')!;
    final decemberMoon = catalog.byId('full-moon-2026-12-24')!;

    expect(mercury2026.kind, mercury2027.kind);
    expect(resolver.forEvent(mercury2026).significanceLabel, 'BEGIN');
    expect(resolver.forEvent(mercury2027).significanceLabel, 'ANTICIPATE');
    expect(
      resolver.forEvent(mercury2026).personalQuestion,
      isNot(resolver.forEvent(mercury2027).personalQuestion),
    );

    expect(novemberMoon.kind, decemberMoon.kind);
    expect(resolver.forEvent(novemberMoon).significanceLabel, 'PREPARE');
    expect(resolver.forEvent(decemberMoon).significanceLabel, 'CONTINUE');
    expect(
      resolver.forEvent(novemberMoon).personalQuestion,
      isNot(resolver.forEvent(decemberMoon).personalQuestion),
    );
  });

  test('events 31+ retain the controlled domain-function fallback', () {
    final event30 = catalog.byId('lyrids-2027')!;
    final laterNights = catalog.upcomingNights(
      nowUtc: event30.primaryInstantUtc.add(const Duration(seconds: 1)),
    );

    expect(laterNights, isNotEmpty);
    expect(laterNights.first.anchor.id, 'eta-aquariids-2027');

    for (final night in laterNights) {
      final event = night.anchor;
      final meaning = resolver.forNight(night);

      expect(
        meaning.observation,
        event.culturalName ?? event.name,
        reason: event.id,
      );
      expect(
        meaning.significanceLabel,
        event.function.displayLabel.toUpperCase(),
        reason: event.id,
      );
      expect(
        meaning.personalQuestion,
        _expectedFallbackQuestion(event.function),
        reason: event.id,
      );
    }
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
      'mars-jupiter-conjunction-2026-11-16': 'attend',
      'mercury-elongation-2026-11-20': 'attend',
      'full-moon-2026-11-24': 'reveal',
      'geminids-2026': 'attend',
      'winter-solstice-2026': 'turn',
      'ursids-2026': 'attend',
      'full-moon-2026-12-24': 'reveal',
      'venus-elongation-2027-01-03': 'attend',
      'quadrantids-2027': 'attend',
      'full-moon-2027-01-22': 'reveal',
      'mercury-elongation-2027-02-03': 'attend',
      'solar-eclipse-2027-02-06': 'reconsider',
      'jupiter-opposition-2027-02-11': 'attend',
      'mars-opposition-2027-02-19': 'attend',
      'full-moon-2027-02-20': 'reveal',
      'lunar-eclipse-2027-02-20': 'reconsider',
      'mercury-elongation-2027-03-17': 'attend',
      'spring-equinox-2027': 'measure',
      'full-moon-2027-03-22': 'reveal',
      'full-moon-2027-04-20': 'reveal',
      'lyrids-2027': 'attend',
    };

    for (final entry in expectedFunctions.entries) {
      expect(catalog.byId(entry.key)?.function.wireName, entry.value);
    }
  });
}

String _expectedFallbackQuestion(SkyEventFunction function) {
  switch (function) {
    case SkyEventFunction.measure:
      return 'What do you want to measure against the sky?';
    case SkyEventFunction.reveal:
      return 'What might this turning reveal that you have not named yet?';
    case SkyEventFunction.reconsider:
      return 'What deserves another look when conditions shift?';
    case SkyEventFunction.turn:
      return 'What turn are you willing to make when the sky changes?';
    case SkyEventFunction.attend:
      return 'What do you want to be present for when it happens?';
  }
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

const _expectedMeanings11To30 = <String, _ExpectedMeaning>{
  'mars-jupiter-conjunction-2026-11-16': _ExpectedMeaning(
    observation:
        'Mars and Jupiter appear close together even as they follow separate paths.',
    purpose: 'COMBINE',
    question:
        'What two things will you bring together to move something forward?',
  ),
  'mercury-elongation-2026-11-20': _ExpectedMeaning(
    observation:
        'Mercury becomes easier to see before sunrise, briefly appearing ahead of the day.',
    purpose: 'BEGIN',
    question:
        'What will you get moving before everything else starts competing for your attention?',
  ),
  'full-moon-2026-11-24': _ExpectedMeaning(
    observation:
        'The Moon reaches fullness as the nights continue growing longer after the equinox.',
    purpose: 'PREPARE',
    question:
        'What can you put in place now that will make the next stretch easier or stronger?',
  ),
  'geminids-2026': _ExpectedMeaning(
    observation:
        'The Geminids build into a dense shower, sending many bright streaks from the same region of sky.',
    purpose: 'MOMENTUM',
    question:
        'What will you push far enough that it becomes easier to keep going?',
  ),
  'winter-solstice-2026': _ExpectedMeaning(
    observation:
        'The Sun reaches its lowest arc and the shortest span of daylight. From here, the light begins to return.',
    purpose: 'REBUILD',
    question: 'What will you begin rebuilding from here?',
  ),
  'ursids-2026': _ExpectedMeaning(
    observation:
        'The Ursids arrive just after the solstice; usually quieter, but still capable of sudden bursts.',
    purpose: 'SUSTAIN',
    question: 'What will you keep advancing even when the results are quiet?',
  ),
  'full-moon-2026-12-24': _ExpectedMeaning(
    observation:
        'The first full Moon after the solstice arrives as daylight has just begun to lengthen again.',
    purpose: 'CONTINUE',
    question: 'What will you keep building as the light begins to return?',
  ),
  'venus-elongation-2027-01-03': _ExpectedMeaning(
    observation:
        'Venus reaches its greatest separation from the Sun and shines prominently before dawn.',
    purpose: 'ORIENT',
    question:
        'What future will you orient your life toward—and what will you change now to move toward it?',
  ),
  'quadrantids-2027': _ExpectedMeaning(
    observation:
        'The Quadrantids flare intensely, but their strongest activity passes quickly.',
    purpose: 'FOCUS',
    question:
        'What will you give a concentrated push to while the moment is right?',
  ),
  'full-moon-2027-01-22': _ExpectedMeaning(
    observation:
        'The Moon reaches fullness again while daylight continues to lengthen after the solstice.',
    purpose: 'STRENGTHEN',
    question: 'What will you make measurably stronger by the next full Moon?',
  ),
  'mercury-elongation-2027-02-03': _ExpectedMeaning(
    observation:
        'Mercury pulls as far from the Sun as its orbit allows in the evening sky, holding briefly in the twilight before turning back.',
    purpose: 'CLAIM',
    question:
        'What opportunity will you claim now, before the opening narrows?',
  ),
  'solar-eclipse-2027-02-06': _ExpectedMeaning(
    observation:
        'The Moon crosses the Sun but cannot cover it completely; a ring of sunlight remains.',
    purpose: 'PRESERVE',
    question:
        'What will you protect now so it can still shape the life you’re building?',
  ),
  'jupiter-opposition-2027-02-11': _ExpectedMeaning(
    observation:
        'Jupiter—the largest planet—rises as the Sun sets and holds the sky through the night near its brightest.',
    purpose: 'EXPAND',
    question: 'What will you feed until it becomes too substantial to ignore?',
  ),
  'mars-opposition-2027-02-19': _ExpectedMeaning(
    observation:
        'Mars rises as the Sun sets and burns red through the night, brighter and closer than at most other times.',
    purpose: 'CONFRONT',
    question:
        'What hard thing will you confront now because becoming equal to it would change you?',
  ),
  'full-moon-2027-02-20': _ExpectedMeaning(
    observation:
        'The full Moon passes through the faint outer edge of Earth’s shadow; the change is real even when it is difficult to see.',
    purpose: 'CORRECT',
    question:
        'What will you correct now before a small drift becomes a larger one?',
  ),
  'mercury-elongation-2027-03-17': _ExpectedMeaning(
    observation:
        'Mercury reaches its widest morning separation from the Sun and appears before dawn, ahead of the day.',
    purpose: 'ANTICIPATE',
    question:
        'What can you prepare now that would make what’s coming easier to step into?',
  ),
  'spring-equinox-2027': _ExpectedMeaning(
    observation:
        'Day and night come nearly even, then the balance begins shifting toward more light.',
    purpose: 'EMERGE',
    question: 'What are you ready to bring into the light and start growing?',
  ),
  'full-moon-2027-03-22': _ExpectedMeaning(
    observation:
        'Two days after the equinox, the Moon reaches fullness while day and night are still near balance.',
    purpose: 'ALIGN',
    question:
        'What is lining up for you right now—and what will you do while the timing is good?',
  ),
  'full-moon-2027-04-20': _ExpectedMeaning(
    observation:
        'One lunar cycle later, the Moon reaches fullness again while the days are still growing longer.',
    purpose: 'ADVANCE',
    question:
        'What will you keep pushing forward while the window is still opening?',
  ),
  'lyrids-2027': _ExpectedMeaning(
    observation:
        'Earth crosses the debris trail of Comet Thatcher; the comet itself takes about four centuries to return.',
    purpose: 'LEGACY',
    question:
        'What will you act on now that could keep creating something long after this moment passes?',
  ),
};
