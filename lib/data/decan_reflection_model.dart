class DecanReflection {
  final String id;
  final String decanName;
  final String? decanTheme;
  final DateTime decanStart;
  final DateTime decanEnd;
  final int badgeCount;
  final String reflectionText;
  final DateTime createdAt;

  DecanReflection({
    required this.id,
    required this.decanName,
    required this.decanTheme,
    required this.decanStart,
    required this.decanEnd,
    required this.badgeCount,
    required this.reflectionText,
    required this.createdAt,
  });

  factory DecanReflection.fromJson(Map<String, dynamic> json) {
    return DecanReflection(
      id: json['id'] as String,
      decanName: json['decan_name'] as String? ?? '',
      decanTheme: json['decan_theme'] as String?,
      decanStart: DateTime.parse(json['decan_start'] as String),
      decanEnd: DateTime.parse(json['decan_end'] as String),
      badgeCount: json['badge_count'] as int? ?? 0,
      reflectionText: json['reflection_text'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class DecanReflectionGraphHints {
  final String? leadAxis;
  final List<String> anchorNodes;

  const DecanReflectionGraphHints({
    required this.leadAxis,
    required this.anchorNodes,
  });

  bool get isEmpty => leadAxis == null && anchorNodes.isEmpty;

  factory DecanReflectionGraphHints.fromGenerationJson(
    Map<String, dynamic> json,
  ) {
    final metadata = _asStringKeyedMap(json['metadata']);
    final decisionMatrix = _asStringKeyedMap(metadata['decision_matrix']);
    final rawAnchorNodes = json['anchor_nodes'];
    final fallbackAnchorNodes = decisionMatrix['anchor_nodes'];

    return DecanReflectionGraphHints(
      leadAxis: _trimmedString(metadata['lead_axis']) ??
          _trimmedString(decisionMatrix['lead_axis']),
      anchorNodes: _stringList(rawAnchorNodes).isNotEmpty
          ? _stringList(rawAnchorNodes)
          : _stringList(fallbackAnchorNodes),
    );
  }
}

Map<String, dynamic> _asStringKeyedMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

String? _trimmedString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  final seen = <String>{};
  final result = <String>[];
  for (final raw in value) {
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) continue;
    final key = text.toLowerCase();
    if (seen.contains(key)) continue;
    seen.add(key);
    result.add(text);
  }
  return result;
}
