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
        expect(opener, contains('KemeticMath.fromGregorian(localStart)'));
        expect(opener, contains('_loadCalendarState()'));
        expect(
          opener,
          contains("_loadFromDisk(source: 'shared_calendar_event_tap')"),
        );
        expect(opener, contains('_openDayView('));
        expect(opener, contains('initialEventDetailRestorationState: detail'));
        expect(opener, contains('_routeHomeForSearchResult('));
        expect(opener, contains('_clearDetachedCalendarOverlayState('));
        expect(opener, contains('_kCalendarOverlayKindSharedCalendars'));
        expect(opener, contains('eventDetail: detail'));
        expect(opener, isNot(contains('_openDaySheet(')));
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

        final detachedSheet = _sourceBetween(
          calendar,
          'static Future<void> _openDetachedSharedCalendarsSheet',
          'static Future<void> _openDetachedFlowStudioSheet',
        );
        expect(detachedSheet, contains('onEventTapRequested'));
        expect(detachedSheet, contains('openFiledCalendarEventFromAnyContext'));

        expect(
          inbox,
          contains(
            "import '../calendar/calendar_page.dart' show CalendarPage;",
          ),
        );
        expect(
          RegExp(
            r'onEventTapRequested: \(_, filedEvent\) =>\s+CalendarPage\.openFiledCalendarEventFromAnyContext',
          ).allMatches(inbox).length,
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
