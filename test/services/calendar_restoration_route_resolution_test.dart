import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';

void main() {
  group('calendar restoration parent route resolution', () {
    test('root calendar overlays do not replace the saved base page', () {
      for (final overlay in <Map<String, dynamic>>[
        <String, dynamic>{
          'kind': 'calendar.sharedCalendars',
          'parentRoute': '/',
        },
        <String, dynamic>{
          'kind': 'calendar.flowStudio',
          'parentRoute': '/',
          'mode': 'maatTemplate',
          'templateKey': 'follow_the_sky',
        },
        <String, dynamic>{'kind': 'calendar.sharedCalendars'},
      ]) {
        expect(
          CalendarPage.restorableOverlayParentRouteFromStack(
            <Map<String, dynamic>>[overlay],
          ),
          isNull,
          reason: overlay.toString(),
        );
      }
    });

    test('detached calendar overlays restore their parent page first', () {
      expect(
        CalendarPage.restorableOverlayParentRouteFromStack(
          const <Map<String, dynamic>>[
            <String, dynamic>{
              'kind': 'calendar.sharedCalendars',
              'parentRoute': '/rhythm/today',
              'expandedCalendarIds': <String>['personal', 'temple'],
            },
          ],
        ),
        '/rhythm/today',
      );

      expect(
        CalendarPage.restorableOverlayParentRouteFromStack(
          const <Map<String, dynamic>>[
            <String, dynamic>{
              'kind': 'calendar.flowStudio',
              'parentRoute': '/profile/user-1',
              'mode': 'maatTemplate',
              'templateKey': 'follow_the_sky',
            },
          ],
        ),
        '/profile/user-1',
      );
    });

    test('latest restorable calendar overlay wins', () {
      expect(
        CalendarPage.restorableOverlayParentRouteFromStack(
          const <Map<String, dynamic>>[
            <String, dynamic>{
              'kind': 'calendar.sharedCalendars',
              'parentRoute': '/inbox',
            },
            <String, dynamic>{
              'kind': 'calendar.flowStudio',
              'parentRoute': '/rhythm/today',
              'mode': 'myFlows',
            },
          ],
        ),
        '/rhythm/today',
      );
    });

    test('ignores unrelated overlays and malformed parent routes', () {
      expect(
        CalendarPage.restorableOverlayParentRouteFromStack(
          const <Map<String, dynamic>>[
            <String, dynamic>{'kind': 'comments', 'parentRoute': '/feed/post'},
            <String, dynamic>{
              'kind': 'calendar.sharedCalendars',
              'parentRoute': ' ',
            },
          ],
        ),
        isNull,
      );
    });
  });
}
