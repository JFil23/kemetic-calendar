import 'package:flutter/material.dart';

import '../../../calendar_event_visual_style.dart';
import '../../../kemetic_month_metadata.dart';
import '../../../maat_flow_visual_tokens.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart';
import '../../domain/sky_observing_night.dart';
import '../follow_sky_calendar_preview.dart';
import '../turning_meaning.dart';
import 'follow_sky_v11_tokens.dart';
import 'track_sky_event_block_visual.dart';

class FollowSkyPreviewCalendar extends StatelessWidget {
  const FollowSkyPreviewCalendar({
    super.key,
    required this.skyNights,
    required this.calendarRows,
    required this.excludedSkyEventIds,
    required this.carried,
    required this.draftIntentions,
    required this.onOpenSkyNight,
    required this.onExcludeSkyNight,
    required this.meaningResolver,
  });

  final List<SkyObservingNight> skyNights;
  final List<FollowSkyCalendarPreviewRow> calendarRows;
  final Set<String> excludedSkyEventIds;
  final bool carried;
  final Map<String, String> draftIntentions;
  final ValueChanged<SkyObservingNight> onOpenSkyNight;
  final ValueChanged<SkyObservingNight> onExcludeSkyNight;
  final TurningMeaningResolver meaningResolver;

  @override
  Widget build(BuildContext context) {
    final days = _groupedDays();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < days.length; i++) ...[
            _PreviewDayCard(
              day: days[i],
              excludedSkyEventIds: excludedSkyEventIds,
              carried: carried,
              draftIntentions: draftIntentions,
              meaningResolver: meaningResolver,
              onOpenSkyNight: onOpenSkyNight,
              onExcludeSkyNight: onExcludeSkyNight,
            ),
            if (i != days.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  List<_PreviewDay> _groupedDays() {
    final byDay = <DateTime, _PreviewDayBuilder>{};

    for (final night in skyNights) {
      final local = DateUtils.dateOnly(night.primaryInstantUtc.toLocal());
      byDay.putIfAbsent(local, () => _PreviewDayBuilder(date: local));
      byDay[local]!.rows.add(_PreviewRow.sky(night));
    }

    for (final row in calendarRows) {
      final local = DateUtils.dateOnly(row.localDay);
      byDay[local]?.rows.add(_PreviewRow.calendar(row));
    }

    final days = byDay.values.map((builder) => builder.build()).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return days;
  }
}

class _PreviewDay {
  const _PreviewDay({required this.date, required this.rows});

  final DateTime date;
  final List<_PreviewRow> rows;
}

class _PreviewDayBuilder {
  _PreviewDayBuilder({required this.date});

  final DateTime date;
  final List<_PreviewRow> rows = <_PreviewRow>[];

  _PreviewDay build() {
    rows.sort((a, b) => a.start.compareTo(b.start));
    return _PreviewDay(date: date, rows: List<_PreviewRow>.unmodifiable(rows));
  }
}

class _PreviewRow {
  const _PreviewRow._({this.night, this.calendar});

  factory _PreviewRow.sky(SkyObservingNight night) =>
      _PreviewRow._(night: night);
  factory _PreviewRow.calendar(FollowSkyCalendarPreviewRow row) =>
      _PreviewRow._(calendar: row);

  final SkyObservingNight? night;
  final FollowSkyCalendarPreviewRow? calendar;

  bool get isSky => night != null;
  DateTime get start => night?.primaryInstantUtc.toLocal() ?? calendar!.start;
}

class _PreviewDayCard extends StatelessWidget {
  const _PreviewDayCard({
    required this.day,
    required this.excludedSkyEventIds,
    required this.carried,
    required this.draftIntentions,
    required this.meaningResolver,
    required this.onOpenSkyNight,
    required this.onExcludeSkyNight,
  });

  final _PreviewDay day;
  final Set<String> excludedSkyEventIds;
  final bool carried;
  final Map<String, String> draftIntentions;
  final TurningMeaningResolver meaningResolver;
  final ValueChanged<SkyObservingNight> onOpenSkyNight;
  final ValueChanged<SkyObservingNight> onExcludeSkyNight;

  @override
  Widget build(BuildContext context) {
    final kemetic = KemeticMath.fromGregorian(day.date);
    final month = getMonthById(kemetic.kMonth);
    return Container(
      key: ValueKey<String>('follow-sky-preview-day-${_dateKey(day.date)}'),
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 7),
      decoration: BoxDecoration(
        color: FollowSkyV11Tokens.calendarPreview,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x38C4A64A)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06C4A64A),
            offset: Offset(0, 1),
            blurRadius: 0,
          ),
        ],
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
                  style: const TextStyle(
                    color: FollowSkyV11Tokens.calendarAntique,
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontFamilyFallback: MaatFlowListTokens.fontFallback,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                _gregorianLabel(day.date),
                maxLines: 1,
                style: const TextStyle(
                  color: FollowSkyV11Tokens.calendarGregorian,
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
          for (var i = 0; i < day.rows.length; i++) ...[
            if (i > 0) const Divider(color: Color(0x26C4A64A), height: 1),
            if (day.rows[i].isSky)
              _SkyPreviewCard(
                night: day.rows[i].night!,
                meaning: meaningResolver.forNight(day.rows[i].night!),
                excluded: excludedSkyEventIds.contains(
                  day.rows[i].night!.skyEventId,
                ),
                carried: carried,
                intention: draftIntentions[day.rows[i].night!.skyEventId],
                onTap: () => onOpenSkyNight(day.rows[i].night!),
                onExclude: () => onExcludeSkyNight(day.rows[i].night!),
              )
            else
              _OrdinaryPreviewRow(row: day.rows[i].calendar!),
          ],
        ],
      ),
    );
  }

  String _gregorianLabel(DateTime d) {
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
    return '${weekdays[d.weekday - 1]} · ${months[d.month - 1]} ${d.day}';
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _OrdinaryPreviewRow extends StatelessWidget {
  const _OrdinaryPreviewRow({required this.row});

  final FollowSkyCalendarPreviewRow row;

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
                color: row.eventColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                row.allDay ? 'All day' : _formatTime(row.start),
                style: const TextStyle(
                  color: FollowSkyV11Tokens.silverMid,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              row.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FollowSkyV11Tokens.silverHi,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkyPreviewCard extends StatelessWidget {
  const _SkyPreviewCard({
    required this.night,
    required this.meaning,
    required this.excluded,
    required this.carried,
    required this.intention,
    required this.onTap,
    required this.onExclude,
  });

  final SkyObservingNight night;
  final TurningMeaning meaning;
  final bool excluded;
  final bool carried;
  final String? intention;
  final VoidCallback onTap;
  final VoidCallback onExclude;

  @override
  Widget build(BuildContext context) {
    final title = night.displayName;
    final visual = resolveCalendarEventVisualStyle(
      eventColor: FollowSkyV11Tokens.intentionPeriwinkle,
      flowName: 'Follow the sky',
      eventTitle: title,
    );
    final graphic = visual.graphic!;
    final hasIntention = intention?.trim().isNotEmpty == true;
    final height = hasIntention ? 126.0 : 100.0;

    return GestureDetector(
      key: ValueKey<String>('follow-sky-preview-${night.skyEventId}'),
      onTap: excluded ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Stack(
          children: [
            TrackSkyEventBlockVisual(
              title: title,
              graphic: graphic,
              height: height,
              width: double.infinity,
              compact: false,
              isPreview: !carried,
              dashedBorder: !carried,
              opacity: excluded ? 0.20 : 1,
              child: Padding(
                padding: const EdgeInsets.only(right: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        color: carried
                            ? FollowSkyV11Tokens.intentionPeriwinkle
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: FollowSkyV11Tokens.glow,
                          width: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    SizedBox(
                      width: 56,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(
                          _formatTime(night.primaryInstantUtc.toLocal()),
                          style: TextStyle(
                            color: FollowSkyV11Tokens.glow.withValues(
                              alpha: 0.72,
                            ),
                            fontFamily: MaatFlowListTokens.fontFamily,
                            fontFamilyFallback: MaatFlowListTokens.fontFallback,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: graphic.titleColor,
                                fontFamily: MaatFlowListTokens.fontFamily,
                                fontFamilyFallback:
                                    MaatFlowListTokens.fontFallback,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _meaningLine(meaning),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: FollowSkyV11Tokens.silverMid,
                                fontFamily: MaatFlowListTokens.fontFamily,
                                fontFamilyFallback:
                                    MaatFlowListTokens.fontFallback,
                                fontSize: 14.5,
                                fontStyle: FontStyle.italic,
                                height: 1.25,
                              ),
                            ),
                            if (hasIntention) ...[
                              const SizedBox(height: 7),
                              Text(
                                '“${intention!.trim()}”',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: FollowSkyV11Tokens.silverHi,
                                  fontFamily: MaatFlowListTokens.fontFamily,
                                  fontFamilyFallback:
                                      MaatFlowListTokens.fontFallback,
                                  fontSize: 14.5,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!carried && !excluded)
              Positioned(
                top: 6,
                right: 6,
                child: IconButton(
                  key: ValueKey<String>(
                    'follow-sky-exclude-${night.skyEventId}',
                  ),
                  tooltip: 'Remove $title from this course',
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: onExclude,
                  icon: const Icon(
                    Icons.close,
                    size: 14,
                    color: FollowSkyV11Tokens.silverLo,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _meaningLine(TurningMeaning value) {
    if (value.significanceLabel == 'ENDURE') {
      return 'Endure · stay true when conditions change.';
    }
    final label = value.significanceLabel.toLowerCase();
    final titled = '${label[0].toUpperCase()}${label.substring(1)}';
    return '$titled · ${value.observation}';
  }
}

String _formatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}
