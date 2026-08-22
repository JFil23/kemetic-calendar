import '../domain/track_sky_course.dart';
import 'course_candidate_engine.dart';

/// Builds [CourseActivitySignal]s from plain calendar/flow snapshots (no V1).
class CourseActivitySnapshot {
  const CourseActivitySnapshot({
    required this.label,
    required this.sourceType,
    required this.sourceId,
    required this.startsAt,
    required this.endsAt,
    this.isHidden = false,
    this.isSystemOrMaat = false,
    this.isActive = true,
  });

  final String label;
  final TrackSkyCourseSourceType sourceType;
  final String sourceId;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isHidden;
  final bool isSystemOrMaat;
  final bool isActive;
}

class CourseActivityAggregator {
  const CourseActivityAggregator();

  List<CourseActivitySignal> aggregate({
    required List<CourseActivitySnapshot> snapshots,
    required DateTime now,
    Duration window = const Duration(days: 28),
    Duration halfWindow = const Duration(days: 14),
  }) {
    final from = now.subtract(window);
    final mid = now.subtract(halfWindow);
    final bySource = <String, _Acc>{};

    for (final snap in snapshots) {
      if (snap.endsAt.isBefore(from) || snap.startsAt.isAfter(now)) continue;
      final acc = bySource.putIfAbsent(
        snap.sourceId,
        () => _Acc(
          label: snap.label,
          sourceType: snap.sourceType,
          sourceId: snap.sourceId,
          isHidden: snap.isHidden,
          isSystemOrMaat: snap.isSystemOrMaat,
          isActive: snap.isActive,
        ),
      );
      final minutes = snap.endsAt.difference(snap.startsAt).inMinutes.abs();
      final midPoint = snap.startsAt.add(
        snap.endsAt.difference(snap.startsAt) ~/ 2,
      );
      acc.occurrenceCount += 1;
      if (!midPoint.isBefore(mid)) {
        acc.recentMinutes += minutes;
      } else {
        acc.previousMinutes += minutes;
      }
    }

    return [
      for (final acc in bySource.values)
        CourseActivitySignal(
          label: acc.label,
          sourceType: acc.sourceType,
          sourceId: acc.sourceId,
          occurrenceCount: acc.occurrenceCount,
          recentMinutes: acc.recentMinutes,
          previousMinutes: acc.previousMinutes,
          isHidden: acc.isHidden,
          isSystemOrMaat: acc.isSystemOrMaat,
          isActive: acc.isActive,
        ),
    ];
  }
}

class _Acc {
  _Acc({
    required this.label,
    required this.sourceType,
    required this.sourceId,
    required this.isHidden,
    required this.isSystemOrMaat,
    required this.isActive,
  });

  final String label;
  final TrackSkyCourseSourceType sourceType;
  final String sourceId;
  final bool isHidden;
  final bool isSystemOrMaat;
  final bool isActive;
  int occurrenceCount = 0;
  int recentMinutes = 0;
  int previousMinutes = 0;
}
