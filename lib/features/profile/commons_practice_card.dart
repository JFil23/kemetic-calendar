import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/commons_models.dart';
import '../../widgets/profile_avatar.dart';
import 'commons_question_block.dart';

const _profileGoldMid = Color(0xFFE8BE54);
const _profileGoldText = Color(0xFFF1CF7A);
const _profileSerifFont = 'CormorantGaramond';
const _profileSerifFallback = ['GentiumPlus', 'Georgia', 'serif'];

/// The existing Commons room card. The passive pane variant shares its identity,
/// typography and member glyphs; actions stay in the canonical Commons screen.
class CommonsPracticeCard extends StatelessWidget {
  const CommonsPracticeCard({
    super.key,
    required this.room,
    this.pane = false,
    this.liked = false,
    this.likeCount = 0,
    this.onLike,
    this.onOpen,
    this.viewerAction = const SizedBox.shrink(),
  });
  final CommonsPracticeRoom room;
  final bool pane, liked;
  final int likeCount;
  final VoidCallback? onLike, onOpen;
  final Widget viewerAction;

  @override
  Widget build(BuildContext context) {
    if (pane) return _pane();
    return buildCommonsCard(
      borderColor: _profileGoldMid.withValues(alpha: 0.22),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statusPill(
                      'Public group flow',
                      color: const Color(0xFF30D5C8),
                    ),
                    const SizedBox(height: 10),
                    _title(),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (room.viewerIsMember || room.viewerCanManage)
                IconButton(
                  onPressed: onOpen,
                  tooltip: 'Open group flow',
                  icon: const Icon(Icons.open_in_new_rounded, size: 20),
                  color: _profileGoldText,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.28),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            [
              if (room.calendarName?.trim().isNotEmpty == true)
                room.calendarName!.trim(),
              '${room.memberCount} ${room.memberCount == 1 ? 'member' : 'members'}',
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildCommonsPublicMemberRoster(room),
          const Spacer(),
          Row(
            children: [
              TextButton.icon(
                key: ValueKey<String>('commons_group_like_${room.id}'),
                onPressed: onLike,
                icon: Icon(
                  liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 18,
                ),
                label: Text(likeCount > 0 ? '$likeCount' : 'Like'),
                style: TextButton.styleFrom(
                  foregroundColor: liked
                      ? const Color(0xFFC4DCE8)
                      : Colors.white.withValues(alpha: 0.62),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 40),
                ),
              ),
              const Spacer(),
              viewerAction,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The group is public here; its conversation stays with the people practicing inside it.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.50),
              fontFamily: _profileSerifFont,
              fontFamilyFallback: _profileSerifFallback,
              fontStyle: FontStyle.italic,
              fontSize: 14,
              height: 1.24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _title({int maxLines = 2}) => Text(
    room.title,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: Colors.white.withValues(alpha: 0.9),
      fontFamily: _profileSerifFont,
      fontFamilyFallback: _profileSerifFallback,
      fontSize: pane ? 17 : 24,
      fontWeight: FontWeight.w700,
      height: 1.05,
    ),
  );
  Widget _buildCommonsPublicMemberRoster(CommonsPracticeRoom room) {
    final visibleMembers = room.publicMembers.take(3).toList(growable: false);
    if (visibleMembers.isEmpty) {
      return Text(
        '${room.memberCount} practicing · names kept private',
        maxLines: pane ? 1 : null,
        overflow: pane ? TextOverflow.ellipsis : null,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.52),
          fontFamily: _profileSerifFont,
          fontFamilyFallback: _profileSerifFallback,
          fontSize: pane ? 10 : 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    final privateCount = math.max(0, room.memberCount - visibleMembers.length);
    return Row(
      children: [
        SizedBox(
          width:
              (pane ? 20.0 : 28.0) +
              ((visibleMembers.length - 1) * (pane ? 14 : 19)),
          height: pane ? 22 : 30,
          child: Stack(
            children: [
              for (var index = 0; index < visibleMembers.length; index++)
                Positioned(
                  left: index * (pane ? 14 : 19),
                  child: ProfileAvatar(
                    radius: pane ? 10 : 14,
                    displayName: visibleMembers[index].label,
                    avatarUrl: pane ? null : visibleMembers[index].avatarUrl,
                    avatarGlyphIds: visibleMembers[index].avatarGlyphIds,
                    backgroundColor: const Color(0xFF163C32),
                    foregroundColor: const Color(0xFFB9E5D7),
                    borderColor: const Color(0xFF090704),
                    borderWidth: 1,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            pane
                ? '${room.memberCount} members'
                : [
                    visibleMembers.map((member) => member.label).join(', '),
                    if (privateCount > 0) '+ $privateCount private',
                  ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: pane ? 10 : 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusPill(String label, {required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: pane ? 6 : 10,
        vertical: pane ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.48)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: pane ? 7.5 : 10.5,
          height: pane ? 1 : null,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _pane() => LayoutBuilder(
    builder: (context, box) => IgnorePointer(
      child: ExcludeFocus(
        child: buildCommonsCard(
          borderColor: _profileGoldMid.withValues(alpha: 0.22),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statusPill('Public group flow', color: const Color(0xFF30D5C8)),
              const SizedBox(height: 4),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _title(maxLines: box.maxHeight < 115 ? 1 : 2),
                ),
              ),
              const SizedBox(height: 4),
              _buildCommonsPublicMemberRoster(room),
              const SizedBox(height: 4),
              Text(
                'Practice Together',
                style: const TextStyle(
                  fontFamily: _profileSerifFont,
                  fontFamilyFallback: _profileSerifFallback,
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: _profileGoldText,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
