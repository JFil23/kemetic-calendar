import '../domain/sky_event.dart';
import '../domain/sky_event_kind.dart';
import '../domain/sky_visibility.dart';
import 'sky_observation_window_policy.dart';

/// Decides what Hꜣw may claim about local observation.
/// Timezone alone must never claim solar-eclipse or close-conjunction visibility.
class SkyVisibilityService {
  const SkyVisibilityService({
    this.windowPolicy = const SkyObservationWindowPolicy(),
  });

  final SkyObservationWindowPolicy windowPolicy;

  SkyObservationDecision decide(
    SkyEvent event, {
    bool hasObservingLocation = false,
    bool locationConfirmsVisibility = false,
  }) {
    if (event.visibilityPolicy == SkyVisibilityPolicy.global) {
      final prompt = event.specialNotification;
      return SkyObservationDecision(
        canClaimLocalVisibility: true,
        promptObservation: prompt,
        userFacingNote: event.notes ?? '',
      );
    }

    // locationGated
    if (!hasObservingLocation) {
      final kindLabel = event.kind == SkyEventKind.solarEclipse
          ? 'Solar eclipse · global event'
          : '${event.name} · global event';
      return SkyObservationDecision(
        canClaimLocalVisibility: false,
        promptObservation: false,
        userFacingNote: '$kindLabel. Visibility depends on where you are.',
      );
    }

    if (!locationConfirmsVisibility) {
      return SkyObservationDecision(
        canClaimLocalVisibility: false,
        promptObservation: false,
        userFacingNote:
            'Not expected to be visible from your observing location.',
      );
    }

    return SkyObservationDecision(
      canClaimLocalVisibility: true,
      promptObservation: event.specialNotification,
      userFacingNote: event.notes ?? 'Visible from your observing location.',
    );
  }

  /// Default observation window in local civil time for calendar materialization.
  /// Approximate events get coarse windows; UI copy should say "Best tonight" not fake seconds.
  SkyObservationWindow localViewingWindow({
    required SkyEvent event,
    required String ianaTimeZone,
    required DateTime Function(DateTime utc, String iana) toLocal,
  }) {
    return windowPolicy.resolve(
      event: event,
      ianaTimeZone: ianaTimeZone,
      toLocal: toLocal,
    );
  }
}
