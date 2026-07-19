import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_runtime_config_guard.dart';
import '../features/inbox/dm_conversation_models.dart';

const _genericDmConversationError =
    'Could not update messages right now. Please try again.';

enum DmConversationOperation {
  createConversation('create_dm_conversation'),
  sendMessage('send_dm_message_v2'),
  listConversations('list_conversations'),
  readMessages('read_dm_messages'),
  markRead('mark_dm_conversation_read');

  const DmConversationOperation(this.label);

  final String label;
}

enum DmConversationErrorCategory {
  backendUnavailable('backend_unavailable'),
  participantDenied('participant_denied'),
  duplicateParticipants('duplicate_participants'),
  groupTooLarge('group_too_large'),
  unauthenticated('unauthenticated'),
  conversationUnavailable('conversation_unavailable'),
  network('network'),
  unknown('unknown');

  const DmConversationErrorCategory(this.label);

  final String label;
}

@immutable
class DmConversationFailure implements Exception {
  const DmConversationFailure({
    required this.operation,
    required this.category,
    required this.localOverrideActive,
    this.status,
    this.code,
  });

  final DmConversationOperation operation;
  final DmConversationErrorCategory category;
  final bool localOverrideActive;
  final int? status;
  final String? code;

  @override
  String toString() => dmConversationFailureDiagnostic(this);
}

DmConversationFailure classifyDmConversationFailure({
  required DmConversationOperation operation,
  required bool localOverrideActive,
  int? status,
  Object? data,
  Object? error,
}) {
  final effectiveStatus = status ?? _statusFromError(error);
  final text = _classificationText(data, error);
  final sourceCode = _diagnosticCode(
    _sourceErrorCode(data) ?? _sourceErrorCode(error),
  );
  final category = _categoryForDmFailure(
    operation: operation,
    status: effectiveStatus,
    code: sourceCode,
    classificationText: text,
  );
  return DmConversationFailure(
    operation: operation,
    category: category,
    localOverrideActive: localOverrideActive,
    status: effectiveStatus,
    code: sourceCode ?? _statusCode(effectiveStatus) ?? category.label,
  );
}

String dmConversationFailureDiagnostic(DmConversationFailure failure) {
  return '[DmConversationRepo] operation=${failure.operation.label} '
      'failed status=${failure.status ?? 'n/a'} '
      'category=${failure.category.label} '
      'code=${failure.code ?? 'none'} '
      'localOverride=${failure.localOverrideActive}';
}

String userFacingDmConversationError(Object error) {
  if (error is DmConversationFailure) {
    switch (error.category) {
      case DmConversationErrorCategory.backendUnavailable:
        return 'Group chats are not available on this backend yet.';
      case DmConversationErrorCategory.participantDenied:
        return "One or more people can't be added to this group.";
      case DmConversationErrorCategory.duplicateParticipants:
        return 'That person is already selected.';
      case DmConversationErrorCategory.groupTooLarge:
        return 'Group chats are limited to 6 people.';
      case DmConversationErrorCategory.unauthenticated:
        return 'Please sign in to send messages.';
      case DmConversationErrorCategory.conversationUnavailable:
        return 'That conversation is not available.';
      case DmConversationErrorCategory.network:
      case DmConversationErrorCategory.unknown:
        return _genericDmConversationError;
    }
  }

  final message = error.toString().toLowerCase();
  if (message.contains('not signed in') || message.contains('unauthorized')) {
    return 'Please sign in to send messages.';
  }
  if (message.contains('duplicate participants')) {
    return 'That person is already selected.';
  }
  if (message.contains('not accepting messages') ||
      message.contains('blocked') ||
      message.contains('cannot be created')) {
    return "One or more people can't be added to this group.";
  }
  if (message.contains('limited to 6')) {
    return 'Group chats are limited to 6 people.';
  }
  if (_looksLikeMissingDmBackend(message: message, status: null)) {
    return 'Group chats are not available on this backend yet.';
  }
  if (message.contains('conversation not found') ||
      message.contains('not available')) {
    return 'That conversation is not available.';
  }
  return _genericDmConversationError;
}

class DmConversationRepo {
  DmConversationRepo(this._client);

  final SupabaseClient _client;
  static int _channelSequence = 0;
  static const bool _allowLocalSupabase = bool.fromEnvironment(
    'ALLOW_LOCAL_SUPABASE',
  );

  static String _nextRealtimeChannelName(String prefix) {
    _channelSequence = (_channelSequence + 1) % 0x3fffffff;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_channelSequence';
  }

  String? get currentUserId => _client.auth.currentUser?.id;

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  bool get _localSupabaseOverrideActive {
    return _allowLocalSupabase &&
        hasAllowedLocalSupabaseUrl(
          _baseSupabaseUrlFromRestUrl(_client.rest.url),
        );
  }

  DmConversationFailure _failureFor({
    required DmConversationOperation operation,
    int? status,
    Object? data,
    Object? error,
  }) {
    return classifyDmConversationFailure(
      operation: operation,
      status: status,
      data: data,
      error: error,
      localOverrideActive: _localSupabaseOverrideActive,
    );
  }

  void _logFailure(DmConversationFailure failure) {
    _log(dmConversationFailureDiagnostic(failure));
  }

  Future<String> createConversation({
    required List<String> participantIds,
    String? initialText,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not signed in');
    try {
      final response = await _client.functions.invoke(
        'create_dm_conversation',
        body: {
          'participantIds': participantIds,
          if (initialText?.trim().isNotEmpty == true)
            'initialText': initialText!.trim(),
        },
      );
      final body = _map(response.data);
      final conversation = _map(body?['conversation']);
      final conversationId = _string(conversation?['id']);
      if (conversationId == null) {
        throw _failureFor(
          operation: DmConversationOperation.createConversation,
          status: response.status,
          data: response.data,
        );
      }
      return conversationId;
    } on DmConversationFailure catch (failure) {
      _logFailure(failure);
      rethrow;
    } catch (e) {
      final failure = _failureFor(
        operation: DmConversationOperation.createConversation,
        data: e is FunctionException ? e.details : null,
        error: e,
      );
      _logFailure(failure);
      throw failure;
    }
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

    try {
      await _client.functions.invoke(
        'send_dm_message_v2',
        body: {
          'conversationId': conversationId,
          'text': trimmed,
          if (clientMessageId?.trim().isNotEmpty == true)
            'clientMessageId': clientMessageId!.trim(),
        },
      );
    } catch (e) {
      final failure = _failureFor(
        operation: DmConversationOperation.sendMessage,
        data: e is FunctionException ? e.details : null,
        error: e,
      );
      _logFailure(failure);
      throw failure;
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
      _logFailure(
        _failureFor(
          operation: DmConversationOperation.markRead,
          data: e is FunctionException ? e.details : null,
          error: e,
        ),
      );
      return false;
    }
  }

  Future<List<DmConversationSummary>> getConversationSummaries() async {
    final uid = currentUserId;
    if (uid == null) return const [];
    try {
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
    } catch (e) {
      final failure = _failureFor(
        operation: DmConversationOperation.listConversations,
        data: e is PostgrestException ? e.toJson() : null,
        error: e,
      );
      _logFailure(failure);
      throw failure;
    }
  }

  Future<DmConversationSummary?> getConversationSummary(
    String conversationId,
  ) async {
    try {
      final rows = await _client
          .from('dm_conversation_summaries')
          .select()
          .eq('conversation_id', conversationId)
          .limit(1);
      final list = (rows as List<dynamic>? ?? const [])
          .whereType<Map>()
          .toList();
      if (list.isEmpty) return null;
      return DmConversationSummary.fromJson(
        Map<String, dynamic>.from(list.first),
      );
    } catch (e) {
      final failure = _failureFor(
        operation: DmConversationOperation.listConversations,
        data: e is PostgrestException ? e.toJson() : null,
        error: e,
      );
      _logFailure(failure);
      throw failure;
    }
  }

  Future<List<DmConversationMessage>> getMessages(String conversationId) async {
    final uid = currentUserId;
    if (uid == null) return const [];
    try {
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
    } catch (e) {
      final failure = _failureFor(
        operation: DmConversationOperation.readMessages,
        data: e is PostgrestException ? e.toJson() : null,
        error: e,
      );
      _logFailure(failure);
      throw failure;
    }
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
      } catch (_) {
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
            '[DmConversationRepo] channel=$channelName status=$status '
            'error=${error == null ? 'none' : 'present'}',
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
      } catch (_) {
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
            '[DmConversationRepo] channel=$channelName status=$status '
            'error=${error == null ? 'none' : 'present'}',
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

String _baseSupabaseUrlFromRestUrl(String restUrl) {
  final trimmed = restUrl.trim();
  const suffix = '/rest/v1';
  if (trimmed.endsWith(suffix)) {
    return trimmed.substring(0, trimmed.length - suffix.length);
  }
  return trimmed;
}

int? _statusFromError(Object? error) {
  if (error is FunctionException) return error.status;
  return null;
}

String? _sourceErrorCode(Object? raw) {
  if (raw is PostgrestException) return raw.code;
  if (raw is FunctionException) {
    return _sourceErrorCode(raw.details) ?? _statusCode(raw.status);
  }
  final map = _map(raw);
  if (map == null) return null;
  return _string(map['code']) ??
      _string(map['error_code']) ??
      _string(map['errorCode']);
}

String? _statusCode(int? status) {
  return status == null ? null : 'http_$status';
}

String? _diagnosticCode(String? raw) {
  final value = _string(raw);
  if (value == null) return null;
  final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  final trimmed = sanitized.replaceAll(RegExp(r'_+'), '_').trim();
  if (trimmed.isEmpty) return null;
  return trimmed.length > 48 ? trimmed.substring(0, 48) : trimmed;
}

String _classificationText(Object? data, Object? error) {
  final parts = <String>[];

  void add(Object? raw) {
    if (raw == null) return;
    if (raw is FunctionException) {
      add(raw.reasonPhrase);
      add(raw.details);
      add(raw.status);
      return;
    }
    if (raw is PostgrestException) {
      add(raw.message);
      add(raw.code);
      add(raw.details);
      add(raw.hint);
      return;
    }
    if (raw is Map) {
      for (final key in const [
        'error',
        'message',
        'code',
        'error_code',
        'details',
        'hint',
      ]) {
        add(raw[key]);
      }
      return;
    }
    if (raw is Iterable) {
      for (final item in raw) {
        add(item);
      }
      return;
    }
    final value = raw.toString().trim();
    if (value.isNotEmpty) {
      parts.add(value.length > 500 ? value.substring(0, 500) : value);
    }
  }

  add(data);
  add(error);
  return parts.join(' ').toLowerCase();
}

DmConversationErrorCategory _categoryForDmFailure({
  required DmConversationOperation operation,
  required int? status,
  required String? code,
  required String classificationText,
}) {
  final sourceCode = code?.toLowerCase();
  final message = classificationText.toLowerCase();
  if (sourceCode == 'pgrst205' ||
      _looksLikeMissingDmBackend(message: message, status: status)) {
    return DmConversationErrorCategory.backendUnavailable;
  }

  if (message.contains('not signed in') ||
      message.contains('unauthorized') ||
      status == 401) {
    return DmConversationErrorCategory.unauthenticated;
  }

  if (message.contains('duplicate participants')) {
    return DmConversationErrorCategory.duplicateParticipants;
  }

  if (message.contains('limited to 6') ||
      message.contains('group size') ||
      message.contains('too many')) {
    return DmConversationErrorCategory.groupTooLarge;
  }

  if (message.contains('not accepting messages') ||
      message.contains('allow_incoming') ||
      message.contains('allow incoming') ||
      message.contains('blocked') ||
      message.contains('cannot be created') ||
      message.contains('invalid user') ||
      message.contains('invalid participant') ||
      message.contains('participant ids')) {
    return DmConversationErrorCategory.participantDenied;
  }

  if (message.contains('conversation not found') ||
      message.contains('conversation is not available') ||
      message.contains('not a participant') ||
      message.contains('not a member') ||
      (status == 403 &&
          operation != DmConversationOperation.createConversation)) {
    return DmConversationErrorCategory.conversationUnavailable;
  }

  if (status == 403 &&
      operation == DmConversationOperation.createConversation) {
    return DmConversationErrorCategory.participantDenied;
  }

  if (message.contains('socketexception') ||
      message.contains('connection refused') ||
      message.contains('failed host lookup') ||
      message.contains('network')) {
    return DmConversationErrorCategory.network;
  }

  return DmConversationErrorCategory.unknown;
}

bool _looksLikeMissingDmBackend({
  required String message,
  required int? status,
}) {
  final lower = message.toLowerCase();
  if (lower.contains('pgrst205') ||
      lower.contains('schema cache') ||
      lower.contains('could not find the table') ||
      lower.contains('dm_conversation_summaries') ||
      lower.contains('dm_conversation_messages_client')) {
    return true;
  }

  if (status == 404 &&
      (lower.isEmpty ||
          lower.contains('function not found') ||
          lower.contains('edge function') ||
          lower.contains('not found') ||
          lower.contains('create_dm_conversation') ||
          lower.contains('send_dm_message_v2') ||
          lower.contains('mark_dm_conversation_read'))) {
    return true;
  }

  return false;
}
