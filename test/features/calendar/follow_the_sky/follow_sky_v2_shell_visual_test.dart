
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';

void main() {
  late SkyCatalog catalog;

  setUpAll(() {
    catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
  });

  testWidgets('joined no-course keeps full detail hierarchy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FollowSkyDetailPage(
          isJoined: true,
          initialCatalog: catalog,
          now: DateTime.utc(2026, 9, 1, 12),
          candidates: const [
            CourseActivitySignal(
              label: 'Studio A',
              sourceType: TrackSkyCourseSourceType.flow,
              sourceId: 'flow:2',
              occurrenceCount: 5,
              recentMinutes: 195,
              previousMinutes: 360,
            ),
            CourseActivitySignal(
              label: 'Studio B',
              sourceType: TrackSkyCourseSourceType.flow,
              sourceId: 'flow:1',
              occurrenceCount: 6,
              recentMinutes: 180,
              previousMinutes: 240,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Keep what matters from drifting.'), findsOneWidget);
    expect(find.text('ONE THING TO CARRY'), findsOneWidget);
    expect(
      find.text("What don’t you want daily life to quietly steal from you?"),
      findsOneWidget,
    );
    expect(
      find.text('ḥꜣw will carry it between turnings.'),
      findsOneWidget,
    );
    expect(find.text('Or name something else'), findsOneWidget);
    expect(find.text('Carry this course'), findsOneWidget);
    expect(find.textContaining('65 observing nights through'), findsOneWidget);
    expect(
      find.textContaining('5 Full Moons that are also lunar eclipses'),
      findsOneWidget,
    );
    expect(find.textContaining('70 turnings'), findsNothing);
    expect(find.text('ALREADY IN YOUR LIFE'), findsNothing);
    expect(find.text('Meet the turning'), findsNothing);
    expect(
      find.textContaining('compares the life you’re actually scheduling with the course you chose'),
      findsOneWidget,
    );
    expect(find.text('NEXT TURNING'), findsOneWidget);
    expect(find.text('IN KEMET'), findsOneWidget);
    expect(find.text('WHAT YOU\'LL FOLLOW'), findsOneWidget);
    expect(find.text('UPCOMING TURNINGS'), findsOneWidget);
    expect(find.text('Solar'), findsOneWidget);
    expect(find.text('meteors + planets'), findsOneWidget);
    // No solid marketing billboard title-as-hero replacing the page
    expect(find.text('FOLLOW THE SKY'), findsNothing);
  });
}
