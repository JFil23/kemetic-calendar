import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shared calendar upcoming event tap navigation', () {
    test(
      'calendar sheet rows dismiss and restore Day View event detail',
      () async {
        final sheet = await File(
          'lib/features/calendars/shared_calendars_sheet.dart',
        ).readAsString();
        final calendar = await File(
          'lib/features/calendar/calendar_page.dart',
        ).readAsString();

        final tapHandler = _sourceBetween(
          sheet,
          'void _openCalendarEvent(',
          'Future<void> _leaveCalendar',
        );
        expect(tapHandler, contains('widget.onEventTapRequested'));
        expect(
          tapHandler,
          contains('Navigator.of(context, rootNavigator: true).pop(_changed)'),
        );
        expect(tapHandler, contains('_calendarEventsById[calendar.id]'));
        expect(tapHandler, contains('addPostFrameCallback'));
        expect(
          tapHandler,
          contains(
            'handler(calendar, filedEvent, calendarEvents: calendarEvents)',
          ),
        );

        final row = _sourceBetween(
          sheet,
          'Widget _calendarEventRow(',
          'String _eventMetaText',
        );
        expect(row, contains('InkWell'));
        expect(row, contains('onTap: canOpenEvent'));
        expect(row, contains('_openCalendarEvent(calendar, filedEvent)'));
        expect(row, isNot(contains('_addEventToCalendar(')));

        final snapshot = _sourceBetween(
          calendar,
          'class _SharedCalendarEventDetailSnapshot',
          'class CalendarPage extends StatefulWidget',
        );
        expect(snapshot, contains('final String title'));
        expect(snapshot, contains('final String? detail'));
        expect(snapshot, contains('final String? location'));
        expect(snapshot, contains('final DateTime startsAtLocal'));
        expect(snapshot, contains('final DateTime? endsAtLocal'));
        expect(snapshot, contains('final String? calendarId'));
        expect(snapshot, contains('final SharedCalendarSummary calendar'));
        expect(snapshot, contains('final String? eventId'));
        expect(snapshot, contains('final String? clientEventId'));
        expect(snapshot, contains('final Color? calendarColor'));

        final snapshotBuilder = _sourceBetween(
          calendar,
          'static _SharedCalendarEventDetailSnapshot\n'
              '  _sharedCalendarEventDetailSnapshotForFiledEvent({',
          'static EventDetailRestorationState?\n'
              '  _eventDetailRestorationStateForFiledCalendarEvent({',
        );
        expect(
          snapshotBuilder,
          contains('required SharedCalendarSummary calendar'),
        );
        expect(snapshotBuilder, contains('required FiledEvent filedEvent'));
        expect(
          snapshotBuilder,
          contains('_decodeDetailMetadata(event.detail)'),
        );
        expect(snapshotBuilder, contains('_cleanDetail(decodedDetail.detail)'));
        expect(snapshotBuilder, contains('event.calendarColor'));
        expect(snapshotBuilder, contains('filedEvent.calendar.color'));
        expect(snapshotBuilder, contains('calendar.colorValue'));

        final identity = _sourceBetween(
          calendar,
          'static EventDetailRestorationState?\n'
              '  _eventDetailRestorationStateForFiledCalendarEvent({',
          'static Future<void> openFiledCalendarEventFromAnyContext',
        );
        expect(identity, contains('filedEvent.event'));
        expect(identity, contains('event.clientEventId?.trim()'));
        expect(identity, contains('eventDetailIdentityClientEventId'));
        expect(identity, contains('event.id.trim()'));
        expect(identity, contains('eventDetailIdentityEventId'));

        final opener = _sourceBetween(
          calendar,
          'static Future<void> openFiledCalendarEventFromAnyContext',
          'static Future<void> openMyFlowsFromAnyContext',
        );
        expect(opener, contains('required SharedCalendarSummary calendar'));
        expect(opener, contains('List<FiledEvent> calendarEvents = const []'));
        expect(opener, contains('KemeticMath.fromGregorian(localStart)'));
        expect(
          opener,
          contains('_sharedCalendarEventDetailSnapshotForFiledEvent'),
        );
        expect(opener, contains('_sameDayFiledEvents('));
        expect(opener, contains('_seedSameDaySharedCalendarFiledEvents('));
        expect(opener, contains('_seedOneShotSharedCalendarEventSnapshot('));
        expect(opener, contains('unawaited(mountedHost._loadCalendarState())'));
        expect(
          opener,
          contains("source: 'shared_calendar_event_tap_background'"),
        );
        expect(opener, contains('_openDayView('));
        expect(opener, contains('initialEventDetailRestorationState: detail'));
        expect(
          opener,
          contains("debugOpenSource: 'shared_calendar_event_tap'"),
        );
        final mountedOpenIndex = opener.indexOf('_openDayView(');
        final mountedHydrationIndex = opener.indexOf(
          "source: 'shared_calendar_event_tap_background'",
        );
        expect(mountedOpenIndex, isNonNegative);
        expect(mountedHydrationIndex, isNonNegative);
        expect(mountedOpenIndex, lessThan(mountedHydrationIndex));
        expect(opener, contains('_loadWarmStartSearchSnapshot()'));
        expect(opener, contains('_loadWarmCalendarStateSnapshot()'));
        expect(opener, contains('_pendingSharedCalendarRealDayViewIntent ='));
        expect(opener, contains('warmStartNotes: warmStartSnapshot.notes'));
        expect(opener, contains('warmStartFlows: warmStartSnapshot.flows'));
        expect(
          opener,
          contains(
            'warmCalendarSummariesById: <String, SharedCalendarSummary>{',
          ),
        );
        expect(
          opener,
          contains(
            'warmHiddenCalendarIds: warmCalendarSnapshot.hiddenCalendarIds',
          ),
        );
        expect(opener, contains('sameCalendarEvents: sameDayEvents'));
        expect(opener, contains("GoRouter.of(context).go('/')"));
        expect(opener, contains('_clearDetachedCalendarOverlayState('));
        expect(opener, contains('_kCalendarOverlayKindSharedCalendars'));
        final intentIndex = opener.indexOf(
          '_pendingSharedCalendarRealDayViewIntent =',
        );
        final routeHomeIndex = opener.indexOf("GoRouter.of(context).go('/')");
        final clearDetachedIndex = opener.indexOf(
          '_clearDetachedCalendarOverlayState',
        );
        expect(intentIndex, isNonNegative);
        expect(routeHomeIndex, isNonNegative);
        expect(clearDetachedIndex, isNonNegative);
        expect(intentIndex, lessThan(routeHomeIndex));
        expect(routeHomeIndex, lessThan(clearDetachedIndex));
        expect(opener, contains('detail: detail'));
        expect(opener, contains('snapshot: snapshot'));
        expect(opener, isNot(contains('_routeHomeForSearchResult(')));
        expect(opener, isNot(contains('context.go(')));
        expect(opener, isNot(contains('MaterialPageRoute<void>(')));
        expect(opener, isNot(contains('builder: (_) => CalendarPage()')));
        expect(opener, isNot(contains('sharedCalendarEventSnapshot')));
        expect(opener, isNot(contains('DayViewPage(')));
        expect(opener, isNot(contains('return <NoteData>[snapshotNote]')));
        expect(opener, isNot(contains('await mountedHost._loadFromDisk')));
        expect(opener, isNot(contains("source: 'shared_calendar_event_tap')")));
        expect(opener, isNot(contains('_openDaySheet(')));
        expect(opener, isNot(contains('saveDurableLaunchRoute')));
        expect(opener, isNot(contains('SessionResumeService')));
      },
    );

    test(
      'real cached day intent opens before hydration and avoids dummy route',
      () async {
        final calendar = await File(
          'lib/features/calendar/calendar_page.dart',
        ).readAsString();

        expect(
          calendar,
          isNot(contains('_pushOneShotSharedCalendarEventDayView')),
        );
        expect(calendar, isNot(contains('return <NoteData>[snapshotNote]')));

        final intent = _sourceBetween(
          calendar,
          'class _SharedCalendarRealDayViewIntent',
          'class CalendarPage extends StatefulWidget',
        );
        expect(
          intent,
          contains('final Map<String, List<_Note>> warmStartNotes'),
        );
        expect(intent, contains('final List<_Flow> warmStartFlows'));
        expect(
          intent,
          contains(
            'final Map<String, SharedCalendarSummary> warmCalendarSummariesById',
          ),
        );
        expect(intent, contains('final Set<String> warmHiddenCalendarIds'));
        expect(intent, contains('final List<FiledEvent> sameCalendarEvents'));
        expect(
          intent,
          contains('final _SharedCalendarEventDetailSnapshot snapshot'),
        );
        expect(intent, contains('final EventDetailRestorationState detail'));

        final warmStore = _sourceBetween(
          calendar,
          'class _CalendarWarmStateStore',
          'class CalendarPage extends StatefulWidget',
        );
        expect(warmStore, contains('static void save({'));
        expect(warmStore, contains('snapshotForUser'));
        expect(warmStore, contains('_copyNotesByDay'));
        expect(warmStore, contains('_copyFlow'));

        final consumer = _sourceBetween(
          calendar,
          'bool _consumePendingSharedCalendarRealDayViewIntentIfAny() {',
          'Future<void> _requestInitialStartupRun',
        );
        expect(
          consumer,
          contains('CalendarPage._pendingSharedCalendarRealDayViewIntent'),
        );
        expect(consumer, contains('..addAll(intent.warmStartFlows)'));
        expect(consumer, contains('intent.warmStartNotes.entries.map'));
        expect(
          consumer,
          contains('..addAll(intent.warmCalendarSummariesById)'),
        );
        expect(consumer, contains('_seedSameDaySharedCalendarFiledEvents('));
        expect(consumer, contains('_seedOneShotSharedCalendarEventSnapshot('));
        expect(consumer, contains('_rebuildReminderRulesFromFlowsIfMissing()'));
        expect(consumer, contains('_openDayView('));
        expect(
          consumer,
          contains('initialEventDetailRestorationState: intent.detail'),
        );
        expect(
          consumer,
          contains("debugOpenSource: 'shared_calendar_event_tap'"),
        );
        expect(consumer, contains('_pendingPersistentDayViewState = null'));
        expect(consumer, contains('_persistentDayViewRestoreAttempted = true'));
        expect(consumer, contains('_calendarOverlayRestoreAttempted = true'));
        expect(consumer, contains('_calendarOverlayRestoreInFlight = false'));
        expect(
          consumer,
          contains('_calendarOverlayRestorePresentationStarted = false'),
        );
        expect(
          calendar,
          contains('[\$debugOpenSource] Day View route push requested'),
        );
        expect(calendar, contains('[\$debugOpenSource] Day View visible'));
        expect(
          consumer,
          contains("reason: 'shared_calendar_event_tap_background'"),
        );
        final openIndex = consumer.indexOf('_openDayView(');
        final clearRestoreIndex = consumer.indexOf(
          '_pendingPersistentDayViewState = null',
        );
        final startupIndex = consumer.indexOf('_requestInitialStartupRun(');
        expect(openIndex, isNonNegative);
        expect(clearRestoreIndex, isNonNegative);
        expect(startupIndex, isNonNegative);
        expect(clearRestoreIndex, lessThan(openIndex));
        expect(openIndex, lessThan(startupIndex));
        final sameDaySeedIndex = consumer.indexOf(
          '_seedSameDaySharedCalendarFiledEvents(',
        );
        final snapshotSeedIndex = consumer.indexOf(
          '_seedOneShotSharedCalendarEventSnapshot(',
        );
        expect(sameDaySeedIndex, isNonNegative);
        expect(snapshotSeedIndex, isNonNegative);
        expect(sameDaySeedIndex, lessThan(snapshotSeedIndex));
        expect(consumer, isNot(contains('DayViewPage(')));
        expect(consumer, isNot(contains('_routeHomeForSearchResult')));
        expect(consumer, isNot(contains('_openDaySheet(')));
        expect(consumer, isNot(contains('saveDurableLaunchRoute')));
        expect(consumer, isNot(contains('SessionResumeService')));

        final initState = _sourceBetween(
          calendar,
          '  @override\n  void initState() {',
          '  void _handleCalendarInvalidated',
        );
        final consumedIntentBranch = _sourceBetween(
          initState,
          'if (consumedSharedCalendarIntent) {',
          '}\n    unawaited(_loadCalendarState());',
        );
        expect(consumedIntentBranch, contains('return;'));
        expect(consumedIntentBranch, isNot(contains('_loadCalendarState')));

        final seed = _sourceBetween(
          calendar,
          'void _seedOneShotSharedCalendarEventSnapshot({',
          'bool _consumePendingSharedCalendarRealDayViewIntentIfAny() {',
        );
        expect(
          seed,
          contains('_noteFromSharedCalendarEventSnapshot(snapshot)'),
        );
        expect(seed, contains('_notes.putIfAbsent'));
        expect(seed, contains('bucket.any'));
        expect(seed, contains('using cached real detail note'));
        expect(seed, contains('bucket.removeWhere'));
        expect(seed, contains('_noteMatchesEventDetailRestorationState'));
        expect(seed, contains('_visibleDayNoteBaseKey'));
        expect(seed, contains('_standaloneDedupeKey'));
        expect(seed, isNot(contains('_notifyDayViewDataChanged')));
        expect(seed, isNot(contains('_scheduleWarmStartCacheSave')));

        final sameDaySeed = _sourceBetween(
          calendar,
          'void _seedSameDaySharedCalendarFiledEvents({',
          'bool _noteMatchesEventDetailRestorationState',
        );
        expect(sameDaySeed, contains('required List<FiledEvent> filedEvents'));
        expect(sameDaySeed, contains('_noteFromSharedCalendarFiledEvent('));
        expect(sameDaySeed, contains('_noteMatchesFiledEventIdentity'));
        expect(sameDaySeed, contains('_dedupeVisibleDayNotes('));
        expect(sameDaySeed, contains('seeded same-day filed events'));

        final pendingLaunch = _sourceBetween(
          calendar,
          'bool _schedulePendingDetachedLaunchActionIfAny() {',
          'final action = CalendarPage._pendingDetachedLaunchAction;',
        );
        final createSheetIndex = pendingLaunch.indexOf(
          'final pendingSearchDay',
        );
        expect(createSheetIndex, isNonNegative);
        final searchResultBranch = pendingLaunch.substring(0, createSheetIndex);
        final searchOpenIndex = searchResultBranch.indexOf('_openDayView(');
        expect(searchOpenIndex, isNonNegative);
        expect(
          searchResultBranch,
          isNot(contains('_seedOneShotSharedCalendarEventSnapshot')),
        );
        expect(
          searchResultBranch,
          isNot(contains("source: 'shared_calendar_event_tap_background'")),
        );
        expect(
          searchResultBranch,
          isNot(contains('sharedCalendarEventSnapshot')),
        );
        expect(searchResultBranch, isNot(contains('await _loadFromDisk')));
        expect(searchResultBranch, isNot(contains('_openDaySheet(')));

        final loadFromDisk = _sourceBetween(
          calendar,
          'Future<void> _loadFromDisk({',
          '/// Allows other screens',
        );
        expect(loadFromDisk, contains('hasPaintedStandaloneLaneAtLoadStart'));
        expect(
          loadFromDisk,
          contains('commitVisibleCalendarState(String phase)'),
        );
        expect(loadFromDisk, contains('preservePaintedStandaloneLane'));
        expect(
          loadFromDisk,
          contains('_mergePaintedStandaloneLaneInto(newNotes)'),
        );
        expect(loadFromDisk, contains('dedupedNotes'));
        expect(loadFromDisk, contains('_notes\n          ..clear()'));
        expect(loadFromDisk, contains('..addAll(dedupedNotes)'));
        expect(
          loadFromDisk,
          contains(
            '[SharedCalendarEventTap] hydration complete source=\$source',
          ),
        );
      },
    );

    test(
      'CalendarPage and Inbox pass the event tap callback into the sheet',
      () async {
        final calendar = await File(
          'lib/features/calendar/calendar_page.dart',
        ).readAsString();
        final inbox = await File(
          'lib/features/inbox/inbox_page.dart',
        ).readAsString();

        final rootSheet = _sourceBetween(
          calendar,
          'Future<void> _openSharedCalendarsSheet({',
          'Future<bool> _openCalendarScopedNoteDialog',
        );
        expect(
          rootSheet,
          contains('onAddEventRequested: _openCalendarScopedNoteDialog'),
        );
        expect(rootSheet, contains('onEventTapRequested'));
        expect(
          rootSheet,
          contains('CalendarPage.openFiledCalendarEventFromAnyContext'),
        );
        expect(rootSheet, contains('calendar: calendar'));

        final detachedSheet = _sourceBetween(
          calendar,
          'static Future<void> _openDetachedSharedCalendarsSheet',
          'static Future<void> _openDetachedFlowStudioSheet',
        );
        expect(detachedSheet, contains('onEventTapRequested'));
        expect(detachedSheet, contains('openFiledCalendarEventFromAnyContext'));
        expect(detachedSheet, contains('calendar: calendar'));
        expect(detachedSheet, contains('calendarEvents: calendarEvents'));

        expect(rootSheet, contains('calendarEvents: calendarEvents'));

        final calendarsRoute = _sourceBetween(
          calendar,
          'class _SharedCalendarsRoutePage extends StatelessWidget',
          'class _FlowEditorRoutePage',
        );
        expect(calendarsRoute, contains('UtilitySheetRouteScaffold'));
        expect(calendarsRoute, contains("semanticLabel: 'Calendars'"));
        expect(calendarsRoute, contains('SharedCalendarsSheet('));
        expect(calendarsRoute, contains('routeMode: true'));
        expect(calendarsRoute, contains('routeModeSafeAreaTop: false'));
        expect(calendarsRoute, contains('dismissOnEventTap: false'));
        expect(calendarsRoute, contains('showCloseButton: false'));
        expect(calendarsRoute, contains("closeOrReturn(context, '/')"));
        expect(
          calendarsRoute,
          contains('CalendarPage.openFiledCalendarEventFromAnyContext'),
        );
        expect(calendarsRoute, contains('calendarEvents: calendarEvents'));

        expect(
          inbox,
          contains(
            "import '../calendar/calendar_page.dart' show CalendarPage;",
          ),
        );
        expect(
          RegExp(
            r'onEventTapRequested:\s+\(calendar, filedEvent, \{calendarEvents = const \[\]\}\) =>\s+CalendarPage\.openFiledCalendarEventFromAnyContext',
          ).allMatches(inbox).length,
          greaterThanOrEqualTo(4),
        );
        expect(
          RegExp(r'calendarEvents: calendarEvents').allMatches(inbox).length,
          greaterThanOrEqualTo(4),
        );
        expect(
          RegExp(r'calendar: calendar').allMatches(inbox).length,
          greaterThanOrEqualTo(4),
        );
      },
    );
  });
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'Missing start marker: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: 'Missing end marker: $end');
  return source.substring(startIndex, endIndex);
}
