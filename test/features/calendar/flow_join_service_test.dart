import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_invalidation.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/maat_flow_catalog.dart';
import 'package:mobile/features/calendar/maat_flow_identity.dart';
import 'package:mobile/features/calendar/maat_decan_flow.dart';
import 'package:mobile/features/calendar/moon_return_astronomy.dart';
import 'package:mobile/features/calendar/moon_return_flow.dart';
import 'package:mobile/features/calendar/the_decan_watch_enrollment.dart';
import 'package:mobile/features/calendar/the_decan_watch_flow.dart';
import 'package:mobile/features/calendar/the_djed_enrollment.dart';
import 'package:mobile/features/calendar/the_djed_flow.dart';
import 'package:mobile/features/calendar/the_djed_v2_flow.dart';
import 'package:mobile/features/calendar/the_course_flow.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/the_open_hand_enrollment.dart';
import 'package:mobile/features/calendar/the_open_hand_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:mobile/utils/event_cid_util.dart';

const DjedV2Configuration _testDjedV2Configuration = DjedV2Configuration(
  supports: <DjedV2SupportDefinition>[
    DjedV2SupportDefinition(
      slot: 1,
      name: 'daily energy',
      initialCondition: DjedV2SupportCondition.underPressure,
    ),
    DjedV2SupportDefinition(
      slot: 2,
      name: 'the work',
      initialCondition: DjedV2SupportCondition.holding,
    ),
    DjedV2SupportDefinition(
      slot: 3,
      name: 'home',
      initialCondition: DjedV2SupportCondition.wobbling,
    ),
    DjedV2SupportDefinition(
      slot: 4,
      name: 'close relationships',
      initialCondition: DjedV2SupportCondition.holding,
    ),
  ],
);

void main() {
  test('retired flows stop at the shared creation boundary', () {
    for (final kind in kArchivedCompatibilityMaatFlowKinds) {
      expect(isMaatFlowNewJoinAllowedKind(kind), isFalse, reason: kind.flowKey);
      expect(
        () => ensureNewFlowCreationAllowedByMaatCatalog(flowKey: kind.flowKey),
        throwsA(isA<NonJoinableMaatFlowException>()),
        reason: kind.flowKey,
      );
    }
  });

  test(
    'default enrollment resolvers return no-window failures without throwing',
    () async {
      final timezone = TrackSkyTimeZone.pacific;
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
              fail('No-window joins must not persist a flow.');
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
              fail('No-window joins must not persist events.');
            },
        fileHeadlessEventDelivery:
            ({
              required eventFiling,
              required debugLabel,
              required clientEventId,
              required startsAtLocal,
              required alertOffsetMinutes,
              required title,
              body,
            }) async {
              fail('No-window joins must not file delivery.');
            },
        publishHeadlessCalendarInvalidation:
            ({required reason, required flowId, required clientEventIds}) {
              fail('No-window joins must not publish invalidation.');
            },
      );

      Future<void> expectNoEnrollmentWindow(
        String label,
        Future<FlowJoinResult> Function(DateTime startDate) join,
        DateTime startDate, {
        FlowJoinFailureCode expected = FlowJoinFailureCode.noEnrollmentWindow,
      }) async {
        final result = await join(startDate);
        expect(result.succeeded, isFalse, reason: label);
        expect(result.failureCode, expected, reason: label);
        expect(result.flowIdOrNegativeOne, -1, reason: label);
        expect(result.clientEventIds, isEmpty, reason: label);
      }

      await expectNoEnrollmentWindow(
        'Moon Return',
        (startDate) => service.joinMoonReturnHeadless(
          templateKey: kMoonReturnFlowKey,
          templateTitle: kMoonReturnTitle,
          templateOverview: kMoonReturnOverview,
          templateColor: Colors.indigo,
          personalCalendarId: 'personal-calendar',
          timezone: timezone,
          startDate: startDate,
        ),
        _firstUnavailableEnrollmentStart<MoonReturnEnrollmentWindow>(
          (startDate) => resolveMoonReturnEnrollmentWindowSafely(
            timezone: timezone,
            startDate: startDate,
          ),
        ),
      );

      for (final kind in const <MaatFlowKind>[
        MaatFlowKind.theWag,
        MaatFlowKind.daysOutsideTheYear,
      ]) {
        expect(isMaatFlowNewJoinAllowedKind(kind), isFalse);
        expect(
          () =>
              ensureNewFlowCreationAllowedByMaatCatalog(flowKey: kind.flowKey),
          throwsA(isA<NonJoinableMaatFlowException>()),
        );
      }

      await expectNoEnrollmentWindow(
        'Decan Watch',
        (startDate) => service.joinDecanWatchHeadless(
          templateKey: kDecanWatchFlowKey,
          templateTitle: kDecanWatchTitle,
          templateOverview: kDecanWatchOverview,
          templateColor: Colors.blue,
          personalCalendarId: 'personal-calendar',
          timezone: timezone,
          startDate: startDate,
        ),
        _firstUnavailableEnrollmentStart<DecanWatchEnrollmentWindow>(
          (startDate) => resolveDecanWatchEnrollmentWindowSafely(
            timezone: timezone,
            startDate: startDate,
          ),
        ),
      );

      await expectNoEnrollmentWindow(
        'Open Hand',
        (startDate) => service.joinOpenHandHeadless(
          templateKey: kTheOpenHandFlowKey,
          templateTitle: kTheOpenHandTitle,
          templateOverview: kOpenHandOverview,
          templateColor: Colors.green,
          personalCalendarId: 'personal-calendar',
          timezone: timezone,
          startDate: startDate,
        ),
        _firstUnavailableEnrollmentStart<OpenHandEnrollmentWindow>(
          (startDate) => resolveOpenHandEnrollmentWindowSafely(
            timezone: timezone,
            startDate: startDate,
          ),
        ),
      );

      await expectNoEnrollmentWindow(
        'Djed',
        (startDate) => service.joinDjedHeadless(
          templateKey: kTheDjedFlowKey,
          templateTitle: kTheDjedTitle,
          templateOverview: kDjedOverview,
          templateColor: Colors.teal,
          personalCalendarId: 'personal-calendar',
          timezone: timezone,
          startDate: startDate,
          configuration: _testDjedV2Configuration,
        ),
        _firstUnavailableEnrollmentStart<DjedEnrollmentWindow>(
          (startDate) => resolveDjedEnrollmentWindowSafely(
            timezone: timezone,
            startDate: startDate,
          ),
        ),
      );
    },
  );

  test(
    'headless Moon Return join persists, files at-time delivery, invalidates once, and returns success',
    () async {
      final timezone = TrackSkyTimeZone.eastern;
      final selectedStart = DateTime(2026, 1, 1);
      final enrolledAt = DateTime(2026, 1, 1, 9);
      final window = MoonReturnEnrollmentWindow(
        opensAtLocal: selectedStart,
        closesAtLocal: DateTime(2026, 1, 2),
        newMoonInstantLocal: DateTime(2026, 1, 1, 12),
        newMoonInstantUtc: DateTime.utc(2026, 1, 1, 17),
        newMoonDateIso: '2026-01-01',
        enrollProminence: MoonReturnCopyVariant.standard,
        timezone: timezone,
      );
      final occurrence = MoonReturnOccurrence(
        kind: MoonReturnEventKind.emptyEye,
        startLocal: DateTime(2026, 1, 1, 18),
        endLocal: DateTime(2026, 1, 1, 18, 5),
        startUtc: DateTime.utc(2026, 1, 1, 23),
        endUtc: DateTime.utc(2026, 1, 1, 23, 5),
        phaseDateIso: '2026-01-01',
        variant: MoonReturnCopyVariant.standard,
        isBonusBlueMoon: false,
        timezone: timezone,
        scheduleType: 'local_dusk_new_moon',
        referenceLocationName: 'Test horizon',
        usedFallback: false,
      );

      final flowCalls = <Map<String, Object?>>[];
      final eventCalls = <Map<String, Object?>>[];
      final deliveryCalls = <Map<String, Object?>>[];
      final invalidations = <CalendarInvalidated>[];

      final service = FlowJoinService(
        resolveMoonReturnWindow: ({required timezone, startDate}) {
          expect(timezone, TrackSkyTimeZone.eastern);
          expect(startDate, selectedStart);
          return window;
        },
        moonReturnOccurrencesForWindow: ({required window}) {
          expect(window.newMoonDateIso, '2026-01-01');
          return <MoonReturnOccurrence>[occurrence];
        },
        moonReturnNowInZone: (timezone) {
          expect(timezone, TrackSkyTimeZone.eastern);
          return enrolledAt;
        },
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
              flowCalls.add({
                'name': name,
                'active': active,
                'calendarId': calendarId,
                'startDate': startDate,
                'endDate': endDate,
                'notes': notes,
                'rules': rules,
                'originType': originType,
              });
              return 42;
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
              eventCalls.add({
                'clientEventId': clientEventId,
                'title': title,
                'startsAtUtc': startsAtUtc,
                'detail': detail,
                'allDay': allDay,
                'endsAtUtc': endsAtUtc,
                'flowLocalId': flowLocalId,
                'category': category,
                'actionId': actionId,
                'behaviorPayload': behaviorPayload,
                'calendarId': calendarId,
                'caller': caller,
              });
            },
        fileHeadlessEventDelivery:
            ({
              required eventFiling,
              required debugLabel,
              required clientEventId,
              required startsAtLocal,
              required alertOffsetMinutes,
              required title,
              body,
            }) async {
              deliveryCalls.add({
                'debugLabel': debugLabel,
                'clientEventId': clientEventId,
                'startsAtLocal': startsAtLocal,
                'alertOffsetMinutes': alertOffsetMinutes,
                'title': title,
                'body': body,
              });
            },
        publishHeadlessCalendarInvalidation:
            ({required reason, required flowId, required clientEventIds}) {
              invalidations.add(
                CalendarInvalidated(
                  reason: reason,
                  flowId: flowId,
                  clientEventIds: List<String>.from(clientEventIds),
                ),
              );
            },
      );

      final result = await service.joinMoonReturnHeadless(
        templateKey: kMoonReturnFlowKey,
        templateTitle: kMoonReturnTitle,
        templateOverview: kMoonReturnOverview,
        templateColor: Colors.indigo,
        personalCalendarId: 'personal-calendar',
        timezone: timezone,
        startDate: selectedStart,
        lens: MoonReturnLens.heru,
        alertOffsetMinutes: 0,
      );

      expect(result.succeeded, isTrue);
      expect(result.hasLocalFastPath, isTrue);
      expect(result.persistInBackground, isNotNull);
      expect(eventCalls, isEmpty);
      expect(deliveryCalls, isEmpty);
      expect(invalidations, isEmpty);
      await result.persistInBackground!();
      await Future<void>.delayed(Duration.zero);
      expect(result.flowId, 42);
      expect(result.flowIdOrZero, 42);
      expect(result.clientEventIds, <String>['moon-return:42:new:2026-01-01']);

      expect(flowCalls, hasLength(1));
      expect(flowCalls.single['name'], kMoonReturnTitle);
      expect(flowCalls.single['calendarId'], 'personal-calendar');
      expect(flowCalls.single['startDate'], DateTime(2026, 1, 1));
      expect(flowCalls.single['endDate'], DateTime(2026, 1, 1));
      expect(flowCalls.single['originType'], 'template');
      expect(flowCalls.single['notes'], contains('maat=$kMoonReturnFlowKey'));
      expect(flowCalls.single['notes'], contains('moon_tz=eastern'));
      expect(flowCalls.single['notes'], contains('moon_lens=heru'));
      expect(
        flowCalls.single['notes'],
        contains('moon_enrolled_at=${enrolledAt.toIso8601String()}'),
      );
      final rules = jsonDecode(flowCalls.single['rules']! as String) as List;
      expect(rules.single, containsPair('type', 'dates'));

      expect(eventCalls, hasLength(1));
      expect(
        eventCalls.single['clientEventId'],
        'moon-return:42:new:2026-01-01',
      );
      expect(eventCalls.single['startsAtUtc'], occurrence.startUtc);
      expect(eventCalls.single['endsAtUtc'], occurrence.endUtc);
      expect(eventCalls.single['flowLocalId'], 42);
      expect(eventCalls.single['category'], 'Ritual');
      expect(eventCalls.single['caller'], 'moon_return_join_headless');
      expect(eventCalls.single['actionId'], 'the-moon-return-new-2026-01-01');
      expect(eventCalls.single['behaviorPayload'], isA<Map<String, dynamic>>());

      expect(deliveryCalls, hasLength(1));
      expect(
        deliveryCalls.single['clientEventId'],
        'moon-return:42:new:2026-01-01',
      );
      expect(deliveryCalls.single['startsAtLocal'], occurrence.startLocal);
      expect(deliveryCalls.single['alertOffsetMinutes'], 0);
      expect(deliveryCalls.single['debugLabel'], 'moonReturnHeadless');

      expect(invalidations, hasLength(1));
      expect(
        invalidations.single.reason,
        CalendarInvalidationReason.flowJoined,
      );
      expect(invalidations.single.flowId, 42);
      expect(invalidations.single.clientEventIds, <String>[
        'moon-return:42:new:2026-01-01',
      ]);
    },
  );

  test(
    'headless Moon Return backlog rows persist as quiet calendar records, not completion evidence',
    () async {
      final timezone = TrackSkyTimeZone.eastern;
      final selectedStart = DateTime(2026, 1, 15);
      final window = MoonReturnEnrollmentWindow(
        opensAtLocal: selectedStart,
        closesAtLocal: DateTime(2026, 1, 16),
        newMoonInstantLocal: DateTime(2026, 1, 15, 12),
        newMoonInstantUtc: DateTime.utc(2026, 1, 15, 17),
        newMoonDateIso: '2026-01-15',
        enrollProminence: MoonReturnCopyVariant.standard,
        timezone: timezone,
      );

      MoonReturnOccurrence occurrence({
        required MoonReturnEventKind kind,
        required DateTime startLocal,
        required String phaseDateIso,
      }) {
        return MoonReturnOccurrence(
          kind: kind,
          startLocal: startLocal,
          endLocal: startLocal.add(
            const Duration(minutes: kMoonReturnDurationMinutes),
          ),
          startUtc: startLocal.toUtc(),
          endUtc: startLocal
              .add(const Duration(minutes: kMoonReturnDurationMinutes))
              .toUtc(),
          phaseDateIso: phaseDateIso,
          variant: MoonReturnCopyVariant.standard,
          isBonusBlueMoon: false,
          timezone: timezone,
          scheduleType: 'test_schedule',
          referenceLocationName: 'Test horizon',
          usedFallback: false,
        );
      }

      final backfilledOccurrence = occurrence(
        kind: MoonReturnEventKind.wholeEye,
        startLocal: DateTime(2026, 1, 1, 18),
        phaseDateIso: '2026-01-01',
      );
      final futureOccurrence = occurrence(
        kind: MoonReturnEventKind.emptyEye,
        startLocal: DateTime(2026, 1, 29, 18),
        phaseDateIso: '2026-01-29',
      );

      final eventCalls = <Map<String, Object?>>[];
      final deliveryCalls = <Map<String, Object?>>[];
      final invalidations = <CalendarInvalidated>[];

      final service = FlowJoinService(
        resolveMoonReturnWindow: ({required timezone, startDate}) => window,
        moonReturnOccurrencesForWindow: ({required window}) =>
            <MoonReturnOccurrence>[backfilledOccurrence, futureOccurrence],
        moonReturnNowInZone: (_) => DateTime(2026, 1, 15, 9),
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
            }) async => 43,
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
              eventCalls.add({
                'clientEventId': clientEventId,
                'behaviorPayload': behaviorPayload,
                'caller': caller,
              });
            },
        fileHeadlessEventDelivery:
            ({
              required eventFiling,
              required debugLabel,
              required clientEventId,
              required startsAtLocal,
              required alertOffsetMinutes,
              required title,
              body,
            }) async {
              deliveryCalls.add({
                'clientEventId': clientEventId,
                'startsAtLocal': startsAtLocal,
              });
            },
        publishHeadlessCalendarInvalidation:
            ({required reason, required flowId, required clientEventIds}) {
              invalidations.add(
                CalendarInvalidated(
                  reason: reason,
                  flowId: flowId,
                  clientEventIds: List<String>.from(clientEventIds),
                ),
              );
            },
      );

      final result = await service.joinMoonReturnHeadless(
        templateKey: kMoonReturnFlowKey,
        templateTitle: kMoonReturnTitle,
        templateOverview: kMoonReturnOverview,
        templateColor: Colors.indigo,
        personalCalendarId: 'personal-calendar',
        timezone: timezone,
        startDate: selectedStart,
        alertOffsetMinutes: 0,
      );

      expect(result.succeeded, isTrue);
      expect(result.hasLocalFastPath, isTrue);
      expect(result.persistInBackground, isNotNull);
      expect(eventCalls, isEmpty);
      expect(deliveryCalls, isEmpty);
      expect(invalidations, isEmpty);
      await result.persistInBackground!();
      await Future<void>.delayed(Duration.zero);
      expect(result.clientEventIds, <String>[
        'moon-return:43:full:2026-01-01',
        'moon-return:43:new:2026-01-29',
      ]);
      expect(eventCalls, hasLength(2));
      expect(deliveryCalls, hasLength(2));
      expect(invalidations, hasLength(1));

      final backfilledPayload =
          eventCalls.first['behaviorPayload']! as Map<String, dynamic>;
      expect(backfilledPayload['missed_event_rule'], 'expire_quietly');
      expect(backfilledPayload, isNot(contains('status')));
      expect(backfilledPayload, isNot(contains('completion')));
      expect(backfilledPayload['completion_options'], contains('skipped'));
      expect(eventCalls.first['caller'], 'moon_return_join_headless');
    },
  );
  test(
    'headless Decan Watch join persists events, files at-time delivery, invalidates once, and returns success',
    () async {
      final timezone = TrackSkyTimeZone.pacific;
      final selectedStart = DateTime(2026, 9, 1);
      final enrolledAt = DateTime(2026, 9, 1, 17);

      DecanWatchOccurrence occurrence({
        required int decanIndex,
        required int decanStartDay,
      }) {
        final startLocal = DateTime(2026, 9, decanStartDay, 21);
        final endLocal = startLocal.add(
          const Duration(minutes: kDecanWatchDurationMinutes),
        );
        final startUtc = DateTime.utc(2026, 9, decanStartDay, 4);
        final endUtc = startUtc.add(
          const Duration(minutes: kDecanWatchDurationMinutes),
        );
        return DecanWatchOccurrence(
          kYear: 3,
          kMonth: 4,
          decanIndex: decanIndex,
          decanStartDay: decanStartDay,
          globalDecanId: 9 + decanIndex,
          decanName: 'Test Decan $decanIndex',
          eventDateIso: '2026-09-${decanStartDay.toString().padLeft(2, '0')}',
          timezone: timezone,
          scheduleHour: kDecanWatchDefaultHour,
          scheduleMinute: kDecanWatchDefaultMinute,
          startLocal: startLocal,
          endLocal: endLocal,
          startUtc: startUtc,
          endUtc: endUtc,
        );
      }

      final occurrences = <DecanWatchOccurrence>[
        occurrence(decanIndex: 1, decanStartDay: 1),
        occurrence(decanIndex: 2, decanStartDay: 11),
        occurrence(decanIndex: 3, decanStartDay: 21),
      ];
      final window = DecanWatchEnrollmentWindow(
        opensAtLocal: selectedStart,
        closesAtLocal: DateTime(2026, 9, 2),
        openingOccurrence: occurrences.first,
      );

      final flowCalls = <Map<String, Object?>>[];
      final eventCalls = <Map<String, Object?>>[];
      final deliveryCalls = <Map<String, Object?>>[];
      final invalidations = <CalendarInvalidated>[];

      final service = FlowJoinService(
        resolveDecanWatchWindow: ({required timezone, startDate}) {
          expect(timezone, TrackSkyTimeZone.pacific);
          expect(startDate, selectedStart);
          return window;
        },
        decanWatchOccurrencesForWindow: ({required window, required timezone}) {
          expect(window.openingOccurrence.decanIndex, 1);
          expect(timezone, TrackSkyTimeZone.pacific);
          return occurrences;
        },
        decanWatchNowInZone: (timezone) {
          expect(timezone, TrackSkyTimeZone.pacific);
          return enrolledAt;
        },
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
              flowCalls.add({
                'name': name,
                'active': active,
                'calendarId': calendarId,
                'startDate': startDate,
                'endDate': endDate,
                'notes': notes,
                'rules': rules,
                'originType': originType,
              });
              return 168;
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
              eventCalls.add({
                'clientEventId': clientEventId,
                'title': title,
                'startsAtUtc': startsAtUtc,
                'detail': detail,
                'allDay': allDay,
                'endsAtUtc': endsAtUtc,
                'flowLocalId': flowLocalId,
                'category': category,
                'actionId': actionId,
                'behaviorPayload': behaviorPayload,
                'calendarId': calendarId,
                'caller': caller,
              });
            },
        fileHeadlessEventDelivery:
            ({
              required eventFiling,
              required debugLabel,
              required clientEventId,
              required startsAtLocal,
              required alertOffsetMinutes,
              required title,
              body,
            }) async {
              deliveryCalls.add({
                'debugLabel': debugLabel,
                'clientEventId': clientEventId,
                'startsAtLocal': startsAtLocal,
                'alertOffsetMinutes': alertOffsetMinutes,
                'title': title,
                'body': body,
              });
            },
        publishHeadlessCalendarInvalidation:
            ({required reason, required flowId, required clientEventIds}) {
              invalidations.add(
                CalendarInvalidated(
                  reason: reason,
                  flowId: flowId,
                  clientEventIds: List<String>.from(clientEventIds),
                ),
              );
            },
      );

      final result = await service.joinDecanWatchHeadless(
        templateKey: kDecanWatchFlowKey,
        templateTitle: kDecanWatchTitle,
        templateOverview: kDecanWatchOverview,
        templateColor: Colors.blueGrey,
        personalCalendarId: 'personal-calendar',
        timezone: timezone,
        startDate: selectedStart,
        lens: DecanWatchLens.nut,
        alertOffsetMinutes: 0,
      );

      final expectedIds = <String>[
        for (final occurrence in occurrences)
          'decan-watch:168:3:4:${occurrence.decanIndex}',
      ];

      expect(result.succeeded, isTrue);
      expect(result.hasLocalFastPath, isTrue);
      expect(result.persistInBackground, isNotNull);
      expect(eventCalls, isEmpty);
      expect(deliveryCalls, isEmpty);
      expect(invalidations, isEmpty);
      await result.persistInBackground!();
      await Future<void>.delayed(Duration.zero);
      expect(result.flowId, 168);
      expect(result.clientEventIds, expectedIds);

      expect(flowCalls, hasLength(1));
      expect(flowCalls.single['name'], kDecanWatchTitle);
      expect(flowCalls.single['calendarId'], 'personal-calendar');
      expect(flowCalls.single['startDate'], DateTime(2026, 9, 1));
      expect(flowCalls.single['endDate'], DateTime(2026, 9, 21));
      expect(flowCalls.single['originType'], 'template');
      expect(flowCalls.single['notes'], contains('maat=$kDecanWatchFlowKey'));
      expect(flowCalls.single['notes'], contains('dw_tz=pacific'));
      expect(flowCalls.single['notes'], contains('dw_lens=nut'));
      expect(flowCalls.single['notes'], contains('dw_enrolled_kyear=3'));
      expect(
        flowCalls.single['notes'],
        contains('dw_enrolled_at=${enrolledAt.toIso8601String()}'),
      );
      final rules = jsonDecode(flowCalls.single['rules']! as String) as List;
      expect(rules.single, containsPair('type', 'dates'));

      expect(eventCalls, hasLength(occurrences.length));
      expect(deliveryCalls, hasLength(occurrences.length));
      expect(
        eventCalls.map((call) => call['clientEventId']).toList(),
        expectedIds,
      );
      final firstOccurrence = occurrences.first;
      expect(eventCalls.first['title'], decanWatchEventTitle(firstOccurrence));
      expect(eventCalls.first['startsAtUtc'], firstOccurrence.startUtc);
      expect(eventCalls.first['endsAtUtc'], firstOccurrence.endUtc);
      expect(eventCalls.first['flowLocalId'], 168);
      expect(eventCalls.first['category'], 'Ritual');
      expect(eventCalls.first['caller'], 'decan_watch_join_headless');
      expect(eventCalls.first['actionId'], decanWatchActionId(firstOccurrence));
      final firstPayload =
          eventCalls.first['behaviorPayload']! as Map<String, dynamic>;
      expect(firstPayload['kind'], 'maat_decan_watch');
      expect(firstPayload['flow_key'], kDecanWatchFlowKey);
      expect(firstPayload['k_year'], 3);
      expect(firstPayload['k_month'], 4);
      expect(firstPayload['decan_index'], 1);
      expect(firstPayload['lens'], 'nut');
      expect(firstPayload['schedule'], containsPair('timezone', 'pacific'));

      expect(deliveryCalls.first['clientEventId'], expectedIds.first);
      expect(deliveryCalls.first['startsAtLocal'], firstOccurrence.startLocal);
      expect(deliveryCalls.first['alertOffsetMinutes'], 0);
      expect(deliveryCalls.first['debugLabel'], 'decanWatchHeadless');

      expect(invalidations, hasLength(1));
      expect(
        invalidations.single.reason,
        CalendarInvalidationReason.flowJoined,
      );
      expect(invalidations.single.flowId, 168);
      expect(invalidations.single.clientEventIds, expectedIds);
    },
  );

  test(
    'headless Open Hand join persists events, files at-time delivery, invalidates once, and returns success',
    () async {
      final timezone = TrackSkyTimeZone.central;
      final selectedStart = DateTime(2026, 10, 1);
      final enrolledAt = DateTime(2026, 10, 1, 10);
      final openingOccurrence = DecanWatchOccurrence(
        kYear: 3,
        kMonth: 5,
        decanIndex: 1,
        decanStartDay: 1,
        globalDecanId: 13,
        decanName: 'Test Open Hand Decan',
        eventDateIso: '2026-10-01',
        timezone: timezone,
        scheduleHour: kDecanWatchDefaultHour,
        scheduleMinute: kDecanWatchDefaultMinute,
        startLocal: selectedStart,
        endLocal: selectedStart.add(
          const Duration(minutes: kDecanWatchDurationMinutes),
        ),
        startUtc: DateTime.utc(2026, 10, 1, 5),
        endUtc: DateTime.utc(2026, 10, 1, 5, kDecanWatchDurationMinutes),
      );
      final window = OpenHandEnrollmentWindow(
        opensAtLocal: selectedStart,
        closesAtLocal: DateTime(2026, 10, 2),
        openingOccurrence: openingOccurrence,
      );
      final schedulesByEventNumber = <int, OpenHandOccurrenceSchedule>{};

      OpenHandOccurrenceSchedule scheduleForEvent(OpenHandEvent event) {
        return schedulesByEventNumber.putIfAbsent(event.eventNumber, () {
          final startLocal = selectedStart
              .add(Duration(days: event.flowDay - 1))
              .add(Duration(hours: 7 + event.eventNumber));
          final endLocal = startLocal.add(
            Duration(minutes: event.durationMinutesMax),
          );
          final startUtc = DateTime.utc(
            2026,
            10,
            event.flowDay,
            12 + event.eventNumber,
          );
          final endUtc = startUtc.add(
            Duration(minutes: event.durationMinutesMax),
          );
          return OpenHandOccurrenceSchedule(
            startLocal: startLocal,
            endLocal: endLocal,
            startUtc: startUtc,
            endUtc: endUtc,
            usedFallback: false,
            timezone: timezone,
            referenceLocationName: 'Test horizon',
            scheduleType: 'test_open_hand_schedule',
            fallback: 'test_fallback',
            middayHour: event.slot == OpenHandTimingSlot.checkMidday
                ? kOpenHandDefaultMiddayHour
                : null,
            middayMinute: event.slot == OpenHandTimingSlot.checkMidday
                ? kOpenHandDefaultMiddayMinute
                : null,
          );
        });
      }

      final flowCalls = <Map<String, Object?>>[];
      final eventCalls = <Map<String, Object?>>[];
      final deliveryCalls = <Map<String, Object?>>[];
      final invalidations = <CalendarInvalidated>[];

      final service = FlowJoinService(
        resolveOpenHandWindow: ({required timezone, startDate}) {
          expect(timezone, TrackSkyTimeZone.central);
          expect(startDate, selectedStart);
          return window;
        },
        openHandScheduleForEvent:
            ({required event, required flowStart, required timezone}) {
              expect(flowStart, selectedStart);
              expect(timezone, TrackSkyTimeZone.central);
              return scheduleForEvent(event);
            },
        openHandNowInZone: (timezone) {
          expect(timezone, TrackSkyTimeZone.central);
          return enrolledAt;
        },
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
              flowCalls.add({
                'name': name,
                'active': active,
                'calendarId': calendarId,
                'startDate': startDate,
                'endDate': endDate,
                'notes': notes,
                'rules': rules,
                'originType': originType,
              });
              return 210;
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
              eventCalls.add({
                'clientEventId': clientEventId,
                'title': title,
                'startsAtUtc': startsAtUtc,
                'detail': detail,
                'allDay': allDay,
                'endsAtUtc': endsAtUtc,
                'flowLocalId': flowLocalId,
                'category': category,
                'actionId': actionId,
                'behaviorPayload': behaviorPayload,
                'calendarId': calendarId,
                'caller': caller,
              });
            },
        fileHeadlessEventDelivery:
            ({
              required eventFiling,
              required debugLabel,
              required clientEventId,
              required startsAtLocal,
              required alertOffsetMinutes,
              required title,
              body,
            }) async {
              deliveryCalls.add({
                'debugLabel': debugLabel,
                'clientEventId': clientEventId,
                'startsAtLocal': startsAtLocal,
                'alertOffsetMinutes': alertOffsetMinutes,
                'title': title,
                'body': body,
              });
            },
        publishHeadlessCalendarInvalidation:
            ({required reason, required flowId, required clientEventIds}) {
              invalidations.add(
                CalendarInvalidated(
                  reason: reason,
                  flowId: flowId,
                  clientEventIds: List<String>.from(clientEventIds),
                ),
              );
            },
      );

      final result = await service.joinOpenHandHeadless(
        templateKey: kTheOpenHandFlowKey,
        templateTitle: kTheOpenHandTitle,
        templateOverview: kOpenHandOverview,
        templateColor: Colors.green,
        personalCalendarId: 'personal-calendar',
        timezone: timezone,
        startDate: selectedStart,
        lens: OpenHandLens.hapy,
        alertOffsetMinutes: 0,
      );

      final expectedIds = <String>[
        for (final event in kOpenHandEvents)
          'open-hand:210:event-${event.eventNumber}',
      ];

      expect(result.succeeded, isTrue);
      expect(result.hasLocalFastPath, isTrue);
      expect(result.persistInBackground, isNotNull);
      expect(eventCalls, isEmpty);
      expect(deliveryCalls, isEmpty);
      expect(invalidations, isEmpty);
      await result.persistInBackground!();
      await Future<void>.delayed(Duration.zero);
      expect(result.flowId, 210);
      expect(result.clientEventIds, expectedIds);

      expect(flowCalls, hasLength(1));
      expect(flowCalls.single['name'], kTheOpenHandTitle);
      expect(flowCalls.single['calendarId'], 'personal-calendar');
      expect(flowCalls.single['startDate'], selectedStart);
      expect(
        flowCalls.single['endDate'],
        selectedStart.add(const Duration(days: 29)),
      );
      expect(flowCalls.single['originType'], 'template');
      expect(flowCalls.single['notes'], contains('maat=$kTheOpenHandFlowKey'));
      expect(flowCalls.single['notes'], contains('oh_tz=central'));
      expect(flowCalls.single['notes'], contains('oh_lens=hapy'));
      expect(flowCalls.single['notes'], contains('oh_decan_kyear=3'));
      expect(flowCalls.single['notes'], contains('oh_decan_month=5'));
      expect(flowCalls.single['notes'], contains('oh_decan_day=1'));
      expect(
        flowCalls.single['notes'],
        contains('oh_enrolled_at=${enrolledAt.toIso8601String()}'),
      );
      final rules = jsonDecode(flowCalls.single['rules']! as String) as List;
      expect(rules.single, containsPair('type', 'dates'));

      expect(eventCalls, hasLength(kOpenHandEvents.length));
      expect(deliveryCalls, hasLength(kOpenHandEvents.length));
      expect(
        eventCalls.map((call) => call['clientEventId']).toList(),
        expectedIds,
      );
      final firstEvent = kOpenHandEvents.first;
      final firstSchedule = schedulesByEventNumber[firstEvent.eventNumber]!;
      expect(eventCalls.first['title'], openHandEventTitle(firstEvent));
      expect(eventCalls.first['startsAtUtc'], firstSchedule.startUtc);
      expect(eventCalls.first['endsAtUtc'], firstSchedule.endUtc);
      expect(eventCalls.first['flowLocalId'], 210);
      expect(eventCalls.first['category'], 'Ritual');
      expect(eventCalls.first['caller'], 'open_hand_join_headless');
      expect(eventCalls.first['actionId'], openHandActionId(firstEvent));
      final firstPayload =
          eventCalls.first['behaviorPayload']! as Map<String, dynamic>;
      expect(firstPayload['kind'], 'maat_open_hand_event');
      expect(firstPayload['flow_key'], kTheOpenHandFlowKey);
      expect(firstPayload['event_number'], 1);
      expect(firstPayload['flow_day'], firstEvent.flowDay);
      expect(firstPayload['lens'], 'hapy');
      expect(
        firstPayload['schedule'],
        containsPair('type', 'test_open_hand_schedule'),
      );

      expect(deliveryCalls.first['clientEventId'], expectedIds.first);
      expect(deliveryCalls.first['startsAtLocal'], firstSchedule.startLocal);
      expect(deliveryCalls.first['alertOffsetMinutes'], 0);
      expect(deliveryCalls.first['debugLabel'], 'openHandHeadless');

      expect(invalidations, hasLength(1));
      expect(
        invalidations.single.reason,
        CalendarInvalidationReason.flowJoined,
      );
      expect(invalidations.single.flowId, 210);
      expect(invalidations.single.clientEventIds, expectedIds);
    },
  );

  test(
    'headless Djed join persists events, files at-time delivery, invalidates once, and returns success',
    () async {
      final timezone = TrackSkyTimeZone.mountain;
      final selectedStart = DateTime(2026, 11, 1);
      final enrolledAt = DateTime(2026, 11, 1, 11);
      final openingOccurrence = DecanWatchOccurrence(
        kYear: 3,
        kMonth: 6,
        decanIndex: 1,
        decanStartDay: 1,
        globalDecanId: 16,
        decanName: 'Test Djed Decan',
        eventDateIso: '2026-11-01',
        timezone: timezone,
        scheduleHour: kDecanWatchDefaultHour,
        scheduleMinute: kDecanWatchDefaultMinute,
        startLocal: selectedStart,
        endLocal: selectedStart.add(
          const Duration(minutes: kDecanWatchDurationMinutes),
        ),
        startUtc: DateTime.utc(2026, 11, 1, 6),
        endUtc: DateTime.utc(2026, 11, 1, 6, kDecanWatchDurationMinutes),
      );
      final window = DjedEnrollmentWindow(
        opensAtLocal: selectedStart,
        closesAtLocal: DateTime(2026, 11, 2),
        openingOccurrence: openingOccurrence,
      );
      final schedulesByEventNumber = <int, DjedOccurrenceSchedule>{};

      DjedOccurrenceSchedule scheduleForEvent(DjedV2Event event) {
        return schedulesByEventNumber.putIfAbsent(event.eventNumber, () {
          final startLocal = selectedStart
              .add(Duration(days: event.flowDay - 1))
              .add(Duration(hours: 6 + event.eventNumber));
          final endLocal = startLocal.add(
            Duration(minutes: event.durationMinutes),
          );
          final startUtc = DateTime.utc(
            2026,
            11,
            event.flowDay,
            11 + event.eventNumber,
          );
          final endUtc = startUtc.add(Duration(minutes: event.durationMinutes));
          return DjedOccurrenceSchedule(
            startLocal: startLocal,
            endLocal: endLocal,
            startUtc: startUtc,
            endUtc: endUtc,
            usedFallback: false,
            timezone: timezone,
            referenceLocationName: 'Test horizon',
            scheduleType: 'test_djed_schedule',
            fallback: 'test_fallback',
            middayHour: event.slot == DjedTimingSlot.checkMidday
                ? kDjedDefaultMiddayHour
                : null,
            middayMinute: event.slot == DjedTimingSlot.checkMidday
                ? kDjedDefaultMiddayMinute
                : null,
          );
        });
      }

      final flowCalls = <Map<String, Object?>>[];
      final eventCalls = <Map<String, Object?>>[];
      final deliveryCalls = <Map<String, Object?>>[];
      final invalidations = <CalendarInvalidated>[];

      final service = FlowJoinService(
        resolveDjedWindow: ({required timezone, startDate}) {
          expect(timezone, TrackSkyTimeZone.mountain);
          expect(startDate, selectedStart);
          return window;
        },
        djedScheduleForEvent:
            ({required event, required flowStart, required timezone}) {
              expect(flowStart, selectedStart);
              expect(timezone, TrackSkyTimeZone.mountain);
              return scheduleForEvent(event);
            },
        djedNowInZone: (timezone) {
          expect(timezone, TrackSkyTimeZone.mountain);
          return enrolledAt;
        },
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
              flowCalls.add({
                'name': name,
                'active': active,
                'calendarId': calendarId,
                'startDate': startDate,
                'endDate': endDate,
                'notes': notes,
                'rules': rules,
                'originType': originType,
              });
              return 231;
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
              eventCalls.add({
                'clientEventId': clientEventId,
                'title': title,
                'startsAtUtc': startsAtUtc,
                'detail': detail,
                'allDay': allDay,
                'endsAtUtc': endsAtUtc,
                'flowLocalId': flowLocalId,
                'category': category,
                'actionId': actionId,
                'behaviorPayload': behaviorPayload,
                'calendarId': calendarId,
                'caller': caller,
              });
            },
        fileHeadlessEventDelivery:
            ({
              required eventFiling,
              required debugLabel,
              required clientEventId,
              required startsAtLocal,
              required alertOffsetMinutes,
              required title,
              body,
            }) async {
              deliveryCalls.add({
                'debugLabel': debugLabel,
                'clientEventId': clientEventId,
                'startsAtLocal': startsAtLocal,
                'alertOffsetMinutes': alertOffsetMinutes,
                'title': title,
                'body': body,
              });
            },
        publishHeadlessCalendarInvalidation:
            ({required reason, required flowId, required clientEventIds}) {
              invalidations.add(
                CalendarInvalidated(
                  reason: reason,
                  flowId: flowId,
                  clientEventIds: List<String>.from(clientEventIds),
                ),
              );
            },
      );

      final result = await service.joinDjedHeadless(
        templateKey: kTheDjedFlowKey,
        templateTitle: kTheDjedTitle,
        templateOverview: kDjedOverview,
        templateColor: Colors.teal,
        personalCalendarId: 'personal-calendar',
        timezone: timezone,
        startDate: selectedStart,
        lens: DjedLens.ptah,
        configuration: _testDjedV2Configuration,
        alertOffsetMinutes: 0,
      );

      final expectedIds = <String>[
        for (final event in kDjedV2Events)
          'djed-v2:231:${event.semanticStepId}',
      ];

      expect(result.succeeded, isTrue);
      expect(result.hasLocalFastPath, isTrue);
      expect(result.persistInBackground, isNotNull);
      expect(eventCalls, isEmpty);
      expect(deliveryCalls, isEmpty);
      expect(invalidations, isEmpty);
      await result.persistInBackground!();
      await Future<void>.delayed(Duration.zero);
      expect(result.flowId, 231);
      expect(result.clientEventIds, expectedIds);

      expect(flowCalls, hasLength(1));
      expect(flowCalls.single['name'], kTheDjedTitle);
      expect(flowCalls.single['calendarId'], 'personal-calendar');
      expect(flowCalls.single['startDate'], selectedStart);
      expect(
        flowCalls.single['endDate'],
        selectedStart.add(const Duration(days: 29)),
      );
      expect(flowCalls.single['originType'], 'template');
      expect(flowCalls.single['notes'], contains('maat=$kTheDjedFlowKey'));
      expect(flowCalls.single['notes'], contains('djed_tz=mountain'));
      expect(flowCalls.single['notes'], contains('djed_lens=ptah'));
      expect(
        flowCalls.single['notes'],
        contains('djed_schema_version=$kDjedV2SchemaVersion'),
      );
      expect(flowCalls.single['notes'], contains('djed_v2_config='));
      expect(flowCalls.single['notes'], contains('djed_decan_kyear=3'));
      expect(flowCalls.single['notes'], contains('djed_decan_month=6'));
      expect(flowCalls.single['notes'], contains('djed_decan_day=1'));
      expect(
        flowCalls.single['notes'],
        contains('djed_enrolled_at=${enrolledAt.toIso8601String()}'),
      );
      final rules = jsonDecode(flowCalls.single['rules']! as String) as List;
      expect(rules.single, containsPair('type', 'dates'));

      expect(eventCalls, hasLength(kDjedV2Events.length));
      expect(deliveryCalls, hasLength(kDjedV2Events.length));
      expect(
        eventCalls.map((call) => call['clientEventId']).toList(),
        expectedIds,
      );
      final firstEvent = kDjedV2Events.first;
      final firstSchedule = schedulesByEventNumber[firstEvent.eventNumber]!;
      expect(eventCalls.first['title'], djedV2EventTitle(firstEvent));
      expect(eventCalls.first['startsAtUtc'], firstSchedule.startUtc);
      expect(eventCalls.first['endsAtUtc'], firstSchedule.endUtc);
      expect(eventCalls.first['flowLocalId'], 231);
      expect(eventCalls.first['category'], 'Ritual');
      expect(eventCalls.first['caller'], 'djed_join_headless');
      expect(eventCalls.first['actionId'], djedV2ActionId(firstEvent));
      final firstPayload =
          eventCalls.first['behaviorPayload']! as Map<String, dynamic>;
      expect(firstPayload['kind'], kDjedV2BehaviorKind);
      expect(firstPayload['flow_key'], kTheDjedFlowKey);
      expect(firstPayload['djed_schema_version'], kDjedV2SchemaVersion);
      expect(firstPayload['event_number'], 1);
      expect(firstPayload['semantic_step_id'], firstEvent.semanticStepId);
      expect(
        firstPayload['immutable_occurrence'],
        containsPair('flow_day', firstEvent.flowDay),
      );
      expect(firstPayload['lens'], 'ptah');
      expect(
        firstPayload['schedule'],
        containsPair('type', 'test_djed_schedule'),
      );

      expect(deliveryCalls.first['clientEventId'], expectedIds.first);
      expect(deliveryCalls.first['startsAtLocal'], firstSchedule.startLocal);
      expect(deliveryCalls.first['alertOffsetMinutes'], 0);
      expect(deliveryCalls.first['debugLabel'], 'djedHeadless');

      expect(invalidations, hasLength(1));
      expect(
        invalidations.single.reason,
        CalendarInvalidationReason.flowJoined,
      );
      expect(invalidations.single.flowId, 231);
      expect(invalidations.single.clientEventIds, expectedIds);
    },
  );

  test('non-product Ma’at decan join is rejected before persistence', () async {
    final timezone = TrackSkyTimeZone.pacific;
    final selectedStart = DateTime(2026, 12, 1);
    final definition = maatDecanFlowDefinitionForKey(kFairHearingFlowKey)!;
    final openingOccurrence = DecanWatchOccurrence(
      kYear: 3,
      kMonth: 7,
      decanIndex: 1,
      decanStartDay: 1,
      globalDecanId: 19,
      decanName: 'Test Fair Hearing Decan',
      eventDateIso: '2026-12-01',
      timezone: timezone,
      scheduleHour: kDecanWatchDefaultHour,
      scheduleMinute: kDecanWatchDefaultMinute,
      startLocal: selectedStart,
      endLocal: selectedStart.add(
        const Duration(minutes: kDecanWatchDurationMinutes),
      ),
      startUtc: DateTime.utc(2026, 12, 1, 16),
      endUtc: DateTime.utc(2026, 12, 1, 16, kDecanWatchDurationMinutes),
    );
    final window = DecanWatchEnrollmentWindow(
      opensAtLocal: selectedStart,
      closesAtLocal: DateTime(2026, 12, 2),
      openingOccurrence: openingOccurrence,
    );

    final flowCalls = <Map<String, Object?>>[];
    final eventCalls = <Map<String, Object?>>[];
    final deliveryCalls = <Map<String, Object?>>[];
    final invalidations = <CalendarInvalidated>[];

    final service = FlowJoinService(
      resolveDecanWatchWindow: ({required timezone, startDate}) {
        expect(timezone, TrackSkyTimeZone.pacific);
        expect(startDate, selectedStart);
        return window;
      },
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
            flowCalls.add({
              'name': name,
              'active': active,
              'calendarId': calendarId,
              'startDate': startDate,
              'endDate': endDate,
              'notes': notes,
              'rules': rules,
              'originType': originType,
            });
            return 240;
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
            eventCalls.add({
              'clientEventId': clientEventId,
              'title': title,
              'startsAtUtc': startsAtUtc,
              'detail': detail,
              'allDay': allDay,
              'endsAtUtc': endsAtUtc,
              'flowLocalId': flowLocalId,
              'category': category,
              'actionId': actionId,
              'behaviorPayload': behaviorPayload,
              'calendarId': calendarId,
              'caller': caller,
            });
          },
      fileHeadlessEventDelivery:
          ({
            required eventFiling,
            required debugLabel,
            required clientEventId,
            required startsAtLocal,
            required alertOffsetMinutes,
            required title,
            body,
          }) async {
            deliveryCalls.add({
              'debugLabel': debugLabel,
              'clientEventId': clientEventId,
              'startsAtLocal': startsAtLocal,
              'alertOffsetMinutes': alertOffsetMinutes,
              'title': title,
              'body': body,
            });
          },
      publishHeadlessCalendarInvalidation:
          ({required reason, required flowId, required clientEventIds}) {
            invalidations.add(
              CalendarInvalidated(
                reason: reason,
                flowId: flowId,
                clientEventIds: List<String>.from(clientEventIds),
              ),
            );
          },
    );

    final result = await service.joinMaatDecanFlowHeadless(
      definition: definition,
      templateOverview: kFairHearingOverview,
      templateColor: Colors.amber,
      personalCalendarId: 'personal-calendar',
      timezone: timezone,
      startDate: selectedStart,
      alertOffsetMinutes: 0,
    );

    expect(result.succeeded, isFalse);
    expect(result.failureCode, FlowJoinFailureCode.notJoinable);
    expect(result.clientEventIds, isEmpty);
    expect(flowCalls, isEmpty);
    expect(eventCalls, isEmpty);
    expect(deliveryCalls, isEmpty);
    expect(invalidations, isEmpty);
    return;

    // ignore: dead_code
    final expectedIds = <String>[
      for (final event in definition.events)
        'the-fair-hearing:240:event-${event.eventNumber}',
    ];

    expect(result.succeeded, isTrue);
    expect(result.hasLocalFastPath, isTrue);
    expect(result.persistInBackground, isNotNull);
    expect(eventCalls, isEmpty);
    await result.persistInBackground!();
    await Future<void>.delayed(Duration.zero);
    expect(result.flowId, 240);
    expect(result.clientEventIds, expectedIds);

    expect(flowCalls, hasLength(1));
    expect(flowCalls.single['name'], kFairHearingTitle);
    expect(flowCalls.single['calendarId'], 'personal-calendar');
    expect(flowCalls.single['startDate'], selectedStart);
    expect(
      flowCalls.single['endDate'],
      selectedStart.add(const Duration(days: 29)),
    );
    expect(flowCalls.single['originType'], 'template');
    expect(flowCalls.single['notes'], contains('maat=$kFairHearingFlowKey'));
    expect(
      flowCalls.single['notes'],
      contains('fair_hearing_start=2026-12-01'),
    );
    expect(flowCalls.single['notes'], contains('fair_hearing_tz=pacific'));
    expect(flowCalls.single['notes'], contains('fair_hearing_decan_kyear=3'));
    final rules = jsonDecode(flowCalls.single['rules']! as String) as List;
    expect(rules.single, containsPair('type', 'dates'));

    expect(eventCalls, hasLength(definition.events.length));
    expect(deliveryCalls, hasLength(definition.events.length));
    expect(
      eventCalls.map((call) => call['clientEventId']).toList(),
      expectedIds,
    );
    final firstEvent = definition.events.first;
    expect(
      eventCalls.first['title'],
      maatDecanFlowEventTitle(definition, firstEvent),
    );
    expect(eventCalls.first['flowLocalId'], 240);
    expect(eventCalls.first['category'], 'Ritual');
    expect(eventCalls.first['caller'], 'maat_decan_flow_join_headless');
    expect(
      eventCalls.first['actionId'],
      maatDecanFlowActionId(definition, firstEvent),
    );
    final firstPayload =
        eventCalls.first['behaviorPayload']! as Map<String, dynamic>;
    expect(firstPayload['kind'], 'maat_fair_hearing_event');
    expect(firstPayload['flow_key'], kFairHearingFlowKey);
    expect(firstPayload['event_number'], firstEvent.eventNumber);
    expect(firstPayload['flow_day'], firstEvent.flowDay);

    expect(deliveryCalls.first['clientEventId'], expectedIds.first);
    expect(deliveryCalls.first['alertOffsetMinutes'], 0);
    expect(deliveryCalls.first['debugLabel'], 'maatDecanFlowHeadless');

    expect(invalidations, hasLength(1));
    expect(invalidations.single.reason, CalendarInvalidationReason.flowJoined);
    expect(invalidations.single.flowId, 240);
    expect(invalidations.single.clientEventIds, expectedIds);
  });

  test('absorbed Living Text cannot materialize new events', () async {
    final timezone = TrackSkyTimeZone.pacific;
    final selectedStart = DateTime(2026, 12, 1);
    final openingOccurrence = DecanWatchOccurrence(
      kYear: 3,
      kMonth: 7,
      decanIndex: 1,
      decanStartDay: 1,
      globalDecanId: 19,
      decanName: 'Test Living Text Decan',
      eventDateIso: '2026-12-01',
      timezone: timezone,
      scheduleHour: kDecanWatchDefaultHour,
      scheduleMinute: kDecanWatchDefaultMinute,
      startLocal: selectedStart,
      endLocal: selectedStart.add(
        const Duration(minutes: kDecanWatchDurationMinutes),
      ),
      startUtc: DateTime.utc(2026, 12, 1, 16),
      endUtc: DateTime.utc(2026, 12, 1, 16, kDecanWatchDurationMinutes),
    );
    final window = DecanWatchEnrollmentWindow(
      opensAtLocal: selectedStart,
      closesAtLocal: DateTime(2026, 12, 2),
      openingOccurrence: openingOccurrence,
    );
    var flowWrites = 0;
    final eventCalls = <Map<String, Object?>>[];

    final service = FlowJoinService(
      resolveDecanWatchWindow: ({required timezone, startDate}) => window,
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
            flowWrites += 1;
            return 441;
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
            eventCalls.add(<String, Object?>{
              'title': title,
              'behaviorPayload': behaviorPayload,
            });
          },
      fileHeadlessEventDelivery:
          ({
            required eventFiling,
            required debugLabel,
            required clientEventId,
            required startsAtLocal,
            required alertOffsetMinutes,
            required title,
            body,
          }) async {},
      publishHeadlessCalendarInvalidation:
          ({required reason, required flowId, required clientEventIds}) {},
    );

    final definition = maatDecanFlowDefinitionForKey(kLivingTextFlowKey)!;
    final result = await service.joinMaatDecanFlowHeadless(
      definition: definition,
      templateOverview: kLivingTextOverview,
      templateColor: Colors.amber,
      personalCalendarId: 'personal-calendar',
      timezone: timezone,
      startDate: selectedStart,
    );

    expect(result.succeeded, isFalse);
    expect(result.failureCode, FlowJoinFailureCode.notJoinable);
    expect(result.clientEventIds, isEmpty);
    expect(flowWrites, 0);
    expect(eventCalls, isEmpty);
    return;

    // ignore: dead_code
    expect(result.succeeded, isTrue);
    expect(result.hasLocalFastPath, isTrue);
    expect(result.persistInBackground, isNotNull);
    expect(eventCalls, isEmpty);
    await result.persistInBackground!();
    await Future<void>.delayed(Duration.zero);
    expect(eventCalls, hasLength(definition.events.length));

    final event4Payload =
        eventCalls[3]['behaviorPayload']! as Map<String, dynamic>;
    final event7Payload =
        eventCalls[6]['behaviorPayload']! as Map<String, dynamic>;
    expect(event4Payload['library_cta'], <String, dynamic>{
      'type': kMaatLibraryCtaAddInsight,
      'node_slug': null,
      'label': 'Add your insight',
    });
    expect(event7Payload['library_cta'], <String, dynamic>{
      'type': kMaatLibraryCtaAddInsight,
      'node_slug': null,
      'label': 'Revise your insight',
    });
  });
  test(
    'headless Offering Table join persists events, files at-time delivery, invalidates once, and returns success',
    () async {
      final timezone = TrackSkyTimeZone.pacific;
      final selectedStart = DateTime(2026, 6, 7);
      final days = kOfferingTableDays;

      OfferingTableOccurrenceSchedule scheduleForDay(
        OfferingTableDay day,
        DateTime date,
      ) {
        final startLocal = DateTime(
          date.year,
          date.month,
          date.day,
          kOfferingTableDefaultHour,
          kOfferingTableDefaultMinute + day.dayNumber,
        );
        final endLocal = startLocal.add(Duration(minutes: day.durationMinutes));
        final startUtc = DateTime.utc(
          date.year,
          date.month,
          date.day,
          14,
          kOfferingTableDefaultMinute + day.dayNumber,
        );
        final endUtc = startUtc.add(Duration(minutes: day.durationMinutes));
        return OfferingTableOccurrenceSchedule(
          startLocal: startLocal,
          endLocal: endLocal,
          startUtc: startUtc,
          endUtc: endUtc,
          usedFallback: false,
          clampedToDawn: false,
          timezone: timezone,
          referenceLocationName: 'Test horizon',
          configuredHour: kOfferingTableDefaultHour,
          configuredMinute: kOfferingTableDefaultMinute,
        );
      }

      final schedules = <OfferingTableOccurrenceSchedule>[
        for (var i = 0; i < days.length; i++)
          scheduleForDay(days[i], selectedStart.add(Duration(days: i))),
      ];
      final expectedIds = <String>[
        for (var i = 0; i < days.length; i++)
          EventCidUtil.buildClientEventId(
            ky: KemeticMath.fromGregorian(
              DateUtils.dateOnly(schedules[i].startLocal),
            ).kYear,
            km: KemeticMath.fromGregorian(
              DateUtils.dateOnly(schedules[i].startLocal),
            ).kMonth,
            kd: KemeticMath.fromGregorian(
              DateUtils.dateOnly(schedules[i].startLocal),
            ).kDay,
            title: offeringTableEventTitle(days[i]),
            startHour: schedules[i].startLocal.hour,
            startMinute: schedules[i].startLocal.minute,
            allDay: false,
            flowId: 305,
          ),
      ];

      final order = <String>[];
      final flowCalls = <Map<String, Object?>>[];
      final eventCalls = <Map<String, Object?>>[];
      final deliveryCalls = <Map<String, Object?>>[];
      final invalidations = <CalendarInvalidated>[];

      final service = FlowJoinService(
        offeringTableDays: days,
        offeringTableScheduleForDate: (day, date, timezone) {
          expect(timezone, TrackSkyTimeZone.pacific);
          return scheduleForDay(day, date);
        },
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
              order.add('flow');
              flowCalls.add({
                'name': name,
                'active': active,
                'calendarId': calendarId,
                'startDate': startDate,
                'endDate': endDate,
                'notes': notes,
                'rules': rules,
                'originType': originType,
              });
              return 305;
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
              order.add('event:$clientEventId');
              eventCalls.add({
                'clientEventId': clientEventId,
                'title': title,
                'startsAtUtc': startsAtUtc,
                'detail': detail,
                'allDay': allDay,
                'endsAtUtc': endsAtUtc,
                'flowLocalId': flowLocalId,
                'category': category,
                'actionId': actionId,
                'behaviorPayload': behaviorPayload,
                'calendarId': calendarId,
                'caller': caller,
              });
            },
        fileHeadlessEventDelivery:
            ({
              required eventFiling,
              required debugLabel,
              required clientEventId,
              required startsAtLocal,
              required alertOffsetMinutes,
              required title,
              body,
            }) async {
              order.add('delivery:$clientEventId');
              deliveryCalls.add({
                'debugLabel': debugLabel,
                'clientEventId': clientEventId,
                'startsAtLocal': startsAtLocal,
                'alertOffsetMinutes': alertOffsetMinutes,
                'title': title,
                'body': body,
              });
            },
        publishHeadlessCalendarInvalidation:
            ({required reason, required flowId, required clientEventIds}) {
              order.add('invalidation');
              invalidations.add(
                CalendarInvalidated(
                  reason: reason,
                  flowId: flowId,
                  clientEventIds: List<String>.from(clientEventIds),
                ),
              );
            },
      );

      final result = await service.joinOfferingTableHeadless(
        templateKey: kOfferingTableFlowKey,
        templateTitle: kOfferingTableTitle,
        templateOverview: kOfferingTableOverview,
        templateColor: Colors.brown,
        personalCalendarId: 'personal-calendar',
        timezone: timezone,
        startDate: selectedStart,
        lens: OfferingTableLens.hapy,
        noCupMode: true,
        alertOffsetMinutes: 0,
      );

      expect(result.succeeded, isTrue);
      expect(result.hasLocalFastPath, isTrue);
      expect(result.persistInBackground, isNotNull);
      expect(eventCalls, isEmpty);
      expect(deliveryCalls, isEmpty);
      expect(invalidations, isEmpty);
      await result.persistInBackground!();
      await Future<void>.delayed(Duration.zero);
      expect(result.flowId, 305);
      expect(result.flowIdOrNegativeOne, 305);
      expect(result.clientEventIds, expectedIds);
      expect(result.clientEventIds, hasLength(30));
      expect(result.clientEventIds.toSet(), hasLength(30));

      expect(flowCalls, hasLength(1));
      expect(flowCalls.single['name'], kOfferingTableTitle);
      expect(flowCalls.single['calendarId'], 'personal-calendar');
      expect(flowCalls.single['startDate'], selectedStart);
      expect(
        flowCalls.single['endDate'],
        selectedStart.add(const Duration(days: 29)),
      );
      expect(flowCalls.single['originType'], 'template');
      expect(
        flowCalls.single['notes'],
        contains('maat=$kOfferingTableFlowKey'),
      );
      expect(flowCalls.single['notes'], contains('offering_tz=pacific'));
      expect(flowCalls.single['notes'], contains('offering_lens=hapy'));
      expect(
        flowCalls.single['notes'],
        contains('offering_hour=$kOfferingTableDefaultHour'),
      );
      expect(
        flowCalls.single['notes'],
        contains('offering_minute=$kOfferingTableDefaultMinute'),
      );
      expect(flowCalls.single['notes'], contains('no_cup_mode=1'));
      final rules = jsonDecode(flowCalls.single['rules']! as String) as List;
      expect(rules.single, containsPair('type', 'dates'));

      expect(eventCalls, hasLength(days.length));
      expect(deliveryCalls, hasLength(days.length));
      expect(
        eventCalls.map((call) => call['clientEventId']).toList(),
        expectedIds,
      );
      expect(eventCalls.first['title'], offeringTableEventTitle(days.first));
      expect(eventCalls.first['startsAtUtc'], schedules.first.startUtc);
      expect(eventCalls.first['endsAtUtc'], schedules.first.endUtc);
      expect(eventCalls.first['flowLocalId'], 305);
      expect(eventCalls.first['category'], 'Ritual');
      expect(eventCalls.first['caller'], 'offering_table_join_headless');
      expect(eventCalls.first['actionId'], offeringTableActionId(days.first));
      final firstPayload =
          eventCalls.first['behaviorPayload']! as Map<String, dynamic>;
      expect(firstPayload['kind'], 'maat_offering_table_day');
      expect(firstPayload['flow_key'], kOfferingTableFlowKey);
      expect(firstPayload['day'], days.first.dayNumber);
      expect(firstPayload['lens'], 'hapy');
      expect(firstPayload['no_cup_mode'], isTrue);
      expect(firstPayload, isNot(contains('initial_need')));
      expect(firstPayload, isNot(contains('initialNeed')));
      expect(firstPayload, isNot(contains('intention')));
      expect(
        firstPayload['schedule'],
        containsPair('default_notification', 'event_start'),
      );

      expect(deliveryCalls.first['debugLabel'], 'offeringTableHeadless');
      expect(deliveryCalls.first['clientEventId'], expectedIds.first);
      expect(deliveryCalls.first['startsAtLocal'], schedules.first.startLocal);
      expect(deliveryCalls.first['alertOffsetMinutes'], 0);
      expect(deliveryCalls.first['title'], offeringTableEventTitle(days.first));

      expect(invalidations, hasLength(1));
      expect(
        invalidations.single.reason,
        CalendarInvalidationReason.flowJoined,
      );
      expect(invalidations.single.flowId, 305);
      expect(invalidations.single.clientEventIds, expectedIds);
      expect(order, <String>[
        'flow',
        for (final id in expectedIds) 'event:$id',
        'invalidation',
        for (final id in expectedIds) 'delivery:$id',
      ]);
    },
  );
  test(
    '62-event staged join returns before event writes then persists once',
    () async {
      final timezone = TrackSkyTimeZone.mountain;
      final selectedStart = DateTime(2026, 6, 11);
      final joinedK = KemeticMath.fromGregorian(selectedStart);
      final events = List<CourseEvent>.generate(
        62,
        (index) => CourseEvent(
          eventNumber: index + 1,
          flowDay: (index % 30) + 1,
          decanSection: 'Load test',
          title: 'Deferred occurrence ${index + 1}',
          scheduleKind: CourseScheduleKind.solarDawn,
          durationMinutesMin: 5,
          durationMinutesMax: 10,
          spokenLine: 'Begin.',
          steps: const <String>['Begin.'],
        ),
      );

      CourseOccurrenceSchedule scheduleForEvent(
        CourseEvent event,
        DateTime date,
      ) {
        final startLocal = DateTime(
          date.year,
          date.month,
          date.day,
          event.scheduleKind == CourseScheduleKind.midday ? 11 : 6,
          event.eventNumber,
        );
        final endLocal = startLocal.add(
          Duration(minutes: event.durationMinutesMax),
        );
        final startUtc = DateTime.utc(
          date.year,
          date.month,
          date.day,
          event.scheduleKind == CourseScheduleKind.midday ? 17 : 12,
          event.eventNumber,
        );
        final endUtc = startUtc.add(
          Duration(minutes: event.durationMinutesMax),
        );
        return CourseOccurrenceSchedule(
          startLocal: startLocal,
          endLocal: endLocal,
          startUtc: startUtc,
          endUtc: endUtc,
          usedFallback: false,
          timezone: timezone,
          referenceLocationName: 'Test horizon',
          scheduleType: 'test_course_${event.scheduleKind.key}',
          fallback: 'test_fallback',
          middayHour: event.scheduleKind == CourseScheduleKind.midday
              ? kTheCourseDefaultMiddayHour
              : null,
          middayMinute: event.scheduleKind == CourseScheduleKind.midday
              ? kTheCourseDefaultMiddayMinute
              : null,
        );
      }

      final schedules = <CourseOccurrenceSchedule>[
        for (final event in events)
          scheduleForEvent(
            event,
            selectedStart.add(Duration(days: event.flowDay - 1)),
          ),
      ];
      final expectedIds = <String>[
        for (var i = 0; i < events.length; i++)
          EventCidUtil.buildClientEventId(
            ky: KemeticMath.fromGregorian(
              DateUtils.dateOnly(schedules[i].startLocal),
            ).kYear,
            km: KemeticMath.fromGregorian(
              DateUtils.dateOnly(schedules[i].startLocal),
            ).kMonth,
            kd: KemeticMath.fromGregorian(
              DateUtils.dateOnly(schedules[i].startLocal),
            ).kDay,
            title: courseEventTitle(events[i]),
            startHour: schedules[i].startLocal.hour,
            startMinute: schedules[i].startLocal.minute,
            allDay: false,
            flowId: 308,
          ),
      ];

      final order = <String>[];
      final flowCalls = <Map<String, Object?>>[];
      final eventCalls = <Map<String, Object?>>[];
      final deliveryCalls = <Map<String, Object?>>[];
      final invalidations = <CalendarInvalidated>[];

      final service = FlowJoinService(
        courseEvents: events,
        courseScheduleForDate: (event, date, timezone) {
          expect(timezone, TrackSkyTimeZone.mountain);
          return scheduleForEvent(event, date);
        },
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
              order.add('flow');
              flowCalls.add({
                'name': name,
                'active': active,
                'calendarId': calendarId,
                'startDate': startDate,
                'endDate': endDate,
                'notes': notes,
                'rules': rules,
                'originType': originType,
              });
              return 308;
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
              order.add('event:$clientEventId');
              eventCalls.add({
                'clientEventId': clientEventId,
                'title': title,
                'startsAtUtc': startsAtUtc,
                'detail': detail,
                'allDay': allDay,
                'endsAtUtc': endsAtUtc,
                'flowLocalId': flowLocalId,
                'category': category,
                'actionId': actionId,
                'behaviorPayload': behaviorPayload,
                'calendarId': calendarId,
                'caller': caller,
              });
            },
        fileHeadlessEventDelivery:
            ({
              required eventFiling,
              required debugLabel,
              required clientEventId,
              required startsAtLocal,
              required alertOffsetMinutes,
              required title,
              body,
            }) async {
              order.add('delivery:$clientEventId');
              deliveryCalls.add({
                'debugLabel': debugLabel,
                'clientEventId': clientEventId,
                'startsAtLocal': startsAtLocal,
                'alertOffsetMinutes': alertOffsetMinutes,
                'title': title,
                'body': body,
              });
            },
        publishHeadlessCalendarInvalidation:
            ({required reason, required flowId, required clientEventIds}) {
              order.add('invalidation');
              invalidations.add(
                CalendarInvalidated(
                  reason: reason,
                  flowId: flowId,
                  clientEventIds: List<String>.from(clientEventIds),
                ),
              );
            },
      );

      final result = await service.joinTheCourseHeadless(
        templateKey: kTheCourseFlowKey,
        templateTitle: kTheCourseTitle,
        templateOverview: kTheCourseOverview,
        templateColor: Colors.green,
        personalCalendarId: 'personal-calendar',
        timezone: timezone,
        startDate: selectedStart,
        lens: CourseLens.ra,
        alertOffsetMinutes: 0,
      );

      expect(result.succeeded, isTrue);
      expect(result.flowId, 308);
      expect(result.flowIdOrNegativeOne, 308);
      expect(result.clientEventIds, expectedIds);
      expect(result.hasLocalFastPath, isTrue);
      expect(result.plannedNoteCount, events.length);
      expect(result.persistInBackground, isNotNull);

      // Joining returns after the authoritative flow row; derived event rows
      // and alert filing do not hold navigation open.
      expect(eventCalls, isEmpty);
      expect(deliveryCalls, isEmpty);
      expect(invalidations, isEmpty);
      await result.persistInBackground!();
      await Future<void>.delayed(Duration.zero);

      expect(flowCalls, hasLength(1));
      expect(flowCalls.single['name'], kTheCourseTitle);
      expect(flowCalls.single['calendarId'], 'personal-calendar');
      expect(flowCalls.single['startDate'], selectedStart);
      expect(
        flowCalls.single['endDate'],
        selectedStart.add(const Duration(days: 29)),
      );
      expect(flowCalls.single['originType'], 'template');
      expect(flowCalls.single['notes'], contains('maat=$kTheCourseFlowKey'));
      expect(flowCalls.single['notes'], contains('course_tz=mountain'));
      expect(flowCalls.single['notes'], contains('course_lens=ra'));
      expect(
        flowCalls.single['notes'],
        contains('course_midday_hour=$kTheCourseDefaultMiddayHour'),
      );
      expect(
        flowCalls.single['notes'],
        contains('course_midday_minute=$kTheCourseDefaultMiddayMinute'),
      );
      expect(flowCalls.single['notes'], contains('joined_ky=${joinedK.kYear}'));
      expect(
        flowCalls.single['notes'],
        contains('joined_km=${joinedK.kMonth}'),
      );
      expect(flowCalls.single['notes'], contains('joined_kd=${joinedK.kDay}'));
      final rules = jsonDecode(flowCalls.single['rules']! as String) as List;
      expect(rules.single, containsPair('type', 'dates'));

      expect(eventCalls, hasLength(events.length));
      expect(deliveryCalls, hasLength(events.length));
      expect(
        eventCalls.map((call) => call['clientEventId']).toList(),
        expectedIds,
      );
      expect(eventCalls.first['title'], courseEventTitle(events.first));
      expect(eventCalls.first['startsAtUtc'], schedules.first.startUtc);
      expect(eventCalls.first['endsAtUtc'], schedules.first.endUtc);
      expect(eventCalls.first['flowLocalId'], 308);
      expect(eventCalls.first['category'], 'Ritual');
      expect(eventCalls.first['caller'], 'the_course_join_headless');
      expect(eventCalls.first['actionId'], courseActionId(events.first));
      expect(eventCalls.first['detail'], contains('Current ḥꜣw Context'));
      final firstPayload =
          eventCalls.first['behaviorPayload']! as Map<String, dynamic>;
      expect(firstPayload['kind'], 'maat_course_event');
      expect(firstPayload['flow_key'], kTheCourseFlowKey);
      expect(firstPayload['event_number'], events.first.eventNumber);
      expect(firstPayload['flow_day'], events.first.flowDay);
      expect(firstPayload['requires_day_card'], isTrue);
      final propsProfile =
          firstPayload['props_profile']! as Map<String, dynamic>;
      expect(propsProfile['required'], ['day_card']);
      expect(firstPayload['missed_event_rule'], 'expire_quietly');
      expect(firstPayload['lens'], 'ra');
      expect(
        firstPayload['schedule'],
        containsPair('type', 'test_course_solar_dawn'),
      );
      final calendarContext =
          firstPayload['calendar_context']! as Map<String, dynamic>;
      expect(calendarContext['kemetic_month'], isA<int>());
      expect(calendarContext['kemetic_day'], isA<int>());
      expect(calendarContext['decan_name'], isA<String>());
      expect(calendarContext['season'], isA<String>());

      expect(deliveryCalls.first['debugLabel'], 'theCourseHeadless');
      expect(deliveryCalls.first['clientEventId'], expectedIds.first);
      expect(deliveryCalls.first['startsAtLocal'], schedules.first.startLocal);
      expect(deliveryCalls.first['alertOffsetMinutes'], 0);
      expect(deliveryCalls.first['title'], courseEventTitle(events.first));

      expect(invalidations, hasLength(1));
      expect(
        invalidations.single.reason,
        CalendarInvalidationReason.flowJoined,
      );
      expect(invalidations.single.flowId, 308);
      expect(invalidations.single.clientEventIds, expectedIds);
      expect(order, <String>[
        'flow',
        for (final id in expectedIds) 'event:$id',
        'invalidation',
        for (final id in expectedIds) 'delivery:$id',
      ]);
    },
  );
}

DateTime _firstUnavailableEnrollmentStart<T>(
  T? Function(DateTime startDate) resolve,
) {
  final now = DateTime.now();
  var startDate = DateTime(now.year, now.month, now.day);
  for (var i = 0; i < 180; i += 1) {
    if (resolve(startDate) == null) return startDate;
    startDate = startDate.add(const Duration(days: 1));
  }
  fail('Expected at least one unavailable enrollment start date.');
}
