import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:mobile/features/calendar/track_sky_timezone.dart';

/// Day-sheet helpers for Follow the Sky V2 — no V1 markdown parser.
class FollowSkyDayDetail {
  static final SkyCatalogRepository _repo = SkyCatalogRepository();
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
  }) {
    final base = (eventDetail ?? '').trim();
    if (skyEventId == null || catalog == null) {
      return _stripNoise(base);
    }
    final event = catalog.byId(skyEventId);
    if (event == null) return _stripNoise(base);
    final decision = const SkyVisibilityService().decide(event);
    final parts = <String>[
      if (base.isNotEmpty) _stripNoise(base),
      'Function: ${event.function.displayLabel}',
      if (decision.userFacingNote.isNotEmpty) decision.userFacingNote,
    ];
    return parts.where((p) => p.trim().isNotEmpty).join('\n');
  }

  static String teaser({
    required String title,
    required String? skyEventId,
    SkyCatalog? catalog,
  }) {
    if (skyEventId != null && catalog != null) {
      final event = catalog.byId(skyEventId);
      if (event != null) {
        return '${event.name} · ${event.function.displayLabel}';
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
        .where((l) => !l.trim().toLowerCase().startsWith('cid='))
        .join('\n')
        .trim();
  }
}
