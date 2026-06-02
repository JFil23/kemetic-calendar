import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/dawn_house_rite_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';

void main() {
  test('schedules a three minute Pacific dawn occurrence', () {
    final schedule = dawnHouseRiteScheduleForDate(
      DateTime(2026, 6, 1),
      TrackSkyTimeZone.pacific,
    );

    expect(schedule.startLocal.year, 2026);
    expect(schedule.startLocal.month, 6);
    expect(schedule.startLocal.day, 1);
    expect(schedule.startLocal.hour, inInclusiveRange(3, 5));
    expect(
      schedule.endUtc.difference(schedule.startUtc),
      const Duration(minutes: 3),
    );
    expect(schedule.usedFallback, isFalse);
  });

  test('default start date advances after the current dawn has passed', () {
    final beforeDawn = defaultDawnHouseRiteStartDate(
      TrackSkyTimeZone.pacific,
      now: DateTime.utc(2026, 6, 1, 8),
    );
    final afterDawn = defaultDawnHouseRiteStartDate(
      TrackSkyTimeZone.pacific,
      now: DateTime.utc(2026, 6, 1, 14),
    );

    expect(beforeDawn, DateTime(2026, 6, 1));
    expect(afterDawn, DateTime(2026, 6, 2));
  });

  test('discreet detail removes visible ritual language', () {
    final detail = dawnHouseRiteDetailText(
      kDawnHouseRiteDays[17],
      discreet: true,
      lens: DawnHouseRiteLens.thothic,
    );

    expect(detail.toLowerCase(), isNot(contains('offering')));
    expect(detail.toLowerCase(), isNot(contains('altar')));
    expect(detail.toLowerCase(), isNot(contains("ma'at")));
    expect(detail, contains('sign of care'));
    expect(detail, contains('Record one clear observation'));
  });

  test('detail text keeps only readable rite sections', () {
    final detail = dawnHouseRiteDetailText(
      kDawnHouseRiteDays.first,
      discreet: false,
      lens: DawnHouseRiteLens.neutral,
    );

    expect(detail, isNot(contains('Cycle:')));
    expect(detail, isNot(contains('Completion:')));
    expect(
      detail,
      contains(
        'Purpose\nDawn is the daily proof that order returns. This rite enters that return deliberately.',
      ),
    );
    expect(
      detail,
      contains('Action\nWash hands and face. Set water. Face the light.'),
    );
    expect(detail, contains('Words\n"'));
    expect(detail, contains("Ma'at act\nName one thing"));
  });

  test('builds thirty JSON-safe dawn event payloads', () {
    final startDate = DateTime(2026, 6, 1);
    final starts = <DateTime>{};

    for (var i = 0; i < kDawnHouseRiteDays.length; i++) {
      final day = kDawnHouseRiteDays[i];
      final schedule = dawnHouseRiteScheduleForDate(
        startDate.add(Duration(days: i)),
        TrackSkyTimeZone.eastern,
      );
      final payload = dawnHouseRiteBehaviorPayload(
        day: day,
        schedule: schedule,
        discreet: i.isEven,
        lens: DawnHouseRiteLens.protection,
      );

      expect(jsonDecode(jsonEncode(payload)), isA<Map<String, dynamic>>());
      expect(payload.containsKey('section'), isFalse);
      expect(payload.containsKey('completion_options'), isFalse);
      expect(payload['missed_event_rule'], 'expire_quietly');
      starts.add(schedule.startUtc);
    }

    expect(kDawnHouseRiteDays, hasLength(30));
    expect(starts, hasLength(30));
  });

  test('canonical detail rebuilds stale dawn events without cycle status', () {
    final detail = canonicalDawnHouseRiteDetailTextForEvent(
      flowName: kDawnHouseRiteTitle,
      flowNotes: 'mode=gregorian;maat=dawn-house-rite;dawn_lens=thothic',
      title: 'Day 1: Opening the Day',
      actionId: 'dawn-house-rite-day-01',
      behaviorPayload: const <String, dynamic>{
        'kind': 'maat_dawn_house_rite_day',
        'flow_key': 'dawn-house-rite',
        'day': 1,
      },
    );

    expect(detail, isNotNull);
    expect(detail, isNot(contains('Cycle:')));
    expect(detail, isNot(contains('Completion:')));
    expect(
      detail,
      contains(
        'Purpose\nDawn is the daily proof that order returns. This rite enters that return deliberately.',
      ),
    );
    expect(detail, contains('Lens\nKeep one exact record'));
  });

  test('purpose copy checkpoints match the upgraded thirty-day rite', () {
    expect(
      dawnHouseRiteDayByNumber(1)?.purpose,
      'Dawn is the daily proof that order returns. This rite enters that return deliberately.',
    );
    expect(
      dawnHouseRiteDayByNumber(10)?.purpose,
      'Ten days is one decan — enough time to see a pattern. This rite closes that measure and opens the next one clean.',
    );
    expect(
      dawnHouseRiteDayByNumber(20)?.purpose,
      'The second decan closes. What pattern did the household hold? What does it need to carry better into the next ten days?',
    );
    expect(
      dawnHouseRiteDayByNumber(30)?.purpose,
      'Thirty dawns have opened. The practice does not complete — it becomes more accurate. This rite marks what changed.',
    );
  });

  test('calendar join waits for Dawn event persistence before success', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final methodStart = source.indexOf('Future<int> _addMaatFlowInstance({');
    expect(methodStart, isNonNegative);
    final branchStart = source.indexOf(
      'if (template.kind == _MaatFlowTemplateKind.dawnHouseRite)',
      methodStart,
    );
    expect(branchStart, isNonNegative);
    final branchEnd = source.indexOf('if (startDate == null)', branchStart);
    expect(branchEnd, isNonNegative);
    final branch = source.substring(branchStart, branchEnd);

    expect(branch, contains('await repo.upsertByClientId'));
    expect(branch, isNot(contains('Future.microtask')));
    expect(branch, contains('repo.deleteFlow(serverFlowId)'));
  });

  test(
    'maat template join does not pop a root list route into blank space',
    () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();

      expect(source, contains('if (listNavigator.canPop())'));
      expect(source, contains('listNavigator.pop(importedFlowId)'));
      expect(
        source,
        contains('Navigator.of(listCtx, rootNavigator: true).pop()'),
      );
      expect(source, contains('if (navigator.canPop())'));
      expect(
        source,
        contains('Navigator.of(navigator.context, rootNavigator: true).pop()'),
      );
    },
  );
}
