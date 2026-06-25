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
