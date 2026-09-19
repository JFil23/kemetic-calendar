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

/// How a flow-detail entry obtained this snapshot.
enum CalendarPreviewSupply {
  /// This entry cannot provide calendar data. Distinct from a loaded empty day.
  unavailable,

  /// A window was requested and coverage is not finished.
  loading,

  /// Coverage for the supplied window is complete. Rows may still be empty.
  loaded,
}

/// Per-date reading of [FollowSkyCalendarPreview].
enum MaatFlowDateCalendarState {
  unavailable,
  loading,
  outOfWindow,
  loadedEmpty,
  loaded,
}

String maatFlowDateCalendarLabel(MaatFlowDateCalendarState state) {
  return switch (state) {
    MaatFlowDateCalendarState.unavailable => 'Calendar context unavailable',
    MaatFlowDateCalendarState.loading => 'Loading calendar…',
    MaatFlowDateCalendarState.outOfWindow =>
      'Outside the loaded calendar window',
    MaatFlowDateCalendarState.loadedEmpty ||
    MaatFlowDateCalendarState.loaded => 'No other calendar entries',
  };
}

String maatFlowDateCalendarKeySuffix(MaatFlowDateCalendarState state) {
  return switch (state) {
    MaatFlowDateCalendarState.unavailable => 'unavailable',
    MaatFlowDateCalendarState.loading => 'loading',
    MaatFlowDateCalendarState.outOfWindow => 'out-of-window',
    MaatFlowDateCalendarState.loadedEmpty ||
    MaatFlowDateCalendarState.loaded => 'empty',
  };
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
    this.supply = CalendarPreviewSupply.loaded,
  });

  final List<FollowSkyCalendarPreviewRow> rows;
  final DateTime? windowStart;
  final DateTime? windowEnd;
  final List<CourseActivitySignal> candidates;
  final List<CourseMeasurementInterval> intervals;
  final bool coverageComplete;
  final CalendarPreviewSupply supply;

  /// Loaded window with no rows. Not the same as [unavailable].
  static const empty = FollowSkyCalendarPreview();

  /// This entry path cannot supply calendar context.
  static const unavailable = FollowSkyCalendarPreview(
    coverageComplete: false,
    supply: CalendarPreviewSupply.unavailable,
  );

  /// Window requested; rows are not yet authoritative.
  static const pending = FollowSkyCalendarPreview(
    coverageComplete: false,
    supply: CalendarPreviewSupply.loading,
  );

  bool get _hasWindow => windowStart != null && windowEnd != null;

  List<FollowSkyCalendarPreviewRow> rowsFor(DateTime date) {
    return rows
        .where((row) => DateUtils.isSameDay(row.localDay, date))
        .toList(growable: false);
  }

  MaatFlowDateCalendarState dateState(DateTime date) {
    final day = DateUtils.dateOnly(date);
    if (supply == CalendarPreviewSupply.unavailable) {
      return MaatFlowDateCalendarState.unavailable;
    }
    if (_hasWindow) {
      final start = DateUtils.dateOnly(windowStart!);
      final end = DateUtils.dateOnly(windowEnd!);
      if (day.isBefore(start) || day.isAfter(end)) {
        return MaatFlowDateCalendarState.outOfWindow;
      }
    }
    if (supply == CalendarPreviewSupply.loading || !coverageComplete) {
      return MaatFlowDateCalendarState.loading;
    }
    return rowsFor(day).isEmpty
        ? MaatFlowDateCalendarState.loadedEmpty
        : MaatFlowDateCalendarState.loaded;
  }
}
