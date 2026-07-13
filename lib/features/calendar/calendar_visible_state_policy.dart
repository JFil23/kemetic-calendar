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
}) {
  return loadComplete;
}
