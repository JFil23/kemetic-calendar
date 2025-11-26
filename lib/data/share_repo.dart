// lib/data/share_repo.dart
// ShareRepo - Repository Layer for Flow Sharing System

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart' show PostgrestException;
import 'share_models.dart';

class ShareRepo {
  final SupabaseClient _client;

  ShareRepo(this._client);

  /// Share a flow with recipients
  Future<List<ShareResult>> shareFlow({
    required int flowId,
    required List<ShareRecipient> recipients,
    SuggestedSchedule? suggestedSchedule,
  }) async {
    if (kDebugMode) {
      print('[ShareRepo] Current user: ${_client.auth.currentUser?.id}');
      print('[ShareRepo] Current session: ${_client.auth.currentSession?.accessToken != null}');
    }
    
    try {
      final response = await _client.functions.invoke(
        'create_flow_share',
        body: {
          'flow_id': flowId,
          'recipients': recipients.map((r) => r.toJson()).toList(),
          if (suggestedSchedule != null) 'suggested_schedule': suggestedSchedule.toJson(),
        },
      );

      if (kDebugMode) {
        print('[ShareRepo] create_flow_share status=${response.status}');
        print('[ShareRepo] create_flow_share body=${response.data}');
      }

      // Handle HTTP errors
      if (response.status >= 400) {
        if (kDebugMode) {
          print('[ShareRepo] HTTP error: ${response.status}');
        }
        return [
          ShareResult(
            status: null,
            error: 'HTTP ${response.status}',
          ),
        ];
      }

      // Parse response body
      if (response.data == null) {
        if (kDebugMode) {
          print('[ShareRepo] ERROR: response.data is null');
        }
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

      if (kDebugMode) {
        print('[ShareRepo] Response data keys: ${body.keys}');
      }

      // Extract shares list
      final sharesList = (body['shares'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      if (kDebugMode) {
        print('[ShareRepo] Shares list length: ${sharesList.length}');
      }

      if (sharesList.isEmpty) {
        if (kDebugMode) {
          print('[ShareRepo] WARNING: Empty shares list in response');
        }
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
        if (kDebugMode) {
          print('[ShareRepo] Processing share row: $row');
        }
        results.add(ShareResult.fromJson(row));
      }

      if (kDebugMode) {
        print('[ShareRepo] Parsed ${results.length} share results');
      }

      return results;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('[ShareRepo] Error sharing flow: $e');
        print('[ShareRepo] Stack trace: $stackTrace');
      }
      rethrow;
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
        body: {
          'share_id': shareId,
          if (token != null) 'token': token,
        },
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
    print('📬 [ShareRepo] getInboxItems() called');
    print('📬 [ShareRepo] User ID: ${_client.auth.currentUser?.id}');
    
    try {
      print('📬 [ShareRepo] Querying inbox_share_items_filtered...');
      
      final response = await _client
          .from('inbox_share_items_filtered')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      print('📬 [ShareRepo] Raw response type: ${response.runtimeType}');
      print('📬 [ShareRepo] Raw response: $response');
      
      if (response is! List) {
        print('❌ [ShareRepo] Response is not a List!');
        return [];
      }
      
      print('📬 [ShareRepo] Response has ${(response as List).length} items');
      
      final items = (response as List)
          .map((item) {
            print('📬 [ShareRepo] Parsing item: ${item['share_id']}');
            return InboxShareItem.fromJson(item as Map<String, dynamic>);
          })
          .toList();
      
      print('✅ [ShareRepo] Successfully parsed ${items.length} items');
      return items;
      
    } catch (e, stackTrace) {
      print('❌ [ShareRepo] Error fetching inbox items: $e');
      print('❌ [ShareRepo] Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get unread count for inbox badge
  Future<int> getUnreadCount() async {
    try {
      final response = await _client
          .from('inbox_unread_count_filtered')
          .select('count')
          .maybeSingle();

      return response?['count'] as int? ?? 0;
    } catch (e) {
      print('[ShareRepo] Error fetching unread count: $e');
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
      print('[ShareRepo] Error marking as viewed: $e');
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
      print('[ShareRepo] Error marking as imported: $e');
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
          debugPrint('[ShareRepo] Postgrest error: code=${e.code}, message=${e.message}');
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
      print('[ShareRepo] Error searching users: $e');
      return [];
    }
  }

  /// Watch inbox for real-time updates
  Stream<List<InboxShareItem>> watchInbox() {
    return _client
        .from('inbox_share_items_filtered')
        .stream(primaryKey: ['share_id'])
        .order('created_at', ascending: false)
        .map((data) => data
            .map((item) => InboxShareItem.fromJson(item as Map<String, dynamic>))
            .toList());
  }

  /// Watch unread count for real-time updates
  Stream<int> watchUnreadCount() {
    return _client
        .from('inbox_unread_count_filtered')
        .stream(primaryKey: ['recipient_id'])
        .map((data) => data.isNotEmpty ? data.first['count'] as int? ?? 0 : 0);
  }
}

