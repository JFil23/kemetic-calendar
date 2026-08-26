import '../domain/sky_event.dart';
import '../domain/sky_event_kind.dart';

typedef SkyObservationWindow = ({
  DateTime startLocal,
  DateTime endLocal,
  bool allDay,
});

/// The single policy authority that maps an astronomical fact to the civil
/// window used for observation and calendar materialization.
///
/// Exact solar phase instants remain exact. A solar eclipse stays an all-day
/// observation entry because local contacts require location-based eclipse
/// calculations; its global greatest-eclipse instant remains on [SkyEvent].
class SkyObservationWindowPolicy {
  const SkyObservationWindowPolicy();

  SkyObservationWindow resolve({
    required SkyEvent event,
    required String ianaTimeZone,
    required DateTime Function(DateTime utc, String ianaTimeZone) toLocal,
  }) {
    final localInstant = toLocal(event.primaryInstantUtc, ianaTimeZone);
    switch (event.kind) {
      case SkyEventKind.equinox:
      case SkyEventKind.solstice:
        return (
          startLocal: localInstant,
          endLocal: localInstant.add(const Duration(hours: 1)),
          allDay: false,
        );
      case SkyEventKind.fullMoon:
      case SkyEventKind.lunarEclipse:
        final start = DateTime(
          localInstant.year,
          localInstant.month,
          localInstant.day,
          20,
        );
        return (
          startLocal: start,
          endLocal: start.add(const Duration(hours: 1)),
          allDay: false,
        );
      case SkyEventKind.meteorShower:
        return meteorViewingWindow(localInstant);
      case SkyEventKind.planetOpposition:
        final start = DateTime(
          localInstant.year,
          localInstant.month,
          localInstant.day,
          21,
        );
        return (
          startLocal: start,
          endLocal: start.add(const Duration(hours: 1)),
          allDay: false,
        );
      case SkyEventKind.planetElongation:
      case SkyEventKind.planetConjunction:
      case SkyEventKind.solarEclipse:
        final day = DateTime(
          localInstant.year,
          localInstant.month,
          localInstant.day,
        );
        return (
          startLocal: day,
          endLocal: day.add(const Duration(days: 1)),
          allDay: true,
        );
    }
  }

  /// Chooses the 00:00–05:00 local block nearest the source maximum.
  static SkyObservationWindow meteorViewingWindow(DateTime localInstant) {
    final civilInstant = DateTime.utc(
      localInstant.year,
      localInstant.month,
      localInstant.day,
      localInstant.hour,
      localInstant.minute,
      localInstant.second,
      localInstant.millisecond,
      localInstant.microsecond,
    );
    final sameMorningEnd = DateTime.utc(
      localInstant.year,
      localInstant.month,
      localInstant.day,
      5,
    );
    final nextMorningStart = DateTime.utc(
      localInstant.year,
      localInstant.month,
      localInstant.day + 1,
    );
    final sameMorningDistance = civilInstant.isAfter(sameMorningEnd)
        ? civilInstant.difference(sameMorningEnd)
        : Duration.zero;
    final nextMorningDistance = nextMorningStart.difference(civilInstant);
    final useNextMorning = nextMorningDistance < sameMorningDistance;
    final start = DateTime(
      localInstant.year,
      localInstant.month,
      localInstant.day + (useNextMorning ? 1 : 0),
    );

    return (
      startLocal: start,
      endLocal: DateTime(start.year, start.month, start.day, 5),
      allDay: false,
    );
  }
}
