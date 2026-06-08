import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../services/app_navigation_restoration_controller.dart';
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
  if (router.canPop()) {
    traceRestoration(
      'navigation close_or_return pop fallback=$fallbackLocation',
    );
    router.pop(result);
    return;
  }

  final navigator = Navigator.maybeOf(context);
  if (navigator != null && navigator.canPop()) {
    traceRestoration(
      'navigation close_or_return navigator_pop fallback=$fallbackLocation',
    );
    navigator.pop(result);
    return;
  }

  traceRestoration(
    'navigation close_or_return fallback route=$fallbackLocation',
  );
  context.go(fallbackLocation);
}

Future<T?> openDetailRoute<T>(
  BuildContext context,
  String location, {
  Object? extra,
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
  return pushContext.push<T>(location, extra: extra);
}

void openPrimarySection(BuildContext context, AppSection section) {
  RestorationCoordinator.instance.suppressRestoreForUserNavigation(
    reason: 'open_primary_section',
  );
  unawaited(
    AppNavigationRestorationController.instance.recordPrimaryTabSelection(
      section,
    ),
  );
  context.go(const NavigationPersistencePolicy().routeForSection(section));
}
