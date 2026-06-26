import 'package:supabase_flutter/supabase_flutter.dart';

import 'the_reading_house_flow.dart';

class ReadingHouseSharedFragment {
  const ReadingHouseSharedFragment({
    required this.id,
    required this.calendarId,
    required this.flowId,
    required this.clientEventId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.eventNumber,
    this.passageReference,
  });

  final String id;
  final String calendarId;
  final int flowId;
  final String clientEventId;
  final int? eventNumber;
  final String authorId;
  final String? passageReference;
  final String body;
  final DateTime createdAt;

  bool isAuthoredBy(String? userId) {
    final normalized = userId?.trim();
    return normalized != null &&
        normalized.isNotEmpty &&
        authorId == normalized;
  }

  factory ReadingHouseSharedFragment.fromJson(Map<String, dynamic> json) {
    return ReadingHouseSharedFragment(
      id: _cleanString(json['id']) ?? '',
      calendarId: _cleanString(json['calendar_id']) ?? '',
      flowId: _parseInt(json['flow_id']) ?? 0,
      clientEventId: _cleanString(json['client_event_id']) ?? '',
      eventNumber: _parseInt(json['event_number']),
      authorId: _cleanString(json['author_id']) ?? '',
      passageReference: _cleanString(json['passage_reference']),
      body: _cleanString(json['body']) ?? '',
      createdAt:
          DateTime.tryParse(_cleanString(json['created_at']) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class ReadingHouseFragmentReply {
  const ReadingHouseFragmentReply({
    required this.id,
    required this.fragmentId,
    required this.calendarId,
    required this.flowId,
    required this.clientEventId,
    required this.authorId,
    required this.body,
    required this.isHostAck,
    required this.createdAt,
    this.eventNumber,
  });

  final String id;
  final String fragmentId;
  final String calendarId;
  final int flowId;
  final String clientEventId;
  final int? eventNumber;
  final String authorId;
  final String body;
  final bool isHostAck;
  final DateTime createdAt;

  bool isAuthoredBy(String? userId) {
    final normalized = userId?.trim();
    return normalized != null &&
        normalized.isNotEmpty &&
        authorId == normalized;
  }

  factory ReadingHouseFragmentReply.fromJson(Map<String, dynamic> json) {
    return ReadingHouseFragmentReply(
      id: _cleanString(json['id']) ?? '',
      fragmentId: _cleanString(json['fragment_id']) ?? '',
      calendarId: _cleanString(json['calendar_id']) ?? '',
      flowId: _parseInt(json['flow_id']) ?? 0,
      clientEventId: _cleanString(json['client_event_id']) ?? '',
      eventNumber: _parseInt(json['event_number']),
      authorId: _cleanString(json['author_id']) ?? '',
      body: _cleanString(json['body']) ?? '',
      isHostAck: json['is_host_ack'] == true,
      createdAt:
          DateTime.tryParse(_cleanString(json['created_at']) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class ReadingHouseSharedFragmentsRepo {
  ReadingHouseSharedFragmentsRepo(this._client);

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<bool> canModerateHouse({required String calendarId}) async {
    final trimmedCalendarId = calendarId.trim();
    if (trimmedCalendarId.isEmpty) return false;
    final response = await _client.rpc(
      'reading_house_can_moderate_calendar',
      params: <String, dynamic>{'p_calendar_id': trimmedCalendarId},
    );
    return response == true;
  }

  Future<void> markReadingPosition({
    required String calendarId,
    required int flowId,
    required String clientEventId,
    required int? eventNumber,
    required String readingPosition,
  }) async {
    final normalizedPosition = readingHouseSharedFragmentUnlockPosition(
      readingPosition,
    );
    final acceptedPosition =
        normalizedPosition ??
        (readingPosition.trim().toLowerCase() == kReadingHousePositionNotYet
            ? kReadingHousePositionNotYet
            : null);
    if (acceptedPosition == null) {
      throw ArgumentError.value(
        readingPosition,
        'readingPosition',
        'Must be a Reading House position.',
      );
    }
    await _client.rpc(
      'upsert_reading_house_sitting_position',
      params: <String, dynamic>{
        'p_calendar_id': calendarId.trim(),
        'p_flow_id': flowId,
        'p_client_event_id': clientEventId.trim(),
        'p_event_number': eventNumber,
        'p_reading_position': acceptedPosition,
      },
    );
  }

  Future<List<ReadingHouseSharedFragment>> listFragments({
    required String calendarId,
    required int flowId,
    required String clientEventId,
  }) async {
    final rows = await _client
        .from('reading_house_shared_fragments')
        .select()
        .eq('calendar_id', calendarId.trim())
        .eq('flow_id', flowId)
        .eq('client_event_id', clientEventId.trim())
        .isFilter('deleted_at', null)
        .order('created_at', ascending: true);
    return (rows as List)
        .whereType<Map>()
        .map(
          (row) =>
              ReadingHouseSharedFragment.fromJson(row.cast<String, dynamic>()),
        )
        .where((fragment) => fragment.id.isNotEmpty && fragment.body.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<ReadingHouseFragmentReply>> listReplies({
    required String calendarId,
    required int flowId,
    required String clientEventId,
  }) async {
    final rows = await _client
        .from('reading_house_fragment_replies')
        .select()
        .eq('calendar_id', calendarId.trim())
        .eq('flow_id', flowId)
        .eq('client_event_id', clientEventId.trim())
        .isFilter('deleted_at', null)
        .order('created_at', ascending: true);
    return (rows as List)
        .whereType<Map>()
        .map(
          (row) =>
              ReadingHouseFragmentReply.fromJson(row.cast<String, dynamic>()),
        )
        .where((reply) => reply.id.isNotEmpty && reply.body.isNotEmpty)
        .toList(growable: false);
  }

  Future<ReadingHouseSharedFragment> shareFragment({
    required String calendarId,
    required int flowId,
    required String clientEventId,
    required int? eventNumber,
    required String readingPosition,
    String? passageReference,
    required String body,
  }) async {
    final userId = currentUserId?.trim();
    if (userId == null || userId.isEmpty) {
      throw StateError('Sign in before sharing a Reading House fragment.');
    }
    final unlockPosition = readingHouseSharedFragmentUnlockPosition(
      readingPosition,
    );
    if (unlockPosition == null) {
      throw StateError('Choose Carrying before sharing a fragment.');
    }
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      throw ArgumentError.value(body, 'body', 'Fragment body is required.');
    }
    await markReadingPosition(
      calendarId: calendarId,
      flowId: flowId,
      clientEventId: clientEventId,
      eventNumber: eventNumber,
      readingPosition: unlockPosition,
    );
    final response = await _client
        .from('reading_house_shared_fragments')
        .insert(<String, dynamic>{
          'calendar_id': calendarId.trim(),
          'flow_id': flowId,
          'client_event_id': clientEventId.trim(),
          'event_number': eventNumber,
          'author_id': userId,
          'passage_reference': _cleanString(passageReference),
          'body': trimmedBody,
        })
        .select()
        .single();
    return ReadingHouseSharedFragment.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<void> createReply({
    required String fragmentId,
    required String body,
    bool isHostAck = false,
  }) async {
    final trimmedFragmentId = fragmentId.trim();
    if (trimmedFragmentId.isEmpty) {
      throw ArgumentError.value(fragmentId, 'fragmentId', 'Fragment required.');
    }
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      throw ArgumentError.value(body, 'body', 'Reply body is required.');
    }
    await _client.rpc(
      'create_reading_house_fragment_reply',
      params: <String, dynamic>{
        'p_fragment_id': trimmedFragmentId,
        'p_body': trimmedBody,
        'p_is_host_ack': isHostAck,
      },
    );
  }

  Future<void> deleteReply(String replyId) async {
    final trimmed = replyId.trim();
    if (trimmed.isEmpty) return;
    await _client.rpc(
      'delete_reading_house_fragment_reply',
      params: <String, dynamic>{'p_reply_id': trimmed},
    );
  }

  Future<void> deleteFragment(String fragmentId) async {
    final trimmed = fragmentId.trim();
    if (trimmed.isEmpty) return;
    await _client.rpc(
      'delete_reading_house_shared_fragment',
      params: <String, dynamic>{'p_fragment_id': trimmed},
    );
  }
}

String? _cleanString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

int? _parseInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}
