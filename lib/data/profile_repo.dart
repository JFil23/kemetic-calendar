// lib/data/profile_repo.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'profile_model.dart';
import 'share_models.dart';
import 'flow_post_model.dart';
import 'flows_repo.dart';
import 'user_events_repo.dart';

class ProfileRepo {
  final SupabaseClient _client;

  ProfileRepo(this._client);

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
      print('[ProfileRepo] Error fetching profile: $e');
      return null;
    }
  }

  /// Compute accurate flow and flow-event counts for a user using live tables.
  Future<(int activeFlows, int flowEvents)> computeFlowCountsForUser(String userId) async {
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
      print('[ProfileRepo] Error computing counts: $e');
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
      print('[ProfileRepo] Error checking follow status: $e');
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
      print('[ProfileRepo] Error following user: $e');
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
      print('[ProfileRepo] Error unfollowing user: $e');
      return false;
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
      print('[ProfileRepo] Error fetching profile by handle: $e');
      return null;
    }
  }

  /// Update current user's profile
  Future<bool> updateMyProfile({
    String? handle,
    String? displayName,
    String? avatarUrl,
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
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (bio != null) updates['bio'] = bio;
      if (location != null) updates['location'] = location;
      if (isDiscoverable != null) updates['is_discoverable'] = isDiscoverable;
      if (allowIncomingShares != null) updates['allow_incoming_shares'] = allowIncomingShares;
      updates['updated_at'] = DateTime.now().toUtc().toIso8601String();

      await _client
          .from('profiles')
          .update(updates)
          .eq('id', userId);

      return true;
    } catch (e) {
      print('[ProfileRepo] Error updating profile: $e');
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
      print('[ProfileRepo] Error checking handle: $e');
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

      print('[ProfileRepo] Searching for users matching: $clean');

      // 1️⃣ Search by handle prefix
      final handleResponse = await _client
          .from('profiles')
          .select('id, handle, display_name, avatar_url, email')
          .ilike('handle', '$clean%')
          .eq('allow_incoming_shares', true)
          .limit(10);

      final handleRows = (handleResponse as List?) ?? const [];

      // 2️⃣ Search by display_name substring
      final nameResponse = await _client
          .from('profiles')
          .select('id, handle, display_name, avatar_url, email')
          .ilike('display_name', '%$clean%')
          .eq('allow_incoming_shares', true)
          .limit(10);

      final nameRows = (nameResponse as List?) ?? const [];

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

      print('[ProfileRepo] Search returned ${combined.length} unique results');

      return combined.values.map((json) {
        return UserSearchResult(
          userId: json['id'] as String,
          handle: json['handle'] as String?,
          displayName: json['display_name'] as String?,
          avatarUrl: json['avatar_url'] as String?,
          email: json['email'] as String?,
        );
      }).toList();
    } catch (e) {
      print('[ProfileRepo] Error searching users: $e');
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
      print('[ProfileRepo] Error checking profile completion: $e');
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
      print('[ProfileRepo] Error fetching flow posts: $e');
      return [];
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
      Map<String, dynamic> _eventToPayload(e) {
        int offset = 0;
        if (startDate != null) {
          offset = DateUtils.dateOnly(e.startsAtUtc.toLocal())
              .difference(DateUtils.dateOnly(startDate))
              .inDays;
        }

        String _fmtTime(DateTime dt) {
          final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
          final m = dt.minute.toString().padLeft(2, '0');
          final mer = dt.hour >= 12 ? 'PM' : 'AM';
          return '$h:$m $mer';
        }

        final startLocal = e.startsAtUtc.toLocal();
        final endLocal = e.endsAtUtc?.toLocal();

        return {
          'offset_days': offset,
          'title': e.title,
          'detail': e.detail,
          'location': e.location,
          'all_day': e.allDay,
          'start_time': e.allDay ? null : _fmtTime(startLocal),
          'end_time': e.allDay || endLocal == null ? null : _fmtTime(endLocal),
        };
      }

       final payload = {
         'name': flow.name,
         'color': flow.color,
         'notes': flow.notes,
         'rules': flow.rules,
         'events': events.map(_eventToPayload).toList(),
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

      return FlowPost.fromJson(inserted as Map<String, dynamic>);
    } catch (e) {
      print('[ProfileRepo] Error creating flow post: $e');
      return null;
    }
  }

  Future<bool> deleteFlowPost(String postId) async {
    try {
      await _client.from('flow_posts').delete().eq('id', postId);
      return true;
    } catch (e) {
      print('[ProfileRepo] Error deleting flow post: $e');
      return false;
    }
  }

  /// Save someone else's flow post into my saved flows.
  Future<int?> saveFlowPostToMyFlows(FlowPost post) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final flowsRepo = FlowsRepo(_client);
      final newId = await flowsRepo.insert(
        name: post.name,
        color: post.color,
        active: true,
        isSaved: true,
        isHidden: false,
        startDate: post.startDate,
        endDate: post.endDate,
        notes: post.notes,
        rulesJson: post.rules,
      );

      return newId;
    } catch (e) {
      print('[ProfileRepo] Error saving flow post: $e');
      return null;
    }
  }
}

/// User search result for user search
class UserSearchResult {
  final String userId;
  final String? handle;  // ✅ Made nullable
  final String? displayName;
  final String? avatarUrl;
  final String? email;

  UserSearchResult({
    required this.userId,
    this.handle,  // ✅ Not required
    this.displayName,
    this.avatarUrl,
    this.email,
  });

  String get name => displayName ?? (handle != null ? '@$handle' : 'User');

  /// Convert to ShareRecipient
  ShareRecipient toRecipient() {
    return ShareRecipient(
      type: ShareRecipientType.user,
      value: userId,
    );
  }
}
