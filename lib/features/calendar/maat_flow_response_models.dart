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

enum MaatFlowResponseJournalFormatter {
  standard,
  decanWatch,
  dawnHouseRite,
  closingRelease,
  offeringTable,
  daysOutsideReceipt,
  wepRonpetOpening,
  openHandProvision,
  djedRestoration,
  tendingCare,
  keptWordAgreement,
  wagMemory,
  khatBodyCare,
  oracleSign,
  wanderingRemainder,
}

extension MaatFlowResponseJournalFormatterX
    on MaatFlowResponseJournalFormatter {
  String get wireName {
    switch (this) {
      case MaatFlowResponseJournalFormatter.standard:
        return 'standard';
      case MaatFlowResponseJournalFormatter.decanWatch:
        return 'decan_watch';
      case MaatFlowResponseJournalFormatter.dawnHouseRite:
        return 'dawn_house_rite';
      case MaatFlowResponseJournalFormatter.closingRelease:
        return 'closing_release';
      case MaatFlowResponseJournalFormatter.offeringTable:
        return 'offering_table';
      case MaatFlowResponseJournalFormatter.daysOutsideReceipt:
        return 'days_outside_receipt';
      case MaatFlowResponseJournalFormatter.wepRonpetOpening:
        return 'wep_ronpet_opening';
      case MaatFlowResponseJournalFormatter.openHandProvision:
        return 'open_hand_provision';
      case MaatFlowResponseJournalFormatter.djedRestoration:
        return 'djed_restoration';
      case MaatFlowResponseJournalFormatter.tendingCare:
        return 'tending_care';
      case MaatFlowResponseJournalFormatter.keptWordAgreement:
        return 'kept_word_agreement';
      case MaatFlowResponseJournalFormatter.wagMemory:
        return 'wag_memory';
      case MaatFlowResponseJournalFormatter.khatBodyCare:
        return 'khat_body_care';
      case MaatFlowResponseJournalFormatter.oracleSign:
        return 'oracle_sign';
      case MaatFlowResponseJournalFormatter.wanderingRemainder:
        return 'wandering_remainder';
    }
  }

  static MaatFlowResponseJournalFormatter fromWireName(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'decan_watch':
      case 'decan-watch':
        return MaatFlowResponseJournalFormatter.decanWatch;
      case 'dawn_house_rite':
      case 'dawn-house-rite':
        return MaatFlowResponseJournalFormatter.dawnHouseRite;
      case 'closing_release':
      case 'closing-release':
        return MaatFlowResponseJournalFormatter.closingRelease;
      case 'offering_table':
      case 'offering-table':
        return MaatFlowResponseJournalFormatter.offeringTable;
      case 'days_outside_receipt':
      case 'days-outside-receipt':
        return MaatFlowResponseJournalFormatter.daysOutsideReceipt;
      case 'wep_ronpet_opening':
      case 'wep-ronpet-opening':
        return MaatFlowResponseJournalFormatter.wepRonpetOpening;
      case 'open_hand_provision':
      case 'open-hand-provision':
        return MaatFlowResponseJournalFormatter.openHandProvision;
      case 'djed_restoration':
      case 'djed-restoration':
        return MaatFlowResponseJournalFormatter.djedRestoration;
      case 'tending_care':
      case 'tending-care':
        return MaatFlowResponseJournalFormatter.tendingCare;
      case 'kept_word_agreement':
      case 'kept-word-agreement':
        return MaatFlowResponseJournalFormatter.keptWordAgreement;
      case 'wag_memory':
      case 'wag-memory':
        return MaatFlowResponseJournalFormatter.wagMemory;
      case 'khat_body_care':
      case 'khat-body-care':
        return MaatFlowResponseJournalFormatter.khatBodyCare;
      case 'oracle_sign':
      case 'oracle-sign':
        return MaatFlowResponseJournalFormatter.oracleSign;
      case 'wandering_remainder':
      case 'wandering-remainder':
        return MaatFlowResponseJournalFormatter.wanderingRemainder;
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
    this.offerJournalInclusionDefault = true,
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
  final bool offerJournalInclusionDefault;
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
    required this.includeInJournalByDefault,
  });

  final String sourceId;
  final MaatFlowJournalPolicy policy;
  final String text;
  final bool includeInJournalByDefault;

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
    includeInJournalByDefault: spec.journalPolicy == MaatFlowJournalPolicy.offer
        ? spec.offerJournalInclusionDefault
        : spec.journalPolicy.mirrorsByDefault,
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

  if (policy == MaatFlowJournalPolicy.redactedSummary) {
    final redactedText = _formatRedactedResponseBodyText(sourceSpec).trim();
    if (redactedText.isEmpty) return null;
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
      text: redactedText,
      includeInJournalByDefault: policy.mirrorsByDefault,
    );
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
    includeInJournalByDefault: policy == MaatFlowJournalPolicy.offer
        ? sourceSpec.offerJournalInclusionDefault
        : policy.mirrorsByDefault,
  );
}

String _formatResponseBodyText(
  MaatFlowResponseSpec spec,
  MaatFlowResponseValue value,
) {
  if (spec.journalPolicy == MaatFlowJournalPolicy.redactedSummary) {
    return _formatRedactedResponseBodyText(spec);
  }

  final display = value.displayText(spec).trim();
  if (display.isEmpty) return '';
  switch (spec.journalFormatter) {
    case MaatFlowResponseJournalFormatter.dawnHouseRite:
      return '${spec.journalHeading}: I brought order by ${_sentenceFragment(display)}.';
    case MaatFlowResponseJournalFormatter.closingRelease:
      return '${spec.journalHeading}: I release ${_sentenceFragment(display)}.';
    case MaatFlowResponseJournalFormatter.offeringTable:
      return '${spec.journalHeading}: I provided ${_sentenceFragment(display)}.';
    case MaatFlowResponseJournalFormatter.daysOutsideReceipt:
      return '${spec.journalHeading}: I carry the receipt that ${_sentenceFragment(display)}.';
    case MaatFlowResponseJournalFormatter.wepRonpetOpening:
      return '${spec.journalHeading}: I open the year with ${_sentenceFragment(display)}.';
    case MaatFlowResponseJournalFormatter.openHandProvision:
      return '${spec.journalHeading}: I gave ${_sentenceFragment(display)}.';
    case MaatFlowResponseJournalFormatter.djedRestoration:
      return '${spec.journalHeading}: I restored ${_sentenceFragment(display)} and stood it upright again.';
    case MaatFlowResponseJournalFormatter.tendingCare:
      return '${spec.journalHeading}: I made care specific through ${_sentenceFragment(display)}.';
    case MaatFlowResponseJournalFormatter.keptWordAgreement:
      return '${spec.journalHeading}: I brought one agreement back into clearer order: ${_sentenceFragment(display)}.';
    case MaatFlowResponseJournalFormatter.wagMemory:
      return '${spec.journalHeading}: I kept the table and carried ${_sentenceFragment(display)} forward.';
    case MaatFlowResponseJournalFormatter.khatBodyCare:
      return '${spec.journalHeading}: I listened to the body and answered with ${_sentenceFragment(display)}.';
    case MaatFlowResponseJournalFormatter.oracleSign:
      return '${spec.journalHeading}: I received one sign and will test it through grounded action.';
    case MaatFlowResponseJournalFormatter.wanderingRemainder:
      return '${spec.journalHeading}: I honored what was lost and noticed one thing that remains.';
    case MaatFlowResponseJournalFormatter.decanWatch:
    case MaatFlowResponseJournalFormatter.standard:
      return '${spec.journalHeading}: $display';
  }
}

String _formatRedactedResponseBodyText(MaatFlowResponseSpec spec) {
  final summary = spec.redactedSummary?.trim();
  if (summary != null && summary.isNotEmpty) {
    return '${spec.journalHeading}: $summary';
  }
  return '${spec.journalHeading}: Response recorded.';
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
    case MaatFlowResponseJournalFormatter.offeringTable:
      return _formatOfferingTableResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.openHandProvision:
      return _formatOpenHandResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.djedRestoration:
      return _formatDjedResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.tendingCare:
      return _formatTendingResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.keptWordAgreement:
      return _formatKeptWordResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.wagMemory:
      return _formatWagResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.khatBodyCare:
      return _formatKhatResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.oracleSign:
      return _formatOracleResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.wanderingRemainder:
      return _formatWanderingResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.dawnHouseRite:
    case MaatFlowResponseJournalFormatter.closingRelease:
    case MaatFlowResponseJournalFormatter.daysOutsideReceipt:
    case MaatFlowResponseJournalFormatter.wepRonpetOpening:
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

String _formatOfferingTableResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final fedSpec = byRole['fed'];
  final providedSpec = byRole['provided'];
  final fed = fedSpec == null
      ? ''
      : _joinNatural(
          values[fedSpec.id]?.optionIds
                  .map((id) => fedSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final provided = providedSpec == null
      ? ''
      : _sentenceFragment(values[providedSpec.id]?.displayText(providedSpec));

  if (fed.isNotEmpty && provided.isNotEmpty) {
    return '${specs.first.journalHeading}: I fed $fed by $provided.';
  }
  if (fed.isNotEmpty) {
    return '${specs.first.journalHeading}: I provided $fed today.';
  }
  if (provided.isNotEmpty) {
    return '${specs.first.journalHeading}: I provided $provided.';
  }
  return '';
}

String _formatOpenHandResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final givenSpec = byRole['given'];
  final movedSpec = byRole['moved'];
  final given = givenSpec == null
      ? ''
      : _joinNatural(
          values[givenSpec.id]?.optionIds
                  .map((id) => givenSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final moved = movedSpec == null
      ? ''
      : _sentenceFragment(values[movedSpec.id]?.displayText(movedSpec));

  if (given.isNotEmpty && moved.isNotEmpty) {
    return '${specs.first.journalHeading}: I gave $given ${_provisionPhrase(moved)}.';
  }
  if (given.isNotEmpty) {
    return '${specs.first.journalHeading}: I gave $given where need was visible.';
  }
  if (moved.isNotEmpty) {
    return '${specs.first.journalHeading}: I gave $moved.';
  }
  return '';
}

String _formatDjedResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final stoodSpec = byRole['stood'];
  final restoredSpec = byRole['restored'];
  final stood = stoodSpec == null
      ? ''
      : _joinNatural(
          values[stoodSpec.id]?.optionIds
                  .map((id) => stoodSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final restored = restoredSpec == null
      ? ''
      : _sentenceFragment(values[restoredSpec.id]?.displayText(restoredSpec));

  if (stood.isNotEmpty && restored.isNotEmpty) {
    return '${specs.first.journalHeading}: I restored $stood by ${_restorationActionPhrase(restored)} and stood it upright again.';
  }
  if (stood.isNotEmpty) {
    return '${specs.first.journalHeading}: I restored $stood and stood it upright again.';
  }
  if (restored.isNotEmpty) {
    return '${specs.first.journalHeading}: I restored $restored and stood it upright again.';
  }
  return '';
}

String _formatTendingResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final careSpec = byRole['care'];
  final actSpec = byRole['act'];
  final care = careSpec == null
      ? ''
      : _joinNatural(
          values[careSpec.id]?.optionIds
                  .map((id) => careSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final act = actSpec == null
      ? ''
      : _sentenceFragment(values[actSpec.id]?.displayText(actSpec));

  if (care.isNotEmpty && act.isNotEmpty) {
    return '${specs.first.journalHeading}: I made care specific through $care and completed $act.';
  }
  if (care.isNotEmpty) {
    return '${specs.first.journalHeading}: I made care specific through $care today.';
  }
  if (act.isNotEmpty) {
    return '${specs.first.journalHeading}: I made care specific today and completed $act.';
  }
  return '';
}

String _formatKeptWordResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final statusSpec = byRole['status'];
  final rememberedSpec = byRole['remembered'];
  final status = statusSpec == null
      ? ''
      : _firstNonEmpty(
          values[statusSpec.id]?.optionIds.map(
                (id) => statusSpec.optionById(id)?._displayLabel ?? id,
              ) ??
              const Iterable<String>.empty(),
        ).toLowerCase();
  final remembered = rememberedSpec == null
      ? ''
      : _sentenceFragment(
          values[rememberedSpec.id]?.displayText(rememberedSpec),
        );

  if (status.isNotEmpty && remembered.isNotEmpty) {
    return '${specs.first.journalHeading}: I brought one agreement back into clearer order; the word is $status, and I remember $remembered.';
  }
  if (status.isNotEmpty) {
    return '${specs.first.journalHeading}: I brought one agreement back into clearer order; the word is $status.';
  }
  if (remembered.isNotEmpty) {
    return '${specs.first.journalHeading}: I brought one agreement back into clearer order: $remembered.';
  }
  return '';
}

String _formatWagResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final rememberedSpec = byRole['remembered'];
  final carriedSpec = byRole['carried'];
  final remembered = rememberedSpec == null
      ? ''
      : _joinNatural(
          values[rememberedSpec.id]?.optionIds
                  .map(
                    (id) => rememberedSpec.optionById(id)?._displayLabel ?? id,
                  )
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final carried = carriedSpec == null
      ? ''
      : _sentenceFragment(values[carriedSpec.id]?.displayText(carriedSpec));

  if (remembered.isNotEmpty && carried.isNotEmpty) {
    return '${specs.first.journalHeading}: I kept $remembered at the table and carried $carried forward.';
  }
  if (remembered.isNotEmpty) {
    return '${specs.first.journalHeading}: I kept $remembered at the table and carried one remembered gift forward.';
  }
  if (carried.isNotEmpty) {
    return '${specs.first.journalHeading}: I kept the table and carried $carried forward.';
  }
  return '';
}

String _formatKhatResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final askedSpec = byRole['asked'];
  final careSpec = byRole['care'];
  final asked = askedSpec == null
      ? ''
      : _joinNatural(
          values[askedSpec.id]?.optionIds
                  .map((id) => askedSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final care = careSpec == null
      ? ''
      : _sentenceFragment(values[careSpec.id]?.displayText(careSpec));

  if (asked.isNotEmpty && care.isNotEmpty) {
    return '${specs.first.journalHeading}: I listened to the body asking for $asked and answered with $care.';
  }
  if (asked.isNotEmpty) {
    return '${specs.first.journalHeading}: I listened to the body asking for $asked and answered with one act of care.';
  }
  if (care.isNotEmpty) {
    return '${specs.first.journalHeading}: I listened to the body and answered with $care.';
  }
  return '';
}

String _formatOracleResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final signSpec = byRole['sign'];
  final receivedSpec = byRole['received'];
  final signs = signSpec == null
      ? ''
      : _joinNatural(
          values[signSpec.id]?.optionIds
                  .map((id) => signSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final received = receivedSpec == null
      ? ''
      : _sentenceFragment(values[receivedSpec.id]?.displayText(receivedSpec));

  if (signs.isNotEmpty) {
    return '${specs.first.journalHeading}: I received one sign through $signs and will test it through grounded action.';
  }
  if (received.isNotEmpty) {
    return '${specs.first.journalHeading}: I received one sign and will test it through grounded action.';
  }
  return '';
}

String _formatWanderingResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final remainsSpec = byRole['remains'];
  final foundSpec = byRole['found'];
  final remains = remainsSpec == null
      ? ''
      : _joinNatural(
          values[remainsSpec.id]?.optionIds
                  .map((id) => remainsSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final found = foundSpec == null
      ? ''
      : _sentenceFragment(values[foundSpec.id]?.displayText(foundSpec));

  if (remains.isNotEmpty) {
    return '${specs.first.journalHeading}: I honored $remains and noticed one thing that remains.';
  }
  if (found.isNotEmpty) {
    return '${specs.first.journalHeading}: I honored what was lost and noticed one thing that remains.';
  }
  return '';
}

String _firstNonEmpty(Iterable<String> values) {
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
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

String _provisionPhrase(String value) {
  final trimmed = _sentenceFragment(value);
  if (trimmed.isEmpty) return '';
  final lower = trimmed.toLowerCase();
  const directStarts = <String>[
    'where ',
    'when ',
    'to ',
    'for ',
    'as ',
    'after ',
    'before ',
    'without ',
    'because ',
    'while ',
    'through ',
  ];
  if (directStarts.any((prefix) => lower.startsWith(prefix))) return trimmed;
  return 'by $trimmed';
}

String _restorationActionPhrase(String value) {
  final trimmed = _sentenceFragment(value);
  if (trimmed.isEmpty) return '';
  final lower = trimmed.toLowerCase();
  const actionStarts = <String>[
    'restoring ',
    'raising ',
    'repairing ',
    'setting ',
    'returning ',
    'rebuilding ',
    'restarting ',
    'standing ',
    'making ',
    'holding ',
  ];
  if (actionStarts.any((prefix) => lower.startsWith(prefix))) return trimmed;
  return 'restoring $trimmed';
}

String _joinNatural(Iterable<String> values) {
  final parts = values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  switch (parts.length) {
    case 0:
      return '';
    case 1:
      return parts.single;
    case 2:
      return '${parts.first} and ${parts.last}';
    default:
      return '${parts.sublist(0, parts.length - 1).join(', ')}, and ${parts.last}';
  }
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
