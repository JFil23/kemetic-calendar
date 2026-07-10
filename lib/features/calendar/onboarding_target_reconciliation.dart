class PendingOnboardingTargetReconciliation<T> {
  const PendingOnboardingTargetReconciliation({
    required this.cleanedRefreshItems,
    required this.authoritativeTargetFound,
    required this.shouldPreservePending,
  });

  final List<T> cleanedRefreshItems;
  final bool authoritativeTargetFound;
  final bool shouldPreservePending;
}

PendingOnboardingTargetReconciliation<T> reconcilePendingOnboardingTarget<T>({
  required Iterable<T> refreshedItems,
  required bool Function(T item) matchesTarget,
  required bool Function(T item) isPendingCopy,
}) {
  final cleaned = <T>[
    for (final item in refreshedItems)
      if (!isPendingCopy(item)) item,
  ];
  final authoritativeFound = cleaned.any(matchesTarget);
  return PendingOnboardingTargetReconciliation<T>(
    cleanedRefreshItems: cleaned,
    authoritativeTargetFound: authoritativeFound,
    shouldPreservePending: !authoritativeFound,
  );
}
