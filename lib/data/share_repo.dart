// lib/data/share_repo.dart
// ShareRepo - Repository Layer for Flow Sharing System

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/kemetic_converter.dart';
import 'share_models.dart';
import 'user_events_repo.dart';
import '../utils/event_cid_util.dart';
import '../utils/flow_visibility.dart';

bool isExternalInboxActivityActor(String? actorId, String currentUserId) {
  if (currentUserId.isEmpty) return false;
  if (actorId == null || actorId.isEmpty) return false;
  return actorId != currentUserId;
}

class ShareRepo {
  static const String _activitySeenPrefKey = 'inbox:activity_seen_at:v1';
  static final StreamController<void> _activitySeenChangedController =
      StreamController<void>.broadcast();
  static final Map<String, _InboxUnreadTracker> _unreadTrackers = {};

  final SupabaseClient _client;

  ShareRepo(this._client);

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  _InboxUnreadTracker? _trackerForCurrentUser() {
    final uid = _client.auth.currentUser?.id;
    final staleTrackerIds = _unreadTrackers.keys
        .where((trackerUid) => trackerUid != uid)
        .toList(growable: false);
    for (final trackerUid in staleTrackerIds) {
      final tracker = _unreadTrackers.remove(trackerUid);
      if (tracker != null) {
        unawaited(tracker.dispose());
      }
    }

    if (uid == null || uid.isEmpty) {
      return null;
    }

    return _unreadTrackers.putIfAbsent(
      uid,
      () => _InboxUnreadTracker(_client, uid),
    );
  }

  InboxUnreadState get currentUnreadState =>
      _trackerForCurrentUser()?.currentState ?? const InboxUnreadState();

  String _activitySeenStorageKey(String uid, InboxActivityBucket bucket) {
    return '$_activitySeenPrefKey:$uid:${bucket.storageKey}';
  }

  // Activity items (likes, comments, follows) for unified inbox feed.
  Future<List<InboxActivityItem>> getRecentActivity({int limit = 50}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];

    try {
      Future<List<Map<String, dynamic>>> loadRows(
        String label,
        Future<dynamic> request,
      ) async {
        try {
          final response = await request;
          return (response as List? ?? const []).cast<Map<String, dynamic>>();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[ShareRepo] getRecentActivity $label error: $e');
          }
          return const [];
        }
      }

      final responses = await Future.wait<List<Map<String, dynamic>>>([
        loadRows(
          'likes',
          _client
              .from('flow_post_likes')
              .select(
                'created_at, user_id, flow_post_id, profiles(display_name, handle, avatar_url), flow_posts!inner(name, user_id)',
              )
              .neq('user_id', uid)
              .eq('flow_posts.user_id', uid)
              .order('created_at', ascending: false)
              .limit(limit),
        ),
        loadRows(
          'comments',
          _client
              .from('flow_post_comments')
              .select(
                'created_at, user_id, body, flow_post_id, profiles(display_name, handle, avatar_url), flow_posts!inner(name, user_id)',
              )
              .neq('user_id', uid)
              .eq('flow_posts.user_id', uid)
              .order('created_at', ascending: false)
              .limit(limit),
        ),
        loadRows(
          'follows',
          _client
              .from('follows')
              .select(
                'created_at, follower_id, profiles!follower_id(display_name, handle, avatar_url)',
              )
              .eq('followee_id', uid)
              .order('created_at', ascending: false)
              .limit(limit),
        ),
      ]);
      final likes = responses[0];
      final comments = responses[1];
      final follows = responses[2];

      final items = <InboxActivityItem>[];

      for (final row in likes) {
        final actorId = row['user_id'] as String?;
        if (!isExternalInboxActivityActor(actorId, uid)) continue;
        final profile = row['profiles'] as Map<String, dynamic>?;
        final createdAt = DateTime.parse(row['created_at'] as String);
        items.add(
          InboxActivityItem(
            type: InboxActivityType.like,
            createdAt: createdAt,
            actorId: actorId,
            actorHandle: profile?['handle'] as String?,
            actorName: profile?['display_name'] as String?,
            actorAvatar: profile?['avatar_url'] as String?,
            flowPostId: row['flow_post_id'] as String?,
            flowName: (row['flow_posts'] as Map?)?['name'] as String?,
          ),
        );
      }

      for (final row in comments) {
        final actorId = row['user_id'] as String?;
        if (!isExternalInboxActivityActor(actorId, uid)) continue;
        final profile = row['profiles'] as Map<String, dynamic>?;
        final createdAt = DateTime.parse(row['created_at'] as String);
        items.add(
          InboxActivityItem(
            type: InboxActivityType.comment,
            createdAt: createdAt,
            actorId: actorId,
            actorHandle: profile?['handle'] as String?,
            actorName: profile?['display_name'] as String?,
            actorAvatar: profile?['avatar_url'] as String?,
            flowPostId: row['flow_post_id'] as String?,
            flowName: (row['flow_posts'] as Map?)?['name'] as String?,
            commentPreview: row['body'] as String?,
          ),
        );
      }

      for (final row in follows) {
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

  Future<DateTime?> getActivitySeenAt(InboxActivityBucket bucket) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_activitySeenStorageKey(uid, bucket));
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw)?.toUtc();
    } catch (e) {
      _log('[ShareRepo] Error loading activity seen timestamp: $e');
      return null;
    }
  }

  Future<void> markActivitySeen(
    InboxActivityBucket bucket, {
    DateTime? seenAt,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final effectiveSeenAt = (seenAt ?? DateTime.now()).toUtc();
      await prefs.setString(
        _activitySeenStorageKey(uid, bucket),
        effectiveSeenAt.toIso8601String(),
      );
      _activitySeenChangedController.add(null);
    } catch (e) {
      _log('[ShareRepo] Error saving activity seen timestamp: $e');
    }
  }

  Future<int> getUnreadActivityCount({
    InboxActivityBucket? bucket,
    int limit = 200,
  }) async {
    final activity = await getRecentActivity(limit: limit);
    if (activity.isEmpty) return 0;

    if (bucket != null) {
      final seenAt = await getActivitySeenAt(bucket);
      final bucketItems = activity.where((item) => item.bucket == bucket);
      if (seenAt == null) return bucketItems.length;
      return bucketItems.where((item) => item.createdAt.isAfter(seenAt)).length;
    }

    final unreadState = await getUnreadActivityState(limit: limit);
    return unreadState.totalUnread;
  }

  Future<InboxActivityUnreadState> getUnreadActivityState({
    int limit = 200,
  }) async {
    final activity = await getRecentActivity(limit: limit);
    if (activity.isEmpty) {
      return const InboxActivityUnreadState();
    }

    final movementSeenAt = await getActivitySeenAt(
      InboxActivityBucket.movement,
    );
    final communitySeenAt = await getActivitySeenAt(
      InboxActivityBucket.community,
    );

    var unreadMovement = 0;
    var unreadCommunity = 0;

    for (final item in activity) {
      switch (item.bucket) {
        case InboxActivityBucket.movement:
          if (movementSeenAt == null ||
              item.createdAt.isAfter(movementSeenAt)) {
            unreadMovement++;
          }
          break;
        case InboxActivityBucket.community:
          if (communitySeenAt == null ||
              item.createdAt.isAfter(communitySeenAt)) {
            unreadCommunity++;
          }
          break;
      }
    }

    return InboxActivityUnreadState(
      unreadMovement: unreadMovement,
      unreadCommunity: unreadCommunity,
    );
  }

  Future<InboxUnreadState> getUnreadState() async {
    final results = await Future.wait<dynamic>([
      getUnreadCount(),
      getUnreadActivityState(),
    ]);
    final unreadMessages = results[0] as int;
    final unreadActivity = results[1] as InboxActivityUnreadState;
    return InboxUnreadState(
      unreadMessages: unreadMessages,
      unreadMovement: unreadActivity.unreadMovement,
      unreadCommunity: unreadActivity.unreadCommunity,
    );
  }

  Stream<int> watchUnreadActivityCount({
    InboxActivityBucket? bucket,
    int limit = 200,
  }) {
    return watchUnreadActivityState(limit: limit).map((state) {
      if (bucket == null) return state.totalUnread;
      switch (bucket) {
        case InboxActivityBucket.movement:
          return state.unreadMovement;
        case InboxActivityBucket.community:
          return state.unreadCommunity;
      }
    }).distinct();
  }

  Stream<InboxActivityUnreadState> watchUnreadActivityState({int limit = 200}) {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      return Stream.value(const InboxActivityUnreadState());
    }

    final controller = StreamController<InboxActivityUnreadState>();

    Future<void> refreshUnreadCount() async {
      final state = await getUnreadActivityState(limit: limit);
      if (!controller.isClosed) controller.add(state);
    }

    final channel = _client.channel('inbox_activity_unread_$uid')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'flow_post_likes',
        callback: (_) => refreshUnreadCount(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'flow_post_comments',
        callback: (_) => refreshUnreadCount(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'follows',
        callback: (_) => refreshUnreadCount(),
      )
      ..subscribe();

    final seenSub = _activitySeenChangedController.stream.listen((_) {
      refreshUnreadCount();
    });

    refreshUnreadCount();

    controller.onCancel = () async {
      await seenSub.cancel();
      await channel.unsubscribe();
      await controller.close();
    };

    return controller.stream.distinct();
  }

  Stream<InboxUnreadState> watchUnreadState() {
    final tracker = _trackerForCurrentUser();
    if (tracker == null) {
      return Stream.value(const InboxUnreadState());
    }
    return tracker.stream;
  }

  /// Share a flow with recipients
  Future<List<ShareResult>> shareFlow({
    required int flowId,
    required List<ShareRecipient> recipients,
    SuggestedSchedule? suggestedSchedule,
  }) async {
    final normalizedRecipients = dedupeShareRecipients(recipients);
    _log('[ShareRepo] Current user: ${_client.auth.currentUser?.id}');
    _log(
      '[ShareRepo] Current session: ${_client.auth.currentSession?.accessToken != null}',
    );

    try {
      final response = await _client.functions.invoke(
        'create_flow_share',
        body: {
          'flow_id': flowId,
          'recipients': normalizedRecipients.map((r) => r.toJson()).toList(),
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
    } on FunctionException catch (e, stackTrace) {
      _log('[ShareRepo] Error sharing flow: $e');
      _log('[ShareRepo] Stack trace: $stackTrace');
      if (e.status == 404) {
        _log(
          '[ShareRepo] create_flow_share missing on backend; falling back to direct flow_shares writes',
        );
        try {
          return await _shareFlowDirect(
            flowId: flowId,
            recipients: normalizedRecipients,
            suggestedSchedule: suggestedSchedule,
          );
        } catch (fallbackError, fallbackStackTrace) {
          _log('[ShareRepo] Direct flow share fallback failed: $fallbackError');
          _log('[ShareRepo] Stack trace: $fallbackStackTrace');
          return [
            ShareResult(
              status: null,
              error: _flowShareErrorMessage(
                fallbackError,
                missingFunction: true,
              ),
            ),
          ];
        }
      }

      return [ShareResult(status: null, error: _flowShareErrorMessage(e))];
    } catch (e, stackTrace) {
      _log('[ShareRepo] Error sharing flow: $e');
      _log('[ShareRepo] Stack trace: $stackTrace');
      return [ShareResult(status: null, error: _flowShareErrorMessage(e))];
    }
  }

  Future<List<ShareResult>> _shareFlowDirect({
    required int flowId,
    required List<ShareRecipient> recipients,
    SuggestedSchedule? suggestedSchedule,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return [
        ShareResult(status: null, error: 'Please sign in to share flows'),
      ];
    }

    final rawFlow = await _client
        .from('flows')
        .select('id, name, color, notes, rules, user_id')
        .eq('id', flowId)
        .maybeSingle();
    final flowRow = rawFlow is Map<String, dynamic> ? rawFlow : null;

    if (flowRow == null) {
      return [ShareResult(status: null, error: 'Flow not found')];
    }

    if ((flowRow['user_id'] as String?) != userId) {
      return [
        ShareResult(status: null, error: 'You can only share your own flows'),
      ];
    }

    final payloadJson = await _buildFlowSharePayload(flowId, flowRow);
    final results = <ShareResult>[];
    final flowName = _cleanNullableString(flowRow['name']) ?? 'Shared Flow';

    for (final recipient in recipients) {
      if (recipient.type == ShareRecipientType.user) {
        final recipientId = await _resolveRecipientUserId(recipient.value);
        if (recipientId == null || recipientId.isEmpty) {
          results.add(
            ShareResult(
              recipient: recipient,
              status: null,
              error: 'User not found',
            ),
          );
          continue;
        }

        if (recipientId == userId) {
          results.add(
            ShareResult(
              recipient: recipient,
              status: null,
              error: 'You cannot share with yourself',
            ),
          );
          continue;
        }

        try {
          final rawRow = await _client
              .from('flow_shares')
              .insert({
                'flow_id': flowId,
                'sender_id': userId,
                'recipient_id': recipientId,
                'channel': 'in_app',
                'suggested_schedule': suggestedSchedule?.toJson(),
                'payload_json': payloadJson,
                'status': 'sent',
              })
              .select('id, status, recipient_id')
              .single();
          final row = (rawRow as Map).cast<String, dynamic>();
          results.add(
            ShareResult.fromJson({
              ...row,
              'recipient': recipient.toJson(),
              'recipient_id': recipientId,
            }),
          );
          await _sendFlowSharePush(
            recipientId: recipientId,
            shareId: row['id'] as String?,
            flowName: flowName,
          );
        } catch (e) {
          results.add(
            ShareResult(
              recipient: recipient,
              status: null,
              error: _flowShareErrorMessage(e),
            ),
          );
        }
        continue;
      }

      if (recipient.type == ShareRecipientType.email) {
        try {
          final rawRow = await _client
              .from('flow_shares')
              .insert({
                'flow_id': flowId,
                'sender_id': userId,
                'recipient_id': null,
                'channel': 'email',
                'suggested_schedule': suggestedSchedule?.toJson(),
                'payload_json': payloadJson,
                'status': 'sent',
              })
              .select('id, status')
              .single();
          final row = (rawRow as Map).cast<String, dynamic>();
          results.add(
            ShareResult.fromJson({...row, 'recipient': recipient.toJson()}),
          );
        } catch (e) {
          results.add(
            ShareResult(
              recipient: recipient,
              status: null,
              error: _flowShareErrorMessage(e),
            ),
          );
        }
        continue;
      }

      results.add(
        ShareResult(
          recipient: recipient,
          status: null,
          error: 'Only in-app users and email recipients are supported',
        ),
      );
    }

    return results;
  }

  Future<void> _sendFlowSharePush({
    required String recipientId,
    required String? shareId,
    required String flowName,
  }) async {
    final senderId = _client.auth.currentUser?.id;
    if (senderId == null ||
        senderId.isEmpty ||
        recipientId.isEmpty ||
        shareId == null ||
        shareId.isEmpty) {
      return;
    }

    String senderLabel = 'Someone';
    try {
      final profile = await _client
          .from('profiles')
          .select('display_name, handle')
          .eq('id', senderId)
          .maybeSingle();
      final displayName = _cleanNullableString(profile?['display_name']);
      final handle = _cleanNullableString(profile?['handle']);
      if (displayName != null && displayName.isNotEmpty) {
        senderLabel = displayName;
      } else if (handle != null && handle.isNotEmpty) {
        senderLabel = '@$handle';
      }
    } catch (e) {
      _log('[ShareRepo] load sender profile for flow share push failed: $e');
    }

    final trimmedName = flowName.trim();
    final body = trimmedName.isEmpty ? 'Tap to open in Inbox' : trimmedName;

    try {
      await _client.functions.invoke(
        'send_push',
        body: {
          'userIds': [recipientId],
          'notification': {
            'title': 'Flow shared by $senderLabel',
            'body': body,
          },
          'data': {
            'type': 'dm',
            'kind': 'dm',
            'sender_id': senderId,
            'share_id': shareId,
            'share_kind': 'flow',
          },
        },
      );
    } catch (e) {
      _log('[ShareRepo] send flow share push failed: $e');
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
          'id, user_id, title, detail, location, starts_at, ends_at, all_day, flow_local_id, category',
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
      'category': eventRow['category'],
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

  Future<Map<String, dynamic>> _buildFlowSharePayload(
    int flowId,
    Map<String, dynamic> flowRow,
  ) async {
    final rawFlowEvents = await _client
        .from('user_events')
        .select('title, detail, location, all_day, starts_at, ends_at')
        .eq('flow_local_id', flowId)
        .order('starts_at', ascending: true)
        .order('created_at', ascending: true);

    final flowEvents = (rawFlowEvents as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((row) => row.cast<String, dynamic>())
        .toList(growable: false);

    DateTime? firstStartsAtUtc;
    for (final row in flowEvents) {
      final startUtc = _parseDateTimeValue(row['starts_at'])?.toUtc();
      if (startUtc == null) continue;
      firstStartsAtUtc = startUtc;
      break;
    }

    final flowName = _cleanNullableString(flowRow['name']) ?? 'Shared Flow';
    final eventSnapshots = flowEvents
        .map((row) {
          final startUtc = _parseDateTimeValue(row['starts_at'])?.toUtc();
          final endUtc = _parseDateTimeValue(row['ends_at'])?.toUtc();
          final allDay = _parseBoolishValue(row['all_day']);
          final offsetDays = firstStartsAtUtc != null && startUtc != null
              ? ((startUtc.millisecondsSinceEpoch -
                            firstStartsAtUtc.millisecondsSinceEpoch) /
                        Duration.millisecondsPerDay)
                    .round()
              : 0;

          return <String, dynamic>{
            'offset_days': offsetDays,
            'title': _cleanNullableString(row['title']) ?? flowName,
            'detail': _cleanNullableString(row['detail']),
            'location': _cleanNullableString(row['location']),
            'all_day': allDay,
            if (!allDay && startUtc != null)
              'start_time': _formatShareTime(startUtc),
            if (!allDay && endUtc != null) 'end_time': _formatShareTime(endUtc),
          };
        })
        .toList(growable: false);

    return {
      'flow_id': flowId,
      'name': flowName,
      'color': _parseIntValue(flowRow['color']) ?? 0x004DD0E1,
      'notes': _cleanNullableString(flowRow['notes']),
      'rules': (flowRow['rules'] as List?) ?? const <dynamic>[],
      'events': eventSnapshots,
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

  String _flowShareErrorMessage(Object error, {bool missingFunction = false}) {
    final message = error.toString();
    final normalized = message.toLowerCase();

    if (missingFunction) {
      return 'Flow sharing backend is not deployed yet.';
    }

    if (error is FunctionException && error.status == 404) {
      return 'Flow sharing backend is not deployed yet.';
    }

    if (normalized.contains('user not found') ||
        message.contains('USER_NOT_FOUND')) {
      return 'User not found';
    }

    if (normalized.contains('share with yourself') ||
        message.contains('CANNOT_INVITE_SELF')) {
      return 'You cannot share with yourself';
    }

    if (normalized.contains('flow not found')) {
      return 'Flow not found';
    }

    return 'Could not share flow';
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

    if (!ok) {
      ok = await _confirmEventInviteResponse(
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

  Future<bool> _confirmEventInviteResponse({
    required String shareId,
    required EventInviteResponseStatus responseStatus,
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      return false;
    }

    try {
      final row = await _client
          .from('event_shares')
          .select('response_status')
          .eq('id', shareId)
          .eq('recipient_id', currentUserId)
          .maybeSingle();
      if (row is! Map<String, dynamic>) {
        return false;
      }
      return EventInviteResponseStatus.fromDbValue(
            row['response_status'] as String?,
          ) ==
          responseStatus;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ShareRepo] Error confirming invite response: $e');
        debugPrint('$st');
      }
      return false;
    }
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
      category: _cleanNullableString(payload?['category']),
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
        )) {
      await repo.deleteByFlowId(existingFlowId);
      return;
    }

    final sourceEvents = _asMapList(sourceFlow['events']);
    final inviteStartsAt = _parseDateTimeValue(payload?['starts_at']);
    final inviteEndsAt = _parseDateTimeValue(payload?['ends_at']);
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
    final flowStartDate =
        _parseDateOnlyValue(sourceFlow['start_date']) ??
        firstEventStart ??
        inviteStartsAt;
    final flowEndDate =
        _parseDateOnlyValue(sourceFlow['end_date']) ??
        lastEventStart ??
        inviteEndsAt ??
        inviteStartsAt;

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
      startDate: flowStartDate,
      endDate: flowEndDate,
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

    var importedEventCount = 0;
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
      importedEventCount++;
    }

    if (importedEventCount == 0 && rulesData.isNotEmpty) {
      await _materializeImportedInviteFlowRules(
        repo: repo,
        flowId: targetFlowId,
        flowName: name,
        rawNotes: importedNotes,
        rulesData: rulesData,
        scheduleStart: flowStartDate,
        scheduleEnd: flowEndDate,
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

  Future<int> _materializeImportedInviteFlowRules({
    required UserEventsRepo repo,
    required int flowId,
    required String flowName,
    required String? rawNotes,
    required List<dynamic> rulesData,
    required DateTime? scheduleStart,
    required DateTime? scheduleEnd,
  }) async {
    if (scheduleStart == null) {
      return 0;
    }

    final start = _dateOnlyLocal(scheduleStart);
    final end = _dateOnlyLocal(
      scheduleEnd ?? start.add(const Duration(days: 90)),
    );
    final noteMeta = _decodeInviteFlowRuleNotes(rawNotes);
    final detailWithMeta = _encodeInviteDetailWithAlert(
      noteMeta.detail,
      alertMinutes: noteMeta.alertMinutes,
    );
    final converter = KemeticConverter();
    final rules = rulesData
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);

    var imported = 0;
    for (
      var date = start;
      !date.isAfter(end);
      date = date.add(const Duration(days: 1))
    ) {
      final kDate = converter.fromGregorian(date);
      final kMonth = kDate.epagomenal ? 13 : kDate.month;

      for (final rule in rules) {
        if (!_inviteRuleMatches(
          rule,
          localDate: date,
          kemeticMonth: kMonth,
          kemeticDay: kDate.day,
        )) {
          continue;
        }

        final allDay = _parseRuleAllDay(rule);
        final startHour = allDay ? 9 : (_parseIntValue(rule['startHour']) ?? 9);
        final startMinute = allDay
            ? 0
            : (_parseIntValue(rule['startMinute']) ?? 0);
        final startsAt = DateTime(
          date.year,
          date.month,
          date.day,
          startHour,
          startMinute,
        );

        DateTime? endsAt;
        if (!allDay) {
          final endHour = _parseIntValue(rule['endHour']);
          final endMinute = _parseIntValue(rule['endMinute']);
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

        final clientEventId = EventCidUtil.buildClientEventId(
          ky: kDate.year,
          km: kMonth,
          kd: kDate.day,
          title: flowName.isEmpty ? 'Flow Event' : flowName,
          startHour: startsAt.hour,
          startMinute: startsAt.minute,
          allDay: allDay,
          flowId: flowId,
        );

        await repo.upsertByClientId(
          clientEventId: clientEventId,
          title: flowName.isEmpty ? 'Flow Event' : flowName,
          startsAtUtc: startsAt.toUtc(),
          detail: detailWithMeta ?? noteMeta.detail,
          location: noteMeta.location,
          allDay: allDay,
          endsAtUtc: endsAt?.toUtc(),
          flowLocalId: flowId,
          category: noteMeta.category,
          caller: 'event_share_flow_import_rules',
        );
        imported++;
      }
    }

    return imported;
  }

  bool _inviteRuleMatches(
    Map<String, dynamic> rule, {
    required DateTime localDate,
    required int kemeticMonth,
    required int kemeticDay,
  }) {
    switch (_cleanNullableString(rule['type'])) {
      case 'week':
        return _parseRuleIntSet(rule['weekdays']).contains(localDate.weekday);
      case 'decan':
        if (kemeticMonth == 13) return false;
        final months = _parseRuleIntSet(rule['months']);
        final decans = _parseRuleIntSet(rule['decans']);
        final daysInDecan = _parseRuleIntSet(rule['daysInDecan']);
        if (!months.contains(kemeticMonth)) return false;
        final decan = ((kemeticDay - 1) ~/ 10) + 1;
        final dayInDecan = ((kemeticDay - 1) % 10) + 1;
        if (!decans.contains(decan)) return false;
        if (daysInDecan.isNotEmpty && !daysInDecan.contains(dayInDecan)) {
          return false;
        }
        return true;
      case 'dates':
        final target = _dateOnlyLocal(localDate);
        return _parseRuleDateSet(
          rule['dates'],
        ).any((candidate) => _sameLocalDay(candidate, target));
      default:
        return false;
    }
  }

  bool _parseRuleAllDay(Map<String, dynamic> rule) {
    final raw = rule['allDay'] ?? rule['all_day'];
    return raw == null ? true : _parseBoolishValue(raw);
  }

  Set<int> _parseRuleIntSet(Object? raw) {
    if (raw is! List) return const <int>{};
    return raw.map(_parseIntValue).whereType<int>().toSet();
  }

  Set<DateTime> _parseRuleDateSet(Object? raw) {
    if (raw is! List) return const <DateTime>{};
    final dates = <DateTime>{};
    for (final item in raw) {
      DateTime? parsed;
      if (item is num) {
        parsed = DateTime.fromMillisecondsSinceEpoch(item.toInt());
      } else if (item is String) {
        final asInt = int.tryParse(item.trim());
        if (asInt != null) {
          parsed = DateTime.fromMillisecondsSinceEpoch(asInt);
        } else {
          parsed = DateTime.tryParse(item.trim());
        }
      } else if (item is DateTime) {
        parsed = item;
      }
      if (parsed == null) continue;
      dates.add(_dateOnlyLocal(parsed));
    }
    return dates;
  }

  ({String? detail, String? location, String? category, int? alertMinutes})
  _decodeInviteFlowRuleNotes(String? rawNotes) {
    final trimmed = rawNotes?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return (detail: null, location: null, category: null, alertMinutes: null);
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic> &&
          decoded['kind'] == 'repeating_note') {
        return (
          detail: _cleanNullableString(decoded['detail']),
          location: _cleanNullableString(decoded['location']),
          category: _cleanNullableString(decoded['category']),
          alertMinutes:
              _parseIntValue(decoded['alertMinutes']) ??
              _parseIntValue(decoded['alert_minutes']),
        );
      }
    } catch (_) {
      // Ignore non-JSON note payloads; fall back to legacy overview parsing.
    }

    return (
      detail: _decodeInviteNotesOverview(trimmed),
      location: null,
      category: null,
      alertMinutes: null,
    );
  }

  String? _decodeInviteNotesOverview(String rawNotes) {
    for (final token in rawNotes.split(';')) {
      final trimmed = token.trim();
      if (!trimmed.startsWith('ov=')) continue;
      return _cleanNullableString(Uri.decodeComponent(trimmed.substring(3)));
    }
    return null;
  }

  String? _encodeInviteDetailWithAlert(String? detail, {int? alertMinutes}) {
    final buffer = StringBuffer();
    if (alertMinutes != null) {
      buffer.write('alert=$alertMinutes;');
    }
    final cleanDetail = _cleanNullableString(detail);
    if (cleanDetail != null) {
      buffer.write(cleanDetail);
    }
    final out = buffer.toString();
    return out.isEmpty ? null : out;
  }

  bool _isLocallyEndedImportedFlow({
    required bool active,
    required bool isHidden,
  }) {
    return !isFlowVisibleInLists(active: active, isHidden: isHidden);
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
    return _dateOnlyLocal(parsed);
  }

  DateTime _dateOnlyLocal(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  bool _sameLocalDay(DateTime a, DateTime b) {
    final left = _dateOnlyLocal(a);
    final right = _dateOnlyLocal(b);
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _formatShareTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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

  Future<bool> markInboxItemViewed(InboxShareItem item) async {
    switch (item.kind) {
      case InboxShareKind.flow:
      case InboxShareKind.message:
        return markViewed(item.shareId, isFlow: true);
      case InboxShareKind.event:
        return markViewed(item.shareId, isFlow: false);
      case InboxShareKind.calendar:
        try {
          return await _updateShareRow(
            table: 'shared_calendar_notifications',
            shareId: item.shareId,
            roleColumn: 'recipient_id',
            values: {'viewed_at': DateTime.now().toUtc().toIso8601String()},
          );
        } catch (e) {
          _log('[ShareRepo] Error marking calendar notification as viewed: $e');
          return false;
        }
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
                final kind = (row['kind'] as String?)?.trim();
                final senderId = row['sender_id'] as String?;
                final recipientId = row['recipient_id'] as String?;
                if (kind == 'calendar') {
                  return recipientId == uid;
                }
                return senderId == uid || recipientId == uid;
              })
              .toList(growable: false);
    if (verbose) {
      _log(
        '📬 [ShareRepo] Response has ${rows.length} rows, ${filtered.length} visible to uid=$uid',
      );
    }

    final items = <InboxShareItem>[];
    for (final item in filtered) {
      if (verbose) {
        _log('📬 [ShareRepo] Parsing item: ${item['share_id']}');
      }
      final parsed = InboxShareItem.tryFromJson(item);
      if (parsed == null) {
        if (verbose) {
          _log(
            '⚠️ [ShareRepo] Skipping malformed inbox row: ${item['share_id']}',
          );
        }
        continue;
      }
      items.add(parsed);
    }

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
    final ok = updated is Map;
    if (ok) {
      _trackerForCurrentUser()?.scheduleRefresh(immediate: true);
    }
    return ok;
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

    final controller = StreamController<List<InboxShareItem>>();
    final channelName =
        'inbox_watch_${uid}_${DateTime.now().microsecondsSinceEpoch}';
    List<InboxShareItem> lastItems = const [];
    Timer? refreshDebounce;
    bool refreshInFlight = false;
    bool refreshQueued = false;

    Future<void> emitLatest() async {
      if (refreshInFlight) {
        refreshQueued = true;
        return;
      }
      refreshInFlight = true;
      try {
        final items = await _fetchInboxItems();
        lastItems = items;
        if (!controller.isClosed) {
          controller.add(items);
        }
      } catch (e, st) {
        _log('[watchInbox] refresh failed: $e');
        if (kDebugMode) {
          debugPrint('$st');
        }
        if (!controller.isClosed) {
          controller.add(lastItems);
        }
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
        table: 'flow_shares',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'sender_id',
          value: uid,
        ),
        callback: (_) => scheduleRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'flow_shares',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'recipient_id',
          value: uid,
        ),
        callback: (_) => scheduleRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'event_shares',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'sender_id',
          value: uid,
        ),
        callback: (_) => scheduleRefresh(),
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
        callback: (_) => scheduleRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'shared_calendar_notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'recipient_id',
          value: uid,
        ),
        callback: (_) => scheduleRefresh(),
      )
      ..subscribe((status, [error]) {
        if (kDebugMode) {
          debugPrint(
            '[watchInbox] channel=$channelName status=$status error=$error',
          );
        }
        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
            scheduleRefresh();
            break;
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
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'shared_calendar_notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'recipient_id',
          value: uid,
        ),
        callback: (_) => refreshUnreadCount(),
      )
      ..subscribe();

    refreshUnreadCount();

    controller.onCancel = () async {
      await channel.unsubscribe();
      await controller.close();
    };

    return controller.stream.distinct();
  }
}

class _InboxUnreadTracker {
  _InboxUnreadTracker(this._client, this._uid) {
    stream = Stream<InboxUnreadState>.multi((controller) {
      controller.add(_state);
      final sub = _changes.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = sub.cancel;
    }, isBroadcast: true);

    _seenSub = ShareRepo._activitySeenChangedController.stream.listen((_) {
      scheduleRefresh(immediate: true);
    });

    _channel = _client.channel('inbox_unread_state_$_uid')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'flow_shares',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'recipient_id',
          value: _uid,
        ),
        callback: (_) => scheduleRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'event_shares',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'recipient_id',
          value: _uid,
        ),
        callback: (_) => scheduleRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'shared_calendar_notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'recipient_id',
          value: _uid,
        ),
        callback: (_) => scheduleRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'flow_post_likes',
        callback: (_) => scheduleRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'flow_post_comments',
        callback: (_) => scheduleRefresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'follows',
        callback: (_) => scheduleRefresh(),
      )
      ..subscribe((status, [error]) {
        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
            scheduleRefresh(immediate: true);
            break;
          case RealtimeSubscribeStatus.channelError:
          case RealtimeSubscribeStatus.timedOut:
            if (kDebugMode) {
              debugPrint(
                '[ShareRepo] inbox unread tracker channel status=$status error=$error',
              );
            }
            scheduleRefresh(immediate: true);
            break;
          case RealtimeSubscribeStatus.closed:
            break;
        }
      });

    scheduleRefresh(immediate: true);
  }

  final SupabaseClient _client;
  final String _uid;
  final StreamController<InboxUnreadState> _changes =
      StreamController<InboxUnreadState>.broadcast();
  late final Stream<InboxUnreadState> stream;

  RealtimeChannel? _channel;
  StreamSubscription<void>? _seenSub;
  Timer? _refreshDebounce;
  bool _refreshInFlight = false;
  bool _refreshQueued = false;
  InboxUnreadState _state = const InboxUnreadState();

  InboxUnreadState get currentState => _state;

  void scheduleRefresh({bool immediate = false}) {
    _refreshDebounce?.cancel();
    if (immediate) {
      unawaited(_refresh());
      return;
    }
    _refreshDebounce = Timer(const Duration(milliseconds: 120), () {
      unawaited(_refresh());
    });
  }

  Future<void> _refresh() async {
    if (_refreshInFlight) {
      _refreshQueued = true;
      return;
    }

    _refreshInFlight = true;
    try {
      final nextState = await ShareRepo(_client).getUnreadState();
      if (nextState != _state) {
        _state = nextState;
        if (!_changes.isClosed) {
          _changes.add(nextState);
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ShareRepo] inbox unread tracker refresh failed: $e');
        debugPrint('$st');
      }
    } finally {
      _refreshInFlight = false;
      if (_refreshQueued) {
        _refreshQueued = false;
        scheduleRefresh(immediate: true);
      }
    }
  }

  Future<void> dispose() async {
    _refreshDebounce?.cancel();
    await _seenSub?.cancel();
    await _channel?.unsubscribe();
    await _changes.close();
  }
}

enum InboxActivityBucket { movement, community }

extension on InboxActivityBucket {
  String get storageKey {
    switch (this) {
      case InboxActivityBucket.movement:
        return 'movement';
      case InboxActivityBucket.community:
        return 'community';
    }
  }
}

class InboxActivityUnreadState {
  const InboxActivityUnreadState({
    this.unreadMovement = 0,
    this.unreadCommunity = 0,
  });

  final int unreadMovement;
  final int unreadCommunity;

  int get totalUnread => unreadMovement + unreadCommunity;
  bool get hasUnreadMovement => unreadMovement > 0;
  bool get hasUnreadCommunity => unreadCommunity > 0;

  @override
  bool operator ==(Object other) {
    return other is InboxActivityUnreadState &&
        other.unreadMovement == unreadMovement &&
        other.unreadCommunity == unreadCommunity;
  }

  @override
  int get hashCode => Object.hash(unreadMovement, unreadCommunity);
}

class InboxUnreadState {
  const InboxUnreadState({
    this.unreadMessages = 0,
    this.unreadMovement = 0,
    this.unreadCommunity = 0,
  });

  final int unreadMessages;
  final int unreadMovement;
  final int unreadCommunity;

  int get unreadActivity => unreadMovement + unreadCommunity;
  int get totalUnread => unreadMessages + unreadActivity;
  bool get hasUnread => totalUnread > 0;
  bool get hasUnreadMovement => unreadMovement > 0;
  bool get hasUnreadCommunity => unreadCommunity > 0;

  @override
  bool operator ==(Object other) {
    return other is InboxUnreadState &&
        other.unreadMessages == unreadMessages &&
        other.unreadMovement == unreadMovement &&
        other.unreadCommunity == unreadCommunity;
  }

  @override
  int get hashCode =>
      Object.hash(unreadMessages, unreadMovement, unreadCommunity);
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

  InboxActivityBucket get bucket {
    switch (type) {
      case InboxActivityType.follow:
        return InboxActivityBucket.community;
      case InboxActivityType.like:
      case InboxActivityType.comment:
        return InboxActivityBucket.movement;
    }
  }
}
