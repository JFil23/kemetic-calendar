import 'package:flutter/material.dart';

import '../../core/theme/app_fonts.dart';
import '../../data/insight_post_model.dart';
import '../nodes/widgets.dart';
import 'posted_artifact_frame.dart';
import 'profile_post_frame.dart';

const _insightAccent = Color(0xFFD4AE43);

/// An insight uses the same profile composition as a flow. The Library excerpt
/// belongs above the card; the author's own reflection stays inside it.
class ProfileInsightPostTile extends StatelessWidget {
  const ProfileInsightPostTile({
    super.key,
    required this.post,
    required this.nodeExcerpt,
    required this.authorDisplayName,
    required this.authorHandle,
    required this.authorAvatarUrl,
    required this.authorAvatarGlyphIds,
    required this.relationshipLabel,
    required this.postedDateLabel,
    required this.entryDateLabel,
    required this.onOpenAuthor,
    required this.onReadMore,
    this.onRemove,
    this.nodeGlyph,
  });

  final InsightPost post;
  final String nodeExcerpt;
  final String? nodeGlyph;
  final String authorDisplayName;
  final String? authorHandle;
  final String? authorAvatarUrl;
  final List<String> authorAvatarGlyphIds;
  final String relationshipLabel;
  final String postedDateLabel;
  final String entryDateLabel;
  final VoidCallback onOpenAuthor;
  final VoidCallback onReadMore;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final glyph = nodeGlyph?.trim().isNotEmpty == true
        ? nodeGlyph!.trim()
        : post.nodeGlyph?.trim();
    final reflection = post.bodyText.replaceAll(RegExp(r'\s+'), ' ').trim();
    return SizedBox(
      key: ValueKey<String>('profile-insight-post-${post.id}'),
      height: profilePostHeight(context),
      child: ProfilePostFrame(
        metadata: ProfilePostMetadata(
          relationshipLabel: relationshipLabel,
          postedDateLabel: postedDateLabel,
          accent: _insightAccent,
          authorDisplayName: authorDisplayName,
          authorHandle: authorHandle,
          authorAvatarUrl: authorAvatarUrl,
          authorAvatarGlyphIds: authorAvatarGlyphIds,
          onOpenAuthor: onOpenAuthor,
        ),
        excerpt: nodeExcerpt,
        excerptKey: const ValueKey<String>('profile-insight-node-excerpt'),
        artifact: InkWell(
          key: ValueKey<String>('open-profile-insight-post-${post.id}'),
          onTap: onReadMore,
          borderRadius: BorderRadius.circular(16),
          child: PostedArtifactFrame(
            artifactKey: const ValueKey<String>('posted-insight-artifact'),
            semanticLabel: '${post.nodeTitle}, insight',
            accent: _insightAccent,
            badgeLabel: 'Library',
            readoutLabel: 'DATED ${entryDateLabel.toUpperCase()}',
            typeLabel: 'INSIGHT',
            title: post.nodeTitle,
            overview: reflection.isEmpty ? 'Untitled insight' : reflection,
            hero: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.45),
                  radius: 0.8,
                  colors: [
                    _insightAccent.withValues(alpha: 0.18),
                    const Color(0xFF0D0B08),
                  ],
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: glyph?.isNotEmpty == true
                      ? MediaQuery.withNoTextScaling(
                          child: NodeGlyphMark(
                            glyph: glyph!,
                            width: 116,
                            height: 116,
                            fontSize: 96,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE8CB7D), Color(0xFF98712D)],
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.menu_book_outlined,
                          size: 72,
                          color: Color(0xFFB89A55),
                        ),
                ),
              ),
            ),
          ),
        ),
        actions: Row(
          children: [
            if (onRemove != null)
              TextButton.icon(
                onPressed: onRemove,
                style: _actionStyle(Colors.redAccent.withValues(alpha: 0.85)),
                icon: const Icon(Icons.remove_circle_outline, size: 16),
                label: const Text('Remove'),
              ),
            const Spacer(),
            TextButton(
              onPressed: onReadMore,
              style: _actionStyle(const Color(0xFF9E9A94)),
              child: const Text('Read more'),
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle _actionStyle(Color color) => TextButton.styleFrom(
    foregroundColor: color,
    padding: const EdgeInsets.symmetric(vertical: 6),
    minimumSize: const Size(0, 32),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: const TextStyle(
      fontFamily: AppFonts.ui,
      fontSize: 11,
      fontWeight: FontWeight.w400,
    ),
  );
}
