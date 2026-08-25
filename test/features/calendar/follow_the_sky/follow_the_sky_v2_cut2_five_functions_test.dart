import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';

/// Cut 2 exit — all five system functions have to be genuinely different, and
/// each has to behave with and without an evidence object.
void main() {
  late SkyCatalog catalog;

  setUpAll(() {
    catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
  });

  const functions = CourseFunctionService();
  final now = DateTime.utc(2026, 8, 28, 12);

  final enrollment = TrackSkyEnrollmentService(
    materializer: TrackSkyMaterializer(
      toLocal: (utc, _) => utc,
      toUtc: (local, _) => local,
    ),
    visibilityService: const SkyVisibilityService(),
  );

  final linked = TrackSkyCourse(
    courseId: 'c-studio',
    label: 'Studio Practice',
    sourceType: TrackSkyCourseSourceType.flow,
    sourceId: 'flow:12',
    createdAt: DateTime.utc(2026, 7, 1),
  );
  final freeText = TrackSkyCourse(
    courseId: 'c-book',
    label: 'Finish my book',
    sourceType: TrackSkyCourseSourceType.freeText,
    createdAt: DateTime.utc(2026, 8, 1),
  );

  /// Four occurrences across four weeks — enough to be a carry-forward object.
  final richIntervals = [
    for (final day in [5, 12, 20, 26])
      CourseMeasurementInterval(
        start: DateTime.utc(2026, 8, day, 10),
        end: DateTime.utc(2026, 8, day, 12),
        minutes: 120,
      ),
  ];

  SkyObservingNight nightFor(SkyEventFunction function) {
    return catalog
        .upcomingNights(nowUtc: DateTime.utc(2026, 8, 1))
        .firstWhere((n) => n.function == function);
  }

  CourseFunctionEvidence evidence(
    SkyEventFunction function, {
    required TrackSkyCourse course,
    required List<CourseMeasurementInterval> intervals,
  }) {
    return functions.evidenceFor(
      function: function,
      course: course,
      now: now,
      intervals: intervals,
    );
  }

  group('each function reads the same evidence differently', () {
    test('the catalog assigns one distinct function per kind', () {
      final byFunction = <SkyEventFunction, SkyEventKind>{
        for (final f in SkyEventFunction.values) f: nightFor(f).serviceKind,
      };

      expect(byFunction[SkyEventFunction.measure], SkyEventKind.equinox);
      expect(byFunction[SkyEventFunction.reveal], SkyEventKind.fullMoon);
      expect(byFunction[SkyEventFunction.turn], SkyEventKind.solstice);
      expect(
        byFunction[SkyEventFunction.reconsider],
        anyOf(SkyEventKind.lunarEclipse, SkyEventKind.solarEclipse),
      );
      expect(
        byFunction[SkyEventFunction.attend],
        isNot(
          anyOf(
            SkyEventKind.equinox,
            SkyEventKind.fullMoon,
            SkyEventKind.solstice,
          ),
        ),
      );
    });

    test('the same rich linked activity produces five different services', () {
      final bodies = <SkyEventFunction, String>{
        for (final f in SkyEventFunction.values)
          f: evidence(f, course: linked, intervals: richIntervals).body,
      };

      expect(bodies.values.toSet(), hasLength(SkyEventFunction.values.length));
      expect(bodies[SkyEventFunction.measure], contains('Current 14 days'));
      for (final f in SkyEventFunction.values) {
        if (f == SkyEventFunction.measure) continue;
        expect(bodies[f], isNot(contains('14 days')));
      }
    });

    test('choice sets differ per function', () {
      List<String> choices(SkyEventFunction f) => enrollment
          .availableChoices(
            hasCourse: true,
            hasEvidenceObject: true,
            function: f,
          )
          .map((c) => c.label)
          .toList();

      expect(choices(SkyEventFunction.measure),
          ['Keep it', 'Give it more room', 'Change it']);
      expect(choices(SkyEventFunction.reveal), ['Keep it', 'Change it']);
      expect(choices(SkyEventFunction.reconsider),
          ['Keep it', 'Change it', 'Release it']);
      expect(choices(SkyEventFunction.turn),
          ['Keep it', 'Change it', 'Release it']);
      expect(choices(SkyEventFunction.attend), ['Keep it']);
      for (final f in SkyEventFunction.values) {
        if (f == SkyEventFunction.measure) continue;
        expect(choices(f), isNot(contains('Give it more room')));
      }
    });
  });

  group('evidence branch', () {
    test('Measure reports both windows', () {
      final e = evidence(
        SkyEventFunction.measure,
        course: linked,
        intervals: richIntervals,
      );
      expect(e.available, isTrue);
      expect(e.body, contains('Previous 14 days'));
      expect(e.body, contains('Current 14 days'));
    });

    test('Reveal names one thread that stayed open across weeks', () {
      final e = evidence(
        SkyEventFunction.reveal,
        course: linked,
        intervals: richIntervals,
      );
      expect(e.available, isTrue);
      expect(e.lead, 'Reveal.');
      expect(e.body, contains('Studio Practice'));
      expect(e.body.toLowerCase(), contains('weeks'));
    });

    test('Reveal without multiple weeks still surfaces something open', () {
      final e = evidence(
        SkyEventFunction.reveal,
        course: linked,
        intervals: [richIntervals.last],
      );
      expect(e.available, isTrue);
      expect(e.body.toLowerCase(), contains('still open'));
    });

    test('Reconsider names what keeps being carried forward', () {
      final e = evidence(
        SkyEventFunction.reconsider,
        course: linked,
        intervals: richIntervals,
      );
      expect(e.available, isTrue);
      expect(e.lead, contains('Studio Practice'));
      expect(e.body.toLowerCase(), isNot(contains('14 day')));
    });

    test('Turn summarizes the season for a free-text course too', () {
      final e = evidence(
        SkyEventFunction.turn,
        course: freeText,
        intervals: richIntervals,
      );
      expect(e.available, isTrue);
      expect(e.lead, 'Turn.');
      expect(e.body, contains('Finish my book'));
      expect(e.body, contains('8h 00m'));
    });

    test('Attend never claims to measure anything', () {
      final e = evidence(
        SkyEventFunction.attend,
        course: linked,
        intervals: richIntervals,
      );
      expect(e.available, isTrue);
      expect(e.lead, 'Attend.');
      expect(e.body.toLowerCase(), contains('nothing to optimize'));
      expect(e.body, isNot(contains('Studio Practice')));
    });
  });

  group('no-evidence branch', () {
    test('Measure has nothing to compare', () {
      final e = evidence(
        SkyEventFunction.measure,
        course: freeText,
        intervals: const [],
      );
      expect(e.available, isFalse);
      expect(e.unavailableReason, contains('No calendar activity'));
    });

    test('Reveal has nothing open', () {
      final e = evidence(
        SkyEventFunction.reveal,
        course: linked,
        intervals: const [],
      );
      expect(e.available, isFalse);
      expect(e.unavailableReason, contains('Nothing unfinished'));
    });

    test('Reconsider has nothing carried forward', () {
      final e = evidence(
        SkyEventFunction.reconsider,
        course: linked,
        intervals: const [],
      );
      expect(e.available, isFalse);
      expect(e.unavailableReason, contains('activity connected'));
    });

    test('Turn stays usable and refuses to invent meaning', () {
      final e = evidence(
        SkyEventFunction.turn,
        course: freeText,
        intervals: const [],
      );
      expect(e.available, isTrue);
      expect(e.body, contains('without inventing meaning'));
      expect(e.body, isNot(contains('0h 00m')));
    });

    test('Attend needs no evidence at all', () {
      expect(
        evidence(
          SkyEventFunction.attend,
          course: freeText,
          intervals: const [],
        ).available,
        isTrue,
      );
    });
  });

  // V11 removed V2 ritual/history and next-turning detail widget tests.
  // See follow_the_sky_v2_turning_history_test for persisted history behavior.
}
