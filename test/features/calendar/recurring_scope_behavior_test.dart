import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_recurring_scope.dart';

void main() {
  group('recurring scope date planner', () {
    final dates = <DateTime>[
      DateTime(2026, 6, 8),
      DateTime(2026, 6, 9),
      DateTime(2026, 6, 10),
    ];

    test('this event only does not alter the full series', () {
      final plan = planCalendarRecurringDateScope(
        originalDates: dates,
        selectedDate: DateTime(2026, 6, 9),
        targetSelectedDate: DateTime(2026, 6, 12),
        scope: CalendarRecurringMutationScope.thisEventOnly,
      );

      expect(plan.keptOriginalDates, {
        DateTime(2026, 6, 8),
        DateTime(2026, 6, 10),
      });
      expect(plan.affectedOriginalDates, {DateTime(2026, 6, 9)});
      expect(plan.shiftedAffectedDates, {DateTime(2026, 6, 12)});
    });

    test('this and future splits past from affected future dates', () {
      final plan = planCalendarRecurringDateScope(
        originalDates: dates,
        selectedDate: DateTime(2026, 6, 9),
        scope: CalendarRecurringMutationScope.thisAndFuture,
      );

      expect(plan.keptOriginalDates, {DateTime(2026, 6, 8)});
      expect(plan.affectedOriginalDates, {
        DateTime(2026, 6, 9),
        DateTime(2026, 6, 10),
      });
    });

    test('entire series alters the full series', () {
      final plan = planCalendarRecurringDateScope(
        originalDates: dates,
        selectedDate: DateTime(2026, 6, 9),
        targetSelectedDate: DateTime(2026, 6, 11),
        scope: CalendarRecurringMutationScope.entireSeries,
      );

      expect(plan.keptOriginalDates, isEmpty);
      expect(plan.affectedOriginalDates, dates.toSet());
      expect(plan.shiftedAffectedDates, {
        DateTime(2026, 6, 10),
        DateTime(2026, 6, 11),
        DateTime(2026, 6, 12),
      });
    });
  });

  group('recurring scope calendar integration guards', () {
    late String calendarPage;
    late String dayView;
    late String gridWidgets;

    setUpAll(() async {
      calendarPage = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      dayView = await File(
        'lib/features/calendar/day_view.dart',
      ).readAsString();
      gridWidgets = await File(
        'lib/features/calendar/calendar_grid_widgets.dart',
      ).readAsString();
    });

    test('editing a repeating event shows native scope choices', () {
      final scopeSheet = _sourceBetween(
        calendarPage,
        'Future<CalendarRecurringMutationScope?> _showRepeatingEventScopeSheet',
        'Future<_Flow?> _persistRepeatingNoteFlow',
      );

      expect(scopeSheet, contains('CupertinoActionSheet'));
      expect(
        CalendarRecurringMutationScope.thisEventOnly.label,
        'This event only',
      );
      expect(
        CalendarRecurringMutationScope.thisAndFuture.label,
        'This and future events',
      );
      expect(
        CalendarRecurringMutationScope.entireSeries.label,
        'Entire series',
      );

      final saveHandler = _sourceBetween(
        calendarPage,
        'final editingRepeatingFlow =',
        'if (!handledRepeatingEdit &&',
      );
      expect(saveHandler, contains('_showRepeatingEventScopeSheet'));
      expect(saveHandler, contains('_applyRepeatingNoteEditScope'));
    });

    test('deleting a repeating event shows scope choices before mutation', () {
      final deleteRepeatingBranch = _sourceBetween(
        calendarPage,
        'final repeatingFlow = _repeatingNoteFlowForId(flowIdForNote);',
        'final pendingKey = _buildDeletionKey',
      );

      expect(deleteRepeatingBranch, contains('_showRepeatingEventScopeSheet'));
      expect(deleteRepeatingBranch, contains('_applyRepeatingNoteDeleteScope'));
      expect(
        deleteRepeatingBranch.indexOf('_showRepeatingEventScopeSheet'),
        lessThan(
          deleteRepeatingBranch.indexOf('_applyRepeatingNoteDeleteScope'),
        ),
      );
    });

    test('notification reconcile respects selected scope', () {
      final exactDelete = _sourceBetween(
        calendarPage,
        'Future<void> _deleteRepeatingOccurrenceRow',
        'Future<void> _notifySharedRepeatingScope',
      );
      final deleteScope = _sourceBetween(
        calendarPage,
        'Future<bool> _applyRepeatingNoteDeleteScope',
        '_applyRepeatingNoteEditScope({',
      );
      final editScope = _sourceBetween(
        calendarPage,
        '_applyRepeatingNoteEditScope({',
        'String? _buildDeletionKey',
      );
      final persistFlow = _sourceBetween(
        calendarPage,
        'Future<_Flow?> _persistRepeatingNoteFlow',
        'Future<_Flow> _createRepeatingNoteFlowFromDates',
      );
      final createFlow = _sourceBetween(
        calendarPage,
        'Future<_Flow> _createRepeatingNoteFlowFromDates',
        'Future<void> _deleteRepeatingNoteFlowSeries',
      );

      expect(exactDelete, contains('Notify.cancelNotificationForEvent'));
      expect(deleteScope, contains("deleteScope: 'repeat_this_event'"));
      expect(editScope, contains('deleteByFlowId'));
      expect(persistFlow, contains('scheduleFlowNotes'));
      expect(createFlow, contains('scheduleFlowNotes'));
      expect(editScope, contains('repeat_this_and_future'));
      expect(editScope, contains('repeat_entire_series_replace'));
    });

    test('shared calendar update fanout respects selected scope', () {
      final notifyScope = _sourceBetween(
        calendarPage,
        'Future<void> _notifySharedRepeatingScope',
        'Future<bool> _applyRepeatingNoteDeleteScope',
      );

      expect(notifyScope, contains('_notifySharedCalendarMembers'));
      expect(notifyScope, contains("'recurrence_scope': scope.name"));
      expect(notifyScope, contains("'flow_id': flowId"));
    });

    test(
      'search and detail routing do not reopen stale deleted occurrences',
      () {
        final dayViewDelete = _sourceBetween(
          dayView,
          "value == 'end_note'",
          "value == 'journal'",
        );
        final gridDelete = _sourceBetween(
          gridWidgets,
          "value == 'end_note'",
          "value == 'journal'",
        );
        final searchOpen = _sourceBetween(
          calendarPage,
          'void _openSearchForContext',
          '/* ───── Flow Studio ───── */',
        );

        expect(dayViewDelete, contains('Navigator.pop(sheetContext)'));
        expect(gridDelete, contains('Navigator.pop(sheetContext)'));
        expect(
          searchOpen,
          contains('_eventDetailRestorationStateForSearchNote'),
        );
        expect(
          searchOpen,
          contains('initialEventDetailRestorationState: detail'),
        );
      },
    );

    test(
      'existing one-off event edit and delete behavior remains unchanged',
      () {
        final saveHandler = _sourceBetween(
          calendarPage,
          'else if (!isRepeating) {',
          '} else {\n                                      // Repeating note',
        );
        final deleteFallback = _sourceBetween(
          calendarPage,
          'final pendingKey = _buildDeletionKey',
          'Future<void> _deleteNoteByEvent',
        );

        expect(saveHandler, contains('_updateSingleNoteOnly'));
        expect(saveHandler, contains('_saveSingleNoteOnly'));
        expect(deleteFallback, contains('await repo.delete(note.id!)'));
        expect(deleteFallback, contains('await repo.deleteByClientId'));
      },
    );

    test('day view drag edits repeating events through scope control', () {
      final movePath = _sourceBetween(
        calendarPage,
        'Future<void> _moveEventInDayView',
        'final repo = UserEventsRepo',
      );

      expect(movePath, contains('_showRepeatingEventScopeSheet'));
      expect(movePath, contains('_applyRepeatingNoteEditScope'));
      expect(movePath, contains('if (scope == null) return;'));
    });
  });
}

String _sourceBetween(String source, String startNeedle, String endNeedle) {
  final start = source.indexOf(startNeedle);
  expect(start, isNonNegative, reason: 'Missing start needle: $startNeedle');
  final end = source.indexOf(endNeedle, start + startNeedle.length);
  expect(end, isNonNegative, reason: 'Missing end needle: $endNeedle');
  return source.substring(start, end);
}
