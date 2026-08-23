/// User-owned course for Follow the Sky V2.
enum TrackSkyCourseSourceType {
  flow,
  eventTitle,
  freeText,
}

extension TrackSkyCourseSourceTypeX on TrackSkyCourseSourceType {
  String get wireName {
    switch (this) {
      case TrackSkyCourseSourceType.flow:
        return 'flow';
      case TrackSkyCourseSourceType.eventTitle:
        return 'eventTitle';
      case TrackSkyCourseSourceType.freeText:
        return 'freeText';
    }
  }

  static TrackSkyCourseSourceType parse(String raw) {
    switch (raw.trim()) {
      case 'flow':
        return TrackSkyCourseSourceType.flow;
      case 'eventTitle':
        return TrackSkyCourseSourceType.eventTitle;
      case 'freeText':
        return TrackSkyCourseSourceType.freeText;
      default:
        throw FormatException('Unknown TrackSkyCourseSourceType: $raw');
    }
  }
}

class TrackSkyCourse {
  const TrackSkyCourse({
    required this.courseId,
    required this.label,
    required this.sourceType,
    required this.createdAt,
    this.sourceId,
    this.schemaVersion = TrackSkyCourse.currentSchemaVersion,
  });

  static const int currentSchemaVersion = 2;

  /// Stable UUID for this course record (not the linked flow id).
  final String courseId;
  final String label;
  final TrackSkyCourseSourceType sourceType;

  /// Stable source reference. For flows: `flow:<serverId>` (same-user stable).
  /// For event titles: `event_title:<normalized>`. Null for freeText until linked.
  final String? sourceId;
  final DateTime createdAt;
  final int schemaVersion;

  bool get isLinked =>
      sourceType != TrackSkyCourseSourceType.freeText &&
      sourceId != null &&
      sourceId!.trim().isNotEmpty;

  TrackSkyCourse copyWith({
    String? courseId,
    String? label,
    TrackSkyCourseSourceType? sourceType,
    String? sourceId,
    DateTime? createdAt,
    int? schemaVersion,
  }) {
    return TrackSkyCourse(
      courseId: courseId ?? this.courseId,
      label: label ?? this.label,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      createdAt: createdAt ?? this.createdAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }
}

/// Candidate suggested from calendar activity — never a hard-coded intention.
class TrackSkyCourseCandidate {
  const TrackSkyCourseCandidate({
    required this.label,
    required this.sourceType,
    required this.sourceId,
    required this.recentMinutes,
    required this.previousMinutes,
    required this.occurrenceCount,
    required this.driftScore,
    required this.rankScore,
  });

  final String label;
  final TrackSkyCourseSourceType sourceType;
  final String sourceId;
  final int recentMinutes;
  final int previousMinutes;
  final int occurrenceCount;
  final double driftScore;
  final double rankScore;

  /// Debug/live provenance — must always point at a real source ID + activity.
  String get provenance =>
      'label=$label, source=$sourceId, $occurrenceCount occurrences, '
      '$recentMinutes min recent / $previousMinutes min previous';
}
