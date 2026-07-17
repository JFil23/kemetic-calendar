import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/drawer_route_history.dart';

void main() {
  test('primary replacement clears only old overlays', () {
    final history = DrawerRouteHistory(baseRoute: '/journal')
        .replacePrimary('/inbox')
        .pushOverlay('/calendars')
        .replacePrimary('/settings');

    expect(history.baseRoute, '/settings');
    expect(history.overlayRoutes, isEmpty);
    expect(history.visibleRoute, '/settings');
  });

  test('nested utility closes reveal their original base in order', () {
    final history = DrawerRouteHistory(
      baseRoute: '/inbox',
    ).pushOverlay('/calendars').pushOverlay('/flows');

    expect(history.visibleRoute, '/flows');
    expect(history.routeBelowVisible, '/calendars');

    final afterFlowsClose = history.popOverlay();
    expect(afterFlowsClose.visibleRoute, '/calendars');
    expect(afterFlowsClose.routeBelowVisible, '/inbox');

    final afterCalendarsClose = afterFlowsClose.popOverlay();
    expect(afterCalendarsClose.visibleRoute, '/inbox');
    expect(afterCalendarsClose.hasOverlays, isFalse);
  });

  test(
    'process restoration selects Inbox before replaying its utility stack',
    () {
      final history = DrawerRouteHistory(
        baseRoute: '/inbox',
      ).pushOverlay('/calendars').pushOverlay('/profile/me');

      final restored = DrawerRouteHistory.fromJson(history.toJson());

      expect(restored, isNotNull);
      expect(restored!.baseRoute, '/inbox');
      expect(restored.overlayRoutes, <String>['/calendars', '/profile/me']);
      expect(restored.visibleRoute, '/profile/me');
      expect(restored.matchesVisibleRoute('/profile/me'), isTrue);
    },
  );

  test(
    'invalid persisted locations are rejected instead of resetting history',
    () {
      expect(
        DrawerRouteHistory.fromJson(<String, dynamic>{
          'schemaVersion': DrawerRouteHistory.schemaVersion,
          'baseRoute': 'https://example.com',
          'overlayRoutes': <String>['/calendars'],
        }),
        isNull,
      );
    },
  );
}
