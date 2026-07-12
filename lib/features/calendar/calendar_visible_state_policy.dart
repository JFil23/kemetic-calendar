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
  bool standaloneLaneAuthoritative = true,
}) {
  if (!hasPaintedStandaloneLane) return false;
  if (commitPhase != 'complete') return false;
  if (!standaloneLaneAuthoritative) return true;
  return source == 'invalidation:calendarImportSynced';
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
