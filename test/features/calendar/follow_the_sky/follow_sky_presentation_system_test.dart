import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/domain/follow_sky_track_definition.dart';
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
      expect(model.peakMarker.label, isNotEmpty);
      expect(model.track.visualMetric, isNotEmpty);
      expect(model.visual.family, model.instrument.family);
      expect(
        model.focusInstant.isBefore(model.track.trackStart),
        isFalse,
        reason: model.skyEventId,
      );
      expect(
        model.focusInstant.isAfter(model.track.trackEnd),
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
        track: model.track,
        now: model.track.trackStart.subtract(const Duration(days: 2)),
      );
      final peakLabel = model.peakMarker.displayLabel;
      final peakFraction = controller.fractionFor(model.peakMarker.instant);
      controller.selectFraction(peakFraction < 0.5 ? 0.9 : 0.1);

      expect(controller.value, isNot(model.peakMarker.instant));
      expect(model.peakMarker.displayLabel, peakLabel);
      controller.dispose();
    }
  });

  test('all nine track modes expose the experience-peak label', () {
    final labels = <FollowSkyTrackMode, Set<String>>{
      for (final mode in FollowSkyTrackMode.values)
        mode: models
            .where((model) => model.track.mode == mode)
            .map((model) => model.peakMarker.label)
            .toSet(),
    };
    expect(labels[FollowSkyTrackMode.fullMoonNight], <String>{'HIGHEST'});
    expect(labels[FollowSkyTrackMode.lunarEclipse], <String>{'MAX ECLIPSE'});
    expect(labels[FollowSkyTrackMode.meteorActivity], <String>{'PEAK'});
    expect(labels[FollowSkyTrackMode.oppositionNight], <String>{'HIGHEST'});
    expect(labels[FollowSkyTrackMode.elongationCycle], <String>{
      'MAX SEPARATION',
    });
    expect(labels[FollowSkyTrackMode.conjunctionApproach], <String>{'CLOSEST'});
    expect(labels[FollowSkyTrackMode.equinoxDayNight], <String>{'SUNSET'});
    expect(labels[FollowSkyTrackMode.solsticeSunArc], <String>{'HIGHEST'});
    expect(labels[FollowSkyTrackMode.solarEclipse], <String>{'MAX ECLIPSE'});
    expect(
      losAngelesFullMoonPresentationFixture.peakMarker.label,
      'MAX ECLIPSE',
    );
  });

  test('all 65 records resolve to the audited tracking-mode table', () {
    final counts = <FollowSkyTrackMode, int>{
      for (final mode in FollowSkyTrackMode.values) mode: 0,
    };
    for (final model in models) {
      counts.update(model.track.mode, (value) => value + 1);
    }
    expect(counts, <FollowSkyTrackMode, int>{
      FollowSkyTrackMode.fullMoonNight: 14,
      FollowSkyTrackMode.lunarEclipse: 5,
      FollowSkyTrackMode.meteorActivity: 19,
      FollowSkyTrackMode.oppositionNight: 4,
      FollowSkyTrackMode.elongationCycle: 10,
      FollowSkyTrackMode.conjunctionApproach: 4,
      FollowSkyTrackMode.equinoxDayNight: 3,
      FollowSkyTrackMode.solsticeSunArc: 3,
      FollowSkyTrackMode.solarEclipse: 3,
    });
  });

  test(
    'catalog-only data remains explicitly honest about visual precision',
    () {
      final counts = <FollowSkyTrackDataQuality, int>{
        for (final quality in FollowSkyTrackDataQuality.values) quality: 0,
      };
      for (final model in models) {
        counts.update(model.track.dataQuality, (value) => value + 1);
      }
      expect(counts, <FollowSkyTrackDataQuality, int>{
        FollowSkyTrackDataQuality.observerCalculated: 0,
        FollowSkyTrackDataQuality.locallyDerived: 6,
        FollowSkyTrackDataQuality.catalogEnvelope: 51,
        FollowSkyTrackDataQuality.globalTimingEnvelope: 8,
      });
    },
  );

  test(
    'every event changes the tracked phenomenon across five review states',
    () {
      for (final model in models) {
        final track = model.track;
        final reviewFractions = <double>[0, 0.25, track.peakFraction, 0.75, 1];
        final signatures = reviewFractions.map((fraction) {
          final state = track.stateAt(track.timeAtFraction(fraction));
          return <double>[
            state.eventStrength,
            state.altitudeNormalized,
            state.separationNormalized,
            state.daylight,
          ].map((value) => value.toStringAsFixed(3)).join('/');
        }).toSet();
        expect(signatures.length, greaterThan(1), reason: model.skyEventId);
        String signatureAt(double fraction) {
          final state = track.stateAt(track.timeAtFraction(fraction));
          return <double>[
            state.eventStrength,
            state.altitudeNormalized,
            state.separationNormalized,
            state.daylight,
          ].map((value) => value.toStringAsFixed(3)).join('/');
        }

        expect(
          signatureAt(0),
          isNot(signatureAt(track.peakFraction)),
          reason: model.skyEventId,
        );
        expect(model.peakMarker.instant, track.experiencePeak);
      }
    },
  );

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
      final sheetHost = File(
        'lib/features/calendar/presentation/'
        'instrument_event_presentation_frame.dart',
      ).readAsStringSync();
      final route = File(
        'lib/features/calendar/follow_the_sky/presentation/'
        'follow_sky_observation_route.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('full-moon-2026-08-28')));
      expect(source, isNot(contains('FollowSkyObservationSheet(')));
      expect(source, contains('InstrumentEventSheetHost('));
      expect(sheetHost, contains('onVerticalDragUpdate: keyboardInset == 0'));
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
      final liveWallTime = model.track.trackStart.add(
        model.track.trackEnd.difference(model.track.trackStart) ~/ 2,
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
        expect(
          tester.widget<Text>(time).data,
          contains(_formatTime(liveWallTime)),
        );
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
        _harness(model, now: () => model.track.trackStart.toUtc()),
      );
      await tester.pump();

      expect(find.text('Saturn Opposition'), findsOneWidget);
      expect(find.text('OPPOSITION'), findsNothing);
      final marker = find.byKey(
        const ValueKey<String>('follow-sky-peak-marker-opposition'),
      );
      expect(
        tester.widget<Semantics>(marker).properties.value,
        startsWith('HIGHEST · '),
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
