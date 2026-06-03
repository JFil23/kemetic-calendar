import 'route_location_sanitizer.dart';

const int navigationPersistenceSchemaVersion = 1;
const String navigationLaunchRouteMetadataKey = 'launchRouteMetadata';

enum AppSection { calendar, inbox, journal, settings, profile }

enum NavigationRouteClass {
  durablePrimary,
  pageState,
  transient,
  oneShotIntent,
  unknown,
}

enum NavigationSource {
  userPrimaryTab,
  programmatic,
  calendarDidPushNext,
  calendarDispose,
  detailRestoration,
  modalLifecycle,
  notificationTap,
  searchResultTap,
  sharedCalendarEventTap,
  nodeActionUrl,
  authCallback,
  appLink,
  sessionResume,
  bootRestore,
  unknown,
}

extension NavigationRouteClassWireName on NavigationRouteClass {
  String get wireName {
    switch (this) {
      case NavigationRouteClass.durablePrimary:
        return 'durablePrimary';
      case NavigationRouteClass.pageState:
        return 'pageState';
      case NavigationRouteClass.transient:
        return 'transient';
      case NavigationRouteClass.oneShotIntent:
        return 'oneShotIntent';
      case NavigationRouteClass.unknown:
        return 'unknown';
    }
  }
}

extension NavigationSourceWireName on NavigationSource {
  String get wireName {
    switch (this) {
      case NavigationSource.userPrimaryTab:
        return 'userPrimaryTab';
      case NavigationSource.programmatic:
        return 'programmatic';
      case NavigationSource.calendarDidPushNext:
        return 'calendarDidPushNext';
      case NavigationSource.calendarDispose:
        return 'calendarDispose';
      case NavigationSource.detailRestoration:
        return 'detailRestoration';
      case NavigationSource.modalLifecycle:
        return 'modalLifecycle';
      case NavigationSource.notificationTap:
        return 'notificationTap';
      case NavigationSource.searchResultTap:
        return 'searchResultTap';
      case NavigationSource.sharedCalendarEventTap:
        return 'sharedCalendarEventTap';
      case NavigationSource.nodeActionUrl:
        return 'nodeActionUrl';
      case NavigationSource.authCallback:
        return 'authCallback';
      case NavigationSource.appLink:
        return 'appLink';
      case NavigationSource.sessionResume:
        return 'sessionResume';
      case NavigationSource.bootRestore:
        return 'bootRestore';
      case NavigationSource.unknown:
        return 'unknown';
    }
  }
}

NavigationRouteClass navigationRouteClassFromWireName(String? raw) {
  switch (raw?.trim()) {
    case 'durablePrimary':
      return NavigationRouteClass.durablePrimary;
    case 'pageState':
      return NavigationRouteClass.pageState;
    case 'transient':
      return NavigationRouteClass.transient;
    case 'oneShotIntent':
      return NavigationRouteClass.oneShotIntent;
    case 'unknown':
    default:
      return NavigationRouteClass.unknown;
  }
}

NavigationSource navigationSourceFromWireName(String? raw) {
  switch (raw?.trim()) {
    case 'userPrimaryTab':
      return NavigationSource.userPrimaryTab;
    case 'programmatic':
      return NavigationSource.programmatic;
    case 'calendarDidPushNext':
      return NavigationSource.calendarDidPushNext;
    case 'calendarDispose':
      return NavigationSource.calendarDispose;
    case 'detailRestoration':
      return NavigationSource.detailRestoration;
    case 'modalLifecycle':
      return NavigationSource.modalLifecycle;
    case 'notificationTap':
      return NavigationSource.notificationTap;
    case 'searchResultTap':
      return NavigationSource.searchResultTap;
    case 'sharedCalendarEventTap':
      return NavigationSource.sharedCalendarEventTap;
    case 'nodeActionUrl':
      return NavigationSource.nodeActionUrl;
    case 'authCallback':
      return NavigationSource.authCallback;
    case 'appLink':
      return NavigationSource.appLink;
    case 'sessionResume':
      return NavigationSource.sessionResume;
    case 'bootRestore':
      return NavigationSource.bootRestore;
    case 'unknown':
    default:
      return NavigationSource.unknown;
  }
}

class NavigationLaunchRouteMetadata {
  const NavigationLaunchRouteMetadata({
    required this.schemaVersion,
    required this.source,
    required this.routeClass,
  });

  final int schemaVersion;
  final NavigationSource source;
  final NavigationRouteClass routeClass;

  bool get isCurrentUserPrimaryDurable {
    return schemaVersion == navigationPersistenceSchemaVersion &&
        source == NavigationSource.userPrimaryTab &&
        routeClass == NavigationRouteClass.durablePrimary;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'source': source.wireName,
      'routeClass': routeClass.wireName,
    };
  }

  static NavigationLaunchRouteMetadata? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final schemaVersion = (raw['schemaVersion'] as num?)?.toInt();
    if (schemaVersion == null) return null;
    return NavigationLaunchRouteMetadata(
      schemaVersion: schemaVersion,
      source: navigationSourceFromWireName(raw['source'] as String?),
      routeClass: navigationRouteClassFromWireName(
        raw['routeClass'] as String?,
      ),
    );
  }
}

class NavigationClassification {
  const NavigationClassification({
    required this.requestedRoute,
    required this.source,
    required this.routeClass,
    required this.accepted,
    required this.reason,
    this.canonicalRoute,
    this.section,
  });

  final String requestedRoute;
  final String? canonicalRoute;
  final NavigationSource source;
  final NavigationRouteClass routeClass;
  final bool accepted;
  final String reason;
  final AppSection? section;

  NavigationLaunchRouteMetadata get metadata => NavigationLaunchRouteMetadata(
    schemaVersion: navigationPersistenceSchemaVersion,
    source: source,
    routeClass: routeClass,
  );
}

class NavigationPersistencePolicy {
  const NavigationPersistencePolicy();

  static const Set<NavigationSource> oneShotSources = <NavigationSource>{
    NavigationSource.notificationTap,
    NavigationSource.searchResultTap,
    NavigationSource.sharedCalendarEventTap,
    NavigationSource.nodeActionUrl,
    NavigationSource.authCallback,
    NavigationSource.appLink,
  };

  static const Set<NavigationSource> pageStateSources = <NavigationSource>{
    NavigationSource.calendarDidPushNext,
    NavigationSource.calendarDispose,
    NavigationSource.detailRestoration,
  };

  String routeForSection(AppSection section) {
    switch (section) {
      case AppSection.calendar:
        return '/';
      case AppSection.inbox:
        return '/inbox';
      case AppSection.journal:
        return '/journal';
      case AppSection.settings:
        return '/settings';
      case AppSection.profile:
        return '/profile/me';
    }
  }

  AppSection? sectionForDurableRoute(String route) {
    final uri = Uri.tryParse(route.trim());
    if (uri == null || uri.hasScheme || uri.host.isNotEmpty) return null;
    if (uri.hasQuery || uri.fragment.isNotEmpty) return null;
    switch (uri.path) {
      case '/':
        return AppSection.calendar;
      case '/inbox':
        return AppSection.inbox;
      case '/journal':
        return AppSection.journal;
      case '/settings':
        return AppSection.settings;
      case '/profile/me':
        return AppSection.profile;
    }
    return null;
  }

  NavigationClassification classifyRoute(
    String route,
    NavigationSource source,
  ) {
    final requested = route.trim();
    if (requested.isEmpty) {
      return NavigationClassification(
        requestedRoute: route,
        source: source,
        routeClass: NavigationRouteClass.unknown,
        accepted: false,
        reason: 'empty_route',
      );
    }

    final sanitized = stableRouteLocationForContinuity(requested);
    final uri = Uri.tryParse(requested);
    if (uri == null ||
        uri.hasScheme ||
        uri.host.isNotEmpty ||
        !uri.path.startsWith('/')) {
      return NavigationClassification(
        requestedRoute: requested,
        source: source,
        routeClass: NavigationRouteClass.unknown,
        accepted: false,
        reason: 'invalid_internal_route',
      );
    }

    if (oneShotSources.contains(source)) {
      final canonicalRoute = source == NavigationSource.authCallback
          ? '/'
          : sanitized;
      return NavigationClassification(
        requestedRoute: requested,
        canonicalRoute: canonicalRoute,
        source: source,
        routeClass: NavigationRouteClass.oneShotIntent,
        accepted: false,
        reason: canonicalRoute == requested
            ? 'one_shot_intent'
            : 'one_shot_intent_sanitized',
      );
    }

    if (pageStateSources.contains(source)) {
      return NavigationClassification(
        requestedRoute: requested,
        canonicalRoute: sanitized,
        source: source,
        routeClass: NavigationRouteClass.pageState,
        accepted: false,
        reason: 'page_state_source',
      );
    }

    if (source != NavigationSource.userPrimaryTab) {
      return NavigationClassification(
        requestedRoute: requested,
        canonicalRoute: sanitized,
        source: source,
        routeClass: NavigationRouteClass.transient,
        accepted: false,
        reason: 'programmatic_navigation_rejected',
      );
    }

    if (uri.hasQuery || uri.fragment.isNotEmpty) {
      return NavigationClassification(
        requestedRoute: requested,
        canonicalRoute: sanitized,
        source: source,
        routeClass: NavigationRouteClass.transient,
        accepted: false,
        reason: 'query_or_fragment_route',
      );
    }

    if (_isEditDetailOrModalRoute(uri.path)) {
      return NavigationClassification(
        requestedRoute: requested,
        canonicalRoute: sanitized,
        source: source,
        routeClass: NavigationRouteClass.transient,
        accepted: false,
        reason: 'edit_detail_or_modal_route',
      );
    }

    final section = sectionForDurableRoute(sanitized ?? requested);
    if (section == null) {
      return NavigationClassification(
        requestedRoute: requested,
        canonicalRoute: sanitized,
        source: source,
        routeClass: NavigationRouteClass.unknown,
        accepted: false,
        reason: 'unknown_or_non_primary_route',
      );
    }

    final canonical = routeForSection(section);
    return NavigationClassification(
      requestedRoute: requested,
      canonicalRoute: canonical,
      source: source,
      routeClass: NavigationRouteClass.durablePrimary,
      accepted: true,
      reason: 'accepted_user_primary_tab',
      section: section,
    );
  }

  bool isValidDurableLaunchRoute(
    String? route,
    NavigationLaunchRouteMetadata? metadata,
  ) {
    final normalized = route?.trim();
    if (normalized == null || normalized.isEmpty || metadata == null) {
      return false;
    }
    if (!metadata.isCurrentUserPrimaryDurable) return false;
    final classification = classifyRoute(
      normalized,
      NavigationSource.userPrimaryTab,
    );
    return classification.accepted &&
        classification.canonicalRoute == normalized;
  }

  bool _isEditDetailOrModalRoute(String path) {
    if (path.contains('/edit')) return true;
    if (path.contains('/editor/')) return true;
    if (path.contains('/conversation/')) return true;
    if (path.startsWith('/shared-flow/')) return true;
    if (path.startsWith('/event-invite/')) return true;
    if (path.startsWith('/insight-post/')) return true;
    if (path.startsWith('/flow-post/')) return true;
    if (path.startsWith('/journal/entry/')) return true;
    if (path.startsWith('/maat-guidance/')) return true;
    if (path.startsWith('/nodes/')) return true;
    if (path.startsWith('/reflections/')) return true;
    if (path.startsWith('/share/')) return true;
    if (path.startsWith('/rhythm/editor/')) return true;
    return false;
  }
}
