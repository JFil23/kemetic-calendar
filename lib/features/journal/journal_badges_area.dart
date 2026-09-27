import 'package:flutter/material.dart';
import '../../shared/glossy_text.dart';
import 'journal_event_badge.dart';
import 'journal_empty_badge_glyph.dart';

class JournalBadgesArea extends StatelessWidget {
  const JournalBadgesArea({
    super.key,
    required this.height,
    required this.badges,
    this.compact = false,
    this.pageMode = false,
    this.scrollController,
    this.expandedIds = const {},
    this.onDelete,
    this.onToggle,
  });
  final double height;
  final List<EventBadgeToken> badges;
  final bool compact, pageMode;
  final ScrollController? scrollController;
  final Set<String> expandedIds;
  final ValueChanged<EventBadgeToken>? onDelete;
  final void Function(EventBadgeToken, bool)? onToggle;
  @override
  Widget build(BuildContext context) {
    final badgeCountLabel = badges.isEmpty
        ? 'No badges yet'
        : '${badges.length} badge${badges.length == 1 ? '' : 's'}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, compact ? 6 : 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Badges',
                  style: TextStyle(
                    color: KemeticGold.base,
                    fontSize: compact
                        ? 13
                        : pageMode
                        ? 16
                        : 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  badgeCountLabel,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A),
                  border: Border.all(color: const Color(0xFF333333), width: 1),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: compact
                    ? _buildCompactBadgeList(badges)
                    : _buildExpandedBadgeList(badges),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBadgeList(List<EventBadgeToken> badges) {
    if (badges.isEmpty) {
      return const JournalEmptyBadgeGlyph(width: 96, height: 32, fontSize: 32);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: badges.map((token) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: EventBadgeWidget(
              token: token,
              initialExpanded: false,
              expandable: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExpandedBadgeList(List<EventBadgeToken> badges) {
    if (badges.isEmpty) {
      return const JournalEmptyBadgeGlyph();
    }

    return Scrollbar(
      thumbVisibility: scrollController != null,
      controller: scrollController,
      child: SingleChildScrollView(
        primary: false,
        controller: scrollController,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: badges.map((token) {
            final expanded = expandedIds.contains(token.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: EventBadgeWidget(
                token: token,
                initialExpanded: expanded,
                onDelete: onDelete == null ? null : () => onDelete!(token),
                onToggle: (next) => onToggle?.call(token, next),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
