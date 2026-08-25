import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SkyCatalog catalog;
  late TrackSkyMaterializer materializer;

  setUpAll(() {
    tzdata.initializeTimeZones();
    catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
    materializer = TrackSkyMaterializer(
      toLocal: (utc, iana) =>
          tz.TZDateTime.from(utc.toUtc(), tz.getLocation(iana)),
      toUtc: (local, iana) {
        final location = tz.getLocation(iana);
        return tz.TZDateTime(
          location,
          local.year,
          local.month,
          local.day,
          local.hour,
          local.minute,
          local.second,
        ).toUtc();
      },
    );
  });

  test('meteor maxima materialize onto the nearest local morning block', () {
    final rows =
        <
          ({
            String id,
            String timeZone,
            DateTime sourceLocal,
            DateTime startLocal,
            DateTime endLocal,
          })
        >[
          (
            id: 'lyrids-2027',
            timeZone: 'America/Los_Angeles',
            sourceLocal: DateTime(2027, 4, 22, 18, 40),
            startLocal: DateTime(2027, 4, 23),
            endLocal: DateTime(2027, 4, 23, 5),
          ),
          (
            id: 'quadrantids-2027',
            timeZone: 'America/Los_Angeles',
            sourceLocal: DateTime(2027, 1, 3, 19, 25),
            startLocal: DateTime(2027, 1, 4),
            endLocal: DateTime(2027, 1, 4, 5),
          ),
          (
            id: 'eta-aquariids-2027',
            timeZone: 'America/Los_Angeles',
            sourceLocal: DateTime(2027, 5, 6, 2),
            startLocal: DateTime(2027, 5, 6),
            endLocal: DateTime(2027, 5, 6, 5),
          ),
          (
            id: 'perseids-2027',
            timeZone: 'America/Los_Angeles',
            sourceLocal: DateTime(2027, 8, 13, 2),
            startLocal: DateTime(2027, 8, 13),
            endLocal: DateTime(2027, 8, 13, 5),
          ),
          (
            id: 'leonids-2027',
            timeZone: 'America/Los_Angeles',
            sourceLocal: DateTime(2027, 11, 17, 22),
            startLocal: DateTime(2027, 11, 18),
            endLocal: DateTime(2027, 11, 18, 5),
          ),
          (
            id: 'ursids-2027',
            timeZone: 'America/Los_Angeles',
            sourceLocal: DateTime(2027, 12, 22, 20),
            startLocal: DateTime(2027, 12, 23),
            endLocal: DateTime(2027, 12, 23, 5),
          ),
          (
            id: 'lyrids-2027',
            timeZone: 'America/New_York',
            sourceLocal: DateTime(2027, 4, 22, 21, 40),
            startLocal: DateTime(2027, 4, 23),
            endLocal: DateTime(2027, 4, 23, 5),
          ),
        ];

    for (final row in rows) {
      final event = catalog.byId(row.id)!;
      final sourceLocal = materializer.toLocal(
        event.primaryInstantUtc,
        row.timeZone,
      );
      final occurrence = materializer.materialize(
        event: event,
        ianaTimeZone: row.timeZone,
      );

      expect(_civilTime(sourceLocal), row.sourceLocal, reason: row.id);
      expect(occurrence.startsAtLocal, row.startLocal, reason: row.id);
      expect(occurrence.endsAtLocal, row.endLocal, reason: row.id);
      expect(occurrence.allDay, isFalse, reason: row.id);
      expect(event.precision, SkyEventPrecision.approximate, reason: row.id);
      expect(occurrence.detail, contains('Best tonight'), reason: row.id);
    }
  });
}

DateTime _civilTime(DateTime value) => DateTime(
  value.year,
  value.month,
  value.day,
  value.hour,
  value.minute,
  value.second,
);
