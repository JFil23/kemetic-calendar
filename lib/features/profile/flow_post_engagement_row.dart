// lib/features/profile/flow_post_engagement_row.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/shared/glossy_text.dart';

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
  bool _commentSubmitting = false;
  bool _engagementUnavailable = false;
  List<FlowPostComment> _comments = const [];
  final TextEditingController _commentController = TextEditingController();
  bool _didAutoOpenComments = false;

  @override
  void initState() {
    super.initState();
    _loadEngagement();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _likeButtonEnabled ? _toggleLike : null,
              borderRadius: BorderRadius.circular(10),
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
                        : '${_likesCount.toString()} Likes',
                    style: labelStyle,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: _engagementUnavailable
                  ? _showMigrationNeeded
                  : _openCommentsSheet,
              borderRadius: BorderRadius.circular(10),
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
                        : '${_comments.length.toString()} Comments',
                    style: labelStyle,
                  ),
                ],
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
          _showError('Could not update like. Please try again.');
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
    await _loadComments();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D0F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
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
                      Expanded(
                        child: _commentsLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    KemeticGold.base,
                                  ),
                                ),
                              )
                            : _comments.isEmpty
                            ? Center(
                                child: Text(
                                  'No comments yet.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _comments.length,
                                itemBuilder: (context, index) {
                                  final c = _comments[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildAvatarForComment(c),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      c.displayName ??
                                                          c.handle ??
                                                          'User',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    _formatCommentDate(
                                                      c.createdAt,
                                                    ),
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(alpha: 0.55),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                c.body,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),
                      _buildCommentInput(modalSetState),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCommentInput(StateSetter modalSetState) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _commentController,
            maxLines: 3,
            maxLength: 150,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Add a comment (150 characters max)',
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
          onPressed: _commentSubmitting
              ? null
              : () => _submitComment(modalSetState),
          style: ElevatedButton.styleFrom(
            backgroundColor: KemeticGold.base,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
              : const Icon(Icons.send),
        ),
      ],
    );
  }

  Future<void> _submitComment(StateSetter modalSetState) async {
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
      _showError('Please enter a comment.');
      return;
    }
    if (text.length > 150) {
      _showError('Comments are limited to 150 characters.');
      return;
    }

    setState(() => _commentSubmitting = true);
    modalSetState(() {});

    FlowPostComment? created;
    try {
      created = await _repo.addFlowPostComment(widget.post.id, text);
    } on FlowPostEngagementUnavailable {
      if (!mounted) return;
      setState(() {
        _commentSubmitting = false;
        _engagementUnavailable = true;
      });
      modalSetState(() {});
      _showMigrationNeeded();
      return;
    }

    if (!mounted) return;

    setState(() {
      _commentSubmitting = false;
      if (created != null) {
        _comments = List<FlowPostComment>.from(_comments)..add(created);
        _commentController.clear();
        _repo.sendFlowPostPush(
          targetUserId: widget.post.userId,
          title: 'New comment on your flow',
          body: created.body,
          data: {
            'type': 'flow_comment',
            'flow_post_id': widget.post.id,
            'flow_name': widget.post.name,
          },
        );
      } else {
        _showError('Could not post comment. Please try again.');
      }
    });
    modalSetState(() {});
  }

  Widget _buildAvatarForComment(FlowPostComment c) {
    final label = (c.displayName ?? c.handle ?? 'U').trim();
    final initial = label.isEmpty ? 'U' : label[0].toUpperCase();
    return CircleAvatar(
      radius: 16,
      backgroundColor: const Color(0xFF1C1C1E),
      foregroundColor: KemeticGold.base,
      child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
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

  void _showAuthError() {
    _showError('Please sign in to like or comment.');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showMigrationNeeded() {
    _showError(
      'Likes and comments need the latest update. Please apply the new Supabase migration.',
    );
  }
}
