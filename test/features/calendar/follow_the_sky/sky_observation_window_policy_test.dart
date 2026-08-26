import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late SkyCatalog catalog;
  late TrackSkyMaterializer materializer;

  DateTime toLocal(DateTime utc, String iana) {
    return tz.TZDateTime.from(utc.toUtc(), tz.getLocation(iana));
  }

  DateTime toUtc(DateTime local, String iana) {
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
  }

  setUpAll(() {
    tzdata.initializeTimeZones();
    catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
    materializer = TrackSkyMaterializer(toLocal: toLocal, toUtc: toUtc);
  });

  test('season occurrences begin at every locked astronomical instant', () {
    const locked = <String, String>{
      'autumn-equinox-2026': '2026-09-23T00:06:00Z',
      'winter-solstice-2026': '2026-12-21T20:50:00Z',
      'spring-equinox-2027': '2027-03-20T20:25:00Z',
      'summer-solstice-2027': '2027-06-21T14:11:00Z',
      'autumn-equinox-2027': '2027-09-23T06:02:00Z',
      'winter-solstice-2027': '2027-12-22T02:43:00Z',
    };

    for (final row in locked.entries) {
      final event = catalog.byId(row.key)!;
      final expectedUtc = DateTime.parse(row.value).toUtc();
      final expectedLocal = toLocal(expectedUtc, 'America/Los_Angeles');
      final occurrence = materializer.materialize(
        event: event,
        ianaTimeZone: 'America/Los_Angeles',
      );

      expect(event.primaryInstantUtc, expectedUtc, reason: row.key);
      expect(occurrence.startsAtUtc, expectedUtc, reason: row.key);
      expect(occurrence.startsAtLocal, expectedLocal, reason: row.key);
      expect(
        occurrence.endsAtLocal,
        expectedLocal.add(const Duration(hours: 1)),
        reason: row.key,
      );
      expect(occurrence.allDay, isFalse, reason: row.key);
    }
  });

  test('solar eclipses retain honest all-day observation semantics', () {
    const locked = <String, String>{
      'solar-eclipse-2027-02-06': '2027-02-06T16:00:00Z',
      'solar-eclipse-2027-08-02': '2027-08-02T10:07:00Z',
      'solar-eclipse-2028-01-26': '2028-01-26T15:08:00Z',
    };

    for (final row in locked.entries) {
      final event = catalog.byId(row.key)!;
      final expectedUtc = DateTime.parse(row.value).toUtc();
      final occurrence = materializer.materialize(
        event: event,
        ianaTimeZone: 'America/Los_Angeles',
      );
      final visibility = const SkyVisibilityService().decide(event);

      expect(event.primaryInstantUtc, expectedUtc, reason: row.key);
      expect(occurrence.allDay, isTrue, reason: row.key);
      expect(
        occurrence.endsAtLocal.difference(occurrence.startsAtLocal),
        const Duration(days: 1),
        reason: row.key,
      );
      expect(
        occurrence.detail,
        contains(
          'Global greatest eclipse (UTC): ${expectedUtc.toIso8601String()}',
        ),
        reason: row.key,
      );
      expect(visibility.canClaimLocalVisibility, isFalse, reason: row.key);
      expect(
        visibility.userFacingNote,
        contains('Visibility depends on where you are'),
        reason: row.key,
      );
    }
  });

  test('non-solar observation windows retain their production behavior', () {
    final rows =
        <({String id, DateTime startLocal, DateTime endLocal, bool allDay})>[
          (
            id: 'full-moon-2026-09-26',
            startLocal: DateTime(2026, 9, 26, 20),
            endLocal: DateTime(2026, 9, 26, 21),
            allDay: false,
          ),
          (
            id: 'lunar-eclipse-2026-08-28',
            startLocal: DateTime(2026, 8, 27, 20),
            endLocal: DateTime(2026, 8, 27, 21),
            allDay: false,
          ),
          (
            id: 'saturn-opposition-2026-10-04',
            startLocal: DateTime(2026, 10, 4, 21),
            endLocal: DateTime(2026, 10, 4, 22),
            allDay: false,
          ),
          (
            id: 'mercury-elongation-2026-10-12',
            startLocal: DateTime(2026, 10, 12),
            endLocal: DateTime(2026, 10, 13),
            allDay: true,
          ),
          (
            id: 'mars-jupiter-conjunction-2026-11-16',
            startLocal: DateTime(2026, 11, 15),
            endLocal: DateTime(2026, 11, 16),
            allDay: true,
          ),
        ];

    for (final row in rows) {
      final window = const SkyObservationWindowPolicy().resolve(
        event: catalog.byId(row.id)!,
        ianaTimeZone: 'America/Los_Angeles',
        toLocal: toLocal,
      );
      expect(window.startLocal, row.startLocal, reason: row.id);
      expect(window.endLocal, row.endLocal, reason: row.id);
      expect(window.allDay, row.allDay, reason: row.id);
    }
  });

  test('visibility and materialization delegate to the same policy', () {
    final policy = _RecordingObservationWindowPolicy();
    final event = catalog.byId('full-moon-2026-09-26')!;
    final delegatedMaterializer = TrackSkyMaterializer(
      toLocal: toLocal,
      toUtc: toUtc,
      windowPolicy: policy,
    );
    final visibility = SkyVisibilityService(windowPolicy: policy);

    final occurrence = delegatedMaterializer.materialize(
      event: event,
      ianaTimeZone: 'America/Los_Angeles',
    );
    final viewingWindow = visibility.localViewingWindow(
      event: event,
      ianaTimeZone: 'America/Los_Angeles',
      toLocal: toLocal,
    );

    expect(policy.calls, 2);
    expect(occurrence.startsAtLocal, policy.window.startLocal);
    expect(occurrence.endsAtLocal, policy.window.endLocal);
    expect(viewingWindow, policy.window);
  });

  test('the event-kind timing switch has one source owner', () {
    final materializerSource = File(
      'lib/features/calendar/follow_the_sky/services/'
      'track_sky_materializer.dart',
    ).readAsStringSync();
    final visibilitySource = File(
      'lib/features/calendar/follow_the_sky/services/'
      'sky_visibility_service.dart',
    ).readAsStringSync();
    final policySource = File(
      'lib/features/calendar/follow_the_sky/services/'
      'sky_observation_window_policy.dart',
    ).readAsStringSync();

    expect(materializerSource, isNot(contains('defaultWindowBuilder')));
    expect(materializerSource, isNot(contains('meteorViewingWindow')));
    expect(visibilitySource, isNot(contains('switch (event.kind)')));
    expect(policySource, contains('switch (event.kind)'));
  });
}

class _RecordingObservationWindowPolicy extends SkyObservationWindowPolicy {
  final SkyObservationWindow window = (
    startLocal: DateTime(2026, 9, 26, 19),
    endLocal: DateTime(2026, 9, 26, 20),
    allDay: false,
  );
  int calls = 0;

  @override
  SkyObservationWindow resolve({
    required SkyEvent event,
    required String ianaTimeZone,
    required DateTime Function(DateTime utc, String ianaTimeZone) toLocal,
  }) {
    calls += 1;
    return window;
  }
}
