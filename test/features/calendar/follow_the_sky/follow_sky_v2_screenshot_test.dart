import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';

@Skip('V11 replaced V2 Course-era screenshot fixtures')
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SkyCatalog catalog;
  final outDir = Directory('test/screenshots/follow_sky_v2');

  setUpAll(() {
    outDir.createSync(recursive: true);
    catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
  });

  const candidates = <CourseActivitySignal>[
    CourseActivitySignal(
      label: 'Kung Fu',
      sourceType: TrackSkyCourseSourceType.flow,
      sourceId: 'flow:1',
      occurrenceCount: 6,
      recentMinutes: 180,
      previousMinutes: 240,
    ),
    CourseActivitySignal(
      label: 'The Madness',
      sourceType: TrackSkyCourseSourceType.flow,
      sourceId: 'flow:2',
      occurrenceCount: 5,
      recentMinutes: 195,
      previousMinutes: 360,
    ),
    CourseActivitySignal(
      label: 'Kettlebell',
      sourceType: TrackSkyCourseSourceType.eventTitle,
      sourceId: 'event_title:kettlebell',
      occurrenceCount: 4,
      recentMinutes: 90,
      previousMinutes: 90,
    ),
  ];

  final intervals = <CourseMeasurementInterval>[
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
  ];

  testWidgets('capture unjoined first-course detail', (tester) async {
    await _pumpAndCapture(
      tester,
      outPath: '${outDir.path}/01_unjoined_first_course.png',
      child: FollowSkyDetailPage(
        isJoined: false,
        initialCatalog: catalog,
        now: DateTime.utc(2026, 9, 1, 12),
        candidates: candidates,
      ),
    );
  });

  testWidgets('capture joined set-course prompt', (tester) async {
    await _pumpAndCapture(
      tester,
      outPath: '${outDir.path}/02_joined_set_course.png',
      child: FollowSkyDetailPage(
        isJoined: true,
        initialCatalog: catalog,
        now: DateTime.utc(2026, 9, 1, 12),
        candidates: candidates,
      ),
    );
  });

  testWidgets('capture joined course + measurement + turning', (tester) async {
    final codec = TrackSkyCourseMetadataCodec();
    final course = TrackSkyCourse(
      courseId: 'course-visual',
      label: 'The Madness',
      sourceType: TrackSkyCourseSourceType.flow,
      sourceId: TrackSkyCourseSourceIdentity.forFlow(2),
      createdAt: DateTime.utc(2026, 8, 22),
    );
    await _pumpAndCapture(
      tester,
      outPath: '${outDir.path}/03_joined_course_active.png',
      child: FollowSkyDetailPage(
        isJoined: true,
        existingFlowNotes: codec.encode(course),
        initialCatalog: catalog,
        now: DateTime.utc(2026, 9, 1, 12),
        candidates: candidates,
        measurementIntervals: intervals,
      ),
    );
  });
}

Future<void> _pumpAndCapture(
  WidgetTester tester, {
  required String outPath,
  required Widget child,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: RepaintBoundary(
        child: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: child,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));

  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  });
  expect(bytes, isNotNull);
  expect(bytes!.length, greaterThan(1000));
  // Never overwrite tracked goldens during a normal `flutter test` run.
  // Opt in with: --dart-define=UPDATE_FOLLOW_SKY_GOLDENS=true
  const updateGoldens = bool.fromEnvironment('UPDATE_FOLLOW_SKY_GOLDENS');
  if (updateGoldens) {
    File(outPath).writeAsBytesSync(bytes);
  }
}
