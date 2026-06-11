import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('global side drawer is the only app-level navigation chrome', () async {
    final main = await File('lib/main.dart').readAsString();
    final shell = _sourceBetween(
      main,
      'class _GlobalFloatingMenuShellState',
      'class PushIntentBridge',
    );

    expect(shell, contains('GlobalSideDrawer('));
    expect(shell, contains('GlobalMenuBubble('));
    expect(shell, isNot(contains('_GlobalBottomMenuBar')));
    expect(shell, isNot(contains('_GlobalMenuBarrier')));
    expect(
      shell,
      isNot(contains('CalendarPage.buildDetachedActionsMenuPanel')),
    );
    expect(shell, isNot(contains('useGlobalSideDrawerNavigation')));
    expect(main, isNot(contains('navigation_feature_flags')));
    expect(main, isNot(contains('USE_GLOBAL_SIDE_DRAWER_NAVIGATION')));
  });

  test(
    'global side drawer is an underlay behind the foreground shell',
    () async {
      final main = await File('lib/main.dart').readAsString();
      final shell = _sourceBetween(
        main,
        'class _GlobalFloatingMenuShellState',
        'class PushIntentBridge',
      );
      final drawer = await File(
        'lib/widgets/global_side_drawer.dart',
      ).readAsString();
      final drawerWidget = _sourceBetween(
        drawer,
        'class GlobalSideDrawer extends StatelessWidget',
        'class GlobalSideDrawerForeground extends StatelessWidget',
      );

      expect(shell, contains('GlobalSideDrawer('));
      expect(shell, contains('GlobalSideDrawerForeground('));
      expect(
        shell.indexOf('GlobalSideDrawer('),
        lessThan(shell.indexOf('GlobalSideDrawerForeground(')),
      );
      expect(shell, contains('globalSideDrawerScrimKey'));
      expect(shell, contains('onTap: () => unawaited(_closeFloatingMenu())'));
      expect(drawer, contains('globalSideDrawerForegroundKey'));
      expect(drawer, contains('AnimatedSlide'));
      expect(drawerWidget, isNot(contains('globalSideDrawerScrimKey')));
      expect(drawerWidget, isNot(contains('GestureDetector')));
    },
  );

  test('drawer rows use final labels and include Profile', () async {
    final main = await File('lib/main.dart').readAsString();
    final items = _sourceBetween(
      main,
      'List<GlobalSideDrawerItem> _buildGlobalSideDrawerItems()',
      'void _openMaatGuidance',
    );

    for (final label in <String>[
      'Calendar',
      'Planner',
      'Library',
      'Journal',
      'Inbox',
      'Calendars',
      'Flows',
      'Reflections',
      'Profile',
      'Settings',
    ]) {
      expect(items, contains("label: '$label'"));
    }
    expect(items, isNot(contains("label: 'Home'")));
    expect(items, isNot(contains("label: 'Flow Studio'")));
    expect(items, contains('MeduNeterGlyphs.profile'));
  });

  test(
    'drawer dispatch keeps primary utility and profile route contracts',
    () async {
      final main = await File('lib/main.dart').readAsString();
      final primary = _sourceBetween(
        main,
        'Future<void> _openPrimarySectionFromDrawer',
        'Future<void> _openProfileFromDrawer',
      );
      final profile = _sourceBetween(
        main,
        'Future<void> _openProfileFromDrawer',
        'Future<void> _openFlowsFromDrawer',
      );
      final flows = _sourceBetween(
        main,
        'Future<void> _openFlowsFromDrawer',
        'Future<void> _openCalendarsFromDrawer',
      );
      final calendars = _sourceBetween(
        main,
        'Future<void> _openCalendarsFromDrawer',
        'bool _isDrawerDestinationSelected',
      );
      final items = _sourceBetween(
        main,
        'List<GlobalSideDrawerItem> _buildGlobalSideDrawerItems()',
        'void _openMaatGuidance',
      );

      expect(primary, contains('openPrimarySection(context, section'));
      expect(primary, contains('unawaited(_closeFloatingMenu())'));
      expect(primary, isNot(contains('await _closeFloatingMenu();')));
      expect(profile, contains('openDetailRoute<void>'));
      expect(profile, contains("'/profile/me'"));
      expect(profile, contains('unawaited(_closeFloatingMenu())'));
      expect(profile, isNot(contains('await _closeFloatingMenu();')));
      expect(profile, isNot(contains('openPrimarySection')));
      expect(profile, isNot(contains('recordPrimaryTabSelection')));
      expect(
        main,
        isNot(contains('openPrimarySection(context, AppSection.profile')),
      );
      expect(flows, contains('unawaited(_closeFloatingMenu())'));
      expect(flows, isNot(contains('await _closeFloatingMenu();')));
      expect(calendars, contains('unawaited(_closeFloatingMenu())'));
      expect(calendars, isNot(contains('await _closeFloatingMenu();')));
      expect(items, contains('_openCalendarsFromDrawer()'));
      expect(items, contains('_openFlowsFromDrawer()'));
      expect(main, contains('openUtilityRoute<void>'));
      expect(main, contains("'/flows'"));
      expect(main, contains("'/calendars'"));
    },
  );

  test('drawer back handling toggles only on durable primary routes', () async {
    final main = await File('lib/main.dart').readAsString();
    final routeReader = _sourceBetween(
      main,
      'Uri _readRouterUri()',
      'void _handleRouteChanged()',
    );
    final backRoutes = _sourceBetween(
      main,
      'bool get _isDrawerBackToggleRoute',
      'bool _shouldOpenDrawerForBack',
    );
    final shouldOpen = _sourceBetween(
      main,
      'bool _shouldOpenDrawerForBack',
      'Future<bool> _handleBackButton',
    );
    final handler = _sourceBetween(
      main,
      'Future<bool> _handleBackButton',
      '@override\n  Widget build',
    );

    for (final route in <String>[
      '/',
      '/rhythm/today',
      '/nodes',
      '/journal',
      '/inbox',
      '/settings',
      '/reflections',
    ]) {
      expect(backRoutes, contains("'$route'"));
    }
    expect(backRoutes, isNot(contains('/profile/me')));
    expect(backRoutes, isNot(contains('/flows')));
    expect(backRoutes, isNot(contains('/calendars')));

    expect(shouldOpen, contains('_isDrawerBackToggleRoute'));
    expect(shouldOpen, contains('_shouldActivateFloatingMenu(context)'));
    expect(shouldOpen, isNot(contains('useGlobalSideDrawerNavigation')));
    expect(handler, contains('_dailyCosmicContextController.hasVisibleBadge'));
    expect(handler, contains('if (_menuMounted && _menuOpen)'));
    expect(handler, contains('await _closeFloatingMenu();'));
    expect(handler, contains('if (_shouldOpenDrawerForBack(context))'));
    expect(handler, contains('_openFloatingMenu();'));
    expect(handler, isNot(contains('openPrimarySection')));
    expect(handler, isNot(contains('closeOrReturn')));
    expect(handler, isNot(contains('recordPrimaryTabSelection')));
    expect(routeReader, contains('ImperativeRouteMatch'));
    expect(routeReader, contains('topMatch.matches.uri'));
  });

  test('drawer state is local and not restoration-backed', () async {
    final main = await File('lib/main.dart').readAsString();
    final shell = _sourceBetween(
      main,
      'class _GlobalFloatingMenuShellState',
      'class PushIntentBridge',
    );

    expect(shell, contains('bool _menuMounted = false;'));
    expect(shell, contains('bool _menuOpen = false;'));
    expect(shell, isNot(contains('RestorationMixin')));
    expect(shell, isNot(contains('RestorableBool')));
    expect(shell, isNot(contains('restorationId')));
  });

  test('global drawer shell does not add route swipe systems', () async {
    final main = await File('lib/main.dart').readAsString();
    final shell = _sourceBetween(
      main,
      'class _GlobalFloatingMenuShellState',
      'class PushIntentBridge',
    );
    final drawer = await File(
      'lib/widgets/global_side_drawer.dart',
    ).readAsString();
    final navigation = await File('NAVIGATION.md').readAsString();

    for (final source in <String>[shell, drawer]) {
      expect(source, isNot(contains('PageView')));
      expect(source, isNot(contains('TabBarView')));
      expect(source, isNot(contains('onHorizontalDrag')));
      expect(source, isNot(contains('Dismissible')));
    }
    expect(shell, isNot(contains('BackButtonDispatcher')));
    expect(shell, isNot(contains('NavigatorPopHandler')));
    expect(shell, isNot(contains('ShellRoute')));
    expect(shell, isNot(contains('CupertinoPageRoute')));

    for (final phrase in <String>[
      'Do not add custom page-to-page swipe navigation',
      'Calendar month/day/event detail',
      'Planner cards',
      'Profile carousels',
      'onboarding slides',
      'flow_post_detail_page.dart',
      'Node reader',
      'Dismissible',
    ]) {
      expect(navigation, contains(phrase));
    }
  });
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNot(-1), reason: 'Missing source marker: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNot(-1), reason: 'Missing source marker: $end');
  return source.substring(startIndex, endIndex);
}
