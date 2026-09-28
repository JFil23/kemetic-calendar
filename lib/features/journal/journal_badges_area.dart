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
    this.pane = false,
    this.pageMode = false,
    this.scrollController,
    this.expandedIds = const {},
    this.onDelete,
    this.onToggle,
  });
  final double height;
  final List<EventBadgeToken> badges;
  final bool compact, pageMode, pane;
  final ScrollController? scrollController;
  final Set<String> expandedIds;
  final ValueChanged<EventBadgeToken>? onDelete;
  final void Function(EventBadgeToken, bool)? onToggle;
  @override
  Widget build(BuildContext context) {
    final badgeCountLabel = badges.isEmpty
        ? 'No badges yet'
        : '${badges.length} badge${badges.length == 1 ? '' : 's'}';

    if (pane) return _buildPane(badgeCountLabel);

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

  Widget _buildPane(String count) => ColoredBox(
    color: const Color(0xFF0A0910),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'BADGES',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 7,
                  letterSpacing: 1.2,
                  color: Color(0xFFD4AF37),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  count,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'GentiumPlus',
                    fontSize: 9,
                    color: Color(0xFF938B9E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: badges.isEmpty
                ? const JournalEmptyBadgeGlyph(
                    width: 100,
                    height: 40,
                    fontSize: 40,
                  )
                : Align(
                    alignment: Alignment.topLeft,
                    child: LayoutBuilder(
                      builder: (context, bounds) {
                        // Journal sheet: 24px outer inset and 12px badge inset
                        // on each side. Lay out the real pill at that width,
                        // then reduce every part together to the pane width.
                        final sheetBadgeWidth =
                            MediaQuery.sizeOf(context).width - 2 * (24 + 12);
                        return SizedBox(
                          width: bounds.maxWidth,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topLeft,
                            child: SizedBox(
                              width: sheetBadgeWidth,
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: EventBadgeWidget(
                                  token: badges.first,
                                  expandable: false,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    ),
  );

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
