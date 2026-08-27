import 'package:flutter/material.dart';

import '../decan_metadata.dart';
import '../kemetic_month_metadata.dart';
import '../maat_flow_visual_tokens.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart';

abstract final class MaatFlowThirtyDayCalendarGeometry {
  static const double decanRowHeight = 80;
  static const double dayNumberAreaHeight = 42;
  static const double todayRingDiameter = 40;
  static const double highlightRingDiameter = 36;
  static const double ringDotGap = 6;
  static const double todayLabelFontSize = 10.5;
  static const double dayNumberFontSize = 21;
}

@immutable
class MaatFlowThirtyDayCalendarTheme {
  const MaatFlowThirtyDayCalendarTheme({
    required this.introText,
    required this.introEmphasis,
    required this.border,
    required this.month,
    required this.monthTransliteration,
    required this.decan,
    required this.day,
    required this.today,
    required this.highlight,
  });

  final Color introText;
  final Color introEmphasis;
  final Color border;
  final Color month;
  final Color monthTransliteration;
  final Color decan;
  final Color day;
  final Color today;
  final Color highlight;
}

@immutable
class MaatFlowThirtyDayMarker {
  const MaatFlowThirtyDayMarker({
    required this.date,
    this.isToday = false,
    this.highlighted = false,
    this.filled = false,
    this.accent,
    this.secondaryColors = const <Color>[],
  });

  final DateTime date;
  final bool isToday;
  final bool highlighted;
  final bool filled;
  final Color? accent;
  final List<Color> secondaryColors;
}

/// Shared Kemetic month/decan calendar geometry for a rolling thirty-day flow.
/// Flow adapters supply only marker state and colors; date grouping and layout
/// remain identical across detail pages.
class MaatFlowThirtyDayCalendar extends StatelessWidget {
  const MaatFlowThirtyDayCalendar({
    super.key,
    required this.windowStart,
    required this.markers,
    required this.theme,
    required this.introFirstLine,
    required this.introSecondLine,
    required this.keyPrefix,
    this.dayCount = 30,
  });

  final DateTime windowStart;
  final List<MaatFlowThirtyDayMarker> markers;
  final MaatFlowThirtyDayCalendarTheme theme;
  final String introFirstLine;
  final String introSecondLine;
  final String keyPrefix;
  final int dayCount;

  @override
  Widget build(BuildContext context) {
    final sections = _sectionsForWindow();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                introFirstLine,
                style: TextStyle(
                  color: theme.introText,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  height: 1.36,
                ),
              ),
              Text(
                introSecondLine,
                style: TextStyle(
                  color: theme.introEmphasis,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                  height: 1.36,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        for (final section in sections) ...[
          _MonthBand(monthId: section.monthId, theme: theme),
          for (var i = 0; i < section.decans.length; i++)
            _DecanRow(
              decan: section.decans[i],
              theme: theme,
              keyPrefix: keyPrefix,
              drawBottomBorder:
                  section == sections.last && i == section.decans.length - 1,
            ),
        ],
        const SizedBox(height: 6),
      ],
    );
  }

  List<_MonthSection> _sectionsForWindow() {
    final start = DateUtils.dateOnly(windowStart);
    final markersByDay = <DateTime, MaatFlowThirtyDayMarker>{
      for (final marker in markers) DateUtils.dateOnly(marker.date): marker,
    };
    final sections = <_MonthSection>[];
    _MonthSection? currentMonth;
    _DecanStrip? currentDecan;

    for (var offset = 0; offset < dayCount; offset++) {
      final date = start.add(Duration(days: offset));
      final kemetic = KemeticMath.fromGregorian(date);
      final decanIndex = ((kemetic.kDay - 1) ~/ 10).clamp(0, 2);
      if (currentMonth == null || currentMonth.monthId != kemetic.kMonth) {
        currentMonth = _MonthSection(monthId: kemetic.kMonth);
        sections.add(currentMonth);
        currentDecan = null;
      }
      if (currentDecan == null || currentDecan.decanIndex != decanIndex) {
        final names =
            DecanMetadata.decanNames[kemetic.kMonth] ??
            const <String>['I', 'II', 'III'];
        currentDecan = _DecanStrip(
          name: names[decanIndex],
          decanIndex: decanIndex,
        );
        currentMonth.decans.add(currentDecan);
      }

      final marker = markersByDay[date];
      currentDecan.days[(kemetic.kDay - 1) % 10] = _CalendarDay(
        date: date,
        dayNumber: kemetic.kDay,
        isToday: marker?.isToday ?? false,
        highlighted: marker?.highlighted ?? false,
        filled: marker?.filled ?? false,
        accent: marker?.accent,
        secondaryColors: marker?.secondaryColors ?? const <Color>[],
      );
    }
    return sections;
  }
}

class _MonthSection {
  _MonthSection({required this.monthId});

  final int monthId;
  final List<_DecanStrip> decans = <_DecanStrip>[];
}

class _DecanStrip {
  _DecanStrip({required this.name, required this.decanIndex});

  final String name;
  final int decanIndex;
  final List<_CalendarDay?> days = List<_CalendarDay?>.filled(10, null);
}

class _CalendarDay {
  const _CalendarDay({
    required this.date,
    required this.dayNumber,
    required this.isToday,
    required this.highlighted,
    required this.filled,
    required this.accent,
    required this.secondaryColors,
  });

  final DateTime date;
  final int dayNumber;
  final bool isToday;
  final bool highlighted;
  final bool filled;
  final Color? accent;
  final List<Color> secondaryColors;
}

class _MonthBand extends StatelessWidget {
  const _MonthBand({required this.monthId, required this.theme});

  final int monthId;
  final MaatFlowThirtyDayCalendarTheme theme;

  @override
  Widget build(BuildContext context) {
    final month = getMonthById(monthId);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: Text.rich(
        TextSpan(
          text: month.displayShort,
          children: [
            TextSpan(
              text: ' (${month.displayTransliteration})',
              style: TextStyle(
                color: theme.monthTransliteration,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        style: TextStyle(
          color: theme.month,
          fontFamily: MaatFlowListTokens.fontFamily,
          fontFamilyFallback: MaatFlowListTokens.fontFallback,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.52,
        ),
      ),
    );
  }
}

class _DecanRow extends StatelessWidget {
  const _DecanRow({
    required this.decan,
    required this.theme,
    required this.keyPrefix,
    required this.drawBottomBorder,
  });

  final _DecanStrip decan;
  final MaatFlowThirtyDayCalendarTheme theme;
  final String keyPrefix;
  final bool drawBottomBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MaatFlowThirtyDayCalendarGeometry.decanRowHeight,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.border),
          bottom: drawBottomBorder
              ? BorderSide(color: theme.border)
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(
                decan.name.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  color: theme.decan,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1.52,
                  height: 1.05,
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                for (final day in decan.days)
                  Expanded(
                    child: _DayTile(
                      day: day,
                      theme: theme,
                      keyPrefix: keyPrefix,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.theme,
    required this.keyPrefix,
  });

  final _CalendarDay? day;
  final MaatFlowThirtyDayCalendarTheme theme;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final value = day;
    if (value == null) return const SizedBox.expand();
    final accent = value.accent ?? theme.highlight;
    final ringDiameter = value.isToday
        ? MaatFlowThirtyDayCalendarGeometry.todayRingDiameter
        : MaatFlowThirtyDayCalendarGeometry.highlightRingDiameter;
    final dateKey = _dateKey(value.date);

    return Column(
      key: ValueKey<String>('$keyPrefix-day-$dateKey'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: MaatFlowThirtyDayCalendarGeometry.dayNumberAreaHeight,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (value.isToday || value.highlighted)
                OverflowBox(
                  minWidth: ringDiameter,
                  maxWidth: ringDiameter,
                  minHeight: ringDiameter,
                  maxHeight: ringDiameter,
                  child: Container(
                    key: ValueKey<String>('$keyPrefix-ring-$dateKey'),
                    width: ringDiameter,
                    height: ringDiameter,
                    decoration: BoxDecoration(
                      color: value.highlighted && value.filled
                          ? accent.withValues(alpha: 0.10)
                          : null,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: value.highlighted ? accent : theme.month,
                      ),
                    ),
                  ),
                ),
              Text(
                key: ValueKey<String>('$keyPrefix-number-$dateKey'),
                value.isToday ? 'today' : '${value.dayNumber}',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: value.isToday ? theme.today : theme.day,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: value.isToday
                      ? MaatFlowThirtyDayCalendarGeometry.todayLabelFontSize
                      : MaatFlowThirtyDayCalendarGeometry.dayNumberFontSize,
                  height: value.isToday ? null : 1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MaatFlowThirtyDayCalendarGeometry.ringDotGap),
        SizedBox(
          key: ValueKey<String>('$keyPrefix-dots-$dateKey'),
          height: 3,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (index, color)
                  in value.secondaryColors.take(4).indexed) ...[
                Container(
                  key: ValueKey<String>('$keyPrefix-dot-$dateKey-$index'),
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 2),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
