import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNot(-1), reason: 'Missing source marker: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNot(-1), reason: 'Missing source marker: $end');
  return source.substring(startIndex, endIndex);
}

void main() {
  test('device stability receipt records the accepted source and evidence', () {
    final receipt = File('STABILITY_BASELINE.md').readAsStringSync();

    for (final value in <String>[
      '67f725fe2fd8f0ed43b65df510d8abdbc8377b53',
      '67f725f-drawer-history-short-iphone-20260717',
      '201b618e7142543109e10ea3791bb2069a114d295d25a4029ee2e87bdc9d2330',
      'f0bd649502456f941373694f43d10bdf3af05e106642e81f4f0535492bc5c8d6',
      '5d5ae321bef91badaa7ed3cb6c204138ed1608c21547620a8da7ae85813b65f3',
      '4e6afae936963e5162934940487558dcecffd02f57a2c70b0d8d4bf973cb2d60',
      '1d17f8ea826e4702c37ab0d5d167e84d0106f4e862ef3707e6832bdb63492f01',
      '6a0945f65b26702c8f68d5193d48d0875d749682',
    ]) {
      expect(receipt, contains(value));
    }
    expect(receipt, contains('requires a new device gate'));
  });

  test('drawer baseline retains its visual and dispatch authority', () async {
    final main = await File('lib/main.dart').readAsString();
    final drawer = await File(
      'lib/widgets/global_side_drawer.dart',
    ).readAsString();
    final shell = _sourceBetween(
      main,
      'class _GlobalFloatingMenuShellState',
      'class PushIntentBridge',
    );
    final dispatcher = _sourceBetween(
      main,
      'void _dispatchDrawerDestination',
      'bool _isDrawerDestinationSelected',
    );
    final foreground = _sourceBetween(
      drawer,
      'class GlobalSideDrawerForeground extends StatelessWidget',
      'class _GlobalSideDrawerRow extends StatelessWidget',
    );

    expect(drawer, contains('Color(0xFF000000)'));
    expect(foreground, contains('Transform.translate'));
    expect(foreground, contains('globalSideDrawerWidth(context)'));
    expect(shell, contains('GlobalSideDrawerForeground('));
    expect(shell, contains('GlobalMenuBubble('));
    expect(dispatcher, contains('_drawerNavigationGeneration.runIfCurrent'));
    expect(dispatcher, contains('widget.router.go(destination.location)'));
    expect(dispatcher, contains('openUtilityRoute<void>('));
    expect(dispatcher, contains('openDetailRoute<void>('));
    expect(dispatcher, contains('unawaited(_closeFloatingMenu'));
    expect(dispatcher, isNot(contains('await _closeFloatingMenu()')));
    expect(dispatcher, isNot(contains('popUntil(')));
    expect(dispatcher, isNot(contains('Navigator.maybeOf(')));
  });

  test(
    'base-plus-overlay history cannot collapse to an automatic Calendar',
    () async {
      final main = await File('lib/main.dart').readAsString();
      final history = await File(
        'lib/core/drawer_route_history.dart',
      ).readAsString();
      final historyTests = await File(
        'test/core/drawer_route_history_test.dart',
      ).readAsString();
      final lifecycleTests = await File(
        'test/widgets/global_navigation_shell_test.dart',
      ).readAsString();

      expect(main, contains('boot drawer history accepted'));
      expect(main, contains('return drawerHistory.baseRoute;'));
      expect(main, contains('_pushDrawerHistoryUtility(destination)'));
      expect(main, contains('_replaceDrawerHistoryPrimary(destination)'));
      expect(history, contains('DrawerRouteHistory popOverlay()'));
      expect(
        history,
        contains('overlayRoutes.sublist(0, overlayRoutes.length - 1)'),
      );
      expect(historyTests, contains('process restoration selects Inbox'));
      expect(lifecycleTests, contains('same mounted Inbox after resume'));
      expect(lifecycleTests, contains('rapid Inbox Calendars Calendar'));
    },
  );

  test(
    'Planner termination and frozen Calendar regression guards remain',
    () async {
      final navigation = await File('NAVIGATION.md').readAsString();
      final planner = await File(
        'test/services/termination_safe_primary_navigation_test.dart',
      ).readAsString();
      final topology = await File(
        'test/features/calendar/calendar_startup_render_guard_test.dart',
      ).readAsString();
      final today = await File(
        'test/features/calendar/calendar_today_in_place_guard_test.dart',
      ).readAsString();
      final calendar = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final todayCommand = _sourceBetween(
        calendar,
        'void _applyTodayNavigationCommand(',
        'bool _consumePendingTodayNavigationCommand',
      );

      expect(navigation, contains('UX-RESTORE-001'));
      expect(navigation, contains('UX-RESTORE-005'));
      expect(planner, contains('recordPrimaryTabSelectionCriticalSnapshot'));
      expect(planner, contains('/rhythm/today'));
      expect(topology, contains('single YearSection topology'));
      expect(today, contains('one in-place animated viewport command'));
      expect(todayCommand, isNot(contains("router.go('/')")));
    },
  );
}
