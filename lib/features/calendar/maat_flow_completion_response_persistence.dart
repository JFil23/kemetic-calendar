import 'maat_flow_response_models.dart';

const String kMaatCompletionResponsesMetadataKey = 'maat_completion_responses';
const int kMaatCompletionResponsesSchemaVersion = 1;

class MaatCompletionResponseRecord {
  const MaatCompletionResponseRecord({
    required this.specId,
    required this.value,
    required this.sourceId,
    required this.journalBehavior,
    required this.updatedAt,
  });

  final String specId;
  final MaatFlowResponseValue value;
  final String sourceId;
  final MaatFlowJournalBehavior journalBehavior;
  final DateTime? updatedAt;
}

class MaatCompletionResponseSnapshot {
  const MaatCompletionResponseSnapshot({
    required this.values,
    required this.records,
  });

  final Map<String, MaatFlowResponseValue> values;
  final List<MaatCompletionResponseRecord> records;
}

Map<String, dynamic> buildMaatCompletionResponseMetadata({
  required Map<String, dynamic> existingMetadata,
  required List<MaatFlowResponseSpec> specs,
  required Map<String, MaatFlowResponseValue> currentValues,
  required Set<String> dirtySpecIds,
  required String clientEventId,
  required int flowId,
  required DateTime localDate,
  required String? eventKey,
  required DateTime completedAt,
  required String Function(MaatFlowResponseSpec spec) sourceIdForSpec,
  required String Function(MaatFlowResponseSpec spec, String groupId)
  sourceIdForGroup,
}) {
  final metadata = Map<String, dynamic>.from(existingMetadata);
  if (specs.isEmpty) return metadata;

  final specsById = <String, MaatFlowResponseSpec>{
    for (final spec in specs) spec.id: spec,
  };
  final previous = extractMaatCompletionResponseValues(
    metadata,
    specs: specs,
  ).values;
  final nextValues = <String, MaatFlowResponseValue>{...previous};

  for (final specId in dirtySpecIds) {
    final spec = specsById[specId];
    if (spec == null) continue;
    final value = currentValues[specId];
    if (value == null || value.isEmpty) {
      nextValues.remove(specId);
    } else {
      nextValues[specId] = value;
    }
  }

  if (nextValues.isEmpty) {
    metadata.remove(kMaatCompletionResponsesMetadataKey);
    return metadata;
  }

  final records = <String, dynamic>{};
  for (final entry in nextValues.entries) {
    final spec = specsById[entry.key];
    if (spec == null) continue;
    final groupId = spec.normalizedJournalGroupId;
    final sourceId = groupId == null
        ? sourceIdForSpec(spec)
        : sourceIdForGroup(spec, groupId);
    records[entry.key] = <String, dynamic>{
      'spec_id': spec.id,
      'flow_key': spec.flowKey,
      if (spec.eventKey != null) 'event_key': spec.eventKey,
      'kind': spec.kind.wireName,
      'journal_behavior': spec.journalBehavior.wireName,
      'source_id': sourceId,
      'updated_at': completedAt.toUtc().toIso8601String(),
      'value': entry.value.toJson(),
    };
  }

  metadata[kMaatCompletionResponsesMetadataKey] = <String, dynamic>{
    'schema_version': kMaatCompletionResponsesSchemaVersion,
    'client_event_id': clientEventId,
    'flow_id': flowId,
    'event_key': eventKey,
    'local_date': _dateOnlyWire(localDate),
    'updated_at': completedAt.toUtc().toIso8601String(),
    'records': records,
  };
  return metadata;
}

MaatCompletionResponseSnapshot extractMaatCompletionResponseValues(
  Map<dynamic, dynamic>? metadata, {
  required List<MaatFlowResponseSpec> specs,
}) {
  final envelope = metadata?[kMaatCompletionResponsesMetadataKey];
  if (envelope is! Map) {
    return const MaatCompletionResponseSnapshot(
      values: <String, MaatFlowResponseValue>{},
      records: <MaatCompletionResponseRecord>[],
    );
  }
  final rawRecords = envelope['records'];
  if (rawRecords is! Map) {
    return const MaatCompletionResponseSnapshot(
      values: <String, MaatFlowResponseValue>{},
      records: <MaatCompletionResponseRecord>[],
    );
  }

  final specsById = <String, MaatFlowResponseSpec>{
    for (final spec in specs) spec.id: spec,
  };
  final values = <String, MaatFlowResponseValue>{};
  final records = <MaatCompletionResponseRecord>[];
  for (final entry in rawRecords.entries) {
    final rawRecord = entry.value;
    if (rawRecord is! Map) continue;
    final specId = rawRecord['spec_id']?.toString().trim();
    if (specId == null || specId.isEmpty || !specsById.containsKey(specId)) {
      continue;
    }
    final spec = specsById[specId]!;
    final rawValue = rawRecord['value'];
    final value = rawValue is Map
        ? MaatFlowResponseValue.fromJson(rawValue)
        : null;
    if (value == null || value.isEmpty) continue;
    final sourceId = rawRecord['source_id']?.toString().trim() ?? '';
    final updatedAt = DateTime.tryParse(
      rawRecord['updated_at']?.toString() ?? '',
    );
    final behavior = _journalBehaviorForRecord(rawRecord, spec);
    values[specId] = value;
    records.add(
      MaatCompletionResponseRecord(
        specId: specId,
        value: value,
        sourceId: sourceId,
        journalBehavior: behavior,
        updatedAt: updatedAt,
      ),
    );
  }

  return MaatCompletionResponseSnapshot(
    values: Map<String, MaatFlowResponseValue>.unmodifiable(values),
    records: List<MaatCompletionResponseRecord>.unmodifiable(records),
  );
}

MaatFlowJournalBehavior _journalBehaviorForRecord(
  Map<dynamic, dynamic> rawRecord,
  MaatFlowResponseSpec spec,
) {
  final raw = rawRecord['journal_behavior']?.toString();
  if (raw == null || raw.trim().isEmpty) return spec.journalBehavior;

  try {
    final stored = MaatFlowJournalBehaviorX.fromWireName(raw);
    // Stored behavior is an audit snapshot; the registered spec drives current
    // projection so behavior drift cannot hide the canonical response value.
    return stored == spec.journalBehavior ? stored : spec.journalBehavior;
  } on FormatException {
    return spec.journalBehavior;
  }
}

String _dateOnlyWire(DateTime value) {
  final date = DateTime(value.year, value.month, value.day);
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
