import '../domain/sky_event.dart';
import '../domain/sky_catalog.dart';
import '../domain/sky_event_kind.dart';

/// Migration-only: map V1 future events → canonical skyEventId.
/// Never used by V2 runtime identity after Cut 3.
class LegacyTrackSkyCandidate {
  const LegacyTrackSkyCandidate({
    required this.clientEventId,
    required this.title,
    required this.startsAtUtc,
    this.category,
    this.ownedByTrackSkyFlow = true,
  });

  final String clientEventId;
  final String title;
  final DateTime startsAtUtc;
  final String? category;
  final bool ownedByTrackSkyFlow;
}

class LegacyTrackSkyMigrationMatcher {
  const LegacyTrackSkyMigrationMatcher();

  /// Returns skyEventId for a legacy occurrence, or null if no confident match.
  String? match({
    required LegacyTrackSkyCandidate legacy,
    required SkyCatalog catalog,
  }) {
    if (!legacy.ownedByTrackSkyFlow) return null;

    final titleKey = _normalize(legacy.title);
    SkyEvent? best;
    var bestScore = 0;

    for (final event in catalog.materializableEvents) {
      final dayDelta = event.primaryInstantUtc
          .difference(legacy.startsAtUtc)
          .inHours
          .abs();
      if (dayDelta > 36) continue;

      var score = 0;
      final eventKey = _normalize(event.name);
      if (titleKey.contains(eventKey) || eventKey.contains(titleKey)) {
        score += 50;
      }
      if (_keywordHit(titleKey, event)) score += 40;
      if (dayDelta <= 12) score += 20;
      if (dayDelta <= 24) score += 10;

      if (score > bestScore) {
        bestScore = score;
        best = event;
      }
    }

    if (bestScore < 50) return null;
    return best?.id;
  }

  Map<String, String> matchAll({
    required List<LegacyTrackSkyCandidate> legacyEvents,
    required SkyCatalog catalog,
  }) {
    final out = <String, String>{};
    final used = <String>{};
    for (final legacy in legacyEvents) {
      final id = match(legacy: legacy, catalog: catalog);
      if (id == null || used.contains(id)) continue;
      used.add(id);
      out[legacy.clientEventId] = id;
    }
    return out;
  }

  bool _keywordHit(String titleKey, SkyEvent event) {
    final needles = <String>[
      ...event.name.toLowerCase().split(RegExp(r'[^a-z0-9]+')),
      event.kind.wireName.toLowerCase(),
    ];
    if (titleKey.contains('equinox') && event.kind.wireName == 'equinox') {
      return true;
    }
    if (titleKey.contains('solstice') && event.kind.wireName == 'solstice') {
      return true;
    }
    if ((titleKey.contains('full moon') || titleKey.contains('supermoon')) &&
        event.kind.wireName == 'fullMoon') {
      return true;
    }
    if (titleKey.contains('eclipse') &&
        (event.kind.wireName == 'lunarEclipse' ||
            event.kind.wireName == 'solarEclipse')) {
      return true;
    }
    for (final n in needles) {
      if (n.length < 4) continue;
      if (titleKey.contains(n)) return true;
    }
    return false;
  }

  String _normalize(String raw) =>
      raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
