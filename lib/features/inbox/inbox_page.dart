// lib/features/inbox/inbox_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/share_models.dart';
import '../../data/share_repo.dart';
import '../../data/user_events_repo.dart';
import '../../repositories/inbox_repo.dart';
import '../calendar/calendar_page.dart';
import '../../utils/event_cid_util.dart';
import 'inbox_conversation_page.dart';
import 'conversation_user.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({Key? key}) : super(key: key);

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  static const _bg = Color(0xFF000000);
  static const _cardBg = Color(0xFF0D0D0F);
  static const _gold = Color(0xFFD4AF37);
  static const _silver = Color(0xFFB0B0B0);

  late final InboxRepo _inboxRepo;
  late final ShareRepo _shareRepo;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _shareRepo = ShareRepo(client);
    _inboxRepo = InboxRepo(client);
  }

  Future<void> _handleRefresh() async {
    // Stream auto-updates; small delay to let stream catch up
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: _gold),
          onPressed: () => Navigator.pop(context),
        ),
        title: StreamBuilder<int>(
          stream: _shareRepo.watchUnreadCount(),
          builder: (context, snapshot) {
            final unreadCount = snapshot.data ?? 0;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Inbox',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _gold,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: _gold,
      child: StreamBuilder<Map<String, List<InboxShareItem>>>(
        stream: _inboxRepo.watchConversations(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load inbox',
                    style: TextStyle(
                      color: _silver,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      '${snapshot.error}',
                      style: const TextStyle(
                        color: _silver,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _handleRefresh,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_gold),
              ),
            );
          }

          final threads = snapshot.data!;
          if (threads.isEmpty) {
            return _buildEmptyState();
          }

          final entries = threads.entries.toList()
            ..sort((a, b) {
              // Sort by newest message in thread (descending)
              final aLast = a.value.last.createdAt;
              final bLast = b.value.last.createdAt;
              return bLast.compareTo(aLast);
            });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final otherUserId = entries[index].key;
              final items = entries[index].value;
              final last = items.last;
              final currentUserId = _inboxRepo.currentUserId;
              
              if (currentUserId == null) {
                return const SizedBox.shrink();
              }
              
              final otherProfile = _resolveOtherProfile(last, currentUserId);
              final hasUnread = items.any((i) => i.isUnread);

              return _buildConversationBar(
                context: context,
                otherUserId: otherUserId,
                otherProfile: otherProfile,
                lastItem: last,
                hasUnread: hasUnread,
              );
            },
          );
        },
      ),
    );
  }
  
  ConversationUser _resolveOtherProfile(InboxShareItem item, String currentUserId) {
    final isMine = item.senderId == currentUserId;
    
    if (!isMine) {
      // Item was sent TO me, so sender is the "other" person
      return ConversationUser(
        id: item.senderId,
        displayName: item.senderName,
        handle: item.senderHandle,
        avatarUrl: item.senderAvatar,
      );
    } else {
      // Item was sent BY me, so recipient is the "other" person
      // TODO: Once backend adds recipient profile fields, use those
      return ConversationUser(
        id: item.recipientId,
        displayName: item.recipientDisplayName ?? 'User',
        handle: item.recipientHandle ?? 'user',
        avatarUrl: item.recipientAvatarUrl,
      );
    }
  }
  
  Widget _buildConversationBar({
    required BuildContext context,
    required String otherUserId,
    required ConversationUser otherProfile,
    required InboxShareItem lastItem,
    required bool hasUnread,
  }) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: _gold.withOpacity(0.2),
        backgroundImage: otherProfile.avatarUrl != null
            ? NetworkImage(otherProfile.avatarUrl!)
            : null,
        child: otherProfile.avatarUrl == null
            ? Text(
                (otherProfile.displayName ?? otherProfile.handle ?? '?')
                    .characters
                    .take(2)
                    .toString()
                    .toUpperCase(),
                style: const TextStyle(
                  color: _gold,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Text(
        otherProfile.displayName ?? otherProfile.handle ?? 'User',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        lastItem.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 14,
        ),
      ),
      trailing: hasUnread
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: _gold,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InboxConversationPage(
              otherUserId: otherUserId,
              otherProfile: otherProfile,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No shares yet',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Shared flows will appear here',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}


// Legacy code below - keeping for FlowPreviewCard compatibility
// Preview Card Widget
class FlowPreviewCard extends StatefulWidget {
  final InboxShareItem item;
  final Map<String, bool> importStatusCache;
  final VoidCallback onImportComplete;

  const FlowPreviewCard({
    Key? key,
    required this.item,
    required this.importStatusCache,
    required this.onImportComplete,
  }) : super(key: key);

  @override
  State<FlowPreviewCard> createState() => _FlowPreviewCardState();
}

class _FlowPreviewCardState extends State<FlowPreviewCard> {
  static const _bg = Color(0xFF000000);
  static const _cardBg = Color(0xFF0D0D0F);
  static const _gold = Color(0xFFD4AF37);
  static const _silver = Color(0xFFB0B0B0);

  final _shareRepo = ShareRepo(Supabase.instance.client);
  final _inboxRepo = InboxRepo(Supabase.instance.client);
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.85,
      ),
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Flow Preview',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: _silver),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          const Divider(color: _silver, height: 1),
          
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 20 + bottomPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender info
                  _buildSenderInfo(),
                  const SizedBox(height: 24),
                  
                  // Flow title and details
                  _buildFlowDetails(),
                  const SizedBox(height: 24),
                  
                  // Suggested schedule (if present)
                  if (widget.item.suggestedSchedule != null) ...[
                    _buildScheduleSection(),
                    const SizedBox(height: 24),
                  ],
                  
                  // Action buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSenderInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: _gold.withOpacity(0.2),
            backgroundImage: widget.item.senderAvatar != null
                ? NetworkImage(widget.item.senderAvatar!)
                : null,
            child: widget.item.senderAvatar == null
                ? Text(
                    (widget.item.senderName ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.senderName ?? 'Unknown User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${widget.item.senderHandle ?? 'unknown'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shared ${widget.item.isFlow ? 'Flow' : 'Event'}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.item.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleSection() {
    final schedule = widget.item.suggestedSchedule!;
    final weekdayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suggested Schedule',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _gold.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Start date
              if (schedule.startDate.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.calendar_today, 
                        size: 16, 
                        color: Colors.white.withOpacity(0.5)),
                    const SizedBox(width: 8),
                    Text(
                      'Starts: ${schedule.startDate}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              
              // Weekdays
              if (schedule.weekdays.isNotEmpty) ...[
                Text(
                  'Days:',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: schedule.weekdays.map((day) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _gold.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _gold.withOpacity(0.5)),
                      ),
                      child: Text(
                        weekdayNames[day],
                        style: const TextStyle(
                          color: _gold,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              
              // Times
              if (schedule.timesByWeekday.isNotEmpty) ...[
                Text(
                  'Times:',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                ...schedule.timesByWeekday.entries.map((entry) {
                  final dayName = weekdayNames[int.parse(entry.key)];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 50,
                          child: Text(
                            dayName,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            entry.value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InboxFlowDetailsPage(item: widget.item),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
            ),
            child: const Text('View Full Details'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: _buildImportButton(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Close',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImportButton() {
    return FutureBuilder<int?>(
      future: UserEventsRepo(Supabase.instance.client).getFlowIdByShareId(widget.item.shareId),
      builder: (context, snapshot) {
        final flowId = snapshot.data;
        final isImported = flowId != null; // Flow exists in user's flows
        
        return ElevatedButton(
          onPressed: _isImporting || isImported ? null : _handleImport,
          style: ElevatedButton.styleFrom(
            backgroundColor: isImported 
              ? const Color(0xFF4A4A4A)  // Visible medium grey
              : const Color(0xFFD4AF37),
            foregroundColor: isImported 
              ? const Color(0xFFAAAAAA)  // Light grey text
              : Colors.black,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isImporting
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              : Text(
                  isImported 
                      ? 'Already Imported'
                      : (widget.item.isFlow
                          ? 'Import Flow to Calendar'
                          : 'Import Event to Calendar'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        );
      },
    );
  }

  Future<void> _handleImport() async {
    setState(() => _isImporting = true);
    
    try {
      final inboxRepo = InboxRepo(Supabase.instance.client);
      final userEventsRepo = UserEventsRepo(Supabase.instance.client);
      
      int? flowId;
      if (widget.item.isFlow) {
        // Step 1: Import the flow and get the flowId
        flowId = await _importFlow(widget.item);
        
        if (kDebugMode) {
          print('[InboxPage] ✓ Successfully imported flow $flowId and linked to share ${widget.item.shareId}');
        }
      } else {
        // TODO: Implement event import
        throw Exception('Event import not yet implemented');
      }
      
      if (!mounted) return;
      
      // Step 4: Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.item.title} imported successfully!'),
          backgroundColor: const Color(0xFFD4AF37),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Close the preview modal
      Navigator.pop(context); // Close preview
      
      // Notify parent to refresh
      widget.onImportComplete();
      
      // ✅ NEW: Close inbox and return the flowId to calendar
      Navigator.pop(context, flowId);
    } catch (e) {
      if (kDebugMode) {
        print('[InboxPage] ✗ Import failed: $e');
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to import: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<int> _importFlow(InboxShareItem item) async {
    try {
      if (kDebugMode) {
        print('[InboxPage] Starting import for: ${item.title}');
      }
      
      // Step 1: Extract flow data from payloadJson
      final payloadJson = item.payloadJson;
      if (payloadJson == null) {
        throw Exception('No flow data available to import');
      }
      
      final name = payloadJson['name'] as String;
      final color = payloadJson['color'] as int;
      final notes = payloadJson['notes'] as String?;
      final rulesData = payloadJson['rules']; // This is a List
      
      // Extract start_date from suggested_schedule if available
      DateTime? startDate;
      if (item.suggestedSchedule != null) {
        try {
          startDate = DateTime.parse(item.suggestedSchedule!.startDate);
        } catch (e) {
          if (kDebugMode) {
            print('[InboxPage] Failed to parse start date: $e');
          }
        }
      }
      
      if (kDebugMode) {
        print('[InboxPage] Flow data: name=$name, color=$color');
        print('[InboxPage] Rules type: ${rulesData.runtimeType}');
      }
      
      // Step 2: Convert rules from List to JSON String
      final rulesString = jsonEncode(rulesData);
      
      if (kDebugMode) {
        print('[InboxPage] Rules JSON string: $rulesString');
      }
      
      // Step 3: Import the flow using UserEventsRepo
      final userEventsRepo = UserEventsRepo(Supabase.instance.client);
      final flowId = await userEventsRepo.upsertFlow(
        name: name,
        color: color,
        active: true,
        startDate: startDate,
        notes: notes,
        rules: rulesString,
      );
      
      if (kDebugMode) {
        print('[InboxPage] ✓ Flow created with ID: $flowId');
      }
      
      // Step 4: Link the flow to the share for re-import tracking
      await userEventsRepo.updateFlowShareId(
        flowId: flowId,
        shareId: item.shareId,
      );
      
      if (kDebugMode) {
        print('[InboxPage] ✓ Flow linked to share: ${item.shareId}');
      }
      
      // Step 5: Mark the share as imported
      final inboxRepo = InboxRepo(Supabase.instance.client);
      final success = await inboxRepo.markImported(
        item.shareId,
        isFlow: true,
      );
      
      if (!success) {
        throw Exception('Failed to mark share as imported');
      }
      
      if (kDebugMode) {
        print('[InboxPage] ✓ Share marked as imported');
      }
      
      // Step 6: Schedule the flow's notes immediately using the NEW flow ID
      await _scheduleImportedFlow(flowId, item);
      
      return flowId;
      
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('[InboxPage] ✗ Import failed: $e');
        print('[InboxPage] Stack trace: $stackTrace');
      }
      rethrow; // Let the caller handle the error
    }
  }

  /// Schedules notes for a newly imported flow
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
      
      final repo = UserEventsRepo(Supabase.instance.client);
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
              detail: '',  // ✅ Remove the flowLocalId from detail
              allDay: rule.allDay,
              endsAtUtc: endsAt?.toUtc(),
              flowLocalId: flowId,  // ✅ ADD THIS - Proper parameter!
            );
            
            scheduledCount++;
          }
        }
      }
      
      if (kDebugMode) {
        print('[InboxPage] ✓ Scheduled $scheduledCount notes for flow $flowId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[InboxPage] ✗ Failed to schedule: $e');
      }
    }
  }


}

class InboxFlowDetailsPage extends StatelessWidget {
  final InboxShareItem item;

  const InboxFlowDetailsPage({super.key, required this.item});

  bool _isLikelyUrl(String text) {
    final lower = text.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  List<TextSpan> _buildTextSpans(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(https?://\S+)', multiLine: true);
    int start = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: const TextStyle(
            decoration: TextDecoration.underline,
            color: Color(0xFF4DA3FF),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
        ),
      );
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final payload = item.payloadJson ?? <String, dynamic>{};
    final name = (payload['name'] as String?) ?? item.title;
    final overview = (payload['overview'] as String?) ?? '';
    final active = (payload['active'] as bool?) ?? true;
    final colorInt = (payload['color'] as int?) ?? 0xFFD4AF37;
    final color = Color(colorInt);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(name),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                active ? 'Active' : 'Inactive',
                style: TextStyle(
                  fontSize: 12,
                  color: active
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFB0B0B0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (overview.isNotEmpty) ...[
            const Text(
              'Overview',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFDDDDDD),
                  height: 1.4,
                ),
                children: _buildTextSpans(overview),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // TODO: extend with schedule / rules if you want parity with Flow Studio
        ],
      ),
    );
  }
}




