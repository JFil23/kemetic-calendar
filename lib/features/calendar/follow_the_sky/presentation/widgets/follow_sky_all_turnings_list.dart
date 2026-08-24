import 'package:flutter/material.dart';

import '../../domain/sky_catalog.dart';
import '../../domain/sky_observing_night.dart';
import '../../../maat_flow_visual_tokens.dart';
import '../turning_meaning.dart';
import 'follow_sky_v11_tokens.dart';

class FollowSkyAllTurningsList extends StatelessWidget {
  const FollowSkyAllTurningsList({
    super.key,
    required this.catalog,
    required this.nowUtc,
    required this.lastSurfacedNight,
    required this.expanded,
    required this.onToggle,
    required this.meaningResolver,
    required this.onOpenNight,
  });

  final SkyCatalog catalog;
  final DateTime nowUtc;
  final SkyObservingNight? lastSurfacedNight;
  final bool expanded;
  final VoidCallback onToggle;
  final TurningMeaningResolver meaningResolver;
  final ValueChanged<SkyObservingNight> onOpenNight;

  @override
  Widget build(BuildContext context) {
    final endLabel = _formatCoverageMonth(catalog.coverageEnd.toLocal());
    final remaining = _remainingNights();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Color(0xFF2A2518), height: 32),
        InkWell(
          onTap: onToggle,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'All ${catalog.observingNightCount} turnings through $endLabel',
                  style: const TextStyle(
                    color: FollowSkyV11Tokens.gold,
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontFamilyFallback: MaatFlowListTokens.fontFallback,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                child: const Icon(
                  Icons.expand_more,
                  color: FollowSkyV11Tokens.gold,
                ),
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: [
              const SizedBox(height: 12),
              for (var i = 0; i < remaining.length; i++)
                _AllTurningRow(
                  index: _sequenceAfterSurfaced(i),
                  night: remaining[i],
                  meaning: meaningResolver.forNight(remaining[i]),
                  onTap: () => onOpenNight(remaining[i]),
                ),
              const SizedBox(height: 12),
              const Text(
                'The sky keeps the schedule either way.',
                style: TextStyle(
                  color: FollowSkyV11Tokens.silverMid,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ],
          ),
          crossFadeState:
              expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 260),
        ),
      ],
    );
  }

  List<SkyObservingNight> _remainingNights() {
    final all = catalog.upcomingNights(nowUtc: nowUtc);
    if (lastSurfacedNight == null) return all;
    final lastInstant = lastSurfacedNight!.primaryInstantUtc;
    return all
        .where((n) => n.primaryInstantUtc.isAfter(lastInstant))
        .toList(growable: false);
  }

  int _sequenceAfterSurfaced(int index) {
    final surfacedCount = catalog.upcomingNights(nowUtc: nowUtc).length -
        _remainingNights().length;
    return surfacedCount + index + 1;
  }

  String _formatCoverageMonth(DateTime local) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[local.month - 1]} ${local.year}';
  }
}

class _AllTurningRow extends StatelessWidget {
  const _AllTurningRow({
    required this.index,
    required this.night,
    required this.meaning,
    required this.onTap,
  });

  final int index;
  final SkyObservingNight night;
  final TurningMeaning meaning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = night.primaryInstantUtc.toLocal();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$index',
                style: const TextStyle(
                  color: FollowSkyV11Tokens.silverMid,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    night.displayName,
                    style: const TextStyle(
                      color: FollowSkyV11Tokens.silverHi,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _shortDate(date),
                    style: const TextStyle(
                      color: FollowSkyV11Tokens.silverMid,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    meaning.significanceLabel,
                    style: const TextStyle(
                      color: FollowSkyV11Tokens.gold,
                      fontSize: 12,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: FollowSkyV11Tokens.silverMid),
          ],
        ),
      ),
    );
  }

  String _shortDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
