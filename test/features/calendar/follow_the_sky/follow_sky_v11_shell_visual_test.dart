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

  testWidgets('V11 detail shows thirty-day copy and carry dock', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: FollowSkyDetailPage(
          initialCatalog: catalog,
          now: DateTime.utc(2026, 9, 1, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Here they are.'), findsOneWidget);
    expect(find.text('How a turning works'), findsOneWidget);
    expect(find.text('Carry'), findsOneWidget);
    expect(find.textContaining('All ${catalog.observingNightCount} turnings'),
        findsOneWidget);
  });

  testWidgets('joined state shows in-your-calendar dock', (tester) async {
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

    expect(find.text('In your calendar'), findsOneWidget);
    expect(
      find.text('The sky will find you. Change anything later.'),
      findsOneWidget,
    );
  });
}
