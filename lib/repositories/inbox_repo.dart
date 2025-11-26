// lib/repositories/inbox_repo.dart
// FIXED VERSION - Correctly checks if user has imported flow
// 
// KEY FIX: The old code was checking flow_shares.flow_id (sender's original flow)
// The new code checks flows.share_id (user's imported copy linked to inbox share)

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../data/share_models.dart';
import '../data/share_repo.dart';
import '../data/user_events_repo.dart';
import '../features/calendar/calendar_page.dart' show CalendarPage, KemeticMath;
import '../utils/event_cid_util.dart';

class InboxRepo {
  final SupabaseClient _client;
  final ShareRepo _shareRepo;
  
  InboxRepo(this._client) : _shareRepo = ShareRepo(_client);
  
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
  
  /// Watch conversations grouped by other user ID (DM-style)
  Stream<Map<String, List<InboxShareItem>>> watchConversations() {
    return watchInbox().map((items) {
      final uid = currentUserId;
      if (uid == null) return <String, List<InboxShareItem>>{};
      
      final Map<String, List<InboxShareItem>> grouped = {};
      
      for (final item in items) {
        final otherId = _getOtherUserId(item, uid);
        if (otherId == null) continue;
        grouped.putIfAbsent(otherId, () => []).add(item);
      }
      
      // Sort each thread by createdAt ascending (older → newer)
      for (final list in grouped.values) {
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      
      return grouped;
    });
  }
  
  /// Watch a specific conversation with another user
  Stream<List<InboxShareItem>> watchConversationWith(String otherUserId) {
    return watchInbox().map((items) {
      final uid = currentUserId;
      if (uid == null) return <InboxShareItem>[];
      
      final conv = items.where((item) {
        final a = item.senderId == uid && item.recipientId == otherUserId;
        final b = item.senderId == otherUserId && item.recipientId == uid;
        return a || b;
      }).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      return conv;
    });
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
    if (kDebugMode) {
      print('[InboxRepo] Starting import for: ${share.title}');
    }
    
    try {
      final payloadJson = share.payloadJson;
      if (payloadJson == null) {
        throw Exception('No flow data available to import');
      }
      
      final name = payloadJson['name'] as String;
      final color = payloadJson['color'] as int;
      final notes = payloadJson['notes'] as String?;
      final rulesData = payloadJson['rules']; // This is a List
      
      // Determine start date
      DateTime? startDate = overrideStartDate;
      if (startDate == null && share.suggestedSchedule != null) {
        try {
          startDate = DateTime.parse(share.suggestedSchedule!.startDate);
        } catch (e) {
          if (kDebugMode) {
            print('[InboxRepo] Failed to parse start date: $e');
          }
        }
      }
      
      if (kDebugMode) {
        print('[InboxRepo] Flow data: name=$name, color=$color');
        print('[InboxRepo] Rules type: ${rulesData.runtimeType}');
      }
      
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
      );
      
      if (kDebugMode) {
        print('[InboxRepo] ✓ Flow created with ID: $flowId');
      }
      
      // Link the flow to the share for re-import tracking
      await userEventsRepo.updateFlowShareId(
        flowId: flowId,
        shareId: share.shareId,
      );
      
      if (kDebugMode) {
        print('[InboxRepo] ✓ Flow linked to share: ${share.shareId}');
      }
      
      // Mark the share as imported
      final success = await markImported(share.shareId, isFlow: true);
      if (!success) {
        throw Exception('Failed to mark share as imported');
      }
      
      if (kDebugMode) {
        print('[InboxRepo] ✓ Share marked as imported');
      }
      
      // Schedule the flow's notes immediately
      await _scheduleImportedFlow(flowId, share);
      
      return flowId;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('[InboxRepo] ✗ Import failed: $e');
        print('[InboxRepo] Stack trace: $stackTrace');
      }
      rethrow;
    }
  }
  
  /// Schedule notes for a newly imported flow
  Future<void> _scheduleImportedFlow(int flowId, InboxShareItem item) async {
    try {
      final payloadJson = item.payloadJson;
      if (payloadJson == null) return;
      
      final rulesData = payloadJson['rules'] as List?;
      if (rulesData == null || rulesData.isEmpty) return;
      
      // Parse rules using CalendarPage's static method
      final rules = rulesData.map((r) => 
        CalendarPage.ruleFromJson(r as Map<String, dynamic>)
      ).toList();
      
      final repo = UserEventsRepo(_client);
      final start = DateTime.now();
      final end = start.add(const Duration(days: 90));
      
      // Clear existing notes for this flow
      await repo.deleteByFlowId(flowId, fromDate: start.toUtc());
      
      int scheduledCount = 0;
      
      for (var date = start; date.isBefore(end); date = date.add(const Duration(days: 1))) {
        final kDate = KemeticMath.fromGregorian(date);
        
        for (final rule in rules) {
          if (rule.matches(ky: kDate.kYear, km: kDate.kMonth, kd: kDate.kDay, g: date)) {
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
            
            final startsAt = DateTime(date.year, date.month, date.day, startHour, startMinute);
            DateTime? endsAt;
            if (!rule.allDay && rule.end != null) {
              endsAt = DateTime(date.year, date.month, date.day, rule.end!.hour, rule.end!.minute);
            }
            
            await repo.upsertByClientId(
              clientEventId: cid,
              title: noteTitle,
              startsAtUtc: startsAt.toUtc(),
              detail: '',
              allDay: rule.allDay,
              endsAtUtc: endsAt?.toUtc(),
              flowLocalId: flowId,
            );
            
            scheduledCount++;
          }
        }
      }
      
      if (kDebugMode) {
        print('[InboxRepo] ✓ Scheduled $scheduledCount notes for flow $flowId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[InboxRepo] ✗ Failed to schedule: $e');
      }
      // Don't rethrow - scheduling failure shouldn't fail the import
    }
  }
}