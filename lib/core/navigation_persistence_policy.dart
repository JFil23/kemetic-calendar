import 'route_location_sanitizer.dart';

const int navigationPersistenceSchemaVersion = 2;
const String navigationLaunchRouteMetadataKey = 'launchRouteMetadata';

enum AppSection {
  calendar,
  inbox,
  library,
  journal,
  planner,
  settings,
  profile,
}

enum AppRouteOwner {
  calendar,
  inbox,
  library,
  journal,
  settings,
  profile,
  rhythm,
  reflections,
  sharing,
  guidance,
  unknown,
}

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

extension AppSectionWireName on AppSection {
  String get wireName {
    switch (this) {
      case AppSection.calendar:
        return 'calendar';
      case AppSection.inbox:
        return 'inbox';
      case AppSection.library:
        return 'library';
      case AppSection.journal:
        return 'journal';
      case AppSection.planner:
        return 'planner';
      case AppSection.settings:
        return 'settings';
      case AppSection.profile:
        return 'profile';
    }
  }
}

AppSection? appSectionFromWireName(String? raw) {
  switch (raw?.trim()) {
    case 'calendar':
      return AppSection.calendar;
    case 'inbox':
      return AppSection.inbox;
    case 'library':
      return AppSection.library;
    case 'journal':
      return AppSection.journal;
    case 'planner':
      return AppSection.planner;
    case 'settings':
      return AppSection.settings;
    case 'profile':
      return AppSection.profile;
  }
  return null;
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
    this.section,
    this.canonicalRoute,
    this.recordedAtMs,
  });

  final int schemaVersion;
  final NavigationSource source;
  final NavigationRouteClass routeClass;
  final AppSection? section;
  final String? canonicalRoute;
  final int? recordedAtMs;

  bool get isCurrentUserPrimaryDurable {
    final canonical = canonicalRoute?.trim();
    return schemaVersion == navigationPersistenceSchemaVersion &&
        source == NavigationSource.userPrimaryTab &&
        routeClass == NavigationRouteClass.durablePrimary &&
        section != null &&
        canonical != null &&
        canonical.isNotEmpty;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'source': source.wireName,
      'routeClass': routeClass.wireName,
      if (section != null) 'section': section!.wireName,
      if (canonicalRoute != null) 'canonicalRoute': canonicalRoute,
      if (recordedAtMs != null) 'recordedAtMs': recordedAtMs,
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
      section: appSectionFromWireName(raw['section'] as String?),
      canonicalRoute: (raw['canonicalRoute'] as String?)?.trim(),
      recordedAtMs: (raw['recordedAtMs'] as num?)?.toInt(),
    );
  }
}

class AppRouteDefinition {
  const AppRouteDefinition({
    required this.pattern,
    required this.routeClass,
    required this.owner,
    this.section,
    this.canonicalDurableRoute,
    this.allowedPersistenceSources = const <NavigationSource>{},
    this.allowQueryParameters = false,
    this.canBeOneShotTarget = false,
    this.prefixMatch = false,
  });

  final String pattern;
  final NavigationRouteClass routeClass;
  final AppRouteOwner owner;
  final AppSection? section;
  final String? canonicalDurableRoute;
  final Set<NavigationSource> allowedPersistenceSources;
  final bool allowQueryParameters;
  final bool canBeOneShotTarget;
  final bool prefixMatch;

  bool matchesPath(String path) {
    if (prefixMatch) {
      return path.startsWith(pattern);
    }
    return path == pattern;
  }
}

class AppRouteRegistry {
  const AppRouteRegistry();

  static const List<AppRouteDefinition> routes = <AppRouteDefinition>[
    AppRouteDefinition(
      pattern: '/',
      routeClass: NavigationRouteClass.durablePrimary,
      owner: AppRouteOwner.calendar,
      section: AppSection.calendar,
      canonicalDurableRoute: '/',
      allowedPersistenceSources: <NavigationSource>{
        NavigationSource.userPrimaryTab,
      },
    ),
    AppRouteDefinition(
      pattern: '/flows',
      routeClass: NavigationRouteClass.durablePrimary,
      owner: AppRouteOwner.calendar,
      section: AppSection.calendar,
      canonicalDurableRoute: '/flows',
      allowedPersistenceSources: <NavigationSource>{
        NavigationSource.userPrimaryTab,
      },
    ),
    AppRouteDefinition(
      pattern: '/calendars',
      routeClass: NavigationRouteClass.durablePrimary,
      owner: AppRouteOwner.calendar,
      section: AppSection.calendar,
      canonicalDurableRoute: '/calendars',
      allowedPersistenceSources: <NavigationSource>{
        NavigationSource.userPrimaryTab,
      },
    ),
    AppRouteDefinition(
      pattern: '/inbox',
      routeClass: NavigationRouteClass.durablePrimary,
      owner: AppRouteOwner.inbox,
      section: AppSection.inbox,
      canonicalDurableRoute: '/inbox',
      allowedPersistenceSources: <NavigationSource>{
        NavigationSource.userPrimaryTab,
      },
    ),
    AppRouteDefinition(
      pattern: '/nodes',
      routeClass: NavigationRouteClass.durablePrimary,
      owner: AppRouteOwner.library,
      section: AppSection.library,
      canonicalDurableRoute: '/nodes',
      allowedPersistenceSources: <NavigationSource>{
        NavigationSource.userPrimaryTab,
      },
    ),
    AppRouteDefinition(
      pattern: '/journal',
      routeClass: NavigationRouteClass.durablePrimary,
      owner: AppRouteOwner.journal,
      section: AppSection.journal,
      canonicalDurableRoute: '/journal',
      allowedPersistenceSources: <NavigationSource>{
        NavigationSource.userPrimaryTab,
      },
    ),
    AppRouteDefinition(
      pattern: '/rhythm/today',
      routeClass: NavigationRouteClass.durablePrimary,
      owner: AppRouteOwner.rhythm,
      section: AppSection.planner,
      canonicalDurableRoute: '/rhythm/today',
      allowedPersistenceSources: <NavigationSource>{
        NavigationSource.userPrimaryTab,
      },
      canBeOneShotTarget: true,
    ),
    AppRouteDefinition(
      pattern: '/settings',
      routeClass: NavigationRouteClass.durablePrimary,
      owner: AppRouteOwner.settings,
      section: AppSection.settings,
      canonicalDurableRoute: '/settings',
      allowedPersistenceSources: <NavigationSource>{
        NavigationSource.userPrimaryTab,
      },
    ),
    AppRouteDefinition(
      pattern: '/profile/me',
      routeClass: NavigationRouteClass.durablePrimary,
      owner: AppRouteOwner.profile,
      section: AppSection.profile,
      canonicalDurableRoute: '/profile/me',
      allowedPersistenceSources: <NavigationSource>{
        NavigationSource.userPrimaryTab,
      },
    ),
    AppRouteDefinition(
      pattern: '/inbox/conversation/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.inbox,
      canBeOneShotTarget: true,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/nodes/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.library,
      canBeOneShotTarget: true,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/journal/entry/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.journal,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/flows/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.calendar,
      canBeOneShotTarget: true,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/shared-flow/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.sharing,
      canBeOneShotTarget: true,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/event-invite/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.sharing,
      canBeOneShotTarget: true,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/insight-post/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.profile,
      canBeOneShotTarget: true,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/flow-post/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.profile,
      canBeOneShotTarget: true,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/profile/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.profile,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/profile-search',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.profile,
    ),
    AppRouteDefinition(
      pattern: '/reflections',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.reflections,
    ),
    AppRouteDefinition(
      pattern: '/reflections/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.reflections,
      canBeOneShotTarget: true,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/maat-guidance/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.guidance,
      canBeOneShotTarget: true,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/share/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.sharing,
      canBeOneShotTarget: true,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/rhythm/todo',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.rhythm,
    ),
    AppRouteDefinition(
      pattern: '/rhythm/tracker',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.rhythm,
    ),
    AppRouteDefinition(
      pattern: '/rhythm/decan/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.rhythm,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/rhythm/editor/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.rhythm,
      prefixMatch: true,
    ),
  ];

  AppRouteDefinition routeForPath(String path) {
    for (final definition in routes) {
      if (!definition.prefixMatch && definition.matchesPath(path)) {
        return definition;
      }
    }
    for (final definition in routes) {
      if (definition.prefixMatch && definition.matchesPath(path)) {
        return definition;
      }
    }
    return const AppRouteDefinition(
      pattern: '<unknown>',
      routeClass: NavigationRouteClass.unknown,
      owner: AppRouteOwner.unknown,
    );
  }

  AppRouteDefinition? durableRouteForSection(AppSection section) {
    for (final definition in routes) {
      if (definition.routeClass == NavigationRouteClass.durablePrimary &&
          definition.section == section) {
        return definition;
      }
    }
    return null;
  }

  AppRouteDefinition? durableRouteForLocation(String route) {
    final uri = Uri.tryParse(route.trim());
    if (uri == null ||
        uri.hasScheme ||
        uri.host.isNotEmpty ||
        uri.hasQuery ||
        uri.fragment.isNotEmpty) {
      return null;
    }
    final definition = routeForPath(uri.path);
    if (definition.routeClass != NavigationRouteClass.durablePrimary) {
      return null;
    }
    return definition;
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
    section: section,
    canonicalRoute: canonicalRoute,
    recordedAtMs: DateTime.now().millisecondsSinceEpoch,
  );
}

class NavigationPersistencePolicy {
  const NavigationPersistencePolicy();

  static const AppRouteRegistry registry = AppRouteRegistry();

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
    final definition = registry.durableRouteForSection(section);
    return definition?.canonicalDurableRoute ?? '/';
  }

  AppSection? sectionForDurableRoute(String route) {
    return registry.durableRouteForLocation(route)?.section;
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

    final definition = registry.routeForPath(uri.path);
    if (_isEditDetailOrModalRoute(definition, uri.path)) {
      return NavigationClassification(
        requestedRoute: requested,
        canonicalRoute: sanitized,
        source: source,
        routeClass: definition.routeClass,
        accepted: false,
        reason: 'edit_detail_or_modal_route',
      );
    }

    if (definition.routeClass != NavigationRouteClass.durablePrimary ||
        !definition.allowedPersistenceSources.contains(source) ||
        definition.section == null ||
        definition.canonicalDurableRoute == null) {
      return NavigationClassification(
        requestedRoute: requested,
        canonicalRoute: sanitized,
        source: source,
        routeClass: definition.routeClass,
        accepted: false,
        reason: 'unknown_or_non_primary_route',
      );
    }

    return NavigationClassification(
      requestedRoute: requested,
      canonicalRoute: definition.canonicalDurableRoute,
      source: source,
      routeClass: NavigationRouteClass.durablePrimary,
      accepted: true,
      reason: 'accepted_user_primary_tab',
      section: definition.section,
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
        classification.canonicalRoute == normalized &&
        metadata.canonicalRoute == classification.canonicalRoute &&
        metadata.section == classification.section;
  }

  bool _isEditDetailOrModalRoute(AppRouteDefinition definition, String path) {
    if (definition.routeClass == NavigationRouteClass.transient) return true;
    if (path.contains('/edit')) return true;
    if (path.contains('/editor/')) return true;
    return false;
  }
}
