import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calendar search result navigation', () {
    test(
      'result taps carry the tapped note into Day View detail restoration',
      () async {
        final delegate = await File(
          'lib/features/calendar/calendar_event_search_delegate.dart',
        ).readAsString();
        final calendar = await File(
          'lib/features/calendar/calendar_page.dart',
        ).readAsString();

        expect(
          delegate,
          contains(
            'void Function(int ky, int km, int kd, _Note note) openResult',
          ),
        );
        expect(
          delegate,
          contains('onTap: () => openResult(it.ky, it.km, it.kd, it.note)'),
        );

        final mountedSearch = _sourceBetween(
          calendar,
          'void _openSearchForContext(BuildContext searchContext) {',
          '// Centralize applying Flow Studio results to calendar state',
        );

        expect(mountedSearch, contains('openResult: (ky, km, kd, note)'));
        expect(
          mountedSearch,
          contains('CalendarPage._eventDetailRestorationStateForSearchNote'),
        );
        expect(mountedSearch, contains('note: note'));
        expect(mountedSearch, contains('_openDayView('));
        expect(
          mountedSearch,
          contains('initialEventDetailRestorationState: detail'),
        );
        expect(mountedSearch, isNot(contains('_openDaySheet(')));
      },
    );

    test(
      'detached search resumes into Day View, not the create-note sheet',
      () async {
        final calendar = await File(
          'lib/features/calendar/calendar_page.dart',
        ).readAsString();

        final detachedSearch = _sourceBetween(
          calendar,
          'static Future<void> openSearchFromAnyContext(BuildContext context) async {',
          'static Future<({Map<String, List<_Note>> notes, List<_Flow> flows})>',
        );
        expect(detachedSearch, contains('openResult: (ky, km, kd, note)'));
        expect(detachedSearch, contains('_routeHomeForSearchResult('));
        expect(detachedSearch, contains('eventDetail: detail'));

        final pendingLaunch = _sourceBetween(
          calendar,
          'bool _schedulePendingDetachedLaunchActionIfAny() {',
          'final action = CalendarPage._pendingDetachedLaunchAction;',
        );
        final searchResultIndex = pendingLaunch.indexOf(
          'final pendingSearchResult',
        );
        final createSheetIndex = pendingLaunch.indexOf(
          'final pendingSearchDay',
        );

        expect(searchResultIndex, isNonNegative);
        expect(createSheetIndex, isNonNegative);
        expect(searchResultIndex, lessThan(createSheetIndex));

        final searchResultBranch = pendingLaunch.substring(
          searchResultIndex,
          createSheetIndex,
        );
        expect(searchResultBranch, contains('_openDayView('));
        expect(searchResultBranch, contains('pendingSearchResult.eventDetail'));
        expect(searchResultBranch, isNot(contains('_openDaySheet(')));

        final createSheetBranch = pendingLaunch.substring(createSheetIndex);
        expect(createSheetBranch, contains('_openDaySheet('));
        expect(createSheetBranch, contains('pendingSearchDay.ky'));
      },
    );

    test('search detail identity uses stable event identifiers', () async {
      final calendar = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final helper = _sourceBetween(
        calendar,
        'static EventDetailRestorationState?\n'
            '  _eventDetailRestorationStateForSearchNote({',
        'static Future<({Map<String, List<_Note>> notes, List<_Flow> flows})>',
      );

      expect(helper, contains('note.clientEventId?.trim()'));
      expect(helper, contains('eventDetailIdentityClientEventId'));
      expect(helper, contains('note.id?.trim()'));
      expect(helper, contains('eventDetailIdentityEventId'));
      expect(helper, contains('note.reminderId?.trim()'));
      expect(helper, contains('eventDetailIdentityReminderId'));
    });
  });
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'Missing start marker: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: 'Missing end marker: $end');
  return source.substring(startIndex, endIndex);
}
