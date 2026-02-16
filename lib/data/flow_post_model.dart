// lib/data/flow_post_model.dart

class FlowPost {
  final String id;
  final String userId;
  final int? sourceFlowId;
  final String name;
  final int color;
  final String? notes;
  final List<dynamic> rules;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isHidden;
  final Map<String, dynamic>? aiMetadata;
  final Map<String, dynamic>? payloadJson;
  final DateTime createdAt;

  FlowPost({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
    this.sourceFlowId,
    this.notes,
    required this.rules,
    this.startDate,
    this.endDate,
    this.isHidden = false,
    this.aiMetadata,
    this.payloadJson,
    required this.createdAt,
  });

  factory FlowPost.fromJson(Map<String, dynamic> json) {
    DateTime? _d(dynamic v) => v == null ? null : DateTime.parse(v as String);

    final rawRules = json['rules'];
    final rules = rawRules is List ? rawRules : <dynamic>[];

    return FlowPost(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sourceFlowId: (json['flow_id'] as num?)?.toInt(),
      name: json['name'] as String? ?? 'Untitled Flow',
      color: (json['color'] as num?)?.toInt() ?? 0,
      notes: json['notes'] as String?,
      rules: rules,
      startDate: _d(json['start_date']),
      endDate: _d(json['end_date']),
      isHidden: (json['is_hidden'] as bool?) ?? false,
      aiMetadata: json['ai_metadata'] != null
          ? Map<String, dynamic>.from(json['ai_metadata'] as Map)
          : null,
      payloadJson: _extractPayload(json),
      createdAt: _d(json['created_at']) ?? DateTime.now(),
    );
  }

  static Map<String, dynamic>? _extractPayload(Map<String, dynamic> json) {
    if (json['payload'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(json['payload'] as Map);
    }
    final ai = json['ai_metadata'];
    if (ai is Map && ai['payload'] is Map) {
      return Map<String, dynamic>.from(ai['payload'] as Map);
    }
    return null;
  }
}
