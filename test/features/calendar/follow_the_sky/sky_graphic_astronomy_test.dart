import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:mobile/features/calendar/follow_the_sky/domain/sky_graphic_astronomy.dart';
import 'package:mobile/features/calendar/follow_the_sky/domain/observing_place.dart';
import 'package:mobile/features/calendar/follow_the_sky/domain/sky_catalog.dart';
import 'package:mobile/features/calendar/follow_the_sky/domain/sky_event_kind.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_observation_presentation_model.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/follow_sky_instrument_surface.dart';
import 'package:mobile/features/calendar/follow_the_sky/services/sky_instrument_data_provider.dart';
import 'package:mobile/features/calendar/follow_the_sky/services/sky_graphic_geometry.dart';

void main() {
  tzdata.initializeTimeZones();
  final raw =
      jsonDecode(
            File(
              'assets/follow_the_sky/sky_catalog_v2_graphics_v1.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final catalog = SkyCatalog.fromJson(raw);
  SkyGraphicAstronomy facts(String id) => catalog.byId(id)!.graphicAstronomy!;
  test(
    'all changed event kinds carry sourced typed facts; existing catalog round-trips',
    () {
      for (final event in catalog.events) {
        if ([
          SkyEventKind.meteorShower,
          SkyEventKind.solarEclipse,
          SkyEventKind.lunarEclipse,
          SkyEventKind.planetOpposition,
          SkyEventKind.planetElongation,
          SkyEventKind.planetConjunction,
        ].contains(event.kind)) {
          expect(event.graphicAstronomy, isNotNull, reason: event.id);
          expect(event.graphicAstronomy!.source, isNotEmpty);
          expect(event.graphicAstronomy!.provisional, event.provisional);
          expect(
            event.toJson()['graphicAstronomy'],
            raw['events'].firstWhere(
              (e) => e['id'] == event.id,
            )['graphicAstronomy'],
          );
        }
      }
    },
  );
  test(
    'showers differ by radiant, velocity, rate and physical peak duration',
    () {
      final orion = facts('orionids-2026').meteor!;
      final gem = facts('geminids-2026').meteor!;
      final taurid = facts('southern-taurids-2026').meteor!;
      final north = facts('northern-taurids-2026').meteor!;
      final quad = facts('quadrantids-2027').meteor!;
      expect(orion.rightAscensionDegrees, isNot(gem.rightAscensionDegrees));
      expect(taurid.declinationDegrees, isNot(north.declinationDegrees));
      expect(taurid.zenithalHourlyRate, lessThan(gem.zenithalHourlyRate / 10));
      expect(orion.streakLength, greaterThan(gem.streakLength));
      expect(quad.activity(6), lessThan(0.1));
      expect(gem.activity(6), greaterThan(0.9));
      expect(taurid.activity(6), greaterThan(0.99));
      expect(orion.activity(10, uncertaintyHours: 24), 1);
    },
  );
  test(
    'observer geometry and moonlight match independent engine Horizon calculations',
    () {
      final refs =
          jsonDecode(
                File(
                  'test/fixtures/follow_sky/graphic_geometry_engine_2_1_19.json',
                ).readAsStringSync(),
              )
              as List;
      for (final r in refs) {
        final place = ObservingPlace(
          latitude: r['latitude'],
          longitude: r['longitude'],
          ianaTimeZone: r['zone'],
          label: 'test',
          source: ObservingPlaceSource.manual,
        );
        final data = resolveSkyGraphicAstronomy(
          catalog.byId(r['event'])!,
          place,
        )!;
        final at = DateTime.parse(r['at']);
        final s = data.meteorAt(at)!;
        // Includes half-hour samples: sub-degree accuracy is sufficient for the
        // small instrument; this tolerance catches RA-hours/deg and UTC errors.
        expect(s.radiantAltitude, closeTo(r['radiantAltitude'], 0.6));
        expect(s.radiantAzimuth, closeTo(r['radiantAzimuth'], 1.2));
        expect(s.moonAltitude, closeTo(r['moonAltitude'], 0.6));
        expect(s.sunAltitude, closeTo(r['sunAltitude'], 0.6));
        expect(s.moonIllumination, closeTo(r['illumination'], 0.001));
      }
    },
  );
  test(
    'moonlight suppresses faint meteors only while Moon is up; daylight suppresses all',
    () {
      MeteorSkySample sky(double moon, double sun) => MeteorSkySample(
        at: DateTime(2027),
        radiantAzimuth: 100,
        radiantAltitude: 55,
        moonAltitude: moon,
        moonIllumination: 1,
        sunAltitude: sun,
      );
      expect(
        sky(70, -25).faintVisibility,
        lessThan(sky(-10, -25).faintVisibility / 3),
      );
      expect(sky(-10, -25).moonInterference, 0);
      expect(sky(70, 5).faintVisibility, 0);
    },
  );
  test(
    'solar radius ratios and lunar shadow classes are physically distinct',
    () {
      final total = facts('solar-eclipse-2027-08-02').solarEclipse!;
      final annular = facts('solar-eclipse-2027-02-06').solarEclipse!;
      expect(total.hasTotality, isTrue);
      expect(total.lunarSolarRadiusRatio, greaterThan(1));
      expect(1 - annular.lunarSolarRadiusRatio, greaterThan(0));
      expect(annular.hasTotality, isFalse);
      expect(
        facts('lunar-eclipse-2026-08-28').lunarEclipse!.type,
        LunarEclipseType.partial,
      );
      expect(
        facts('lunar-eclipse-2027-02-20').lunarEclipse!.type,
        LunarEclipseType.penumbral,
      );
      expect(
        facts('lunar-eclipse-2027-07-18').lunarEclipse!.penumbralMagnitude,
        lessThan(0.002),
      );
    },
  );
  test(
    'planet disks scale from angular size and conjunction gaps retain precision',
    () {
      final jupiter = facts('jupiter-opposition-2027-02-11').planets.single;
      final mars = facts('mars-opposition-2027-02-19').planets.single;
      expect(
        jupiter.angularDiameterArcseconds,
        greaterThan(mars.angularDiameterArcseconds * 2),
      );
      expect(jupiter.visualRadius, greaterThan(mars.visualRadius));
      expect(jupiter.glowOpacity, greaterThan(mars.glowOpacity));
      final tight = facts('venus-mars-conjunction-2027-11-25');
      final wide = facts('mars-jupiter-conjunction-2026-11-16');
      expect(tight.minimumSeparationDegrees, closeTo(0.3, 0.03));
      expect(wide.minimumSeparationDegrees, closeTo(1.2, 0.03));
      expect(
        tight.minimumSeparationDegrees! * 24,
        lessThan(wide.minimumSeparationDegrees! * 24),
      );
      expect(tight.planets.map((p) => p.body), [SkyBody.venus, SkyBody.mars]);
    },
  );
  test(
    'all surrounding copy, readouts, tracking windows and fixed peaks stay unchanged',
    () async {
      final originalJson = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
      for (final e in originalJson['events']) {
        e.remove('graphicAstronomy');
      }
      final original = SkyCatalog.fromJson(originalJson);
      const factory = FollowSkyObservationPresentationModelFactory(
        instrumentProvider: CatalogSkyInstrumentDataProvider(),
      );
      for (final event in catalog.materializableEvents) {
        final a = await factory.build(
          catalog: original,
          skyEventId: event.id,
          intention: 'unchanged',
        );
        final b = await factory.build(
          catalog: catalog,
          skyEventId: event.id,
          intention: 'unchanged',
        );
        expect(
          [
            b.title,
            b.dateLabel,
            b.locationLabel,
            b.ianaTimeZone,
            b.copy.lensLabel,
            b.copy.lensStatement,
            b.copy.reflectionPrompt,
            b.copy.dragLead,
            b.copy.intentionContext,
            b.peakMarker.displayLabel,
          ],
          [
            a.title,
            a.dateLabel,
            a.locationLabel,
            a.ianaTimeZone,
            a.copy.lensLabel,
            a.copy.lensStatement,
            a.copy.reflectionPrompt,
            a.copy.dragLead,
            a.copy.intentionContext,
            a.peakMarker.displayLabel,
          ],
          reason: event.id,
        );
        expect(
          [
            b.track.trackStart,
            b.track.trackEnd,
            b.track.experiencePeak,
            b.track.astronomyAnchor,
            b.track.mode,
          ],
          [
            a.track.trackStart,
            a.track.trackEnd,
            a.track.experiencePeak,
            a.track.astronomyAnchor,
            a.track.mode,
          ],
        );
        for (final f in [0.0, 0.25, 0.5, 0.75, 1.0]) {
          final time = a.track.timeAtFraction(f);
          final ar = FollowSkyInstrumentSurface.readingFor(
            a.instrument,
            a.track,
            time,
          );
          final br = FollowSkyInstrumentSurface.readingFor(
            b.instrument,
            b.track,
            time,
          );
          expect(
            [br.primary, br.secondary, br.semanticsValue],
            [ar.primary, ar.secondary, ar.semanticsValue],
          );
        }
      }
    },
  );
}
