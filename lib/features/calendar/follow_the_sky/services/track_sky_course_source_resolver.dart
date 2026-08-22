import '../domain/track_sky_course.dart';
import 'track_sky_course_source_identity.dart';

/// Minimal hydrated flow identity used for Gate 16 resolution.
///
/// Mirrors what [calendar_hydration_engine] reconstructs from Postgres `flows.id`:
/// the same bigint PK returned by `FlowsRepo.insert` / `.upsert` `.select().single()`.
class HydratedFlowRef {
  const HydratedFlowRef({
    required this.serverId,
    required this.name,
  });

  final int serverId;
  final String name;
}

enum CourseSourceResolveStatus {
  /// `flow:<serverId>` found in the hydrated catalog.
  linked,

  /// Free-text / event-title course (not a flow PK link).
  unlinkedByDesign,

  /// Persisted `flow:<serverId>` is missing/deleted — must NOT alias another flow.
  sourceMissing,
}

class CourseSourceResolveResult {
  const CourseSourceResolveResult({
    required this.status,
    required this.course,
    this.resolvedFlow,
  });

  final CourseSourceResolveStatus status;
  final TrackSkyCourse course;
  final HydratedFlowRef? resolvedFlow;

  bool get isLinked => status == CourseSourceResolveStatus.linked;
}

/// Gate 16: resolve persisted course sources after sync / rehydration / restore.
///
/// Contract:
/// 1. Linkage stores Postgres `flows.id` as `flow:<serverId>` (never a local-only
///    optimistic counter that can be remapped).
/// 2. After hydration, resolve **only** by that server id.
/// 3. If the id is absent, unlink safely — never attach by matching label/name.
class TrackSkyCourseSourceResolver {
  const TrackSkyCourseSourceResolver();

  /// Build a linked course from a **persisted** server flow row.
  /// Rejects non-positive ids (local placeholders are not durable).
  TrackSkyCourse courseFromPersistedServerFlow({
    required String courseId,
    required int serverFlowId,
    required String label,
    required DateTime createdAt,
  }) {
    return TrackSkyCourse(
      courseId: courseId,
      label: label,
      sourceType: TrackSkyCourseSourceType.flow,
      sourceId: TrackSkyCourseSourceIdentity.forFlow(serverFlowId),
      createdAt: createdAt.toUtc(),
    );
  }

  /// Resolve a decoded course against the hydrated same-user flow catalog.
  CourseSourceResolveResult resolve({
    required TrackSkyCourse course,
    required Map<int, HydratedFlowRef> flowsByServerId,
  }) {
    if (course.sourceType != TrackSkyCourseSourceType.flow) {
      return CourseSourceResolveResult(
        status: CourseSourceResolveStatus.unlinkedByDesign,
        course: course,
      );
    }

    final serverId = TrackSkyCourseSourceIdentity.tryParseFlowId(course.sourceId);
    if (serverId == null) {
      return CourseSourceResolveResult(
        status: CourseSourceResolveStatus.sourceMissing,
        course: _asUnlinked(course),
      );
    }

    final match = flowsByServerId[serverId];
    if (match == null) {
      // Critical: do not scan by name — a different flow with the same label
      // must never inherit this course linkage.
      return CourseSourceResolveResult(
        status: CourseSourceResolveStatus.sourceMissing,
        course: _asUnlinked(course),
      );
    }

    return CourseSourceResolveResult(
      status: CourseSourceResolveStatus.linked,
      course: course,
      resolvedFlow: match,
    );
  }

  /// Returns an unlinked free-text course when the persisted flow id is gone.
  TrackSkyCourse unlinkIfSourceMissing({
    required TrackSkyCourse course,
    required Map<int, HydratedFlowRef> flowsByServerId,
  }) {
    return resolve(course: course, flowsByServerId: flowsByServerId).course;
  }

  TrackSkyCourse _asUnlinked(TrackSkyCourse course) {
    return TrackSkyCourse(
      courseId: course.courseId,
      label: course.label,
      sourceType: TrackSkyCourseSourceType.freeText,
      sourceId: null,
      createdAt: course.createdAt,
      schemaVersion: course.schemaVersion,
    );
  }
}
