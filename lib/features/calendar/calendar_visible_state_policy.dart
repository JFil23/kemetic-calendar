bool shouldCommitFlowOnlyVisibleCalendarState({
  required int flowAddedCount,
  required bool keepWarmStartSnapshotVisible,
  required bool hasPaintedEventSnapshot,
}) {
  if (flowAddedCount <= 0) return false;
  if (keepWarmStartSnapshotVisible) return false;
  if (hasPaintedEventSnapshot) return false;
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

bool shouldPublishCompletedVisibleCalendarSnapshot({
  required bool loadComplete,
  required bool hasIncomingEventSnapshot,
  required bool hasPaintedEventSnapshot,
}) {
  if (loadComplete) return true;
  if (!hasPaintedEventSnapshot) return hasIncomingEventSnapshot;
  return false;
}
