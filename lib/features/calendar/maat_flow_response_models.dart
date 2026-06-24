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
  followSkyWitness,
  weighingRecord,
  firstArrangementOrder,
  livingPatternPrinciple,
  houseOfLifeKnowledge,
  hotepPeace,
  shoreExchange,
  livingTextLine,
  clearingSpace,
  hetHeruJoy,
  fairHearingMeasure,
  boundaryStoneRestoration,
  openMouthWord,
  autobiographyRecord,
  trueNameAccount,
  livingRecordCarried,
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
      case MaatFlowResponseJournalFormatter.followSkyWitness:
        return 'follow_sky_witness';
      case MaatFlowResponseJournalFormatter.weighingRecord:
        return 'weighing_record';
      case MaatFlowResponseJournalFormatter.firstArrangementOrder:
        return 'first_arrangement_order';
      case MaatFlowResponseJournalFormatter.livingPatternPrinciple:
        return 'living_pattern_principle';
      case MaatFlowResponseJournalFormatter.houseOfLifeKnowledge:
        return 'house_of_life_knowledge';
      case MaatFlowResponseJournalFormatter.hotepPeace:
        return 'hotep_peace';
      case MaatFlowResponseJournalFormatter.shoreExchange:
        return 'shore_exchange';
      case MaatFlowResponseJournalFormatter.livingTextLine:
        return 'living_text_line';
      case MaatFlowResponseJournalFormatter.clearingSpace:
        return 'clearing_space';
      case MaatFlowResponseJournalFormatter.hetHeruJoy:
        return 'het_heru_joy';
      case MaatFlowResponseJournalFormatter.fairHearingMeasure:
        return 'fair_hearing_measure';
      case MaatFlowResponseJournalFormatter.boundaryStoneRestoration:
        return 'boundary_stone_restoration';
      case MaatFlowResponseJournalFormatter.openMouthWord:
        return 'open_mouth_word';
      case MaatFlowResponseJournalFormatter.autobiographyRecord:
        return 'autobiography_record';
      case MaatFlowResponseJournalFormatter.trueNameAccount:
        return 'true_name_account';
      case MaatFlowResponseJournalFormatter.livingRecordCarried:
        return 'living_record_carried';
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
      case 'follow_sky_witness':
      case 'follow-sky-witness':
        return MaatFlowResponseJournalFormatter.followSkyWitness;
      case 'weighing_record':
      case 'weighing-record':
        return MaatFlowResponseJournalFormatter.weighingRecord;
      case 'first_arrangement_order':
      case 'first-arrangement-order':
        return MaatFlowResponseJournalFormatter.firstArrangementOrder;
      case 'living_pattern_principle':
      case 'living-pattern-principle':
        return MaatFlowResponseJournalFormatter.livingPatternPrinciple;
      case 'house_of_life_knowledge':
      case 'house-of-life-knowledge':
        return MaatFlowResponseJournalFormatter.houseOfLifeKnowledge;
      case 'hotep_peace':
      case 'hotep-peace':
        return MaatFlowResponseJournalFormatter.hotepPeace;
      case 'shore_exchange':
      case 'shore-exchange':
        return MaatFlowResponseJournalFormatter.shoreExchange;
      case 'living_text_line':
      case 'living-text-line':
        return MaatFlowResponseJournalFormatter.livingTextLine;
      case 'clearing_space':
      case 'clearing-space':
        return MaatFlowResponseJournalFormatter.clearingSpace;
      case 'het_heru_joy':
      case 'het-heru-joy':
        return MaatFlowResponseJournalFormatter.hetHeruJoy;
      case 'fair_hearing_measure':
      case 'fair-hearing-measure':
        return MaatFlowResponseJournalFormatter.fairHearingMeasure;
      case 'boundary_stone_restoration':
      case 'boundary-stone-restoration':
        return MaatFlowResponseJournalFormatter.boundaryStoneRestoration;
      case 'open_mouth_word':
      case 'open-mouth-word':
        return MaatFlowResponseJournalFormatter.openMouthWord;
      case 'autobiography_record':
      case 'autobiography-record':
        return MaatFlowResponseJournalFormatter.autobiographyRecord;
      case 'true_name_account':
      case 'true-name-account':
        return MaatFlowResponseJournalFormatter.trueNameAccount;
      case 'living_record_carried':
      case 'living-record-carried':
        return MaatFlowResponseJournalFormatter.livingRecordCarried;
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

class MaatFlowInitialPromptSpec {
  const MaatFlowInitialPromptSpec({
    required this.flowKey,
    required this.title,
    this.subtitle = '',
    this.enabled = true,
    this.requiredBeforeJoin = false,
    this.fields = const <MaatFlowResponseSpec>[],
  }) : assert(flowKey.length > 0),
       assert(title.length > 0);

  final String flowKey;
  final bool enabled;
  final bool requiredBeforeJoin;
  final String title;
  final String subtitle;
  final List<MaatFlowResponseSpec> fields;

  bool get isRenderable => enabled && fields.isNotEmpty;
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
    case MaatFlowResponseJournalFormatter.followSkyWitness:
      return '${spec.journalHeading}: I noticed ${_sentenceFragment(display)} and kept one line of witness.';
    case MaatFlowResponseJournalFormatter.weighingRecord:
      return '${spec.journalHeading}: I placed one record on the scale and named one correction.';
    case MaatFlowResponseJournalFormatter.firstArrangementOrder:
      return '${spec.journalHeading}: I put one space back into order and made ${_sentenceFragment(display)} visible.';
    case MaatFlowResponseJournalFormatter.livingPatternPrinciple:
      return '${spec.journalHeading}: I observed one pattern and carried ${_sentenceFragment(display)} into action.';
    case MaatFlowResponseJournalFormatter.houseOfLifeKnowledge:
      return '${spec.journalHeading}: I preserved one piece of knowledge by ${_sentenceFragment(display)}.';
    case MaatFlowResponseJournalFormatter.hotepPeace:
      return '${spec.journalHeading}: I named what was given, let enough be enough, and let the heart cool.';
    case MaatFlowResponseJournalFormatter.shoreExchange:
      return '${spec.journalHeading}: I brought one exchange closer to honest measure.';
    case MaatFlowResponseJournalFormatter.livingTextLine:
      return '${spec.journalHeading}: I received ${_sentenceFragment(display)} from the text and added it back to life.';
    case MaatFlowResponseJournalFormatter.clearingSpace:
      return '${spec.journalHeading}: I created space before response and acted from the cleared place.';
    case MaatFlowResponseJournalFormatter.hetHeruJoy:
      return '${spec.journalHeading}: I cooled the hot force and made room for beauty, joy, or rest.';
    case MaatFlowResponseJournalFormatter.fairHearingMeasure:
      return '${spec.journalHeading}: I listened before deciding and kept the measure even.';
    case MaatFlowResponseJournalFormatter.boundaryStoneRestoration:
      return '${spec.journalHeading}: I restored one marker to its rightful place.';
    case MaatFlowResponseJournalFormatter.openMouthWord:
      return '${spec.journalHeading}: I governed the word and let speech serve Ma\'at.';
    case MaatFlowResponseJournalFormatter.autobiographyRecord:
      return '${spec.journalHeading}: I named one part of my record with clearer evidence.';
    case MaatFlowResponseJournalFormatter.trueNameAccount:
      return '${spec.journalHeading}: I measured a false account against the record and stood closer to the accurate name.';
    case MaatFlowResponseJournalFormatter.livingRecordCarried:
      return '${spec.journalHeading}: I turned one part of the decan into a record that can be carried forward.';
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
    case MaatFlowResponseJournalFormatter.followSkyWitness:
      return _formatFollowSkyResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.weighingRecord:
      return _formatWeighingResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.firstArrangementOrder:
      return _formatFirstArrangementResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.livingPatternPrinciple:
      return _formatLivingPatternResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.houseOfLifeKnowledge:
      return _formatHouseOfLifeResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.hotepPeace:
      return _formatHotepResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.shoreExchange:
      return _formatShoreResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.livingTextLine:
      return _formatLivingTextResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.clearingSpace:
      return _formatClearingResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.hetHeruJoy:
      return _formatHetHeruResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.fairHearingMeasure:
      return _formatFairHearingResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.boundaryStoneRestoration:
      return _formatBoundaryStoneResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.openMouthWord:
      return _formatOpenMouthResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.autobiographyRecord:
      return _formatAutobiographyResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.trueNameAccount:
      return _formatTrueNameResponseGroup(specs, values);
    case MaatFlowResponseJournalFormatter.livingRecordCarried:
      return _formatLivingRecordResponseGroup(specs, values);
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

String _formatFollowSkyResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final shownSpec = byRole['shown'];
  final changedSpec = byRole['changed'];
  final shown = shownSpec == null
      ? ''
      : _joinNatural(
          values[shownSpec.id]?.optionIds
                  .map((id) => shownSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final changed = changedSpec == null
      ? ''
      : _sentenceFragment(values[changedSpec.id]?.displayText(changedSpec));

  if (shown.isNotEmpty && changed.isNotEmpty) {
    return '${specs.first.journalHeading}: I noticed $shown and kept $changed.';
  }
  if (shown.isNotEmpty) {
    return '${specs.first.journalHeading}: I noticed $shown and kept one line of witness.';
  }
  if (changed.isNotEmpty) {
    return '${specs.first.journalHeading}: I noticed the sky change and kept $changed.';
  }
  return '';
}

String _formatWeighingResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final revealedSpec = byRole['revealed'];
  final witnessedSpec = byRole['witnessed'];
  final revealed = revealedSpec == null
      ? ''
      : _joinNatural(
          values[revealedSpec.id]?.optionIds
                  .map((id) => revealedSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final witnessed = witnessedSpec == null
      ? ''
      : _sentenceFragment(values[witnessedSpec.id]?.displayText(witnessedSpec));

  if (revealed.isNotEmpty) {
    return '${specs.first.journalHeading}: I placed $revealed on the scale and named one correction.';
  }
  if (witnessed.isNotEmpty) {
    return '${specs.first.journalHeading}: I placed one record on the scale and named one correction.';
  }
  return '';
}

String _formatFirstArrangementResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final orderedSpec = byRole['ordered'];
  final changedSpec = byRole['changed'];
  final ordered = orderedSpec == null
      ? ''
      : _joinNatural(
          values[orderedSpec.id]?.optionIds
                  .map((id) => orderedSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final changed = changedSpec == null
      ? ''
      : _sentenceFragment(values[changedSpec.id]?.displayText(changedSpec));

  if (ordered.isNotEmpty && changed.isNotEmpty) {
    return '${specs.first.journalHeading}: I put $ordered into order and made $changed visible.';
  }
  if (ordered.isNotEmpty) {
    return '${specs.first.journalHeading}: I put $ordered back into order and made what belongs there visible.';
  }
  if (changed.isNotEmpty) {
    return '${specs.first.journalHeading}: I put one space back into order and made $changed visible.';
  }
  return '';
}

String _formatLivingPatternResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final observedSpec = byRole['observed'];
  final principleSpec = byRole['principle'];
  final observed = observedSpec == null
      ? ''
      : _joinNatural(
          values[observedSpec.id]?.optionIds
                  .map((id) => observedSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final principle = principleSpec == null
      ? ''
      : _sentenceFragment(values[principleSpec.id]?.displayText(principleSpec));

  if (observed.isNotEmpty && principle.isNotEmpty) {
    return '${specs.first.journalHeading}: I observed $observed and carried $principle into action.';
  }
  if (observed.isNotEmpty) {
    return '${specs.first.journalHeading}: I observed $observed and carried its principle into action.';
  }
  if (principle.isNotEmpty) {
    return '${specs.first.journalHeading}: I observed one pattern and carried $principle into action.';
  }
  return '';
}

String _formatHouseOfLifeResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final clearerSpec = byRole['clearer'];
  final learnedSpec = byRole['learned'];
  final clearer = clearerSpec == null
      ? ''
      : _joinNatural(
          values[clearerSpec.id]?.optionIds
                  .map((id) => clearerSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final learned = learnedSpec == null
      ? ''
      : _sentenceFragment(values[learnedSpec.id]?.displayText(learnedSpec));

  if (clearer.isNotEmpty && learned.isNotEmpty) {
    return '${specs.first.journalHeading}: I made $clearer clearer and preserved $learned.';
  }
  if (clearer.isNotEmpty) {
    return '${specs.first.journalHeading}: I preserved $clearer and made it useful.';
  }
  if (learned.isNotEmpty) {
    return '${specs.first.journalHeading}: I preserved one piece of knowledge by $learned.';
  }
  return '';
}

String _formatHotepResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final cooledSpec = byRole['cooled'];
  final enoughSpec = byRole['enough'];
  final cooled = cooledSpec == null
      ? ''
      : _joinNatural(
          values[cooledSpec.id]?.optionIds
                  .map((id) => cooledSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final enough = enoughSpec == null
      ? ''
      : _sentenceFragment(values[enoughSpec.id]?.displayText(enoughSpec));

  if (cooled.isNotEmpty) {
    return '${specs.first.journalHeading}: I named $cooled, let enough be enough, and let the heart cool.';
  }
  if (enough.isNotEmpty) {
    return '${specs.first.journalHeading}: I named what was given, let enough be enough, and let the heart cool.';
  }
  return '';
}

String _formatShoreResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final exchangeSpec = byRole['exchange'];
  final measuredSpec = byRole['measured'];
  final exchange = exchangeSpec == null
      ? ''
      : _joinNatural(
          values[exchangeSpec.id]?.optionIds
                  .map((id) => exchangeSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final measured = measuredSpec == null
      ? ''
      : _sentenceFragment(values[measuredSpec.id]?.displayText(measuredSpec));

  if (exchange.isNotEmpty) {
    return '${specs.first.journalHeading}: I brought $exchange closer to honest measure.';
  }
  if (measured.isNotEmpty) {
    return '${specs.first.journalHeading}: I brought one exchange closer to honest measure.';
  }
  return '';
}

String _formatLivingTextResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final addedSpec = byRole['added'];
  final appliedSpec = byRole['applied'];
  final added = addedSpec == null
      ? ''
      : _joinNatural(
          values[addedSpec.id]?.optionIds
                  .map((id) => addedSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final applied = appliedSpec == null
      ? ''
      : _sentenceFragment(values[appliedSpec.id]?.displayText(appliedSpec));

  if (added.isNotEmpty && applied.isNotEmpty) {
    return '${specs.first.journalHeading}: I received $added from the text and added $applied back to life.';
  }
  if (added.isNotEmpty) {
    return '${specs.first.journalHeading}: I received $added from the text and added it back to life.';
  }
  if (applied.isNotEmpty) {
    return '${specs.first.journalHeading}: I received one line from the text and added $applied back to life.';
  }
  return '';
}

String _formatClearingResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final clearedSpec = byRole['cleared'];
  final waitedSpec = byRole['waited'];
  final cleared = clearedSpec == null
      ? ''
      : _joinNatural(
          values[clearedSpec.id]?.optionIds
                  .map((id) => clearedSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final waited = waitedSpec == null
      ? ''
      : _sentenceFragment(values[waitedSpec.id]?.displayText(waitedSpec));

  if (cleared.isNotEmpty) {
    return '${specs.first.journalHeading}: I cleared $cleared before response and acted from the cleared place.';
  }
  if (waited.isNotEmpty) {
    return '${specs.first.journalHeading}: I created space before response and acted from the cleared place.';
  }
  return '';
}

String _formatHetHeruResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final cooledSpec = byRole['cooled'];
  final joySpec = byRole['joy'];
  final cooled = cooledSpec == null
      ? ''
      : _joinNatural(
          values[cooledSpec.id]?.optionIds
                  .map((id) => cooledSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final joy = joySpec == null
      ? ''
      : _sentenceFragment(values[joySpec.id]?.displayText(joySpec));

  if (cooled.isNotEmpty) {
    return '${specs.first.journalHeading}: I cooled the hot force with $cooled and made room for beauty, joy, or rest.';
  }
  if (joy.isNotEmpty) {
    return '${specs.first.journalHeading}: I cooled the hot force and made room for beauty, joy, or rest.';
  }
  return '';
}

String _formatFairHearingResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final heardSpec = byRole['heard'];
  final rememberedSpec = byRole['remembered'];
  final heard = heardSpec == null
      ? ''
      : _joinNatural(
          values[heardSpec.id]?.optionIds
                  .map((id) => heardSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final remembered = rememberedSpec == null
      ? ''
      : _sentenceFragment(
          values[rememberedSpec.id]?.displayText(rememberedSpec),
        );

  if (heard.isNotEmpty) {
    return '${specs.first.journalHeading}: I listened before deciding, marked $heard, and kept the measure even.';
  }
  if (remembered.isNotEmpty) {
    return '${specs.first.journalHeading}: I listened before deciding and kept the measure even.';
  }
  return '';
}

String _formatBoundaryStoneResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final markerSpec = byRole['marker'];
  final restoredSpec = byRole['restored'];
  final marker = markerSpec == null
      ? ''
      : _joinNatural(
          values[markerSpec.id]?.optionIds
                  .map((id) => markerSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final restored = restoredSpec == null
      ? ''
      : _sentenceFragment(values[restoredSpec.id]?.displayText(restoredSpec));

  if (marker.isNotEmpty) {
    return '${specs.first.journalHeading}: I restored $marker to its rightful place.';
  }
  if (restored.isNotEmpty) {
    return '${specs.first.journalHeading}: I restored one marker to its rightful place.';
  }
  return '';
}

String _formatOpenMouthResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final wordSpec = byRole['word'];
  final governedSpec = byRole['governed'];
  final word = wordSpec == null
      ? ''
      : _joinNatural(
          values[wordSpec.id]?.optionIds
                  .map((id) => wordSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final governed = governedSpec == null
      ? ''
      : _sentenceFragment(values[governedSpec.id]?.displayText(governedSpec));

  if (word.isNotEmpty) {
    return '${specs.first.journalHeading}: I governed $word and let speech serve Ma\'at.';
  }
  if (governed.isNotEmpty) {
    return '${specs.first.journalHeading}: I governed the word and let speech serve Ma\'at.';
  }
  return '';
}

String _formatAutobiographyResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final recordSpec = byRole['record'];
  final rememberedSpec = byRole['remembered'];
  final record = recordSpec == null
      ? ''
      : _joinNatural(
          values[recordSpec.id]?.optionIds
                  .map((id) => recordSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final remembered = rememberedSpec == null
      ? ''
      : _sentenceFragment(
          values[rememberedSpec.id]?.displayText(rememberedSpec),
        );

  if (record.isNotEmpty) {
    return '${specs.first.journalHeading}: I named $record in my record with clearer evidence.';
  }
  if (remembered.isNotEmpty) {
    return '${specs.first.journalHeading}: I named one part of my record with clearer evidence.';
  }
  return '';
}

String _formatTrueNameResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final accountSpec = byRole['account'];
  final supportedSpec = byRole['supported'];
  final account = accountSpec == null
      ? ''
      : _joinNatural(
          values[accountSpec.id]?.optionIds
                  .map((id) => accountSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final supported = supportedSpec == null
      ? ''
      : _sentenceFragment(values[supportedSpec.id]?.displayText(supportedSpec));

  if (account.isNotEmpty) {
    return '${specs.first.journalHeading}: I measured $account against the record and stood closer to the accurate name.';
  }
  if (supported.isNotEmpty) {
    return '${specs.first.journalHeading}: I measured a false account against the record and stood closer to the accurate name.';
  }
  return '';
}

String _formatLivingRecordResponseGroup(
  List<MaatFlowResponseSpec> specs,
  Map<String, MaatFlowResponseValue> values,
) {
  final byRole = <String, MaatFlowResponseSpec>{
    for (final spec in specs)
      if (spec.normalizedJournalRole != null) spec.normalizedJournalRole!: spec,
  };

  final recordSpec = byRole['record'];
  final carriedSpec = byRole['carried'];
  final record = recordSpec == null
      ? ''
      : _joinNatural(
          values[recordSpec.id]?.optionIds
                  .map((id) => recordSpec.optionById(id)?._displayLabel ?? id)
                  .where((label) => label.trim().isNotEmpty)
                  .map((label) => label.trim().toLowerCase()) ??
              const Iterable<String>.empty(),
        );
  final carried = carriedSpec == null
      ? ''
      : _sentenceFragment(values[carriedSpec.id]?.displayText(carriedSpec));

  if (record.isNotEmpty) {
    return '${specs.first.journalHeading}: I turned $record into a record that can be carried forward.';
  }
  if (carried.isNotEmpty) {
    return '${specs.first.journalHeading}: I turned one part of the decan into a record that can be carried forward.';
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
