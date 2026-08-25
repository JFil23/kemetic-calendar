enum SkyVisibilityPolicy {
  /// Safe to schedule/observe generically from civil timezone alone.
  global,

  /// Exists in catalog; do not claim the user can see it from timezone alone.
  locationGated,
}

extension SkyVisibilityPolicyX on SkyVisibilityPolicy {
  String get wireName {
    switch (this) {
      case SkyVisibilityPolicy.global:
        return 'global';
      case SkyVisibilityPolicy.locationGated:
        return 'locationGated';
    }
  }

  static SkyVisibilityPolicy parse(String raw) {
    switch (raw.trim()) {
      case 'global':
        return SkyVisibilityPolicy.global;
      case 'locationGated':
        return SkyVisibilityPolicy.locationGated;
      default:
        throw FormatException('Unknown SkyVisibilityPolicy: $raw');
    }
  }
}

enum SkyEventPrecision {
  /// Moon phases, equinoxes, eclipses — high clock precision.
  phase,

  /// Planet oppositions/elongations/conjunctions — ~± hours; UI should avoid fake precision.
  approximate,
}

extension SkyEventPrecisionX on SkyEventPrecision {
  String get wireName {
    switch (this) {
      case SkyEventPrecision.phase:
        return 'phase';
      case SkyEventPrecision.approximate:
        return 'approximate';
    }
  }

  static SkyEventPrecision parse(String raw) {
    switch (raw.trim()) {
      case 'phase':
        return SkyEventPrecision.phase;
      case 'approximate':
        return SkyEventPrecision.approximate;
      default:
        throw FormatException('Unknown SkyEventPrecision: $raw');
    }
  }
}

/// Observation decision for a specific user context.
class SkyObservationDecision {
  const SkyObservationDecision({
    required this.canClaimLocalVisibility,
    required this.promptObservation,
    required this.userFacingNote,
  });

  final bool canClaimLocalVisibility;
  final bool promptObservation;
  final String userFacingNote;
}
