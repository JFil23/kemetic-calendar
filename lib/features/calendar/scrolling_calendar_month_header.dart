import 'package:flutter/material.dart';

import '../../shared/glossy_text.dart';
import '../../widgets/month_name_text.dart';
import 'kemetic_month_metadata.dart';

/// Persistent month context for the scrolling calendar.
///
/// The calendar scroll coordinator owns the active top-edge month. This widget
/// only presents that state, keeping the banner independent from calendar
/// navigation and restoration behavior.
class ScrollingCalendarMonthHeader extends StatelessWidget {
  const ScrollingCalendarMonthHeader({
    super.key,
    required this.month,
    required this.yearLabel,
  });

  static const double height = 58;

  final KemeticMonth month;
  final String yearLabel;

  @override
  Widget build(BuildContext context) {
    final seasonAndYear = '${month.season.label} $yearLabel';

    return Semantics(
      container: true,
      header: true,
      label: '${month.displayFull}, $seasonAndYear',
      child: Container(
        height: height,
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 7),
        decoration: BoxDecoration(
          color: const Color(0xFF060504),
          border: Border(
            bottom: BorderSide(
              color: KemeticGold.base.withValues(alpha: 0.18),
              width: 0.6,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    ShaderMask(
                      shaderCallback: KemeticGold.gloss.createShader,
                      blendMode: BlendMode.srcIn,
                      child: MonthNameText(
                        month.displayShort,
                        key: const Key('scrolling-calendar-month-name'),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 29,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'CormorantGaramond',
                          fontFamilyFallback: [
                            'GentiumPlus',
                            'NotoSans',
                            'Roboto',
                          ],
                        ),
                      ),
                    ),
                    if (month.displayTransliteration.trim().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      MonthNameText(
                        '(${month.displayTransliteration})',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: TextStyle(
                          color: const Color(
                            0xFFA08648,
                          ).withValues(alpha: 0.88),
                          fontSize: 17,
                          height: 1,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'CormorantGaramond',
                          fontFamilyFallback: const [
                            'GentiumPlus',
                            'NotoSans',
                            'Roboto',
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              seasonAndYear,
              key: const Key('scrolling-calendar-season-year'),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: const Color(0xFF927842).withValues(alpha: 0.88),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                fontFamily: 'CormorantGaramond',
                fontFamilyFallback: const ['GentiumPlus', 'NotoSans', 'Roboto'],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
