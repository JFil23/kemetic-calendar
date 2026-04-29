import 'local_end_date.dart';

export 'local_end_date.dart';

/// True when a flow should still behave as active on the user's local day.
bool isFlowActiveLocally({
  required bool active,
  required DateTime? endDate,
  DateTime? now,
}) {
  if (!active) return false;
  return isActiveThroughLocalEndDate(endDate, now: now);
}

/// True when a flow should appear in active user-facing flow lists.
///
/// Hidden flows stay out of these lists even if they are still active, while
/// other systems such as event hydration can still treat them as active.
bool isFlowVisibleLocally({
  required bool active,
  required bool isHidden,
  required DateTime? endDate,
  DateTime? now,
}) {
  if (isHidden) return false;
  return isFlowActiveLocally(active: active, endDate: endDate, now: now);
}
