import 'dart:math';

import '../domain/sky_catalog.dart';
import '../domain/track_sky_course.dart';
import 'sky_visibility_service.dart';
import 'track_sky_course_metadata_codec.dart';
import 'track_sky_course_source_identity.dart';
import 'track_sky_course_source_resolver.dart';
import 'track_sky_materializer.dart';

enum FollowSkyProductChoice {
  keepCourse,
  giveMoreRoom,
  changeCourse,
}

extension FollowSkyProductChoiceX on FollowSkyProductChoice {
  String get label {
    switch (this) {
      case FollowSkyProductChoice.keepCourse:
        return 'Keep course';
      case FollowSkyProductChoice.giveMoreRoom:
        return 'Give it more room';
      case FollowSkyProductChoice.changeCourse:
        return 'Change course';
    }
  }
}

class TrackSkyEnrollmentDraft {
  const TrackSkyEnrollmentDraft({
    required this.flowNotes,
    required this.occurrences,
    required this.ianaTimeZone,
    this.course,
  });

  final String flowNotes;
  final List<MaterializedSkyOccurrence> occurrences;
  final String ianaTimeZone;
  final TrackSkyCourse? course;
}

typedef TrackSkyIdGenerator = String Function();

/// Feature-specific enrollment orchestration. Depends on injected upserts, not V1.
class TrackSkyEnrollmentService {
  TrackSkyEnrollmentService({
    required this.materializer,
    required this.visibilityService,
    TrackSkyCourseMetadataCodec? codec,
    TrackSkyIdGenerator? courseIdGenerator,
  })  : codec = codec ?? TrackSkyCourseMetadataCodec(),
        courseIdGenerator = courseIdGenerator ?? _defaultCourseId;

  final TrackSkyMaterializer materializer;
  final SkyVisibilityService visibilityService;
  final TrackSkyCourseMetadataCodec codec;
  final TrackSkyIdGenerator courseIdGenerator;

  static String _defaultCourseId() {
    final ms = DateTime.now().toUtc().microsecondsSinceEpoch;
    final r = Random(ms).nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'course-$ms-$r';
  }

  TrackSkyCourse createCourse({
    required String label,
    required TrackSkyCourseSourceType sourceType,
    String? sourceId,
    DateTime? createdAt,
  }) {
    return TrackSkyCourse(
      courseId: courseIdGenerator(),
      label: label.trim(),
      sourceType: sourceType,
      sourceId: sourceId,
      createdAt: (createdAt ?? DateTime.now()).toUtc(),
    );
  }

  TrackSkyCourse createCourseFromCandidate(
    TrackSkyCourseCandidate candidate, {
    DateTime? createdAt,
  }) {
    return createCourse(
      label: candidate.label,
      sourceType: candidate.sourceType,
      sourceId: candidate.sourceId,
      createdAt: createdAt,
    );
  }

  String notesWithCourse({
    required String? existingNotes,
    required TrackSkyCourse course,
    String templateKey = 'track-the-sky',
    String? timezoneKey,
    String? overview,
  }) {
    var base = existingNotes ?? '';
    if (!base.contains('maat=')) {
      final parts = <String>[
        if (base.isNotEmpty) base,
        'mode=gregorian',
        'split=1',
        'maat=$templateKey',
        if (timezoneKey != null) 'sky_tz=$timezoneKey',
        if (overview != null && overview.trim().isNotEmpty)
          'ov=${Uri.encodeComponent(overview.trim())}',
      ];
      base = parts.where((p) => p.isNotEmpty).join(';');
    }
    return codec.encode(course, existingNotes: base);
  }

  String notesWithoutCourse({
    String templateKey = 'track-the-sky',
    String? timezoneKey,
    String? overview,
    String? existingNotes,
  }) {
    final map = <String, String>{
      'mode': 'gregorian',
      'split': '1',
      'maat': templateKey,
      'track_sky_schema': '2',
    };
    if (timezoneKey != null) map['sky_tz'] = timezoneKey;
    if (overview != null && overview.trim().isNotEmpty) {
      map['ov'] = Uri.encodeComponent(overview.trim());
    }
    // Preserve unrelated tokens from existing notes.
    if (existingNotes != null && existingNotes.isNotEmpty) {
      for (final part in existingNotes.split(';')) {
        final trimmed = part.trim();
        final eq = trimmed.indexOf('=');
        if (eq <= 0) continue;
        final key = trimmed.substring(0, eq).trim();
        if (key.startsWith('sky_course')) continue;
        if (map.containsKey(key)) continue;
        map[key] = trimmed.substring(eq + 1).trim();
      }
    }
    return map.entries.map((e) => '${e.key}=${e.value}').join(';');
  }

  TrackSkyEnrollmentDraft buildJoinDraft({
    required SkyCatalog catalog,
    required DateTime nowUtc,
    required String ianaTimeZone,
    String? timezoneKey,
    String? overview,
    TrackSkyCourse? course,
    bool hasObservingLocation = false,
  }) {
    final upcoming = catalog.upcoming(nowUtc: nowUtc);
    final occurrences = <MaterializedSkyOccurrence>[];
    for (final event in upcoming) {
      final decision = visibilityService.decide(
        event,
        hasObservingLocation: hasObservingLocation,
      );
      occurrences.add(
        materializer.materialize(
          event: event,
          ianaTimeZone: ianaTimeZone,
          visibilityNote: decision.userFacingNote,
        ),
      );
    }

    final notes = course == null
        ? [
            'mode=gregorian',
            'split=1',
            'maat=track-the-sky',
            if (timezoneKey != null) 'sky_tz=$timezoneKey',
            if (overview != null && overview.trim().isNotEmpty)
              'ov=${Uri.encodeComponent(overview.trim())}',
            'track_sky_schema=2',
          ].join(';')
        : notesWithCourse(
            existingNotes: null,
            course: course,
            timezoneKey: timezoneKey,
            overview: overview,
          );

    return TrackSkyEnrollmentDraft(
      flowNotes: notes,
      occurrences: occurrences,
      ianaTimeZone: ianaTimeZone,
      course: course,
    );
  }

  List<FollowSkyProductChoice> availableChoices({required bool hasCourse}) {
    if (!hasCourse) return const [];
    return FollowSkyProductChoice.values;
  }

  /// Validates linked flow source still points at the expected flow (gate 16).
  bool validateLinkedFlowSource({
    required TrackSkyCourse course,
    required int flowId,
    required String flowName,
  }) {
    if (course.sourceType != TrackSkyCourseSourceType.flow) return true;
    return TrackSkyCourseSourceIdentity.matchesFlow(
      sourceId: course.sourceId,
      flowId: flowId,
    );
  }

  /// Re-resolve course after hydration; missing source becomes free-text.
  TrackSkyCourse rehydrateCourse({
    required TrackSkyCourse course,
    required Map<int, HydratedFlowRef> flowsByServerId,
  }) {
    return const TrackSkyCourseSourceResolver().unlinkIfSourceMissing(
      course: course,
      flowsByServerId: flowsByServerId,
    );
  }
}
