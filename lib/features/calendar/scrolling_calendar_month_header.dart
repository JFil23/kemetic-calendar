import 'package:flutter/material.dart';

import '../../shared/glossy_text.dart';
import '../../widgets/month_name_text.dart';
import '../../widgets/pronounce_icon_button.dart';
import 'kemetic_month_metadata.dart';
import 'speech_resolver.dart';

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
    required this.showGregorian,
    required this.gregorianMonthName,
    required this.gregorianYearLabel,
    required this.weekdayLabels,
  }) : assert(weekdayLabels.length >= 5 && weekdayLabels.length <= 10);

  static const double monthBandHeight = 58;
  static const double weekdayBandHeight = 24;
  static const double _dividerWidth = 0.6;
  static const double height = monthBandHeight + weekdayBandHeight;
  static const double _weekdayHorizontalInset = 26;
  static const double _weekdayColumnGap = 3;
  static const double _speechTargetSize = 48;
  static const double _speechGap = 4;

  final KemeticMonth month;
  final String yearLabel;
  final bool showGregorian;
  final String gregorianMonthName;
  final String gregorianYearLabel;
  final List<String> weekdayLabels;

  static const _primaryStyle = TextStyle(
    color: Colors.white,
    fontSize: 29,
    height: 1,
    fontWeight: FontWeight.w600,
    fontFamily: 'CormorantGaramond',
    fontFamilyFallback: ['GentiumPlus', 'NotoSans', 'Roboto'],
  );
  static final _parentheticalStyle = TextStyle(
    color: const Color(0xFFA08648).withValues(alpha: 0.88),
    fontSize: 17,
    height: 1,
    fontWeight: FontWeight.w400,
    fontFamily: 'CormorantGaramond',
    fontFamilyFallback: const ['GentiumPlus', 'NotoSans', 'Roboto'],
  );

  @override
  Widget build(BuildContext context) {
    final seasonAndYear = '${month.season.label} $yearLabel';
    final primaryMonthName = showGregorian
        ? gregorianMonthName
        : month.displayShort;
    final contextLabel = showGregorian ? gregorianYearLabel : seasonAndYear;
    final monthGradient = showGregorian ? blueGloss : KemeticGold.gloss;
    final semanticsLabel = showGregorian
        ? '$gregorianMonthName, Gregorian calendar, $gregorianYearLabel'
        : '${month.displayFull}, $seasonAndYear';

    return Semantics(
      container: true,
      header: true,
      label: semanticsLabel,
      child: Container(
        height: height,
        color: const Color(0xFF060504),
        foregroundDecoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: KemeticGold.base.withValues(alpha: 0.18),
              width: _dividerWidth,
            ),
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: monthBandHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 5, 18, 5),
                child: Row(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final iconOffset = _speechIconOffset(
                            context,
                            constraints,
                          );
                          return Row(
                            children: [
                              // Fit only the label so the speech target and its
                              // gap never shrink with a longer month name.
                              Flexible(
                                child: FittedBox(
                                  key: const Key(
                                    'scrolling-calendar-month-label',
                                  ),
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      ShaderMask(
                                        shaderCallback:
                                            monthGradient.createShader,
                                        blendMode: BlendMode.srcIn,
                                        child: MonthNameText(
                                          primaryMonthName,
                                          key: const Key(
                                            'scrolling-calendar-month-name',
                                          ),
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.fade,
                                          style: _primaryStyle,
                                        ),
                                      ),
                                      if (!showGregorian &&
                                          month.displayTransliteration
                                              .trim()
                                              .isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        MonthNameText(
                                          '(${month.displayTransliteration})',
                                          key: const Key(
                                            'scrolling-calendar-month-parenthetical',
                                          ),
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.fade,
                                          style: _parentheticalStyle,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              if (!showGregorian) ...[
                                const SizedBox(width: _speechGap),
                                SizedBox(
                                  width: _speechTargetSize,
                                  height: _speechTargetSize,
                                  child: PronounceIconButton(
                                    key: const Key(
                                      'scrolling-calendar-month-speech',
                                    ),
                                    speakText: SpeechResolver.month(
                                      month: month,
                                    ),
                                    utteranceId:
                                        'calendar-banner-month-${month.id}',
                                    color: const Color(
                                      0xFFA08648,
                                    ).withValues(alpha: 0.72),
                                    size: 16,
                                    iconOffset: iconOffset,
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      contextLabel,
                      key: const Key('scrolling-calendar-season-year'),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: (showGregorian ? blue : const Color(0xFF927842))
                            .withValues(alpha: 0.88),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                        fontFamily: 'CormorantGaramond',
                        fontFamilyFallback: const [
                          'GentiumPlus',
                          'NotoSans',
                          'Roboto',
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              key: const Key('scrolling-calendar-weekday-row'),
              height: weekdayBandHeight,
              child: Semantics(
                label: 'Weekday sequence ${weekdayLabels.join(', ')}',
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _weekdayHorizontalInset,
                    ),
                    child: Row(
                      children: [
                        for (
                          var index = 0;
                          index < weekdayLabels.length;
                          index++
                        ) ...[
                          Expanded(
                            child: Center(
                              child: Text(
                                weekdayLabels[index],
                                key: ValueKey(
                                  'scrolling-calendar-weekday-$index',
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF756238),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                          if (index < weekdayLabels.length - 1)
                            const SizedBox(width: _weekdayColumnGap),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Offset _speechIconOffset(BuildContext context, BoxConstraints constraints) {
    if (showGregorian || month.displayTransliteration.trim().isEmpty) {
      return const Offset(-3, 0);
    }
    // Match MonthNameText's baseline and height behavior, then apply the same
    // scale-down fit. This keeps the icon centered on the actual parenthetical
    // text without shifting either label or reducing the button's hit area.
    TextPainter measure(String text, TextStyle style) => TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(
          context,
        ).style.merge(style).copyWith(letterSpacing: 0),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
      maxLines: 1,
    )..layout();
    final primary = measure(month.displayShort, _primaryStyle);
    final parenthetical = measure(
      '(${month.displayTransliteration})',
      _parentheticalStyle,
    );
    final primaryBaseline = primary.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final parentheticalBaseline = parenthetical.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final baseline = primaryBaseline > parentheticalBaseline
        ? primaryBaseline
        : parentheticalBaseline;
    final primaryDescent = primary.height - primaryBaseline;
    final parentheticalDescent = parenthetical.height - parentheticalBaseline;
    final height =
        baseline +
        (primaryDescent > parentheticalDescent
            ? primaryDescent
            : parentheticalDescent);
    final naturalSize = Size(primary.width + 8 + parenthetical.width, height);
    final fitted = applyBoxFit(
      BoxFit.scaleDown,
      naturalSize,
      Size(
        (constraints.maxWidth - _speechTargetSize - _speechGap).clamp(
          0,
          double.infinity,
        ),
        _speechTargetSize,
      ),
    );
    final scale = fitted.destination.height / height;
    final centerOffset =
        (baseline -
            parentheticalBaseline +
            parenthetical.height / 2 -
            height / 2) *
        scale;
    primary.dispose();
    parenthetical.dispose();
    // Keep the visible 17px gap as the icon shrinks, without moving its target.
    return Offset(-3, centerOffset);
  }
}
