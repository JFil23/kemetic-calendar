import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/calendar_completion.dart';
import 'package:mobile/features/calendar/calendar_reflection_context.dart';
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

  test(
    'detail top action is Add reflection while End Flow stays overflow-only',
    () {
      final sources = {
        'day_view.dart': File(
          'lib/features/calendar/day_view.dart',
        ).readAsStringSync(),
        'calendar_grid_widgets.dart': File(
          'lib/features/calendar/calendar_grid_widgets.dart',
        ).readAsStringSync(),
        'landscape_month_view.dart': File(
          'lib/features/calendar/landscape_month_view.dart',
        ).readAsStringSync(),
      };

      for (final entry in sources.entries) {
        final topStart = entry.value.indexOf('_buildEventDetailTopActionRow');
        final topEnd = entry.value.indexOf(
          '_buildEventDetailPrimaryAction',
          topStart,
        );
        expect(topStart, isNonNegative, reason: entry.key);
        expect(topEnd, isNonNegative, reason: entry.key);
        final topRow = entry.value.substring(topStart, topEnd);
        expect(topRow, contains('_buildAddReflectionButton('));
        expect(entry.value, contains("label: const Text('Add reflection')"));
        expect(topRow, isNot(contains("label: const Text('End Flow')")));
        expect(entry.value, contains("value: 'end_flow'"));
      }
    },
  );

  test(
    'reflection route context targets the real journal route with source data',
    () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains("path: '/journal'"));
      expect(main, contains('extra is CalendarReflectionContext'));
      expect(main, contains('child: JournalRoutePage(reflectionContext'));
      expect(main, contains('await _controller.loadDate'));
      expect(main, contains('buildJournalPrefillText'));

      final context = CalendarReflectionContext(
        sourceType: CompletionSourceType.userFlow,
        sourceId: 'cid:event-1',
        title: 'Practice',
        calendarDate: DateTime(2026, 6, 9),
        occurrenceId: 'occ-1',
        eventId: 'event-1',
        flowId: 7,
        start: DateTime(2026, 6, 9, 12),
        end: DateTime(2026, 6, 9, 13),
        color: const Color(0xFF64B5F6),
        completionStatus: CompletionStatus.partial,
      );

      expect(context.journalRouteLocation, '/journal');
      final decoded = CalendarReflectionContext.fromQueryParameters(
        context.toQueryParameters(),
      );
      expect(decoded, isNotNull);
      expect(decoded!.sourceType, CompletionSourceType.userFlow);
      expect(decoded.sourceId, 'cid:event-1');
      expect(decoded.occurrenceId, 'occ-1');
      expect(decoded.eventId, 'event-1');
      expect(decoded.flowId, 7);
      expect(decoded.completionStatus, CompletionStatus.partial);

      final prefill = context.buildJournalPrefillText();
      expect(prefill, contains('Reflection on Practice'));
      expect(prefill, contains('sourceType=user_flow'));
      expect(prefill, contains('reflectionStatus=user_written'));
      expect(prefill, contains('completionStatus=partial'));
    },
  );

  test('Add reflection uses one-shot route extra, not durable query state', () {
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
      expect(source, contains('extra: reflectionContext'));
      expect(source, isNot(contains("go('/journal?")));
      expect(source, isNot(contains('go("/journal?')));
    }
  });

  test('observed and partial create continuity while skipped stays muted', () {
    expect(CompletionStatus.observed.createsJournalContinuity, isTrue);
    expect(CompletionStatus.partial.createsJournalContinuity, isTrue);
    expect(CompletionStatus.skipped.createsJournalContinuity, isFalse);
  });

  test('badge colors use completed partial and muted skipped semantics', () {
    const eventColor = Color(0xFFFFC145);

    expect(
      calendarCompletionBadgeColor(CompletionStatus.observed, eventColor),
      const Color(0xFF4CAF50),
    );
    expect(
      calendarCompletionBadgeColor(CompletionStatus.partial, eventColor),
      const Color(0xFF64B5F6),
    );
    expect(
      calendarCompletionBadgeColor(CompletionStatus.skipped, eventColor),
      Colors.white38,
    );
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
