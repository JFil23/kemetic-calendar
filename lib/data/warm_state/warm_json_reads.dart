import 'warm_resource_contract.dart';
import 'dart:async';
import 'warm_work_queue.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'warm_snapshot_store.dart';

/// Opt-in JSON boundary for passive repository reads. Cached-only reconstruction
/// runs the same domain parsing code without invoking the supplied fetch.
class WarmJsonReads {
  WarmJsonReads(this.client, {this.cachedOnly = false, this.mayFetch});
  final SupabaseClient client;
  final bool cachedOnly;
  final bool Function()? mayFetch;

  /// Restores the existing bounded cache without fetching. Repositories may
  /// reconcile overlapping snapshots while retaining each confirmation time.
  Future<Map<String, WarmSnapshot>> cachedFamily(String prefix) async {
    WarmResourceContract.requireRegistered(prefix);
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw const WarmReadCancelled();
    final store = WarmSnapshotStore.instance;
    await store.restore(uid);
    if (client.auth.currentUser?.id != uid || !(mayFetch?.call() ?? true)) {
      throw const WarmReadCancelled();
    }
    return store.peekFamily(uid, prefix);
  }

  Future<Object?> value(
    String key,
    Future<Object?> Function() fetch, {
    void Function(Object?)? validate,
  }) async {
    WarmResourceContract.requireRegistered(key);
    Future<Object?> checkedFetch() async {
      final value = await fetch();
      validate?.call(value);
      return value;
    }

    final uid = client.auth.currentUser?.id;
    if (uid == null) throw const WarmReadCancelled();
    final guard = Zone.current[warmReadGuard] as bool Function()?;
    final store = WarmSnapshotStore.instance;
    Object? result;
    try {
      result = cachedOnly
          ? await store.cached(uid, key)
          : (await store.refresh(
              uid,
              key,
              checkedFetch,
              isCurrent: () =>
                  client.auth.currentUser?.id == uid &&
                  (mayFetch?.call() ?? true) &&
                  (guard?.call() ?? true),
            )).data;
    } catch (error) {
      final denied =
          error is PostgrestException && error.code == '42501' ||
          error is FunctionException && error.status == 403;
      if (denied) {
        store.invalidate(uid, prefix: key);
        throw const WarmAccessDenied();
      }
      rethrow;
    }
    if (client.auth.currentUser?.id != uid) throw const WarmReadCancelled();
    validate?.call(result);
    return result;
  }

  Future<List<Map<String, dynamic>>> rows(
    String key,
    Future<Object?> Function() fetch,
  ) async =>
      (await value(
                key,
                fetch,
                validate: (data) {
                  if (data is! List || data.any((r) => r is! Map)) {
                    throw const FormatException(
                      'Expected a complete list of rows',
                    );
                  }
                },
              )
              as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
}
