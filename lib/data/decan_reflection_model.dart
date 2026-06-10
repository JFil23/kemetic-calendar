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
  final DecanReflectionCta? cta;
  final DecanReflectionNodeSuggestion? fallbackNode;
  final DecanReflectionNodeSuggestion? canonicalNode;

  const DecanReflectionGraphHints({
    required this.leadAxis,
    required this.anchorNodes,
    this.cta,
    this.fallbackNode,
    this.canonicalNode,
  });

  bool get isEmpty =>
      leadAxis == null &&
      anchorNodes.isEmpty &&
      cta == null &&
      fallbackNode == null &&
      canonicalNode == null;

  factory DecanReflectionGraphHints.fromGenerationJson(
    Map<String, dynamic> json,
  ) {
    final metadata = _asStringKeyedMap(json['metadata']);
    final sourceSnapshot = _asStringKeyedMap(json['source_snapshot']);
    final decisionMatrix = _asStringKeyedMap(metadata['decision_matrix']);
    final metadataOutputControl = _asStringKeyedMap(metadata['output_control']);
    final sourceOutputControl = _asStringKeyedMap(
      sourceSnapshot['output_control'],
    );
    final package = _firstMap([
      metadataOutputControl['compiled_output_package'],
      sourceOutputControl['compiled_output_package'],
    ]);
    final rawAnchorNodes = json['anchor_nodes'];
    final fallbackAnchorNodes = decisionMatrix['anchor_nodes'];
    final cta = DecanReflectionCta.fromGenerationJson(json);

    return DecanReflectionGraphHints(
      leadAxis:
          _trimmedString(metadata['lead_axis']) ??
          _trimmedString(decisionMatrix['lead_axis']),
      anchorNodes: _stringList(rawAnchorNodes).isNotEmpty
          ? _stringList(rawAnchorNodes)
          : _stringList(fallbackAnchorNodes),
      cta: cta.hasDestination ? cta : null,
      fallbackNode: DecanReflectionNodeSuggestion.tryFromCtaFallback(cta),
      canonicalNode: DecanReflectionNodeSuggestion.tryFromCanonicalMaps([
        package,
        metadataOutputControl,
        sourceOutputControl,
      ]),
    );
  }
}

class DecanReflectionNodeSuggestion {
  final String ref;
  final String label;

  const DecanReflectionNodeSuggestion({required this.ref, required this.label});

  static DecanReflectionNodeSuggestion? tryFromCtaFallback(
    DecanReflectionCta cta,
  ) {
    final fallbackType = cta.fallbackType?.trim().toLowerCase();
    final fallbackRef = cta.fallbackRef?.trim();
    if (!_isNodeCtaType(fallbackType) ||
        fallbackRef == null ||
        fallbackRef.isEmpty) {
      return null;
    }
    return DecanReflectionNodeSuggestion(
      ref: fallbackRef,
      label: cta.fallbackLabel?.trim().isNotEmpty == true
          ? cta.fallbackLabel!.trim()
          : _defaultCtaLabel('node'),
    );
  }

  static DecanReflectionNodeSuggestion? tryFromCanonicalMaps(
    Iterable<Map<String, dynamic>> maps,
  ) {
    for (final map in maps) {
      final ref = _trimmedString(map['node_ref']);
      if (ref == null) continue;
      return DecanReflectionNodeSuggestion(
        ref: ref,
        label: _trimmedString(map['node_title']) ?? _defaultCtaLabel('node'),
      );
    }
    return null;
  }

  bool get hasNode => ref.trim().isNotEmpty;
}

class DecanReflectionCta {
  final String type;
  final String ref;
  final String label;
  final String? fallbackType;
  final String? fallbackRef;
  final String? fallbackLabel;

  const DecanReflectionCta({
    required this.type,
    required this.ref,
    required this.label,
    this.fallbackType,
    this.fallbackRef,
    this.fallbackLabel,
  });

  factory DecanReflectionCta.fromGenerationJson(Map<String, dynamic> json) {
    final metadata = _asStringKeyedMap(json['metadata']);
    final sourceSnapshot = _asStringKeyedMap(json['source_snapshot']);
    final metadataOutputControl = _asStringKeyedMap(metadata['output_control']);
    final sourceOutputControl = _asStringKeyedMap(
      sourceSnapshot['output_control'],
    );
    final package = _firstMap([
      metadataOutputControl['compiled_output_package'],
      sourceOutputControl['compiled_output_package'],
    ]);
    final destination = _firstMap([
      package['destination'],
      metadataOutputControl['reflection_destination'],
      sourceOutputControl['reflection_destination'],
    ]);
    final cta = _asStringKeyedMap(package['cta']);
    final type =
        _trimmedString(destination['type']) ??
        _trimmedString(cta['type']) ??
        _trimmedString(package['cta_type']);
    final ref =
        _trimmedString(destination['ref']) ??
        _trimmedString(cta['ref']) ??
        _trimmedString(package['cta_ref']);
    if (type == null || ref == null || type == 'none') {
      return const DecanReflectionCta(type: 'none', ref: '', label: '');
    }
    final fallback = _asStringKeyedMap(destination['fallback']);
    return DecanReflectionCta(
      type: type,
      ref: ref,
      label:
          _trimmedString(destination['label']) ??
          _trimmedString(cta['label']) ??
          _defaultCtaLabel(type),
      fallbackType:
          _trimmedString(fallback['ctaType']) ??
          _trimmedString(fallback['cta_type']),
      fallbackRef:
          _trimmedString(fallback['ctaRef']) ??
          _trimmedString(fallback['cta_ref']),
      fallbackLabel:
          _trimmedString(fallback['ctaLabel']) ??
          _trimmedString(fallback['cta_label']),
    );
  }

  bool get hasDestination => type != 'none' && ref.trim().isNotEmpty;
}

bool _isNodeCtaType(String? type) {
  switch (type) {
    case 'node':
    case 'library_node':
    case 'node_library':
      return true;
    default:
      return false;
  }
}

Map<String, dynamic> _asStringKeyedMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

Map<String, dynamic> _firstMap(Iterable<Object?> values) {
  for (final value in values) {
    final map = _asStringKeyedMap(value);
    if (map.isNotEmpty) return map;
  }
  return const <String, dynamic>{};
}

String _defaultCtaLabel(String type) {
  switch (type) {
    case 'node':
      return 'Read the guiding node';
    case 'flow':
    case 'flow_template':
      return 'Open suggested flow';
    case 'flow_personalized':
      return 'Create this flow';
    default:
      return '';
  }
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
