import 'dart:async';
import 'package:flutter/foundation.dart';

class ViewReadCancelled implements Exception {
  const ViewReadCancelled();
}

/// Ephemeral projections of repository data, never a persistence authority.
/// No timers, subscriptions, I/O, or writes are started by this cache.
class AccountViewCache {
  AccountViewCache();
  static final instance = AccountViewCache();
  String? _account;
  int _generation = 0;
  final _values = <String, Object>{};
  final _loadedAt = <String, DateTime>{};
  final _versions = <String, int>{};
  final _pending = <String, Future<Object?>>{};
  final _failures = <String, int>{};
  final _attemptedEntry = <String, int>{};
  final changes = ValueNotifier<String?>(null);
  int _entry = 0;

  void enterAccount(String userId) {
    if (_account == userId) return;
    _account = userId;
    _generation++;
    _values.clear();
    _versions.clear();
    _loadedAt.clear();
    _pending.clear();
    _failures.clear();
    _attemptedEntry.clear();
  }

  void beginVisibleEntry() {
    _entry++;
  }

  void beginRefreshCycle() {
    _failures.clear();
    beginVisibleEntry();
  }

  T? peek<T>(String userId, String key) =>
      _account == userId ? _values[key] as T? : null;
  DateTime? loadedAt(String userId, String key) =>
      _account == userId ? _loadedAt[key] : null;
  bool failed(String key) => (_failures[key] ?? 0) > 0;
  bool loading(String key) => _pending.containsKey(key);
  void publish<T extends Object>(String userId, String key, T value) {
    // A response for a departed account must never repopulate this cache.
    if (_account == null) enterAccount(userId);
    if (_account != userId) return;
    if (identical(_values[key], value)) return;
    _versions[key] = (_versions[key] ?? 0) + 1;
    _values[key] = value;
    if (key.startsWith('image.')) {
      final images = _values.keys.where((k) => k.startsWith('image.')).toList();
      while (images.length > 8) {
        final oldest = images.removeAt(0);
        _values.remove(oldest);
        _loadedAt.remove(oldest);
        _attemptedEntry.remove(oldest);
        _failures.remove(oldest);
      }
    }
    _loadedAt[key] = DateTime.now();
    _failures.remove(key);
    changes.value = null;
    changes.value = key;
  }

  void invalidate(String userId, String key) {
    if (_account != userId) return;
    _loadedAt.remove(key);
    _versions[key] = (_versions[key] ?? 0) + 1;
    if (!failed(key)) _attemptedEntry.remove(key);
  }

  void invalidatePrefix(String userId, String prefix) {
    if (_account != userId) return;
    for (final key in {..._values.keys, ..._pending.keys}) {
      if (key.startsWith(prefix)) invalidate(userId, key);
    }
  }

  void evictPrefix(String userId, String prefix) {
    if (_account != userId) return;
    for (final key in {
      ..._values.keys,
      ..._pending.keys,
    }.where((key) => key.startsWith(prefix)).toList()) {
      invalidate(userId, key);
      _values.remove(key);
      changes.value = null;
      changes.value = key;
    }
  }

  Future<T?> load<T extends Object>(
    String userId,
    String key,
    Future<T> Function() fetch, {
    required bool Function() mayFetch,
    bool stale = false,
  }) async {
    if (_account != userId || !mayFetch()) return peek<T>(userId, key);
    final existing = peek<T>(userId, key);
    if (existing != null && !stale && _loadedAt.containsKey(key)) {
      return existing;
    }
    final pending = _pending[key];
    if (pending != null) return await pending as T?;
    if ((_failures[key] ?? 0) >= 3 || _attemptedEntry[key] == _entry) {
      return existing;
    }
    _attemptedEntry[key] = _entry;
    final generation = _generation;
    final version = _versions[key] ?? 0;
    final future =
        Future<T>(() async {
          if (!mayFetch() || generation != _generation) {
            throw const ViewReadCancelled();
          }
          return fetch();
        }).then<Object?>(
          (value) {
            if (generation != _generation || version != (_versions[key] ?? 0)) {
              return null;
            }
            publish(userId, key, value);
            return value;
          },
          onError: (Object error, StackTrace stack) {
            if (generation == _generation &&
                version == (_versions[key] ?? 0) &&
                error is! ViewReadCancelled) {
              _failures[key] = (_failures[key] ?? 0) + 1;
              changes.value = null;
              changes.value = key;
            }
            return null;
          },
        );
    _pending[key] = future;
    try {
      return await future as T?;
    } finally {
      if (generation == _generation) _pending.remove(key);
    }
  }
}
