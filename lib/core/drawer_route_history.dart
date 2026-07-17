import 'route_location_sanitizer.dart';

/// The durable route stack owned by the global drawer.
///
/// Primary selections replace [baseRoute]. Drawer utilities and details append
/// to [overlayRoutes], so closing one returns to the exact route beneath it.
/// This is deliberately separate from Flutter's transient Navigator history:
/// it lets a cold launch recreate a valid base plus its stacked utilities.
class DrawerRouteHistory {
  const DrawerRouteHistory({
    required this.baseRoute,
    this.overlayRoutes = const <String>[],
  });

  static const int schemaVersion = 1;

  final String baseRoute;
  final List<String> overlayRoutes;

  String get visibleRoute =>
      overlayRoutes.isEmpty ? baseRoute : overlayRoutes.last;

  String get routeBelowVisible => overlayRoutes.length < 2
      ? baseRoute
      : overlayRoutes[overlayRoutes.length - 2];

  bool get hasOverlays => overlayRoutes.isNotEmpty;

  DrawerRouteHistory replacePrimary(String route) {
    return DrawerRouteHistory(baseRoute: _requireRoute(route));
  }

  DrawerRouteHistory pushOverlay(String route) {
    final normalized = _requireRoute(route);
    if (_sameRoute(normalized, visibleRoute)) return this;
    return DrawerRouteHistory(
      baseRoute: baseRoute,
      overlayRoutes: <String>[...overlayRoutes, normalized],
    );
  }

  DrawerRouteHistory popOverlay() {
    if (overlayRoutes.isEmpty) return this;
    return DrawerRouteHistory(
      baseRoute: baseRoute,
      overlayRoutes: overlayRoutes.sublist(0, overlayRoutes.length - 1),
    );
  }

  bool matchesVisibleRoute(String route) => _sameRoute(visibleRoute, route);

  bool matchesRouteBelowVisible(String route) =>
      _sameRoute(routeBelowVisible, route);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'baseRoute': baseRoute,
    'overlayRoutes': overlayRoutes,
  };

  static DrawerRouteHistory? fromJson(Map<String, dynamic>? raw) {
    if (raw == null || raw['schemaVersion'] != schemaVersion) return null;
    final base = _normalizeRoute(raw['baseRoute'] as String?);
    final overlays = raw['overlayRoutes'];
    if (base == null || overlays is! List) return null;
    final normalizedOverlays = <String>[];
    for (final value in overlays) {
      if (value is! String) return null;
      final route = _normalizeRoute(value);
      if (route == null) return null;
      normalizedOverlays.add(route);
    }
    return DrawerRouteHistory(
      baseRoute: base,
      overlayRoutes: List<String>.unmodifiable(normalizedOverlays),
    );
  }

  static String _requireRoute(String route) {
    final normalized = _normalizeRoute(route);
    if (normalized == null) {
      throw ArgumentError.value(route, 'route', 'must be an internal route');
    }
    return normalized;
  }

  static String? _normalizeRoute(String? route) {
    final normalized = stableRouteLocationForContinuity(route);
    if (normalized == null || normalized.isEmpty) return null;
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.hasScheme || uri.host.isNotEmpty) return null;
    return uri.path.startsWith('/') ? normalized : null;
  }

  static bool _sameRoute(String left, String right) {
    final leftUri = Uri.tryParse(left);
    final rightUri = Uri.tryParse(right);
    return leftUri != null &&
        rightUri != null &&
        leftUri.path == rightUri.path &&
        leftUri.query == rightUri.query;
  }
}
