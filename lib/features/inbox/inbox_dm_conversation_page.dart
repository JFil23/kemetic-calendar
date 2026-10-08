import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/navigation_fallback.dart';
import '../../data/warm_state/warm_snapshot_store.dart';
import '../../repositories/dm_conversation_repo.dart';
import '../../shared/glossy_text.dart';
import '../../shared/candlelit_mahogany_background.dart';
import '../../widgets/keyboard_aware.dart';
import 'conversation_scroll_physics.dart';
import 'dm_conversation_models.dart';
import 'presentation/inbox_message_bubble.dart';
import 'presentation/inbox_message_actions.dart';
import 'presentation/inbox_message_action_host.dart';

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
  StreamSubscription<AuthState>? _accountSub;
  String? _accountId;
  late Future<DmConversationSummary?> _summaryFuture;
  int _lastMessageCount = 0;
  final _pendingMessages = <String, _PendingGroupMessage>{};
  List<DmConversationMessage>? _initialMessages;
  DmConversationSummary? _initialSummary;
  int _generation = 0;
  String? _lastReadMessageId;
  bool _leaving = false;
  InboxReplyTarget? _replyTo;
  final _locallyDeleted = <String>{};
  final FocusNode _composerFocus = FocusNode();

  late Stream<List<DmConversationMessage>> _messages;

  @override
  void initState() {
    super.initState();
    _repo = DmConversationRepo(Supabase.instance.client);
    _accountId = _repo.currentUserId;
    _accountSub = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      final next = state.session?.user.id;
      if (!mounted || next == _accountId) return;
      setState(() {
        _accountId = next;
        _replyTo = null;
        _messageController.clear();
        _locallyDeleted.clear();
        _bindConversation();
      });
    });
    _bindConversation();
  }

  @override
  void didUpdateWidget(covariant InboxDmConversationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _messageController.clear();
      _bindConversation();
    }
  }

  void _bindConversation() {
    _generation++;
    _pendingMessages.clear();
    _lastMessageCount = 0;
    _lastReadMessageId = null;
    _replyTo = null;
    _locallyDeleted.clear();
    _initialMessages = _repo.cachedMessages(widget.conversationId);
    _initialSummary = _repo.cachedConversationSummary(widget.conversationId);
    _messages = _repo.watchMessages(widget.conversationId);
    _summaryFuture = _repo.getConversationSummary(widget.conversationId);
  }

  @override
  void dispose() {
    _accountSub?.cancel();
    _composerFocus.dispose();
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
    if (text.isEmpty || _accountId == null) return;
    final reply = _replyTo;
    final id = 'mobile:${DateTime.now().microsecondsSinceEpoch}';
    final pending = _PendingGroupMessage(
      DmConversationMessage(
        id: id,
        clientMessageId: id,
        conversationId: widget.conversationId,
        senderId: _accountId!,
        body: text,
        kind: 'text',
        createdAt: DateTime.now(),
        payloadJson: reply == null
            ? null
            : {
                'reply_to': {'text': reply.text},
              },
      ),
      reply?.id,
    );
    setState(() {
      _pendingMessages[id] = pending;
      _replyTo = null;
    });
    _messageController.clear();
    _scrollToBottom();
    await _sendPending(pending);
  }

  Future<void> _sendPending(_PendingGroupMessage pending) async {
    if (pending.sending || pending.confirmed) return;
    final generation = _generation;
    setState(() {
      pending.sending = true;
      pending.failed = false;
    });
    try {
      final confirmed = await _repo.sendMessage(
        conversationId: pending.message.conversationId,
        text: pending.message.body,
        replyToId: pending.replyToId,
        clientMessageId: pending.message.clientMessageId,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        pending.message = confirmed;
        pending.confirmed = true;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => pending.failed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingDmConversationError(error)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() => pending.sending = false);
      }
    }
  }

  void _leaveConversation() {
    if (_leaving) return;
    _leaving = true;
    popOrGo(context, '/inbox');
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _repo.currentUserId;
    return FutureBuilder<DmConversationSummary?>(
      key: ValueKey('summary-$_generation'),
      initialData: _initialSummary,
      future: _summaryFuture,
      builder: (context, summarySnapshot) {
        final summary =
            summarySnapshot.hasError &&
                summarySnapshot.error is! WarmAccessDenied
            ? _initialSummary
            : summarySnapshot.data;
        final title = summary?.titleFor(currentUserId) ?? 'Conversation';
        final isGroup = summary?.type == DmConversationType.group;

        final page = Scaffold(
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
                      key: ValueKey('messages-$_generation'),
                      stream: _messages,
                      initialData: _initialMessages,
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

                        if (!snapshot.hasData && _pendingMessages.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                KemeticGold.base,
                              ),
                            ),
                          );
                        }

                        final received =
                            snapshot.data ?? const <DmConversationMessage>[];
                        final remoteIds = received.map((m) => m.id).toSet();
                        final remoteClientIds = received
                            .map((m) => m.clientMessageId)
                            .toSet();
                        final local = _pendingMessages.values
                            .where(
                              (p) =>
                                  !remoteIds.contains(p.message.id) &&
                                  !remoteClientIds.contains(
                                    p.message.clientMessageId,
                                  ),
                            )
                            .toList();
                        final messages =
                            [...received, ...local.map((p) => p.message)]
                                .where((m) => !_locallyDeleted.contains(m.id))
                                .toList();
                        if (messages.length != _lastMessageCount) {
                          final firstPaint = _lastMessageCount == 0;
                          final followingLatest =
                              !_scrollController.hasClients ||
                              _scrollController.position.extentAfter < 80;
                          _lastMessageCount = messages.length;
                          if (firstPaint || followingLatest) _scrollToBottom();
                        }
                        final lastReceived = received.lastOrNull;
                        if (lastReceived != null &&
                            lastReceived.id != _lastReadMessageId) {
                          _lastReadMessageId = lastReceived.id;
                          unawaited(_repo.markRead(widget.conversationId));
                        }
                        final matched = _pendingMessages.entries
                            .where(
                              (entry) =>
                                  remoteIds.contains(entry.value.message.id) ||
                                  remoteClientIds.contains(entry.key),
                            )
                            .map((entry) => entry.key)
                            .toList();
                        if (matched.isNotEmpty) {
                          final generation = _generation;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted || generation != _generation) return;
                            setState(() {
                              for (final id in matched) {
                                _pendingMessages.remove(id);
                              }
                            });
                          });
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
                          physics: const ConversationScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isMine = message.senderId == currentUserId;
                            final pending =
                                _pendingMessages[message.clientMessageId];
                            if (pending != null &&
                                !pending.confirmed &&
                                !remoteIds.contains(message.id)) {
                              return InboxMessageActions(
                                key: ValueKey(message.id),
                                createdAt: message.createdAt,
                                onCopy: () => Clipboard.setData(
                                  ClipboardData(text: message.body),
                                ),
                                onRetry: pending.failed
                                    ? () => _sendPending(pending)
                                    : null,
                                onDeleteForMe: pending.failed
                                    ? () => setState(
                                        () => _pendingMessages.remove(
                                          message.clientMessageId,
                                        ),
                                      )
                                    : null,
                                child: InboxDmMessageRow(
                                  message: message,
                                  isMine: true,
                                  showSender: false,
                                  deliveryLabel: pending.failed
                                      ? 'Not sent'
                                      : 'Sending…',
                                ),
                              );
                            }
                            return InboxMessageActionHost(
                              key: ValueKey(message.id),
                              target: InboxReplyTarget(
                                id: message.id,
                                kind: 'dm',
                                conversationId: widget.conversationId,
                                text: message.body,
                              ),
                              createdAt: message.createdAt,
                              isMine: isMine,
                              isText: true,
                              onReply: (target) {
                                setState(() => _replyTo = target);
                                _composerFocus.requestFocus();
                              },
                              onRemoved: () => setState(
                                () => _locallyDeleted.add(message.id),
                              ),
                              child: InboxDmMessageRow(
                                message: message,
                                isMine: isMine,
                                showSender: isGroup && !isMine,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                if (_replyTo != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InboxReplyPreview(
                        text: _replyTo!.text,
                        onCancel: () => setState(() => _replyTo = null),
                      ),
                    ),
                  ),
                _buildComposer(),
              ],
            ),
          ),
        );
        return KeyboardAwareEditableSurface(child: page);
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
                focusNode: _composerFocus,
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
            onPressed: _sendMessage,
            style: ElevatedButton.styleFrom(
              backgroundColor: KemeticGold.base,
              foregroundColor: Colors.black,
              minimumSize: const Size(52, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

class _PendingGroupMessage {
  _PendingGroupMessage(this.message, this.replyToId);
  DmConversationMessage message;
  final String? replyToId;
  bool sending = false;
  bool confirmed = false;
  bool failed = false;
}
