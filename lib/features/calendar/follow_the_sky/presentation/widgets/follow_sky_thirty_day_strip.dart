import 'package:flutter/material.dart';

import '../../../presentation/maat_flow_thirty_day_calendar.dart';
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
    return MaatFlowThirtyDayCalendar(
      windowStart: windowStart,
      markers: _markers(),
      theme: FollowSkyV11Tokens.thirtyDayCalendarTheme,
      introFirstLine: 'Here they are.',
      introSecondLine: 'In your next thirty days.',
      keyPrefix: 'follow-sky-strip',
      dayCount: dayCount,
    );
  }

  List<MaatFlowThirtyDayMarker> _markers() {
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

    return [
      for (var offset = 0; offset < dayCount; offset++)
        () {
          final date = start.add(Duration(days: offset));
          final skyIds = skyIdsByDay[date] ?? const <String>[];
          return MaatFlowThirtyDayMarker(
            date: date,
            isToday: offset == 0,
            highlighted: skyIds.any((id) => !excludedSkyEventIds.contains(id)),
            filled: carried,
            accent: FollowSkyV11Tokens.intentionPeriwinkle,
            secondaryColors: eventColorsByDay[date] ?? const <Color>[],
          );
        }(),
    ];
  }
}
