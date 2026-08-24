import '../domain/sky_event.dart';
import '../domain/sky_event_function.dart';
import '../domain/sky_event_kind.dart';
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
    observation: 'The moon passes through shadow without leaving its course.',
    significanceLabel: 'ENDURE',
    personalQuestion:
        'What do you want to stay true to when conditions change?',
  );

  TurningMeaning forNight(SkyObservingNight night) {
    if (_isApprovedEclipseExample(night)) return approvedLunarEclipse;
    return _fallbackFor(night);
  }

  TurningMeaning forEvent(SkyEvent event) {
    if (_isApprovedEclipseEvent(event)) return approvedLunarEclipse;
    return _fallbackForEvent(event);
  }

  bool _isApprovedEclipseExample(SkyObservingNight night) {
    return night.companion != null ||
        night.anchor.kind == SkyEventKind.lunarEclipse ||
        night.anchor.name.toLowerCase().contains('eclipse');
  }

  bool _isApprovedEclipseEvent(SkyEvent event) {
    return event.kind == SkyEventKind.lunarEclipse ||
        event.mergedIntoId != null ||
        event.name.toLowerCase().contains('eclipse');
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
