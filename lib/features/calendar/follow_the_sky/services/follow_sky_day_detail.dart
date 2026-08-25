import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:mobile/features/calendar/track_sky_timezone.dart';

/// Day-sheet helpers for Follow the Sky V2 — no V1 markdown parser.
class FollowSkyDayDetail {
  static final SkyCatalogRepository _repo = SkyCatalogRepository();
  static const TurningMeaningResolver _meaningResolver =
      TurningMeaningResolver();
  static SkyCatalog? _cached;

  static Future<SkyCatalog> catalog() async {
    return _cached ??= await _repo.load();
  }

  static String? skyEventIdFromBehavior(Map<String, dynamic>? payload) {
    return TrackSkyEventOwnership.skyEventIdFromPayload(payload);
  }

  static String displayDetail({
    required String? eventDetail,
    required String? skyEventId,
    SkyCatalog? catalog,
    Map<String, dynamic>? behaviorPayload,
  }) {
    final base = (eventDetail ?? '').trim();
    final companions = TrackSkyEventOwnership.companionIdsFromPayload(
      behaviorPayload,
    );
    final intention = TrackSkyEventOwnership.intentionFromPayload(
      behaviorPayload,
    );
    final resolvedId = skyEventId ?? skyEventIdFromBehavior(behaviorPayload);
    if (resolvedId == null || catalog == null) return _stripNoise(base);
    final event = catalog.byId(resolvedId);
    final meaning = _meaningResolver.forCatalogEvent(catalog, resolvedId);
    if (event == null || meaning == null) return _stripNoise(base);
    final night = event.mergedIntoId == null
        ? catalog.observingNight(event)
        : null;
    final decision = const SkyVisibilityService().decide(
      night?.windowSource ?? event,
    );
    final parts = <String>[
      meaning.observation,
      meaning.significanceLabel,
      meaning.personalQuestion,
      if (companions.isNotEmpty)
        'Merged companions: ${companions.join(', ')}'
      else if (night?.companion != null)
        'Merged companions: ${night!.companion!.id}',
      if (decision.userFacingNote.isNotEmpty) decision.userFacingNote,
      if (intention != null) 'Intention: $intention',
    ];
    return parts.where((p) => p.trim().isNotEmpty).join('\n');
  }

  static String teaser({
    required String title,
    required String? skyEventId,
    SkyCatalog? catalog,
    Map<String, dynamic>? behaviorPayload,
  }) {
    final resolvedId = skyEventId ?? skyEventIdFromBehavior(behaviorPayload);
    if (resolvedId != null && catalog != null) {
      final event = catalog.byId(resolvedId);
      final meaning = _meaningResolver.forCatalogEvent(catalog, resolvedId);
      if (event != null && meaning != null) {
        final displayName = event.mergedIntoId == null
            ? catalog.observingNight(event).displayName
            : event.name;
        return '${meaning.titledSignificanceLabel} · $displayName';
      }
    }
    return title;
  }

  static TrackSkyTimeZone? timezoneFromNotes(String? notes) {
    if (notes == null) return null;
    for (final part in notes.split(';')) {
      final trimmed = part.trim();
      if (!trimmed.startsWith('sky_tz=')) continue;
      return TrackSkyTimeZoneX.tryParse(trimmed.substring('sky_tz='.length));
    }
    return null;
  }

  static String _stripNoise(String raw) {
    return raw
        .split('\n')
        .where((line) {
          final lower = line.trim().toLowerCase();
          return !lower.startsWith('cid=') &&
              !lower.startsWith('skyeventid=') &&
              !lower.startsWith('function:');
        })
        .join('\n')
        .trim();
  }
}
