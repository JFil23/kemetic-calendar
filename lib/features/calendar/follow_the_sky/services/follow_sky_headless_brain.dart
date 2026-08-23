import '../domain/sky_catalog.dart';
import '../domain/sky_event_function.dart';
import '../domain/track_sky_course.dart';
import 'course_candidate_engine.dart';
import 'course_function_service.dart';
import 'course_measurement_service.dart';
import 'track_sky_enrollment_service.dart';

/// Headless product brain for Cut 1 exit gate. No widgets. No V1 imports.
class FollowSkyHeadlessBrain {
  FollowSkyHeadlessBrain({
    required this.catalog,
    required this.candidateEngine,
    required this.measurementService,
    required this.enrollmentService,
  });

  final SkyCatalog catalog;
  final CourseCandidateEngine candidateEngine;
  final CourseMeasurementService measurementService;
  final TrackSkyEnrollmentService enrollmentService;

  String demonstrate({
    required List<CourseActivitySignal> signals,
    required TrackSkyCourse selectedCourse,
    required List<CourseMeasurementInterval> intervals,
    required DateTime nowUtc,
    String? locationLabel,
  }) {
    final candidates = candidateEngine.suggest(signals, now: nowUtc);
    final next = catalog.nextObservingNight(nowUtc: nowUtc);
    final measurement = measurementService.measure(
      course: selectedCourse,
      now: nowUtc,
      intervals: intervals,
    );
    final function = next?.function ?? SkyEventFunction.measure;
    final evidence = const CourseFunctionService().evidenceFor(
      function: function,
      course: selectedCourse,
      now: nowUtc,
      intervals: intervals,
    );
    final choices = enrollmentService.availableChoices(
      hasCourse: true,
      hasEvidenceObject: evidence.available,
      function: function,
    );

    final buf = StringBuffer();
    buf.writeln('Course candidates:');
    if (candidates.isEmpty) {
      buf.writeln('(none)');
    } else {
      for (final c in candidates) {
        buf.writeln('- ${c.label}');
      }
    }
    buf.writeln();
    buf.writeln('Selected course:');
    final linkTag = selectedCourse.isLinked ? 'linked' : 'unlinked';
    buf.writeln('${selectedCourse.label} [$linkTag]');
    buf.writeln();
    buf.writeln('Next turning:');
    if (next == null) {
      buf.writeln('(none)');
    } else {
      buf.writeln('${next.displayName} ${next.primaryInstantUtc.year}');
      buf.writeln('Function: ${next.function.displayLabel.toUpperCase()}');
    }
    buf.writeln();
    buf.writeln('Course measurement:');
    if (!measurement.available) {
      buf.writeln(measurement.unavailableReason ?? 'unavailable');
    } else {
      buf.writeln(
        'previous 14d: ${CourseMeasurementService.formatDuration(measurement.previousMinutes)}',
      );
      buf.writeln(
        'current 14d: ${CourseMeasurementService.formatDuration(measurement.recentMinutes)}',
      );
      final delta = measurement.deltaFraction;
      if (delta != null) {
        final pct = (delta * 100).toStringAsFixed(1);
        buf.writeln('delta: $pct%');
      }
    }
    buf.writeln();
    buf.writeln('Available product choices:');
    for (final c in choices) {
      buf.writeln('- ${c.label}');
    }
    if (locationLabel != null) {
      buf.writeln();
      buf.writeln('Context: $locationLabel');
    }
    return buf.toString().trimRight();
  }
}
