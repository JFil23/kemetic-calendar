import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
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
    final night = catalog.observingNight(catalog.byId('full-moon-2026-08-28')!);

    final meaning = resolver.forNight(night);
    expect(meaning.significanceLabel, 'ENDURE');
    expect(
      meaning.observation,
      'The Moon passes through Earth’s shadow without leaving its course.',
    );
  });

  test('buildJoinDraft respects excludedSkyEventIds filter', () {
    final enrollment = TrackSkyEnrollmentService(
      materializer: TrackSkyMaterializer(
        toLocal: (utc, _) => utc.toLocal(),
        toUtc: (local, _) => local.toUtc(),
      ),
      visibilityService: SkyVisibilityService(),
    );
    final now = DateTime.utc(2026, 9, 1);
    final nights = catalog.upcomingNights(nowUtc: now).take(3).toList();
    final excluded = catalog.materializableEvents
        .map((event) => event.id)
        .where((id) => id != nights.first.skyEventId)
        .toSet();

    final draft = enrollment.buildJoinDraft(
      catalog: catalog,
      eligibleNights: enrollment.canonicalNights(catalog: catalog),
      ianaTimeZone: 'America/Los_Angeles',
      excludedSkyEventIds: excluded,
    );

    expect(draft.occurrences, hasLength(1));
    expect(draft.occurrences.single.skyEventId, nights.first.skyEventId);
  });

  test('legacy payload ID overrides its persisted measure presentation', () {
    final legacyPayload = TrackSkyEventOwnership.behaviorPayload(
      skyEventId: 'autumn-equinox-2026',
      resolvedFunction: 'measure',
      displayName: 'Autumn Equinox',
    );

    final teaser = FollowSkyDayDetail.teaser(
      title: 'Autumn Equinox',
      skyEventId: null,
      catalog: catalog,
      behaviorPayload: legacyPayload,
    );
    final detail = FollowSkyDayDetail.displayDetail(
      eventDetail: 'skyEventId=autumn-equinox-2026\nFunction: Measure',
      skyEventId: null,
      catalog: catalog,
      behaviorPayload: legacyPayload,
    );

    expect(teaser, 'Balance · Autumn Equinox');
    expect(detail, contains('BALANCE'));
    expect(
      detail,
      contains('What do you want to make more room for so it can grow?'),
    );
    expect(detail, isNot(contains('Function: Measure')));
    expect(detail, isNot(contains('MEASURE')));
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
    expect(find.text('Follow\nthe Sky'), findsOneWidget);
    expect(find.text(FollowSkyV11Tokens.heroSubtitle), findsOneWidget);
    expect(find.text('𓇼'), findsOneWidget);
    final heroStar = tester.widget<Text>(
      find.byKey(const ValueKey<String>('follow-sky-hero-star')),
    );
    expect(heroStar.style?.fontFamily, 'Noto Sans Egyptian Hieroglyphs');
    expect(heroStar.style?.fontSize, 29);
    expect(find.text('HOW A TURNING WORKS'), findsOneWidget);
    expect(find.text('BALANCE'), findsWidgets);
    expect(find.text('Carry this course'), findsOneWidget);
  });

  testWidgets(
    'legacy measure equinox identity renders BALANCE in the V11 turning sheet',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pageKey = GlobalKey<FollowSkyDetailPageState>();
      final equinox = catalog.byId('autumn-equinox-2026')!;
      final legacyPayload = TrackSkyEventOwnership.behaviorPayload(
        skyEventId: equinox.id,
        resolvedFunction: 'measure',
        displayName: equinox.name,
      );

      expect(equinox.function, SkyEventFunction.measure);
      expect(
        TrackSkyEventOwnership.resolvedFunctionFromPayload(legacyPayload),
        'measure',
      );
      expect(
        TrackSkyEventOwnership.skyEventIdFromPayload(legacyPayload),
        equinox.id,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FollowSkyDetailPage(
            key: pageKey,
            initialCatalog: catalog,
            now: DateTime.utc(2026, 9, 1, 12),
          ),
        ),
      );
      await tester.pumpAndSettle();

      unawaited(
        pageKey.currentState!.openTurningSheetForTest(
          catalog.observingNight(equinox),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Day and night come nearly even. Then the balance begins to turn.',
        ),
        findsWidgets,
      );
      expect(find.text('BALANCE'), findsWidgets);
      expect(
        find.text('What do you want to make more room for so it can grow?'),
        findsWidgets,
      );
      expect(find.text('MEASURE'), findsNothing);
      expect(
        find.text('What do you want to measure against the sky?'),
        findsNothing,
      );
    },
  );

  test('hero asset is registered', () {
    expect(File('assets/follow_the_sky/hero.png').existsSync(), isTrue);
    expect(FollowSkyV11Tokens.heroAsset, 'assets/follow_the_sky/hero.png');
  });

  test(
    'hero uses canonical N14 glyph without painter or Material substitute',
    () {
      final source = File(
        'lib/features/calendar/follow_the_sky/presentation/widgets/'
        'follow_sky_scroll_shell.dart',
      ).readAsStringSync();
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(kFollowSkyGlyph, '𓇼');
      expect(source, contains('glyph: kFollowSkyGlyph'));
      expect(source, isNot(contains('_FollowSkyHeroGlyphPainter')));
      expect(source, isNot(contains('Icons.star')));
      expect(pubspec, contains('family: Noto Sans Egyptian Hieroglyphs'));
      expect(pubspec, contains('NotoSansEgyptianHieroglyphs-Regular.ttf'));
    },
  );

  test(
    'V11 delegates geometry, hero hierarchy, and dock to shared primitives',
    () {
      final detailSource = File(
        'lib/features/calendar/follow_the_sky/presentation/'
        'follow_sky_detail_page.dart',
      ).readAsStringSync();
      final heroSource = File(
        'lib/features/calendar/follow_the_sky/presentation/widgets/'
        'follow_sky_scroll_shell.dart',
      ).readAsStringSync();
      final dockSource = File(
        'lib/features/calendar/follow_the_sky/presentation/widgets/'
        'follow_sky_v11_dock.dart',
      ).readAsStringSync();

      expect(detailSource, contains('return MaatFlowDetailShell('));
      expect(heroSource, contains('return MaatFlowDetailHero('));
      expect(dockSource, contains('return MaatFlowDetailDock('));
      expect(detailSource, isNot(contains('FollowSkyScrollShell(')));
    },
  );
}
