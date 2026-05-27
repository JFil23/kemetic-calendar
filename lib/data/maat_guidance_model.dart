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
  expired;

  static MaatGuidanceStatus fromDb(String? value) {
    for (final status in MaatGuidanceStatus.values) {
      if (status.name == value) return status;
    }
    return MaatGuidanceStatus.pending;
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
    );
  }

  bool get hasCta => ctaType != MaatGuidanceCtaType.none && ctaRef != null;

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

Map<String, dynamic> _jsonMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return const <String, dynamic>{};
}

String? _trimmed(Object? raw) {
  final text = raw?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _dateTime(Object? raw) {
  final text = _trimmed(raw);
  return text == null ? null : DateTime.tryParse(text);
}
