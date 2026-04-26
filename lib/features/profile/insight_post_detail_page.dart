import 'package:flutter/material.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
                      onPressed: () => Navigator.of(context).maybePop(),
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
                                widget.isOwner
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
                                    post.nodeTitle,
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
                            Text(
                              post.bodyText.trim(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                height: 1.6,
                              ),
                            ),
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

  Widget _buildDoneButton() {
    return OutlinedButton(
      onPressed: () => Navigator.of(context).maybePop(),
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
    Navigator.of(context).pop(true);
  }
}
