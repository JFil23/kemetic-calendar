import 'dart:convert';

// lib/models/ai_flow_generation_response.dart

class AIFlowGenerationResponse {
  final bool success;
  final int? flowId;
  final String? flowName;
  final String? flowColor; // hex like "#4dd0e1"
  final String? overviewTitle;
  final String? overviewSummary;
  final String? notes;
  final int? notesCount;
  final List<Map<String, dynamic>>?
  events; // future use when backend returns them
  final String? modelUsed;
  final bool? cached;
  final String? generationId;
  final String? schemaVersion;
  final String? policyVersion;
  final String? snapshotVersion;
  final String? errorMessage;
  final DateTime? requestedStartDate;
  final DateTime? requestedEndDate;

  const AIFlowGenerationResponse({
    required this.success,
    this.flowId,
    this.flowName,
    this.flowColor,
    this.overviewTitle,
    this.overviewSummary,
    this.notes,
    this.notesCount,
    this.events,
    this.modelUsed,
    this.cached,
    this.generationId,
    this.schemaVersion,
    this.policyVersion,
    this.snapshotVersion,
    this.errorMessage,
    this.requestedStartDate,
    this.requestedEndDate,
  });

  factory AIFlowGenerationResponse.fromJson(Map<String, dynamic> j) {
    final notesRaw = j['notes'];
    String? notesString;
    int? inferredNotesCount;

    if (notesRaw is List) {
      inferredNotesCount = notesRaw.length;
      try {
        notesString = jsonEncode(notesRaw);
      } catch (_) {
        notesString = null;
      }
    } else if (notesRaw is String) {
      notesString = notesRaw;
    }

    String? error;
    for (final key in ['error', 'message', 'detail', 'errorMessage']) {
      final v = j[key];
      if (v is String && v.trim().isNotEmpty) {
        error = v.trim();
        break;
      }
    }

    DateTime? parseDate(Object? raw) {
      if (raw is! String || raw.trim().isEmpty) return null;
      return DateTime.tryParse(raw.trim());
    }

    return AIFlowGenerationResponse(
      success: (j['success'] as bool?) ?? false,
      flowId: j['flowId'] as int? ?? j['flow_id'] as int?,
      flowName: j['flowName'] as String? ?? j['flow_name'] as String?,
      flowColor: j['flowColor'] as String? ?? j['flow_color'] as String?,
      overviewTitle:
          j['overviewTitle'] as String? ?? j['overview_title'] as String?,
      overviewSummary:
          j['overviewSummary'] as String? ?? j['overview_summary'] as String?,
      notes: notesString,
      notesCount:
          j['notesCount'] as int? ??
          j['notes_count'] as int? ??
          inferredNotesCount,
      events: (j['events'] as List?)?.cast<Map<String, dynamic>>(),
      modelUsed: j['modelUsed'] as String? ?? j['model_used'] as String?,
      cached: j['cached'] as bool?,
      generationId:
          j['generationId'] as String? ?? j['generation_id'] as String?,
      schemaVersion:
          j['schemaVersion'] as String? ?? j['schema_version'] as String?,
      policyVersion:
          j['policyVersion'] as String? ?? j['policy_version'] as String?,
      snapshotVersion:
          j['snapshotVersion'] as String? ?? j['snapshot_version'] as String?,
      errorMessage: error,
      requestedStartDate: parseDate(
        j['requestedStartDate'] ?? j['requested_start_date'],
      ),
      requestedEndDate: parseDate(
        j['requestedEndDate'] ?? j['requested_end_date'],
      ),
    );
  }

  AIFlowGenerationResponse copyWith({
    bool? success,
    int? flowId,
    String? flowName,
    String? flowColor,
    String? overviewTitle,
    String? overviewSummary,
    String? notes,
    int? notesCount,
    List<Map<String, dynamic>>? events,
    String? modelUsed,
    bool? cached,
    String? generationId,
    String? schemaVersion,
    String? policyVersion,
    String? snapshotVersion,
    String? errorMessage,
    DateTime? requestedStartDate,
    DateTime? requestedEndDate,
  }) {
    return AIFlowGenerationResponse(
      success: success ?? this.success,
      flowId: flowId ?? this.flowId,
      flowName: flowName ?? this.flowName,
      flowColor: flowColor ?? this.flowColor,
      overviewTitle: overviewTitle ?? this.overviewTitle,
      overviewSummary: overviewSummary ?? this.overviewSummary,
      notes: notes ?? this.notes,
      notesCount: notesCount ?? this.notesCount,
      events: events ?? this.events,
      modelUsed: modelUsed ?? this.modelUsed,
      cached: cached ?? this.cached,
      generationId: generationId ?? this.generationId,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      policyVersion: policyVersion ?? this.policyVersion,
      snapshotVersion: snapshotVersion ?? this.snapshotVersion,
      errorMessage: errorMessage ?? this.errorMessage,
      requestedStartDate: requestedStartDate ?? this.requestedStartDate,
      requestedEndDate: requestedEndDate ?? this.requestedEndDate,
    );
  }
}
