enum MaatGuidanceKind {
  decanOpening,
  driftNudge,
  strengthNudge;

  static MaatGuidanceKind fromDb(String? value) {
    switch (value) {
      case 'drift_nudge':
        return MaatGuidanceKind.driftNudge;
      case 'strength_nudge':
        return MaatGuidanceKind.strengthNudge;
      case 'decan_opening':
      default:
        return MaatGuidanceKind.decanOpening;
    }
  }

  String get dbValue {
    switch (this) {
      case MaatGuidanceKind.decanOpening:
        return 'decan_opening';
      case MaatGuidanceKind.driftNudge:
        return 'drift_nudge';
      case MaatGuidanceKind.strengthNudge:
        return 'strength_nudge';
    }
  }

  String get title {
    switch (this) {
      case MaatGuidanceKind.decanOpening:
        return 'Decan Opening';
      case MaatGuidanceKind.driftNudge:
        return 'Ma’at Grounding';
      case MaatGuidanceKind.strengthNudge:
        return 'Ma’at Holding';
    }
  }
}

enum MaatGuidanceStatus {
  pending,
  shown,
  dismissed,
  opened,
  acted,
  expired,
  archiveOnly;

  static MaatGuidanceStatus fromDb(String? value) {
    if (value == 'archive_only') return MaatGuidanceStatus.archiveOnly;
    for (final status in MaatGuidanceStatus.values) {
      if (status.name == value) return status;
    }
    return MaatGuidanceStatus.pending;
  }

  String get dbValue {
    switch (this) {
      case MaatGuidanceStatus.archiveOnly:
        return 'archive_only';
      case MaatGuidanceStatus.pending:
      case MaatGuidanceStatus.shown:
      case MaatGuidanceStatus.dismissed:
      case MaatGuidanceStatus.opened:
      case MaatGuidanceStatus.acted:
      case MaatGuidanceStatus.expired:
        return name;
    }
  }
}

enum MaatGuidanceCtaType {
  none,
  node,
  flow,
  flowTemplate,
  flowPersonalized;

  static MaatGuidanceCtaType fromDb(String? value) {
    switch (value) {
      case 'node':
        return MaatGuidanceCtaType.node;
      case 'flow':
        return MaatGuidanceCtaType.flow;
      case 'flow_template':
        return MaatGuidanceCtaType.flowTemplate;
      case 'flow_personalized':
        return MaatGuidanceCtaType.flowPersonalized;
      case 'none':
      default:
        return MaatGuidanceCtaType.none;
    }
  }
}

class MaatGuidanceDelivery {
  const MaatGuidanceDelivery({
    required this.id,
    required this.kind,
    required this.decanPeriodKey,
    required this.status,
    required this.priority,
    required this.teaserText,
    required this.bodyText,
    required this.payload,
    required this.ctaType,
    required this.ctaRef,
    required this.triggerReason,
    required this.createdAt,
    this.renderMetadata,
  });

  final String id;
  final MaatGuidanceKind kind;
  final String decanPeriodKey;
  final MaatGuidanceStatus status;
  final int priority;
  final String teaserText;
  final String bodyText;
  final Map<String, dynamic> payload;
  final MaatGuidanceCtaType ctaType;
  final String? ctaRef;
  final String? triggerReason;
  final DateTime? createdAt;
  final MaatGuidanceRenderMetadata? renderMetadata;

  factory MaatGuidanceDelivery.fromJson(Map<String, dynamic> json) {
    final payload = _jsonMap(json['payload']);
    final compiledPackage = _jsonMap(payload['compiled_output_package']);
    final packageCta = _jsonMap(compiledPackage['cta']);
    return MaatGuidanceDelivery(
      id: (json['id'] as String?)?.trim() ?? '',
      kind: MaatGuidanceKind.fromDb(json['kind'] as String?),
      decanPeriodKey: (json['decan_period_key'] as String?)?.trim() ?? '',
      status: MaatGuidanceStatus.fromDb(json['status'] as String?),
      priority: (json['priority'] as num?)?.toInt() ?? 100,
      teaserText:
          _trimmed(compiledPackage['teaser_text']) ??
          _trimmed(json['teaser_text']) ??
          '',
      bodyText:
          _trimmed(compiledPackage['final_text']) ??
          _trimmed(json['body_text']) ??
          '',
      payload: payload,
      ctaType: MaatGuidanceCtaType.fromDb(
        _trimmed(json['cta_type']) ?? _trimmed(packageCta['type']),
      ),
      ctaRef: _trimmed(json['cta_ref']) ?? _trimmed(packageCta['ref']),
      triggerReason: _trimmed(json['trigger_reason']),
      createdAt: _dateTime(json['created_at']),
      renderMetadata: MaatGuidanceRenderMetadata.maybeFromPayload(payload),
    );
  }

  bool get hasCta => ctaType != MaatGuidanceCtaType.none && ctaRef != null;

  bool get isDeterministicWeighingOpeningOrientation =>
      kind == MaatGuidanceKind.decanOpening &&
      renderMetadata?.isTheWeighingOpeningOrientation == true;

  String get lowerThirdBadgeTitle {
    if (isDeterministicWeighingOpeningOrientation) {
      return renderMetadata?.badgeTitle ?? 'Orientation';
    }
    return kind.title;
  }

  String get lowerThirdBadgeText {
    if (isDeterministicWeighingOpeningOrientation) {
      return _trimmed(renderMetadata?.badgeBody) ?? displayTeaserText;
    }
    return displayTeaserText;
  }

  String get detailText {
    if (isDeterministicWeighingOpeningOrientation) {
      return _trimmed(renderMetadata?.detailBody) ??
          _trimmed(renderMetadata?.body) ??
          _trimmed(renderMetadata?.selectedSeed) ??
          bodyText;
    }
    return bodyText;
  }

  String get decanDisplayName {
    if (kind != MaatGuidanceKind.decanOpening) return '';
    return _trimmed(payload['decan_short_name']) ??
        _shortDecanName(_trimmed(payload['decan_display_name'])) ??
        _shortDecanName(_trimmed(payload['decan_label'])) ??
        '';
  }

  String get bannerTitle {
    final decanName = decanDisplayName;
    if (kind == MaatGuidanceKind.decanOpening && decanName.isNotEmpty) {
      return 'You are in $decanName';
    }
    return kind.title;
  }

  String get displayTeaserText {
    final decanName = decanDisplayName;
    if (kind != MaatGuidanceKind.decanOpening || decanName.isEmpty) {
      return teaserText;
    }
    return _replaceThisDecanReference(teaserText, decanName);
  }

  String get ctaLabel {
    switch (ctaType) {
      case MaatGuidanceCtaType.node:
        return kind == MaatGuidanceKind.decanOpening
            ? 'Read the guiding node'
            : 'Open Node';
      case MaatGuidanceCtaType.flow:
      case MaatGuidanceCtaType.flowTemplate:
        return 'Open suggested flow';
      case MaatGuidanceCtaType.flowPersonalized:
        return 'Create this flow';
      case MaatGuidanceCtaType.none:
        return '';
    }
  }
}

class MaatGuidanceRenderMetadata {
  const MaatGuidanceRenderMetadata({
    required this.renderer,
    required this.usedLlm,
    required this.llmCost,
    required this.spectrumFlowKey,
    required this.responseKind,
    required this.badgeRole,
    required this.preferredSurface,
    this.badgeTitle,
    this.badgeBody,
    this.detailBody,
    this.body,
    this.selectedSeed,
    this.raw = const <String, dynamic>{},
  });

  final String? renderer;
  final bool? usedLlm;
  final num? llmCost;
  final String? spectrumFlowKey;
  final String? responseKind;
  final String? badgeRole;
  final String? preferredSurface;
  final String? badgeTitle;
  final String? badgeBody;
  final String? detailBody;
  final String? body;
  final String? selectedSeed;
  final Map<String, dynamic> raw;

  bool get isDeterministicSpectrum => renderer == 'deterministic_spectrum';

  bool get isTheWeighingOpeningOrientation =>
      isDeterministicSpectrum &&
      usedLlm == false &&
      llmCost == 0 &&
      spectrumFlowKey == 'the-weighing' &&
      responseKind == 'orientation' &&
      badgeRole == 'opening_orientation' &&
      preferredSurface == 'lower_third_badge';

  static MaatGuidanceRenderMetadata? maybeFromPayload(
    Map<String, dynamic> payload,
  ) {
    if (payload.isEmpty) return null;
    final metadata = MaatGuidanceRenderMetadata.fromPayload(payload);
    if (metadata.renderer == null &&
        metadata.usedLlm == null &&
        metadata.spectrumFlowKey == null &&
        metadata.responseKind == null &&
        metadata.badgeBody == null &&
        metadata.body == null) {
      return null;
    }
    return metadata;
  }

  factory MaatGuidanceRenderMetadata.fromPayload(Map<String, dynamic> payload) {
    final response = _jsonMap(payload['maat_flow_response']);
    final renderer = _jsonMap(payload['maat_flow_response_renderer']);
    final outputControl = _jsonMap(payload['output_control']);
    final spectrumRender = _jsonMap(outputControl['spectrum_render']);
    final selectedSeed = _jsonMap(
      response['selectedSeed'] ?? response['selected_seed'],
    );

    return MaatGuidanceRenderMetadata(
      renderer:
          _trimmed(renderer['renderer']) ??
          _trimmed(response['source']) ??
          _trimmed(spectrumRender['source']),
      usedLlm:
          _boolFrom(renderer['used_llm']) ??
          _boolFrom(response['usedLlm']) ??
          _boolFrom(response['used_llm']) ??
          _boolFrom(spectrumRender['usedLlm']) ??
          _boolFrom(spectrumRender['used_llm']),
      llmCost: _numFrom(renderer['llm_cost']),
      spectrumFlowKey:
          _trimmed(renderer['spectrum_flow_key']) ??
          _trimmed(selectedSeed['flowKey']) ??
          _trimmed(selectedSeed['flow_key']),
      responseKind:
          _trimmed(renderer['response_kind']) ??
          _trimmed(response['responseKind']) ??
          _trimmed(response['response_kind']) ??
          _trimmed(spectrumRender['responseKind']) ??
          _trimmed(spectrumRender['response_kind']),
      badgeRole:
          _trimmed(renderer['badge_role']) ??
          _trimmed(selectedSeed['badgeRole']) ??
          _trimmed(selectedSeed['badge_role']),
      preferredSurface:
          _trimmed(renderer['preferred_surface']) ??
          _trimmed(selectedSeed['preferredSurface']) ??
          _trimmed(selectedSeed['preferred_surface']),
      badgeTitle:
          _trimmed(renderer['badge_title']) ??
          _trimmed(response['badgeTitle']) ??
          _trimmed(response['badge_title']) ??
          _trimmed(selectedSeed['badgeTitle']) ??
          _trimmed(selectedSeed['badge_title']),
      badgeBody:
          _trimmed(response['badgeBody']) ??
          _trimmed(response['badge_body']) ??
          _trimmed(selectedSeed['badgeBody']) ??
          _trimmed(selectedSeed['badge_body']),
      detailBody:
          _trimmed(response['detailBody']) ?? _trimmed(response['detail_body']),
      body: _trimmed(response['body']),
      selectedSeed:
          _trimmed(renderer['selected_seed']) ?? _trimmed(selectedSeed['seed']),
      raw: payload,
    );
  }
}

Map<String, dynamic> _jsonMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return const <String, dynamic>{};
}

String? _trimmed(Object? raw) {
  final text = raw?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String? _shortDecanName(String? value) {
  if (value == null) return null;
  final emDash = value.lastIndexOf('—');
  final withoutMonth = emDash >= 0 ? value.substring(emDash + 1).trim() : value;
  final withoutGloss = withoutMonth.replaceFirst(
    RegExp(r'\s*\([^)]*\)\s*$'),
    '',
  );
  final text = withoutGloss.trim();
  return text.isEmpty ? null : text;
}

String _replaceThisDecanReference(String text, String decanName) {
  return text.replaceFirst(RegExp(r'\b[Tt]his decan\b'), decanName);
}

DateTime? _dateTime(Object? raw) {
  final text = _trimmed(raw);
  return text == null ? null : DateTime.tryParse(text);
}

bool? _boolFrom(Object? raw) {
  if (raw is bool) return raw;
  final text = _trimmed(raw)?.toLowerCase();
  if (text == 'true') return true;
  if (text == 'false') return false;
  return null;
}

num? _numFrom(Object? raw) {
  if (raw is num) return raw;
  return num.tryParse(raw?.toString() ?? '');
}
