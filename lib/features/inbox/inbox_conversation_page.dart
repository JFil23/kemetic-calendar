// lib/features/inbox/inbox_conversation_page.dart
// Conversation view showing sent/received flows as chat bubbles

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/share_models.dart';
import '../../data/share_repo.dart';
import '../../repositories/inbox_repo.dart';
import 'shared_flow_details_entry.dart';
import 'conversation_user.dart';
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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final InboxRepo _inboxRepo;
  bool _sendingMessage = false;
  int _lastItemCount = 0;

  @override
  void initState() {
    super.initState();
    _inboxRepo = InboxRepo(Supabase.instance.client);
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

  @override
  Widget build(BuildContext context) {
    final currentUserId = _inboxRepo.currentUserId;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFD4AF37)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
              backgroundImage: widget.otherProfile.avatarUrl != null
                  ? NetworkImage(widget.otherProfile.avatarUrl!)
                  : null,
              child: widget.otherProfile.avatarUrl == null
                  ? Text(
                      (widget.otherProfile.displayName ?? widget.otherProfile.handle ?? '?')
                          .characters
                          .take(2)
                          .toString()
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              widget.otherProfile.displayName ?? widget.otherProfile.handle ?? 'User',
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
            icon: const Icon(Icons.person, color: Color(0xFFD4AF37)),
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
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
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
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
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

                      return Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () async {
                            if (isText) return;
                            if (kDebugMode) {
                              debugPrint('[InboxConversationPage] tapped share '
                                  'shareId=${share.shareId} kind=${share.kind.asString} '
                                  'title=${share.title}');
                            }
                            final importedFlowId = await Navigator.push<int>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SharedFlowDetailsEntry(share: share),
                              ),
                            );

                            if (importedFlowId != null && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Flow imported successfully! Open Flow Studio to edit.'),
                                  backgroundColor: Color(0xFFD4AF37),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
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
                                            ? 'Unsend ${isText ? 'Message' : 'Flow'}'
                                            : 'Delete ${isText ? 'Message' : 'Flow'}',
                                        style: const TextStyle(color: Colors.red),
                                      ),
                                      onTap: () async {
                                        Navigator.pop(context);

                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            backgroundColor: const Color(0xFF0D0D0F),
                                            title: Text(
                                              isMine
                                                  ? 'Unsend this ${isText ? 'message' : 'flow'}?'
                                                  : 'Delete this ${isText ? 'message' : 'flow'}?',
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                            content: Text(
                                              isMine
                                                  ? 'This will remove it from the conversation for both you and the recipient. They may have already seen it.'
                                                  : 'This will hide it from your inbox and conversation. '
                                                    'It may still be visible to the sender until they delete or unsend it.',
                                              style: const TextStyle(color: Colors.white70),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.red,
                                                ),
                                                child: Text(isMine ? 'Unsend' : 'Delete'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirmed != true) return;

                                        final shareRepo = ShareRepo(Supabase.instance.client);

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
                                          ScaffoldMessenger.of(context).showSnackBar(
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

                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                isMine
                                                    ? '${isText ? 'Message' : 'Flow'} unsent'
                                                    : '${isText ? 'Message' : 'Flow'} deleted',
                                              ),
                                              duration: const Duration(seconds: 1),
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
                                )
                              : _FlowBubble(
                                  title: share.title,
                                  createdAt: share.createdAt,
                                  isMine: isMine,
                                  isImported: share.importedAt != null,
                                ),
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
                backgroundColor: const Color(0xFFD4AF37),
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
  final String title;
  final DateTime createdAt;
  final bool isMine;
  final bool isImported;

  const _FlowBubble({
    required this.title,
    required this.createdAt,
    required this.isMine,
    required this.isImported,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: isMine
            ? const Color(0xFFD4AF37).withOpacity(0.2)
            : const Color(0xFF0D0D0F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMine
              ? const Color(0xFFD4AF37).withOpacity(0.3)
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
                Icons.view_timeline,
                size: 16,
                color: isMine ? const Color(0xFFD4AF37) : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                'Flow',
                style: TextStyle(
                  color: isMine ? const Color(0xFFD4AF37) : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isImported) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            _formatTime(createdAt),
            style: TextStyle(
              color: (isMine ? Colors.white : Colors.white70).withOpacity(0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final DateTime createdAt;
  final bool isMine;

  const _MessageBubble({
    required this.text,
    required this.createdAt,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: isMine
            ? const Color(0xFFD4AF37).withOpacity(0.2)
            : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMine
              ? const Color(0xFFD4AF37).withOpacity(0.4)
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
          Text(
            _formatTime(createdAt),
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      final hours = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minutes = date.minute.toString().padLeft(2, '0');
      final suffix = date.hour >= 12 ? 'PM' : 'AM';
      return '$hours:$minutes $suffix';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
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
