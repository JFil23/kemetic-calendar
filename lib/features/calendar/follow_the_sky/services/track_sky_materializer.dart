import '../domain/sky_event.dart';
import '../domain/sky_event_function.dart';
import '../domain/sky_event_kind.dart';
import '../domain/sky_observing_night.dart';
import '../domain/sky_visibility.dart';
import 'sky_observation_window_policy.dart';

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
    this.windowPolicy = const SkyObservationWindowPolicy(),
  });

  final LocalTimeConverter toLocal;
  final UtcTimeConverter toUtc;
  final SkyObservationWindowPolicy windowPolicy;

  MaterializedSkyOccurrence materialize({
    required SkyEvent event,
    required String ianaTimeZone,
    String? visibilityNote,
    SkyObservingNight? night,
    String? intention,
  }) {
    final resolved = night ?? SkyObservingNight(anchor: event);
    final windowEvent = resolved.windowSource;
    final window = windowPolicy.resolve(
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
      if (windowEvent.kind == SkyEventKind.solarEclipse)
        'Global greatest eclipse (UTC): '
            '${windowEvent.primaryInstantUtc.toIso8601String()}',
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
}
