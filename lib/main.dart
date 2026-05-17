// lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:file_picker/file_picker.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:go_router/go_router.dart';

import 'data/user_events_repo.dart';
import 'features/calendar/notify.dart';
import 'features/calendar/calendar_page.dart';
import 'features/calendar/ics_preview_card.dart';
import 'utils/ics_parser.dart';
import 'features/sharing/share_preview_page.dart';
import 'features/inbox/inbox_page.dart';
import 'features/inbox/inbox_conversation_page.dart';
import 'features/inbox/conversation_user.dart';
import 'features/inbox/shared_flow_details_entry.dart';
import 'features/inbox/shared_flow_details_page.dart';
import 'features/invites/event_invite_details_page.dart';
import 'data/profile_model.dart';
import 'data/profile_repo.dart';
import 'data/flow_post_model.dart';
import 'data/insight_post_model.dart';
import 'data/maat_guidance_repo.dart';
import 'data/profile_avatar_glyphs.dart';
import 'data/share_models.dart';
import 'utils/event_cid_util.dart';
import 'telemetry/telemetry.dart';
import 'shared/glossy_text.dart';

import 'utils/hive_local_storage_web.dart';
import 'core/async_guard.dart';
import 'core/app_link_intent.dart';
import 'core/global_bottom_menu_metrics.dart';
import 'core/global_menu_routes.dart';
import 'core/planner_launch_intent.dart';
import 'core/push_intent_bus.dart';
import 'core/shared_file_intent.dart';
import 'core/theme/app_theme.dart';
import 'services/calendar_sync_service.dart';
import 'services/push_notifications.dart';
import 'services/decan_reflection_scheduler.dart';
import 'features/journal/journal_controller.dart';
import 'features/journal/journal_entry_detail_page.dart';
import 'features/journal/journal_page.dart';
import 'features/maat_guidance/maat_guidance_controller.dart';
import 'features/maat_guidance/maat_guidance_detail_page.dart';
import 'features/maat_guidance/maat_guidance_floating_card.dart';
import 'features/nodes/kemetic_node_library.dart';
import 'features/nodes/kemetic_node_list_page.dart';
import 'features/nodes/kemetic_node_reader_page.dart';
import 'features/profile/edit_profile_page.dart';
import 'features/profile/flow_post_detail_page.dart';
import 'features/profile/flow_post_picker_page.dart';
import 'features/profile/follow_list_page.dart';
import 'features/profile/insight_post_detail_page.dart';
import 'features/profile/insight_post_picker_page.dart';
import 'features/profile/profile_page.dart';
import 'features/profile/profile_search_page.dart';
import 'features/reflections/decan_reflection_archive_page.dart';
import 'features/rhythm/pages/commitment_tracker_page.dart';
import 'features/rhythm/pages/rhythm_editors.dart';
import 'features/rhythm/pages/todays_alignment_page.dart';
import 'features/settings/settings_page.dart';
import 'features/settings/settings_prefs.dart';
import 'features/reflections/decan_reflection_detail_page.dart';
import 'widgets/inbox_icon_with_badge.dart';
import 'widgets/kemetic_keyboard.dart';
import 'widgets/kemetic_day_info.dart';
import 'services/app_restoration_service.dart';
import 'services/app_window_service.dart';
import 'services/restoration_coordinator.dart';
import 'services/session_resume_service.dart';

// Conditional import: on web we use URL cleanup + visibility hook; elsewhere no-ops.
import 'utils/web_history.dart'
    if (dart.library.html) 'utils/web_history_web.dart';

// ---- Supabase configuration via --dart-define ----
const supabaseUrlEnv = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKeyEnv = String.fromEnvironment('SUPABASE_ANON_KEY');

// Silences console output in release/profile builds to keep store reviews clean
final ZoneSpecification _releasePrintSilencer = ZoneSpecification(
  print: (self, parent, zone, line) {
    if (kDebugMode) parent.print(zone, line);
  },
);

Future<({String url, String anonKey})> _loadSupabaseConfig() async {
  var url = supabaseUrlEnv.trim();
  var anonKey = supabaseAnonKeyEnv.trim();

  if ((url.isEmpty || anonKey.length <= 20) && !kReleaseMode) {
    try {
      final raw = await rootBundle.loadString('env/dev.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final fileUrl = (json['SUPABASE_URL'] as String?)?.trim() ?? '';
      final fileKey = (json['SUPABASE_ANON_KEY'] as String?)?.trim() ?? '';
      final looksServiceRole =
          fileKey.toLowerCase().contains('service_role') ||
          fileKey.toLowerCase().contains('service-role');
      if (kDebugMode && looksServiceRole) {
        debugPrint(
          '[env] Ignoring service_role key in env/dev.json; only anon keys allowed.',
        );
      }
      final looksPlaceholder =
          fileUrl.contains('YOUR_PROJECT_REF') ||
          fileKey.contains('YOUR_SUPABASE_ANON_KEY');

      if (fileUrl.isNotEmpty &&
          fileKey.length > 20 &&
          !looksServiceRole &&
          !looksPlaceholder) {
        url = fileUrl;
        anonKey = fileKey;
        if (kDebugMode) {
          debugPrint('[env] Loaded Supabase config from env/dev.json');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[env] Failed to load env/dev.json: $e');
      }
    }
  }

  return (url: url, anonKey: anonKey);
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<bool> _webAuthExchangeInProgress = ValueNotifier<bool>(
  false,
);
bool _deferSessionResumeForPushNavigation = false;
String? _bootRestoredLocation;

void _configureLogging() {
  if (kReleaseMode || kProfileMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
}

// Kick off heavier services without blocking the first frame.
void _startBackgroundWarmups() {
  unawaited(() async {
    try {
      await Notify.init();
    } catch (_) {
      // best-effort; AuthGate will retry
    }
  }());

  unawaited(() async {
    try {
      await PushNotifications.instance(Supabase.instance.client).init();
    } catch (_) {
      // best-effort; registration path will retry
    }
  }());
}

Future<void> main() async {
  await runZoned(() async {
    _configureLogging();

    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('[boot] main() executed');

    // Register background handler for FCM (no-op on web)
    registerPushBackgroundHandler();

    final supabaseConfig = await _loadSupabaseConfig();

    if (kDebugMode) {
      debugPrint('🔍 SUPABASE_URL: ${supabaseConfig.url}');
      final key = supabaseConfig.anonKey;
      final startLen = key.length >= 8 ? 8 : key.length;
      final endLen = key.length >= 6 ? 6 : key.length;
      final maskedKey = key.isEmpty
          ? '<empty>'
          : '${key.substring(0, startLen)}...${key.substring(key.length - endLen)} (len=${key.length})';
      debugPrint(
        '🔍 ANON_KEY present: ${key.isNotEmpty}, fingerprint: $maskedKey',
      );
    }

    if (supabaseConfig.url.isEmpty || supabaseConfig.anonKey.length <= 20) {
      runApp(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(child: Text('Missing Supabase configuration.')),
          ),
        ),
      );
      return;
    }

    // Normalize URL: strip trailing slash if present
    final supabaseUrl = supabaseConfig.url.endsWith('/')
        ? supabaseConfig.url.substring(0, supabaseConfig.url.length - 1)
        : supabaseConfig.url;

    await Supabase.initialize(
      url: supabaseUrl, // Use normalized URL
      anonKey: supabaseConfig.anonKey,
      authOptions: FlutterAuthClientOptions(
        autoRefreshToken: true,
        localStorage: kIsWeb ? HiveLocalStorageWeb() : null,
      ),
    );

    await _refreshSessionIfNeeded('boot');

    await ProfileRepo(Supabase.instance.client).preloadLocalCaches();

    await AppWindowService.instance.ensureInitialized();
    await AppRestorationService.instance.initialize();
    _bootRestoredLocation = await _readBootRestoredLocation();
    RestorationCoordinator.instance.beginLaunchRestore(
      reason: RestorationRestoreReason.coldLaunch,
      targetLocation: _bootRestoredLocation ?? '/',
    );

    // 🚨 Initialize notifications/push without blocking the first frame.
    // AuthGate will re-attempt on sign-in if these fail.
    _startBackgroundWarmups();

    // Web/PWA boot hardening (iOS PWA friendly)
    _startWebBootTasks();

    runApp(const MyApp());
  }, zoneSpecification: _releasePrintSilencer);
}

final supabase = Supabase.instance.client;

/* ───────────────────────── Helpers for web/PWA ───────────────────────── */

void _startWebBootTasks() {
  if (!kIsWeb) return;
  AppWindowService.instance.installWebLifecycleLogging(
    onEvent: _handleWebContinuityLifecycleEvent,
  );
  _webAuthExchangeInProgress.value = Uri.base.queryParameters.containsKey(
    'code',
  );
  _installVisibilityRefresh();
  unawaited(_completeWebOAuthIfNeeded());
  unawaited(_refreshSessionIfNeeded('web boot'));
}

void _handleWebContinuityLifecycleEvent(
  String event,
  Map<String, Object?> detail,
) {
  switch (event) {
    case 'visibilitychange':
      final state = detail['state']?.toString();
      if (state == 'hidden') {
        RestorationCoordinator.instance.noteLifecycleState(
          AppLifecycleState.hidden,
        );
        unawaited(RestorationCoordinator.instance.flush());
      } else if (state == 'visible') {
        RestorationCoordinator.instance.noteLifecycleState(
          AppLifecycleState.resumed,
        );
      }
      break;
    case 'pagehide':
    case 'beforeunload':
    case 'freeze':
      RestorationCoordinator.instance.noteLifecycleState(
        AppLifecycleState.detached,
      );
      unawaited(RestorationCoordinator.instance.flush());
      break;
    case 'pageshow':
      RestorationCoordinator.instance.noteLifecycleState(
        AppLifecycleState.resumed,
      );
      break;
  }
}

Future<void> _completeWebOAuthIfNeeded() async {
  if (!kIsWeb) return;

  final uri = Uri.base;
  final hasCode = uri.queryParameters.containsKey('code');
  if (!hasCode) return;

  _webAuthExchangeInProgress.value = true;
  try {
    // Exchange PKCE code -> session (persists it) without blocking first paint.
    await Supabase.instance.client.auth
        .exchangeCodeForSession(uri.toString())
        .timeout(const Duration(seconds: 12));

    // Clean URL so refreshes don't re-exchange.
    replaceUrlWithoutQuery();

    // Nudge the standalone webview after returning from external auth.
    nudgeStandaloneWebView();

    unawaited(Supabase.instance.client.auth.refreshSession());
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[web-auth] exchangeCodeForSession failed: $e');
    }
  } finally {
    _webAuthExchangeInProgress.value = false;
  }
}

Future<void> _refreshSessionIfNeeded(String origin) async {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null || !session.isExpired) return;

  try {
    await Supabase.instance.client.auth.refreshSession().timeout(
      const Duration(seconds: 8),
    );
    if (kDebugMode) {
      debugPrint('[auth] refreshed expired session during $origin');
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[auth] failed to refresh expired session during $origin: $e');
    }
  }
}

Future<void> _waitForWebAuthExchangeToSettle() async {
  if (!_webAuthExchangeInProgress.value) return;

  final completer = Completer<void>();
  late VoidCallback listener;
  listener = () {
    if (!_webAuthExchangeInProgress.value && !completer.isCompleted) {
      _webAuthExchangeInProgress.removeListener(listener);
      completer.complete();
    }
  };

  _webAuthExchangeInProgress.addListener(listener);
  listener();
  try {
    await completer.future.timeout(const Duration(seconds: 12));
  } on TimeoutException {
    _webAuthExchangeInProgress.removeListener(listener);
  }
}

void _installVisibilityRefresh() {
  if (!kIsWeb) return;
  // Implemented in utils/web_history_web.dart; no-op on non-web.
  onVisibilityChange(() {
    // fire-and-forget; reduces iOS PWA storage eviction issues
    unawaited(Supabase.instance.client.auth.refreshSession());
    nudgeStandaloneWebView();
  });
}

/* ───────────────────────── Analytics/Event Helpers ───────────────────────── */

class Events {
  static final _repo = UserEventsRepo(supabase);

  static bool get hasSession => supabase.auth.currentSession != null;

  static void debugAuthBanner([String origin = '']) {
    final s = supabase.auth.currentSession;
    if (s == null) {
      debugPrint('[auth] ($origin) NO SESSION');
    } else {
      final t = s.accessToken;
      final tail = t.isEmpty ? '-' : t.substring(0, 10);
      debugPrint('[auth] ($origin) user=${s.user.id} token=$tail…');
    }
  }

  static Future<void> trackIfAuthed(
    String event,
    Map<String, dynamic> props,
  ) async {
    final s = supabase.auth.currentSession;
    if (s == null) {
      debugPrint('[events] skipped "$event" (no session)');
      return;
    }
    try {
      await _repo.track(event: event, properties: props);
      debugPrint('[events] inserted "$event" as ${s.user.id}');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[events] failed "$event": $e');
        debugPrint('$st');
      }
    }
  }
}

/* ───────────────────────── Routing/Telemetry ───────────────────────── */

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
const Color _launchBackdrop = Color(0xFF171518);
final ValueNotifier<int> _floatingMenuModalDepth = ValueNotifier<int>(0);
final ValueNotifier<bool> _launchOverlayDismissed = ValueNotifier<bool>(false);
final _FloatingMenuRouteObserver _floatingMenuRouteObserver =
    _FloatingMenuRouteObserver();
const Duration _floatingMenuModalSettleDelay = Duration(milliseconds: 80);
const Duration _globalBottomMenuBarTransitionDuration = Duration(
  milliseconds: 220,
);
const Curve _globalBottomMenuBarTransitionCurve = Curves.easeOutCubic;
const bool _debugForceGlobalFloatingMenu = bool.fromEnvironment(
  'FORCE_GLOBAL_MENU_FOR_TESTING',
);

class _FloatingMenuRouteObserver extends NavigatorObserver {
  bool _suppressesFloatingMenu(Route<dynamic> route) {
    if (route.settings.name == calendarActionsMenuRouteName) return false;
    return route is PopupRoute;
  }

  void _adjustDepth(int delta) {
    final next = _floatingMenuModalDepth.value + delta;
    _floatingMenuModalDepth.value = next < 0 ? 0 : next;
  }

  void _decrementAfterRouteSettles(Route<dynamic> route) {
    if (route is TransitionRoute<dynamic>) {
      unawaited(
        route.completed.whenComplete(() async {
          await Future<void>.delayed(_floatingMenuModalSettleDelay);
          _adjustDepth(-1);
        }),
      );
      return;
    }
    _adjustDepth(-1);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (_suppressesFloatingMenu(route)) _adjustDepth(1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (_suppressesFloatingMenu(route)) _decrementAfterRouteSettles(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (_suppressesFloatingMenu(route)) _decrementAfterRouteSettles(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute != null && _suppressesFloatingMenu(oldRoute)) {
      _decrementAfterRouteSettles(oldRoute);
    }
    if (newRoute != null && _suppressesFloatingMenu(newRoute)) {
      _adjustDepth(1);
    }
  }
}

/* ───────────────────────── Telemetry Route Observer ───────────────────────── */

class TelemetryRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  void _send(PageRoute<dynamic>? route) {
    final name = route?.settings.name ?? '/';
    unawaited(Events.trackIfAuthed('screen_view', {'route': name}));
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) _send(route);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute) _send(newRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute is PageRoute) _send(previousRoute);
  }
}

/* ───────────────────────── Router Configuration ───────────────────────── */

String _resolveInitialLocation() {
  final defaultRoute = PlatformDispatcher.instance.defaultRouteName.trim();
  if (defaultRoute.isEmpty || defaultRoute == Navigator.defaultRouteName) {
    return _bootRestoredLocation ?? '/';
  }
  return defaultRoute.startsWith('/') ? defaultRoute : '/$defaultRoute';
}

Future<String?> _readBootRestoredLocation() async {
  final hasSession = Supabase.instance.client.auth.currentSession != null;
  final result = await AppRestorationService.instance.readBestSnapshot(
    includeRemote: hasSession,
  );
  if (result.status != AppRestorationReadStatus.restored &&
      result.status != AppRestorationReadStatus.tentative) {
    return null;
  }
  final overlayParentRoute = CalendarPage.restorableOverlayParentRouteFromStack(
    result.snapshot?.overlayStack ?? const <Map<String, dynamic>>[],
  );
  final location = overlayParentRoute ?? result.snapshot?.routeLocation?.trim();
  if (location == null || location.isEmpty || location == '/') {
    return null;
  }
  return _isContinuityRouteLocation(location) ? location : null;
}

bool _isContinuityRouteLocation(String location) {
  final uri = Uri.tryParse(location);
  if (uri == null || !uri.path.startsWith('/')) {
    return false;
  }
  final path = uri.path;
  return path == '/' ||
      path == '/inbox' ||
      path == '/settings' ||
      path == '/profile-search' ||
      path == '/journal' ||
      path == '/nodes' ||
      path == '/reflections' ||
      path.startsWith('/inbox/conversation/') ||
      path.startsWith('/event-invite/') ||
      path.startsWith('/shared-flow/') ||
      path.startsWith('/profile/') ||
      path.startsWith('/insight-post/') ||
      path.startsWith('/flow-post/') ||
      path.startsWith('/journal/entry/') ||
      path.startsWith('/maat-guidance/') ||
      path.startsWith('/nodes/') ||
      path.startsWith('/reflections/') ||
      path.startsWith('/share/') ||
      path.startsWith('/rhythm/');
}

String? _redirectExternalAppLink(Uri uri) {
  if (uri.scheme.isEmpty && uri.host.isEmpty) {
    return null;
  }

  final intent = AppLinkIntent.parse(uri);
  if (intent is PlannerAppLinkIntent) {
    return intent.routeLocation;
  }
  if (intent is ShareAppLinkIntent) {
    return intent.routeLocation;
  }
  return null;
}

String? _redirectRetiredRhythmRoute(Uri uri) {
  final path = uri.path;
  if (path == '/rhythm/mycycle') {
    return '/rhythm/today';
  }
  return null;
}

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: _resolveInitialLocation(),
  restorationScopeId: AppWindowService.instance.restorationScopeId,
  observers: <NavigatorObserver>[
    routeObserver,
    _floatingMenuRouteObserver,
    TelemetryRouteObserver(),
  ],
  redirect: (context, state) =>
      _redirectRetiredRhythmRoute(state.uri) ??
      _redirectExternalAppLink(state.uri),
  routes: [
    GoRoute(path: '/', builder: (context, state) => const AuthGate()),
    GoRoute(
      path: '/inbox',
      builder: (context, state) {
        final shareId = state.uri.queryParameters['share'];
        if (shareId != null) {
          // Redirect to share preview if share parameter exists
          return SessionTrackedRoute(
            location: state.uri.toString(),
            child: SharePreviewPage(
              shareId: shareId,
              token: state.uri.queryParameters['token'],
            ),
          );
        }
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: const InboxPage(),
        );
      },
    ),
    GoRoute(
      path: '/inbox/conversation/:userId',
      builder: (context, state) {
        final userId = Uri.decodeComponent(state.pathParameters['userId']!);
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: InboxConversationRoutePage(
            otherUserId: userId,
            extra: state.extra,
          ),
        );
      },
    ),
    GoRoute(
      path: '/event-invite/:shareId',
      builder: (context, state) {
        final shareId = Uri.decodeComponent(state.pathParameters['shareId']!);
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: EventInviteRoutePage(shareId: shareId, extra: state.extra),
        );
      },
    ),
    GoRoute(
      path: '/shared-flow/:shareId',
      builder: (context, state) {
        final shareId = Uri.decodeComponent(state.pathParameters['shareId']!);
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: SharedFlowRoutePage(shareId: shareId, extra: state.extra),
        );
      },
    ),
    GoRoute(
      path: '/shared-flow/by-flow/:flowId',
      builder: (context, state) {
        final flowId = int.tryParse(state.pathParameters['flowId'] ?? '');
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: SharedFlowRoutePage(flowId: flowId),
        );
      },
    ),
    GoRoute(
      path: '/profile/:userId/followers',
      builder: (context, state) {
        final userId = Uri.decodeComponent(state.pathParameters['userId']!);
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: FollowListPage(userId: userId, type: FollowListType.followers),
        );
      },
    ),
    GoRoute(
      path: '/profile/:userId/following',
      builder: (context, state) {
        final userId = Uri.decodeComponent(state.pathParameters['userId']!);
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: FollowListPage(userId: userId, type: FollowListType.following),
        );
      },
    ),
    GoRoute(
      path: '/profile/me/edit',
      builder: (context, state) => SessionTrackedRoute(
        location: state.uri.toString(),
        child: EditProfileRoutePage(
          requireCompletion:
              state.uri.queryParameters['requireCompletion'] == '1',
        ),
      ),
    ),
    GoRoute(
      path: '/profile-search',
      builder: (context, state) {
        final title = state.uri.queryParameters['title'];
        final hint = state.uri.queryParameters['hint'];
        final fallback = state.uri.queryParameters['fallback'];
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: ProfileSearchPage(
            returnFullResult:
                state.uri.queryParameters['returnFullResult'] == '1',
            titleText: title?.trim().isNotEmpty == true
                ? title!.trim()
                : 'Find People',
            hintText: hint?.trim().isNotEmpty == true
                ? hint!.trim()
                : 'Search by @handle or display name',
            fallbackLocation: fallback?.trim().isNotEmpty == true
                ? fallback!.trim()
                : '/profile/me',
            selectionMode: state.uri.queryParameters['select'] ?? 'profile',
          ),
        );
      },
    ),
    GoRoute(
      path: '/profile/flow-post-picker',
      builder: (context, state) => SessionTrackedRoute(
        location: state.uri.toString(),
        child: const FlowPostPickerPage(),
      ),
    ),
    GoRoute(
      path: '/profile/insight-post-picker',
      builder: (context, state) => SessionTrackedRoute(
        location: state.uri.toString(),
        child: const InsightPostPickerPage(),
      ),
    ),
    GoRoute(
      path: '/profile/:userId',
      builder: (context, state) {
        final rawUserId = Uri.decodeComponent(state.pathParameters['userId']!);
        final currentUserId = supabase.auth.currentUser?.id;
        final userId = rawUserId == 'me' ? currentUserId : rawUserId;
        if (userId == null || userId.trim().isEmpty) {
          return const AuthGate();
        }
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: ProfilePage(
            key: ValueKey(userId),
            userId: userId,
            isMyProfile: currentUserId != null && currentUserId == userId,
          ),
        );
      },
    ),
    GoRoute(
      path: '/insight-post/:postId',
      builder: (context, state) {
        final postId = Uri.decodeComponent(state.pathParameters['postId']!);
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: InsightPostRoutePage(postId: postId, extra: state.extra),
        );
      },
    ),
    GoRoute(
      path: '/flow-post/:postId',
      builder: (context, state) {
        final postId = Uri.decodeComponent(state.pathParameters['postId']!);
        final openComments =
            state.uri.queryParameters['comments'] == '1' ||
            state.uri.queryParameters['openComments'] == '1';
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: FlowPostRoutePage(
            postId: postId,
            openCommentsOnLoad: openComments,
            extra: state.extra,
          ),
        );
      },
    ),
    GoRoute(
      path: '/journal',
      builder: (context, state) => SessionTrackedRoute(
        location: state.uri.toString(),
        child: const JournalRoutePage(),
      ),
    ),
    GoRoute(
      path: '/journal/entry/:entryId',
      builder: (context, state) {
        final entryId = Uri.decodeComponent(state.pathParameters['entryId']!);
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: JournalEntryDetailPage(entryId: entryId),
        );
      },
    ),
    GoRoute(
      path: '/nodes',
      builder: (context, state) => SessionTrackedRoute(
        location: state.uri.toString(),
        child: const KemeticNodeListPage(),
      ),
    ),
    GoRoute(
      path: '/nodes/:nodeId',
      builder: (context, state) {
        final nodeId = Uri.decodeComponent(state.pathParameters['nodeId']!);
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: NodeReaderRoutePage(nodeId: nodeId),
        );
      },
    ),
    GoRoute(
      path: '/reflections',
      builder: (context, state) => SessionTrackedRoute(
        location: state.uri.toString(),
        child: const DecanReflectionArchivePage(),
      ),
    ),
    GoRoute(
      path: '/reflections/:reflectionId',
      builder: (context, state) {
        final reflectionId = Uri.decodeComponent(
          state.pathParameters['reflectionId']!,
        );
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: DecanReflectionDetailPage(reflectionId: reflectionId),
        );
      },
    ),
    GoRoute(
      path: '/maat-guidance/:deliveryId',
      builder: (context, state) {
        final deliveryId = Uri.decodeComponent(
          state.pathParameters['deliveryId']!,
        );
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: MaatGuidanceDetailPage(deliveryId: deliveryId),
        );
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => SessionTrackedRoute(
        location: state.uri.toString(),
        child: const SettingsPage(),
      ),
    ),
    GoRoute(
      path: '/share/:shareId',
      builder: (context, state) {
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: SharePreviewPage(
            shareId: state.pathParameters['shareId']!,
            token: state.uri.queryParameters['token'],
          ),
        );
      },
    ),
    GoRoute(
      path: '/rhythm/today',
      builder: (context, state) {
        final launchIntent =
            PlannerLaunchIntent.parse(state.uri) ??
            PlannerLaunchIntent.fallbackForRoute('/rhythm/today');
        return SessionTrackedRoute(
          location: launchIntent.sessionLocation,
          child: TodaysAlignmentPage(launchIntent: launchIntent),
        );
      },
    ),
    GoRoute(
      path: '/rhythm/todo',
      builder: (context, state) {
        final launchIntent =
            PlannerLaunchIntent.parse(state.uri) ??
            PlannerLaunchIntent.fallbackForRoute('/rhythm/todo');
        return SessionTrackedRoute(
          location: launchIntent.sessionLocation,
          child: TodaysAlignmentPage(launchIntent: launchIntent),
        );
      },
    ),
    GoRoute(
      path: '/rhythm/tracker',
      builder: (context, state) => SessionTrackedRoute(
        location: state.uri.toString(),
        child: const CommitmentTrackerPage(),
      ),
    ),
    GoRoute(
      path: '/rhythm/decan/:dayKey',
      builder: (context, state) {
        final dayKey = Uri.decodeComponent(state.pathParameters['dayKey']!);
        final info = KemeticDayData.getInfoForDay(dayKey);
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: info == null
              ? const _RouteMissingScaffold(
                  message: 'Decan details are not available yet.',
                  fallbackLocation: '/rhythm/today',
                )
              : DecanInfoPage(dayKey: dayKey, info: info),
        );
      },
    ),
    GoRoute(
      path: '/rhythm/editor/timed',
      builder: (context, state) {
        final resume = state.extra is RhythmEditorResumePayload
            ? state.extra as RhythmEditorResumePayload
            : null;
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: TimedRhythmEditorPage(
            initial: resume?.draft,
            categoryDisplay:
                resume?.category ??
                state.uri.queryParameters['category'] ??
                'Rhythm of Day',
          ),
        );
      },
    ),
    GoRoute(
      path: '/rhythm/editor/untimed',
      builder: (context, state) {
        final resume = state.extra is RhythmEditorResumePayload
            ? state.extra as RhythmEditorResumePayload
            : null;
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: UntimedRhythmEditorPage(
            initial: resume?.draft,
            category:
                resume?.category ??
                state.uri.queryParameters['category'] ??
                'Custom',
          ),
        );
      },
    ),
    GoRoute(
      path: '/rhythm/editor/custom',
      builder: (context, state) => SessionTrackedRoute(
        location: state.uri.toString(),
        child: const CustomRhythmEditorPage(),
      ),
    ),
  ],
);

/* ───────────────────────── App Widgets ───────────────────────── */

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      restorationScopeId: AppWindowService.instance.restorationScopeId,
      theme: AppTheme.dark,
      routerConfig: _router,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final isTablet = mq.size.shortestSide >= 600;
        final baseTextScaleFactor = mq.textScaler.scale(16) / 16;
        // Keep the existing tablet text boost while avoiding deprecated APIs.
        final textScaler = isTablet
            ? TextScaler.linear(baseTextScaleFactor * 1.5)
            : mq.textScaler;
        return MediaQuery(
          data: mq.copyWith(textScaler: textScaler),
          child: SessionLifecycleBridge(
            child: PushIntentBridge(
              child: _LaunchShell(
                child: _GlobalFloatingMenuShell(
                  router: _router,
                  child: KemeticKeyboardHost(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlobalFloatingMenuShell extends StatefulWidget {
  const _GlobalFloatingMenuShell({required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  State<_GlobalFloatingMenuShell> createState() =>
      _GlobalFloatingMenuShellState();
}

class _GlobalFloatingMenuShellState extends State<_GlobalFloatingMenuShell>
    with WidgetsBindingObserver {
  late final MaatGuidanceController _maatGuidanceController =
      MaatGuidanceController(MaatGuidanceRepo(supabase));
  Uri _currentUri = Uri(path: '/');
  StreamSubscription<AuthState>? _authSub;
  bool _menuMounted = false;
  bool _menuOpen = false;
  bool _rebuildScheduled = false;
  bool? _lastGuidanceSuppressed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUri = _readRouterUri();
    widget.router.routerDelegate.addListener(_handleRouteChanged);
    widget.router.routeInformationProvider.addListener(_handleRouteChanged);
    _floatingMenuModalDepth.addListener(_handleMenuVisibilityChanged);
    _launchOverlayDismissed.addListener(_handleMenuVisibilityChanged);
    _maatGuidanceController.addListener(_scheduleRebuild);
    _authSub = supabase.auth.onAuthStateChange.listen((_) {
      if (supabase.auth.currentSession == null) {
        _maatGuidanceController.clearForSignedOut();
      } else {
        unawaited(_maatGuidanceController.refresh(force: true));
        unawaited(
          Future<void>.delayed(const Duration(seconds: 2)).then((_) {
            if (mounted) {
              return _maatGuidanceController.refresh(force: true);
            }
          }),
        );
      }
      _scheduleRebuild();
    });
  }

  @override
  void didUpdateWidget(covariant _GlobalFloatingMenuShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router == widget.router) return;
    oldWidget.router.routerDelegate.removeListener(_handleRouteChanged);
    oldWidget.router.routeInformationProvider.removeListener(
      _handleRouteChanged,
    );
    _currentUri = _readRouterUri();
    widget.router.routerDelegate.addListener(_handleRouteChanged);
    widget.router.routeInformationProvider.addListener(_handleRouteChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.router.routerDelegate.removeListener(_handleRouteChanged);
    widget.router.routeInformationProvider.removeListener(_handleRouteChanged);
    _floatingMenuModalDepth.removeListener(_handleMenuVisibilityChanged);
    _launchOverlayDismissed.removeListener(_handleMenuVisibilityChanged);
    _maatGuidanceController.removeListener(_scheduleRebuild);
    _maatGuidanceController.dispose();
    unawaited(_authSub?.cancel());
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() => _handleBackButton();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (supabase.auth.currentSession == null) return;
    unawaited(_maatGuidanceController.evaluateAndRefresh());
  }

  Uri _readRouterUri() {
    final delegateUri = widget.router.routerDelegate.currentConfiguration.uri;
    if (delegateUri.path.isNotEmpty) return delegateUri;
    return widget.router.routeInformationProvider.value.uri;
  }

  void _handleRouteChanged() {
    final nextUri = _readRouterUri();
    if (nextUri == _currentUri) return;
    _currentUri = nextUri;
    if (_menuMounted) {
      _menuMounted = false;
      _menuOpen = false;
    }
    unawaited(_maatGuidanceController.refresh());
    _scheduleRebuild();
  }

  void _handleMenuVisibilityChanged() {
    if (_floatingMenuModalDepth.value > 0 && _menuMounted) {
      _menuMounted = false;
      _menuOpen = false;
    }
    _scheduleRebuild();
  }

  void _scheduleRebuild() {
    if (!mounted || _rebuildScheduled) return;
    _rebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (!mounted) return;
      setState(() {});
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool get _shouldMountFloatingMenu {
    if (!_launchOverlayDismissed.value) return false;
    if (supabase.auth.currentSession == null &&
        !(kDebugMode && _debugForceGlobalFloatingMenu)) {
      return false;
    }
    return true;
  }

  bool get _shouldActivateFloatingMenu =>
      _shouldMountFloatingMenu && _floatingMenuModalDepth.value == 0;

  bool _shouldSuppressMaatGuidance(BuildContext context) {
    if (!_launchOverlayDismissed.value) return true;
    if (supabase.auth.currentSession == null) return true;
    if (_floatingMenuModalDepth.value > 0) return true;
    if (_menuMounted || _menuOpen) return true;
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return true;

    final path = _currentUri.path;
    if (path.startsWith('/maat-guidance/')) return true;
    if (path.startsWith('/rhythm/editor/')) return true;
    return false;
  }

  void _syncMaatGuidanceSuppression(bool suppressed) {
    if (_lastGuidanceSuppressed == suppressed) return;
    _lastGuidanceSuppressed = suppressed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maatGuidanceController.updateSuppression(suppressed);
    });
  }

  void _handleFloatingMenuPressed() {
    if (_menuOpen) {
      unawaited(_closeFloatingMenu());
      return;
    }
    _openFloatingMenu();
  }

  void _openFloatingMenu() {
    if (!_shouldActivateFloatingMenu) return;
    setState(() {
      _menuMounted = true;
      _menuOpen = true;
    });
  }

  Future<void> _closeFloatingMenu() async {
    if (!_menuMounted) return;
    setState(() => _menuOpen = false);
    await Future<void>.delayed(_globalBottomMenuBarTransitionDuration);
    if (!mounted || _menuOpen) return;
    setState(() => _menuMounted = false);
  }

  void _navigateFromMenu(String location) {
    _router.go(location);
  }

  Future<bool> _handleBackButton() async {
    if (!_menuMounted || !_menuOpen) return false;
    await _closeFloatingMenu();
    return true;
  }

  Widget _buildFloatingActionsPanel(BuildContext context) {
    final menuContext =
        _rootNavigatorKey.currentState?.overlay?.context ??
        _rootNavigatorKey.currentContext ??
        context;
    return CalendarPage.buildDetachedActionsMenuPanel(
      menuContext,
      includeNewNote: false,
      onNavigate: _navigateFromMenu,
      closeMenu: _closeFloatingMenu,
    );
  }

  void _handleMenuDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 80) {
      unawaited(_closeFloatingMenu());
    }
  }

  @override
  Widget build(BuildContext context) {
    final shouldMountFloatingMenu = _shouldMountFloatingMenu;
    final shouldActivateFloatingMenu = _shouldActivateFloatingMenu;
    final suppressGuidance = _shouldSuppressMaatGuidance(context);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    _syncMaatGuidanceSuppression(suppressGuidance);

    Widget buildAnimatedFloatingPanel() {
      return AnimatedSlide(
        offset: _menuOpen ? Offset.zero : const Offset(0, 1),
        duration: _globalBottomMenuBarTransitionDuration,
        curve: _globalBottomMenuBarTransitionCurve,
        child: AnimatedOpacity(
          opacity: _menuOpen ? 1 : 0,
          duration: _globalBottomMenuBarTransitionDuration,
          curve: _globalBottomMenuBarTransitionCurve,
          child: _buildFloatingActionsPanel(context),
        ),
      );
    }

    return MaatGuidanceScope(
      controller: _maatGuidanceController,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (shouldMountFloatingMenu && _menuMounted) ...[
            Positioned.fill(
              child: _GlobalMenuBarrier(
                visible: _menuOpen,
                onDismiss: _closeFloatingMenu,
              ),
            ),
            if (isLandscape)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => unawaited(_closeFloatingMenu()),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      onVerticalDragEnd: _handleMenuDragEnd,
                      child: buildAnimatedFloatingPanel(),
                    ),
                  ),
                ),
              )
            else
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragEnd: _handleMenuDragEnd,
                  child: buildAnimatedFloatingPanel(),
                ),
              ),
          ],
          if (shouldMountFloatingMenu)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _GlobalBottomMenuBar(
                visible: shouldActivateFloatingMenu,
                onPressed: _handleFloatingMenuPressed,
              ),
            ),
          MaatGuidanceOverlayHost(
            controller: _maatGuidanceController,
            visible:
                _maatGuidanceController.hasVisibleDelivery && !suppressGuidance,
          ),
        ],
      ),
    );
  }
}

class _GlobalMenuBarrier extends StatelessWidget {
  const _GlobalMenuBarrier({required this.visible, required this.onDismiss});

  final bool visible;
  final Future<void> Function() onDismiss;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: _globalBottomMenuBarTransitionDuration,
      curve: _globalBottomMenuBarTransitionCurve,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(onDismiss()),
        child: const ColoredBox(color: Color(0x73000000)),
      ),
    );
  }
}

class _GlobalBottomMenuBar extends StatelessWidget {
  const _GlobalBottomMenuBar({required this.visible, required this.onPressed});

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final visualHeight = globalBottomMenuHeight(context);

    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 1.08),
          duration: _globalBottomMenuBarTransitionDuration,
          curve: _globalBottomMenuBarTransitionCurve,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: _globalBottomMenuBarTransitionDuration,
            curve: _globalBottomMenuBarTransitionCurve,
            child: Semantics(
              label: 'Menu',
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onPressed,
                child: SizedBox(
                  height: visualHeight,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Color(0xF6000000),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xB3000000),
                          blurRadius: 18,
                          offset: Offset(0, -8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottomPadding),
                      child: const Center(child: _FloatingMenuGlyph()),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingMenuGlyph extends StatelessWidget {
  const _FloatingMenuGlyph();

  @override
  Widget build(BuildContext context) {
    return InboxUnreadDotOverlay(
      top: 1,
      right: 0,
      size: 6.5,
      dotColor: const Color(0xFFFF3B30),
      borderColor: const Color(0xFF07080A),
      borderWidth: 1.05,
      child: const _MenuGlyphText(size: 22, boxSize: 30, yOffset: -1.3),
    );
  }
}

class _MenuGlyphText extends StatelessWidget {
  const _MenuGlyphText({
    required this.size,
    required this.boxSize,
    this.yOffset = 0,
  });

  final double size;
  final double boxSize;
  final double yOffset;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: boxSize,
      child: Center(
        child: Transform.translate(
          offset: Offset(0, yOffset),
          child: ShaderMask(
            shaderCallback: (bounds) => goldGloss.createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Text(
              '𓉹',
              textAlign: TextAlign.center,
              strutStyle: StrutStyle(
                fontSize: size,
                height: 1,
                forceStrutHeight: true,
              ),
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
              style: TextStyle(
                color: Colors.white,
                fontSize: size,
                height: 1,
                letterSpacing: 0,
                fontWeight: FontWeight.w500,
                fontFamily: 'Noto Sans Egyptian Hieroglyphs',
                fontFamilyFallback: meduNeterFontFallback,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PushIntentBridge extends StatefulWidget {
  const PushIntentBridge({super.key, required this.child});

  final Widget child;

  @override
  State<PushIntentBridge> createState() => _PushIntentBridgeState();
}

class _PushIntentBridgeState extends State<PushIntentBridge> {
  static const String _kCalendarPushResumeKind = 'calendar_push_event';
  static const int _kPushNavigationDedupWindowMs = 8000;

  StreamSubscription<Map<String, dynamic>>? _pushNavSub;
  StreamSubscription<AuthState>? _authSub;
  final Map<String, int> _handledPushNavigationKeys = <String, int>{};
  Map<String, dynamic>? _pendingPushData;
  bool _initialTasksStarted = false;

  @override
  void initState() {
    super.initState();

    final push = PushNotifications.instance(supabase);
    _pushNavSub = push.openedMessages.listen(
      (data) {
        runGuardedSync(
          'push intent bridge',
          () => _queueOrHandlePushData(data),
          onError: _logPushBridgeError,
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        _logPushBridgeError('push intent stream', error, stackTrace);
      },
    );

    _authSub = supabase.auth.onAuthStateChange.listen(
      (data) {
        if (supabase.auth.currentSession == null) return;
        final pending = _pendingPushData;
        if (pending == null) return;
        _pendingPushData = null;
        fireAndForgetGuarded(
          'pending push navigation',
          _handlePushNavigationWhenReady(pending),
          onError: _logPushBridgeError,
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        _logPushBridgeError('push intent auth stream', error, stackTrace);
      },
    );

    onPushNotificationTap((data) {
      runGuardedSync(
        'web push tap bridge',
        () => _queueOrHandlePushData(data),
        onError: _logPushBridgeError,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startInitialTasks();
    });
  }

  @override
  void dispose() {
    _pushNavSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  void _logPushBridgeError(String scope, Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;
    debugPrint('[PushIntentBridge] $scope failed: $error');
    debugPrint('$stackTrace');
  }

  void _startInitialTasks() {
    if (_initialTasksStarted) return;
    _initialTasksStarted = true;

    fireAndForgetGuarded(
      'initial push message',
      PushNotifications.instance(supabase).emitInitialMessage(),
      onError: _logPushBridgeError,
    );
    _consumePendingWebPushIntent();
  }

  void _consumePendingWebPushIntent() {
    if (!kIsWeb) return;
    final params = Uri.base.queryParameters;
    final kind = _trimmedValue(params['push_kind'] ?? params['pushKind']);
    if (kind == null) return;

    final data = <String, dynamic>{
      'kind': kind,
      if (_trimmedValue(params['reflection_id'] ?? params['reflectionId']) !=
          null)
        'reflection_id': params['reflection_id'] ?? params['reflectionId'],
      if (_trimmedValue(params['sender_id'] ?? params['senderId']) != null)
        'sender_id': params['sender_id'] ?? params['senderId'],
      if (_trimmedValue(params['share_id'] ?? params['shareId']) != null)
        'share_id': params['share_id'] ?? params['shareId'],
      if (_trimmedValue(params['calendar_id'] ?? params['calendarId']) != null)
        'calendar_id': params['calendar_id'] ?? params['calendarId'],
      if (_trimmedValue(
            params['notification_id'] ?? params['notificationId'],
          ) !=
          null)
        'notification_id':
            params['notification_id'] ?? params['notificationId'],
      if (_trimmedValue(
            params['response_status'] ?? params['responseStatus'],
          ) !=
          null)
        'response_status':
            params['response_status'] ?? params['responseStatus'],
      if (_trimmedValue(params['client_event_id'] ?? params['clientEventId']) !=
          null)
        'client_event_id': params['client_event_id'] ?? params['clientEventId'],
      if (_trimmedValue(params['flow_post_id'] ?? params['flowPostId']) != null)
        'flow_post_id': params['flow_post_id'] ?? params['flowPostId'],
      if (_trimmedValue(params['reminder_id'] ?? params['reminderId']) != null)
        'reminder_id': params['reminder_id'] ?? params['reminderId'],
    };

    replaceUrlWithoutQuery();
    _queueOrHandlePushData(data);
  }

  void _queueOrHandlePushData(Map<String, dynamic> rawData) {
    final data = Map<String, dynamic>.from(rawData);
    if (data.isEmpty) return;

    _deferSessionResumeForPushNavigation = true;

    if (supabase.auth.currentSession == null) {
      _pendingPushData = data;
      return;
    }

    fireAndForgetGuarded(
      'push navigation',
      _handlePushNavigationWhenReady(data),
      onError: _logPushBridgeError,
    );
  }

  String? _trimmedValue(Object? raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    return text.isEmpty ? null : text;
  }

  String _pushNavigationKey(Map<String, dynamic> data) {
    return 'payload:${jsonEncode(_normalizePushNavigationData(data))}';
  }

  Object? _normalizePushNavigationData(Object? value) {
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      return <String, Object?>{
        for (final entry in entries)
          entry.key.toString(): _normalizePushNavigationData(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(_normalizePushNavigationData).toList(growable: false);
    }
    if (value == null || value is num || value is String || value is bool) {
      return value;
    }
    return value.toString();
  }

  void _pruneHandledPushNavigationKeys([int? nowMs]) {
    final thresholdMs =
        (nowMs ?? DateTime.now().millisecondsSinceEpoch) -
        _kPushNavigationDedupWindowMs;
    _handledPushNavigationKeys.removeWhere(
      (_, handledAtMs) => handledAtMs < thresholdMs,
    );
    while (_handledPushNavigationKeys.length > 48) {
      _handledPushNavigationKeys.remove(_handledPushNavigationKeys.keys.first);
    }
  }

  bool _wasHandledRecently(String navigationKey) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _pruneHandledPushNavigationKeys(nowMs);
    final handledAtMs = _handledPushNavigationKeys[navigationKey];
    if (handledAtMs == null) {
      return false;
    }
    return nowMs - handledAtMs <= _kPushNavigationDedupWindowMs;
  }

  void _rememberHandledPushNavigation(String navigationKey) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _handledPushNavigationKeys[navigationKey] = nowMs;
    _pruneHandledPushNavigationKeys(nowMs);
  }

  Future<void> _handlePushNavigationWhenReady(
    Map<String, dynamic> data, {
    int attempt = 0,
  }) async {
    if (!mounted) return;

    final nav = _rootNavigatorKey.currentState;
    if (nav == null) {
      if (attempt >= 20) return;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      return _handlePushNavigationWhenReady(data, attempt: attempt + 1);
    }

    final navigationKey = _pushNavigationKey(data);
    if (_wasHandledRecently(navigationKey)) {
      return;
    }

    final handled = await _handlePushNavigation(data);
    if (!handled) {
      return;
    }

    _rememberHandledPushNavigation(navigationKey);
  }

  Future<bool> _handlePushNavigation(Map<String, dynamic> data) async {
    final kind = _trimmedValue(data['kind'] ?? data['type']);
    if (kind == null) return false;
    final shareKind = _trimmedValue(data['share_kind'] ?? data['shareKind']);

    final reflectionId = _trimmedValue(
      data['reflectionId'] ?? data['reflection_id'],
    );
    if (kind == 'decan_reflection' && reflectionId != null) {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return false;
      _router.go('/reflections/${Uri.encodeComponent(reflectionId)}');
      return true;
    }

    if (kind == 'flow_share' || (kind == 'dm' && shareKind == 'flow')) {
      final shareId = _trimmedValue(data['share_id'] ?? data['shareId']);
      if (shareId != null) {
        _openSharedFlow(shareId);
      } else {
        _router.go('/inbox');
      }
      return true;
    }

    if (kind == 'dm') {
      final senderId = _trimmedValue(data['sender_id'] ?? data['senderId']);
      if (senderId != null) {
        await _openDmConversation(senderId);
      } else {
        _router.go('/inbox');
      }
      return true;
    }

    if (kind == 'follow') {
      _router.go('/inbox');
      return true;
    }

    if (kind == 'event_invite') {
      final shareId = _trimmedValue(data['share_id'] ?? data['shareId']);
      final senderId = _trimmedValue(data['sender_id'] ?? data['senderId']);
      if (shareId != null) {
        await _openEventInvite(shareId, senderId: senderId);
      } else if (senderId != null) {
        await _openDmConversation(senderId);
      } else {
        _router.go('/inbox');
      }
      return true;
    }

    if (kind == 'calendar_invite' || kind == 'calendar_invite_response') {
      _router.go('/inbox');
      return true;
    }

    if (kind == 'flow_like' ||
        kind == 'flow_comment' ||
        kind == 'flow_comment_reply' ||
        kind == 'flow_comment_like') {
      final flowPostId = _trimmedValue(
        data['flow_post_id'] ?? data['flowPostId'],
      );
      if (flowPostId != null) {
        await _openFlowPostActivity(
          flowPostId,
          openCommentsOnLoad: kind != 'flow_like',
        );
      } else {
        _router.go('/inbox');
      }
      return true;
    }

    final clientEventId = _trimmedValue(
      data['client_event_id'] ?? data['clientEventId'],
    );
    if (kind == 'calendar_event' ||
        kind == 'scheduled_notification' ||
        kind == 'reminder_10min' ||
        (clientEventId != null && kind == 'reminder')) {
      if (clientEventId != null) {
        await _openCalendarEventFromPush(clientEventId);
      } else {
        _router.go('/');
      }
      return true;
    }

    if (clientEventId != null) {
      await _openCalendarEventFromPush(clientEventId);
      return true;
    }

    return false;
  }

  void _openSharedFlow(String shareId) {
    _router.go('/shared-flow/${Uri.encodeComponent(shareId)}');
  }

  Future<void> _openDmConversation(String senderId) async {
    try {
      Map<String, dynamic>? profile;
      try {
        profile = await supabase
            .from('profiles')
            .select('id, display_name, handle, avatar_url, avatar_glyphs')
            .eq('id', senderId)
            .maybeSingle();
      } catch (e) {
        if (!_isMissingAvatarGlyphsColumnError(e)) rethrow;
        profile = await supabase
            .from('profiles')
            .select('id, display_name, handle, avatar_url')
            .eq('id', senderId)
            .maybeSingle();
      }

      final otherProfile = ConversationUser(
        id: senderId,
        displayName: (profile?['display_name'] as String?)?.trim(),
        handle: (profile?['handle'] as String?)?.trim(),
        avatarUrl: (profile?['avatar_url'] as String?)?.trim(),
        avatarGlyphIds: parseProfileAvatarGlyphIds(profile?['avatar_glyphs']),
      );

      _router.go(
        '/inbox/conversation/${Uri.encodeComponent(senderId)}',
        extra: otherProfile,
      );
    } catch (_) {
      _router.go('/inbox');
    }
  }

  bool _isMissingAvatarGlyphsColumnError(Object error) {
    if (error is! PostgrestException) return false;
    final text =
        '${error.code} ${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return text.contains('avatar_glyphs') &&
        (error.code == '42703' ||
            error.code == 'PGRST204' ||
            text.contains('column') ||
            text.contains('schema cache'));
  }

  Future<void> _openEventInvite(String shareId, {String? senderId}) async {
    for (final viewName in const [
      'share_filing_items_client',
      'inbox_share_items_filtered',
    ]) {
      try {
        final row = await supabase
            .from(viewName)
            .select()
            .eq('share_id', shareId)
            .maybeSingle();
        if (row != null) {
          final share = InboxShareItem.fromJson(row);
          _router.go(
            '/event-invite/${Uri.encodeComponent(shareId)}',
            extra: share,
          );
          return;
        }
      } catch (_) {
        // Fall back to the next source.
      }
    }

    final directShare = await _loadEventInviteShare(shareId);
    if (directShare != null) {
      _router.go(
        '/event-invite/${Uri.encodeComponent(shareId)}',
        extra: directShare,
      );
      return;
    }

    if (senderId != null) {
      await _openDmConversation(senderId);
      return;
    }
    _router.go('/inbox');
  }

  Map<String, dynamic>? _coerceJsonMap(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  DateTime? _parseDateTimeValue(Object? raw) {
    final text = _trimmedValue(raw);
    if (text == null) {
      return null;
    }
    return DateTime.tryParse(text);
  }

  Future<InboxShareItem?> _loadEventInviteShare(String shareId) async {
    try {
      final raw = await supabase
          .from('event_shares')
          .select(
            'id, event_id, recipient_id, sender_id, payload_json, '
            'created_at, viewed_at, imported_at, deleted_at, '
            'response_status, responded_at, '
            'sender:profiles!event_shares_sender_id_fkey(handle, display_name, avatar_url), '
            'recipient:profiles!event_shares_recipient_id_fkey(handle, display_name, avatar_url)',
          )
          .eq('id', shareId)
          .maybeSingle();

      final row = _coerceJsonMap(raw);
      if (row == null) {
        return null;
      }

      final payload = _coerceJsonMap(row['payload_json']);
      final sender = _coerceJsonMap(row['sender']);
      final recipient = _coerceJsonMap(row['recipient']);
      final createdAt =
          _parseDateTimeValue(row['created_at']) ?? DateTime.now().toUtc();

      return InboxShareItem(
        shareId: (_trimmedValue(row['id']) ?? shareId),
        kind: InboxShareKind.event,
        recipientId: _trimmedValue(row['recipient_id']) ?? '',
        senderId: _trimmedValue(row['sender_id']) ?? '',
        senderHandle: _trimmedValue(sender?['handle']),
        senderName: _trimmedValue(sender?['display_name']),
        senderAvatar: _trimmedValue(sender?['avatar_url']),
        payloadId: _trimmedValue(row['event_id']) ?? shareId,
        title:
            _trimmedValue(payload?['title'] ?? payload?['name']) ??
            'Event Invite',
        createdAt: createdAt,
        viewedAt: _parseDateTimeValue(row['viewed_at']),
        importedAt: _parseDateTimeValue(row['imported_at']),
        deletedAt: _parseDateTimeValue(row['deleted_at']),
        eventDate: _parseDateTimeValue(
          payload?['starts_at'] ?? payload?['startsAt'],
        ),
        payloadJson: payload,
        responseStatus: EventInviteResponseStatus.fromDbValue(
          _trimmedValue(row['response_status']),
        ),
        respondedAt: _parseDateTimeValue(row['responded_at']),
        recipientHandle: _trimmedValue(recipient?['handle']),
        recipientDisplayName: _trimmedValue(recipient?['display_name']),
        recipientAvatarUrl: _trimmedValue(recipient?['avatar_url']),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _openFlowPostActivity(
    String flowPostId, {
    required bool openCommentsOnLoad,
  }) async {
    try {
      final post = await ProfileRepo(supabase).getFlowPostById(flowPostId);
      if (post != null) {
        _router.go(
          '/flow-post/${Uri.encodeComponent(flowPostId)}'
          '${openCommentsOnLoad ? '?comments=1' : ''}',
          extra: post,
        );
        return;
      }
    } catch (_) {
      // Fall back below.
    }

    _router.go('/inbox');
  }

  Future<void> _openCalendarEventFromPush(String clientEventId) async {
    await SessionResumeService.saveResumeEntry(
      baseRoute: '/',
      kind: _kCalendarPushResumeKind,
      payload: {'clientEventId': clientEventId},
    );
    emitCalendarPushOpenIntent(clientEventId);
    _router.go('/');
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _LaunchShell extends StatefulWidget {
  const _LaunchShell({required this.child});

  final Widget child;

  @override
  State<_LaunchShell> createState() => _LaunchShellState();
}

class _LaunchShellState extends State<_LaunchShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _fadeOut = Tween<double>(
    begin: 1,
    end: 0,
  ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _launchOverlayDismissed.value = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreDetachedCalendarOverlayAfterBoot());
      _dismissOverlay();
    });
  }

  Future<void> _restoreDetachedCalendarOverlayAfterBoot() async {
    for (var attempt = 0; attempt < 30; attempt++) {
      if (!mounted) return;
      final navContext = _rootNavigatorKey.currentContext;
      if (navContext != null) {
        if (!navContext.mounted) return;
        final currentLocation = _router.routerDelegate.currentConfiguration.uri
            .toString();
        final restored =
            await CalendarPage.restoreDetachedCalendarOverlayFromAnyContext(
              navContext,
              currentLocation: currentLocation,
            );
        if (restored) return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<void> _dismissOverlay() async {
    await Future<void>.delayed(const Duration(milliseconds: 950));
    await _waitForWebAuthExchangeToSettle();
    await CalendarPage.waitForInitialCalendarRestorationToSettle();
    if (!mounted) return;
    await _fadeController.forward();
    if (!mounted) return;
    setState(() => _dismissed = true);
    _launchOverlayDismissed.value = true;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_dismissed)
          IgnorePointer(
            // The launch shell is decorative; don't block early taps during
            // standalone web auth/bootstrap.
            ignoring: true,
            child: FadeTransition(
              opacity: _fadeOut,
              child: const ColoredBox(
                color: _launchBackdrop,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _ShimmeringLaunchWord(),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ShimmeringLaunchWord extends StatefulWidget {
  const _ShimmeringLaunchWord();

  @override
  State<_ShimmeringLaunchWord> createState() => _ShimmeringLaunchWordState();
}

class _ShimmeringLaunchWordState extends State<_ShimmeringLaunchWord>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shimmerOffset = (_controller.value * 2.6) - 1.3;
        final shimmerGradient = LinearGradient(
          begin: Alignment(-1.6 + shimmerOffset, 0),
          end: Alignment(1.6 + shimmerOffset, 0),
          colors: const [
            goldDeep,
            gold,
            goldLight,
            Color(0xFFFFF8DD),
            goldLight,
            gold,
            goldDeep,
          ],
          stops: const [0.0, 0.2, 0.38, 0.5, 0.62, 0.8, 1.0],
        );

        return GlossyText(
          text: 'ḥꜣw',
          gradient: shimmerGradient,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 42,
            fontWeight: FontWeight.w500,
            fontFamily: 'GentiumPlus',
            fontFamilyFallback: ['NotoSans', 'Roboto', 'Arial', 'sans-serif'],
            shadows: [
              Shadow(
                color: Color(0x552C1A00),
                blurRadius: 18,
                offset: Offset(0, 4),
              ),
            ],
          ),
        );
      },
    );
  }
}

class InboxConversationRoutePage extends StatefulWidget {
  const InboxConversationRoutePage({
    super.key,
    required this.otherUserId,
    this.extra,
  });

  final String otherUserId;
  final Object? extra;

  static String editorKey(String otherUserId) =>
      'inbox_conversation:${otherUserId.trim()}';

  @override
  State<InboxConversationRoutePage> createState() =>
      _InboxConversationRoutePageState();
}

class _InboxConversationRoutePageState
    extends State<InboxConversationRoutePage> {
  late Future<({ConversationUser profile, String? draftText})> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant InboxConversationRoutePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.otherUserId != widget.otherUserId ||
        oldWidget.extra != widget.extra) {
      _future = _load();
    }
  }

  Future<({ConversationUser profile, String? draftText})> _load() async {
    final extraProfile = _profileFromExtra(widget.extra);
    final profile = extraProfile ?? await _loadConversationUser();
    final textValue = await RestorationCoordinator.instance
        .readTextEditingValue(
          InboxConversationRoutePage.editorKey(widget.otherUserId),
        );
    return (
      profile: profile,
      draftText: textValue?.text ?? _draftFromExtra(widget.extra),
    );
  }

  ConversationUser? _profileFromExtra(Object? extra) {
    if (extra is ConversationUser) {
      return extra;
    }
    if (extra is Map) {
      final raw = extra['profile'];
      if (raw is ConversationUser) {
        return raw;
      }
    }
    return null;
  }

  String? _draftFromExtra(Object? extra) {
    if (extra is! Map) {
      return null;
    }
    final draft = extra['initialDraftText'] as String?;
    final normalized = draft?.trim();
    return normalized == null || normalized.isEmpty ? null : draft;
  }

  Future<ConversationUser> _loadConversationUser() async {
    final cached = await ProfileRepo(
      supabase,
    ).restoreCachedProfile(widget.otherUserId);
    final live =
        cached ?? await ProfileRepo(supabase).getProfile(widget.otherUserId);
    if (live != null) {
      return ConversationUser(
        id: live.id,
        displayName: live.displayName,
        handle: live.handle,
        avatarUrl: live.avatarUrl,
        avatarGlyphIds: live.avatarGlyphIds,
      );
    }
    return ConversationUser(id: widget.otherUserId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({ConversationUser profile, String? draftText})>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null) {
          return InboxConversationPage(
            otherUserId: widget.otherUserId,
            otherProfile: data.profile,
            initialDraftText: data.draftText,
          );
        }
        return const _RouteLoadingScaffold();
      },
    );
  }
}

class FlowPostRoutePage extends StatefulWidget {
  const FlowPostRoutePage({
    super.key,
    required this.postId,
    required this.openCommentsOnLoad,
    this.extra,
  });

  final String postId;
  final bool openCommentsOnLoad;
  final Object? extra;

  @override
  State<FlowPostRoutePage> createState() => _FlowPostRoutePageState();
}

class _FlowPostRoutePageState extends State<FlowPostRoutePage> {
  late Future<({FlowPost post, List<FlowPost>? posts, int initialIndex})?>
  _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant FlowPostRoutePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId || oldWidget.extra != widget.extra) {
      _future = _load();
    }
  }

  Future<({FlowPost post, List<FlowPost>? posts, int initialIndex})?>
  _load() async {
    final extra = widget.extra;
    if (extra is FlowPost && extra.id == widget.postId) {
      return (post: extra, posts: null, initialIndex: 0);
    }
    if (extra is Map) {
      final raw = extra['post'];
      final postsRaw = extra['posts'];
      final posts = postsRaw is List<FlowPost> ? postsRaw : null;
      final initialIndex = (extra['initialIndex'] as num?)?.toInt() ?? 0;
      if (raw is FlowPost && raw.id == widget.postId) {
        return (post: raw, posts: posts, initialIndex: initialIndex);
      }
    }
    final post = await ProfileRepo(supabase).getFlowPostById(widget.postId);
    if (post == null) {
      return null;
    }
    return (post: post, posts: null, initialIndex: 0);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
      ({FlowPost post, List<FlowPost>? posts, int initialIndex})?
    >(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null) {
          final currentUserId = supabase.auth.currentUser?.id;
          return FlowPostDetailPage(
            post: data.post,
            posts: data.posts,
            initialIndex: data.initialIndex,
            isOwner: currentUserId != null && data.post.userId == currentUserId,
            openCommentsOnLoad: widget.openCommentsOnLoad,
          );
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return _RouteMissingScaffold(
            message: 'This post is no longer available.',
            fallbackLocation: '/profile/me',
          );
        }
        return const _RouteLoadingScaffold();
      },
    );
  }
}

class EventInviteRoutePage extends StatefulWidget {
  const EventInviteRoutePage({super.key, required this.shareId, this.extra});

  final String shareId;
  final Object? extra;

  @override
  State<EventInviteRoutePage> createState() => _EventInviteRoutePageState();
}

class _EventInviteRoutePageState extends State<EventInviteRoutePage> {
  late Future<InboxShareItem?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant EventInviteRoutePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shareId != widget.shareId ||
        oldWidget.extra != widget.extra) {
      _future = _load();
    }
  }

  Future<InboxShareItem?> _load() async {
    final extra = widget.extra;
    if (extra is InboxShareItem && extra.shareId == widget.shareId) {
      return extra;
    }
    return _loadInboxShareItemForRoute(
      widget.shareId,
      expectedKind: InboxShareKind.event,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InboxShareItem?>(
      future: _future,
      builder: (context, snapshot) {
        final share = snapshot.data;
        if (share != null) {
          return EventInviteDetailsPage(share: share);
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return const _RouteMissingScaffold(
            message: 'This invite is no longer available.',
            fallbackLocation: '/inbox',
          );
        }
        return const _RouteLoadingScaffold();
      },
    );
  }
}

class SharedFlowRoutePage extends StatefulWidget {
  const SharedFlowRoutePage({super.key, this.shareId, this.flowId, this.extra});

  final String? shareId;
  final int? flowId;
  final Object? extra;

  @override
  State<SharedFlowRoutePage> createState() => _SharedFlowRoutePageState();
}

class _SharedFlowRoutePageState extends State<SharedFlowRoutePage> {
  late Future<InboxShareItem?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant SharedFlowRoutePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shareId != widget.shareId ||
        oldWidget.flowId != widget.flowId ||
        oldWidget.extra != widget.extra) {
      _future = _load();
    }
  }

  Future<InboxShareItem?> _load() async {
    final extra = widget.extra;
    if (extra is InboxShareItem &&
        widget.shareId != null &&
        extra.shareId == widget.shareId) {
      return extra;
    }
    final shareId = widget.shareId;
    if (shareId == null || shareId.trim().isEmpty) {
      return null;
    }
    return _loadInboxShareItemForRoute(
      shareId,
      expectedKind: InboxShareKind.flow,
    );
  }

  @override
  Widget build(BuildContext context) {
    final flowId = widget.flowId;
    if (flowId != null) {
      return SharedFlowDetailsPage(flowId: flowId);
    }
    return FutureBuilder<InboxShareItem?>(
      future: _future,
      builder: (context, snapshot) {
        final share = snapshot.data;
        if (share != null && share.isFlow) {
          return SharedFlowDetailsEntry(share: share);
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return const _RouteMissingScaffold(
            message: 'This shared flow is no longer available.',
            fallbackLocation: '/inbox',
          );
        }
        return const _RouteLoadingScaffold();
      },
    );
  }
}

class EditProfileRoutePage extends StatefulWidget {
  const EditProfileRoutePage({super.key, this.requireCompletion = false});

  final bool requireCompletion;

  @override
  State<EditProfileRoutePage> createState() => _EditProfileRoutePageState();
}

class _EditProfileRoutePageState extends State<EditProfileRoutePage> {
  late Future<UserProfile?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<UserProfile?> _load() async {
    final profile = await ProfileRepo(supabase).getMyProfile();
    if (profile != null) {
      return profile;
    }
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) {
      return null;
    }
    return UserProfile(
      id: userId,
      isDiscoverable: true,
      allowIncomingShares: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _future,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        if (profile != null) {
          return EditProfilePage(
            initialProfile: profile,
            requireCompletion: widget.requireCompletion,
          );
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return const _RouteMissingScaffold(
            message: 'Profile could not be loaded.',
            fallbackLocation: '/profile/me',
          );
        }
        return const _RouteLoadingScaffold();
      },
    );
  }
}

class JournalRoutePage extends StatefulWidget {
  const JournalRoutePage({super.key});

  @override
  State<JournalRoutePage> createState() => _JournalRoutePageState();
}

class _JournalRoutePageState extends State<JournalRoutePage>
    with WidgetsBindingObserver {
  late final JournalController _controller = JournalController(supabase);
  late final Future<void> _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _controller.init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_controller.forceSave());
        break;
      case AppLifecycleState.resumed:
        unawaited(_controller.reloadToday());
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return JournalPage(
            controller: _controller,
            entryPoint: 'restored_route',
          );
        }
        return const _RouteLoadingScaffold();
      },
    );
  }
}

class NodeReaderRoutePage extends StatelessWidget {
  const NodeReaderRoutePage({super.key, required this.nodeId});

  final String nodeId;

  @override
  Widget build(BuildContext context) {
    final node = KemeticNodeLibrary.resolve(nodeId);
    if (node == null) {
      return const _RouteMissingScaffold(
        message: 'This library entry is no longer available.',
        fallbackLocation: '/nodes',
      );
    }
    return KemeticNodeReaderPage(node: node);
  }
}

class InsightPostRoutePage extends StatefulWidget {
  const InsightPostRoutePage({super.key, required this.postId, this.extra});

  final String postId;
  final Object? extra;

  @override
  State<InsightPostRoutePage> createState() => _InsightPostRoutePageState();
}

class _InsightPostRoutePageState extends State<InsightPostRoutePage> {
  late Future<InsightPost?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant InsightPostRoutePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId || oldWidget.extra != widget.extra) {
      _future = _load();
    }
  }

  Future<InsightPost?> _load() async {
    final extra = widget.extra;
    if (extra is InsightPost && extra.id == widget.postId) {
      return extra;
    }
    if (extra is Map) {
      final raw = extra['post'];
      if (raw is InsightPost && raw.id == widget.postId) {
        return raw;
      }
    }
    try {
      final row = await supabase
          .from('insight_posts')
          .select(
            'id, user_id, insight_entry_id, node_id, body_text, entry_date, '
            'is_hidden, created_at, updated_at, '
            'nodes(slug, title, glyph), '
            'profiles(handle, display_name, avatar_url, avatar_glyphs)',
          )
          .eq('id', widget.postId)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      return InsightPost.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InsightPost?>(
      future: _future,
      builder: (context, snapshot) {
        final post = snapshot.data;
        if (post != null) {
          final currentUserId = supabase.auth.currentUser?.id;
          return InsightPostDetailPage(
            post: post,
            isOwner: currentUserId != null && currentUserId == post.userId,
          );
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return const _RouteMissingScaffold(
            message: 'This insight is no longer available.',
            fallbackLocation: '/profile/me',
          );
        }
        return const _RouteLoadingScaffold();
      },
    );
  }
}

String? _trimmedRouteValue(Object? raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  return text.isEmpty ? null : text;
}

Map<String, dynamic>? _coerceRouteJsonMap(Object? raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  if (raw is String) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return null;
    }
  }
  return null;
}

DateTime? _parseRouteDateTimeValue(Object? raw) {
  final text = _trimmedRouteValue(raw);
  return text == null ? null : DateTime.tryParse(text);
}

Future<InboxShareItem?> _loadInboxShareItemForRoute(
  String shareId, {
  InboxShareKind? expectedKind,
}) async {
  for (final viewName in const [
    'share_filing_items_client',
    'inbox_share_items_filtered',
  ]) {
    try {
      final row = await supabase
          .from(viewName)
          .select()
          .eq('share_id', shareId)
          .maybeSingle();
      final json = _coerceRouteJsonMap(row);
      if (json == null) {
        continue;
      }
      final item = InboxShareItem.tryFromJson(json);
      if (item == null) {
        continue;
      }
      if (expectedKind == null || item.kind == expectedKind) {
        return item;
      }
    } catch (_) {
      // Try the next source.
    }
  }

  if (expectedKind == InboxShareKind.event) {
    return _loadDirectEventInviteShareForRoute(shareId);
  }
  return null;
}

Future<InboxShareItem?> _loadDirectEventInviteShareForRoute(
  String shareId,
) async {
  try {
    final raw = await supabase
        .from('event_shares')
        .select(
          'id, event_id, recipient_id, sender_id, payload_json, '
          'created_at, viewed_at, imported_at, deleted_at, '
          'response_status, responded_at, '
          'sender:profiles!event_shares_sender_id_fkey(handle, display_name, avatar_url), '
          'recipient:profiles!event_shares_recipient_id_fkey(handle, display_name, avatar_url)',
        )
        .eq('id', shareId)
        .maybeSingle();

    final row = _coerceRouteJsonMap(raw);
    if (row == null) {
      return null;
    }

    final payload = _coerceRouteJsonMap(row['payload_json']);
    final sender = _coerceRouteJsonMap(row['sender']);
    final recipient = _coerceRouteJsonMap(row['recipient']);
    final createdAt =
        _parseRouteDateTimeValue(row['created_at']) ?? DateTime.now().toUtc();

    return InboxShareItem(
      shareId: _trimmedRouteValue(row['id']) ?? shareId,
      kind: InboxShareKind.event,
      recipientId: _trimmedRouteValue(row['recipient_id']) ?? '',
      senderId: _trimmedRouteValue(row['sender_id']) ?? '',
      senderHandle: _trimmedRouteValue(sender?['handle']),
      senderName: _trimmedRouteValue(sender?['display_name']),
      senderAvatar: _trimmedRouteValue(sender?['avatar_url']),
      payloadId: _trimmedRouteValue(row['event_id']) ?? shareId,
      title:
          _trimmedRouteValue(payload?['title'] ?? payload?['name']) ??
          'Event Invite',
      createdAt: createdAt,
      viewedAt: _parseRouteDateTimeValue(row['viewed_at']),
      importedAt: _parseRouteDateTimeValue(row['imported_at']),
      deletedAt: _parseRouteDateTimeValue(row['deleted_at']),
      eventDate: _parseRouteDateTimeValue(
        payload?['starts_at'] ?? payload?['startsAt'],
      ),
      payloadJson: payload,
      responseStatus: EventInviteResponseStatus.fromDbValue(
        _trimmedRouteValue(row['response_status']),
      ),
      respondedAt: _parseRouteDateTimeValue(row['responded_at']),
      recipientHandle: _trimmedRouteValue(recipient?['handle']),
      recipientDisplayName: _trimmedRouteValue(recipient?['display_name']),
      recipientAvatarUrl: _trimmedRouteValue(recipient?['avatar_url']),
    );
  } catch (_) {
    return null;
  }
}

class _RouteLoadingScaffold extends StatelessWidget {
  const _RouteLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(KemeticGold.base),
        ),
      ),
    );
  }
}

class _RouteMissingScaffold extends StatelessWidget {
  const _RouteMissingScaffold({
    required this.message,
    required this.fallbackLocation,
  });

  final String message;
  final String fallbackLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go(fallbackLocation),
                child: KemeticGold.text(
                  'Return',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<Uri>? _linkSub;
  AppLinks? _appLinks;
  String? _lastHandledLinkSignature;
  DateTime? _lastHandledLinkAt;
  String? _lastHandledSharedFilesSignature;
  DateTime? _lastHandledSharedFilesAt;
  PlannerLaunchIntent? _pendingPlannerLaunchIntent;

  StreamSubscription? _intentDataStreamSubscription;

  void _logIcs(String message) {
    if (kDebugMode) {
      debugPrint('[ICS] $message');
    }
  }

  void _logAuthGateError(String scope, Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;
    debugPrint('[AuthGate] $scope failed: $error');
    debugPrint('$stackTrace');
  }

  CalendarSyncService? _calendarSync;
  final DecanReflectionScheduler _decanScheduler = DecanReflectionScheduler(
    supabase,
  );
  bool _scheduledDecans = false;

  // One-shot guards
  bool _appOpenLogged = false;
  bool _notifyInitInProgress = false;
  bool _notifyInitialized = false;
  bool _sessionResumeChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _calendarSync = sharedCalendarSyncService(supabase);

    // React to auth changes (includes initialSession)
    _authSub = supabase.auth.onAuthStateChange.listen(
      (data) {
        unawaited(
          runGuardedAsync(
            'auth state change',
            () => _handleAuthStateChange(data),
            onError: _logAuthGateError,
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        _logAuthGateError('auth state stream', error, stackTrace);
      },
    );

    _initDeepLinksMobile(); // custom scheme for Android/iOS native builds
    _initSharingIntent(); // Initialize ICS file sharing
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _linkSub?.cancel();
    _intentDataStreamSubscription?.cancel();
    unawaited(disposeSharedCalendarSyncService());
    super.dispose();
  }

  void _ensureDecanSchedules({required String scope, bool force = false}) {
    if (supabase.auth.currentSession == null) return;
    fireAndForgetGuarded(
      scope,
      _decanScheduler.ensureCurrentAndNextScheduled(force: force),
      onError: _logAuthGateError,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    unawaited(
      _refreshSessionIfNeeded('resume').whenComplete(
        () => _ensureDecanSchedules(scope: 'decan schedule resume'),
      ),
    );
  }

  // -- Keep a profiles row (id/email) for the user
  Future<void> _ensureProfile() async {
    final u = supabase.auth.currentUser;
    if (u == null) return;
    await supabase.from('profiles').upsert({
      'id': u.id,
      'email': u.email,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'id');
  }

  Future<void> _handleAuthStateChange(AuthState data) async {
    if (mounted) setState(() {});
    final ev = data.event;

    if (ev == AuthChangeEvent.initialSession ||
        ev == AuthChangeEvent.signedIn) {
      Events.debugAuthBanner('onAuthStateChange:$ev');
      await _ensureProfile(); // keep profiles hydrated with email
      await UserEventsRepo.refreshTelemetrySettings(supabase);
      await _logAppOpenOnce(); // one-shot per cold start
      final pendingPlannerLaunch = _pendingPlannerLaunchIntent;
      if (pendingPlannerLaunch != null) {
        _pendingPlannerLaunchIntent = null;
        _routeToPlanner(pendingPlannerLaunch);
      }
      fireAndForgetGuarded(
        'notify init',
        _initNotificationsSafely(),
        onError: _logAuthGateError,
      );
      final pushEnabled = await SettingsPrefs.realTimeAlertsEnabled();
      if (pushEnabled) {
        final push = PushNotifications.instance(supabase);
        if (!kIsWeb) {
          fireAndForgetGuarded(
            'push register',
            push.registerForUser().then((ok) {
              if (!ok && kDebugMode) {
                debugPrint('[push] registerForUser failed');
              }
            }),
            onError: _logAuthGateError,
          );
        } else {
          fireAndForgetGuarded(
            'push web refresh',
            push.refreshRegistrationIfAuthorized().then((ok) {
              if (!ok && kDebugMode) {
                debugPrint(
                  '[push] web token refresh skipped or unavailable; waiting for manual enable/refresh',
                );
              }
            }),
            onError: _logAuthGateError,
          );
        }
      } else if (kDebugMode) {
        debugPrint('[push] registerForUser skipped (device push toggle off)');
      }
      _scheduleSessionResumeCheck();
      if (!_scheduledDecans) {
        _scheduledDecans = true;
        _ensureDecanSchedules(scope: 'decan schedule', force: true);
      }
      final autoCalendarSyncEnabled =
          await SettingsPrefs.autoCalendarSyncEnabled();
      if (autoCalendarSyncEnabled) {
        fireAndForgetGuarded(
          'calendar sync start',
          _calendarSync?.start(),
          onError: _logAuthGateError,
        );
      } else {
        _calendarSync?.stop();
      }
    }

    if (ev == AuthChangeEvent.signedOut) {
      _scheduledDecans = false;
      _sessionResumeChecked = false;
      await AppRestorationService.instance.clearBootFallbackIdentity();
      _calendarSync?.stop();
      fireAndForgetGuarded(
        'push unregister',
        PushNotifications.instance(supabase).unregister(),
        onError: _logAuthGateError,
      );
    }
  }

  void _scheduleSessionResumeCheck() {
    if (_sessionResumeChecked) return;
    _sessionResumeChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeResumeSessionRoute());
    });
  }

  Future<void> _maybeResumeSessionRoute() async {
    if (!mounted ||
        supabase.auth.currentSession == null ||
        _deferSessionResumeForPushNavigation) {
      return;
    }
    final overlayParentRoute =
        CalendarPage.restorableOverlayParentRouteFromStack(
          await AppRestorationService.instance.readOverlayStack(),
        );
    final savedLocation =
        overlayParentRoute ??
        await AppRestorationService.instance.readRouteLocation(
          includeRemote: true,
        ) ??
        await SessionResumeService.readRouteLocation();
    if (!mounted ||
        savedLocation == null ||
        _deferSessionResumeForPushNavigation ||
        savedLocation.isEmpty ||
        savedLocation == '/' ||
        !_isContinuityRouteLocation(savedLocation)) {
      return;
    }
    RestorationCoordinator.instance.beginLaunchRestore(
      reason: RestorationRestoreReason.authResume,
      targetLocation: savedLocation,
    );
    _router.go(savedLocation);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navContext = _rootNavigatorKey.currentContext;
      if (navContext == null) return;
      unawaited(
        CalendarPage.restoreDetachedCalendarOverlayFromAnyContext(
          navContext,
          currentLocation: savedLocation,
        ),
      );
    });
  }

  // -- Log app_open once per cold start after auth is present
  Future<void> _logAppOpenOnce() async {
    if (_appOpenLogged) return;

    final hasSession = supabase.auth.currentSession != null;
    if (!hasSession) return;

    final repo = UserEventsRepo(supabase);
    try {
      await repo.track(
        event: 'app_open',
        properties: {
          'platform': kIsWeb ? 'web' : 'mobile',
          'ts': DateTime.now().toUtc().toIso8601String(),
        },
      );
      unawaited(
        repo.track(
          event: 'telemetry_enabled',
          properties: {'v': kAppEventsSchemaVersion},
        ),
      );
      _appOpenLogged = true;
    } catch (_) {
      // keep false; try again later
    }
  }

  /// Initialize local notifications once, safely.
  Future<void> _initNotificationsSafely() async {
    if (_notifyInitialized || _notifyInitInProgress) return;
    _notifyInitInProgress = true;
    try {
      await Notify.init();
      _notifyInitialized = true;
    } catch (_) {
      // ignore platform races (e.g., permissionRequestInProgress)
    } finally {
      _notifyInitInProgress = false;
    }
  }

  // ------------------------------------
  // MOBILE: handle custom scheme callback
  // ------------------------------------
  Future<void> _initDeepLinksMobile() async {
    if (kIsWeb) return;
    _appLinks = AppLinks();

    // Cold start
    try {
      Uri? initialUri;
      try {
        initialUri = await (_appLinks as dynamic).getInitialAppLink();
      } catch (_) {
        try {
          initialUri = await (_appLinks as dynamic).getInitialLink();
        } catch (_) {
          initialUri = null;
        }
      }
      if (initialUri != null) {
        await runGuardedAsync(
          'initial app link',
          () => _handleIncomingAppLink(initialUri!),
          onError: _logAuthGateError,
        );
      }
    } catch (e, st) {
      _logAuthGateError('initial app link setup', e, st);
    }

    // While running
    _linkSub = _appLinks!.uriLinkStream.listen(
      (uri) {
        unawaited(
          runGuardedAsync(
            'incoming app link',
            () => _handleIncomingAppLink(uri),
            onError: _logAuthGateError,
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        _logAuthGateError('app link stream', error, stackTrace);
      },
    );
  }

  Future<void> _handleIncomingAppLink(Uri uri) async {
    final intent = AppLinkIntent.parse(uri);
    if (intent == null) {
      return;
    }

    final signature = intent is AuthAppLinkIntent
        ? 'auth:${intent.uri}'
        : intent is ShareAppLinkIntent
        ? 'share:${intent.routeLocation}'
        : intent is PlannerAppLinkIntent
        ? 'planner:${intent.routeLocation}'
        : 'unknown:${uri.toString()}';

    if (_shouldSkipDuplicateLink(signature)) {
      return;
    }

    if (intent is AuthAppLinkIntent) {
      await _exchangeAuthCallback(intent.uri);
      return;
    }

    if (intent is ShareAppLinkIntent) {
      _routeToSharedFlow(intent);
      return;
    }

    if (intent is PlannerAppLinkIntent) {
      _routeToPlanner(intent.plannerIntent);
    }
  }

  bool _shouldSkipDuplicateLink(String signature) {
    final now = DateTime.now();
    final isRecentDuplicate =
        _lastHandledLinkSignature == signature &&
        _lastHandledLinkAt != null &&
        now.difference(_lastHandledLinkAt!) < const Duration(seconds: 2);
    if (isRecentDuplicate) {
      return true;
    }
    _lastHandledLinkSignature = signature;
    _lastHandledLinkAt = now;
    return false;
  }

  Future<void> _exchangeAuthCallback(Uri uri) async {
    try {
      await supabase.auth.exchangeCodeForSession(uri.toString());
      await supabase.auth.refreshSession();
      Events.debugAuthBanner('deeplink');
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _routeToSharedFlow(ShareAppLinkIntent intent) {
    final location = intent.routeLocation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _router.go(location);
    });
  }

  void _routeToPlanner(PlannerLaunchIntent intent) {
    _deferSessionResumeForPushNavigation = true;

    if (supabase.auth.currentSession == null) {
      _pendingPlannerLaunchIntent = intent;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _router.go('/');
      });
      return;
    }

    final resolvedIntent = intent.openDayCard
        ? intent.withLaunchToken(
            DateTime.now().microsecondsSinceEpoch.toString(),
          )
        : intent;
    final location = resolvedIntent.routeLocation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _router.go(location);
    });
  }

  // ------------------------------------
  // ICS FILE HANDLING
  // ------------------------------------

  void _initSharingIntent() {
    if (kIsWeb) {
      _logIcs('Skipping sharing intent setup on web.');
      return;
    }

    _logIcs('Initializing sharing intent handling...');

    try {
      // Handle files shared while app is closed
      ReceiveSharingIntent.instance
          .getInitialMedia()
          .then((List<SharedMediaFile> value) {
            unawaited(
              runGuardedAsync(
                'initial shared media',
                () => _handleIncomingSharedMedia(value, source: 'initial'),
                onError: _logAuthGateError,
              ),
            );
          })
          .catchError((Object error, StackTrace stackTrace) {
            _logIcs('Error getting initial media: $error');
            _logAuthGateError('initial shared media fetch', error, stackTrace);
          });

      // Handle files shared while app is open
      _intentDataStreamSubscription = ReceiveSharingIntent.instance
          .getMediaStream()
          .listen(
            (List<SharedMediaFile> value) {
              unawaited(
                runGuardedAsync(
                  'stream shared media',
                  () => _handleIncomingSharedMedia(value, source: 'stream'),
                  onError: _logAuthGateError,
                ),
              );
            },
            onError: (Object error, StackTrace stackTrace) {
              _logIcs('Error in media stream: $error');
              _logAuthGateError('shared media stream', error, stackTrace);
            },
          );
    } on MissingPluginException catch (error, stackTrace) {
      _logIcs('Sharing intent plugin unavailable: $error');
      _logAuthGateError('sharing intent setup', error, stackTrace);
      _intentDataStreamSubscription = null;
    }
  }

  Future<void> _handleIncomingSharedMedia(
    List<SharedMediaFile> media, {
    required String source,
  }) async {
    if (media.isEmpty) return;

    _logIcs('Received $source files: ${media.length}');
    for (final file in media) {
      _logIcs(
        '${source[0].toUpperCase()}${source.substring(1)} file: ${file.path}',
      );
    }

    final files = media
        .map(
          (file) => PlatformFile(
            name: file.path.split('/').last,
            size: 0,
            path: file.path,
          ),
        )
        .toList(growable: false);
    final signature = buildSharedFileIntentSignature(
      files.map((file) => file.path ?? file.name),
    );

    try {
      if (_shouldSkipDuplicateSharedFiles(signature)) {
        _logIcs('Skipping duplicate $source shared payload');
        return;
      }

      await _handleSharedFiles(files, source: source);
    } finally {
      try {
        await ReceiveSharingIntent.instance.reset();
      } catch (error) {
        _logIcs('Error resetting shared media: $error');
      }
    }
  }

  bool _shouldSkipDuplicateSharedFiles(String signature) {
    final now = DateTime.now();
    final shouldSkip = shouldSkipDuplicateSharedFileIntent(
      signature: signature,
      lastSignature: _lastHandledSharedFilesSignature,
      lastHandledAt: _lastHandledSharedFilesAt,
      now: now,
    );
    if (shouldSkip) {
      return true;
    }
    _lastHandledSharedFilesSignature = signature;
    _lastHandledSharedFilesAt = now;
    return false;
  }

  Future<void> _handleSharedFiles(
    List<PlatformFile> files, {
    String source = 'manual',
  }) async {
    _logIcs('Handling ${files.length} shared files from $source');
    final seenEntries = <String>{};
    IcsEvent? previewEvent;

    for (final file in files) {
      final path = file.path;
      final entry = (path ?? file.name).trim();
      if (entry.isNotEmpty && !seenEntries.add(entry)) {
        _logIcs('Skipping duplicate file entry: $entry');
        continue;
      }
      _logIcs('Processing file: $path');

      // Check if it's an ICS file
      if (isSupportedSharedCalendarFilePath(path ?? file.name)) {
        if (path == null || path.isEmpty) {
          _logIcs('Shared ICS file is missing a readable path');
          continue;
        }
        _logIcs('Received ICS file: $path');

        // Parse the ICS file
        final events = await IcsParser.parseFile(path);

        if (events.isEmpty) {
          _logIcs('No events found in file');
          continue;
        }

        _logIcs('Found ${events.length} events in file');

        previewEvent = events.first;
        if (events.length > 1) {
          _logIcs('Using the first event from a multi-event ICS file');
        }
        break;
      } else {
        _logIcs('File is not an ICS file: $path');
      }
    }

    if (previewEvent != null && mounted) {
      _showIcsPreview(previewEvent);
    }
  }

  void _showIcsPreview(IcsEvent event) {
    _logIcs('Showing preview for event: ${event.title}');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => IcsPreviewCard(
        title: event.title,
        startTime: event.startTime,
        endTime: event.endTime,
        location: event.location,
        description: event.description,
        onAdd: () {
          Navigator.pop(context);
          _addEventFromIcs(event);
        },
        onEditAndAdd: null,
        onCancel: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _addEventFromIcs(IcsEvent event) async {
    try {
      _logIcs('Starting import for event: ${event.title}');

      // Convert Gregorian date to Kemetic using your existing logic
      final kemeticDate = KemeticMath.fromGregorian(event.startTime);
      _logIcs(
        'Converted to Kemetic date: '
        '${kemeticDate.kYear}-${kemeticDate.kMonth}-${kemeticDate.kDay}',
      );

      // Extract time info
      final startHour = event.isAllDay ? null : event.startTime.hour;
      final startMinute = event.isAllDay ? null : event.startTime.minute;

      // Use YOUR _buildCid format to create the client event ID
      final clientEventId = _buildCid(
        ky: kemeticDate.kYear,
        km: kemeticDate.kMonth,
        kd: kemeticDate.kDay,
        title: event.title,
        startHour: startHour,
        startMinute: startMinute,
        allDay: event.isAllDay,
        flowId: -1, // -1 indicates standalone event (not part of a flow)
      );

      _logIcs('Generated client ID: $clientEventId');

      final repo = UserEventsRepo(supabase);

      await repo.upsertByClientId(
        clientEventId: clientEventId,
        title: event.title,
        startsAtUtc: event.startTime.toUtc(),
        endsAtUtc: event.endTime?.toUtc(),
        detail: event.description,
        location: event.location,
        allDay: event.isAllDay,
        caller: 'ics_import',
      );

      _logIcs('Event imported successfully: ${event.title}');
      _logIcs(
        'Kemetic date: '
        '${kemeticDate.kYear}-${kemeticDate.kMonth}-${kemeticDate.kDay}',
      );
      _logIcs('Client ID: $clientEventId');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event "${event.title}" added to calendar'),
            backgroundColor: KemeticGold.base,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _logIcs('Error importing event: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to import event'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method to build clientEventId in your format (copied from calendar_page.dart)
  String _buildCid({
    required int ky,
    required int km,
    required int kd,
    required String title,
    int? startHour,
    int? startMinute,
    bool allDay = false,
    required int flowId,
  }) {
    final int sHour = (allDay || startHour == null) ? 9 : startHour;
    final int sMinute = (allDay || startMinute == null) ? 0 : startMinute;
    return EventCidUtil.buildClientEventId(
      ky: ky,
      km: km,
      kd: kd,
      title: title,
      startHour: sHour,
      startMinute: sMinute,
      allDay: allDay,
      flowId: flowId,
    );
  }

  Future<void> _signInWithGoogle() async {
    final redirect = kIsWeb
        ? Uri.base
              .removeFragment()
              .replace(queryParameters: const {})
              .toString()
        : 'kemet.app://login-callback';
    try {
      if (kIsWeb) {
        await supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirect,
        );
      } else {
        await supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirect,
          authScreenLaunchMode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;

    if (session == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KemeticGold.text(
                    'Kemetic Calendar',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sign in to sync your flows and events.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white, // White text
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _signInWithGoogle,
                    icon: const Icon(Icons.login, color: Colors.black),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KemeticGold.base, // Gold button
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () async {
                        await supabase.auth.signOut();
                      },
                      child: KemeticGold.text(
                        'Sign out (debug)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Authenticated
    return Scaffold(
      body: SessionTrackedRoute(location: '/', child: CalendarPage()),
    );
  }
}
