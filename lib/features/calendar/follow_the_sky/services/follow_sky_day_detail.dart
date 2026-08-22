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
    Map<String, dynamic>? behaviorPayload,
  }) {
    final base = (eventDetail ?? '').trim();
    final payloadName =
        TrackSkyEventOwnership.displayNameFromPayload(behaviorPayload);
    final payloadFn =
        TrackSkyEventOwnership.resolvedFunctionFromPayload(behaviorPayload);
    final companions =
        TrackSkyEventOwnership.companionIdsFromPayload(behaviorPayload);

    if (skyEventId == null || catalog == null) {
      final parts = <String>[
        if (base.isNotEmpty) _stripNoise(base),
        if (payloadFn != null) 'Function: ${_labelForFunctionWire(payloadFn)}',
        if (companions.isNotEmpty)
          'Merged companions: ${companions.join(', ')}',
      ];
      return parts.where((p) => p.trim().isNotEmpty).join('\n');
    }
    final event = catalog.byId(skyEventId);
    if (event == null) return _stripNoise(base);
    final night = event.mergedIntoId == null
        ? catalog.observingNight(event)
        : null;
    final decision = const SkyVisibilityService().decide(
      night?.windowSource ?? event,
    );
    final functionLabel = payloadFn != null
        ? _labelForFunctionWire(payloadFn)
        : (night?.function ?? event.function).displayLabel;
    final parts = <String>[
      if (base.isNotEmpty) _stripNoise(base),
      if (payloadName != null &&
          !base.contains(payloadName) &&
          night?.isEclipseFullMoon == true)
        payloadName,
      'Function: $functionLabel',
      if (companions.isNotEmpty)
        'Merged companions: ${companions.join(', ')}'
      else if (night?.companion != null)
        'Merged companions: ${night!.companion!.id}',
      if (decision.userFacingNote.isNotEmpty) decision.userFacingNote,
    ];
    return parts.where((p) => p.trim().isNotEmpty).join('\n');
  }

  static String teaser({
    required String title,
    required String? skyEventId,
    SkyCatalog? catalog,
    Map<String, dynamic>? behaviorPayload,
  }) {
    final payloadName =
        TrackSkyEventOwnership.displayNameFromPayload(behaviorPayload);
    final payloadFn =
        TrackSkyEventOwnership.resolvedFunctionFromPayload(behaviorPayload);
    if (payloadName != null && payloadFn != null) {
      return '$payloadName · ${_labelForFunctionWire(payloadFn)}';
    }
    if (skyEventId != null && catalog != null) {
      final event = catalog.byId(skyEventId);
      if (event != null && event.mergedIntoId == null) {
        final night = catalog.observingNight(event);
        return '${night.displayName} · ${night.function.displayLabel}';
      }
      if (event != null) {
        return '${event.name} · ${event.function.displayLabel}';
      }
    }
    return title;
  }

  static String _labelForFunctionWire(String wire) {
    try {
      return SkyEventFunctionX.parse(wire).displayLabel;
    } catch (_) {
      return wire;
    }
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
