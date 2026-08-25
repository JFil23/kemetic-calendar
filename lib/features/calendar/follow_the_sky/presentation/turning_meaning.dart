import '../domain/sky_catalog.dart';
import '../domain/sky_event.dart';
import '../domain/sky_event_function.dart';
import '../domain/sky_observing_night.dart';

/// Human-facing turning copy for Follow Sky detail presentation.
class TurningMeaning {
  const TurningMeaning({
    required this.observation,
    required this.significanceLabel,
    required this.personalQuestion,
  });

  final String observation;
  final String significanceLabel;
  final String personalQuestion;

  String get titledSignificanceLabel {
    final lower = significanceLabel.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }

  String get detailText =>
      '$observation\n$significanceLabel\n$personalQuestion';
}

/// Maps canonical sky events into presentation copy without touching domain enums.
class TurningMeaningResolver {
  const TurningMeaningResolver();

  static const TurningMeaning approvedLunarEclipse = TurningMeaning(
    observation:
        'The Moon passes through Earth’s shadow without leaving its course.',
    significanceLabel: 'ENDURE',
    personalQuestion:
        'What do you want to stay true to when conditions change?',
  );

  static const Map<String, String> _canonicalEventIdAliases = {
    'lunar-eclipse-2026-08-28': 'full-moon-2026-08-28',
    'lunar-eclipse-2027-02-20': 'full-moon-2027-02-20',
    'lunar-eclipse-2027-07-18': 'full-moon-2027-07-18',
    'lunar-eclipse-2027-08-17': 'full-moon-2027-08-17',
  };

  static const Map<String, TurningMeaning> _meaningsByCanonicalEventId = {
    'full-moon-2026-08-28': approvedLunarEclipse,
    'autumn-equinox-2026': TurningMeaning(
      observation:
          'Day and night come nearly even. Then the balance begins to turn.',
      significanceLabel: 'BALANCE',
      personalQuestion:
          'What do you want to make more room for so it can grow?',
    ),
    'full-moon-2026-09-26': TurningMeaning(
      observation:
          'For several nights, the Moon rises soon after sunset, extending the evening light.',
      significanceLabel: 'GATHER',
      personalQuestion:
          'What can you finish now so your work becomes something you can actually use or enjoy?',
    ),
    'saturn-opposition-2026-10-04': TurningMeaning(
      observation:
          'Saturn rises at sunset and remains visible through the night.',
      significanceLabel: 'PRACTICE',
      personalQuestion:
          'What will you practice until it becomes part of who you are?',
    ),
    'mercury-elongation-2026-10-12': TurningMeaning(
      observation:
          'Mercury briefly becomes visible after sunset before slipping back into the Sun’s glare.',
      significanceLabel: 'ACT',
      personalQuestion: 'What needs doing while the window is open?',
    ),
    'orionids-2026': TurningMeaning(
      observation:
          'Earth crosses debris left behind by Halley’s Comet; an old passage becomes visible again in the present.',
      significanceLabel: 'RENEW',
      personalQuestion:
          'What unfinished thing from your past will you pick back up and move forward?',
    ),
    'full-moon-2026-10-26': TurningMeaning(
      observation:
          'The Moon reaches full illumination again and carries bright light through the night.',
      significanceLabel: 'CELEBRATE',
      personalQuestion:
          'What are you doing right now that deserves a milestone—and how will you mark it?',
    ),
    'southern-taurids-2026': TurningMeaning(
      observation:
          'The Southern Taurids bring fewer meteors, but some burn exceptionally bright.',
      significanceLabel: 'POSSIBILITY',
      personalQuestion:
          'What small possibility are you ready to give a real chance?',
    ),
    'northern-taurids-2026': TurningMeaning(
      observation:
          'The Northern and Southern Taurids appear separately, but belong to the same larger family.',
      significanceLabel: 'CONNECT',
      personalQuestion:
          'What could become possible if two parts of your life worked together?',
    ),
    'leonids-2026': TurningMeaning(
      observation:
          'Leonids flash across the sky at exceptional speed; the brightest can leave glowing trails behind.',
      significanceLabel: 'IMPACT',
      personalQuestion:
          'What do you want to set in motion that could outlast this moment?',
    ),
    'mars-jupiter-conjunction-2026-11-16': TurningMeaning(
      observation:
          'Mars and Jupiter appear close together even as they follow separate paths.',
      significanceLabel: 'COMBINE',
      personalQuestion:
          'What two things will you bring together to move something forward?',
    ),
    'mercury-elongation-2026-11-20': TurningMeaning(
      observation:
          'Mercury becomes easier to see before sunrise, briefly appearing ahead of the day.',
      significanceLabel: 'BEGIN',
      personalQuestion:
          'What will you get moving before everything else starts competing for your attention?',
    ),
    'full-moon-2026-11-24': TurningMeaning(
      observation:
          'The Moon reaches fullness as the nights continue growing longer after the equinox.',
      significanceLabel: 'PREPARE',
      personalQuestion:
          'What can you put in place now that will make the next stretch easier or stronger?',
    ),
    'geminids-2026': TurningMeaning(
      observation:
          'The Geminids build into a dense shower, sending many bright streaks from the same region of sky.',
      significanceLabel: 'MOMENTUM',
      personalQuestion:
          'What will you push far enough that it becomes easier to keep going?',
    ),
    'winter-solstice-2026': TurningMeaning(
      observation:
          'The Sun reaches its lowest arc and the shortest span of daylight. From here, the light begins to return.',
      significanceLabel: 'REBUILD',
      personalQuestion: 'What will you begin rebuilding from here?',
    ),
    'ursids-2026': TurningMeaning(
      observation:
          'The Ursids arrive just after the solstice; usually quieter, but still capable of sudden bursts.',
      significanceLabel: 'SUSTAIN',
      personalQuestion:
          'What will you keep advancing even when the results are quiet?',
    ),
    'full-moon-2026-12-24': TurningMeaning(
      observation:
          'The first full Moon after the solstice arrives as daylight has just begun to lengthen again.',
      significanceLabel: 'CONTINUE',
      personalQuestion:
          'What will you keep building as the light begins to return?',
    ),
    'venus-elongation-2027-01-03': TurningMeaning(
      observation:
          'Venus reaches its greatest separation from the Sun and shines prominently before dawn.',
      significanceLabel: 'ORIENT',
      personalQuestion:
          'What future will you orient your life toward—and what will you change now to move toward it?',
    ),
    'quadrantids-2027': TurningMeaning(
      observation:
          'The Quadrantids flare intensely, but their strongest activity passes quickly.',
      significanceLabel: 'FOCUS',
      personalQuestion:
          'What will you give a concentrated push to while the moment is right?',
    ),
    'full-moon-2027-01-22': TurningMeaning(
      observation:
          'The Moon reaches fullness again while daylight continues to lengthen after the solstice.',
      significanceLabel: 'STRENGTHEN',
      personalQuestion:
          'What will you make measurably stronger by the next full Moon?',
    ),
    'mercury-elongation-2027-02-03': TurningMeaning(
      observation:
          'Mercury pulls as far from the Sun as its orbit allows in the evening sky, holding briefly in the twilight before turning back.',
      significanceLabel: 'CLAIM',
      personalQuestion:
          'What opportunity will you claim now, before the opening narrows?',
    ),
    'solar-eclipse-2027-02-06': TurningMeaning(
      observation:
          'The Moon crosses the Sun but cannot cover it completely; a ring of sunlight remains.',
      significanceLabel: 'PRESERVE',
      personalQuestion:
          'What will you protect now so it can still shape the life you’re building?',
    ),
    'jupiter-opposition-2027-02-11': TurningMeaning(
      observation:
          'Jupiter—the largest planet—rises as the Sun sets and holds the sky through the night near its brightest.',
      significanceLabel: 'EXPAND',
      personalQuestion:
          'What will you feed until it becomes too substantial to ignore?',
    ),
    'mars-opposition-2027-02-19': TurningMeaning(
      observation:
          'Mars rises as the Sun sets and burns red through the night, brighter and closer than at most other times.',
      significanceLabel: 'CONFRONT',
      personalQuestion:
          'What hard thing will you confront now because becoming equal to it would change you?',
    ),
    'full-moon-2027-02-20': TurningMeaning(
      observation:
          'The full Moon passes through the faint outer edge of Earth’s shadow; the change is real even when it is difficult to see.',
      significanceLabel: 'CORRECT',
      personalQuestion:
          'What will you correct now before a small drift becomes a larger one?',
    ),
    'mercury-elongation-2027-03-17': TurningMeaning(
      observation:
          'Mercury reaches its widest morning separation from the Sun and appears before dawn, ahead of the day.',
      significanceLabel: 'ANTICIPATE',
      personalQuestion:
          'What can you prepare now that would make what’s coming easier to step into?',
    ),
    'spring-equinox-2027': TurningMeaning(
      observation:
          'Day and night come nearly even, then the balance begins shifting toward more light.',
      significanceLabel: 'EMERGE',
      personalQuestion:
          'What are you ready to bring into the light and start growing?',
    ),
    'full-moon-2027-03-22': TurningMeaning(
      observation:
          'Two days after the equinox, the Moon reaches fullness while day and night are still near balance.',
      significanceLabel: 'ALIGN',
      personalQuestion:
          'What is lining up for you right now—and what will you do while the timing is good?',
    ),
    'full-moon-2027-04-20': TurningMeaning(
      observation:
          'One lunar cycle later, the Moon reaches fullness again while the days are still growing longer.',
      significanceLabel: 'ADVANCE',
      personalQuestion:
          'What will you keep pushing forward while the window is still opening?',
    ),
    'lyrids-2027': TurningMeaning(
      observation:
          'Earth crosses the debris trail of Comet Thatcher; the comet itself takes about four centuries to return.',
      significanceLabel: 'LEGACY',
      personalQuestion:
          'What will you act on now that could keep creating something long after this moment passes?',
    ),
    'eta-aquariids-2027': TurningMeaning(
      observation:
          'The η-Aquariids are fragments shed by Halley’s Comet—a visitor humans have recorded for more than 2,000 years.',
      significanceLabel: 'INHERIT',
      personalQuestion:
          'What have you inherited that you want to carry further?',
    ),
    'venus-saturn-conjunction-2027-05-07': TurningMeaning(
      observation:
          'Bright Venus and ringed Saturn appear within about half a degree of each other in the sky.',
      significanceLabel: 'COMMIT',
      personalQuestion:
          'What deserves a place in your life that you refuse to leave to chance?',
    ),
    'full-moon-2027-05-20': TurningMeaning(
      observation:
          'The Moon reaches fullness as the Sun continues climbing toward its highest arc.',
      significanceLabel: 'CULTIVATE',
      personalQuestion:
          'What is gaining strength in your life that deserves more of your care?',
    ),
    'mercury-elongation-2027-05-28': TurningMeaning(
      observation:
          'The solar system’s fastest planet pulls far enough from the Sun to hold briefly in the evening twilight.',
      significanceLabel: 'DECIDE',
      personalQuestion:
          'What decision would give everything that follows a clearer direction?',
    ),
    'full-moon-2027-06-19': TurningMeaning(
      observation:
          'The Moon reaches fullness just two days before the Sun reaches the crest of its yearly climb.',
      significanceLabel: 'READY',
      personalQuestion:
          'What are you willing to climb toward because reaching it would change your life?',
    ),
    'summer-solstice-2027': TurningMeaning(
      observation:
          'The Sun reaches its highest arc and longest span of daylight—the crest before the light begins to turn.',
      significanceLabel: 'ASCEND',
      personalQuestion:
          'What will you attempt now that deserves the strongest version of you?',
    ),
    'mercury-elongation-2027-07-15': TurningMeaning(
      observation:
          'Mercury reaches its widest morning separation from the Sun, appearing before dawn after the solar cycle has begun to turn.',
      significanceLabel: 'PIVOT',
      personalQuestion:
          'What will you adjust now to make the next phase work in your favor?',
    ),
    'full-moon-2027-07-18': TurningMeaning(
      observation:
          'The full Moon brushes Earth’s faint outer shadow; the eclipse is so slight it may be almost impossible to see.',
      significanceLabel: 'ATTUNE',
      personalQuestion:
          'What subtle change in yourself are you ready to trust enough to act on?',
    ),
    'southern-delta-aquariids-2027': TurningMeaning(
      observation:
          'A long stream of mostly faint meteors builds toward its peak, with much of its activity easier to detect than to see.',
      significanceLabel: 'ACCUMULATE',
      personalQuestion:
          'What will you build through small, repeated effort while the conditions are in your favor?',
    ),
    'alpha-capricornids-2027': TurningMeaning(
      observation:
          'On the same night, the Alpha Capricornids produce far fewer meteors—but are unusually capable of brilliant fireballs.',
      significanceLabel: 'BREAKTHROUGH',
      personalQuestion:
          'What one bold move will you make that could change what becomes possible next?',
    ),
    'solar-eclipse-2027-08-02': TurningMeaning(
      observation:
          'At its deepest point, the Moon completely covers the Sun for more than six minutes—an exceptionally long total eclipse.',
      significanceLabel: 'TRANSFORM',
      personalQuestion:
          'What are you ready to change so completely that your life has a before and after?',
    ),
    'perseids-2027': TurningMeaning(
      observation:
          'The Perseids come from Swift-Tuttle, a 26-kilometer-wide comet that takes about 133 years to circle the Sun.',
      significanceLabel: 'PURSUE',
      personalQuestion:
          'What promising thing are you ready to take seriously and see how far it can go?',
    ),
    'full-moon-2027-08-17': TurningMeaning(
      observation:
          'Fifteen days after the total solar eclipse, the full Moon passes through Earth’s outer shadow—the second eclipse of the same eclipse season.',
      significanceLabel: 'INTEGRATE',
      personalQuestion:
          'What change are you ready to make part of how you actually live?',
    ),
    'full-moon-2027-09-15': TurningMeaning(
      observation:
          'The Moon reaches fullness as the Sun approaches the same equinox threshold it crossed one solar cycle ago.',
      significanceLabel: 'AFFIRM',
      personalQuestion:
          'What became more important to you over this solar cycle—and what will you do with that knowledge?',
    ),
    'autumn-equinox-2027': TurningMeaning(
      observation:
          'Day and night come nearly even. Then the balance begins shifting toward longer nights.',
      significanceLabel: 'REBALANCE',
      personalQuestion:
          'What part of your life deserves a fairer share of your time?',
    ),
    'mercury-elongation-2027-09-24': TurningMeaning(
      observation:
          'One day after the equinox, Mercury reaches its widest evening separation from the Sun and stands briefly clear in the twilight.',
      significanceLabel: 'DECLARE',
      personalQuestion:
          'What direction are you ready to name clearly enough that your choices can start following it?',
    ),
    'full-moon-2027-10-15': TurningMeaning(
      observation:
          'The Moon reaches full illumination while the nights continue growing longer.',
      significanceLabel: 'CLARIFY',
      personalQuestion:
          'What desire is becoming clear enough that you’re ready to act on it?',
    ),
    'saturn-opposition-2027-10-18': TurningMeaning(
      observation:
          'Earth passes between the Sun and Saturn, bringing the ringed planet into one of its brightest and most commanding appearances.',
      significanceLabel: 'MASTER',
      personalQuestion: 'What would you love to become undeniably good at?',
    ),
    'orionids-2027': TurningMeaning(
      observation:
          'Fragments of Halley’s Comet strike Earth’s atmosphere at about 66 kilometers per second—among the fastest meteors we regularly see—and can leave glowing trains behind them.',
      significanceLabel: 'ACCELERATE',
      personalQuestion:
          'What are you ready to accelerate because the direction already feels right?',
    ),
    'mercury-elongation-2027-11-04': TurningMeaning(
      observation:
          'Mercury reaches its greatest separation west of the Sun, becoming visible in the morning sky before sunrise.',
      significanceLabel: 'FORESIGHT',
      personalQuestion:
          'What will you do with something you can see coming before it becomes obvious?',
    ),
    'southern-taurids-2027': TurningMeaning(
      observation:
          'Comet Encke, the source of the Southern Taurids, circles the Sun every 3.3 years—the shortest orbit of any known comet.',
      significanceLabel: 'ITERATE',
      personalQuestion:
          'What could become noticeably better if you gave it one more good pass?',
    ),
    'northern-taurids-2027': TurningMeaning(
      observation:
          'The Northern Taurids belong to the sprawling Taurid complex, where one broad stream of debris has separated into distinct branches.',
      significanceLabel: 'DEFINE',
      personalQuestion: 'What are you ready to make distinctly your own?',
    ),
    'full-moon-2027-11-14': TurningMeaning(
      observation:
          'At fullness, the Moon’s Earth-facing side is completely illuminated, leaving none of its visible face in shadow.',
      significanceLabel: 'REVEAL',
      personalQuestion: 'What are you ready to let people see more of?',
    ),
    'leonids-2027': TurningMeaning(
      observation:
          'The 2027 Leonids may run stronger than usual, with enhanced intervals modeled around 40–50 meteors an hour. The shower has produced extraordinary meteor storms in the past.',
      significanceLabel: 'SURGE',
      personalQuestion:
          'Where could one serious burst of effort change the pace of things?',
    ),
    'venus-mars-conjunction-2027-11-25': TurningMeaning(
      observation:
          'Brilliant Venus and red Mars appear only about 0.3° apart—closer together than the width of a full Moon.',
      significanceLabel: 'DESIRE',
      personalQuestion:
          'What do you want badly enough to bring closer to your real life?',
    ),
    'full-moon-2027-12-13': TurningMeaning(
      observation:
          'The Moon reaches fullness as the Geminids reach their peak, flooding the same sky the meteors are crossing.',
      significanceLabel: 'PRIORITIZE',
      personalQuestion: 'What deserves your fullest attention right now?',
    ),
    'geminids-2027': TurningMeaning(
      observation:
          'First noticed in the mid-1800s as a modest shower, the Geminids have grown into one of the sky’s most reliable annual displays.',
      significanceLabel: 'BECOME',
      personalQuestion:
          'What will you keep developing because it is becoming more than you first imagined?',
    ),
    'winter-solstice-2027': TurningMeaning(
      observation:
          'The Sun reaches its lowest arc and shortest span of daylight. From here, the light begins returning.',
      significanceLabel: 'RETURN',
      personalQuestion:
          'What part of yourself are you ready to bring back into your life?',
    ),
    'ursids-2027': TurningMeaning(
      observation:
          'The Ursids come from Comet 8P/Tuttle, whose long orbit carries it beyond Saturn before it travels back toward the Sun.',
      significanceLabel: 'VENTURE',
      personalQuestion:
          'What are you curious enough to follow farther than you have before?',
    ),
    'quadrantids-2028': TurningMeaning(
      observation:
          'The Quadrantids are named for Quadrans Muralis—a constellation removed from modern star maps, even though its name still survives in the shower.',
      significanceLabel: 'OUTLAST',
      personalQuestion:
          'What are you creating that should survive even if its original form changes?',
    ),
  };

  TurningMeaning forNight(SkyObservingNight night) {
    final meaning = _meaningForEventId(night.anchor.id);
    if (meaning != null) return meaning;
    return _fallbackFor(night);
  }

  TurningMeaning forEvent(SkyEvent event) {
    final meaning = _meaningForEventId(event.id);
    if (meaning != null) return meaning;
    return _fallbackForEvent(event);
  }

  /// Resolves current presentation from stable catalog identity.
  ///
  /// This deliberately ignores persisted function/display copy. Callers that
  /// only have an existing event payload should extract its `skyEventId` and
  /// enter the same resolver path used by the V11 preview and turning sheet.
  TurningMeaning? forCatalogEvent(SkyCatalog catalog, String skyEventId) {
    final event = catalog.byId(skyEventId);
    if (event == null) return null;
    final anchor = event.mergedIntoId == null
        ? event
        : catalog.byId(event.mergedIntoId!);
    if (anchor == null || anchor.mergedIntoId != null) {
      return forEvent(event);
    }
    return forNight(catalog.observingNight(anchor));
  }

  TurningMeaning? _meaningForEventId(String eventId) {
    final canonicalId = _canonicalEventIdAliases[eventId] ?? eventId;
    return _meaningsByCanonicalEventId[canonicalId];
  }

  TurningMeaning _fallbackFor(SkyObservingNight night) =>
      _fallbackForEvent(night.anchor);

  TurningMeaning _fallbackForEvent(SkyEvent event) {
    final label = event.function.displayLabel.toUpperCase();
    return TurningMeaning(
      observation: event.culturalName ?? event.name,
      significanceLabel: label,
      personalQuestion: _questionFor(event.function),
    );
  }

  String _questionFor(SkyEventFunction function) {
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
}
