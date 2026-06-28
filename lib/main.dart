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
import 'package:http/http.dart' as http;

import 'data/user_events_repo.dart';
import 'features/calendar/notify.dart';
import 'features/calendar/calendar_page.dart';
import 'features/calendar/daily_cosmic_context_badge.dart';
import 'features/calendar/ics_preview_card.dart';
import 'utils/ics_parser.dart';
import 'features/sharing/share_preview_page.dart';
import 'features/inbox/inbox_page.dart';
import 'features/inbox/inbox_conversation_page.dart';
import 'features/inbox/conversation_user.dart';
import 'features/inbox/shared_flow_details_entry.dart';
import 'features/inbox/shared_flow_details_page.dart';
import 'features/inbox/inbox_threading.dart';
import 'features/invites/event_invite_details_page.dart';
import 'data/profile_model.dart';
import 'data/profile_repo.dart';
import 'data/flow_post_model.dart';
import 'data/insight_post_model.dart';
import 'data/maat_guidance_model.dart';
import 'data/maat_guidance_repo.dart';
import 'data/profile_avatar_glyphs.dart';
import 'data/share_models.dart';
import 'utils/event_cid_util.dart';
import 'telemetry/telemetry.dart';
import 'shared/glossy_text.dart';

import 'utils/hive_local_storage_web.dart';
import 'core/async_guard.dart';
import 'core/app_link_intent.dart';
import 'core/global_menu_routes.dart';
import 'core/navigation_fallback.dart';
import 'core/navigation_persistence_policy.dart';
import 'core/planner_launch_intent.dart';
import 'core/push_intent_bus.dart';
import 'core/shared_file_intent.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'services/calendar_sync_service.dart';
import 'services/navigation_trace.dart';
import 'services/push_notifications.dart';
import 'services/decan_reflection_scheduler.dart';
import 'features/journal/journal_controller.dart';
import 'features/journal/journal_entry_detail_page.dart';
import 'features/journal/journal_page.dart';
import 'features/calendar/calendar_reflection_context.dart';
import 'features/maat_guidance/maat_guidance_controller.dart';
import 'features/maat_guidance/maat_guidance_detail_page.dart';
import 'features/maat_guidance/maat_guidance_floating_card.dart';
import 'features/nodes/kemetic_node_library.dart';
import 'features/nodes/kemetic_node_list_page.dart';
import 'features/nodes/kemetic_node_reader_page.dart';
import 'package:mobile/features/onboarding/guided_onboarding_overlay.dart';
import 'features/onboarding/onboarding_progress.dart';
import 'features/onboarding/onboarding_storage.dart';
import 'features/profile/edit_profile_page.dart';
import 'features/profile/flow_post_detail_page.dart';
import 'features/profile/flow_post_picker_page.dart';
import 'features/profile/follow_list_page.dart';
import 'features/profile/insight_post_detail_page.dart';
import 'features/profile/insight_post_picker_page.dart';
import 'features/profile/profile_page.dart';
import 'features/profile/profile_search_page.dart';
import 'features/reflections/decan_reflection_archive_page.dart';
import 'features/shared_practice/shared_practice_room_page.dart';
import 'features/rhythm/pages/commitment_tracker_page.dart';
import 'features/rhythm/pages/rhythm_editors.dart';
import 'features/rhythm/pages/todays_alignment_page.dart';
import 'features/settings/settings_page.dart';
import 'features/settings/settings_prefs.dart';
import 'features/reflections/decan_reflection_detail_page.dart';
import 'widgets/global_side_drawer.dart';
import 'widgets/kemetic_keyboard.dart';
import 'widgets/kemetic_day_info.dart';
import 'services/app_restoration_service.dart';
import 'services/app_window_service.dart';
import 'services/app_navigation_restoration_controller.dart';
import 'services/restoration_coordinator.dart';
import 'services/restoration_trace.dart';
import 'services/session_resume_service.dart';

// Conditional import: on web we use URL cleanup + visibility hook; elsewhere no-ops.
import 'utils/web_history.dart'
    if (dart.library.html) 'utils/web_history_web.dart';

// ---- Supabase configuration via --dart-define ----
const supabaseUrlEnv = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKeyEnv = String.fromEnvironment('SUPABASE_ANON_KEY');
const appEnvironmentEnv = String.fromEnvironment(
  'APP_ENV',
  defaultValue: 'dev',
);
const defaultProductionAppSiteUrl = 'https://maat.app';
const appSiteUrlEnv = String.fromEnvironment(
  'APP_SITE_URL',
  defaultValue: defaultProductionAppSiteUrl,
);
const _kDebugDaySheetSmokeRoute = '/debug/day-sheet-smoke';
const _debugInitialRouteEnv = String.fromEnvironment('H3W_DEBUG_ROUTE');
const _debugDaySheetSmokeEnv = bool.fromEnvironment(
  'H3W_DEBUG_DAY_SHEET_SMOKE',
);

bool _debugDaySheetSmokeBootRequested = false;

typedef AppRuntimeConfig = ({
  String url,
  String anonKey,
  String appEnvironment,
  String appSiteUrl,
});

// Silences console output in release/profile builds to keep store reviews clean
final ZoneSpecification _releasePrintSilencer = ZoneSpecification(
  print: (self, parent, zone, line) {
    if (kDebugMode) parent.print(zone, line);
  },
);

Future<AppRuntimeConfig> _loadSupabaseConfig() async {
  var url = supabaseUrlEnv.trim();
  var anonKey = supabaseAnonKeyEnv.trim();
  var appEnvironment = appEnvironmentEnv.trim();
  var appSiteUrl = appSiteUrlEnv.trim();

  if (kIsWeb) {
    final webEnv = await _loadWebRuntimeEnvJson();
    url = _runtimeFallbackValue(url, webEnv['SUPABASE_URL']);
    anonKey = _runtimeFallbackValue(anonKey, webEnv['SUPABASE_ANON_KEY']);
    appEnvironment = _runtimeFallbackValue(
      appEnvironment,
      webEnv['APP_ENV'],
      treatDevAsUnset: true,
    );
    appSiteUrl = _runtimeFallbackValue(
      appSiteUrl,
      webEnv['APP_SITE_URL'],
      treatDefaultSiteAsUnset: true,
    );
  }

  if (kIsWeb && kReleaseMode && _hasValidSupabaseRuntimeConfig(url, anonKey)) {
    final envName = appEnvironment.trim().toLowerCase();
    if (envName.isEmpty || envName == 'dev') {
      appEnvironment = 'prod';
    }
    if (appSiteUrl.trim().isEmpty) {
      appSiteUrl = defaultProductionAppSiteUrl;
    }
  }

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

  return (
    url: url,
    anonKey: anonKey,
    appEnvironment: appEnvironment,
    appSiteUrl: appSiteUrl,
  );
}

bool _isDebugDaySheetSmokeLocation(String? raw) {
  if (!kDebugMode) return false;
  final value = raw?.trim();
  if (value == null || value.isEmpty) return false;
  final uri = Uri.tryParse(value);
  final path = uri?.path.isNotEmpty == true
      ? uri!.path
      : value.split('?').first.split('#').first;
  return path == _kDebugDaySheetSmokeRoute;
}

String? _debugInitialLocationFromDefines() {
  if (!kDebugMode) return null;
  if (_debugDaySheetSmokeEnv) return _kDebugDaySheetSmokeRoute;
  if (_isDebugDaySheetSmokeLocation(_debugInitialRouteEnv)) {
    return _kDebugDaySheetSmokeRoute;
  }
  return null;
}

bool _debugDaySheetSmokeRequestedAtBoot() {
  if (!kDebugMode) return false;
  if (_debugInitialLocationFromDefines() != null) return true;
  if (kIsWeb && _isDebugDaySheetSmokeLocation(Uri.base.toString())) {
    return true;
  }
  return _isDebugDaySheetSmokeLocation(
    PlatformDispatcher.instance.defaultRouteName,
  );
}

AppRuntimeConfig _debugDaySheetSmokeFallbackConfig() {
  return (
    url: 'https://debug-day-sheet-smoke.supabase.co',
    anonKey: 'sb_publishable_debug_day_sheet_smoke_route_only',
    appEnvironment: 'dev',
    appSiteUrl: defaultProductionAppSiteUrl,
  );
}

Future<Map<String, String>> _loadWebRuntimeEnvJson() async {
  if (!kIsWeb) return const {};

  try {
    final response = await http.get(Uri.base.resolve('env.json'));
    if (response.statusCode != 200) {
      if (kDebugMode) {
        debugPrint('[env] env.json returned HTTP ${response.statusCode}');
      }
      return const {};
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return const {};

    return decoded.map((key, value) {
      final stringValue = value is String ? value.trim() : '';
      return MapEntry(key, stringValue);
    })..removeWhere((_, value) => value.isEmpty);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[env] Failed to load web env.json: $e');
    }
    return const {};
  }
}

String _runtimeFallbackValue(
  String current,
  String? candidate, {
  bool treatDevAsUnset = false,
  bool treatDefaultSiteAsUnset = false,
}) {
  final next = candidate?.trim() ?? '';
  if (next.isEmpty) return current;

  final normalizedCurrent = current.trim();
  final lowerCurrent = normalizedCurrent.toLowerCase();
  final currentLooksUnset =
      normalizedCurrent.isEmpty ||
      _looksLikePlaceholder(lowerCurrent) ||
      (treatDevAsUnset && lowerCurrent == 'dev') ||
      (treatDefaultSiteAsUnset && lowerCurrent == 'https://maat.app');

  return currentLooksUnset ? next : current;
}

bool _hasValidSupabaseRuntimeConfig(String url, String anonKey) {
  return _hasValidSupabaseUrl(url) && _hasValidSupabaseAnonKey(anonKey);
}

bool _hasValidSupabaseUrl(String url) {
  final normalized = url.trim();
  final parsed = Uri.tryParse(normalized);
  return normalized.isNotEmpty &&
      parsed != null &&
      parsed.scheme == 'https' &&
      parsed.host.endsWith('.supabase.co') &&
      !_looksLikePlaceholder(normalized.toLowerCase());
}

bool _hasValidSupabaseAnonKey(String anonKey) {
  final normalized = anonKey.trim();
  final lower = normalized.toLowerCase();
  return normalized.length > 20 &&
      !_looksLikePlaceholder(lower) &&
      !lower.contains('service_role') &&
      !lower.contains('service-role');
}

List<String> _runtimeConfigErrors(AppRuntimeConfig config) {
  final errors = <String>[];
  final url = config.url.trim();
  final anonKey = config.anonKey.trim();
  final envName = config.appEnvironment.trim().toLowerCase();
  final siteUrl = config.appSiteUrl.trim();
  final nativeRedirect = Uri.tryParse(nativeAuthRedirectUrl);

  if (url.isEmpty) {
    errors.add('SUPABASE_URL is missing.');
  } else {
    final parsed = Uri.tryParse(url);
    final lowerUrl = url.toLowerCase();
    if (parsed == null ||
        parsed.scheme != 'https' ||
        !parsed.host.endsWith('.supabase.co') ||
        _looksLikePlaceholder(lowerUrl)) {
      errors.add('SUPABASE_URL must be a real https://*.supabase.co URL.');
    }
  }

  final lowerAnon = anonKey.toLowerCase();
  if (anonKey.length <= 20) {
    errors.add('SUPABASE_ANON_KEY is missing or too short.');
  } else if (_looksLikePlaceholder(lowerAnon)) {
    errors.add('SUPABASE_ANON_KEY still looks like a placeholder.');
  } else if (lowerAnon.contains('service_role') ||
      lowerAnon.contains('service-role')) {
    errors.add('SUPABASE_ANON_KEY must not be a service role key.');
  }

  if (envName.isEmpty) {
    errors.add('APP_ENV is missing.');
  } else if (!const {'dev', 'staging', 'prod'}.contains(envName)) {
    errors.add('APP_ENV must be one of dev, staging, or prod.');
  }

  if ((kReleaseMode || kProfileMode) && envName == 'dev') {
    errors.add('Release/profile builds must set APP_ENV to staging or prod.');
  }

  final site = Uri.tryParse(siteUrl);
  if (siteUrl.isEmpty ||
      site == null ||
      site.scheme != 'https' ||
      site.host.isEmpty ||
      _looksLikePlaceholder(siteUrl.toLowerCase())) {
    errors.add('APP_SITE_URL must be a real https URL.');
  }

  if (nativeRedirect == null ||
      nativeRedirect.scheme != 'kemet.app' ||
      nativeRedirect.host != 'login-callback') {
    errors.add('Native auth redirect must remain kemet.app://login-callback.');
  }

  return errors;
}

bool _looksLikePlaceholder(String value) {
  return value.contains('your-') ||
      value.contains('your_') ||
      value.contains('your_project') ||
      value.contains('placeholder') ||
      value.contains('example') ||
      value.contains('change-me');
}

Widget _runtimeConfigErrorApp(List<String> errors) {
  final visibleErrors = kDebugMode
      ? errors
      : const <String>['Production app configuration is incomplete.'];
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Missing App Configuration',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'The app cannot start until required public runtime config is provided.',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  for (final error in visibleErrors)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '- $error',
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.35,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
@visibleForTesting
GlobalKey<NavigatorState> get rootNavigatorKeyForTesting => _rootNavigatorKey;
final ValueNotifier<bool> _webAuthExchangeInProgress = ValueNotifier<bool>(
  false,
);
String? _bootRestoredLocation;
String? _bootExplicitIntentLocation;
String? _bootAuthDeferredRestoredLocation;
bool _bootRestoreDeferredForAuth = false;
bool _bootDeferredRestorePreparedForAuth = false;
PushInitialMessage? _bootInitialPushMessage;
String? _bootInitialAppLinkSignature;
String? _lastHandledAuthCallbackSignature;
DateTime? _lastHandledAuthCallbackAt;

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
    _debugDaySheetSmokeBootRequested = _debugDaySheetSmokeRequestedAtBoot();

    // Register background handler for FCM (no-op on web)
    registerPushBackgroundHandler();

    var supabaseConfig = await _loadSupabaseConfig();
    var runtimeConfigErrors = _runtimeConfigErrors(supabaseConfig);
    if (_debugDaySheetSmokeBootRequested && runtimeConfigErrors.isNotEmpty) {
      supabaseConfig = _debugDaySheetSmokeFallbackConfig();
      runtimeConfigErrors = _runtimeConfigErrors(supabaseConfig);
      if (kDebugMode) {
        debugPrint(
          '[debug-smoke] Using local placeholder Supabase config for $_kDebugDaySheetSmokeRoute',
        );
      }
    }

    if (kDebugMode) {
      debugPrint(
        '[boot] Supabase config present: '
        'urlHost=${safeUriHost(supabaseConfig.url)} '
        'anonKeyPresent=${supabaseConfig.anonKey.isNotEmpty}',
      );
    }

    if (runtimeConfigErrors.isNotEmpty) {
      runApp(_runtimeConfigErrorApp(runtimeConfigErrors));
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

    if (!_debugDaySheetSmokeBootRequested) {
      await _refreshSessionIfNeeded('boot');

      await ProfileRepo(Supabase.instance.client).preloadLocalCaches();
    }

    await AppWindowService.instance.ensureInitialized();
    await AppRestorationService.instance.initialize();
    await NavigationTrace.instance.load();
    if (_debugDaySheetSmokeBootRequested) {
      _bootExplicitIntentLocation = _kDebugDaySheetSmokeRoute;
      _bootRestoredLocation = null;
    } else {
      await _readBootInitialAppLinkIntent();
      await _readBootInitialPushIntent();
      _bootRestoredLocation = await _readBootRestoredLocation();
    }
    final initialLocation = _resolveInitialLocation();
    _router = _createRouter(initialLocation: initialLocation);
    traceRestoration('boot router created initialLocation=$initialLocation');
    traceRestoration(
      'boot route apply prepared explicit=${_bootExplicitIntentLocation ?? '<none>'} '
      'restored=${_bootRestoredLocation ?? '<none>'} '
      'initial=$initialLocation',
    );
    final restoreTargetLocation = _authDeferredRestorePending
        ? _bootAuthDeferredRestoredLocation
        : initialLocation;
    RestorationCoordinator.instance.beginLaunchRestore(
      reason: RestorationRestoreReason.coldLaunch,
      targetLocation: restoreTargetLocation,
    );
    _suppressPassiveLaunchSurfacesForExplicitIntentIfNeeded();

    // 🚨 Initialize notifications/push without blocking the first frame.
    // AuthGate will re-attempt on sign-in if these fail.
    if (!_debugDaySheetSmokeBootRequested) {
      _startBackgroundWarmups();

      // Web/PWA boot hardening (iOS PWA friendly)
      _startWebBootTasks();
    }

    runApp(const MyApp());
    _traceRouterLocationAfterFrame('after_run_app_first_frame');
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

bool _shouldSkipDuplicateAuthCallback(Uri uri) {
  final signature = uri.toString();
  final now = DateTime.now();
  final isRecentDuplicate =
      _lastHandledAuthCallbackSignature == signature &&
      _lastHandledAuthCallbackAt != null &&
      now.difference(_lastHandledAuthCallbackAt!) < const Duration(seconds: 5);
  if (isRecentDuplicate) {
    return true;
  }
  _lastHandledAuthCallbackSignature = signature;
  _lastHandledAuthCallbackAt = now;
  return false;
}

Future<bool> _exchangeAuthCallbackUri(Uri uri) async {
  if (_shouldSkipDuplicateAuthCallback(uri)) return false;
  try {
    await supabase.auth.exchangeCodeForSession(uri.toString());
    await supabase.auth.refreshSession();
    Events.debugAuthBanner('deeplink');
    return true;
  } catch (error) {
    if (kDebugMode) {
      debugPrint('[auth] exchangeCodeForSession failed: $error');
    }
    return false;
  }
}

Future<void> _startGoogleSignIn(BuildContext context) async {
  final redirect = authRedirectTo();
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
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Sign-in failed: $error')));
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
    if (!kDebugMode) return;
    final s = supabase.auth.currentSession;
    if (s == null) {
      debugPrint('[auth] ($origin) NO SESSION');
    } else {
      debugPrint(
        '[auth] ($origin) user=${safeLogIdentifier(s.user.id)} '
        'token=<redacted>',
      );
    }
  }

  static Future<void> trackIfAuthed(
    String event,
    Map<String, dynamic> props,
  ) async {
    final s = supabase.auth.currentSession;
    if (s == null) {
      if (kDebugMode) {
        debugPrint('[events] skipped "$event" (no session)');
      }
      return;
    }
    try {
      await _repo.track(event: event, properties: props);
      if (kDebugMode) {
        debugPrint(
          '[events] inserted "$event" user=${safeLogIdentifier(s.user.id)}',
        );
      }
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
final ValueNotifier<int> _maatGuidancePostEnsureRefresh = ValueNotifier<int>(0);
const MethodChannel _shellBackChannel = MethodChannel(
  'com.kemetic.calendar/shell_back',
);
final _FloatingMenuRouteObserver _floatingMenuRouteObserver =
    _FloatingMenuRouteObserver();
final GlobalKey globalMenuButtonKey = GlobalKey(
  debugLabel: 'global_menu_bubble',
);
const Duration _floatingMenuModalSettleDelay = Duration(milliseconds: 80);
const bool _debugForceGlobalFloatingMenu = bool.fromEnvironment(
  'FORCE_GLOBAL_MENU_FOR_TESTING',
);
bool _debugForceGlobalFloatingMenuForTesting = false;

int get globalFloatingMenuModalDepthValue => _floatingMenuModalDepth.value;

@visibleForTesting
NavigatorObserver get globalFloatingMenuRouteObserverForTesting =>
    _floatingMenuRouteObserver;

bool get rootNavigatorContextMountedForNavigationTrace =>
    _rootNavigatorKey.currentContext?.mounted ?? false;

bool get rootNavigatorOverlayContextMountedForNavigationTrace =>
    _rootNavigatorKey.currentState?.overlay?.context.mounted ?? false;

String get rootRouterUriForNavigationTrace {
  try {
    return _router.routerDelegate.currentConfiguration.uri.toString();
  } catch (error) {
    return '<unavailable:${error.runtimeType}>';
  }
}

class _FloatingMenuRouteObserver extends NavigatorObserver {
  bool _isSearchRoute(Route<dynamic> route) {
    if (route is! PageRoute<dynamic>) return false;
    try {
      final Object? delegate = (route as dynamic).delegate;
      return delegate is SearchDelegate<dynamic>;
    } catch (_) {
      return false;
    }
  }

  bool _suppressesFloatingMenu(Route<dynamic> route) {
    if (route.settings.name == calendarActionsMenuRouteName) return false;
    if (route.settings.name == calendarMonthDetailRouteName) return true;
    if (_isSearchRoute(route)) return true;
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
  final ScreenViewDedupe _screenViews = ScreenViewDedupe();

  void _send(PageRoute<dynamic>? route) {
    if (kDebugMode && _debugDaySheetSmokeBootRequested) return;
    final name = route?.settings.name ?? '/';
    if (!_screenViews.shouldTrack(name, DateTime.now())) return;
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
  final debugInitial = _debugInitialLocationFromDefines();
  if (debugInitial != null) return debugInitial;
  if (_debugDaySheetSmokeBootRequested) return _kDebugDaySheetSmokeRoute;

  final defaultRoute = PlatformDispatcher.instance.defaultRouteName.trim();
  final location =
      defaultRoute.isEmpty || defaultRoute == Navigator.defaultRouteName
      ? _bootExplicitIntentLocation ?? _bootRestoredLocation ?? '/'
      : defaultRoute.startsWith('/')
      ? defaultRoute
      : '/$defaultRoute';
  traceRestoration(
    'boot initial route resolved location=$location '
    'defaultRoute=${defaultRoute.isEmpty ? '<empty>' : defaultRoute} '
    'explicit=${_bootExplicitIntentLocation ?? '<none>'} '
    'restored=${_bootRestoredLocation ?? '<none>'}',
  );
  return location;
}

String _routerLocationForTrace() {
  try {
    return _router.routerDelegate.currentConfiguration.uri.toString();
  } catch (error) {
    return '<unavailable:$error>';
  }
}

void _traceRouterLocationAfterFrame(String reason) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    traceRestoration(
      'router final route reason=$reason location=${_routerLocationForTrace()}',
    );
  });
}

String? _traceRouterRedirect(Uri uri, String? redirect) {
  traceRestoration('router redirect input=$uri output=${redirect ?? '<none>'}');
  return redirect;
}

String _traceRouteValue(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? '<none>' : normalized;
}

Future<void> _readBootInitialAppLinkIntent() async {
  if (kIsWeb) return;
  final initialUri = await _readInitialAppLinkUri();
  if (initialUri == null) return;
  final intent = AppLinkIntent.parse(initialUri);
  if (intent == null) return;

  _bootInitialAppLinkSignature = _appLinkIntentSignature(intent, initialUri);
  final location = _initialLocationFromAppLinkIntent(intent);
  if (location != null) {
    _bootExplicitIntentLocation ??= await _consumeBootOneShotLocation(
      requestedRoute: location,
      key: _bootInitialAppLinkSignature!,
      source: intent is AuthAppLinkIntent
          ? NavigationSource.authCallback
          : NavigationSource.appLink,
    );
  }
  if (intent is AuthAppLinkIntent) {
    await _exchangeAuthCallbackUri(intent.uri);
  }
}

Future<Uri?> _readInitialAppLinkUri() async {
  final appLinks = AppLinks();
  try {
    try {
      return await (appLinks as dynamic).getInitialAppLink() as Uri?;
    } catch (_) {
      return await (appLinks as dynamic).getInitialLink() as Uri?;
    }
  } catch (_) {
    return null;
  }
}

Future<void> _readBootInitialPushIntent() async {
  if (kIsWeb) {
    final location = _initialLocationFromPushData(
      _pushIntentDataFromQuery(Uri.base.queryParameters),
      hasSession: Supabase.instance.client.auth.currentSession != null,
    );
    if (location != null) {
      _bootExplicitIntentLocation ??= await _consumeBootOneShotLocation(
        requestedRoute: location,
        key: 'web-push:${Uri.base.query}',
        source: NavigationSource.notificationTap,
      );
    }
    return;
  }

  final initial = await PushNotifications.instance(
    Supabase.instance.client,
  ).takeInitialMessage();
  _bootInitialPushMessage = initial;
  final location = _initialLocationFromPushData(
    initial?.data,
    hasSession: Supabase.instance.client.auth.currentSession != null,
  );
  if (location != null) {
    _bootExplicitIntentLocation ??= await _consumeBootOneShotLocation(
      requestedRoute: location,
      key: 'push:${initial?.messageId ?? jsonEncode(initial?.data)}',
      source: NavigationSource.notificationTap,
    );
  }
}

Future<String?> _consumeBootOneShotLocation({
  required String requestedRoute,
  required String key,
  required NavigationSource source,
}) async {
  final resolved = await AppNavigationRestorationController.instance
      .consumeOneShotIntent(
        PendingNavigationIntent(
          key: key,
          requestedRoute: requestedRoute,
          source: source,
        ),
      );
  return resolved?.route;
}

bool _hasExplicitBootIntent() {
  final defaultRoute = PlatformDispatcher.instance.defaultRouteName.trim();
  return _bootExplicitIntentLocation != null ||
      (defaultRoute.isNotEmpty && defaultRoute != Navigator.defaultRouteName);
}

bool get _authDeferredRestorePending {
  final target = _bootAuthDeferredRestoredLocation?.trim();
  return _bootRestoreDeferredForAuth &&
      !_hasExplicitBootIntent() &&
      target != null &&
      target.isNotEmpty &&
      target != '/';
}

void _suppressPassiveLaunchSurfacesForExplicitIntentIfNeeded() {
  if (!_hasExplicitBootIntent()) return;
  RestorationCoordinator.instance.suppressRestoreForExplicitIntent(
    reason: 'explicit_launch_intent',
    surfaces: const <String>[
      RestorationCoordinator.calendarDayViewSurface,
      RestorationCoordinator.calendarOverlayStackSurface,
    ],
  );
}

Future<String?> _readBootRestoredLocation() async {
  final hasSession = Supabase.instance.client.auth.currentSession != null;
  traceRestoration('boot restore read start hasSession=$hasSession');
  final destination = await AppNavigationRestorationController.instance
      .restoreLaunchDestination(
        isAuthenticated: hasSession,
        includeRemote: hasSession,
      );
  final result = await AppRestorationService.instance.readBestSnapshot(
    includeRemote: hasSession,
  );
  traceRestoration(
    'boot restore read result status=${result.status.name} '
    'source=${result.source ?? '<none>'} reason=${result.reason ?? '<none>'} '
    'route=${_traceRouteValue(result.snapshot?.routeLocation)} '
    'updatedAtMs=${result.snapshot?.updatedAtMs ?? '<none>'} '
    'overlayCount=${result.snapshot?.overlayStack.length ?? 0}',
  );
  final tentativeRoute = result.snapshot?.routeLocation?.trim();
  if (!hasSession &&
      result.status == AppRestorationReadStatus.tentative &&
      tentativeRoute != null &&
      tentativeRoute.isNotEmpty) {
    _bootRestoreDeferredForAuth = true;
    _bootAuthDeferredRestoredLocation = tentativeRoute;
    traceRestoration(
      'boot restore deferred_for_auth '
      'route=$_bootAuthDeferredRestoredLocation '
      'source=${result.source ?? '<none>'} '
      'reason=${result.reason ?? '<none>'}',
    );
  }
  traceRestoration(
    'boot restore selected=${destination.route} '
    'decisionSource=${destination.decisionSource} reason=${destination.reason}',
  );
  return destination.route;
}

void _prepareDeferredBootRestoreForAuth(AuthChangeEvent event) {
  final target = _bootAuthDeferredRestoredLocation?.trim();
  traceRestoration(
    'auth deferred restore prepare event=${event.name} '
    'deferred=$_bootRestoreDeferredForAuth '
    'prepared=$_bootDeferredRestorePreparedForAuth '
    'target=${target == null || target.isEmpty ? '<none>' : target} '
    'explicit=${_hasExplicitBootIntent()}',
  );
  if (!_bootRestoreDeferredForAuth ||
      _bootDeferredRestorePreparedForAuth ||
      _hasExplicitBootIntent() ||
      target == null ||
      target.isEmpty) {
    return;
  }
  RestorationCoordinator.instance.beginAuthResumeRestore(
    targetLocation: target,
  );
  _bootDeferredRestorePreparedForAuth = true;
}

Future<void> _replayDeferredBootRestoreAfterAuth(AuthChangeEvent event) async {
  final currentRoute = _routerLocationForTrace();
  traceRestoration(
    'auth deferred restore replay start event=${event.name} '
    'current=$currentRoute deferred=$_bootRestoreDeferredForAuth '
    'explicit=${_hasExplicitBootIntent()}',
  );
  final destination = await AppNavigationRestorationController.instance
      .restoreDeferredLaunchDestinationAfterAuth(
        currentRoute: currentRoute,
        restoreWasDeferredForAuth: _bootRestoreDeferredForAuth,
        hasExplicitBootIntent: _hasExplicitBootIntent(),
        includeRemote: true,
      );
  if (destination == null) {
    _bootRestoreDeferredForAuth = false;
    _bootAuthDeferredRestoredLocation = null;
    _bootDeferredRestorePreparedForAuth = false;

    // Timing safety net: on hot restart or fast-auth, initialSession can
    // fire before _bootRestoreDeferredForAuth is set. If auth confirms while
    // the app is still at '/', run a fresh authenticated restore before
    // leaving the user on the boot default.
    final trimmedCurrent = currentRoute.trim();
    final isAtRoot = trimmedCurrent.isEmpty || trimmedCurrent == '/';
    if (isAtRoot) {
      final fallback = await AppNavigationRestorationController.instance
          .restoreLaunchDestination(isAuthenticated: true, includeRemote: true);
      final fallbackRoute = fallback.route.trim();
      final fallbackIsRoot = fallbackRoute.isEmpty || fallbackRoute == '/';
      if (!fallbackIsRoot) {
        RestorationCoordinator.instance.beginAuthResumeRestore(
          targetLocation: fallbackRoute,
        );
        _router.go(fallbackRoute);
        traceRestoration(
          'auth deferred restore replay completed route=$fallbackRoute '
          'reason=fallback_authenticated_restore',
        );
        _traceRouterLocationAfterFrame('after_auth_deferred_restore_fallback');
      }
    }
    return;
  }

  RestorationCoordinator.instance.beginAuthResumeRestore(
    targetLocation: destination.route,
  );
  traceRestoration(
    'auth deferred restore replay apply event=${event.name} '
    'from=$currentRoute to=${destination.route} '
    'decisionSource=${destination.decisionSource} '
    'reason=${destination.reason}',
  );
  _bootRestoreDeferredForAuth = false;
  _bootAuthDeferredRestoredLocation = null;
  _bootDeferredRestorePreparedForAuth = false;
  _router.go(destination.route);
  traceRestoration(
    'auth deferred restore replay completed route=${destination.route}',
  );
  _traceRouterLocationAfterFrame('after_auth_deferred_restore');
}

Map<String, dynamic>? _pushIntentDataFromQuery(Map<String, String> params) {
  final kind = _trimmedPushValue(params['push_kind'] ?? params['pushKind']);
  if (kind == null) return null;

  return <String, dynamic>{
    'kind': kind,
    if (_trimmedPushValue(params['reflection_id'] ?? params['reflectionId']) !=
        null)
      'reflection_id': params['reflection_id'] ?? params['reflectionId'],
    if (_trimmedPushValue(params['delivery_id'] ?? params['deliveryId']) !=
        null)
      'delivery_id': params['delivery_id'] ?? params['deliveryId'],
    if (_trimmedPushValue(params['cta_type'] ?? params['ctaType']) != null)
      'cta_type': params['cta_type'] ?? params['ctaType'],
    if (_trimmedPushValue(params['cta_ref'] ?? params['ctaRef']) != null)
      'cta_ref': params['cta_ref'] ?? params['ctaRef'],
    if (_trimmedPushValue(params['sender_id'] ?? params['senderId']) != null)
      'sender_id': params['sender_id'] ?? params['senderId'],
    if (_trimmedPushValue(params['share_id'] ?? params['shareId']) != null)
      'share_id': params['share_id'] ?? params['shareId'],
    if (_trimmedPushValue(params['calendar_id'] ?? params['calendarId']) !=
        null)
      'calendar_id': params['calendar_id'] ?? params['calendarId'],
    if (_trimmedPushValue(
          params['notification_id'] ?? params['notificationId'],
        ) !=
        null)
      'notification_id': params['notification_id'] ?? params['notificationId'],
    if (_trimmedPushValue(
          params['response_status'] ?? params['responseStatus'],
        ) !=
        null)
      'response_status': params['response_status'] ?? params['responseStatus'],
    if (_trimmedPushValue(
          params['client_event_id'] ?? params['clientEventId'],
        ) !=
        null)
      'client_event_id': params['client_event_id'] ?? params['clientEventId'],
    if (_trimmedPushValue(params['item_type'] ?? params['itemType']) != null)
      'item_type': params['item_type'] ?? params['itemType'],
    if (_trimmedPushValue(params['item_id'] ?? params['itemId']) != null)
      'item_id': params['item_id'] ?? params['itemId'],
    if (_trimmedPushValue(params['k_year'] ?? params['kYear']) != null)
      'k_year': params['k_year'] ?? params['kYear'],
    if (_trimmedPushValue(params['k_month'] ?? params['kMonth']) != null)
      'k_month': params['k_month'] ?? params['kMonth'],
    if (_trimmedPushValue(params['k_day'] ?? params['kDay']) != null)
      'k_day': params['k_day'] ?? params['kDay'],
    if (_trimmedPushValue(params['event_id'] ?? params['eventId']) != null)
      'event_id': params['event_id'] ?? params['eventId'],
    if (_trimmedPushValue(params['flow_id'] ?? params['flowId']) != null)
      'flow_id': params['flow_id'] ?? params['flowId'],
    if (_trimmedPushValue(params['flow_post_id'] ?? params['flowPostId']) !=
        null)
      'flow_post_id': params['flow_post_id'] ?? params['flowPostId'],
    if (_trimmedPushValue(params['reminder_id'] ?? params['reminderId']) !=
        null)
      'reminder_id': params['reminder_id'] ?? params['reminderId'],
    if (_trimmedPushValue(params['note_id'] ?? params['noteId']) != null)
      'note_id': params['note_id'] ?? params['noteId'],
    if (_trimmedPushValue(params['task_id'] ?? params['taskId']) != null)
      'task_id': params['task_id'] ?? params['taskId'],
    if (_trimmedPushValue(params['delivery_key'] ?? params['deliveryKey']) !=
        null)
      'delivery_key': params['delivery_key'] ?? params['deliveryKey'],
    if (_trimmedPushValue(params['delivery_kind'] ?? params['deliveryKind']) !=
        null)
      'delivery_kind': params['delivery_kind'] ?? params['deliveryKind'],
  };
}

String? _initialLocationFromPushData(
  Map<String, dynamic>? data, {
  required bool hasSession,
}) {
  if (data == null || data.isEmpty) return null;
  final deliveryKeyForKind = _trimmedPushValue(
    data['delivery_key'] ?? data['deliveryKey'],
  );
  final kind =
      _trimmedPushValue(data['kind'] ?? data['type']) ??
      (deliveryKeyForKind?.startsWith('maat_guidance:') == true
          ? 'maat_guidance'
          : null);
  final clientEventId = _trimmedPushValue(
    data['client_event_id'] ?? data['clientEventId'],
  );
  final calendarIntent = CalendarPushOpenIntent.fromNotificationData(data);
  if (kind == null && clientEventId == null && calendarIntent == null) {
    return null;
  }
  if (!hasSession) return '/';

  if (kind == 'maat_guidance') {
    final deliveryId = _trimmedPushValue(
      data['delivery_id'] ??
          data['deliveryId'] ??
          data['maat_guidance_id'] ??
          data['maatGuidanceId'],
    );
    final deliveryKey = _trimmedPushValue(
      data['delivery_key'] ?? data['deliveryKey'],
    );
    final keyId =
        deliveryKey != null && deliveryKey.startsWith('maat_guidance:')
        ? deliveryKey.substring('maat_guidance:'.length)
        : null;
    final id = deliveryId ?? keyId;
    return id == null ? null : '/maat-guidance/${Uri.encodeComponent(id)}';
  }

  final reflectionId = _trimmedPushValue(
    data['reflectionId'] ?? data['reflection_id'],
  );
  if (kind == 'decan_reflection' && reflectionId != null) {
    return '/reflections/${Uri.encodeComponent(reflectionId)}';
  }

  final shareKind = _trimmedPushValue(data['share_kind'] ?? data['shareKind']);
  if (kind == 'flow_share' || (kind == 'dm' && shareKind == 'flow')) {
    final shareId = _trimmedPushValue(data['share_id'] ?? data['shareId']);
    return shareId == null
        ? '/inbox'
        : '/shared-flow/${Uri.encodeComponent(shareId)}';
  }

  if (kind == 'dm') {
    final senderId = _trimmedPushValue(
      data['conversation_user_id'] ??
          data['conversationUserId'] ??
          data['sender_id'] ??
          data['senderId'],
    );
    return senderId == null
        ? '/inbox'
        : '/inbox/conversation/${Uri.encodeComponent(senderId)}';
  }

  if (kind == 'event_invite') {
    final shareId = _trimmedPushValue(data['share_id'] ?? data['shareId']);
    return shareId == null
        ? '/inbox'
        : '/event-invite/${Uri.encodeComponent(shareId)}';
  }

  if (kind == 'follow' ||
      kind == 'calendar_invite' ||
      kind == 'calendar_invite_response') {
    return '/inbox';
  }

  final sharedCalendarInboxRoute = sharedCalendarInboxRouteLocationFromPushData(
    data,
  );
  if (sharedCalendarInboxRoute != null) {
    return sharedCalendarInboxRoute;
  }

  if (kind == 'flow_like' ||
      kind == 'flow_comment' ||
      kind == 'flow_comment_reply' ||
      kind == 'flow_comment_like') {
    final flowPostId = _trimmedPushValue(
      data['flow_post_id'] ?? data['flowPostId'],
    );
    if (flowPostId == null) return '/inbox';
    final comments = kind == 'flow_like' ? '' : '?comments=1';
    return '/flow-post/${Uri.encodeComponent(flowPostId)}$comments';
  }

  if (kind == 'shared_calendar_item_added' ||
      kind == 'calendar_event' ||
      kind == 'scheduled_notification' ||
      kind == 'reminder_10min' ||
      (clientEventId != null && kind == 'reminder') ||
      clientEventId != null ||
      calendarIntent != null) {
    return '/';
  }

  return null;
}

String? _trimmedPushValue(Object? raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  return text.isEmpty ? null : text;
}

String? _initialLocationFromAppLinkIntent(AppLinkIntent intent) {
  if (intent is AuthAppLinkIntent) {
    return '/';
  }
  if (intent is PlannerAppLinkIntent) {
    return intent.routeLocation;
  }
  if (intent is ShareAppLinkIntent) {
    return intent.routeLocation;
  }
  return null;
}

String _appLinkIntentSignature(AppLinkIntent intent, Uri uri) {
  return intent is AuthAppLinkIntent
      ? 'auth:${intent.uri}'
      : intent is ShareAppLinkIntent
      ? 'share:${intent.routeLocation}'
      : intent is PlannerAppLinkIntent
      ? 'planner:${intent.routeLocation}'
      : 'unknown:${uri.toString()}';
}

bool _isBootInitialAppLinkUri(Uri uri) {
  final intent = AppLinkIntent.parse(uri);
  final signature = intent == null
      ? null
      : _appLinkIntentSignature(intent, uri);
  return signature != null && signature == _bootInitialAppLinkSignature;
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

String _navigationTraceProfileUserId(String? userId, String? currentUserId) {
  final trimmed = userId?.trim();
  if (trimmed == null || trimmed.isEmpty) return '<empty>';
  if (trimmed == 'me') return 'me';
  if (currentUserId != null && currentUserId == trimmed) {
    return '<currentUser>';
  }
  return '<id:${trimmed.length}>';
}

late final GoRouter _router;

GoRoute _calmRoute({
  required String path,
  required Widget Function(BuildContext context, GoRouterState state) builder,
}) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => NoTransitionPage<dynamic>(
      key: state.pageKey,
      child: builder(context, state),
    ),
  );
}

GoRoute _utilitySheetRoute({
  required String path,
  required Widget Function(BuildContext context, GoRouterState state) builder,
}) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) {
      return CustomTransitionPage<dynamic>(
        key: state.pageKey,
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 140),
        child: builder(context, state),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
    },
  );
}

GoRouter _createRouter({required String initialLocation}) => GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: initialLocation,
  // Route history is intentionally not restored by go_router. The app owns
  // durable state through AppRestorationService; restoring Navigator history
  // here reopens whatever secondary page was active before process restart.
  observers: <NavigatorObserver>[
    routeObserver,
    _floatingMenuRouteObserver,
    TelemetryRouteObserver(),
  ],
  redirect: (context, state) => _traceRouterRedirect(
    state.uri,
    _redirectRetiredRhythmRoute(state.uri) ??
        _redirectExternalAppLink(state.uri),
  ),
  routes: [
    _calmRoute(path: '/', builder: (context, state) => const AuthGate()),
    if (kDebugMode)
      _calmRoute(
        path: _kDebugDaySheetSmokeRoute,
        builder: (context, state) {
          return SessionTrackedRoute(
            location: state.uri.toString(),
            child: CalendarPage.buildDebugDaySheetSmokeRoute(),
          );
        },
      ),
    _calmRoute(
      path: '/inbox',
      builder: (context, state) {
        traceRestoration('router build /inbox uri=${state.uri}');
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
        final initialSharedCalendarId =
            state.uri.queryParameters[sharedCalendarInboxCalendarQueryParam] ??
            state.uri.queryParameters['calendar_id'];
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: InboxPage(initialSharedCalendarId: initialSharedCalendarId),
        );
      },
    ),
    _calmRoute(
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
    _calmRoute(
      path: '/event-invite/:shareId',
      builder: (context, state) {
        final shareId = Uri.decodeComponent(state.pathParameters['shareId']!);
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: EventInviteRoutePage(shareId: shareId, extra: state.extra),
        );
      },
    ),
    _calmRoute(
      path: '/shared-flow/:shareId',
      builder: (context, state) {
        final shareId = Uri.decodeComponent(state.pathParameters['shareId']!);
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: SharedFlowRoutePage(shareId: shareId, extra: state.extra),
        );
      },
    ),
    _calmRoute(
      path: '/shared-flow/by-flow/:flowId',
      builder: (context, state) {
        final flowId = int.tryParse(state.pathParameters['flowId'] ?? '');
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: SharedFlowRoutePage(flowId: flowId),
        );
      },
    ),
    _calmRoute(
      path: '/shared-practice/:roomId',
      builder: (context, state) {
        final roomId = Uri.decodeComponent(state.pathParameters['roomId']!);
        if (roomId.trim().isEmpty) {
          return const _RouteMissingScaffold(
            message: 'This shared practice room is no longer available.',
            fallbackLocation: '/profile/me',
          );
        }
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: SharedPracticeRoomPage(roomId: roomId),
        );
      },
    ),
    _utilitySheetRoute(
      path: '/flows',
      builder: (context, state) => SessionTrackedRoute(
        location: state.uri.toString(),
        child: CalendarPage.buildFlowStudioRoutePage(routeUri: state.uri),
      ),
    ),
    _utilitySheetRoute(
      path: '/calendars',
      builder: (context, state) => SessionTrackedRoute(
        location: state.uri.toString(),
        child: CalendarPage.buildSharedCalendarsRoutePage(),
      ),
    ),
    _calmRoute(
      path: '/flows/:flowId/edit',
      builder: (context, state) {
        final flowId = int.tryParse(state.pathParameters['flowId'] ?? '');
        if (flowId == null || flowId <= 0) {
          return const _RouteMissingScaffold(
            message: 'This flow is no longer available.',
            fallbackLocation: '/',
          );
        }
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: CalendarPage.buildFlowEditorRoutePage(
            flowId: flowId,
            calendarId: state.uri.queryParameters['calendarId'],
            fallbackLocation: state.uri.queryParameters['fallback'],
          ),
        );
      },
    ),
    _calmRoute(
      path: '/profile/:userId/followers',
      builder: (context, state) {
        final userId = Uri.decodeComponent(state.pathParameters['userId']!);
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: FollowListPage(userId: userId, type: FollowListType.followers),
        );
      },
    ),
    _calmRoute(
      path: '/profile/:userId/following',
      builder: (context, state) {
        final userId = Uri.decodeComponent(state.pathParameters['userId']!);
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: FollowListPage(userId: userId, type: FollowListType.following),
        );
      },
    ),
    _calmRoute(
      path: '/profile/me/edit',
      builder: (context, state) => SessionTrackedRoute(
        location: state.uri.toString(),
        child: EditProfileRoutePage(
          requireCompletion:
              state.uri.queryParameters['requireCompletion'] == '1',
          onboardingMode: state.uri.queryParameters['onboarding'] == '1',
        ),
      ),
    ),
    _calmRoute(
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
    _calmRoute(
      path: '/profile/flow-post-picker',
      builder: (context, state) => SessionTrackedRoute(
        location: state.uri.toString(),
        child: const FlowPostPickerPage(),
      ),
    ),
    _calmRoute(
      path: '/profile/insight-post-picker',
      builder: (context, state) => SessionTrackedRoute(
        location: state.uri.toString(),
        child: const InsightPostPickerPage(),
      ),
    ),
    _calmRoute(
      path: '/profile/:userId',
      builder: (context, state) {
        final rawUserId = Uri.decodeComponent(state.pathParameters['userId']!);
        final currentUserId = supabase.auth.currentUser?.id;
        NavigationTrace.instance.record(
          'profile route builder started',
          state: <String, Object?>{
            'uri': state.uri.toString(),
            'rawUserId': _navigationTraceProfileUserId(
              rawUserId,
              currentUserId,
            ),
            'currentUserIdPresent': currentUserId != null,
          },
        );
        final userId = rawUserId == 'me' ? currentUserId : rawUserId;
        NavigationTrace.instance.record(
          'profile route user resolved',
          state: <String, Object?>{
            'rawUserId': _navigationTraceProfileUserId(
              rawUserId,
              currentUserId,
            ),
            'resolvedUserId': _navigationTraceProfileUserId(
              userId,
              currentUserId,
            ),
            'hasResolvedUserId': userId != null && userId.trim().isNotEmpty,
          },
        );
        if (userId == null || userId.trim().isEmpty) {
          return const AuthGate();
        }
        NavigationTrace.instance.record(
          'profile route returning ProfilePage',
          state: <String, Object?>{
            'resolvedUserId': _navigationTraceProfileUserId(
              userId,
              currentUserId,
            ),
            'isMyProfile': currentUserId != null && currentUserId == userId,
          },
        );
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
    _calmRoute(
      path: '/insight-post/:postId',
      builder: (context, state) {
        final postId = Uri.decodeComponent(state.pathParameters['postId']!);
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: InsightPostRoutePage(postId: postId, extra: state.extra),
        );
      },
    ),
    _calmRoute(
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
    _calmRoute(
      path: '/journal',
      builder: (context, state) {
        final extra = state.extra;
        final reflectionContext = extra is CalendarReflectionContext
            ? extra
            : CalendarReflectionContext.fromQueryParameters(
                state.uri.queryParameters,
              );
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: JournalRoutePage(reflectionContext: reflectionContext),
        );
      },
    ),
    _calmRoute(
      path: '/journal/entry/:entryId',
      builder: (context, state) {
        final entryId = Uri.decodeComponent(state.pathParameters['entryId']!);
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: JournalEntryDetailPage(entryId: entryId),
        );
      },
    ),
    _calmRoute(
      path: '/nodes',
      builder: (context, state) => SessionTrackedRoute(
        location: state.uri.toString(),
        child: KemeticNodeListPage(
          initialNodeId: state.uri.queryParameters['focus'],
        ),
      ),
    ),
    _calmRoute(
      path: '/nodes/:nodeId',
      builder: (context, state) {
        final nodeId = Uri.decodeComponent(state.pathParameters['nodeId']!);
        return SessionTrackedRoute(
          location: state.uri.toString(),
          child: NodeReaderRoutePage(
            nodeId: nodeId,
            openInsightEditorOnLoad: shouldOpenInsightEditorOnLoadFromNodeRoute(
              state.uri,
            ),
          ),
        );
      },
    ),
    _calmRoute(
      path: '/reflections',
      builder: (context, state) => SessionTrackedRoute(
        location: state.uri.toString(),
        child: const DecanReflectionArchivePage(),
      ),
    ),
    _calmRoute(
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
    _calmRoute(
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
    _calmRoute(
      path: '/settings',
      builder: (context, state) => SessionTrackedRoute(
        location: state.uri.toString(),
        child: const SettingsPage(),
      ),
    ),
    _calmRoute(
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
    _calmRoute(
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
    _calmRoute(
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
    _calmRoute(
      path: '/rhythm/tracker',
      builder: (context, state) => SessionTrackedRoute(
        location: state.uri.toString(),
        child: const CommitmentTrackerPage(),
      ),
    ),
    _calmRoute(
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
    _calmRoute(
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
    _calmRoute(
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
    _calmRoute(
      path: '/rhythm/editor/custom',
      builder: (context, state) => SessionTrackedRoute(
        location: state.uri.toString(),
        child: const CustomRhythmEditorPage(),
      ),
    ),
  ],
);

/* ───────────────────────── App Widgets ───────────────────────── */

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<Uri>? _linkSub;
  AppLinks? _appLinks;
  bool _rebuildScheduled = false;
  bool _passwordRecoverySession = false;

  @override
  void initState() {
    super.initState();
    _authSub = supabase.auth.onAuthStateChange.listen(
      (data) {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          _passwordRecoverySession = true;
        } else if (data.event == AuthChangeEvent.signedOut) {
          _passwordRecoverySession = false;
        }
        _scheduleRebuild();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!kDebugMode) return;
        debugPrint('[MyApp] auth state stream failed: $error');
        debugPrint('$stackTrace');
      },
    );
    _initAuthDeepLinks();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _linkSub?.cancel();
    super.dispose();
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

  Future<void> _initAuthDeepLinks() async {
    if (kIsWeb) return;
    _appLinks = AppLinks();

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
        if (!_isBootInitialAppLinkUri(initialUri)) {
          await _handleRootAuthLink(initialUri);
        }
      }
    } catch (error, stackTrace) {
      _logRootAuthLinkError('initial app link setup', error, stackTrace);
    }

    _linkSub = _appLinks!.uriLinkStream.listen(
      (uri) {
        unawaited(_handleRootAuthLink(uri));
      },
      onError: (Object error, StackTrace stackTrace) {
        _logRootAuthLinkError('app link stream', error, stackTrace);
      },
    );
  }

  Future<void> _handleRootAuthLink(Uri uri) async {
    final intent = AppLinkIntent.parse(uri);
    if (intent is! AuthAppLinkIntent) return;
    final exchanged = await _exchangeAuthCallbackUri(intent.uri);
    if (exchanged) _scheduleRebuild();
  }

  void _logRootAuthLinkError(
    String scope,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!kDebugMode) return;
    debugPrint('[MyApp] $scope failed: $error');
    debugPrint('$stackTrace');
  }

  MediaQuery _scaledMediaQuery({
    required BuildContext context,
    required Widget child,
  }) {
    final mq = MediaQuery.of(context);
    final isTablet = mq.size.shortestSide >= 600;
    final baseTextScaleFactor = mq.textScaler.scale(16) / 16;
    final textScaler = isTablet
        ? TextScaler.linear(baseTextScaleFactor * 1.5)
        : mq.textScaler;
    return MediaQuery(
      data: mq.copyWith(textScaler: textScaler),
      child: child,
    );
  }

  Widget _buildLoginApp() {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      builder: (context, child) {
        return NavigationTraceOverlay(
          child: _scaledMediaQuery(
            context: context,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: Builder(
        builder: (context) =>
            LoginScreen(onGoogleSignIn: () => _startGoogleSignIn(context)),
      ),
    );
  }

  Widget _buildPasswordRecoveryApp() {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      builder: (context, child) {
        return NavigationTraceOverlay(
          child: _scaledMediaQuery(
            context: context,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: PasswordRecoveryScreen(
        onPasswordUpdated: () async {
          _passwordRecoverySession = false;
          _scheduleRebuild();
        },
        onCancel: () async {
          _passwordRecoverySession = false;
          await supabase.auth.signOut();
          _scheduleRebuild();
        },
      ),
    );
  }

  Widget _buildAuthedApp() {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      // Keep Flutter's implicit route restoration off. AppRestorationService
      // restores calendar/page state without turning saved pages into launch
      // commands.
      theme: AppTheme.dark,
      routerConfig: _router,
      builder: (context, child) {
        return NavigationTraceOverlay(
          child: _scaledMediaQuery(
            context: context,
            child: SessionLifecycleBridge(
              child: PushIntentBridge(
                child: _AppChrome(
                  router: _router,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_debugDaySheetSmokeBootRequested) {
      return _buildAuthedApp();
    }

    final signedIn = supabase.auth.currentSession != null;
    if (signedIn && _passwordRecoverySession) {
      return _buildPasswordRecoveryApp();
    }
    return signedIn ? _buildAuthedApp() : _buildLoginApp();
  }
}

class _AppChrome extends StatefulWidget {
  const _AppChrome({required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  State<_AppChrome> createState() => _AppChromeState();
}

class _AppChromeState extends State<_AppChrome> {
  StreamSubscription<AuthState>? _authSub;
  bool _rebuildScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_handleRouteOrAuthChanged);
    _authSub = supabase.auth.onAuthStateChange.listen((_) {
      _handleRouteOrAuthChanged();
    });
  }

  @override
  void didUpdateWidget(covariant _AppChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router == widget.router) return;
    oldWidget.router.routerDelegate.removeListener(_handleRouteOrAuthChanged);
    widget.router.routerDelegate.addListener(_handleRouteOrAuthChanged);
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_handleRouteOrAuthChanged);
    unawaited(_authSub?.cancel());
    super.dispose();
  }

  void _handleRouteOrAuthChanged() {
    if (!mounted || _rebuildScheduled) return;
    _rebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (supabase.auth.currentSession == null) {
      return widget.child;
    }

    return GuidedOnboardingOverlayHost(
      child: _LaunchShell(
        child: _GlobalFloatingMenuShell(
          router: widget.router,
          child: KemeticKeyboardHost(child: widget.child),
        ),
      ),
    );
  }
}

@visibleForTesting
Widget buildGlobalFloatingMenuShellForTesting({
  required GoRouter router,
  required Widget child,
  String? dailyCosmicContextUserId,
  bool dailyCosmicContextAuthenticated = false,
  bool? dailyCosmicContextOnboardingComplete,
  DateTime Function()? dailyCosmicContextNow,
}) {
  _debugForceGlobalFloatingMenuForTesting = true;
  _launchOverlayDismissed.value = true;
  return _GlobalFloatingMenuShell(
    router: router,
    dailyCosmicContextUserIdForTesting: dailyCosmicContextUserId,
    dailyCosmicContextAuthenticatedForTesting: dailyCosmicContextAuthenticated,
    dailyCosmicContextOnboardingCompleteForTesting:
        dailyCosmicContextOnboardingComplete,
    dailyCosmicContextNowForTesting: dailyCosmicContextNow,
    child: KemeticKeyboardHost(child: child),
  );
}

@visibleForTesting
void resetGlobalFloatingMenuShellForTesting() {
  _debugForceGlobalFloatingMenuForTesting = false;
  _launchOverlayDismissed.value = false;
  _floatingMenuModalDepth.value = 0;
}

class _GlobalFloatingMenuShell extends StatefulWidget {
  const _GlobalFloatingMenuShell({
    required this.router,
    required this.child,
    this.dailyCosmicContextUserIdForTesting,
    this.dailyCosmicContextAuthenticatedForTesting = false,
    this.dailyCosmicContextOnboardingCompleteForTesting,
    this.dailyCosmicContextNowForTesting,
  });

  final GoRouter router;
  final Widget child;
  final String? dailyCosmicContextUserIdForTesting;
  final bool dailyCosmicContextAuthenticatedForTesting;
  final bool? dailyCosmicContextOnboardingCompleteForTesting;
  final DateTime Function()? dailyCosmicContextNowForTesting;

  @override
  State<_GlobalFloatingMenuShell> createState() =>
      _GlobalFloatingMenuShellState();
}

class _GlobalFloatingMenuShellState extends State<_GlobalFloatingMenuShell>
    with WidgetsBindingObserver {
  late final MaatGuidanceController _maatGuidanceController =
      MaatGuidanceController(MaatGuidanceRepo(supabase));
  late final DailyCosmicContextController _dailyCosmicContextController =
      DailyCosmicContextController(now: widget.dailyCosmicContextNowForTesting);
  Uri _currentUri = Uri(path: '/');
  StreamSubscription<AuthState>? _authSub;
  bool _menuMounted = false;
  bool _menuOpen = false;
  bool _drawerBackGestureActive = false;
  bool _drawerBackPopRouteConsumePending = false;
  Timer? _drawerBackPopRouteConsumeTimer;
  bool _rebuildScheduled = false;
  bool? _lastGuidanceSuppressed;
  int _dailyCosmicContextEvaluationSerial = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUri = _readRouterUri();
    widget.router.routerDelegate.addListener(_handleRouteChanged);
    widget.router.routeInformationProvider.addListener(_handleRouteChanged);
    _floatingMenuModalDepth.addListener(_handleMenuVisibilityChanged);
    _launchOverlayDismissed.addListener(_handleMenuVisibilityChanged);
    _maatGuidancePostEnsureRefresh.addListener(
      _handleMaatGuidancePostEnsureRefresh,
    );
    _maatGuidanceController.addListener(_scheduleRebuild);
    _dailyCosmicContextController.addListener(_scheduleRebuild);
    _shellBackChannel.setMethodCallHandler(_handleShellBackMethodCall);
    GuidedOnboardingController.instance.addListener(
      _handleExternalOverlayGateChanged,
    );
    _authSub = supabase.auth.onAuthStateChange.listen((_) {
      if (supabase.auth.currentSession == null) {
        _resetFloatingMenuState();
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
      _scheduleDailyCosmicContextEvaluation();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleDailyCosmicContextEvaluation();
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
    _scheduleDailyCosmicContextEvaluation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.router.routerDelegate.removeListener(_handleRouteChanged);
    widget.router.routeInformationProvider.removeListener(_handleRouteChanged);
    _floatingMenuModalDepth.removeListener(_handleMenuVisibilityChanged);
    _launchOverlayDismissed.removeListener(_handleMenuVisibilityChanged);
    _maatGuidancePostEnsureRefresh.removeListener(
      _handleMaatGuidancePostEnsureRefresh,
    );
    _maatGuidanceController.removeListener(_scheduleRebuild);
    _dailyCosmicContextController.removeListener(_scheduleRebuild);
    _shellBackChannel.setMethodCallHandler(null);
    GuidedOnboardingController.instance.removeListener(
      _handleExternalOverlayGateChanged,
    );
    _maatGuidanceController.dispose();
    _dailyCosmicContextController.dispose();
    _drawerBackPopRouteConsumeTimer?.cancel();
    unawaited(_authSub?.cancel());
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() => _handleBackButton();

  Future<Object?> _handleShellBackMethodCall(MethodCall call) async {
    if (call.method != 'handleAndroidBack') {
      throw MissingPluginException('No shell back handler for ${call.method}');
    }
    return _handleAndroidBackButton();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (!(_menuMounted && _menuOpen)) return false;
    _drawerBackGestureActive = true;
    return true;
  }

  @override
  void handleCommitBackGesture() {
    if (!_drawerBackGestureActive) return;
    _drawerBackGestureActive = false;
    _consumeNextPopRouteAfterDrawerBackGesture();
    unawaited(_closeFloatingMenu());
  }

  @override
  void handleCancelBackGesture() {
    _drawerBackGestureActive = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_dailyCosmicContextAuthenticated) {
      _scheduleDailyCosmicContextEvaluation();
    }
    if (supabase.auth.currentSession == null) return;
    unawaited(_maatGuidanceController.evaluateAndRefresh());
  }

  void _handleMaatGuidancePostEnsureRefresh() {
    if (supabase.auth.currentSession == null) return;
    unawaited(_maatGuidanceController.refresh(force: true));
  }

  Uri _readRouterUri() {
    final configuration = widget.router.routerDelegate.currentConfiguration;
    final topMatch = configuration.lastOrNull;
    if (topMatch is ImperativeRouteMatch) return topMatch.matches.uri;
    final delegateUri = configuration.uri;
    if (delegateUri.path.isNotEmpty) return delegateUri;
    return widget.router.routeInformationProvider.value.uri;
  }

  void _handleRouteChanged() {
    final nextUri = _readRouterUri();
    if (nextUri == _currentUri) return;
    _currentUri = nextUri;
    final navContext = _rootNavigatorKey.currentContext ?? context;
    unawaited(
      CalendarPage.dismissAppOwnedTransientOverlaysForRouteChange(navContext),
    );
    if (!_menuMounted || _menuOpen) {
      _resetFloatingMenuState();
    }
    unawaited(_maatGuidanceController.refresh());
    _scheduleDailyCosmicContextEvaluation();
    _scheduleRebuild();
  }

  void _handleMenuVisibilityChanged() {
    if ((!_shouldActivateFloatingMenu(context) ||
            _floatingMenuModalDepth.value > 0) &&
        _menuMounted) {
      _resetFloatingMenuState();
    }
    _scheduleDailyCosmicContextEvaluation();
    _scheduleRebuild();
  }

  void _handleExternalOverlayGateChanged() {
    _scheduleDailyCosmicContextEvaluation();
    _scheduleRebuild();
  }

  void _resetFloatingMenuState() {
    _drawerBackGestureActive = false;
    _drawerBackPopRouteConsumePending = false;
    _drawerBackPopRouteConsumeTimer?.cancel();
    _drawerBackPopRouteConsumeTimer = null;
    _menuMounted = false;
    _menuOpen = false;
  }

  void _consumeNextPopRouteAfterDrawerBackGesture() {
    _drawerBackPopRouteConsumePending = true;
    _drawerBackPopRouteConsumeTimer?.cancel();
    _drawerBackPopRouteConsumeTimer = Timer(
      globalSideDrawerTransitionDuration + const Duration(milliseconds: 250),
      () {
        _drawerBackPopRouteConsumePending = false;
        _drawerBackPopRouteConsumeTimer = null;
      },
    );
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
    if (GuidedOnboardingController.instance.suppressExternalOverlays) {
      return false;
    }
    if (supabase.auth.currentSession == null &&
        !(kDebugMode &&
            (_debugForceGlobalFloatingMenu ||
                _debugForceGlobalFloatingMenuForTesting))) {
      return false;
    }
    return true;
  }

  bool get _shouldSuppressFloatingMenuForCurrentRoute {
    if (_currentUri.queryParameters['onboarding'] == '1') return true;
    final path = _currentUri.path.isEmpty ? '/' : _currentUri.path;
    return path == '/calendars';
  }

  bool _shouldActivateFloatingMenu(BuildContext context) =>
      _shouldMountFloatingMenu &&
      !_shouldSuppressFloatingMenuForCurrentRoute &&
      _floatingMenuModalDepth.value == 0 &&
      MediaQuery.viewInsetsOf(context).bottom == 0;

  bool get _dailyCosmicContextAuthenticated {
    if (supabase.auth.currentSession != null) return true;
    return kDebugMode && widget.dailyCosmicContextAuthenticatedForTesting;
  }

  String? get _dailyCosmicContextUserId {
    final currentUserId = supabase.auth.currentUser?.id.trim();
    if (currentUserId != null && currentUserId.isNotEmpty) {
      return currentUserId;
    }
    if (kDebugMode) return widget.dailyCosmicContextUserIdForTesting?.trim();
    return null;
  }

  bool _shouldSuppressDailyCosmicContext(BuildContext context) {
    if (!_launchOverlayDismissed.value) return true;
    if (!_dailyCosmicContextAuthenticated) return true;
    if (_floatingMenuModalDepth.value > 0) return true;
    if (_menuMounted || _menuOpen) return true;
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return true;
    if (GuidedOnboardingController.instance.suppressExternalOverlays) {
      return true;
    }
    if (isDailyCosmicContextRouteSuppressed(_currentUri)) return true;
    return false;
  }

  void _scheduleDailyCosmicContextEvaluation() {
    final serial = ++_dailyCosmicContextEvaluationSerial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || serial != _dailyCosmicContextEvaluationSerial) return;
      unawaited(_evaluateDailyCosmicContext(serial));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _evaluateDailyCosmicContext(int serial) async {
    final isAuthenticated = _dailyCosmicContextAuthenticated;
    final userId = _dailyCosmicContextUserId;
    final suppressed = _shouldSuppressDailyCosmicContext(context);
    final onboardingComplete =
        isAuthenticated && userId != null && userId.isNotEmpty && !suppressed
        ? await _dailyCosmicContextOnboardingComplete(userId)
        : false;
    if (!mounted || serial != _dailyCosmicContextEvaluationSerial) return;
    await _dailyCosmicContextController.evaluate(
      userId: userId,
      isAuthenticated: isAuthenticated,
      onboardingComplete: onboardingComplete,
      suppressed: suppressed,
    );
  }

  Future<bool> _dailyCosmicContextOnboardingComplete(String userId) async {
    final testingOverride =
        widget.dailyCosmicContextOnboardingCompleteForTesting;
    if (kDebugMode && testingOverride != null) return testingOverride;

    try {
      final progress = await OnboardingProgressStorage().loadLocal(userId);
      if (progress.completedOnboarding) return true;
      return OnboardingStorage(supabase).isCompletedLocally(userId);
    } catch (_) {
      return false;
    }
  }

  void _resetFloatingMenuStateAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_menuMounted) return;
      setState(_resetFloatingMenuState);
    });
  }

  bool _shouldSuppressMaatGuidance(BuildContext context) {
    if (!_launchOverlayDismissed.value) return true;
    if (supabase.auth.currentSession == null) return true;
    if (_dailyCosmicContextController.hasVisibleBadge) return true;
    if (_floatingMenuModalDepth.value > 0) return true;
    if (_menuMounted || _menuOpen) return true;
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return true;
    if (GuidedOnboardingController.instance.suppressExternalOverlays) {
      return true;
    }

    final path = _currentUri.path;
    if (_currentUri.queryParameters['onboarding'] == '1') return true;
    if (path.startsWith('/maat-guidance/')) return true;
    if (path.startsWith('/rhythm/editor/')) return true;
    return false;
  }

  String _traceRouteLabel() {
    final path = _currentUri.path.isEmpty ? '/' : _currentUri.path;
    final queryKeys =
        _currentUri.queryParameters.keys
            .where((key) => key.trim().isNotEmpty)
            .toList(growable: false)
          ..sort();
    if (queryKeys.isEmpty) return path;
    return '$path?${queryKeys.map((key) => '$key=<redacted>').join('&')}';
  }

  Map<String, Object?> _traceOverlayState({BuildContext? mediaContext}) {
    final mediaQuery = mediaContext == null
        ? null
        : MediaQuery.maybeOf(mediaContext);
    return <String, Object?>{
      '_menuMounted': _menuMounted,
      '_menuOpen': _menuOpen,
      '_floatingMenuModalDepth.value': _floatingMenuModalDepth.value,
      '_launchOverlayDismissed.value': _launchOverlayDismissed.value,
      'route': _traceRouteLabel(),
      'MediaQuery.viewInsets.bottom': mediaQuery?.viewInsets.bottom,
    };
  }

  void _traceNavigation(
    String label, {
    BuildContext? mediaContext,
    Map<String, Object?> state = const <String, Object?>{},
  }) {
    NavigationTrace.instance.record(
      label,
      state: <String, Object?>{
        ..._traceOverlayState(mediaContext: mediaContext),
        ...state,
      },
    );
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
    _traceNavigation('global drawer bubble tapped', mediaContext: context);
    if (_menuOpen) {
      unawaited(_closeFloatingMenu());
      return;
    }
    _openFloatingMenu();
  }

  void _openFloatingMenu() {
    if (!_shouldActivateFloatingMenu(context)) {
      _traceNavigation('global drawer open blocked', mediaContext: context);
      return;
    }
    setState(() {
      _menuMounted = true;
      _menuOpen = true;
    });
    _traceNavigation('global drawer mounted/opened', mediaContext: context);
  }

  Future<void> _closeFloatingMenu() async {
    if (!_menuMounted) return;
    _traceNavigation('menu close started', mediaContext: context);
    setState(() => _menuOpen = false);
    await Future<void>.delayed(globalSideDrawerTransitionDuration);
    if (!mounted || _menuOpen) return;
    setState(() => _menuMounted = false);
    _traceNavigation('menu close completed', mediaContext: context);
  }

  Future<void> _openPrimarySectionFromDrawer(AppSection section) {
    unawaited(_closeFloatingMenu());
    openPrimarySection(context, section, router: widget.router);
    return Future<void>.value();
  }

  Future<void> _openProfileFromDrawer() {
    _traceNavigation(
      '_openProfileFromDrawer entered',
      mediaContext: context,
      state: const <String, Object?>{'route': '/profile/me'},
    );
    unawaited(_closeFloatingMenu());
    if (!mounted) return Future<void>.value();
    final navigationContext = _rootNavigatorKey.currentContext ?? context;
    if (!navigationContext.mounted) return Future<void>.value();
    _traceNavigation(
      "global drawer detail route push('/profile/me') requested",
      mediaContext: context,
      state: const <String, Object?>{'route': '/profile/me'},
    );
    unawaited(
      openDetailRoute<void>(
        navigationContext,
        '/profile/me',
        router: widget.router,
      ),
    );
    return Future<void>.value();
  }

  Future<void> _openFlowsFromDrawer() {
    _traceNavigation(
      '_openFlowsFromDrawer entered',
      mediaContext: context,
      state: const <String, Object?>{'route': '/flows'},
    );
    unawaited(_closeFloatingMenu());
    if (!mounted) return Future<void>.value();
    _traceNavigation(
      "global drawer utility route push('/flows') requested",
      mediaContext: context,
      state: const <String, Object?>{'route': '/flows'},
    );
    unawaited(
      openUtilityRoute<void>(
        context,
        '/flows',
        navigationContext: _rootNavigatorKey.currentContext,
        router: widget.router,
      ),
    );
    return Future<void>.value();
  }

  Future<void> _openCalendarsFromDrawer() {
    _traceNavigation(
      '_openCalendarsFromDrawer entered',
      mediaContext: context,
      state: const <String, Object?>{'route': '/calendars'},
    );
    unawaited(_closeFloatingMenu());
    if (!mounted) return Future<void>.value();
    _traceNavigation(
      "global drawer utility route push('/calendars') requested",
      mediaContext: context,
      state: const <String, Object?>{'route': '/calendars'},
    );
    unawaited(
      openUtilityRoute<void>(
        context,
        '/calendars',
        navigationContext: _rootNavigatorKey.currentContext,
        router: widget.router,
      ),
    );
    return Future<void>.value();
  }

  bool _isDrawerDestinationSelected(String destination) {
    final path = _currentUri.path.isEmpty ? '/' : _currentUri.path;
    return switch (destination) {
      '/' => path == '/',
      '/rhythm/today' => path.startsWith('/rhythm/'),
      '/nodes' => path == '/nodes' || path.startsWith('/nodes/'),
      '/journal' => path == '/journal' || path.startsWith('/journal/'),
      '/inbox' => path == '/inbox' || path.startsWith('/inbox/'),
      '/calendars' => path == '/calendars',
      '/flows' => path == '/flows' || path.startsWith('/flows/'),
      '/reflections' =>
        path == '/reflections' || path.startsWith('/reflections/'),
      '/profile/me' => path == '/profile/me' || path.startsWith('/profile/'),
      '/settings' => path == '/settings',
      _ => false,
    };
  }

  List<GlobalSideDrawerItem> _buildGlobalSideDrawerItems() {
    return <GlobalSideDrawerItem>[
      GlobalSideDrawerItem(
        label: 'Calendar',
        glyph: MeduNeterGlyphs.home,
        selected: _isDrawerDestinationSelected('/'),
        onSelected: () =>
            unawaited(_openPrimarySectionFromDrawer(AppSection.calendar)),
      ),
      GlobalSideDrawerItem(
        label: 'Planner',
        glyph: MeduNeterGlyphs.planner,
        selected: _isDrawerDestinationSelected('/rhythm/today'),
        onSelected: () =>
            unawaited(_openPrimarySectionFromDrawer(AppSection.planner)),
      ),
      GlobalSideDrawerItem(
        label: 'Library',
        glyph: MeduNeterGlyphs.library,
        glyphSize: 20,
        selected: _isDrawerDestinationSelected('/nodes'),
        onSelected: () =>
            unawaited(_openPrimarySectionFromDrawer(AppSection.library)),
      ),
      GlobalSideDrawerItem(
        label: 'Journal',
        glyph: MeduNeterGlyphs.journal,
        selected: _isDrawerDestinationSelected('/journal'),
        onSelected: () =>
            unawaited(_openPrimarySectionFromDrawer(AppSection.journal)),
      ),
      GlobalSideDrawerItem(
        label: 'Inbox',
        glyph: MeduNeterGlyphs.inbox,
        showNotificationDot: true,
        selected: _isDrawerDestinationSelected('/inbox'),
        onSelected: () =>
            unawaited(_openPrimarySectionFromDrawer(AppSection.inbox)),
      ),
      GlobalSideDrawerItem(
        label: 'Calendars',
        glyph: MeduNeterGlyphs.calendars,
        selected: _isDrawerDestinationSelected('/calendars'),
        onSelected: () => unawaited(_openCalendarsFromDrawer()),
      ),
      GlobalSideDrawerItem(
        label: 'Flows',
        glyph: MeduNeterGlyphs.flowStudio,
        glyphSize: 20,
        selected: _isDrawerDestinationSelected('/flows'),
        onSelected: () => unawaited(_openFlowsFromDrawer()),
      ),
      GlobalSideDrawerItem(
        label: 'Reflections',
        glyph: MeduNeterGlyphs.reflections,
        glyphSize: 18,
        selected: _isDrawerDestinationSelected('/reflections'),
        onSelected: () =>
            unawaited(_openPrimarySectionFromDrawer(AppSection.reflections)),
      ),
      GlobalSideDrawerItem(
        label: 'Profile',
        glyph: MeduNeterGlyphs.profile,
        selected: _isDrawerDestinationSelected('/profile/me'),
        onSelected: () => unawaited(_openProfileFromDrawer()),
      ),
      GlobalSideDrawerItem(
        label: 'Settings',
        glyph: MeduNeterGlyphs.settings,
        selected: _isDrawerDestinationSelected('/settings'),
        onSelected: () =>
            unawaited(_openPrimarySectionFromDrawer(AppSection.settings)),
      ),
    ];
  }

  void _openMaatGuidance(MaatGuidanceDelivery delivery) {
    _router.go('/maat-guidance/${Uri.encodeComponent(delivery.id)}');
  }

  bool get _isDrawerBackToggleRoute {
    final path = _currentUri.path.isEmpty ? '/' : _currentUri.path;
    return switch (path) {
      '/' ||
      '/rhythm/today' ||
      '/nodes' ||
      '/journal' ||
      '/inbox' ||
      '/settings' ||
      '/reflections' => true,
      _ => false,
    };
  }

  bool _shouldOpenDrawerForBack(BuildContext context) {
    return _isDrawerBackToggleRoute && _shouldActivateFloatingMenu(context);
  }

  Future<bool> _handleBackButton() async {
    if (_drawerBackPopRouteConsumePending) {
      _drawerBackPopRouteConsumePending = false;
      _drawerBackPopRouteConsumeTimer?.cancel();
      _drawerBackPopRouteConsumeTimer = null;
      return true;
    }
    if (_dailyCosmicContextController.hasVisibleBadge) {
      await _dailyCosmicContextController.dismiss();
      return true;
    }
    if (_menuMounted && _menuOpen) {
      await _closeFloatingMenu();
      return true;
    }
    if (_shouldOpenDrawerForBack(context)) {
      _openFloatingMenu();
      return true;
    }
    return false;
  }

  Future<bool> _handleAndroidBackButton() async {
    if (_drawerBackPopRouteConsumePending) {
      _drawerBackPopRouteConsumePending = false;
      _drawerBackPopRouteConsumeTimer?.cancel();
      _drawerBackPopRouteConsumeTimer = null;
      return true;
    }
    if (_dailyCosmicContextController.hasVisibleBadge) {
      await _dailyCosmicContextController.dismiss();
      return true;
    }
    if (_menuMounted && _menuOpen) {
      await _closeFloatingMenu();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final shouldMountFloatingMenu = _shouldMountFloatingMenu;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final shouldActivateFloatingMenu = _shouldActivateFloatingMenu(context);
    if (keyboardVisible && _menuMounted) {
      _resetFloatingMenuStateAfterFrame();
    }
    final menuOpenForInteraction = _menuOpen && shouldActivateFloatingMenu;
    final suppressGuidance = _shouldSuppressMaatGuidance(context);
    _syncMaatGuidanceSuppression(suppressGuidance);

    return MaatGuidanceScope(
      controller: _maatGuidanceController,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (shouldMountFloatingMenu && _menuMounted)
            Positioned.fill(
              child: GlobalSideDrawer(
                open: menuOpenForInteraction,
                items: _buildGlobalSideDrawerItems(),
              ),
            ),
          GlobalSideDrawerForeground(
            open: menuOpenForInteraction,
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.child,
                if (shouldMountFloatingMenu && _menuMounted)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !menuOpenForInteraction,
                      child: ExcludeSemantics(
                        excluding: !menuOpenForInteraction,
                        child: AnimatedOpacity(
                          opacity: menuOpenForInteraction ? 1 : 0,
                          duration: globalSideDrawerTransitionDuration,
                          curve: globalSideDrawerTransitionCurve,
                          child: GestureDetector(
                            key: globalSideDrawerScrimKey,
                            behavior: HitTestBehavior.opaque,
                            onTap: () => unawaited(_closeFloatingMenu()),
                            child: const ColoredBox(color: Colors.transparent),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (shouldActivateFloatingMenu || _menuMounted)
                  GlobalMenuBubble(
                    key: globalMenuButtonKey,
                    visible: shouldActivateFloatingMenu,
                    open: menuOpenForInteraction,
                    onPressed: _handleFloatingMenuPressed,
                  ),
                DailyCosmicContextOverlayHost(
                  controller: _dailyCosmicContextController,
                ),
                MaatGuidanceOverlayHost(
                  controller: _maatGuidanceController,
                  onOpen: _openMaatGuidance,
                  visible:
                      _maatGuidanceController.hasVisibleDelivery &&
                      !suppressGuidance,
                ),
              ],
            ),
          ),
        ],
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
  int? _lastHandledCalendarBusIntentNonce;

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
      runGuardedSync('web push tap bridge', () {
        unawaited(
          PushNotifications.instance(
            supabase,
          ).recordDeliveryReceiptFromPayload(data, event: 'opened'),
        );
        _queueOrHandlePushData(data);
      }, onError: _logPushBridgeError);
    });

    calendarPushOpenIntent.addListener(_handleCalendarBusIntent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleCalendarBusIntent();
      _startInitialTasks();
    });
  }

  @override
  void dispose() {
    _pushNavSub?.cancel();
    _authSub?.cancel();
    calendarPushOpenIntent.removeListener(_handleCalendarBusIntent);
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

    final bootMessage = _bootInitialPushMessage;
    if (bootMessage != null) {
      _bootInitialPushMessage = null;
      unawaited(
        PushNotifications.instance(supabase).recordDeliveryReceiptFromPayload(
          bootMessage.data,
          event: 'opened',
          messageId: bootMessage.messageId,
        ),
      );
      _queueOrHandlePushData(bootMessage.data);
    } else {
      fireAndForgetGuarded(
        'initial push message',
        PushNotifications.instance(supabase).emitInitialMessage(),
        onError: _logPushBridgeError,
      );
    }
    _consumePendingWebPushIntent();
  }

  void _consumePendingWebPushIntent() {
    if (!kIsWeb) return;
    final data = _pushIntentDataFromQuery(Uri.base.queryParameters);
    if (data == null) return;

    replaceUrlWithoutQuery();
    unawaited(
      PushNotifications.instance(
        supabase,
      ).recordDeliveryReceiptFromPayload(data, event: 'opened'),
    );
    _queueOrHandlePushData(data);
  }

  void _queueOrHandlePushData(Map<String, dynamic> rawData) {
    final data = Map<String, dynamic>.from(rawData);
    if (data.isEmpty) return;

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
    final oneShotRoute = _initialLocationFromPushData(
      data,
      hasSession: supabase.auth.currentSession != null,
    );
    if (oneShotRoute != null) {
      await AppNavigationRestorationController.instance.consumeOneShotIntent(
        PendingNavigationIntent(
          key: navigationKey,
          requestedRoute: oneShotRoute,
          source: NavigationSource.notificationTap,
        ),
      );
    }

    final handled = await _handlePushNavigation(data);
    if (!handled) {
      return;
    }

    _rememberHandledPushNavigation(navigationKey);
  }

  Future<bool> _handlePushNavigation(Map<String, dynamic> data) async {
    final deliveryKeyForKind = _trimmedValue(
      data['delivery_key'] ?? data['deliveryKey'],
    );
    final kind =
        _trimmedValue(data['kind'] ?? data['type']) ??
        (deliveryKeyForKind?.startsWith('maat_guidance:') == true
            ? 'maat_guidance'
            : null);
    final calendarIntent = CalendarPushOpenIntent.fromNotificationData(data);
    final clientEventId = _trimmedValue(
      data['client_event_id'] ?? data['clientEventId'],
    );
    if (kind == null && calendarIntent == null && clientEventId == null) {
      return false;
    }
    final shareKind = _trimmedValue(data['share_kind'] ?? data['shareKind']);

    final reflectionId = _trimmedValue(
      data['reflectionId'] ?? data['reflection_id'],
    );
    if (kind == 'maat_guidance') {
      final deliveryId = _trimmedValue(
        data['delivery_id'] ??
            data['deliveryId'] ??
            data['maat_guidance_id'] ??
            data['maatGuidanceId'],
      );
      final deliveryKey = _trimmedValue(
        data['delivery_key'] ?? data['deliveryKey'],
      );
      final keyId =
          deliveryKey != null && deliveryKey.startsWith('maat_guidance:')
          ? deliveryKey.substring('maat_guidance:'.length)
          : null;
      final id = deliveryId ?? keyId;
      if (id == null) return false;
      _router.go('/maat-guidance/${Uri.encodeComponent(id)}');
      return true;
    }
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
      final senderId = _trimmedValue(
        data['conversation_user_id'] ??
            data['conversationUserId'] ??
            data['sender_id'] ??
            data['senderId'],
      );
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

    final sharedCalendarInboxRoute =
        sharedCalendarInboxRouteLocationFromPushData(data);
    if (sharedCalendarInboxRoute != null) {
      _router.go(sharedCalendarInboxRoute);
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

    if (kind == 'shared_calendar_item_added' ||
        kind == 'calendar_event' ||
        kind == 'scheduled_notification' ||
        kind == 'reminder_10min' ||
        (clientEventId != null && kind == 'reminder') ||
        calendarIntent != null) {
      if (calendarIntent != null) {
        await _openCalendarEventFromPush(calendarIntent);
      } else if (clientEventId != null) {
        await _openCalendarEventFromPush(
          CalendarPushOpenIntent(
            clientEventId: clientEventId,
            nonce: DateTime.now().microsecondsSinceEpoch,
          ),
        );
      } else {
        _router.go('/');
      }
      return true;
    }

    if (clientEventId != null) {
      await _openCalendarEventFromPush(
        CalendarPushOpenIntent(
          clientEventId: clientEventId,
          nonce: DateTime.now().microsecondsSinceEpoch,
        ),
      );
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

  Future<void> _openCalendarEventFromPush(CalendarPushOpenIntent intent) async {
    await SessionResumeService.saveResumeEntry(
      baseRoute: '/',
      kind: _kCalendarPushResumeKind,
      payload: intent.toJson(),
    );
    emitCalendarPushOpenIntent(intent);
    _router.go('/');
  }

  void _handleCalendarBusIntent() {
    final intent = calendarPushOpenIntent.value;
    if (intent == null) return;
    if (_lastHandledCalendarBusIntentNonce == intent.nonce) return;
    _lastHandledCalendarBusIntentNonce = intent.nonce;

    unawaited(
      SessionResumeService.saveResumeEntry(
        baseRoute: '/',
        kind: _kCalendarPushResumeKind,
        payload: intent.toJson(),
      ),
    );
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
    if (supabase.auth.currentSession == null) {
      _dismissed = true;
      _launchOverlayDismissed.value = true;
      return;
    }

    _launchOverlayDismissed.value = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreDetachedCalendarOverlayAfterBoot());
      _dismissOverlay();
    });
  }

  Future<void> _restoreDetachedCalendarOverlayAfterBoot() async {
    if (supabase.auth.currentSession == null) return;
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
    if (supabase.auth.currentSession == null) {
      if (!mounted) return;
      setState(() => _dismissed = true);
      _launchOverlayDismissed.value = true;
      return;
    }

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
  String get _fallbackLocation {
    final extra = widget.extra;
    if (extra is Map) {
      final rawFallback = extra['fallbackLocation'];
      if (rawFallback is String && rawFallback.trim().isNotEmpty) {
        final fallback = rawFallback.trim();
        return fallback;
      }
    }
    return '/inbox';
  }

  InboxShareItem? get _extraShare {
    final extra = widget.extra;
    if (extra is InboxShareItem) return extra;
    if (extra is Map) {
      final share = extra['share'];
      if (share is InboxShareItem) return share;
    }
    return null;
  }

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
    final extra = _extraShare;
    if (extra != null &&
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
      return SharedFlowDetailsPage(
        flowId: flowId,
        fallbackLocation: _fallbackLocation,
      );
    }
    return FutureBuilder<InboxShareItem?>(
      future: _future,
      builder: (context, snapshot) {
        final share = snapshot.data;
        if (share != null && share.isFlow) {
          return SharedFlowDetailsEntry(
            share: share,
            fallbackLocation: _fallbackLocation,
          );
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return _RouteMissingScaffold(
            message: 'This shared flow is no longer available.',
            fallbackLocation: _fallbackLocation,
          );
        }
        return const _RouteLoadingScaffold();
      },
    );
  }
}

class EditProfileRoutePage extends StatefulWidget {
  const EditProfileRoutePage({
    super.key,
    this.requireCompletion = false,
    this.onboardingMode = false,
  });

  final bool requireCompletion;
  final bool onboardingMode;

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
            onboardingMode: widget.onboardingMode,
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
  const JournalRoutePage({
    super.key,
    this.controllerForTesting,
    this.reflectionContext,
  });

  @visibleForTesting
  final JournalController? controllerForTesting;
  final CalendarReflectionContext? reflectionContext;

  @override
  State<JournalRoutePage> createState() => _JournalRoutePageState();
}

class _JournalRoutePageState extends State<JournalRoutePage>
    with WidgetsBindingObserver {
  late final JournalController _controller =
      widget.controllerForTesting ?? JournalController(supabase);
  late final Future<void> _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _initializeJournalRoute();
  }

  Future<void> _initializeJournalRoute() async {
    await _controller.init();
    final reflectionContext = widget.reflectionContext;
    if (reflectionContext == null) return;
    await _controller.loadDate(reflectionContext.calendarDate);
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
            reflectionContext: widget.reflectionContext,
          );
        }
        return const _RouteLoadingScaffold();
      },
    );
  }
}

class NodeReaderRoutePage extends StatefulWidget {
  const NodeReaderRoutePage({
    super.key,
    required this.nodeId,
    this.openInsightEditorOnLoad = false,
  });

  final String nodeId;
  final bool openInsightEditorOnLoad;

  @override
  State<NodeReaderRoutePage> createState() => _NodeReaderRoutePageState();
}

class _NodeReaderRoutePageState extends State<NodeReaderRoutePage> {
  bool _pendingInsightEditorIntent = false;
  String? _pendingInsightEditorNodeId;

  @override
  void initState() {
    super.initState();
    _captureInsightEditorIntentIfNeeded();
  }

  @override
  void didUpdateWidget(covariant NodeReaderRoutePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodeId != widget.nodeId) {
      _pendingInsightEditorIntent = false;
      _pendingInsightEditorNodeId = null;
    }
    _captureInsightEditorIntentIfNeeded();
  }

  void _captureInsightEditorIntentIfNeeded() {
    if (!widget.openInsightEditorOnLoad) return;
    _pendingInsightEditorIntent = true;
    _pendingInsightEditorNodeId = widget.nodeId;
  }

  bool get _shouldOpenInsightEditorOnLoad =>
      _pendingInsightEditorIntent &&
      _pendingInsightEditorNodeId == widget.nodeId;

  void _consumeInsightEditorIntent() {
    if (!_shouldOpenInsightEditorOnLoad) return;
    setState(() {
      _pendingInsightEditorIntent = false;
      _pendingInsightEditorNodeId = null;
    });
    final stableLocation = '/nodes/${Uri.encodeComponent(widget.nodeId)}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GoRouter.of(context).replace(stableLocation);
    });
  }

  @override
  Widget build(BuildContext context) {
    final node = KemeticNodeLibrary.resolve(widget.nodeId);
    if (node == null) {
      return const _RouteMissingScaffold(
        message: 'This library entry is no longer available.',
        fallbackLocation: '/nodes',
      );
    }
    return KemeticNodeReaderPage(
      node: node,
      openInsightEditorOnLoad: _shouldOpenInsightEditorOnLoad,
      onInsightEditorIntentConsumed: _consumeInsightEditorIntent,
    );
  }
}

@visibleForTesting
bool shouldOpenInsightEditorOnLoadFromNodeRoute(Uri uri) {
  final action = uri.queryParameters['action'];
  final legacyInsight = uri.queryParameters['insight'];
  return action == 'add_insight' || legacyInsight == 'new';
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
    onMaatGuidanceEnsured: () {
      _maatGuidancePostEnsureRefresh.value += 1;
    },
  );
  bool _scheduledDecans = false;

  // One-shot guards
  bool _appOpenLogged = false;
  bool _notifyInitInProgress = false;
  bool _notifyInitialized = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_authDeferredRestorePending) return;
      final session = supabase.auth.currentSession;
      if (session == null) return;
      unawaited(
        runGuardedAsync(
          'auth deferred restore current session',
          () => _handleAuthStateChange(
            AuthState(AuthChangeEvent.initialSession, session),
          ),
          onError: _logAuthGateError,
        ),
      );
    });
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

  void _startPostAuthStartupWarmups() {
    fireAndForgetGuarded(
      'ensure profile',
      _ensureProfile(),
      onError: _logAuthGateError,
    );
    fireAndForgetGuarded(
      'telemetry settings refresh',
      UserEventsRepo.refreshTelemetrySettings(supabase),
      onError: _logAuthGateError,
    );
    fireAndForgetGuarded(
      'app open log',
      _logAppOpenOnce(),
      onError: _logAuthGateError,
    );
  }

  Future<void> _handleAuthStateChange(AuthState data) async {
    final ev = data.event;
    final isSessionReadyEvent =
        ev == AuthChangeEvent.initialSession || ev == AuthChangeEvent.signedIn;
    if (isSessionReadyEvent) {
      _prepareDeferredBootRestoreForAuth(ev);
    }
    if (!isSessionReadyEvent && mounted) setState(() {});

    if (isSessionReadyEvent) {
      Events.debugAuthBanner('onAuthStateChange:$ev');
      final shouldReplayBeforeStartup =
          _authDeferredRestorePending || _bootDeferredRestorePreparedForAuth;
      final pendingPlannerLaunch = _pendingPlannerLaunchIntent;
      if (pendingPlannerLaunch != null) {
        _pendingPlannerLaunchIntent = null;
        _bootRestoreDeferredForAuth = false;
        _bootAuthDeferredRestoredLocation = null;
        _bootDeferredRestorePreparedForAuth = false;
        traceRestoration(
          'auth deferred restore skipped event=${ev.name} '
          'reason=pending_planner_launch_intent',
        );
        _routeToPlanner(pendingPlannerLaunch);
      } else {
        await _replayDeferredBootRestoreAfterAuth(ev);
      }
      if (mounted) setState(() {});
      if (shouldReplayBeforeStartup) {
        _startPostAuthStartupWarmups();
      } else {
        await _ensureProfile(); // keep profiles hydrated with email
        await UserEventsRepo.refreshTelemetrySettings(supabase);
        await _logAppOpenOnce(); // one-shot per cold start
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
      _bootRestoreDeferredForAuth = false;
      _bootAuthDeferredRestoredLocation = null;
      _bootDeferredRestorePreparedForAuth = false;
      await AppRestorationService.instance.clearBootFallbackIdentity();
      _router.go('/');
      _calendarSync?.stop();
      fireAndForgetGuarded(
        'push unregister',
        PushNotifications.instance(supabase).unregister(),
        onError: _logAuthGateError,
      );
    }
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
        if (!_isBootInitialAppLinkUri(initialUri)) {
          await runGuardedAsync(
            'initial app link',
            () => _handleIncomingAppLink(initialUri!),
            onError: _logAuthGateError,
          );
        }
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

    final signature = _appLinkIntentSignature(intent, uri);

    if (_shouldSkipDuplicateLink(signature)) {
      return;
    }
    final oneShotRoute = _initialLocationFromAppLinkIntent(intent) ?? '/';
    unawaited(
      AppNavigationRestorationController.instance.consumeOneShotIntent(
        PendingNavigationIntent(
          key: signature,
          requestedRoute: oneShotRoute,
          source: intent is AuthAppLinkIntent
              ? NavigationSource.authCallback
              : NavigationSource.appLink,
        ),
      ),
    );

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
    final exchanged = await _exchangeAuthCallbackUri(uri);
    if (exchanged && mounted) setState(() {});
  }

  void _routeToSharedFlow(ShareAppLinkIntent intent) {
    final location = intent.routeLocation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _router.go(location);
    });
  }

  void _routeToPlanner(PlannerLaunchIntent intent) {
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
    await _startGoogleSignIn(context);
  }

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;
    traceRestoration(
      'auth gate build session=${session == null ? 'signed_out' : 'signed_in'}',
    );

    if (session == null) {
      return LoginScreen(onGoogleSignIn: _signInWithGoogle);
    }

    if (_authDeferredRestorePending) {
      traceRestoration('launch restoration shell shown');
      return const _RouteLoadingScaffold();
    }

    // Authenticated
    return Scaffold(
      body: SessionTrackedRoute(
        location: '/',
        // Main calendar uses infinite scroll and intentionally manages its own
        // bottom spacing.
        applyBottomNavInset: false,
        child: CalendarPage(),
      ),
    );
  }
}
