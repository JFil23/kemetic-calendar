import 'sky_event.dart';
import 'sky_observing_night.dart';

class SkyCatalog {
  const SkyCatalog({
    required this.schemaVersion,
    required this.sourceVersion,
    required this.coverageStart,
    required this.coverageEnd,
    required this.events,
  });

  final int schemaVersion;
  final String sourceVersion;
  final DateTime coverageStart;
  final DateTime coverageEnd;
  final List<SkyEvent> events;

  SkyEvent? byId(String id) {
    for (final event in events) {
      if (event.id == id) return event;
    }
    return null;
  }

  /// Events that should materialize as calendar rows (merged eclipses stay metadata-only).
  List<SkyEvent> get materializableEvents =>
      events.where((e) => e.mergedIntoId == null).toList(growable: false);

  /// Companion lunar eclipse merged into a Full Moon anchor, if any.
  SkyEvent? companionMergedInto(String anchorId) {
    for (final event in events) {
      if (event.mergedIntoId == anchorId) return event;
    }
    return null;
  }

  /// Resolve one observing night: eclipse overrides Full Moon → Reconsider.
  SkyObservingNight observingNight(SkyEvent anchor) {
    if (anchor.mergedIntoId != null) {
      throw ArgumentError(
        'observingNight requires a materializable anchor, got ${anchor.id}',
      );
    }
    return SkyObservingNight(
      anchor: anchor,
      companion: companionMergedInto(anchor.id),
    );
  }

  List<SkyEvent> upcoming({
    required DateTime nowUtc,
    DateTime? untilUtc,
  }) {
    final end = untilUtc ?? coverageEnd;
    return materializableEvents.where((e) {
      final t = e.primaryInstantUtc;
      return !t.isBefore(nowUtc) && !t.isAfter(end);
    }).toList(growable: false)
      ..sort((a, b) => a.primaryInstantUtc.compareTo(b.primaryInstantUtc));
  }

  List<SkyObservingNight> upcomingNights({
    required DateTime nowUtc,
    DateTime? untilUtc,
  }) {
    return upcoming(nowUtc: nowUtc, untilUtc: untilUtc)
        .map(observingNight)
        .toList(growable: false);
  }

  SkyEvent? nextTurning({required DateTime nowUtc}) {
    final list = upcoming(nowUtc: nowUtc);
    return list.isEmpty ? null : list.first;
  }

  SkyObservingNight? nextObservingNight({required DateTime nowUtc}) {
    final next = nextTurning(nowUtc: nowUtc);
    return next == null ? null : observingNight(next);
  }

  int get observingNightCount => materializableEvents.length;

  int get eclipseFullMoonNightCount => materializableEvents
      .where((e) => companionMergedInto(e.id) != null)
      .length;

  factory SkyCatalog.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'] as List? ?? const [];
    return SkyCatalog(
      schemaVersion: json['schemaVersion'] as int? ?? 2,
      sourceVersion: json['sourceVersion'] as String? ?? '',
      coverageStart: DateTime.parse(json['coverageStart'] as String).toUtc(),
      coverageEnd: DateTime.parse(json['coverageEnd'] as String).toUtc(),
      events: rawEvents
          .map((e) => SkyEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
    );
  }
}
