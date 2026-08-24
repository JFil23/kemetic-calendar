import 'package:flutter/material.dart';
import 'package:mobile/features/calendar/decan_metadata.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart';

import '../../../maat_flow_visual_tokens.dart';
import 'follow_sky_v11_tokens.dart';

class FollowSkyThirtyDayStrip extends StatelessWidget {
  const FollowSkyThirtyDayStrip({
    super.key,
    required this.windowStart,
    required this.dayCount = 30,
  });

  final DateTime windowStart;
  final int dayCount;

  @override
  Widget build(BuildContext context) {
    final segments = _segmentsForWindow();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Here they are.',
          style: TextStyle(
            color: FollowSkyV11Tokens.gold,
            fontFamily: MaatFlowListTokens.fontFamily,
            fontFamilyFallback: MaatFlowListTokens.fontFallback,
            fontSize: 28,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'In your next thirty days.',
          style: TextStyle(
            color: FollowSkyV11Tokens.silverHi,
            fontFamily: MaatFlowListTokens.fontFamily,
            fontFamilyFallback: MaatFlowListTokens.fontFallback,
            fontSize: 18,
            fontStyle: FontStyle.italic,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 18),
        ...segments.map(
          (segment) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _KemeticSegmentRow(segment: segment),
          ),
        ),
      ],
    );
  }

  List<_KemeticSegment> _segmentsForWindow() {
    final start = DateUtils.dateOnly(windowStart);
    final segments = <_KemeticSegment>[];
    _KemeticSegment? current;
    for (var i = 0; i < dayCount; i++) {
      final day = start.add(Duration(days: i));
      final k = KemeticMath.fromGregorian(day);
      final month = getMonthById(k.kMonth);
      final decanNames = DecanMetadata.decanNames[k.kMonth] ?? const ['I', 'II', 'III'];
      final decanIndex = ((k.kDay - 1) ~/ 10).clamp(0, 2);
      final decan = decanNames[decanIndex];
      final label = '${month.displayTransliteration} · Decan $decan';
      if (current != null && current.label == label) {
        current = current.copyWith(endDay: day);
      } else {
        if (current != null) segments.add(current);
        current = _KemeticSegment(label: label, startDay: day, endDay: day);
      }
    }
    if (current != null) segments.add(current);
    return segments;
  }
}

class _KemeticSegment {
  const _KemeticSegment({
    required this.label,
    required this.startDay,
    required this.endDay,
  });

  final String label;
  final DateTime startDay;
  final DateTime endDay;

  _KemeticSegment copyWith({DateTime? endDay}) => _KemeticSegment(
        label: label,
        startDay: startDay,
        endDay: endDay ?? this.endDay,
      );
}

class _KemeticSegmentRow extends StatelessWidget {
  const _KemeticSegmentRow({required this.segment});

  final _KemeticSegment segment;

  @override
  Widget build(BuildContext context) {
    final range = _formatRange(segment.startDay, segment.endDay);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 7, right: 10),
          decoration: const BoxDecoration(
            color: FollowSkyV11Tokens.gold,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                segment.label,
                style: const TextStyle(
                  color: FollowSkyV11Tokens.gold,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (range.isNotEmpty)
                Text(
                  range,
                  style: const TextStyle(
                    color: FollowSkyV11Tokens.silverMid,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatRange(DateTime start, DateTime end) {
    if (DateUtils.isSameDay(start, end)) {
      return _shortDate(start);
    }
    return '${_shortDate(start)} – ${_shortDate(end)}';
  }

  String _shortDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}
