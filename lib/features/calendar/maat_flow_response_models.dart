import 'package:mobile/core/completion_status.dart';

enum MaatFlowResponseSurface { initialDetail, calendarSheet, both }

extension MaatFlowResponseSurfaceX on MaatFlowResponseSurface {
  String get wireName {
    switch (this) {
      case MaatFlowResponseSurface.initialDetail:
        return 'initial_detail';
      case MaatFlowResponseSurface.calendarSheet:
        return 'calendar_sheet';
      case MaatFlowResponseSurface.both:
        return 'both';
    }
  }

  bool includes(MaatFlowResponseSurface requested) {
    return this == MaatFlowResponseSurface.both || this == requested;
  }

  static MaatFlowResponseSurface fromWireName(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'initial_detail':
      case 'initial':
      case 'detail':
        return MaatFlowResponseSurface.initialDetail;
      case 'calendar_sheet':
      case 'calendar':
      case 'sheet':
        return MaatFlowResponseSurface.calendarSheet;
      case 'both':
        return MaatFlowResponseSurface.both;
      default:
        return MaatFlowResponseSurface.calendarSheet;
    }
  }
}

enum MaatFlowResponseKind {
  text,
  multiline,
  choice,
  chips,
  checkbox,
  statusNote,
}

extension MaatFlowResponseKindX on MaatFlowResponseKind {
  String get wireName {
    switch (this) {
      case MaatFlowResponseKind.text:
        return 'text';
      case MaatFlowResponseKind.multiline:
        return 'multiline';
      case MaatFlowResponseKind.choice:
        return 'choice';
      case MaatFlowResponseKind.chips:
        return 'chips';
      case MaatFlowResponseKind.checkbox:
        return 'checkbox';
      case MaatFlowResponseKind.statusNote:
        return 'status_note';
    }
  }

  static MaatFlowResponseKind fromWireName(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'multiline':
      case 'multi_line':
      case 'long_text':
        return MaatFlowResponseKind.multiline;
      case 'choice':
      case 'select':
        return MaatFlowResponseKind.choice;
      case 'chips':
      case 'multi_select':
        return MaatFlowResponseKind.chips;
      case 'checkbox':
      case 'check':
        return MaatFlowResponseKind.checkbox;
      case 'status_note':
      case 'status-note':
        return MaatFlowResponseKind.statusNote;
      case 'text':
      default:
        return MaatFlowResponseKind.text;
    }
  }
}

enum MaatFlowJournalPolicy { mirror, offer, redactedSummary, localOnly }

extension MaatFlowJournalPolicyX on MaatFlowJournalPolicy {
  String get wireName {
    switch (this) {
      case MaatFlowJournalPolicy.mirror:
        return 'mirror';
      case MaatFlowJournalPolicy.offer:
        return 'offer';
      case MaatFlowJournalPolicy.redactedSummary:
        return 'redacted_summary';
      case MaatFlowJournalPolicy.localOnly:
        return 'local_only';
    }
  }

  bool get canProduceJournalBody {
    return this != MaatFlowJournalPolicy.localOnly;
  }

  bool get mirrorsByDefault {
    return this == MaatFlowJournalPolicy.mirror ||
        this == MaatFlowJournalPolicy.redactedSummary;
  }

  static MaatFlowJournalPolicy fromWireName(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'offer':
        return MaatFlowJournalPolicy.offer;
      case 'redacted_summary':
      case 'redacted-summary':
      case 'redacted':
        return MaatFlowJournalPolicy.redactedSummary;
      case 'local_only':
      case 'local-only':
      case 'local':
        return MaatFlowJournalPolicy.localOnly;
      case 'mirror':
      default:
        return MaatFlowJournalPolicy.mirror;
    }
  }
}

enum MaatFlowResponseJournalFormatter { standard, decanWatch }

extension MaatFlowResponseJournalFormatterX
    on MaatFlowResponseJournalFormatter {
  String get wireName {
    switch (this) {
      case MaatFlowResponseJournalFormatter.standard:
        return 'standard';
      case MaatFlowResponseJournalFormatter.decanWatch:
        return 'decan_watch';
    }
  }

  static MaatFlowResponseJournalFormatter fromWireName(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'decan_watch':
      case 'decan-watch':
        return MaatFlowResponseJournalFormatter.decanWatch;
      case 'standard':
      default:
        return MaatFlowResponseJournalFormatter.standard;
    }
  }
}

class MaatFlowResponseOption {
  const MaatFlowResponseOption({
    required this.id,
    required this.label,
    this.journalLabel,
  }) : assert(id.length > 0),
       assert(label.length > 0);

  final String id;
  final String label;
  final String? journalLabel;

  String get _displayLabel {
    final journal = journalLabel?.trim();
    if (journal != null && journal.isNotEmpty) return journal;
    return label.trim();
  }
}

class MaatFlowResponseSpec {
  const MaatFlowResponseSpec({
    required this.id,
    required this.flowKey,
    required this.surface,
    required this.kind,
    required this.label,
    this.eventKey,
    this.sittingKey,
    this.prompt,
    this.placeholder,
    this.options = const <MaatFlowResponseOption>[],
    this.requiredForObserved = false,
    this.journalPolicy = MaatFlowJournalPolicy.localOnly,
    this.journalLabel,
    this.journalGroupId,
    this.journalGroupLabel,
    this.journalFormatter = MaatFlowResponseJournalFormatter.standard,
    this.journalRole,
    this.redactedSummary,
    this.privacyClass = 'ordinary',
    this.ignoreEmptyValues = true,
    this.suppressJournalWhenSkipped = true,
  }) : assert(id.length > 0),
       assert(flowKey.length > 0),
       assert(label.length > 0);

  final String id;
  final String flowKey;
  final String? eventKey;
  final String? sittingKey;
  final MaatFlowResponseSurface surface;
  final MaatFlowResponseKind kind;
  final String label;
  final String? prompt;
  final String? placeholder;
  final List<MaatFlowResponseOption> options;
  final bool requiredForObserved;
  final MaatFlowJournalPolicy journalPolicy;
  final String? journalLabel;
  final String? journalGroupId;
  final String? journalGroupLabel;
  final MaatFlowResponseJournalFormatter journalFormatter;
  final String? journalRole;
  final String? redactedSummary;
  final String privacyClass;
  final bool ignoreEmptyValues;
  final bool suppressJournalWhenSkipped;

  bool supportsSurface(MaatFlowResponseSurface requested) {
    return surface.includes(requested);
  }

  String get journalHeading {
    final group = journalGroupLabel?.trim();
    if (group != null && group.isNotEmpty) return group;
    final explicit = journalLabel?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return label.trim();
  }

  String? get normalizedJournalGroupId {
    final group = journalGroupId?.trim();
    if (group == null || group.isEmpty) return null;
    return group;
  }

  String? get normalizedJournalRole {
    final role = journalRole?.trim();
    if (role == null || role.isEmpty) return null;
    return role;
  }

  String sourceId({
    String? clientEventId,
    DateTime? localDate,
    String? eventKeyOverride,
  }) {
    return buildMaatFlowResponseSourceId(
      flowKey: flowKey,
      responseSpecId: id,
      clientEventId: clientEventId,
      localDate: localDate,
      eventKey: eventKeyOverride ?? eventKey,
    );
  }

  MaatFlowResponseOption? optionById(String optionId) {
    final normalized = optionId.trim();
    for (final option in options) {
      if (option.id == normalized) return option;
    }
    return null;
  }
}

class MaatFlowResponseValue {
  const MaatFlowResponseValue({
    required this.specId,
    required this.kind,
    this.text,
    this.optionIds = const <String>[],
    this.checked,
  }) : assert(specId.length > 0);

  factory MaatFlowResponseValue.text({
    required String specId,
    required String text,
    bool multiline = false,
  }) {
    return MaatFlowResponseValue(
      specId: specId,
      kind: multiline
          ? MaatFlowResponseKind.multiline
          : MaatFlowResponseKind.text,
      text: text,
    );
  }

  factory MaatFlowResponseValue.choice({
    required String specId,
    required String optionId,
  }) {
    return MaatFlowResponseValue(
      specId: specId,
      kind: MaatFlowResponseKind.choice,
      optionIds: <String>[optionId],
    );
  }

  factory MaatFlowResponseValue.chips({
    required String specId,
    required List<String> optionIds,
  }) {
    return MaatFlowResponseValue(
      specId: specId,
      kind: MaatFlowResponseKind.chips,
      optionIds: optionIds,
    );
  }

  factory MaatFlowResponseValue.checkbox({
    required String specId,
    required bool checked,
  }) {
    return MaatFlowResponseValue(
      specId: specId,
      kind: MaatFlowResponseKind.checkbox,
      checked: checked,
    );
  }

  factory MaatFlowResponseValue.statusNote({
    required String specId,
    required String text,
  }) {
    return MaatFlowResponseValue(
      specId: specId,
      kind: MaatFlowResponseKind.statusNote,
      text: text,
    );
  }

  final String specId;
  final MaatFlowResponseKind kind;
  final String? text;
  final List<String> optionIds;
  final bool? checked;

  bool get isEmpty {
    switch (kind) {
      case MaatFlowResponseKind.text:
      case MaatFlowResponseKind.multiline:
      case MaatFlowResponseKind.statusNote:
        return (text ?? '').trim().isEmpty;
      case MaatFlowResponseKind.choice:
      case MaatFlowResponseKind.chips:
        return optionIds.where((id) => id.trim().isNotEmpty).isEmpty;
      case MaatFlowResponseKind.checkbox:
        return checked != true;
    }
  }

  String displayText(MaatFlowResponseSpec spec) {
    switch (kind) {
      case MaatFlowResponseKind.text:
      case MaatFlowResponseKind.multiline:
      case MaatFlowResponseKind.statusNote:
        return (text ?? '').trim();
      case MaatFlowResponseKind.choice:
        if (optionIds.isEmpty) return '';
        return _optionLabel(spec, optionIds.first);
      case MaatFlowResponseKind.chips:
        return optionIds
            .map((id) => _optionLabel(spec, id))
            .where((label) => label.isNotEmpty)
            .join(', ');
      case MaatFlowResponseKind.checkbox:
        return checked == true ? 'Yes' : '';
    }
  }

  String _optionLabel(MaatFlowResponseSpec spec, String optionId) {
    final normalized = optionId.trim();
    if (normalized.isEmpty) return '';
    return spec.optionById(normalized)?._displayLabel ?? normalized;
  }
}

class MaatFlowResponseJournalPreview {
  const MaatFlowResponseJournalPreview({
    required this.sourceId,
    required this.policy,
    required this.text,
  });

  final String sourceId;
  final MaatFlowJournalPolicy policy;
  final String text;

  bool get writesByDefault => policy.mirrorsByDefault;
  bool get requiresUserChoice => policy == MaatFlowJournalPolicy.offer;
}

MaatFlowResponseJournalPreview? buildMaatFlowResponseJournalPreview({
  required MaatFlowResponseSpec spec,
  required MaatFlowResponseValue value,
  CompletionStatus completionStatus = CompletionStatus.none,
  String? clientEventId,
  DateTime? localDate,
  String? sourceId,
}) {
  if (!spec.journalPolicy.canProduceJournalBody) return null;
  if (spec.ignoreEmptyValues && value.isEmpty) return null;
  if (spec.suppressJournalWhenSkipped &&
      completionStatus == CompletionStatus.skipped) {
    return null;
  }

  final bodyText = _formatResponseBodyText(spec, value);
  if (bodyText.trim().isEmpty) return null;

  return MaatFlowResponseJournalPreview(
    sourceId:
        sourceId ??
        spec.sourceId(clientEventId: clientEventId, localDate: localDate),
    policy: spec.journalPolicy,
    text: bodyText,
  );
}

List<MaatFlowResponseJournalPreview> buildMaatFlowResponseJournalPreviews({
  required List<MaatFlowResponseSpec> specs,
  required Map<String, MaatFlowResponseValue> values,
  CompletionStatus completionStatus = CompletionStatus.none,
  String? clientEventId,
  DateTime? localDate,
  String? eventKey,
  String Function(MaatFlowResponseSpec spec)? sourceIdForSpec,
  String Function(MaatFlowResponseSpec spec, String groupId)? sourceIdForGroup,
}) {
  if (specs.isEmpty || values.isEmpty) {
    return const <MaatFlowResponseJournalPreview>[];
  }

  final grouped = <String, List<MaatFlowResponseSpec>>{};
  for (final spec in specs) {
    final groupId = spec.normalizedJournalGroupId;
    if (groupId == null) continue;
    grouped.putIfAbsent(groupId, () => <MaatFlowResponseSpec>[]).add(spec);
  }

  final previews = <MaatFlowResponseJournalPreview>[];
  final seenGroups = <String>{};
  for (final spec in specs) {
    final groupId = spec.normalizedJournalGroupId;
    if (groupId == null) {
      final value = values[spec.id];
      if (value == null) continue;
      final preview = buildMaatFlowResponseJournalPreview(
        spec: spec,
        value: value,
        completionStatus: completionStatus,
        clientEventId: clientEventId,
        localDate: localDate,
        sourceId: sourceIdForSpec?.call(spec),
      );
      if (preview != null) previews.add(preview);
      continue;
    }

    if (!seenGroups.add(groupId)) continue;
    final groupSpecs = grouped[groupId] ?? const <MaatFlowResponseSpec>[];
    final preview = _buildGroupedMaatFlowResponseJournalPreview(
      groupId: groupId,
      specs: groupSpecs,
      values: values,
      completionStatus: completionStatus,
      clientEventId: clientEventId,
      localDate: localDate,
      eventKey: eventKey,
      sourceId: sourceIdForGroup?.call(spec, groupId),
    );
    if (preview != null) previews.add(preview);
  }
  return previews;
}

MaatFlowResponseJournalPreview? _buildGroupedMaatFlowResponseJournalPreview({
  required String groupId,
  required List<MaatFlowResponseSpec> specs,
  required Map<String, MaatFlowResponseValue> values,
  required CompletionStatus completionStatus,
  String? clientEventId,
  DateTime? localDate,
  String? eventKey,
  String? sourceId,
}) {
  if (specs.isEmpty) return null;
  final sourceSpec = specs.first;
  final policy = specs
      .map((spec) => spec.journalPolicy)
      .firstWhere(
        (policy) => policy.canProduceJournalBody,
        orElse: () => sourceSpec.journalPolicy,
      );
  if (!policy.canProduceJournalBody) return null;
  if (sourceSpec.suppressJournalWhenSkipped &&
      completionStatus == CompletionStatus.skipped) {
    return null;
  }

  final bodyText = _formatGroupedResponseBodyText(specs, values).trim();
  if (bodyText.isEmpty) return null;

  return MaatFlowResponseJournalPreview(
    sourceId:
        sourceId ??
        buildMaatFlowResponseSourceId(
          flowKey: sourceSpec.flowKey,
          responseSpecId: groupId,
          clientEventId: clientEventId,
          localDate: localDate,
          eventKey: eventKey ?? sourceSpec.eventKey,
        ),
    policy: policy,
    text: bodyText,
  );
}

String _formatResponseBodyText(
  MaatFlowResponseSpec spec,
  MaatFlowResponseValue value,
) {
  if (spec.journalPolicy == MaatFlowJournalPolicy.redactedSummary) {
    final summary = spec.redactedSummary?.trim();
    if (summary != null && summary.isNotEmpty) {
      return '${spec.journalHeading}: $summary';
    }
    return '${spec.journalHeading}: Response recorded.';
  }

  final display = value.displayText(spec).trim();
  if (display.isEmpty) return '';
  return '${spec.journalHeading}: $display';
}

String _formatGroupedResponseBodyText(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  if (specs.isEmpty) return '';
  final formatter = specs.first.journalFormatter;
  switch (formatter) {
    case MaatFlowResponseJournalFormatter.decanWatch:
      return _formatDecanWatchResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.standard:
      final fragments = <String>[];
      for (final spec in specs) {
        final value = values[spec.id];
        if (value == null || value.isEmpty) continue;
        final display = value.displayText(spec).trim();
        if (display.isNotEmpty) fragments.add(display);
      }
      if (fragments.isEmpty) return '';
      return '${specs.first.journalHeading}: ${fragments.join(' ')}';
  }
}

String _formatDecanWatchResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final visibilitySpec = byRole['visibility'];
  final skySpec = byRole['sky_note'];
  final bearingSpec = byRole['bearing'];
  final fragments = <String>[];

  if (visibilitySpec != null) {
    final value = values[visibilitySpec.id];
    final optionId = value?.optionIds
        .map((id) => id.trim().toLowerCase().replaceAll('-', '_'))
        .firstWhere((id) => id.isNotEmpty, orElse: () => '');
    switch (optionId) {
      case 'outside':
        fragments.add('I watched from outside.');
        break;
      case 'inside':
        fragments.add('I watched from inside.');
        break;
      case 'clouded':
        fragments.add('The sky was clouded.');
        break;
      case 'not_visible':
        fragments.add('The decan was not visible.');
        break;
    }
  }

  final sky = skySpec == null
      ? ''
      : _sentenceFragment(values[skySpec.id]?.displayText(skySpec));
  if (sky.isNotEmpty) {
    fragments.add('The sky showed $sky.');
  }

  final bearing = bearingSpec == null
      ? ''
      : _sentenceFragment(values[bearingSpec.id]?.displayText(bearingSpec));
  if (bearing.isNotEmpty) {
    fragments.add('I carry $bearing into the next ten days.');
  }

  if (fragments.isEmpty) return '';
  return '${specs.first.journalHeading}: ${fragments.join(' ')}';
}

String _sentenceFragment(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return '';
  return trimmed.replaceFirst(RegExp(r'[.!?]+$'), '').trim();
}

String buildMaatFlowResponseSourceId({
  required String flowKey,
  required String responseSpecId,
  String? clientEventId,
  DateTime? localDate,
  String? eventKey,
}) {
  final eventIdentity = _sourcePart(clientEventId);
  if (eventIdentity != null) {
    return 'maat_response:${_requiredSourcePart(flowKey)}:cid:$eventIdentity:${_requiredSourcePart(responseSpecId)}';
  }

  final dateIdentity = localDate == null
      ? null
      : '${localDate.year.toString().padLeft(4, '0')}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
  final eventKeyIdentity = _sourcePart(eventKey);
  if (dateIdentity != null || eventKeyIdentity != null) {
    return 'maat_response:${_requiredSourcePart(flowKey)}:${dateIdentity ?? 'undated'}:${eventKeyIdentity ?? 'event'}:${_requiredSourcePart(responseSpecId)}';
  }

  return 'maat_response:${_requiredSourcePart(flowKey)}:global:${_requiredSourcePart(responseSpecId)}';
}

String _requiredSourcePart(String value) {
  return _sourcePart(value) ?? 'unknown';
}

String? _sourcePart(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed.replaceAll(RegExp(r'\s+'), '-');
}
