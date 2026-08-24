import 'package:flutter/material.dart';

import '../../../decan_metadata.dart';
import '../../../kemetic_month_metadata.dart';
import '../../../maat_flow_visual_tokens.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart';
import '../../domain/sky_observing_night.dart';
import '../follow_sky_calendar_preview.dart';
import 'follow_sky_v11_tokens.dart';

class FollowSkyThirtyDayStrip extends StatelessWidget {
  const FollowSkyThirtyDayStrip({
    super.key,
    required this.windowStart,
    required this.skyNights,
    required this.calendarRows,
    required this.excludedSkyEventIds,
    required this.carried,
    this.dayCount = 30,
  });

  final DateTime windowStart;
  final List<SkyObservingNight> skyNights;
  final List<FollowSkyCalendarPreviewRow> calendarRows;
  final Set<String> excludedSkyEventIds;
  final bool carried;
  final int dayCount;

  @override
  Widget build(BuildContext context) {
    final sections = _sectionsForWindow();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 36, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Here they are.', style: _introStyle),
              Text(
                'In your next thirty days.',
                style: TextStyle(
                  color: FollowSkyV11Tokens.silverMid,
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
          _MonthBand(monthId: section.monthId),
          for (var i = 0; i < section.decans.length; i++)
            _DecanRow(
              decan: section.decans[i],
              drawBottomBorder:
                  section == sections.last && i == section.decans.length - 1,
            ),
        ],
        const SizedBox(height: 6),
      ],
    );
  }

  static const TextStyle _introStyle = TextStyle(
    color: FollowSkyV11Tokens.silverHi,
    fontFamily: MaatFlowListTokens.fontFamily,
    fontFamilyFallback: MaatFlowListTokens.fontFallback,
    fontSize: 24,
    fontWeight: FontWeight.w400,
    height: 1.36,
  );

  List<_MonthSection> _sectionsForWindow() {
    final start = DateUtils.dateOnly(windowStart);
    final skyIdsByDay = <DateTime, List<String>>{};
    for (final night in skyNights) {
      final day = DateUtils.dateOnly(night.primaryInstantUtc.toLocal());
      skyIdsByDay.putIfAbsent(day, () => <String>[]).add(night.skyEventId);
    }
    final eventColorsByDay = <DateTime, List<Color>>{};
    for (final row in calendarRows) {
      final day = DateUtils.dateOnly(row.localDay);
      eventColorsByDay.putIfAbsent(day, () => <Color>[]).add(row.eventColor);
    }

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

      final skyIds = skyIdsByDay[date] ?? const <String>[];
      currentDecan.days[(kemetic.kDay - 1) % 10] = _StripDay(
        dayNumber: kemetic.kDay,
        today: offset == 0,
        hasSky: skyIds.any((id) => !excludedSkyEventIds.contains(id)),
        eventColors: eventColorsByDay[date] ?? const <Color>[],
        carried: carried,
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
  final List<_StripDay?> days = List<_StripDay?>.filled(10, null);
}

class _StripDay {
  const _StripDay({
    required this.dayNumber,
    required this.today,
    required this.hasSky,
    required this.eventColors,
    required this.carried,
  });

  final int dayNumber;
  final bool today;
  final bool hasSky;
  final List<Color> eventColors;
  final bool carried;
}

class _MonthBand extends StatelessWidget {
  const _MonthBand({required this.monthId});

  final int monthId;

  @override
  Widget build(BuildContext context) {
    final month = getMonthById(monthId);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x2EC4A64A))),
      ),
      child: Text.rich(
        TextSpan(
          text: month.displayShort,
          children: [
            TextSpan(
              text: ' (${month.displayTransliteration})',
              style: const TextStyle(
                color: FollowSkyV11Tokens.calendarTransliteration,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        style: const TextStyle(
          color: FollowSkyV11Tokens.calendarAntique,
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
  const _DecanRow({required this.decan, required this.drawBottomBorder});

  final _DecanStrip decan;
  final bool drawBottomBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 57,
      decoration: BoxDecoration(
        border: Border(
          top: const BorderSide(color: Color(0x2EC4A64A)),
          bottom: drawBottomBorder
              ? const BorderSide(color: Color(0x2EC4A64A))
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
                style: const TextStyle(
                  color: FollowSkyV11Tokens.calendarDecan,
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
                  Expanded(child: _DayTile(day: day)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day});

  final _StripDay? day;

  @override
  Widget build(BuildContext context) {
    final value = day;
    if (value == null) return const SizedBox.expand();
    final ringColor = value.hasSky
        ? FollowSkyV11Tokens.intentionPeriwinkle.withValues(alpha: 0.72)
        : FollowSkyV11Tokens.calendarAntique.withValues(alpha: 0.72);
    return Stack(
      alignment: Alignment.center,
      children: [
        if (value.today || value.hasSky)
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: value.hasSky && value.carried
                  ? FollowSkyV11Tokens.intentionPeriwinkle.withValues(
                      alpha: 0.10,
                    )
                  : null,
              shape: BoxShape.circle,
              border: Border.all(color: ringColor),
            ),
          ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value.today ? 'today' : '${value.dayNumber}',
              style: TextStyle(
                color: value.today
                    ? const Color(0xFFE2C862)
                    : FollowSkyV11Tokens.calendarDay,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 10.5,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 3,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final color in value.eventColors.take(4)) ...[
                    Container(
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
        ),
      ],
    );
  }
}
