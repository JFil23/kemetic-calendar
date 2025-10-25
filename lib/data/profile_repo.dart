// lib/data/profile_repo.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_model.dart';
import 'share_models.dart';

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
  Future<List<UserSearchResult>> searchUsersByHandle(String query) async {
    try {
      final cleanQuery = query.startsWith('@') ? query.substring(1) : query;
      if (cleanQuery.isEmpty || cleanQuery.length < 2) {
        return [];
      }

      print('[ProfileRepo] Searching for handles matching: $cleanQuery');

      final response = await _client
          .from('profiles')
          .select('id, handle, display_name, avatar_url, email')
          .ilike('handle', '$cleanQuery%')
          .eq('allow_incoming_shares', true)
          .limit(10);

      print('[ProfileRepo] Search returned ${response.length} results');

      return (response as List).map((json) {
        return UserSearchResult(
          userId: json['id'] as String,
          handle: json['handle'] as String,
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
}

/// User search result for @handle search
class UserSearchResult {
  final String userId;
  final String handle;
  final String? displayName;
  final String? avatarUrl;
  final String? email;

  UserSearchResult({
    required this.userId,
    required this.handle,
    this.displayName,
    this.avatarUrl,
    this.email,
  });

  String get name => displayName ?? '@$handle';

  /// Convert to ShareRecipient
  ShareRecipient toRecipient() {
    return ShareRecipient(
      type: ShareRecipientType.user,
      value: userId,
    );
  }
}

