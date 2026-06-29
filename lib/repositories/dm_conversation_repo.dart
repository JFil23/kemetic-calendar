import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/inbox/dm_conversation_models.dart';

String userFacingDmConversationError(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('not signed in') || message.contains('unauthorized')) {
    return 'Please sign in to send messages.';
  }
  if (message.contains('duplicate participants')) {
    return 'That person is already selected.';
  }
  if (message.contains('not accepting messages')) {
    return 'One or more people are not accepting messages right now.';
  }
  if (message.contains('cannot be created')) {
    return 'This group cannot be created with the selected people.';
  }
  if (message.contains('limited to 6')) {
    return 'Group chats are limited to 6 people.';
  }
  if (message.contains('conversation not found') ||
      message.contains('not available')) {
    return 'That conversation is not available.';
  }
  return 'Could not update messages right now. Please try again.';
}

class DmConversationRepo {
  DmConversationRepo(this._client);

  final SupabaseClient _client;
  static int _channelSequence = 0;

  static String _nextRealtimeChannelName(String prefix) {
    _channelSequence = (_channelSequence + 1) % 0x3fffffff;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_channelSequence';
  }

  String? get currentUserId => _client.auth.currentUser?.id;

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  Future<String> createConversation({
    required List<String> participantIds,
    String? initialText,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not signed in');
    final response = await _client.functions.invoke(
      'create_dm_conversation',
      body: {
        'participantIds': participantIds,
        if (initialText?.trim().isNotEmpty == true)
          'initialText': initialText!.trim(),
      },
    );
    final body = _map(response.data);
    if (response.status >= 400) {
      throw Exception(_string(body?['error']) ?? 'HTTP ${response.status}');
    }
    final conversation = _map(body?['conversation']);
    final conversationId = _string(conversation?['id']);
    if (conversationId == null) {
      throw Exception('Conversation not found');
    }
    return conversationId;
  }

  Future<void> sendMessage({
    required String conversationId,
    required String text,
    String? clientMessageId,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not signed in');
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final response = await _client.functions.invoke(
      'send_dm_message_v2',
      body: {
        'conversationId': conversationId,
        'text': trimmed,
        if (clientMessageId?.trim().isNotEmpty == true)
          'clientMessageId': clientMessageId!.trim(),
      },
    );
    final body = _map(response.data);
    if (response.status >= 400) {
      throw Exception(_string(body?['error']) ?? 'HTTP ${response.status}');
    }
  }

  Future<bool> markRead(String conversationId) async {
    final uid = currentUserId;
    if (uid == null) return false;
    try {
      final response = await _client.functions.invoke(
        'mark_dm_conversation_read',
        body: {'conversationId': conversationId},
      );
      return response.status < 400;
    } catch (e) {
      _log('[DmConversationRepo] markRead failed: $e');
      return false;
    }
  }

  Future<List<DmConversationSummary>> getConversationSummaries() async {
    final uid = currentUserId;
    if (uid == null) return const [];
    final response = await _client
        .from('dm_conversation_summaries')
        .select()
        .order('updated_at', ascending: false);
    return (response as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (row) =>
              DmConversationSummary.fromJson(Map<String, dynamic>.from(row)),
        )
        .where((summary) => summary.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<DmConversationSummary?> getConversationSummary(
    String conversationId,
  ) async {
    final rows = await _client
        .from('dm_conversation_summaries')
        .select()
        .eq('conversation_id', conversationId)
        .limit(1);
    final list = (rows as List<dynamic>? ?? const []).whereType<Map>().toList();
    if (list.isEmpty) return null;
    return DmConversationSummary.fromJson(
      Map<String, dynamic>.from(list.first),
    );
  }

  Future<List<DmConversationMessage>> getMessages(String conversationId) async {
    final uid = currentUserId;
    if (uid == null) return const [];
    final response = await _client
        .from('dm_conversation_messages_client')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
    return (response as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (row) =>
              DmConversationMessage.fromJson(Map<String, dynamic>.from(row)),
        )
        .where((message) => message.id.isNotEmpty)
        .toList(growable: false);
  }

  Stream<List<DmConversationSummary>> watchConversationSummaries() {
    final uid = currentUserId;
    if (uid == null) return Stream.value(const []);

    final controller = StreamController<List<DmConversationSummary>>();
    final channelName = _nextRealtimeChannelName('dm_conversation_watch');
    Timer? refreshDebounce;
    bool refreshInFlight = false;
    bool refreshQueued = false;
    List<DmConversationSummary> lastSummaries = const [];

    Future<void> emitLatest() async {
      if (refreshInFlight) {
        refreshQueued = true;
        return;
      }
      refreshInFlight = true;
      try {
        final summaries = await getConversationSummaries();
        lastSummaries = summaries;
        if (!controller.isClosed) controller.add(summaries);
      } catch (e, st) {
        _log('[DmConversationRepo] summary refresh failed: $e');
        if (kDebugMode) debugPrint('$st');
        if (!controller.isClosed) controller.add(lastSummaries);
      } finally {
        refreshInFlight = false;
        if (refreshQueued) {
          refreshQueued = false;
          unawaited(emitLatest());
        }
      }
    }

    void scheduleRefresh() {
      refreshDebounce?.cancel();
      refreshDebounce = Timer(const Duration(milliseconds: 120), () {
        unawaited(emitLatest());
      });
    }

    final channel = _client.channel(channelName)
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'dm_conversation_members',
        callback: (_) => scheduleRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'dm_conversations',
        callback: (_) => scheduleRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'dm_messages',
        callback: (_) => scheduleRefresh(),
      )
      ..subscribe((status, [error]) {
        if (kDebugMode) {
          debugPrint(
            '[DmConversationRepo] channel=$channelName status=$status error=$error',
          );
        }
        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
          case RealtimeSubscribeStatus.channelError:
          case RealtimeSubscribeStatus.timedOut:
            scheduleRefresh();
            break;
          case RealtimeSubscribeStatus.closed:
            break;
        }
      });

    unawaited(emitLatest());

    controller.onCancel = () async {
      refreshDebounce?.cancel();
      await channel.unsubscribe();
      await controller.close();
    };

    return controller.stream;
  }

  Stream<List<DmConversationMessage>> watchMessages(String conversationId) {
    final uid = currentUserId;
    if (uid == null) return Stream.value(const []);

    final controller = StreamController<List<DmConversationMessage>>();
    final channelName = _nextRealtimeChannelName('dm_messages');
    Timer? refreshDebounce;

    Future<void> emitLatest() async {
      try {
        final messages = await getMessages(conversationId);
        if (!controller.isClosed) controller.add(messages);
      } catch (e, st) {
        _log('[DmConversationRepo] message refresh failed: $e');
        if (kDebugMode) debugPrint('$st');
        if (!controller.isClosed) controller.add(const []);
      }
    }

    void scheduleRefresh() {
      refreshDebounce?.cancel();
      refreshDebounce = Timer(const Duration(milliseconds: 120), () {
        unawaited(emitLatest());
      });
    }

    final channel = _client.channel(channelName)
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'dm_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: (_) => scheduleRefresh(),
      )
      ..subscribe((status, [error]) {
        if (kDebugMode) {
          debugPrint(
            '[DmConversationRepo] channel=$channelName status=$status error=$error',
          );
        }
        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
          case RealtimeSubscribeStatus.channelError:
          case RealtimeSubscribeStatus.timedOut:
            scheduleRefresh();
            break;
          case RealtimeSubscribeStatus.closed:
            break;
        }
      });

    unawaited(emitLatest());

    controller.onCancel = () async {
      refreshDebounce?.cancel();
      await channel.unsubscribe();
      await controller.close();
    };

    return controller.stream;
  }
}

Map<String, dynamic>? _map(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.cast<String, dynamic>();
  return null;
}

String? _string(Object? raw) {
  if (raw == null) return null;
  final text = raw is String ? raw : raw.toString();
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : trimmed;
}
