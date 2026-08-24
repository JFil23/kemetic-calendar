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

  testWidgets('V11 detail hierarchy replaces Course-era marketing shell', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: FollowSkyDetailPage(
          isJoined: true,
          initialCatalog: catalog,
          now: DateTime.utc(2026, 9, 1, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Here they are.'), findsOneWidget);
    expect(find.text('HOW A TURNING WORKS'), findsOneWidget);
    expect(find.text('Keep what matters from drifting.'), findsNothing);
    expect(find.text('ONE THING TO CARRY'), findsNothing);
    expect(find.text('UPCOMING TURNINGS'), findsNothing);
    expect(find.text('In your calendar'), findsOneWidget);
  });
}
