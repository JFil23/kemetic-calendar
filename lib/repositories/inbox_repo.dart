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
  
  /// Mark a share as imported (delegates to ShareRepo)
  Future<bool> markImported(String shareId, {required bool isFlow}) {
    return _shareRepo.markImported(shareId, isFlow: isFlow);
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
        // ✅ Skip deleted items
        if (item.isDeleted) continue;
        
        final otherId = _getOtherUserId(item, uid);
        if (otherId == null) continue;
        grouped.putIfAbsent(otherId, () => []).add(item);
      }
      
      // Sort each thread by createdAt ascending (older → newer)
      for (final list in grouped.values) {
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      
      if (kDebugMode) {
        debugPrint('[watchConversations] ${grouped.length} conversations, keys: ${grouped.keys.toList()}');
        // ✅ Add per-thread logging
        for (final entry in grouped.entries) {
          debugPrint('[watchConversations] otherId=${entry.key} items=${entry.value.length}');
        }
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
        return (a || b) && !item.isDeleted; // ✅ don't show deleted
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
      
      // Schedule the flow's notes immediately (using the selected start date)
      await _scheduleImportedFlow(flowId, share, startDate: startDate);
      
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
        print('[InboxRepo] _scheduleImportedFlow for flowId=$flowId');
        print('[InboxRepo] payloadJson keys: ${payloadJson.keys}');
      }
      
      // ✅ 1. Use sender's event snapshots if present (NEW SHARES)
      final events = payloadJson['events'] as List<dynamic>?;
      if (events != null && events.isNotEmpty) {
        if (kDebugMode) {
          print('[InboxRepo] Importing ${events.length} snapshot events for flow $flowId');
        }
        
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
          
          final startsAt = DateTime(date.year, date.month, date.day, startHour, startMinute);
          
          DateTime? endsAt;
          if (!allDay) {
            if (endHour != null && endMinute != null) {
              endsAt = DateTime(date.year, date.month, date.day, endHour, endMinute);
            } else {
              endsAt = startsAt.add(const Duration(hours: 1));
            }
          }
          
          await repo.upsertByClientId(
            clientEventId: cid,
            title: title,          // ✅ exactly sender title
            startsAtUtc: startsAt.toUtc(),
            detail: detail,        // ✅ exactly sender detail
            location: location,    // ✅ exactly sender location
            allDay: allDay,
            endsAtUtc: endsAt?.toUtc(),
            flowLocalId: flowId,
          );
          
          count++;
        }
        
        if (kDebugMode) {
          print('[InboxRepo] ✓ Scheduled $count events from snapshot for flow $flowId');
        }
        return; // ✅ Don't fall back to rules - we have the real data
      }
      
      // 2. Fallback for old shares with no events[]: use rules-based logic
      if (kDebugMode) {
        print('[InboxRepo] No events[] in payload, falling back to rules-based scheduling for flowId=$flowId');
      }
      await _scheduleImportedFlowFromRules(flowId, item, startDate: start);
    } catch (e, stack) {
      if (kDebugMode) {
        print('[InboxRepo] ✗ Failed to schedule imported flow $flowId: $e');
        print(stack);
      }
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
      
      final rules = rulesData.map((r) => 
        CalendarPage.ruleFromJson(r as Map<String, dynamic>)
      ).toList();
      
      final repo = UserEventsRepo(_client);
      final start = startDate ?? DateTime.now();
      final end = start.add(const Duration(days: 90));
      
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
            break; // Only one event per day
          }
        }
      }
      
      if (kDebugMode) {
        print('[InboxRepo] ✓ Scheduled $scheduledCount notes from rules for flow $flowId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[InboxRepo] ✗ Failed to schedule from rules: $e');
      }
    }
  }
}