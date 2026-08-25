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
