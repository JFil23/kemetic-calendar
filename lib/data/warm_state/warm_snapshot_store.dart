import 'warm_resource_contract.dart';
import 'dart:async';
import 'dart:convert';
import '../account_view_cache.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// A repository supplies the key, JSON codec and coverage boundary. This store
/// never infers domain completeness, fetches on its own, or queues mutations.
class WarmSnapshot {
  const WarmSnapshot(this.data, this.updatedAt);
  final Object? data;
  final DateTime updatedAt;
}

class WarmSnapshotChange {
  const WarmSnapshotChange(this.userId, this.key);
  final String userId, key;
}

class WarmReadCancelled extends ViewReadCancelled {
  const WarmReadCancelled();
}

class WarmAccessDenied implements Exception {
  const WarmAccessDenied();
}

class WarmCacheMiss implements Exception {
  const WarmCacheMiss(this.key);
  final String key;
}

class WarmSnapshotStore {
  WarmSnapshotStore({
    Future<SharedPreferences> Function()? preferences,
    DateTime Function()? now,
    WarmResourceSchema? Function(String)? schemaFor,
    this.maxEntries = 96,
    this.maxBytes = 2 * 1024 * 1024,
  }) : _schemaFor = schemaFor ?? WarmResourceContract.find,
       _preferences = preferences ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now;

  static final instance = WarmSnapshotStore();
  static const _prefix = 'warm_snapshot:v1:';
  final Future<SharedPreferences> Function() _preferences;
  final DateTime Function() _now;
  final int maxEntries, maxBytes;
  final WarmResourceSchema? Function(String) _schemaFor;
  final _values = <String, WarmSnapshot>{};
  final _sizes = <String, int>{};
  final _versions = <String, int>{};
  final _epochs = <String, int>{};
  final _invalidatedPrefixes = <String, Set<String>>{};
  final _flights = <String, Future<WarmSnapshot>>{};
  final _restores = <String, Future<void>>{};
  final _changes = StreamController<WarmSnapshotChange>.broadcast(sync: true);
  Future<void> _writes = Future<void>.value();

  Stream<WarmSnapshotChange> get changes => _changes.stream;
  List<String> recentKeys(String userId, {int limit = 8}) {
    final scope = _scope(userId);
    final keys = _values.keys.where((k) => k.startsWith(scope)).toList()
      ..sort((a, b) => _values[b]!.updatedAt.compareTo(_values[a]!.updatedAt));
    return keys
        .map((key) => Uri.decodeComponent(key.substring(scope.length)))
        .where(
          (key) =>
              key.startsWith('flow.detail.') ||
              key.startsWith('social.post.') ||
              key.startsWith('journal.entry.') ||
              key.startsWith('reflection.') &&
                  key != 'reflection.list' &&
                  !key.startsWith('reflection.activity.') &&
                  !key.startsWith('reflection.source.') ||
              key.startsWith('dm.messages.') ||
              key.startsWith('guidance.') && key != 'guidance.archive',
        )
        .take(limit)
        .toList();
  }

  Future<void> get flushed => _writes;
  String _scope(String userId) => '$_prefix${Uri.encodeComponent(userId)}:';
  String _id(String userId, String key) =>
      '${_scope(userId)}${Uri.encodeComponent(key)}';

  int _priority(String id) {
    final key = Uri.decodeComponent(id.substring(id.lastIndexOf(':') + 1));
    if (key.startsWith('image.')) return -1;
    if ([
      'pages.',
      'rhythm.',
      'social.feed.',
      'commons.',
      'journal.recent.',
      'calendars.',
      'dm.summaries',
    ].any(key.startsWith)) {
      return 1;
    }
    return 0;
  }

  WarmSnapshot? peek(String userId, String key) => _values[_id(userId, key)];

  /// Loads one bounded account working set. Never waits on the network.
  Future<void> restore(String userId) => _restores[userId] ??= _restore(userId);

  Future<void> _restore(String userId) async {
    final epoch = _epochs[userId] ?? 0;
    try {
      final prefs = await _preferences();
      final records = <({String id, String raw, DateTime at, Object? data})>[];
      for (final id in prefs.getKeys().where(
        (k) => k.startsWith(_scope(userId)),
      )) {
        final raw = prefs.getString(id);
        if (raw == null || raw.length > maxBytes) continue;
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          if (json['schema'] != 1 ||
              json['userId'] != userId ||
              !json.containsKey('data')) {
            continue;
          }
          final at = DateTime.parse(json['updatedAt'] as String);
          final resource = Uri.decodeComponent(
            id.substring(_scope(userId).length),
          );
          final schema = _schemaFor(resource) ?? const WarmResourceSchema();
          final data = schema.upgrade(
            json['data'],
            (json['resourceSchema'] as int?) ?? 1,
          );
          records.add((id: id, raw: raw, at: at, data: data));
        } catch (_) {
          // A malformed cache is a miss, never authoritative empty data.
        }
      }
      records.sort((a, b) {
        final priority = _priority(b.id).compareTo(_priority(a.id));
        return priority != 0 ? priority : b.at.compareTo(a.at);
      });
      var bytes = 0, count = 0;
      for (final row in records) {
        if ((_epochs[userId] ?? 0) != epoch) return;
        final resource = Uri.decodeComponent(
          row.id.substring(_scope(userId).length),
        );
        if ((_invalidatedPrefixes[userId] ?? const <String>{}).any(
          resource.startsWith,
        )) {
          continue;
        }
        final size = utf8.encode(row.raw).length;
        if (count >= maxEntries || bytes + size > maxBytes) continue;
        bytes += size;
        count++;
        // A live result or invalidation that raced restoration always wins.
        if (_values.containsKey(row.id) || _versions.containsKey(row.id)) {
          continue;
        }
        _values[row.id] = WarmSnapshot(row.data, row.at);
        _sizes[row.id] = size;
        _changes.add(
          WarmSnapshotChange(
            userId,
            Uri.decodeComponent(row.id.substring(_scope(userId).length)),
          ),
        );
      }
    } catch (_) {
      // Storage being unavailable must not stop the live application.
    }
  }

  Future<Object?> cached(String userId, String key) async {
    await restore(userId);
    final value = peek(userId, key);
    if (value == null) throw WarmCacheMiss(key);
    return value.data;
  }

  /// Refreshes through a repository's passive read. Errors propagate; the last
  /// successful value remains available. A successful null/[] is distinct.
  Future<WarmSnapshot> refresh(
    String userId,
    String key,
    Future<Object?> Function() fetch, {
    required bool Function() isCurrent,
    Duration? maxAge,
  }) {
    final id = _id(userId, key);
    if (!isCurrent()) return Future.error(const WarmReadCancelled());
    final existing = _values[id];
    if (existing != null &&
        maxAge != null &&
        _now().difference(existing.updatedAt) < maxAge &&
        _now().difference(existing.updatedAt) >= Duration.zero) {
      return Future.value(existing);
    }
    final flight = _flights[id];
    if (flight != null) return flight;
    final epoch = _epochs[userId] ?? 0;
    final version = _versions[id] ?? 0;
    late Future<WarmSnapshot> operation;
    operation =
        Future<WarmSnapshot>(() async {
          if (!isCurrent()) throw const WarmReadCancelled();
          final data = await fetch();
          if (!isCurrent() ||
              epoch != (_epochs[userId] ?? 0) ||
              version != (_versions[id] ?? 0)) {
            throw const WarmReadCancelled();
          }
          final value = WarmSnapshot(data, _now());
          final bytes = utf8.encode(jsonEncode(data)).length;
          if (bytes > maxBytes ~/ 2) return value;
          _values[id] = value;
          _sizes[id] = bytes;
          final owned =
              _values.keys.where((k) => k.startsWith(_scope(userId))).toList()
                ..sort((a, b) {
                  final priority = _priority(a).compareTo(_priority(b));
                  return priority != 0
                      ? priority
                      : _values[a]!.updatedAt.compareTo(_values[b]!.updatedAt);
                });
          var total = owned.fold<int>(0, (n, k) => n + (_sizes[k] ?? 0));
          while (owned.isNotEmpty &&
              (owned.length > maxEntries || total > maxBytes)) {
            final oldest = owned.removeAt(0);
            total -= _sizes.remove(oldest) ?? 0;
            _values.remove(oldest);
          }
          _changes.add(WarmSnapshotChange(userId, key));
          _persist(userId, key, value, epoch, version);
          return value;
        }).whenComplete(() {
          if (identical(_flights[id], operation)) _flights.remove(id);
        });
    _flights[id] = operation;
    return operation;
  }

  void _persist(
    String userId,
    String key,
    WarmSnapshot value,
    int epoch,
    int version,
  ) {
    final id = _id(userId, key);
    _writes = _writes.then((_) async {
      if (epoch != (_epochs[userId] ?? 0) || version != (_versions[id] ?? 0)) {
        return;
      }
      try {
        final raw = jsonEncode({
          'schema': 1,
          'resourceSchema':
              (_schemaFor(key) ?? const WarmResourceSchema()).version,
          'userId': userId,
          'updatedAt': value.updatedAt.toIso8601String(),
          'data': value.data,
        });
        final size = utf8.encode(raw).length;
        // Large histories must be paginated by their repository.
        if (size > maxBytes ~/ 2) return;
        final prefs = await _preferences();
        if (epoch != (_epochs[userId] ?? 0) ||
            version != (_versions[id] ?? 0)) {
          return;
        }
        await prefs.setString(id, raw);
        _sizes[id] = size;
        // Include rows not restored into memory so old disk entries cannot grow
        // without bound across process restarts.
        final owned = prefs
            .getKeys()
            .where((k) => k.startsWith(_scope(userId)))
            .toList();
        final dates = <String, String>{};
        final sizes = <String, int>{};
        for (final key in owned) {
          final raw = prefs.getString(key) ?? '';
          sizes[key] = utf8.encode(raw).length;
          try {
            dates[key] = (jsonDecode(raw) as Map)['updatedAt'] as String;
          } catch (_) {
            dates[key] = '';
          }
        }
        owned.sort((a, b) {
          final priority = _priority(a).compareTo(_priority(b));
          return priority != 0 ? priority : dates[a]!.compareTo(dates[b]!);
        });
        var total = sizes.values.fold<int>(0, (a, b) => a + b);
        while (owned.isNotEmpty &&
            (owned.length > maxEntries || total > maxBytes)) {
          final oldest = owned.removeAt(0);
          total -= sizes[oldest] ?? 0;
          _sizes.remove(oldest);
          _values.remove(oldest);
          await prefs.remove(oldest);
        }
      } catch (_) {
        // Publication already succeeded. Persistence cannot veto it.
      }
    });
  }

  /// Invalidating also fences in-flight responses and persisted values. The
  /// caller decides whether currently displayed content can remain on screen.
  void invalidate(String userId, {String prefix = ''}) {
    final scope = _scope(userId);
    final ids = {..._values.keys, ..._flights.keys}
        .where(
          (id) =>
              id.startsWith(scope) &&
              Uri.decodeComponent(
                id.substring(scope.length),
              ).startsWith(prefix),
        )
        .toList();
    for (final id in ids) {
      _versions[id] = (_versions[id] ?? 0) + 1;
      _values.remove(id);
      _sizes.remove(id);
      _flights.remove(id);
    }
    // Fence matching disk rows, including rows not yet restored. Unrelated
    // resources keep refreshing; an account departure fences everything.
    (_invalidatedPrefixes[userId] ??= <String>{}).add(prefix);
    if (prefix.isEmpty) _epochs[userId] = (_epochs[userId] ?? 0) + 1;
    _writes = _writes.then((_) async {
      try {
        final prefs = await _preferences();
        for (final id in prefs.getKeys().where(
          (id) =>
              id.startsWith(scope) &&
              Uri.decodeComponent(
                id.substring(scope.length),
              ).startsWith(prefix),
        )) {
          await prefs.remove(id);
        }
      } catch (_) {}
    });
  }

  Future<void> forgetAccount(String userId) async {
    invalidate(userId);
    _restores.remove(userId);
    await _writes;
    _invalidatedPrefixes.remove(userId);
  }
}
