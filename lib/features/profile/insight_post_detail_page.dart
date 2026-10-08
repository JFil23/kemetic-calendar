import '../nodes/kemetic_node_library.dart';
import '../../data/account_operation_fence.dart';
import 'package:flutter/material.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/navigation_fallback.dart';
import '../../data/insight_post_model.dart';
import '../../data/profile_repo.dart';
import '../../utils/kemetic_date_format.dart';
import '../../widgets/profile_avatar.dart';

class InsightPostDetailPage extends StatefulWidget {
  final InsightPost post;
  final bool isOwner;

  const InsightPostDetailPage({
    super.key,
    required this.post,
    required this.isOwner,
  });

  @override
  State<InsightPostDetailPage> createState() => _InsightPostDetailPageState();
}

class _InsightPostDetailPageState extends State<InsightPostDetailPage> {
  final _repo = ProfileRepo(Supabase.instance.client);

  bool _removing = false;
  bool _safetyBusy = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF101114),
                    Colors.black,
                    Colors.black.withValues(alpha: 0.96),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => popOrGo(
                        context,
                        '/profile/${Uri.encodeComponent(post.userId)}',
                      ),
                      icon: const Icon(Icons.close, color: KemeticGold.base),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: KemeticGold.base.withValues(alpha: 0.28),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.44),
                              blurRadius: 24,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: KemeticGold.base.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: KemeticGold.base.withValues(
                                    alpha: 0.22,
                                  ),
                                ),
                              ),
                              child: Text(
                                post.isDecanReflection
                                    ? (widget.isOwner
                                          ? 'Your Reflection'
                                          : 'Posted Reflection')
                                    : widget.isOwner
                                    ? 'Your Insight'
                                    : 'Posted Insight',
                                style: const TextStyle(
                                  color: KemeticGold.base,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                ProfileAvatar(
                                  displayName: post.authorLabel,
                                  avatarUrl: post.authorAvatarUrl,
                                  avatarGlyphIds: post.authorAvatarGlyphIds,
                                  radius: 18,
                                  foregroundColor: KemeticGold.base,
                                  backgroundColor: const Color(0xFF111115),
                                  borderColor: KemeticGold.base.withValues(
                                    alpha: 0.24,
                                  ),
                                  borderWidth: 1,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        post.authorLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if ((post.authorHandle
                                                  ?.trim()
                                                  .isNotEmpty ??
                                              false) &&
                                          post.authorHandle !=
                                              post.authorDisplayName)
                                        Text(
                                          '@${post.authorHandle}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.56,
                                            ),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((post.nodeGlyph?.trim().isNotEmpty ??
                                    false))
                                  Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: Text(
                                      post.nodeGlyph!,
                                      style: const TextStyle(
                                        color: KemeticGold.base,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: KemeticGold.text(
                                    post.isDecanReflection
                                        ? 'Decan reflection'
                                        : post.nodeTitle,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      height: 1.06,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Dated ${formatKemeticDate(post.entryDate)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.66),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Posted ${formatKemeticDate(post.createdAt)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.54),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (post.isDecanReflection &&
                                (post.questionText?.isNotEmpty ?? false)) ...[
                              Text(
                                post.questionText!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Text(
                              post.bodyText.trim(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                height: 1.6,
                              ),
                            ),
                            if (post.isDecanReflection)
                              _reflectionActions(post),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: widget.isOwner
                        ? _buildRemoveButton()
                        : _buildDoneButton(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reflectionActions(InsightPost post) {
    final slug = post.readingLink?['slug'] as String?;
    final reading = slug == null ? null : KemeticNodeLibrary.resolve(slug);
    return TextButtonTheme(
      data: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: KemeticGold.base),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reading != null)
              TextButton(
                onPressed: () => openDetailRoute<void>(
                  context,
                  '/nodes/${Uri.encodeComponent(reading.id)}',
                ),
                child: Text('Read ${reading.title}'),
              ),
            TextButton(
              onPressed: () => openDetailRoute<void>(
                context,
                '/profile/${Uri.encodeComponent(post.userId)}',
              ),
              child: Text('View ${post.authorLabel}'),
            ),
            if (widget.isOwner) ...[
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: post.sourceReflectionId == null
                        ? null
                        : () => openDetailRoute<void>(
                            context,
                            '/reflections/${post.sourceReflectionId}?compose=1',
                          ),
                    child: const Text('Edit post'),
                  ),
                  TextButton(
                    onPressed: post.sourceReflectionId == null
                        ? null
                        : () => openDetailRoute<void>(
                            context,
                            '/reflections/${post.sourceReflectionId}',
                          ),
                    child: const Text('Open your reflection'),
                  ),
                ],
              ),
              const Text(
                'Your Journal and this post keep separate copies.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ] else
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: _safetyBusy ? null : _report,
                    child: const Text('Report post'),
                  ),
                  TextButton(
                    onPressed: _safetyBusy ? null : _block,
                    child: const Text('Block author'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _report() async {
    setState(() => _safetyBusy = true);
    final fence = AccountOperationFence(Supabase.instance.client);
    try {
      final ok = await _repo.reportContent(
        contentType: 'insight_post',
        contentId: widget.post.id,
        reportedUserId: widget.post.userId,
        reason: 'user_report',
      );
      if (mounted && fence.isCurrent)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok ? 'Report sent.' : 'Could not send the report. Try again.',
            ),
          ),
        );
    } finally {
      fence.dispose();
      if (mounted) setState(() => _safetyBusy = false);
    }
  }

  Future<void> _block() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block author?'),
        content: const Text(
          'Their posts and comments will be hidden from your refreshed feeds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block author'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _safetyBusy = true);
    final fence = AccountOperationFence(Supabase.instance.client);
    try {
      final ok = await _repo.blockUser(widget.post.userId);
      if (!mounted || !fence.isCurrent) return;
      if (ok)
        popOrGo(context, '/profile/me');
      else
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not block this author. Try again.'),
          ),
        );
    } finally {
      fence.dispose();
      if (mounted) setState(() => _safetyBusy = false);
    }
  }

  Widget _buildDoneButton() {
    return OutlinedButton(
      onPressed: () => popOrGo(
        context,
        '/profile/${Uri.encodeComponent(widget.post.userId)}',
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: const Text('Done'),
    );
  }

  Widget _buildRemoveButton() {
    return ElevatedButton(
      onPressed: _removing ? null : _remove,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
        foregroundColor: Colors.redAccent,
        side: const BorderSide(color: Colors.redAccent),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: _removing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
              ),
            )
          : const Text('Remove from profile'),
    );
  }

  Future<void> _remove() async {
    setState(() => _removing = true);
    final ok = await _repo.deleteInsightPost(widget.post.id);
    if (!mounted) return;
    setState(() => _removing = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to remove this insight.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    popOrGo(
      context,
      '/profile/${Uri.encodeComponent(widget.post.userId)}',
      result: true,
    );
  }
}
