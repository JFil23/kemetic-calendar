import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/evening_threshold_rite_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';

void main() {
  test('schedules a three minute Pacific sunset occurrence', () {
    final schedule = eveningThresholdScheduleForDate(
      DateTime(2026, 6, 1),
      TrackSkyTimeZone.pacific,
    );

    expect(schedule.startLocal.year, 2026);
    expect(schedule.startLocal.month, 6);
    expect(schedule.startLocal.day, 1);
    expect(schedule.startLocal.hour, inInclusiveRange(19, 21));
    expect(
      schedule.endUtc.difference(schedule.startUtc),
      const Duration(minutes: 3),
    );
    expect(schedule.usedFallback, isFalse);
  });

  test('default start date advances after the current evening has passed', () {
    final beforeEvening = defaultEveningThresholdRiteStartDate(
      TrackSkyTimeZone.pacific,
      now: DateTime.utc(2026, 6, 2, 1),
    );
    final afterEvening = defaultEveningThresholdRiteStartDate(
      TrackSkyTimeZone.pacific,
      now: DateTime.utc(2026, 6, 2, 5),
    );

    expect(beforeEvening, DateTime(2026, 6, 1));
    expect(afterEvening, DateTime(2026, 6, 2));
  });

  test('discreet detail removes visible ritual language', () {
    final detail = eveningThresholdRiteDetailText(
      kEveningThresholdRiteDays[27],
      discreet: true,
      lens: EveningThresholdRiteLens.hiddenRenewal,
    );

    expect(detail.toLowerCase(), isNot(contains('offering')));
    expect(detail.toLowerCase(), isNot(contains('altar')));
    expect(detail.toLowerCase(), isNot(contains('flame')));
    expect(detail.toLowerCase(), isNot(contains('incense')));
    expect(detail.toLowerCase(), isNot(contains("ma'at")));
    expect(detail, contains('Quiet line'));
    expect(detail, contains('sign of gratitude'));
    expect(detail, contains('Let quiet restore'));
  });

  test('detail text keeps only readable rite sections', () {
    final detail = eveningThresholdRiteDetailText(
      kEveningThresholdRiteDays.first,
      discreet: false,
      lens: EveningThresholdRiteLens.neutral,
    );

    expect(detail, isNot(contains('Cycle:')));
    expect(detail, isNot(contains('Completion:')));
    expect(
      detail,
      contains(
        'Purpose\nThe evening has no official start time. This rite marks one deliberately.',
      ),
    );
    expect(detail, contains('Action\nPause near a window'));
    expect(detail, contains('Words\n"'));
    expect(detail, contains('Evening act\nClose one open loop'));
  });

  test('builds thirty JSON-safe evening event payloads', () {
    final startDate = DateTime(2026, 6, 1);
    final starts = <DateTime>{};

    for (var i = 0; i < kEveningThresholdRiteDays.length; i++) {
      final day = kEveningThresholdRiteDays[i];
      final schedule = eveningThresholdScheduleForDate(
        startDate.add(Duration(days: i)),
        TrackSkyTimeZone.eastern,
        fallbackMinutesAfterMidnight: 21 * 60,
      );
      final payload = eveningThresholdRiteBehaviorPayload(
        day: day,
        schedule: schedule,
        discreet: i.isEven,
        lens: EveningThresholdRiteLens.protection,
      );

      expect(jsonDecode(jsonEncode(payload)), isA<Map<String, dynamic>>());
      expect(payload['burden'], 'low');
      expect(payload['completion_options'], hasLength(3));
      expect(payload['missed_event_rule'], 'expire_quietly');
      expect(
        payload['schedule'],
        containsPair('fallback', 'user_selected_evening_time'),
      );
      starts.add(schedule.startUtc);
    }

    expect(kEveningThresholdRiteDays, hasLength(30));
    expect(starts, hasLength(30));
  });

  test('purpose copy checkpoints match the upgraded thirty-evening rite', () {
    expect(
      kEveningThresholdRiteDays[0].purpose,
      'The evening has no official start time. This rite marks one deliberately.',
    );
    expect(
      kEveningThresholdRiteDays[9].purpose,
      'What pattern appeared across the first ten closings? The recalibration asks before the next ten begin.',
    );
    expect(
      kEveningThresholdRiteDays[19].purpose,
      'Ten evenings of household attention. What did the house give back? What does it still need?',
    );
    expect(
      kEveningThresholdRiteDays[29].purpose,
      'Thirty evenings of deliberate closing. The practice is not finished — it is established. This rite marks what changed.',
    );
  });

  test('calendar join waits for Evening event persistence before success', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final methodStart = source.indexOf('Future<int> _addMaatFlowInstance({');
    expect(methodStart, isNonNegative);
    final branchStart = source.indexOf(
      'if (template.kind == _MaatFlowTemplateKind.eveningThresholdRite)',
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
}
