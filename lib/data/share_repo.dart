// lib/data/share_repo.dart
// ShareRepo - Repository Layer for Flow Sharing System

import 'package:supabase_flutter/supabase_flutter.dart';
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
    try {
      final response = await _client.functions.invoke(
        'create_flow_share',
        body: {
          'flow_id': flowId,
          'recipients': recipients.map((r) => r.toJson()).toList(),
          if (suggestedSchedule != null) 'suggested_schedule': suggestedSchedule.toJson(),
        },
      );

      if (response.data == null) {
        throw Exception('No response from create_flow_share function');
      }

      final results = (response.data['results'] as List)
          .map((r) => ShareResult.fromJson(r as Map<String, dynamic>))
          .toList();

      return results;
    } catch (e) {
      print('[ShareRepo] Error sharing flow: $e');
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

  /// Delete an inbox item
  Future<bool> deleteInboxItem(String shareId, {required bool isFlow}) async {
    try {
      final table = isFlow ? 'flow_shares' : 'event_shares';
      await _client
          .from(table)
          .delete()
          .eq('id', shareId);

      return true;
    } catch (e) {
      print('[ShareRepo] Error deleting inbox item: $e');
      return false;
    }
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
