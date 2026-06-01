import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_invalidation.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/dawn_house_rite_flow.dart';
import 'package:mobile/features/calendar/evening_threshold_rite_flow.dart';
import 'package:mobile/features/calendar/maat_decan_flow.dart';
import 'package:mobile/features/calendar/moon_return_astronomy.dart';
import 'package:mobile/features/calendar/moon_return_flow.dart';
import 'package:mobile/features/calendar/the_days_outside_year_enrollment.dart';
import 'package:mobile/features/calendar/the_days_outside_year_flow.dart';
import 'package:mobile/features/calendar/the_days_outside_year_scheduler.dart';
import 'package:mobile/features/calendar/the_decan_watch_enrollment.dart';
import 'package:mobile/features/calendar/the_decan_watch_flow.dart';
import 'package:mobile/features/calendar/the_djed_enrollment.dart';
import 'package:mobile/features/calendar/the_djed_flow.dart';
import 'package:mobile/features/calendar/the_course_flow.dart';
import 'package:mobile/features/calendar/the_kept_word_flow.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/the_open_hand_enrollment.dart';
import 'package:mobile/features/calendar/the_open_hand_flow.dart';
import 'package:mobile/features/calendar/the_tending_flow.dart';
import 'package:mobile/features/calendar/the_wag_enrollment.dart';
import 'package:mobile/features/calendar/the_wag_flow.dart';
import 'package:mobile/features/calendar/the_wag_scheduler.dart';
import 'package:mobile/features/calendar/the_weighing_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:mobile/utils/event_cid_util.dart';

void main() {
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
        DateTime startDate,
      ) async {
        final result = await join(startDate);
        expect(result.succeeded, isFalse, reason: label);
        expect(
          result.failureCode,
          FlowJoinFailureCode.noEnrollmentWindow,
          reason: label,
        );
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

      await expectNoEnrollmentWindow(
        'Wag',
        (startDate) => service.joinWagHeadless(
          templateKey: kTheWagFlowKey,
          templateTitle: kTheWagTitle,
          templateOverview: kTheWagOverview,
          templateColor: Colors.brown,
          personalCalendarId: 'personal-calendar',
          timezone: timezone,
          startDate: startDate,
        ),
        _firstUnavailableEnrollmentStart<WagEnrollmentWindow>(
          (startDate) => resolveWagEnrollmentWindowSafely(
            timezone: timezone,
            startDate: startDate,
          ),
        ),
      );

      await expectNoEnrollmentWindow(
        'Days Outside the Year',
        (startDate) => service.joinDaysOutsideYearHeadless(
          templateKey: kDaysOutsideTheYearFlowKey,
          templateTitle: kDaysOutsideTheYearTitle,
          templateOverview: kDaysOutsideTheYearOverview,
          templateColor: Colors.orange,
          personalCalendarId: 'personal-calendar',
          timezone: timezone,
          startDate: startDate,
        ),
        _firstUnavailableEnrollmentStart<DaysOutsideYearEnrollmentWindow>(
          (startDate) => resolveDaysOutsideYearEnrollmentWindowSafely(
            timezone: timezone,
            startDate: startDate,
          ),
        ),
      );

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
    'headless Wag join persists events, files at-time delivery, invalidates once, and returns success',
    () async {
      final timezone = TrackSkyTimeZone.central;
      final selectedStart = DateTime(2026, 7, 17);
      final enrolledAt = DateTime(2026, 7, 17, 7);
      final window = WagEnrollmentWindow(
        kYear: 3,
        opensAtLocal: selectedStart,
        closesAtLocal: DateTime(2026, 7, 19),
        wepRonpetLocalDate: selectedStart,
        timezone: timezone,
      );
      final schedulesByEventNumber = <int, WagOccurrenceSchedule>{};

      WagOccurrenceSchedule scheduleForEvent(WagEvent event) {
        return schedulesByEventNumber.putIfAbsent(event.eventNumber, () {
          final startLocal = DateTime(2026, 7, event.eventNumber, 8);
          final endLocal = startLocal.add(
            Duration(minutes: event.durationMinutesMax),
          );
          final startUtc = DateTime.utc(2026, 7, event.eventNumber, 13);
          final endUtc = startUtc.add(
            Duration(minutes: event.durationMinutesMax),
          );
          return WagOccurrenceSchedule(
            startLocal: startLocal,
            endLocal: endLocal,
            startUtc: startUtc,
            endUtc: endUtc,
            usedFallback: false,
            timezone: timezone,
            referenceLocationName: 'Test horizon',
            scheduleType: 'test_schedule',
          );
        });
      }

      final flowCalls = <Map<String, Object?>>[];
      final eventCalls = <Map<String, Object?>>[];
      final deliveryCalls = <Map<String, Object?>>[];
      final invalidations = <CalendarInvalidated>[];

      final service = FlowJoinService(
        resolveWagWindow: ({required timezone, startDate}) {
          expect(timezone, TrackSkyTimeZone.central);
          expect(startDate, selectedStart);
          return window;
        },
        wagScheduleForEvent:
            ({required event, required kYear, required timezone}) {
              expect(kYear, 3);
              expect(timezone, TrackSkyTimeZone.central);
              return scheduleForEvent(event);
            },
        wagNowInZone: (timezone) {
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
              return 84;
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

      final result = await service.joinWagHeadless(
        templateKey: kTheWagFlowKey,
        templateTitle: kTheWagTitle,
        templateOverview: kTheWagOverview,
        templateColor: Colors.deepPurple,
        personalCalendarId: 'personal-calendar',
        timezone: timezone,
        startDate: selectedStart,
        lens: WagLens.anpu,
        alertOffsetMinutes: 0,
      );

      final expectedIds = <String>[
        for (final event in kWagEvents)
          'wag:84:3:event-${event.eventNumber.toString().padLeft(2, '0')}',
      ];

      expect(result.succeeded, isTrue);
      expect(result.flowId, 84);
      expect(result.clientEventIds, expectedIds);

      expect(flowCalls, hasLength(1));
      expect(flowCalls.single['name'], kTheWagTitle);
      expect(flowCalls.single['calendarId'], 'personal-calendar');
      expect(flowCalls.single['originType'], 'template');
      expect(flowCalls.single['notes'], contains('maat=$kTheWagFlowKey'));
      expect(flowCalls.single['notes'], contains('wag_kyear=3'));
      expect(flowCalls.single['notes'], contains('wag_tz=central'));
      expect(flowCalls.single['notes'], contains('wag_lens=anpu'));
      expect(
        flowCalls.single['notes'],
        contains('wag_enrolled_at=${enrolledAt.toIso8601String()}'),
      );
      final rules = jsonDecode(flowCalls.single['rules']! as String) as List;
      expect(rules.single, containsPair('type', 'dates'));

      expect(eventCalls, hasLength(kWagEvents.length));
      expect(deliveryCalls, hasLength(kWagEvents.length));
      expect(
        eventCalls.map((call) => call['clientEventId']).toList(),
        expectedIds,
      );
      final firstEvent = kWagEvents.first;
      final firstSchedule = schedulesByEventNumber[firstEvent.eventNumber]!;
      expect(eventCalls.first['title'], wagEventTitle(firstEvent));
      expect(eventCalls.first['startsAtUtc'], firstSchedule.startUtc);
      expect(eventCalls.first['endsAtUtc'], firstSchedule.endUtc);
      expect(eventCalls.first['flowLocalId'], 84);
      expect(eventCalls.first['category'], 'Ritual');
      expect(eventCalls.first['caller'], 'wag_join_headless');
      expect(eventCalls.first['actionId'], wagActionId(firstEvent));
      final firstPayload =
          eventCalls.first['behaviorPayload']! as Map<String, dynamic>;
      expect(firstPayload['kind'], 'maat_wag_event');
      expect(firstPayload['flow_key'], kTheWagFlowKey);
      expect(firstPayload['k_year'], 3);
      expect(firstPayload['lens'], 'anpu');
      expect(firstPayload['schedule'], containsPair('timezone', 'central'));

      expect(deliveryCalls.first['clientEventId'], expectedIds.first);
      expect(deliveryCalls.first['startsAtLocal'], firstSchedule.startLocal);
      expect(deliveryCalls.first['alertOffsetMinutes'], 0);
      expect(deliveryCalls.first['debugLabel'], 'wagHeadless');

      expect(invalidations, hasLength(1));
      expect(
        invalidations.single.reason,
        CalendarInvalidationReason.flowJoined,
      );
      expect(invalidations.single.flowId, 84);
      expect(invalidations.single.clientEventIds, expectedIds);
    },
  );

  test(
    'headless Days Outside join persists events, files at-time delivery, invalidates once, and returns success',
    () async {
      final timezone = TrackSkyTimeZone.mountain;
      final selectedStart = DateTime(2026, 8, 9);
      final enrolledAt = DateTime(2026, 8, 9, 6);
      final window = DaysOutsideYearEnrollmentWindow(
        closingKYear: 3,
        opensAtLocal: selectedStart,
        closesAtLocal: DateTime(2026, 8, 14),
        anchorLocalDate: selectedStart,
        timezone: timezone,
      );
      final schedulesByEventNumber = <int, DaysOutsideOccurrenceSchedule>{};

      DaysOutsideOccurrenceSchedule scheduleForEvent(DaysOutsideEvent event) {
        return schedulesByEventNumber.putIfAbsent(event.eventNumber, () {
          final day = event.eventNumber + 1;
          final startLocal = DateTime(2026, 8, day, 7);
          final endLocal = startLocal.add(
            Duration(minutes: event.durationMinutes),
          );
          final startUtc = DateTime.utc(2026, 8, day, 13);
          final endUtc = startUtc.add(Duration(minutes: event.durationMinutes));
          return DaysOutsideOccurrenceSchedule(
            startLocal: startLocal,
            endLocal: endLocal,
            startUtc: startUtc,
            endUtc: endUtc,
            usedFallback: false,
            timezone: timezone,
            referenceLocationName: 'Test horizon',
            scheduleType: 'test_schedule',
          );
        });
      }

      final flowCalls = <Map<String, Object?>>[];
      final eventCalls = <Map<String, Object?>>[];
      final deliveryCalls = <Map<String, Object?>>[];
      final invalidations = <CalendarInvalidated>[];

      final service = FlowJoinService(
        resolveDaysOutsideYearWindow: ({required timezone, startDate}) {
          expect(timezone, TrackSkyTimeZone.mountain);
          expect(startDate, selectedStart);
          return window;
        },
        daysOutsideYearScheduleForEvent:
            ({required event, required closingKYear, required timezone}) {
              expect(closingKYear, 3);
              expect(timezone, TrackSkyTimeZone.mountain);
              return scheduleForEvent(event);
            },
        daysOutsideYearNowInZone: (timezone) {
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
              return 126;
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

      final result = await service.joinDaysOutsideYearHeadless(
        templateKey: kDaysOutsideTheYearFlowKey,
        templateTitle: kDaysOutsideTheYearTitle,
        templateOverview: kDaysOutsideTheYearOverview,
        templateColor: Colors.orange,
        personalCalendarId: 'personal-calendar',
        timezone: timezone,
        startDate: selectedStart,
        alertOffsetMinutes: 0,
      );

      final expectedIds = <String>[
        for (final event in kDaysOutsideEvents)
          'days-outside:126:3:${event.eventNumber}',
      ];

      expect(result.succeeded, isTrue);
      expect(result.flowId, 126);
      expect(result.clientEventIds, expectedIds);

      expect(flowCalls, hasLength(1));
      expect(flowCalls.single['name'], kDaysOutsideTheYearTitle);
      expect(flowCalls.single['calendarId'], 'personal-calendar');
      expect(flowCalls.single['startDate'], selectedStart);
      expect(flowCalls.single['originType'], 'template');
      expect(
        flowCalls.single['notes'],
        contains('maat=$kDaysOutsideTheYearFlowKey'),
      );
      expect(flowCalls.single['notes'], contains('doy_kyear=3'));
      expect(flowCalls.single['notes'], contains('doy_tz=mountain'));
      expect(
        flowCalls.single['notes'],
        contains('doy_enrolled_at=${enrolledAt.toIso8601String()}'),
      );
      final rules = jsonDecode(flowCalls.single['rules']! as String) as List;
      expect(rules.single, containsPair('type', 'dates'));

      expect(eventCalls, hasLength(kDaysOutsideEvents.length));
      expect(deliveryCalls, hasLength(kDaysOutsideEvents.length));
      expect(
        eventCalls.map((call) => call['clientEventId']).toList(),
        expectedIds,
      );
      final firstEvent = kDaysOutsideEvents.first;
      final firstSchedule = schedulesByEventNumber[firstEvent.eventNumber]!;
      expect(eventCalls.first['title'], daysOutsideEventTitle(firstEvent));
      expect(eventCalls.first['startsAtUtc'], firstSchedule.startUtc);
      expect(eventCalls.first['endsAtUtc'], firstSchedule.endUtc);
      expect(eventCalls.first['flowLocalId'], 126);
      expect(eventCalls.first['category'], 'Ritual');
      expect(eventCalls.first['caller'], 'days_outside_year_join_headless');
      expect(eventCalls.first['actionId'], daysOutsideActionId(firstEvent));
      final firstPayload =
          eventCalls.first['behaviorPayload']! as Map<String, dynamic>;
      expect(firstPayload['kind'], 'maat_days_outside_year');
      expect(firstPayload['flow_key'], kDaysOutsideTheYearFlowKey);
      expect(firstPayload['closing_k_year'], 3);
      expect(firstPayload['timezone'], 'mountain');
      expect(firstPayload['schedule_type'], 'test_schedule');

      expect(deliveryCalls.first['clientEventId'], expectedIds.first);
      expect(deliveryCalls.first['startsAtLocal'], firstSchedule.startLocal);
      expect(deliveryCalls.first['alertOffsetMinutes'], 0);
      expect(deliveryCalls.first['debugLabel'], 'daysOutsideYearHeadless');

      expect(invalidations, hasLength(1));
      expect(
        invalidations.single.reason,
        CalendarInvalidationReason.flowJoined,
      );
      expect(invalidations.single.flowId, 126);
      expect(invalidations.single.clientEventIds, expectedIds);
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

      DjedOccurrenceSchedule scheduleForEvent(DjedEvent event) {
        return schedulesByEventNumber.putIfAbsent(event.eventNumber, () {
          final startLocal = selectedStart
              .add(Duration(days: event.flowDay - 1))
              .add(Duration(hours: 6 + event.eventNumber));
          final endLocal = startLocal.add(
            Duration(minutes: event.durationMinutesMax),
          );
          final startUtc = DateTime.utc(
            2026,
            11,
            event.flowDay,
            11 + event.eventNumber,
          );
          final endUtc = startUtc.add(
            Duration(minutes: event.durationMinutesMax),
          );
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
        alertOffsetMinutes: 0,
      );

      final expectedIds = <String>[
        for (final event in kDjedEvents) 'djed:231:event-${event.eventNumber}',
      ];

      expect(result.succeeded, isTrue);
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
      expect(flowCalls.single['notes'], contains('djed_decan_kyear=3'));
      expect(flowCalls.single['notes'], contains('djed_decan_month=6'));
      expect(flowCalls.single['notes'], contains('djed_decan_day=1'));
      expect(
        flowCalls.single['notes'],
        contains('djed_enrolled_at=${enrolledAt.toIso8601String()}'),
      );
      final rules = jsonDecode(flowCalls.single['rules']! as String) as List;
      expect(rules.single, containsPair('type', 'dates'));

      expect(eventCalls, hasLength(kDjedEvents.length));
      expect(deliveryCalls, hasLength(kDjedEvents.length));
      expect(
        eventCalls.map((call) => call['clientEventId']).toList(),
        expectedIds,
      );
      final firstEvent = kDjedEvents.first;
      final firstSchedule = schedulesByEventNumber[firstEvent.eventNumber]!;
      expect(eventCalls.first['title'], djedEventTitle(firstEvent));
      expect(eventCalls.first['startsAtUtc'], firstSchedule.startUtc);
      expect(eventCalls.first['endsAtUtc'], firstSchedule.endUtc);
      expect(eventCalls.first['flowLocalId'], 231);
      expect(eventCalls.first['category'], 'Ritual');
      expect(eventCalls.first['caller'], 'djed_join_headless');
      expect(eventCalls.first['actionId'], djedActionId(firstEvent));
      final firstPayload =
          eventCalls.first['behaviorPayload']! as Map<String, dynamic>;
      expect(firstPayload['kind'], 'maat_djed_event');
      expect(firstPayload['flow_key'], kTheDjedFlowKey);
      expect(firstPayload['event_number'], 1);
      expect(firstPayload['flow_day'], firstEvent.flowDay);
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

  test(
    'headless Ma’at decan join persists events, files at-time delivery, invalidates once, and returns success',
    () async {
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

      final expectedIds = <String>[
        for (final event in definition.events)
          'the-fair-hearing:240:event-${event.eventNumber}',
      ];

      expect(result.succeeded, isTrue);
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
      expect(
        invalidations.single.reason,
        CalendarInvalidationReason.flowJoined,
      );
      expect(invalidations.single.flowId, 240);
      expect(invalidations.single.clientEventIds, expectedIds);
    },
  );

  test(
    'headless Dawn House Rite join persists events, intentionally skips delivery without alert, invalidates once, and returns success',
    () async {
      final timezone = TrackSkyTimeZone.pacific;
      final selectedStart = DateTime(2026, 6, 1);
      final days = <DawnHouseRiteDay>[
        kDawnHouseRiteDays[0],
        kDawnHouseRiteDays[1],
      ];

      DawnHouseRiteOccurrenceSchedule scheduleForDate(DateTime date) {
        final dayOffset = date.difference(selectedStart).inDays;
        final startLocal = DateTime(2026, 6, 1 + dayOffset, 5, 30 + dayOffset);
        final endLocal = startLocal.add(
          const Duration(minutes: kDawnHouseRiteDurationMinutes),
        );
        final startUtc = DateTime.utc(2026, 6, 1 + dayOffset, 12, 30);
        final endUtc = startUtc.add(
          const Duration(minutes: kDawnHouseRiteDurationMinutes),
        );
        return DawnHouseRiteOccurrenceSchedule(
          startLocal: startLocal,
          endLocal: endLocal,
          startUtc: startUtc,
          endUtc: endUtc,
          usedFallback: false,
          timezone: timezone,
          referenceLocation: kDawnHouseRiteReferenceLocations[timezone]!,
        );
      }

      final schedules = <DawnHouseRiteOccurrenceSchedule>[
        for (var i = 0; i < days.length; i++)
          scheduleForDate(selectedStart.add(Duration(days: i))),
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
            title: dawnHouseRiteEventTitle(days[i]),
            startHour: schedules[i].startLocal.hour,
            startMinute: schedules[i].startLocal.minute,
            allDay: false,
            flowId: 302,
          ),
      ];

      final order = <String>[];
      final flowCalls = <Map<String, Object?>>[];
      final eventCalls = <Map<String, Object?>>[];
      final deliveryCalls = <Map<String, Object?>>[];
      final invalidations = <CalendarInvalidated>[];

      final service = FlowJoinService(
        dawnHouseRiteDays: days,
        dawnHouseRiteScheduleForDate: (date, timezone) {
          expect(timezone, TrackSkyTimeZone.pacific);
          return scheduleForDate(date);
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
              return 302;
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

      final result = await service.joinDawnHouseRiteHeadless(
        templateKey: kDawnHouseRiteFlowKey,
        templateTitle: kDawnHouseRiteTitle,
        templateOverview: kDawnHouseRiteOverview,
        templateColor: Colors.amber,
        personalCalendarId: 'personal-calendar',
        timezone: timezone,
        startDate: selectedStart,
        discreet: true,
        lens: DawnHouseRiteLens.thothic,
      );

      expect(result.succeeded, isTrue);
      expect(result.flowId, 302);
      expect(result.flowIdOrNegativeOne, 302);
      expect(result.clientEventIds, expectedIds);

      expect(flowCalls, hasLength(1));
      expect(flowCalls.single['name'], kDawnHouseRiteTitle);
      expect(flowCalls.single['calendarId'], 'personal-calendar');
      expect(flowCalls.single['startDate'], selectedStart);
      expect(flowCalls.single['endDate'], DateTime(2026, 6, 2));
      expect(flowCalls.single['originType'], 'template');
      expect(
        flowCalls.single['notes'],
        contains('maat=$kDawnHouseRiteFlowKey'),
      );
      expect(flowCalls.single['notes'], contains('dawn_tz=pacific'));
      expect(flowCalls.single['notes'], contains('dawn_discreet=1'));
      expect(flowCalls.single['notes'], contains('dawn_lens=thothic'));
      final rules = jsonDecode(flowCalls.single['rules']! as String) as List;
      expect(rules.single, containsPair('type', 'dates'));

      expect(eventCalls, hasLength(days.length));
      expect(
        eventCalls.map((call) => call['clientEventId']).toList(),
        expectedIds,
      );
      expect(eventCalls.first['title'], dawnHouseRiteEventTitle(days.first));
      expect(eventCalls.first['startsAtUtc'], schedules.first.startUtc);
      expect(eventCalls.first['endsAtUtc'], schedules.first.endUtc);
      expect(eventCalls.first['flowLocalId'], 302);
      expect(eventCalls.first['category'], 'Ritual');
      expect(eventCalls.first['caller'], 'dawn_house_rite_join_headless');
      expect(eventCalls.first['actionId'], dawnHouseRiteActionId(days.first));
      final firstPayload =
          eventCalls.first['behaviorPayload']! as Map<String, dynamic>;
      expect(firstPayload['kind'], 'maat_dawn_house_rite_day');
      expect(firstPayload['flow_key'], kDawnHouseRiteFlowKey);
      expect(firstPayload['day'], days.first.dayNumber);
      expect(firstPayload['discreet_mode'], isTrue);
      expect(firstPayload['lens'], 'thothic');
      expect(firstPayload['schedule'], containsPair('timezone', 'pacific'));

      expect(deliveryCalls, isEmpty);
      expect(invalidations, hasLength(1));
      expect(
        invalidations.single.reason,
        CalendarInvalidationReason.flowJoined,
      );
      expect(invalidations.single.flowId, 302);
      expect(invalidations.single.clientEventIds, expectedIds);
      expect(order, <String>[
        'flow',
        'event:${expectedIds[0]}',
        'event:${expectedIds[1]}',
        'invalidation',
      ]);
    },
  );

  test(
    'headless Evening Threshold Rite join persists events, intentionally skips delivery without alert, invalidates once, and returns success',
    () async {
      final timezone = TrackSkyTimeZone.eastern;
      final selectedStart = DateTime(2026, 6, 3);
      final fallbackMinutes = (21 * 60) + 15;
      final days = <EveningThresholdRiteDay>[
        kEveningThresholdRiteDays[0],
        kEveningThresholdRiteDays[1],
      ];

      EveningThresholdOccurrenceSchedule scheduleForDate(DateTime date) {
        final dayOffset = date.difference(selectedStart).inDays;
        final startLocal = DateTime(2026, 6, 3 + dayOffset, 21, 15);
        final endLocal = startLocal.add(
          const Duration(minutes: kEveningThresholdRiteDurationMinutes),
        );
        final startUtc = DateTime.utc(2026, 6, 4 + dayOffset, 1, 15);
        final endUtc = startUtc.add(
          const Duration(minutes: kEveningThresholdRiteDurationMinutes),
        );
        return EveningThresholdOccurrenceSchedule(
          startLocal: startLocal,
          endLocal: endLocal,
          startUtc: startUtc,
          endUtc: endUtc,
          usedFallback: true,
          timezone: timezone,
          referenceLocation: kEveningThresholdReferenceLocations[timezone]!,
          fallbackMinutesAfterMidnight: fallbackMinutes,
        );
      }

      final schedules = <EveningThresholdOccurrenceSchedule>[
        for (var i = 0; i < days.length; i++)
          scheduleForDate(selectedStart.add(Duration(days: i))),
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
            title: eveningThresholdRiteEventTitle(days[i]),
            startHour: schedules[i].startLocal.hour,
            startMinute: schedules[i].startLocal.minute,
            allDay: false,
            flowId: 303,
          ),
      ];

      final order = <String>[];
      final flowCalls = <Map<String, Object?>>[];
      final eventCalls = <Map<String, Object?>>[];
      final deliveryCalls = <Map<String, Object?>>[];
      final invalidations = <CalendarInvalidated>[];

      final service = FlowJoinService(
        eveningThresholdRiteDays: days,
        eveningThresholdScheduleForDate:
            (date, timezone, {required fallbackMinutesAfterMidnight}) {
              expect(timezone, TrackSkyTimeZone.eastern);
              expect(fallbackMinutesAfterMidnight, fallbackMinutes);
              return scheduleForDate(date);
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
              return 303;
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

      final result = await service.joinEveningThresholdRiteHeadless(
        templateKey: kEveningThresholdRiteFlowKey,
        templateTitle: kEveningThresholdRiteTitle,
        templateOverview: kEveningThresholdRiteOverview,
        templateColor: Colors.deepOrange,
        personalCalendarId: 'personal-calendar',
        timezone: timezone,
        startDate: selectedStart,
        discreet: true,
        lens: EveningThresholdRiteLens.hiddenRenewal,
        fallbackMinutesAfterMidnight: fallbackMinutes,
      );

      expect(result.succeeded, isTrue);
      expect(result.flowId, 303);
      expect(result.flowIdOrNegativeOne, 303);
      expect(result.clientEventIds, expectedIds);

      expect(flowCalls, hasLength(1));
      expect(flowCalls.single['name'], kEveningThresholdRiteTitle);
      expect(flowCalls.single['calendarId'], 'personal-calendar');
      expect(flowCalls.single['startDate'], selectedStart);
      expect(flowCalls.single['endDate'], DateTime(2026, 6, 4));
      expect(flowCalls.single['originType'], 'template');
      expect(
        flowCalls.single['notes'],
        contains('maat=$kEveningThresholdRiteFlowKey'),
      );
      expect(flowCalls.single['notes'], contains('evening_tz=eastern'));
      expect(flowCalls.single['notes'], contains('evening_discreet=1'));
      expect(
        flowCalls.single['notes'],
        contains('evening_lens=hidden_renewal'),
      );
      expect(
        flowCalls.single['notes'],
        contains('evening_fallback=$fallbackMinutes'),
      );
      final rules = jsonDecode(flowCalls.single['rules']! as String) as List;
      expect(rules.single, containsPair('type', 'dates'));

      expect(eventCalls, hasLength(days.length));
      expect(
        eventCalls.map((call) => call['clientEventId']).toList(),
        expectedIds,
      );
      expect(
        eventCalls.first['title'],
        eveningThresholdRiteEventTitle(days.first),
      );
      expect(eventCalls.first['startsAtUtc'], schedules.first.startUtc);
      expect(eventCalls.first['endsAtUtc'], schedules.first.endUtc);
      expect(eventCalls.first['flowLocalId'], 303);
      expect(eventCalls.first['category'], 'Ritual');
      expect(
        eventCalls.first['caller'],
        'evening_threshold_rite_join_headless',
      );
      expect(
        eventCalls.first['actionId'],
        eveningThresholdRiteActionId(days.first),
      );
      final firstPayload =
          eventCalls.first['behaviorPayload']! as Map<String, dynamic>;
      expect(firstPayload['kind'], 'maat_evening_threshold_rite_day');
      expect(firstPayload['flow_key'], kEveningThresholdRiteFlowKey);
      expect(firstPayload['day'], days.first.dayNumber);
      expect(firstPayload['discreet_mode'], isTrue);
      expect(firstPayload['lens'], 'hidden_renewal');
      expect(firstPayload['schedule'], containsPair('timezone', 'eastern'));
      expect(
        firstPayload['schedule'],
        containsPair('fallback_minutes_after_midnight', fallbackMinutes),
      );

      expect(deliveryCalls, isEmpty);
      expect(invalidations, hasLength(1));
      expect(
        invalidations.single.reason,
        CalendarInvalidationReason.flowJoined,
      );
      expect(invalidations.single.flowId, 303);
      expect(invalidations.single.clientEventIds, expectedIds);
      expect(order, <String>[
        'flow',
        'event:${expectedIds[0]}',
        'event:${expectedIds[1]}',
        'invalidation',
      ]);
    },
  );

  test(
    'headless The Weighing join persists events, intentionally skips delivery without alert, invalidates once, and returns success',
    () async {
      final timezone = TrackSkyTimeZone.central;
      final selectedStart = DateTime(2026, 6, 5);
      final events = <TheWeighingEvent>[
        kTheWeighingEvents[0],
        kTheWeighingEvents[1],
      ];

      TheWeighingOccurrenceSchedule scheduleForEvent(
        TheWeighingEvent event,
        DateTime date,
      ) {
        final startLocal = DateTime(
          date.year,
          date.month,
          date.day,
          event.slot == TheWeighingTimingSlot.checkMidday ? 11 : 6,
          event.eventNumber,
        );
        final endLocal = startLocal.add(
          Duration(minutes: event.durationMinutesMax),
        );
        final startUtc = DateTime.utc(
          date.year,
          date.month,
          date.day,
          event.slot == TheWeighingTimingSlot.checkMidday ? 16 : 11,
          event.eventNumber,
        );
        final endUtc = startUtc.add(
          Duration(minutes: event.durationMinutesMax),
        );
        return TheWeighingOccurrenceSchedule(
          startLocal: startLocal,
          endLocal: endLocal,
          startUtc: startUtc,
          endUtc: endUtc,
          usedFallback: false,
          timezone: timezone,
          referenceLocationName: 'Test horizon',
          scheduleType: 'test_weighing_${event.slot.key}',
          fallback: 'test_fallback',
          middayHour: event.slot == TheWeighingTimingSlot.checkMidday
              ? kTheWeighingDefaultMiddayHour
              : null,
          middayMinute: event.slot == TheWeighingTimingSlot.checkMidday
              ? kTheWeighingDefaultMiddayMinute
              : null,
        );
      }

      final schedules = <TheWeighingOccurrenceSchedule>[
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
            title: theWeighingEventTitle(events[i]),
            startHour: schedules[i].startLocal.hour,
            startMinute: schedules[i].startLocal.minute,
            allDay: false,
            flowId: 304,
          ),
      ];

      final order = <String>[];
      final flowCalls = <Map<String, Object?>>[];
      final eventCalls = <Map<String, Object?>>[];
      final deliveryCalls = <Map<String, Object?>>[];
      final invalidations = <CalendarInvalidated>[];

      final service = FlowJoinService(
        theWeighingEvents: events,
        theWeighingScheduleForDate: (event, date, timezone) {
          expect(timezone, TrackSkyTimeZone.central);
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
              return 304;
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

      final result = await service.joinTheWeighingHeadless(
        templateKey: kTheWeighingFlowKey,
        templateTitle: kTheWeighingTitle,
        templateOverview: kTheWeighingOverview,
        templateColor: Colors.blueGrey,
        personalCalendarId: 'personal-calendar',
        timezone: timezone,
        startDate: selectedStart,
        lens: TheWeighingLens.djehuty,
      );

      expect(result.succeeded, isTrue);
      expect(result.flowId, 304);
      expect(result.flowIdOrNegativeOne, 304);
      expect(result.clientEventIds, expectedIds);

      expect(flowCalls, hasLength(1));
      expect(flowCalls.single['name'], kTheWeighingTitle);
      expect(flowCalls.single['calendarId'], 'personal-calendar');
      expect(flowCalls.single['startDate'], selectedStart);
      expect(
        flowCalls.single['endDate'],
        selectedStart.add(const Duration(days: 29)),
      );
      expect(flowCalls.single['originType'], 'template');
      expect(flowCalls.single['notes'], contains('maat=$kTheWeighingFlowKey'));
      expect(flowCalls.single['notes'], contains('weighing_tz=central'));
      expect(flowCalls.single['notes'], contains('weighing_lens=djehuty'));
      expect(
        flowCalls.single['notes'],
        contains('weighing_midday_hour=$kTheWeighingDefaultMiddayHour'),
      );
      expect(
        flowCalls.single['notes'],
        contains('weighing_midday_minute=$kTheWeighingDefaultMiddayMinute'),
      );
      final rules = jsonDecode(flowCalls.single['rules']! as String) as List;
      expect(rules.single, containsPair('type', 'dates'));

      expect(eventCalls, hasLength(events.length));
      expect(
        eventCalls.map((call) => call['clientEventId']).toList(),
        expectedIds,
      );
      expect(eventCalls.first['title'], theWeighingEventTitle(events.first));
      expect(eventCalls.first['startsAtUtc'], schedules.first.startUtc);
      expect(eventCalls.first['endsAtUtc'], schedules.first.endUtc);
      expect(eventCalls.first['flowLocalId'], 304);
      expect(eventCalls.first['category'], 'Ritual');
      expect(eventCalls.first['caller'], 'the_weighing_join_headless');
      expect(eventCalls.first['actionId'], theWeighingActionId(events.first));
      final firstPayload =
          eventCalls.first['behaviorPayload']! as Map<String, dynamic>;
      expect(firstPayload['kind'], 'maat_the_weighing_event');
      expect(firstPayload['flow_key'], kTheWeighingFlowKey);
      expect(firstPayload['event_number'], events.first.eventNumber);
      expect(firstPayload['flow_day'], events.first.flowDay);
      expect(firstPayload['lens'], 'djehuty');
      expect(
        firstPayload['schedule'],
        containsPair('type', 'test_weighing_open_morning'),
      );

      expect(deliveryCalls, isEmpty);
      expect(invalidations, hasLength(1));
      expect(
        invalidations.single.reason,
        CalendarInvalidationReason.flowJoined,
      );
      expect(invalidations.single.flowId, 304);
      expect(invalidations.single.clientEventIds, expectedIds);
      expect(order, <String>[
        'flow',
        'event:${expectedIds[0]}',
        'event:${expectedIds[1]}',
        'invalidation',
      ]);
    },
  );

  test(
    'headless Offering Table join persists events, files at-time delivery, invalidates once, and returns success',
    () async {
      final timezone = TrackSkyTimeZone.pacific;
      final selectedStart = DateTime(2026, 6, 7);
      final days = <OfferingTableDay>[
        kOfferingTableDays[0],
        kOfferingTableDays[1],
      ];

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
      expect(result.flowId, 305);
      expect(result.flowIdOrNegativeOne, 305);
      expect(result.clientEventIds, expectedIds);

      expect(flowCalls, hasLength(1));
      expect(flowCalls.single['name'], kOfferingTableTitle);
      expect(flowCalls.single['calendarId'], 'personal-calendar');
      expect(flowCalls.single['startDate'], selectedStart);
      expect(flowCalls.single['endDate'], DateTime(2026, 6, 8));
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
        'event:${expectedIds[0]}',
        'delivery:${expectedIds[0]}',
        'event:${expectedIds[1]}',
        'delivery:${expectedIds[1]}',
        'invalidation',
      ]);
    },
  );

  test(
    'headless The Tending join persists events, files at-time delivery, invalidates once, and returns success',
    () async {
      final timezone = TrackSkyTimeZone.mountain;
      final selectedStart = DateTime(2026, 6, 9);
      final events = <TheTendingEvent>[
        kTheTendingEvents[0],
        kTheTendingEvents[1],
      ];

      TheTendingOccurrenceSchedule scheduleForEvent(
        TheTendingEvent event,
        DateTime date,
      ) {
        final startLocal = DateTime(
          date.year,
          date.month,
          date.day,
          event.slot == TheTendingTimingSlot.checkMidday ? 11 : 6,
          event.eventNumber,
        );
        final endLocal = startLocal.add(
          Duration(minutes: event.durationMinutesMax),
        );
        final startUtc = DateTime.utc(
          date.year,
          date.month,
          date.day,
          event.slot == TheTendingTimingSlot.checkMidday ? 17 : 12,
          event.eventNumber,
        );
        final endUtc = startUtc.add(
          Duration(minutes: event.durationMinutesMax),
        );
        return TheTendingOccurrenceSchedule(
          startLocal: startLocal,
          endLocal: endLocal,
          startUtc: startUtc,
          endUtc: endUtc,
          usedFallback: false,
          timezone: timezone,
          referenceLocationName: 'Test horizon',
          scheduleType: 'test_tending_${event.slot.key}',
          fallback: 'test_fallback',
          middayHour: event.slot == TheTendingTimingSlot.checkMidday
              ? kTheTendingDefaultMiddayHour
              : null,
          middayMinute: event.slot == TheTendingTimingSlot.checkMidday
              ? kTheTendingDefaultMiddayMinute
              : null,
        );
      }

      final schedules = <TheTendingOccurrenceSchedule>[
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
            title: theTendingEventTitle(events[i]),
            startHour: schedules[i].startLocal.hour,
            startMinute: schedules[i].startLocal.minute,
            allDay: false,
            flowId: 306,
          ),
      ];

      final order = <String>[];
      final flowCalls = <Map<String, Object?>>[];
      final eventCalls = <Map<String, Object?>>[];
      final deliveryCalls = <Map<String, Object?>>[];
      final invalidations = <CalendarInvalidated>[];

      final service = FlowJoinService(
        theTendingEvents: events,
        theTendingScheduleForDate: (event, date, timezone) {
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
              return 306;
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

      final result = await service.joinTheTendingHeadless(
        templateKey: kTheTendingFlowKey,
        templateTitle: kTheTendingTitle,
        templateOverview: kTheTendingOverview,
        templateColor: Colors.green,
        personalCalendarId: 'personal-calendar',
        timezone: timezone,
        startDate: selectedStart,
        lens: TheTendingLens.aset,
        alertOffsetMinutes: 0,
      );

      expect(result.succeeded, isTrue);
      expect(result.flowId, 306);
      expect(result.flowIdOrNegativeOne, 306);
      expect(result.clientEventIds, expectedIds);

      expect(flowCalls, hasLength(1));
      expect(flowCalls.single['name'], kTheTendingTitle);
      expect(flowCalls.single['calendarId'], 'personal-calendar');
      expect(flowCalls.single['startDate'], selectedStart);
      expect(
        flowCalls.single['endDate'],
        selectedStart.add(const Duration(days: 29)),
      );
      expect(flowCalls.single['originType'], 'template');
      expect(flowCalls.single['notes'], contains('maat=$kTheTendingFlowKey'));
      expect(flowCalls.single['notes'], contains('tending_tz=mountain'));
      expect(flowCalls.single['notes'], contains('tending_lens=aset'));
      expect(
        flowCalls.single['notes'],
        contains('tending_midday_hour=$kTheTendingDefaultMiddayHour'),
      );
      expect(
        flowCalls.single['notes'],
        contains('tending_midday_minute=$kTheTendingDefaultMiddayMinute'),
      );
      final rules = jsonDecode(flowCalls.single['rules']! as String) as List;
      expect(rules.single, containsPair('type', 'dates'));

      expect(eventCalls, hasLength(events.length));
      expect(deliveryCalls, hasLength(events.length));
      expect(
        eventCalls.map((call) => call['clientEventId']).toList(),
        expectedIds,
      );
      expect(eventCalls.first['title'], theTendingEventTitle(events.first));
      expect(eventCalls.first['startsAtUtc'], schedules.first.startUtc);
      expect(eventCalls.first['endsAtUtc'], schedules.first.endUtc);
      expect(eventCalls.first['flowLocalId'], 306);
      expect(eventCalls.first['category'], 'Ritual');
      expect(eventCalls.first['caller'], 'the_tending_join_headless');
      expect(eventCalls.first['actionId'], theTendingActionId(events.first));
      final firstPayload =
          eventCalls.first['behaviorPayload']! as Map<String, dynamic>;
      expect(firstPayload['kind'], 'maat_the_tending_event');
      expect(firstPayload['flow_key'], kTheTendingFlowKey);
      expect(firstPayload['event_number'], events.first.eventNumber);
      expect(firstPayload['flow_day'], events.first.flowDay);
      expect(firstPayload['local_prompt'], 'care_inventory');
      expect(firstPayload['privacy'], containsPair('sync_care_names', false));
      expect(firstPayload['lens'], 'aset');
      expect(
        firstPayload['schedule'],
        containsPair('type', 'test_tending_open_morning'),
      );

      expect(deliveryCalls.first['debugLabel'], 'theTendingHeadless');
      expect(deliveryCalls.first['clientEventId'], expectedIds.first);
      expect(deliveryCalls.first['startsAtLocal'], schedules.first.startLocal);
      expect(deliveryCalls.first['alertOffsetMinutes'], 0);
      expect(deliveryCalls.first['title'], theTendingEventTitle(events.first));

      expect(invalidations, hasLength(1));
      expect(
        invalidations.single.reason,
        CalendarInvalidationReason.flowJoined,
      );
      expect(invalidations.single.flowId, 306);
      expect(invalidations.single.clientEventIds, expectedIds);
      expect(order, <String>[
        'flow',
        'event:${expectedIds[0]}',
        'delivery:${expectedIds[0]}',
        'event:${expectedIds[1]}',
        'delivery:${expectedIds[1]}',
        'invalidation',
      ]);
    },
  );

  test(
    'headless Kept Word join persists events, files at-time delivery, invalidates once, and returns success',
    () async {
      final timezone = TrackSkyTimeZone.mountain;
      final selectedStart = DateTime(2026, 6, 10);
      final events = <KeptWordEvent>[kKeptWordEvents[0], kKeptWordEvents[1]];

      KeptWordOccurrenceSchedule scheduleForEvent(
        KeptWordEvent event,
        DateTime date,
      ) {
        final startLocal = DateTime(
          date.year,
          date.month,
          date.day,
          event.slot == KeptWordTimingSlot.checkMidday ? 11 : 6,
          event.eventNumber,
        );
        final endLocal = startLocal.add(
          Duration(minutes: event.durationMinutesMax),
        );
        final startUtc = DateTime.utc(
          date.year,
          date.month,
          date.day,
          event.slot == KeptWordTimingSlot.checkMidday ? 17 : 12,
          event.eventNumber,
        );
        final endUtc = startUtc.add(
          Duration(minutes: event.durationMinutesMax),
        );
        return KeptWordOccurrenceSchedule(
          startLocal: startLocal,
          endLocal: endLocal,
          startUtc: startUtc,
          endUtc: endUtc,
          usedFallback: false,
          timezone: timezone,
          referenceLocationName: 'Test horizon',
          scheduleType: 'test_kept_word_${event.slot.key}',
          fallback: 'test_fallback',
          middayHour: event.slot == KeptWordTimingSlot.checkMidday
              ? kKeptWordDefaultMiddayHour
              : null,
          middayMinute: event.slot == KeptWordTimingSlot.checkMidday
              ? kKeptWordDefaultMiddayMinute
              : null,
        );
      }

      final schedules = <KeptWordOccurrenceSchedule>[
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
            title: keptWordEventTitle(events[i]),
            startHour: schedules[i].startLocal.hour,
            startMinute: schedules[i].startLocal.minute,
            allDay: false,
            flowId: 307,
          ),
      ];

      final order = <String>[];
      final flowCalls = <Map<String, Object?>>[];
      final eventCalls = <Map<String, Object?>>[];
      final deliveryCalls = <Map<String, Object?>>[];
      final invalidations = <CalendarInvalidated>[];

      final service = FlowJoinService(
        keptWordEvents: events,
        keptWordScheduleForDate: (event, date, timezone) {
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
              return 307;
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

      final result = await service.joinKeptWordHeadless(
        templateKey: kKeptWordFlowKey,
        templateTitle: kKeptWordTitle,
        templateOverview: kKeptWordOverview,
        templateColor: Colors.green,
        personalCalendarId: 'personal-calendar',
        timezone: timezone,
        startDate: selectedStart,
        lens: KeptWordLens.djehuty,
        alertOffsetMinutes: 0,
      );

      expect(result.succeeded, isTrue);
      expect(result.flowId, 307);
      expect(result.flowIdOrNegativeOne, 307);
      expect(result.clientEventIds, expectedIds);

      expect(flowCalls, hasLength(1));
      expect(flowCalls.single['name'], kKeptWordTitle);
      expect(flowCalls.single['calendarId'], 'personal-calendar');
      expect(flowCalls.single['startDate'], selectedStart);
      expect(
        flowCalls.single['endDate'],
        selectedStart.add(const Duration(days: 29)),
      );
      expect(flowCalls.single['originType'], 'template');
      expect(flowCalls.single['notes'], contains('maat=$kKeptWordFlowKey'));
      expect(flowCalls.single['notes'], contains('kept_word_tz=mountain'));
      expect(flowCalls.single['notes'], contains('kept_word_lens=djehuty'));
      expect(
        flowCalls.single['notes'],
        contains('kept_word_midday_hour=$kKeptWordDefaultMiddayHour'),
      );
      expect(
        flowCalls.single['notes'],
        contains('kept_word_midday_minute=$kKeptWordDefaultMiddayMinute'),
      );
      final rules = jsonDecode(flowCalls.single['rules']! as String) as List;
      expect(rules.single, containsPair('type', 'dates'));

      expect(eventCalls, hasLength(events.length));
      expect(deliveryCalls, hasLength(events.length));
      expect(
        eventCalls.map((call) => call['clientEventId']).toList(),
        expectedIds,
      );
      expect(eventCalls.first['title'], keptWordEventTitle(events.first));
      expect(eventCalls.first['startsAtUtc'], schedules.first.startUtc);
      expect(eventCalls.first['endsAtUtc'], schedules.first.endUtc);
      expect(eventCalls.first['flowLocalId'], 307);
      expect(eventCalls.first['category'], 'Ritual');
      expect(eventCalls.first['caller'], 'the_kept_word_join_headless');
      expect(eventCalls.first['actionId'], keptWordActionId(events.first));
      final firstPayload =
          eventCalls.first['behaviorPayload']! as Map<String, dynamic>;
      expect(firstPayload['kind'], 'maat_kept_word_event');
      expect(firstPayload['flow_key'], kKeptWordFlowKey);
      expect(firstPayload['event_number'], events.first.eventNumber);
      expect(firstPayload['flow_day'], events.first.flowDay);
      expect(firstPayload['local_prompt'], 'agreement_inventory');
      expect(
        firstPayload['privacy'],
        containsPair('household_notes_storage', 'device_only'),
      );
      expect(
        firstPayload['privacy'],
        containsPair('sync_agreement_text', false),
      );
      expect(firstPayload['privacy'], containsPair('sync_names', false));
      expect(firstPayload['lens'], 'djehuty');
      expect(
        firstPayload['schedule'],
        containsPair('type', 'test_kept_word_open_morning'),
      );

      expect(deliveryCalls.first['debugLabel'], 'keptWordHeadless');
      expect(deliveryCalls.first['clientEventId'], expectedIds.first);
      expect(deliveryCalls.first['startsAtLocal'], schedules.first.startLocal);
      expect(deliveryCalls.first['alertOffsetMinutes'], 0);
      expect(deliveryCalls.first['title'], keptWordEventTitle(events.first));

      expect(invalidations, hasLength(1));
      expect(
        invalidations.single.reason,
        CalendarInvalidationReason.flowJoined,
      );
      expect(invalidations.single.flowId, 307);
      expect(invalidations.single.clientEventIds, expectedIds);
      expect(order, <String>[
        'flow',
        'event:${expectedIds[0]}',
        'delivery:${expectedIds[0]}',
        'event:${expectedIds[1]}',
        'delivery:${expectedIds[1]}',
        'invalidation',
      ]);
    },
  );

  test(
    'headless Course join persists events, files at-time delivery, invalidates once, and returns success',
    () async {
      final timezone = TrackSkyTimeZone.mountain;
      final selectedStart = DateTime(2026, 6, 11);
      final joinedK = KemeticMath.fromGregorian(selectedStart);
      final events = <CourseEvent>[kTheCourseEvents[0], kTheCourseEvents[1]];

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
        'event:${expectedIds[0]}',
        'delivery:${expectedIds[0]}',
        'event:${expectedIds[1]}',
        'delivery:${expectedIds[1]}',
        'invalidation',
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
