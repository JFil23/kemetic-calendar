// lib/features/inbox/inbox_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/share_models.dart';
import '../../data/share_repo.dart';
import '../../data/user_events_repo.dart';
import '../../repositories/inbox_repo.dart';
import '../calendar/calendar_page.dart';
import 'dart:convert';

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

  final _shareRepo = ShareRepo(Supabase.instance.client);
  final _inboxRepo = InboxRepo(Supabase.instance.client);
  List<InboxShareItem> _items = [];
  bool _isLoading = true;
  String? _error;
  int _unreadCount = 0;
  
  // NEW: Cache of actual import statuses
  final Map<String, bool> _importStatusCache = {};

  @override
  void initState() {
    super.initState();
    _loadInboxItems();
  }

  Future<void> _loadInboxItems() async {
    print('📬 [InboxPage] Starting _loadInboxItems()');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('📬 [InboxPage] Calling _shareRepo.getInboxItems()...');
      final items = await _shareRepo.getInboxItems();
      print('📬 [InboxPage] Received ${items.length} items from repo');
      
      if (items.isNotEmpty) {
        print('📬 [InboxPage] First item: ${items[0].title} from @${items[0].senderHandle}');
      } else {
        print('⚠️  [InboxPage] Items list is EMPTY');
      }
      
      final unreadCount = await _shareRepo.getUnreadCount();
      print('📬 [InboxPage] Unread count: $unreadCount');
      
      // NEW: Check actual import status for each flow share
      for (final item in items) {
        if (item.isFlow) {
          final isImported = await _inboxRepo.isFlowCurrentlyImported(item.shareId);
          _importStatusCache[item.shareId] = isImported;
        } else {
          // For events, keep the simple check
          _importStatusCache[item.shareId] = item.importedAt != null;
        }
      }
      
      if (mounted) {
        setState(() {
          _items = items;
          _unreadCount = unreadCount;
          _isLoading = false;
        });
        print('📬 [InboxPage] State updated with ${_items.length} items');
      }
    } catch (e, stackTrace) {
      print('❌ [InboxPage] Error in _loadInboxItems: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _loadInboxItems();
  }

  Future<void> _onItemTap(InboxShareItem item) async {
    // Mark as viewed immediately
    if (item.viewedAt == null) {
      try {
        await _shareRepo.markViewed(item.shareId, isFlow: item.isFlow);
        
        // Update local state manually (no copyWith method)
        final index = _items.indexWhere((i) => i.shareId == item.shareId);
        if (index != -1) {
          setState(() {
            _items[index] = InboxShareItem(
              shareId: item.shareId,
              kind: item.kind,
              recipientId: item.recipientId,
              senderId: item.senderId,
              senderHandle: item.senderHandle,
              senderName: item.senderName,
              senderAvatar: item.senderAvatar,
              payloadId: item.payloadId,
              title: item.title,
              createdAt: item.createdAt,
              viewedAt: DateTime.now(), // ✅ Mark as viewed
              importedAt: item.importedAt,
              suggestedSchedule: item.suggestedSchedule,
              eventDate: item.eventDate,
              payloadJson: item.payloadJson,
            );
          });
        }
      } catch (e) {
        print('Failed to mark as viewed: $e');
      }
    }

    // Show preview modal
    if (!mounted) return;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FlowPreviewCard(
        item: item,
        importStatusCache: _importStatusCache,
        onImportComplete: () => _loadInboxItems(), // Refresh after import
      ),
    );

    // Refresh inbox if flow was imported
    if (result is int) {  // ✅ Only reload if flow was imported
      // Small delay to let database update propagate
      await Future.delayed(const Duration(milliseconds: 300));
      await _loadInboxItems();
    }
  }

  Future<void> _onDismiss(InboxShareItem item) async {
    // Optimistically remove from UI
    setState(() {
      _items.removeWhere((i) => i.shareId == item.shareId);
    });

    try {
      // Delete from database
      await _shareRepo.deleteInboxItem(item.shareId, isFlow: item.isFlow);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Share dismissed'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.black87,
        ),
      );
    } catch (e) {
      // Restore item on error
      await _loadInboxItems();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to dismiss: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        title: Row(
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
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _gold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_gold),
        ),
      );
    }

    if (_error != null) {
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
                _error!,
                style: const TextStyle(
                  color: _silver,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInboxItems,
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

    if (_items.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: _gold,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return _buildInboxCard(item);
        },
      ),
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

  Widget _buildInboxCard(InboxShareItem item) {
    final isUnread = item.viewedAt == null;
    final isImported = item.importedAt != null;

    return Dismissible(
      key: Key(item.shareId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _onDismiss(item),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: InkWell(
        onTap: () => _onItemTap(item),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUnread ? _gold.withOpacity(0.3) : Colors.white.withOpacity(0.1),
              width: isUnread ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Unread dot indicator
              if (isUnread)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: const BoxDecoration(
                    color: _gold,
                    shape: BoxShape.circle,
                  ),
                ),
              
              // Sender avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: _gold.withOpacity(0.2),
                backgroundImage: item.senderAvatar != null
                    ? NetworkImage(item.senderAvatar!)
                    : null,
                child: item.senderAvatar == null
                    ? Text(
                        (item.senderName ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          color: _gold,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sender info + timestamp
                    Row(
                      children: [
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: item.senderName ?? 'Unknown User',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                  ),
                                ),
                                TextSpan(
                                  text: ' @${item.senderHandle ?? 'unknown'}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          _formatTimeAgo(item.createdAt),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // Flow title
                    Text(
                      item.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    
                    // Status badges
                    Row(
                      children: [
                        if (isImported)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Imported',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (isUnread) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _gold.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'New',
                              style: TextStyle(
                                color: _gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Icon(
                          item.isFlow ? Icons.view_timeline : Icons.event,
                          size: 14,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.isFlow ? 'Flow' : 'Event',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Chevron
              Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.month}/${date.day}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}

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
            
            final cid = _buildCid(
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

  String _buildCid({
    required int ky,
    required int km,
    required int kd,
    required String title,
    required int startHour,
    required int startMinute,
    required bool allDay,
    required int flowId,
  }) {
    final startMin = allDay ? 540 : (startHour * 60 + startMinute);
    return 'ky=$ky-km=$km-kd=$kd|s=$startMin|t=${Uri.encodeComponent(title)}|f=$flowId';
  }

}
