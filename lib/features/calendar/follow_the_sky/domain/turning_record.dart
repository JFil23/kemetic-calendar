enum TurningCompletion { observed, partly, skipped }

extension TurningCompletionX on TurningCompletion {
  String get wireName => switch (this) {
    TurningCompletion.observed => 'observed',
    TurningCompletion.partly => 'partly',
    TurningCompletion.skipped => 'skipped',
  };

  static TurningCompletion? tryParse(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'observed' => TurningCompletion.observed,
      'partly' || 'partial' || 'observed_partly' => TurningCompletion.partly,
      'skipped' => TurningCompletion.skipped,
      _ => null,
    };
  }
}

/// Engagement state for one materialized Follow the Sky occurrence.
///
/// The calendar remains authoritative for time and the occurrence payload for
/// intention. Their values here are immutable encounter-time snapshots.
class TurningRecord {
  const TurningRecord({
    required this.id,
    required this.clientEventId,
    required this.skyEventId,
    required this.intentionSnapshot,
    required this.reflectionText,
    required this.startedAt,
    required this.lastEditedAt,
    required this.scheduledTimeSnapshot,
    this.photoObjectPath,
    this.completion,
    this.completedAt,
  });

  final String id;
  final String clientEventId;
  final String skyEventId;
  final String? intentionSnapshot;
  final String reflectionText;
  final String? photoObjectPath;
  final TurningCompletion? completion;
  final DateTime startedAt;
  final DateTime lastEditedAt;
  final DateTime? completedAt;
  final DateTime scheduledTimeSnapshot;

  TurningRecord copyWith({
    String? id,
    String? reflectionText,
    String? photoObjectPath,
    bool clearPhoto = false,
    TurningCompletion? completion,
    bool clearCompletion = false,
    DateTime? lastEditedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return TurningRecord(
      id: id ?? this.id,
      clientEventId: clientEventId,
      skyEventId: skyEventId,
      intentionSnapshot: intentionSnapshot,
      reflectionText: reflectionText ?? this.reflectionText,
      photoObjectPath: clearPhoto
          ? null
          : photoObjectPath ?? this.photoObjectPath,
      completion: clearCompletion ? null : completion ?? this.completion,
      startedAt: startedAt,
      lastEditedAt: lastEditedAt ?? this.lastEditedAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      scheduledTimeSnapshot: scheduledTimeSnapshot,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'client_event_id': clientEventId,
    'sky_event_id': skyEventId,
    'intention_snapshot': intentionSnapshot,
    'reflection_text': reflectionText,
    'photo_object_path': photoObjectPath,
    'completion_status': completion?.wireName,
    'started_at': startedAt.toUtc().toIso8601String(),
    'last_edited_at': lastEditedAt.toUtc().toIso8601String(),
    'completed_at': completedAt?.toUtc().toIso8601String(),
    'scheduled_time_snapshot': scheduledTimeSnapshot.toUtc().toIso8601String(),
  };

  factory TurningRecord.fromJson(Map<String, dynamic> json) {
    DateTime readDate(String key) =>
        DateTime.parse(json[key] as String).toUtc();
    DateTime? readOptionalDate(String key) {
      final value = json[key]?.toString();
      return value == null || value.isEmpty
          ? null
          : DateTime.parse(value).toUtc();
    }

    return TurningRecord(
      id: json['id'] as String,
      clientEventId: json['client_event_id'] as String,
      skyEventId: json['sky_event_id'] as String,
      intentionSnapshot: json['intention_snapshot']?.toString(),
      reflectionText: json['reflection_text']?.toString() ?? '',
      photoObjectPath: json['photo_object_path']?.toString(),
      completion: TurningCompletionX.tryParse(
        json['completion_status']?.toString(),
      ),
      startedAt: readDate('started_at'),
      lastEditedAt: readDate('last_edited_at'),
      completedAt: readOptionalDate('completed_at'),
      scheduledTimeSnapshot: readDate('scheduled_time_snapshot'),
    );
  }
}
