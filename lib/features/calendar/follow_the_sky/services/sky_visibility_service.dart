import '../domain/sky_event.dart';
import '../domain/sky_event_kind.dart';
import '../domain/sky_visibility.dart';
import 'track_sky_materializer.dart';

/// Decides what Hꜣw may claim about local observation.
/// Timezone alone must never claim solar-eclipse or close-conjunction visibility.
class SkyVisibilityService {
  const SkyVisibilityService();

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
        userFacingNote:
            '$kindLabel. Visibility depends on where you are.',
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
  ({DateTime startLocal, DateTime endLocal, bool allDay}) localViewingWindow({
    required SkyEvent event,
    required String ianaTimeZone,
    required DateTime Function(DateTime utc, String iana) toLocal,
  }) {
    final localInstant = toLocal(event.primaryInstantUtc, ianaTimeZone);
    switch (event.kind) {
      case SkyEventKind.equinox:
        final start = DateTime(
          localInstant.year,
          localInstant.month,
          localInstant.day,
          localInstant.month == 9 ? 18 : 6,
          localInstant.month == 9 ? 0 : 30,
        );
        return (startLocal: start, endLocal: start.add(const Duration(hours: 1)), allDay: false);
      case SkyEventKind.solstice:
        final start = DateTime(
          localInstant.year,
          localInstant.month,
          localInstant.day,
          17,
          0,
        );
        return (startLocal: start, endLocal: start.add(const Duration(hours: 1)), allDay: false);
      case SkyEventKind.fullMoon:
      case SkyEventKind.lunarEclipse:
        final start = DateTime(
          localInstant.year,
          localInstant.month,
          localInstant.day,
          20,
          0,
        );
        return (startLocal: start, endLocal: start.add(const Duration(hours: 1)), allDay: false);
      case SkyEventKind.meteorShower:
        return TrackSkyMaterializer.meteorViewingWindow(localInstant);
      case SkyEventKind.planetOpposition:
        final start = DateTime(
          localInstant.year,
          localInstant.month,
          localInstant.day,
          21,
          0,
        );
        return (startLocal: start, endLocal: start.add(const Duration(hours: 1)), allDay: false);
      case SkyEventKind.planetElongation:
      case SkyEventKind.planetConjunction:
      case SkyEventKind.solarEclipse:
        final day = DateTime(localInstant.year, localInstant.month, localInstant.day);
        return (startLocal: day, endLocal: day.add(const Duration(days: 1)), allDay: true);
    }
  }
}
