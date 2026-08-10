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

  test('Ma_at preview event cells expand inline with full details', () {
    final source = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();

    expect(source, contains('Widget _buildExpandableFlowEventTile'));
    expect(source, contains('AnimatedSize'));
    expect(source, contains('_expandedMaatEventKey'));
    expect(source, contains('_MyFlowDayContentCard'));
    expect(source, isNot(contains('ExpansionTile')));
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

  test(
    'headless flow studio defers delivery and invalidation through shared API',
    () {
      final pageSource = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final serviceSource = File(
        'lib/features/calendar/flow_join_service.dart',
      ).readAsStringSync();
      final headlessPersist = _sourceBetween(
        pageSource,
        'static Future<int?> _persistFlowStudioResultHeadless',
        'static Future<({int flowId, bool didStageEvents})?> importFlowFromShare',
      );
      final sharedPersist = _sourceBetween(
        serviceSource,
        'FlowJoinResult stagePlannedNotesAndDeferPersist',
        'Future<int> _upsertFlowRow',
      );

      expect(headlessPersist, contains('stagePlannedNotesAndDeferPersist'));
      expect(
        headlessPersist,
        isNot(contains('await userEventsRepo.upsertByClientId')),
      );
      expect(sharedPersist, contains('_fileHeadlessEventDelivery'));
      expect(sharedPersist, contains('_publishHeadlessCalendarInvalidation'));
      expect(
        headlessPersist,
        contains('CalendarInvalidationReason.flowStudioPersisted'),
      );
    },
  );

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
    final pageSource = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final coordinatorSource = File(
      'lib/features/calendar/calendar_load_coordinator.dart',
    ).readAsStringSync();

    expect(pageSource, contains('_loadCoordinator.attach()'));
    expect(pageSource, contains('_loadCoordinator.dispose()'));
    expect(pageSource, isNot(contains('_handleCalendarInvalidated')));
    expect(pageSource, isNot(contains('_flushCalendarInvalidationReload')));

    final attach = _sourceBetween(
      coordinatorSource,
      'void attach() {',
      'void _drainBusBacklog()',
    );
    expect(attach, contains('_bus.stream.listen'));
    expect(attach, contains('_drainBusBacklog()'));

    final drain = _sourceBetween(
      coordinatorSource,
      'void _drainBusBacklog() {',
      'void _schedule(CalendarInvalidationReason reason',
    );
    expect(drain, contains('_bus.peekPendingAfter(_scheduledRevision)'));
    expect(drain, contains('_schedule(pending.invalidation.reason'));

    final schedule = _sourceBetween(
      coordinatorSource,
      'void _schedule(CalendarInvalidationReason reason',
      'void _flush() {',
    );
    expect(schedule, contains('_pending = true'));
    expect(schedule, contains('_debounceTimer?.cancel()'));
    expect(schedule, contains('Timer(_debounce, _flush)'));

    final flush = _sourceBetween(
      coordinatorSource,
      'void _flush() {',
      'void dispose() {',
    );
    expect(flush, contains('preserveViewport: true'));
    expect(flush, contains('_bus.markConsumed(revision)'));
    expect(flush, contains("source: 'invalidation:"));
    expect(flush, isNot(contains('_loadFromDisk(')));
  });

  test('all Ma_at service joins call the universal staged completion', () {
    final source = File(
      'lib/features/calendar/flow_join_service.dart',
    ).readAsStringSync();

    expect(_countOccurrences(source, 'stagePlannedNotesAndDeferPersist('), 19);
    expect(
      _countOccurrences(
        source,
        'FlowJoinResult stagePlannedNotesAndDeferPersist',
      ),
      1,
    );
    expect(source, isNot(contains('_stageAndDeferPersist')));
    expect(source, isNot(contains('_completeHeadlessJoin')));
    expect(source, contains('joinTrackSkyHeadless'));
    expect(source, contains('_joinSequenceHeadless'));
    expect(source, contains('_repo.upsertManyDeterministic(rows)'));
  });

  test('mounted and detached Ma_at joins stage the same service result', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final headless = _sourceBetween(
      source,
      'static Future<int> _addMaatFlowInstanceHeadless',
      'static Future<EndFlowOutcome> _endFlowHeadless',
    );
    final mounted = _sourceBetween(
      source,
      'Future<int> _addMaatFlowInstance({',
      '_MountedFlowEndPatch _optimisticallyPatchEndedFlow',
    );

    expect(headless, contains('int stageResult(FlowJoinResult result)'));
    expect(headless, contains('_stageFlowForDeferredPersistence('));
    expect(headless, contains('joinTrackSkyHeadless'));
    expect(headless, contains('_joinSequenceHeadless'));
    expect(
      headless,
      isNot(contains('if (template.kind == _MaatFlowTemplateKind.theCourse)')),
    );
    expect(mounted, contains('_addMaatFlowInstanceHeadless('));
    expect(mounted, contains('_applyPendingStagedFlow(flowId)'));
    expect(mounted, isNot(contains('upsertManyDeterministic')));
  });

  test('Ma_at join completion never hydrates to rediscover staged notes', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();

    expect(
      source,
      isNot(contains("_loadFromDisk(source: 'maat_join_day_view')")),
    );
    expect(
      source,
      isNot(contains("_loadFromDisk(source: 'maat_decan_flow_join')")),
    );
    expect(
      source,
      isNot(contains("_loadFromDisk(source: 'evening_threshold_join')")),
    );
    expect(source, contains('Could not stage the first day of this flow.'));
    expect(source, contains('_openDayViewForStagedFlow(flowId)'));
  });

  test('universal staging boundary contains no Ma_at-named symbols', () {
    final pageSource = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final serviceSource = File(
      'lib/features/calendar/flow_join_service.dart',
    ).readAsStringSync();

    final api = _sourceBetween(
      serviceSource,
      'FlowJoinResult stagePlannedNotesAndDeferPersist',
      'Future<int> _upsertFlowRow',
    );
    final pendingType = _sourceBetween(
      pageSource,
      'class _PendingStagedFlow',
      'class CalendarPage extends StatefulWidget',
    );
    final pendingFields = _sourceBetween(
      pageSource,
      'static int? _pendingStagedFlowDayViewFlowId',
      'static _SharedCalendarRealDayViewIntent?',
    );
    final persistenceHelpers = _sourceBetween(
      pageSource,
      'static void _stageFlowForDeferredPersistence',
      'static FlowDetailActionPolicy resolveCanonicalCustomFlowActionPolicy',
    );
    final completionHelpers = _sourceBetween(
      pageSource,
      'void _openDayViewForStagedFlow',
      'Future<void> _completeMountedMaatJoinWithDayView',
    );

    for (final boundary in <String>[
      api,
      pendingType,
      pendingFields,
      persistenceHelpers,
      completionHelpers,
    ]) {
      expect(boundary.toLowerCase(), isNot(contains('maat')));
    }
    for (final retired in <String>[
      '_stageMaatJoinFastPath',
      '_applyPendingMaatJoinFastPath',
      '_pendingMaatJoinDayViewFlowId',
      '_openDayViewForJoinedMaatFlow',
    ]) {
      expect(pageSource, isNot(contains(retired)));
    }
  });
}

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
    end: 'Widget _buildDjedScaffold',
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
