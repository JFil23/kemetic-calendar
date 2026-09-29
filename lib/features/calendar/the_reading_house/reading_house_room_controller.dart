import 'dart:async';
import '../../../../data/warm_state/warm_snapshot_store.dart';

import 'package:flutter/foundation.dart';

import 'reading_house_room_repository.dart';

enum ReadingHouseRoomStatus { idle, loading, ready, error }

class ReadingHouseRoomController extends ChangeNotifier {
  ReadingHouseRoomController({
    required ReadingHouseRoomDataSource dataSource,
    required this.identity,
  }) : _dataSource = dataSource,
       _account = dataSource.currentUserId {
    if (dataSource is CachedReadingHouseRoomDataSource) {
      _applyCached(
        (dataSource as CachedReadingHouseRoomDataSource).cachedRoom(identity),
      );
    }
  }

  final ReadingHouseRoomDataSource _dataSource;
  final String? _account;
  bool _hasSnapshot = false;
  bool get _current => !_disposed && _dataSource.currentUserId == _account;

  void _applyCached(ReadingHouseRoomSnapshot? cached) {
    if (!_current || cached == null || _hasSnapshot) return;
    messages = cached.messages;
    summary = _summaryFor(cached.summaries);
    hasOlder = messages.length == 50;
    _hasSnapshot = true;
    status = ReadingHouseRoomStatus.ready;
  }

  void _failed(Object nextError) {
    if (!_current) return;
    error = nextError;
    if (nextError is WarmAccessDenied) {
      messages = const [];
      summary = null;
      _hasSnapshot = false;
    }
    status = _hasSnapshot
        ? ReadingHouseRoomStatus.ready
        : ReadingHouseRoomStatus.error;
    notifyListeners();
  }

  final ReadingHouseRoomIdentity identity;

  ReadingHouseRoomStatus status = ReadingHouseRoomStatus.idle;
  ReadingHouseRoomSummary? summary;
  List<ReadingHouseRoomMessage> messages = const <ReadingHouseRoomMessage>[];
  Object? error;
  bool hasOlder = true;
  bool loadingOlder = false;
  bool sending = false;
  bool followingLatest = true;
  int newMessageCount = 0;

  StreamSubscription<void>? _activitySubscription;
  bool _refreshing = false;
  bool _refreshQueued = false;
  bool _disposed = false;

  Future<void> start() async {
    if (_activitySubscription != null || _disposed) return;
    if (!_hasSnapshot) status = ReadingHouseRoomStatus.loading;
    notifyListeners();
    _activitySubscription = _dataSource
        .watchRoom(identity)
        .listen(
          (_) => unawaited(refresh()),
          onError: (Object nextError, StackTrace stackTrace) {
            _failed(nextError);
          },
        );
    final source = _dataSource;
    if (!_hasSnapshot && source is CachedReadingHouseRoomDataSource) {
      unawaited(
        (source as CachedReadingHouseRoomDataSource)
            .restoreRoom(identity)
            .then((snapshot) {
              if (!_current || _hasSnapshot) return;
              _applyCached(snapshot);
              if (_hasSnapshot) notifyListeners();
            })
            .catchError((Object _) {}),
      );
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (!_current) return;
    if (_refreshing) {
      _refreshQueued = true;
      return;
    }
    _refreshing = true;
    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        _dataSource.listMessages(identity: identity, limit: 50),
        _dataSource.listSummaries(),
      ]);
      if (!_current) return;
      final nextMessages = results[0] as List<ReadingHouseRoomMessage>;
      final nextSummaries = results[1] as List<ReadingHouseRoomSummary>;
      final previousIds = messages.map((message) => message.id).toSet();
      final added = nextMessages
          .where(
            (message) =>
                !previousIds.contains(message.id) &&
                message.authorId != _dataSource.currentUserId,
          )
          .length;
      messages = nextMessages;
      summary = _summaryFor(nextSummaries);
      hasOlder = nextMessages.length == 50;
      error = null;
      _hasSnapshot = true;
      status = ReadingHouseRoomStatus.ready;
      if (!followingLatest && previousIds.isNotEmpty) {
        newMessageCount += added;
      } else {
        newMessageCount = 0;
        unawaited(_markLatestRead());
      }
      notifyListeners();
    } catch (nextError) {
      _failed(nextError);
    } finally {
      _refreshing = false;
      if (_refreshQueued && !_disposed) {
        _refreshQueued = false;
        unawaited(refresh());
      }
    }
  }

  Future<void> loadOlder() async {
    if (!_current || loadingOlder || !hasOlder || messages.isEmpty) return;
    loadingOlder = true;
    notifyListeners();
    try {
      final older = await _dataSource.listMessages(
        identity: identity,
        before: messages.first.createdAt,
        limit: 50,
      );
      if (!_current) return;
      final byId = <String, ReadingHouseRoomMessage>{
        for (final message in older) message.id: message,
        for (final message in messages) message.id: message,
      };
      final combined = byId.values.toList()
        ..sort((a, b) {
          final created = a.createdAt.compareTo(b.createdAt);
          return created != 0 ? created : a.id.compareTo(b.id);
        });
      messages = List<ReadingHouseRoomMessage>.unmodifiable(combined);
      hasOlder = older.length == 50;
      error = null;
    } catch (nextError) {
      if (!_disposed) error = nextError;
    } finally {
      if (!_disposed) {
        loadingOlder = false;
        notifyListeners();
      }
    }
  }

  Future<void> send(String body) async {
    if (!_current ||
        sending ||
        summary == null ||
        summary!.locked ||
        summary!.ended) {
      return;
    }
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    sending = true;
    notifyListeners();
    try {
      await _dataSource.sendMessage(identity: identity, body: trimmed);
      followingLatest = true;
      newMessageCount = 0;
      await refresh();
    } catch (nextError) {
      if (!_disposed) error = nextError;
      rethrow;
    } finally {
      if (!_disposed) {
        sending = false;
        notifyListeners();
      }
    }
  }

  Future<void> updateMessage(String messageId, String body) async {
    if (!_current || sending || summary?.ended == true) return;
    sending = true;
    notifyListeners();
    try {
      await _dataSource.updateMessage(
        identity: identity,
        messageId: messageId,
        body: body,
      );
      await refresh();
    } catch (nextError) {
      if (!_disposed) error = nextError;
      rethrow;
    } finally {
      if (!_disposed) {
        sending = false;
        notifyListeners();
      }
    }
  }

  Future<void> deleteMessage(String messageId) async {
    if (!_current || sending || summary?.ended == true) return;
    sending = true;
    notifyListeners();
    try {
      await _dataSource.deleteMessage(identity: identity, messageId: messageId);
      await refresh();
    } catch (nextError) {
      if (!_disposed) error = nextError;
      rethrow;
    } finally {
      if (!_disposed) {
        sending = false;
        notifyListeners();
      }
    }
  }

  void setFollowingLatest(bool value) {
    if (!_current || followingLatest == value) return;
    followingLatest = value;
    if (value) {
      newMessageCount = 0;
      unawaited(_markLatestRead());
    }
    notifyListeners();
  }

  Future<void> jumpToLatest() async {
    setFollowingLatest(true);
    await _markLatestRead();
  }

  ReadingHouseRoomSummary? _summaryFor(
    List<ReadingHouseRoomSummary> summaries,
  ) {
    for (final candidate in summaries) {
      if (candidate.identity == identity) return candidate;
    }
    return null;
  }

  Future<void> _markLatestRead() async {
    if (!_current || messages.isEmpty) return;
    final latest = messages.last.createdAt;
    try {
      await _dataSource.markRead(identity: identity, through: latest);
    } catch (nextError) {
      if (kDebugMode) {
        debugPrint('[ReadingHouseRoomController] mark read failed: $nextError');
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_activitySubscription?.cancel());
    super.dispose();
  }
}
