import '../account_view_cache.dart';
import 'warm_snapshot_store.dart';

/// Existing repositories call this at both sides of a write. It fences reads
/// started before/during the mutation; it never persists optimistic data.
void invalidateWarmDomains(String? userId, List<String> prefixes) {
  if (userId == null) return;
  for (final prefix in prefixes) {
    WarmSnapshotStore.instance.invalidate(userId, prefix: prefix);
    AccountViewCache.instance.invalidatePrefix(userId, prefix);
  }
}
