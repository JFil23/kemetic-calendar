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
  final List<Map<String, dynamic>>? events; // future use when backend returns them
  final String? modelUsed;
  final bool? cached;

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

    return AIFlowGenerationResponse(
      success: (j['success'] as bool?) ?? false,
      flowId: j['flowId'] as int? ?? j['flow_id'] as int?,
      flowName: j['flowName'] as String? ?? j['flow_name'] as String?,
      flowColor: j['flowColor'] as String? ?? j['flow_color'] as String?,
      overviewTitle: j['overviewTitle'] as String? ?? j['overview_title'] as String?,
      overviewSummary: j['overviewSummary'] as String? ?? j['overview_summary'] as String?,
      notes: notesString,
      notesCount: j['notesCount'] as int? ??
          j['notes_count'] as int? ??
          inferredNotesCount,
      events: (j['events'] as List?)?.cast<Map<String, dynamic>>(),
      modelUsed: j['modelUsed'] as String? ?? j['model_used'] as String?,
      cached: j['cached'] as bool?,
    );
  }
}



