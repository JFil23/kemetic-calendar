// lib/data/flow_share_snapshot.dart
// Typed models for flow share payload_json snapshots

import 'flow_appearance.dart';

class FlowShareEventSnapshot {
  final int offsetDays;
  final String title;
  final String? detail;
  final String? location;
  final bool allDay;
  final String? startTime; // "HH:mm"
  final String? endTime; // "HH:mm"
  final int? endOffsetDays;
  final String? actionId;
  final Map<String, dynamic>? behaviorPayload;

  FlowShareEventSnapshot({
    required this.offsetDays,
    required this.title,
    this.detail,
    this.location,
    required this.allDay,
    this.startTime,
    this.endTime,
    this.endOffsetDays,
    this.actionId,
    this.behaviorPayload,
  });

  factory FlowShareEventSnapshot.fromJson(Map<String, dynamic> json) {
    return FlowShareEventSnapshot(
      offsetDays: (json['offset_days'] ?? 0) as int,
      title: (json['title'] ?? '') as String,
      detail: json['detail'] as String?,
      location: json['location'] as String?,
      allDay: (json['all_day'] ?? false) as bool,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      endOffsetDays: (json['end_offset_days'] as num?)?.toInt(),
      actionId: json['action_id'] as String?,
      behaviorPayload: json['behavior_payload'] is Map
          ? Map<String, dynamic>.from(json['behavior_payload'] as Map)
          : null,
    );
  }
}

class FlowSharePayload {
  final String name;
  final int? color;
  final String? notes;
  final List<dynamic> rules; // keep loose for now
  final List<FlowShareEventSnapshot> events;
  final FlowAppearance appearance;

  FlowSharePayload({
    required this.name,
    this.color,
    this.notes,
    required this.rules,
    required this.events,
    this.appearance = FlowAppearance.empty,
  });

  factory FlowSharePayload.fromJson(Map<String, dynamic> json) {
    final eventsJson = (json['events'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return FlowSharePayload(
      name: (json['name'] ?? 'Untitled Flow') as String,
      color: json['color'] as int?,
      notes: json['notes'] as String?,
      rules: (json['rules'] as List<dynamic>? ?? []),
      events: eventsJson
          .map((e) => FlowShareEventSnapshot.fromJson(e))
          .toList(),
      appearance: FlowAppearance.fromJson(json['appearance']),
    );
  }
}

/// Accept both deployed posted-flow times and current share snapshot times.
(int, int)? parseFlowSnapshotTime(Object? raw) {
  if (raw is! String) return null;
  final match = RegExp(
    r'^\s*(\d{1,2}):(\d{2})\s*(am|pm)?\s*$',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match == null) return null;
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final meridian = match.group(3)?.toLowerCase();
  if (minute > 59 ||
      hour > 23 ||
      (meridian != null && (hour < 1 || hour > 12))) {
    return null;
  }
  if (meridian == 'pm' && hour < 12) hour += 12;
  if (meridian == 'am' && hour == 12) hour = 0;
  return (hour, minute);
}
