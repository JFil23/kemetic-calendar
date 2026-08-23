import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';

void main() {
  const service = CourseFunctionService();
  final linked = TrackSkyCourse(
    courseId: 'c1',
    label: 'Studio Practice',
    sourceType: TrackSkyCourseSourceType.flow,
    sourceId: 'flow:12',
    createdAt: DateTime.utc(2026, 7, 1),
  );
  final freeText = TrackSkyCourse(
    courseId: 'c2',
    label: 'Finish my book',
    sourceType: TrackSkyCourseSourceType.freeText,
    createdAt: DateTime.utc(2026, 8, 22),
  );
  final now = DateTime.utc(2026, 8, 28, 12);
  final intervals = [
    CourseMeasurementInterval(
      start: DateTime.utc(2026, 8, 5, 10),
      end: DateTime.utc(2026, 8, 5, 12),
      minutes: 120,
    ),
    CourseMeasurementInterval(
      start: DateTime.utc(2026, 8, 12, 10),
      end: DateTime.utc(2026, 8, 12, 11, 30),
      minutes: 90,
    ),
    CourseMeasurementInterval(
      start: DateTime.utc(2026, 8, 20, 10),
      end: DateTime.utc(2026, 8, 20, 12),
      minutes: 120,
    ),
    CourseMeasurementInterval(
      start: DateTime.utc(2026, 8, 26, 9),
      end: DateTime.utc(2026, 8, 26, 10),
      minutes: 60,
    ),
  ];

  TrackSkyEnrollmentService enrollment() => TrackSkyEnrollmentService(
        materializer: TrackSkyMaterializer(
          toLocal: (u, _) => u,
          toUtc: (l, _) => l.toUtc(),
        ),
        visibilityService: const SkyVisibilityService(),
      );

  test('reconsider uses carry-forward evidence, not 14d delta copy', () {
    final e = service.evidenceFor(
      function: SkyEventFunction.reconsider,
      course: linked,
      now: now,
      intervals: intervals,
    );
    expect(e.available, isTrue);
    expect(e.lead, contains('Studio Practice'));
    expect(e.lead.toLowerCase(), anyOf(contains('moved'), contains('weeks')));
    expect(e.body.toLowerCase(), isNot(contains('previous 14')));
    expect(e.body.toLowerCase(), isNot(contains('current 14')));
  });

  test('measure still compares previous vs current 14d', () {
    final e = service.evidenceFor(
      function: SkyEventFunction.measure,
      course: linked,
      now: now,
      intervals: intervals,
    );
    expect(e.available, isTrue);
    expect(e.body, contains('Previous 14 days'));
    expect(e.body, contains('Current 14 days'));
    expect(
      enrollment().availableChoices(
        hasCourse: true,
        hasEvidenceObject: e.available,
        function: SkyEventFunction.measure,
      ).map((c) => c.label).toList(),
      ['Keep it', 'Give it more room', 'Change it'],
    );
  });

  test('free-text measure works from Protect-attributed intervals', () {
    final e = service.evidenceFor(
      function: SkyEventFunction.measure,
      course: freeText,
      now: now,
      intervals: intervals,
    );
    expect(e.available, isTrue);
    expect(e.body, contains('Previous 14 days'));
    expect(e.body, contains('Current 14 days'));
    expect(
      enrollment().availableChoices(
        hasCourse: true,
        hasEvidenceObject: e.available,
        function: SkyEventFunction.measure,
      ).map((c) => c.label).toList(),
      ['Keep it', 'Give it more room', 'Change it'],
    );
  });

  test('free-text measure without intervals stays unavailable', () {
    final e = service.evidenceFor(
      function: SkyEventFunction.measure,
      course: freeText,
      now: now,
      intervals: const [],
    );
    expect(e.available, isFalse);
    expect(
      enrollment().availableChoices(
        hasCourse: true,
        hasEvidenceObject: e.available,
        function: SkyEventFunction.measure,
      ),
      isEmpty,
    );
  });

  test('linked measure with zero tracked time is not measurable yet', () {
    final e = service.evidenceFor(
      function: SkyEventFunction.measure,
      course: linked,
      now: now,
      intervals: const [],
    );
    expect(e.available, isFalse);
  });

  test('free-text Protect intervals do not qualify as Reconsider evidence', () {
    final e = service.evidenceFor(
      function: SkyEventFunction.reconsider,
      course: freeText,
      now: now,
      intervals: intervals,
    );
    expect(e.available, isFalse);
    expect(
      e.unavailableReason,
      contains('carried-forward'),
    );
    expect(
      enrollment().availableChoices(
        hasCourse: true,
        hasEvidenceObject: e.available,
        function: SkyEventFunction.reconsider,
      ),
      isEmpty,
    );
  });

  test('free-text Protect intervals do not qualify as Reveal evidence', () {
    final e = service.evidenceFor(
      function: SkyEventFunction.reveal,
      course: freeText,
      now: now,
      intervals: intervals,
    );
    expect(e.available, isFalse);
    expect(
      enrollment().availableChoices(
        hasCourse: true,
        hasEvidenceObject: e.available,
        function: SkyEventFunction.reveal,
      ),
      isEmpty,
    );
  });

  test('reconsider choices require a surfaced evidence object', () {
    final withEvidence = enrollment().availableChoices(
      hasCourse: true,
      hasEvidenceObject: true,
      function: SkyEventFunction.reconsider,
    );
    expect(
      withEvidence.map((c) => c.label).toList(),
      ['Keep it', 'Change it', 'Release it'],
    );
    expect(withEvidence, isNot(contains(FollowSkyProductChoice.giveMoreRoom)));

    expect(
      enrollment().availableChoices(
        hasCourse: true,
        hasEvidenceObject: false,
        function: SkyEventFunction.reconsider,
      ),
      isEmpty,
    );
  });

  test('thin linked activity is not enough for reconsider choices', () {
    final thin = [
      CourseMeasurementInterval(
        start: DateTime.utc(2026, 8, 26, 9),
        end: DateTime.utc(2026, 8, 26, 10),
        minutes: 60,
      ),
    ];
    final e = service.evidenceFor(
      function: SkyEventFunction.reconsider,
      course: linked,
      now: now,
      intervals: thin,
    );
    expect(e.available, isFalse);
    expect(
      enrollment().availableChoices(
        hasCourse: true,
        hasEvidenceObject: e.available,
        function: SkyEventFunction.reconsider,
      ),
      isEmpty,
    );
  });

  test('Turn may summarize Protect-owned intervals without Connect', () {
    final e = service.evidenceFor(
      function: SkyEventFunction.turn,
      course: freeText,
      now: now,
      intervals: intervals,
    );
    expect(e.available, isTrue);
    expect(e.lead, 'Turn.');
    expect(e.body.toLowerCase(), contains('season'));
    expect(e.body, contains('Finish my book'));
  });

}
