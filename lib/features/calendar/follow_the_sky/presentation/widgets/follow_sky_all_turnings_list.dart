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
    required this.remainingNights,
    required this.surfacedCount,
    required this.expanded,
    required this.onToggle,
    required this.meaningResolver,
    required this.onOpenNight,
  });

  final SkyCatalog catalog;
  final List<SkyObservingNight> remainingNights;
  final int surfacedCount;
  final bool expanded;
  final VoidCallback onToggle;
  final TurningMeaningResolver meaningResolver;
  final ValueChanged<SkyObservingNight> onOpenNight;

  @override
  Widget build(BuildContext context) {
    final endLabel = _formatCoverageMonth(catalog.coverageEnd.toLocal());
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: InkWell(
              key: const ValueKey<String>('follow-sky-all-turnings-toggle'),
              onTap: onToggle,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 2,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0x2ED4AE43)),
                    bottom: BorderSide(color: Color(0x2ED4AE43)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'All ${catalog.observingNightCount} turnings through $endLabel',
                        style: const TextStyle(
                          color: FollowSkyV11Tokens.contentSecondary,
                          fontFamily: MaatFlowListTokens.fontFamily,
                          fontFamilyFallback: MaatFlowListTokens.fontFallback,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          height: 1,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: const Icon(
                        Icons.expand_more,
                        size: 16,
                        color: FollowSkyV11Tokens.goldDim,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              alignment: Alignment.topCenter,
              duration: const Duration(milliseconds: 450),
              curve: Curves.ease,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          for (var i = 0; i < remainingNights.length; i++)
                            _AllTurningRow(
                              index: surfacedCount + i + 1,
                              night: remainingNights[i],
                              meaning: meaningResolver.forNight(
                                remainingNights[i],
                              ),
                              onTap: () => onOpenNight(remainingNights[i]),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 22, 24, 0),
            child: Text(
              'The sky keeps the schedule either way.',
              style: TextStyle(
                color: FollowSkyV11Tokens.contentMuted,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCoverageMonth(DateTime local) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
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
      key: ValueKey<String>('follow-sky-all-${night.skyEventId}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                index.toString().padLeft(2, '0'),
                style: const TextStyle(
                  color: FollowSkyV11Tokens.goldDim,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.76,
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
                      color: FollowSkyV11Tokens.gold,
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
                      fontSize: 19,
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.italic,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    _shortDate(date),
                    style: const TextStyle(
                      color: FollowSkyV11Tokens.contentMuted,
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  Text(
                    meaning.significanceLabel,
                    style: const TextStyle(
                      color: FollowSkyV11Tokens.contentSecondary,
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
                      fontSize: 14.5,
                      fontStyle: FontStyle.italic,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: FollowSkyV11Tokens.intentionPeriwinkle,
            ),
          ],
        ),
      ),
    );
  }

  String _shortDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
