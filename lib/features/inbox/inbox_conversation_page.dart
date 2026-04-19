// lib/features/inbox/inbox_conversation_page.dart
// Conversation view showing sent/received flows as chat bubbles

import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/shared/glossy_text.dart';
import '../../data/share_models.dart';
import '../../data/share_repo.dart';
import '../../repositories/inbox_repo.dart';
import 'shared_flow_details_entry.dart';
import 'conversation_user.dart';
import '../invites/event_invite_details_page.dart';
import '../profile/profile_page.dart';

class InboxConversationPage extends StatefulWidget {
  final String otherUserId;
  final ConversationUser otherProfile;

  const InboxConversationPage({
    required this.otherUserId,
    required this.otherProfile,
    super.key,
  });

  @override
  State<InboxConversationPage> createState() => _InboxConversationPageState();
}

class _InboxConversationPageState extends State<InboxConversationPage> {
  final Set<String> _locallyDeleted = <String>{};
  final Set<String> _locallyViewedShareIds = <String>{};
  final Set<String> _messageLikeUpdatingIds = <String>{};
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final InboxRepo _inboxRepo;
  late final ShareRepo _shareRepo;
  bool _sendingMessage = false;
  int _lastItemCount = 0;
  Map<String, int> _messageLikeCounts = const {};
  Set<String> _messageLikedByMeIds = const <String>{};
  bool _messageLikesUnavailable = false;
  String _messageLikeSignature = '';

  @override
  void initState() {
    super.initState();
    _inboxRepo = InboxRepo(Supabase.instance.client);
    _shareRepo = ShareRepo(Supabase.instance.client);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sendingMessage) return;

    setState(() => _sendingMessage = true);
    try {
      await _inboxRepo.sendTextMessage(
        recipientId: widget.otherUserId,
        text: text,
      );
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingMessage = false);
      }
    }
  }

  Future<void> _markIncomingUnreadViewed(List<InboxShareItem> items) async {
    final currentUserId = _inboxRepo.currentUserId;
    if (currentUserId == null) return;

    final unreadItems = items.where((item) {
      final isIncoming = item.recipientId == currentUserId;
      return isIncoming &&
          item.viewedAt == null &&
          !_locallyViewedShareIds.contains(item.shareId);
    }).toList();
    if (unreadItems.isEmpty) return;

    final shareIds = unreadItems.map((item) => item.shareId).toSet();
    _locallyViewedShareIds.addAll(shareIds);

    final results = await Future.wait(
      unreadItems.map(
        (item) => _shareRepo.markViewed(item.shareId, isFlow: item.isFlow),
      ),
    );

    final failedIds = <String>{};
    for (var i = 0; i < unreadItems.length; i++) {
      if (!results[i]) {
        failedIds.add(unreadItems[i].shareId);
      }
    }

    if (failedIds.isEmpty || !mounted) return;
    setState(() {
      _locallyViewedShareIds.removeAll(failedIds);
    });
  }

  Future<void> _syncMessageLikeState(List<InboxShareItem> items) async {
    final shareIds =
        items
            .where((item) => item.isTextMessage)
            .map((item) => item.shareId)
            .toSet()
            .toList()
          ..sort();
    final signature = shareIds.join('|');
    if (signature == _messageLikeSignature) return;
    _messageLikeSignature = signature;

    if (shareIds.isEmpty) {
      if (!mounted) return;
      setState(() {
        _messageLikeCounts = const {};
        _messageLikedByMeIds = const <String>{};
        _messageLikesUnavailable = false;
      });
      return;
    }

    try {
      final states = await _inboxRepo.getMessageLikeStates(shareIds);
      if (!mounted || _messageLikeSignature != signature) return;

      final counts = <String, int>{};
      final likedByMe = <String>{};
      for (final shareId in shareIds) {
        final state = states[shareId];
        counts[shareId] = state?.count ?? 0;
        if (state?.likedByMe == true) {
          likedByMe.add(shareId);
        }
      }

      setState(() {
        _messageLikeCounts = counts;
        _messageLikedByMeIds = likedByMe;
        _messageLikesUnavailable = false;
      });
    } on InboxMessageLikesUnavailable {
      if (!mounted || _messageLikeSignature != signature) return;
      setState(() {
        _messageLikeCounts = const {};
        _messageLikedByMeIds = const <String>{};
        _messageLikesUnavailable = true;
      });
    }
  }

  Future<void> _toggleMessageLike(InboxShareItem share) async {
    if (!share.isTextMessage) return;
    if (_messageLikesUnavailable) {
      _showMessageLikeUnavailable();
      return;
    }
    final userId = _inboxRepo.currentUserId;
    if (userId == null) {
      _showError('Please sign in to like messages.');
      return;
    }
    if (_messageLikeUpdatingIds.contains(share.shareId)) return;

    final target = !_messageLikedByMeIds.contains(share.shareId);
    setState(() => _messageLikeUpdatingIds.add(share.shareId));

    try {
      final ok = await _inboxRepo.setMessageLike(share.shareId, like: target);
      if (!mounted) return;

      setState(() {
        _messageLikeUpdatingIds.remove(share.shareId);
        if (!ok) return;

        final nextCounts = Map<String, int>.from(_messageLikeCounts);
        final currentCount = nextCounts[share.shareId] ?? 0;
        nextCounts[share.shareId] = target
            ? currentCount + 1
            : (currentCount - 1).clamp(0, 1 << 30).toInt();
        _messageLikeCounts = nextCounts;

        final nextLiked = Set<String>.from(_messageLikedByMeIds);
        if (target) {
          nextLiked.add(share.shareId);
        } else {
          nextLiked.remove(share.shareId);
        }
        _messageLikedByMeIds = nextLiked;
      });

      if (!ok) {
        _showError('Could not update message like. Please try again.');
      }
    } on InboxMessageLikesUnavailable {
      if (!mounted) return;
      setState(() {
        _messageLikeUpdatingIds.remove(share.shareId);
        _messageLikesUnavailable = true;
      });
      _showMessageLikeUnavailable();
    }
  }

  void _showMessageLikeUnavailable() {
    _showError(
      'Message likes need the latest update. Please apply the new Supabase migration.',
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _inboxRepo.currentUserId;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: KemeticGold.icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: KemeticGold.base.withOpacity(0.2),
              backgroundImage: widget.otherProfile.avatarUrl != null
                  ? NetworkImage(widget.otherProfile.avatarUrl!)
                  : null,
              child: widget.otherProfile.avatarUrl == null
                  ? Text(
                      (widget.otherProfile.displayName ??
                              widget.otherProfile.handle ??
                              '?')
                          .characters
                          .take(2)
                          .toString()
                          .toUpperCase(),
                      style: const TextStyle(
                        color: KemeticGold.base,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              widget.otherProfile.displayName ??
                  widget.otherProfile.handle ??
                  'User',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'View profile',
            icon: KemeticGold.icon(Icons.person),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfilePage(userId: widget.otherUserId),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<InboxShareItem>>(
                stream: _inboxRepo.watchConversationWith(widget.otherUserId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          KemeticGold.base,
                        ),
                      ),
                    );
                  }

                  var items = snapshot.data ?? const <InboxShareItem>[];

                  // Optional: clean up local cache for items the backend no longer sends
                  final streamIds = items.map((e) => e.shareId).toSet();
                  _locallyDeleted.removeWhere((id) => !streamIds.contains(id));

                  // Filter out locally deleted items
                  items = items
                      .where((item) => !_locallyDeleted.contains(item.shareId))
                      .toList();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    unawaited(_markIncomingUnreadViewed(items));
                    unawaited(_syncMessageLikeState(items));
                  });

                  if (items.length != _lastItemCount) {
                    _lastItemCount = items.length;
                    _scrollToBottom();
                  }

                  if (items.isEmpty) {
                    return const Center(
                      child: Text(
                        'No messages yet',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final share = items[index];
                      final isMine = share.senderId == currentUserId;
                      final isText = share.isTextMessage;
                      final itemLabel = isText
                          ? 'Message'
                          : (share.isEvent ? 'Invite' : 'Flow');

                      return Align(
                        alignment: isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: isText
                              ? null
                              : () async {
                                  if (kDebugMode) {
                                    debugPrint(
                                      '[InboxConversationPage] tapped share '
                                      'shareId=${share.shareId} kind=${share.kind.asString} '
                                      'title=${share.title}',
                                    );
                                  }
                                  if (share.isEvent) {
                                    await Navigator.push<void>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EventInviteDetailsPage(
                                          share: share,
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  final importedFlowId =
                                      await Navigator.push<int>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              SharedFlowDetailsEntry(
                                                share: share,
                                              ),
                                        ),
                                      );

                                  if (importedFlowId != null && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Flow imported successfully! Open Flow Studio to edit.',
                                        ),
                                        backgroundColor: KemeticGold.base,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                          onDoubleTap: isText
                              ? () => _toggleMessageLike(share)
                              : null,
                          onLongPress: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: const Color(0xFF0D0D0F),
                              builder: (context) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: Icon(
                                        isMine ? Icons.undo : Icons.delete,
                                        color: Colors.red,
                                      ),
                                      title: Text(
                                        isMine
                                            ? 'Unsend $itemLabel'
                                            : 'Delete $itemLabel',
                                        style: const TextStyle(
                                          color: Colors.red,
                                        ),
                                      ),
                                      onTap: () async {
                                        Navigator.pop(context);

                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            backgroundColor: const Color(
                                              0xFF0D0D0F,
                                            ),
                                            title: Text(
                                              isMine
                                                  ? 'Unsend this ${itemLabel.toLowerCase()}?'
                                                  : 'Delete this ${itemLabel.toLowerCase()}?',
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            content: Text(
                                              isMine
                                                  ? 'This will remove it from the conversation for both you and the recipient. They may have already seen it.'
                                                  : 'This will hide it from your inbox and conversation. '
                                                        'It may still be visible to the sender until they delete or unsend it.',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.red,
                                                ),
                                                child: Text(
                                                  isMine ? 'Unsend' : 'Delete',
                                                ),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirmed != true) return;

                                        final shareRepo = ShareRepo(
                                          Supabase.instance.client,
                                        );

                                        final bool ok = isMine
                                            ? await shareRepo.unsendShare(
                                                share.shareId,
                                                isFlow: share.isFlow,
                                              )
                                            : await shareRepo.deleteInboxItem(
                                                share.shareId,
                                                isFlow: share.isFlow,
                                              );

                                        if (!ok && context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                isMine
                                                    ? 'Could not unsend this item. Please try again.'
                                                    : 'Could not delete this item. Please try again.',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        } else if (ok && mounted) {
                                          setState(() {
                                            _locallyDeleted.add(share.shareId);
                                          });

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                isMine
                                                    ? '$itemLabel unsent'
                                                    : '$itemLabel deleted',
                                              ),
                                              duration: const Duration(
                                                seconds: 1,
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: isText
                              ? _MessageBubble(
                                  text: share.messageText ?? share.title,
                                  createdAt: share.createdAt,
                                  isMine: isMine,
                                  likesCount:
                                      _messageLikeCounts[share.shareId] ?? 0,
                                  likedByMe: _messageLikedByMeIds.contains(
                                    share.shareId,
                                  ),
                                  likeUpdating: _messageLikeUpdatingIds
                                      .contains(share.shareId),
                                )
                              : _FlowBubble(share: share, isMine: isMine),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        color: const Color(0xFF000000),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(
                    hintText: 'Send a message…',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _sendingMessage ? null : _sendMessage,
              style: ElevatedButton.styleFrom(
                backgroundColor: KemeticGold.base,
                foregroundColor: Colors.black,
                minimumSize: const Size(52, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: _sendingMessage
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowBubble extends StatelessWidget {
  final InboxShareItem share;
  final bool isMine;

  const _FlowBubble({required this.share, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final isEvent = share.isEvent;
    final payload = share.eventPayload;
    final title = payload?.title ?? share.title;
    final label = isEvent ? 'Invite' : 'Flow';
    final icon = isEvent ? Icons.event_available_outlined : Icons.view_timeline;
    final statusLabel = _statusLabel(share);
    final statusColor = _statusColor(share);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: isMine
            ? KemeticGold.base.withOpacity(0.2)
            : const Color(0xFF0D0D0F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMine
              ? KemeticGold.base.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isMine ? KemeticGold.base : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isMine ? KemeticGold.base : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!isEvent && share.importedAt != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Imported',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (isEvent && statusLabel != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              color: isMine ? Colors.white : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            _detailLine(payload),
            style: TextStyle(
              color: (isMine ? Colors.white : Colors.white70).withOpacity(0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _detailLine(EventSharePayload? payload) {
    if (share.isEvent) {
      final startsAt = payload?.startsAt ?? share.eventDate;
      if (startsAt == null) return _formatTime(share.createdAt);
      return _formatEventTime(startsAt, payload?.allDay ?? false);
    }
    return _formatTime(share.createdAt);
  }

  String _formatEventTime(DateTime date, bool allDay) {
    final localDate = date.toLocal();
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    if (allDay) {
      return '$month/$day • All day';
    }
    final minute = localDate.minute.toString().padLeft(2, '0');
    final hour24 = localDate.hour;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    return '$month/$day • $hour12:$minute $period';
  }

  String _formatTime(DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localDate);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${localDate.month}/${localDate.day}/${localDate.year}';
    }
  }

  String? _statusLabel(InboxShareItem share) {
    switch (share.responseStatus) {
      case EventInviteResponseStatus.accepted:
        return 'Yes';
      case EventInviteResponseStatus.declined:
        return 'No';
      case EventInviteResponseStatus.maybe:
        return 'Maybe';
      case EventInviteResponseStatus.noResponse:
        if (share.viewedAt != null) return 'Opened';
        return isMine ? 'Pending' : null;
    }
  }

  Color _statusColor(InboxShareItem share) {
    switch (share.responseStatus) {
      case EventInviteResponseStatus.accepted:
        return Colors.greenAccent;
      case EventInviteResponseStatus.declined:
        return Colors.redAccent;
      case EventInviteResponseStatus.maybe:
        return Colors.orangeAccent;
      case EventInviteResponseStatus.noResponse:
        return Colors.white70;
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final DateTime createdAt;
  final bool isMine;
  final int likesCount;
  final bool likedByMe;
  final bool likeUpdating;

  const _MessageBubble({
    required this.text,
    required this.createdAt,
    required this.isMine,
    required this.likesCount,
    required this.likedByMe,
    required this.likeUpdating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: isMine
            ? KemeticGold.base.withOpacity(0.2)
            : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMine
              ? KemeticGold.base.withOpacity(0.4)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(createdAt),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 11,
                ),
              ),
              if (likeUpdating) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
                  ),
                ),
              ] else if (likesCount > 0) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.favorite,
                  size: 12,
                  color: likedByMe
                      ? Colors.redAccent
                      : Colors.redAccent.withOpacity(0.75),
                ),
                if (likesCount > 1) ...[
                  const SizedBox(width: 3),
                  Text(
                    '$likesCount',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localDate);

    if (diff.inDays == 0) {
      final hours = localDate.hour % 12 == 0 ? 12 : localDate.hour % 12;
      final minutes = localDate.minute.toString().padLeft(2, '0');
      final suffix = localDate.hour >= 12 ? 'PM' : 'AM';
      return '$hours:$minutes $suffix';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${localDate.month}/${localDate.day}/${localDate.year}';
    }
  }
}

class _ConversationUser {
  final String id;
  final String? displayName;
  final String? handle;
  final String? avatarUrl;

  _ConversationUser({
    required this.id,
    this.displayName,
    this.handle,
    this.avatarUrl,
  });
}
