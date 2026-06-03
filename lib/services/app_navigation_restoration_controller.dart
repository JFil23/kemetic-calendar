import '../core/navigation_persistence_policy.dart';
import 'app_restoration_service.dart';
import 'restoration_trace.dart';

class PendingNavigationIntent {
  const PendingNavigationIntent({
    required this.key,
    required this.requestedRoute,
    required this.source,
  });

  final String key;
  final String requestedRoute;
  final NavigationSource source;
}

class OneShotNavigationResolution {
  const OneShotNavigationResolution({
    required this.requestedRoute,
    required this.source,
    this.route,
    required this.reason,
  });

  final String requestedRoute;
  final String? route;
  final NavigationSource source;
  final String reason;
}

class LaunchDestination {
  const LaunchDestination({
    required this.route,
    required this.decisionSource,
    required this.reason,
  });

  final String route;
  final String decisionSource;
  final String reason;
}

class PageState {
  const PageState({required this.owner, required this.reason, this.route});

  final String owner;
  final String reason;
  final String? route;
}

class AppNavigationRestorationController {
  AppNavigationRestorationController._();

  static final AppNavigationRestorationController instance =
      AppNavigationRestorationController._();

  final NavigationPersistencePolicy _policy =
      const NavigationPersistencePolicy();
  final Set<String> _consumedOneShotIntentKeys = <String>{};

  NavigationClassification classifyRoute(
    String route,
    NavigationSource source,
  ) {
    return _policy.classifyRoute(route, source);
  }

  Future<void> recordPrimaryTabSelection(AppSection section) {
    return recordPrimaryRouteSelection(_policy.routeForSection(section));
  }

  Future<void> recordPrimaryRouteSelection(String route) async {
    final classification = _policy.classifyRoute(
      route,
      NavigationSource.userPrimaryTab,
    );
    _logPersistenceAttempt(classification);
    if (!classification.accepted || classification.canonicalRoute == null) {
      return;
    }
    await AppRestorationService.instance.saveDurableLaunchRoute(
      classification.canonicalRoute!,
      metadata: classification.metadata,
    );
  }

  Future<void> recordNavigationAttempt({
    required String route,
    required NavigationSource source,
  }) async {
    final classification = _policy.classifyRoute(route, source);
    _logPersistenceAttempt(classification);
    if (!classification.accepted || classification.canonicalRoute == null) {
      return;
    }
    await AppRestorationService.instance.saveDurableLaunchRoute(
      classification.canonicalRoute!,
      metadata: classification.metadata,
    );
  }

  Future<void> recordPageState(PageState state) async {
    final route = state.route;
    if (route == null || route.trim().isEmpty) {
      traceRestoration(
        'navigation page_state owner=${state.owner} reason=${state.reason} '
        'route=<none> accepted=false',
      );
      return;
    }
    final classification = _policy.classifyRoute(
      route,
      NavigationSource.detailRestoration,
    );
    _logPersistenceAttempt(classification);
  }

  Future<OneShotNavigationResolution?> consumeOneShotIntent(
    PendingNavigationIntent intent,
  ) async {
    final normalizedKey = intent.key.trim();
    if (normalizedKey.isEmpty) return null;
    if (_consumedOneShotIntentKeys.contains(normalizedKey)) {
      traceRestoration(
        'navigation one_shot consumed key=$normalizedKey '
        'requested=${intent.requestedRoute} source=${intent.source.wireName} '
        'accepted=false reason=already_consumed',
      );
      return null;
    }
    _consumedOneShotIntentKeys.add(normalizedKey);

    final classification = _policy.classifyRoute(
      intent.requestedRoute,
      intent.source,
    );
    _logPersistenceAttempt(classification);
    final route = classification.canonicalRoute;
    traceRestoration(
      'navigation one_shot consumed key=$normalizedKey '
      'requested=${intent.requestedRoute} source=${intent.source.wireName} '
      'route=${route ?? '<none>'} reason=${classification.reason}',
    );
    return OneShotNavigationResolution(
      requestedRoute: intent.requestedRoute,
      route: route,
      source: intent.source,
      reason: classification.reason,
    );
  }

  Future<LaunchDestination> restoreLaunchDestination({
    required bool isAuthenticated,
    PendingNavigationIntent? intent,
    bool includeRemote = false,
  }) async {
    if (intent != null) {
      final oneShot = await consumeOneShotIntent(intent);
      final oneShotRoute = oneShot?.route;
      if (oneShotRoute != null && oneShotRoute.trim().isNotEmpty) {
        return _decision(
          route: oneShotRoute,
          source: 'oneShotIntent',
          reason: oneShot!.reason,
        );
      }
    }

    if (!isAuthenticated) {
      return _decision(
        route: '/',
        source: 'default',
        reason: 'not_authenticated',
      );
    }

    final result = await AppRestorationService.instance.readBestSnapshot(
      includeRemote: includeRemote,
    );
    final route = result.snapshot?.routeLocation;
    final metadata = result.snapshot?.launchRouteMetadata;
    if (_policy.isValidDurableLaunchRoute(route, metadata)) {
      return _decision(
        route: route!,
        source: result.source ?? 'durablePrimary',
        reason: 'valid_durable_metadata',
      );
    }

    final hadLegacyRoute = route != null && route.trim().isNotEmpty;
    return _decision(
      route: '/',
      source: 'default',
      reason: hadLegacyRoute
          ? 'invalid_or_legacy_launch_route_metadata'
          : 'no_durable_launch_route',
    );
  }

  void resetForTesting() {
    _consumedOneShotIntentKeys.clear();
  }

  LaunchDestination _decision({
    required String route,
    required String source,
    required String reason,
  }) {
    traceRestoration(
      'navigation launch destination route=$route '
      'decisionSource=$source reason=$reason',
    );
    return LaunchDestination(
      route: route,
      decisionSource: source,
      reason: reason,
    );
  }

  void _logPersistenceAttempt(NavigationClassification classification) {
    traceRestoration(
      'navigation persistence attempt requested=${classification.requestedRoute} '
      'source=${classification.source.wireName} '
      'classification=${classification.routeClass.wireName} '
      'accepted=${classification.accepted} '
      'reason=${classification.reason} '
      'canonical=${classification.canonicalRoute ?? '<none>'}',
    );
  }
}
