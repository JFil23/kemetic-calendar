// lib/data/share_repo.dart
// ShareRepo - Repository Layer for Flow Sharing System

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'share_models.dart';

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
    _log(
      '[ShareRepo] shareEvent: eventId=$eventId recipients=${recipients.length}',
    );

    try {
      final response = await _client.functions.invoke(
        'create_event_share',
        body: {
          'event_id': eventId,
          'recipients': recipients.map((r) => r.toJson()).toList(),
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
        results.add(
          ShareResult(
            status: null,
            error: err['error'] as String? ?? 'Unknown error',
            shareId: null,
          ),
        );
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
            recipients: recipients,
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
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return [
        ShareResult(status: null, error: 'Please sign in to send invites'),
      ];
    }

    final rawEvent = await _client
        .from('user_events')
        .select(
          'id, user_id, title, detail, location, starts_at, ends_at, all_day',
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

    final eventPayload = <String, dynamic>{
      'event_id': eventId,
      'title': eventRow['title'],
      'detail': eventRow['detail'],
      'location': eventRow['location'],
      'starts_at': eventRow['starts_at'],
      'ends_at': eventRow['ends_at'],
      'all_day': eventRow['all_day'],
      if (payloadJson != null) ...payloadJson,
    };

    final results = <ShareResult>[];
    for (final recipient in recipients) {
      if (recipient.type != ShareRecipientType.user) {
        results.add(ShareResult(status: null, error: 'IN_APP_USER_REQUIRED'));
        continue;
      }

      final recipientId = await _resolveRecipientUserId(recipient.value);
      if (recipientId == null || recipientId.isEmpty) {
        results.add(ShareResult(status: null, error: 'USER_NOT_FOUND'));
        continue;
      }

      if (recipientId == userId) {
        results.add(ShareResult(status: null, error: 'CANNOT_INVITE_SELF'));
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

      final basePatch = <String, dynamic>{
        'channel': 'in_app',
        'payload_json': eventPayload,
        'status': 'sent',
        'viewed_at': null,
        'imported_at': null,
        'deleted_at': null,
        'response_status': 'no_response',
        'responded_at': null,
      };

      try {
        final row = existingId != null && existingId.isNotEmpty
            ? await _updateEventShareRow(existingId, basePatch)
            : await _insertEventShareRow(
                eventId: eventId,
                senderId: userId,
                recipientId: recipientId,
                values: basePatch,
              );
        results.add(ShareResult.fromJson(row));
      } catch (e) {
        results.add(ShareResult(status: null, error: _inviteErrorMessage(e)));
      }
    }

    return results;
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
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _client
          .from('event_shares')
          .update({
            'response_status': responseStatus.dbValue,
            'responded_at': now,
            'viewed_at': now,
          })
          .eq('id', shareId);
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ShareRepo] Error responding to invite: $e');
        debugPrint('$st');
      }
      return false;
    }
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
      _log('📬 [ShareRepo] Querying inbox_share_items_filtered...');

      final response = await _client
          .from('inbox_share_items_filtered')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      _log('📬 [ShareRepo] Raw response type: ${response.runtimeType}');
      _log('📬 [ShareRepo] Raw response: $response');

      final rows = response.cast<Map<String, dynamic>>();
      _log('📬 [ShareRepo] Response has ${rows.length} items');

      final items = rows.map((item) {
        _log('📬 [ShareRepo] Parsing item: ${item['share_id']}');
        return InboxShareItem.fromJson(item);
      }).toList();

      _log('✅ [ShareRepo] Successfully parsed ${items.length} items');
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
      await _client
          .from(table)
          .update({'viewed_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', shareId);

      return true;
    } catch (e) {
      _log('[ShareRepo] Error marking as viewed: $e');
      return false;
    }
  }

  /// Mark a share as imported
  Future<bool> markImported(String shareId, {required bool isFlow}) async {
    try {
      final table = isFlow ? 'flow_shares' : 'event_shares';
      await _client
          .from(table)
          .update({'imported_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', shareId);

      return true;
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

      await _client
          .from(table)
          .update({'deleted_at': now})
          .eq('id', shareId)
          .eq(roleColumn, userId);

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

          // ✅ Explicit client-side filter: sent OR received (defensive check)
          final filtered = list.cast<Map<String, dynamic>>().where((row) {
            final senderId = row['sender_id'] as String?;
            final recipientId = row['recipient_id'] as String?;
            return senderId == uid || recipientId == uid;
          }).toList();

          if (kDebugMode) {
            debugPrint(
              '[watchInbox] ${list.length} raw items, ${filtered.length} filtered (uid=$uid)',
            );
            // ✅ Add detailed logging for first few rows (raw JSON)
            for (final row in filtered.take(3)) {
              debugPrint(
                '[watchInbox] share_id=${row['share_id']} '
                'sender=${row['sender_id']} recipient=${row['recipient_id']} '
                'title=${row['title']}',
              );
            }
          }

          // Parse to InboxShareItem and log payload info
          final items = filtered
              .map((item) => InboxShareItem.fromJson(item))
              .toList();

          if (kDebugMode) {
            debugPrint('[watchInbox] ${items.length} parsed items');
            for (final item in items.take(3)) {
              final hasPayload =
                  item.payloadJson != null && item.payloadJson!.isNotEmpty;
              debugPrint(
                '[watchInbox] shareId=${item.shareId} kind=${item.kind.asString} '
                'title=${item.title} '
                'hasPayload=$hasPayload '
                'payloadKeys=${item.payloadJson?.keys.toList()}',
              );
            }
          }

          return items;
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

    controller.onCancel = () {
      channel.unsubscribe();
    };

    return controller.stream;
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
