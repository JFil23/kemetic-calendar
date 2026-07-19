import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/drawer_navigation_generation.dart';

void main() {
  test(
    'older route and close futures are inert after a newer drawer selection',
    () async {
      final generations = DrawerNavigationGeneration();
      final inboxGeneration = generations.issue();
      final calendarsGeneration = generations.issue();
      final calendarGeneration = generations.issue();
      final inboxRoute = Completer<void>();
      final calendarsRoute = Completer<void>();
      final calendarRoute = Completer<void>();
      final inboxClose = Completer<void>();
      final calendarsClose = Completer<void>();
      final calendarClose = Completer<void>();
      final committedRoutes = <String>[];
      final completedCloses = <int>[];

      Future<void> completeRoute(
        int generation,
        String route,
        Completer<void> completion,
      ) async {
        await completion.future;
        generations.runIfCurrent(generation, () => committedRoutes.add(route));
      }

      Future<void> completeClose(
        int generation,
        Completer<void> completion,
      ) async {
        await completion.future;
        generations.runIfCurrent(
          generation,
          () => completedCloses.add(generation),
        );
      }

      final pending = <Future<void>>[
        completeRoute(inboxGeneration, '/inbox', inboxRoute),
        completeRoute(calendarsGeneration, '/calendars', calendarsRoute),
        completeRoute(calendarGeneration, '/', calendarRoute),
        completeClose(inboxGeneration, inboxClose),
        completeClose(calendarsGeneration, calendarsClose),
        completeClose(calendarGeneration, calendarClose),
      ];

      calendarRoute.complete();
      calendarClose.complete();
      inboxClose.complete();
      calendarsRoute.complete();
      inboxRoute.complete();
      calendarsClose.complete();
      await Future.wait(pending);

      expect(committedRoutes, <String>['/']);
      expect(completedCloses, <int>[calendarGeneration]);
      expect(generations.current, calendarGeneration);
    },
  );
}
