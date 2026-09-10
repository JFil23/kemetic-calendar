import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_invalidation.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/the_kar/the_kar.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('Kꜣr schedules the five places and closing walk on exact days', () {
    final schedule = karSchedule(
      anchorDate: DateTime(2026, 9, 10),
      netjer: KarNetjer.djehuty,
      cycleId: 'cycle-1',
    );

    expect(schedule.map((value) => value.stage.day), <int>[
      1,
      4,
      9,
      15,
      22,
      30,
    ]);
    expect(schedule.map((value) => value.stage.place), <String>[
      'Threshold',
      'Left jamb',
      'Right jamb',
      'Lintel',
      'Base',
      'Inner chamber',
    ]);
    expect(schedule.map((value) => value.startLocal.day), <int>[
      10,
      13,
      18,
      24,
      1,
      9,
    ]);
    expect(schedule.last.isWalk, isTrue);
    expect(
      schedule.last.behaviorPayload(cycleSequence: 1),
      containsPair('kind', 'maat_kar_walk'),
    );
    expect(
      schedule.first.behaviorPayload(cycleSequence: 1),
      containsPair('kind', 'maat_kar_scene'),
    );
  });

  test('one permanent shrine keeps drafts separate from placed versions', () {
    final initial = KarShrine(
      id: 'kar-user-djehuty',
      netjer: KarNetjer.djehuty,
      revision: 0,
      cycles: const [],
    );
    final started = initial.beginCycle(
      cycleId: 'cycle-1',
      anchorDate: DateTime(2026, 9, 10, 18),
      flowId: 91,
    );
    final drafted = started.saveDraft(
      stageIndex: 0,
      draft: KarDraft(
        kind: 'description',
        content: 'A blue robe and a silver pipe.',
        savedAt: DateTime.utc(2026, 9, 10),
      ),
    );

    expect(drafted.activeCycle!.placements.first.activeVersion, isNull);
    expect(drafted.drafts, hasLength(1));

    final placed = drafted.placeDraft(
      stageIndex: 0,
      versionId: 'entry-1',
      now: DateTime.utc(2026, 9, 10, 19),
    );
    expect(placed.drafts, isEmpty);
    expect(placed.activeCycle!.placedCount, 1);
    expect(
      placed.activeCycle!.placements.first.activeVersion!.content,
      'A blue robe and a silver pipe.',
    );
  });

  test('replacement appends an immutable version and preserves lineage', () {
    var shrine = _startedShrine();
    shrine = _draftAndPlace(
      shrine,
      cycleId: 'cycle-1',
      stageIndex: 0,
      content: 'First threshold.',
      versionId: 'entry-1',
    );
    shrine = _draftAndPlace(
      shrine,
      cycleId: 'cycle-1',
      stageIndex: 0,
      content: 'Threshold after returning.',
      versionId: 'entry-2',
    );

    final placement = shrine.activeCycle!.placements.first;
    expect(placement.versions, hasLength(2));
    expect(placement.versions.last.supersedesId, 'entry-1');
    expect(placement.activeVersion!.id, 'entry-2');
    expect(placement.versions.first.content, 'First threshold.');
  });

  test(
    'a completed cycle stays editable while its earlier version remains',
    () {
      var shrine = _draftAndPlace(
        _startedShrine(),
        cycleId: 'cycle-1',
        stageIndex: 0,
        content: 'Original.',
        versionId: 'entry-1',
      );
      shrine = shrine.completeWalk(
        now: DateTime.utc(2026, 10, 9),
        outcomes: const <String>['recalled', 'open', 'open', 'open', 'open'],
      );
      shrine = _draftAndPlace(
        shrine,
        cycleId: 'cycle-1',
        stageIndex: 0,
        content: 'Edited after completion.',
        versionId: 'entry-2',
      );

      final completed = shrine.cycles.single;
      expect(completed.status, KarCycleStatus.completed);
      expect(completed.placements.first.versions, hasLength(2));
      expect(
        completed.placements.first.activeVersion!.content,
        'Edited after completion.',
      );
    },
  );

  test('earlier-cycle scenes never fill current-cycle blanks', () {
    var shrine = _draftAndPlace(
      _startedShrine(),
      cycleId: 'cycle-1',
      stageIndex: 4,
      content: 'Earlier base.',
      versionId: 'old-base',
    );
    shrine = shrine.completeWalk(
      now: DateTime.utc(2026, 10, 9),
      outcomes: const <String>['open', 'open', 'open', 'open', 'recalled'],
    );
    shrine = shrine.beginCycle(
      cycleId: 'cycle-2',
      anchorDate: DateTime(2026, 11, 1),
      flowId: 92,
    );

    expect(shrine.earlierCycles.single.placements[4].activeVersion, isNotNull);
    expect(shrine.activeCycle!.placements[4].activeVersion, isNull);
  });

  test('opening and serialization never move a cycle schedule', () {
    final shrine = _startedShrine();
    final restored = KarShrine.fromRow(<String, dynamic>{
      'id': shrine.id,
      'netjer_key': shrine.netjer.key,
      'revision': 8,
      'state': jsonDecode(jsonEncode(shrine.toStateJson())),
    });

    expect(restored.activeCycle!.anchorDate, DateTime(2026, 9, 10));
    expect(restored.activeCycle!.dateForStage(5), DateTime(2026, 10, 9));

    final explicitlyMoved = restored.reanchor(
      anchorDate: DateTime(2026, 12, 1),
      flowId: 91,
    );
    expect(explicitlyMoved.activeCycle!.anchorDate, DateTime(2026, 12, 1));
  });

  test('headless join stages exactly six canonical Kꜣr events', () async {
    final events = <Map<String, Object?>>[];
    final flows = <Map<String, Object?>>[];
    final invalidations = <CalendarInvalidated>[];
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
            flows.add(<String, Object?>{
              'id': id,
              'name': name,
              'startDate': startDate,
              'endDate': endDate,
              'notes': notes,
              'rules': rules,
            });
            return id ?? 91;
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
            events.add(<String, Object?>{
              'title': title,
              'startsAtUtc': startsAtUtc,
              'behaviorPayload': behaviorPayload,
              'flowLocalId': flowLocalId,
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
          }) async {},
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

    final result = await service.joinKarHeadless(
      templateKey: kKarFlowKey,
      templateTitle: kKarTitle,
      templateOverview: kKarOverview,
      templateColor: const Color(0xFF91B7C7),
      personalCalendarId: 'personal',
      timezone: TrackSkyTimeZone.pacific,
      startDate: DateTime(2026, 9, 10),
      netjer: KarNetjer.maat,
      cycleId: 'cycle-1',
      cycleSequence: 1,
    );

    expect(result.succeeded, isTrue);
    expect(events, isEmpty);
    await result.persistInBackground!();
    await Future<void>.delayed(Duration.zero);

    expect(flows, hasLength(1));
    expect(flows.single['startDate'], DateTime(2026, 9, 10));
    expect(flows.single['endDate'], DateTime(2026, 10, 9, 9));
    expect(flows.single['notes'], contains('maat=the-kar'));
    expect(events, hasLength(6));
    expect(
      events.map((event) => (event['behaviorPayload']! as Map)['kar_day']),
      <int>[1, 4, 9, 15, 22, 30],
    );
    expect(events.last['title'], 'Walk the kꜣr');
    expect(events.last['caller'], 'kar_join_headless');
    expect(invalidations.single.flowId, 91);
  });

  test(
    'explicit reschedule reuses the existing flow and preserves old events',
    () async {
      final flowIds = <int?>[];
      var eventWrites = 0;
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
              flowIds.add(id);
              return id ?? 91;
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
              eventWrites += 1;
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

      final result = await service.joinKarHeadless(
        templateKey: kKarFlowKey,
        templateTitle: kKarTitle,
        templateOverview: kKarOverview,
        templateColor: const Color(0xFF91B7C7),
        personalCalendarId: 'personal',
        timezone: TrackSkyTimeZone.pacific,
        startDate: DateTime(2026, 12, 1),
        netjer: KarNetjer.djehuty,
        cycleId: 'cycle-1',
        cycleSequence: 1,
        existingFlowId: 91,
      );
      await result.persistInBackground!();

      expect(flowIds, <int?>[91]);
      expect(eventWrites, 6);
    },
  );
}

KarShrine _startedShrine() => KarShrine(
  id: 'kar-user-djehuty',
  netjer: KarNetjer.djehuty,
  revision: 0,
  cycles: const [],
).beginCycle(cycleId: 'cycle-1', anchorDate: DateTime(2026, 9, 10), flowId: 91);

KarShrine _draftAndPlace(
  KarShrine shrine, {
  required String cycleId,
  required int stageIndex,
  required String content,
  required String versionId,
}) {
  final drafted = shrine.saveDraft(
    cycleId: cycleId,
    stageIndex: stageIndex,
    draft: KarDraft(
      kind: 'description',
      content: content,
      savedAt: DateTime.utc(2026, 9, 10),
    ),
  );
  return drafted.placeDraft(
    cycleId: cycleId,
    stageIndex: stageIndex,
    versionId: versionId,
    now: DateTime.utc(2026, 9, 10, 12),
  );
}
