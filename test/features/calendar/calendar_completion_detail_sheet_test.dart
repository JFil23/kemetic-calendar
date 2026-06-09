import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/calendar_completion.dart';
import 'package:mobile/features/journal/journal_event_badge.dart';

void main() {
  test('calendar detail sheets no longer expose Add to journal actions', () {
    final dayView = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();
    final monthGrid = File(
      'lib/features/calendar/calendar_grid_widgets.dart',
    ).readAsStringSync();
    final landscape = File(
      'lib/features/calendar/landscape_month_view.dart',
    ).readAsStringSync();

    for (final source in [dayView, monthGrid, landscape]) {
      expect(source, isNot(contains('Add to journal')));
      expect(source, isNot(contains("value: 'journal'")));
      expect(source, isNot(contains("value == 'journal'")));
    }
  });

  test(
    'completion picker is wired for Ma_at, ordinary flow, note, and reminder details',
    () {
      final dayView = File(
        'lib/features/calendar/day_view.dart',
      ).readAsStringSync();
      final monthGrid = File(
        'lib/features/calendar/calendar_grid_widgets.dart',
      ).readAsStringSync();

      expect(dayView, contains('class _MaatFlowCompletionPanel'));
      expect(dayView, contains('CalendarCompletionPicker('));
      expect(dayView, contains('CalendarEventCompletionPanel('));
      expect(monthGrid, contains('CalendarEventCompletionPanel('));

      expect(dayView, contains('CompletionSourceType.maatFlow'));
      expect(dayView, contains('CompletionSourceType.userFlow'));
      expect(dayView, contains('CompletionSourceType.note'));
      expect(dayView, contains('CompletionSourceType.reminder'));
    },
  );

  test('observed and partial create continuity while skipped stays muted', () {
    expect(CompletionStatus.observed.createsJournalContinuity, isTrue);
    expect(CompletionStatus.partial.createsJournalContinuity, isTrue);
    expect(CompletionStatus.skipped.createsJournalContinuity, isFalse);
  });

  test('observed and partial badge tokens share identity and keep status', () {
    final observed = buildCalendarCompletionBadgeToken(
      identity: 'cid:event-1',
      sourceType: CompletionSourceType.userFlow,
      completionStatus: CompletionStatus.observed,
      title: 'Practice',
      color: const Color(0xFFFFC145),
    );
    final partial = buildCalendarCompletionBadgeToken(
      identity: 'cid:event-1',
      sourceType: CompletionSourceType.userFlow,
      completionStatus: CompletionStatus.partial,
      title: 'Practice',
      color: const Color(0xFFFFC145),
    );

    final observedToken = EventBadgeToken.parse(observed);
    final partialToken = EventBadgeToken.parse(partial);

    expect(observedToken!.id, partialToken!.id);
    expect(observedToken.completionStatus, CompletionStatus.observed);
    expect(partialToken.completionStatus, CompletionStatus.partial);
  });

  test(
    'detail opening remains a real transient sheet for notification search and shared taps',
    () {
      final calendarPage = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();

      expect(
        calendarPage,
        contains('Future<void> _openCalendarEventDetailSheet'),
      );
      expect(calendarPage, contains('showModalBottomSheet'));
      expect(calendarPage, contains('_restoreCalendarEventDetailOverlay'));
      expect(
        calendarPage,
        contains('_eventDetailRestorationStateForPushIntent'),
      );
      expect(
        calendarPage,
        contains('_sharedCalendarEventDetailSnapshotForFiledEvent'),
      );
      expect(
        calendarPage,
        contains('await _clearCalendarEventDetailOverlayState();'),
      );

      final openSheetStart = calendarPage.indexOf(
        'Future<void> _openCalendarEventDetailSheet',
      );
      final openSheetEnd = calendarPage.indexOf(
        'Future<bool> _restoreCalendarEventDetailOverlay',
      );
      final openSheetBody = calendarPage.substring(
        openSheetStart,
        openSheetEnd,
      );
      expect(openSheetBody, isNot(contains('durableSection')));
    },
  );
}
