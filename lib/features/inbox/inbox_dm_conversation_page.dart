import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/navigation_fallback.dart';
import '../../repositories/dm_conversation_repo.dart';
import '../../shared/glossy_text.dart';
import '../../shared/candlelit_mahogany_background.dart';
import '../../widgets/keyboard_aware.dart';
import '../../widgets/profile_avatar.dart';
import 'conversation_user.dart';
import 'dm_conversation_models.dart';

class InboxDmConversationPage extends StatefulWidget {
  const InboxDmConversationPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<InboxDmConversationPage> createState() =>
      _InboxDmConversationPageState();
}

class _InboxDmConversationPageState extends State<InboxDmConversationPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final DmConversationRepo _repo;
  late Future<DmConversationSummary?> _summaryFuture;
  int _lastMessageCount = 0;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _repo = DmConversationRepo(Supabase.instance.client);
    _summaryFuture = _repo.getConversationSummary(widget.conversationId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_repo.markRead(widget.conversationId));
    });
  }

  @override
  void didUpdateWidget(covariant InboxDmConversationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _summaryFuture = _repo.getConversationSummary(widget.conversationId);
      _lastMessageCount = 0;
      unawaited(_repo.markRead(widget.conversationId));
    }
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
    if (_sending) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    _messageController.clear();
    try {
      await _repo.sendMessage(
        conversationId: widget.conversationId,
        text: text,
        clientMessageId: 'mobile:${DateTime.now().microsecondsSinceEpoch}',
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      _messageController.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingDmConversationError(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _leaveConversation() async {
    await _repo.markRead(widget.conversationId);
    if (!mounted) return;
    popOrGo(context, '/inbox');
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _repo.currentUserId;
    return FutureBuilder<DmConversationSummary?>(
      future: _summaryFuture,
      builder: (context, summarySnapshot) {
        final summary = summarySnapshot.data;
        final title = summary?.titleFor(currentUserId) ?? 'Conversation';
        final isGroup = summary?.type == DmConversationType.group;

        return Scaffold(
          backgroundColor: const Color(0xFF000000),
          appBar: AppBar(
            backgroundColor: const Color(0xFF000000),
            elevation: 0,
            leading: IconButton(
              icon: KemeticGold.icon(Icons.arrow_back),
              onPressed: _leaveConversation,
            ),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: CandlelitMahoganyBackground(
                    paintBottomScrimAboveChild: false,
                    child: StreamBuilder<List<DmConversationMessage>>(
                      stream: _repo.watchMessages(widget.conversationId),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          if (kDebugMode) {
                            debugPrint(
                              '[InboxDmConversationPage] message stream error: ${snapshot.error}',
                            );
                          }
                          return const Center(
                            child: Text(
                              'Conversation temporarily unavailable',
                              style: TextStyle(color: Colors.white70),
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

                        final messages = snapshot.data!;
                        if (messages.length != _lastMessageCount) {
                          _lastMessageCount = messages.length;
                          _scrollToBottom();
                          unawaited(_repo.markRead(widget.conversationId));
                          _summaryFuture = _repo.getConversationSummary(
                            widget.conversationId,
                          );
                        }

                        if (messages.isEmpty) {
                          return const Center(
                            child: Text(
                              'No messages yet',
                              style: TextStyle(color: Colors.white70),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isMine = message.senderId == currentUserId;
                            return _DmMessageRow(
                              message: message,
                              isMine: isMine,
                              showSender: isGroup && !isMine,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                _buildComposer(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildComposer() {
    return Container(
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: TextField(
                controller: _messageController,
                scrollPadding: keyboardManagedTextFieldScrollPadding,
                style: const TextStyle(color: Colors.white),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(
                  hintText: 'Send a message...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _sending ? null : _sendMessage,
            style: ElevatedButton.styleFrom(
              backgroundColor: KemeticGold.base,
              foregroundColor: Colors.black,
              minimumSize: const Size(52, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

class _DmMessageRow extends StatelessWidget {
  const _DmMessageRow({
    required this.message,
    required this.isMine,
    required this.showSender,
  });

  final DmConversationMessage message;
  final bool isMine;
  final bool showSender;

  @override
  Widget build(BuildContext context) {
    final sender = message.sender;
    final bubble = _DmMessageBubble(
      text: message.body,
      createdAt: message.createdAt,
      isMine: isMine,
      senderName: showSender ? _displayName(sender) : null,
    );

    if (isMine) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfileAvatar(
              radius: 15,
              displayName: _displayName(sender),
              avatarUrl: sender?.avatarUrl,
              avatarGlyphIds: sender?.avatarGlyphIds ?? const [],
              backgroundColor: KemeticGold.base.withValues(alpha: 0.2),
              foregroundColor: KemeticGold.base,
            ),
            const SizedBox(width: 8),
            bubble,
          ],
        ),
      ),
    );
  }
}

class _DmMessageBubble extends StatelessWidget {
  const _DmMessageBubble({
    required this.text,
    required this.createdAt,
    required this.isMine,
    this.senderName,
  });

  final String text;
  final DateTime createdAt;
  final bool isMine;
  final String? senderName;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.74,
      ),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMine ? KemeticGold.base : const Color(0xFF171719),
        borderRadius: BorderRadius.circular(12),
        border: isMine
            ? null
            : Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (senderName != null) ...[
            Text(
              senderName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.64),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: isMine ? Colors.black : Colors.white,
              fontSize: 15,
              height: 1.32,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              _timeLabel(createdAt),
              style: TextStyle(
                color: isMine
                    ? Colors.black.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _displayName(ConversationUser? user) {
  final displayName = user?.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;
  final handle = user?.handle?.trim();
  if (handle != null && handle.isNotEmpty) return '@$handle';
  return 'User';
}

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}
