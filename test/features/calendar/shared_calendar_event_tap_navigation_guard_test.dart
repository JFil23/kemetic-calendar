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
        expect(tapHandler, contains('addPostFrameCallback'));
        expect(tapHandler, contains('handler(calendar, filedEvent)'));

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
        expect(opener, contains('KemeticMath.fromGregorian(localStart)'));
        expect(
          opener,
          contains('_sharedCalendarEventDetailSnapshotForFiledEvent'),
        );
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
        expect(opener, contains('_routeHomeForSearchResult('));
        expect(opener, contains('_clearDetachedCalendarOverlayState('));
        expect(opener, contains('_kCalendarOverlayKindSharedCalendars'));
        expect(opener, contains('eventDetail: detail'));
        expect(opener, contains('sharedCalendarEventSnapshot: snapshot'));
        expect(opener, isNot(contains('await mountedHost._loadFromDisk')));
        expect(opener, isNot(contains("source: 'shared_calendar_event_tap')")));
        expect(opener, isNot(contains('_openDaySheet(')));
        expect(opener, isNot(contains('saveDurableLaunchRoute')));
        expect(opener, isNot(contains('SessionResumeService')));
      },
    );

    test(
      'snapshot seed opens before hydration and is duplicate-safe',
      () async {
        final calendar = await File(
          'lib/features/calendar/calendar_page.dart',
        ).readAsString();

        final seed = _sourceBetween(
          calendar,
          'void _seedOneShotSharedCalendarEventSnapshot({',
          'Future<void> _requestInitialStartupRun',
        );
        expect(
          seed,
          contains('_noteFromSharedCalendarEventSnapshot(snapshot)'),
        );
        expect(seed, contains('_notes.putIfAbsent'));
        expect(seed, contains('bucket.removeWhere'));
        expect(seed, contains('_noteMatchesEventDetailRestorationState'));
        expect(seed, contains('_visibleDayNoteBaseKey'));
        expect(seed, contains('_standaloneDedupeKey'));
        expect(seed, isNot(contains('_notifyDayViewDataChanged')));
        expect(seed, isNot(contains('_scheduleWarmStartCacheSave')));

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
        final seedIndex = searchResultBranch.indexOf(
          '_seedOneShotSharedCalendarEventSnapshot',
        );
        final openIndex = searchResultBranch.indexOf('_openDayView(');
        expect(seedIndex, isNonNegative);
        expect(openIndex, isNonNegative);
        expect(seedIndex, lessThan(openIndex));
        expect(
          searchResultBranch,
          contains("source: 'shared_calendar_event_tap_background'"),
        );
        expect(
          searchResultBranch,
          contains('unawaited(\n          _loadFromDisk('),
        );
        expect(searchResultBranch, contains('sharedCalendarEventSnapshot'));
        expect(searchResultBranch, isNot(contains('await _loadFromDisk')));
        expect(searchResultBranch, isNot(contains('_openDaySheet(')));

        final loadFromDisk = _sourceBetween(
          calendar,
          'Future<void> _loadFromDisk({',
          '/// Allows other screens',
        );
        expect(loadFromDisk, contains('_notes\n        ..clear()'));
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

        expect(
          inbox,
          contains(
            "import '../calendar/calendar_page.dart' show CalendarPage;",
          ),
        );
        expect(
          RegExp(
            r'onEventTapRequested: \(calendar, filedEvent\) =>\s+CalendarPage\.openFiledCalendarEventFromAnyContext',
          ).allMatches(inbox).length,
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
