import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/turning_meaning.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/follow_sky_v11_tokens.dart';

void main() {
  late SkyCatalog catalog;

  setUpAll(() {
    catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
  });

  test('TurningMeaningResolver ships approved eclipse copy', () {
    const resolver = TurningMeaningResolver();
    final night = catalog
        .upcomingNights(nowUtc: DateTime.utc(2026, 9, 1))
        .firstWhere((n) => n.companion != null);

    final meaning = resolver.forNight(night);
    expect(meaning.significanceLabel, 'ENDURE');
    expect(
      meaning.observation,
      'The moon passes through shadow without leaving its course.',
    );
  });

  test('buildJoinDraft respects includedSkyEventIds filter', () {
    final enrollment = TrackSkyEnrollmentService(
      materializer: TrackSkyMaterializer(
        toLocal: (utc, _) => utc.toLocal(),
        toUtc: (local, _) => local.toUtc(),
      ),
      visibilityService: SkyVisibilityService(),
    );
    final now = DateTime.utc(2026, 9, 1);
    final nights = catalog.upcomingNights(nowUtc: now).take(3).toList();
    final onlyFirst = {nights.first.skyEventId};

    final draft = enrollment.buildJoinDraft(
      catalog: catalog,
      nowUtc: now,
      ianaTimeZone: 'America/Los_Angeles',
      includedSkyEventIds: onlyFirst,
    );

    expect(draft.occurrences, hasLength(1));
    expect(draft.occurrences.single.skyEventId, nights.first.skyEventId);
  });

  testWidgets('FollowSkyDetailPage renders V11 headings', (tester) async {
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
    expect(find.text('In your next thirty days.'), findsOneWidget);
    expect(find.text('Follow\nthe sky'), findsOneWidget);
    expect(find.text(FollowSkyV11Tokens.heroSubtitle), findsOneWidget);
    expect(find.text('HOW A TURNING WORKS'), findsOneWidget);
    expect(find.text('ENDURE'), findsWidgets);
    expect(find.text('Carry this course'), findsOneWidget);
  });

  test('hero asset is registered', () {
    expect(File('assets/follow_the_sky/hero.png').existsSync(), isTrue);
    expect(FollowSkyV11Tokens.heroAsset, 'assets/follow_the_sky/hero.png');
  });
}
