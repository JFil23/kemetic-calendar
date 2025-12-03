// lib/models/ai_flow_generation_response.dart

class AIFlowGenerationResponse {
  final bool success;
  final int? flowId;
  final String? flowName;
  final String? flowColor; // hex like "#4dd0e1"
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
    this.notes,
    this.notesCount,
    this.events,
    this.modelUsed,
    this.cached,
  });

  factory AIFlowGenerationResponse.fromJson(Map<String, dynamic> j) {
    return AIFlowGenerationResponse(
      success: (j['success'] as bool?) ?? false,
      flowId: j['flowId'] as int?,
      flowName: j['flowName'] as String?,
      flowColor: j['flowColor'] as String?,
      notes: j['notes'] as String?,
      notesCount: j['notesCount'] as int?,
      events: (j['events'] as List?)?.cast<Map<String, dynamic>>(),
      modelUsed: j['modelUsed'] as String?,
      cached: j['cached'] as bool?,
    );
  }
}



