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

  test('global drawer bubble skin is not route-specific', () async {
    final main = await File('lib/main.dart').readAsString();
    final shell = _sourceBetween(
      main,
      'class _GlobalFloatingMenuShellState',
      'class PushIntentBridge',
    );
    final drawer = await File(
      'lib/widgets/global_side_drawer.dart',
    ).readAsString();
    final bubble = _sourceBetween(
      drawer,
      'class GlobalMenuBubble extends StatelessWidget',
      'class GlobalSideDrawer extends StatelessWidget',
    );

    expect(shell, contains('GlobalMenuBubble('));
    expect(shell, isNot(contains('_globalMenuBubbleStyle')));
    expect(shell, isNot(contains('_isReflectionsRoute')));
    expect(shell, isNot(contains('_isJournalRoute')));
    expect(shell, isNot(contains('decanReflectionGlobalMenuBubbleStyle')));
    expect(shell, isNot(contains('JournalSkinTokens.floatingGlyph')));
    expect(bubble, contains('globalTransparentMenuBubbleStyle'));
    expect(bubble, contains('globalMenuBubbleSurfaceKey'));
    expect(bubble, isNot(contains('Color(0xF6000000)')));
  });

  test(
    'UX-DRAWER contract keeps an opaque underlay and translated shell',
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
      expect(drawerWidget, contains('Color(0xFF000000)'));
      expect(drawerWidget, isNot(contains('AnimatedSlide')));
      final foregroundWidget = _sourceBetween(
        drawer,
        'class GlobalSideDrawerForeground extends StatelessWidget',
        'class _GlobalSideDrawerRow extends StatelessWidget',
      );
      expect(foregroundWidget, contains('TweenAnimationBuilder<double>'));
      expect(foregroundWidget, contains('Transform.translate'));
      expect(foregroundWidget, contains('globalSideDrawerWidth(context)'));
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
        'void _openPrimarySectionFromDrawer',
        'void _openProfileFromDrawer',
      );
      final profile = _sourceBetween(
        main,
        'void _openProfileFromDrawer',
        'void _openFlowsFromDrawer',
      );
      final flows = _sourceBetween(
        main,
        'void _openFlowsFromDrawer',
        'void _openCalendarsFromDrawer',
      );
      final calendars = _sourceBetween(
        main,
        'void _openCalendarsFromDrawer',
        'bool _isDrawerDestinationSelected',
      );
      final items = _sourceBetween(
        main,
        'List<GlobalSideDrawerItem> _buildGlobalSideDrawerItems()',
        'void _openMaatGuidance',
      );

      expect(primary, contains('openPrimarySection(context, section'));
      expect(primary, contains('_requestDrawerDestinationThenClose'));
      expect(primary, isNot(contains('await _closeFloatingMenu();')));
      expect(primary, contains('_currentUri.path == location'));
      expect(primary, contains('if (section == AppSection.calendar)'));
      expect(primary, contains('Navigator.maybeOf('));
      expect(primary, contains('rootNavigator: true'));
      expect(primary, contains('popUntil((route) => route.isFirst)'));
      expect(profile, contains('openDetailRoute<void>'));
      expect(profile, contains("'/profile/me'"));
      expect(profile, contains('_requestDrawerDestinationThenClose'));
      expect(profile, isNot(contains('await _closeFloatingMenu();')));
      expect(profile, isNot(contains('openPrimarySection')));
      expect(profile, isNot(contains('recordPrimaryTabSelection')));
      expect(
        main,
        isNot(contains('openPrimarySection(context, AppSection.profile')),
      );
      expect(flows, contains('_requestDrawerDestinationThenClose'));
      expect(calendars, contains('_requestDrawerDestinationThenClose'));
      expect(items, contains('onSelected: _openCalendarsFromDrawer'));
      expect(items, contains('onSelected: _openFlowsFromDrawer'));
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

  test(
    'global drawer bubble remains available on the main calendar route',
    () async {
      final main = await File('lib/main.dart').readAsString();
      final suppression = _sourceBetween(
        main,
        'bool get _shouldSuppressFloatingMenuForCurrentRoute',
        'bool _shouldActivateFloatingMenu(BuildContext context)',
      );

      expect(suppression, isNot(contains("path == '/'")));
      expect(suppression, contains("path == '/calendars'"));
    },
  );

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

  test(
    'NAVIGATION locks the reveal-push drawer interaction contract',
    () async {
      final navigation = await File('NAVIGATION.md').readAsString();

      for (final contract in <String>[
        'UX-DRAWER-001',
        'UX-DRAWER-002',
        'UX-DRAWER-003',
        'UX-DRAWER-004',
        'UX-DRAWER-005',
        'UX-DRAWER-006',
      ]) {
        expect(navigation, contains(contract));
      }
      expect(navigation, contains('opaque surface behind the application'));
      expect(navigation, contains('translates the entire foreground'));
      expect(navigation, contains('exact pre-open Calendar offset'));
      expect(navigation, contains('single `GlobalMenuBubble` remains mounted'));
      expect(navigation, contains('before it starts the independent close'));
      expect(navigation, contains('must not reconstruct the routed page'));
    },
  );

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
