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

  test(
    'events 31–60 resolve exact copy by canonical ID independent of position',
    () {
      final reversedCatalog = SkyCatalog(
        schemaVersion: catalog.schemaVersion,
        sourceVersion: catalog.sourceVersion,
        coverageStart: catalog.coverageStart,
        coverageEnd: catalog.coverageEnd,
        events: catalog.events.reversed.toList(growable: false),
      );

      for (final entry in _expectedMeanings31To60.entries.toList().reversed) {
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

  test('July eclipse companion aliases to one ATTUNE meaning', () {
    final anchor = catalog.byId('full-moon-2027-07-18')!;
    final companion = catalog.byId('lunar-eclipse-2027-07-18')!;
    final nights = catalog
        .upcomingNights(
          nowUtc: DateTime.utc(2027, 7, 17),
          untilUtc: DateTime.utc(2027, 7, 19),
        )
        .where((night) => night.anchor.id == anchor.id)
        .toList();
    final expected = _expectedMeanings31To60[anchor.id]!;

    expect(nights, hasLength(1));
    expect(nights.single.anchor.id, anchor.id);
    expect(nights.single.companion?.id, companion.id);
    expect(companion.mergedIntoId, anchor.id);
    expect(companion.specialNotification, isFalse);
    _expectMeaning(resolver.forNight(nights.single), expected);
    _expectMeaning(resolver.forEvent(anchor), expected);
    _expectMeaning(resolver.forEvent(companion), expected);
    _expectMeaning(resolver.forCatalogEvent(catalog, anchor.id)!, expected);
    _expectMeaning(resolver.forCatalogEvent(catalog, companion.id)!, expected);
  });

  test('August eclipse companion aliases to one INTEGRATE meaning', () {
    final anchor = catalog.byId('full-moon-2027-08-17')!;
    final companion = catalog.byId('lunar-eclipse-2027-08-17')!;
    final nights = catalog
        .upcomingNights(
          nowUtc: DateTime.utc(2027, 8, 16),
          untilUtc: DateTime.utc(2027, 8, 18),
        )
        .where((night) => night.anchor.id == anchor.id)
        .toList();
    final expected = _expectedMeanings31To60[anchor.id]!;

    expect(nights, hasLength(1));
    expect(nights.single.anchor.id, anchor.id);
    expect(nights.single.companion?.id, companion.id);
    expect(companion.mergedIntoId, anchor.id);
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

  test('events 31–60 repeated kinds retain occurrence-specific meanings', () {
    const fullMoonIds = <String>[
      'full-moon-2027-05-20',
      'full-moon-2027-06-19',
      'full-moon-2027-07-18',
      'full-moon-2027-08-17',
      'full-moon-2027-09-15',
      'full-moon-2027-10-15',
      'full-moon-2027-11-14',
      'full-moon-2027-12-13',
    ];
    const mercuryIds = <String>[
      'mercury-elongation-2027-05-28',
      'mercury-elongation-2027-07-15',
      'mercury-elongation-2027-09-24',
      'mercury-elongation-2027-11-04',
    ];

    final fullMoonMeanings = fullMoonIds
        .map((id) => resolver.forEvent(catalog.byId(id)!))
        .toList();
    final mercuryMeanings = mercuryIds
        .map((id) => resolver.forEvent(catalog.byId(id)!))
        .toList();

    expect(
      fullMoonMeanings.map((meaning) => meaning.significanceLabel).toSet(),
      hasLength(fullMoonIds.length),
    );
    expect(
      fullMoonMeanings.map((meaning) => meaning.personalQuestion).toSet(),
      hasLength(fullMoonIds.length),
    );
    expect(
      mercuryMeanings.map((meaning) => meaning.significanceLabel).toSet(),
      hasLength(mercuryIds.length),
    );
    expect(
      mercuryMeanings.map((meaning) => meaning.personalQuestion).toSet(),
      hasLength(mercuryIds.length),
    );
  });

  test('events 31+ retain the controlled domain-function fallback', () {
    // This test name is release-authority locked. The fallback boundary moves
    // forward as approved occurrence-specific meanings are added.
    final event60 = catalog.byId('quadrantids-2028')!;
    final laterNights = catalog.upcomingNights(
      nowUtc: event60.primaryInstantUtc.add(const Duration(seconds: 1)),
    );

    expect(laterNights, isNotEmpty);
    expect(laterNights.first.anchor.id, 'mercury-mars-conjunction-2028-01-09');

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
      'eta-aquariids-2027': 'attend',
      'venus-saturn-conjunction-2027-05-07': 'attend',
      'full-moon-2027-05-20': 'reveal',
      'mercury-elongation-2027-05-28': 'attend',
      'full-moon-2027-06-19': 'reveal',
      'summer-solstice-2027': 'turn',
      'mercury-elongation-2027-07-15': 'attend',
      'full-moon-2027-07-18': 'reveal',
      'lunar-eclipse-2027-07-18': 'reconsider',
      'southern-delta-aquariids-2027': 'attend',
      'alpha-capricornids-2027': 'attend',
      'solar-eclipse-2027-08-02': 'reconsider',
      'perseids-2027': 'attend',
      'full-moon-2027-08-17': 'reveal',
      'lunar-eclipse-2027-08-17': 'reconsider',
      'full-moon-2027-09-15': 'reveal',
      'autumn-equinox-2027': 'measure',
      'mercury-elongation-2027-09-24': 'attend',
      'full-moon-2027-10-15': 'reveal',
      'saturn-opposition-2027-10-18': 'attend',
      'orionids-2027': 'attend',
      'mercury-elongation-2027-11-04': 'attend',
      'southern-taurids-2027': 'attend',
      'northern-taurids-2027': 'attend',
      'full-moon-2027-11-14': 'reveal',
      'leonids-2027': 'attend',
      'venus-mars-conjunction-2027-11-25': 'attend',
      'full-moon-2027-12-13': 'reveal',
      'geminids-2027': 'attend',
      'winter-solstice-2027': 'turn',
      'ursids-2027': 'attend',
      'quadrantids-2028': 'attend',
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

const _expectedMeanings31To60 = <String, _ExpectedMeaning>{
  'eta-aquariids-2027': _ExpectedMeaning(
    observation:
        'The η-Aquariids are fragments shed by Halley’s Comet—a visitor humans have recorded for more than 2,000 years.',
    purpose: 'INHERIT',
    question: 'What have you inherited that you want to carry further?',
  ),
  'venus-saturn-conjunction-2027-05-07': _ExpectedMeaning(
    observation:
        'Bright Venus and ringed Saturn appear within about half a degree of each other in the sky.',
    purpose: 'COMMIT',
    question:
        'What deserves a place in your life that you refuse to leave to chance?',
  ),
  'full-moon-2027-05-20': _ExpectedMeaning(
    observation:
        'The Moon reaches fullness as the Sun continues climbing toward its highest arc.',
    purpose: 'CULTIVATE',
    question:
        'What is gaining strength in your life that deserves more of your care?',
  ),
  'mercury-elongation-2027-05-28': _ExpectedMeaning(
    observation:
        'The solar system’s fastest planet pulls far enough from the Sun to hold briefly in the evening twilight.',
    purpose: 'DECIDE',
    question:
        'What decision would give everything that follows a clearer direction?',
  ),
  'full-moon-2027-06-19': _ExpectedMeaning(
    observation:
        'The Moon reaches fullness just two days before the Sun reaches the crest of its yearly climb.',
    purpose: 'READY',
    question:
        'What are you willing to climb toward because reaching it would change your life?',
  ),
  'summer-solstice-2027': _ExpectedMeaning(
    observation:
        'The Sun reaches its highest arc and longest span of daylight—the crest before the light begins to turn.',
    purpose: 'ASCEND',
    question:
        'What will you attempt now that deserves the strongest version of you?',
  ),
  'mercury-elongation-2027-07-15': _ExpectedMeaning(
    observation:
        'Mercury reaches its widest morning separation from the Sun, appearing before dawn after the solar cycle has begun to turn.',
    purpose: 'PIVOT',
    question:
        'What will you adjust now to make the next phase work in your favor?',
  ),
  'full-moon-2027-07-18': _ExpectedMeaning(
    observation:
        'The full Moon brushes Earth’s faint outer shadow; the eclipse is so slight it may be almost impossible to see.',
    purpose: 'ATTUNE',
    question:
        'What subtle change in yourself are you ready to trust enough to act on?',
  ),
  'southern-delta-aquariids-2027': _ExpectedMeaning(
    observation:
        'A long stream of mostly faint meteors builds toward its peak, with much of its activity easier to detect than to see.',
    purpose: 'ACCUMULATE',
    question:
        'What will you build through small, repeated effort while the conditions are in your favor?',
  ),
  'alpha-capricornids-2027': _ExpectedMeaning(
    observation:
        'On the same night, the Alpha Capricornids produce far fewer meteors—but are unusually capable of brilliant fireballs.',
    purpose: 'BREAKTHROUGH',
    question:
        'What one bold move will you make that could change what becomes possible next?',
  ),
  'solar-eclipse-2027-08-02': _ExpectedMeaning(
    observation:
        'At its deepest point, the Moon completely covers the Sun for more than six minutes—an exceptionally long total eclipse.',
    purpose: 'TRANSFORM',
    question:
        'What are you ready to change so completely that your life has a before and after?',
  ),
  'perseids-2027': _ExpectedMeaning(
    observation:
        'The Perseids come from Swift-Tuttle, a 26-kilometer-wide comet that takes about 133 years to circle the Sun.',
    purpose: 'PURSUE',
    question:
        'What promising thing are you ready to take seriously and see how far it can go?',
  ),
  'full-moon-2027-08-17': _ExpectedMeaning(
    observation:
        'Fifteen days after the total solar eclipse, the full Moon passes through Earth’s outer shadow—the second eclipse of the same eclipse season.',
    purpose: 'INTEGRATE',
    question:
        'What change are you ready to make part of how you actually live?',
  ),
  'full-moon-2027-09-15': _ExpectedMeaning(
    observation:
        'The Moon reaches fullness as the Sun approaches the same equinox threshold it crossed one solar cycle ago.',
    purpose: 'AFFIRM',
    question:
        'What became more important to you over this solar cycle—and what will you do with that knowledge?',
  ),
  'autumn-equinox-2027': _ExpectedMeaning(
    observation:
        'Day and night come nearly even. Then the balance begins shifting toward longer nights.',
    purpose: 'REBALANCE',
    question: 'What part of your life deserves a fairer share of your time?',
  ),
  'mercury-elongation-2027-09-24': _ExpectedMeaning(
    observation:
        'One day after the equinox, Mercury reaches its widest evening separation from the Sun and stands briefly clear in the twilight.',
    purpose: 'DECLARE',
    question:
        'What direction are you ready to name clearly enough that your choices can start following it?',
  ),
  'full-moon-2027-10-15': _ExpectedMeaning(
    observation:
        'The Moon reaches full illumination while the nights continue growing longer.',
    purpose: 'CLARIFY',
    question:
        'What desire is becoming clear enough that you’re ready to act on it?',
  ),
  'saturn-opposition-2027-10-18': _ExpectedMeaning(
    observation:
        'Earth passes between the Sun and Saturn, bringing the ringed planet into one of its brightest and most commanding appearances.',
    purpose: 'MASTER',
    question: 'What would you love to become undeniably good at?',
  ),
  'orionids-2027': _ExpectedMeaning(
    observation:
        'Fragments of Halley’s Comet strike Earth’s atmosphere at about 66 kilometers per second—among the fastest meteors we regularly see—and can leave glowing trains behind them.',
    purpose: 'ACCELERATE',
    question:
        'What are you ready to accelerate because the direction already feels right?',
  ),
  'mercury-elongation-2027-11-04': _ExpectedMeaning(
    observation:
        'Mercury reaches its greatest separation west of the Sun, becoming visible in the morning sky before sunrise.',
    purpose: 'FORESIGHT',
    question:
        'What will you do with something you can see coming before it becomes obvious?',
  ),
  'southern-taurids-2027': _ExpectedMeaning(
    observation:
        'Comet Encke, the source of the Southern Taurids, circles the Sun every 3.3 years—the shortest orbit of any known comet.',
    purpose: 'ITERATE',
    question:
        'What could become noticeably better if you gave it one more good pass?',
  ),
  'northern-taurids-2027': _ExpectedMeaning(
    observation:
        'The Northern Taurids belong to the sprawling Taurid complex, where one broad stream of debris has separated into distinct branches.',
    purpose: 'DEFINE',
    question: 'What are you ready to make distinctly your own?',
  ),
  'full-moon-2027-11-14': _ExpectedMeaning(
    observation:
        'At fullness, the Moon’s Earth-facing side is completely illuminated, leaving none of its visible face in shadow.',
    purpose: 'REVEAL',
    question: 'What are you ready to let people see more of?',
  ),
  'leonids-2027': _ExpectedMeaning(
    observation:
        'The 2027 Leonids may run stronger than usual, with enhanced intervals modeled around 40–50 meteors an hour. The shower has produced extraordinary meteor storms in the past.',
    purpose: 'SURGE',
    question:
        'Where could one serious burst of effort change the pace of things?',
  ),
  'venus-mars-conjunction-2027-11-25': _ExpectedMeaning(
    observation:
        'Brilliant Venus and red Mars appear only about 0.3° apart—closer together than the width of a full Moon.',
    purpose: 'DESIRE',
    question:
        'What do you want badly enough to bring closer to your real life?',
  ),
  'full-moon-2027-12-13': _ExpectedMeaning(
    observation:
        'The Moon reaches fullness as the Geminids reach their peak, flooding the same sky the meteors are crossing.',
    purpose: 'PRIORITIZE',
    question: 'What deserves your fullest attention right now?',
  ),
  'geminids-2027': _ExpectedMeaning(
    observation:
        'First noticed in the mid-1800s as a modest shower, the Geminids have grown into one of the sky’s most reliable annual displays.',
    purpose: 'BECOME',
    question:
        'What will you keep developing because it is becoming more than you first imagined?',
  ),
  'winter-solstice-2027': _ExpectedMeaning(
    observation:
        'The Sun reaches its lowest arc and shortest span of daylight. From here, the light begins returning.',
    purpose: 'RETURN',
    question:
        'What part of yourself are you ready to bring back into your life?',
  ),
  'ursids-2027': _ExpectedMeaning(
    observation:
        'The Ursids come from Comet 8P/Tuttle, whose long orbit carries it beyond Saturn before it travels back toward the Sun.',
    purpose: 'VENTURE',
    question:
        'What are you curious enough to follow farther than you have before?',
  ),
  'quadrantids-2028': _ExpectedMeaning(
    observation:
        'The Quadrantids are named for Quadrans Muralis—a constellation removed from modern star maps, even though its name still survives in the shower.',
    purpose: 'OUTLAST',
    question:
        'What are you creating that should survive even if its original form changes?',
  ),
};
