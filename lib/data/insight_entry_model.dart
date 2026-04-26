class InsightEntry {
  final String id;
  final String userId;
  final String nodeId;
  final String nodeTitle;
  final String? nodeGlyph;
  final String bodyText;
  final DateTime entryDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InsightEntry({
    required this.id,
    required this.userId,
    required this.nodeId,
    required this.nodeTitle,
    required this.bodyText,
    required this.entryDate,
    required this.createdAt,
    required this.updatedAt,
    this.nodeGlyph,
  });

  factory InsightEntry.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic raw, DateTime fallback) {
      if (raw is String) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
      }
      return fallback;
    }

    final node = _extractNodeMap(json);
    final now = DateTime.now();

    return InsightEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      nodeId:
          _stringOrNull(json['node_slug']) ??
          _stringOrNull(node?['slug']) ??
          '',
      nodeTitle:
          _stringOrNull(json['node_title']) ??
          _stringOrNull(node?['title']) ??
          'Insight',
      nodeGlyph:
          _stringOrNull(json['node_glyph']) ?? _stringOrNull(node?['glyph']),
      bodyText: json['body_text'] as String? ?? '',
      entryDate: parseDate(json['entry_date'], now),
      createdAt: parseDate(json['created_at'], now),
      updatedAt: parseDate(json['updated_at'], now),
    );
  }

  InsightEntry copyWith({
    String? bodyText,
    DateTime? entryDate,
    DateTime? updatedAt,
  }) {
    return InsightEntry(
      id: id,
      userId: userId,
      nodeId: nodeId,
      nodeTitle: nodeTitle,
      nodeGlyph: nodeGlyph,
      bodyText: bodyText ?? this.bodyText,
      entryDate: entryDate ?? this.entryDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static Map<String, dynamic>? _extractNodeMap(Map<String, dynamic> json) {
    final raw = json['nodes'];
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  static String? _stringOrNull(dynamic value) {
    final text = value as String?;
    if (text == null) return null;
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
