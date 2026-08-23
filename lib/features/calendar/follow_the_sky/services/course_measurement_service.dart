import '../domain/track_sky_course.dart';

class CourseMeasurement {
  const CourseMeasurement({
    required this.available,
    required this.recentMinutes,
    required this.previousMinutes,
    required this.recentOccurrences,
    required this.previousOccurrences,
    this.unavailableReason,
  });

  final bool available;
  final int recentMinutes;
  final int previousMinutes;
  final int recentOccurrences;
  final int previousOccurrences;
  final String? unavailableReason;

  double? get deltaFraction {
    if (!available || previousMinutes <= 0) return null;
    return (recentMinutes - previousMinutes) / previousMinutes;
  }

  static CourseMeasurement unavailable(String reason) => CourseMeasurement(
        available: false,
        recentMinutes: 0,
        previousMinutes: 0,
        recentOccurrences: 0,
        previousOccurrences: 0,
        unavailableReason: reason,
      );
}

class CourseMeasurementInterval {
  const CourseMeasurementInterval({
    required this.start,
    required this.end,
    required this.minutes,
  });

  final DateTime start;
  final DateTime end;
  final int minutes;
}

/// Measures course-attributed calendar intervals. Never invents history.
/// Free-text courses become measurable once Protect Time (or Connect) supplies intervals.
class CourseMeasurementService {
  const CourseMeasurementService();

  CourseMeasurement measure({
    required TrackSkyCourse course,
    required DateTime now,
    required List<CourseMeasurementInterval> intervals,
    Duration window = const Duration(days: 14),
  }) {
    // Intervals are pre-attributed by the host (Connect-linked source and/or
    // Protect-stamped blocks). Measure them even when the Course remains
    // free-text / unlinked via Connect.
    if (intervals.isEmpty) {
      return CourseMeasurement.unavailable(
        course.isLinked
            ? 'No protected time found for this course yet.'
            : 'Hꜣw will track the time you protect for this from here forward.',
      );
    }


    final currentStart = now.subtract(window);
    final previousStart = currentStart.subtract(window);

    var recentMinutes = 0;
    var previousMinutes = 0;
    var recentOcc = 0;
    var previousOcc = 0;

    for (final interval in intervals) {
      if (!interval.end.isAfter(previousStart) ||
          !interval.start.isBefore(now)) {
        continue;
      }
      // Attribute to current vs previous 14d by interval midpoint.
      final mid = interval.start.add(
        interval.end.difference(interval.start) ~/ 2,
      );
      if (!mid.isBefore(currentStart) && mid.isBefore(now)) {
        recentMinutes += interval.minutes;
        recentOcc += 1;
      } else if (!mid.isBefore(previousStart) && mid.isBefore(currentStart)) {
        previousMinutes += interval.minutes;
        previousOcc += 1;
      }
    }

    return CourseMeasurement(
      available: true,
      recentMinutes: recentMinutes,
      previousMinutes: previousMinutes,
      recentOccurrences: recentOcc,
      previousOccurrences: previousOcc,
    );
  }

  static String formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}
