import '../domain/sky_event.dart';
import '../domain/sky_event_function.dart';
import '../domain/sky_event_kind.dart';
import '../domain/sky_observing_night.dart';
import '../domain/sky_visibility.dart';

/// Ownership metadata stamped on V2-generated (or migrated) calendar events.
class TrackSkyEventOwnership {
  static const int schemaVersion = 2;
  static const String behaviorKind = 'track_sky_v2';

  static Map<String, dynamic> behaviorPayload({
    required String skyEventId,
    bool legacyPreserved = false,
    List<String> mergedCompanionSkyEventIds = const [],
    String? resolvedFunction,
    String? displayName,
    String? intention,
  }) {
    return <String, dynamic>{
      'kind': behaviorKind,
      'skyEventId': skyEventId,
      'trackSkySchemaVersion': schemaVersion,
      if (legacyPreserved) 'legacyPreserved': true,
      if (mergedCompanionSkyEventIds.isNotEmpty)
        'mergedCompanionSkyEventIds': List<String>.from(
          mergedCompanionSkyEventIds,
        ),
      if (resolvedFunction != null && resolvedFunction.isNotEmpty)
        'resolvedFunction': resolvedFunction,
      if (displayName != null && displayName.isNotEmpty)
        'displayName': displayName,
      if (intention != null && intention.trim().isNotEmpty)
        'intention': intention.trim(),
    };
  }

  static String? skyEventIdFromPayload(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    if (payload['kind'] != behaviorKind) return null;
    final id = payload['skyEventId'];
    return id is String ? id : null;
  }

  static List<String> companionIdsFromPayload(Map<String, dynamic>? payload) {
    if (payload == null) return const [];
    if (payload['kind'] != behaviorKind) return const [];
    final raw = payload['mergedCompanionSkyEventIds'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is String && item.isNotEmpty) item,
    ];
  }

  static String? resolvedFunctionFromPayload(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    if (payload['kind'] != behaviorKind) return null;
    final v = payload['resolvedFunction'];
    return v is String && v.isNotEmpty ? v : null;
  }

  static String? displayNameFromPayload(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    if (payload['kind'] != behaviorKind) return null;
    final v = payload['displayName'];
    return v is String && v.isNotEmpty ? v : null;
  }

  static String? intentionFromPayload(Map<String, dynamic>? payload) {
    if (payload == null || payload['kind'] != behaviorKind) return null;
    final value = payload['intention'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  static bool isLegacyPreserved(Map<String, dynamic>? payload) {
    if (payload == null) return false;
    return payload['legacyPreserved'] == true;
  }

  static bool isEclipseObservingNight(Map<String, dynamic>? payload) {
    return companionIdsFromPayload(payload).isNotEmpty;
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

typedef LocalTimeConverter =
    DateTime Function(DateTime utc, String ianaTimeZone);
typedef UtcTimeConverter =
    DateTime Function(DateTime local, String ianaTimeZone);

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
    SkyObservingNight? night,
    String? intention,
  }) {
    final resolved = night ?? SkyObservingNight(anchor: event);
    final windowEvent = resolved.windowSource;
    final window = windowBuilder(
      event: windowEvent,
      ianaTimeZone: ianaTimeZone,
      toLocal: toLocal,
    );
    final detailParts = <String>[
      if (visibilityNote != null && visibilityNote.trim().isNotEmpty)
        visibilityNote.trim(),
      'skyEventId=${resolved.skyEventId}',
      'Function: ${resolved.function.displayLabel}',
      if (resolved.isEclipseFullMoon)
        'Merged companion: ${resolved.companion!.id}',
      if (windowEvent.precision.wireName == 'approximate') 'Best tonight',
      if (resolved.provisional) 'Provisional — source may update',
      if (intention != null && intention.trim().isNotEmpty)
        'Intention: ${intention.trim()}',
    ];
    return MaterializedSkyOccurrence(
      skyEventId: resolved.skyEventId,
      title: resolved.displayName,
      category: TrackSkyEventOwnership.categoryFor(windowEvent),
      startsAtUtc: toUtc(window.startLocal, ianaTimeZone),
      startsAtLocal: window.startLocal,
      endsAtUtc: toUtc(window.endLocal, ianaTimeZone),
      endsAtLocal: window.endLocal,
      allDay: window.allDay,
      behaviorPayload: TrackSkyEventOwnership.behaviorPayload(
        skyEventId: resolved.skyEventId,
        mergedCompanionSkyEventIds: [
          if (resolved.companion != null) resolved.companion!.id,
        ],
        resolvedFunction: resolved.function.wireName,
        displayName: resolved.displayName,
        intention: intention,
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
  static ({DateTime startLocal, DateTime endLocal, bool allDay})
  meteorViewingWindow(DateTime localInstant) {
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

typedef SkyVisibilityWindowBuilder =
    ({DateTime startLocal, DateTime endLocal, bool allDay}) Function({
      required SkyEvent event,
      required String ianaTimeZone,
      required LocalTimeConverter toLocal,
    });
