import 'package:flutter/material.dart';

import '../../data/flow_appearance.dart';
import '../../data/flow_post_model.dart';
import '../../utils/detail_sanitizer.dart';
import '../../widgets/profile_avatar.dart';
import 'flow_post_engagement_row.dart';
import 'haw_profile_icon.dart';
import 'posted_flow_artifact.dart';

const Color _profilePostBone = Color(0xFFF2ECE0);
const Color _profilePostMid = Color(0xFF9E9A94);
const Color _profilePostLow = Color(0xFF6A6660);
const String _profilePostSerifFont = 'CormorantGaramond';
const List<String> _profilePostSerifFallback = <String>[
  'GentiumPlus',
  'Georgia',
  'serif',
];

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
      height: 392,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ProfilePostMetadata(
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
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: ClipRect(
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  captionText,
                  key: const ValueKey<String>('profile-flow-post-caption'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasCaption ? _profilePostBone : _profilePostMid,
                    fontFamily: _profilePostSerifFont,
                    fontFamilyFallback: _profilePostSerifFallback,
                    fontSize: hasCaption ? 20 : 17,
                    fontWeight: FontWeight.w400,
                    fontStyle: hasCaption ? FontStyle.normal : FontStyle.italic,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 11),
          InkWell(
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
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: FlowPostEngagementRow(
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
                          key: ValueKey<String>(
                            'profile_together_flow_${post.id}',
                          ),
                          icon: Icons.people_outline_rounded,
                          profileIcon: HawProfileIconKind.together,
                          label: 'Together',
                          onPressed: onTogether!,
                        ),
                    ]
                  : const <FlowPostEngagementAction>[],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePostMetadata extends StatelessWidget {
  const _ProfilePostMetadata({
    required this.relationshipLabel,
    required this.postedDateLabel,
    required this.accent,
    required this.authorDisplayName,
    required this.authorHandle,
    required this.authorAvatarUrl,
    required this.authorAvatarGlyphIds,
    required this.onOpenAuthor,
    required this.onOpenMenu,
  });

  final String relationshipLabel;
  final String postedDateLabel;
  final Color accent;
  final String authorDisplayName;
  final String? authorHandle;
  final String? authorAvatarUrl;
  final List<String> authorAvatarGlyphIds;
  final VoidCallback onOpenAuthor;
  final ValueChanged<Rect> onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final handle = authorHandle?.trim();
    final showRelationship = relationshipLabel.trim().isNotEmpty;
    return SizedBox(
      height: 34,
      child: Row(
        children: <Widget>[
          Expanded(
            child: InkWell(
              onTap: onOpenAuthor,
              borderRadius: BorderRadius.circular(17),
              child: Row(
                children: <Widget>[
                  ProfileAvatar(
                    displayName: authorDisplayName,
                    avatarUrl: authorAvatarUrl,
                    avatarGlyphIds: authorAvatarGlyphIds,
                    radius: 17,
                    foregroundColor: const Color(0xFFD4AE43),
                    backgroundColor: const Color(0xFF15110A),
                    borderColor: const Color(0xFF2C2619),
                    borderWidth: 1,
                    maxInitialCharacters: 1,
                    initialFontSize: 15,
                    initialFontFamily: _profilePostSerifFont,
                    initialFontWeight: FontWeight.w400,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                authorDisplayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _profilePostBone,
                                  fontFamily: _profilePostSerifFont,
                                  fontFamilyFallback: _profilePostSerifFallback,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w400,
                                  height: 1.05,
                                ),
                              ),
                            ),
                            if (showRelationship) ...<Widget>[
                              const SizedBox(width: 7),
                              Text(
                                relationshipLabel.toUpperCase(),
                                style: TextStyle(
                                  color: accent,
                                  fontFamily: 'Inter',
                                  fontSize: 8,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 1.44,
                                  height: 1,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (handle != null && handle.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(
                            '@$handle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _profilePostLow,
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              height: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              postedDateLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF777068),
                fontFamily: _profilePostSerifFont,
                fontFamilyFallback: _profilePostSerifFallback,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Post options',
            child: Builder(
              builder: (menuContext) => GestureDetector(
                key: const ValueKey<String>('profile-flow-post-menu'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final renderObject = menuContext.findRenderObject();
                  if (renderObject is! RenderBox || !renderObject.hasSize) {
                    return;
                  }
                  onOpenMenu(
                    renderObject.localToGlobal(Offset.zero) & renderObject.size,
                  );
                },
                child: const SizedBox(
                  width: 20,
                  height: 34,
                  child: Center(
                    child: Text(
                      '⋮',
                      style: TextStyle(
                        color: Color(0xFF8A8378),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 2,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
