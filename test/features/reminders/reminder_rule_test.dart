import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/reminders/reminder_rule.dart';

void main() {
  group('ReminderRepeat.fromJson', () {
    test('supports legacy single-day repeat fields', () {
      final repeat = ReminderRepeat.fromJson({
        'kind': 'monthlyDay',
        'interval': 2,
        'weekdays': [1, 3, 7],
        'monthDay': 14,
        'decanDay': 3,
        'kemeticMonthDay': 20,
      });

      expect(repeat.kind, ReminderRepeatKind.monthlyDay);
      expect(repeat.interval, 2);
      expect(repeat.weekdays, {1, 3, 7});
      expect(repeat.monthDay, 14);
      expect(repeat.monthDays, {14});
      expect(repeat.decanDays, {3});
      expect(repeat.kemeticMonthDays, {20});
    });

    test('prefers explicit day sets over legacy single values', () {
      final repeat = ReminderRepeat.fromJson({
        'kind': 'kemeticMonthDay',
        'monthDay': 14,
        'monthDays': [1, 15],
        'decanDay': 2,
        'decanDays': [4, 8],
        'kemeticMonthDay': 12,
        'kemeticMonthDays': [6, 18, 24],
      });

      expect(repeat.monthDays, {1, 15});
      expect(repeat.decanDays, {4, 8});
      expect(repeat.kemeticMonthDays, {6, 18, 24});
    });
  });

  group('ReminderRule serialization', () {
    test('applies safe defaults when optional fields are omitted', () {
      final rule = ReminderRule.fromJson({
        'id': 'rule-1',
        'title': 'Temple visit',
        'startLocal': '2026-04-15T09:00:00',
      });

      expect(rule.id, 'rule-1');
      expect(rule.title, 'Temple visit');
      expect(rule.allDay, isFalse);
      expect(rule.color.toARGB32(), Colors.blue.toARGB32());
      expect(rule.category, isNull);
      expect(rule.active, isTrue);
      expect(rule.repeat.kind, ReminderRepeatKind.none);
      expect(rule.alertOffsetMinutes, -1);
    });

    test('encodeList and decodeList dedupe by reminder id', () {
      final first = ReminderRule(
        id: 'rule-1',
        title: 'Morning prayer',
        startLocal: DateTime(2026, 4, 15, 6),
        color: Colors.orange,
      );
      final duplicate = first.copyWith(title: 'Changed title');
      final second = ReminderRule(
        id: 'rule-2',
        title: 'Evening reflection',
        startLocal: DateTime(2026, 4, 15, 20),
        color: Colors.indigo,
        repeat: const ReminderRepeat(
          kind: ReminderRepeatKind.weekly,
          weekdays: {1, 3, 5},
        ),
      );

      final encoded = ReminderRule.encodeList([first, duplicate, second]);
      final decoded = ReminderRule.decodeList(encoded);

      expect(decoded, hasLength(2));
      expect(decoded.first.id, 'rule-1');
      expect(decoded.first.title, 'Morning prayer');
      expect(decoded.last.id, 'rule-2');
      expect(decoded.last.repeat.kind, ReminderRepeatKind.weekly);
      expect(decoded.last.repeat.weekdays, {1, 3, 5});
    });
  });
}
