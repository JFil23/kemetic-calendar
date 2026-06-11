class DecanReflection {
  final String id;
  final String decanName;
  final String? decanTheme;
  final DateTime decanStart;
  final DateTime decanEnd;
  final int badgeCount;
  final String reflectionText;
  final DateTime createdAt;
  final DecanReflectionRenderMetadata? renderMetadata;

  DecanReflection({
    required this.id,
    required this.decanName,
    required this.decanTheme,
    required this.decanStart,
    required this.decanEnd,
    required this.badgeCount,
    required this.reflectionText,
    required this.createdAt,
    this.renderMetadata,
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
      renderMetadata: json['render_metadata'] is Map
          ? DecanReflectionRenderMetadata.fromGenerationJson(
              Map<String, dynamic>.from(json['render_metadata'] as Map),
            )
          : null,
    );
  }

  DecanReflection copyWith({DecanReflectionRenderMetadata? renderMetadata}) {
    return DecanReflection(
      id: id,
      decanName: decanName,
      decanTheme: decanTheme,
      decanStart: decanStart,
      decanEnd: decanEnd,
      badgeCount: badgeCount,
      reflectionText: reflectionText,
      createdAt: createdAt,
      renderMetadata: renderMetadata ?? this.renderMetadata,
    );
  }
}

class DecanReflectionRenderMetadata {
  const DecanReflectionRenderMetadata({
    required this.renderer,
    required this.usedLlm,
    required this.llmCost,
    required this.spectrumFlowKey,
    this.responseKind,
    this.selectedTier,
    this.selectedSeed,
    this.badgeTitle,
    this.badgeBody,
    this.detailBody,
    this.centralTension,
    this.anthropicAttempted,
    this.raw = const <String, dynamic>{},
  });

  final String? renderer;
  final bool? usedLlm;
  final num? llmCost;
  final String? spectrumFlowKey;
  final String? responseKind;
  final String? selectedTier;
  final String? selectedSeed;
  final String? badgeTitle;
  final String? badgeBody;
  final String? detailBody;
  final String? centralTension;
  final bool? anthropicAttempted;
  final Map<String, dynamic> raw;

  bool get isDeterministicSpectrum => renderer == 'deterministic_spectrum';

  bool get isTheWeighingSpectrum =>
      isDeterministicSpectrum && spectrumFlowKey == 'the-weighing';

  factory DecanReflectionRenderMetadata.fromResponseJson(
    Map<String, dynamic> json,
  ) {
    final outputControl = _asStringKeyedMap(
      json['outputControl'] ?? json['output_control'],
    );
    return _fromMaps(root: json, outputControl: outputControl, raw: json);
  }

  factory DecanReflectionRenderMetadata.fromGenerationJson(
    Map<String, dynamic> json,
  ) {
    final metadata = _asStringKeyedMap(json['metadata']);
    final sourceSnapshot = _asStringKeyedMap(json['source_snapshot']);
    final metadataOutputControl = _asStringKeyedMap(metadata['output_control']);
    final sourceOutputControl = _asStringKeyedMap(
      sourceSnapshot['output_control'],
    );
    final outputControl = metadataOutputControl.isNotEmpty
        ? metadataOutputControl
        : sourceOutputControl;
    return _fromMaps(
      root: metadata.isNotEmpty ? metadata : sourceSnapshot,
      outputControl: outputControl,
      raw: json,
    );
  }

  static DecanReflectionRenderMetadata? maybeFromGenerationJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null || json.isEmpty) return null;
    final metadata = DecanReflectionRenderMetadata.fromGenerationJson(json);
    if (metadata.renderer == null &&
        metadata.usedLlm == null &&
        metadata.spectrumFlowKey == null &&
        metadata.badgeBody == null &&
        metadata.detailBody == null) {
      return null;
    }
    return metadata;
  }

  static DecanReflectionRenderMetadata _fromMaps({
    required Map<String, dynamic> root,
    required Map<String, dynamic> outputControl,
    required Map<String, dynamic> raw,
  }) {
    final rendererBlock = _asStringKeyedMap(outputControl['renderer']);
    final deterministicResponse = _asStringKeyedMap(
      rendererBlock['deterministic_response'] ??
          rendererBlock['deterministicResponse'],
    );
    final selectedSeed = _asStringKeyedMap(
      deterministicResponse['selectedSeed'] ??
          deterministicResponse['selected_seed'],
    );
    return DecanReflectionRenderMetadata(
      renderer:
          _trimmedString(root['renderer']) ??
          _trimmedString(rendererBlock['renderer']),
      usedLlm:
          _boolFrom(root['used_llm']) ?? _boolFrom(rendererBlock['used_llm']),
      llmCost:
          _numFrom(root['llm_cost']) ?? _numFrom(rendererBlock['llm_cost']),
      spectrumFlowKey:
          _trimmedString(root['spectrum_flow_key']) ??
          _trimmedString(rendererBlock['spectrum_flow_key']),
      responseKind:
          _trimmedString(root['response_kind']) ??
          _trimmedString(rendererBlock['response_kind']) ??
          _trimmedString(deterministicResponse['responseKind']) ??
          _trimmedString(deterministicResponse['response_kind']),
      selectedTier:
          _trimmedString(root['selected_tier']) ??
          _trimmedString(rendererBlock['selected_tier']) ??
          _trimmedString(selectedSeed['tier']),
      selectedSeed:
          _trimmedString(root['selected_seed']) ??
          _trimmedString(rendererBlock['selected_seed']) ??
          _trimmedString(selectedSeed['seed']),
      badgeTitle:
          _trimmedString(root['badge_title']) ??
          _trimmedString(rendererBlock['badge_title']) ??
          _trimmedString(deterministicResponse['badgeTitle']) ??
          _trimmedString(deterministicResponse['badge_title']),
      badgeBody:
          _trimmedString(root['badge_body']) ??
          _trimmedString(rendererBlock['badge_body']) ??
          _trimmedString(deterministicResponse['badgeBody']) ??
          _trimmedString(deterministicResponse['badge_body']),
      detailBody:
          _trimmedString(root['detail_body']) ??
          _trimmedString(rendererBlock['detail_body']) ??
          _trimmedString(deterministicResponse['detailBody']) ??
          _trimmedString(deterministicResponse['detail_body']) ??
          _trimmedString(deterministicResponse['body']),
      centralTension:
          _trimmedString(root['central_tension']) ??
          _trimmedString(rendererBlock['central_tension']) ??
          _trimmedString(deterministicResponse['centralTension']) ??
          _trimmedString(deterministicResponse['central_tension']),
      anthropicAttempted: _boolFrom(rendererBlock['anthropic_attempted']),
      raw: raw,
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

bool? _boolFrom(Object? value) {
  if (value is bool) return value;
  final text = value?.toString().trim().toLowerCase();
  if (text == 'true') return true;
  if (text == 'false') return false;
  return null;
}

num? _numFrom(Object? value) {
  if (value is num) return value;
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return num.tryParse(text);
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
