// lib/data/share_repo.dart
// ShareRepo - Repository Layer for Flow Sharing System

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'share_models.dart';
import 'user_events_repo.dart';

class ShareRepo {
  final SupabaseClient _client;

  ShareRepo(this._client);

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  // Activity items (likes, comments, follows) for unified inbox feed.
  Future<List<InboxActivityItem>> getRecentActivity({int limit = 50}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];

    try {
      final likes = await _client
          .from('flow_post_likes')
          .select(
            'created_at, user_id, flow_post_id, profiles(display_name, handle, avatar_url), flow_posts!inner(name, user_id)',
          )
          .eq('flow_posts.user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);

      final comments = await _client
          .from('flow_post_comments')
          .select(
            'created_at, user_id, body, flow_post_id, profiles(display_name, handle, avatar_url), flow_posts!inner(name, user_id)',
          )
          .eq('flow_posts.user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);

      final follows = await _client
          .from('follows')
          .select(
            'created_at, follower_id, profiles!follower_id(display_name, handle, avatar_url)',
          )
          .eq('followee_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);

      final items = <InboxActivityItem>[];

      for (final row in (likes as List? ?? const [])) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        final createdAt = DateTime.parse(row['created_at'] as String);
        items.add(
          InboxActivityItem(
            type: InboxActivityType.like,
            createdAt: createdAt,
            actorId: row['user_id'] as String?,
            actorHandle: profile?['handle'] as String?,
            actorName: profile?['display_name'] as String?,
            actorAvatar: profile?['avatar_url'] as String?,
            flowPostId: row['flow_post_id'] as String?,
            flowName: (row['flow_posts'] as Map?)?['name'] as String?,
          ),
        );
      }

      for (final row in (comments as List? ?? const [])) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        final createdAt = DateTime.parse(row['created_at'] as String);
        items.add(
          InboxActivityItem(
            type: InboxActivityType.comment,
            createdAt: createdAt,
            actorId: row['user_id'] as String?,
            actorHandle: profile?['handle'] as String?,
            actorName: profile?['display_name'] as String?,
            actorAvatar: profile?['avatar_url'] as String?,
            flowPostId: row['flow_post_id'] as String?,
            flowName: (row['flow_posts'] as Map?)?['name'] as String?,
            commentPreview: row['body'] as String?,
          ),
        );
      }

      for (final row in (follows as List? ?? const [])) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        final createdAt = DateTime.parse(row['created_at'] as String);
        items.add(
          InboxActivityItem(
            type: InboxActivityType.follow,
            createdAt: createdAt,
            actorId: row['follower_id'] as String?,
            actorHandle: profile?['handle'] as String?,
            actorName: profile?['display_name'] as String?,
            actorAvatar: profile?['avatar_url'] as String?,
          ),
        );
      }

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items.take(limit).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ShareRepo] getRecentActivity error: $e');
      }
      return const [];
    }
  }

  /// Share a flow with recipients
  Future<List<ShareResult>> shareFlow({
    required int flowId,
    required List<ShareRecipient> recipients,
    SuggestedSchedule? suggestedSchedule,
  }) async {
    _log('[ShareRepo] Current user: ${_client.auth.currentUser?.id}');
    _log(
      '[ShareRepo] Current session: ${_client.auth.currentSession?.accessToken != null}',
    );

    try {
      final response = await _client.functions.invoke(
        'create_flow_share',
        body: {
          'flow_id': flowId,
          'recipients': recipients.map((r) => r.toJson()).toList(),
          if (suggestedSchedule != null)
            'suggested_schedule': suggestedSchedule.toJson(),
        },
      );

      _log('[ShareRepo] create_flow_share status=${response.status}');
      _log('[ShareRepo] create_flow_share body=${response.data}');

      // Handle HTTP errors
      if (response.status >= 400) {
        _log('[ShareRepo] HTTP error: ${response.status}');
        return [ShareResult(status: null, error: 'HTTP ${response.status}')];
      }

      // Parse response body
      if (response.data == null) {
        _log('[ShareRepo] ERROR: response.data is null');
        return [
          ShareResult(
            status: null,
            error: 'Edge Function returned null response',
          ),
        ];
      }

      final Map<String, dynamic> body = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : (jsonDecode(response.data as String) as Map<String, dynamic>);

      _log('[ShareRepo] Response data keys: ${body.keys}');

      // Extract shares list
      final sharesList = (body['shares'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      _log('[ShareRepo] Shares list length: ${sharesList.length}');

      if (sharesList.isEmpty) {
        _log('[ShareRepo] WARNING: Empty shares list in response');
        return [
          ShareResult(
            status: null,
            error: 'No shares returned from create_flow_share',
          ),
        ];
      }

      // Parse each share row from the database
      final results = <ShareResult>[];
      for (final row in sharesList) {
        _log('[ShareRepo] Processing share row: $row');
        results.add(ShareResult.fromJson(row));
      }

      // Parse errors array if present
      final errorsList = (body['errors'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      if (errorsList.isNotEmpty) {
        _log('[ShareRepo] Errors from Edge function: $errorsList');
        // Create ShareResult objects for errors
        for (final err in errorsList) {
          results.add(
            ShareResult(
              status: null,
              error: err['error'] as String? ?? 'Unknown error',
              shareId: null,
            ),
          );
        }
      }

      _log(
        '[ShareRepo] Parsed ${results.length} share results (${sharesList.length} successes, ${errorsList.length} errors)',
      );

      return results;
    } catch (e, stackTrace) {
      _log('[ShareRepo] Error sharing flow: $e');
      _log('[ShareRepo] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Share an event (user_events) with recipients
  Future<List<ShareResult>> shareEvent({
    required String eventId,
    required List<ShareRecipient> recipients,
    Map<String, dynamic>? payloadJson,
  }) async {
    final normalizedRecipients = dedupeShareRecipients(recipients);
    _log(
      '[ShareRepo] shareEvent: eventId=$eventId recipients=${normalizedRecipients.length}',
    );

    try {
      final response = await _client.functions.invoke(
        'create_event_share',
        body: {
          'event_id': eventId,
          'recipients': normalizedRecipients.map((r) => r.toJson()).toList(),
          if (payloadJson != null) 'payload_json': payloadJson,
        },
      );

      _log('[ShareRepo] create_event_share status=${response.status}');
      _log('[ShareRepo] create_event_share body=${response.data}');

      if (response.status >= 400) {
        return [ShareResult(status: null, error: 'HTTP ${response.status}')];
      }

      if (response.data == null) {
        return [
          ShareResult(
            status: null,
            error: 'Edge Function returned null response',
          ),
        ];
      }

      final Map<String, dynamic> body = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : (jsonDecode(response.data as String) as Map<String, dynamic>);

      final sharesList = (body['shares'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      final results = <ShareResult>[];
      for (final row in sharesList) {
        results.add(ShareResult.fromJson(row));
      }

      final errorsList = (body['errors'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      for (final err in errorsList) {
        results.add(ShareResult.fromJson(err));
      }

      return results;
    } on FunctionException catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ShareRepo] Error sharing event: $e');
        debugPrint('$st');
      }

      if (e.status == 404) {
        _log(
          '[ShareRepo] create_event_share missing on backend; falling back to direct event_shares writes',
        );
        try {
          return await _shareEventDirect(
            eventId: eventId,
            recipients: normalizedRecipients,
            payloadJson: payloadJson,
          );
        } catch (fallbackError, fallbackStackTrace) {
          if (kDebugMode) {
            debugPrint(
              '[ShareRepo] Direct event share fallback failed: $fallbackError',
            );
            debugPrint('$fallbackStackTrace');
          }
          return [
            ShareResult(
              status: null,
              error: _inviteErrorMessage(fallbackError, missingFunction: true),
            ),
          ];
        }
      }

      return [ShareResult(status: null, error: _inviteErrorMessage(e))];
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ShareRepo] Error sharing event: $e');
        debugPrint('$st');
      }
      return [ShareResult(status: null, error: _inviteErrorMessage(e))];
    }
  }

  Future<List<ShareResult>> _shareEventDirect({
    required String eventId,
    required List<ShareRecipient> recipients,
    Map<String, dynamic>? payloadJson,
  }) async {
    final normalizedRecipients = dedupeShareRecipients(recipients);
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return [
        ShareResult(status: null, error: 'Please sign in to send invites'),
      ];
    }

    final rawEvent = await _client
        .from('user_events')
        .select(
          'id, user_id, title, detail, location, starts_at, ends_at, all_day, flow_local_id',
        )
        .eq('id', eventId)
        .maybeSingle();

    final eventRow = rawEvent is Map<String, dynamic> ? rawEvent : null;
    if (eventRow == null) {
      return [ShareResult(status: null, error: 'Event not found')];
    }

    if ((eventRow['user_id'] as String?) != userId) {
      return [
        ShareResult(
          status: null,
          error: 'You can only invite people to your own events',
        ),
      ];
    }

    final sourceFlowPayload = await _buildEventSourceFlowPayload(
      _parseIntValue(eventRow['flow_local_id']),
    );
    final eventPayload = <String, dynamic>{
      if (payloadJson != null) ...payloadJson,
      'event_id': eventId,
      'title': eventRow['title'],
      'detail': eventRow['detail'],
      'location': eventRow['location'],
      'starts_at': eventRow['starts_at'],
      'ends_at': eventRow['ends_at'],
      'all_day': eventRow['all_day'],
      if (sourceFlowPayload != null) 'source_flow': sourceFlowPayload,
    };
    final inviteTitle =
        (eventRow['title'] as String?)?.trim().isNotEmpty == true
        ? (eventRow['title'] as String).trim()
        : 'an event';

    final results = <ShareResult>[];
    for (final recipient in normalizedRecipients) {
      if (recipient.type != ShareRecipientType.user) {
        results.add(
          ShareResult(
            recipient: recipient,
            status: null,
            error: 'IN_APP_USER_REQUIRED',
          ),
        );
        continue;
      }

      final recipientId = await _resolveRecipientUserId(recipient.value);
      if (recipientId == null || recipientId.isEmpty) {
        results.add(
          ShareResult(
            recipient: recipient,
            status: null,
            error: 'USER_NOT_FOUND',
          ),
        );
        continue;
      }

      if (recipientId == userId) {
        results.add(
          ShareResult(
            recipient: recipient,
            status: null,
            error: 'CANNOT_INVITE_SELF',
          ),
        );
        continue;
      }

      final rawExisting = await _client
          .from('event_shares')
          .select('id')
          .eq('event_id', eventId)
          .eq('sender_id', userId)
          .eq('recipient_id', recipientId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final existingRow = rawExisting is Map<String, dynamic>
          ? rawExisting
          : null;
      final existingId = (existingRow?['id'] as String?)?.trim();

      final insertValues = <String, dynamic>{
        'channel': 'in_app',
        'payload_json': eventPayload,
        'status': 'sent',
        'viewed_at': null,
        'imported_at': null,
        'deleted_at': null,
        'response_status': 'no_response',
        'responded_at': null,
      };
      final updateValues = <String, dynamic>{
        'channel': 'in_app',
        'payload_json': eventPayload,
        'status': 'sent',
        'deleted_at': null,
      };

      try {
        final row = existingId != null && existingId.isNotEmpty
            ? await _updateEventShareRow(existingId, updateValues)
            : await _insertEventShareRow(
                eventId: eventId,
                senderId: userId,
                recipientId: recipientId,
                values: insertValues,
              );
        results.add(
          ShareResult.fromJson({
            ...row,
            'recipient': recipient.toJson(),
            'recipient_id': recipientId,
          }),
        );
        await _sendEventInvitePush(
          recipientId: recipientId,
          shareId: row['id'] as String?,
          title: inviteTitle,
        );
      } catch (e) {
        results.add(
          ShareResult(
            recipient: recipient,
            status: null,
            error: _inviteErrorMessage(e),
          ),
        );
      }
    }

    return results;
  }

  Future<void> _sendEventInvitePush({
    required String recipientId,
    required String? shareId,
    required String title,
  }) async {
    final senderId = _client.auth.currentUser?.id;
    if (senderId == null ||
        senderId.isEmpty ||
        shareId == null ||
        shareId.isEmpty) {
      return;
    }

    try {
      await _client.functions.invoke(
        'send_push',
        body: {
          'userIds': [recipientId],
          'notification': {'title': 'Event invite', 'body': title},
          'data': {
            'type': 'event_invite',
            'kind': 'event_invite',
            'sender_id': senderId,
            'share_id': shareId,
          },
        },
      );
    } catch (e) {
      _log('[ShareRepo] send event invite push failed: $e');
    }
  }

  Future<void> _sendEventInviteResponsePush({
    required String organizerId,
    required String shareId,
    required String eventTitle,
    required EventInviteResponseStatus responseStatus,
  }) async {
    final responderId = _client.auth.currentUser?.id;
    if (responderId == null ||
        responderId.isEmpty ||
        organizerId.isEmpty ||
        shareId.isEmpty) {
      return;
    }

    String responderLabel = 'Someone';
    try {
      final profile = await _client
          .from('profiles')
          .select('display_name, handle')
          .eq('id', responderId)
          .maybeSingle();
      final displayName = (profile?['display_name'] as String?)?.trim();
      final handle = (profile?['handle'] as String?)?.trim();
      if (displayName != null && displayName.isNotEmpty) {
        responderLabel = displayName;
      } else if (handle != null && handle.isNotEmpty) {
        responderLabel = '@$handle';
      }
    } catch (e) {
      _log('[ShareRepo] load responder profile for RSVP push failed: $e');
    }

    final normalizedTitle = eventTitle.trim();
    final responseLabel = responseStatus.label;
    final body = normalizedTitle.isEmpty
        ? '$responseLabel to your event invite'
        : '$responseLabel for $normalizedTitle';

    try {
      await _client.functions.invoke(
        'send_push',
        body: {
          'userIds': [organizerId],
          'notification': {
            'title': 'RSVP update from $responderLabel',
            'body': body,
          },
          'data': {
            'type': 'event_invite',
            'kind': 'event_invite',
            'sender_id': responderId,
            'share_id': shareId,
            'response_status': responseStatus.dbValue,
          },
        },
      );
    } catch (e) {
      _log('[ShareRepo] send event invite response push failed: $e');
    }
  }

  Future<String?> _resolveRecipientUserId(String rawValue) async {
    final byId = await _client
        .from('profiles')
        .select('id')
        .eq('id', rawValue)
        .maybeSingle();
    final idRow = byId is Map<String, dynamic> ? byId : null;
    final id = (idRow?['id'] as String?)?.trim();
    if (id != null && id.isNotEmpty) {
      return id;
    }

    final byHandle = await _client
        .from('profiles')
        .select('id')
        .eq('handle', rawValue)
        .maybeSingle();
    final handleRow = byHandle is Map<String, dynamic> ? byHandle : null;
    return (handleRow?['id'] as String?)?.trim();
  }

  Future<Map<String, dynamic>?> _buildEventSourceFlowPayload(
    int? sourceFlowId,
  ) async {
    if (sourceFlowId == null || sourceFlowId <= 0) {
      return null;
    }

    final rawFlow = await _client
        .from('flows')
        .select(
          'id, name, color, notes, rules, start_date, end_date, is_hidden, is_reminder, reminder_uuid, origin_flow_id, root_flow_id',
        )
        .eq('id', sourceFlowId)
        .maybeSingle();
    final flowRow = rawFlow is Map<String, dynamic> ? rawFlow : null;
    if (flowRow == null) {
      return null;
    }

    final rawFlowEvents = await _client
        .from('user_events')
        .select(
          'client_event_id, title, detail, location, all_day, starts_at, ends_at, category',
        )
        .eq('flow_local_id', sourceFlowId)
        .order('starts_at', ascending: true)
        .order('created_at', ascending: true);

    final flowEvents = (rawFlowEvents as List)
        .cast<Map<String, dynamic>>()
        .where((row) => _cleanNullableString(row['category']) != 'tombstone')
        .map(
          (row) => <String, dynamic>{
            'source_client_event_id': _cleanNullableString(
              row['client_event_id'],
            ),
            'title': _cleanNullableString(row['title']) ?? flowRow['name'],
            'detail': _cleanNullableString(row['detail']),
            'location': _cleanNullableString(row['location']),
            'all_day': _parseBoolishValue(row['all_day']),
            'starts_at': row['starts_at'],
            'ends_at': row['ends_at'],
            'category': _cleanNullableString(row['category']),
          },
        )
        .toList(growable: false);

    return {
      'flow_id': sourceFlowId,
      'name': _cleanNullableString(flowRow['name']) ?? 'Shared Flow',
      'color': _parseIntValue(flowRow['color']) ?? 0x004DD0E1,
      'notes': _cleanNullableString(flowRow['notes']),
      'rules': (flowRow['rules'] as List?) ?? const <dynamic>[],
      'start_date': flowRow['start_date'],
      'end_date': flowRow['end_date'],
      'is_hidden': _parseBoolishValue(flowRow['is_hidden']),
      'is_reminder': _parseBoolishValue(flowRow['is_reminder']),
      'reminder_uuid': _cleanNullableString(flowRow['reminder_uuid']),
      'origin_flow_id': _parseIntValue(flowRow['origin_flow_id']),
      'root_flow_id': _parseIntValue(flowRow['root_flow_id']),
      'events': flowEvents,
    };
  }

  Future<Map<String, dynamic>> _insertEventShareRow({
    required String eventId,
    required String senderId,
    required String recipientId,
    required Map<String, dynamic> values,
  }) async {
    final insertValues = <String, dynamic>{
      'event_id': eventId,
      'sender_id': senderId,
      'recipient_id': recipientId,
      ...values,
    };
    return await _writeEventShareRow(
      action: () => _client
          .from('event_shares')
          .insert(insertValues)
          .select('id, status, response_status')
          .single(),
      legacyAction: () => _client
          .from('event_shares')
          .insert(
            {...insertValues, 'response_status': null, 'responded_at': null}
              ..remove('response_status')
              ..remove('responded_at'),
          )
          .select('id, status')
          .single(),
    );
  }

  Future<Map<String, dynamic>> _updateEventShareRow(
    String shareId,
    Map<String, dynamic> values,
  ) async {
    return await _writeEventShareRow(
      action: () => _client
          .from('event_shares')
          .update(values)
          .eq('id', shareId)
          .select('id, status, response_status')
          .single(),
      legacyAction: () => _client
          .from('event_shares')
          .update(
            {...values}
              ..remove('response_status')
              ..remove('responded_at'),
          )
          .eq('id', shareId)
          .select('id, status')
          .single(),
    );
  }

  Future<Map<String, dynamic>> _writeEventShareRow({
    required Future<dynamic> Function() action,
    required Future<dynamic> Function() legacyAction,
  }) async {
    try {
      final raw = await action();
      return (raw as Map).cast<String, dynamic>();
    } catch (e) {
      if (!_looksLikeInviteSchemaMismatch(e)) rethrow;
      final raw = await legacyAction();
      return (raw as Map).cast<String, dynamic>();
    }
  }

  bool _looksLikeInviteSchemaMismatch(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('response_status') ||
        message.contains('responded_at') ||
        message.contains('column');
  }

  String _inviteErrorMessage(Object error, {bool missingFunction = false}) {
    final message = error.toString();

    if (missingFunction) {
      if (_looksLikeInviteSchemaMismatch(error)) {
        return 'Invite backend is not fully deployed yet. Push the latest database migration.';
      }
      return 'Invite backend is not deployed yet. Deploy the create_event_share function.';
    }

    if (_looksLikeInviteSchemaMismatch(error)) {
      return 'Invite database changes are not deployed yet.';
    }

    if (error is FunctionException && error.status == 404) {
      return 'Invite backend is not deployed yet. Deploy the create_event_share function.';
    }

    if (message.contains('CANNOT_INVITE_SELF')) {
      return 'You cannot invite yourself';
    }
    if (message.contains('USER_NOT_FOUND')) {
      return 'User not found';
    }
    if (message.contains('IN_APP_USER_REQUIRED')) {
      return 'Event invites only support in-app users';
    }

    return 'Could not send invites';
  }

  Future<List<EventInviteeStatus>> getEventInvitees({
    required String eventId,
  }) async {
    try {
      final response = await _client
          .from('event_shares')
          .select(
            'id, recipient_id, viewed_at, responded_at, response_status, '
            'recipient:profiles!event_shares_recipient_id_fkey(handle, display_name, avatar_url)',
          )
          .eq('event_id', eventId)
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: true);

      return (response as List)
          .cast<Map<String, dynamic>>()
          .map(EventInviteeStatus.fromJson)
          .toList(growable: false);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ShareRepo] Error loading event invitees: $e');
        debugPrint('$st');
      }
      return const [];
    }
  }

  Future<bool> respondToEventInvite({
    required String shareId,
    required EventInviteResponseStatus responseStatus,
  }) async {
    bool ok = false;
    try {
      final response = await _client.functions.invoke(
        'respond_to_event_invite',
        body: {'share_id': shareId, 'response_status': responseStatus.dbValue},
      );
      if (response.status >= 200 && response.status < 300) {
        ok = true;
      } else {
        _log(
          '[ShareRepo] respond_to_event_invite returned status=${response.status}; falling back to direct write',
        );
        ok = await _respondToEventInviteDirect(
          shareId: shareId,
          responseStatus: responseStatus,
        );
      }
    } on FunctionException catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ShareRepo] respond_to_event_invite edge call failed: $e');
        debugPrint('$st');
      }
      ok = await _respondToEventInviteDirect(
        shareId: shareId,
        responseStatus: responseStatus,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ShareRepo] Error responding to invite: $e');
        debugPrint('$st');
      }
      ok = await _respondToEventInviteDirect(
        shareId: shareId,
        responseStatus: responseStatus,
      );
    }

    if (ok) {
      try {
        await syncAcceptedInviteCalendarImports();
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[ShareRepo] invite calendar sync failed: $e');
          debugPrint('$st');
        }
      }
    }

    return ok;
  }

  Future<bool> _respondToEventInviteDirect({
    required String shareId,
    required EventInviteResponseStatus responseStatus,
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      return false;
    }

    try {
      final existing = await _client
          .from('event_shares')
          .select('sender_id, response_status, responded_at, payload_json')
          .eq('id', shareId)
          .eq('recipient_id', currentUserId)
          .maybeSingle();
      if (existing == null) {
        _log(
          '[ShareRepo] respondToEventInvite: no matching recipient row found for shareId=$shareId',
        );
        return false;
      }

      final payload = existing['payload_json'] as Map<String, dynamic>?;
      final currentStatus = EventInviteResponseStatus.fromDbValue(
        existing['response_status'] as String?,
      );
      final changed =
          currentStatus != responseStatus || existing['responded_at'] == null;
      final organizerId = (existing['sender_id'] as String?)?.trim() ?? '';
      final now = DateTime.now().toUtc().toIso8601String();
      final updated = await _updateShareRow(
        table: 'event_shares',
        shareId: shareId,
        roleColumn: 'recipient_id',
        values: {
          'viewed_at': now,
          if (changed) 'response_status': responseStatus.dbValue,
          if (changed) 'responded_at': now,
        },
      );
      if (!updated) {
        _log(
          '[ShareRepo] respondToEventInvite: no matching recipient row updated for shareId=$shareId',
        );
        return false;
      }

      if (changed && organizerId.isNotEmpty && organizerId != currentUserId) {
        await _sendEventInviteResponsePush(
          organizerId: organizerId,
          shareId: shareId,
          eventTitle: (payload?['title'] as String?)?.trim() ?? '',
          responseStatus: responseStatus,
        );
      }
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ShareRepo] Direct RSVP update failed: $e');
        debugPrint('$st');
      }
      return false;
    }
  }

  Future<void> syncAcceptedInviteCalendarImports() async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      return;
    }

    final rows = await _client
        .from('event_shares')
        .select('id, payload_json, response_status, deleted_at, status')
        .eq('recipient_id', currentUserId);

    final shareRows = (rows as List)
        .cast<Map<String, dynamic>>()
        .where((row) => (row['id'] as String?)?.trim().isNotEmpty == true)
        .toList(growable: false);

    final acceptedSourceFlowIds = <int>{};
    for (final row in shareRows) {
      if (!_isAcceptedInviteRow(row)) continue;
      final payload = _asMap(row['payload_json']);
      final sourceFlowId = _sourceFlowIdFromPayload(payload);
      if (sourceFlowId != null && sourceFlowId > 0) {
        acceptedSourceFlowIds.add(sourceFlowId);
      }
    }

    final repo = UserEventsRepo(_client);
    for (final row in shareRows) {
      final shareId = (row['id'] as String?)!.trim();
      final payload = _asMap(row['payload_json']);
      try {
        if (_isAcceptedInviteRow(row)) {
          await _applyAcceptedInviteCalendarImport(
            repo: repo,
            shareId: shareId,
            payload: payload,
          );
        } else {
          await _removeInviteCalendarImports(
            repo: repo,
            shareId: shareId,
            payload: payload,
            acceptedSourceFlowIds: acceptedSourceFlowIds,
          );
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint(
            '[ShareRepo] Failed to sync invite import for shareId=$shareId: $e',
          );
          debugPrint('$st');
        }
      }
    }
  }

  bool _isAcceptedInviteRow(Map<String, dynamic> row) {
    if (row['deleted_at'] != null) return false;
    final status = (row['status'] as String?)?.trim().toLowerCase() ?? '';
    if (status.isNotEmpty &&
        status != 'sent' &&
        status != 'viewed' &&
        status != 'imported') {
      return false;
    }
    return EventInviteResponseStatus.fromDbValue(
          row['response_status'] as String?,
        ) ==
        EventInviteResponseStatus.accepted;
  }

  Future<void> _applyAcceptedInviteCalendarImport({
    required UserEventsRepo repo,
    required String shareId,
    required Map<String, dynamic>? payload,
  }) async {
    final sourceFlow = _asMap(payload?['source_flow']);
    final sourceFlowId = _sourceFlowIdFromPayload(payload);
    if (sourceFlow != null && sourceFlowId != null && sourceFlowId > 0) {
      await _upsertImportedFlowFromInvite(
        repo: repo,
        shareId: shareId,
        payload: payload,
        sourceFlow: sourceFlow,
      );
      await repo.deleteByClientId('event_share:$shareId');
      await repo.deleteByClientIdPrefix('event_share_flow:$shareId:');
      return;
    }

    await _upsertStandaloneInviteEvent(
      repo: repo,
      shareId: shareId,
      payload: payload,
    );
    await repo.deleteByClientIdPrefix('event_share_flow:$shareId:');
  }

  Future<void> _removeInviteCalendarImports({
    required UserEventsRepo repo,
    required String shareId,
    required Map<String, dynamic>? payload,
    required Set<int> acceptedSourceFlowIds,
  }) async {
    await repo.deleteByClientId('event_share:$shareId');
    await repo.deleteByClientIdPrefix('event_share_flow:$shareId:');

    final sourceFlowId = _sourceFlowIdFromPayload(payload);
    if (sourceFlowId == null ||
        sourceFlowId <= 0 ||
        acceptedSourceFlowIds.contains(sourceFlowId)) {
      return;
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    final rawByShareId = await _client
        .from('flows')
        .select('id')
        .eq('user_id', userId)
        .eq('origin_type', 'share_import')
        .eq('origin_generation_id', shareId);
    final byShareId = (rawByShareId as List).cast<Map<String, dynamic>>();
    final rawFlows = byShareId.isNotEmpty
        ? byShareId
        : (await _client
                      .from('flows')
                      .select('id')
                      .eq('user_id', userId)
                      .eq('origin_type', 'share_import')
                      .eq('origin_flow_id', sourceFlowId)
                      .isFilter('origin_generation_id', null)
                  as List)
              .cast<Map<String, dynamic>>();

    for (final row in rawFlows) {
      final flowId = (row['id'] as num?)?.toInt();
      if (flowId == null || flowId <= 0) continue;
      await repo.deleteByFlowId(flowId);
      await repo.deleteFlow(flowId);
    }
  }

  Future<void> _upsertStandaloneInviteEvent({
    required UserEventsRepo repo,
    required String shareId,
    required Map<String, dynamic>? payload,
  }) async {
    final startsAt = _parseDateTimeValue(payload?['starts_at']);
    if (startsAt == null) return;

    final title =
        _cleanNullableString(payload?['title']) ??
        _cleanNullableString(payload?['name']) ??
        'Shared Event';
    await repo.upsertByClientId(
      clientEventId: 'event_share:$shareId',
      title: title,
      startsAtUtc: startsAt.toUtc(),
      detail: _cleanNullableString(payload?['detail']),
      location: _cleanNullableString(payload?['location']),
      allDay: _parseBoolishValue(payload?['all_day']),
      endsAtUtc: _parseDateTimeValue(payload?['ends_at'])?.toUtc(),
      category: null,
      caller: 'event_share_accept_import',
    );
  }

  Future<void> _upsertImportedFlowFromInvite({
    required UserEventsRepo repo,
    required String shareId,
    required Map<String, dynamic>? payload,
    required Map<String, dynamic> sourceFlow,
  }) async {
    final sourceFlowId = _parseIntValue(sourceFlow['flow_id']);
    if (sourceFlowId == null || sourceFlowId <= 0) {
      await _upsertStandaloneInviteEvent(
        repo: repo,
        shareId: shareId,
        payload: payload,
      );
      return;
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return;
    }

    final rawExisting = await _loadExistingImportedFlowForInvite(
      userId: userId,
      shareId: shareId,
      sourceFlowId: sourceFlowId,
    );

    final existing = rawExisting is Map<String, dynamic> ? rawExisting : null;
    final existingFlowId = (existing?['id'] as num?)?.toInt();
    final existingReminderUuid = (existing?['reminder_uuid'] as String?)
        ?.trim();
    final existingActive = (existing?['active'] as bool?) ?? true;
    final existingHidden = (existing?['is_hidden'] as bool?) ?? false;
    final existingEndDate = _parseDateOnlyValue(existing?['end_date']);
    final matchedByShareId = existing?['_matched_by_share_id'] == true;

    // Recipient-owned lifecycle state wins over the sender snapshot. If the
    // invitee already ended or hid their imported copy, do not resurrect it on
    // the next accepted-invite sync. Only enforce this for rows already linked
    // to this invite; legacy share_import rows from older builds should be
    // allowed to heal forward into the new share-linked shape.
    if (existingFlowId != null &&
        matchedByShareId &&
        _isLocallyEndedImportedFlow(
          active: existingActive,
          isHidden: existingHidden,
          endDate: existingEndDate,
        )) {
      await repo.deleteByFlowId(existingFlowId);
      return;
    }

    final sourceEvents = _asMapList(sourceFlow['events']);
    final firstEventStart = sourceEvents
        .map((event) => _parseDateTimeValue(event['starts_at']))
        .whereType<DateTime>()
        .fold<DateTime?>(null, (prev, dt) {
          if (prev == null || dt.isBefore(prev)) return dt;
          return prev;
        });
    final lastEventStart = sourceEvents
        .map((event) => _parseDateTimeValue(event['starts_at']))
        .whereType<DateTime>()
        .fold<DateTime?>(null, (prev, dt) {
          if (prev == null || dt.isAfter(prev)) return dt;
          return prev;
        });

    final isReminder = _parseBoolishValue(sourceFlow['is_reminder']);
    final importedReminderUuid = isReminder
        ? ((existingReminderUuid?.isNotEmpty ?? false)
              ? existingReminderUuid!
              : const Uuid().v4())
        : null;
    final importedNotes = isReminder
        ? _rewriteReminderNotesForImport(
            _cleanNullableString(sourceFlow['notes']),
            importedReminderUuid: importedReminderUuid!,
          )
        : _cleanNullableString(sourceFlow['notes']);
    final rulesData = isReminder
        ? const <dynamic>[]
        : (sourceFlow['rules'] as List?) ?? const <dynamic>[];
    final name =
        _cleanNullableString(sourceFlow['name']) ??
        _cleanNullableString(payload?['title']) ??
        'Shared Flow';
    final targetFlowId = await repo.upsertFlow(
      id: existingFlowId,
      name: name,
      color: _parseIntValue(sourceFlow['color']) ?? 0x004DD0E1,
      active: true,
      startDate:
          _parseDateOnlyValue(sourceFlow['start_date']) ?? firstEventStart,
      endDate: _parseDateOnlyValue(sourceFlow['end_date']) ?? lastEventStart,
      notes: importedNotes,
      rules: jsonEncode(rulesData),
      // Accepted imports should show up on the recipient's calendar even if the
      // sender had their own source flow hidden locally.
      isHidden: false,
      isReminder: isReminder,
      reminderUuid: importedReminderUuid,
      originType: 'share_import',
      originFlowId: sourceFlowId,
      // Event invites need a share-linked marker, but origin_share_id is a
      // flow_shares FK. Reuse origin_generation_id as an opaque event_share id.
      originGenerationId: shareId,
      rootFlowId: _parseIntValue(sourceFlow['root_flow_id']) ?? sourceFlowId,
    );

    await repo.deleteByFlowId(targetFlowId);

    // Reminder-backed imports should behave like reminders, not copied notes.
    // The imported flow metadata is enough for the calendar reminder engine to
    // regenerate the visible occurrences on the next refresh.
    if (isReminder) {
      return;
    }

    for (final event in sourceEvents) {
      final startsAt = _parseDateTimeValue(event['starts_at']);
      if (startsAt == null) continue;

      final title = _cleanNullableString(event['title']) ?? name;
      final allDay = _parseBoolishValue(event['all_day']);
      final clientEventId = _buildImportedFlowInviteEventCid(
        flowId: targetFlowId,
        sourceEvent: event,
      );

      await repo.upsertByClientId(
        clientEventId: clientEventId,
        title: title,
        startsAtUtc: startsAt.toUtc(),
        detail: _cleanNullableString(event['detail']),
        location: _cleanNullableString(event['location']),
        allDay: allDay,
        endsAtUtc: _parseDateTimeValue(event['ends_at'])?.toUtc(),
        flowLocalId: targetFlowId,
        category: _cleanNullableString(event['category']),
        caller: 'event_share_flow_import',
      );
    }
  }

  int? _sourceFlowIdFromPayload(Map<String, dynamic>? payload) {
    final sourceFlow = _asMap(payload?['source_flow']);
    if (sourceFlow == null) return null;
    return _parseIntValue(sourceFlow['flow_id']);
  }

  Future<Map<String, dynamic>?> _loadExistingImportedFlowForInvite({
    required String userId,
    required String shareId,
    required int sourceFlowId,
  }) async {
    final byShareId = await _client
        .from('flows')
        .select('id, reminder_uuid, active, is_hidden, end_date')
        .eq('user_id', userId)
        .eq('origin_type', 'share_import')
        .eq('origin_generation_id', shareId)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (byShareId is Map<String, dynamic>) {
      return {...byShareId, '_matched_by_share_id': true};
    }

    final legacy = await _client
        .from('flows')
        .select('id, reminder_uuid, active, is_hidden, end_date')
        .eq('user_id', userId)
        .eq('origin_type', 'share_import')
        .eq('origin_flow_id', sourceFlowId)
        .isFilter('origin_generation_id', null)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return legacy is Map<String, dynamic>
        ? {...legacy, '_matched_by_share_id': false}
        : null;
  }

  bool _isLocallyEndedImportedFlow({
    required bool active,
    required bool isHidden,
    required DateTime? endDate,
  }) {
    if (!active || isHidden) {
      return true;
    }
    if (endDate == null) {
      return false;
    }
    final endUtc = endDate.toUtc();
    final endDateOnly = DateTime.utc(endUtc.year, endUtc.month, endUtc.day);
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    return endDateOnly.isBefore(today);
  }

  Map<String, dynamic>? _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  List<Map<String, dynamic>> _asMapList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  int? _parseIntValue(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  bool _parseBoolishValue(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is! String) return false;
    switch (raw.trim().toLowerCase()) {
      case '1':
      case 'true':
      case 't':
      case 'yes':
      case 'y':
        return true;
      default:
        return false;
    }
  }

  DateTime? _parseDateTimeValue(Object? raw) {
    if (raw is DateTime) return raw;
    if (raw is! String || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  DateTime? _parseDateOnlyValue(Object? raw) {
    final parsed = _parseDateTimeValue(raw);
    if (parsed == null) return null;
    final local = parsed.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  String? _cleanNullableString(Object? raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _rewriteReminderNotesForImport(
    String? rawNotes, {
    required String importedReminderUuid,
  }) {
    if (rawNotes == null || rawNotes.trim().isEmpty) {
      return jsonEncode({'id': importedReminderUuid});
    }

    try {
      final decoded = jsonDecode(rawNotes);
      if (decoded is! Map) return rawNotes;
      final map = Map<String, dynamic>.from(decoded);
      final rawId = map['id']?.toString().trim();
      if (rawId == null || rawId.isEmpty) {
        map['id'] = importedReminderUuid;
      } else if (rawId.startsWith('nutrition:')) {
        map['id'] = 'nutrition:$importedReminderUuid';
      } else if (_looksLikeUuidString(rawId)) {
        map['id'] = importedReminderUuid;
      }
      return jsonEncode(map);
    } catch (_) {
      return rawNotes;
    }
  }

  bool _looksLikeUuidString(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  String _buildImportedFlowInviteEventCid({
    required int flowId,
    required Map<String, dynamic> sourceEvent,
  }) {
    final sourceClientEventId = _cleanNullableString(
      sourceEvent['source_client_event_id'],
    );
    final startsAt = _parseDateTimeValue(
      sourceEvent['starts_at'],
    )?.toUtc().toIso8601String();
    final title = _cleanNullableString(sourceEvent['title']) ?? 'event';
    final sourceKey =
        sourceClientEventId ??
        '$startsAt|${Uri.encodeComponent(title)}|${_cleanNullableString(sourceEvent['location']) ?? ''}';
    return 'flow_import:$flowId:${Uri.encodeComponent(sourceKey)}';
  }

  /// Resolve a share link and get flow details for preview
  Future<Map<String, dynamic>> resolveShare({
    required String shareId,
    String? token,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'resolve_share',
        body: {'share_id': shareId, if (token != null) 'token': token},
      );

      if (response.status != 200) {
        throw Exception('Failed to resolve share: ${response.data}');
      }

      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Error resolving share: $e');
    }
  }

  /// Get inbox items for current user
  Future<List<InboxShareItem>> getInboxItems({
    int limit = 50,
    int offset = 0,
  }) async {
    _log('📬 [ShareRepo] getInboxItems() called');
    _log('📬 [ShareRepo] User ID: ${_client.auth.currentUser?.id}');

    try {
      final items = await _fetchInboxItems(
        limit: limit,
        offset: offset,
        verbose: true,
      );
      return items;
    } catch (e, stackTrace) {
      _log('❌ [ShareRepo] Error fetching inbox items: $e');
      _log('❌ [ShareRepo] Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get unread count for inbox badge
  Future<int> getUnreadCount() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return 0;

    try {
      final resp = await _client
          .from('inbox_share_items_filtered')
          .select('share_id')
          .eq('recipient_id', uid)
          .neq('kind', 'event')
          .filter('viewed_at', 'is', null)
          .filter('deleted_at', 'is', null);

      return resp.length;
    } catch (e) {
      _log('[ShareRepo] Error fetching unread count: $e');
      return 0;
    }
  }

  /// Mark a share as viewed
  Future<bool> markViewed(String shareId, {required bool isFlow}) async {
    try {
      final table = isFlow ? 'flow_shares' : 'event_shares';
      return await _updateShareRow(
        table: table,
        shareId: shareId,
        roleColumn: 'recipient_id',
        values: {'viewed_at': DateTime.now().toUtc().toIso8601String()},
      );
    } catch (e) {
      _log('[ShareRepo] Error marking as viewed: $e');
      return false;
    }
  }

  /// Mark a share as imported
  Future<bool> markImported(String shareId, {required bool isFlow}) async {
    try {
      final table = isFlow ? 'flow_shares' : 'event_shares';
      return await _updateShareRow(
        table: table,
        shareId: shareId,
        roleColumn: 'recipient_id',
        values: {'imported_at': DateTime.now().toUtc().toIso8601String()},
      );
    } catch (e) {
      _log('[ShareRepo] Error marking as imported: $e');
      return false;
    }
  }

  /// Low-level helper: soft-delete a share row by role (sender or recipient).
  /// Returns true if update succeeds, false on error.
  /// Note: This will fail silently until backend adds `deleted_at` column.
  Future<bool> _softDeleteShare({
    required String shareId,
    required bool isFlow,
    required String roleColumn, // 'sender_id' or 'recipient_id'
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          debugPrint('[ShareRepo] softDelete: no auth user');
        }
        return false;
      }

      final userId = user.id;
      final table = isFlow ? 'flow_shares' : 'event_shares';
      final now = DateTime.now().toUtc().toIso8601String();

      if (kDebugMode) {
        debugPrint(
          '[ShareRepo] softDelete table=$table shareId=$shareId roleColumn=$roleColumn userId=$userId',
        );
      }

      final updated = await _updateShareRow(
        table: table,
        shareId: shareId,
        roleColumn: roleColumn,
        userId: userId,
        values: {'deleted_at': now},
      );
      if (!updated) {
        if (kDebugMode) {
          debugPrint(
            '[ShareRepo] softDelete: no matching row updated for shareId=$shareId',
          );
        }
        return false;
      }

      if (kDebugMode) {
        debugPrint('[ShareRepo] ✓ softDelete success for shareId=$shareId');
      }

      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ShareRepo] ✗ softDelete error: $e');
        debugPrint('$st');
        // In dev, you can distinguish error types for better debugging:
        if (e is PostgrestException) {
          debugPrint(
            '[ShareRepo] Postgrest error: code=${e.code}, message=${e.message}',
          );
          if (e.code == 'PGRST116') {
            // Column doesn't exist
            debugPrint('[ShareRepo] ⚠️ deleted_at column may not exist yet');
          }
        }
      }
      return false;
    }
  }

  /// Delete from your inbox (you are the recipient).
  Future<bool> deleteInboxItem(String shareId, {required bool isFlow}) {
    return _softDeleteShare(
      shareId: shareId,
      isFlow: isFlow,
      roleColumn: 'recipient_id',
    );
  }

  /// Unsend something you sent (you are the sender).
  Future<bool> unsendShare(String shareId, {required bool isFlow}) {
    return _softDeleteShare(
      shareId: shareId,
      isFlow: isFlow,
      roleColumn: 'sender_id',
    );
  }

  Future<List<InboxShareItem>> _fetchInboxItems({
    int? limit,
    int offset = 0,
    bool verbose = false,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (verbose) {
      _log('📬 [ShareRepo] Querying inbox_share_items_filtered...');
    }

    dynamic query = _client
        .from('inbox_share_items_filtered')
        .select()
        .order('created_at', ascending: false);
    if (limit != null) {
      query = query.range(offset, offset + limit - 1);
    }

    final response = await query;
    if (verbose) {
      _log('📬 [ShareRepo] Raw response type: ${response.runtimeType}');
      _log('📬 [ShareRepo] Raw response: $response');
    }

    final rows = response.cast<Map<String, dynamic>>();
    final filtered = uid == null
        ? rows
        : rows
              .where((row) {
                final senderId = row['sender_id'] as String?;
                final recipientId = row['recipient_id'] as String?;
                return senderId == uid || recipientId == uid;
              })
              .toList(growable: false);
    if (verbose) {
      _log(
        '📬 [ShareRepo] Response has ${rows.length} rows, ${filtered.length} visible to uid=$uid',
      );
    }

    final items = filtered
        .map((item) {
          if (verbose) {
            _log('📬 [ShareRepo] Parsing item: ${item['share_id']}');
          }
          return InboxShareItem.fromJson(item);
        })
        .toList(growable: false);

    if (verbose) {
      _log('✅ [ShareRepo] Successfully parsed ${items.length} items');
    }
    return items;
  }

  Future<bool> _updateShareRow({
    required String table,
    required String shareId,
    required Map<String, dynamic> values,
    String? roleColumn,
    String? userId,
  }) async {
    dynamic query = _client.from(table).update(values).eq('id', shareId);
    if (roleColumn != null) {
      final actorId = userId ?? _client.auth.currentUser?.id;
      if (actorId == null || actorId.isEmpty) {
        return false;
      }
      query = query.eq(roleColumn, actorId);
    }

    final updated = await query.select('id').maybeSingle();
    return updated is Map;
  }

  /// Search for users by handle
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return [];

      final response = await _client
          .from('profiles')
          .select('id, handle, display_name, avatar_url, is_discoverable')
          .ilike('handle', '%$query%')
          .eq('is_discoverable', true)
          .limit(10);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _log('[ShareRepo] Error searching users: $e');
      return [];
    }
  }

  /// Watch inbox for real-time updates
  Stream<List<InboxShareItem>> watchInbox() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      if (kDebugMode) {
        debugPrint(
          '[watchInbox] No authenticated user, returning empty stream',
        );
      }
      return Stream.value(const []);
    }

    return _client
        .from('inbox_share_items_filtered')
        .stream(primaryKey: ['share_id'])
        .order('created_at', ascending: false)
        .map((data) {
          final list = (data as List?) ?? const [];
          final filtered = list.cast<Map<String, dynamic>>().where((row) {
            final senderId = row['sender_id'] as String?;
            final recipientId = row['recipient_id'] as String?;
            return senderId == uid || recipientId == uid;
          }).toList();

          if (kDebugMode) {
            debugPrint(
              '[watchInbox] ${list.length} raw items, ${filtered.length} filtered (uid=$uid)',
            );
          }

          return filtered
              .map((item) => InboxShareItem.fromJson(item))
              .toList(growable: false);
        });
  }

  Stream<List<InboxShareItem>> watchPendingEventInvites() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      return Stream.value(const []);
    }

    return watchInbox().map((items) {
      final invites = items.where((item) {
        return item.isPendingEventInvite && item.recipientId == uid;
      }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return invites;
    });
  }

  /// Watch unread count for real-time updates
  Stream<int> watchUnreadCount() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      return Stream.value(0);
    }
    final controller = StreamController<int>();

    Future<void> refreshUnreadCount() async {
      final count = await getUnreadCount();
      if (!controller.isClosed) controller.add(count);
    }

    // Subscribe to both flow and event shares for this recipient
    final channel = _client.channel('inbox_unread_$uid')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'flow_shares',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'recipient_id',
          value: uid,
        ),
        callback: (_) => refreshUnreadCount(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'event_shares',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'recipient_id',
          value: uid,
        ),
        callback: (_) => refreshUnreadCount(),
      )
      ..subscribe();

    // Initial load
    refreshUnreadCount();

    controller.onCancel = () async {
      await channel.unsubscribe();
      await controller.close();
    };

    return controller.stream.distinct();
  }
}

enum InboxActivityType { like, comment, follow }

class InboxActivityItem {
  InboxActivityItem({
    required this.type,
    required this.createdAt,
    this.actorId,
    this.actorHandle,
    this.actorName,
    this.actorAvatar,
    this.flowPostId,
    this.flowName,
    this.commentPreview,
  });

  final InboxActivityType type;
  final DateTime createdAt;
  final String? actorId;
  final String? actorHandle;
  final String? actorName;
  final String? actorAvatar;
  final String? flowPostId;
  final String? flowName;
  final String? commentPreview;
}
