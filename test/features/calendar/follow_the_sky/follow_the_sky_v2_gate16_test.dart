import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';

/// Gate 16 integration proof:
/// local candidate → persisted server id → hydrate/sync → same flow;
/// missing source → safe unlink (never alias by name).
void main() {
  final codec = TrackSkyCourseMetadataCodec();
  const resolver = TrackSkyCourseSourceResolver();
  const measurement = CourseMeasurementService();

  /// Simulates Postgres insert returning a durable bigint PK.
  int simulateServerInsert({required int nextServerId}) => nextServerId;

  /// Simulates hydration on another device: server catalog → local refs.
  Map<int, HydratedFlowRef> simulateHydrate(List<HydratedFlowRef> serverRows) {
    return {for (final row in serverRows) row.serverId: row};
  }

  test(
    'candidate → server persist → hydrate/restore → resolves exact same flow',
    () {
      // Device A: user picks a candidate whose durable identity is the server PK
      // (after FlowsRepo.insert returns id from Postgres).
      const localOptimisticId = -7; // must never be persisted as source
      expect(
        () => TrackSkyCourseSourceIdentity.forFlow(localOptimisticId),
        throwsArgumentError,
      );

      final serverFlowId = simulateServerInsert(nextServerId: 184);
      final course = resolver.courseFromPersistedServerFlow(
        courseId: 'course-kung-fu',
        serverFlowId: serverFlowId,
        label: 'Kung Fu',
        createdAt: DateTime.utc(2026, 8, 22, 15),
      );
      expect(course.sourceId, 'flow:184');

      // Persist onto Follow the Sky notes (codec = notes backing store).
      final followSkyNotes = codec.encode(
        course,
        existingNotes: 'mode=gregorian;maat=track-the-sky;sky_tz=pacific',
      );

      // Device B / restore: hydrate flows from server rows (same ids).
      final hydratedFlows = simulateHydrate([
        const HydratedFlowRef(serverId: 184, name: 'Kung Fu'),
        const HydratedFlowRef(serverId: 200, name: 'Yoga'),
      ]);
      final decoded = codec.decode(followSkyNotes)!;
      final resolved = resolver.resolve(
        course: decoded,
        flowsByServerId: hydratedFlows,
      );

      expect(resolved.status, CourseSourceResolveStatus.linked);
      expect(resolved.resolvedFlow?.serverId, 184);
      expect(resolved.resolvedFlow?.name, 'Kung Fu');
      expect(resolved.course.isLinked, isTrue);

      // Rename on device B must not break linkage (id is durable, label is not).
      final renamedHydrate = simulateHydrate([
        const HydratedFlowRef(serverId: 184, name: 'Kung Fu — evenings'),
        const HydratedFlowRef(serverId: 200, name: 'Yoga'),
      ]);
      final stillLinked = resolver.resolve(
        course: decoded,
        flowsByServerId: renamedHydrate,
      );
      expect(stillLinked.status, CourseSourceResolveStatus.linked);
      expect(stillLinked.resolvedFlow?.serverId, 184);
    },
  );

  test(
    'missing/deleted source unlinks and never aliases another same-name flow',
    () {
      final course = resolver.courseFromPersistedServerFlow(
        courseId: 'course-kung-fu',
        serverFlowId: 184,
        label: 'Kung Fu',
        createdAt: DateTime.utc(2026, 8, 22, 15),
      );
      final notes = codec.encode(course);
      final decoded = codec.decode(notes)!;

      // Flow 184 deleted; a different flow reused the label.
      final hydrated = simulateHydrate([
        const HydratedFlowRef(serverId: 999, name: 'Kung Fu'),
        const HydratedFlowRef(serverId: 200, name: 'Yoga'),
      ]);

      final resolved = resolver.resolve(
        course: decoded,
        flowsByServerId: hydrated,
      );

      expect(resolved.status, CourseSourceResolveStatus.sourceMissing);
      expect(resolved.resolvedFlow, isNull);
      expect(resolved.course.sourceType, TrackSkyCourseSourceType.freeText);
      expect(resolved.course.sourceId, isNull);
      expect(resolved.course.isLinked, isFalse);
      expect(resolved.course.label, 'Kung Fu');

      // Measurement integrity: unlinked course must not invent history even if
      // intervals exist under the same label's other flow.
      final measure = measurement.measure(
        course: resolved.course,
        now: DateTime.utc(2026, 8, 22),
        intervals: [
          CourseMeasurementInterval(
            start: DateTime.utc(2026, 8, 20, 10),
            end: DateTime.utc(2026, 8, 20, 12),
            minutes: 120,
          ),
        ],
      );
      expect(measure.available, isFalse);
      expect(measure.recentMinutes, 0);
    },
  );

  test('enrollment rehydrateCourse applies the same unlink contract', () {
    final enrollment = TrackSkyEnrollmentService(
      materializer: TrackSkyMaterializer(
        toLocal: (utc, _) => utc.toLocal(),
        toUtc: (local, _) => local.toUtc(),
      ),
      visibilityService: const SkyVisibilityService(),
    );
    final course = resolver.courseFromPersistedServerFlow(
      courseId: 'c1',
      serverFlowId: 42,
      label: 'Madness',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final after = enrollment.rehydrateCourse(
      course: course,
      flowsByServerId: {
        99: const HydratedFlowRef(serverId: 99, name: 'Madness'),
      },
    );
    expect(after.isLinked, isFalse);
    expect(after.sourceType, TrackSkyCourseSourceType.freeText);
  });
}
