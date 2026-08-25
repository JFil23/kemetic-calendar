import '../domain/sky_event_function.dart';
import '../domain/track_sky_course.dart';
import 'course_measurement_service.dart';

/// Function-specific service copy for a turning — not a generic measurement dump.
class CourseFunctionEvidence {
  const CourseFunctionEvidence({
    required this.available,
    required this.lead,
    required this.body,
    this.unavailableReason,
  });

  final bool available;
  final String lead;
  final String body;
  final String? unavailableReason;

  static CourseFunctionEvidence unavailable(String reason) =>
      CourseFunctionEvidence(
        available: false,
        lead: '',
        body: '',
        unavailableReason: reason,
      );
}

/// Builds the human-facing service for each system function from real intervals.
///
/// Course ownership establishes relevance; event-function rules decide evidence.
/// Protect-stamped time counts for Measure (and Turn summary). It does **not**
/// by itself qualify as Reconsider (deferred/carried-forward) or Reveal
/// (unfinished/open) evidence.
class CourseFunctionService {
  const CourseFunctionService({
    this.measurement = const CourseMeasurementService(),
  });

  final CourseMeasurementService measurement;

  CourseFunctionEvidence evidenceFor({
    required SkyEventFunction function,
    required TrackSkyCourse course,
    required DateTime now,
    required List<CourseMeasurementInterval> intervals,
  }) {
    switch (function) {
      case SkyEventFunction.measure:
        return _measure(course: course, now: now, intervals: intervals);
      case SkyEventFunction.reconsider:
        return _reconsider(course: course, now: now, intervals: intervals);
      case SkyEventFunction.reveal:
        return _reveal(course: course, now: now, intervals: intervals);
      case SkyEventFunction.turn:
        return _turn(course: course, now: now, intervals: intervals);
      case SkyEventFunction.attend:
        return const CourseFunctionEvidence(
          available: true,
          lead: 'Attend.',
          body:
              'Not every turning asks you to do more. Make room to watch — nothing to optimize.',
        );
    }
  }

  CourseFunctionEvidence _measure({
    required TrackSkyCourse course,
    required DateTime now,
    required List<CourseMeasurementInterval> intervals,
  }) {
    final m = measurement.measure(
      course: course,
      now: now,
      intervals: intervals,
    );
    if (!m.available) {
      return CourseFunctionEvidence.unavailable(
        'No calendar activity connected yet',
      );
    }
    final hasTrackedTime = m.recentMinutes + m.previousMinutes > 0 ||
        m.recentOccurrences + m.previousOccurrences > 0;
    if (!hasTrackedTime) {
      return CourseFunctionEvidence.unavailable(
        'No calendar activity connected yet',
      );
    }
    return CourseFunctionEvidence(
      available: true,
      lead: '',
      body:
          'Previous 14 days: ${CourseMeasurementService.formatDuration(m.previousMinutes)}\n'
          'Current 14 days: ${CourseMeasurementService.formatDuration(m.recentMinutes)}',
    );
  }

  CourseFunctionEvidence _reconsider({
    required TrackSkyCourse course,
    required DateTime now,
    required List<CourseMeasurementInterval> intervals,
  }) {
    // Protect-owned blocks prove time was given; they are not automatically a
    // deferred/carried-forward object. Reconsider still needs Connect-linked
    // (or future explicit deferred) activity.
    if (!course.isLinked) {
      return CourseFunctionEvidence.unavailable(
        'There isn’t a specific carried-forward object for Hꜣw to reconsider yet.',
      );
    }
    final stats = _stats(intervals: intervals, now: now);
    if (stats.occurrenceCount == 0) {
      return CourseFunctionEvidence.unavailable(
        'There isn’t any Hꜣw activity connected to this course yet.',
      );
    }

    // Choices require a concrete carry-forward object — not thin activity.
    if (stats.weeksSpanned >= 3 && stats.totalMinutes >= 60) {
      return CourseFunctionEvidence(
        available: true,
        lead:
            '“${course.label}” has stayed with you across ${stats.weeksSpanned} weeks.',
        body:
            'You protected ${CourseMeasurementService.formatDuration(stats.totalMinutes)} for it, and it keeps moving forward.',
      );
    }
    if (stats.occurrenceCount >= 3) {
      return CourseFunctionEvidence(
        available: true,
        lead:
            '“${course.label}” has moved forward ${stats.occurrenceCount} times.',
        body: 'Hꜣw noticed it in the time you actually scheduled.',
      );
    }
    return CourseFunctionEvidence.unavailable(
      'There isn’t a specific carry-forward object for Hꜣw to reconsider yet.',
    );
  }

  CourseFunctionEvidence _reveal({
    required TrackSkyCourse course,
    required DateTime now,
    required List<CourseMeasurementInterval> intervals,
  }) {
    // Protect-owned blocks are not automatically an unfinished/open Reveal object.
    if (!course.isLinked) {
      return CourseFunctionEvidence.unavailable(
        'There isn’t a specific unfinished object for Hꜣw to reveal yet.',
      );
    }
    final stats = _stats(intervals: intervals, now: now);
    if (stats.occurrenceCount == 0) {
      return CourseFunctionEvidence.unavailable(
        'Nothing unfinished is visible in recent calendar time for this course.',
      );
    }
    return CourseFunctionEvidence(
      available: true,
      lead: 'Reveal.',
      body: stats.weeksSpanned >= 2
          ? 'One thread of “${course.label}” has followed you across ${stats.weeksSpanned} weeks. Finish it, show it, or finally name it.'
          : 'Hꜣw surfaces “${course.label}” as something still open in the time you scheduled.',
    );
  }

  CourseFunctionEvidence _turn({
    required TrackSkyCourse course,
    required DateTime now,
    required List<CourseMeasurementInterval> intervals,
  }) {
    final stats = _stats(intervals: intervals, now: now);
    return CourseFunctionEvidence(
      available: true,
      lead: 'Turn.',
      body: stats.totalMinutes > 0
          ? 'This season held ${CourseMeasurementService.formatDuration(stats.totalMinutes)} for “${course.label}”. Choose what deserves the next season.'
          : 'Choose what deserves the next season — without inventing meaning you did not choose.',
    );
  }

  ({int occurrenceCount, int totalMinutes, int weeksSpanned}) _stats({
    required List<CourseMeasurementInterval> intervals,
    required DateTime now,
  }) {
    final from = now.subtract(const Duration(days: 42));
    final weekKeys = <String>{};
    var count = 0;
    var minutes = 0;
    for (final interval in intervals) {
      if (!interval.end.isAfter(from) || !interval.start.isBefore(now)) {
        continue;
      }
      count += 1;
      minutes += interval.minutes;
      final mid = interval.start.add(
        interval.end.difference(interval.start) ~/ 2,
      );
      final weekStart = mid.subtract(Duration(days: mid.weekday - 1));
      weekKeys.add(
        '${weekStart.year}-${weekStart.month}-${weekStart.day}',
      );
    }
    return (
      occurrenceCount: count,
      totalMinutes: minutes,
      weeksSpanned: weekKeys.isEmpty ? 0 : weekKeys.length,
    );
  }
}
