import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/reminder_sync_idempotence.dart';

void main() {
  group('reminder occurrence idempotence', () {
    test('treats unchanged occurrence rows as already synchronized', () {
      final desired = ReminderOccurrencePayload(
        clientEventId: 'reminder:rule-1:2026-06-19',
        title: 'journal every night',
        detail: 'color=7bb661;alert=0;',
        location: null,
        startsAtUtc: DateTime.utc(2026, 6, 20, 4, 30),
        endsAtUtc: DateTime.utc(2026, 6, 20, 5),
        allDay: false,
        calendarId: 'calendar-1',
        category: 'Spirit',
        flowLocalId: 677,
      );
      final existing = ReminderOccurrencePayload(
        clientEventId: 'reminder:rule-1:2026-06-19',
        title: 'journal every night',
        detail: 'color=7bb661;alert=0;',
        location: null,
        startsAtUtc: DateTime.parse('2026-06-20T04:30:00.000Z'),
        endsAtUtc: DateTime.parse('2026-06-20T05:00:00.000Z'),
        allDay: false,
        calendarId: 'calendar-1',
        category: 'Spirit',
        flowLocalId: 677,
      );

      expect(
        reminderOccurrencePayloadMatches(desired: desired, existing: existing),
        isTrue,
      );
    });

    test('requires changed reminder rows to be written again', () {
      final desired = ReminderOccurrencePayload(
        clientEventId: 'reminder:rule-1:2026-06-19',
        title: 'journal every night',
        detail: 'color=7bb661;alert=15;',
        location: null,
        startsAtUtc: DateTime.utc(2026, 6, 20, 4, 30),
        endsAtUtc: DateTime.utc(2026, 6, 20, 5),
        allDay: false,
        calendarId: 'calendar-1',
        category: 'Spirit',
        flowLocalId: 677,
      );
      final existing = ReminderOccurrencePayload(
        clientEventId: 'reminder:rule-1:2026-06-19',
        title: 'journal every night',
        detail: 'color=7bb661;alert=0;',
        location: null,
        startsAtUtc: DateTime.utc(2026, 6, 20, 4, 30),
        endsAtUtc: DateTime.utc(2026, 6, 20, 5),
        allDay: false,
        calendarId: 'calendar-1',
        category: 'Spirit',
        flowLocalId: 677,
      );

      expect(
        reminderOccurrencePayloadMatches(desired: desired, existing: existing),
        isFalse,
      );
    });

    test('keeps one-time and all-day end handling exact', () {
      final desired = ReminderOccurrencePayload(
        clientEventId: 'reminder:rule-2:2026-06-19',
        title: 'drink water',
        detail: 'color=55dde0;alert=-1;',
        startsAtUtc: DateTime.utc(2026, 6, 19, 16),
        allDay: true,
      );
      final existingWithNoEnd = ReminderOccurrencePayload(
        clientEventId: 'reminder:rule-2:2026-06-19',
        title: 'drink water',
        detail: 'color=55dde0;alert=-1;',
        startsAtUtc: DateTime.utc(2026, 6, 19, 16),
        allDay: true,
      );
      final existingWithEnd = ReminderOccurrencePayload(
        clientEventId: 'reminder:rule-2:2026-06-19',
        title: 'drink water',
        detail: 'color=55dde0;alert=-1;',
        startsAtUtc: DateTime.utc(2026, 6, 19, 16),
        endsAtUtc: DateTime.utc(2026, 6, 19, 16, 30),
        allDay: true,
      );

      expect(
        reminderOccurrencePayloadMatches(
          desired: desired,
          existing: existingWithNoEnd,
        ),
        isTrue,
      );
      expect(
        reminderOccurrencePayloadMatches(
          desired: desired,
          existing: existingWithEnd,
        ),
        isFalse,
      );
    });
  });

  test('sync worker prunes stale reminders before skipping unchanged rows', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final worker = _sourceBetween(
      source,
      'Future<void> _performReminderSync({',
      'Future<void> _deleteReminderOccurrenceRows',
    );

    expect(worker, contains('reminderOccurrencePayloadMatches'));
    expect(worker, contains('skippedUnchangedOccurrenceWrites'));
    expect(
      worker.indexOf('_deleteReminderOccurrenceRows('),
      lessThan(worker.indexOf('reminderOccurrencePayloadMatches')),
    );
    expect(
      worker.indexOf('reminderOccurrencePayloadMatches'),
      lessThan(worker.indexOf('repo.upsertByClientId(')),
    );
  });
}

String _sourceBetween(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  expect(start, isNonNegative, reason: 'missing start marker: $startMarker');
  final end = source.indexOf(endMarker, start + startMarker.length);
  expect(end, isNonNegative, reason: 'missing end marker: $endMarker');
  return source.substring(start, end);
}
