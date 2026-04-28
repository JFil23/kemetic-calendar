// lib/repositories/inbox_repo.dart
// FIXED VERSION - Correctly checks if user has imported flow
//
// KEY FIX: The old code was checking flow_shares.flow_id (sender's original flow)
// The new code checks flows.share_id (user's imported copy linked to inbox share)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../data/share_models.dart';
import '../data/share_repo.dart';
import '../data/user_events_repo.dart';
import '../features/calendar/calendar_page.dart' show CalendarPage, KemeticMath;
import '../utils/event_cid_util.dart';

Map<String, ({int count, bool likedByMe})> aggregateDmMessageLikeStates(
  Iterable<String> shareIds,
  Iterable<Map<String, dynamic>> rows,
  String? currentUserId,
) {
  final ids = shareIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();
  final states = <String, ({int count, bool likedByMe})>{
    for (final id in ids) id: (count: 0, likedByMe: false),
  };

  if (ids.isEmpty) return states;

  for (final row in rows) {
    final shareId = row['message_share_id'] as String?;
    if (shareId == null || shareId.isEmpty) continue;
    final previous = states[shareId] ?? (count: 0, likedByMe: false);
    states[shareId] = (
      count: previous.count + 1,
      likedByMe: previous.likedByMe || row['user_id'] == currentUserId,
    );
  }

  return states;
}

bool isMissingDmFunctionError(Object error) {
  if (error is FunctionException && error.status == 404) {
    return true;
  }

  final message = error.toString().toLowerCase();
  return message.contains('send_dm_message') &&
      (message.contains('404') ||
          message.contains('not found') ||
          message.contains('does not exist'));
}

bool shouldRetryDmPushFromResponse(dynamic responseData) {
  final body = _asDmMap(responseData);
  if (body == null) return false;

  final pushError = _asDmString(body['pushError']);
  if (pushError != null && pushError.isNotEmpty) {
    return true;
  }

  final push = _asDmMap(body['push']);
  if (push == null) return false;

  final delivered =
      push['delivered'] == true ||
      _asDmString(push['delivered'])?.toLowerCase() == 'true';
  if (delivered) return false;

  final reason = _asDmString(push['reason'])?.toLowerCase();
  return reason == 'missing_internal_function_key' || reason == 'unauthorized';
}

String userFacingDmSendError(Object error) {
  final message = error.toString().toLowerCase();

  if (message.contains('not signed in')) {
    return 'Please sign in to send messages.';
  }
  if (message.contains('cannot message yourself')) {
    return 'You cannot message yourself.';
  }
  if (message.contains('recipient not found')) {
    return 'That user could not be found.';
  }
  if (message.contains('not accepting messages')) {
    return 'That user is not accepting messages right now.';
  }
  if (isMissingDmFunctionError(error)) {
    return 'Messaging is updating right now. Please try again in a moment.';
  }

  return 'Could not send message right now. Please try again.';
}

Map<String, dynamic>? _asDmMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

String? _asDmString(dynamic value) {
  if (value == null) return null;
  final text = value is String ? value : value.toString();
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class InboxRepo {
  final SupabaseClient _client;
  final ShareRepo _shareRepo;

  InboxRepo(this._client) : _shareRepo = ShareRepo(_client);

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  String? get currentUserId => _client.auth.currentUser?.id;

  /// Watch inbox items stream (delegates to ShareRepo)
  Stream<List<InboxShareItem>> watchInbox() => _shareRepo.watchInbox();

  /// Check if a shared flow is currently imported and exists in user's flows
  ///
  /// FIXED: Now correctly looks for flows with share_id, not flow_shares.flow_id
  ///
  /// How it works:
  /// 1. When user imports: new flow created with share_id = inbox item id
  /// 2. This method checks: does user have a flow with share_id = shareId?
  /// 3. After deletion: trigger clears imported_at, this returns false
  /// 4. Re-import: button reactivates because no matching flow exists
  Future<bool> isFlowCurrentlyImported(String shareId) async {
    bool isActiveByEndDateStr(String? endDateStr) {
      if (endDateStr == null) return true;
      final end = DateTime.parse(endDateStr).toUtc();
      final endDateOnly = DateTime.utc(end.year, end.month, end.day);
      final now = DateTime.now().toUtc();
      final today = DateTime.utc(now.year, now.month, now.day);
      return !endDateOnly.isBefore(today);
    }

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        _log('[InboxRepo] No user logged in');
        return false;
      }

      // ✅ CORRECT: Look in user's flows table for a flow with this share_id
      // This finds the USER'S imported copy, not the sender's original
      final flowResponse = await _client
          .from('flows')
          .select('id, active, share_id, end_date')
          .eq('user_id', userId) // User's flows only
          .eq('share_id', shareId) // Linked to this inbox share
          .eq('active', true) // Must be active
          .maybeSingle();

      // Flow is imported if it exists, is active, and not past end_date
      final exists =
          flowResponse != null &&
          (flowResponse['active'] as bool? ?? false) &&
          isActiveByEndDateStr(flowResponse['end_date'] as String?);

      if (kDebugMode) {
        _log('[InboxRepo] isFlowCurrentlyImported($shareId)');
        _log('[InboxRepo]   userId: $userId');
        _log('[InboxRepo]   exists: $exists');
        if (flowResponse != null) {
          _log('[InboxRepo]   flow_id: ${flowResponse['id']}');
          _log('[InboxRepo]   active: ${flowResponse['active']}');
          _log('[InboxRepo]   share_id: ${flowResponse['share_id']}');
          _log('[InboxRepo]   end_date: ${flowResponse['end_date']}');
        } else {
          _log('[InboxRepo]   No flow found with share_id=$shareId');
        }
      }

      return exists;
    } catch (e) {
      _log('[InboxRepo] ❌ Error checking import status: $e');
      return false;
    }
  }

  /// Mark a share as imported (delegates to ShareRepo)
  Future<bool> markImported(String shareId, {required bool isFlow}) {
    return _shareRepo.markImported(shareId, isFlow: isFlow);
  }

  /// Clear import status (manually called or triggered by deletion)
  Future<bool> clearImportStatus(String shareId, {required bool isFlow}) async {
    try {
      final table = isFlow ? 'flow_shares' : 'event_shares';
      await _client.from(table).update({'imported_at': null}).eq('id', shareId);

      _log('[InboxRepo] Cleared import status for $shareId in $table');

      return true;
    } catch (e) {
      _log('[InboxRepo] Error clearing import status: $e');
      return false;
    }
  }

  /// Get all shares for the current user
  Future<List<InboxShareItem>> getShares() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from('inbox_share_items_filtered')
          .select()
          .eq('recipient_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => InboxShareItem.fromJson(json))
          .toList();
    } catch (e) {
      _log('[InboxRepo] Error loading shares: $e');
      return [];
    }
  }

  /// Watch conversations grouped by other user ID (DM-style)
  Stream<Map<String, List<InboxShareItem>>> watchConversations() {
    return watchInbox().map((items) {
      final uid = currentUserId;
      if (uid == null) return <String, List<InboxShareItem>>{};

      final Map<String, List<InboxShareItem>> grouped = {};

      for (final item in items) {
        // ✅ Skip deleted items
        if (item.isDeleted || item.isEvent || item.isCalendar) continue;

        final otherId = _getOtherUserId(item, uid);
        if (otherId == null) continue;
        grouped.putIfAbsent(otherId, () => []).add(item);
      }

      // Sort each thread by createdAt ascending (older → newer)
      for (final list in grouped.values) {
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }

      if (kDebugMode) {
        debugPrint(
          '[watchConversations] ${grouped.length} conversations, keys: ${grouped.keys.toList()}',
        );
        // ✅ Add per-thread logging
        for (final entry in grouped.entries) {
          debugPrint(
            '[watchConversations] otherId=${entry.key} items=${entry.value.length}',
          );
        }
      }

      return grouped;
    });
  }

  /// Send a plain text message into a conversation thread.
  /// Uses flow_shares with a hidden placeholder flow owned by the sender.
  Future<InboxShareItem?> sendTextMessage({
    required String recipientId,
    required String text,
  }) async {
    final senderId = currentUserId;
    if (senderId == null) {
      throw Exception('Not signed in');
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    try {
      final response = await _client.functions.invoke(
        'send_dm_message',
        body: {'recipientId': recipientId, 'text': trimmed},
      );
      final body = _asDmMap(response.data);
      if (response.status >= 400) {
        final message = _asDmString(body?['error'] ?? body?['message']);
        throw Exception(message ?? 'HTTP ${response.status}');
      }

      if (shouldRetryDmPushFromResponse(body)) {
        final share = _asDmMap(body?['share']);
        unawaited(
          _sendDmPushFallback(
            recipientId: recipientId,
            senderId: senderId,
            text: trimmed,
            shareId: _asDmString(share?['id']),
          ),
        );
      }
      return null;
    } on FunctionException catch (e, st) {
      if (isMissingDmFunctionError(e)) {
        if (kDebugMode) {
          debugPrint(
            '[InboxRepo] send_dm_message missing, using direct DM fallback',
          );
          debugPrint('$st');
        }
        await _sendTextMessageDirect(
          senderId: senderId,
          recipientId: recipientId,
          text: trimmed,
        );
        return null;
      }
      rethrow;
    } catch (e, st) {
      if (isMissingDmFunctionError(e)) {
        if (kDebugMode) {
          debugPrint(
            '[InboxRepo] send_dm_message unavailable, using direct DM fallback',
          );
          debugPrint('$st');
        }
        await _sendTextMessageDirect(
          senderId: senderId,
          recipientId: recipientId,
          text: trimmed,
        );
        return null;
      }
      if (kDebugMode) {
        debugPrint('[InboxRepo] sendTextMessage failed: $e');
        debugPrint('$st');
      }
      rethrow;
    }
  }

  /// Watch a specific conversation with another user
  Stream<List<InboxShareItem>> watchConversationWith(String otherUserId) {
    return watchInbox().map((items) {
      final uid = currentUserId;
      if (uid == null) return <InboxShareItem>[];

      final conv = items.where((item) {
        final a = item.senderId == uid && item.recipientId == otherUserId;
        final b = item.senderId == otherUserId && item.recipientId == uid;
        return (a || b) && !item.isDeleted && !item.isEvent && !item.isCalendar;
      }).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return conv;
    });
  }

  Future<void> _sendTextMessageDirect({
    required String senderId,
    required String recipientId,
    required String text,
  }) async {
    final recipient = await _client
        .from('profiles')
        .select('id, allow_incoming_shares')
        .eq('id', recipientId)
        .maybeSingle();

    if (recipient == null || _asDmString(recipient['id']) == null) {
      throw Exception('Recipient not found');
    }
    if (recipient['allow_incoming_shares'] == false) {
      throw Exception('Recipient is not accepting messages right now');
    }

    final dmFlowId = await _ensureDmPlaceholderFlow(senderId);
    final payload = {'type': 'message', 'text': text, 'name': text};
    final inserted = await _client
        .from('flow_shares')
        .insert({
          'flow_id': dmFlowId,
          'sender_id': senderId,
          'recipient_id': recipientId,
          'channel': 'in_app',
          'status': 'sent',
          'payload_json': payload,
        })
        .select('id')
        .single();

    await _sendDmPushFallback(
      recipientId: recipientId,
      senderId: senderId,
      text: text,
      shareId: _asDmString(inserted['id']),
    );
  }

  Future<int> _ensureDmPlaceholderFlow(String senderId) async {
    final existing = await _client
        .from('flows')
        .select('id')
        .eq('user_id', senderId)
        .eq('notes', '__dm_placeholder__')
        .order('id', ascending: true)
        .limit(1)
        .maybeSingle();

    final existingId = existing?['id'];
    if (existingId is int) return existingId;
    if (existingId is num) return existingId.toInt();

    final inserted = await _client
        .from('flows')
        .insert({
          'user_id': senderId,
          'name': 'DM Messages',
          'color': 0,
          'active': false,
          'rules': [],
          'notes': '__dm_placeholder__',
          'ai_metadata': {'dm_placeholder': true},
        })
        .select('id')
        .single();

    final insertedId = inserted['id'];
    if (insertedId is int) return insertedId;
    if (insertedId is num) return insertedId.toInt();
    throw Exception('Failed to create DM placeholder flow');
  }

  Future<void> _sendDmPushFallback({
    required String recipientId,
    required String senderId,
    required String text,
    String? shareId,
  }) async {
    final senderProfile = await _client
        .from('profiles')
        .select('display_name, handle')
        .eq('id', senderId)
        .maybeSingle();

    final displayName = _asDmString(senderProfile?['display_name']);
    final handle = _asDmString(senderProfile?['handle']);
    final senderLabel =
        displayName ?? (handle != null ? '@$handle' : 'Someone');
    final preview = text.length > 120 ? '${text.substring(0, 120)}...' : text;

    try {
      await _client.functions.invoke(
        'send_push',
        body: {
          'userIds': [recipientId],
          'notification': {
            'title': 'New message from $senderLabel',
            'body': preview,
          },
          'data': {
            'type': 'dm',
            'kind': 'dm',
            'sender_id': senderId,
            if (shareId != null && shareId.isNotEmpty) 'share_id': shareId,
          },
        },
      );
    } catch (e) {
      _log('[InboxRepo] DM push fallback failed: $e');
    }
  }

  Future<Map<String, ({int count, bool likedByMe})>> getMessageLikeStates(
    Iterable<String> shareIds,
  ) async {
    final userId = currentUserId;
    final ids = shareIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (userId == null || ids.isEmpty) return const {};

    try {
      final rows = await _client
          .from('dm_message_likes')
          .select('message_share_id, user_id')
          .inFilter('message_share_id', ids);
      return aggregateDmMessageLikeStates(
        ids,
        (rows as List<dynamic>? ?? const []).cast<Map<String, dynamic>>(),
        userId,
      );
    } catch (e) {
      if (_isMissingTable(e, 'dm_message_likes')) {
        throw const InboxMessageLikesUnavailable('dm_message_likes');
      }
      _log('[InboxRepo] Error fetching message likes: $e');
      return {for (final id in ids) id: (count: 0, likedByMe: false)};
    }
  }

  Future<bool> setMessageLike(String shareId, {required bool like}) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      if (like) {
        await _client.from('dm_message_likes').upsert({
          'message_share_id': shareId,
          'user_id': userId,
        }, onConflict: 'message_share_id,user_id');
      } else {
        await _client
            .from('dm_message_likes')
            .delete()
            .eq('message_share_id', shareId)
            .eq('user_id', userId);
      }

      return true;
    } catch (e) {
      if (_isMissingTable(e, 'dm_message_likes')) {
        throw const InboxMessageLikesUnavailable('dm_message_likes');
      }
      _log('[InboxRepo] Error updating message like: $e');
      return false;
    }
  }

  Future<void> sendMessageLikePush({
    required String targetUserId,
    required String likerUserId,
    required String messageText,
    String? shareId,
  }) async {
    final normalizedTargetUserId = targetUserId.trim();
    final normalizedLikerUserId = likerUserId.trim();
    if (normalizedTargetUserId.isEmpty || normalizedLikerUserId.isEmpty) {
      return;
    }
    if (normalizedTargetUserId == normalizedLikerUserId) return;

    try {
      final likerProfile = await _client
          .from('profiles')
          .select('display_name, handle')
          .eq('id', normalizedLikerUserId)
          .maybeSingle();

      final displayName = _asDmString(likerProfile?['display_name']);
      final handle = _asDmString(likerProfile?['handle']);
      final likerLabel =
          displayName ?? (handle != null ? '@$handle' : 'Someone');
      final preview = messageText.trim();
      final body = preview.isEmpty
          ? 'Tap to open the conversation.'
          : (preview.length > 120
                ? '${preview.substring(0, 120)}...'
                : preview);

      await _client.functions.invoke(
        'send_push',
        body: {
          'userIds': [normalizedTargetUserId],
          'notification': {
            'title': '$likerLabel liked your message',
            'body': body,
          },
          'data': {
            'type': 'dm_message_like',
            'kind': 'dm',
            'sender_id': normalizedLikerUserId,
            if (shareId != null && shareId.trim().isNotEmpty)
              'share_id': shareId.trim(),
          },
        },
      );
    } catch (e) {
      _log('[InboxRepo] DM like push failed: $e');
    }
  }

  /// Get the "other" user ID from a share item
  String? _getOtherUserId(InboxShareItem item, String uid) {
    if (item.senderId == uid) return item.recipientId;
    if (item.recipientId == uid) return item.senderId;
    return null;
  }

  /// Import a shared flow with optional start date override
  /// Returns the new flow ID on success
  Future<int> importSharedFlow({
    required InboxShareItem share,
    DateTime? overrideStartDate,
  }) async {
    _log('[InboxRepo] Starting import for: ${share.title}');

    try {
      // ✅ Make import resilient - handle null/empty payload gracefully
      final payloadJson = share.payloadJson ?? const <String, dynamic>{};

      // ✅ Use nullable casts with fallbacks to prevent type errors
      final name = (payloadJson['name'] as String?) ?? share.title;
      final color = payloadJson['color'] as int? ?? 0xFF4DD0E1;
      final notes = payloadJson['notes'] as String?;
      final rulesData = payloadJson['rules'] as List<dynamic>? ?? const [];

      // Determine start date
      DateTime? startDate = overrideStartDate;
      if (startDate == null && share.suggestedSchedule != null) {
        try {
          startDate = DateTime.parse(share.suggestedSchedule!.startDate);
        } catch (e) {
          _log('[InboxRepo] Failed to parse start date: $e');
        }
      }

      if (kDebugMode) {
        _log('[InboxRepo] Flow data: name=$name, color=$color');
        _log('[InboxRepo] Rules type: ${rulesData.runtimeType}');
      }

      final originFlowId =
          (payloadJson['flow_id'] as num?)?.toInt() ??
          int.tryParse(share.payloadId);

      // Convert rules from List to JSON String
      final rulesString = jsonEncode(rulesData);

      // Import the flow using UserEventsRepo
      final userEventsRepo = UserEventsRepo(_client);
      final flowId = await userEventsRepo.upsertFlow(
        name: name,
        color: color,
        active: true,
        startDate: startDate,
        notes: notes,
        rules: rulesString,
        originType: 'share_import',
        originShareId: share.shareId,
        originFlowId: originFlowId,
        rootFlowId: originFlowId,
      );

      _log('[InboxRepo] ✓ Flow created with ID: $flowId');

      // Link the flow to the share for re-import tracking
      await userEventsRepo.updateFlowShareId(
        flowId: flowId,
        shareId: share.shareId,
      );

      _log('[InboxRepo] ✓ Flow linked to share: ${share.shareId}');

      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        try {
          await _client.from('flow_saves').upsert({
            'user_id': userId,
            'flow_id': flowId,
            'saved_from': 'share',
            'metadata': {
              'share_id': share.shareId,
              if (originFlowId != null) 'origin_flow_id': originFlowId,
            },
          }, onConflict: 'user_id,flow_id');
        } catch (e) {
          _log('[InboxRepo] flow_saves upsert failed: $e');
        }
      }

      // Mark the share as imported
      final success = await markImported(share.shareId, isFlow: true);
      if (!success) {
        throw Exception('Failed to mark share as imported');
      }

      _log('[InboxRepo] ✓ Share marked as imported');

      // Schedule the flow's notes immediately (using the selected start date)
      await _scheduleImportedFlow(flowId, share, startDate: startDate);

      return flowId;
    } catch (e, stackTrace) {
      _log('[InboxRepo] ✗ Import failed: $e');
      _log('[InboxRepo] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Schedule notes for a newly imported flow
  /// ✅ FIXED: Uses sender's event snapshots if available, preserving exact titles/details/locations
  Future<void> _scheduleImportedFlow(
    int flowId,
    InboxShareItem item, {
    DateTime? startDate,
  }) async {
    try {
      final payloadJson = item.payloadJson;
      if (payloadJson == null) return;

      final repo = UserEventsRepo(_client);
      final start = startDate ?? DateTime.now();

      // Clear existing notes for this flow
      await repo.deleteByFlowId(flowId, fromDate: start.toUtc());

      if (kDebugMode) {
        _log('[InboxRepo] _scheduleImportedFlow for flowId=$flowId');
        _log('[InboxRepo] payloadJson keys: ${payloadJson.keys}');
      }

      // ✅ 1. Use sender's event snapshots if present (NEW SHARES)
      final events = payloadJson['events'] as List<dynamic>?;
      if (events != null && events.isNotEmpty) {
        _log(
          '[InboxRepo] Importing ${events.length} snapshot events for flow $flowId',
        );

        final baseDate = DateTime(start.year, start.month, start.day);
        int count = 0;

        for (final raw in events) {
          final e = raw as Map<String, dynamic>;

          final offset = (e['offset_days'] as num?)?.toInt() ?? 0;
          final date = baseDate.add(Duration(days: offset));

          final allDay = e['all_day'] as bool? ?? false;
          final title = (e['title'] as String?) ?? item.title;
          final rawDetail = (e['detail'] as String?) ?? '';
          // Remove legacy "flowLocalId=123;1)" prefix if present (defensive)
          final detail = rawDetail.replaceFirst(
            RegExp(r'^flowLocalId=\d+;\d+\)\s*'),
            '',
          );
          final location = e['location'] as String?;

          int startHour = 9;
          int startMinute = 0;
          int? endHour;
          int? endMinute;

          final startTime = e['start_time'] as String?;
          final endTime = e['end_time'] as String?;

          if (!allDay && startTime != null && startTime.length >= 5) {
            startHour = int.parse(startTime.substring(0, 2));
            startMinute = int.parse(startTime.substring(3, 5));
          }
          if (!allDay && endTime != null && endTime.length >= 5) {
            endHour = int.parse(endTime.substring(0, 2));
            endMinute = int.parse(endTime.substring(3, 5));
          }

          final kDate = KemeticMath.fromGregorian(date);

          final cid = EventCidUtil.buildClientEventId(
            ky: kDate.kYear,
            km: kDate.kMonth,
            kd: kDate.kDay,
            title: title,
            startHour: startHour,
            startMinute: startMinute,
            allDay: allDay,
            flowId: flowId,
          );

          final startsAt = DateTime(
            date.year,
            date.month,
            date.day,
            startHour,
            startMinute,
          );

          DateTime? endsAt;
          if (!allDay) {
            if (endHour != null && endMinute != null) {
              endsAt = DateTime(
                date.year,
                date.month,
                date.day,
                endHour,
                endMinute,
              );
            } else {
              endsAt = startsAt.add(const Duration(hours: 1));
            }
          }

          await repo.upsertByClientId(
            clientEventId: cid,
            title: title, // ✅ exactly sender title
            startsAtUtc: startsAt.toUtc(),
            detail: detail, // ✅ exactly sender detail
            location: location, // ✅ exactly sender location
            allDay: allDay,
            endsAtUtc: endsAt?.toUtc(),
            flowLocalId: flowId,
            caller: 'inbox_import_snapshot',
          );

          count++;
        }

        _log(
          '[InboxRepo] ✓ Scheduled $count events from snapshot for flow $flowId',
        );
        return; // ✅ Don't fall back to rules - we have the real data
      }

      // 2. Fallback for old shares with no events[]: use rules-based logic
      _log(
        '[InboxRepo] No events[] in payload, falling back to rules-based scheduling for flowId=$flowId',
      );
      await _scheduleImportedFlowFromRules(flowId, item, startDate: start);
    } catch (e, stack) {
      _log('[InboxRepo] ✗ Failed to schedule imported flow $flowId: $e');
      _log('$stack');
      // Don't rethrow - scheduling failure shouldn't fail the import
    }
  }

  /// Fallback: Schedule events from rules (loses individual note data)
  /// Only used for old shares that don't have events[] in payloadJson
  Future<void> _scheduleImportedFlowFromRules(
    int flowId,
    InboxShareItem item, {
    DateTime? startDate,
  }) async {
    try {
      final payloadJson = item.payloadJson;
      if (payloadJson == null) return;

      final rulesData = payloadJson['rules'] as List?;
      if (rulesData == null || rulesData.isEmpty) return;

      final rules = rulesData
          .map((r) => CalendarPage.ruleFromJson(r as Map<String, dynamic>))
          .toList();

      final repo = UserEventsRepo(_client);
      final start = startDate ?? DateTime.now();
      final end = start.add(const Duration(days: 90));

      int scheduledCount = 0;

      for (
        var date = start;
        date.isBefore(end);
        date = date.add(const Duration(days: 1))
      ) {
        final kDate = KemeticMath.fromGregorian(date);

        for (final rule in rules) {
          if (rule.matches(
            ky: kDate.kYear,
            km: kDate.kMonth,
            kd: kDate.kDay,
            g: date,
          )) {
            final noteTitle = payloadJson['name'] as String? ?? item.title;
            final startHour = rule.allDay ? 9 : (rule.start?.hour ?? 9);
            final startMinute = rule.allDay ? 0 : (rule.start?.minute ?? 0);

            final cid = EventCidUtil.buildClientEventId(
              ky: kDate.kYear,
              km: kDate.kMonth,
              kd: kDate.kDay,
              title: noteTitle,
              startHour: startHour,
              startMinute: startMinute,
              allDay: rule.allDay,
              flowId: flowId,
            );

            final startsAt = DateTime(
              date.year,
              date.month,
              date.day,
              startHour,
              startMinute,
            );
            DateTime? endsAt;
            if (!rule.allDay && rule.end != null) {
              endsAt = DateTime(
                date.year,
                date.month,
                date.day,
                rule.end!.hour,
                rule.end!.minute,
              );
            }

            await repo.upsertByClientId(
              clientEventId: cid,
              title: noteTitle,
              startsAtUtc: startsAt.toUtc(),
              detail: '',
              allDay: rule.allDay,
              endsAtUtc: endsAt?.toUtc(),
              flowLocalId: flowId,
              caller: 'inbox_import_rules',
            );

            scheduledCount++;
            break; // Only one event per day
          }
        }
      }

      _log(
        '[InboxRepo] ✓ Scheduled $scheduledCount notes from rules for flow $flowId',
      );
    } catch (e) {
      _log('[InboxRepo] ✗ Failed to schedule from rules: $e');
    }
  }

  bool _isMissingTable(Object error, String table) {
    if (error is! PostgrestException) return false;
    final message = _postgrestText(error);
    return message.contains(table.toLowerCase()) &&
        (error.code == 'PGRST205' ||
            error.code == '42P01' ||
            message.contains('table') ||
            message.contains('relation') ||
            message.contains('schema cache'));
  }

  String _postgrestText(PostgrestException error) {
    return '${error.code} ${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
        .toLowerCase();
  }
}

class InboxMessageLikesUnavailable implements Exception {
  final String table;
  const InboxMessageLikesUnavailable(this.table);

  @override
  String toString() => 'Inbox message likes table missing: $table';
}
