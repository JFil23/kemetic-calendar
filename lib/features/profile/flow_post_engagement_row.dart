// lib/features/profile/flow_post_engagement_row.dart

import 'package:flutter/material.dart';
import 'package:mobile/core/touch_targets.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/flow_post_comment_model.dart';
import '../../data/flow_post_model.dart';
import '../../data/profile_repo.dart';

class FlowPostEngagementRow extends StatefulWidget {
  final FlowPost post;
  final bool autoOpenComments;

  const FlowPostEngagementRow({
    super.key,
    required this.post,
    this.autoOpenComments = false,
  });

  @override
  State<FlowPostEngagementRow> createState() => _FlowPostEngagementRowState();
}

class _FlowPostEngagementRowState extends State<FlowPostEngagementRow> {
  final _repo = ProfileRepo(Supabase.instance.client);

  bool _likesLoading = true;
  bool _likeUpdating = false;
  int _likesCount = 0;
  bool _likedByMe = false;
  bool _commentsLoading = true;
  bool _engagementUnavailable = false;
  List<FlowPostComment> _comments = const [];
  bool _didAutoOpenComments = false;

  @override
  void initState() {
    super.initState();
    _loadEngagement();
  }

  Future<void> _loadEngagement() async {
    try {
      await Future.wait([_loadLikes(), _loadComments()]);
      _maybeAutoOpenComments();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _engagementUnavailable = true;
        _likesLoading = false;
        _commentsLoading = false;
      });
    }
  }

  void _maybeAutoOpenComments() {
    if (_didAutoOpenComments ||
        !widget.autoOpenComments ||
        _engagementUnavailable) {
      return;
    }
    _didAutoOpenComments = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openCommentsSheet();
    });
  }

  Future<void> _loadLikes() async {
    setState(() => _likesLoading = true);
    try {
      final result = await _repo.getFlowPostLikeState(widget.post.id);
      if (!mounted) return;
      setState(() {
        _likesCount = result.$1;
        _likedByMe = result.$2;
        _likesLoading = false;
      });
    } on FlowPostEngagementUnavailable {
      if (!mounted) return;
      setState(() {
        _engagementUnavailable = true;
        _likesLoading = false;
      });
    }
  }

  Future<void> _loadComments() async {
    setState(() => _commentsLoading = true);
    try {
      final comments = await _repo.getFlowPostComments(widget.post.id);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _commentsLoading = false;
      });
    } on FlowPostEngagementUnavailable {
      if (!mounted) return;
      setState(() {
        _engagementUnavailable = true;
        _commentsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.85),
      fontWeight: FontWeight.w600,
    );
    final actionMinHeight = useExpandedTouchTargets(context)
        ? kMinInteractiveDimension
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _likeButtonEnabled ? _toggleLike : null,
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: actionMinHeight),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _likeUpdating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                KemeticGold.base,
                              ),
                            ),
                          )
                        : (_likedByMe
                              ? const Icon(
                                  Icons.favorite,
                                  color: Colors.redAccent,
                                )
                              : KemeticGold.icon(Icons.favorite_border)),
                    const SizedBox(width: 6),
                    Text(
                      _engagementUnavailable
                          ? 'Unavailable'
                          : _likesLoading
                          ? 'Like'
                          : '$_likesCount Likes',
                      style: labelStyle,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: _engagementUnavailable
                  ? _showMigrationNeeded
                  : _openCommentsSheet,
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: actionMinHeight),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    KemeticGold.icon(Icons.chat_bubble_outline),
                    const SizedBox(width: 6),
                    Text(
                      _engagementUnavailable
                          ? 'Unavailable'
                          : _commentsLoading
                          ? 'Comments'
                          : '${_comments.length} Comments',
                      style: labelStyle,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _likeButtonEnabled =>
      !_engagementUnavailable && !_likesLoading && !_likeUpdating;

  Future<void> _toggleLike() async {
    if (_engagementUnavailable) {
      _showMigrationNeeded();
      return;
    }
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showAuthError();
      return;
    }
    if (_likeUpdating) return;

    final target = !_likedByMe;
    setState(() => _likeUpdating = true);
    try {
      final ok = await _repo.setFlowPostLike(widget.post.id, like: target);
      if (!mounted) return;
      setState(() {
        _likeUpdating = false;
        if (ok) {
          _likedByMe = target;
          _likesCount += target ? 1 : -1;
          if (_likesCount < 0) _likesCount = 0;
          if (target) {
            _repo.sendFlowPostPush(
              targetUserId: widget.post.userId,
              title: 'New like on your flow',
              body: widget.post.name,
              data: {
                'type': 'flow_like',
                'flow_post_id': widget.post.id,
                'flow_name': widget.post.name,
              },
            );
          }
        } else {
          _showErrorSnackBar(
            context,
            'Could not update like. Please try again.',
          );
        }
      });
    } on FlowPostEngagementUnavailable {
      if (!mounted) return;
      setState(() {
        _likeUpdating = false;
        _engagementUnavailable = true;
      });
      _showMigrationNeeded();
    }
  }

  Future<void> _openCommentsSheet() async {
    if (_engagementUnavailable) {
      _showMigrationNeeded();
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0D0D0F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return _FlowPostCommentsSheet(
          post: widget.post,
          repo: _repo,
          initialComments: _comments,
        );
      },
    );

    if (!mounted || _engagementUnavailable) return;
    await _loadComments();
  }

  void _showAuthError() {
    _showErrorSnackBar(context, 'Please sign in to like, reply, or comment.');
  }

  void _showMigrationNeeded() {
    _showErrorSnackBar(
      context,
      'Likes, replies, and comments need the latest update. Please apply the new Supabase migration.',
    );
  }
}

class _FlowPostCommentsSheet extends StatefulWidget {
  const _FlowPostCommentsSheet({
    required this.post,
    required this.repo,
    required this.initialComments,
  });

  final FlowPost post;
  final ProfileRepo repo;
  final List<FlowPostComment> initialComments;

  @override
  State<_FlowPostCommentsSheet> createState() => _FlowPostCommentsSheetState();
}

class _FlowPostCommentsSheetState extends State<_FlowPostCommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final Set<String> _commentLikeUpdatingIds = <String>{};
  final Set<String> _commentDeleteUpdatingIds = <String>{};

  bool _commentsLoading = true;
  bool _commentSubmitting = false;
  bool _engagementUnavailable = false;
  List<FlowPostComment> _comments = const [];
  String? _replyingToCommentId;

  @override
  void initState() {
    super.initState();
    _comments = List<FlowPostComment>.from(widget.initialComments);
    _commentsLoading = widget.initialComments.isEmpty;
    _refreshComments(showSpinner: widget.initialComments.isEmpty);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  FlowPostComment? get _replyTarget => _findCommentById(_replyingToCommentId);
  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  List<FlowPostComment> get _rootComments =>
      _comments.where((comment) => comment.parentCommentId == null).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<FlowPostComment> _childrenFor(String parentId) =>
      _comments.where((comment) => comment.parentCommentId == parentId).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  FlowPostComment? _findCommentById(String? commentId) {
    if (commentId == null) return null;
    for (final comment in _comments) {
      if (comment.id == commentId) return comment;
    }
    return null;
  }

  Future<void> _refreshComments({bool showSpinner = true}) async {
    if (showSpinner && mounted) {
      setState(() => _commentsLoading = true);
    }
    try {
      final comments = await widget.repo.getFlowPostComments(widget.post.id);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _commentsLoading = false;
      });
    } on FlowPostEngagementUnavailable {
      if (!mounted) return;
      setState(() {
        _engagementUnavailable = true;
        _commentsLoading = false;
      });
      _showMigrationNeeded();
    }
  }

  Future<void> _submitComment() async {
    if (_engagementUnavailable) {
      _showMigrationNeeded();
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showAuthError();
      return;
    }

    final text = _commentController.text.trim();
    if (text.isEmpty) {
      _showComposerError('Please enter a comment.');
      return;
    }
    if (text.length > 150) {
      _showComposerError('Comments are limited to 150 characters.');
      return;
    }

    final replyTarget = _replyTarget;

    setState(() => _commentSubmitting = true);

    FlowPostComment? created;
    try {
      created = await widget.repo.addFlowPostComment(
        widget.post.id,
        text,
        parentCommentId: replyTarget?.id,
      );
    } on FlowPostEngagementUnavailable {
      if (!mounted) return;
      setState(() {
        _commentSubmitting = false;
        _engagementUnavailable = true;
      });
      _showMigrationNeeded();
      return;
    }

    if (!mounted) return;

    if (created == null) {
      setState(() => _commentSubmitting = false);
      _showComposerError('Could not post comment. Please try again.');
      return;
    }

    setState(() {
      _commentSubmitting = false;
      _replyingToCommentId = null;
      _commentController.clear();
      _comments = List<FlowPostComment>.from(_comments)..add(created!);
    });

    await _notifyOnCommentCreated(created, replyTarget);
  }

  Future<void> _notifyOnCommentCreated(
    FlowPostComment created,
    FlowPostComment? replyTarget,
  ) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final notified = <String>{};

    Future<void> sendTo(
      String? targetUserId, {
      required String title,
      required String type,
    }) async {
      if (targetUserId == null ||
          targetUserId.isEmpty ||
          targetUserId == currentUserId ||
          !notified.add(targetUserId)) {
        return;
      }
      await widget.repo.sendFlowPostPush(
        targetUserId: targetUserId,
        title: title,
        body: created.body,
        data: {
          'type': type,
          'flow_post_id': widget.post.id,
          'flow_name': widget.post.name,
        },
      );
    }

    await sendTo(
      widget.post.userId,
      title: 'New comment on your flow',
      type: 'flow_comment',
    );

    if (replyTarget != null) {
      await sendTo(
        replyTarget.userId,
        title: 'New reply to your comment',
        type: 'flow_comment_reply',
      );
    }
  }

  Future<void> _toggleCommentLike(FlowPostComment comment) async {
    if (_engagementUnavailable) {
      _showMigrationNeeded();
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showAuthError();
      return;
    }
    if (_commentLikeUpdatingIds.contains(comment.id)) return;

    final target = !comment.likedByMe;
    setState(() => _commentLikeUpdatingIds.add(comment.id));

    try {
      final ok = await widget.repo.setFlowPostCommentLike(
        comment.id,
        like: target,
      );
      if (!mounted) return;

      setState(() {
        _commentLikeUpdatingIds.remove(comment.id);
        if (!ok) return;
        _comments = _comments
            .map(
              (entry) => entry.id != comment.id
                  ? entry
                  : entry.copyWith(
                      likedByMe: target,
                      likesCount: target
                          ? entry.likesCount + 1
                          : (entry.likesCount - 1).clamp(0, 1 << 30).toInt(),
                    ),
            )
            .toList();
      });

      if (ok && target) {
        await widget.repo.sendFlowPostPush(
          targetUserId: comment.userId,
          title: 'New like on your comment',
          body: comment.body,
          data: {
            'type': 'flow_comment_like',
            'flow_post_id': widget.post.id,
            'flow_name': widget.post.name,
          },
        );
      } else if (!ok) {
        _showComposerError('Could not update comment like. Please try again.');
      }
    } on FlowPostEngagementUnavailable {
      if (!mounted) return;
      setState(() {
        _commentLikeUpdatingIds.remove(comment.id);
        _engagementUnavailable = true;
      });
      _showMigrationNeeded();
    }
  }

  Future<void> _confirmDeleteComment(FlowPostComment comment) async {
    if (_commentDeleteUpdatingIds.contains(comment.id)) return;

    final threadIds = collectFlowPostThreadIds(_comments, comment.id);
    final replyCount = threadIds.length - 1;
    final replyLabel = replyCount == 1 ? '1 reply' : '$replyCount replies';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D0F),
        title: Text(
          replyCount > 0 ? 'Delete comment thread?' : 'Delete comment?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          replyCount > 0
              ? 'This will also remove $replyLabel in this thread. This cannot be undone.'
              : 'This comment will be removed. This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _deleteComment(comment, threadIds);
  }

  Future<void> _deleteComment(
    FlowPostComment comment,
    Set<String> threadIds,
  ) async {
    if (_engagementUnavailable) {
      _showMigrationNeeded();
      return;
    }

    final userId = _currentUserId;
    if (userId == null) {
      _showAuthError();
      return;
    }
    if (comment.userId != userId) return;

    setState(() => _commentDeleteUpdatingIds.add(comment.id));

    try {
      final ok = await widget.repo.deleteFlowPostComment(comment.id);
      if (!mounted) return;

      setState(() {
        _commentDeleteUpdatingIds.remove(comment.id);
        if (!ok) return;
        _commentLikeUpdatingIds.removeWhere(threadIds.contains);
        _commentDeleteUpdatingIds.removeWhere(threadIds.contains);
        _comments = _comments
            .where((entry) => !threadIds.contains(entry.id))
            .toList();
        if (_replyingToCommentId != null &&
            threadIds.contains(_replyingToCommentId)) {
          _replyingToCommentId = null;
        }
      });

      if (!ok) {
        _showComposerError('Could not delete comment. Please try again.');
        return;
      }

      await _refreshComments(showSpinner: false);
    } on FlowPostEngagementUnavailable {
      if (!mounted) return;
      setState(() {
        _commentDeleteUpdatingIds.remove(comment.id);
        _engagementUnavailable = true;
      });
      _showMigrationNeeded();
    }
  }

  void _beginReplyTo(FlowPostComment comment) {
    setState(() {
      _replyingToCommentId = comment.id;
    });
    _commentFocusNode.requestFocus();
  }

  void _clearReplyTarget() {
    setState(() {
      _replyingToCommentId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.8,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Comments',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${_comments.length} total',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildCommentsBody()),
              const SizedBox(height: 12),
              _buildCommentComposer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentsBody() {
    if (_commentsLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(KemeticGold.base),
        ),
      );
    }

    if (_comments.isEmpty) {
      return Center(
        child: Text(
          'No comments yet.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
      );
    }

    return ListView(
      children: [
        for (final comment in _rootComments) ...[
          _buildCommentThread(comment),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildCommentThread(FlowPostComment comment, {int depth = 0}) {
    final replies = _childrenFor(comment.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentCard(comment, depth: depth),
        for (final reply in replies)
          _buildCommentThread(reply, depth: depth + 1),
      ],
    );
  }

  Widget _buildCommentCard(FlowPostComment comment, {required int depth}) {
    final parent = _findCommentById(comment.parentCommentId);
    final updatingLike = _commentLikeUpdatingIds.contains(comment.id);
    final deleting = _commentDeleteUpdatingIds.contains(comment.id);
    final canDelete = comment.userId == _currentUserId;
    final compactActionPadding = useExpandedTouchTargets(context)
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 2, vertical: 2);
    final compactActionMinHeight = expandedTouchTargetMinDimension(context);
    final indent = depth == 0
        ? 0.0
        : (18.0 + ((depth - 1) * 14.0)).clamp(0.0, 42.0).toDouble();

    return Padding(
      padding: EdgeInsets.only(left: indent, top: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatarForComment(comment, isReply: depth > 0),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comment.displayName ?? comment.handle ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (parent != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Replying to ${parent.displayName ?? parent.handle ?? 'User'}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatCommentDate(comment.createdAt),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.body,
                  style: const TextStyle(color: Colors.white, height: 1.3),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    InkWell(
                      onTap: updatingLike || deleting
                          ? null
                          : () => _toggleCommentLike(comment),
                      borderRadius: BorderRadius.circular(999),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: compactActionMinHeight,
                        ),
                        child: Padding(
                          padding: compactActionPadding,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (updatingLike)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      KemeticGold.base,
                                    ),
                                  ),
                                )
                              else
                                Icon(
                                  comment.likedByMe
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 15,
                                  color: comment.likedByMe
                                      ? Colors.redAccent
                                      : KemeticGold.base,
                                ),
                              const SizedBox(width: 5),
                              Text(
                                comment.likesCount > 0
                                    ? '${comment.likesCount}'
                                    : 'Like',
                                style: TextStyle(
                                  color: comment.likedByMe
                                      ? Colors.redAccent
                                      : Colors.white.withValues(alpha: 0.72),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: deleting ? null : () => _beginReplyTo(comment),
                      borderRadius: BorderRadius.circular(999),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: compactActionMinHeight,
                        ),
                        child: Padding(
                          padding: compactActionPadding,
                          child: Text(
                            _replyingToCommentId == comment.id
                                ? 'Replying'
                                : 'Reply',
                            style: TextStyle(
                              color: _replyingToCommentId == comment.id
                                  ? KemeticGold.base
                                  : Colors.white.withValues(alpha: 0.72),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (canDelete)
                      InkWell(
                        onTap: deleting
                            ? null
                            : () => _confirmDeleteComment(comment),
                        borderRadius: BorderRadius.circular(999),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: compactActionMinHeight,
                          ),
                          child: Padding(
                            padding: compactActionPadding,
                            child: Text(
                              deleting ? 'Deleting…' : 'Delete',
                              style: TextStyle(
                                color: Colors.redAccent.withValues(
                                  alpha: deleting ? 0.75 : 1,
                                ),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentComposer() {
    final replyTarget = _replyTarget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (replyTarget != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Replying to ${replyTarget.displayName ?? replyTarget.handle ?? 'User'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: expandedVisualDensity(
                    context,
                    fallback: VisualDensity.compact,
                  ),
                  onPressed: _clearReplyTarget,
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                focusNode: _commentFocusNode,
                maxLines: 3,
                maxLength: 150,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: replyTarget == null
                      ? 'Add a comment (150 characters max)'
                      : 'Add a reply (150 characters max)',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  counterStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _commentSubmitting ? null : _submitComment,
              style: ElevatedButton.styleFrom(
                backgroundColor: KemeticGold.base,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 12,
                ),
                minimumSize: const Size(48, 48),
              ),
              child: _commentSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : Icon(replyTarget == null ? Icons.send : Icons.reply),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatarForComment(
    FlowPostComment comment, {
    required bool isReply,
  }) {
    final label = (comment.displayName ?? comment.handle ?? 'U').trim();
    final initial = label.isEmpty ? 'U' : label[0].toUpperCase();
    return CircleAvatar(
      radius: isReply ? 14 : 16,
      backgroundColor: const Color(0xFF1C1C1E),
      foregroundColor: KemeticGold.base,
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: isReply ? 12 : 13,
        ),
      ),
    );
  }

  void _showAuthError() {
    _showComposerError('Please sign in to like, reply, or comment.');
  }

  void _showMigrationNeeded() {
    _showComposerError(
      'Likes, replies, and comments need the latest update. Please apply the new Supabase migration.',
    );
  }

  void _showComposerError(String message) {
    _showErrorSnackBar(context, message);
  }
}

String _formatCommentDate(DateTime dt) {
  final local = dt.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final meridian = local.hour >= 12 ? 'PM' : 'AM';
  return '$month/$day ${hour.toString()}:$minute $meridian';
}

void _showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
}
