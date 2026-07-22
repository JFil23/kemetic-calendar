import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../services/app_navigation_restoration_controller.dart';
import '../services/app_restoration_service.dart';
import '../services/restoration_coordinator.dart';
import '../services/restoration_trace.dart';
import 'navigation_persistence_policy.dart';

void popOrGo(BuildContext context, String fallbackLocation, {Object? result}) {
  closeOrReturn(context, fallbackLocation, result: result);
}

void closeOrReturn(
  BuildContext context,
  String fallbackLocation, {
  Object? result,
}) {
  RestorationCoordinator.instance.suppressRestoreForUserNavigation(
    reason: 'close_or_return',
  );

  final router = GoRouter.of(context);
  final dismissedRoute = router.routerDelegate.currentConfiguration.uri
      .toString();
  if (router.canPop()) {
    traceRestoration(
      'navigation close_or_return pop fallback=$fallbackLocation',
    );
    router.pop(result);
    _recordRouteAfterClose(
      router,
      dismissedRoute: dismissedRoute,
      reason: 'go_router_pop',
    );
    return;
  }

  final navigator = Navigator.maybeOf(context);
  if (navigator != null && navigator.canPop()) {
    traceRestoration(
      'navigation close_or_return navigator_pop fallback=$fallbackLocation',
    );
    navigator.pop(result);
    _recordRouteAfterClose(
      router,
      dismissedRoute: dismissedRoute,
      reason: 'navigator_pop',
    );
    return;
  }

  final dismissedClassification = AppNavigationRestorationController.instance
      .classifyRoute(dismissedRoute, NavigationSource.userDismissal);
  if (dismissedClassification.routeClass == NavigationRouteClass.utility) {
    unawaited(
      _closeUtilityWithoutLocalStack(
        context,
        router,
        dismissedRoute: dismissedRoute,
      ),
    );
    return;
  }

  traceRestoration(
    'navigation close_or_return fallback route=$fallbackLocation',
  );
  context.go(fallbackLocation);
  unawaited(
    AppNavigationRestorationController.instance.recordSurfaceDismissal(
      dismissedRoute: dismissedRoute,
      fallbackRoute: fallbackLocation,
      source: NavigationSource.userDismissal,
    ),
  );
}

Future<void> _closeUtilityWithoutLocalStack(
  BuildContext context,
  GoRouter router, {
  required String dismissedRoute,
}) async {
  final destination = await AppNavigationRestorationController.instance
      .resolveUtilityFallbackDestination();
  if (!context.mounted) return;

  final currentRoute = router.routerDelegate.currentConfiguration.uri
      .toString();
  if (currentRoute != dismissedRoute) {
    traceRestoration(
      'navigation utility fallback dropped dismissed=$dismissedRoute '
      'current=$currentRoute reason=route_changed',
    );
    return;
  }

  traceRestoration(
    'navigation utility fallback route=${destination.route} '
    'reason=${destination.reason}',
  );
  router.go(destination.route);
  unawaited(
    AppNavigationRestorationController.instance.recordSurfaceDismissal(
      dismissedRoute: dismissedRoute,
      fallbackRoute: destination.route,
      source: NavigationSource.userDismissal,
    ),
  );
}

void _recordRouteAfterClose(
  GoRouter router, {
  required String dismissedRoute,
  required String reason,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final route = router.routerDelegate.currentConfiguration.uri.toString();
    traceRestoration(
      'navigation close_or_return visible route=$route '
      'dismissed=$dismissedRoute reason=$reason',
    );
    unawaited(
      AppNavigationRestorationController.instance.recordSurfaceDismissal(
        dismissedRoute: dismissedRoute,
        fallbackRoute: route,
        source: NavigationSource.userBack,
      ),
    );
  });
}

Future<T?> openDetailRoute<T>(
  BuildContext context,
  String location, {
  Object? extra,
  GoRouter? router,
  NavigationSource source = NavigationSource.programmatic,
}) {
  RestorationCoordinator.instance.suppressRestoreForUserNavigation(
    reason: 'open_detail_route',
  );
  unawaited(
    AppNavigationRestorationController.instance.recordNavigationAttempt(
      route: location,
      source: source,
    ),
  );
  if (router != null) return router.push<T>(location, extra: extra);
  return context.push<T>(location, extra: extra);
}

Future<T?> openUtilityRoute<T>(
  BuildContext context,
  String location, {
  Object? extra,
  BuildContext? navigationContext,
  GoRouter? router,
  NavigationSource source = NavigationSource.programmatic,
}) {
  RestorationCoordinator.instance.suppressRestoreForUserNavigation(
    reason: 'open_utility_route',
  );
  unawaited(
    AppNavigationRestorationController.instance.recordNavigationAttempt(
      route: location,
      source: source,
    ),
  );

  final pushContext = navigationContext != null && navigationContext.mounted
      ? navigationContext
      : context;
  final routeController = router ?? GoRouter.of(pushContext);
  final currentUri = routeController.routerDelegate.currentConfiguration.uri;
  final targetUri = Uri.tryParse(location.trim());
  if (targetUri != null &&
      currentUri.path == targetUri.path &&
      currentUri.query == targetUri.query) {
    traceRestoration('navigation utility_route noop route=$location');
    return Future<T?>.value();
  }

  traceRestoration('navigation utility_route push route=$location');
  if (router != null) return router.push<T>(location, extra: extra);
  return pushContext.push<T>(location, extra: extra);
}

Future<AppRestorationMutationResult> recordPrimarySectionSelection(
  AppSection section,
) async {
  RestorationCoordinator.instance.suppressRestoreForUserNavigation(
    reason: 'open_primary_section',
  );
  await RestorationCoordinator.instance.flushCalendarForPrimaryNavigation();
  return AppNavigationRestorationController.instance
      .recordPrimaryTabSelectionWithResult(section);
}

Future<void> openPrimarySection(
  BuildContext context,
  AppSection section, {
  GoRouter? router,
}) {
  return recordPrimaryTabSelectionAndOpen(
    section,
    navigate: (location) {
      if (router != null) {
        router.go(location);
        return;
      }
      context.go(location);
    },
  );
}

Future<void> recordPrimaryTabSelectionAndOpen(
  AppSection section, {
  required void Function(String location) navigate,
}) async {
  final location = const NavigationPersistencePolicy().routeForSection(section);
  if (!AppRestorationService.instance.requiresAcknowledgedDurableWrites) {
    unawaited(recordPrimarySectionSelection(section));
    navigate(location);
    return;
  }
  final result = await recordPrimarySectionSelection(section);
  if (result.status != AppRestorationMutationStatus.persisted) {
    traceRestoration(
      'navigation primary_section blocked section=${section.wireName} '
      'reason=durable_write_${result.status.name}',
    );
    return;
  }
  navigate(location);
}
