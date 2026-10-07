// lib/features/inbox/inbox_conversation_page.dart
// Conversation view showing sent/received flows as chat bubbles

import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/navigation_fallback.dart';
import 'package:mobile/services/app_haptics.dart';
import 'package:mobile/shared/glossy_text.dart';
import '../../data/share_models.dart';
import '../../data/flow_appearance.dart';
import '../calendar/maat_flow_identity.dart';
import 'presentation/flow_message_preview.dart';
import '../../data/share_repo.dart';
import '../../repositories/inbox_repo.dart';
import '../../shared/candlelit_mahogany_background.dart';
import 'conversation_user.dart';
import 'conversation_scroll_physics.dart';
import '../../services/restoration_coordinator.dart';
import '../../services/session_resume_service.dart';
import '../../widgets/kemetic_app_bar_action.dart';
import 'presentation/inbox_message_bubble.dart';
import 'presentation/inbox_message_actions.dart';
import 'presentation/inbox_message_action_host.dart';
import '../../widgets/keyboard_aware.dart';
import '../../widgets/profile_avatar.dart';

class InboxConversationPage extends StatefulWidget {
  final String otherUserId;
  final ConversationUser otherProfile;
  final String? initialDraftText;

  const InboxConversationPage({
    required this.otherUserId,
    required this.otherProfile,
    this.initialDraftText,
    super.key,
  });

  @override
  State<InboxConversationPage> createState() => _InboxConversationPageState();
}

class _InboxConversationPageState extends State<InboxConversationPage> {
  static const String _resumeKind = 'inbox_conversation';
  final Set<String> _locallyDeleted = <String>{};
  final Set<String> _locallyViewedShareIds = <String>{};
  final Set<String> _messageLikeUpdatingIds = <String>{};
  final List<_PendingDmMessage> _pendingMessages = <_PendingDmMessage>[];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final InboxRepo _inboxRepo;
  late final ShareRepo _shareRepo;
  late Stream<List<InboxShareItem>> _conversation;
  List<InboxShareItem>? _initialItems;
  StreamSubscription<AuthState>? _accountSub;
  String? _accountId;
  int _conversationGeneration = 0;
  int _lastItemCount = 0;
  InboxReplyTarget? _replyTo;
  final FocusNode _composerFocus = FocusNode();
  Map<String, int> _messageLikeCounts = const {};
  Set<String> _messageLikedByMeIds = const <String>{};
  bool _messageLikesUnavailable = false;
  String _messageLikeSignature = '';

  String get _editorKey => 'inbox_conversation:${widget.otherUserId}';
  String get _conversationLocation =>
      '/inbox/conversation/${Uri.encodeComponent(widget.otherUserId)}';

  @override
  void initState() {
    super.initState();
    _inboxRepo = InboxRepo(Supabase.instance.client);
    _shareRepo = ShareRepo(Supabase.instance.client);
    _accountId = _inboxRepo.currentUserId;
    _bindConversation();
    _accountSub = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (!mounted) return;
      final nextAccount = state.session?.user.id;
      if (nextAccount == _accountId &&
          state.event != AuthChangeEvent.signedOut) {
        return;
      }
      setState(() {
        _accountId = nextAccount;
        _messageController.removeListener(_persistResumeState);
        _messageController.clear();
        _messageController.addListener(_persistResumeState);
        _bindConversation();
      });
    });
    _messageController.text = widget.initialDraftText ?? '';
    _messageController.addListener(_persistResumeState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _persistResumeState();
    });
  }

  void _bindConversation() {
    _conversationGeneration++;
    _initialItems = _inboxRepo.cachedConversationWith(widget.otherUserId);
    _conversation = _inboxRepo.watchConversationWith(widget.otherUserId);
    _replyTo = null;
    _pendingMessages.clear();
    _locallyDeleted.clear();
    _locallyViewedShareIds.clear();
    _messageLikeUpdatingIds.clear();
    _messageLikeCounts = const {};
    _messageLikedByMeIds = const {};
    _messageLikeSignature = '';
    _lastItemCount = 0;
  }

  @override
  void didUpdateWidget(covariant InboxConversationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.otherUserId != widget.otherUserId) {
      _messageController.text = widget.initialDraftText ?? '';
      _bindConversation();
    }
  }

  @override
  void dispose() {
    _accountSub?.cancel();
    _messageController.removeListener(_persistResumeState);
    unawaited(SessionResumeService.clearResumeEntry(kind: _resumeKind));
    _composerFocus.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _persistResumeState() {
    final draftText = _messageController.text;
    if (draftText.trim().isEmpty) {
      unawaited(RestorationCoordinator.instance.clearEditorState(_editorKey));
      unawaited(SessionResumeService.clearResumeEntry(kind: _resumeKind));
      return;
    }

    unawaited(
      RestorationCoordinator.instance.saveTextEditingValue(
        key: _editorKey,
        value: _messageController.value,
        metadata: <String, dynamic>{
          'kind': _resumeKind,
          'otherUserId': widget.otherUserId,
          'displayName': widget.otherProfile.displayName,
          'handle': widget.otherProfile.handle,
          'avatarUrl': widget.otherProfile.avatarUrl,
          'avatarGlyphIds': widget.otherProfile.avatarGlyphIds,
          'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        },
      ),
    );
    unawaited(
      SessionResumeService.saveResumeEntry(
        baseRoute: '/inbox',
        kind: _resumeKind,
        payload: {
          'otherUserId': widget.otherUserId,
          'displayName': widget.otherProfile.displayName,
          'handle': widget.otherProfile.handle,
          'avatarUrl': widget.otherProfile.avatarUrl,
          'avatarGlyphIds': widget.otherProfile.avatarGlyphIds,
          'draftText': draftText,
        },
      ),
    );
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (!animate) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final reply = _replyTo;
    final clientId = 'pending:${DateTime.now().microsecondsSinceEpoch}';
    final pending = _PendingDmMessage(
      clientId: clientId,
      text: text,
      createdAt: DateTime.now(),
      reply: reply,
    );

    setState(() {
      _pendingMessages.add(pending);
      _replyTo = null;
    });
    _messageController.clear();
    unawaited(RestorationCoordinator.instance.clearEditorState(_editorKey));
    _persistResumeState();
    _scrollToBottom();

    try {
      await _inboxRepo.sendTextMessage(
        recipientId: widget.otherUserId,
        text: text,
        replyToId: reply?.id,
        replyToKind: reply?.kind,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final index = _pendingMessages.indexWhere(
          (message) => message.clientId == clientId,
        );
        if (index >= 0) {
          _pendingMessages[index] = pending.copyWith(failed: true);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingDmSendError(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _leaveConversation() async {
    RestorationCoordinator.instance.suppressRestoreForUserNavigation(
      reason: 'dm_conversation_back',
      surfaces: const <String>[_resumeKind],
    );
    await SessionResumeService.clearResumeEntry(kind: _resumeKind);
    if (!mounted) return;
    popOrGo(context, '/inbox');
  }

  List<_PendingDmMessage> _visiblePendingMessages(List<InboxShareItem> items) {
    if (_pendingMessages.isEmpty) return const <_PendingDmMessage>[];

    final currentUserId = _inboxRepo.currentUserId;
    if (currentUserId == null) {
      return List<_PendingDmMessage>.of(_pendingMessages);
    }

    final matchedIds = <String>{};
    for (final item in items) {
      if (!item.isTextMessage || item.senderId != currentUserId) continue;
      for (final pending in _pendingMessages) {
        if (matchedIds.contains(pending.clientId)) continue;
        if (_serverMessageMatchesPending(item, pending)) {
          matchedIds.add(pending.clientId);
          break;
        }
      }
    }

    if (matchedIds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _pendingMessages.removeWhere(
            (message) => matchedIds.contains(message.clientId),
          );
        });
      });
    }

    return _pendingMessages
        .where((message) => !matchedIds.contains(message.clientId))
        .toList(growable: false);
  }

  bool _serverMessageMatchesPending(
    InboxShareItem item,
    _PendingDmMessage pending,
  ) {
    final serverText = (item.messageText ?? item.title).trim();
    if (serverText != pending.text) return false;

    final earliest = pending.createdAt.subtract(const Duration(minutes: 2));
    final latest = pending.createdAt.add(const Duration(minutes: 5));
    return !item.createdAt.isBefore(earliest) &&
        !item.createdAt.isAfter(latest);
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
    AppHapticResult? hapticResult;
    if (target) {
      hapticResult = await AppHaptics.productiveAction(
        reason: 'dm_message_like',
      );
      if (!mounted) return;
      _showDebugHapticsSnackBar(hapticResult);
    }
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
      } else if (target) {
        await _inboxRepo.sendMessageLikePush(
          targetUserId: share.senderId,
          likerUserId: userId,
          messageText: share.messageText ?? share.title,
          shareId: share.shareId,
        );
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

  void _showDebugHapticsSnackBar(AppHapticResult result) {
    if (!kDebugMode || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Haptics: ${result.debugSummary}'),
          duration: const Duration(milliseconds: 900),
        ),
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

    final page = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_leaveConversation());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        appBar: AppBar(
          backgroundColor: const Color(0xFF000000),
          elevation: 0,
          leading: IconButton(
            icon: KemeticGold.icon(Icons.arrow_back),
            onPressed: () async {
              await _leaveConversation();
            },
          ),
          title: Row(
            children: [
              ProfileAvatar(
                radius: 16,
                displayName:
                    widget.otherProfile.displayName ??
                    widget.otherProfile.handle ??
                    'User',
                avatarUrl: widget.otherProfile.avatarUrl,
                avatarGlyphIds: widget.otherProfile.avatarGlyphIds,
                backgroundColor: KemeticGold.base.withValues(alpha: 0.2),
                foregroundColor: KemeticGold.base,
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
              icon: const KemeticAppBarProfileIcon(),
              onPressed: () {
                unawaited(
                  openDetailRoute<void>(
                    context,
                    '/profile/${Uri.encodeComponent(widget.otherUserId)}',
                  ),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: CandlelitMahoganyBackground(
                  paintBottomScrimAboveChild: false,
                  child: StreamBuilder<List<InboxShareItem>>(
                    key: ValueKey(_conversationGeneration),
                    stream: _conversation,
                    initialData: _initialItems,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        if (kDebugMode) {
                          debugPrint(
                            '[InboxConversationPage] conversation stream error: ${snapshot.error}',
                          );
                        }
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
                              const Text(
                                'Conversation temporarily unavailable',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
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

                      var items = snapshot.data ?? const <InboxShareItem>[];

                      // Optional: clean up local cache for items the backend no longer sends
                      final streamIds = items.map((e) => e.shareId).toSet();
                      _locallyDeleted.removeWhere(
                        (id) => !streamIds.contains(id),
                      );

                      // Filter out locally deleted items
                      items = items
                          .where(
                            (item) => !_locallyDeleted.contains(item.shareId),
                          )
                          .toList();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        unawaited(_markIncomingUnreadViewed(items));
                        unawaited(_syncMessageLikeState(items));
                      });

                      final visiblePending = _visiblePendingMessages(items);
                      final itemCount = items.length + visiblePending.length;

                      if (itemCount != _lastItemCount) {
                        final firstPaint = _lastItemCount == 0;
                        final followingLatest =
                            !_scrollController.hasClients ||
                            _scrollController.position.extentAfter < 48;
                        _lastItemCount = itemCount;
                        if (firstPaint || followingLatest) {
                          _scrollToBottom(animate: !firstPaint);
                        }
                      }

                      if (itemCount == 0) {
                        return const Center(
                          child: Text(
                            'No messages yet',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      const listBottomPadding = 24.0;

                      return ListView.builder(
                        key: ValueKey(
                          'conversation-list-$_conversationGeneration',
                        ),
                        controller: _scrollController,
                        physics: const ConversationScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          listBottomPadding,
                        ),
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          if (index >= items.length) {
                            final pending =
                                visiblePending[index - items.length];
                            return Align(
                              key: ValueKey(pending.clientId),
                              alignment: Alignment.centerRight,
                              child: InboxMessageActions(
                                createdAt: pending.createdAt,
                                onCopy: () => Clipboard.setData(
                                  ClipboardData(text: pending.text),
                                ),
                                onDeleteForMe: pending.failed
                                    ? () => setState(
                                        () => _pendingMessages.removeWhere(
                                          (m) => m.clientId == pending.clientId,
                                        ),
                                      )
                                    : null,
                                child: InboxMessageBubble(
                                  text: pending.text,
                                  replyText: pending.reply?.text,
                                  createdAt: pending.createdAt,
                                  isMine: true,
                                  likesCount: 0,
                                  likedByMe: false,
                                  likeUpdating: false,
                                  failed: pending.failed,
                                ),
                              ),
                            );
                          }

                          final share = items[index];
                          final isMine = share.senderId == currentUserId;
                          final isText = share.isTextMessage;

                          return Align(
                            key: ValueKey(share.shareId),
                            alignment: isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: InboxMessageActionHost(
                              target: InboxReplyTarget(
                                id: share.shareId,
                                kind: share.isEvent ? 'event' : 'flow',
                                text: share.messageText ?? share.title,
                              ),
                              createdAt: share.createdAt,
                              isMine: isMine,
                              isText: isText,
                              onReply: (target) {
                                setState(() => _replyTo = target);
                                _composerFocus.requestFocus();
                              },
                              onRemoved: () => setState(
                                () => _locallyDeleted.add(share.shareId),
                              ),
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
                                          unawaited(
                                            openDetailRoute<void>(
                                              context,
                                              '/event-invite/${Uri.encodeComponent(share.shareId)}',
                                              extra: share,
                                            ),
                                          );
                                          return;
                                        }
                                        unawaited(
                                          openDetailRoute<void>(
                                            context,
                                            '/shared-flow/${Uri.encodeComponent(share.shareId)}',
                                            extra: <String, Object?>{
                                              'share': share,
                                              'fallbackLocation':
                                                  _conversationLocation,
                                            },
                                          ),
                                        );
                                      },
                                onDoubleTap: isText
                                    ? () => _toggleMessageLike(share)
                                    : null,
                                child: isText
                                    ? InboxMessageBubble(
                                        text: share.messageText ?? share.title,
                                        replyText:
                                            (share.payloadJson?['reply_to']
                                                    as Map?)?['text']
                                                as String?,
                                        createdAt: share.createdAt,
                                        isMine: isMine,
                                        likesCount:
                                            _messageLikeCounts[share.shareId] ??
                                            0,
                                        likedByMe: _messageLikedByMeIds
                                            .contains(share.shareId),
                                        likeUpdating: _messageLikeUpdatingIds
                                            .contains(share.shareId),
                                      )
                                    : _FlowBubble(share: share, isMine: isMine),
                              ),
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
      ),
    );
    return KeyboardAwareEditableSurface(child: page);
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

class _PendingDmMessage {
  final String clientId;
  final String text;
  final DateTime createdAt;
  final bool failed;
  final InboxReplyTarget? reply;

  const _PendingDmMessage({
    required this.clientId,
    required this.text,
    required this.createdAt,
    this.failed = false,
    this.reply,
  });

  _PendingDmMessage copyWith({bool? failed}) {
    return _PendingDmMessage(
      clientId: clientId,
      text: text,
      createdAt: createdAt,
      failed: failed ?? this.failed,
      reply: reply,
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
    if (share.isFlow) {
      final payload = share.payloadJson;
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            FlowMessagePreview(
              title: payload?['name'] as String? ?? share.title,
              appearance: FlowAppearance.fromJson(payload?['appearance']),
              maatFlowKind: resolveMaatFlowKind(
                flowName: payload?['name'] as String? ?? share.title,
                flowNotes: payload?['notes'] as String?,
              ),
              color:
                  (payload?['color'] as num?)?.toInt() ??
                  KemeticGold.base.toARGB32(),
            ),
            const SizedBox(height: 5),
            Text(
              '${_formatTime(share.createdAt)}${!isMine && share.isCurrentlyImported ? ' · Added' : ''}',
              textAlign: isMine ? TextAlign.right : TextAlign.left,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      );
    }
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
            ? KemeticGold.base.withValues(alpha: 0.2)
            : const Color(0xFF0D0D0F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMine
              ? KemeticGold.base.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
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
                    color: Colors.green.withValues(alpha: 0.2),
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
                    color: statusColor.withValues(alpha: 0.18),
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
              color: (isMine ? Colors.white : Colors.white70).withValues(
                alpha: 0.6,
              ),
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
