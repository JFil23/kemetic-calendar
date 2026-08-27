import 'package:flutter/material.dart';

import '../kemetic_month_metadata.dart';
import '../maat_flow_visual_tokens.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart';

@immutable
class MaatFlowPreviewTheme {
  const MaatFlowPreviewTheme({
    required this.surface,
    required this.border,
    required this.shadow,
    required this.kemeticDate,
    required this.gregorianDate,
    required this.divider,
    required this.primaryText,
    required this.secondaryText,
  });

  final Color surface;
  final Color border;
  final Color shadow;
  final Color kemeticDate;
  final Color gregorianDate;
  final Color divider;
  final Color primaryText;
  final Color secondaryText;
}

/// Shared date heading and card geometry used by Ma'at flow previews.
class MaatFlowPreviewDayCard extends StatelessWidget {
  const MaatFlowPreviewDayCard({
    super.key,
    required this.date,
    required this.theme,
    required this.children,
  });

  final DateTime date;
  final MaatFlowPreviewTheme theme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final kemetic = KemeticMath.fromGregorian(date);
    final month = getMonthById(kemetic.kMonth);
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 7),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
        boxShadow: [BoxShadow(color: theme.shadow, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  '${month.displayShort} ${kemetic.kDay}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.kemeticDate,
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontFamilyFallback: MaatFlowListTokens.fontFallback,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                gregorianDateLabel(date),
                maxLines: 1,
                style: TextStyle(
                  color: theme.gregorianDate,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 10,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(color: theme.divider, height: 1),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Compact calendar-event row. Rich flow-specific event art remains owned by
/// the flow; this primitive covers only time, title, and restrained support.
class MaatFlowPreviewEventRow extends StatelessWidget {
  const MaatFlowPreviewEventRow({
    super.key,
    required this.timeLabel,
    required this.title,
    required this.accent,
    required this.theme,
    this.subtitle,
  });

  final String timeLabel;
  final String title;
  final String? subtitle;
  final Color accent;
  final MaatFlowPreviewTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 12,
            child: Container(
              width: 3,
              height: 14,
              margin: const EdgeInsets.only(top: 4, right: 9),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                timeLabel,
                style: TextStyle(
                  color: theme.secondaryText,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.primaryText,
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontFamilyFallback: MaatFlowListTokens.fontFallback,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                  ),
                ),
                if (subtitle?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.secondaryText,
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String gregorianDateLabel(DateTime date) {
  const weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = <String>[
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
  return '${weekdays[date.weekday - 1]} · ${months[date.month - 1]} ${date.day}';
}
