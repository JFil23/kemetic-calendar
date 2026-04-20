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
import 'features/invites/event_invite_details_page.dart';
import 'data/share_models.dart';
import 'utils/event_cid_util.dart';
import 'telemetry/telemetry.dart';
import 'shared/glossy_text.dart';

import 'utils/hive_local_storage_web.dart';
import 'core/app_link_intent.dart';
import 'core/shared_file_intent.dart';
import 'core/theme/app_theme.dart';
import 'services/calendar_sync_service.dart';
import 'services/push_notifications.dart';
import 'services/decan_reflection_scheduler.dart';
import 'features/profile/profile_page.dart';
import 'features/rhythm/pages/commitment_tracker_page.dart';
import 'features/rhythm/pages/my_cycle_page.dart';
import 'features/rhythm/pages/todays_alignment_page.dart';
import 'features/settings/settings_prefs.dart';
import 'features/reflections/decan_reflection_detail_page.dart';
import 'widgets/kemetic_keyboard.dart';

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
  _webAuthExchangeInProgress.value = Uri.base.queryParameters.containsKey(
    'code',
  );
  _installVisibilityRefresh();
  unawaited(_completeWebOAuthIfNeeded());
  unawaited(_rehydrateSessionOnce());
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

Future<void> _rehydrateSessionOnce() async {
  // Touching currentSession is enough; the SDK already persisted it.
  final _ = Supabase.instance.client.auth.currentSession;
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
    await _repo.track(event: event, properties: props);
    debugPrint('[events] inserted "$event" as ${s.user.id}');
  }
}

/* ───────────────────────── Routing/Telemetry ───────────────────────── */

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
const Color _launchBackdrop = Color(0xFF171518);

/* ───────────────────────── Telemetry Route Observer ───────────────────────── */

class TelemetryRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  void _send(PageRoute<dynamic>? route) {
    final name = route?.settings.name ?? '/';
    Events.trackIfAuthed('screen_view', {'route': name});
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

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const AuthGate()),
    GoRoute(
      path: '/inbox',
      builder: (context, state) {
        final shareId = state.uri.queryParameters['share'];
        if (shareId != null) {
          // Redirect to share preview if share parameter exists
          return SharePreviewPage(
            shareId: shareId,
            token: state.uri.queryParameters['token'],
          );
        }
        return const InboxPage();
      },
    ),
    GoRoute(
      path: '/share/:shareId',
      builder: (context, state) {
        return SharePreviewPage(
          shareId: state.pathParameters['shareId']!,
          token: state.uri.queryParameters['token'],
        );
      },
    ),
    GoRoute(
      path: '/rhythm/mycycle',
      builder: (context, state) => const MyCyclePage(),
    ),
    GoRoute(
      path: '/rhythm/today',
      builder: (context, state) => const TodaysAlignmentPage(),
    ),
    GoRoute(
      path: '/rhythm/todo',
      builder: (context, state) => const TodaysAlignmentPage(),
    ),
    GoRoute(
      path: '/rhythm/tracker',
      builder: (context, state) => const CommitmentTrackerPage(),
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
          child: _LaunchShell(
            child: KemeticKeyboardHost(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dismissOverlay();
    });
  }

  Future<void> _dismissOverlay() async {
    await Future<void>.delayed(const Duration(milliseconds: 950));
    await _waitForWebAuthExchangeToSettle();
    if (!mounted) return;
    await _fadeController.forward();
    if (!mounted) return;
    setState(() => _dismissed = true);
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

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<Uri>? _linkSub;
  AppLinks? _appLinks;
  String? _lastHandledLinkSignature;
  DateTime? _lastHandledLinkAt;
  String? _lastHandledSharedFilesSignature;
  DateTime? _lastHandledSharedFilesAt;

  StreamSubscription? _intentDataStreamSubscription;

  void _logIcs(String message) {
    if (kDebugMode) {
      debugPrint('[ICS] $message');
    }
  }

  CalendarSyncService? _calendarSync;
  StreamSubscription<Map<String, dynamic>>? _pushNavSub;
  final DecanReflectionScheduler _decanScheduler = DecanReflectionScheduler(
    supabase,
  );
  final Set<String> _handledPushNavigationKeys = <String>{};
  bool _scheduledDecans = false;

  // One-shot guards
  bool _appOpenLogged = false;
  bool _notifyInitInProgress = false;
  bool _notifyInitialized = false;

  @override
  void initState() {
    super.initState();
    _calendarSync = sharedCalendarSyncService(supabase);

    // React to auth changes (includes initialSession)
    _authSub = supabase.auth.onAuthStateChange.listen((data) async {
      if (mounted) setState(() {});
      final ev = data.event;

      if (ev == AuthChangeEvent.initialSession ||
          ev == AuthChangeEvent.signedIn) {
        Events.debugAuthBanner('onAuthStateChange:$ev');
        await _ensureProfile(); // keep profiles hydrated with email
        await UserEventsRepo.refreshTelemetrySettings(supabase);
        await _logAppOpenOnce(); // one-shot per cold start
        unawaited(_initNotificationsSafely());
        final pushEnabled = await SettingsPrefs.realTimeAlertsEnabled();
        if (pushEnabled) {
          final push = PushNotifications.instance(supabase);
          if (!kIsWeb) {
            unawaited(
              push.registerForUser().then((ok) {
                if (!ok && kDebugMode) {
                  debugPrint('[push] registerForUser failed');
                }
              }),
            );
          } else {
            unawaited(
              push.refreshRegistrationIfAuthorized().then((ok) {
                if (!ok && kDebugMode) {
                  debugPrint(
                    '[push] web token refresh skipped or unavailable; waiting for manual enable/refresh',
                  );
                }
              }),
            );
          }
        } else if (kDebugMode) {
          debugPrint('[push] registerForUser skipped (device push toggle off)');
        }
        _installPushNavigation();
        _consumePendingWebPushIntent();
        if (!_scheduledDecans) {
          _scheduledDecans = true;
          unawaited(_decanScheduler.ensureCurrentAndNextScheduled());
        }
        final autoCalendarSyncEnabled =
            await SettingsPrefs.autoCalendarSyncEnabled();
        if (autoCalendarSyncEnabled) {
          unawaited(_calendarSync?.start());
        } else {
          _calendarSync?.stop();
        }
      }

      if (ev == AuthChangeEvent.signedOut) {
        _calendarSync?.stop();
        unawaited(PushNotifications.instance(supabase).unregister());
      }
    });

    _initDeepLinksMobile(); // custom scheme for Android/iOS native builds
    _initSharingIntent(); // Initialize ICS file sharing
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _linkSub?.cancel();
    _intentDataStreamSubscription?.cancel();
    unawaited(disposeSharedCalendarSyncService());
    _pushNavSub?.cancel();
    super.dispose();
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
        await _handleIncomingAppLink(initialUri);
      }
    } catch (_) {}

    // While running
    _linkSub = _appLinks!.uriLinkStream.listen((uri) async {
      await _handleIncomingAppLink(uri);
    }, onError: (_) {});
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

  // ------------------------------------
  // ICS FILE HANDLING
  // ------------------------------------

  void _initSharingIntent() {
    _logIcs('Initializing sharing intent handling...');

    // Handle files shared while app is closed
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) async {
          await _handleIncomingSharedMedia(value, source: 'initial');
        })
        .catchError((error) {
          _logIcs('Error getting initial media: $error');
        });

    // Handle files shared while app is open
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (List<SharedMediaFile> value) async {
            await _handleIncomingSharedMedia(value, source: 'stream');
          },
          onError: (error) {
            _logIcs('Error in media stream: $error');
          },
        );
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
    return Scaffold(body: CalendarPage());
  }

  void _installPushNavigation() {
    final push = PushNotifications.instance(supabase);
    _pushNavSub ??= push.openedMessages.listen(_handlePushNavigation);
    unawaited(push.emitInitialMessage());
  }

  void _consumePendingWebPushIntent() {
    if (!kIsWeb) return;
    final params = Uri.base.queryParameters;
    final kind = params['push_kind'] ?? params['pushKind'];
    if (kind == null || kind.isEmpty) return;

    final data = <String, dynamic>{
      'kind': kind,
      if ((params['reflection_id'] ?? params['reflectionId']) != null)
        'reflection_id': params['reflection_id'] ?? params['reflectionId'],
      if ((params['sender_id'] ?? params['senderId']) != null)
        'sender_id': params['sender_id'] ?? params['senderId'],
      if ((params['share_id'] ?? params['shareId']) != null)
        'share_id': params['share_id'] ?? params['shareId'],
      if ((params['client_event_id'] ?? params['clientEventId']) != null)
        'client_event_id': params['client_event_id'] ?? params['clientEventId'],
    };

    replaceUrlWithoutQuery();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handlePushNavigation(data);
    });
  }

  String _pushNavigationKey(Map<String, dynamic> data) {
    final kind = (data['kind'] ?? data['type'] ?? 'unknown').toString();
    final detail =
        data['reflectionId'] ??
        data['reflection_id'] ??
        data['share_id'] ??
        data['sender_id'] ??
        data['client_event_id'] ??
        '';
    return '$kind:$detail';
  }

  void _handlePushNavigation(Map<String, dynamic> data) {
    final kind = data['kind'] ?? data['type'];
    final navigationKey = _pushNavigationKey(data);
    if (_handledPushNavigationKeys.contains(navigationKey)) {
      return;
    }
    _handledPushNavigationKeys.add(navigationKey);
    while (_handledPushNavigationKeys.length > 24) {
      _handledPushNavigationKeys.remove(_handledPushNavigationKeys.first);
    }

    final reflectionId = data['reflectionId'] ?? data['reflection_id'];
    final nav = _rootNavigatorKey.currentState;
    if (nav == null) return;

    if (kind == 'decan_reflection' &&
        reflectionId is String &&
        reflectionId.isNotEmpty) {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;
      nav.push(
        MaterialPageRoute(
          builder: (_) => ProfilePage(userId: uid, isMyProfile: true),
        ),
      );
      nav.push(
        MaterialPageRoute(
          builder: (_) => DecanReflectionDetailPage(reflectionId: reflectionId),
        ),
      );
      return;
    }

    if (kind == 'dm') {
      final senderId = (data['sender_id'] ?? data['senderId'])?.toString();
      if (senderId != null && senderId.isNotEmpty) {
        unawaited(_openDmConversation(nav, senderId));
        return;
      }
      nav.push(MaterialPageRoute(builder: (_) => const InboxPage()));
      return;
    }

    if (kind == 'event_invite') {
      final shareId = (data['share_id'] ?? data['shareId'])?.toString();
      final senderId = (data['sender_id'] ?? data['senderId'])?.toString();
      if (shareId != null && shareId.isNotEmpty) {
        unawaited(_openEventInvite(nav, shareId, senderId: senderId));
        return;
      }
      if (senderId != null && senderId.isNotEmpty) {
        unawaited(_openDmConversation(nav, senderId));
        return;
      }
      nav.push(MaterialPageRoute(builder: (_) => const InboxPage()));
    }
  }

  Future<void> _openDmConversation(NavigatorState nav, String senderId) async {
    try {
      final profile = await supabase
          .from('profiles')
          .select('id, display_name, handle, avatar_url')
          .eq('id', senderId)
          .maybeSingle();

      final otherProfile = ConversationUser(
        id: senderId,
        displayName: (profile?['display_name'] as String?)?.trim(),
        handle: (profile?['handle'] as String?)?.trim(),
        avatarUrl: (profile?['avatar_url'] as String?)?.trim(),
      );

      nav.push(
        MaterialPageRoute(
          builder: (_) => InboxConversationPage(
            otherUserId: senderId,
            otherProfile: otherProfile,
          ),
        ),
      );
    } catch (_) {
      nav.push(MaterialPageRoute(builder: (_) => const InboxPage()));
    }
  }

  Future<void> _openEventInvite(
    NavigatorState nav,
    String shareId, {
    String? senderId,
  }) async {
    try {
      final row = await supabase
          .from('inbox_share_items_filtered')
          .select()
          .eq('share_id', shareId)
          .maybeSingle();
      if (row != null) {
        final share = InboxShareItem.fromJson(row);
        nav.push(
          MaterialPageRoute(
            builder: (_) => EventInviteDetailsPage(share: share),
          ),
        );
        return;
      }
    } catch (_) {
      // Fall back below.
    }

    if (senderId != null && senderId.isNotEmpty) {
      await _openDmConversation(nav, senderId);
      return;
    }
    nav.push(MaterialPageRoute(builder: (_) => const InboxPage()));
  }
}
