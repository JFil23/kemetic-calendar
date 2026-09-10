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
      'lib/features/calendar/calendar_active_maat_flows.dart',
    ).readAsStringSync();

    expect(source, contains('_flowMatchesActiveMaatTemplate'));
    expect(source, contains("reason: 'open_maat_flows'"));
    expect(source, contains('flowsRepo.refreshMyFiledFlows()'));
    expect(source, contains('isFlowScheduleOpenLocally'));
    expect(listSource, contains('class _MaatFlowsListPageWithSnapshot'));
  });

  test('retained date pickers declare their approved initial modes', () {
    final readingHouse = File(
      'lib/features/calendar/the_reading_house/presentation/'
      'reading_house_sitting_editor.dart',
    ).readAsStringSync();
    final offeringTable = File(
      'lib/features/calendar/the_offering_table/presentation/'
      'offering_table_detail_page.dart',
    ).readAsStringSync();

    expect(readingHouse, contains('MaatFlowDatePicker.show'));
    expect(readingHouse, contains('MaatFlowDatePickerMode.kemetic'));
    expect(offeringTable, contains('MaatFlowDatePicker.show'));
    expect(offeringTable, contains('MaatFlowDatePickerMode.gregorian'));
    expect(readingHouse, isNot(contains('showDatePicker(')));
    expect(offeringTable, isNot(contains('showDatePicker(')));
  });

  test('active product details delegate to five dedicated surfaces', () {
    final source = File(
      'lib/features/calendar/calendar_active_maat_flows.dart',
    ).readAsStringSync();

    expect(source, contains('Widget _buildFollowSky()'));
    expect(source, contains('Widget _buildOfferingTable()'));
    expect(source, contains('Widget _buildReadingHouse()'));
    expect(source, contains('Widget _buildDjed()'));
    expect(source, isNot(contains('Widget _buildDjedEventTile')));
    expect(source, isNot(contains('Widget _buildWagEventTile')));
    expect(source, isNot(contains('Widget _buildMoonReturnOccurrenceTile')));
  });

  test('retired product implementation sources are absent', () {
    for (final path in const <String>[
      'lib/features/calendar/dawn_house_rite_flow.dart',
      'lib/features/calendar/evening_threshold_rite_flow.dart',
      'lib/features/calendar/the_weighing_flow.dart',
      'lib/features/calendar/the_tending_flow.dart',
      'lib/features/calendar/the_kept_word_flow.dart',
      'lib/features/calendar/the_wag_flow.dart',
      'lib/features/calendar/the_wag_scheduler.dart',
      'lib/features/calendar/the_wag_enrollment.dart',
      'lib/features/calendar/the_days_outside_year_flow.dart',
      'lib/features/calendar/the_days_outside_year_scheduler.dart',
      'lib/features/calendar/the_days_outside_year_enrollment.dart',
    ]) {
      expect(File(path).existsSync(), isFalse, reason: path);
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
    'retired enrollment preview scaffolds are absent from active details',
    () {
      final source = File(
        'lib/features/calendar/calendar_active_maat_flows.dart',
      ).readAsStringSync();

      for (final retiredBuilder in const <String>[
        '_buildMoonReturnScaffold',
        '_buildWagScaffold',
        '_buildDecanWatchScaffold',
        '_buildOpenHandScaffold',
        '_buildDaysOutsideYearScaffold',
      ]) {
        expect(source, isNot(contains(retiredBuilder)), reason: retiredBuilder);
      }
      expect(source, contains('Widget _buildDjed()'));
      expect(source, contains('ArchivedMaatFlowDetailView('));
    },
  );

  test('active detail enrollment keeps safe temporal boundaries', () {
    final active = File(
      'lib/features/calendar/calendar_active_maat_flows.dart',
    ).readAsStringSync();
    final service = File(
      'lib/features/calendar/flow_join_service.dart',
    ).readAsStringSync();

    expect(
      active,
      contains('djedNextEnrollmentWindow(_timezone).opensAtLocal'),
    );
    expect(active, contains('initialStartDate: widget.joinedFlow?.start'));
    expect(service, contains('_resolveDjedWindow('));
    expect(service, contains('_resolveTemporalStart('));
    expect(service, contains('FlowJoinFailureCode.noEnrollmentWindow'));
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
    final bridgeSource = File(
      'lib/features/calendar/hydration/calendar_hydration_invalidation_bridge.dart',
    ).readAsStringSync();

    expect(pageSource, contains('_hydrationInvalidationBridge.attach()'));
    expect(pageSource, contains('_hydrationInvalidationBridge.dispose()'));
    expect(pageSource, isNot(contains('_handleCalendarInvalidated')));
    expect(pageSource, isNot(contains('_flushCalendarInvalidationReload')));

    final attach = _sourceBetween(
      bridgeSource,
      'void attach() {',
      'void _drain() {',
    );
    expect(attach, contains('_bus.stream.listen'));
    expect(attach, contains('_drain()'));

    final drain = _sourceBetween(
      bridgeSource,
      'void _drain() {',
      'void _flush() {',
    );
    expect(drain, contains('_bus.peekPendingAfter(_scheduledRevision)'));
    expect(drain, contains('_pending = next.invalidation'));
    expect(drain, contains('_timer?.cancel()'));
    expect(drain, contains('Timer(_debounce, _flush)'));

    final flush = _sourceBetween(
      bridgeSource,
      'void _flush() {',
      'void dispose() {',
    );
    expect(flush, contains('_bus.markConsumed(revision)'));
    expect(flush, contains('_onInvalidation(invalidation)'));
  });

  test('core-flow joins cross the universal staging authority', () {
    final page = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final active = File(
      'lib/features/calendar/calendar_active_maat_flows.dart',
    ).readAsStringSync();
    final service = File(
      'lib/features/calendar/flow_join_service.dart',
    ).readAsStringSync();

    expect(
      page,
      contains('if (!isMaatFlowNewJoinAllowed(template.key)) return -1;'),
    );
    expect(active, contains('joinTrackSkyV2Headless'));
    expect(active, contains('_joinOfferingTableFromDetailAuthority'));
    expect(active, contains('Future<void> _joinDjed('));
    expect(active, contains('ReadingHouseAuthority'));
    expect(page, contains('_stageHeadlessMaatFlowJoinResult('));
    expect(service, contains('stagePlannedNotesAndDeferPersist('));
    expect(service, isNot(contains('_stageAndDeferPersist')));
    expect(service, isNot(contains('_completeHeadlessJoin')));
  });

  test('mounted and detached active joins share staging and policy gates', () {
    final page = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final active = File(
      'lib/features/calendar/calendar_active_maat_flows.dart',
    ).readAsStringSync();
    final headless = _sourceBetween(
      page,
      'static Future<int> _addMaatFlowInstanceHeadless',
      'static Future<EndFlowOutcome> _endFlowHeadless',
    );
    final mounted = _sourceBetween(
      page,
      'Future<int> _addMaatFlowInstance({',
      '_MountedFlowEndPatch _optimisticallyPatchEndedFlow',
    );

    expect(headless, contains('isMaatFlowNewJoinAllowed(template.key)'));
    expect(headless, contains('_stageHeadlessMaatFlowJoinResult('));
    expect(mounted, contains('_addMaatFlowInstanceHeadless('));
    expect(mounted, contains('_applyPendingStagedFlow(flowId)'));
    expect(active, contains('_stageHeadlessMaatFlowJoinResult('));
    expect(active, contains('_joinOfferingTableFromDetailAuthority('));
    expect(active, contains('completionRequired: false'));
  });

  test(
    'Day View flow visuals fall back to pending staged flow when catalog misses',
    () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();

      final helper = _sourceBetween(
        source,
        '_Flow? _visualFlowForNote(_Note note)',
        'Color _noteColor(_Note note)',
      );
      expect(helper, contains('for (final flow in _flows)'));
      expect(
        helper,
        contains('CalendarPage._pendingStagedFlows[id]?.localFlow'),
      );
      expect(helper, isNot(contains('firstWhere')));

      final noteColor = _sourceBetween(
        source,
        'Color _noteColor(_Note note)',
        'String? _flowName(_Note note)',
      );
      expect(noteColor, contains('_visualFlowForNote(note)'));
      expect(noteColor, contains('note.manualColor'));
      expect(noteColor, contains('note.isReminder'));
      expect(noteColor, isNot(contains('firstWhere')));

      final flowName = _sourceBetween(
        source,
        'String? _flowName(_Note note)',
        'List<_CalendarAction> _calendarActions',
      );
      expect(flowName, contains('_visualFlowForNote(note)?.name'));
      expect(flowName, isNot(contains('firstWhere')));
    },
  );

  test('instrument sheets and flow-owned previews keep distinct authorities', () {
    final shared = File(
      'lib/features/calendar/presentation/instrument_event_presentation_frame.dart',
    ).readAsStringSync();
    final dayView = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();
    final offering = File(
      'lib/features/calendar/the_offering_table/presentation/offering_table_detail_page.dart',
    ).readAsStringSync();
    final offeringPreview = File(
      'lib/features/calendar/the_offering_table/presentation/offering_table_preview_day_sheet.dart',
    ).readAsStringSync();

    expect(shared, contains('class InstrumentEventSheetHost'));
    expect(shared, contains('delta / availableSheetHeight'));
    expect(dayView, contains('InstrumentEventSheetHost('));
    expect(dayView, contains('showCalendarEventDetailSheetModal<void>('));
    expect(dayView, isNot(contains('_instrumentSheetExtent')));
    expect(offering, contains('showOfferingTablePreviewDaySheet('));
    expect(offeringPreview, contains('class OfferingTablePreviewDaySheet'));
    expect(offeringPreview, isNot(contains('InstrumentEventSheetHost(')));
    expect(offeringPreview, isNot(contains('delta / availableSheetHeight')));
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

const _maatEventDetailSourceFiles = [
  'lib/features/calendar/track_sky_flow.dart',
  'lib/features/calendar/the_offering_table_flow.dart',
  'lib/features/calendar/the_course_flow.dart',
  'lib/features/calendar/moon_return_flow.dart',
  'lib/features/calendar/the_decan_watch_flow.dart',
  'lib/features/calendar/the_open_hand_flow.dart',
  'lib/features/calendar/the_djed_flow.dart',
  'lib/features/calendar/the_reading_house_flow.dart',
  'lib/features/calendar/maat_decan_flow.dart',
];

const _sensitiveMaatEventDetailSourceFiles = [
  'lib/features/calendar/the_decan_watch_flow.dart',
  'lib/features/calendar/the_open_hand_flow.dart',
  'lib/features/calendar/the_djed_flow.dart',
  'lib/features/calendar/the_reading_house_flow.dart',
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
