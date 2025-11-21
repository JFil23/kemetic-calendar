// lib/models/ai_generated_flow.dart
// ✅ REFACTOR: New model for AI-generated flows (no dates, only day_index)

import 'package:flutter/foundation.dart';

class AiGeneratedFlow {
  final String flowName;
  final String overviewTitle;
  final String overviewSummary;
  final String? flowColor; // hex like "#4dd0e1"
  final List<AiGeneratedNote> notes;
  final Map<String, dynamic>? metadata;

  const AiGeneratedFlow({
    required this.flowName,
    required this.overviewTitle,
    required this.overviewSummary,
    this.flowColor,
    required this.notes,
    this.metadata,
  });

  factory AiGeneratedFlow.fromJson(
    Map<String, dynamic> json, {
    DateTime? startDate, // ✅ needed to compute day_index from old `date` fields
  }) {
    // ---- 1. Basic fields ----
    String flowName =
        json['flow_name'] as String? ?? json['flowName'] as String? ?? '';
    if (flowName.trim().isEmpty) {
      flowName = 'Untitled Flow';
    }

    final String? overviewTitle =
        json['overview_title'] as String? ?? json['overviewTitle'] as String?;
    final String? overviewSummary =
        json['overview_summary'] as String? ?? json['overviewSummary'] as String?;
    final String? flowColor =
        json['flow_color'] as String? ?? json['flowColor'] as String?;

    // ---- 2. Aggressive "find the notes" logic ----
    dynamic notesRaw = json['notes'];
    
    bool _isEmpty(dynamic v) =>
        v == null ||
        (v is List && v.isEmpty) ||
        (v is Map && v.isEmpty);
    
    // Fallback to common alternate keys if notes is missing or empty
    if (_isEmpty(notesRaw)) {
      notesRaw = json['days'] ??
          json['day_list'] ??
          json['schedule'] ??
          json['plan'] ??
          json['entries'] ??
          json['events'];
    }
    
    // As a final safety net, scan for a List of Maps that looks like note objects
    if (_isEmpty(notesRaw)) {
      for (final entry in json.entries) {
        final value = entry.value;
        if (value is List &&
            value.isNotEmpty &&
            value.first is Map &&
            ((value.first as Map).containsKey('title') ||
                (value.first as Map).containsKey('details') ||
                (value.first as Map).containsKey('day_index'))) {
          notesRaw = value;
          if (kDebugMode) {
            debugPrint('🔍 [AiGeneratedFlow.fromJson] Using "${entry.key}" as notes');
          }
          break;
        }
      }
    }
    
    if (kDebugMode) {
      debugPrint('🔍 [AiGeneratedFlow.fromJson] notesRaw type: ${notesRaw.runtimeType}');
    }
    
    List rawNotes;
    
    if (notesRaw is List) {
      rawNotes = notesRaw;
    } else if (notesRaw is Map) {
      // If TS ever returns an object keyed by day/etc, pull the values
      rawNotes = notesRaw.values.toList();
    } else if (notesRaw == null) {
      rawNotes = const [];
    } else {
      if (kDebugMode) {
        debugPrint('🔍 [AiGeneratedFlow.fromJson] ⚠️ notesRaw is ${notesRaw.runtimeType}, not List/Map');
      }
      rawNotes = const [];
    }
    
    if (kDebugMode) {
      debugPrint('[AiGeneratedFlow.fromJson] rawNotes.length = ${rawNotes.length}');
      debugPrint('[AiGeneratedFlow.fromJson] json keys = ${json.keys}');
      if (rawNotes.isEmpty) {
        debugPrint(
            '[AiGeneratedFlow.fromJson] ⚠️ WARNING: Empty notes array in AI response after normalization');
      }
    }

    // ---- 3. Normalize notes to the new shape ----
    final normalizedNotes = <AiGeneratedNote>[];

    for (var i = 0; i < rawNotes.length; i++) {
      final raw = Map<String, dynamic>.from(rawNotes[i] as Map);

      if (kDebugMode && i == 0) {
        debugPrint('[AiGeneratedFlow.fromJson] First raw note keys: ${raw.keys}');
        debugPrint('[AiGeneratedFlow.fromJson] First raw note value: $raw');
      }

      // 3a. Ensure day_index exists (support old date-based format)
      if (!raw.containsKey('day_index')) {
        if (startDate != null && raw['date'] is String) {
          try {
            final nd = DateTime.parse(raw['date'] as String);
            final noteDay = DateTime(nd.year, nd.month, nd.day);
            final start =
                DateTime(startDate.year, startDate.month, startDate.day);
            final idx = noteDay.difference(start).inDays;
            raw['day_index'] = idx < 0 ? 0 : idx; // clamp negatives
          } catch (_) {
            raw['day_index'] = i; // fallback: sequential
          }
        } else {
          raw['day_index'] = i; // fallback: sequential
        }
      }

      // 3b. all_day: normalize allDay → all_day
      if (!raw.containsKey('all_day') && raw.containsKey('allDay')) {
        raw['all_day'] = raw['allDay'];
      }

      // 3c. start_time: normalize startsAt (ISO) → "HH:mm"
      if (!raw.containsKey('start_time') && raw['startsAt'] is String) {
        try {
          final dt = DateTime.parse(raw['startsAt'] as String);
          raw['start_time'] =
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } catch (_) {
          // leave null
        }
      }

      // 3d. end_time: normalize endsAt (ISO) → "HH:mm"
      if (!raw.containsKey('end_time') && raw['endsAt'] is String) {
        try {
          final dt = DateTime.parse(raw['endsAt'] as String);
          raw['end_time'] =
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } catch (_) {
          // leave null
        }
      }

      normalizedNotes.add(AiGeneratedNote.fromJson(raw));
    }

    if (kDebugMode) {
      debugPrint(
          '[AiGeneratedFlow.fromJson] normalizedNotes.length = ${normalizedNotes.length}');
    }

    return AiGeneratedFlow(
      flowName: flowName,
      overviewTitle: overviewTitle ?? '',
      overviewSummary: overviewSummary ?? '',
      flowColor: flowColor,
      notes: normalizedNotes,
      // accept either `ai_metadata` (new) or `metadata` (old)
      metadata:
          (json['ai_metadata'] ?? json['metadata']) as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'flow_name': flowName,
      'overview_title': overviewTitle,
      'overview_summary': overviewSummary,
      if (flowColor != null) 'flow_color': flowColor,
      'notes': notes.map((n) => n.toJson()).toList(),
      if (metadata != null) 'ai_metadata': metadata,
    };
  }
}

class AiGeneratedNote {
  final int dayIndex; // 0-based offset from start date
  final String title;
  final String details;
  final bool allDay;
  final String? startTime; // "HH:mm" format
  final String? endTime; // "HH:mm" format
  final String? location;

  const AiGeneratedNote({
    required this.dayIndex,
    required this.title,
    required this.details,
    required this.allDay,
    this.startTime,
    this.endTime,
    this.location,
  });

  factory AiGeneratedNote.fromJson(Map<String, dynamic> json) {
    // dayIndex: support both day_index and dayIndex, ints or numbers
    final int dayIndex = (json['day_index'] as num?)?.toInt() ??
        (json['dayIndex'] as num?)?.toInt() ??
        0;

    // allDay: snake_case / camelCase
    final bool allDay =
        json['all_day'] as bool? ?? json['allDay'] as bool? ?? false;

    // Times: snake_case / camelCase
    final String? startTime =
        json['start_time'] as String? ?? json['startTime'] as String?;
    final String? endTime =
        json['end_time'] as String? ?? json['endTime'] as String?;

    // Title / details: robust fallbacks
    final String rawTitle = (json['title'] as String?)?.trim() ?? '';
    final String rawDetails =
        (json['details'] as String?)?.trim() ??
        (json['description'] as String?)?.trim() ??
        '';

    final String title = rawTitle.isEmpty ? 'Untitled' : rawTitle;
    final String details = rawDetails;

    return AiGeneratedNote(
      dayIndex: dayIndex,
      title: title,
      details: details,
      allDay: allDay,
      startTime: startTime,
      endTime: endTime,
      location: (json['location'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day_index': dayIndex,
      'title': title,
      'details': details,
      'all_day': allDay,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (location != null) 'location': location,
    };
  }
}

