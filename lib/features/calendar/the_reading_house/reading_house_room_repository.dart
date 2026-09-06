import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@immutable
class ReadingHouseRoomIdentity {
  const ReadingHouseRoomIdentity({
    required this.calendarId,
    required this.flowId,
  });

  final String calendarId;
  final int flowId;

  bool get isValid => calendarId.trim().isNotEmpty && flowId > 0;

  @override
  bool operator ==(Object other) =>
      other is ReadingHouseRoomIdentity &&
      other.calendarId == calendarId &&
      other.flowId == flowId;

  @override
  int get hashCode => Object.hash(calendarId, flowId);
}

@immutable
class ReadingHouseRoomMember {
  const ReadingHouseRoomMember({
    required this.userId,
    required this.role,
    this.displayName,
    this.handle,
    this.avatarUrl,
    this.avatarGlyphs,
  });

  final String userId;
  final String role;
  final String? displayName;
  final String? handle;
  final String? avatarUrl;
  final String? avatarGlyphs;

  factory ReadingHouseRoomMember.fromJson(Map<String, dynamic> json) {
    return ReadingHouseRoomMember(
      userId: _cleanString(json['user_id']) ?? '',
      role: _cleanString(json['role']) ?? 'member',
      displayName: _cleanString(json['display_name']),
      handle: _cleanString(json['handle']),
      avatarUrl: _cleanString(json['avatar_url']),
      avatarGlyphs: _cleanString(json['avatar_glyphs']),
    );
  }
}

@immutable
class ReadingHouseRoomSummary {
  const ReadingHouseRoomSummary({
    required this.identity,
    required this.title,
    required this.members,
    required this.memberCount,
    required this.unreadCount,
    required this.active,
    required this.locked,
    required this.ended,
    this.latestMessage,
    this.latestMessageAt,
    this.latestAuthorId,
    this.latestAuthorDisplayName,
    this.latestAuthorHandle,
    this.lastReadAt,
  });

  final ReadingHouseRoomIdentity identity;
  final String title;
  final List<ReadingHouseRoomMember> members;
  final int memberCount;
  final int unreadCount;
  final bool active;
  final bool locked;
  final bool ended;
  final String? latestMessage;
  final DateTime? latestMessageAt;
  final String? latestAuthorId;
  final String? latestAuthorDisplayName;
  final String? latestAuthorHandle;
  final DateTime? lastReadAt;

  factory ReadingHouseRoomSummary.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'];
    final members = rawMembers is List
        ? rawMembers
              .whereType<Map>()
              .map(
                (member) => ReadingHouseRoomMember.fromJson(
                  member.cast<String, dynamic>(),
                ),
              )
              .where((member) => member.userId.isNotEmpty)
              .toList(growable: false)
        : const <ReadingHouseRoomMember>[];
    return ReadingHouseRoomSummary(
      identity: ReadingHouseRoomIdentity(
        calendarId: _cleanString(json['calendar_id']) ?? '',
        flowId: _parseInt(json['flow_id']) ?? 0,
      ),
      title: _cleanString(json['house_title']) ?? 'Reading House',
      members: members,
      memberCount: _parseInt(json['member_count']) ?? members.length,
      unreadCount: _parseInt(json['unread_count']) ?? 0,
      active: json['active'] == true,
      locked: json['locked'] == true,
      ended: json['ended'] == true,
      latestMessage: _cleanString(json['latest_message']),
      latestMessageAt: _parseDate(json['latest_message_at']),
      latestAuthorId: _cleanString(json['latest_author_id']),
      latestAuthorDisplayName: _cleanString(json['latest_author_display_name']),
      latestAuthorHandle: _cleanString(json['latest_author_handle']),
      lastReadAt: _parseDate(json['last_read_at']),
    );
  }
}

@immutable
class ReadingHouseRoomMessage {
  const ReadingHouseRoomMessage({
    required this.id,
    required this.identity,
    required this.authorId,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final ReadingHouseRoomIdentity identity;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ReadingHouseRoomMessage.fromJson(Map<String, dynamic> json) {
    final createdAt =
        _parseDate(json['created_at']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return ReadingHouseRoomMessage(
      id: _cleanString(json['id']) ?? '',
      identity: ReadingHouseRoomIdentity(
        calendarId: _cleanString(json['calendar_id']) ?? '',
        flowId: _parseInt(json['flow_id']) ?? 0,
      ),
      authorId: _cleanString(json['author_id']) ?? '',
      body: _cleanString(json['body']) ?? '',
      createdAt: createdAt,
      updatedAt: _parseDate(json['updated_at']) ?? createdAt,
    );
  }
}

abstract interface class ReadingHouseRoomDataSource {
  String? get currentUserId;

  Future<List<ReadingHouseRoomSummary>> listSummaries();

  Future<List<ReadingHouseRoomMessage>> listMessages({
    required ReadingHouseRoomIdentity identity,
    DateTime? before,
    int limit,
  });

  Future<void> sendMessage({
    required ReadingHouseRoomIdentity identity,
    required String body,
  });

  Future<void> updateMessage({
    required ReadingHouseRoomIdentity identity,
    required String messageId,
    required String body,
  });

  Future<void> deleteMessage({
    required ReadingHouseRoomIdentity identity,
    required String messageId,
  });

  Future<DateTime> markRead({
    required ReadingHouseRoomIdentity identity,
    required DateTime through,
  });

  Stream<void> watchRoom(ReadingHouseRoomIdentity identity);

  Stream<List<ReadingHouseRoomSummary>> watchSummaries();
}

class SupabaseReadingHouseRoomRepository implements ReadingHouseRoomDataSource {
  SupabaseReadingHouseRoomRepository(this._client);

  final SupabaseClient _client;
  static int _channelSerial = 0;
  static const List<String> _publishedRoomActivityTables = <String>[
    'reading_house_chat_messages',
    'reading_house_shared_fragments',
    'reading_house_fragment_replies',
    'reading_house_announcements',
  ];
  static const List<String> _publishedRoomSummaryTables = <String>[
    'reading_house_chat_messages',
  ];

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<List<ReadingHouseRoomSummary>> listSummaries() async {
    if (currentUserId == null) return const <ReadingHouseRoomSummary>[];
    final rows = await _client
        .from('reading_house_room_summaries')
        .select()
        .order('ended', ascending: true)
        .order('latest_message_at', ascending: false, nullsFirst: false);
    return (rows as List)
        .whereType<Map>()
        .map(
          (row) =>
              ReadingHouseRoomSummary.fromJson(row.cast<String, dynamic>()),
        )
        .where((summary) => summary.identity.isValid)
        .toList(growable: false);
  }

  @override
  Future<List<ReadingHouseRoomMessage>> listMessages({
    required ReadingHouseRoomIdentity identity,
    DateTime? before,
    int limit = 50,
  }) async {
    _requireIdentity(identity);
    final boundedLimit = limit.clamp(1, 100);
    var query = _client
        .from('reading_house_chat_messages')
        .select()
        .eq('calendar_id', identity.calendarId.trim())
        .eq('flow_id', identity.flowId)
        .isFilter('deleted_at', null);
    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }
    final rows = await query
        .order('created_at', ascending: false)
        .limit(boundedLimit);
    final messages =
        (rows as List)
            .whereType<Map>()
            .map(
              (row) =>
                  ReadingHouseRoomMessage.fromJson(row.cast<String, dynamic>()),
            )
            .where(
              (message) =>
                  message.id.isNotEmpty &&
                  message.body.isNotEmpty &&
                  message.identity == identity,
            )
            .toList(growable: true)
          ..sort((a, b) {
            final created = a.createdAt.compareTo(b.createdAt);
            return created != 0 ? created : a.id.compareTo(b.id);
          });
    return List<ReadingHouseRoomMessage>.unmodifiable(messages);
  }

  @override
  Future<void> sendMessage({
    required ReadingHouseRoomIdentity identity,
    required String body,
  }) async {
    _requireIdentity(identity);
    final trimmed = body.trim();
    if (trimmed.isEmpty || trimmed.length > 4000) {
      throw ArgumentError.value(body, 'body', 'Enter 1–4000 characters.');
    }
    await _client.rpc(
      'create_reading_house_chat_message',
      params: <String, dynamic>{
        'p_calendar_id': identity.calendarId.trim(),
        'p_flow_id': identity.flowId,
        'p_body': trimmed,
      },
    );
  }

  @override
  Future<void> updateMessage({
    required ReadingHouseRoomIdentity identity,
    required String messageId,
    required String body,
  }) async {
    _requireIdentity(identity);
    final trimmedId = messageId.trim();
    final trimmedBody = body.trim();
    if (trimmedId.isEmpty) {
      throw ArgumentError.value(messageId, 'messageId', 'Message required.');
    }
    if (trimmedBody.isEmpty || trimmedBody.length > 4000) {
      throw ArgumentError.value(body, 'body', 'Enter 1–4000 characters.');
    }
    await _client.rpc(
      'update_reading_house_chat_message',
      params: <String, dynamic>{
        'p_message_id': trimmedId,
        'p_body': trimmedBody,
      },
    );
  }

  @override
  Future<void> deleteMessage({
    required ReadingHouseRoomIdentity identity,
    required String messageId,
  }) async {
    _requireIdentity(identity);
    final trimmedId = messageId.trim();
    if (trimmedId.isEmpty) {
      throw ArgumentError.value(messageId, 'messageId', 'Message required.');
    }
    await _client.rpc(
      'delete_reading_house_chat_message',
      params: <String, dynamic>{'p_message_id': trimmedId},
    );
  }

  @override
  Future<DateTime> markRead({
    required ReadingHouseRoomIdentity identity,
    required DateTime through,
  }) async {
    _requireIdentity(identity);
    final response = await _client.rpc(
      'mark_reading_house_room_read',
      params: <String, dynamic>{
        'p_calendar_id': identity.calendarId.trim(),
        'p_flow_id': identity.flowId,
        'p_last_read_at': through.toUtc().toIso8601String(),
      },
    );
    return _parseDate(response) ?? through.toUtc();
  }

  @override
  Stream<void> watchRoom(ReadingHouseRoomIdentity identity) {
    _requireIdentity(identity);
    final controller = StreamController<void>();
    Timer? debounce;

    void emit() {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 120), () {
        if (!controller.isClosed) controller.add(null);
      });
    }

    final channelName =
        'reading_house_room_${identity.flowId}_${++_channelSerial}';
    final channel = _subscribeToRoomActivity(
      channelName: channelName,
      identity: identity,
      tables: _publishedRoomActivityTables,
      onActivity: emit,
      onStatus: (status, error) {
        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
          case RealtimeSubscribeStatus.channelError:
          case RealtimeSubscribeStatus.timedOut:
            emit();
            break;
          case RealtimeSubscribeStatus.closed:
            break;
        }
      },
    );

    controller.onCancel = () async {
      debounce?.cancel();
      await channel.unsubscribe();
      await controller.close();
    };
    return controller.stream;
  }

  @override
  Stream<List<ReadingHouseRoomSummary>> watchSummaries() {
    if (currentUserId == null) {
      return Stream<List<ReadingHouseRoomSummary>>.value(
        const <ReadingHouseRoomSummary>[],
      );
    }
    final controller = StreamController<List<ReadingHouseRoomSummary>>();
    Timer? debounce;
    bool refreshing = false;
    bool queued = false;
    List<ReadingHouseRoomSummary> last = const <ReadingHouseRoomSummary>[];
    final roomChannels = <ReadingHouseRoomIdentity, RealtimeChannel>{};
    late final Future<void> Function() refresh;

    void scheduleRefresh() {
      debounce?.cancel();
      debounce = Timer(
        const Duration(milliseconds: 120),
        () => unawaited(refresh()),
      );
    }

    Future<void> reconcileRoomChannels(
      List<ReadingHouseRoomSummary> summaries,
    ) async {
      final desired = summaries.map((summary) => summary.identity).toSet();
      final removed = roomChannels.keys
          .where((identity) => !desired.contains(identity))
          .toList(growable: false);
      for (final identity in removed) {
        await roomChannels.remove(identity)?.unsubscribe();
      }
      for (final identity in desired) {
        if (roomChannels.containsKey(identity) || controller.isClosed) {
          continue;
        }
        final channel = _subscribeToRoomActivity(
          channelName:
              'reading_house_summary_${identity.flowId}_${++_channelSerial}',
          identity: identity,
          tables: _publishedRoomSummaryTables,
          onActivity: scheduleRefresh,
          onStatus: (status, error) {
            if (status == RealtimeSubscribeStatus.channelError ||
                status == RealtimeSubscribeStatus.timedOut) {
              scheduleRefresh();
            }
          },
        );
        roomChannels[identity] = channel;
      }
    }

    refresh = () async {
      if (refreshing) {
        queued = true;
        return;
      }
      refreshing = true;
      try {
        last = await listSummaries();
        await reconcileRoomChannels(last);
        if (!controller.isClosed) controller.add(last);
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('[ReadingHouseRooms] summary refresh failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
        if (!controller.isClosed) controller.add(last);
      } finally {
        refreshing = false;
        if (queued) {
          queued = false;
          unawaited(refresh());
        }
      }
    };

    unawaited(refresh());
    controller.onCancel = () async {
      debounce?.cancel();
      await Future.wait<void>(
        roomChannels.values.map((channel) => channel.unsubscribe()),
      );
      await controller.close();
    };
    return controller.stream;
  }

  RealtimeChannel _subscribeToRoomActivity({
    required String channelName,
    required ReadingHouseRoomIdentity identity,
    required Iterable<String> tables,
    required void Function() onActivity,
    required void Function(RealtimeSubscribeStatus status, Object? error)
    onStatus,
  }) {
    final calendarId = identity.calendarId.trim();
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'flow_id',
      value: identity.flowId,
    );
    final channel = _client.channel(channelName);

    void verifyAndRefresh(PostgresChangePayload payload) {
      final row = payload.newRecord.isNotEmpty
          ? payload.newRecord
          : payload.oldRecord;
      if (_cleanString(row['calendar_id']) == calendarId &&
          _parseInt(row['flow_id']) == identity.flowId) {
        onActivity();
      }
    }

    for (final table in tables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: filter,
        callback: verifyAndRefresh,
      );
    }
    channel.subscribe((status, [error]) => onStatus(status, error));
    return channel;
  }

  void _requireIdentity(ReadingHouseRoomIdentity identity) {
    if (!identity.isValid) {
      throw ArgumentError.value(identity, 'identity', 'House room required.');
    }
  }
}

String? _cleanString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _parseInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}

DateTime? _parseDate(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed?.toUtc();
}
