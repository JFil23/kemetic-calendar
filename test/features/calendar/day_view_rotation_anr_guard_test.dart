import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Day View rotation ANR guard', () {
    late String calendarSource;
    late String dayViewSource;
    late String landscapeSource;

    setUpAll(() {
      calendarSource = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      dayViewSource = File(
        'lib/features/calendar/day_view.dart',
      ).readAsStringSync();
      landscapeSource = File(
        'lib/features/calendar/landscape_month_view.dart',
      ).readAsStringSync();
    });

    test('Day View notes adapter is pure during orientation builds', () {
      final openDayView = _sourceBetween(
        calendarSource,
        'void _openDayView(',
        'Navigator.push(',
      );
      final adapter = _sourceBetween(
        openDayView,
        'List<NoteData> notesForDayFn(int y, int m, int d)',
        'final flowIndex = _buildCalendarFlowChromeIndex();',
      );

      expect(adapter, contains('_noteDataForDay(y, m, d)'));
      expect(adapter, isNot(contains('_reminderService')));
      expect(adapter, isNot(contains('addOrUpdate')));
      expect(adapter, isNot(contains('Notify.')));
      expect(adapter, isNot(contains('Events.track')));
      expect(adapter, isNot(contains('title="')));
    });

    test('shared note render adapter does not mutate reminders', () {
      final helper = _sourceBetween(
        calendarSource,
        'List<NoteData> _noteDataForDay(int y, int m, int d)',
        '// Build a reminder id',
      );

      expect(helper, contains('_dedupeVisibleDayNotes'));
      expect(helper, contains('_noteDataFromNote(note)'));
      expect(helper, isNot(contains('_reminderService')));
      expect(helper, isNot(contains('addOrUpdate')));
      expect(helper, isNot(contains('Notify.')));
      expect(helper, isNot(contains('Events.track')));
    });

    test('reminder writes remain in the scheduling path', () {
      final schedulingPath = _sourceBetween(
        calendarSource,
        'Future<NotificationScheduleResult?> _scheduleAlertForEvent({',
        'void _showNotificationScheduleWarning',
      );

      expect(schedulingPath, contains('Notify.scheduleAlertWithPersistenceResult'));
      expect(schedulingPath, contains('_reminderService.addOrUpdate'));
    });

    test('reminder sync pauses and coalesces during orientation changes', () {
      final syncEntry = _sourceBetween(
        calendarSource,
        'Future<void> _syncReminderEvents({',
        'static const int _reminderSyncYieldBatchSize',
      );
      final syncWorker = _sourceBetween(
        calendarSource,
        'Future<void> _performReminderSync({',
        'Future<void> _deleteReminderOccurrenceRows',
      );
      final orientationMetrics = _sourceBetween(
        calendarSource,
        'void didChangeMetrics()',
        '/* ───── helpers ───── */',
      );
      final orientationBuild = _sourceBetween(
        calendarSource,
        'final previousOrientation = _lastOrientation;',
        'if (useGrid) {',
      );

      expect(syncEntry, contains('_reminderSyncGate.runCoalesced'));
      expect(syncEntry, contains('_pendingReminderSyncRefreshUi'));
      expect(syncEntry, contains('_pendingReminderSyncUpdateLocalCache'));
      expect(
        syncWorker,
        contains('_reminderSyncGate.waitForOrientationCriticalSection()'),
      );
      expect(syncWorker, contains('_yieldReminderSyncBatchIfNeeded'));
      expect(syncWorker, contains("caller: 'reminder_sync'"));
      expect(
        orientationMetrics,
        contains("_beginOrientationCriticalReminderSyncDeferral('metrics')"),
      );
      expect(
        orientationBuild,
        contains(
          "_beginOrientationCriticalReminderSyncDeferral('calendar_build')",
        ),
      );
    });

    test('landscape month build logging does not print raw note titles', () {
      final buildEventsForDay = _sourceBetween(
        landscapeSource,
        'List<Widget> _buildEventsForDay(int day, double colW)',
        'final notes = _dedupeNotesForUI(rawNotes);',
      );

      expect(buildEventsForDay, contains('Raw notes:'));
      expect(buildEventsForDay, isNot(contains('note.title')));
      expect(buildEventsForDay, isNot(contains('Note: "')));
    });

    test('Day View event block rendering does not log raw event titles', () {
      final buildEventBlock = _sourceBetween(
        dayViewSource,
        'Widget _buildEventBlock(',
        'final int durationMinutes =',
      );

      expect(buildEventBlock, isNot(contains('debugPrint')));
      expect(buildEventBlock, isNot(contains('event.title')));
      expect(buildEventBlock, isNot(contains('Rendering: title=')));
    });
  });
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'Missing source start: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: 'Missing source end: $end');
  return source.substring(startIndex, endIndex);
}
