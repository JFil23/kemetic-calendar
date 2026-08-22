import '../domain/sky_event.dart';
import '../domain/sky_event_function.dart';
import '../domain/sky_event_kind.dart';
import '../domain/sky_visibility.dart';

/// Ownership metadata stamped on V2-generated (or migrated) calendar events.
class TrackSkyEventOwnership {
  static const int schemaVersion = 2;
  static const String behaviorKind = 'track_sky_v2';

  static Map<String, dynamic> behaviorPayload({
    required String skyEventId,
    bool legacyPreserved = false,
  }) {
    return <String, dynamic>{
      'kind': behaviorKind,
      'skyEventId': skyEventId,
      'trackSkySchemaVersion': schemaVersion,
      if (legacyPreserved) 'legacyPreserved': true,
    };
  }

  static String? skyEventIdFromPayload(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    if (payload['kind'] != behaviorKind) return null;
    final id = payload['skyEventId'];
    return id is String ? id : null;
  }

  static bool isLegacyPreserved(Map<String, dynamic>? payload) {
    if (payload == null) return false;
    return payload['legacyPreserved'] == true;
  }

  static String categoryFor(SkyEvent event) {
    switch (event.kind) {
      case SkyEventKind.equinox:
      case SkyEventKind.solstice:
      case SkyEventKind.solarEclipse:
        return 'Solar Events';
      case SkyEventKind.fullMoon:
      case SkyEventKind.lunarEclipse:
        return 'Lunar Events';
      case SkyEventKind.meteorShower:
        return 'Meteor Showers';
      case SkyEventKind.planetOpposition:
      case SkyEventKind.planetElongation:
      case SkyEventKind.planetConjunction:
        return 'Planetary Highlights';
    }
  }
}

class MaterializedSkyOccurrence {
  const MaterializedSkyOccurrence({
    required this.skyEventId,
    required this.title,
    required this.category,
    required this.startsAtUtc,
    required this.startsAtLocal,
    required this.endsAtUtc,
    required this.endsAtLocal,
    required this.allDay,
    required this.behaviorPayload,
    required this.detail,
  });

  final String skyEventId;
  final String title;
  final String category;
  final DateTime startsAtUtc;
  final DateTime startsAtLocal;
  final DateTime endsAtUtc;
  final DateTime endsAtLocal;
  final bool allDay;
  final Map<String, dynamic> behaviorPayload;
  final String detail;
}

typedef LocalTimeConverter = DateTime Function(DateTime utc, String ianaTimeZone);
typedef UtcTimeConverter = DateTime Function(DateTime local, String ianaTimeZone);

/// Builds V2 calendar occurrence drafts from canonical catalog events.
class TrackSkyMaterializer {
  TrackSkyMaterializer({
    required this.toLocal,
    required this.toUtc,
    SkyVisibilityWindowBuilder? windowBuilder,
  }) : windowBuilder = windowBuilder ?? defaultWindowBuilder;

  final LocalTimeConverter toLocal;
  final UtcTimeConverter toUtc;
  final SkyVisibilityWindowBuilder windowBuilder;

  MaterializedSkyOccurrence materialize({
    required SkyEvent event,
    required String ianaTimeZone,
    String? visibilityNote,
  }) {
    final window = windowBuilder(event: event, ianaTimeZone: ianaTimeZone, toLocal: toLocal);
    final detailParts = <String>[
      if (visibilityNote != null && visibilityNote.trim().isNotEmpty)
        visibilityNote.trim(),
      'skyEventId=${event.id}',
      'Function: ${event.function.displayLabel}',
      if (event.precision.wireName == 'approximate') 'Best tonight',
      if (event.provisional) 'Provisional — source may update',
    ];
    return MaterializedSkyOccurrence(
      skyEventId: event.id,
      title: event.name,
      category: TrackSkyEventOwnership.categoryFor(event),
      startsAtUtc: toUtc(window.startLocal, ianaTimeZone),
      startsAtLocal: window.startLocal,
      endsAtUtc: toUtc(window.endLocal, ianaTimeZone),
      endsAtLocal: window.endLocal,
      allDay: window.allDay,
      behaviorPayload: TrackSkyEventOwnership.behaviorPayload(
        skyEventId: event.id,
      ),
      detail: detailParts.join('\n'),
    );
  }

  static ({DateTime startLocal, DateTime endLocal, bool allDay})
      defaultWindowBuilder({
    required SkyEvent event,
    required String ianaTimeZone,
    required LocalTimeConverter toLocal,
  }) {
    final localInstant = toLocal(event.primaryInstantUtc, ianaTimeZone);
    switch (event.kind) {
      case SkyEventKind.equinox:
        final start = DateTime(
          localInstant.year,
          localInstant.month,
          localInstant.day,
          localInstant.month == 9 || localInstant.month == 10 ? 18 : 6,
          localInstant.month == 9 || localInstant.month == 10 ? 0 : 30,
        );
        return (
          startLocal: start,
          endLocal: start.add(const Duration(hours: 1)),
          allDay: false,
        );
      case SkyEventKind.solstice:
        final start = DateTime(
          localInstant.year,
          localInstant.month,
          localInstant.day,
          17,
        );
        return (
          startLocal: start,
          endLocal: start.add(const Duration(hours: 1)),
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
        final start = DateTime(
          localInstant.year,
          localInstant.month,
          localInstant.day,
        );
        return (
          startLocal: start,
          endLocal: start.add(const Duration(hours: 5)),
          allDay: false,
        );
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
}

typedef SkyVisibilityWindowBuilder = ({
  DateTime startLocal,
  DateTime endLocal,
  bool allDay,
}) Function({
  required SkyEvent event,
  required String ianaTimeZone,
  required LocalTimeConverter toLocal,
});
