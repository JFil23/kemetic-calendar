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

      expect(
        schedulingPath,
        contains('Notify.scheduleAlertWithPersistenceResult'),
      );
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
        'if (shouldBuildLandscapeGrid) {',
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

    test('covered Calendar route does not build hidden landscape grid', () {
      final landscapeBranch = _sourceBetween(
        calendarSource,
        'final routeIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;',
        'if (shouldBuildLandscapeGrid) {',
      );
      final gridBranch = _sourceBetween(
        calendarSource,
        'if (shouldBuildLandscapeGrid) {',
        'final scaffold = _withCalendarFloatingShortcuts(',
      );

      expect(landscapeBranch, contains('final useGrid ='));
      expect(
        landscapeBranch,
        contains(
          'final routeShouldRemainRendered =\n'
          '        routeIsCurrent ||\n'
          '        CalendarPage._hasCalendarOwnedTransientOverlayOpenOrOpening;',
        ),
      );
      expect(
        landscapeBranch,
        contains(
          'final shouldBuildLandscapeGrid = useGrid && routeShouldRemainRendered;',
        ),
        reason:
            'Calendar-owned sheets keep the route painted behind them; unrelated covered routes still shrink below.',
      );
      expect(gridBranch, contains('LandscapeMonthView('));
      expect(gridBranch, isNot(contains('if (useGrid) {')));
    });

    test('covered Calendar route skips heavy calendar body builds', () {
      final coveredRouteBranch = _sourceBetween(
        calendarSource,
        'if (!routeShouldRemainRendered) {',
        'if (shouldBuildLandscapeGrid) {',
      );

      expect(coveredRouteBranch, contains('Scaffold('));
      expect(coveredRouteBranch, contains('SizedBox.shrink()'));
      expect(coveredRouteBranch, isNot(contains('_buildBodyWithJournal')));
      expect(coveredRouteBranch, isNot(contains('LandscapeMonthView(')));
    });

    test('portrait recenter keeps Calendar body painted', () {
      final bodyWithJournal = _sourceBetween(
        calendarSource,
        'Widget _buildBodyWithJournal() {',
        '/* ───────────── Decan Reflection Badge & Archive ───────────── */',
      );

      expect(bodyWithJournal, contains('_ensurePortraitCentered();'));
      expect(bodyWithJournal, contains('_buildCalendarScrollView()'));
      expect(bodyWithJournal, isNot(contains('Offstage(')));
      expect(
        bodyWithJournal,
        isNot(contains('offstage: _portraitRecenterPending && isPortrait')),
      );
    });

    test(
      'landscape uses a lazy day viewport without logging private note content',
      () {
        final viewportSource = File(
          'lib/features/calendar/landscape_timeline_viewport.dart',
        ).readAsStringSync();
        expect(viewportSource, contains('TwoDimensionalChildBuilderDelegate('));
        expect(viewportSource, isNot(contains('debugPrint')));
        expect(landscapeSource, contains('_buildDay(_dateAt(index))'));
        expect(landscapeSource, isNot(contains('debugPrint')));
      },
    );

    test('Day View event block rendering does not log raw event titles', () {
      final buildEventBlock = _sourceBetween(
        dayViewSource,
        'Widget _buildEventBlock(',
        'Widget _buildNowLine()',
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
