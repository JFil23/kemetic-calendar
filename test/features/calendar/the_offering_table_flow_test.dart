import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';

void main() {
  test('defines thirty unique daily provision sittings', () {
    expect(kOfferingTableDays, hasLength(30));
    expect(
      kOfferingTableDays.map((day) => day.dayNumber).toList(),
      List<int>.generate(30, (index) => index + 1),
    );
    expect(kOfferingTableDays.map((day) => day.title).toSet(), hasLength(30));
    expect(
      kOfferingTableDays.map((day) => day.provisionAct).toSet(),
      hasLength(30),
    );
    expect(kOfferingTableDays.last.durationMinutes, 5);
    expect(kOfferingTableDays.last.sharePromptOnComplete, isTrue);
  });

  test('derives the three decan lines by day number', () {
    expect(offeringTableDecanLine(1), contains('Your Ka will sit'));
    expect(offeringTableDecanLine(10), contains('Your Ka will sit'));
    expect(offeringTableDecanLine(11), contains('breath of the nostrils'));
    expect(offeringTableDecanLine(20), contains('breath of the nostrils'));
    expect(offeringTableDecanLine(21), contains('What is given'));
    expect(offeringTableDecanLine(30), contains('What is given'));
  });

  test('schedules the default morning table at 7:30 local after dawn', () {
    final schedule = offeringTableScheduleForDate(
      kOfferingTableDays.first,
      DateTime(2026, 6, 1),
      TrackSkyTimeZone.pacific,
    );

    expect(schedule.startLocal.hour, 7);
    expect(schedule.startLocal.minute, 30);
    expect(
      schedule.endUtc.difference(schedule.startUtc),
      const Duration(minutes: 3),
    );
    expect(schedule.clampedToDawn, isFalse);

    final clamped = offeringTableScheduleForDate(
      kOfferingTableDays.first,
      DateTime(2026, 6, 1),
      TrackSkyTimeZone.pacific,
      hour: 3,
    );
    expect(clamped.clampedToDawn, isTrue);
    expect(clamped.startLocal.isAfter(DateTime(2026, 6, 1, 3)), isTrue);
  });

  test('default start date advances after the morning table has passed', () {
    final before = defaultOfferingTableStartDate(
      TrackSkyTimeZone.pacific,
      now: DateTime.utc(2026, 6, 1, 13),
    );
    final after = defaultOfferingTableStartDate(
      TrackSkyTimeZone.pacific,
      now: DateTime.utc(2026, 6, 1, 16),
    );

    expect(before, DateTime(2026, 6, 1));
    expect(after, DateTime(2026, 6, 2));
  });

  test('builds JSON-safe behavior payloads and action ids', () {
    final startDate = DateTime(2026, 6, 1);
    final ids = <String>{};

    for (var i = 0; i < kOfferingTableDays.length; i++) {
      final day = kOfferingTableDays[i];
      final schedule = offeringTableScheduleForDate(
        day,
        startDate.add(Duration(days: i)),
        TrackSkyTimeZone.eastern,
      );
      final payload = offeringTableBehaviorPayload(
        day: day,
        schedule: schedule,
        lens: OfferingTableLens.hapy,
        noCupMode: i.isEven,
      );

      expect(jsonDecode(jsonEncode(payload)), isA<Map<String, dynamic>>());
      expect(payload['kind'], 'maat_offering_table_day');
      expect(payload['flow_key'], 'the-offering-table');
      expect(payload['missed_event_rule'], 'expire_quietly');
      ids.add(offeringTableActionId(day));
    }

    expect(ids, hasLength(30));
    expect(ids.first, 'the-offering-table-day-01');
    expect(ids.last, 'the-offering-table-day-30');
  });

  test('detail text contains water, words, provision, drink, and lens', () {
    final detail = offeringTableDetailText(
      kOfferingTableDays.first,
      lens: OfferingTableLens.hapy,
      noCupMode: true,
    );

    expect(detail, contains('Water\nHold the cup'));
    expect(detail, contains('Words\n"Wash yourself'));
    expect(detail, contains('Lens\nLet Hapy'));
    expect(detail, contains('Provision\nBefore food'));
    expect(detail, contains('Drink\nDrink the water'));
    expect(detail, isNot(contains('Privacy\n')));
    expect(detail, isNot(contains('Source\n')));
  });

  test('purpose copy checkpoints match the upgraded offering table', () {
    expect(
      offeringTableDayByNumber(1)?.purpose,
      'The Kemetic offering table began with water before anything else — not because water is symbolic, but because it is the most immediate provision. This rite does the same.',
    );
    expect(
      offeringTableDayByNumber(10)?.purpose,
      'The scribe\'s record closes with what is — not what was intended, but what actually happened. This rite produces that account.',
    );
    expect(
      offeringTableDayByNumber(20)?.purpose,
      'What improved? What still leaks? The second seal requires only these two facts, not a full solution.',
    );
    expect(
      offeringTableDayByNumber(30)?.purpose,
      'The table was never about perfection — it was about the record being honest. Speak what is true. The cycle closes with accuracy, not with achievement.',
    );
  });

  test('representative source note is preserved', () {
    expect(
      kOfferingTableDays.first.sourceNote,
      'Kemetic offering ritual begins with water before bread, oil, or incense. The table starts by acknowledging what sustains life first.',
    );
  });

  test('canonical detail rebuilds a stored offering table day', () {
    final detail = canonicalOfferingTableDetailTextForEvent(
      flowName: kOfferingTableTitle,
      flowNotes:
          'mode=gregorian;maat=the-offering-table;offering_lens=ausar;no_cup_mode=1',
      title: 'Day 1: The First Water',
      actionId: 'the-offering-table-day-01',
      behaviorPayload: const <String, dynamic>{
        'kind': 'maat_offering_table_day',
        'flow_key': 'the-offering-table',
        'day': 1,
      },
    );

    expect(detail, isNotNull);
    expect(detail, contains('Hold the cup'));
    expect(detail, contains('Lens\nLet Ausar'));
  });

  test('calendar join branch creates thirty daily events', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final methodStart = source.indexOf('Future<int> _addMaatFlowInstance({');
    expect(methodStart, isNonNegative);
    final branchStart = source.indexOf(
      'if (template.kind == _MaatFlowTemplateKind.offeringTable)',
      methodStart,
    );
    expect(branchStart, isNonNegative);
    final branchEnd = source.indexOf('if (startDate == null)', branchStart);
    expect(branchEnd, isNonNegative);
    final branch = source.substring(branchStart, branchEnd);

    expect(branch, contains('kOfferingTableDays'));
    expect(branch, contains('await repo.upsertByClientId'));
    expect(branch, isNot(contains('Future.microtask')));
    expect(branch, contains('repo.deleteFlow(serverFlowId)'));
    expect(branch, contains(r'offering_hour=$kOfferingTableDefaultHour'));
    expect(branch, contains('no_cup_mode='));
  });
}
