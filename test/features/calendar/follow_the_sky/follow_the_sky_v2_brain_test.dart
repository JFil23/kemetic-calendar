import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';

void main() {
  late SkyCatalog catalog;

  setUpAll(() {
    final file = File('assets/follow_the_sky/sky_catalog_v2.json');
    catalog = SkyCatalogRepository.parseJsonString(file.readAsStringSync());
  });

  group('SkyCatalog', () {
    test('loads 18-month coverage with stable ids and sources', () {
      expect(catalog.schemaVersion, 2);
      expect(catalog.events, isNotEmpty);
      expect(catalog.coverageStart.isBefore(catalog.coverageEnd), isTrue);
      for (final e in catalog.events) {
        expect(e.id, isNotEmpty);
        expect(e.source, isNotEmpty);
        expect(e.sourceVersion, isNotEmpty);
        expect(() => e.primaryInstantUtc, returnsNormally);
      }
      final ids = catalog.events.map((e) => e.id).toSet();
      expect(ids.length, catalog.events.length);
    });

    test('autumn equinox 2026 is MEASURE', () {
      final e = catalog.byId('autumn-equinox-2026');
      expect(e, isNotNull);
      expect(e!.function, SkyEventFunction.measure);
      expect(e.kind, SkyEventKind.equinox);
    });

    test('solar eclipses are location-gated', () {
      final e = catalog.byId('solar-eclipse-2028-01-26');
      expect(e, isNotNull);
      expect(e!.visibilityPolicy, SkyVisibilityPolicy.locationGated);
    });

    test('merged lunar eclipses are not materializable rows', () {
      expect(catalog.byId('lunar-eclipse-2026-08-28')?.mergedIntoId, isNotNull);
      expect(
        catalog.materializableEvents.any((e) => e.id == 'lunar-eclipse-2026-08-28'),
        isFalse,
      );
      expect(
        catalog.materializableEvents.any((e) => e.id == 'full-moon-2026-08-28'),
        isTrue,
      );
    });

    test('eclipse Full Moon nights resolve to Reconsider not Reveal', () {
      const merged = <(String eclipseId, String fullMoonId, String title)>[
        (
          'lunar-eclipse-2026-08-28',
          'full-moon-2026-08-28',
          'Full Moon + Partial Lunar Eclipse',
        ),
        (
          'lunar-eclipse-2027-02-20',
          'full-moon-2027-02-20',
          'Full Moon + Penumbral Lunar Eclipse',
        ),
        (
          'lunar-eclipse-2027-07-18',
          'full-moon-2027-07-18',
          'Full Moon + Slight Penumbral Lunar Eclipse',
        ),
        (
          'lunar-eclipse-2027-08-17',
          'full-moon-2027-08-17',
          'Full Moon + Penumbral Lunar Eclipse',
        ),
        (
          'lunar-eclipse-2028-01-12',
          'full-moon-2028-01-12',
          'Full Moon + Partial Lunar Eclipse',
        ),
      ];
      expect(catalog.events.length, 70);
      expect(catalog.observingNightCount, 65);
      expect(catalog.eclipseFullMoonNightCount, 5);

      for (final row in merged) {
        final anchor = catalog.byId(row.$2)!;
        // Raw catalog fact still Reveal — that is the defect without resolution.
        expect(anchor.function, SkyEventFunction.reveal);

        final night = catalog.observingNight(anchor);
        expect(night.companion?.id, row.$1);
        expect(night.function, SkyEventFunction.reconsider);
        expect(night.serviceKind, SkyEventKind.lunarEclipse);
        expect(night.displayName, row.$3);
        expect(night.skyEventId, row.$2);
      }

      // Ordinary Full Moon stays Reveal.
      final plain = catalog.observingNight(catalog.byId('full-moon-2026-09-26')!);
      expect(plain.companion, isNull);
      expect(plain.function, SkyEventFunction.reveal);
      expect(plain.displayName, 'Full Moon');
    });
  });

  group('SkyVisibilityService', () {
    const service = SkyVisibilityService();

    test('timezone alone cannot claim solar eclipse visibility', () {
      final e = catalog.byId('solar-eclipse-2027-08-02')!;
      final d = service.decide(e, hasObservingLocation: false);
      expect(d.canClaimLocalVisibility, isFalse);
      expect(d.promptObservation, isFalse);
      expect(d.userFacingNote.toLowerCase(), contains('visibility depends'));
    });

    test('global full moon can claim visibility', () {
      final e = catalog.byId('full-moon-2026-09-26')!;
      final d = service.decide(e);
      expect(d.canClaimLocalVisibility, isTrue);
    });
  });

  group('CourseCandidateEngine', () {
    const engine = CourseCandidateEngine();

    test('returns top user-authored labels and excludes system/hidden', () {
      final out = engine.suggest([
        const CourseActivitySignal(
          label: 'Work',
          sourceType: TrackSkyCourseSourceType.flow,
          sourceId: 'flow:1',
          occurrenceCount: 20,
          recentMinutes: 600,
          previousMinutes: 600,
        ),
        const CourseActivitySignal(
          label: 'Kung Fu',
          sourceType: TrackSkyCourseSourceType.flow,
          sourceId: 'flow:2',
          occurrenceCount: 6,
          recentMinutes: 180,
          previousMinutes: 360,
        ),
        const CourseActivitySignal(
          label: 'Kettlebell',
          sourceType: TrackSkyCourseSourceType.eventTitle,
          sourceId: 'event_title:kettlebell',
          occurrenceCount: 4,
          recentMinutes: 120,
          previousMinutes: 120,
        ),
        const CourseActivitySignal(
          label: 'Dental appointment',
          sourceType: TrackSkyCourseSourceType.eventTitle,
          sourceId: 'event_title:dental appointment',
          occurrenceCount: 1,
          recentMinutes: 60,
          previousMinutes: 0,
        ),
        const CourseActivitySignal(
          label: 'Follow the Sky',
          sourceType: TrackSkyCourseSourceType.flow,
          sourceId: 'flow:9',
          occurrenceCount: 5,
          recentMinutes: 300,
          previousMinutes: 300,
          isSystemOrMaat: true,
        ),
      ]);
      expect(out.map((e) => e.label).toList(), containsAll(['Work', 'Kung Fu', 'Kettlebell']));
      expect(out.any((e) => e.label == 'Dental appointment'), isFalse);
      expect(out.any((e) => e.label == 'Follow the Sky'), isFalse);
      expect(out.length, lessThanOrEqualTo(4));
    });

    test('fewer than 2 strong candidates yields empty list', () {
      final out = engine.suggest([
        const CourseActivitySignal(
          label: 'Only One',
          sourceType: TrackSkyCourseSourceType.flow,
          sourceId: 'flow:1',
          occurrenceCount: 5,
          recentMinutes: 100,
          previousMinutes: 100,
        ),
      ]);
      expect(out, isEmpty);
    });

    test('boosts drifted courses toward the front', () {
      final out = engine.suggest([
        const CourseActivitySignal(
          label: 'Stable',
          sourceType: TrackSkyCourseSourceType.flow,
          sourceId: 'flow:1',
          occurrenceCount: 4,
          recentMinutes: 200,
          previousMinutes: 200,
        ),
        const CourseActivitySignal(
          label: 'The Madness',
          sourceType: TrackSkyCourseSourceType.flow,
          sourceId: 'flow:2',
          occurrenceCount: 4,
          recentMinutes: 120,
          previousMinutes: 360,
        ),
        const CourseActivitySignal(
          label: 'Kettlebell',
          sourceType: TrackSkyCourseSourceType.eventTitle,
          sourceId: 'event_title:kettlebell',
          occurrenceCount: 3,
          recentMinutes: 90,
          previousMinutes: 90,
        ),
      ]);
      expect(out.first.label, 'The Madness');
    });
  });

  group('CourseMeasurementService', () {
    const service = CourseMeasurementService();

    test('unlinked course with no intervals never invents history', () {
      final course = TrackSkyCourse(
        courseId: 'c1',
        label: 'Be present',
        sourceType: TrackSkyCourseSourceType.freeText,
        createdAt: DateTime.utc(2026, 8, 22),
      );
      final m = service.measure(
        course: course,
        now: DateTime.utc(2026, 8, 22),
        intervals: const [],
      );
      expect(m.available, isFalse);
      expect(m.recentMinutes, 0);
    });

    test('unlinked course measures host-attributed Protect intervals', () {
      final course = TrackSkyCourse(
        courseId: 'c1',
        label: 'Finish my book',
        sourceType: TrackSkyCourseSourceType.freeText,
        createdAt: DateTime.utc(2026, 8, 1),
      );
      final now = DateTime.utc(2026, 8, 22, 12);
      final m = service.measure(
        course: course,
        now: now,
        intervals: [
          CourseMeasurementInterval(
            start: DateTime.utc(2026, 8, 20, 19),
            end: DateTime.utc(2026, 8, 20, 20),
            minutes: 60,
          ),
        ],
      );
      expect(m.available, isTrue);
      expect(m.recentMinutes, 60);
    });

    test('linked course measures from intervals', () {
      final course = TrackSkyCourse(
        courseId: 'c1',
        label: 'The Madness',
        sourceType: TrackSkyCourseSourceType.flow,
        sourceId: TrackSkyCourseSourceIdentity.forFlow(184),
        createdAt: DateTime.utc(2026, 8, 22),
      );
      final now = DateTime.utc(2026, 8, 22, 12);
      final m = service.measure(
        course: course,
        now: now,
        intervals: [
          // current 14d: 3h15m
          CourseMeasurementInterval(
            start: DateTime.utc(2026, 8, 20, 10),
            end: DateTime.utc(2026, 8, 20, 13, 15),
            minutes: 195,
          ),
          // previous 14d: 6h
          CourseMeasurementInterval(
            start: DateTime.utc(2026, 8, 5, 10),
            end: DateTime.utc(2026, 8, 5, 16),
            minutes: 360,
          ),
        ],
      );
      expect(m.available, isTrue);
      expect(m.recentMinutes, 195);
      expect(m.previousMinutes, 360);
      expect(m.deltaFraction, closeTo(-0.458, 0.01));
    });
  });

  group('TrackSkyCourseMetadataCodec', () {
    final codec = TrackSkyCourseMetadataCodec();

    test('round-trips and preserves unrelated notes', () {
      final course = TrackSkyCourse(
        courseId: 'course-abc',
        label: 'Kung Fu',
        sourceType: TrackSkyCourseSourceType.flow,
        sourceId: TrackSkyCourseSourceIdentity.forFlow(184),
        createdAt: DateTime.utc(2026, 8, 22, 13, 0),
      );
      final notes = codec.encode(
        course,
        existingNotes: 'mode=gregorian;split=1;maat=track-the-sky;sky_tz=pacific',
      );
      expect(notes, contains('maat=track-the-sky'));
      expect(notes, contains('sky_tz=pacific'));
      final decoded = codec.decode(notes);
      expect(decoded?.label, 'Kung Fu');
      expect(decoded?.sourceId, 'flow:184');
      expect(decoded?.courseId, 'course-abc');
    });

    test('malformed notes return null', () {
      expect(codec.decode('mode=gregorian;sky_course=OnlyLabel'), isNull);
    });
  });

  group('TrackSkyCourseSourceIdentity', () {
    test('flow id wire format is stable and parseable', () {
      final id = TrackSkyCourseSourceIdentity.forFlow(184);
      expect(id, 'flow:184');
      expect(TrackSkyCourseSourceIdentity.tryParseFlowId(id), 184);
      expect(
        TrackSkyCourseSourceIdentity.matchesFlow(
          sourceId: id,
          flowId: 184,
        ),
        isTrue,
      );
      expect(
        TrackSkyCourseSourceIdentity.matchesFlow(
          sourceId: id,
          flowId: 999,
        ),
        isFalse,
      );
    });
  });

  group('TrackSkyReconciler', () {
    const reconciler = TrackSkyReconciler();

    test('stamps edited futures without adding duplicates', () {
      final now = DateTime.utc(2026, 9, 1);
      final plan = reconciler.plan(
        catalog: catalog,
        nowUtc: now,
        existing: [
          TrackSkyExistingOccurrence(
            clientEventId: 'cid-eq',
            title: 'Autumn Equinox — Watch from Griffith',
            startsAtUtc: DateTime.utc(2026, 9, 23, 1),
            isUserEdited: true,
          ),
        ],
        legacySkyEventIds: {'cid-eq': 'autumn-equinox-2026'},
      );
      expect(
        plan.actions.any(
          (a) =>
              a.type == TrackSkyReconcileActionType.stampOnly &&
              a.skyEventId == 'autumn-equinox-2026',
        ),
        isTrue,
      );
      expect(
        plan.actions.any(
          (a) =>
              a.type == TrackSkyReconcileActionType.add &&
              a.skyEventId == 'autumn-equinox-2026',
        ),
        isFalse,
      );
    });

    test('replace includes notification cancel for untouched futures', () {
      final now = DateTime.utc(2026, 9, 1);
      final plan = reconciler.plan(
        catalog: catalog,
        nowUtc: now,
        existing: [
          TrackSkyExistingOccurrence(
            clientEventId: 'cid-old',
            title: 'Saturn',
            startsAtUtc: DateTime.utc(2026, 10, 4, 4),
            hasScheduledNotification: true,
          ),
        ],
        legacySkyEventIds: {'cid-old': 'saturn-opposition-2026-10-04'},
      );
      final replace = plan.actions.firstWhere(
        (a) => a.type == TrackSkyReconcileActionType.replace,
      );
      expect(replace.cancelNotificationForClientEventId, 'cid-old');
    });
  });

  group('LegacyTrackSkyMigrationMatcher', () {
    const matcher = LegacyTrackSkyMigrationMatcher();

    test('matches by date + title keywords', () {
      final id = matcher.match(
        legacy: LegacyTrackSkyCandidate(
          clientEventId: 'x',
          title: 'Autumn Equinox 2026',
          startsAtUtc: DateTime.utc(2026, 9, 23, 0, 5),
        ),
        catalog: catalog,
      );
      expect(id, 'autumn-equinox-2026');
    });
  });

  group('FollowSkyHeadlessBrain', () {
    test('Cut 1 exit demonstration format', () {
      final materializer = TrackSkyMaterializer(
        toLocal: (utc, _) => utc.toLocal(),
        toUtc: (local, _) => local.toUtc(),
      );
      final enrollment = TrackSkyEnrollmentService(
        materializer: materializer,
        visibilityService: const SkyVisibilityService(),
        courseIdGenerator: () => 'course-demo',
      );
      final brain = FollowSkyHeadlessBrain(
        catalog: catalog,
        candidateEngine: const CourseCandidateEngine(),
        measurementService: const CourseMeasurementService(),
        enrollmentService: enrollment,
      );

      final now = DateTime.utc(2026, 9, 1, 12);
      final course = enrollment.createCourse(
        label: 'The Madness',
        sourceType: TrackSkyCourseSourceType.flow,
        sourceId: TrackSkyCourseSourceIdentity.forFlow(2),
        createdAt: now,
      );

      final text = brain.demonstrate(
        signals: [
          const CourseActivitySignal(
            label: 'Kung Fu',
            sourceType: TrackSkyCourseSourceType.flow,
            sourceId: 'flow:1',
            occurrenceCount: 6,
            recentMinutes: 180,
            previousMinutes: 200,
          ),
          const CourseActivitySignal(
            label: 'The Madness',
            sourceType: TrackSkyCourseSourceType.flow,
            sourceId: 'flow:2',
            occurrenceCount: 5,
            recentMinutes: 195,
            previousMinutes: 360,
          ),
          const CourseActivitySignal(
            label: 'Kettlebell',
            sourceType: TrackSkyCourseSourceType.eventTitle,
            sourceId: 'event_title:kettlebell',
            occurrenceCount: 4,
            recentMinutes: 90,
            previousMinutes: 90,
          ),
        ],
        selectedCourse: course,
        intervals: [
          CourseMeasurementInterval(
            start: DateTime.utc(2026, 8, 28, 10),
            end: DateTime.utc(2026, 8, 28, 13, 15),
            minutes: 195,
          ),
          CourseMeasurementInterval(
            start: DateTime.utc(2026, 8, 10, 10),
            end: DateTime.utc(2026, 8, 10, 16),
            minutes: 360,
          ),
        ],
        nowUtc: now,
        locationLabel: 'America/Los_Angeles',
      );

      expect(text, contains('Course candidates:'));
      expect(text, contains('- Kung Fu'));
      expect(text, contains('- The Madness'));
      expect(text, contains('- Kettlebell'));
      expect(text, contains('The Madness [linked]'));
      expect(text, contains('Autumn Equinox'));
      expect(text, contains('Function: MEASURE'));
      expect(text, contains('previous 14d:'));
      expect(text, contains('Give it more room'));
    });
  });

  group('V1 import fence', () {
    test('follow_the_sky library sources do not import track_sky_flow', () {
      final root = Directory('lib/features/calendar/follow_the_sky');
      final offenders = <String>[];
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final src = entity.readAsStringSync();
        if (src.contains('track_sky_flow.dart') ||
            src.contains('track_sky_flow_data.g.dart')) {
          offenders.add(entity.path);
        }
      }
      expect(offenders, isEmpty, reason: offenders.join(', '));
    });
  });
}
