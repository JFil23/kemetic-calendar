import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Ma_at flow hub and list use the readable Ma_at Flows label', () {
    final modelsSource = File(
      'lib/features/calendar/calendar_flow_studio_models.dart',
    ).readAsStringSync();
    final hubSource = File(
      'lib/features/calendar/calendar_flow_pages.dart',
    ).readAsStringSync();
    final calendarSource = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();

    expect(modelsSource, contains('const String _kMaatFlowsDisplayTitle'));
    expect(modelsSource, contains('"Ma\'at Flows"'));
    expect(hubSource, contains('title: _kMaatFlowsDisplayTitle'));
    expect(calendarSource, contains('title: _kMaatFlowsDisplayTitle'));
  });

  test('Ma_at flow added state refreshes from flow filing data', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final listSource = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();

    expect(source, contains('_flowMatchesActiveMaatTemplate'));
    expect(source, contains("source: 'open_maat_flows'"));
    expect(source, contains('flowsRepo.refreshMyFiledFlows()'));
    expect(source, contains('isFlowScheduleOpenLocally'));
    expect(listSource, contains('class _MaatFlowsListPageWithSnapshot'));
  });

  test('Ma_at flow join focuses first hydrated calendar occurrence', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final helper = _sourceBetween(
      source,
      '_focusCalendarOnFirstUpcomingFlowEvent',
      '_Note? _firstFlowTargetNoteForDay',
    );
    final listJoin = _sourceBetween(
      source,
      'Widget _buildMaatFlowsListPage',
      'Widget _buildFlowStudioHubPage',
    );
    final routeReturn = _sourceBetween(
      source,
      "source: 'open_maat_flows'",
      'onCreateNew: () async',
    );

    expect(helper, contains('_firstUpcomingNoteForFlow(flowId)'));
    expect(
      helper,
      contains('_setView(firstEvent.ky, firstEvent.km, kd: firstEvent.kd)'),
    );
    expect(helper, contains('_centerMonth(firstEvent.ky, firstEvent.km)'));
    expect(
      listJoin,
      contains("await _loadFromDisk(source: 'maat_flow_imported')"),
    );
    expect(
      listJoin,
      contains('_focusCalendarOnFirstUpcomingFlowEvent(importedFlowId)'),
    );
    expect(
      listJoin.indexOf("await _loadFromDisk(source: 'maat_flow_imported')"),
      lessThan(
        listJoin.indexOf(
          '_focusCalendarOnFirstUpcomingFlowEvent(importedFlowId)',
        ),
      ),
    );
    expect(routeReturn, contains("source: 'maat_flow_imported_return'"));
    expect(
      routeReturn,
      contains('_focusCalendarOnFirstUpcomingFlowEvent(importedFlowId)'),
    );
  });

  test('Ma_at flow detail pages default to Kemetic date mode', () {
    final source = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();

    expect(source, contains('bool _useKemetic = true;'));
    expect(source, contains('void _toggleDateMode()'));
    expect(source, contains('Widget _buildDateModeTitle'));
    expect(source, contains("label: _useKemetic ? 'Show Gregorian dates'"));
    expect(source, contains('gradient: _useKemetic ? goldGloss : whiteGloss'));
  });

  test('Ma_at preview event cells expand inline with full details', () {
    final source = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();

    expect(source, contains('Widget _buildExpandableFlowEventTile'));
    expect(source, contains('ExpansionTile'));
    expect(source, isNot(contains('_showFlowEventDetails')));
    expect(source, isNot(contains('DraggableScrollableSheet')));

    for (final branch in _previewInlineDetailBranches) {
      final tile = _sourceBetween(source, branch.start, branch.end);

      expect(
        tile,
        contains('_buildExpandableFlowEventTile'),
        reason: '${branch.name} event cells should expand inline.',
      );
      expect(
        tile,
        isNot(contains('showModalBottomSheet')),
        reason: '${branch.name} should not use modal detail sheets.',
      );
      expect(
        tile,
        contains(branch.detailFunction),
        reason: '${branch.name} should use its canonical detail text.',
      );
      expect(
        tile,
        isNot(contains('onTap: ()')),
        reason:
            '${branch.name} detail cells should use expansion, not tap handlers.',
      );
    }
  });

  test('Ma_at event detail builders omit source sections', () {
    for (final sourceFile in _maatEventDetailSourceFiles) {
      final source = File(sourceFile).readAsStringSync();

      expect(
        source,
        isNot(contains("'Source\\n")),
        reason: '$sourceFile should not build Source event-note sections.',
      );
      expect(
        source,
        isNot(contains('"Source\\n')),
        reason: '$sourceFile should not build Source event-note sections.',
      );
    }
  });

  test('sensitive Ma_at detail builders omit private-storage notes', () {
    for (final sourceFile in _sensitiveMaatEventDetailSourceFiles) {
      final source = File(sourceFile).readAsStringSync();

      expect(
        source,
        isNot(contains('Private note:')),
        reason: '$sourceFile should keep event details practice-focused.',
      );
    }
  });

  test(
    'Ma_at flow date references route through the shared date formatter',
    () {
      final source = File(
        'lib/features/calendar/calendar_maat_flows.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('String _dateLabel(BuildContext context, DateTime date)'),
      );
      expect(source, contains('_startDateButtonLabel(context, selectedStart)'));
      expect(
        source,
        contains(
          r"'Start: ${_dateLabel(context, selectedStart)} at $firstTime'",
        ),
      );
      expect(
        source,
        contains(
          '_buildStartDateRow(\n'
          '              context,\n'
          '              selectedStart,',
        ),
      );
      expect(
        source,
        isNot(contains(r'Start: ${_fmtGregorian(selectedStart)}')),
      );
      expect(source, isNot(contains(r'First dawn: ${_fmtGregorian')));
      expect(source, isNot(contains('CupertinoSegmentedControl<bool>')));
    },
  );

  test('Ma_at enrollment preview scaffolds use safe window resolvers', () {
    final source = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();

    for (final branch in _previewEnrollmentBranches) {
      final scaffold = _sourceBetween(
        source,
        branch.scaffoldStart,
        branch.scaffoldEnd,
      );

      expect(
        scaffold,
        contains(branch.resolverCall),
        reason: '${branch.name} preview must use its safe resolver.',
      );
      expect(
        scaffold,
        contains('_buildEnrollmentUnavailableScaffold'),
        reason:
            '${branch.name} preview must render an unavailable state on null.',
      );
      expect(
        scaffold,
        isNot(contains('NextEnrollmentWindow(')),
        reason:
            '${branch.name} scaffold must not call throwing next-window APIs directly during build.',
      );
      expect(
        scaffold,
        isNot(contains('_tryEnrollmentWindow(')),
        reason:
            '${branch.name} scaffold should keep try/catch inside its resolver.',
      );
    }
  });

  test('Ma_at enrollment preview resolvers catch throwing window APIs', () {
    final source = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();

    expect(source, contains('T? _tryEnrollmentWindow<T>'));
    expect(source, contains(r'timezone=${_previewTrackSkyTimeZone.key}'));
    expect(source, contains('selectedDate='));
    expect(source, contains(r'now=${DateTime.now().toIso8601String()}'));
    expect(source, contains('_calendarDebugPrint'));

    for (final branch in _previewEnrollmentBranches) {
      final resolver = _sourceBetween(
        source,
        branch.resolverStart,
        branch.resolverEnd,
      );

      expect(
        resolver,
        contains('_tryEnrollmentWindow'),
        reason: '${branch.name} resolver must catch enrollment failures.',
      );
      expect(
        resolver,
        contains(branch.throwingApi),
        reason:
            '${branch.name} resolver should keep existing next-window behavior inside the safe boundary.',
      );
    }
  });

  test('FlowJoinService default enrollment resolvers use safe wrappers', () {
    final source = File(
      'lib/features/calendar/flow_join_service.dart',
    ).readAsStringSync();

    for (final branch in _flowJoinSafeDefaultEnrollmentResolvers) {
      final resolver = _sourceBetween(
        source,
        branch.resolverStart,
        branch.resolverEnd,
      );

      expect(
        resolver,
        contains(branch.safeResolver),
        reason:
            '${branch.name} default resolver must convert enrollment failures to null.',
      );
      expect(
        resolver,
        isNot(contains(branch.throwingNextApi)),
        reason:
            '${branch.name} default resolver must not call the throwing next-window API directly.',
      );
      expect(
        resolver,
        isNot(contains(branch.throwingSelectedApi)),
        reason:
            '${branch.name} default resolver must not call the throwing selected-date API directly.',
      );
    }
  });

  test('headless flow studio files delivery and invalidates calendar data', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final headlessPersist = _sourceBetween(
      source,
      'static Future<int?> _persistFlowStudioResultHeadless',
      'static Future<int?> importFlowFromShare',
    );

    expect(headlessPersist, contains('EventFilingService'));
    expect(headlessPersist, contains('_fileHeadlessEventDelivery'));
    expect(headlessPersist, contains('_publishHeadlessCalendarInvalidation'));
    expect(
      headlessPersist,
      contains('CalendarInvalidationReason.flowStudioPersisted'),
    );
  });

  test('headless delivery helper logs delivery failures without throwing', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final helper = _sourceBetween(
      source,
      'static Future<void> _fileHeadlessEventDelivery',
      'static void _publishHeadlessCalendarInvalidation',
    );

    expect(helper, contains('await eventFiling.fileDelivery'));
    expect(helper, contains('catch (e, st)'));
    expect(helper, contains('delivery filing failed'));
    expect(helper, contains('_calendarDebugPrint'));
  });

  test('headless invalidation helper publishes one immutable event', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final helper = _sourceBetween(
      source,
      'static void _publishHeadlessCalendarInvalidation',
      'static Future<int> _addMaatFlowInstanceHeadless',
    );

    expect(helper, contains('CalendarInvalidationBus.instance.publish'));
    expect(helper, contains('CalendarInvalidated'));
    expect(helper, contains('List.unmodifiable(clientEventIds)'));
  });

  test('calendar invalidation consumer coalesces reloads', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final initState = _sourceBetween(
      source,
      'void initState()',
      'void _handleCalendarInvalidated',
    );
    final handler = _sourceBetween(
      source,
      'void _handleCalendarInvalidated',
      'void _schedulePendingCalendarInvalidationReload',
    );
    final pendingScheduler = _sourceBetween(
      source,
      'void _schedulePendingCalendarInvalidationReload',
      'void _scheduleCalendarInvalidationReload',
    );
    final scheduler = _sourceBetween(
      source,
      'void _scheduleCalendarInvalidationReload',
      'void _flushCalendarInvalidationReload',
    );
    final flush = _sourceBetween(
      source,
      'void _flushCalendarInvalidationReload',
      'void _scheduleDaySheetResumeRestore',
    );
    final dispose = _sourceBetween(
      source,
      'void dispose()',
      '// ✅ Called when we pop back to Calendar from another page',
    );

    expect(initState, contains('CalendarInvalidationBus.instance.stream'));
    expect(initState, contains('_schedulePendingCalendarInvalidationReload'));
    expect(handler, contains('_schedulePendingCalendarInvalidationReload'));
    expect(handler, isNot(contains('_loadFromDisk(')));
    expect(
      pendingScheduler,
      contains('CalendarInvalidationBus.instance.peekPendingAfter'),
    );
    expect(
      pendingScheduler,
      contains('_calendarInvalidationScheduledRevision'),
    );
    expect(pendingScheduler, contains('revision: pending.revision'));
    expect(scheduler, contains('_calendarInvalidationReloadPending = true'));
    expect(scheduler, contains('_calendarInvalidationReloadInFlight'));
    expect(
      scheduler,
      contains('_calendarInvalidationReloadDebounce?.cancel()'),
    );
    expect(scheduler, contains('Timer('));
    expect(scheduler, contains('_calendarInvalidationReloadRevision'));
    expect(flush, contains('_calendarInvalidationReloadInFlight = true'));
    expect(flush, contains('_calendarInvalidationReloadPending = false'));
    expect(flush, contains('_isLoadingFromDisk'));
    expect(flush, contains('_loadFromDisk('));
    expect(flush, contains('CalendarInvalidationBus.instance.markConsumed'));
    expect(flush, contains('preserveViewport: true'));
    expect(flush, contains('whenComplete'));
    expect(flush, contains('_flushCalendarInvalidationReload();'));
    expect(dispose, contains('_calendarInvalidationReloadDebounce?.cancel()'));
  });

  test('headless Moon Return delegates to FlowJoinService', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final moonReturnHeadless = _sourceBetween(
      source,
      'if (template.kind == _MaatFlowTemplateKind.moonReturn)',
      'if (template.kind == _MaatFlowTemplateKind.theWag)',
    );

    expect(moonReturnHeadless, contains('FlowJoinService'));
    expect(moonReturnHeadless, contains('joinMoonReturnHeadless'));
    expect(moonReturnHeadless, contains('templateKey: template.key'));
    expect(moonReturnHeadless, contains('templateTitle: template.title'));
    expect(moonReturnHeadless, contains('alertOffsetMinutes: 0'));
    expect(moonReturnHeadless, contains('flowIdOrNegativeOne'));
  });

  test('headless Wag delegates to FlowJoinService', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final wagHeadless = _sourceBetween(
      source,
      'if (template.kind == _MaatFlowTemplateKind.theWag)',
      'if (template.kind == _MaatFlowTemplateKind.daysOutsideTheYear)',
    );

    expect(wagHeadless, contains('FlowJoinService'));
    expect(wagHeadless, contains('joinWagHeadless'));
    expect(wagHeadless, contains('templateKey: template.key'));
    expect(wagHeadless, contains('templateTitle: template.title'));
    expect(wagHeadless, contains('alertOffsetMinutes: 0'));
    expect(wagHeadless, contains('flowIdOrNegativeOne'));
  });

  test('headless Days Outside the Year delegates to FlowJoinService', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final daysOutsideHeadless = _sourceBetween(
      source,
      'if (template.kind == _MaatFlowTemplateKind.daysOutsideTheYear)',
      'if (template.kind == _MaatFlowTemplateKind.theOpenHand)',
    );

    expect(daysOutsideHeadless, contains('FlowJoinService'));
    expect(daysOutsideHeadless, contains('joinDaysOutsideYearHeadless'));
    expect(daysOutsideHeadless, contains('templateKey: template.key'));
    expect(daysOutsideHeadless, contains('templateTitle: template.title'));
    expect(daysOutsideHeadless, contains('alertOffsetMinutes: 0'));
    expect(daysOutsideHeadless, contains('flowIdOrNegativeOne'));
  });

  test('FlowJoinService Moon Return files delivery and invalidates once', () {
    final source = File(
      'lib/features/calendar/flow_join_service.dart',
    ).readAsStringSync();
    final moonReturnService = _sourceBetween(
      source,
      'Future<FlowJoinResult> joinMoonReturnHeadless',
      'Future<FlowJoinResult> joinWagHeadless',
    );

    expect(moonReturnService, contains('moon_return_join_headless'));
    expect(moonReturnService, contains('_fileHeadlessJoinDelivery'));
    expect(
      moonReturnService,
      contains('alertOffsetMinutes: alertOffsetMinutes'),
    );
    expect(_countOccurrences(moonReturnService, '_completeHeadlessJoin'), 1);
  });

  test('FlowJoinService Wag files delivery and invalidates once', () {
    final source = File(
      'lib/features/calendar/flow_join_service.dart',
    ).readAsStringSync();
    final wagService = _sourceBetween(
      source,
      'Future<FlowJoinResult> joinWagHeadless',
      'Future<FlowJoinResult> joinDaysOutsideYearHeadless',
    );

    expect(wagService, contains('wag_join_headless'));
    expect(wagService, contains('_fileHeadlessJoinDelivery'));
    expect(wagService, contains('alertOffsetMinutes: alertOffsetMinutes'));
    expect(_countOccurrences(wagService, '_completeHeadlessJoin'), 1);
  });

  test(
    'FlowJoinService Days Outside the Year files delivery and invalidates once',
    () {
      final source = File(
        'lib/features/calendar/flow_join_service.dart',
      ).readAsStringSync();
      final daysOutsideService = _sourceBetween(
        source,
        'Future<FlowJoinResult> joinDaysOutsideYearHeadless',
        'Future<FlowJoinResult> joinDecanWatchHeadless',
      );

      expect(daysOutsideService, contains('days_outside_year_join_headless'));
      expect(daysOutsideService, contains('_fileHeadlessJoinDelivery'));
      expect(
        daysOutsideService,
        contains('alertOffsetMinutes: alertOffsetMinutes'),
      );
      expect(_countOccurrences(daysOutsideService, '_completeHeadlessJoin'), 1);
    },
  );

  test('headless Decan Watch delegates to FlowJoinService', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final decanWatchHeadless = _sourceBetween(
      source,
      'if (template.kind == _MaatFlowTemplateKind.decanWatch)',
      'if (template.kind == _MaatFlowTemplateKind.dawnHouseRite)',
    );

    expect(decanWatchHeadless, contains('FlowJoinService'));
    expect(decanWatchHeadless, contains('joinDecanWatchHeadless'));
    expect(decanWatchHeadless, contains('templateKey: template.key'));
    expect(decanWatchHeadless, contains('templateTitle: template.title'));
    expect(decanWatchHeadless, contains('alertOffsetMinutes: 0'));
    expect(decanWatchHeadless, contains('flowIdOrNegativeOne'));
  });

  test('FlowJoinService Decan Watch files delivery and invalidates once', () {
    final source = File(
      'lib/features/calendar/flow_join_service.dart',
    ).readAsStringSync();
    final decanWatchService = _sourceBetween(
      source,
      'Future<FlowJoinResult> joinDecanWatchHeadless',
      'Future<FlowJoinResult> joinOpenHandHeadless',
    );

    expect(decanWatchService, contains('decan_watch_join_headless'));
    expect(decanWatchService, contains('_fileHeadlessJoinDelivery'));
    expect(
      decanWatchService,
      contains('alertOffsetMinutes: alertOffsetMinutes'),
    );
    expect(_countOccurrences(decanWatchService, '_completeHeadlessJoin'), 1);
  });

  test('headless Open Hand delegates to FlowJoinService', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final openHandHeadless = _sourceBetween(
      source,
      'if (template.kind == _MaatFlowTemplateKind.theOpenHand)',
      'if (template.kind == _MaatFlowTemplateKind.theDjed)',
    );

    expect(openHandHeadless, contains('FlowJoinService'));
    expect(openHandHeadless, contains('joinOpenHandHeadless'));
    expect(openHandHeadless, contains('templateKey: template.key'));
    expect(openHandHeadless, contains('templateTitle: template.title'));
    expect(openHandHeadless, contains('alertOffsetMinutes: 0'));
    expect(openHandHeadless, contains('flowIdOrNegativeOne'));
  });

  test('FlowJoinService Open Hand files delivery and invalidates once', () {
    final source = File(
      'lib/features/calendar/flow_join_service.dart',
    ).readAsStringSync();
    final openHandService = _sourceBetween(
      source,
      'Future<FlowJoinResult> joinOpenHandHeadless',
      'Future<FlowJoinResult> joinDjedHeadless',
    );

    expect(openHandService, contains('open_hand_join_headless'));
    expect(openHandService, contains('_fileHeadlessJoinDelivery'));
    expect(openHandService, contains('alertOffsetMinutes: alertOffsetMinutes'));
    expect(_countOccurrences(openHandService, '_completeHeadlessJoin'), 1);
  });

  test('headless Djed delegates to FlowJoinService', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final djedHeadless = _sourceBetween(
      source,
      'if (template.kind == _MaatFlowTemplateKind.theDjed)',
      'if (template.kind == _MaatFlowTemplateKind.readingHouse)',
    );

    expect(djedHeadless, contains('FlowJoinService'));
    expect(djedHeadless, contains('joinDjedHeadless'));
    expect(djedHeadless, contains('templateKey: template.key'));
    expect(djedHeadless, contains('templateTitle: template.title'));
    expect(djedHeadless, contains('alertOffsetMinutes: 0'));
    expect(djedHeadless, contains('flowIdOrNegativeOne'));
  });

  test('FlowJoinService Djed files delivery and invalidates once', () {
    final source = File(
      'lib/features/calendar/flow_join_service.dart',
    ).readAsStringSync();
    final djedService = _sourceBetween(
      source,
      'Future<FlowJoinResult> joinDjedHeadless',
      'Future<FlowJoinResult> joinMaatDecanFlowHeadless',
    );

    expect(djedService, contains('djed_join_headless'));
    expect(djedService, contains('_fileHeadlessJoinDelivery'));
    expect(djedService, contains('alertOffsetMinutes: alertOffsetMinutes'));
    expect(_countOccurrences(djedService, '_completeHeadlessJoin'), 1);
  });

  test('headless Reading House delegates to FlowJoinService', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final readingHouseHeadless = _sourceBetween(
      source,
      'if (template.kind == _MaatFlowTemplateKind.readingHouse)',
      'if (template.kind == _MaatFlowTemplateKind.maatDecan)',
    );

    expect(readingHouseHeadless, contains('FlowJoinService'));
    expect(readingHouseHeadless, contains('joinReadingHouseHeadless'));
    expect(readingHouseHeadless, contains('templateKey: template.key'));
    expect(readingHouseHeadless, contains('templateTitle: template.title'));
    expect(
      readingHouseHeadless,
      contains('alertOffsetMinutes: kEventFilingNoAlertMinutes'),
    );
    expect(readingHouseHeadless, contains('flowIdOrNegativeOne'));
  });

  test('FlowJoinService Reading House files delivery and invalidates once', () {
    final source = File(
      'lib/features/calendar/flow_join_service.dart',
    ).readAsStringSync();
    final readingHouseService = _sourceBetween(
      source,
      'Future<FlowJoinResult> joinReadingHouseHeadless',
      'Future<FlowJoinResult> joinKeptWordHeadless',
    );

    expect(readingHouseService, contains('reading_house_join_headless'));
    expect(readingHouseService, contains('_fileHeadlessJoinDelivery'));
    expect(
      readingHouseService,
      contains('alertOffsetMinutes: alertOffsetMinutes'),
    );
    expect(_countOccurrences(readingHouseService, '_completeHeadlessJoin'), 1);
  });

  test('headless Dawn House Rite delegates to FlowJoinService', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final dawnHouseRiteHeadless = _sourceBetween(
      source,
      'if (template.kind == _MaatFlowTemplateKind.dawnHouseRite)',
      'if (template.kind == _MaatFlowTemplateKind.eveningThreshold)',
    );

    expect(dawnHouseRiteHeadless, contains('FlowJoinService'));
    expect(dawnHouseRiteHeadless, contains('joinDawnHouseRiteHeadless'));
    expect(dawnHouseRiteHeadless, contains('templateKey: template.key'));
    expect(dawnHouseRiteHeadless, contains('templateTitle: template.title'));
    expect(
      dawnHouseRiteHeadless,
      contains('alertOffsetMinutes: kEventFilingNoAlertMinutes'),
    );
    expect(dawnHouseRiteHeadless, contains('flowIdOrNegativeOne'));
  });

  test(
    'FlowJoinService Dawn House Rite makes no-alert delivery explicit and invalidates once',
    () {
      final source = File(
        'lib/features/calendar/flow_join_service.dart',
      ).readAsStringSync();
      final dawnHouseRiteService = _sourceBetween(
        source,
        'Future<FlowJoinResult> joinDawnHouseRiteHeadless',
        'Future<FlowJoinResult> joinEveningThresholdRiteHeadless',
      );

      expect(dawnHouseRiteService, contains('dawn_house_rite_join_headless'));
      expect(
        dawnHouseRiteService,
        contains('alertOffsetMinutes != kEventFilingNoAlertMinutes'),
      );
      expect(dawnHouseRiteService, contains('_fileHeadlessJoinDelivery'));
      expect(
        dawnHouseRiteService,
        contains('alertOffsetMinutes: alertOffsetMinutes'),
      );
      expect(
        _countOccurrences(dawnHouseRiteService, '_completeHeadlessJoin'),
        1,
      );
    },
  );

  test('headless Evening Threshold delegates to FlowJoinService', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final eveningThresholdHeadless = _sourceBetween(
      source,
      'if (template.kind == _MaatFlowTemplateKind.eveningThreshold)',
      'if (template.kind == _MaatFlowTemplateKind.eveningThresholdRite)',
    );

    expect(eveningThresholdHeadless, contains('FlowJoinService'));
    expect(eveningThresholdHeadless, contains('joinEveningThresholdHeadless'));
    expect(eveningThresholdHeadless, contains('templateKey: template.key'));
    expect(eveningThresholdHeadless, contains('templateTitle: template.title'));
    expect(
      eveningThresholdHeadless,
      contains('initialCarryText: eveningThresholdInitialCarry'),
    );
    expect(eveningThresholdHeadless, contains('flowIdOrNegativeOne'));
  });

  test('headless Evening Threshold Rite delegates to FlowJoinService', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final eveningThresholdRiteHeadless = _sourceBetween(
      source,
      'if (template.kind == _MaatFlowTemplateKind.eveningThresholdRite)',
      'if (template.kind == _MaatFlowTemplateKind.theWeighing)',
    );

    expect(eveningThresholdRiteHeadless, contains('FlowJoinService'));
    expect(
      eveningThresholdRiteHeadless,
      contains('joinEveningThresholdRiteHeadless'),
    );
    expect(eveningThresholdRiteHeadless, contains('templateKey: template.key'));
    expect(
      eveningThresholdRiteHeadless,
      contains('templateTitle: template.title'),
    );
    expect(
      eveningThresholdRiteHeadless,
      contains('fallbackMinutesAfterMidnight: fallbackMinutes'),
    );
    expect(
      eveningThresholdRiteHeadless,
      contains('alertOffsetMinutes: kEventFilingNoAlertMinutes'),
    );
    expect(eveningThresholdRiteHeadless, contains('flowIdOrNegativeOne'));
  });

  test(
    'FlowJoinService Evening Threshold Rite makes no-alert delivery explicit and invalidates once',
    () {
      final source = File(
        'lib/features/calendar/flow_join_service.dart',
      ).readAsStringSync();
      final eveningThresholdRiteService = _sourceBetween(
        source,
        'Future<FlowJoinResult> joinEveningThresholdRiteHeadless',
        'Future<FlowJoinResult> joinEveningThresholdHeadless',
      );

      expect(
        eveningThresholdRiteService,
        contains('evening_threshold_rite_join_headless'),
      );
      expect(
        eveningThresholdRiteService,
        contains('alertOffsetMinutes != kEventFilingNoAlertMinutes'),
      );
      expect(
        eveningThresholdRiteService,
        contains('_fileHeadlessJoinDelivery'),
      );
      expect(
        eveningThresholdRiteService,
        contains('alertOffsetMinutes: alertOffsetMinutes'),
      );
      expect(
        _countOccurrences(eveningThresholdRiteService, '_completeHeadlessJoin'),
        1,
      );
    },
  );

  test('headless The Weighing delegates to FlowJoinService', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final theWeighingHeadless = _sourceBetween(
      source,
      'if (template.kind == _MaatFlowTemplateKind.theWeighing)',
      'if (template.kind == _MaatFlowTemplateKind.offeringTable)',
    );

    expect(theWeighingHeadless, contains('FlowJoinService'));
    expect(theWeighingHeadless, contains('joinTheWeighingHeadless'));
    expect(theWeighingHeadless, contains('templateKey: template.key'));
    expect(theWeighingHeadless, contains('templateTitle: template.title'));
    expect(theWeighingHeadless, contains('lens: theWeighingLens'));
    expect(
      theWeighingHeadless,
      contains('alertOffsetMinutes: kEventFilingNoAlertMinutes'),
    );
    expect(theWeighingHeadless, contains('flowIdOrNegativeOne'));
  });

  test(
    'FlowJoinService The Weighing makes no-alert delivery explicit and invalidates once',
    () {
      final source = File(
        'lib/features/calendar/flow_join_service.dart',
      ).readAsStringSync();
      final theWeighingService = _sourceBetween(
        source,
        'Future<FlowJoinResult> joinTheWeighingHeadless',
        'Future<FlowJoinResult> joinOfferingTableHeadless',
      );

      expect(theWeighingService, contains('the_weighing_join_headless'));
      expect(
        theWeighingService,
        contains('alertOffsetMinutes != kEventFilingNoAlertMinutes'),
      );
      expect(theWeighingService, contains('_fileHeadlessJoinDelivery'));
      expect(
        theWeighingService,
        contains('alertOffsetMinutes: alertOffsetMinutes'),
      );
      expect(_countOccurrences(theWeighingService, '_completeHeadlessJoin'), 1);
    },
  );

  test('headless Offering Table delegates to FlowJoinService', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final offeringTableHeadless = _sourceBetween(
      source,
      'if (template.kind == _MaatFlowTemplateKind.offeringTable)',
      'if (template.kind == _MaatFlowTemplateKind.theTending)',
    );

    expect(offeringTableHeadless, contains('FlowJoinService'));
    expect(offeringTableHeadless, contains('joinOfferingTableHeadless'));
    expect(offeringTableHeadless, contains('templateKey: template.key'));
    expect(offeringTableHeadless, contains('templateTitle: template.title'));
    expect(offeringTableHeadless, contains('lens: offeringTableLens'));
    expect(offeringTableHeadless, contains('noCupMode: offeringNoCupMode'));
    expect(offeringTableHeadless, contains('alertOffsetMinutes: 0'));
    expect(offeringTableHeadless, contains('flowIdOrNegativeOne'));
  });

  test(
    'FlowJoinService Offering Table files delivery and invalidates once',
    () {
      final source = File(
        'lib/features/calendar/flow_join_service.dart',
      ).readAsStringSync();
      final offeringTableService = _sourceBetween(
        source,
        'Future<FlowJoinResult> joinOfferingTableHeadless',
        'Future<FlowJoinResult> joinTheTendingHeadless',
      );

      expect(offeringTableService, contains('offering_table_join_headless'));
      expect(
        offeringTableService,
        contains('alertOffsetMinutes != kEventFilingNoAlertMinutes'),
      );
      expect(offeringTableService, contains('_fileHeadlessJoinDelivery'));
      expect(
        offeringTableService,
        contains('alertOffsetMinutes: alertOffsetMinutes'),
      );
      expect(
        _countOccurrences(offeringTableService, '_completeHeadlessJoin'),
        1,
      );
    },
  );

  test('headless The Tending delegates to FlowJoinService', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final theTendingHeadless = _sourceBetween(
      source,
      'if (template.kind == _MaatFlowTemplateKind.theTending)',
      'if (template.kind == _MaatFlowTemplateKind.keptWord)',
    );

    expect(theTendingHeadless, contains('FlowJoinService'));
    expect(theTendingHeadless, contains('joinTheTendingHeadless'));
    expect(theTendingHeadless, contains('templateKey: template.key'));
    expect(theTendingHeadless, contains('templateTitle: template.title'));
    expect(theTendingHeadless, contains('lens: theTendingLens'));
    expect(theTendingHeadless, contains('alertOffsetMinutes: 0'));
    expect(theTendingHeadless, contains('flowIdOrNegativeOne'));
  });

  test('FlowJoinService The Tending files delivery and invalidates once', () {
    final source = File(
      'lib/features/calendar/flow_join_service.dart',
    ).readAsStringSync();
    final theTendingService = _sourceBetween(
      source,
      'Future<FlowJoinResult> joinTheTendingHeadless',
      'Future<FlowJoinResult> joinReadingHouseHeadless',
    );

    expect(theTendingService, contains('the_tending_join_headless'));
    expect(
      theTendingService,
      contains('alertOffsetMinutes != kEventFilingNoAlertMinutes'),
    );
    expect(theTendingService, contains('_fileHeadlessJoinDelivery'));
    expect(
      theTendingService,
      contains('alertOffsetMinutes: alertOffsetMinutes'),
    );
    expect(_countOccurrences(theTendingService, '_completeHeadlessJoin'), 1);
  });

  test('headless Kept Word delegates to FlowJoinService', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final keptWordHeadless = _sourceBetween(
      source,
      'if (template.kind == _MaatFlowTemplateKind.keptWord)',
      'if (template.kind == _MaatFlowTemplateKind.theCourse)',
    );

    expect(keptWordHeadless, contains('FlowJoinService'));
    expect(keptWordHeadless, contains('joinKeptWordHeadless'));
    expect(keptWordHeadless, contains('templateKey: template.key'));
    expect(keptWordHeadless, contains('templateTitle: template.title'));
    expect(keptWordHeadless, contains('lens: keptWordLens'));
    expect(keptWordHeadless, contains('alertOffsetMinutes: 0'));
    expect(keptWordHeadless, contains('flowIdOrNegativeOne'));
  });

  test('FlowJoinService Kept Word files delivery and invalidates once', () {
    final source = File(
      'lib/features/calendar/flow_join_service.dart',
    ).readAsStringSync();
    final keptWordService = _sourceBetween(
      source,
      'Future<FlowJoinResult> joinKeptWordHeadless',
      'Future<FlowJoinResult> joinTheCourseHeadless',
    );

    expect(keptWordService, contains('the_kept_word_join_headless'));
    expect(
      keptWordService,
      contains('alertOffsetMinutes != kEventFilingNoAlertMinutes'),
    );
    expect(keptWordService, contains('_fileHeadlessJoinDelivery'));
    expect(keptWordService, contains('alertOffsetMinutes: alertOffsetMinutes'));
    expect(_countOccurrences(keptWordService, '_completeHeadlessJoin'), 1);
  });

  test('headless Course delegates to FlowJoinService', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final courseHeadless = _sourceBetween(
      source,
      'if (template.kind == _MaatFlowTemplateKind.theCourse)',
      'if (startDate == null) return -1;',
    );

    expect(courseHeadless, contains('FlowJoinService'));
    expect(courseHeadless, contains('joinTheCourseHeadless'));
    expect(courseHeadless, contains('templateKey: template.key'));
    expect(courseHeadless, contains('templateTitle: template.title'));
    expect(courseHeadless, contains('lens: courseLens'));
    expect(courseHeadless, contains('alertOffsetMinutes: 0'));
    expect(courseHeadless, contains('flowIdOrNegativeOne'));
  });

  test('FlowJoinService Course files delivery and invalidates once', () {
    final source = File(
      'lib/features/calendar/flow_join_service.dart',
    ).readAsStringSync();
    final courseService = _sourceBetween(
      source,
      'Future<FlowJoinResult> joinTheCourseHeadless',
      'Future<void> _fileHeadlessJoinDelivery',
    );

    expect(courseService, contains('the_course_join_headless'));
    expect(courseService, contains('courseContextForKemeticDate'));
    expect(
      courseService,
      contains('alertOffsetMinutes != kEventFilingNoAlertMinutes'),
    );
    expect(courseService, contains('_fileHeadlessJoinDelivery'));
    expect(courseService, contains('alertOffsetMinutes: alertOffsetMinutes'));
    expect(_countOccurrences(courseService, '_completeHeadlessJoin'), 1);
  });

  test('FlowJoinService headless completion helper invalidates once', () {
    final source = File(
      'lib/features/calendar/flow_join_service.dart',
    ).readAsStringSync();
    final helpers = _sourceBetween(
      source,
      'Future<void> _fileHeadlessJoinDelivery',
      'Future<int> _upsertFlowRow',
    );

    expect(helpers, contains('_fileHeadlessEventDelivery'));
    expect(helpers, contains('eventFiling: _eventFiling'));
    expect(
      _countOccurrences(helpers, '_publishHeadlessCalendarInvalidation'),
      1,
    );
    expect(helpers, contains('CalendarInvalidationReason.flowJoined'));
    expect(helpers, contains('FlowJoinResult.success'));
  });

  test(
    'mounted Track Sky, Moon Return, Wag, Days Outside, Decan Watch, Open Hand, Djed, Reading House, Offering Table, Tending, Kept Word, and Course persist events before filing alerts',
    () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final mountedJoin = _sourceBetween(
        source,
        'Future<int> _addMaatFlowInstance({',
        'Future<EndFlowActionResult> _endFlowFromEventTarget',
      );

      final trackSkyBranch = _sourceBetween(
        mountedJoin,
        'if (template.kind == _MaatFlowTemplateKind.trackSky)',
        'if (template.kind == _MaatFlowTemplateKind.moonReturn)',
      );
      _expectPersistsBeforeAlertFiling(
        trackSkyBranch,
        caller: "caller: 'track_sky_join'",
        branchName: 'mounted Track Sky',
      );

      final moonReturnBranch = _sourceBetween(
        mountedJoin,
        'if (template.kind == _MaatFlowTemplateKind.moonReturn)',
        'if (template.kind == _MaatFlowTemplateKind.theWag)',
      );
      _expectPersistsBeforeAlertFiling(
        moonReturnBranch,
        caller: "caller: 'moon_return_join'",
        branchName: 'mounted Moon Return',
      );

      final wagBranch = _sourceBetween(
        mountedJoin,
        'if (template.kind == _MaatFlowTemplateKind.theWag)',
        'if (template.kind == _MaatFlowTemplateKind.daysOutsideTheYear)',
      );
      _expectPersistsBeforeAlertFiling(
        wagBranch,
        caller: "caller: 'wag_join'",
        branchName: 'mounted Wag',
      );

      final daysOutsideBranch = _sourceBetween(
        mountedJoin,
        'if (template.kind == _MaatFlowTemplateKind.daysOutsideTheYear)',
        'if (template.kind == _MaatFlowTemplateKind.theOpenHand)',
      );
      _expectPersistsBeforeAlertFiling(
        daysOutsideBranch,
        caller: "caller: 'days_outside_year_join'",
        branchName: 'mounted Days Outside the Year',
      );

      final decanWatchBranch = _sourceBetween(
        mountedJoin,
        'if (template.kind == _MaatFlowTemplateKind.decanWatch)',
        'if (template.kind == _MaatFlowTemplateKind.dawnHouseRite)',
      );
      _expectPersistsBeforeAlertFiling(
        decanWatchBranch,
        caller: "caller: 'decan_watch_join'",
        branchName: 'mounted Decan Watch',
      );

      final openHandBranch = _sourceBetween(
        mountedJoin,
        'if (template.kind == _MaatFlowTemplateKind.theOpenHand)',
        'if (template.kind == _MaatFlowTemplateKind.theDjed)',
      );
      _expectPersistsBeforeAlertFiling(
        openHandBranch,
        caller: "caller: 'open_hand_join'",
        branchName: 'mounted Open Hand',
      );

      final djedBranch = _sourceBetween(
        mountedJoin,
        'if (template.kind == _MaatFlowTemplateKind.theDjed)',
        'if (template.kind == _MaatFlowTemplateKind.readingHouse)',
      );
      _expectPersistsBeforeAlertFiling(
        djedBranch,
        caller: "caller: 'djed_join'",
        branchName: 'mounted Djed',
      );

      final readingHouseBranch = _sourceBetween(
        mountedJoin,
        'if (template.kind == _MaatFlowTemplateKind.readingHouse)',
        'if (template.kind == _MaatFlowTemplateKind.decanWatch)',
      );
      _expectPersistsBeforeAlertFiling(
        readingHouseBranch,
        caller: "caller: 'reading_house_join'",
        branchName: 'mounted Reading House',
      );

      final offeringTableBranch = _sourceBetween(
        mountedJoin,
        'if (template.kind == _MaatFlowTemplateKind.offeringTable)',
        'if (template.kind == _MaatFlowTemplateKind.theTending)',
      );
      _expectPersistsBeforeAlertFiling(
        offeringTableBranch,
        caller: "caller: 'offering_table_join'",
        branchName: 'mounted Offering Table',
      );

      final tendingBranch = _sourceBetween(
        mountedJoin,
        'if (template.kind == _MaatFlowTemplateKind.theTending)',
        'if (template.kind == _MaatFlowTemplateKind.keptWord)',
      );
      _expectPersistsBeforeAlertFiling(
        tendingBranch,
        caller: "caller: 'the_tending_join'",
        branchName: 'mounted Tending',
      );

      final keptWordBranch = _sourceBetween(
        mountedJoin,
        'if (template.kind == _MaatFlowTemplateKind.keptWord)',
        'if (template.kind == _MaatFlowTemplateKind.theCourse)',
      );
      _expectPersistsBeforeAlertFiling(
        keptWordBranch,
        caller: "caller: 'the_kept_word_join'",
        branchName: 'mounted Kept Word',
      );

      final courseBranch = _sourceBetween(
        mountedJoin,
        'if (template.kind == _MaatFlowTemplateKind.theCourse)',
        "// Current Ma'at templates must use explicit branches above;",
      );
      _expectPersistsBeforeAlertFiling(
        courseBranch,
        caller: "caller: 'the_course_join'",
        branchName: 'mounted Course',
      );
    },
  );

  test('mounted Track Sky preserves event identity and alert contract', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final mountedJoin = _sourceBetween(
      source,
      'Future<int> _addMaatFlowInstance({',
      'Future<EndFlowActionResult> _endFlowFromEventTarget',
    );
    final trackSkyBranch = _sourceBetween(
      mountedJoin,
      'if (template.kind == _MaatFlowTemplateKind.trackSky)',
      'if (template.kind == _MaatFlowTemplateKind.moonReturn)',
    );

    expect(trackSkyBranch, contains('loadTrackSkyFlowData(timezone)'));
    expect(trackSkyBranch, contains('upcomingTrackSkyEvents(flowData)'));
    expect(trackSkyBranch, contains('mode=gregorian'));
    expect(trackSkyBranch, contains('maat=\${template.key}'));
    expect(trackSkyBranch, contains('sky_tz=\${timezone.key}'));
    expect(
      trackSkyBranch,
      contains('trackSkyTimeZone ?? detectTrackSkyTimeZone'),
    );
    expect(
      trackSkyBranch,
      contains('trackSkyEventStartLocal(event, timezone)'),
    );
    expect(trackSkyBranch, contains('trackSkyEventEndLocal(event, timezone)'));
    expect(trackSkyBranch, contains('clientEventId = _buildCid('));
    expect(trackSkyBranch, contains('title: event.title'));
    expect(trackSkyBranch, contains('detail: event.detailText'));
    expect(trackSkyBranch, contains('allDay: event.schedule.allDay'));
    expect(trackSkyBranch, contains('category: event.category'));
    expect(trackSkyBranch, contains('alertOffsetMinutes: alertMinutesBefore'));
    expect(
      trackSkyBranch,
      contains('startsAtUtc: trackSkyEventStartUtc(event, timezone)'),
    );
    expect(
      trackSkyBranch,
      contains('endsAtUtc: trackSkyEventEndUtc(event, timezone)'),
    );
    expect(trackSkyBranch, contains('alertMinutes: alertMinutesBefore'));
    expect(trackSkyBranch, contains('caller: \'track_sky_join\''));
    expect(trackSkyBranch, contains('_addNote('));
    expect(trackSkyBranch, contains('await repo.upsertByClientId('));
    expect(trackSkyBranch, contains('await _scheduleAlertForEvent('));
  });

  test('mounted Track Sky persistence failures are handled explicitly', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final mountedJoin = _sourceBetween(
      source,
      'Future<int> _addMaatFlowInstance({',
      'Future<EndFlowActionResult> _endFlowFromEventTarget',
    );
    final trackSkyBranch = _sourceBetween(
      mountedJoin,
      'if (template.kind == _MaatFlowTemplateKind.trackSky)',
      'if (template.kind == _MaatFlowTemplateKind.moonReturn)',
    );

    expect(trackSkyBranch, isNot(contains('Future.microtask')));
    expect(trackSkyBranch, contains('} catch (e, st) {'));
    expect(trackSkyBranch, contains('[trackSky] event creation failed: \$e'));
    expect(trackSkyBranch, contains('Could not create \${template.title}.'));
    expect(trackSkyBranch, contains('await repo.deleteFlow(serverFlowId);'));
    expect(trackSkyBranch, contains('return -1;'));
  });

  test('Decan Watch horizon persists events before filing alerts', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final horizon = _sourceBetween(
      source,
      'Future<void> _ensureDecanWatchHorizon(int flowId) async {',
      'String? _flowNoteToken(String? notes, String prefix)',
    );

    _expectPersistsBeforeAlertFiling(
      horizon,
      caller: "caller: 'decan_watch_horizon'",
      branchName: 'Decan Watch horizon',
    );
    expect(horizon, contains('alertOffsetMinutes: 0'));
    expect(horizon, contains('decanWatchClientEventId('));
    expect(horizon, contains('decanWatchBehaviorPayload('));
    expect(horizon, contains('decanWatchActionId(occurrence)'));
  });

  test('Decan Watch horizon failures are not silently swallowed', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final horizon = _sourceBetween(
      source,
      'Future<void> _ensureDecanWatchHorizon(int flowId) async {',
      'String? _flowNoteToken(String? notes, String prefix)',
    );

    expect(horizon, contains('} catch (e, st) {'));
    expect(horizon, contains('[decanWatchHorizon] event creation failed '));
    expect(horizon, contains('[decanWatchHorizon] flow rule update failed'));
    expect(horizon, isNot(contains('catch (_) {}')));
  });

  test('mounted no-alert rites keep explicit no-alert policy', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final mountedJoin = _sourceBetween(
      source,
      'Future<int> _addMaatFlowInstance({',
      'Future<EndFlowActionResult> _endFlowFromEventTarget',
    );

    final dawnBranch = _sourceBetween(
      mountedJoin,
      'if (template.kind == _MaatFlowTemplateKind.dawnHouseRite)',
      'if (template.kind == _MaatFlowTemplateKind.eveningThreshold)',
    );
    final eveningBranch = _sourceBetween(
      mountedJoin,
      'if (template.kind == _MaatFlowTemplateKind.eveningThresholdRite)',
      'if (template.kind == _MaatFlowTemplateKind.theWeighing)',
    );
    final weighingBranch = _sourceBetween(
      mountedJoin,
      'if (template.kind == _MaatFlowTemplateKind.theWeighing)',
      'if (template.kind == _MaatFlowTemplateKind.offeringTable)',
    );

    _expectMountedBranchUsesExplicitNoAlert(
      dawnBranch,
      branchName: 'mounted Dawn House Rite',
    );
    _expectMountedBranchUsesExplicitNoAlert(
      eveningBranch,
      branchName: 'mounted Evening Threshold Rite',
    );
    _expectMountedBranchUsesExplicitNoAlert(
      weighingBranch,
      branchName: 'mounted The Weighing',
    );
  });

  test('mounted Ma_at templates are explicitly handled before fallback', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final templateList = _sourceBetween(
      source,
      'final List<_MaatFlowTemplate> _kMaatFlowTemplates = [',
      'CALENDAR PAGE (flows + notes)',
    );
    final mountedJoin = _sourceBetween(
      source,
      'Future<int> _addMaatFlowInstance({',
      'Future<EndFlowActionResult> _endFlowFromEventTarget',
    );
    final explicitBranches = _sourceBetween(
      mountedJoin,
      'if (template.kind == _MaatFlowTemplateKind.trackSky)',
      "// Current Ma'at templates must use explicit branches above;",
    );
    const explicitTemplateCount = 33;
    const explicitKinds = [
      'trackSky',
      'dawnHouseRite',
      'eveningThreshold',
      'eveningThresholdRite',
      'theWeighing',
      'offeringTable',
      'theTending',
      'keptWord',
      'theCourse',
      'moonReturn',
      'theWag',
      'decanWatch',
      'daysOutsideTheYear',
      'theOpenHand',
      'theDjed',
      'readingHouse',
      'maatDecan',
    ];

    expect(
      _countOccurrences(templateList, '_MaatFlowTemplate('),
      explicitTemplateCount,
      reason: 'Every current Ma_at template should be represented here.',
    );
    expect(
      _countOccurrences(templateList, 'kind: _MaatFlowTemplateKind.'),
      explicitTemplateCount,
      reason: 'Current templates must declare explicit kinds.',
    );
    expect(
      templateList,
      isNot(contains('kind: _MaatFlowTemplateKind.sequence')),
      reason: 'Legacy sequence templates are not current product templates.',
    );
    for (final kind in explicitKinds) {
      expect(
        templateList,
        contains('kind: _MaatFlowTemplateKind.$kind'),
        reason: 'Template list must include $kind explicitly.',
      );
      expect(
        explicitBranches,
        contains('if (template.kind == _MaatFlowTemplateKind.$kind)'),
        reason: '$kind must be handled before the fail-closed fallback.',
      );
    }
  });

  test('mounted generic Ma_at fallback fails closed without autoschedule', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final mountedJoin = _sourceBetween(
      source,
      'Future<int> _addMaatFlowInstance({',
      'Future<EndFlowActionResult> _endFlowFromEventTarget',
    );
    final fallbackStart = mountedJoin.indexOf(
      "// Current Ma'at templates must use explicit branches above;",
    );
    expect(fallbackStart, isNonNegative);
    final fallback = mountedJoin.substring(fallbackStart);

    expect(mountedJoin, isNot(contains('Future.microtask')));
    expect(mountedJoin, isNot(contains("caller: 'maat_autoschedule'")));
    expect(fallback, contains('_calendarDebugPrint('));
    expect(fallback, contains("Unsupported mounted Ma'at template"));
    expect(fallback, contains('ScaffoldMessenger.of(context).showSnackBar'));
    expect(fallback, contains('return -1;'));
    expect(fallback, isNot(contains('_addNote(')));
    expect(fallback, isNot(contains('repo.upsertByClientId(')));
    expect(fallback, isNot(contains('await _scheduleAlertForEvent(')));
    expect(fallback, isNot(contains('catch (_)')));
  });

  test('mounted Moon Return join uses safe enrollment resolution', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final resolver = _sourceBetween(
      source,
      'MoonReturnEnrollmentWindow? _resolveMountedMoonReturnJoinWindow',
      '/// Create a user-owned *instance*',
    );
    final mountedJoin = _sourceBetween(
      source,
      'Future<int> _addMaatFlowInstance({',
      'Future<EndFlowActionResult> _endFlowFromEventTarget',
    );
    final moonReturnBranch = _sourceBetween(
      mountedJoin,
      'if (template.kind == _MaatFlowTemplateKind.moonReturn)',
      'if (template.kind == _MaatFlowTemplateKind.theWag)',
    );

    expect(resolver, contains('resolveMoonReturnEnrollmentWindowSafely'));
    expect(resolver, contains('flow=The Moon Return'));
    expect(resolver, contains('timezone=\${timezone.key}'));
    expect(resolver, contains('selectedDate='));
    expect(resolver, contains('now=\${now.toIso8601String()}'));
    expect(resolver, isNot(contains('moonReturnNextEnrollmentWindow(')));
    expect(moonReturnBranch, contains('_resolveMountedMoonReturnJoinWindow'));
    expect(
      moonReturnBranch,
      isNot(contains('moonReturnNextEnrollmentWindow(')),
    );
    expect(
      moonReturnBranch,
      isNot(contains('moonReturnEnrollmentWindowForStartDate(')),
    );
    expect(
      moonReturnBranch,
      contains('FlowJoinFailureCode.noEnrollmentWindow'),
    );
    expect(moonReturnBranch, contains('FlowJoinFailureCode.noOccurrences'));
  });

  test(
    'mounted Moon Return join preserves event identity and payload contract',
    () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final mountedJoin = _sourceBetween(
        source,
        'Future<int> _addMaatFlowInstance({',
        'Future<EndFlowActionResult> _endFlowFromEventTarget',
      );
      final moonReturnBranch = _sourceBetween(
        mountedJoin,
        'if (template.kind == _MaatFlowTemplateKind.moonReturn)',
        'if (template.kind == _MaatFlowTemplateKind.theWag)',
      );

      expect(moonReturnBranch, contains('mode=astronomy'));
      expect(moonReturnBranch, contains('maat=\${template.key}'));
      expect(moonReturnBranch, contains('moon_tz=\${timezone.key}'));
      expect(moonReturnBranch, contains('moon_lens=\${moonReturnLens.key}'));
      expect(moonReturnBranch, contains('moon_enrolled_at='));
      expect(moonReturnBranch, contains('moon_window_open='));
      expect(moonReturnBranch, contains('moon_new_moon='));
      expect(moonReturnBranch, contains('moonReturnEventTitle(occurrence)'));
      expect(moonReturnBranch, contains('moonReturnDetailText('));
      expect(moonReturnBranch, contains('moonReturnBehaviorPayload('));
      expect(moonReturnBranch, contains('moonReturnClientEventId('));
      expect(moonReturnBranch, contains('moonReturnActionId(occurrence)'));
      expect(moonReturnBranch, contains('startsAtUtc: occurrence.startUtc'));
      expect(moonReturnBranch, contains('endsAtUtc: occurrence.endUtc'));
      expect(moonReturnBranch, contains('category: \'Ritual\''));
      expect(moonReturnBranch, contains('alertOffsetMinutes: 0'));
      expect(moonReturnBranch, contains('caller: \'moon_return_join\''));
      expect(moonReturnBranch, contains('_addNote('));
      expect(moonReturnBranch, contains('await _scheduleAlertForEvent('));
    },
  );

  test('mounted Wag join uses safe enrollment resolution', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final resolver = _sourceBetween(
      source,
      'WagEnrollmentWindow? _resolveMountedWagJoinWindow',
      '/// Create a user-owned *instance*',
    );
    final mountedJoin = _sourceBetween(
      source,
      'Future<int> _addMaatFlowInstance({',
      'Future<EndFlowActionResult> _endFlowFromEventTarget',
    );
    final wagBranch = _sourceBetween(
      mountedJoin,
      'if (template.kind == _MaatFlowTemplateKind.theWag)',
      'if (template.kind == _MaatFlowTemplateKind.daysOutsideTheYear)',
    );

    expect(resolver, contains('resolveWagEnrollmentWindowSafely'));
    expect(resolver, contains('flow=The Wag'));
    expect(resolver, contains('timezone=\${timezone.key}'));
    expect(resolver, contains('selectedDate='));
    expect(resolver, contains('now=\${now.toIso8601String()}'));
    expect(resolver, isNot(contains('wagNextEnrollmentWindow(')));
    expect(wagBranch, contains('_resolveMountedWagJoinWindow'));
    expect(wagBranch, isNot(contains('wagNextEnrollmentWindow(')));
    expect(wagBranch, isNot(contains('wagEnrollmentWindowForStartDate(')));
    expect(wagBranch, contains('FlowJoinFailureCode.noEnrollmentWindow'));
  });

  test('mounted Wag join preserves event identity and payload contract', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final mountedJoin = _sourceBetween(
      source,
      'Future<int> _addMaatFlowInstance({',
      'Future<EndFlowActionResult> _endFlowFromEventTarget',
    );
    final wagBranch = _sourceBetween(
      mountedJoin,
      'if (template.kind == _MaatFlowTemplateKind.theWag)',
      'if (template.kind == _MaatFlowTemplateKind.daysOutsideTheYear)',
    );

    expect(wagBranch, contains('mode=kemetic'));
    expect(wagBranch, contains('maat=\${template.key}'));
    expect(wagBranch, contains('wag_kyear=\$kYear'));
    expect(wagBranch, contains('wag_tz=\${timezone.key}'));
    expect(wagBranch, contains('wag_lens=\${wagLens.key}'));
    expect(wagBranch, contains('wag_enrolled_at='));
    expect(wagBranch, contains('wag_window_open='));
    expect(wagBranch, contains('wagEventTitle(event)'));
    expect(wagBranch, contains('wagDetailText('));
    expect(wagBranch, contains('wagBehaviorPayload('));
    expect(wagBranch, contains('wagClientEventId('));
    expect(wagBranch, contains('wagActionId(event)'));
    expect(wagBranch, contains('startsAtUtc: schedule.startUtc'));
    expect(wagBranch, contains('endsAtUtc: schedule.endUtc'));
    expect(wagBranch, contains('category: \'Ritual\''));
    expect(wagBranch, contains('alertOffsetMinutes: 0'));
    expect(wagBranch, contains('caller: \'wag_join\''));
    expect(wagBranch, contains('_addNote('));
    expect(wagBranch, contains('await _scheduleAlertForEvent('));
  });

  test('mounted Days Outside join uses safe enrollment resolution', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final resolver = _sourceBetween(
      source,
      'DaysOutsideYearEnrollmentWindow? _resolveMountedDaysOutsideYearJoinWindow',
      '/// Create a user-owned *instance*',
    );
    final mountedJoin = _sourceBetween(
      source,
      'Future<int> _addMaatFlowInstance({',
      'Future<EndFlowActionResult> _endFlowFromEventTarget',
    );
    final daysOutsideBranch = _sourceBetween(
      mountedJoin,
      'if (template.kind == _MaatFlowTemplateKind.daysOutsideTheYear)',
      'if (template.kind == _MaatFlowTemplateKind.theOpenHand)',
    );

    expect(resolver, contains('resolveDaysOutsideYearEnrollmentWindowSafely'));
    expect(resolver, contains('flow=The Days Outside the Year'));
    expect(resolver, contains('timezone=\${timezone.key}'));
    expect(resolver, contains('selectedDate='));
    expect(resolver, contains('now=\${now.toIso8601String()}'));
    expect(resolver, isNot(contains('daysOutsideYearNextEnrollmentWindow(')));
    expect(
      daysOutsideBranch,
      contains('_resolveMountedDaysOutsideYearJoinWindow'),
    );
    expect(
      daysOutsideBranch,
      isNot(contains('daysOutsideYearNextEnrollmentWindow(')),
    );
    expect(
      daysOutsideBranch,
      isNot(contains('daysOutsideYearEnrollmentWindowForStartDate(')),
    );
    expect(
      daysOutsideBranch,
      contains('FlowJoinFailureCode.noEnrollmentWindow'),
    );
  });

  test(
    'mounted Days Outside join preserves event identity and payload contract',
    () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final mountedJoin = _sourceBetween(
        source,
        'Future<int> _addMaatFlowInstance({',
        'Future<EndFlowActionResult> _endFlowFromEventTarget',
      );
      final daysOutsideBranch = _sourceBetween(
        mountedJoin,
        'if (template.kind == _MaatFlowTemplateKind.daysOutsideTheYear)',
        'if (template.kind == _MaatFlowTemplateKind.theOpenHand)',
      );

      expect(daysOutsideBranch, contains('mode=kemetic'));
      expect(daysOutsideBranch, contains('maat=\${template.key}'));
      expect(daysOutsideBranch, contains('doy_kyear=\$closingKYear'));
      expect(daysOutsideBranch, contains('doy_tz=\${timezone.key}'));
      expect(daysOutsideBranch, contains('doy_enrolled_at='));
      expect(daysOutsideBranch, contains('doy_window_open='));
      expect(daysOutsideBranch, contains('daysOutsideEventTitle(event)'));
      expect(daysOutsideBranch, contains('daysOutsideDetailText('));
      expect(daysOutsideBranch, contains('daysOutsideBehaviorPayload('));
      expect(daysOutsideBranch, contains('daysOutsideClientEventId('));
      expect(daysOutsideBranch, contains('daysOutsideActionId(event)'));
      expect(daysOutsideBranch, contains('startsAtUtc: schedule.startUtc'));
      expect(daysOutsideBranch, contains('endsAtUtc: schedule.endUtc'));
      expect(daysOutsideBranch, contains('category: \'Ritual\''));
      expect(daysOutsideBranch, contains('alertOffsetMinutes: 0'));
      expect(daysOutsideBranch, contains('caller: \'days_outside_year_join\''));
      expect(daysOutsideBranch, contains('_addNote('));
      expect(daysOutsideBranch, contains('await _scheduleAlertForEvent('));
    },
  );

  test('mounted Decan Watch join uses safe enrollment resolution', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final resolver = _sourceBetween(
      source,
      'DecanWatchEnrollmentWindow? _resolveMountedDecanWatchJoinWindow',
      '/// Create a user-owned *instance*',
    );
    final mountedJoin = _sourceBetween(
      source,
      'Future<int> _addMaatFlowInstance({',
      'Future<EndFlowActionResult> _endFlowFromEventTarget',
    );
    final decanWatchBranch = _sourceBetween(
      mountedJoin,
      'if (template.kind == _MaatFlowTemplateKind.decanWatch)',
      'if (template.kind == _MaatFlowTemplateKind.dawnHouseRite)',
    );

    expect(resolver, contains('resolveDecanWatchEnrollmentWindowSafely'));
    expect(resolver, contains('flow=The Decan Watch'));
    expect(resolver, contains('timezone=\${timezone.key}'));
    expect(resolver, contains('selectedDate='));
    expect(resolver, contains('now=\${now.toIso8601String()}'));
    expect(resolver, isNot(contains('decanWatchNextEnrollmentWindow(')));
    expect(decanWatchBranch, contains('_resolveMountedDecanWatchJoinWindow'));
    expect(
      decanWatchBranch,
      isNot(contains('decanWatchNextEnrollmentWindow(')),
    );
    expect(
      decanWatchBranch,
      isNot(contains('decanWatchEnrollmentWindowForStartDate(')),
    );
    expect(
      decanWatchBranch,
      contains('FlowJoinFailureCode.noEnrollmentWindow'),
    );
  });

  test(
    'mounted Decan Watch join preserves event identity and payload contract',
    () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final mountedJoin = _sourceBetween(
        source,
        'Future<int> _addMaatFlowInstance({',
        'Future<EndFlowActionResult> _endFlowFromEventTarget',
      );
      final decanWatchBranch = _sourceBetween(
        mountedJoin,
        'if (template.kind == _MaatFlowTemplateKind.decanWatch)',
        'if (template.kind == _MaatFlowTemplateKind.dawnHouseRite)',
      );

      expect(decanWatchBranch, contains('mode=kemetic'));
      expect(decanWatchBranch, contains('maat=\${template.key}'));
      expect(decanWatchBranch, contains('dw_tz=\${timezone.key}'));
      expect(decanWatchBranch, contains('dw_lens=\${decanWatchLens.key}'));
      expect(
        decanWatchBranch,
        contains('dw_enrolled_kyear=\${window.openingOccurrence.kYear}'),
      );
      expect(decanWatchBranch, contains('dw_hour=\$kDecanWatchDefaultHour'));
      expect(
        decanWatchBranch,
        contains('dw_minute=\$kDecanWatchDefaultMinute'),
      );
      expect(decanWatchBranch, contains('dw_enrolled_at='));
      expect(decanWatchBranch, contains('decanWatchEventTitle(occurrence)'));
      expect(decanWatchBranch, contains('courseContextForKemeticDate('));
      expect(decanWatchBranch, contains('decanWatchDetailText('));
      expect(decanWatchBranch, contains('decanWatchBehaviorPayload('));
      expect(decanWatchBranch, contains('decanWatchClientEventId('));
      expect(decanWatchBranch, contains('decanWatchActionId(occurrence)'));
      expect(decanWatchBranch, contains('startsAtUtc: occurrence.startUtc'));
      expect(decanWatchBranch, contains('endsAtUtc: occurrence.endUtc'));
      expect(decanWatchBranch, contains('category: \'Ritual\''));
      expect(decanWatchBranch, contains('alertOffsetMinutes: 0'));
      expect(decanWatchBranch, contains('caller: \'decan_watch_join\''));
      expect(decanWatchBranch, contains('_addNote('));
      expect(decanWatchBranch, contains('await _scheduleAlertForEvent('));
    },
  );

  test('mounted Open Hand join uses safe enrollment resolution', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final resolver = _sourceBetween(
      source,
      'OpenHandEnrollmentWindow? _resolveMountedOpenHandJoinWindow',
      '/// Create a user-owned *instance*',
    );
    final mountedJoin = _sourceBetween(
      source,
      'Future<int> _addMaatFlowInstance({',
      'Future<EndFlowActionResult> _endFlowFromEventTarget',
    );
    final openHandBranch = _sourceBetween(
      mountedJoin,
      'if (template.kind == _MaatFlowTemplateKind.theOpenHand)',
      'if (template.kind == _MaatFlowTemplateKind.theDjed)',
    );

    expect(resolver, contains('resolveOpenHandEnrollmentWindowSafely'));
    expect(resolver, contains('flow=The Open Hand'));
    expect(resolver, contains('timezone=\${timezone.key}'));
    expect(resolver, contains('selectedDate='));
    expect(resolver, contains('now=\${now.toIso8601String()}'));
    expect(resolver, isNot(contains('openHandNextEnrollmentWindow(')));
    expect(openHandBranch, contains('_resolveMountedOpenHandJoinWindow'));
    expect(openHandBranch, isNot(contains('openHandNextEnrollmentWindow(')));
    expect(
      openHandBranch,
      isNot(contains('openHandEnrollmentWindowForStartDate(')),
    );
    expect(openHandBranch, contains('FlowJoinFailureCode.noEnrollmentWindow'));
  });

  test(
    'mounted Open Hand join preserves event identity and payload contract',
    () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final mountedJoin = _sourceBetween(
        source,
        'Future<int> _addMaatFlowInstance({',
        'Future<EndFlowActionResult> _endFlowFromEventTarget',
      );
      final openHandBranch = _sourceBetween(
        mountedJoin,
        'if (template.kind == _MaatFlowTemplateKind.theOpenHand)',
        'if (template.kind == _MaatFlowTemplateKind.theDjed)',
      );

      expect(openHandBranch, contains('mode=gregorian'));
      expect(openHandBranch, contains('maat=\${template.key}'));
      expect(openHandBranch, contains('oh_start=\$startIso'));
      expect(openHandBranch, contains('oh_tz=\${timezone.key}'));
      expect(openHandBranch, contains('oh_lens=\${openHandLens.key}'));
      expect(openHandBranch, contains('oh_midday_hour='));
      expect(openHandBranch, contains('oh_midday_minute='));
      expect(
        openHandBranch,
        contains('oh_decan_kyear=\${window.openingOccurrence.kYear}'),
      );
      expect(
        openHandBranch,
        contains('oh_decan_month=\${window.openingOccurrence.kMonth}'),
      );
      expect(
        openHandBranch,
        contains('oh_decan_day=\${window.openingOccurrence.decanStartDay}'),
      );
      expect(openHandBranch, contains('oh_enrolled_at='));
      expect(openHandBranch, contains('openHandEventTitle(event)'));
      expect(openHandBranch, contains('openHandDetailText('));
      expect(openHandBranch, contains('openHandBehaviorPayload('));
      expect(openHandBranch, contains('openHandClientEventId('));
      expect(openHandBranch, contains('openHandActionId(event)'));
      expect(openHandBranch, contains('startsAtUtc: schedule.startUtc'));
      expect(openHandBranch, contains('endsAtUtc: schedule.endUtc'));
      expect(openHandBranch, contains('category: \'Ritual\''));
      expect(openHandBranch, contains('alertOffsetMinutes: 0'));
      expect(openHandBranch, contains('caller: \'open_hand_join\''));
      expect(openHandBranch, contains('_addNote('));
      expect(openHandBranch, contains('await _scheduleAlertForEvent('));
    },
  );

  test('mounted Djed join uses safe enrollment resolution', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final resolver = _sourceBetween(
      source,
      'DjedEnrollmentWindow? _resolveMountedDjedJoinWindow',
      '/// Create a user-owned *instance*',
    );
    final mountedJoin = _sourceBetween(
      source,
      'Future<int> _addMaatFlowInstance({',
      'Future<EndFlowActionResult> _endFlowFromEventTarget',
    );
    final djedBranch = _sourceBetween(
      mountedJoin,
      'if (template.kind == _MaatFlowTemplateKind.theDjed)',
      'if (template.kind == _MaatFlowTemplateKind.readingHouse)',
    );

    expect(resolver, contains('resolveDjedEnrollmentWindowSafely'));
    expect(resolver, contains('flow=The Djed'));
    expect(resolver, contains('timezone=\${timezone.key}'));
    expect(resolver, contains('selectedDate='));
    expect(resolver, contains('now=\${now.toIso8601String()}'));
    expect(resolver, isNot(contains('djedNextEnrollmentWindow(')));
    expect(djedBranch, contains('_resolveMountedDjedJoinWindow'));
    expect(djedBranch, isNot(contains('djedNextEnrollmentWindow(')));
    expect(djedBranch, isNot(contains('djedEnrollmentWindowForStartDate(')));
    expect(djedBranch, contains('FlowJoinFailureCode.noEnrollmentWindow'));
  });

  test('mounted Djed join preserves event identity and payload contract', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final mountedJoin = _sourceBetween(
      source,
      'Future<int> _addMaatFlowInstance({',
      'Future<EndFlowActionResult> _endFlowFromEventTarget',
    );
    final djedBranch = _sourceBetween(
      mountedJoin,
      'if (template.kind == _MaatFlowTemplateKind.theDjed)',
      'if (template.kind == _MaatFlowTemplateKind.readingHouse)',
    );

    expect(djedBranch, contains('mode=gregorian'));
    expect(djedBranch, contains('maat=\${template.key}'));
    expect(djedBranch, contains('djed_start=\$startIso'));
    expect(djedBranch, contains('djed_tz=\${timezone.key}'));
    expect(djedBranch, contains('djed_lens=\${djedLens.key}'));
    expect(djedBranch, contains('djed_midday_hour='));
    expect(djedBranch, contains('djed_midday_minute='));
    expect(
      djedBranch,
      contains('djed_decan_kyear=\${window.openingOccurrence.kYear}'),
    );
    expect(
      djedBranch,
      contains('djed_decan_month=\${window.openingOccurrence.kMonth}'),
    );
    expect(
      djedBranch,
      contains('djed_decan_day=\${window.openingOccurrence.decanStartDay}'),
    );
    expect(djedBranch, contains('djed_enrolled_at='));
    expect(djedBranch, contains('djedEventTitle(event)'));
    expect(djedBranch, contains('djedDetailText('));
    expect(djedBranch, contains('djedBehaviorPayload('));
    expect(djedBranch, contains('djedClientEventId('));
    expect(djedBranch, contains('djedActionId(event)'));
    expect(djedBranch, contains('startsAtUtc: schedule.startUtc'));
    expect(djedBranch, contains('endsAtUtc: schedule.endUtc'));
    expect(djedBranch, contains('category: \'Ritual\''));
    expect(djedBranch, contains('alertOffsetMinutes: 0'));
    expect(djedBranch, contains('caller: \'djed_join\''));
    expect(djedBranch, contains('_addNote('));
    expect(djedBranch, contains('await _scheduleAlertForEvent('));
  });

  test(
    'mounted Reading House join preserves event identity and payload contract',
    () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final mountedJoin = _sourceBetween(
        source,
        'Future<int> _addMaatFlowInstance({',
        'Future<EndFlowActionResult> _endFlowFromEventTarget',
      );
      final readingHouseBranch = _sourceBetween(
        mountedJoin,
        'if (template.kind == _MaatFlowTemplateKind.readingHouse)',
        'if (template.kind == _MaatFlowTemplateKind.decanWatch)',
      );

      expect(readingHouseBranch, contains('mode=gregorian'));
      expect(readingHouseBranch, contains('maat=\${template.key}'));
      expect(readingHouseBranch, contains('reading_house_tz=\${timezone.key}'));
      expect(
        readingHouseBranch,
        contains('...readingHouseFlowNoteTokens(plan)'),
      );
      expect(
        readingHouseBranch,
        contains('reading_house_hour=\$kReadingHouseDefaultHour'),
      );
      expect(
        readingHouseBranch,
        contains('reading_house_minute=\$kReadingHouseDefaultMinute'),
      );
      expect(readingHouseBranch, contains('readingHouseSittingTitle(sitting)'));
      expect(
        readingHouseBranch,
        contains('readingHouseDetailText(sitting, plan: plan)'),
      );
      expect(readingHouseBranch, contains('readingHouseBehaviorPayload('));
      expect(readingHouseBranch, contains('_buildCid('));
      expect(readingHouseBranch, contains('readingHouseActionId(sitting)'));
      expect(readingHouseBranch, contains('startsAtUtc: occurrence.startUtc'));
      expect(readingHouseBranch, contains('endsAtUtc: occurrence.endUtc'));
      expect(readingHouseBranch, contains('category: \'Study\''));
      expect(
        readingHouseBranch,
        contains('alertOffsetMinutes: _alertNoneMinutes'),
      );
      expect(readingHouseBranch, contains('caller: \'reading_house_join\''));
      expect(readingHouseBranch, contains('_addNote('));
      expect(readingHouseBranch, contains('await _scheduleAlertForEvent('));
    },
  );

  test(
    'mounted Offering Table join preserves event identity and payload contract',
    () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final mountedJoin = _sourceBetween(
        source,
        'Future<int> _addMaatFlowInstance({',
        'Future<EndFlowActionResult> _endFlowFromEventTarget',
      );
      final offeringTableBranch = _sourceBetween(
        mountedJoin,
        'if (template.kind == _MaatFlowTemplateKind.offeringTable)',
        'if (template.kind == _MaatFlowTemplateKind.theTending)',
      );

      expect(offeringTableBranch, contains('mode=gregorian'));
      expect(offeringTableBranch, contains('maat=\${template.key}'));
      expect(offeringTableBranch, contains('offering_tz=\${timezone.key}'));
      expect(
        offeringTableBranch,
        contains('offering_lens=\${offeringTableLens.key}'),
      );
      expect(offeringTableBranch, contains('offering_hour='));
      expect(offeringTableBranch, contains('offering_minute='));
      expect(
        offeringTableBranch,
        contains('no_cup_mode=\${offeringNoCupMode ? 1 : 0}'),
      );
      expect(offeringTableBranch, contains('offeringTableEventTitle(day)'));
      expect(offeringTableBranch, contains('offeringTableDetailText('));
      expect(offeringTableBranch, contains('lens: offeringTableLens'));
      expect(offeringTableBranch, contains('noCupMode: offeringNoCupMode'));
      expect(offeringTableBranch, contains('offeringTableBehaviorPayload('));
      expect(offeringTableBranch, contains('offeringTableActionId(day)'));
      expect(offeringTableBranch, contains('clientEventId = _buildCid('));
      expect(offeringTableBranch, contains('startsAtUtc: occurrence.startUtc'));
      expect(offeringTableBranch, contains('endsAtUtc: occurrence.endUtc'));
      expect(offeringTableBranch, contains('category: \'Ritual\''));
      expect(offeringTableBranch, contains('alertOffsetMinutes: 0'));
      expect(offeringTableBranch, contains('caller: \'offering_table_join\''));
      expect(offeringTableBranch, contains('_addNote('));
      expect(offeringTableBranch, contains('await _scheduleAlertForEvent('));
    },
  );

  test(
    'mounted The Weighing join preserves event identity and payload contract',
    () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final weighingSource = File(
        'lib/features/calendar/the_weighing_flow.dart',
      ).readAsStringSync();
      final mountedJoin = _sourceBetween(
        source,
        'Future<int> _addMaatFlowInstance({',
        'Future<EndFlowActionResult> _endFlowFromEventTarget',
      );
      final weighingBranch = _sourceBetween(
        mountedJoin,
        'if (template.kind == _MaatFlowTemplateKind.theWeighing)',
        'if (template.kind == _MaatFlowTemplateKind.offeringTable)',
      );
      final weighingPayload = _sourceBetween(
        weighingSource,
        'Map<String, dynamic> theWeighingBehaviorPayload({',
        'String theWeighingDetailText(',
      );

      expect(weighingBranch, contains('mode=gregorian'));
      expect(weighingBranch, contains('maat=\${template.key}'));
      expect(weighingBranch, contains('weighing_tz=\${timezone.key}'));
      expect(weighingBranch, contains('weighing_lens=\${theWeighingLens.key}'));
      expect(weighingBranch, contains('weighing_midday_hour='));
      expect(weighingBranch, contains('weighing_midday_minute='));
      expect(weighingBranch, contains('theWeighingEventTitle(event)'));
      expect(weighingBranch, contains('theWeighingDetailText('));
      expect(weighingBranch, contains('lens: theWeighingLens'));
      expect(weighingBranch, contains('theWeighingBehaviorPayload('));
      expect(weighingBranch, contains('event: event'));
      expect(weighingBranch, contains('schedule: occurrence'));
      expect(weighingBranch, contains('theWeighingActionId(event)'));
      expect(weighingBranch, contains('clientEventId = _buildCid('));
      expect(weighingBranch, contains('startsAtUtc: occurrence.startUtc'));
      expect(weighingBranch, contains('endsAtUtc: occurrence.endUtc'));
      expect(weighingBranch, contains('category: \'Ritual\''));
      expect(weighingBranch, contains('alertOffsetMinutes: _alertNoneMinutes'));
      expect(weighingBranch, contains('caller: \'the_weighing_join\''));
      expect(weighingBranch, contains('_addNote('));
      expect(weighingBranch, contains('await _scheduleAlertForEvent('));

      expect(weighingPayload, contains("'kind': 'maat_the_weighing_event'"));
      expect(weighingPayload, contains("'flow_key': kTheWeighingFlowKey"));
      expect(weighingPayload, contains("'event_number': event.eventNumber"));
      expect(weighingPayload, contains("'flow_day': event.flowDay"));
      expect(weighingPayload, contains("'schedule': <String, dynamic>{"));
      expect(weighingPayload, contains("'lens': lens.key"));
    },
  );

  test(
    'mounted Tending join preserves event identity and privacy payload contract',
    () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final tendingSource = File(
        'lib/features/calendar/the_tending_flow.dart',
      ).readAsStringSync();
      final mountedJoin = _sourceBetween(
        source,
        'Future<int> _addMaatFlowInstance({',
        'Future<EndFlowActionResult> _endFlowFromEventTarget',
      );
      final tendingBranch = _sourceBetween(
        mountedJoin,
        'if (template.kind == _MaatFlowTemplateKind.theTending)',
        'if (template.kind == _MaatFlowTemplateKind.keptWord)',
      );
      final tendingPayload = _sourceBetween(
        tendingSource,
        'Map<String, dynamic> theTendingBehaviorPayload({',
        'String theTendingDetailText(',
      );

      expect(tendingBranch, contains('mode=gregorian'));
      expect(tendingBranch, contains('maat=\${template.key}'));
      expect(tendingBranch, contains('tending_tz=\${timezone.key}'));
      expect(tendingBranch, contains('tending_lens=\${theTendingLens.key}'));
      expect(tendingBranch, contains('tending_midday_hour='));
      expect(tendingBranch, contains('tending_midday_minute='));
      expect(tendingBranch, contains('theTendingEventTitle(event)'));
      expect(tendingBranch, contains('theTendingDetailText('));
      expect(tendingBranch, contains('lens: theTendingLens'));
      expect(tendingBranch, contains('theTendingBehaviorPayload('));
      expect(tendingBranch, contains('event: event'));
      expect(tendingBranch, contains('schedule: occurrence'));
      expect(tendingBranch, contains('theTendingActionId(event)'));
      expect(tendingBranch, contains('clientEventId = _buildCid('));
      expect(tendingBranch, contains('startsAtUtc: occurrence.startUtc'));
      expect(tendingBranch, contains('endsAtUtc: occurrence.endUtc'));
      expect(tendingBranch, contains('category: \'Ritual\''));
      expect(tendingBranch, contains('alertOffsetMinutes: 0'));
      expect(tendingBranch, contains('caller: \'the_tending_join\''));
      expect(tendingBranch, contains('_addNote('));
      expect(tendingBranch, contains('await _scheduleAlertForEvent('));

      expect(tendingPayload, contains("'local_prompt': event.localPrompt.key"));
      expect(tendingPayload, contains("'care_notes_storage': 'device_only'"));
      expect(tendingPayload, contains("'sync_care_names': false"));
    },
  );

  test(
    'mounted Kept Word join preserves event identity and privacy payload contract',
    () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final keptWordSource = File(
        'lib/features/calendar/the_kept_word_flow.dart',
      ).readAsStringSync();
      final mountedJoin = _sourceBetween(
        source,
        'Future<int> _addMaatFlowInstance({',
        'Future<EndFlowActionResult> _endFlowFromEventTarget',
      );
      final keptWordBranch = _sourceBetween(
        mountedJoin,
        'if (template.kind == _MaatFlowTemplateKind.keptWord)',
        'if (template.kind == _MaatFlowTemplateKind.theCourse)',
      );
      final keptWordPayload = _sourceBetween(
        keptWordSource,
        'Map<String, dynamic> keptWordBehaviorPayload({',
        'String keptWordDetailText(',
      );

      expect(keptWordBranch, contains('mode=gregorian'));
      expect(keptWordBranch, contains('maat=\${template.key}'));
      expect(keptWordBranch, contains('kept_word_tz=\${timezone.key}'));
      expect(keptWordBranch, contains('kept_word_lens=\${keptWordLens.key}'));
      expect(keptWordBranch, contains('kept_word_midday_hour='));
      expect(keptWordBranch, contains('kept_word_midday_minute='));
      expect(keptWordBranch, contains('keptWordEventTitle(event)'));
      expect(keptWordBranch, contains('keptWordDetailText('));
      expect(keptWordBranch, contains('lens: keptWordLens'));
      expect(keptWordBranch, contains('keptWordBehaviorPayload('));
      expect(keptWordBranch, contains('event: event'));
      expect(keptWordBranch, contains('schedule: occurrence'));
      expect(keptWordBranch, contains('keptWordActionId(event)'));
      expect(keptWordBranch, contains('clientEventId = _buildCid('));
      expect(keptWordBranch, contains('startsAtUtc: occurrence.startUtc'));
      expect(keptWordBranch, contains('endsAtUtc: occurrence.endUtc'));
      expect(keptWordBranch, contains('category: \'Ritual\''));
      expect(keptWordBranch, contains('alertOffsetMinutes: 0'));
      expect(keptWordBranch, contains('caller: \'the_kept_word_join\''));
      expect(keptWordBranch, contains('_addNote('));
      expect(keptWordBranch, contains('await _scheduleAlertForEvent('));

      expect(keptWordSource, contains("return 'agreement_inventory'"));
      expect(
        keptWordPayload,
        contains("'local_prompt': event.localPrompt.key"),
      );
      expect(
        keptWordPayload,
        contains("'household_notes_storage': 'device_only'"),
      );
      expect(keptWordPayload, contains("'sync_agreement_text': false"));
      expect(keptWordPayload, contains("'sync_names': false"));
    },
  );

  test(
    'mounted Course join preserves event identity and calendar payload contract',
    () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final courseSource = File(
        'lib/features/calendar/the_course_flow.dart',
      ).readAsStringSync();
      final mountedJoin = _sourceBetween(
        source,
        'Future<int> _addMaatFlowInstance({',
        'Future<EndFlowActionResult> _endFlowFromEventTarget',
      );
      final courseBranch = _sourceBetween(
        mountedJoin,
        'if (template.kind == _MaatFlowTemplateKind.theCourse)',
        "// Current Ma'at templates must use explicit branches above;",
      );
      final coursePayload = _sourceBetween(
        courseSource,
        'Map<String, dynamic> courseBehaviorPayload({',
        'String courseDetailText(',
      );

      expect(courseBranch, contains('mode=gregorian'));
      expect(courseBranch, contains('maat=\${template.key}'));
      expect(courseBranch, contains('course_tz=\${timezone.key}'));
      expect(courseBranch, contains('course_lens=\${courseLens.key}'));
      expect(courseBranch, contains('course_midday_hour='));
      expect(courseBranch, contains('course_midday_minute='));
      expect(courseBranch, contains('joined_ky='));
      expect(courseBranch, contains('joined_km='));
      expect(courseBranch, contains('joined_kd='));
      expect(courseBranch, contains('courseContextForKemeticDate('));
      expect(courseBranch, contains('kYear: kyKmKd.kYear'));
      expect(courseBranch, contains('kMonth: kyKmKd.kMonth'));
      expect(courseBranch, contains('kDay: kyKmKd.kDay'));
      expect(courseBranch, contains('courseEventTitle(event)'));
      expect(courseBranch, contains('courseDetailText('));
      expect(courseBranch, contains('lens: courseLens'));
      expect(courseBranch, contains('context: courseContext'));
      expect(courseBranch, contains('courseBehaviorPayload('));
      expect(courseBranch, contains('event: event'));
      expect(courseBranch, contains('schedule: occurrence'));
      expect(courseBranch, contains('courseActionId(event)'));
      expect(courseBranch, contains('clientEventId = _buildCid('));
      expect(courseBranch, contains('startsAtUtc: occurrence.startUtc'));
      expect(courseBranch, contains('endsAtUtc: occurrence.endUtc'));
      expect(courseBranch, contains('category: \'Ritual\''));
      expect(courseBranch, contains('alertOffsetMinutes: 0'));
      expect(courseBranch, contains('caller: \'the_course_join\''));
      expect(courseBranch, contains('_addNote('));
      expect(courseBranch, contains('await _scheduleAlertForEvent('));

      expect(coursePayload, contains("'flow_key': kTheCourseFlowKey"));
      expect(coursePayload, contains("'required': <String>['day_card']"));
      expect(
        coursePayload,
        contains("'requires_day_card': event.requiresDayCard"),
      );
      expect(coursePayload, contains("'season_aware': event.seasonAware"));
      expect(coursePayload, contains("'calendar_context': <String, dynamic>{"));
      expect(coursePayload, contains("'kemetic_month': context.kMonth"));
      expect(coursePayload, contains("'kemetic_day': context.kDay"));
      expect(coursePayload, contains("'decan_name': context.decanName"));
      expect(coursePayload, contains("'season': context.seasonKey"));
      expect(coursePayload, contains("'lens': lens.key"));
    },
  );

  test('mounted enrollment cluster uses safe join resolvers', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final mountedJoin = _sourceBetween(
      source,
      'Future<int> _addMaatFlowInstance({',
      'Future<EndFlowActionResult> _endFlowFromEventTarget',
    );

    for (final branch in _mountedSafeEnrollmentBranches) {
      final resolver = _sourceBetween(
        source,
        branch.resolverStart,
        '/// Create a user-owned *instance*',
      );
      final mountedBranch = _sourceBetween(
        mountedJoin,
        branch.branchStart,
        branch.branchEnd,
      );

      expect(
        resolver,
        contains(branch.safeResolver),
        reason: '${branch.name} must have a mounted safe resolver.',
      );
      expect(
        mountedBranch,
        contains(branch.mountedResolver),
        reason: '${branch.name} must use its mounted safe resolver.',
      );
      expect(
        mountedBranch,
        isNot(contains(branch.throwingNextApi)),
        reason:
            '${branch.name} mounted join must not call the throwing next-window API directly.',
      );
      expect(
        mountedBranch,
        isNot(contains(branch.throwingSelectedApi)),
        reason:
            '${branch.name} mounted join must not call the throwing selected-date API directly.',
      );
      expect(
        mountedBranch,
        contains('FlowJoinFailureCode.noEnrollmentWindow'),
        reason: '${branch.name} must return structured no-window failure.',
      );
    }
  });

  test(
    'migrated headless Ma_at enrollment branches stay service-backed inside _addMaatFlowInstanceHeadless',
    () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final headlessMethod = _sourceBetween(
        source,
        'static Future<int> _addMaatFlowInstanceHeadless',
        'static FlowRule ruleFromJson',
      );

      for (final branch in _serviceBackedHeadlessMaatEnrollmentBranches) {
        final headlessBranch = _sourceBetween(
          headlessMethod,
          branch.start,
          branch.end,
        );

        expect(
          headlessBranch,
          contains('FlowJoinService'),
          reason: '${branch.name} must delegate to FlowJoinService',
        );
        expect(
          headlessBranch,
          contains(branch.method),
          reason: '${branch.name} must call its service method',
        );
        expect(
          headlessBranch,
          contains('flowIdOrNegativeOne'),
          reason: '${branch.name} must preserve failure return semantics',
        );
        for (final marker in _directHeadlessPersistenceMarkers) {
          expect(
            headlessBranch,
            isNot(contains(marker)),
            reason:
                '${branch.name} should not directly persist headless enrollment events via $marker',
          );
        }
      }
    },
  );

  test(
    '_addMaatFlowInstanceHeadless has no inline Ma_at template persistence branches',
    () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final headlessMethod = _sourceBetween(
        source,
        'static Future<int> _addMaatFlowInstanceHeadless',
        'static FlowRule ruleFromJson',
      );
      final explicitTemplateBranches = _sourceBetween(
        headlessMethod,
        'if (template.kind == _MaatFlowTemplateKind.moonReturn)',
        'if (startDate == null) return -1;',
      );

      for (final marker in _directHeadlessPersistenceMarkers) {
        expect(
          explicitTemplateBranches,
          isNot(contains(marker)),
          reason:
              'Explicit headless Ma_at template branches must delegate to FlowJoinService instead of using $marker.',
        );
      }
      expect(
        _countOccurrences(explicitTemplateBranches, 'FlowJoinService'),
        _serviceBackedHeadlessMaatEnrollmentBranches.length,
        reason:
            'Each explicit headless Ma_at template branch needs a service delegate.',
      );
    },
  );

  test('Ma_at flow kind decisions route through the identity resolver', () {
    final calendarSource = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final mountedJoin = _sourceBetween(
      calendarSource,
      'Future<int> _addMaatFlowInstance({',
      'Future<EndFlowActionResult> _endFlowFromEventTarget',
    );

    expect(mountedJoin, contains('resolveMaatFlowKind'));
    expect(
      mountedJoin,
      isNot(contains("contains('maat=")),
      reason:
          'Mounted join duplicate checks must not reintroduce raw maat= matching.',
    );
    expect(
      mountedJoin,
      isNot(contains('notesDecode(flow.notes).maatKey')),
      reason: 'Mounted join kind checks must use maat_flow_identity.dart.',
    );

    final dayViewSource = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();
    final decanMilestonePanel = _sourceBetween(
      dayViewSource,
      'class _DecanWatchMilestonePanelState',
      'class _DaysOutsideYearLocalNotesPanel',
    );

    expect(decanMilestonePanel, contains('resolveMaatFlowKind'));
    expect(
      decanMilestonePanel,
      isNot(contains("metadata['flow_key']")),
      reason:
          'Decan milestone identity checks must use maat_flow_identity.dart.',
    );
  });
}

const _serviceBackedHeadlessMaatEnrollmentBranches = [
  (
    name: 'Moon Return',
    start: 'if (template.kind == _MaatFlowTemplateKind.moonReturn)',
    end: 'if (template.kind == _MaatFlowTemplateKind.theWag)',
    method: 'joinMoonReturnHeadless',
  ),
  (
    name: 'Wag',
    start: 'if (template.kind == _MaatFlowTemplateKind.theWag)',
    end: 'if (template.kind == _MaatFlowTemplateKind.daysOutsideTheYear)',
    method: 'joinWagHeadless',
  ),
  (
    name: 'Days Outside the Year',
    start: 'if (template.kind == _MaatFlowTemplateKind.daysOutsideTheYear)',
    end: 'if (template.kind == _MaatFlowTemplateKind.theOpenHand)',
    method: 'joinDaysOutsideYearHeadless',
  ),
  (
    name: 'Open Hand',
    start: 'if (template.kind == _MaatFlowTemplateKind.theOpenHand)',
    end: 'if (template.kind == _MaatFlowTemplateKind.theDjed)',
    method: 'joinOpenHandHeadless',
  ),
  (
    name: 'Djed',
    start: 'if (template.kind == _MaatFlowTemplateKind.theDjed)',
    end: 'if (template.kind == _MaatFlowTemplateKind.readingHouse)',
    method: 'joinDjedHeadless',
  ),
  (
    name: 'Reading House',
    start: 'if (template.kind == _MaatFlowTemplateKind.readingHouse)',
    end: 'if (template.kind == _MaatFlowTemplateKind.maatDecan)',
    method: 'joinReadingHouseHeadless',
  ),
  (
    name: 'Ma’at Decan',
    start: 'if (template.kind == _MaatFlowTemplateKind.maatDecan)',
    end: 'if (template.kind == _MaatFlowTemplateKind.decanWatch)',
    method: 'joinMaatDecanFlowHeadless',
  ),
  (
    name: 'Decan Watch',
    start: 'if (template.kind == _MaatFlowTemplateKind.decanWatch)',
    end: 'if (template.kind == _MaatFlowTemplateKind.dawnHouseRite)',
    method: 'joinDecanWatchHeadless',
  ),
  (
    name: 'Dawn House Rite',
    start: 'if (template.kind == _MaatFlowTemplateKind.dawnHouseRite)',
    end: 'if (template.kind == _MaatFlowTemplateKind.eveningThreshold)',
    method: 'joinDawnHouseRiteHeadless',
  ),
  (
    name: 'Evening Threshold',
    start: 'if (template.kind == _MaatFlowTemplateKind.eveningThreshold)',
    end: 'if (template.kind == _MaatFlowTemplateKind.eveningThresholdRite)',
    method: 'joinEveningThresholdHeadless',
  ),
  (
    name: 'Evening Threshold Rite',
    start: 'if (template.kind == _MaatFlowTemplateKind.eveningThresholdRite)',
    end: 'if (template.kind == _MaatFlowTemplateKind.theWeighing)',
    method: 'joinEveningThresholdRiteHeadless',
  ),
  (
    name: 'The Weighing',
    start: 'if (template.kind == _MaatFlowTemplateKind.theWeighing)',
    end: 'if (template.kind == _MaatFlowTemplateKind.offeringTable)',
    method: 'joinTheWeighingHeadless',
  ),
  (
    name: 'Offering Table',
    start: 'if (template.kind == _MaatFlowTemplateKind.offeringTable)',
    end: 'if (template.kind == _MaatFlowTemplateKind.theTending)',
    method: 'joinOfferingTableHeadless',
  ),
  (
    name: 'The Tending',
    start: 'if (template.kind == _MaatFlowTemplateKind.theTending)',
    end: 'if (template.kind == _MaatFlowTemplateKind.keptWord)',
    method: 'joinTheTendingHeadless',
  ),
  (
    name: 'Kept Word',
    start: 'if (template.kind == _MaatFlowTemplateKind.keptWord)',
    end: 'if (template.kind == _MaatFlowTemplateKind.theCourse)',
    method: 'joinKeptWordHeadless',
  ),
  (
    name: 'Course',
    start: 'if (template.kind == _MaatFlowTemplateKind.theCourse)',
    end: 'if (startDate == null) return -1;',
    method: 'joinTheCourseHeadless',
  ),
];

const _previewEnrollmentBranches = [
  (
    name: 'Moon Return',
    resolverStart:
        'MoonReturnEnrollmentWindow? _resolveMoonReturnPreviewWindow',
    resolverEnd: 'Widget _buildMoonReturnOccurrenceTile',
    resolverCall: '_resolveMoonReturnPreviewWindow()',
    scaffoldStart: 'Widget _buildMoonReturnScaffold',
    scaffoldEnd: 'Widget _buildCourseScaffold',
    throwingApi: 'moonReturnNextEnrollmentWindow',
  ),
  (
    name: 'Wag',
    resolverStart: 'WagEnrollmentWindow? _resolveWagPreviewWindow',
    resolverEnd: 'Widget _buildWagEventTile',
    resolverCall: '_resolveWagPreviewWindow()',
    scaffoldStart: 'Widget _buildWagScaffold',
    scaffoldEnd: 'DecanWatchEnrollmentWindow? _resolveDecanWatchPreviewWindow',
    throwingApi: 'wagNextEnrollmentWindow',
  ),
  (
    name: 'Decan Watch',
    resolverStart:
        'DecanWatchEnrollmentWindow? _resolveDecanWatchPreviewWindow',
    resolverEnd: 'Widget _buildDecanWatchOccurrenceTile',
    resolverCall: '_resolveDecanWatchPreviewWindow()',
    scaffoldStart: 'Widget _buildDecanWatchScaffold',
    scaffoldEnd: 'OpenHandEnrollmentWindow? _resolveOpenHandPreviewWindow',
    throwingApi: 'decanWatchNextEnrollmentWindow',
  ),
  (
    name: 'Open Hand',
    resolverStart: 'OpenHandEnrollmentWindow? _resolveOpenHandPreviewWindow',
    resolverEnd: 'Widget _buildOpenHandEventTile',
    resolverCall: '_resolveOpenHandPreviewWindow()',
    scaffoldStart: 'Widget _buildOpenHandScaffold',
    scaffoldEnd: 'DjedEnrollmentWindow? _resolveDjedPreviewWindow',
    throwingApi: 'openHandNextEnrollmentWindow',
  ),
  (
    name: 'Djed',
    resolverStart: 'DjedEnrollmentWindow? _resolveDjedPreviewWindow',
    resolverEnd: 'Widget _buildDjedEventTile',
    resolverCall: '_resolveDjedPreviewWindow()',
    scaffoldStart: 'Widget _buildDjedScaffold',
    scaffoldEnd:
        'DaysOutsideYearEnrollmentWindow? _resolveDaysOutsideYearPreviewWindow',
    throwingApi: 'djedNextEnrollmentWindow',
  ),
  (
    name: 'Days Outside the Year',
    resolverStart:
        'DaysOutsideYearEnrollmentWindow? _resolveDaysOutsideYearPreviewWindow',
    resolverEnd: 'Widget _buildDaysOutsideYearEventTile',
    resolverCall: '_resolveDaysOutsideYearPreviewWindow()',
    scaffoldStart: 'Widget _buildDaysOutsideYearScaffold',
    scaffoldEnd: 'Widget _buildMoonReturnScaffold',
    throwingApi: 'daysOutsideYearNextEnrollmentWindow',
  ),
];

const _maatEventDetailSourceFiles = [
  'lib/features/calendar/track_sky_flow.dart',
  'lib/features/calendar/dawn_house_rite_flow.dart',
  'lib/features/calendar/evening_threshold_rite_flow.dart',
  'lib/features/calendar/the_weighing_flow.dart',
  'lib/features/calendar/the_offering_table_flow.dart',
  'lib/features/calendar/the_tending_flow.dart',
  'lib/features/calendar/the_kept_word_flow.dart',
  'lib/features/calendar/the_course_flow.dart',
  'lib/features/calendar/moon_return_flow.dart',
  'lib/features/calendar/the_wag_flow.dart',
  'lib/features/calendar/the_decan_watch_flow.dart',
  'lib/features/calendar/the_days_outside_year_flow.dart',
  'lib/features/calendar/the_open_hand_flow.dart',
  'lib/features/calendar/the_djed_flow.dart',
  'lib/features/calendar/the_reading_house_flow.dart',
  'lib/features/calendar/maat_decan_flow.dart',
];

const _sensitiveMaatEventDetailSourceFiles = [
  'lib/features/calendar/the_tending_flow.dart',
  'lib/features/calendar/the_kept_word_flow.dart',
  'lib/features/calendar/the_wag_flow.dart',
  'lib/features/calendar/the_decan_watch_flow.dart',
  'lib/features/calendar/the_days_outside_year_flow.dart',
  'lib/features/calendar/the_open_hand_flow.dart',
  'lib/features/calendar/the_djed_flow.dart',
  'lib/features/calendar/the_reading_house_flow.dart',
];

const _previewInlineDetailBranches = [
  (
    name: 'Moon Return',
    start: 'Widget _buildMoonReturnOccurrenceTile',
    end: 'WagEnrollmentWindow? _resolveWagPreviewWindow',
    detailFunction: 'moonReturnDetailText',
  ),
  (
    name: 'Wag',
    start: 'Widget _buildWagEventTile',
    end: 'DecanWatchEnrollmentWindow? _resolveDecanWatchPreviewWindow',
    detailFunction: 'wagDetailText',
  ),
  (
    name: 'Decan Watch',
    start: 'Widget _buildDecanWatchOccurrenceTile',
    end: 'Widget _buildDecanWatchScaffold',
    detailFunction: 'decanWatchDetailText',
  ),
  (
    name: 'Open Hand',
    start: 'Widget _buildOpenHandEventTile',
    end: 'DecanWatchEnrollmentWindow? _resolveMaatDecanPreviewWindow',
    detailFunction: 'openHandDetailText',
  ),
  (
    name: 'Ma’at Decan',
    start: 'Widget _buildMaatDecanFlowEventTile',
    end: 'Widget _buildMaatDecanFlowScaffold',
    detailFunction: 'maatDecanFlowDetailText',
  ),
  (
    name: 'Djed',
    start: 'Widget _buildDjedEventTile',
    end:
        'DaysOutsideYearEnrollmentWindow? _resolveDaysOutsideYearPreviewWindow',
    detailFunction: 'djedDetailText',
  ),
  (
    name: 'Reading House',
    start: 'Widget _buildReadingHouseSittingTile',
    end: 'Widget _buildReadingHouseScaffold',
    detailFunction: 'readingHouseDetailText',
  ),
  (
    name: 'Days Outside the Year',
    start: 'Widget _buildDaysOutsideYearEventTile',
    end: 'Widget _buildDaysOutsideYearScaffold',
    detailFunction: 'daysOutsideDetailText',
  ),
];

const _mountedSafeEnrollmentBranches = [
  (
    name: 'Moon Return',
    resolverStart:
        'MoonReturnEnrollmentWindow? _resolveMountedMoonReturnJoinWindow',
    branchStart: 'if (template.kind == _MaatFlowTemplateKind.moonReturn)',
    branchEnd: 'if (template.kind == _MaatFlowTemplateKind.theWag)',
    mountedResolver: '_resolveMountedMoonReturnJoinWindow',
    safeResolver: 'resolveMoonReturnEnrollmentWindowSafely',
    throwingNextApi: 'moonReturnNextEnrollmentWindow(',
    throwingSelectedApi: 'moonReturnEnrollmentWindowForStartDate(',
  ),
  (
    name: 'Wag',
    resolverStart: 'WagEnrollmentWindow? _resolveMountedWagJoinWindow',
    branchStart: 'if (template.kind == _MaatFlowTemplateKind.theWag)',
    branchEnd: 'if (template.kind == _MaatFlowTemplateKind.daysOutsideTheYear)',
    mountedResolver: '_resolveMountedWagJoinWindow',
    safeResolver: 'resolveWagEnrollmentWindowSafely',
    throwingNextApi: 'wagNextEnrollmentWindow(',
    throwingSelectedApi: 'wagEnrollmentWindowForStartDate(',
  ),
  (
    name: 'Days Outside the Year',
    resolverStart:
        'DaysOutsideYearEnrollmentWindow? _resolveMountedDaysOutsideYearJoinWindow',
    branchStart:
        'if (template.kind == _MaatFlowTemplateKind.daysOutsideTheYear)',
    branchEnd: 'if (template.kind == _MaatFlowTemplateKind.maatDecan)',
    mountedResolver: '_resolveMountedDaysOutsideYearJoinWindow',
    safeResolver: 'resolveDaysOutsideYearEnrollmentWindowSafely',
    throwingNextApi: 'daysOutsideYearNextEnrollmentWindow(',
    throwingSelectedApi: 'daysOutsideYearEnrollmentWindowForStartDate(',
  ),
  (
    name: 'Ma’at Decan',
    resolverStart:
        'DecanWatchEnrollmentWindow? _resolveMountedDecanWatchJoinWindow',
    branchStart: 'if (template.kind == _MaatFlowTemplateKind.maatDecan)',
    branchEnd: 'if (template.kind == _MaatFlowTemplateKind.theOpenHand)',
    mountedResolver: '_resolveMountedDecanWatchJoinWindow',
    safeResolver: 'resolveDecanWatchEnrollmentWindowSafely',
    throwingNextApi: 'decanWatchNextEnrollmentWindow(',
    throwingSelectedApi: 'decanWatchEnrollmentWindowForStartDate(',
  ),
  (
    name: 'Open Hand',
    resolverStart:
        'OpenHandEnrollmentWindow? _resolveMountedOpenHandJoinWindow',
    branchStart: 'if (template.kind == _MaatFlowTemplateKind.theOpenHand)',
    branchEnd: 'if (template.kind == _MaatFlowTemplateKind.theDjed)',
    mountedResolver: '_resolveMountedOpenHandJoinWindow',
    safeResolver: 'resolveOpenHandEnrollmentWindowSafely',
    throwingNextApi: 'openHandNextEnrollmentWindow(',
    throwingSelectedApi: 'openHandEnrollmentWindowForStartDate(',
  ),
  (
    name: 'Djed',
    resolverStart: 'DjedEnrollmentWindow? _resolveMountedDjedJoinWindow',
    branchStart: 'if (template.kind == _MaatFlowTemplateKind.theDjed)',
    branchEnd: 'if (template.kind == _MaatFlowTemplateKind.readingHouse)',
    mountedResolver: '_resolveMountedDjedJoinWindow',
    safeResolver: 'resolveDjedEnrollmentWindowSafely',
    throwingNextApi: 'djedNextEnrollmentWindow(',
    throwingSelectedApi: 'djedEnrollmentWindowForStartDate(',
  ),
  (
    name: 'Decan Watch',
    resolverStart:
        'DecanWatchEnrollmentWindow? _resolveMountedDecanWatchJoinWindow',
    branchStart: 'if (template.kind == _MaatFlowTemplateKind.decanWatch)',
    branchEnd: 'if (template.kind == _MaatFlowTemplateKind.dawnHouseRite)',
    mountedResolver: '_resolveMountedDecanWatchJoinWindow',
    safeResolver: 'resolveDecanWatchEnrollmentWindowSafely',
    throwingNextApi: 'decanWatchNextEnrollmentWindow(',
    throwingSelectedApi: 'decanWatchEnrollmentWindowForStartDate(',
  ),
];

const _flowJoinSafeDefaultEnrollmentResolvers = [
  (
    name: 'Moon Return',
    resolverStart:
        'static MoonReturnEnrollmentWindow? _defaultResolveMoonReturnWindow',
    resolverEnd: 'static List<MoonReturnOccurrence>',
    safeResolver: 'resolveMoonReturnEnrollmentWindowSafely',
    throwingNextApi: 'moonReturnNextEnrollmentWindow(',
    throwingSelectedApi: 'moonReturnEnrollmentWindowForStartDate(',
  ),
  (
    name: 'Wag',
    resolverStart: 'static WagEnrollmentWindow? _defaultResolveWagWindow',
    resolverEnd: 'static WagOccurrenceSchedule',
    safeResolver: 'resolveWagEnrollmentWindowSafely',
    throwingNextApi: 'wagNextEnrollmentWindow(',
    throwingSelectedApi: 'wagEnrollmentWindowForStartDate(',
  ),
  (
    name: 'Days Outside the Year',
    resolverStart:
        'static DaysOutsideYearEnrollmentWindow? _defaultResolveDaysOutsideYearWindow',
    resolverEnd: 'static DaysOutsideOccurrenceSchedule',
    safeResolver: 'resolveDaysOutsideYearEnrollmentWindowSafely',
    throwingNextApi: 'daysOutsideYearNextEnrollmentWindow(',
    throwingSelectedApi: 'daysOutsideYearEnrollmentWindowForStartDate(',
  ),
  (
    name: 'Decan Watch',
    resolverStart:
        'static DecanWatchEnrollmentWindow? _defaultResolveDecanWatchWindow',
    resolverEnd: 'static List<DecanWatchOccurrence>',
    safeResolver: 'resolveDecanWatchEnrollmentWindowSafely',
    throwingNextApi: 'decanWatchNextEnrollmentWindow(',
    throwingSelectedApi: 'decanWatchEnrollmentWindowForStartDate(',
  ),
  (
    name: 'Open Hand',
    resolverStart:
        'static OpenHandEnrollmentWindow? _defaultResolveOpenHandWindow',
    resolverEnd: 'static OpenHandOccurrenceSchedule',
    safeResolver: 'resolveOpenHandEnrollmentWindowSafely',
    throwingNextApi: 'openHandNextEnrollmentWindow(',
    throwingSelectedApi: 'openHandEnrollmentWindowForStartDate(',
  ),
  (
    name: 'Djed',
    resolverStart: 'static DjedEnrollmentWindow? _defaultResolveDjedWindow',
    resolverEnd: 'static DjedOccurrenceSchedule',
    safeResolver: 'resolveDjedEnrollmentWindowSafely',
    throwingNextApi: 'djedNextEnrollmentWindow(',
    throwingSelectedApi: 'djedEnrollmentWindowForStartDate(',
  ),
];

const _directHeadlessPersistenceMarkers = [
  'UserEventsRepo(Supabase.instance.client)',
  '.upsertFlow(',
  '.upsertByClientId(',
  '_fileHeadlessEventDelivery(',
  '_publishHeadlessCalendarInvalidation(',
];

String _sourceBetween(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  expect(start, isNonNegative, reason: 'missing start marker $startMarker');
  final end = source.indexOf(endMarker, start);
  expect(end, isNonNegative, reason: 'missing end marker $endMarker');
  return source.substring(start, end);
}

int _countOccurrences(String source, String needle) {
  var count = 0;
  var index = 0;
  while (true) {
    index = source.indexOf(needle, index);
    if (index < 0) return count;
    count++;
    index += needle.length;
  }
}

void _expectPersistsBeforeAlertFiling(
  String branch, {
  required String caller,
  required String branchName,
}) {
  final eventPersistIndex = branch.indexOf(caller);
  expect(
    eventPersistIndex,
    isNonNegative,
    reason: '$branchName must persist its user_event row.',
  );

  final alertFilingIndex = branch.indexOf('await _scheduleAlertForEvent(');
  expect(
    alertFilingIndex,
    isNonNegative,
    reason: '$branchName must file alert delivery.',
  );
  expect(
    eventPersistIndex,
    lessThan(alertFilingIndex),
    reason:
        '$branchName must persist the backing user_event before notification filing can reconcile it.',
  );
}

void _expectMountedBranchUsesExplicitNoAlert(
  String branch, {
  required String branchName,
}) {
  expect(
    branch,
    contains('alertOffsetMinutes: _alertNoneMinutes'),
    reason: '$branchName must encode no-alert intent explicitly.',
  );
  expect(
    branch,
    isNot(contains('alertOffsetMinutes: 0')),
    reason: '$branchName must not file at-time alerts by default.',
  );
  expect(
    branch,
    contains('await _scheduleAlertForEvent('),
    reason: '$branchName should still route through no-alert cancellation.',
  );
}
