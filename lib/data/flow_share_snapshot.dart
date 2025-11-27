// lib/data/flow_share_snapshot.dart
// Typed models for flow share payload_json snapshots

import 'package:flutter/foundation.dart';

class FlowShareEventSnapshot {
  final int offsetDays;
  final String title;
  final String? detail;
  final String? location;
  final bool allDay;
  final String? startTime; // "HH:mm"
  final String? endTime;   // "HH:mm"

  FlowShareEventSnapshot({
    required this.offsetDays,
    required this.title,
    this.detail,
    this.location,
    required this.allDay,
    this.startTime,
    this.endTime,
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
    );
  }
}

class FlowSharePayload {
  final String name;
  final int? color;
  final String? notes;
  final List<dynamic> rules; // keep loose for now
  final List<FlowShareEventSnapshot> events;

  FlowSharePayload({
    required this.name,
    this.color,
    this.notes,
    required this.rules,
    required this.events,
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
    );
  }
}

