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
        contains(r'First dawn: ${_dateLabel(context, selectedStart)}'),
      );
      expect(
        source,
        contains(r'First evening: ${_dateLabel(context, selectedStart)}'),
      );
      expect(
        source,
        contains(r'First sitting: ${_dateLabel(context, selectedStart)}'),
      );
      expect(
        source,
        isNot(contains(r'Start: ${_fmtGregorian(selectedStart)}')),
      );
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
      'List<OnboardingSlide> _buildOnboardingSlides',
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
      'if (template.kind == _MaatFlowTemplateKind.decanWatch)',
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
      'Future<FlowJoinResult> joinDawnHouseRiteHeadless',
    );

    expect(djedService, contains('djed_join_headless'));
    expect(djedService, contains('_fileHeadlessJoinDelivery'));
    expect(djedService, contains('alertOffsetMinutes: alertOffsetMinutes'));
    expect(_countOccurrences(djedService, '_completeHeadlessJoin'), 1);
  });

  test('headless Dawn House Rite delegates to FlowJoinService', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final dawnHouseRiteHeadless = _sourceBetween(
      source,
      'if (template.kind == _MaatFlowTemplateKind.dawnHouseRite)',
      'if (template.kind == _MaatFlowTemplateKind.eveningThresholdRite)',
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
        'Future<FlowJoinResult> joinTheWeighingHeadless',
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
      'Future<FlowJoinResult> joinKeptWordHeadless',
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

  test('mounted Moon Return and Wag persist events before filing alerts', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final mountedJoin = _sourceBetween(
      source,
      'Future<int> _addMaatFlowInstance({',
      'Future<bool> _endFlowFromEventTarget',
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
      'if (template.kind == _MaatFlowTemplateKind.decanWatch)',
    );
    _expectPersistsBeforeAlertFiling(
      wagBranch,
      caller: "caller: 'wag_join'",
      branchName: 'mounted Wag',
    );
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
      'Future<bool> _endFlowFromEventTarget',
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
    end: 'if (template.kind == _MaatFlowTemplateKind.decanWatch)',
    method: 'joinDjedHeadless',
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
    end: 'if (template.kind == _MaatFlowTemplateKind.eveningThresholdRite)',
    method: 'joinDawnHouseRiteHeadless',
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
