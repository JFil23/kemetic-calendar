// lib/data/profile_repo.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:mobile/utils/detail_sanitizer.dart';
import 'package:mobile/utils/event_cid_util.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart' show KemeticMath;
import 'profile_avatar_glyphs.dart';
import 'profile_model.dart';
import 'share_models.dart';
import 'flow_post_model.dart';
import 'flows_repo.dart';
import 'user_events_repo.dart';
import 'flow_post_comment_model.dart';

class ProfileAvatarGlyphsUnavailable implements Exception {
  const ProfileAvatarGlyphsUnavailable();

  @override
  String toString() {
    return 'Glyph avatars are not available on this backend yet. '
        'Apply the avatar glyph migration and refresh the PostgREST schema cache.';
  }
}

class ProfileRepo {
  final SupabaseClient _client;

  ProfileRepo(this._client);

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  String _profilesSelect({bool includeAvatarGlyphs = true}) {
    final avatarGlyphs = includeAvatarGlyphs ? ', avatar_glyphs' : '';
    return 'id, handle, display_name, avatar_url$avatarGlyphs, email';
  }

  String _profileRelationSelect({bool includeAvatarGlyphs = true}) {
    final avatarGlyphs = includeAvatarGlyphs ? ', avatar_glyphs' : '';
    return 'profiles(display_name, handle, avatar_url$avatarGlyphs)';
  }

  String _flowPostCommentSelect({
    required bool includeParentCommentId,
    required bool includeAvatarGlyphs,
  }) {
    final parentCommentId = includeParentCommentId ? 'parent_comment_id, ' : '';
    return 'id, flow_post_id, user_id, ${parentCommentId}body, created_at, '
        '${_profileRelationSelect(includeAvatarGlyphs: includeAvatarGlyphs)}';
  }

  Future<List<dynamic>> _runProfilesQuery(
    Future<dynamic> Function(String selectClause) run,
  ) async {
    try {
      final response = await run(_profilesSelect());
      return (response as List<dynamic>?) ?? const [];
    } catch (e) {
      if (!_isMissingColumn(e, 'avatar_glyphs')) rethrow;
      _log(
        '[ProfileRepo] avatar_glyphs missing from profiles; retrying query without glyphs.',
      );
      final response = await run(_profilesSelect(includeAvatarGlyphs: false));
      return (response as List<dynamic>?) ?? const [];
    }
  }

  Future<Map<String, dynamic>> _insertFlowPostCommentRow(
    Map<String, dynamic> payload, {
    required bool includeParentCommentId,
  }) async {
    var includeParent = includeParentCommentId;
    var includeAvatarGlyphs = true;

    while (true) {
      try {
        final inserted = await _client
            .from('flow_post_comments')
            .insert(payload)
            .select(
              _flowPostCommentSelect(
                includeParentCommentId: includeParent,
                includeAvatarGlyphs: includeAvatarGlyphs,
              ),
            )
            .single();
        return Map<String, dynamic>.from(inserted as Map);
      } catch (e) {
        if (includeParent && _isMissingColumn(e, 'parent_comment_id')) {
          includeParent = false;
          continue;
        }
        if (includeAvatarGlyphs && _isMissingColumn(e, 'avatar_glyphs')) {
          includeAvatarGlyphs = false;
          continue;
        }
        rethrow;
      }
    }
  }

  Future<List<dynamic>> _selectFlowPostCommentsRowsWithFallback(
    String postId,
  ) async {
    var includeParent = true;
    var includeAvatarGlyphs = true;

    while (true) {
      try {
        final rows = await _client
            .from('flow_post_comments')
            .select(
              _flowPostCommentSelect(
                includeParentCommentId: includeParent,
                includeAvatarGlyphs: includeAvatarGlyphs,
              ),
            )
            .eq('flow_post_id', postId)
            .order('created_at', ascending: true);
        return (rows as List<dynamic>?) ?? const [];
      } catch (e) {
        if (includeParent && _isMissingColumn(e, 'parent_comment_id')) {
          includeParent = false;
          continue;
        }
        if (includeAvatarGlyphs && _isMissingColumn(e, 'avatar_glyphs')) {
          includeAvatarGlyphs = false;
          continue;
        }
        rethrow;
      }
    }
  }

  /// Fetch profile by user ID
  Future<UserProfile?> getProfile(String userId) async {
    try {
      final response = await _client
          .from('profile_stats')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (e) {
      _log('[ProfileRepo] Error fetching profile: $e');
      return null;
    }
  }

  /// Compute accurate flow and flow-event counts for a user using live tables.
  Future<(int activeFlows, int flowEvents)> computeFlowCountsForUser(
    String userId,
  ) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();

      final flowsResp = await _client
          .from('flows')
          .select('id')
          .eq('user_id', userId)
          .eq('active', true)
          .or('end_date.is.null,end_date.gte.$nowIso')
          .or('is_hidden.is.null,is_hidden.eq.false');

      final flowsList = (flowsResp as List?) ?? const [];
      final flowIds = flowsList
          .map((row) => (row['id'] as num?)?.toInt())
          .whereType<int>()
          .toList();

      final activeFlows = flowIds.length;
      if (flowIds.isEmpty) return (0, 0);

      final eventsResp = await _client
          .from('user_events')
          .select('id')
          .eq('user_id', userId)
          .inFilter('flow_local_id', flowIds);

      final flowEvents = (eventsResp as List?)?.length ?? 0;
      return (activeFlows, flowEvents);
    } catch (e) {
      _log('[ProfileRepo] Error computing counts: $e');
      return (0, 0);
    }
  }

  /// Check if the current user follows another user
  Future<bool> isFollowing(String targetUserId) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) return false;
      if (currentUserId == targetUserId) return false;

      final response = await _client
          .from('follows')
          .select('follower_id')
          .eq('follower_id', currentUserId)
          .eq('followee_id', targetUserId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      _log('[ProfileRepo] Error checking follow status: $e');
      return false;
    }
  }

  /// Follow another user
  Future<bool> followUser(String targetUserId) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) return false;
      if (currentUserId == targetUserId) return false;

      await _client.from('follows').upsert({
        'follower_id': currentUserId,
        'followee_id': targetUserId,
      });
      return true;
    } catch (e) {
      _log('[ProfileRepo] Error following user: $e');
      return false;
    }
  }

  /// Unfollow another user
  Future<bool> unfollowUser(String targetUserId) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) return false;
      if (currentUserId == targetUserId) return false;

      await _client
          .from('follows')
          .delete()
          .eq('follower_id', currentUserId)
          .eq('followee_id', targetUserId);
      return true;
    } catch (e) {
      _log('[ProfileRepo] Error unfollowing user: $e');
      return false;
    }
  }

  /// List the followers for a given user.
  Future<List<UserSearchResult>> listFollowers(String userId) async {
    try {
      final rows = await _client
          .from('follows')
          .select('follower_id, created_at')
          .eq('followee_id', userId)
          .order('created_at', ascending: false);

      final followerIds = ((rows as List<dynamic>?) ?? const [])
          .map((r) => r['follower_id'] as String?)
          .whereType<String>()
          .toList();
      if (followerIds.isEmpty) return const [];

      final profilesResp = await _runProfilesQuery(
        (selectClause) => _client
            .from('profiles')
            .select(selectClause)
            .inFilter('id', followerIds),
      );

      final profileMap = <String, Map<String, dynamic>>{};
      for (final row in profilesResp) {
        final id = row['id'] as String?;
        if (id != null) {
          profileMap[id] = row as Map<String, dynamic>;
        }
      }

      final results = <UserSearchResult>[];
      for (final id in followerIds) {
        final p = profileMap[id];
        if (p == null) continue;
        results.add(
          UserSearchResult(
            userId: id,
            handle: p['handle'] as String?,
            displayName: p['display_name'] as String?,
            avatarUrl: p['avatar_url'] as String?,
            avatarGlyphIds: parseProfileAvatarGlyphIds(p['avatar_glyphs']),
            email: p['email'] as String?,
          ),
        );
      }
      return results;
    } catch (e) {
      _log('[ProfileRepo] Error listing followers: $e');
      return const [];
    }
  }

  /// List the accounts a user is following.
  Future<List<UserSearchResult>> listFollowing(String userId) async {
    try {
      final rows = await _client
          .from('follows')
          .select('followee_id, created_at')
          .eq('follower_id', userId)
          .order('created_at', ascending: false);

      final followeeIds = ((rows as List<dynamic>?) ?? const [])
          .map((r) => r['followee_id'] as String?)
          .whereType<String>()
          .toList();
      if (followeeIds.isEmpty) return const [];

      final profilesResp = await _runProfilesQuery(
        (selectClause) => _client
            .from('profiles')
            .select(selectClause)
            .inFilter('id', followeeIds),
      );

      final profileMap = <String, Map<String, dynamic>>{};
      for (final row in profilesResp) {
        final id = row['id'] as String?;
        if (id != null) {
          profileMap[id] = row as Map<String, dynamic>;
        }
      }

      final results = <UserSearchResult>[];
      for (final id in followeeIds) {
        final p = profileMap[id];
        if (p == null) continue;
        results.add(
          UserSearchResult(
            userId: id,
            handle: p['handle'] as String?,
            displayName: p['display_name'] as String?,
            avatarUrl: p['avatar_url'] as String?,
            avatarGlyphIds: parseProfileAvatarGlyphIds(p['avatar_glyphs']),
            email: p['email'] as String?,
          ),
        );
      }
      return results;
    } catch (e) {
      _log('[ProfileRepo] Error listing following: $e');
      return const [];
    }
  }

  /// Fetch profile by handle
  Future<UserProfile?> getProfileByHandle(String handle) async {
    try {
      final response = await _client
          .from('profile_stats')
          .select()
          .eq('handle', handle)
          .maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (e) {
      _log('[ProfileRepo] Error fetching profile by handle: $e');
      return null;
    }
  }

  /// Update current user's profile
  Future<bool> updateMyProfile({
    String? handle,
    String? displayName,
    String? avatarUrl,
    bool clearAvatarUrl = false,
    List<String>? avatarGlyphIds,
    String? bio,
    String? location,
    bool? isDiscoverable,
    bool? allowIncomingShares,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      final updates = <String, dynamic>{};
      if (handle != null) updates['handle'] = handle;
      if (displayName != null) updates['display_name'] = displayName;
      if (clearAvatarUrl) {
        updates['avatar_url'] = null;
      }
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (avatarGlyphIds != null) {
        updates['avatar_glyphs'] = normalizeProfileAvatarGlyphIds(
          avatarGlyphIds,
        );
      }
      if (bio != null) updates['bio'] = bio;
      if (location != null) updates['location'] = location;
      if (isDiscoverable != null) updates['is_discoverable'] = isDiscoverable;
      if (allowIncomingShares != null) {
        updates['allow_incoming_shares'] = allowIncomingShares;
      }
      updates['updated_at'] = DateTime.now().toUtc().toIso8601String();

      await _client.from('profiles').update(updates).eq('id', userId);

      return true;
    } catch (e) {
      if (avatarGlyphIds != null && _isMissingColumn(e, 'avatar_glyphs')) {
        throw const ProfileAvatarGlyphsUnavailable();
      }
      _log('[ProfileRepo] Error updating profile: $e');
      return false;
    }
  }

  /// Get current user's profile
  Future<UserProfile?> getMyProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    return getProfile(userId);
  }

  /// Check if handle is available
  Future<bool> isHandleAvailable(String handle) async {
    try {
      final response = await _client
          .from('profiles')
          .select('id')
          .eq('handle', handle)
          .maybeSingle();

      return response == null;
    } catch (e) {
      _log('[ProfileRepo] Error checking handle: $e');
      return false;
    }
  }

  /// Search for users by handle (for @handle search in ShareFlowSheet)
  /// @deprecated Use searchUsers instead
  Future<List<UserSearchResult>> searchUsersByHandle(String query) async {
    return searchUsers(query);
  }

  /// Search for users by handle OR display_name
  /// Supports typing "Jordan", "jordanphillips", or "@jordan" - all work
  Future<List<UserSearchResult>> searchUsers(String rawQuery) async {
    try {
      final query = rawQuery.trim();
      if (query.length < 2) return [];

      final clean = query.startsWith('@') ? query.substring(1) : query;
      if (clean.isEmpty) return [];

      _log('[ProfileRepo] Searching for users matching: $clean');

      // 1️⃣ Search by handle prefix
      final handleRows = await _runProfilesQuery(
        (selectClause) => _client
            .from('profiles')
            .select(selectClause)
            .ilike('handle', '$clean%')
            .eq('allow_incoming_shares', true)
            .limit(10),
      );

      // 2️⃣ Search by display_name substring
      final nameRows = await _runProfilesQuery(
        (selectClause) => _client
            .from('profiles')
            .select(selectClause)
            .ilike('display_name', '%$clean%')
            .eq('allow_incoming_shares', true)
            .limit(10),
      );

      // 3️⃣ Combine + dedupe by id
      final Map<String, Map<String, dynamic>> combined = {};

      for (final row in handleRows) {
        final id = row['id'] as String;
        combined[id] = row as Map<String, dynamic>;
      }
      for (final row in nameRows) {
        final id = row['id'] as String;
        combined[id] = row as Map<String, dynamic>;
      }

      _log('[ProfileRepo] Search returned ${combined.length} unique results');

      return combined.values.map((json) {
        return UserSearchResult(
          userId: json['id'] as String,
          handle: json['handle'] as String?,
          displayName: json['display_name'] as String?,
          avatarUrl: json['avatar_url'] as String?,
          avatarGlyphIds: parseProfileAvatarGlyphIds(json['avatar_glyphs']),
          email: json['email'] as String?,
        );
      }).toList();
    } catch (e) {
      _log('[ProfileRepo] Error searching users: $e');
      return [];
    }
  }

  /// Check if current user has completed their profile
  Future<bool> hasCompletedProfile() async {
    try {
      final profile = await getMyProfile();
      return profile != null &&
          profile.handle != null &&
          profile.handle!.isNotEmpty &&
          profile.displayName != null &&
          profile.displayName!.isNotEmpty;
    } catch (e) {
      _log('[ProfileRepo] Error checking profile completion: $e');
      return false;
    }
  }

  /// List flow posts for a given user (newest first)
  Future<List<FlowPost>> getFlowPosts(String userId) async {
    try {
      final rows = await _client
          .from('flow_posts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(FlowPost.fromJson)
          .toList();
    } catch (e) {
      _log('[ProfileRepo] Error fetching flow posts: $e');
      return [];
    }
  }

  /// Fetch a ranked community feed of posted flows.
  Future<List<FlowPost>> getFlowFeed({int limit = 24, int offset = 0}) async {
    try {
      final response = await _client.rpc(
        'get_flow_post_feed',
        params: {'p_limit': limit, 'p_offset': offset},
      );
      final rows = (response as List<dynamic>?) ?? const [];
      return rows
          .whereType<Map>()
          .map((row) => FlowPost.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      _log('[ProfileRepo] Error fetching flow feed: $e');
      return _getFlowFeedFallback(limit: limit, offset: offset);
    }
  }

  /// Fetch a single flow post by id.
  Future<FlowPost?> getFlowPostById(String postId) async {
    try {
      final row = await _client
          .from('flow_posts')
          .select()
          .eq('id', postId)
          .maybeSingle();

      if (row == null) return null;
      return FlowPost.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ProfileRepo] Error fetching flow post by id: $e');
      }
      return null;
    }
  }

  /// Create a flow post for the current user from an existing flow.
  Future<FlowPost?> postFlow(int flowId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final flow = await FlowsRepo(_client).getFlowById(flowId);
      if (flow == null || flow.userId != userId) return null;

      final events = await UserEventsRepo(_client).getEventsForFlow(flow.id);
      final startDate = flow.startDate;
      Map<String, dynamic> eventToPayload(e) {
        int offset = 0;
        if (startDate != null) {
          offset = DateUtils.dateOnly(
            e.startsAtUtc.toLocal(),
          ).difference(DateUtils.dateOnly(startDate)).inDays;
        }

        String formatTime(DateTime dt) {
          final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
          final m = dt.minute.toString().padLeft(2, '0');
          final mer = dt.hour >= 12 ? 'PM' : 'AM';
          return '$h:$m $mer';
        }

        final startLocal = e.startsAtUtc.toLocal();
        final endLocal = e.endsAtUtc?.toLocal();

        final detail = cleanFlowDetail(e.detail);
        final location = e.location?.trim();

        return {
          'offset_days': offset,
          'title': e.title,
          'detail': detail,
          'location': location == null || location.isEmpty ? null : location,
          'all_day': e.allDay,
          'start_time': e.allDay ? null : formatTime(startLocal),
          'end_time': e.allDay || endLocal == null
              ? null
              : formatTime(endLocal),
        };
      }

      final payload = {
        'name': flow.name,
        'color': flow.color,
        'notes': flow.notes,
        'rules': flow.rules,
        'events': events.map(eventToPayload).toList(),
        'start_date': startDate?.toIso8601String(),
        'end_date': flow.endDate?.toIso8601String(),
      };

      final inserted = await _client
          .from('flow_posts')
          .insert({
            'user_id': userId,
            'flow_id': flow.id,
            'name': flow.name,
            'color': flow.color,
            'notes': flow.notes,
            'rules': flow.rules,
            'start_date': flow.startDate?.toIso8601String(),
            'end_date': flow.endDate?.toIso8601String(),
            'is_hidden': flow.isHidden,
            'ai_metadata': {
              'payload': payload,
              if (flow.aiMetadata != null) 'source_ai': flow.aiMetadata,
            },
          })
          .select()
          .single();

      return FlowPost.fromJson(inserted);
    } catch (e) {
      _log('[ProfileRepo] Error creating flow post: $e');
      return null;
    }
  }

  Future<bool> deleteFlowPost(String postId) async {
    try {
      await _client.from('flow_posts').delete().eq('id', postId);
      return true;
    } catch (e) {
      _log('[ProfileRepo] Error deleting flow post: $e');
      return false;
    }
  }

  /// Save someone else's flow post into my saved flows.
  Future<int?> saveFlowPostToMyFlows(
    FlowPost post, {
    DateTime? startDateOverride,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      DateTime? parseDate(String? raw) {
        if (raw == null) return null;
        try {
          return DateTime.tryParse(raw);
        } catch (_) {
          return null;
        }
      }

      DateTime dateOnly(DateTime dateTime) => DateUtils.dateOnly(dateTime);
      final today = dateOnly(DateTime.now());
      final payloadStart = parseDate(
        post.payloadJson?['start_date'] as String?,
      );
      final rawStart = startDateOverride ?? post.startDate ?? payloadStart;
      final normalizedStart = rawStart == null ? null : dateOnly(rawStart);
      final effectiveStart = (normalizedStart == null)
          ? today
          : (startDateOverride == null && normalizedStart.isBefore(today))
          ? today
          : normalizedStart;

      DateTime? effectiveEnd;
      if (post.endDate != null) {
        final originalStart = post.startDate ?? payloadStart;
        final endOnly = dateOnly(post.endDate!);
        if (originalStart != null) {
          final startOnly = dateOnly(originalStart);
          final span = endOnly.difference(startOnly);
          effectiveEnd = dateOnly(effectiveStart.add(span));
        } else {
          effectiveEnd = endOnly.isBefore(effectiveStart)
              ? effectiveStart
              : endOnly;
        }
      }

      final userEventsRepo = UserEventsRepo(_client);
      final rulesString = jsonEncode(post.rules);
      final newId = await userEventsRepo.upsertFlow(
        name: post.name,
        color: post.color,
        active: true,
        isSaved: true,
        isHidden: false,
        startDate: effectiveStart,
        endDate: effectiveEnd,
        notes: post.notes,
        rules: rulesString,
        originType: 'profile_import',
        originFlowId: post.sourceFlowId,
        rootFlowId: post.sourceFlowId,
      );

      try {
        await _client.from('flow_saves').upsert({
          'user_id': userId,
          'flow_id': newId,
          'saved_from': 'profile',
          'metadata': {'flow_post_id': post.id, 'source_user_id': post.userId},
        }, onConflict: 'user_id,flow_id');
      } catch (e) {
        _log('[ProfileRepo] flow_saves upsert failed: $e');
      }

      await _copyFlowPostEvents(
        targetFlowId: newId,
        post: post,
        userEventsRepo: userEventsRepo,
        baseStart: effectiveStart,
      );

      return newId;
    } catch (e) {
      _log('[ProfileRepo] Error saving flow post: $e');
      return null;
    }
  }

  Future<void> _copyFlowPostEvents({
    required int targetFlowId,
    required FlowPost post,
    required UserEventsRepo userEventsRepo,
    required DateTime baseStart,
  }) async {
    final payload = post.payloadJson;
    final events = payload?['events'] as List<dynamic>?;
    if (events == null || events.isEmpty) return;

    (int hour, int minute)? parseTime(String? raw) {
      if (raw == null) return null;
      final match = RegExp(
        r'^\s*(\d{1,2}):(\d{2})\s*(am|pm)?\s*$',
        caseSensitive: false,
      ).firstMatch(raw);
      if (match == null) return null;
      var hour = int.tryParse(match.group(1) ?? '');
      final minute = int.tryParse(match.group(2) ?? '');
      if (hour == null || minute == null) return null;
      final meridian = match.group(3)?.toLowerCase();
      if (meridian == 'pm' && hour < 12) hour += 12;
      if (meridian == 'am' && hour == 12) hour = 0;
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
      return (hour, minute);
    }

    final baseStartLocal = DateUtils.dateOnly(baseStart);

    for (final raw in events) {
      final e = raw as Map<String, dynamic>;

      final offset = (e['offset_days'] as num?)?.toInt() ?? 0;
      final date = baseStartLocal.add(Duration(days: offset));

      final allDay = e['all_day'] as bool? ?? false;
      final rawTitle = (e['title'] as String?) ?? post.name;
      final title = rawTitle.trim().isEmpty ? post.name : rawTitle.trim();

      final detailRaw = e['detail'] as String?;
      final detailClean = cleanFlowDetail(detailRaw);
      final detailForStore = detailClean.isEmpty ? null : detailClean;

      final locationRaw = (e['location'] as String?)?.trim();
      final location = (locationRaw == null || locationRaw.isEmpty)
          ? null
          : locationRaw;

      final parsedStart = parseTime(e['start_time'] as String?);
      final parsedEnd = parseTime(e['end_time'] as String?);

      final startHour = parsedStart?.$1 ?? 9;
      final startMinute = parsedStart?.$2 ?? 0;

      final startDt = DateTime(
        date.year,
        date.month,
        date.day,
        startHour,
        startMinute,
      );

      DateTime? endDt;
      if (!allDay) {
        if (parsedEnd != null) {
          endDt = DateTime(
            date.year,
            date.month,
            date.day,
            parsedEnd.$1,
            parsedEnd.$2,
          );
        } else {
          endDt = startDt.add(const Duration(hours: 1));
        }
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
        flowId: targetFlowId,
      );

      await userEventsRepo.upsertByClientId(
        clientEventId: cid,
        title: title,
        startsAtUtc: startDt.toUtc(),
        detail: detailForStore,
        location: location,
        allDay: allDay,
        endsAtUtc: endDt?.toUtc(),
        flowLocalId: targetFlowId,
        caller: 'profile_import_events',
      );
    }
  }

  /// Fetch like count and whether the current user has liked a flow post.
  Future<(int count, bool likedByMe)> getFlowPostLikeState(
    String postId,
  ) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      final rows = await _client
          .from('flow_post_likes')
          .select('user_id')
          .eq('flow_post_id', postId);

      final list = (rows as List<dynamic>?) ?? const [];
      final count = list.length;
      final liked = currentUserId == null
          ? false
          : list.any((row) => row['user_id'] == currentUserId);

      return (count, liked);
    } catch (e) {
      if (_isMissingTable(e, 'flow_post_likes')) {
        throw const FlowPostEngagementUnavailable('flow_post_likes');
      }
      _log('[ProfileRepo] Error fetching flow post likes: $e');
      return (0, false);
    }
  }

  /// Like or unlike a flow post for the current user.
  Future<bool> setFlowPostLike(String postId, {required bool like}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      if (like) {
        await _client.from('flow_post_likes').upsert({
          'flow_post_id': postId,
          'user_id': userId,
        }, onConflict: 'flow_post_id,user_id');
      } else {
        await _client
            .from('flow_post_likes')
            .delete()
            .eq('flow_post_id', postId)
            .eq('user_id', userId);
      }

      return true;
    } catch (e) {
      if (_isMissingTable(e, 'flow_post_likes')) {
        throw const FlowPostEngagementUnavailable('flow_post_likes');
      }
      _log('[ProfileRepo] Error updating flow post like: $e');
      return false;
    }
  }

  /// List comments for a flow post (oldest first).
  Future<List<FlowPostComment>> getFlowPostComments(String postId) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      final rows = await _selectFlowPostCommentsRows(postId);

      final comments = (rows as List<dynamic>)
          .map((r) => FlowPostComment.fromJson(r as Map<String, dynamic>))
          .toList();

      if (comments.isEmpty) {
        return const [];
      }

      final commentIds = comments.map((comment) => comment.id).toList();
      List<dynamic> likeRows = const [];
      try {
        final fetched = await _client
            .from('flow_post_comment_likes')
            .select('comment_id, user_id')
            .inFilter('comment_id', commentIds);
        likeRows = (fetched as List<dynamic>?) ?? const [];
      } catch (e) {
        if (!_isMissingTable(e, 'flow_post_comment_likes')) {
          _log('[ProfileRepo] Error fetching flow post comment likes: $e');
        }
      }

      final likesCountByComment = <String, int>{};
      final likedByMe = <String>{};
      for (final raw in likeRows) {
        final row = raw as Map<String, dynamic>;
        final commentId = row['comment_id'] as String?;
        if (commentId == null || commentId.isEmpty) continue;
        likesCountByComment.update(
          commentId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        if (currentUserId != null && row['user_id'] == currentUserId) {
          likedByMe.add(commentId);
        }
      }

      return comments
          .map(
            (comment) => comment.copyWith(
              likesCount: likesCountByComment[comment.id] ?? 0,
              likedByMe: likedByMe.contains(comment.id),
            ),
          )
          .toList();
    } catch (e) {
      if (_isMissingTable(e, 'flow_post_comments')) {
        throw const FlowPostEngagementUnavailable('flow_post_comments');
      }
      _log('[ProfileRepo] Error fetching flow post comments: $e');
      return const [];
    }
  }

  /// Add a comment to a flow post (client enforces 150 chars).
  Future<FlowPostComment?> addFlowPostComment(
    String postId,
    String body, {
    String? parentCommentId,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final trimmed = body.trim();
      if (trimmed.isEmpty || trimmed.length > 150) return null;

      final payload = <String, dynamic>{
        'flow_post_id': postId,
        'user_id': userId,
        'body': trimmed,
        if (parentCommentId != null && parentCommentId.isNotEmpty)
          'parent_comment_id': parentCommentId,
      };

      final inserted = await _insertFlowPostCommentRow(
        payload,
        includeParentCommentId: true,
      );

      return FlowPostComment.fromJson(inserted);
    } catch (e) {
      if (_isMissingColumn(e, 'parent_comment_id')) {
        if (parentCommentId != null && parentCommentId.isNotEmpty) {
          throw const FlowPostEngagementUnavailable(
            'flow_post_comment_replies',
          );
        }
        try {
          final inserted = await _insertFlowPostCommentRow({
            'flow_post_id': postId,
            'user_id': _client.auth.currentUser?.id,
            'body': body.trim(),
          }, includeParentCommentId: false);
          return FlowPostComment.fromJson(inserted);
        } catch (fallbackError) {
          if (_isMissingTable(fallbackError, 'flow_post_comments')) {
            throw const FlowPostEngagementUnavailable('flow_post_comments');
          }
          _log(
            '[ProfileRepo] Error adding flow post comment (fallback): $fallbackError',
          );
          return null;
        }
      }
      if (_isMissingTable(e, 'flow_post_comments')) {
        throw const FlowPostEngagementUnavailable('flow_post_comments');
      }
      _log('[ProfileRepo] Error adding flow post comment: $e');
      return null;
    }
  }

  /// Delete one of the current user's flow post comments.
  Future<bool> deleteFlowPostComment(String commentId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      await _client
          .from('flow_post_comments')
          .delete()
          .eq('id', commentId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      if (_isMissingTable(e, 'flow_post_comments')) {
        throw const FlowPostEngagementUnavailable('flow_post_comments');
      }
      _log('[ProfileRepo] Error deleting flow post comment: $e');
      return false;
    }
  }

  /// Like or unlike a specific flow post comment for the current user.
  Future<bool> setFlowPostCommentLike(
    String commentId, {
    required bool like,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      if (like) {
        await _client.from('flow_post_comment_likes').upsert({
          'comment_id': commentId,
          'user_id': userId,
        }, onConflict: 'comment_id,user_id');
      } else {
        await _client
            .from('flow_post_comment_likes')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', userId);
      }

      return true;
    } catch (e) {
      if (_isMissingTable(e, 'flow_post_comment_likes')) {
        throw const FlowPostEngagementUnavailable('flow_post_comment_likes');
      }
      _log('[ProfileRepo] Error updating flow post comment like: $e');
      return false;
    }
  }

  bool _isMissingTable(Object e, String table) {
    if (e is! PostgrestException) return false;
    final message = _postgrestText(e);
    return message.contains(table.toLowerCase()) &&
        (e.code == 'PGRST205' ||
            e.code == '42P01' ||
            message.contains('table') ||
            message.contains('relation') ||
            message.contains('schema cache'));
  }

  bool _isMissingColumn(Object e, String column) {
    if (e is! PostgrestException) return false;
    final message = _postgrestText(e);
    return message.contains(column.toLowerCase()) &&
        (e.code == '42703' ||
            e.code == 'PGRST204' ||
            message.contains('column') ||
            message.contains('schema cache'));
  }

  String _postgrestText(PostgrestException e) {
    return '${e.code} ${e.message} ${e.details ?? ''} ${e.hint ?? ''}'
        .toLowerCase();
  }

  Future<List<FlowPost>> _getFlowFeedFallback({
    required int limit,
    required int offset,
  }) async {
    try {
      final rows = await _client
          .from('flow_posts')
          .select(
            'id, user_id, flow_id, name, color, notes, rules, start_date, end_date, is_hidden, ai_metadata, created_at, profiles(handle, display_name, avatar_url)',
          )
          .eq('is_hidden', false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return ((rows as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map((row) => FlowPost.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      _log('[ProfileRepo] Flow feed fallback failed: $e');
      return const [];
    }
  }

  Future<dynamic> _selectFlowPostCommentsRows(String postId) async {
    try {
      return await _selectFlowPostCommentsRowsWithFallback(postId);
    } catch (e) {
      if (!_isMissingColumn(e, 'parent_comment_id') &&
          !_isMissingColumn(e, 'avatar_glyphs')) {
        rethrow;
      }
      return await _selectFlowPostCommentsRowsWithFallback(postId);
    }
  }

  /// Send a push notification via the edge function `send_push`.
  /// This mirrors the DM notification path: fan-out to push_tokens for userIds.
  Future<void> sendFlowPostPush({
    required String targetUserId,
    required String title,
    String? body,
    Map<String, String>? data,
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return;
    if (currentUserId == targetUserId) return; // Don't notify self

    try {
      await _client.functions.invoke(
        'send_push',
        body: {
          'userIds': [targetUserId],
          'notification': {'title': title, if (body != null) 'body': body},
          if (data != null) 'data': data,
        },
      );
    } catch (e) {
      _log('[ProfileRepo] sendFlowPostPush failed: $e');
    }
  }
}

/// Thrown when engagement tables have not been created on the backend yet.
class FlowPostEngagementUnavailable implements Exception {
  final String table;
  const FlowPostEngagementUnavailable(this.table);

  @override
  String toString() => 'Flow post engagement table missing: $table';
}

/// User search result for user search
class UserSearchResult {
  final String userId;
  final String? handle; // ✅ Made nullable
  final String? displayName;
  final String? avatarUrl;
  final List<String> avatarGlyphIds;
  final String? email;

  UserSearchResult({
    required this.userId,
    this.handle, // ✅ Not required
    this.displayName,
    this.avatarUrl,
    this.avatarGlyphIds = const [],
    this.email,
  });

  String get name => displayName ?? (handle != null ? '@$handle' : 'User');

  /// Convert to ShareRecipient
  ShareRecipient toRecipient() {
    return ShareRecipient(type: ShareRecipientType.user, value: userId);
  }
}
