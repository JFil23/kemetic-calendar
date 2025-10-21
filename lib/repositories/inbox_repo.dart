// lib/repositories/inbox_repo.dart
// FIXED VERSION - Correctly checks if user has imported flow
// 
// KEY FIX: The old code was checking flow_shares.flow_id (sender's original flow)
// The new code checks flows.share_id (user's imported copy linked to inbox share)

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/share_models.dart';

class InboxRepo {
  final SupabaseClient _client;
  
  InboxRepo(this._client);

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
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        if (kDebugMode) print('[InboxRepo] No user logged in');
        return false;
      }
      
      // ✅ CORRECT: Look in user's flows table for a flow with this share_id
      // This finds the USER'S imported copy, not the sender's original
      final flowResponse = await _client
          .from('flows')
          .select('id, active, share_id')
          .eq('user_id', userId)        // User's flows only
          .eq('share_id', shareId)      // Linked to this inbox share
          .maybeSingle();
      
      // Flow is imported if it exists and is active
      final exists = flowResponse != null && (flowResponse['active'] as bool? ?? true);
      
      if (kDebugMode) {
        print('[InboxRepo] isFlowCurrentlyImported($shareId)');
        print('[InboxRepo]   userId: $userId');
        print('[InboxRepo]   exists: $exists');
        if (flowResponse != null) {
          print('[InboxRepo]   flow_id: ${flowResponse['id']}');
          print('[InboxRepo]   active: ${flowResponse['active']}');
          print('[InboxRepo]   share_id: ${flowResponse['share_id']}');
        } else {
          print('[InboxRepo]   No flow found with share_id=$shareId');
        }
      }
      
      return exists;
    } catch (e) {
      if (kDebugMode) {
        print('[InboxRepo] ❌ Error checking import status: $e');
      }
      return false;
    }
  }
  
  /// Mark a share as imported (called after successful import)
  Future<bool> markImported(String shareId, {required bool isFlow}) async {
    try {
      final table = isFlow ? 'flow_shares' : 'event_shares';
      await _client
          .from(table)
          .update({'imported_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', shareId);
      
      if (kDebugMode) {
        print('[InboxRepo] Marked $shareId as imported in $table');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[InboxRepo] Error marking imported: $e');
      }
      return false;
    }
  }
  
  /// Clear import status (manually called or triggered by deletion)
  Future<bool> clearImportStatus(String shareId, {required bool isFlow}) async {
    try {
      final table = isFlow ? 'flow_shares' : 'event_shares';
      await _client
          .from(table)
          .update({'imported_at': null})
          .eq('id', shareId);
      
      if (kDebugMode) {
        print('[InboxRepo] Cleared import status for $shareId in $table');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[InboxRepo] Error clearing import status: $e');
      }
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
      if (kDebugMode) {
        print('[InboxRepo] Error loading shares: $e');
      }
      return [];
    }
  }
}