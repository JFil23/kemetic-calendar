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
        <String, dynamic>{
          'kind': 'calendar.eventDetail',
          'parentRoute': '/',
          'kYear': 6267,
          'kMonth': 4,
          'kDay': 12,
          'identityType': 'clientEventId',
          'identityValue': 'event-client-1',
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

      expect(
        CalendarPage.restorableOverlayParentRouteFromStack(
          const <Map<String, dynamic>>[
            <String, dynamic>{
              'kind': 'calendar.sharedCalendars',
              'parentRoute': '/profile/user-1',
              'expandedCalendarIds': <String>['personal', 'temple'],
            },
          ],
        ),
        '/profile/user-1',
      );

      expect(
        CalendarPage.restorableOverlayParentRouteFromStack(
          const <Map<String, dynamic>>[
            <String, dynamic>{
              'kind': 'calendar.flowStudio',
              'parentRoute': '/reflections',
              'mode': 'myFlows',
            },
          ],
        ),
        '/reflections',
      );
    });

    test(
      'Ma’at template details preserve inbox profile and reflection parents',
      () {
        for (final parentRoute in <String>[
          '/inbox',
          '/profile/user-1',
          '/reflections',
        ]) {
          expect(
            CalendarPage.restorableOverlayParentRouteFromStack(
              <Map<String, dynamic>>[
                <String, dynamic>{
                  'kind': 'calendar.flowStudio',
                  'parentRoute': parentRoute,
                  'mode': 'maatTemplate',
                  'templateKey': 'the-weighing',
                },
              ],
            ),
            parentRoute,
            reason: parentRoute,
          );
        }
      },
    );

    test('library routes restore as detached overlay parents', () {
      for (final parentRoute in <String>[
        '/nodes',
        '/nodes?focus=maat',
        '/nodes/ausar',
      ]) {
        expect(
          CalendarPage.restorableOverlayParentRouteFromStack(
            <Map<String, dynamic>>[
              <String, dynamic>{
                'kind': 'calendar.flowStudio',
                'parentRoute': parentRoute,
                'mode': 'hub',
              },
            ],
          ),
          parentRoute,
          reason: parentRoute,
        );
      }
    });

    test('transient editor overlays do not win restoration selection', () {
      expect(
        CalendarPage.restorableOverlayParentRouteFromStack(
          const <Map<String, dynamic>>[
            <String, dynamic>{
              'kind': 'calendar.eventDetail',
              'parentRoute': '/rhythm/today',
              'parentSurface': 'route.page',
              'kYear': 6267,
              'kMonth': 4,
              'kDay': 12,
              'identityType': 'clientEventId',
              'identityValue': 'event-client-1',
            },
            <String, dynamic>{
              'kind': 'calendar.flowStudio',
              'parentRoute': '/',
              'mode': 'editor',
              'editFlowId': 42,
            },
          ],
        ),
        isNull,
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

      expect(
        CalendarPage.restorableOverlayParentRouteFromStack(
          const <Map<String, dynamic>>[
            <String, dynamic>{
              'kind': 'calendar.eventDetail',
              'parentRoute': '/profile/user-1',
              'kYear': 6267,
              'kMonth': 4,
              'kDay': 12,
              'identityType': 'clientEventId',
              'identityValue': 'event-client-1',
            },
          ],
        ),
        isNull,
      );
    });
  });
}
