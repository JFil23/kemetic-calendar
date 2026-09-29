import 'package:mobile/features/calendar/calendar_event_visual_style.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/track_sky_event_block_visual.dart';
import 'package:mobile/features/calendar/follow_the_sky/services/sky_catalog_repository.dart';
import 'package:mobile/features/calendar/follow_the_sky/services/sky_instrument_data_provider.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/domain/sky_graphic_astronomy.dart';
import 'package:mobile/features/calendar/follow_the_sky/domain/sky_instrument_data.dart';
import 'package:mobile/features/calendar/follow_the_sky/domain/follow_sky_track_definition.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_observation_presentation_model.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_view_time_policy.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/follow_sky_instrument_surface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
          'GentiumPlus',
        )..addFont(rootBundle.load('ios/Runner/Fonts/GentiumPlus-Regular.ttf')))
        .load();
  });
  testWidgets(
    'compact calendar graphics share typed astronomy and preserve card text',
    (tester) async {
      final catalog = SkyCatalogRepository.parseJsonString(
        File('assets/follow_the_sky/sky_catalog_v2_graphics_v1.json').readAsStringSync(),
      );
      final ids = [
        'orionids-2026',
        'southern-taurids-2026',
        'geminids-2026',
        'solar-eclipse-2027-02-06',
        'solar-eclipse-2027-08-02',
        'full-moon-2026-08-28',
        'full-moon-2027-02-20',
        'mars-opposition-2027-02-19',
        'jupiter-opposition-2027-02-11',
        'saturn-opposition-2026-10-04',
        'venus-mars-conjunction-2027-11-25',
        'venus-saturn-conjunction-2027-05-07',
        'mercury-mars-conjunction-2028-01-09',
      ];
      await tester.binding.setSurfaceSize(Size(390, ids.length * 88.0 + 16));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final key = GlobalKey();
      final cards = ids.map((id) {
        final night = catalog.observingNight(catalog.byId(id)!);
        final graphic = resolveCalendarEventVisualStyle(
          eventColor: Colors.indigo,
          flowName: 'Follow the sky',
          eventTitle: night.displayName,
        ).graphic!;
        return Padding(
          padding: const EdgeInsets.all(4),
          child: TrackSkyEventBlockVisual(
            title: night.displayName,
            graphic: graphic,
            height: 76,
            width: 366,
            astronomy: night.windowSource.graphicAstronomy,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                night.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'GentiumPlus',
                  fontSize: 14,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        );
      }).toList();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: const Color(0xFF15121D),
              child: Column(children: cards),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      for (final id in ids) {
        expect(
          find.text(catalog.observingNight(catalog.byId(id)!).displayName),
          findsOneWidget,
        );
      }
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '${Directory.systemTemp.path}/follow-sky-calendar-graphics.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
      // Legacy stored companion IDs must resolve without trying to materialize
      // a companion eclipse as another calendar night.
      final event = catalog.byId('lunar-eclipse-2026-08-28')!;
      final graphic = resolveCalendarEventVisualStyle(
        eventColor: Colors.indigo,
        flowName: 'Follow the sky',
        eventTitle: event.name,
      ).graphic!;
      await tester.pumpWidget(
        MaterialApp(
          home: TrackSkyEventBlockVisual(
            title: event.name,
            graphic: graphic,
            height: 80,
            skyEventId: event.id,
          ),
        ),
      );
      await tester.runAsync(() => SkyCatalogRepository().load());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'catalog graphics at selected times fit narrow, phone and wide surfaces',
    (tester) async {
      final catalog = SkyCatalogRepository.parseJsonString(
        File('assets/follow_the_sky/sky_catalog_v2_graphics_v1.json').readAsStringSync(),
      );
      const factory = FollowSkyObservationPresentationModelFactory(
        instrumentProvider: CatalogSkyInstrumentDataProvider(),
      );
      final out = Directory(
        '${Directory.systemTemp.path}/follow-sky-differentiation-catalog',
      )..createSync(recursive: true);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final id in [
        'orionids-2026',
        'southern-taurids-2026',
        'northern-taurids-2026',
        'leonids-2026',
        'geminids-2026',
        'quadrantids-2027',
        'eta-aquariids-2027',
        'perseids-2027',
        'solar-eclipse-2027-02-06',
        'solar-eclipse-2027-08-02',
        'full-moon-2026-08-28',
        'full-moon-2027-02-20',
        'full-moon-2027-07-18',
        'mars-opposition-2027-02-19',
        'jupiter-opposition-2027-02-11',
        'saturn-opposition-2026-10-04',
        'mercury-elongation-2026-10-12',
        'venus-elongation-2027-01-03',
        'mars-jupiter-conjunction-2026-11-16',
        'venus-mars-conjunction-2027-11-25',
        'venus-saturn-conjunction-2027-05-07',
        'mercury-mars-conjunction-2028-01-09',
        'summer-solstice-2027',
        'winter-solstice-2027',
      ]) {
        final model = await factory.build(catalog: catalog, skyEventId: id);
        for (final width in [320.0, 390.0, 768.0]) {
          await tester.binding.setSurfaceSize(Size(width, 282));
          final controller = FollowSkyViewTimeController(
            track: model.track,
            now: model.track.trackStart.subtract(const Duration(days: 1)),
          );
          for (final state in {
            'start': 0.0,
            'peak': model.track.peakFraction,
            'end': 1.0,
          }.entries) {
            controller.selectFraction(state.value);
            final key = GlobalKey();
            await tester.pumpWidget(
              MaterialApp(
                home: RepaintBoundary(
                  key: key,
                  child: FollowSkyInstrumentSurface(
                    data: model.instrument,
                    peakMarker: model.peakMarker,
                    controller: controller,
                  ),
                ),
              ),
            );
            await tester.pump();
            expect(
              tester.takeException(),
              isNull,
              reason: '$id $width ${state.key}',
            );
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              File(
                '${out.path}/$id-${width.toInt()}-${state.key}.png',
              ).writeAsBytesSync(data!.buffer.asUint8List());
              image.dispose();
            });
          }
          controller.dispose();
        }
      }
    },
  );
  testWidgets(
    'static astronomy reference states use the existing seven painters',
    (tester) async {
      final peak = DateTime(2027, 1, 4, 2);
      final start = peak.subtract(const Duration(hours: 12));
      final end = peak.add(const Duration(hours: 12));
      const provenance = SkyInstrumentProvenance(
        source: 'Static visual fixture',
        sourceVersion: '1',
        calculationVersion: '1',
      );
      const visibility = SkyInstrumentVisibility(
        isLocal: true,
        isTimeFallback: false,
        summary: 'fixture',
      );
      SkyInstrumentAstronomy facts({
        MeteorPhysics? meteor,
        SolarEclipsePhysics? solar,
        LunarEclipsePhysics? lunar,
        List<PlanetAppearance> planets = const [],
      }) => SkyInstrumentAstronomy(
        facts: SkyGraphicAstronomy(
          source: 'Static visual fixture',
          sourceVersion: '1',
          calculationVersion: '1',
          meteor: meteor,
          solarEclipse: solar,
          lunarEclipse: lunar,
          planets: planets,
        ),
        anchor: peak,
        meteorSamples: [
          MeteorSkySample(
            at: start,
            radiantAzimuth: meteor?.rightAscensionDegrees ?? 100,
            radiantAltitude: 55,
            moonAltitude: -20,
            moonIllumination: 0,
            sunAltitude: -25,
          ),
          MeteorSkySample(
            at: end,
            radiantAzimuth: meteor?.rightAscensionDegrees ?? 100,
            radiantAltitude: 55,
            moonAltitude: -20,
            moonIllumination: 0,
            sunAltitude: -25,
          ),
        ],
      );
      final cases = <String, (SkyInstrumentData, FollowSkyTrackMode)>{};
      for (final row in [
        (
          'orionids',
          'Orion',
          95.0,
          66.0,
          20.0,
          MeteorPeakShape.moderate,
          18.0,
          MeteorCharacter.ordinary,
          MeteorCharacter.notable,
        ),
        (
          'taurids',
          'Taurus',
          52.0,
          27.0,
          5.0,
          MeteorPeakShape.plateau,
          120.0,
          MeteorCharacter.notable,
          MeteorCharacter.low,
        ),
        (
          'geminids',
          'Gemini',
          112.0,
          35.0,
          120.0,
          MeteorPeakShape.broad,
          24.0,
          MeteorCharacter.ordinary,
          MeteorCharacter.low,
        ),
        (
          'quadrantids',
          'Boötes',
          230.0,
          41.0,
          120.0,
          MeteorPeakShape.narrow,
          3.0,
          MeteorCharacter.notable,
          MeteorCharacter.low,
        ),
      ]) {
        cases[row.$1] = (
          MeteorWindowData(
            radiantName: row.$2,
            peakWindowStart: start,
            peakWindowEnd: end,
            estimatedZenithalHourlyRate: null,
            provenance: provenance,
            visibility: visibility,
            astronomy: facts(
              meteor: MeteorPhysics(
                constellation: row.$2,
                rightAscensionDegrees: row.$3,
                declinationDegrees: 33,
                velocityKmPerSecond: row.$4,
                zenithalHourlyRate: row.$5,
                peakShape: row.$6,
                halfMaximumHours: row.$7,
                fireballs: row.$8,
                trains: row.$9,
              ),
            ),
          ),
          FollowSkyTrackMode.meteorActivity,
        );
      }
      for (final type in [SolarEclipseType.total, SolarEclipseType.annular]) {
        cases[type.name] = (
          SolarEclipseData(
            greatestEclipse: peak,
            contactInstants: [],
            globalVisibilitySummary: '',
            viewingWindowStart: start,
            viewingWindowEnd: end,
            provenance: provenance,
            visibility: visibility,
            astronomy: facts(
              solar: SolarEclipsePhysics(
                type: type,
                magnitude: type == SolarEclipseType.total ? 1.079 : 0.928,
                lunarSolarRadiusRatio: type == SolarEclipseType.total
                    ? 1.079
                    : 0.928,
              ),
            ),
          ),
          FollowSkyTrackMode.solarEclipse,
        );
      }
      for (final type in [
        LunarEclipseType.partial,
        LunarEclipseType.penumbral,
      ]) {
        cases[type.name] = (
          LunarPathData(
            viewingWindowStart: start,
            viewingWindowEnd: end,
            rise: null,
            transit: null,
            set: null,
            moonSamples: [],
            eclipseContacts: [],
            phaseInstant: peak,
            provenance: provenance,
            visibility: visibility,
            astronomy: facts(
              lunar: LunarEclipsePhysics(
                type: type,
                umbralMagnitude: 0.93,
                penumbralMagnitude: 0.9,
              ),
            ),
          ),
          FollowSkyTrackMode.lunarEclipse,
        );
      }
      for (final body in [SkyBody.mars, SkyBody.jupiter]) {
        cases[body.name] = (
          OppositionData(
            bodyName: body.name,
            closestApproach: peak,
            altitudeSamples: [],
            viewingWindowStart: start,
            viewingWindowEnd: end,
            provenance: provenance,
            visibility: visibility,
            astronomy: facts(
              planets: [
                PlanetAppearance(
                  body: body,
                  angularDiameterArcseconds: body == SkyBody.mars ? 14 : 45,
                  apparentMagnitude: body == SkyBody.mars ? -1.2 : -2.6,
                ),
              ],
            ),
          ),
          FollowSkyTrackMode.oppositionNight,
        );
      }
      final out = Directory(
        '${Directory.systemTemp.path}/follow-sky-differentiation-static',
      )..createSync(recursive: true);
      await tester.binding.setSurfaceSize(const Size(390, 282));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final entry in cases.entries) {
        final track = FollowSkyTrackDefinition(
          mode: entry.value.$2,
          trackStart: start,
          trackEnd: end,
          astronomyAnchor: peak,
          experiencePeak: peak,
          visualMetric: 'fixture',
          dataQuality: FollowSkyTrackDataQuality.catalogEnvelope,
        );
        final controller = FollowSkyViewTimeController(
          track: track,
          now: start.subtract(const Duration(days: 1)),
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: key,
              child: FollowSkyInstrumentSurface(
                data: entry.value.$1,
                peakMarker: FollowSkyPeakMarkerSpec(
                  label: 'PEAK',
                  instant: peak,
                ),
                controller: controller,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '${out.path}/${entry.key}.png',
          ).writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        });
        controller.dispose();
      }
    },
  );
}
