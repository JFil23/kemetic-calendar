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

    test(
      'rule edits update the same occurrence identity instead of duplicating',
      () {
        final editedRuleOccurrence = ReminderOccurrencePayload(
          clientEventId: 'reminder:rule-1:2026-06-19',
          title: 'journal every night',
          detail: 'color=7bb661;alert=0;',
          location: null,
          startsAtUtc: DateTime.utc(2026, 6, 20, 5, 15),
          endsAtUtc: DateTime.utc(2026, 6, 20, 5, 45),
          allDay: false,
          calendarId: 'calendar-1',
          category: 'Spirit',
          flowLocalId: 677,
        );
        final existingOccurrence = ReminderOccurrencePayload(
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
          editedRuleOccurrence.clientEventId,
          existingOccurrence.clientEventId,
          reason:
              'A reminder rule edit for the same day must retain the stable '
              'occurrence CID so upsert replaces the row instead of creating a '
              'second occurrence.',
        );
        expect(
          reminderOccurrencePayloadMatches(
            desired: editedRuleOccurrence,
            existing: existingOccurrence,
          ),
          isFalse,
          reason:
              'The changed schedule must be detected as an update even though '
              'the stable occurrence identity is unchanged.',
        );
      },
    );

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

  test('sync worker keeps warm-start reminders idempotent and authoritative', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final syncWrapper = _sourceBetween(
      source,
      'Future<void> _syncReminderEvents({',
      'static const int _reminderSyncYieldBatchSize',
    );
    final worker = _sourceBetween(
      source,
      'Future<void> _performReminderSync({',
      'Future<void> _deleteReminderOccurrenceRows',
    );
    final deleteRule = _sourceBetween(
      source,
      'Future<void> _deleteReminderRule(String id) async {',
      'Set<int> _monthDayTargets',
    );

    expect(syncWrapper, contains('_pendingReminderSyncUpdateLocalCache ||'));
    expect(
      syncWrapper,
      contains('await _reminderSyncGate.runCoalesced'),
      reason:
          'Repeated warm-start sync requests should collapse into bounded '
          'passes instead of racing duplicate local materialization.',
    );
    expect(worker, contains('existingRowsByClientEventId'));
    expect(worker, contains("final cid = 'reminder:\${rule.id}:\$cidDate';"));
    expect(worker, contains('repo.upsertByClientId('));
    expect(
      worker.indexOf('existingRowsByClientEventId'),
      lessThan(worker.indexOf('repo.upsertByClientId(')),
    );
    expect(
      worker,
      contains('_pruneReminderNotes(rule.id, fromDate: today)'),
      reason:
          'Authorized background sync must remove locally materialized future '
          'copies before re-materializing the current desired occurrence set.',
    );
    expect(worker, contains('_materializeReminderLocally('));
    expect(
      worker.indexOf('_pruneReminderNotes(rule.id, fromDate: today)'),
      lessThan(worker.indexOf('_materializeReminderLocally(')),
    );
    expect(worker, contains('if (!rule.active)'));
    expect(worker, contains("semantic: 'reminder_inactive_prune'"));
    expect(worker, contains("semantic: 'reminder_generated_prune'"));
    expect(
      deleteRule,
      contains('_endedReminderIds.add(id)'),
      reason:
          'Deleted reminders must be tombstoned so later hydration cannot '
          'reconstruct them from stale occurrence rows.',
    );
    expect(
      deleteRule,
      contains('eventsRepo.deleteByClientIdPrefix(cidPrefix)'),
    );
    expect(deleteRule, contains('_pruneReminderNotes('));
    expect(
      worker,
      isNot(contains('requestNotificationsPermission')),
      reason:
          'Background reminder sync may schedule or persist alerts, but it '
          'must not open the Android runtime permission prompt.',
    );
    expect(
      worker,
      isNot(contains('requestPermissions(')),
      reason:
          'Background reminder sync must not open iOS/macOS notification '
          'permission prompts.',
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
