import 'local_end_date.dart';

export 'local_end_date.dart';

/// True when the flow row is still enabled by the user.
bool isFlowEnabled({required bool active}) {
  return active;
}

/// True when a flow should appear in active user-facing flow lists.
///
/// Hidden flows stay out of these lists, but the schedule end date does not
/// hide the row. `endDate` only caps scheduled occurrences, while `active`
/// controls whether the flow is still considered live.
bool isFlowVisibleInLists({required bool active, required bool isHidden}) {
  if (isHidden) return false;
  return isFlowEnabled(active: active);
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
