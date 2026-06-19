bool shouldCommitFlowOnlyVisibleCalendarState({
  required int flowAddedCount,
  required bool keepWarmStartSnapshotVisible,
  required bool hasPaintedStandaloneLane,
}) {
  if (flowAddedCount <= 0) return false;
  if (keepWarmStartSnapshotVisible) return false;
  if (hasPaintedStandaloneLane) return false;
  return true;
}

bool shouldPreservePaintedStandaloneLaneForHydrationCommit({
  required String source,
  required String commitPhase,
  required bool hasPaintedStandaloneLane,
}) {
  return hasPaintedStandaloneLane &&
      source == 'invalidation:calendarImportSynced' &&
      commitPhase == 'complete';
}
