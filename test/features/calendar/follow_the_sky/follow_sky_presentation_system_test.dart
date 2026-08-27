import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/domain/sky_catalog.dart';
import 'package:mobile/features/calendar/follow_the_sky/domain/sky_instrument_data.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/fixtures/follow_sky_observation_presentation_fixture.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_observation_presentation_model.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_observation_route.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_view_time_policy.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/follow_sky_observation_presentation.dart';
import 'package:mobile/features/calendar/follow_the_sky/services/sky_catalog_repository.dart';
import 'package:mobile/features/calendar/follow_the_sky/services/sky_instrument_data_provider.dart';
import 'package:mobile/features/calendar/follow_the_sky/services/track_sky_materializer.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late SkyCatalog catalog;
  late List<FollowSkyObservationPresentationModel> models;
  late tz.Location losAngeles;

  setUpAll(() async {
    tzdata.initializeTimeZones();
    losAngeles = tz.getLocation('America/Los_Angeles');
    catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
    const factory = FollowSkyObservationPresentationModelFactory(
      instrumentProvider: CatalogSkyInstrumentDataProvider(),
    );
    models = <FollowSkyObservationPresentationModel>[];
    for (final event in catalog.materializableEvents) {
      models.add(
        await factory.build(
          catalog: catalog,
          skyEventId: event.id,
          intention: 'test intention',
        ),
      );
    }
  });

  test('all 65 catalog nights construct one complete presentation model', () {
    expect(catalog.observingNightCount, 65);
    expect(models, hasLength(65));
    expect(
      models.map((model) => model.instrument.family).toSet(),
      SkyInstrumentFamily.values.toSet(),
    );

    for (final model in models) {
      expect(model.skyEventId, isNotEmpty);
      expect(model.title, isNotEmpty);
      expect(model.dateLabel, isNotEmpty);
      expect(model.locationLabel, 'Los Angeles');
      expect(model.meaning.observation, isNotEmpty);
      expect(model.meaning.significanceLabel, isNotEmpty);
      expect(model.meaning.personalQuestion, isNotEmpty);
      expect(model.copy.lensLabel, isNotEmpty);
      expect(model.copy.lensStatement, isNotEmpty);
      expect(model.copy.reflectionPrompt, isNotEmpty);
      expect(model.copy.timingLabel, isNotEmpty);
      expect(model.peakMarker.label, isNotEmpty);
      expect(model.copy.timingLabel, model.peakMarker.displayLabel);
      expect(model.visual.family, model.instrument.family);
      expect(
        model.focusInstant.isBefore(model.instrument.viewingWindowStart),
        isFalse,
        reason: model.skyEventId,
      );
      expect(
        model.focusInstant.isAfter(model.instrument.viewingWindowEnd),
        isFalse,
        reason: model.skyEventId,
      );
      expect(
        FollowSkyObservationRoute.matches(
          clientEventId: 'client-${model.skyEventId}',
          behaviorPayload: TrackSkyEventOwnership.behaviorPayload(
            skyEventId: model.skyEventId,
            displayName: 'A renamed flow does not matter',
          ),
          catalog: catalog,
        ),
        isTrue,
        reason: model.skyEventId,
      );
    }
  });

  test('all 65 peak markers remain independent of selected view time', () {
    for (final model in models) {
      final controller = FollowSkyViewTimeController(
        instrument: model.instrument,
        focusInstant: model.focusInstant,
        now: model.instrument.viewingWindowStart.subtract(
          const Duration(days: 2),
        ),
      );
      final peakLabel = model.peakMarker.displayLabel;
      final peakFraction = controller.fractionFor(model.peakMarker.instant);
      controller.selectFraction(peakFraction < 0.5 ? 0.9 : 0.1);

      expect(controller.value, isNot(model.peakMarker.instant));
      expect(model.peakMarker.displayLabel, peakLabel);
      controller.dispose();
    }
  });

  test('all seven families expose the required phenomenon peak label', () {
    final labels = <SkyInstrumentFamily, Set<String>>{
      for (final family in SkyInstrumentFamily.values)
        family: models
            .where((model) => model.instrument.family == family)
            .map((model) => model.peakMarker.label)
            .toSet(),
    };
    expect(labels[SkyInstrumentFamily.lunarPath], <String>{'FULL'});
    expect(labels[SkyInstrumentFamily.meteorWindow], <String>{'PEAK'});
    expect(labels[SkyInstrumentFamily.opposition], <String>{'OPPOSITION'});
    expect(labels[SkyInstrumentFamily.elongation], <String>{'MAX ELONGATION'});
    expect(labels[SkyInstrumentFamily.conjunction], <String>{'CLOSEST'});
    expect(labels[SkyInstrumentFamily.solarThreshold], <String>{
      'EQUINOX',
      'SOLSTICE',
    });
    expect(labels[SkyInstrumentFamily.solarEclipse], <String>{'MAX ECLIPSE'});
    expect(
      losAngelesFullMoonPresentationFixture.peakMarker.label,
      'MAX ECLIPSE',
    );
  });

  test('catalog coverage remains grouped into the seven sealed families', () {
    final counts = <SkyInstrumentFamily, int>{
      for (final family in SkyInstrumentFamily.values) family: 0,
    };
    for (final model in models) {
      counts.update(model.instrument.family, (value) => value + 1);
    }
    expect(counts, <SkyInstrumentFamily, int>{
      SkyInstrumentFamily.lunarPath: 19,
      SkyInstrumentFamily.meteorWindow: 19,
      SkyInstrumentFamily.opposition: 4,
      SkyInstrumentFamily.elongation: 10,
      SkyInstrumentFamily.conjunction: 4,
      SkyInstrumentFamily.solarThreshold: 6,
      SkyInstrumentFamily.solarEclipse: 3,
    });
  });

  test(
    'shared routing and sizing source contains no event-name exceptions',
    () {
      final source = File(
        'lib/features/calendar/day_view.dart',
      ).readAsStringSync();
      final route = File(
        'lib/features/calendar/follow_the_sky/presentation/'
        'follow_sky_observation_route.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('full-moon-2026-08-28')));
      expect(source, isNot(contains('FollowSkyObservationSheet(')));
      expect(
        source,
        contains('activeFollowSkyInstrument && keyboardInset == 0'),
      );
      expect(route, isNot(contains('flowName')));
      expect(route, contains('catalog.byId(skyEventId)'));
    },
  );

  for (final family in SkyInstrumentFamily.values) {
    testWidgets('${family.name} uses the shared shell at min and max height', (
      tester,
    ) async {
      final model = models.firstWhere(
        (candidate) => candidate.instrument.family == family,
      );
      final liveWallTime = model.instrument.viewingWindowStart.add(
        model.instrument.viewingWindowEnd.difference(
              model.instrument.viewingWindowStart,
            ) ~/
            2,
      );
      final liveInstant = tz.TZDateTime(
        losAngeles,
        liveWallTime.year,
        liveWallTime.month,
        liveWallTime.day,
        liveWallTime.hour,
        liveWallTime.minute,
      ).toUtc();

      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      for (final size in <Size>[
        const Size(390, 317),
        const Size(390, 760),
        const Size(320, 317),
        const Size(320, 760),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.physicalSize = size;
        await tester.pumpWidget(_harness(model, now: () => liveInstant));
        await tester.pump();

        expect(
          find.byKey(ValueKey<String>('follow-sky-renderer-${family.name}')),
          findsOneWidget,
        );
        expect(find.text('FOLLOW THE SKY'), findsOneWidget);
        expect(find.text(model.copy.lensLabel), findsOneWidget);
        expect(find.text('Reflect'), findsOneWidget);
        expect(find.text('COMPLETION'), findsOneWidget);
        final marker = find.byKey(
          ValueKey<String>('follow-sky-peak-marker-${family.name}'),
        );
        expect(marker, findsOneWidget);
        expect(
          tester.widget<Semantics>(marker).properties.value,
          model.peakMarker.displayLabel,
        );
        final titleZone = tester.getRect(
          find.byKey(const ValueKey<String>('follow-sky-header-title-zone')),
        );
        final metaZone = tester.getRect(
          find.byKey(const ValueKey<String>('follow-sky-header-meta-zone')),
        );
        expect(titleZone.right, lessThanOrEqualTo(metaZone.left));
        final time = find.byKey(const ValueKey<String>('follow-sky-view-time'));
        expect(tester.widget<Text>(time).data, _formatTime(liveWallTime));
        expect(tester.takeException(), isNull);

        final before = tester.widget<Text>(time).data;
        final hero = find.byKey(const ValueKey<String>('follow-sky-hero-drag'));
        final rect = tester.getRect(hero);
        await tester.tapAt(
          Offset(rect.left + rect.width * 0.18, rect.center.dy),
        );
        await tester.pump();
        expect(tester.widget<Text>(time).data, isNot(before));
        expect(
          tester.widget<Semantics>(marker).properties.value,
          model.peakMarker.displayLabel,
        );
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets(
    'Saturn opposition owns its label as a fixed marker, not header debris',
    (tester) async {
      final model = models.singleWhere(
        (candidate) => candidate.skyEventId == 'saturn-opposition-2026-10-04',
      );
      tester.view.physicalSize = const Size(390, 317);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _harness(model, now: () => model.instrument.viewingWindowStart.toUtc()),
      );
      await tester.pump();

      expect(find.text('Saturn Opposition'), findsOneWidget);
      expect(find.text('OPPOSITION'), findsNothing);
      final marker = find.byKey(
        const ValueKey<String>('follow-sky-peak-marker-opposition'),
      );
      expect(
        tester.widget<Semantics>(marker).properties.value,
        startsWith('OPPOSITION · '),
      );

      final peakValue = tester.widget<Semantics>(marker).properties.value;
      final hero = find.byKey(const ValueKey<String>('follow-sky-hero-drag'));
      final rect = tester.getRect(hero);
      await tester.tapAt(Offset(rect.left + rect.width * 0.84, rect.center.dy));
      await tester.pump();

      expect(tester.widget<Semantics>(marker).properties.value, peakValue);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('follow-sky-view-time')),
            )
            .data,
        isNot(model.peakMarker.displayLabel.split(' · ').last),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _harness(
  FollowSkyObservationPresentationModel model, {
  required DateTime Function() now,
}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      backgroundColor: Colors.black,
      body: FollowSkyObservationPresentation(model: model, now: now),
    ),
  );
}

String _formatTime(DateTime value) {
  final period = value.hour >= 12 ? 'PM' : 'AM';
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  return '$hour:${value.minute.toString().padLeft(2, '0')} $period';
}
