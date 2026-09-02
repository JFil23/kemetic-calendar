import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SkyCatalog catalog;
  late TrackSkyEnrollmentService enrollment;
  late List<MaterializedSkyOccurrence> canonical;

  setUpAll(() {
    tzdata.initializeTimeZones();
    catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
    enrollment = TrackSkyEnrollmentService(
      materializer: TrackSkyMaterializer(
        toLocal: (utc, iana) =>
            tz.TZDateTime.from(utc.toUtc(), tz.getLocation(iana)),
        toUtc: (local, iana) => tz.TZDateTime(
          tz.getLocation(iana),
          local.year,
          local.month,
          local.day,
          local.hour,
          local.minute,
          local.second,
        ).toUtc(),
      ),
      visibilityService: const SkyVisibilityService(),
    );
    canonical = enrollment.buildCanonicalOccurrences(
      catalog: catalog,
      ianaTimeZone: 'America/Los_Angeles',
    );
  });

  setUp(clearTrackSkyFlowDataCacheForTest);

  test('canonical occurrence builder produces 65 unique occurrences', () {
    expect(canonical, hasLength(65));
    expect(canonical.map((row) => row.skyEventId).toSet(), hasLength(65));
  });

  test('reconciliation creates all 65 when no children exist', () {
    final plan = const TrackSkyOccurrenceReconciler().plan(
      expectedOccurrences: canonical,
      existingChildren: const <PersistedTrackSkyChild>[],
    );

    expect(plan.missingOccurrences, hasLength(65));
    expect(plan.existingSkyEventIds, isEmpty);
  });

  test('reconciliation creates only the missing five from 60 children', () {
    final plan = const TrackSkyOccurrenceReconciler().plan(
      expectedOccurrences: canonical,
      existingChildren: _persisted(canonical.take(60)),
    );

    expect(plan.missingOccurrences, hasLength(5));
    expect(
      plan.missingOccurrences.map((row) => row.skyEventId),
      canonical.skip(60).map((row) => row.skyEventId),
    );
  });

  test('reconciliation creates nothing from 65 children', () {
    final plan = const TrackSkyOccurrenceReconciler().plan(
      expectedOccurrences: canonical,
      existingChildren: _persisted(canonical),
    );

    expect(plan.missingOccurrences, isEmpty);
    expect(plan.expectedSkyEventIds, plan.existingSkyEventIds);
    expect(plan.duplicateSkyEventIds, isEmpty);
  });

  test('duplicate children never create another occurrence', () {
    final existing = <PersistedTrackSkyChild>[
      ..._persisted(canonical),
      _persisted(canonical.take(1)).single,
    ];
    final plan = const TrackSkyOccurrenceReconciler().plan(
      expectedOccurrences: canonical,
      existingChildren: existing,
    );

    expect(plan.missingOccurrences, isEmpty);
    expect(plan.duplicateSkyEventIds, {canonical.first.skyEventId});
  });

  test('merged lunar eclipses remain metadata on one Full Moon occurrence', () {
    final mergedNights = enrollment
        .canonicalNights(catalog: catalog)
        .where((night) => night.companion != null)
        .toList();
    final canonicalIds = canonical.map((row) => row.skyEventId).toSet();

    expect(mergedNights, hasLength(5));
    for (final night in mergedNights) {
      expect(canonicalIds, contains(night.skyEventId));
      expect(canonicalIds, isNot(contains(night.companion!.id)));
    }
  });

  test('preview event IDs equal canonical occurrence IDs', () async {
    final preview = await loadTrackSkyFlowData(TrackSkyTimeZone.pacific);

    expect(
      preview.events.map((row) => row.skyEventId).toSet(),
      canonical.map((row) => row.skyEventId).toSet(),
    );
  });

  test(
    'persistence reconciliation stages five missing children then becomes a no-op',
    () async {
      final draft = enrollment.buildJoinDraft(
        catalog: catalog,
        eligibleNights: enrollment.canonicalNights(catalog: catalog),
        ianaTimeZone: 'America/Los_Angeles',
        timezoneKey: 'pacific',
      );
      final eventWrites = <Map<String, dynamic>>[];
      final flowWrites = <Map<String, Object?>>[];
      final service = FlowJoinService(
        upsertFlow:
            ({
              id,
              required name,
              required color,
              required active,
              calendarId,
              startDate,
              endDate,
              notes,
              required rules,
              originType,
            }) async {
              flowWrites.add({
                'id': id,
                'startDate': startDate,
                'endDate': endDate,
                'rules': rules,
              });
              return 956;
            },
        upsertEvent:
            ({
              required clientEventId,
              required title,
              required startsAtUtc,
              detail,
              allDay = false,
              endsAtUtc,
              flowLocalId,
              category,
              actionId,
              behaviorPayload,
              calendarId,
              caller,
            }) async {
              eventWrites.add({
                'clientEventId': clientEventId,
                'behaviorPayload': behaviorPayload,
                'flowLocalId': flowLocalId,
                'caller': caller,
              });
            },
        publishHeadlessCalendarInvalidation:
            ({required reason, required flowId, required clientEventIds}) {},
      );

      final repair = await service.reconcileTrackSkyV2Headless(
        flowId: 956,
        flowName: 'Follow the sky',
        flowColor: Colors.amber,
        active: true,
        personalCalendarId: 'calendar-id',
        existingFlowNotes: draft.flowNotes,
        draft: draft,
        existingChildren: _persisted(canonical.take(60)),
      );

      expect(repair.succeeded, isTrue);
      expect(repair.plannedNoteCount, 5);
      expect(repair.clientEventIds, hasLength(5));
      expect(eventWrites, isEmpty);
      await repair.persistInBackground!();
      expect(eventWrites, hasLength(5));
      expect(
        eventWrites
            .map(
              (row) => TrackSkyEventOwnership.skyEventIdFromPayload(
                row['behaviorPayload'] as Map<String, dynamic>?,
              ),
            )
            .toSet(),
        canonical.skip(60).map((row) => row.skyEventId).toSet(),
      );
      expect(
        eventWrites.every(
          (row) => row['caller'] == 'track_sky_v2_reconcile_headless',
        ),
        isTrue,
      );

      final complete = await service.reconcileTrackSkyV2Headless(
        flowId: 956,
        flowName: 'Follow the sky',
        flowColor: Colors.amber,
        active: true,
        personalCalendarId: 'calendar-id',
        existingFlowNotes: draft.flowNotes,
        draft: draft,
        existingChildren: _persisted(canonical),
      );

      expect(complete.succeeded, isTrue);
      expect(complete.clientEventIds, isEmpty);
      expect(complete.persistInBackground, isNull);
      expect(flowWrites, hasLength(2));
      final rules = jsonDecode(flowWrites.last['rules']! as String) as List;
      final rule = Map<String, dynamic>.from(rules.single as Map);
      final ruleDates = (rule['dates'] as List).toSet();
      final canonicalLocalDates = canonical
          .map(
            (row) => tz.TZDateTime(
              tz.getLocation('America/Los_Angeles'),
              row.startsAtLocal.year,
              row.startsAtLocal.month,
              row.startsAtLocal.day,
            ).millisecondsSinceEpoch,
          )
          .toSet();
      expect(ruleDates, canonicalLocalDates);
      expect(ruleDates, hasLength(63));
    },
  );

  test('late 2027 and final catalog nights remain materialized', () {
    final byId = <String, MaterializedSkyOccurrence>{
      for (final row in canonical) row.skyEventId: row,
    };

    expect(byId['full-moon-2027-11-14'], isNotNull);
    expect(byId['full-moon-2027-11-14']!.startsAtUtc.year, 2027);
    expect(byId['full-moon-2028-02-10'], canonical.last);
  });
}

List<PersistedTrackSkyChild> _persisted(
  Iterable<MaterializedSkyOccurrence> occurrences,
) {
  return <PersistedTrackSkyChild>[
    for (final occurrence in occurrences)
      PersistedTrackSkyChild(
        clientEventId: 'persisted-${occurrence.skyEventId}',
        behaviorPayload: occurrence.behaviorPayload,
      ),
  ];
}
