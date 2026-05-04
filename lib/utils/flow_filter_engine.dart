import 'dart:convert';

/// Dedicated flow/event classifier used to separate active flows, deleted
/// flows, helper rows, reminders, and ghost calendar notes.
enum FlowRecordKind { active, inactive, softDeleted, hiddenHelper, reminder }

enum FlowEventKind {
  standalone,
  activeFlow,
  inactiveFlow,
  deletedFlow,
  hiddenHelperFlow,
  reminderFlow,
  orphanedFlow,
  legacyMaat,
}

class FlowRecordSnapshot {
  const FlowRecordSnapshot({
    required this.id,
    required this.active,
    required this.isHidden,
    required this.isReminder,
    this.isSaved = false,
    this.notes,
  });

  final int id;
  // Live schedule row. A row can still be active even when its local schedule
  // window has expired; end-date semantics are handled separately.
  final bool active;
  // Backend deleted-state marker. Active repeating-note helpers may still look
  // hidden in client metadata, so this flag is not sufficient on its own.
  final bool isHidden;
  // Reminder-backed rows share the flows table but are not user flow rows.
  final bool isReminder;
  // Distinguishes ended historical flows from saved inactive templates.
  final bool isSaved;
  final String? notes;
}

class FlowEventSnapshot {
  const FlowEventSnapshot({
    this.flowLocalId,
    this.clientEventId,
    this.detail,
    this.category,
  });

  final int? flowLocalId;
  final String? clientEventId;
  final String? detail;
  final String? category;
}

class FlowEventDecision {
  const FlowEventDecision({
    required this.kind,
    required this.event,
    this.referencedFlowId,
    this.owner,
  });

  final FlowEventKind kind;
  final FlowEventSnapshot event;
  final int? referencedFlowId;
  final FlowRecordSnapshot? owner;

  bool get isStandaloneVisible => kind == FlowEventKind.standalone;

  bool get shouldPurgeGhostRow =>
      kind == FlowEventKind.deletedFlow ||
      kind == FlowEventKind.orphanedFlow ||
      kind == FlowEventKind.legacyMaat;
}

final RegExp _flowLocalIdTokenRegex = RegExp(
  r'^flowLocalId=([\-0-9]+)(?:;|$)',
  caseSensitive: false,
);

final RegExp _clientEventFlowIdRegex = RegExp(
  r'\|f=([\-0-9]+)(?:\||$)',
  caseSensitive: false,
);

bool hasRepeatingNoteFlowMetadata(String? notes) {
  if (notes == null || notes.trim().isEmpty) return false;
  try {
    final decoded = jsonDecode(notes.trim());
    return decoded is Map && decoded['kind'] == 'repeating_note';
  } catch (_) {
    return false;
  }
}

FlowRecordKind classifyFlowRecord({
  required bool active,
  required bool isHidden,
  required bool isReminder,
  String? notes,
}) {
  if (isReminder) return FlowRecordKind.reminder;
  if (hasRepeatingNoteFlowMetadata(notes) && active) {
    return FlowRecordKind.hiddenHelper;
  }
  if (isHidden) return FlowRecordKind.softDeleted;
  if (active) return FlowRecordKind.active;
  return FlowRecordKind.inactive;
}

FlowRecordKind classifyFlowRecordSnapshot(FlowRecordSnapshot snapshot) {
  return classifyFlowRecord(
    active: snapshot.active,
    isHidden: snapshot.isHidden,
    isReminder: snapshot.isReminder,
    notes: snapshot.notes,
  );
}

bool shouldHydrateFlowEvents(FlowRecordSnapshot snapshot) {
  switch (classifyFlowRecordSnapshot(snapshot)) {
    case FlowRecordKind.active:
    case FlowRecordKind.hiddenHelper:
    case FlowRecordKind.reminder:
      return true;
    case FlowRecordKind.inactive:
    case FlowRecordKind.softDeleted:
      return false;
  }
}

/// Materialized `user_events` hydration is wider than live schedule hydration:
/// ended non-saved flows keep historical rows visible, while saved inactive
/// templates and backend deleted rows stay hidden.
bool shouldHydrateMaterializedUserEvents(FlowRecordSnapshot snapshot) {
  switch (classifyFlowRecordSnapshot(snapshot)) {
    case FlowRecordKind.active:
    case FlowRecordKind.hiddenHelper:
    case FlowRecordKind.reminder:
      return true;
    case FlowRecordKind.inactive:
      return !snapshot.isSaved;
    case FlowRecordKind.softDeleted:
      return false;
  }
}

/// Calendar chrome is broader than the My Flows "Active" ledger: any
/// non-deleted user flow that still owns a loaded calendar note should retain
/// its flow name/color, even when it has fallen out of `ledger.activeItems`.
bool shouldExposeFlowChromeForCalendar(
  FlowRecordSnapshot snapshot, {
  required bool isReferencedByCalendar,
  required bool isActiveLedgerFlow,
}) {
  if (!isReferencedByCalendar && !isActiveLedgerFlow) {
    return false;
  }

  switch (classifyFlowRecordSnapshot(snapshot)) {
    case FlowRecordKind.active:
    case FlowRecordKind.inactive:
    case FlowRecordKind.hiddenHelper:
      return true;
    case FlowRecordKind.softDeleted:
    case FlowRecordKind.reminder:
      return false;
  }
}

String buildMaterializedFlowEventDedupeKey({
  required int flowId,
  required bool allDay,
  String? eventId,
  String? clientEventId,
  required String title,
  int? startMinute,
  int? endMinute,
}) {
  final trimmedEventId = eventId?.trim();
  if (trimmedEventId != null && trimmedEventId.isNotEmpty) {
    return 'flow:$flowId|id:$trimmedEventId';
  }

  final trimmedClientEventId = clientEventId?.trim();
  if (trimmedClientEventId != null && trimmedClientEventId.isNotEmpty) {
    return 'flow:$flowId|cid:$trimmedClientEventId';
  }

  final normalizedTitle = title.trim().toLowerCase();
  if (allDay) {
    return 'flow:$flowId|all-day|title:$normalizedTitle';
  }

  return 'flow:$flowId|time:${startMinute ?? -1}-${endMinute ?? -1}|title:$normalizedTitle';
}

int? extractFlowIdFromClientEventId(String? clientEventId) {
  final raw = clientEventId?.trim() ?? '';
  if (raw.isEmpty) return null;
  final match = _clientEventFlowIdRegex.firstMatch(raw);
  if (match == null) return null;
  return int.tryParse(match.group(1) ?? '');
}

int? extractFlowIdFromDetailMetadata(String? detail) {
  final raw = detail?.trim() ?? '';
  if (raw.isEmpty) return null;

  for (final token in raw.split(';')) {
    final flowId = _parseFlowLocalIdToken(token.trim());
    if (flowId != null) return flowId;
  }

  for (final line in raw.split(RegExp(r'\r?\n'))) {
    final flowId = _parseFlowLocalIdToken(line.trim());
    if (flowId != null) return flowId;
  }

  return null;
}

int? extractReferencedFlowId({
  int? flowLocalId,
  String? clientEventId,
  String? detail,
}) {
  if (flowLocalId != null && flowLocalId > 0) return flowLocalId;

  final cidFlowId = extractFlowIdFromClientEventId(clientEventId);
  if (cidFlowId != null && cidFlowId > 0) return cidFlowId;

  final detailFlowId = extractFlowIdFromDetailMetadata(detail);
  if (detailFlowId != null && detailFlowId > 0) return detailFlowId;

  return null;
}

bool eventReferencesFlow({
  required int flowId,
  int? flowLocalId,
  String? clientEventId,
  String? detail,
}) {
  if (flowId <= 0) return false;
  if (flowLocalId != null && flowLocalId == flowId) return true;
  if (extractFlowIdFromClientEventId(clientEventId) == flowId) return true;
  if (extractFlowIdFromDetailMetadata(detail) == flowId) return true;
  return false;
}

FlowEventDecision classifyFlowEvent({
  required FlowEventSnapshot event,
  Map<int, FlowRecordSnapshot> flowOwnersById = const {},
  FlowRecordSnapshot? owner,
}) {
  final cid = event.clientEventId?.trim() ?? '';
  if (cid.startsWith('maat:')) {
    return FlowEventDecision(
      kind: FlowEventKind.legacyMaat,
      event: event,
      referencedFlowId: extractReferencedFlowId(
        flowLocalId: event.flowLocalId,
        clientEventId: event.clientEventId,
        detail: event.detail,
      ),
      owner: owner,
    );
  }

  final referencedFlowId = extractReferencedFlowId(
    flowLocalId: event.flowLocalId,
    clientEventId: event.clientEventId,
    detail: event.detail,
  );
  if (referencedFlowId == null) {
    return FlowEventDecision(kind: FlowEventKind.standalone, event: event);
  }

  final resolvedOwner = owner ?? flowOwnersById[referencedFlowId];
  if (resolvedOwner == null) {
    return FlowEventDecision(
      kind: FlowEventKind.orphanedFlow,
      event: event,
      referencedFlowId: referencedFlowId,
    );
  }

  switch (classifyFlowRecordSnapshot(resolvedOwner)) {
    case FlowRecordKind.active:
      return FlowEventDecision(
        kind: FlowEventKind.activeFlow,
        event: event,
        referencedFlowId: referencedFlowId,
        owner: resolvedOwner,
      );
    case FlowRecordKind.inactive:
      return FlowEventDecision(
        kind: FlowEventKind.inactiveFlow,
        event: event,
        referencedFlowId: referencedFlowId,
        owner: resolvedOwner,
      );
    case FlowRecordKind.softDeleted:
      return FlowEventDecision(
        kind: FlowEventKind.deletedFlow,
        event: event,
        referencedFlowId: referencedFlowId,
        owner: resolvedOwner,
      );
    case FlowRecordKind.hiddenHelper:
      return FlowEventDecision(
        kind: FlowEventKind.hiddenHelperFlow,
        event: event,
        referencedFlowId: referencedFlowId,
        owner: resolvedOwner,
      );
    case FlowRecordKind.reminder:
      return FlowEventDecision(
        kind: FlowEventKind.reminderFlow,
        event: event,
        referencedFlowId: referencedFlowId,
        owner: resolvedOwner,
      );
  }
}

int? _parseFlowLocalIdToken(String token) {
  final match = _flowLocalIdTokenRegex.firstMatch(token);
  if (match == null) return null;
  return int.tryParse(match.group(1) ?? '');
}
