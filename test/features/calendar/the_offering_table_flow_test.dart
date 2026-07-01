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
      expect(payload['completion_options'], <String>[
        'observed',
        'observed_partly',
        'skipped',
      ]);
      expect(payload['share_prompt_on_complete'], day.sharePromptOnComplete);
      final props = payload['props_profile'] as Map<String, dynamic>;
      expect(props['required'], i.isEven ? isEmpty : <String>['water_cup']);
      expect(props['alternative'], i.isEven ? 'hold_existing_cup' : isNull);
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
    expect(
      detail,
      contains(
        'Drink\nDrink the water. This is reversion: provision returns through the living body, not left on the table.',
      ),
    );
    expect(detail, isNot(contains('Privacy\n')));
    expect(detail, isNot(contains('Source\n')));
  });

  test('generated Words stay speakable across decan sections', () {
    for (final day in <int>[1, 11, 21, 30]) {
      final words = offeringTableDecanLine(day);

      expect(words, isNot(contains('Speak')));
      expect(words, isNot(contains('Before')));
      expect(words, isNot(contains('Then')));
      expect(words, isNot(contains('Optional')));
      expect(words, isNot(contains('\n')));
    }
  });

  test('required provision guardrails do not live in Optional', () {
    final requiredGuardrailDays = <int, String>{
      8: 'schedule the first honest opening',
      9: 'body has actually received it',
      17: 'Do not turn it into apology theater',
      23: 'tell the affected person what is true',
      26: 'Do not leave provision as a symbol',
      28: 'concrete provision the other person can receive',
    };

    for (final entry in requiredGuardrailDays.entries) {
      final day = offeringTableDayByNumber(entry.key)!;

      expect(day.provisionAct, contains(entry.value));
      expect(day.optionalSteps, isEmpty);
      expect(day.optionalSteps.join('\n'), isNot(contains(entry.value)));
    }
  });

  test('completion day truth check and closing names stay discrete', () {
    final day = offeringTableDayByNumber(30)!;
    final detail = offeringTableDetailText(
      day,
      lens: OfferingTableLens.neutral,
      noCupMode: false,
    );

    expect(
      day.purpose,
      'The table was never about perfection — it was about the record being honest. The cycle closes with accuracy, not with achievement.',
    );
    expect(detail, contains('Provision\nSpeak only the lines that are true:'));
    expect(
      detail,
      contains('Say, if true: My water was placed with attention.'),
    );
    expect(
      detail,
      contains(
        'Say, if true: Food, rest, or care was not treated as imaginary.',
      ),
    );
    expect(
      detail,
      contains('Say, if true: I fed one need before it became collapse.'),
    );
    expect(
      detail,
      contains('Say, if true: I noticed who else depends on the table.'),
    );
    expect(
      detail,
      contains('Say, if true: What flowed to me was allowed to return.'),
    );
    expect(detail, contains('Name one shortfall.'));
    expect(detail, contains('Name one provision that surprised you.'));
    expect(detail, isNot(contains('- My water was placed with attention.')));
    expect(detail, isNot(contains('Then name one shortfall')));
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
      'The table was never about perfection — it was about the record being honest. The cycle closes with accuracy, not with achievement.',
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
