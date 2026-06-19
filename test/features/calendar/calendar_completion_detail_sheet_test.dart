import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_badge_style.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/calendar_completion.dart';
import 'package:mobile/features/calendar/calendar_reflection_context.dart';
import 'package:mobile/features/journal/journal_badge_utils.dart';
import 'package:mobile/features/journal/journal_event_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      final landscape = File(
        'lib/features/calendar/landscape_month_view.dart',
      ).readAsStringSync();

      expect(dayView, contains('class _MaatFlowCompletionPanel'));
      expect(dayView, contains('CalendarCompletionPicker('));
      expect(dayView, contains('CalendarEventCompletionPanel('));
      expect(monthGrid, contains('CalendarEventCompletionPanel('));
      expect(landscape, contains('CalendarEventCompletionPanel('));

      expect(dayView, contains('CompletionSourceType.maatFlow'));
      expect(dayView, contains('CompletionSourceType.userFlow'));
      expect(dayView, contains('CompletionSourceType.note'));
      expect(dayView, contains('CompletionSourceType.reminder'));
    },
  );

  test(
    'Evening Threshold detail choices stay tappable and defer release writes',
    () {
      final dayView = File(
        'lib/features/calendar/day_view.dart',
      ).readAsStringSync();

      final statusButton = _sourceBetween(
        dayView,
        'Widget _statusButton',
        'Widget _buildEveningThresholdWitnessBlock',
      );
      expect(statusButton, isNot(contains('_eveningThresholdStatusDisabled')));
      expect(statusButton, contains('_beginEveningThresholdRelease()'));
      expect(statusButton, contains('onPressed: _saving || _loading'));
      expect(statusButton, isNot(contains('chosenReturn')));
      expect(statusButton, isNot(contains('landingStatus')));

      final beginRelease = _sourceBetween(
        dayView,
        'Future<void> _beginEveningThresholdRelease',
        'Future<bool> _applyEveningThresholdCompletion',
      );
      expect(beginRelease, isNot(contains('recordEveningThresholdDecision')));

      final applyCompletion = _sourceBetween(
        dayView,
        'Future<bool> _applyEveningThresholdCompletion',
        'Future<void> _record',
      );
      expect(applyCompletion, contains('carryForward('));
      expect(applyCompletion, contains('releaseWithNewCarry('));
    },
  );

  test('Ma’at custom completion choices trigger ritual feedback pulses', () {
    final dayView = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();

    final feedbackMapper = _sourceBetween(
      dayView,
      'CompletionStatus _completionFeedbackStatusForRawStatus',
      'String? _eveningThresholdPrerequisiteMessage',
    );
    expect(feedbackMapper, contains("case 'held':"));
    expect(feedbackMapper, contains("case 'carry_forward':"));
    expect(feedbackMapper, contains("case 'release':"));
    expect(feedbackMapper, contains("return CompletionStatus.observed;"));
    expect(feedbackMapper, contains("case 'working':"));
    expect(feedbackMapper, contains("case 'slipped':"));
    expect(feedbackMapper, contains("return CompletionStatus.partial;"));

    final record = _sourceBetween(
      dayView,
      'Future<void> _record(String status',
      'Future<void> _clear() async',
    );
    expect(
      record,
      contains(
        'final feedbackStatus = _completionFeedbackStatusForRawStatus(status);',
      ),
    );
    expect(
      record,
      contains('widget.onUserCompletionFeedback?.call(feedbackStatus);'),
    );
  });

  test(
    'Evening Threshold missing prerequisites use feedback, not disabling',
    () {
      final dayView = File(
        'lib/features/calendar/day_view.dart',
      ).readAsStringSync();

      final guard = _sourceBetween(
        dayView,
        'String? _eveningThresholdPrerequisiteMessage',
        'Future<void> _beginEveningThresholdRelease',
      );

      expect(
        guard,
        contains(
          'No carry was set this morning. The flow will resume tomorrow.',
        ),
      );
      expect(
        guard,
        contains('Land yesterday\\\'s carry before choosing what crosses.'),
      );
      expect(guard, contains('_showSheetFeedback('));
      expect(
        guard,
        contains('_showEveningThresholdPrerequisiteFeedbackIfBlocked()'),
      );
      expect(guard, contains('return false;'));

      final statusButton = _sourceBetween(
        dayView,
        'Widget _statusButton',
        'Widget _buildEveningThresholdWitnessBlock',
      );
      expect(
        statusButton,
        contains('_showEveningThresholdPrerequisiteFeedbackIfBlocked()'),
      );

      final feedback = _sourceBetween(
        dayView,
        'void _showSheetFeedback',
        'bool _hasText',
      );
      expect(feedback, contains('_sheetFeedbackMessage = message'));
      expect(feedback, contains('Overlay.maybeOf(context, rootOverlay: true)'));
      expect(feedback, contains('Positioned.fill('));
      expect(feedback, contains('overlay.insert(_sheetFeedbackOverlay!)'));
      expect(feedback, contains('ScaffoldMessenger.of(context)'));

      final contextWidgets = _sourceBetween(
        dayView,
        'List<Widget> _buildEveningThresholdContextWidgets',
        '@override\n  Widget build',
      );
      expect(contextWidgets, contains('_sheetFeedbackMessage != null'));
      expect(
        contextWidgets,
        contains(
          '_buildEveningThresholdFeedbackMessage(_sheetFeedbackMessage!)',
        ),
      );
    },
  );

  test('Evening Threshold carries intention forward until changed', () {
    final dayView = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();
    final orientationRepo = File(
      'lib/features/onboarding/daily_orientation_repo.dart',
    ).readAsStringSync();

    final loader = _sourceBetween(
      dayView,
      'Future<void> _loadEveningThresholdOrientationState',
      'Future<void> _load()',
    );
    expect(loader, contains('loadEffectiveCarry('));
    expect(loader, isNot(contains('repo.load(')));

    expect(
      orientationRepo,
      contains('Future<DailyOrientationEntry?> loadEffectiveCarry'),
    );
    expect(orientationRepo, contains('_writeCurrentCarryLocal('));
    expect(orientationRepo, contains('_readCurrentCarryLocal('));
    expect(orientationRepo, contains('_loadMostRecentCarry('));
  });

  test('Evening Threshold orientation tables are migration-backed', () {
    final migrations = Directory('../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.sql'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(
      migrations,
      contains('create table if not exists public.daily_orientation'),
    );
    expect(
      migrations,
      contains('create table if not exists public.evening_threshold_decisions'),
    );
    expect(migrations, contains('daily_orientation_user_chosen_return_idx'));
    expect(migrations, contains('where chosen_return is not null'));
    for (final column in [
      'kemetic_day_key',
      'entry_state',
      'chosen_return',
      'source',
      'set_at',
      'landing_status',
      'landed_at',
      'carryover_choice',
      'evening_reflection_status',
      'badge_label',
      'status',
      'completed_at',
      'new_carry_text',
    ]) {
      expect(migrations, contains(column), reason: column);
    }
    expect(migrations, contains('primary key (user_id, local_date)'));
    expect(migrations, contains('primary key (user_id, decision_date)'));
    expect(migrations, contains('auth.uid() = user_id'));
    expect(migrations, contains("decision in ('carried', 'released')"));
    expect(
      migrations,
      contains("landing_status in ('held', 'slipped', 'working_on_it')"),
    );
  });

  test('Evening Threshold persistence is remote-first and failure-safe', () {
    final dayView = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();
    final orientationRepo = File(
      'lib/features/onboarding/daily_orientation_repo.dart',
    ).readAsStringSync();

    final record = _sourceBetween(
      dayView,
      'Future<void> _record(String status',
      'Future<void> _clear',
    );
    expect(record.indexOf('try {'), isNonNegative);
    expect(record.indexOf('_applyEveningThresholdCompletion('), isNonNegative);
    expect(
      record.indexOf('try {'),
      lessThan(record.indexOf('_applyEveningThresholdCompletion(')),
    );
    expect(record, contains('Could not record this sitting.'));
    final failureStart = record.indexOf('    } catch (_) {');
    expect(failureStart, isNonNegative);
    final failureBlock = record.substring(failureStart);
    expect(failureBlock, contains('setState(() => _saving = false)'));
    expect(
      failureBlock,
      isNot(contains('_eveningThresholdReleasePending = false')),
    );

    final setCarry = _sourceBetween(
      orientationRepo,
      'Future<void> setCarry',
      'Future<void> recordLanding',
    );
    expect(
      setCarry.indexOf('await _upsertRemote(payload)'),
      lessThan(setCarry.indexOf('await _writeLocal')),
    );
    expect(
      setCarry.indexOf('await _writeLocal'),
      lessThan(setCarry.indexOf('await _writeCurrentCarryLocal')),
    );

    final carryForward = _sourceBetween(
      orientationRepo,
      'Future<void> carryForward',
      'Future<void> releaseWithNewCarry',
    );
    expect(carryForward, contains('_persistLocalAndRemote('));
    expect(carryForward, contains("'carryover_choice': 'carry_it_forward'"));
    expect(
      carryForward.indexOf('_persistLocalAndRemote('),
      lessThan(carryForward.indexOf('recordEveningThresholdDecision(')),
    );

    final release = _sourceBetween(
      orientationRepo,
      'Future<void> releaseWithNewCarry',
      'Future<void> recordEveningThresholdDecision',
    );
    expect(
      release.indexOf('await setCarry('),
      lessThan(release.indexOf('await recordEveningThresholdDecision(')),
    );
    expect(release, contains("decision: 'released'"));

    final decision = _sourceBetween(
      orientationRepo,
      'Future<void> recordEveningThresholdDecision',
      'Future<void> complete',
    );
    expect(
      decision.indexOf(".from('evening_threshold_decisions')"),
      lessThan(decision.indexOf('await _writeDecisionLocal(payload)')),
    );
    expect(decision, contains('throw DailyOrientationPersistenceException'));

    final upsert = _sourceBetween(
      orientationRepo,
      'Future<void> _upsertRemote',
      'static String _dateOnlyIso',
    );
    expect(upsert, contains('throw DailyOrientationPersistenceException'));
  });

  test(
    'all event detail sheets share the Day View completion behavior contract',
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
        final source = entry.value;
        final firstPanel = source.indexOf('CalendarEventCompletionPanel(');
        expect(firstPanel, isNonNegative, reason: entry.key);
        final sheetStart = source.lastIndexOf(
          'Widget _buildEventDetailSheetPage',
          firstPanel,
        );
        final sheetEnd = source.indexOf(
          'Widget _buildEventDetailTopActionRow',
          firstPanel,
        );
        expect(sheetStart, isNonNegative, reason: entry.key);
        expect(sheetEnd, isNonNegative, reason: entry.key);
        final sheet = source.substring(sheetStart, sheetEnd);

        expect(sheet, contains('onClearStatus:'), reason: entry.key);
        expect(sheet, contains('_clearCalendarCompletion('), reason: entry.key);
        expect(sheet, contains('onCreateContinuity:'), reason: entry.key);
        expect(sheet, contains('triggerHaptic:'), reason: entry.key);
        expect(sheet, contains('onUserCompletionFeedback:'), reason: entry.key);
        expect(
          sheet,
          contains('playDayViewRitualCompletionFeedback('),
          reason: entry.key,
        );
        expect(sheet, contains('reloadSignal:'), reason: entry.key);
        expect(
          sheet,
          contains('DayViewRitualCompletionFeedbackCard'),
          reason: entry.key,
        );
      }

      for (final entry in sources.entries.where(
        (entry) => entry.key != 'day_view.dart',
      )) {
        expect(
          entry.value,
          contains('buildDayViewMaatFlowCompletionPanel('),
          reason: entry.key,
        );
        expect(
          entry.value,
          contains('hasDayViewMaatFlowCompletionContext(event, flow)'),
          reason: entry.key,
        );
      }
    },
  );

  test(
    'month and landscape detail sheets wire clear persistence and badge removal',
    () {
      final sources = {
        'calendar_page.dart': File(
          'lib/features/calendar/calendar_page.dart',
        ).readAsStringSync(),
        'calendar_grid_widgets.dart': File(
          'lib/features/calendar/calendar_grid_widgets.dart',
        ).readAsStringSync(),
        'landscape_month_view.dart': File(
          'lib/features/calendar/landscape_month_view.dart',
        ).readAsStringSync(),
      };

      expect(
        sources['calendar_page.dart']!,
        contains('onUnrecordCompletion: _unrecordEventCompletion'),
      );
      expect(
        sources['calendar_page.dart']!,
        contains('await _journalController.removeBadge(badgeId);'),
      );
      expect(
        sources['calendar_grid_widgets.dart']!,
        contains('onUnrecordCompletion: state?._unrecordEventCompletion'),
      );
      for (final entry in sources.entries.where(
        (entry) => entry.key != 'calendar_page.dart',
      )) {
        expect(entry.value, contains('_removeCompletionContinuity('));
        expect(entry.value, contains('widget.onRemoveCompletionBadge'));
        expect(entry.value, contains('calendarCompletionBadgeId('));
        expect(entry.value, contains('await _removeCompletionContinuity('));
      }
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

  test('End Flow reports success, failure, and not-handled distinctly', () {
    final calendarPage = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();

    expect(
      calendarPage,
      contains('enum EndFlowActionResult { success, failed, notHandled }'),
    );

    final staticHandler = _sourceBetween(
      calendarPage,
      'static Future<EndFlowActionResult> endFlowFromEventTarget',
      'static Future<bool> makeTodoFromEventTarget',
    );
    expect(staticHandler, contains('return EndFlowActionResult.notHandled;'));
    expect(staticHandler, contains('return state._endFlowFromEventTarget'));

    final targetHandler = _sourceBetween(
      calendarPage,
      'Future<EndFlowActionResult> _endFlowFromEventTarget',
      'Future<bool> _makeTodoFromEventTarget',
    );
    expect(targetHandler, contains('return EndFlowActionResult.notHandled;'));
    expect(targetHandler, contains('return _endFlow(flowId);'));
    expect(targetHandler, isNot(contains('return true;')));

    final endFlowHandler = _sourceBetween(
      calendarPage,
      'Future<EndFlowActionResult> _endFlow(',
      '//// === END END FLOW ===',
    );
    expect(endFlowHandler, contains('return EndFlowActionResult.failed;'));
    expect(endFlowHandler, contains('return EndFlowActionResult.success;'));
    expect(endFlowHandler, contains("Text('Flow ended.')"));
  });

  test('End Flow detail sheets await success before closing', () {
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
      final handler = _sourceBetween(
        entry.value,
        "if (value == 'end_flow') {",
        "} else if (value == 'end_reminder')",
      );
      final awaitIndex = handler.indexOf(
        'await CalendarPage.endFlowFromEventTarget(target)',
      );
      final popIndex = handler.indexOf('Navigator.pop(sheetContext)');

      expect(awaitIndex, isNonNegative, reason: entry.key);
      expect(popIndex, isNonNegative, reason: entry.key);
      expect(awaitIndex, lessThan(popIndex), reason: entry.key);
      expect(
        handler,
        contains('result == EndFlowActionResult.success'),
        reason: entry.key,
      );
      expect(
        handler,
        contains('result == EndFlowActionResult.notHandled'),
        reason: entry.key,
      );
      expect(handler, contains('_beginEndFlowAction'), reason: entry.key);
      expect(handler, contains('_finishEndFlowAction'), reason: entry.key);
      expect(handler, isNot(contains('routedThroughCalendarPage')));
    }
  });

  test('Day detail sheet keeps failed End Flow feedback inside the sheet', () {
    final dayView = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();
    final handler = _sourceBetween(
      dayView,
      "if (value == 'end_flow') {",
      "} else if (value == 'end_reminder')",
    );

    expect(handler, contains('result == EndFlowActionResult.failed'));
    expect(handler, contains('onEndFlowErrorChanged('));
    expect(dayView, contains("'Could not end this flow right now.\\n'"));
    expect(dayView, contains("'Check your connection and try again.'"));
    expect(dayView, contains('_buildEventDetailInlineError('));
    expect(dayView, contains('ValueListenableBuilder<String?>'));
  });

  test('Month-grid detail sheet keeps failed End Flow feedback inside the sheet', () {
    final monthGrid = File(
      'lib/features/calendar/calendar_grid_widgets.dart',
    ).readAsStringSync();
    final handler = _sourceBetween(
      monthGrid,
      "if (value == 'end_flow') {",
      "} else if (value == 'end_reminder')",
    );
    final failedBranch = _sourceBetween(
      handler,
      'result == EndFlowActionResult.failed',
      'result == EndFlowActionResult.notHandled',
    );

    expect(handler, contains('result == EndFlowActionResult.failed'));
    expect(handler, contains('_setEndFlowError('));
    expect(monthGrid, contains("'Could not end this flow right now.\\n'"));
    expect(monthGrid, contains("'Check your connection and try again.'"));
    expect(monthGrid, contains('_buildEventDetailInlineError('));
    expect(monthGrid, contains('String? _endFlowError;'));
    expect(monthGrid, contains('AnimatedSize('));
    expect(failedBranch, isNot(contains('Navigator.pop(sheetContext);')));
  });

  test('Landscape detail sheet keeps failed End Flow feedback inside the sheet', () {
    final landscape = File(
      'lib/features/calendar/landscape_month_view.dart',
    ).readAsStringSync();
    final handler = _sourceBetween(
      landscape,
      "if (value == 'end_flow') {",
      "} else if (value == 'end_reminder')",
    );
    final failedBranch = _sourceBetween(
      handler,
      'result == EndFlowActionResult.failed',
      'result == EndFlowActionResult.notHandled',
    );

    expect(handler, contains('result == EndFlowActionResult.failed'));
    expect(handler, contains('onEndFlowErrorChanged('));
    expect(landscape, contains("'Could not end this flow right now.\\n'"));
    expect(landscape, contains("'Check your connection and try again.'"));
    expect(landscape, contains('_buildEventDetailInlineError('));
    expect(landscape, contains('ValueNotifier<String?>(null)'));
    expect(landscape, contains('ValueListenableBuilder<String?>'));
    expect(failedBranch, isNot(contains('Navigator.pop(sheetContext);')));
  });

  test('Day detail sheet guards late measurement callbacks after release', () {
    final dayView = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();
    final landscape = File(
      'lib/features/calendar/landscape_month_view.dart',
    ).readAsStringSync();
    final showDetail = _sourceBetween(
      dayView,
      'void _showEventDetail(',
      'String _formatTimeRange',
    );
    final updateMeasuredHeight = _sourceBetween(
      showDetail,
      'void updateMeasuredHeight',
      'void resetSheetPageController',
    );
    final releaseSheet = _sourceBetween(
      showDetail,
      'void releaseSheet()',
      'try {',
    );

    expect(showDetail, contains('var sheetReleased = false;'));
    expect(
      updateMeasuredHeight,
      contains('if (sheetReleased || !mounted) return;'),
    );
    expect(releaseSheet, contains('if (sheetReleased) return;'));
    expect(releaseSheet, contains('sheetReleased = true;'));
    expect(showDetail, contains('endFlowError.dispose();'));

    final measureSize = _sourceBetween(
      dayView,
      'class _MeasureSizeRenderObject extends RenderProxyBox',
      '// Day View - 24-hour timeline',
    );
    expect(measureSize, contains('if (!attached) return;'));

    final landscapeShowDetail = _sourceBetween(
      landscape,
      'void _showEventDetail(',
      'String _formatTimeRange',
    );
    final landscapeUpdateMeasuredHeight = _sourceBetween(
      landscapeShowDetail,
      'void updateMeasuredHeight',
      'void resetSheetPageController',
    );
    final landscapeReleaseSheet = _sourceBetween(
      landscapeShowDetail,
      'void releaseSheet()',
      'try {',
    );
    final landscapeMeasureSize = _sourceBetween(
      landscape,
      'class _MeasureSizeRenderObject extends RenderProxyBox',
      'onChange(newSize);\n    });',
    );

    expect(landscapeShowDetail, contains('var sheetReleased = false;'));
    expect(
      landscapeUpdateMeasuredHeight,
      contains('if (sheetReleased || !mounted) return;'),
    );
    expect(landscapeReleaseSheet, contains('if (sheetReleased) return;'));
    expect(landscapeReleaseSheet, contains('sheetReleased = true;'));
    expect(landscapeMeasureSize, contains('if (!attached) return;'));
  });

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

  test('observed, partial, and skipped create completion continuity', () {
    expect(CompletionStatus.observed.createsJournalContinuity, isTrue);
    expect(CompletionStatus.partial.createsJournalContinuity, isTrue);
    expect(CompletionStatus.skipped.createsJournalContinuity, isTrue);
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

  testWidgets(
    'completion panel toggles selected status off and records replacements',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final recorded = <CompletionStatus>[];
      final continuity = <CompletionStatus>[];
      var clearCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarEventCompletionPanel(
              identity: 'cid:event-1',
              sourceType: CompletionSourceType.userFlow,
              loadStatus: () async => CompletionStatus.none,
              onRecordStatus: (status) async => recorded.add(status),
              onClearStatus: () async => clearCount += 1,
              onCreateContinuity: (status) async => continuity.add(status),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Observed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Observed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Observed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Partly'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skipped'));
      await tester.pumpAndSettle();

      expect(recorded, <CompletionStatus>[
        CompletionStatus.observed,
        CompletionStatus.observed,
        CompletionStatus.partial,
        CompletionStatus.skipped,
      ]);
      expect(clearCount, 1);
      expect(continuity, <CompletionStatus>[
        CompletionStatus.observed,
        CompletionStatus.observed,
        CompletionStatus.partial,
        CompletionStatus.skipped,
      ]);
    },
  );

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

  test('event detail overlay writes are revisioned and serialized', () {
    final calendarPage = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();

    expect(calendarPage, contains('_calendarEventDetailOverlayWriteQueue'));
    expect(calendarPage, contains('_calendarEventDetailOverlayRevision'));
    expect(
      calendarPage,
      contains('revision != _calendarEventDetailOverlayRevision'),
    );
    expect(calendarPage, contains('_sameEventDetailRestorationState'));
    expect(calendarPage, contains('_enqueueCalendarEventDetailOverlayWrite'));
    expect(
      calendarPage,
      contains('if (_preserveEventDetailOverlayForOrientationHandoff)'),
    );
  });

  test('Ma’at process-local joined ledger is scoped to active auth user', () {
    final calendarPage = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();

    expect(calendarPage, contains('_rememberedJoinedMaatUserScope'));
    expect(
      calendarPage,
      contains('Supabase.instance.client.auth.currentUser?.id.trim()'),
    );
    expect(calendarPage, contains('_currentRememberedJoinedMaatUserScope'));
    expect(calendarPage, contains('_clearRememberedJoinedMaatFlowTemplates'));
    expect(calendarPage, contains('if (scope == null)'));
    expect(calendarPage, contains('rememberedScope != scope'));
  });

  test('deleting a flow clears stale Ma’at joined filing state', () {
    final calendarPage = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final deleteFlow = _sourceBetween(
      calendarPage,
      'void _deleteFlow(int flowId) {',
      'String _formatTimeOfDay(TimeOfDay t) {',
    );

    expect(
      deleteFlow,
      contains('CalendarPage._forgetRememberedJoinedMaatFlow(flowId);'),
    );
    expect(deleteFlow, contains('_myFlowsFilingSnapshotCache = null;'));
    expect(deleteFlow, contains('_flowsRepo.clearMyFiledFlowsCache()'));
  });
}

String _sourceBetween(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  expect(start, isNonNegative, reason: 'missing start marker: $startMarker');
  final end = source.indexOf(endMarker, start + startMarker.length);
  expect(end, isNonNegative, reason: 'missing end marker: $endMarker');
  return source.substring(start, end);
}
