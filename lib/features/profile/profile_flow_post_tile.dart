import 'package:flutter/material.dart';

import '../../data/flow_appearance.dart';
import '../../data/flow_post_model.dart';
import '../../utils/detail_sanitizer.dart';
import 'profile_post_frame.dart';
import 'flow_post_engagement_row.dart';
import 'haw_profile_icon.dart';
import 'posted_flow_artifact.dart';

const Color _profilePostBone = Color(0xFFF2ECE0);

/// The profile-specific presentation of a posted flow.
///
/// The portable flow artifact remains the only flow visual authority. This
/// widget adds only profile metadata, the optional caption, engagement, and
/// the profile action boundary around it.
class ProfileFlowPostTile extends StatelessWidget {
  const ProfileFlowPostTile({
    super.key,
    required this.post,
    required this.appearance,
    required this.accent,
    required this.relationshipLabel,
    required this.authorDisplayName,
    required this.authorHandle,
    required this.authorAvatarUrl,
    required this.authorAvatarGlyphIds,
    required this.events,
    required this.postedDateLabel,
    required this.isOwner,
    required this.onOpenAuthor,
    required this.onOpenFlow,
    required this.onOpenMenu,
    required this.onShare,
    this.onSave,
    this.onTogether,
    this.togetherLabel = 'Together',
    this.isSaved = false,
  });

  final FlowPost post;
  final FlowAppearance appearance;
  final Color accent;
  final String relationshipLabel;
  final String authorDisplayName;
  final String? authorHandle;
  final String? authorAvatarUrl;
  final List<String> authorAvatarGlyphIds;
  final List<dynamic> events;
  final String postedDateLabel;
  final bool isOwner;
  final VoidCallback onOpenAuthor;
  final VoidCallback onOpenFlow;
  final ValueChanged<Rect> onOpenMenu;
  final VoidCallback onShare;
  final VoidCallback? onSave;
  final VoidCallback? onTogether;
  final String togetherLabel;
  final bool isSaved;

  @override
  Widget build(BuildContext context) {
    final caption = post.sharedNote?.trim();
    final overview = cleanFlowOverview(post.notes);
    final hasCaption = caption != null && caption.isNotEmpty;
    final captionText = hasCaption
        ? caption
        : overview.isNotEmpty
        ? overview
        : post.name;

    return SizedBox(
      key: ValueKey<String>('profile-flow-post-${post.id}'),
      height: profilePostHeight(context),
      child: ProfilePostFrame(
        metadata: ProfilePostMetadata(
          relationshipLabel: relationshipLabel,
          postedDateLabel: postedDateLabel,
          accent: accent,
          authorDisplayName: authorDisplayName,
          authorHandle: authorHandle,
          authorAvatarUrl: authorAvatarUrl,
          authorAvatarGlyphIds: authorAvatarGlyphIds,
          onOpenAuthor: onOpenAuthor,
          onOpenMenu: onOpenMenu,
        ),
        excerpt: captionText,
        excerptKey: const ValueKey<String>('profile-flow-post-caption'),
        isPersonalCaption: hasCaption,
        artifact: InkWell(
          key: ValueKey<String>('open-profile-flow-post-${post.id}'),
          onTap: onOpenFlow,
          borderRadius: BorderRadius.circular(16),
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
        actions: FlowPostEngagementRow(
          key: ValueKey<String>('profile_engagement_${post.id}'),
          post: post,
          lazyComments: true,
          compact: true,
          profileV2: true,
          likedColor: Color.lerp(accent, _profilePostBone, 0.58),
          onShare: isOwner ? onShare : null,
          additionalActions: !isOwner
              ? <FlowPostEngagementAction>[
                  if (onSave != null)
                    FlowPostEngagementAction(
                      key: ValueKey<String>('profile_save_flow_${post.id}'),
                      icon: Icons.bookmark_add_outlined,
                      profileIcon: HawProfileIconKind.save,
                      label: isSaved ? 'Saved' : 'Save',
                      color: isSaved
                          ? Color.lerp(accent, _profilePostBone, 0.58)
                          : null,
                      onPressed: onSave!,
                    ),
                  if (onTogether != null)
                    FlowPostEngagementAction(
                      key: ValueKey<String>('profile_together_flow_${post.id}'),
                      icon: Icons.people_outline_rounded,
                      profileIcon: HawProfileIconKind.together,
                      label: togetherLabel,
                      onPressed: onTogether!,
                    ),
                ]
              : const <FlowPostEngagementAction>[],
        ),
      ),
    );
  }
}
