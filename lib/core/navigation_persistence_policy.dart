import 'route_location_sanitizer.dart';

const int navigationPersistenceSchemaVersion = 2;
const String navigationLaunchRouteMetadataKey = 'launchRouteMetadata';
const String navigationPrimarySelectionMetadataKey = 'primarySelectionMetadata';

enum AppSection {
  calendar,
  inbox,
  library,
  journal,
  planner,
  settings,
  reflections,
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
  utility,
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
      case NavigationRouteClass.utility:
        return 'utility';
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
      case AppSection.reflections:
        return 'reflections';
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
    case 'reflections':
      return AppSection.reflections;
    case 'profile':
      return AppSection.profile;
  }
  return null;
}

NavigationRouteClass navigationRouteClassFromWireName(String? raw) {
  switch (raw?.trim()) {
    case 'durablePrimary':
      return NavigationRouteClass.durablePrimary;
    case 'utility':
      return NavigationRouteClass.utility;
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
    this.canRecordPrimarySelection,
    this.canRestoreAsSurface,
  });

  final int schemaVersion;
  final NavigationSource source;
  final NavigationRouteClass routeClass;
  final AppSection? section;
  final String? canonicalRoute;
  final int? recordedAtMs;
  final bool? canRecordPrimarySelection;
  final bool? canRestoreAsSurface;

  bool get isCurrentUserPrimaryDurable {
    if (canRecordPrimarySelection != null) {
      final canonical = canonicalRoute?.trim();
      return schemaVersion == navigationPersistenceSchemaVersion &&
          canRecordPrimarySelection! &&
          section != null &&
          canonical != null &&
          canonical.isNotEmpty;
    }
    final canonical = canonicalRoute?.trim();
    return schemaVersion == navigationPersistenceSchemaVersion &&
        source == NavigationSource.userPrimaryTab &&
        routeClass == NavigationRouteClass.durablePrimary &&
        section != null &&
        canonical != null &&
        canonical.isNotEmpty;
  }

  bool get isRestorableSurface {
    if (canRestoreAsSurface != null) {
      final canonical = canonicalRoute?.trim();
      return schemaVersion == navigationPersistenceSchemaVersion &&
          canRestoreAsSurface! &&
          canonical != null &&
          canonical.isNotEmpty;
    }
    return isCurrentUserPrimaryDurable;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'source': source.wireName,
      'routeClass': routeClass.wireName,
      if (section != null) 'section': section!.wireName,
      if (canonicalRoute != null) 'canonicalRoute': canonicalRoute,
      if (recordedAtMs != null) 'recordedAtMs': recordedAtMs,
      if (canRecordPrimarySelection != null)
        'canRecordPrimarySelection': canRecordPrimarySelection,
      if (canRestoreAsSurface != null)
        'canRestoreAsSurface': canRestoreAsSurface,
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
      canRecordPrimarySelection: raw['canRecordPrimarySelection'] is bool
          ? raw['canRecordPrimarySelection'] as bool
          : null,
      canRestoreAsSurface: raw['canRestoreAsSurface'] is bool
          ? raw['canRestoreAsSurface'] as bool
          : null,
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
    this.canRecordPrimarySelection = false,
    this.canRestoreAsSurface = false,
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
  final bool canRecordPrimarySelection;
  final bool canRestoreAsSurface;
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
      canRecordPrimarySelection: true,
      canRestoreAsSurface: true,
    ),
    AppRouteDefinition(
      pattern: '/flows',
      routeClass: NavigationRouteClass.utility,
      owner: AppRouteOwner.calendar,
      canRestoreAsSurface: true,
    ),
    AppRouteDefinition(
      pattern: '/calendars',
      routeClass: NavigationRouteClass.utility,
      owner: AppRouteOwner.calendar,
      canRestoreAsSurface: true,
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
      canRecordPrimarySelection: true,
      canRestoreAsSurface: true,
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
      canRecordPrimarySelection: true,
      canRestoreAsSurface: true,
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
      canRecordPrimarySelection: true,
      canRestoreAsSurface: true,
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
      canRecordPrimarySelection: true,
      canRestoreAsSurface: true,
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
      canRecordPrimarySelection: true,
      canRestoreAsSurface: true,
    ),
    AppRouteDefinition(
      pattern: '/profile/me',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.profile,
      section: AppSection.profile,
      canRestoreAsSurface: true,
    ),
    AppRouteDefinition(
      pattern: '/inbox/conversation/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.inbox,
      section: AppSection.inbox,
      canBeOneShotTarget: true,
      canRestoreAsSurface: true,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/nodes/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.library,
      section: AppSection.library,
      canBeOneShotTarget: true,
      canRestoreAsSurface: true,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/journal/entry/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.journal,
      section: AppSection.journal,
      canRestoreAsSurface: true,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/flows/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.calendar,
      canBeOneShotTarget: true,
      canRestoreAsSurface: true,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/shared-flow/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.sharing,
      canBeOneShotTarget: true,
      canRestoreAsSurface: true,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/event-invite/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.sharing,
      canBeOneShotTarget: true,
      canRestoreAsSurface: true,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/insight-post/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.profile,
      section: AppSection.profile,
      canBeOneShotTarget: true,
      canRestoreAsSurface: true,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/flow-post/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.profile,
      section: AppSection.profile,
      canBeOneShotTarget: true,
      canRestoreAsSurface: true,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/profile/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.profile,
      section: AppSection.profile,
      canRestoreAsSurface: true,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/profile-search',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.profile,
    ),
    AppRouteDefinition(
      pattern: '/reflections',
      routeClass: NavigationRouteClass.durablePrimary,
      owner: AppRouteOwner.reflections,
      section: AppSection.reflections,
      canonicalDurableRoute: '/reflections',
      allowedPersistenceSources: <NavigationSource>{
        NavigationSource.userPrimaryTab,
      },
      canRecordPrimarySelection: true,
      canRestoreAsSurface: true,
    ),
    AppRouteDefinition(
      pattern: '/reflections/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.reflections,
      section: AppSection.reflections,
      canBeOneShotTarget: true,
      canRestoreAsSurface: true,
      prefixMatch: true,
    ),
    AppRouteDefinition(
      pattern: '/maat-guidance/',
      routeClass: NavigationRouteClass.transient,
      owner: AppRouteOwner.guidance,
      canBeOneShotTarget: true,
      canRestoreAsSurface: true,
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
    if (!definition.canRestoreAsSurface) {
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
    required this.canRecordPrimarySelection,
    required this.canRestoreAsSurface,
    this.canonicalRoute,
    this.section,
  });

  final String requestedRoute;
  final String? canonicalRoute;
  final NavigationSource source;
  final NavigationRouteClass routeClass;
  final bool accepted;
  final String reason;
  final bool canRecordPrimarySelection;
  final bool canRestoreAsSurface;
  final AppSection? section;

  NavigationLaunchRouteMetadata get metadata => NavigationLaunchRouteMetadata(
    schemaVersion: navigationPersistenceSchemaVersion,
    source: source,
    routeClass: routeClass,
    section: section,
    canonicalRoute: canonicalRoute,
    recordedAtMs: DateTime.now().millisecondsSinceEpoch,
    canRecordPrimarySelection: canRecordPrimarySelection,
    canRestoreAsSurface: canRestoreAsSurface,
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
        canRecordPrimarySelection: false,
        canRestoreAsSurface: false,
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
        canRecordPrimarySelection: false,
        canRestoreAsSurface: false,
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
        canRecordPrimarySelection: false,
        canRestoreAsSurface: false,
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
        canRecordPrimarySelection: false,
        canRestoreAsSurface: false,
      );
    }

    final sanitizedUri = sanitized == null ? null : Uri.tryParse(sanitized);
    if (sanitized == null ||
        sanitizedUri == null ||
        sanitizedUri.hasScheme ||
        sanitizedUri.host.isNotEmpty ||
        !sanitizedUri.path.startsWith('/')) {
      return NavigationClassification(
        requestedRoute: requested,
        source: source,
        routeClass: NavigationRouteClass.unknown,
        accepted: false,
        reason: 'invalid_sanitized_route',
        canRecordPrimarySelection: false,
        canRestoreAsSurface: false,
      );
    }

    final definition = registry.routeForPath(sanitizedUri.path);
    final canonicalRoute = _canonicalRouteForDefinition(
      definition,
      sanitizedUri,
    );
    if (!definition.canRestoreAsSurface || canonicalRoute == null) {
      return NavigationClassification(
        requestedRoute: requested,
        canonicalRoute: sanitized,
        source: source,
        routeClass: definition.routeClass,
        accepted: false,
        reason: 'unknown_or_non_restorable_route',
        canRecordPrimarySelection: false,
        canRestoreAsSurface: false,
      );
    }

    final canRecordPrimarySelection =
        source == NavigationSource.userPrimaryTab &&
        definition.canRecordPrimarySelection &&
        definition.allowedPersistenceSources.contains(source) &&
        definition.section != null &&
        definition.canonicalDurableRoute != null &&
        canonicalRoute == definition.canonicalDurableRoute;

    return NavigationClassification(
      requestedRoute: requested,
      canonicalRoute: canonicalRoute,
      source: source,
      routeClass: definition.routeClass,
      accepted: true,
      reason: canRecordPrimarySelection
          ? 'accepted_user_primary_tab'
          : canonicalRoute == requested
          ? 'accepted_durable_surface'
          : 'accepted_durable_surface_sanitized',
      section: definition.section,
      canRecordPrimarySelection: canRecordPrimarySelection,
      canRestoreAsSurface: true,
    );
  }

  bool isValidDurableLaunchRoute(
    String? route,
    NavigationLaunchRouteMetadata? metadata,
  ) {
    return isValidDurableSurfaceRoute(route, metadata);
  }

  bool isValidDurableSurfaceRoute(
    String? route,
    NavigationLaunchRouteMetadata? metadata,
  ) {
    final normalized = route?.trim();
    if (normalized == null || normalized.isEmpty || metadata == null) {
      return false;
    }
    if (!metadata.isRestorableSurface) return false;
    final classification = classifyRoute(normalized, metadata.source);
    return classification.accepted &&
        classification.canonicalRoute == normalized &&
        metadata.canonicalRoute == classification.canonicalRoute &&
        metadata.section == classification.section &&
        (metadata.canRestoreAsSurface ?? metadata.isRestorableSurface) ==
            classification.canRestoreAsSurface;
  }

  bool isValidPrimarySelection(NavigationLaunchRouteMetadata? metadata) {
    if (metadata == null || !metadata.isCurrentUserPrimaryDurable) {
      return false;
    }
    final canonical = metadata.canonicalRoute?.trim();
    if (canonical == null || canonical.isEmpty) return false;
    final classification = classifyRoute(
      canonical,
      NavigationSource.userPrimaryTab,
    );
    return classification.canRecordPrimarySelection &&
        classification.canonicalRoute == canonical &&
        metadata.canonicalRoute == classification.canonicalRoute &&
        metadata.section == classification.section;
  }

  String? _canonicalRouteForDefinition(
    AppRouteDefinition definition,
    Uri sanitizedUri,
  ) {
    if (!definition.canRestoreAsSurface) return null;
    if (definition.canRecordPrimarySelection &&
        definition.canonicalDurableRoute != null &&
        !sanitizedUri.hasQuery &&
        sanitizedUri.fragment.isEmpty) {
      return definition.canonicalDurableRoute;
    }
    if (definition.allowQueryParameters && sanitizedUri.hasQuery) {
      return sanitizedUri.toString();
    }
    return Uri(path: sanitizedUri.path).toString();
  }
}
