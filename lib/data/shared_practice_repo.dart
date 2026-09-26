import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/completion_status.dart';
import 'shared_calendar_models.dart';
import 'shared_calendars_repo.dart';
import 'shared_practice_models.dart';

class SharedPracticeRepo {
  SharedPracticeRepo(this._client);

  final SupabaseClient _client;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[SharedPracticeRepo] $message');
    }
  }

  Future<List<SharedCalendarOption>>
  getEligibleSharedCalendarsForPractice() async {
    final calendars = await SharedCalendarsRepo(_client).getAcceptedCalendars();
    final eligible = calendars
        .where(
          (calendar) =>
              calendar.status == SharedCalendarInviteStatus.accepted &&
              calendar.canEditEvents &&
              !calendar.isPersonal &&
              !calendar.isSystem,
        )
        .toList(growable: false);

    final repo = SharedCalendarsRepo(_client);
    final options = <SharedCalendarOption>[];
    for (final calendar in eligible) {
      List<SharedCalendarMember> members = const <SharedCalendarMember>[];
      try {
        members = await repo.listMembers(
          calendar.id,
          expectedMemberCount: calendar.memberCount,
        );
      } catch (e) {
        _log('member preview failed for ${calendar.id}: $e');
      }
      options.add(SharedCalendarOption(calendar: calendar, members: members));
    }
    return options;
  }

  Future<SharedPracticeRoom> createSharedPracticeFromFlow({
    required String calendarId,
    required int sourceFlowId,
    DateTime? startDate,
  }) async {
    final trimmedCalendarId = calendarId.trim();
    if (trimmedCalendarId.isEmpty) {
      throw ArgumentError.value(calendarId, 'calendarId', 'Must not be empty.');
    }
    if (sourceFlowId <= 0) {
      throw ArgumentError.value(
        sourceFlowId,
        'sourceFlowId',
        'Must be positive.',
      );
    }

    final response = await _client.rpc(
      'create_shared_practice_from_flow',
      params: <String, dynamic>{
        'p_calendar_id': trimmedCalendarId,
        'p_source_flow_id': sourceFlowId,
        if (startDate != null) 'p_start_date': _dateOnly(startDate),
      },
    );
    final roomId = response?.toString().trim();
    if (roomId == null || roomId.isEmpty) {
      throw StateError('Shared practice room was not returned.');
    }
    final snapshot = await getSharedPracticeRoom(
      roomId: roomId,
      localDate: startDate ?? DateTime.now(),
    );
    final sharedFlowId = snapshot.room.sharedFlowId;
    if (sharedFlowId != null && sharedFlowId > 0) {
      try {
        await ensureSharedExperienceForFlow(
          flowId: sharedFlowId,
          calendarId: snapshot.room.calendarId,
        );
      } catch (e) {
        _log('ensure shared experience failed for $sharedFlowId: $e');
      }
    }
    unawaited(
      SharedCalendarsRepo(_client).notifySharedCalendarItemAdded(
        calendarId: snapshot.room.calendarId,
        itemType: 'flow',
        itemId:
            snapshot.room.sharedFlowId?.toString() ??
            snapshot.room.sourceFlowId.toString(),
        itemTitle: snapshot.room.title,
        flowId: snapshot.room.sharedFlowId ?? snapshot.room.sourceFlowId,
        startDate: snapshot.room.startDate,
        endDate: snapshot.room.endDate,
      ),
    );
    return snapshot.room;
  }

  Future<String?> ensureSharedExperienceForFlow({
    required int flowId,
    required String? calendarId,
  }) async {
    final trimmedCalendarId = calendarId?.trim();
    if (flowId <= 0 || trimmedCalendarId == null || trimmedCalendarId.isEmpty) {
      return null;
    }
    final response = await _client.rpc(
      'ensure_shared_experience_for_flow',
      params: <String, dynamic>{
        'p_flow_id': flowId,
        'p_calendar_id': trimmedCalendarId,
      },
    );
    final roomId = response?.toString().trim();
    return roomId == null || roomId.isEmpty ? null : roomId;
  }

  Future<JointFlowExperienceResult> createJointFlowExperienceFromCommons({
    required int sourceFlowId,
    required List<String> participantUserIds,
    String? calendarTitle,
    String? clientRequestId,
    Map<String, dynamic>? context,
  }) async {
    if (sourceFlowId <= 0) {
      throw ArgumentError.value(
        sourceFlowId,
        'sourceFlowId',
        'Must be positive.',
      );
    }
    final participants = participantUserIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (participants.isEmpty) {
      throw ArgumentError.value(
        participantUserIds,
        'participantUserIds',
        'At least one other participant is required.',
      );
    }

    final response = await _client.rpc(
      'create_joint_flow_experience_from_commons',
      params: <String, dynamic>{
        'p_source_flow_id': sourceFlowId,
        'p_participant_user_ids': participants,
        if (calendarTitle != null && calendarTitle.trim().isNotEmpty)
          'p_calendar_title': calendarTitle.trim(),
        if (clientRequestId != null && clientRequestId.trim().isNotEmpty)
          'p_client_request_id': clientRequestId.trim(),
        if (context != null && context.isNotEmpty) 'p_context': context,
      },
    );
    if (response is Map<String, dynamic>) {
      return JointFlowExperienceResult.fromJson(response);
    }
    if (response is Map) {
      return JointFlowExperienceResult.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    throw StateError(
      'Unexpected joint flow experience response: ${response.runtimeType}',
    );
  }

  Future<SharedPracticeRoomSnapshot> getSharedPracticeRoom({
    required String roomId,
    required DateTime localDate,
  }) async {
    final trimmedRoomId = roomId.trim();
    if (trimmedRoomId.isEmpty) {
      throw ArgumentError.value(roomId, 'roomId', 'Must not be empty.');
    }
    final response = await _client.rpc(
      'get_shared_practice_room',
      params: <String, dynamic>{
        'p_room_id': trimmedRoomId,
        'p_local_date': _dateOnly(localDate),
      },
    );
    if (response is Map<String, dynamic>) {
      return SharedPracticeRoomSnapshot.fromJson(response);
    }
    if (response is Map) {
      return SharedPracticeRoomSnapshot.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    throw StateError(
      'Unexpected shared practice room response: ${response.runtimeType}',
    );
  }

  Stream<void> watchSharedPracticeChanges(String roomId) {
    final trimmedRoomId = roomId.trim();
    if (trimmedRoomId.isEmpty) {
      return Stream<void>.error(
        ArgumentError.value(roomId, 'roomId', 'Must not be empty.'),
      );
    }

    final controller = StreamController<void>();
    void emitChange() {
      if (!controller.isClosed) controller.add(null);
    }

    final channel =
        _client.channel(
            'shared_practice_room_${trimmedRoomId.replaceAll('-', '')}',
          )
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'shared_practice_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: trimmedRoomId,
            ),
            callback: (_) => emitChange(),
          )
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'shared_practice_rooms',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: trimmedRoomId,
            ),
            callback: (_) => emitChange(),
          )
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'shared_practice_room_members',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: trimmedRoomId,
            ),
            callback: (_) => emitChange(),
          )
          ..subscribe((status, [error]) {
            if (kDebugMode &&
                (status == RealtimeSubscribeStatus.channelError ||
                    status == RealtimeSubscribeStatus.timedOut)) {
              _log('message channel status=$status error=$error');
            }
          });

    controller.onCancel = () async {
      await channel.unsubscribe();
      await controller.close();
    };
    return controller.stream;
  }

  Stream<void> watchTogetherInboxChanges() {
    final userId = _client.auth.currentUser?.id.trim();
    if (userId == null || userId.isEmpty) {
      return Stream<void>.error(StateError('Authentication required.'));
    }

    final controller = StreamController<void>();
    void emitChange() {
      if (!controller.isClosed) controller.add(null);
    }

    final channel =
        _client.channel('together_inbox_${userId.replaceAll('-', '')}')
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'shared_practice_join_requests',
            callback: (_) => emitChange(),
          )
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'shared_practice_room_members',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (_) => emitChange(),
          )
          ..subscribe((status, [error]) {
            if (kDebugMode &&
                (status == RealtimeSubscribeStatus.channelError ||
                    status == RealtimeSubscribeStatus.timedOut)) {
              _log('Together inbox channel status=$status error=$error');
            }
          });

    controller.onCancel = () async {
      await channel.unsubscribe();
      await controller.close();
    };
    return controller.stream;
  }

  Future<SharedPracticeEntry> upsertSharedPracticeEntry({
    required String roomId,
    required String clientEventId,
    required int flowId,
    required DateTime completedOn,
    required CompletionStatus completionStatus,
    String? bodyText,
    SharedPracticeVisibility visibility = SharedPracticeVisibility.private,
    Map<String, dynamic>? completionMetadata,
  }) async {
    if (completionStatus == CompletionStatus.none) {
      throw ArgumentError.value(
        completionStatus,
        'completionStatus',
        'Cannot record none.',
      );
    }
    final response = await _client.rpc(
      'upsert_shared_practice_entry',
      params: <String, dynamic>{
        'p_room_id': roomId.trim(),
        'p_client_event_id': clientEventId.trim(),
        'p_flow_id': flowId,
        'p_completed_on': _dateOnly(completedOn),
        'p_completion_status': completionStatus.wireName,
        'p_body_text': bodyText,
        'p_visibility': visibility.wireName,
      },
    );

    if (completionMetadata != null && completionMetadata.isNotEmpty) {
      await _mergeCompletionMetadata(
        clientEventId: clientEventId,
        sharedPracticeRoomId: roomId,
        visibility: visibility,
        metadata: completionMetadata,
      );
    }

    if (response is Map<String, dynamic>) {
      return SharedPracticeEntry.fromJson(response);
    }
    if (response is Map) {
      return SharedPracticeEntry.fromJson(Map<String, dynamic>.from(response));
    }
    throw StateError(
      'Unexpected shared practice entry response: ${response.runtimeType}',
    );
  }

  Future<void> markSharedStepOpened({
    required String roomId,
    required String clientEventId,
    required DateTime openedOn,
  }) async {
    await _client.rpc(
      'mark_shared_step_opened',
      params: <String, dynamic>{
        'p_room_id': roomId.trim(),
        'p_client_event_id': clientEventId.trim(),
        'p_opened_on': _dateOnly(openedOn),
      },
    );
  }

  Future<SharedPracticeRoom> setSharedPracticeVisibility({
    required String roomId,
    required SharedPracticeRoomVisibility visibility,
    SharedPracticeJoinPolicy? joinPolicy,
  }) async {
    final response = await _client.rpc(
      'set_shared_practice_visibility',
      params: <String, dynamic>{
        'p_room_id': roomId.trim(),
        'p_visibility': visibility.wireName,
        'p_join_policy':
            joinPolicy?.wireName ??
            (visibility == SharedPracticeRoomVisibility.public
                ? SharedPracticeJoinPolicy.ownerApproval.wireName
                : SharedPracticeJoinPolicy.closed.wireName),
      },
    );
    if (response is Map<String, dynamic>) {
      return SharedPracticeRoom.fromJson(response);
    }
    if (response is Map) {
      return SharedPracticeRoom.fromJson(Map<String, dynamic>.from(response));
    }
    throw StateError(
      'Unexpected shared practice visibility response: ${response.runtimeType}',
    );
  }

  Future<SharedPracticeJoinRequest> requestJoinSharedPractice({
    required String roomId,
    String? message,
  }) async {
    final response = await _client.rpc(
      'request_join_shared_practice',
      params: <String, dynamic>{
        'p_room_id': roomId.trim(),
        if (message != null && message.trim().isNotEmpty)
          'p_message': message.trim(),
      },
    );
    if (response is Map<String, dynamic>) {
      return SharedPracticeJoinRequest.fromJson(response);
    }
    if (response is Map) {
      return SharedPracticeJoinRequest.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    throw StateError(
      'Unexpected shared practice join response: ${response.runtimeType}',
    );
  }

  Future<SharedPracticeJoinRequest> respondToJoinRequest({
    required String requestId,
    required bool approve,
  }) async {
    final response = await _client.rpc(
      'respond_to_join_request',
      params: <String, dynamic>{
        'p_request_id': requestId.trim(),
        'p_decision': approve ? 'approved' : 'denied',
      },
    );
    if (response is Map<String, dynamic>) {
      return SharedPracticeJoinRequest.fromJson(response);
    }
    if (response is Map) {
      return SharedPracticeJoinRequest.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    throw StateError(
      'Unexpected shared practice join decision response: '
      '${response.runtimeType}',
    );
  }

  Future<TogetherInboxSnapshot> getTogetherInbox({int limit = 40}) async {
    final responses = await Future.wait<dynamic>(<Future<dynamic>>[
      _client.rpc(
        'get_together_inbox',
        params: <String, dynamic>{'p_limit': limit},
      ),
      _client.rpc(
        'get_together_quote_approvals',
        params: <String, dynamic>{'p_limit': limit},
      ),
      _client.rpc(
        'get_together_request_decisions',
        params: <String, dynamic>{'p_limit': limit},
      ),
    ]);
    final inboxResponse = responses[0];
    final approvalResponse = responses[1];
    final decisionResponse = responses[2];
    if (inboxResponse is! Map) {
      throw StateError(
        'Unexpected Together inbox response: ${inboxResponse.runtimeType}',
      );
    }
    return TogetherInboxSnapshot.fromJson(<String, dynamic>{
      ...Map<String, dynamic>.from(inboxResponse),
      'quote_approvals': approvalResponse is List
          ? approvalResponse
          : const <dynamic>[],
      'request_decisions': decisionResponse is List
          ? decisionResponse
          : const <dynamic>[],
    });
  }

  Future<String?> getTogetherRoomForFlow(int flowId) async {
    if (flowId <= 0) return null;
    final response = await _client.rpc(
      'get_together_room_for_flow',
      params: <String, dynamic>{'p_flow_id': flowId},
    );
    final roomId = response?.toString().trim();
    return roomId == null || roomId.isEmpty ? null : roomId;
  }

  Future<void> respondToTogetherInvitation({
    required String roomId,
    required bool accept,
  }) async {
    await _client.rpc(
      'respond_to_together_invitation',
      params: <String, dynamic>{'p_room_id': roomId.trim(), 'p_accept': accept},
    );
  }

  Future<void> markTogetherRequestDecisionSeen(String requestId) async {
    await _client.rpc(
      'mark_together_request_decision_seen',
      params: <String, dynamic>{'p_request_id': requestId.trim()},
    );
  }

  Future<SharedPracticeMessage> sendSharedPracticeMessage({
    required String roomId,
    required String bodyText,
  }) async {
    final body = bodyText.trim();
    if (body.isEmpty) {
      throw ArgumentError.value(bodyText, 'bodyText', 'Must not be empty.');
    }
    final response = await _client.rpc(
      'send_shared_practice_message',
      params: <String, dynamic>{
        'p_room_id': roomId.trim(),
        'p_body_text': body,
      },
    );
    if (response is Map<String, dynamic>) {
      return SharedPracticeMessage.fromJson(response);
    }
    if (response is Map) {
      return SharedPracticeMessage.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    throw StateError(
      'Unexpected shared practice message response: '
      '${response.runtimeType}',
    );
  }

  Future<void> deleteSharedPracticeMessage(String messageId) async {
    await _client.rpc(
      'delete_shared_practice_message',
      params: <String, dynamic>{'p_message_id': messageId.trim()},
    );
  }

  Future<void> setSharedPracticePublicIdentity({
    required String roomId,
    required bool isPublic,
  }) async {
    await _client.rpc(
      'set_shared_practice_public_identity',
      params: <String, dynamic>{
        'p_room_id': roomId.trim(),
        'p_public': isPublic,
      },
    );
  }

  Future<SharedPracticeQuotePost> requestSharedPracticeQuotePost(
    String messageId,
  ) async {
    final response = await _client.rpc(
      'request_shared_practice_quote_post',
      params: <String, dynamic>{'p_message_id': messageId.trim()},
    );
    if (response is Map) {
      return SharedPracticeQuotePost.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    throw StateError('Unexpected quote-post response: ${response.runtimeType}');
  }

  Future<void> respondToSharedPracticeQuotePost({
    required String quotePostId,
    required bool approve,
  }) async {
    await _client.rpc(
      'respond_to_shared_practice_quote_post',
      params: <String, dynamic>{
        'p_quote_post_id': quotePostId.trim(),
        'p_approve': approve,
      },
    );
  }

  Future<List<SharedPracticeQuotePost>> getSharedPracticeQuotePosts({
    String? roomId,
    int limit = 20,
  }) async {
    final response = await _client.rpc(
      'get_shared_practice_quote_posts',
      params: <String, dynamic>{'p_room_id': roomId?.trim(), 'p_limit': limit},
    );
    if (response is! List) {
      throw StateError(
        'Unexpected quote-post list response: ${response.runtimeType}',
      );
    }
    return response
        .whereType<Map>()
        .map(
          (row) =>
              SharedPracticeQuotePost.fromJson(Map<String, dynamic>.from(row)),
        )
        .where((post) => post.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<({bool likedByMe, int likesCount})> toggleSharedPracticeQuoteLike(
    String quotePostId,
  ) async {
    final response = await _client.rpc(
      'toggle_shared_practice_quote_like',
      params: <String, dynamic>{'p_quote_post_id': quotePostId.trim()},
    );
    if (response is! Map) {
      throw StateError(
        'Unexpected quote-like response: ${response.runtimeType}',
      );
    }
    return (
      likedByMe: response['liked_by_me'] == true,
      likesCount: (response['likes_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<SharedPracticeQuoteComment> addSharedPracticeQuoteComment({
    required String quotePostId,
    required String bodyText,
  }) async {
    final response = await _client.rpc(
      'add_shared_practice_quote_comment',
      params: <String, dynamic>{
        'p_quote_post_id': quotePostId.trim(),
        'p_body_text': bodyText.trim(),
      },
    );
    if (response is Map) {
      return SharedPracticeQuoteComment.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    throw StateError(
      'Unexpected quote-comment response: ${response.runtimeType}',
    );
  }

  Future<void> setSharedPracticeAccess({
    required String roomId,
    required SharedPracticeRoomVisibility visibility,
    required SharedPracticeRequestAudience requestAudience,
  }) async {
    await _client.rpc(
      'set_shared_practice_access',
      params: <String, dynamic>{
        'p_room_id': roomId.trim(),
        'p_visibility': visibility.wireName,
        'p_request_audience': requestAudience.wireName,
      },
    );
  }

  Future<String> createTogetherOverlayForFlow({
    required int flowId,
    List<String> invitedUserIds = const <String>[],
  }) async {
    if (flowId <= 0) {
      throw ArgumentError.value(flowId, 'flowId', 'Must be positive.');
    }
    final response = await _client.rpc(
      'create_together_overlay_for_flow',
      params: <String, dynamic>{
        'p_flow_id': flowId,
        'p_invitee_ids': invitedUserIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList(growable: false),
      },
    );
    if (response is Map) {
      final roomId = response['room_id']?.toString().trim();
      if (roomId != null && roomId.isNotEmpty) return roomId;
    }
    throw StateError('Together overlay response did not include a room.');
  }

  Future<void> _mergeCompletionMetadata({
    required String clientEventId,
    required String sharedPracticeRoomId,
    required SharedPracticeVisibility visibility,
    required Map<String, dynamic> metadata,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final merged = <String, dynamic>{
      ...metadata,
      'shared_practice_room_id': sharedPracticeRoomId,
      'visibility': visibility.wireName,
    };
    await _client
        .from('user_event_completions')
        .update(<String, dynamic>{'metadata': merged})
        .eq('user_id', user.id)
        .eq('client_event_id', clientEventId.trim());
  }
}

String _dateOnly(DateTime value) {
  final local = DateTime(value.year, value.month, value.day);
  return [
    local.year.toString().padLeft(4, '0'),
    local.month.toString().padLeft(2, '0'),
    local.day.toString().padLeft(2, '0'),
  ].join('-');
}
