import 'flow_filter_engine.dart';
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
    required this.visibleInActiveList,
    required this.visibleInSavedList,
    required this.totalEventCount,
    required this.remainingEventCount,
  });

  final T flow;
  final FlowLedgerBucket bucket;
  final bool visibleInActiveList;
  final bool visibleInSavedList;
  final int totalEventCount;
  final int remainingEventCount;

  bool get isActive => visibleInActiveList;
  bool get isSavedTemplate => visibleInSavedList;
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
  return classifyFlowRecord(
        active: true,
        isHidden: false,
        isReminder: isReminder,
      ) ==
      FlowRecordKind.reminder;
}

/// True when the row represents a soft-deleted / ended flow.
///
/// This app does not hard-delete flows during normal user actions. Instead it
/// marks them inactive and hidden so they disappear from user-facing flow UIs
/// while preserving row history for cleanup and imports.
bool isSoftDeletedFlow({required bool active, required bool isHidden}) {
  return classifyFlowRecord(
        active: active,
        isHidden: isHidden,
        isReminder: false,
      ) ==
      FlowRecordKind.softDeleted;
}

/// True when a row is hidden from user-facing calendar flow surfaces.
bool isFlowHiddenFromCalendar({required bool isHidden, String? notes}) {
  final kind = classifyFlowRecord(
    active: true,
    isHidden: isHidden,
    isReminder: false,
    notes: notes,
  );
  return kind == FlowRecordKind.softDeleted ||
      kind == FlowRecordKind.hiddenHelper;
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
  return classifyFlowRecord(
        active: active,
        isHidden: isHidden,
        isReminder: false,
        notes: notes,
      ) ==
      FlowRecordKind.active;
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
  return classifyFlowRecord(
        active: active,
        isHidden: isHidden,
        isReminder: isReminder,
        notes: notes,
      ) ==
      FlowRecordKind.active;
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
  final kind = classifyFlowRecord(
    active: false,
    isHidden: isHidden,
    isReminder: isReminder,
    notes: notes,
  );
  return kind == FlowRecordKind.inactive || kind == FlowRecordKind.active;
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
  final recordKind = classifyFlowRecord(
    active: active,
    isHidden: isHidden,
    isReminder: isReminder,
    notes: notes,
  );
  final scheduleOpen = isFlowScheduleOpenLocally(
    active: active,
    endDate: endDate,
    now: now,
  );

  switch (recordKind) {
    case FlowRecordKind.reminder:
      return FlowLedgerBucket.reminder;
    case FlowRecordKind.softDeleted:
      return FlowLedgerBucket.softDeleted;
    case FlowRecordKind.hiddenHelper:
      return FlowLedgerBucket.hiddenHelper;
    case FlowRecordKind.active:
    case FlowRecordKind.inactive:
      break;
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
    final visibleInSavedList = isSavedFlowTemplate(
      isSaved: isSavedOf(flow),
      isHidden: isHiddenOf(flow),
      isReminder: isReminderOf(flow),
      notes: notesOf(flow),
    );
    final bucket = classifyFlowLedgerBucket(
      active: activeOf(flow),
      isSaved: isSavedOf(flow),
      isHidden: isHiddenOf(flow),
      isReminder: isReminderOf(flow),
      endDate: endDateOf(flow),
      notes: notesOf(flow),
      remainingEventCount: remainingEventCount,
      useRemainingEventCount: useRemainingEventCount,
      now: now,
    );
    entries.add(
      FlowLedgerEntry<T>(
        flow: flow,
        bucket: bucket,
        visibleInActiveList: bucket == FlowLedgerBucket.active,
        visibleInSavedList: visibleInSavedList,
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
