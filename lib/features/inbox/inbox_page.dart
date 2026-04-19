// lib/features/inbox/inbox_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/share_models.dart';
import '../../data/share_repo.dart';
import '../../data/user_events_repo.dart';
import '../../repositories/inbox_repo.dart';
import 'inbox_conversation_page.dart';
import 'conversation_user.dart';
import '../../data/profile_repo.dart';
import '../../utils/detail_sanitizer.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import '../profile/flow_post_detail_page.dart';
import '../profile/profile_page.dart';
import '../profile/profile_search_page.dart';
import 'package:mobile/shared/glossy_text.dart';

void _logInboxImport(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

class InboxPage extends StatefulWidget {
  const InboxPage({Key? key}) : super(key: key);

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  static const _bg = Color(0xFF000000);
  static const _cardBg = Color(0xFF0D0D0F);
  static const _gold = KemeticGold.base;
  static const _silver = Color(0xFFB0B0B0);

  late final InboxRepo _inboxRepo;
  late final ShareRepo _shareRepo;
  StreamSubscription<Map<String, List<InboxShareItem>>>? _convSub;
  Map<String, List<InboxShareItem>> _latestThreads = const {};
  List<_UnifiedInboxItem> _unified = const [];
  bool _loading = true;
  InboxActivityItem? _latestFollow;
  InboxActivityItem? _latestEngagement;
  List<InboxActivityItem> _activity = const [];
  bool _marking = false;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _shareRepo = ShareRepo(client);
    _inboxRepo = InboxRepo(client);
    _convSub = _inboxRepo.watchConversations().listen((threads) {
      _latestThreads = threads;
      _refreshUnified();
    });
    _refreshUnified();
  }

  Future<void> _handleRefresh() async {
    await _refreshUnified();
  }

  Future<void> _refreshUnified() async {
    setState(() => _loading = true);
    final activity = await _shareRepo.getRecentActivity(limit: 50);
    InboxActivityItem? firstMatch(bool Function(InboxActivityItem) test) {
      for (final item in activity) {
        if (test(item)) return item;
      }
      return null;
    }

    _activity = activity;
    _latestFollow = firstMatch((a) => a.type == InboxActivityType.follow);
    _latestEngagement = firstMatch(
      (a) =>
          a.type == InboxActivityType.like ||
          a.type == InboxActivityType.comment,
    );

    // Build message threads (use latest item in each thread)
    final messageItems = <_UnifiedInboxItem>[];
    _latestThreads.forEach((otherId, items) {
      if (items.isEmpty) return;
      final last = items.last;
      final currentUserId = _inboxRepo.currentUserId;
      if (currentUserId == null) return;
      final otherProfile = _resolveOtherProfile(last, currentUserId);
      final hasUnread = items.any(
        (i) => i.recipientId == currentUserId && i.isUnread,
      );
      messageItems.add(
        _UnifiedInboxItem.message(
          createdAt: last.createdAt,
          otherUserId: otherId,
          otherProfile: otherProfile,
          items: items,
          hasUnread: hasUnread,
        ),
      );
    });

    // Only messages appear in the feed; activity stays behind summary buttons.
    final merged = [...messageItems]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await _markAllUnreadViewed();

    if (!mounted) return;
    setState(() {
      _unified = merged;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _convSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: KemeticGold.icon(Icons.close),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
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
        actions: [
          IconButton(
            tooltip: 'New message',
            icon: KemeticGold.icon(Icons.search),
            onPressed: _openUserSearch,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Future<void> _openUserSearch() async {
    final selectedUser = await Navigator.of(context).push<UserSearchResult>(
      MaterialPageRoute(
        builder: (_) => const ProfileSearchPage(
          returnFullResult: true,
          titleText: 'New Message',
          hintText: 'Search people to message',
        ),
      ),
    );

    if (!mounted || selectedUser == null) return;

    final currentUserId = _inboxRepo.currentUserId;
    if (currentUserId != null && selectedUser.userId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot message yourself')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InboxConversationPage(
          otherUserId: selectedUser.userId,
          otherProfile: ConversationUser(
            id: selectedUser.userId,
            displayName: selectedUser.displayName,
            handle: selectedUser.handle,
            avatarUrl: selectedUser.avatarUrl,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: _gold,
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_gold),
              ),
            )
          : (_unified.isEmpty && !_hasSummaries
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _unified.length + _summaryTileCount,
                    itemBuilder: (context, index) {
                      if (_hasSummaries && index < _summaryTileCount) {
                        return _buildSummaryTile(index);
                      }
                      final adjIndex = _hasSummaries
                          ? index - _summaryTileCount
                          : index;
                      final item = _unified[adjIndex];
                      if (item.kind == _UnifiedKind.message) {
                        return _buildConversationBar(
                          context: context,
                          otherUserId: item.otherUserId!,
                          otherProfile: item.otherProfile!,
                          lastItem: item.items!.last,
                          hasUnread: item.hasUnread ?? false,
                          items: item.items!,
                        );
                      } else {
                        return _buildActivityRow(item.activity!);
                      }
                    },
                  )),
    );
  }

  ConversationUser _resolveOtherProfile(
    InboxShareItem item,
    String currentUserId,
  ) {
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
    required List<InboxShareItem> items,
  }) {
    return Dismissible(
      key: Key('conversation_$otherUserId'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF0D0D0F),
                title: const Text(
                  'Delete Conversation?',
                  style: TextStyle(color: Colors.white),
                ),
                content: Text(
                  'This will remove all shared flows/messages with '
                  '${otherProfile.displayName ?? otherProfile.handle ?? 'this user'} '
                  'from your inbox. It will not affect them.',
                  style: const TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) async {
        final shareRepo = ShareRepo(Supabase.instance.client);
        final currentUserId = _inboxRepo.currentUserId;
        if (currentUserId == null) return;

        // Get the latest snapshot of messages in this conversation
        final items = await _inboxRepo.watchConversationWith(otherUserId).first;

        for (final item in items) {
          final isMine = item.senderId == currentUserId;
          final isFlow = item.isFlow;
          final shareId = item.shareId;

          bool ok;
          if (isMine) {
            ok = await shareRepo.unsendShare(shareId, isFlow: isFlow);
          } else {
            ok = await shareRepo.deleteInboxItem(shareId, isFlow: isFlow);
          }

          if (!ok && kDebugMode) {
            debugPrint(
              '[InboxPage] Failed to ${isMine ? 'unsend' : 'delete'} shareId=$shareId',
            );
          }
        }
      },
      child: ListTile(
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
          lastItem.isTextMessage
              ? (lastItem.messageText ?? 'Message')
              : _conversationPreviewText(lastItem),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'View profile',
              icon: KemeticGold.icon(Icons.person),
              onPressed: () => _openProfile(otherUserId),
            ),
            if (hasUnread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 4),
                decoration: const BoxDecoration(
                  color: _gold,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        onTap: () {
          // Mark unread incoming items as viewed when opening the thread
          _markConversationRead(items);

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
      ),
    );
  }

  Future<void> _markConversationRead(List<InboxShareItem> items) async {
    final currentUserId = _inboxRepo.currentUserId;
    if (currentUserId == null) return;

    final shareRepo = ShareRepo(Supabase.instance.client);

    for (final item in items) {
      final isIncoming = item.recipientId == currentUserId;
      if (isIncoming && item.viewedAt == null) {
        try {
          await shareRepo.markViewed(item.shareId, isFlow: item.isFlow);
        } catch (_) {
          // swallow errors; badge will refresh on next stream update
        }
      }
    }
  }

  String _conversationPreviewText(InboxShareItem item) {
    if (!item.isEvent) return item.title;
    final status = item.responseStatus;
    if (status == EventInviteResponseStatus.noResponse) {
      return item.title;
    }
    return '${item.title} • ${status.label}';
  }

  void _openProfile(String userId) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ProfilePage(userId: userId)));
  }

  Future<void> _openActivity(InboxActivityItem activity) async {
    if (activity.type == InboxActivityType.follow) {
      final actorId = activity.actorId;
      if (actorId != null) {
        _openProfile(actorId);
      }
      return;
    }

    final flowPostId = activity.flowPostId;
    if (flowPostId == null) {
      _showActivityOpenError();
      return;
    }

    final post = await ProfileRepo(
      Supabase.instance.client,
    ).getFlowPostById(flowPostId);
    if (!mounted) return;
    if (post == null) {
      _showActivityOpenError();
      return;
    }

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FlowPostDetailPage(
          post: post,
          isOwner: currentUserId != null && post.userId == currentUserId,
          openCommentsOnLoad: activity.type == InboxActivityType.comment,
        ),
      ),
    );
  }

  void _showActivityOpenError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open this movement notification.'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<void> _markAllUnreadViewed() async {
    if (_marking) return;
    final currentUserId = _inboxRepo.currentUserId;
    if (currentUserId == null) return;
    _marking = true;
    final tasks = <Future<bool>>[];
    for (final thread in _latestThreads.values) {
      for (final item in thread) {
        final isIncoming = item.recipientId == currentUserId;
        if (isIncoming && item.viewedAt == null) {
          tasks.add(_shareRepo.markViewed(item.shareId, isFlow: item.isFlow));
        }
      }
    }
    try {
      if (tasks.isNotEmpty) {
        await Future.wait(tasks);
      }
    } finally {
      _marking = false;
    }
  }

  Widget _buildActivityRow(
    InboxActivityItem activity, {
    BuildContext? closeContext,
  }) {
    IconData icon;
    Color color;
    String title;
    String subtitle;

    switch (activity.type) {
      case InboxActivityType.like:
        icon = Icons.favorite;
        color = Colors.redAccent;
        title =
            '${activity.actorName ?? activity.actorHandle ?? 'Someone'} liked your flow';
        subtitle = activity.flowName ?? '';
        break;
      case InboxActivityType.comment:
        icon = Icons.chat_bubble_outline;
        color = KemeticGold.base;
        title =
            '${activity.actorName ?? activity.actorHandle ?? 'Someone'} commented on your flow';
        subtitle = activity.commentPreview ?? activity.flowName ?? '';
        break;
      case InboxActivityType.follow:
        icon = Icons.person_add;
        color = Colors.blueAccent;
        title =
            '${activity.actorName ?? activity.actorHandle ?? 'Someone'} started following you';
        subtitle = '';
        break;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            )
          : null,
      onTap: () async {
        if (closeContext != null) {
          Navigator.of(closeContext).pop();
        }
        await _openActivity(activity);
      },
    );
  }

  bool get _hasSummaries => _latestFollow != null || _latestEngagement != null;
  int get _summaryTileCount =>
      (_latestFollow != null ? 1 : 0) + (_latestEngagement != null ? 1 : 0);

  Widget _buildSummaryTile(int index) {
    // Order: follow first, then engagement
    if (_latestFollow != null && index == 0) {
      final a = _latestFollow!;
      final title =
          '${a.actorName ?? a.actorHandle ?? 'Someone'} started following you';
      return ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.blueAccent,
          child: Icon(Icons.person_add, color: Colors.white),
        ),
        title: Text(
          'Community',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          title,
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        onTap: _openFollowersSheet,
      );
    }

    final a = _latestEngagement!;
    final who = a.actorName ?? a.actorHandle ?? 'Someone';
    final preview = a.type == InboxActivityType.comment
        ? (a.commentPreview ?? a.flowName ?? '')
        : (a.flowName ?? '');
    final summary = a.type == InboxActivityType.comment
        ? '$who commented on your flow'
        : '$who liked your flow';
    final subtitleText = preview.isNotEmpty ? '$summary - $preview' : summary;

    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Colors.pinkAccent,
        child: Icon(Icons.favorite, color: Colors.white),
      ),
      title: const Text(
        'Movement',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitleText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.white.withOpacity(0.7)),
      ),
      onTap: _openEngagementSheet,
    );
  }

  void _openFollowersSheet() {
    final followers =
        _activity.where((a) => a.type == InboxActivityType.follow).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _showActivitySheet(title: 'Community', items: followers);
  }

  void _openEngagementSheet() {
    final engagement =
        _activity
            .where(
              (a) =>
                  a.type == InboxActivityType.like ||
                  a.type == InboxActivityType.comment,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _showActivitySheet(title: 'Movement', items: engagement);
  }

  void _showActivitySheet({
    required String title,
    required List<InboxActivityItem> items,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Nothing here yet.',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final a = items[index];
                        return _buildActivityRow(a, closeContext: context);
                      },
                    ),
                  ),
              ],
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
            'Shared flows and messages will appear here',
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

enum _UnifiedKind { message, activity }

class _UnifiedInboxItem {
  _UnifiedInboxItem.message({
    required this.createdAt,
    required this.otherUserId,
    required this.otherProfile,
    required this.items,
    required this.hasUnread,
  }) : kind = _UnifiedKind.message,
       activity = null;

  _UnifiedInboxItem.activity({required this.createdAt, required this.activity})
    : kind = _UnifiedKind.activity,
      otherUserId = null,
      otherProfile = null,
      items = null,
      hasUnread = null;

  final _UnifiedKind kind;
  final DateTime createdAt;

  // Message thread fields
  final String? otherUserId;
  final ConversationUser? otherProfile;
  final List<InboxShareItem>? items;
  final bool? hasUnread;

  // Activity fields
  final InboxActivityItem? activity;
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
  static const _gold = KemeticGold.base;
  static const _silver = Color(0xFFB0B0B0);

  final _shareRepo = ShareRepo(Supabase.instance.client);
  final _inboxRepo = InboxRepo(Supabase.instance.client);
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
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
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.white.withOpacity(0.5),
                    ),
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

  Future<void> _handleRefresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    widget.onImportComplete();
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () async {
              final flowId = await Navigator.of(context).push<int>(
                MaterialPageRoute(
                  builder: (_) => InboxFlowDetailsPage(item: widget.item),
                ),
              );
              if (!context.mounted) return;
              if (flowId != null) {
                await _handleRefresh();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Flow imported')));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: KemeticGold.base,
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImportButton() {
    return FutureBuilder<int?>(
      future: UserEventsRepo(
        Supabase.instance.client,
      ).getFlowIdByShareId(widget.item.shareId),
      builder: (context, snapshot) {
        final flowId = snapshot.data;
        final isImported = flowId != null; // Flow exists in user's flows
        final isFlowImportable = widget.item.isFlow;

        return ElevatedButton(
          onPressed: _isImporting || isImported || !isFlowImportable
              ? null
              : _handleImport,
          style: ElevatedButton.styleFrom(
            backgroundColor: isImported
                ? const Color(0xFF4A4A4A) // Visible medium grey
                : KemeticGold.base,
            foregroundColor: isImported
                ? const Color(0xFFAAAAAA) // Light grey text
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
                      : (isFlowImportable
                            ? 'Import Flow to Calendar'
                            : 'Event Import Unavailable'),
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
      if (!widget.item.isFlow) {
        throw Exception('Event import is not available in this build');
      }

      int? flowId;
      flowId = await _importFlow(widget.item);

      _logInboxImport(
        '[InboxPage] ✓ Successfully imported flow $flowId and linked to share ${widget.item.shareId}',
      );

      if (!mounted) return;

      // Step 4: Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.item.title} imported successfully!'),
          backgroundColor: KemeticGold.base,
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
      _logInboxImport('[InboxPage] ✗ Import failed: $e');

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
    _logInboxImport('[InboxPage] Starting import for: ${item.title}');
    return _inboxRepo.importSharedFlow(share: item);
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
    final rawName = (payload['name'] as String?) ?? item.title;
    final name = cleanFlowTitle(rawName);
    final overview = cleanFlowOverview(
      (payload['notes'] as String?) ?? (payload['overview'] as String?),
      decodedOverview: payload['overview'] as String?,
    );
    final active = (payload['active'] as bool?) ?? true;
    final colorInt = (payload['color'] as int?) ?? 0xFFD4AF37;
    final color = Color(colorInt);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(name.isEmpty ? 'Flow' : name),
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
