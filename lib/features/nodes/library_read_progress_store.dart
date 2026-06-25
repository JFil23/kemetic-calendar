import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'library_read_state.dart';

abstract class LibraryReadProgressRemote {
  Future<List<LibraryNodeProgress>> fetchAll({required String userId});

  Future<LibraryNodeProgress?> upsert({
    required String userId,
    required LibraryNodeProgress progress,
  });
}

class SupabaseLibraryReadProgressRemote implements LibraryReadProgressRemote {
  SupabaseLibraryReadProgressRemote(this._client);

  static const String tableName = 'user_library_node_progress';
  static const String _select =
      'node_id, progress_percent, last_scroll_offset, last_read_at, '
      'completed_at, bookmarked_at, bookmark_scroll_offset, created_at, '
      'updated_at';

  final SupabaseClient _client;

  @override
  Future<List<LibraryNodeProgress>> fetchAll({required String userId}) async {
    final rows = await _client
        .from(tableName)
        .select(_select)
        .eq('user_id', userId)
        .timeout(const Duration(seconds: 3));
    return _progressListFromRows(rows);
  }

  @override
  Future<LibraryNodeProgress?> upsert({
    required String userId,
    required LibraryNodeProgress progress,
  }) async {
    final row = await _client
        .from(tableName)
        .upsert(<String, Object?>{
          'user_id': userId,
          'node_id': progress.normalizedNodeId,
          'progress_percent': progress.normalizedProgressPercent / 100,
          'last_scroll_offset': progress.lastScrollOffset < 0
              ? 0
              : progress.lastScrollOffset,
          'last_read_at': progress.lastReadAt?.toUtc().toIso8601String(),
          'completed_at': progress.completedAt?.toUtc().toIso8601String(),
          'bookmarked_at': progress.bookmarkedAt?.toUtc().toIso8601String(),
          'bookmark_scroll_offset': progress.bookmarkScrollOffset,
        }, onConflict: 'user_id,node_id')
        .select(_select)
        .maybeSingle()
        .timeout(const Duration(seconds: 3));
    return _progressFromRow(row);
  }

  static List<LibraryNodeProgress> _progressListFromRows(Object? rows) {
    if (rows is! List) return const <LibraryNodeProgress>[];
    return rows
        .map(_progressFromRow)
        .whereType<LibraryNodeProgress>()
        .toList(growable: false);
  }

  static LibraryNodeProgress? _progressFromRow(Object? raw) {
    if (raw is! Map) return null;
    final nodeId = _stringValue(raw['node_id']);
    if (nodeId == null || normalizeLibraryNodeId(nodeId).isEmpty) return null;
    final remoteFraction = _doubleValue(raw['progress_percent']) ?? 0;
    return LibraryNodeProgress(
      nodeId: nodeId,
      progressPercent: (remoteFraction * 100).clamp(0, 100).toDouble(),
      lastScrollOffset: _doubleValue(raw['last_scroll_offset']) ?? 0,
      lastReadAt: _dateValue(raw['last_read_at']),
      completedAt: _dateValue(raw['completed_at']),
      bookmarkedAt: _dateValue(raw['bookmarked_at']),
      bookmarkScrollOffset: _doubleValue(raw['bookmark_scroll_offset']),
      createdAt: _dateValue(raw['created_at']),
      updatedAt: _dateValue(raw['updated_at']),
    );
  }
}

typedef LibraryCurrentUserIdProvider = String? Function();

class LibraryReadProgressStore {
  LibraryReadProgressStore({
    SharedPreferences? prefs,
    DateTime Function()? now,
    LibraryCurrentUserIdProvider? currentUserIdProvider,
    LibraryReadProgressRemote? remote,
  }) : _prefs = prefs,
       _now = now ?? DateTime.now,
       _currentUserIdProvider = currentUserIdProvider,
       _remote = remote ?? _tryCreateRemote();

  static const String _storageKeyPrefix = 'library_node_read_progress_v2';
  static const String _localFallbackScope = 'local';

  final SharedPreferences? _prefs;
  final DateTime Function() _now;
  final LibraryCurrentUserIdProvider? _currentUserIdProvider;
  final LibraryReadProgressRemote? _remote;
  Future<void> _pendingMutation = Future<void>.value();

  Future<LibraryReadSnapshot> readSnapshot() async {
    await _pendingMutation;
    final userId = _currentUserId();
    final progress = await _readMergedProgress(userId: userId);
    return LibraryReadSnapshot(progressByNodeId: progress);
  }

  Future<LibraryNodeProgress?> readNodeProgress(String nodeId) async {
    final snapshot = await readSnapshot();
    return snapshot.progressFor(nodeId);
  }

  Future<LibraryNodeProgress> recordOpened(String nodeId) {
    return _mutateProgress(
      nodeId: nodeId,
      createProgress: (normalizedNodeId, previous, now) => LibraryNodeProgress(
        nodeId: normalizedNodeId,
        progressPercent: previous?.progressPercent ?? 0,
        lastScrollOffset: previous?.lastScrollOffset ?? 0,
        openedAt: previous?.openedAt ?? now,
        lastReadAt: now,
        completedAt: previous?.completedAt,
        bookmarkedAt: previous?.bookmarkedAt,
        bookmarkScrollOffset: previous?.bookmarkScrollOffset,
        createdAt: previous?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  Future<LibraryNodeProgress> saveScrollProgress({
    required String nodeId,
    required double progressPercent,
    required double lastScrollOffset,
  }) {
    return _mutateProgress(
      nodeId: nodeId,
      createProgress: (normalizedNodeId, previous, now) {
        final completedAt =
            previous?.completedAt ??
            (progressPercent >= kLibraryCompletionProgressPercent ? now : null);
        return LibraryNodeProgress(
          nodeId: normalizedNodeId,
          progressPercent: completedAt == null
              ? progressPercent.clamp(0, 100).toDouble()
              : 100,
          lastScrollOffset: lastScrollOffset < 0 ? 0 : lastScrollOffset,
          openedAt: previous?.openedAt ?? now,
          lastReadAt: now,
          completedAt: completedAt,
          bookmarkedAt: previous?.bookmarkedAt,
          bookmarkScrollOffset: previous?.bookmarkScrollOffset,
          createdAt: previous?.createdAt ?? now,
          updatedAt: now,
        );
      },
    );
  }

  Future<LibraryNodeProgress> setBookmark({
    required String nodeId,
    required double progressPercent,
    required double scrollOffset,
  }) {
    return _mutateProgress(
      nodeId: nodeId,
      createProgress: (normalizedNodeId, previous, now) => LibraryNodeProgress(
        nodeId: normalizedNodeId,
        progressPercent: progressPercent.clamp(0, 100).toDouble(),
        lastScrollOffset: scrollOffset < 0 ? 0 : scrollOffset,
        openedAt: previous?.openedAt ?? now,
        lastReadAt: now,
        completedAt: previous?.completedAt,
        bookmarkedAt: now,
        bookmarkScrollOffset: scrollOffset < 0 ? 0 : scrollOffset,
        createdAt: previous?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  Future<LibraryNodeProgress> clearBookmark(String nodeId) {
    return _mutateProgress(
      nodeId: nodeId,
      createProgress: (normalizedNodeId, previous, now) => LibraryNodeProgress(
        nodeId: normalizedNodeId,
        progressPercent: previous?.progressPercent ?? 0,
        lastScrollOffset: previous?.lastScrollOffset ?? 0,
        openedAt: previous?.openedAt ?? now,
        lastReadAt: now,
        completedAt: previous?.completedAt,
        createdAt: previous?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  Future<LibraryNodeProgress> _mutateProgress({
    required String nodeId,
    required LibraryNodeProgress Function(
      String normalizedNodeId,
      LibraryNodeProgress? previous,
      DateTime now,
    )
    createProgress,
  }) {
    final operation = _pendingMutation.then((_) async {
      final userId = _currentUserId();
      final normalizedNodeId = _validatedNodeId(nodeId);
      final cacheProgress = await _readCacheProgress(userId);
      final previous = cacheProgress[normalizedNodeId];
      final localUpdate = createProgress(normalizedNodeId, previous, _now());
      final mergedLocal = localUpdate;
      cacheProgress[normalizedNodeId] = mergedLocal;
      await _writeCacheProgress(userId, cacheProgress);

      if (userId == null || _remote == null) {
        return mergedLocal;
      }

      final remoteProgress = await _syncProgress(
        userId: userId,
        progress: mergedLocal,
      );
      final resolved = mergeLibraryNodeProgress(mergedLocal, remoteProgress)!;
      cacheProgress[normalizedNodeId] = resolved;
      await _writeCacheProgress(userId, cacheProgress);
      return resolved;
    });
    _pendingMutation = operation.then<void>((_) {}, onError: (_) {});
    return operation;
  }

  Future<Map<String, LibraryNodeProgress>> _readMergedProgress({
    required String? userId,
  }) async {
    final userCache = await _readCacheProgress(userId);
    if (userId == null) {
      return userCache;
    }

    final localFallback = await _readCacheProgress(null);
    var merged = mergeLibraryProgressMaps(<Map<String, LibraryNodeProgress>>[
      userCache,
      localFallback,
    ]);

    final remoteProgress = await _fetchRemoteProgress(userId);
    if (remoteProgress != null) {
      merged = mergeLibraryProgressMaps(<Map<String, LibraryNodeProgress>>[
        merged,
        remoteProgress,
      ]);
    }

    await _writeCacheProgress(userId, merged);
    if (localFallback.isNotEmpty) {
      await _syncAll(userId: userId, progressByNodeId: merged);
      await _clearCacheProgress(null);
    }
    return merged;
  }

  Future<Map<String, LibraryNodeProgress>?> _fetchRemoteProgress(
    String userId,
  ) async {
    final remote = _remote;
    if (remote == null) return null;
    try {
      final rows = await remote.fetchAll(userId: userId);
      return <String, LibraryNodeProgress>{
        for (final progress in rows) progress.normalizedNodeId: progress,
      };
    } catch (error) {
      debugPrint('Library progress remote fetch failed: $error');
      return null;
    }
  }

  Future<LibraryNodeProgress?> _syncProgress({
    required String userId,
    required LibraryNodeProgress progress,
  }) async {
    final remote = _remote;
    if (remote == null) return null;
    try {
      return await remote.upsert(userId: userId, progress: progress);
    } catch (error) {
      debugPrint('Library progress remote upsert failed: $error');
      return null;
    }
  }

  Future<void> _syncAll({
    required String userId,
    required Map<String, LibraryNodeProgress> progressByNodeId,
  }) async {
    for (final progress in progressByNodeId.values) {
      await _syncProgress(userId: userId, progress: progress);
    }
  }

  Future<Map<String, LibraryNodeProgress>> _readCacheProgress(
    String? userId,
  ) async {
    final prefs = await _resolvedPrefs();
    final raw = prefs.getString(_storageKeyForUser(userId));
    if (raw == null || raw.trim().isEmpty) {
      return <String, LibraryNodeProgress>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, LibraryNodeProgress>{};
      final progress = <String, LibraryNodeProgress>{};
      for (final entry in decoded.entries) {
        final nodeProgress = LibraryNodeProgress.fromJson(entry.value);
        if (nodeProgress == null) continue;
        progress[nodeProgress.normalizedNodeId] = nodeProgress;
      }
      return progress;
    } on FormatException catch (error) {
      debugPrint('Ignoring malformed library progress cache: $error');
      return <String, LibraryNodeProgress>{};
    }
  }

  Future<void> _writeCacheProgress(
    String? userId,
    Map<String, LibraryNodeProgress> progress,
  ) async {
    final prefs = await _resolvedPrefs();
    final payload = <String, Object?>{
      for (final entry in progress.entries) entry.key: entry.value.toJson(),
    };
    await prefs.setString(_storageKeyForUser(userId), jsonEncode(payload));
  }

  Future<void> _clearCacheProgress(String? userId) async {
    final prefs = await _resolvedPrefs();
    await prefs.remove(_storageKeyForUser(userId));
  }

  String _storageKeyForUser(String? userId) {
    final scope = _cacheScopeForUser(userId);
    return '$_storageKeyPrefix:$scope';
  }

  String _cacheScopeForUser(String? userId) {
    final normalized = userId?.trim();
    if (normalized == null || normalized.isEmpty) return _localFallbackScope;
    return normalized;
  }

  String _validatedNodeId(String nodeId) {
    final normalizedNodeId = normalizeLibraryNodeId(nodeId);
    if (normalizedNodeId.isEmpty) {
      throw ArgumentError.value(nodeId, 'nodeId', 'must not be empty');
    }
    return normalizedNodeId;
  }

  String? _currentUserId() {
    final provided = _currentUserIdProvider?.call()?.trim();
    if (provided != null && provided.isNotEmpty) return provided;
    return _tryCurrentSupabaseUserId();
  }

  Future<SharedPreferences> _resolvedPrefs() async {
    return _prefs ?? SharedPreferences.getInstance();
  }

  static LibraryReadProgressRemote? _tryCreateRemote() {
    final client = _trySupabaseClient();
    return client == null ? null : SupabaseLibraryReadProgressRemote(client);
  }

  static String? _tryCurrentSupabaseUserId() {
    return _trySupabaseClient()?.auth.currentUser?.id.trim();
  }

  static SupabaseClient? _trySupabaseClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}

String? _stringValue(Object? raw) {
  if (raw is String) return raw;
  return null;
}

double? _doubleValue(Object? raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw);
  return null;
}

DateTime? _dateValue(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}
