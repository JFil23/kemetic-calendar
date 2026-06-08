import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/route_location_sanitizer.dart';

void main() {
  group('stableRouteLocationForContinuity', () {
    test('strips node insight action routes to stable node routes', () {
      expect(
        stableRouteLocationForContinuity(
          '/nodes/human_emergence?action=add_insight',
        ),
        '/nodes/human_emergence',
      );
      expect(
        stableRouteLocationForContinuity('/nodes/maat?insight=new'),
        '/nodes/maat',
      );
    });

    test('keeps stable node list focus routes', () {
      expect(
        stableRouteLocationForContinuity('/nodes?focus=human_emergence'),
        '/nodes?focus=human_emergence',
      );
    });

    test('keeps focused inbox calendar routes durable', () {
      expect(
        stableRouteLocationForContinuity('/inbox?calendarId=calendar-1'),
        '/inbox?calendarId=calendar-1',
      );
    });

    test('keeps edit flow routes as stable durable surfaces', () {
      expect(
        stableRouteLocationForContinuity(
          '/flows/42/edit?calendarId=shared-1&fallback=%2Fshared-flow%2Fby-flow%2F42',
        ),
        '/flows/42/edit',
      );
      expect(
        stableRouteLocationForContinuity(
          '/flows/42/edit?calendarId=shared-1&fallback=%2Fjournal',
        ),
        '/flows/42/edit',
      );
      expect(
        stableRouteLocationForContinuity('/flows/42/edit?calendarId=shared-1'),
        '/flows/42/edit',
      );
      expect(
        routeLocationContainsOneShotIntent(
          '/flows/42/edit?calendarId=shared-1',
        ),
        isTrue,
      );
      expect(routeLocationContainsOneShotIntent('/flows/42/edit'), isFalse);
    });

    test('strips planner launch-only query parameters', () {
      expect(
        stableRouteLocationForContinuity(
          '/rhythm/today?openDayCard=1&source=ios_widget&date=2026-05-09&tz=America%2FLos_Angeles&_launch=abc',
        ),
        '/rhythm/today',
      );
    });

    test('rejects external locations for continuity persistence', () {
      expect(
        stableRouteLocationForContinuity(
          'https://maat.app/nodes/human_emergence?action=add_insight',
        ),
        isNull,
      );
    });
  });

  group('routeLocationContainsOneShotIntent', () {
    test('detects known one-shot route actions', () {
      expect(
        routeLocationContainsOneShotIntent(
          '/nodes/human_emergence?action=add_insight',
        ),
        isTrue,
      );
      expect(
        routeLocationContainsOneShotIntent('/rhythm/today?openDayCard=1'),
        isTrue,
      );
      expect(
        routeLocationContainsOneShotIntent('/nodes/human_emergence'),
        isFalse,
      );
    });
  });
}
