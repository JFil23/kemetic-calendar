// lib/main.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'package:file_picker/file_picker.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:go_router/go_router.dart';

import 'data/user_events_repo.dart';
import 'features/calendar/notify.dart';
import 'features/calendar/calendar_page.dart';
import 'features/calendar/ics_preview_card.dart';
import 'utils/ics_parser.dart';
import 'core/kemetic_converter.dart';
import 'features/sharing/share_preview_page.dart';
import 'features/inbox/inbox_page.dart';

import 'utils/hive_local_storage_web.dart';
import 'core/theme/app_theme.dart';

// Conditional import: on web we use URL cleanup + visibility hook; elsewhere no-ops.
import 'utils/web_history.dart'
if (dart.library.html) 'utils/web_history_web.dart';

// ---- Supabase configuration via --dart-define ----
const SUPABASE_URL = String.fromEnvironment('SUPABASE_URL');
const SUPABASE_ANON_KEY = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();


  if (SUPABASE_URL.isEmpty || SUPABASE_ANON_KEY.length <= 20) {
    runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: Text('Missing Supabase configuration.'))),
    ));
    return;
  }

  await Supabase.initialize(
    url: SUPABASE_URL,
    anonKey: SUPABASE_ANON_KEY,
    authOptions: FlutterAuthClientOptions(
      autoRefreshToken: true,
      localStorage: kIsWeb ? HiveLocalStorageWeb() : null,
    ),
  );

  // 🚨 Initialize notifications
  // Ensures notification channels and platform-specific setup happen before the app builds.
  await Notify.init();

  // Web/PWA boot hardening (iOS PWA friendly)
  await _completeWebOAuthIfNeeded();   // 1) exchange ?code once
  await _rehydrateSessionOnce();       // 2) load persisted session into memory
  _installVisibilityRefresh();         // 3) refresh on foreground to stay "warm"

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

/* ───────────────────────── Helpers for web/PWA ───────────────────────── */

Future<void> _completeWebOAuthIfNeeded() async {
  if (!kIsWeb) return;

  final uri = Uri.base;
  final hasCode = uri.queryParameters.containsKey('code');
  if (!hasCode) return;

  // Exchange PKCE code -> session (persists it)
  await Supabase.instance.client.auth.exchangeCodeForSession(uri.toString());

  // Clean URL so refreshes don't re-exchange
  replaceUrlWithoutQuery();
}

Future<void> _rehydrateSessionOnce() async {
  // Touching currentSession is enough; the SDK already persisted it.
  final _ = Supabase.instance.client.auth.currentSession;
}

void _installVisibilityRefresh() {
  if (!kIsWeb) return;
  // Implemented in utils/web_history_web.dart; no-op on non-web.
  onVisibilityChange(() {
    // fire-and-forget; reduces iOS PWA storage eviction issues
    unawaited(Supabase.instance.client.auth.refreshSession());
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
      final tail = (t == null || t.isEmpty) ? '-' : t.substring(0, 10);
      debugPrint('[auth] ($origin) user=${s.user.id} token=$tail…');
    }
  }

  static Future<void> trackIfAuthed(String event, Map<String, dynamic> props) async {
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
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthGate(),
    ),
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
  ],
);

/* ───────────────────────── App Widgets ───────────────────────── */

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
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
  
  // Add these fields for ICS handling:
  StreamSubscription? _intentDataStreamSubscription;

  // One-shot guards
  bool _appOpenLogged = false;
  bool _notifyInitInProgress = false;
  bool _notifyInitialized = false;

  @override
  void initState() {
    super.initState();

    // React to auth changes (includes initialSession)
    _authSub = supabase.auth.onAuthStateChange.listen((data) async {
      if (mounted) setState(() {});
      final ev = data.event;

      if (ev == AuthChangeEvent.initialSession || ev == AuthChangeEvent.signedIn) {
        Events.debugAuthBanner('onAuthStateChange:$ev');
        await _ensureProfile();          // keep profiles hydrated with email
        await _logAppOpenOnce();         // one-shot per cold start
        unawaited(_initNotificationsSafely());
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
      await repo.track(event: 'app_open', properties: {
        'platform': kIsWeb ? 'web' : 'mobile',
        'ts': DateTime.now().toUtc().toIso8601String(),
      });
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
        await _exchangeMobile(initialUri);
      }
    } catch (_) {}

    // While running
    _linkSub = _appLinks!.uriLinkStream.listen((uri) async {
      if (uri != null) {
        await _exchangeMobile(uri);
      }
    }, onError: (_) {});
  }

  Future<void> _exchangeMobile(Uri uri) async {
    final qp = uri.queryParameters;
    final frag = uri.fragment;
    final looksLikeAuth =
        qp.containsKey('code') || frag.contains('access_token=') || frag.contains('refresh_token=');
    if (!looksLikeAuth) return;
    try {
      await supabase.auth.exchangeCodeForSession(uri.toString());
      await supabase.auth.refreshSession();
      Events.debugAuthBanner('deeplink');
      if (mounted) setState(() {});
    } catch (_) {}
  }

  // ------------------------------------
  // ICS FILE HANDLING
  // ------------------------------------
  
  void _initSharingIntent() {
    print('[ICS] Initializing sharing intent handling...');
    
    // Handle files shared while app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        print('[ICS] Received initial files: ${value.length}');
        for (final file in value) {
          print('[ICS] Initial file: ${file.path}');
        }
        _handleSharedFiles(value.map((f) => PlatformFile(
          name: f.path.split('/').last,
          size: 0,
          path: f.path,
        )).toList());
        
        // 🔥 FIX: Clear the shared files after handling them
        ReceiveSharingIntent.instance.reset();
      }
    }).catchError((error) {
      print('[ICS] Error getting initial media: $error');
    });

    // Handle files shared while app is open
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream()
        .listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        print('[ICS] Received stream files: ${value.length}');
        for (final file in value) {
          print('[ICS] Stream file: ${file.path}');
        }
        _handleSharedFiles(value.map((f) => PlatformFile(
          name: f.path.split('/').last,
          size: 0,
          path: f.path,
        )).toList());
        
        // 🔥 FIX: Clear the shared files after handling them
        ReceiveSharingIntent.instance.reset();
      }
    }, onError: (error) {
      print('[ICS] Error in media stream: $error');
    });
  }

  Future<void> _handleSharedFiles(List<PlatformFile> files) async {
    print('[ICS] Handling ${files.length} shared files');
    
    for (final file in files) {
      final path = file.path;
      print('[ICS] Processing file: $path');
      
      // Check if it's an ICS file
      if (path != null && path.toLowerCase().endsWith('.ics')) {
        print('[ICS] Received ICS file: $path');
        
        // Parse the ICS file
        final events = await IcsParser.parseFile(path);
        
        if (events.isEmpty) {
          print('[ICS] No events found in file');
          continue;
        }
        
        print('[ICS] Found ${events.length} events in file');
        
        // Show preview card for the first event
        final event = events.first;
        if (mounted) {
          _showIcsPreview(event);
        }
      } else {
        print('[ICS] File is not an ICS file: $path');
      }
    }
  }

  Future<void> _pickAndImportIcsFile() async {
    try {
      print('[ICS] Opening file picker...');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ics'],
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        print('[ICS] File picked: ${result.files.first.path}');
        await _handleSharedFiles(result.files);
      } else {
        print('[ICS] No file selected');
      }
    } catch (e) {
      print('[ICS] Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to pick ICS file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showIcsPreview(IcsEvent event) {
    print('[ICS] Showing preview for event: ${event.title}');
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
        onEditAndAdd: () {
          Navigator.pop(context);
          _editAndAddEventFromIcs(event);
        },
        onCancel: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _addEventFromIcs(IcsEvent event) async {
    try {
      print('[ICS] Starting import for event: ${event.title}');
      
      // Convert Gregorian date to Kemetic using your existing logic
      final kemeticDate = KemeticMath.fromGregorian(event.startTime);
      print('[ICS] Converted to Kemetic date: ${kemeticDate.kYear}-${kemeticDate.kMonth}-${kemeticDate.kDay}');
      
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
      
      print('[ICS] Generated client ID: $clientEventId');
      
      final repo = UserEventsRepo(supabase);
      
      await repo.upsertByClientId(
        clientEventId: clientEventId,
        title: event.title,
        startsAtUtc: event.startTime.toUtc(),
        endsAtUtc: event.endTime?.toUtc(),
        detail: event.description,
        location: event.location,
        allDay: event.isAllDay,
      );
      
      print('[ICS] Event imported successfully: ${event.title}');
      print('[ICS] Kemetic date: ${kemeticDate.kYear}-${kemeticDate.kMonth}-${kemeticDate.kDay}');
      print('[ICS] Client ID: $clientEventId');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event "${event.title}" added to calendar'),
            backgroundColor: const Color(0xFFD4AF37),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('[ICS] Error importing event: $e');
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

  Future<void> _editAndAddEventFromIcs(IcsEvent event) async {
    // TODO: Open your event editor with pre-filled data
    // For now, just show a message that this will be implemented
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Edit & Add coming soon - event added directly for now'),
          backgroundColor: Color(0xFFD4AF37),
        ),
      );
      // Just add it directly for now
      await _addEventFromIcs(event);
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
    final int sMin = (allDay || startHour == null || startMinute == null)
        ? 9 * 60  // Default to 9:00 AM for all-day events
        : (startHour * 60 + startMinute);
    final String tSlug = title.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    return 'ky=$ky-km=$km-kd=$kd|s=$sMin|t=$tSlug|f=$flowId';
  }

  Future<void> _signInWithGoogle() async {
    final redirect = kIsWeb ? Uri.base.origin : 'kemet.app://login-callback';
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirect,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;

    if (session == null) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Kemetic Calendar',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  const Text('Sign in to sync your flows and events.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _signInWithGoogle,
                    icon: const Icon(Icons.login),
                    label: const Text('Continue with Google'),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () async {
                        await supabase.auth.signOut();
                      },
                      child: const Text('Sign out (debug)'),
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
    return const Scaffold(
      body: CalendarPage(),
    );
  }
}