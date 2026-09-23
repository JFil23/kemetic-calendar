import 'package:flutter/material.dart';

import '../../data/flow_appearance.dart';
import '../../data/flow_post_model.dart';
import '../../widgets/profile_avatar.dart';
import 'flow_post_engagement_row.dart';
import 'posted_flow_artifact.dart';

const Color _bone = Color(0xFFF2ECE0);
const Color _mutedBone = Color(0xFFA69A83);
const String _serifFont = 'CormorantGaramond';
const List<String> _serifFallback = <String>['GentiumPlus', 'Georgia', 'serif'];

class SocialPostAuthorHeader extends StatelessWidget {
  const SocialPostAuthorHeader({
    super.key,
    required this.displayName,
    required this.handle,
    required this.showHandle,
    required this.avatarUrl,
    required this.avatarGlyphIds,
    required this.onTap,
    this.relationshipLabel,
    this.relationshipColor,
    this.avatarRadius = 14,
    this.nameFontSize = 16,
    this.handleFontSize = 11,
  });

  final String displayName;
  final String? handle;
  final bool showHandle;
  final String? avatarUrl;
  final List<String> avatarGlyphIds;
  final VoidCallback onTap;
  final String? relationshipLabel;
  final Color? relationshipColor;
  final double avatarRadius;
  final double nameFontSize;
  final double handleFontSize;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: <Widget>[
            ProfileAvatar(
              displayName: displayName,
              avatarUrl: avatarUrl,
              avatarGlyphIds: avatarGlyphIds,
              radius: avatarRadius,
              foregroundColor: const Color(0xFFF1CF7A),
              backgroundColor: const Color(0xFF111115),
              borderColor: const Color(0xFFE8BE54).withValues(alpha: 0.24),
              borderWidth: 1,
            ),
            SizedBox(width: avatarRadius >= 16 ? 12 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _bone,
                            fontFamily: _serifFont,
                            fontFamilyFallback: _serifFallback,
                            fontSize: nameFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (relationshipLabel?.trim().isNotEmpty ?? false) ...[
                        const SizedBox(width: 7),
                        Text(
                          relationshipLabel!.toUpperCase(),
                          maxLines: 1,
                          style: TextStyle(
                            color:
                                relationshipColor ??
                                Colors.white.withValues(alpha: 0.50),
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (showHandle && handle != null)
                    Text(
                      '@$handle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: handleFontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SocialFlowPostTile extends StatelessWidget {
  const SocialFlowPostTile({
    super.key,
    required this.post,
    required this.appearance,
    required this.accent,
    required this.relationshipLabel,
    required this.events,
    required this.postedDateLabel,
    required this.isOwner,
    required this.onOpenAuthor,
    required this.onOpenFlow,
    required this.onShare,
    required this.onSaveOrEdit,
    required this.onTogether,
  });

  final FlowPost post;
  final FlowAppearance appearance;
  final Color accent;
  final String relationshipLabel;
  final List<Map<String, dynamic>> events;
  final String postedDateLabel;
  final bool isOwner;
  final VoidCallback onOpenAuthor;
  final VoidCallback onOpenFlow;
  final VoidCallback onShare;
  final VoidCallback onSaveOrEdit;
  final VoidCallback onTogether;

  @override
  Widget build(BuildContext context) {
    final authorHandle = post.authorHandle?.trim();
    final authorDisplayName = post.authorDisplayName?.trim();
    final showHandle =
        authorHandle != null &&
        authorHandle.isNotEmpty &&
        authorDisplayName != null &&
        authorDisplayName.isNotEmpty &&
        authorHandle.toLowerCase() != authorDisplayName.toLowerCase();

    return DecoratedBox(
      key: ValueKey<String>('social-flow-post-${post.id}'),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFE8BE54).withValues(alpha: 0.12),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SocialPostAuthorHeader(
              displayName: post.authorLabel,
              handle: post.authorHandle,
              showHandle: showHandle,
              avatarUrl: post.authorAvatarUrl,
              avatarGlyphIds: post.authorAvatarGlyphIds,
              relationshipLabel: relationshipLabel,
              relationshipColor: accent.withValues(alpha: 0.72),
              onTap: onOpenAuthor,
            ),
            if (post.sharedNote != null) ...<Widget>[
              const SizedBox(height: 13),
              Text(
                post.sharedNote!,
                style: const TextStyle(
                  color: _bone,
                  fontFamily: _serifFont,
                  fontFamilyFallback: _serifFallback,
                  fontSize: 23,
                  fontWeight: FontWeight.w500,
                  height: 1.27,
                ),
              ),
            ],
            const SizedBox(height: 14),
            InkWell(
              key: ValueKey<String>('open_flow_post_${post.id}'),
              onTap: onOpenFlow,
              borderRadius: BorderRadius.circular(20),
              child: PostedFlowArtifact(
                name: post.name,
                color: post.color,
                notes: post.notes,
                startDate: post.startDate,
                endDate: post.endDate,
                events: events,
                appearance: appearance,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'Posted $postedDateLabel',
              style: TextStyle(
                color: _mutedBone.withValues(alpha: 0.62),
                fontFamily: _serifFont,
                fontFamilyFallback: _serifFallback,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
            FlowPostEngagementRow(
              key: ValueKey<String>('feed_${post.id}'),
              post: post,
              lazyComments: true,
              likedColor: accent,
              onShare: onShare,
              additionalActions: <FlowPostEngagementAction>[
                FlowPostEngagementAction(
                  key: ValueKey<String>(
                    isOwner
                        ? 'feed_edit_caption_${post.id}'
                        : 'feed_save_flow_${post.id}',
                  ),
                  icon: isOwner
                      ? Icons.edit_note_rounded
                      : Icons.bookmark_add_outlined,
                  label: isOwner ? 'Edit' : 'Save',
                  color: accent.withValues(alpha: 0.92),
                  onPressed: onSaveOrEdit,
                ),
                FlowPostEngagementAction(
                  key: ValueKey<String>('feed_together_${post.id}'),
                  icon: Icons.people_outline_rounded,
                  label: 'Together',
                  onPressed: onTogether,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
