import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';

/// Cut 2 exit — all five system functions have to be genuinely different, and
/// each has to behave with and without an evidence object. A completed function
/// ends in a ritual and lands in history; a witnessed turning does neither.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SkyCatalog catalog;

  setUpAll(() {
    catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
  });

  const functions = CourseFunctionService();
  final codec = TrackSkyCourseMetadataCodec();
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
      // Only Measure talks in 14-day windows.
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
      // Only Measure can offer more room; it is the only function that has a
      // measured shortfall to act on.
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

  group('ritual and history', () {
    Future<GlobalKey<FollowSkyDetailPageState>> pump(
      WidgetTester tester, {
      required TrackSkyCourse course,
      required List<CourseMeasurementInterval> intervals,
    }) async {
      final key = GlobalKey<FollowSkyDetailPageState>();
      await tester.pumpWidget(
        MaterialApp(
          home: FollowSkyDetailPage(
            key: key,
            isJoined: true,
            initialCatalog: catalog,
            existingFlowNotes: codec.encode(course),
            measurementIntervals: intervals,
            now: now,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return key;
    }

    Future<void> openSheet(
      WidgetTester tester,
      GlobalKey<FollowSkyDetailPageState> key,
      SkyObservingNight night,
    ) async {
      unawaited(key.currentState!.openTurningSheetForTest(night));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('a completed Turn ends in a ritual and enters history', (
      tester,
    ) async {
      final key = await pump(
        tester,
        course: linked,
        intervals: richIntervals,
      );
      final solstice = nightFor(SkyEventFunction.turn);

      expect(find.text('YOUR TURNINGS'), findsNothing);

      await openSheet(tester, key, solstice);
      await tester.tap(find.text('Keep it'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('RITUAL'), findsOneWidget);
      expect(
        find.text('You chose what “Studio Practice” deserves next season.'),
        findsOneWidget,
      );
      expect(find.text('Kept.'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('YOUR TURNINGS'), findsOneWidget);
      expect(find.text('Turn completed · Kept.'), findsOneWidget);
      expect(find.textContaining('Witnessed'), findsNothing);

      final history = key.currentState!.turningHistory;
      expect(history.functionsCompleted, hasLength(1));
      expect(history.hasFunctionCompleted(solstice.skyEventId), isTrue);
    });

    testWidgets('an Attend ritual makes no claim about the course', (
      tester,
    ) async {
      final key = await pump(
        tester,
        course: linked,
        intervals: richIntervals,
      );
      final attend = nightFor(SkyEventFunction.attend);

      await openSheet(tester, key, attend);
      await tester.tap(find.text('Keep it'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('You made room to watch.'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Attend completed · Kept.'), findsOneWidget);
    });

    testWidgets('a witnessed turning gets no ritual and reads as witnessed', (
      tester,
    ) async {
      final key = await pump(tester, course: freeText, intervals: const []);
      final eclipse = nightFor(SkyEventFunction.reconsider);

      await openSheet(tester, key, eclipse);
      await tester.tap(find.text('Continue to the eclipse'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('RITUAL'), findsNothing);
      await tester.pumpAndSettle();

      expect(find.text('YOUR TURNINGS'), findsOneWidget);
      expect(find.text('Witnessed · Reconsider'), findsOneWidget);
      expect(find.textContaining('completed ·'), findsNothing);

      final history = key.currentState!.turningHistory;
      expect(history.witnessed, hasLength(1));
      expect(history.functionsCompleted, isEmpty);
    });
  });

  group('one primary advance path', () {
    testWidgets('the next-turning card carries no second CTA button', (
      tester,
    ) async {
      // Embedded exactly as the Ma'at detail scaffold does it, so the dock is
      // the only advance CTA in play.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                FollowSkyDetailPage(
                  isJoined: true,
                  standalone: false,
                  initialCatalog: catalog,
                  existingFlowNotes: codec.encode(linked),
                  measurementIntervals: richIntervals,
                  now: now,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NEXT TURNING'), findsOneWidget);
      // The dock owns advancing; the card must not restate it.
      for (final label in const [
        'Measure my course',
        'Choose what to finish',
        'Reconsider what I’m carrying',
        'Take stock of the season',
        'Plan to watch',
      ]) {
        expect(find.text(label), findsNothing, reason: label);
      }
    });

    testWidgets('tapping the next-turning card opens that turning', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FollowSkyDetailPage(
            isJoined: true,
            initialCatalog: catalog,
            existingFlowNotes: codec.encode(linked),
            measurementIntervals: richIntervals,
            now: now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final next = catalog.nextObservingNight(nowUtc: now)!;
      await tester.tap(find.text('NEXT TURNING'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(next.function.displayLabel.toUpperCase()),
        ),
        findsOneWidget,
      );
    });
  });
}
