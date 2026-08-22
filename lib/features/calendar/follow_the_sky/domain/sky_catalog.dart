import '../domain/sky_event.dart';

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

  SkyEvent? nextTurning({required DateTime nowUtc}) {
    final list = upcoming(nowUtc: nowUtc);
    return list.isEmpty ? null : list.first;
  }

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
