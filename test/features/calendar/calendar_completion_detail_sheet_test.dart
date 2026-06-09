import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_badge_style.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/calendar_completion.dart';
import 'package:mobile/features/calendar/calendar_reflection_context.dart';
import 'package:mobile/features/journal/journal_badge_utils.dart';
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
      expect(main, contains('reflectionContext: widget.reflectionContext'));
      expect(main, isNot(contains('buildJournalPrefillText')));

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
        reflectionPrompt: 'What did this help me see?',
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
      expect(decoded.reflectionPrompt, 'What did this help me see?');

      final placeholder = context.buildJournalPlaceholderText();
      expect(placeholder, 'What did this help me see?');
      expect(placeholder, isNot(contains('Reflection on Practice')));
      expect(placeholder, isNot(contains('Date:')));
      expect(placeholder, isNot(contains('Source:')));
      expect(placeholder, isNot(contains('Source id:')));
      expect(placeholder, isNot(contains('Occurrence id:')));
      expect(placeholder, isNot(contains('Event id:')));
      expect(placeholder, isNot(contains('Completion:')));
      expect(JournalBadgeUtils.hasBadges(placeholder), isFalse);
    },
  );

  test('reflection prompt resolver keeps ghost text user-facing only', () {
    final prompt = resolveCalendarReflectionPrompt(
      sourceType: CompletionSourceType.userFlow,
      title: 'A Proof That Took 358 Years',
      detail:
          'Watch the linked video. Focus: Understand that some math problems are easy to state but hard to prove. Reflection: Why can a simple question take centuries to answer? After watching, say or write one sentence: "What did this video help me see?"',
    );

    expect(prompt, 'What did this video help me see?');

    final payloadPrompt = resolveCalendarReflectionPrompt(
      sourceType: CompletionSourceType.maatFlow,
      title: 'Day 29: Shared Order',
      behaviorPayload: {
        'reflection_guidance': {
          'reflectionIntent': 'What support did you notice today?',
        },
      },
    );
    expect(payloadPrompt, 'What support did you notice today?');

    final rejectedDebugPrompt = CalendarReflectionContext(
      sourceType: CompletionSourceType.userFlow,
      sourceId: 'cid:event-1',
      title: 'Practice',
      calendarDate: DateTime(2026, 6, 9),
      reflectionPrompt: 'Source id: cid:event-1',
    ).buildJournalPlaceholderText();
    expect(rejectedDebugPrompt, kCalendarReflectionSourcePrompt);
  });

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

  test('Add reflection opens without recording completion or continuity', () {
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
      final start = entry.value.indexOf(
        'Future<void> _openReflectionForTarget',
      );
      final end = entry.value.indexOf(
        'Future<CompletionStatus> _loadCalendarCompletionStatus',
        start,
      );
      expect(start, isNonNegative, reason: entry.key);
      expect(end, isNonNegative, reason: entry.key);
      final body = entry.value.substring(start, end);
      expect(body, contains('.load(identity)'), reason: entry.key);
      expect(body, contains('extra: reflectionContext'), reason: entry.key);
      expect(body, isNot(contains('.save(')), reason: entry.key);
      expect(body, isNot(contains('onCreateContinuity')), reason: entry.key);
      expect(body, isNot(contains('appendToJournal')), reason: entry.key);
      expect(body, isNot(contains('appendToToday')), reason: entry.key);
    }
  });

  test('observed and partial create continuity while skipped stays muted', () {
    expect(CompletionStatus.observed.createsJournalContinuity, isTrue);
    expect(CompletionStatus.partial.createsJournalContinuity, isTrue);
    expect(CompletionStatus.skipped.createsJournalContinuity, isFalse);
  });

  test('badge colors preserve source color except skipped muted state', () {
    const eventColor = Color(0xFF1AA7E8);

    expect(
      calendarCompletionBadgeColor(CompletionStatus.observed, eventColor),
      eventColor,
    );
    expect(
      calendarCompletionBadgeColor(CompletionStatus.partial, eventColor),
      eventColor,
    );
    expect(
      calendarCompletionBadgeColor(CompletionStatus.skipped, eventColor),
      kCompletionSkippedBadgeColor,
    );
    expect(
      calendarCompletionBadgeColor(CompletionStatus.observed, eventColor),
      isNot(const Color(0xFF4CAF50)),
    );
    expect(
      calendarCompletionBadgeColor(CompletionStatus.partial, eventColor),
      isNot(const Color(0xFFFFC145)),
    );
  });

  test('badge fallback color is only used as the provided source fallback', () {
    const fallbackColor = Color(0xFF8FD7E8);

    expect(
      completionStatusBadgeColor(
        CompletionStatus.observed,
        fallback: fallbackColor,
      ),
      fallbackColor,
    );
    expect(
      completionStatusBadgeColor(
        CompletionStatus.partial,
        fallback: fallbackColor,
      ),
      fallbackColor,
    );
  });

  test('observed and partial badge tokens share identity and keep status', () {
    const sourceColor = Color(0xFF1AA7E8);
    final observed = buildCalendarCompletionBadgeToken(
      identity: 'cid:event-1',
      sourceType: CompletionSourceType.userFlow,
      completionStatus: CompletionStatus.observed,
      title: 'Practice',
      color: sourceColor,
    );
    final partial = buildCalendarCompletionBadgeToken(
      identity: 'cid:event-1',
      sourceType: CompletionSourceType.userFlow,
      completionStatus: CompletionStatus.partial,
      title: 'Practice',
      color: sourceColor,
    );

    final observedToken = EventBadgeToken.parse(observed);
    final partialToken = EventBadgeToken.parse(partial);

    expect(observedToken!.id, partialToken!.id);
    expect(observedToken.completionStatus, CompletionStatus.observed);
    expect(observedToken.color, sourceColor);
    expect(partialToken.completionStatus, CompletionStatus.partial);
    expect(partialToken.color, sourceColor);
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
