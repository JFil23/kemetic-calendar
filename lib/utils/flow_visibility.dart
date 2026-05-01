import 'dart:convert';

import 'local_end_date.dart';

export 'local_end_date.dart';

enum FlowLedgerBucket {
  active,
  savedTemplate,
  inactive,
  softDeleted,
  hiddenHelper,
  reminder,
}

class FlowLedgerEntry<T> {
  const FlowLedgerEntry({
    required this.flow,
    required this.bucket,
    required this.totalEventCount,
    required this.remainingEventCount,
  });

  final T flow;
  final FlowLedgerBucket bucket;
  final int totalEventCount;
  final int remainingEventCount;

  bool get isActive => bucket == FlowLedgerBucket.active;
  bool get isSavedTemplate => bucket == FlowLedgerBucket.savedTemplate;
}

class FlowLedger<T> {
  const FlowLedger(this.entries);

  final List<FlowLedgerEntry<T>> entries;

  List<T> get allItems =>
      List<T>.unmodifiable(entries.map((entry) => entry.flow));

  List<T> get activeItems => List<T>.unmodifiable(
    entries.where((entry) => entry.isActive).map((entry) => entry.flow),
  );

  List<T> get savedTemplateItems => List<T>.unmodifiable(
    entries.where((entry) => entry.isSavedTemplate).map((entry) => entry.flow),
  );

  int get activeCount => entries.where((entry) => entry.isActive).length;

  int get totalRemainingEventCount => entries
      .where((entry) => entry.isActive)
      .fold(0, (sum, entry) => sum + entry.remainingEventCount);
}

/// True when the row is a reminder-backed flow rather than a user flow.
bool isReminderBackedFlow({required bool isReminder}) {
  return isReminder;
}

/// True when the flow row is still enabled by the user.
bool isFlowEnabled({required bool active}) {
  return active;
}

/// True when the row represents a soft-deleted / ended flow.
///
/// This app does not hard-delete flows during normal user actions. Instead it
/// marks them inactive and hidden so they disappear from user-facing flow UIs
/// while preserving row history for cleanup and imports.
bool isSoftDeletedFlow({required bool active, required bool isHidden}) {
  return !active && isHidden;
}

/// True when the flow row carries repeating-note metadata and should be treated
/// as a hidden helper row rather than a user-facing flow.
bool hasRepeatingNoteFlowMetadata(String? notes) {
  if (notes == null || notes.trim().isEmpty) return false;
  try {
    final decoded = jsonDecode(notes.trim());
    return decoded is Map && decoded['kind'] == 'repeating_note';
  } catch (_) {
    return false;
  }
}

/// True when a row is hidden from user-facing calendar flow surfaces.
bool isFlowHiddenFromCalendar({required bool isHidden, String? notes}) {
  if (isHidden) return true;
  return hasRepeatingNoteFlowMetadata(notes);
}

/// True when a flow should appear in active user-facing flow lists.
///
/// Hidden flows stay out of these lists, but the schedule end date does not
/// hide the row. `endDate` only caps scheduled occurrences, while `active`
/// controls whether the flow is still considered live.
bool isFlowVisibleInLists({
  required bool active,
  required bool isHidden,
  String? notes,
}) {
  if (isFlowHiddenFromCalendar(isHidden: isHidden, notes: notes)) return false;
  return isFlowEnabled(active: active);
}

/// True when a row is a real flow that should count as active on the calendar.
///
/// Reminder-backed rows are stored in the same table, but they are not flows
/// for user-facing counts or flow pickers. Soft-deleted / hidden rows also do
/// not count as active calendar flows.
bool isCalendarActiveFlow({
  required bool active,
  required bool isHidden,
  required bool isReminder,
  String? notes,
}) {
  if (isReminderBackedFlow(isReminder: isReminder)) return false;
  return isFlowVisibleInLists(active: active, isHidden: isHidden, notes: notes);
}

/// True when a row is a saved flow template that should appear in saved-flow
/// user-facing lists.
bool isSavedFlowTemplate({
  required bool isSaved,
  required bool isHidden,
  required bool isReminder,
  String? notes,
}) {
  if (!isSaved) return false;
  if (isFlowHiddenFromCalendar(isHidden: isHidden, notes: notes)) return false;
  if (isReminderBackedFlow(isReminder: isReminder)) return false;
  return true;
}

FlowLedgerBucket classifyFlowLedgerBucket({
  required bool active,
  required bool isSaved,
  required bool isHidden,
  required bool isReminder,
  DateTime? endDate,
  String? notes,
  int remainingEventCount = 0,
  bool useRemainingEventCount = false,
  DateTime? now,
}) {
  final scheduleOpen = isFlowScheduleOpenLocally(
    active: active,
    endDate: endDate,
    now: now,
  );

  if (isReminderBackedFlow(isReminder: isReminder)) {
    return FlowLedgerBucket.reminder;
  }
  if (isSoftDeletedFlow(active: active, isHidden: isHidden)) {
    return FlowLedgerBucket.softDeleted;
  }
  if (isSavedFlowTemplate(
    isSaved: isSaved,
    isHidden: isHidden,
    isReminder: isReminder,
    notes: notes,
  )) {
    if (!active) return FlowLedgerBucket.savedTemplate;
    if (!scheduleOpen) return FlowLedgerBucket.savedTemplate;
    if (useRemainingEventCount && remainingEventCount <= 0) {
      return FlowLedgerBucket.savedTemplate;
    }
  }
  if (isFlowHiddenFromCalendar(isHidden: isHidden, notes: notes)) {
    return FlowLedgerBucket.hiddenHelper;
  }
  if (!active) {
    return FlowLedgerBucket.inactive;
  }
  if (!scheduleOpen) {
    return FlowLedgerBucket.inactive;
  }
  if (useRemainingEventCount && remainingEventCount <= 0) {
    return FlowLedgerBucket.inactive;
  }
  return FlowLedgerBucket.active;
}

FlowLedger<T> buildFlowLedger<T>({
  required Iterable<T> flows,
  required int Function(T flow) idOf,
  required bool Function(T flow) activeOf,
  required bool Function(T flow) isSavedOf,
  required bool Function(T flow) isHiddenOf,
  required bool Function(T flow) isReminderOf,
  required DateTime? Function(T flow) endDateOf,
  required String? Function(T flow) notesOf,
  bool useRemainingEventCount = false,
  Map<int, int> totalEventCounts = const {},
  Map<int, int> remainingEventCounts = const {},
  DateTime? now,
}) {
  final entries = <FlowLedgerEntry<T>>[];

  for (final flow in flows) {
    final flowId = idOf(flow);
    final totalEventCount = totalEventCounts[flowId] ?? 0;
    final remainingEventCount = remainingEventCounts[flowId] ?? 0;
    entries.add(
      FlowLedgerEntry<T>(
        flow: flow,
        bucket: classifyFlowLedgerBucket(
          active: activeOf(flow),
          isSaved: isSavedOf(flow),
          isHidden: isHiddenOf(flow),
          isReminder: isReminderOf(flow),
          endDate: endDateOf(flow),
          notes: notesOf(flow),
          remainingEventCount: remainingEventCount,
          useRemainingEventCount: useRemainingEventCount,
          now: now,
        ),
        totalEventCount: totalEventCount,
        remainingEventCount: remainingEventCount,
      ),
    );
  }

  return FlowLedger<T>(List<FlowLedgerEntry<T>>.unmodifiable(entries));
}

/// True when a flow's scheduled range still includes the current local day.
///
/// Use this only for behaviors that need to continue generating future
/// occurrences, such as reminder-rule rebuilding.
bool isFlowScheduleOpenLocally({
  required bool active,
  required DateTime? endDate,
  DateTime? now,
}) {
  if (!active) return false;
  return isActiveThroughLocalEndDate(endDate, now: now);
}
