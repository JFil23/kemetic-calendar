import 'package:flutter/material.dart';

import '../services/course_candidate_engine.dart';
import '../services/course_measurement_service.dart';

/// Read-only calendar row for Follow Sky's upcoming-turning preview.
@immutable
class FollowSkyCalendarPreviewRow {
  const FollowSkyCalendarPreviewRow({
    required this.localDay,
    required this.start,
    required this.end,
    required this.title,
    required this.eventColor,
    this.eventId,
    this.flowName,
    this.allDay = false,
  });

  final DateTime localDay;
  final DateTime start;
  final DateTime end;
  final String title;
  final Color eventColor;
  final String? eventId;
  final String? flowName;
  final bool allDay;
}

/// Hydrated calendar snapshot passed from [CalendarPageState].
@immutable
class FollowSkyCalendarPreview {
  const FollowSkyCalendarPreview({
    this.rows = const [],
    this.windowStart,
    this.windowEnd,
    this.candidates = const [],
    this.intervals = const [],
    this.coverageComplete = true,
  });

  final List<FollowSkyCalendarPreviewRow> rows;
  final DateTime? windowStart;
  final DateTime? windowEnd;
  final List<CourseActivitySignal> candidates;
  final List<CourseMeasurementInterval> intervals;
  final bool coverageComplete;

  static const empty = FollowSkyCalendarPreview();
}
