import 'package:flutter/material.dart';

import '../../domain/sky_observing_night.dart';
import '../../../maat_flow_visual_tokens.dart';
import '../../../calendar_event_visual_style.dart';
import '../follow_sky_calendar_preview.dart';
import '../turning_meaning.dart';
import 'follow_sky_v11_tokens.dart';
import 'track_sky_event_block_visual.dart';

class FollowSkyPreviewCalendar extends StatelessWidget {
  const FollowSkyPreviewCalendar({
    super.key,
    required this.windowStart,
    required this.skyNights,
    required this.calendarRows,
    required this.excludedSkyEventIds,
    required this.carried,
    required this.draftIntentions,
    required this.onOpenSkyNight,
    required this.onExcludeSkyNight,
    required this.meaningResolver,
  });

  final DateTime windowStart;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final day in days) ...[
          _PreviewDayHeader(date: day.date, dots: day.dots),
          const SizedBox(height: 8),
          for (final row in day.rows) ...[
            if (row.isSky)
              _SkyPreviewCard(
                night: row.night!,
                excluded: excludedSkyEventIds.contains(row.night!.skyEventId),
                carried: carried,
                intention: draftIntentions[row.night!.skyEventId],
                onTap: () => onOpenSkyNight(row.night!),
                onExclude: () => onExcludeSkyNight(row.night!),
              )
            else
              _OrdinaryPreviewRow(row: row.calendar!),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  List<_PreviewDay> _groupedDays() {
    final start = DateUtils.dateOnly(windowStart);
    final byDay = <DateTime, _PreviewDayBuilder>{};
    for (var i = 0; i < 30; i++) {
      final day = start.add(Duration(days: i));
      byDay[day] = _PreviewDayBuilder(date: day);
    }

    for (final night in skyNights) {
      final local = DateUtils.dateOnly(night.localDay);
      byDay.putIfAbsent(local, () => _PreviewDayBuilder(date: local));
      byDay[local]!.rows.add(_PreviewRow.sky(night));
      byDay[local]!.dots.add(_PreviewDot.sky());
    }

    for (final row in calendarRows) {
      final local = DateUtils.dateOnly(row.localDay);
      if (!byDay.containsKey(local)) continue;
      byDay[local]!.rows.add(_PreviewRow.calendar(row));
      byDay[local]!.dots.add(_PreviewDot.event(row.eventColor));
    }

    return byDay.values
        .where((b) => b.rows.isNotEmpty)
        .map((b) => b.build())
        .toList();
  }
}

enum _PreviewDotKind { sky, event }

class _PreviewDot {
  const _PreviewDot._(this.kind, [this.color]);

  factory _PreviewDot.sky() => const _PreviewDot._(_PreviewDotKind.sky);
  factory _PreviewDot.event(Color color) =>
      _PreviewDot._(_PreviewDotKind.event, color);

  final _PreviewDotKind kind;
  final Color? color;
}

class _PreviewDay {
  const _PreviewDay({
    required this.date,
    required this.dots,
    required this.rows,
  });

  final DateTime date;
  final List<_PreviewDot> dots;
  final List<_PreviewRow> rows;
}

class _PreviewDayBuilder {
  _PreviewDayBuilder({required this.date});

  final DateTime date;
  final List<_PreviewDot> dots = [];
  final List<_PreviewRow> rows = [];

  _PreviewDay build() => _PreviewDay(date: date, dots: dots, rows: rows);
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
}

class _PreviewDayHeader extends StatelessWidget {
  const _PreviewDayHeader({required this.date, required this.dots});

  final DateTime date;
  final List<_PreviewDot> dots;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          _label(date),
          style: const TextStyle(
            color: FollowSkyV11Tokens.gold,
            fontFamily: MaatFlowListTokens.fontFamily,
            fontFamilyFallback: MaatFlowListTokens.fontFallback,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 10),
        for (final dot in dots.take(6))
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: dot.kind == _PreviewDotKind.sky
                  ? FollowSkyV11Tokens.intentionPeriwinkle
                  : dot.color ?? FollowSkyV11Tokens.silverMid,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }

  String _label(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}

class _OrdinaryPreviewRow extends StatelessWidget {
  const _OrdinaryPreviewRow({required this.row});

  final FollowSkyCalendarPreviewRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF120F08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2518)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 28,
            decoration: BoxDecoration(
              color: row.eventColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              row.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FollowSkyV11Tokens.silverHi,
                fontSize: 14,
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
    required this.excluded,
    required this.carried,
    required this.intention,
    required this.onTap,
    required this.onExclude,
  });

  final SkyObservingNight night;
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
    final preview = !carried;

    return GestureDetector(
      onTap: excluded ? null : onTap,
      child: Stack(
        children: [
          TrackSkyEventBlockVisual(
            title: title,
            graphic: graphic,
            height: 56,
            width: double.infinity,
            compact: true,
            isPreview: preview,
            dashedBorder: preview && !carried,
            opacity: excluded ? 0.35 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: graphic.titleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (intention != null && intention!.trim().isNotEmpty)
                  Text(
                    intention!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FollowSkyV11Tokens.intentionPeriwinkle,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          if (!carried && !excluded)
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: onExclude,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                    border: Border.all(color: FollowSkyV11Tokens.silverMid),
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

extension _SkyObservingNightLocalDay on SkyObservingNight {
  DateTime get localDay => primaryInstantUtc.toLocal();
}
