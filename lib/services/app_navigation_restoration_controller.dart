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
    return _recordPrimaryRouteFromUserCommand(
      section,
      route: _policy.routeForSection(section),
    );
  }

  Future<void> _recordPrimaryRouteFromUserCommand(
    AppSection section, {
    required String route,
  }) async {
    final classification = _policy.classifyRoute(
      route,
      NavigationSource.userPrimaryTab,
    );
    _logPersistenceAttempt(classification);
    if (!classification.accepted ||
        !classification.canRecordPrimarySelection ||
        classification.canonicalRoute == null ||
        classification.section != section) {
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
    _logPersistenceAttempt(
      classification,
      acceptedOverride: false,
      reasonOverride: classification.accepted
          ? 'generic_navigation_attempt_not_user_primary_command'
          : null,
    );
  }

  Future<void> recordVisibleSurface({
    required String route,
    NavigationSource source = NavigationSource.programmatic,
  }) async {
    final classification = _policy.classifyRoute(route, source);
    _logPersistenceAttempt(classification);
    if (!classification.accepted ||
        !classification.canRestoreAsSurface ||
        classification.canonicalRoute == null) {
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
        final destination = _decision(
          route: oneShotRoute,
          source: 'oneShotIntent',
          reason: oneShot!.reason,
        );
        _logLaunchResolution(
          snapshotSource: 'oneShotIntent',
          route: null,
          metadata: null,
          accepted: false,
          reason: 'one_shot_intent_bypassed_durable_launch_route',
          finalDestination: destination,
        );
        return destination;
      }
    }

    if (!isAuthenticated) {
      final destination = _decision(
        route: '/',
        source: 'default',
        reason: 'not_authenticated',
      );
      _logLaunchResolution(
        snapshotSource: 'none',
        route: null,
        metadata: null,
        accepted: false,
        reason: destination.reason,
        finalDestination: destination,
      );
      return destination;
    }

    final result = await AppRestorationService.instance.readBestSnapshot(
      includeRemote: includeRemote,
    );
    final route = result.snapshot?.routeLocation;
    final metadata = result.snapshot?.launchRouteMetadata;
    final validationReason = _durableLaunchValidationReason(route, metadata);
    if (validationReason == 'valid_durable_metadata') {
      final destination = _decision(
        route: route!,
        source: result.source ?? 'durablePrimary',
        reason: validationReason,
      );
      _logLaunchResolution(
        snapshotSource: result.source ?? 'unknown',
        route: route,
        metadata: metadata,
        accepted: true,
        reason: validationReason,
        finalDestination: destination,
      );
      return destination;
    }

    final hadLegacyRoute = route != null && route.trim().isNotEmpty;
    final destination = _decision(
      route: '/',
      source: 'default',
      reason: hadLegacyRoute
          ? 'invalid_or_legacy_launch_route_metadata'
          : 'no_durable_launch_route',
    );
    _logLaunchResolution(
      snapshotSource: result.source ?? 'none',
      route: route,
      metadata: metadata,
      accepted: false,
      reason: hadLegacyRoute ? validationReason : destination.reason,
      finalDestination: destination,
    );
    return destination;
  }

  Future<LaunchDestination?> restoreDeferredLaunchDestinationAfterAuth({
    required String currentRoute,
    required bool restoreWasDeferredForAuth,
    required bool hasExplicitBootIntent,
    bool includeRemote = false,
  }) async {
    final normalizedCurrent = _normalizedInternalRoute(currentRoute) ?? '/';
    if (!restoreWasDeferredForAuth) {
      _logAuthDeferredReplay(
        currentRoute: normalizedCurrent,
        restoredRoute: null,
        accepted: false,
        reason: 'no_auth_deferred_boot_restore',
      );
      return null;
    }
    if (hasExplicitBootIntent) {
      _logAuthDeferredReplay(
        currentRoute: normalizedCurrent,
        restoredRoute: null,
        accepted: false,
        reason: 'explicit_boot_intent_wins',
      );
      return null;
    }
    if (!_isRootRoute(normalizedCurrent)) {
      _logAuthDeferredReplay(
        currentRoute: normalizedCurrent,
        restoredRoute: null,
        accepted: false,
        reason: 'current_route_no_longer_boot_default',
      );
      return null;
    }

    final destination = await restoreLaunchDestination(
      isAuthenticated: true,
      includeRemote: includeRemote,
    );
    final restoredRoute = _normalizedInternalRoute(destination.route);
    if (restoredRoute == null || _sameRouteLocation(restoredRoute, '/')) {
      _logAuthDeferredReplay(
        currentRoute: normalizedCurrent,
        restoredRoute: restoredRoute,
        accepted: false,
        reason: 'restored_route_is_root_or_empty',
      );
      return null;
    }
    if (_sameRouteLocation(restoredRoute, normalizedCurrent)) {
      _logAuthDeferredReplay(
        currentRoute: normalizedCurrent,
        restoredRoute: restoredRoute,
        accepted: false,
        reason: 'restored_route_already_visible',
      );
      return null;
    }

    _logAuthDeferredReplay(
      currentRoute: normalizedCurrent,
      restoredRoute: restoredRoute,
      accepted: true,
      reason: destination.reason,
      decisionSource: destination.decisionSource,
    );
    return destination;
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
      '[navRestore] final destination=$route '
      'decisionSource=$source reason=$reason',
    );
    return LaunchDestination(
      route: route,
      decisionSource: source,
      reason: reason,
    );
  }

  String _durableLaunchValidationReason(
    String? route,
    NavigationLaunchRouteMetadata? metadata,
  ) {
    final normalized = route?.trim();
    if (normalized == null || normalized.isEmpty) {
      return 'no_durable_launch_route';
    }
    if (metadata == null) {
      return 'missing_durable_metadata';
    }
    if (!metadata.isCurrentUserPrimaryDurable) {
      if (metadata.schemaVersion != navigationPersistenceSchemaVersion) {
        return 'unsupported_schema_version';
      }
      if (!metadata.isRestorableSurface) {
        return 'non_restorable_surface';
      }
    }
    final classification = _policy.classifyRoute(normalized, metadata.source);
    if (!classification.accepted) {
      return classification.reason;
    }
    if (classification.canonicalRoute != normalized) {
      return 'non_canonical_durable_route';
    }
    if (metadata.canonicalRoute != classification.canonicalRoute) {
      return 'metadata_canonical_route_mismatch';
    }
    if (metadata.section != classification.section) {
      return 'metadata_section_mismatch';
    }
    if (!classification.canRestoreAsSurface) {
      return 'non_restorable_surface';
    }
    return 'valid_durable_metadata';
  }

  void _logLaunchResolution({
    required String snapshotSource,
    required String? route,
    required NavigationLaunchRouteMetadata? metadata,
    required bool accepted,
    required String reason,
    required LaunchDestination finalDestination,
  }) {
    traceRestoration(
      '[navRestore] loaded durable metadata: '
      'snapshotSource=$snapshotSource '
      'route=${route == null || route.trim().isEmpty ? '<none>' : route.trim()} '
      'schemaVersion=${metadata?.schemaVersion ?? '<none>'} '
      'source=${metadata?.source.wireName ?? '<none>'} '
      'routeClass=${metadata?.routeClass.wireName ?? '<none>'} '
      'section=${metadata?.section?.wireName ?? '<none>'} '
      'canonicalRoute=${metadata?.canonicalRoute ?? '<none>'} '
      'accepted=$accepted reason=$reason '
      'finalDestination=${finalDestination.route} '
      'decisionSource=${finalDestination.decisionSource} '
      'decisionReason=${finalDestination.reason}',
    );
  }

  void _logPersistenceAttempt(
    NavigationClassification classification, {
    bool? acceptedOverride,
    String? reasonOverride,
  }) {
    final uri = Uri.tryParse(classification.requestedRoute);
    final routePath = uri?.path.trim().isNotEmpty == true
        ? uri!.path
        : '<unknown>';
    traceRestoration(
      '[navPersist] request route=${classification.requestedRoute} '
      'path=$routePath '
      'source=${classification.source.wireName} '
      'classification=${classification.routeClass.wireName} '
      'accepted=${acceptedOverride ?? classification.accepted} '
      'reason=${reasonOverride ?? classification.reason} '
      'section=${classification.section?.wireName ?? '<none>'} '
      'canonical=${classification.canonicalRoute ?? '<none>'}',
    );
  }

  void _logAuthDeferredReplay({
    required String currentRoute,
    required String? restoredRoute,
    required bool accepted,
    required String reason,
    String? decisionSource,
  }) {
    traceRestoration(
      '[navRestore] auth deferred replay current=$currentRoute '
      'restored=${restoredRoute ?? '<none>'} '
      'accepted=$accepted reason=$reason '
      'decisionSource=${decisionSource ?? '<none>'} '
      'finalRoute=${accepted ? restoredRoute ?? '<none>' : currentRoute}',
    );
  }

  static String? _normalizedInternalRoute(String? route) {
    final normalized = route?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        uri.hasScheme ||
        uri.host.isNotEmpty ||
        !uri.path.startsWith('/')) {
      return normalized;
    }
    return uri.toString();
  }

  static bool _isRootRoute(String route) {
    final uri = Uri.tryParse(route.trim());
    return uri == null || uri.path.isEmpty || uri.path == '/';
  }

  static bool _sameRouteLocation(String a, String b) {
    final aUri = Uri.tryParse(a.trim());
    final bUri = Uri.tryParse(b.trim());
    if (aUri == null || bUri == null) return a.trim() == b.trim();
    final aPath = aUri.path.isEmpty ? '/' : aUri.path;
    final bPath = bUri.path.isEmpty ? '/' : bUri.path;
    return aPath == bPath && aUri.query == bUri.query;
  }
}
