import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../features/calendar/notify.dart';

// ---- Firebase background handler (must be a top-level function) ----
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // ignore init errors in background (likely missing google-services during dev)
  }
}

void registerPushBackgroundHandler() {
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
}

/// Lightweight supabase helper to persist push tokens. Safe if the table
/// doesn't exist; errors are swallowed after being logged.
class _PushTokenRepo {
  const _PushTokenRepo(this._client);
  final SupabaseClient _client;

  Future<void> upsertToken({
    required String token,
    required String platform,
    required String deviceId,
  }) async {
    final user = _client.auth.currentUser;
    final uid = user?.id;
    if (uid == null) {
      debugPrint('[push] upsert skipped: no user');
      return;
    }
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final payload = {
      'user_id': uid,
      'platform': platform,
      'token': token,
      'device_id': deviceId,
      'is_active': true,
      'last_seen_at': nowIso,
      'updated_at': nowIso,
    };
    debugPrint('[push] upsert payload: $payload');
    try {
      await _client
          .from('push_tokens')
          .upsert(payload, onConflict: 'device_id')
          .select();
      debugPrint('[push] token upsert succeeded');
    } catch (e) {
      debugPrint('[push] token upsert failed: $e');
    }
  }

  Future<void> deleteToken({required String deviceId}) async {
    try {
      await _client.from('push_tokens').delete().eq('device_id', deviceId);
    } catch (_) {
      // ignore
    }
  }
}

class PushNotifications {
  PushNotifications._(this._client) : _repo = _PushTokenRepo(_client);

  static PushNotifications? _instance;
  static PushNotifications instance(SupabaseClient client) {
    return _instance ??= PushNotifications._(client);
  }

  final SupabaseClient _client;
  final _PushTokenRepo _repo;
  bool _initialized = false;
  bool _askedPermission = false;

  static const _webApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const _webSender = String.fromEnvironment('FIREBASE_WEB_SENDER_ID');
  static const _webProjectId = String.fromEnvironment('FIREBASE_WEB_PROJECT_ID');
  static const _webVapidKey = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');

  /// Request permission, fetch token, and upsert it. Returns the token if available.
  Future<String?> requestAndRegisterToken() async {
    final currentSession = _client.auth.currentSession;
    final currentUser = _client.auth.currentUser;
    debugPrint('[push] currentSession? ${currentSession != null}');
    debugPrint('[push] currentUser? ${currentUser != null}, id=${currentUser?.id}');
    debugPrint('[push] session.expiresAt: ${currentSession?.expiresAt}');

    if (currentSession == null || currentUser?.id == null) {
      debugPrint('[push] no authenticated user; aborting token upsert. Prompt user to sign in.');
      return null;
    }

    final ok = await initAndRequestPermission();
    if (!ok) {
      debugPrint('[push] permission not granted');
      return null;
    }

    final token = await _getToken();
    debugPrint('[push] requestAndRegisterToken token: $token');
    if (token != null) {
      await _registerToken(token);
    }
    return token;
  }

  Future<void> init() async {
    if (_initialized) return;
    final ok = await _ensureFirebaseInitialized();
    if (!ok) return;

    // Foreground presentation (iOS/macOS/web)
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _initialized = true;
    _attachListeners();
  }

  void _attachListeners() {
    FirebaseMessaging.onMessage.listen((message) async {
      final notif = message.notification;
      if (notif == null) return;
      await Notify.showInstant(
        title: notif.title ?? 'Kemetic Calendar',
        body: notif.body,
      );
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _registerToken(token);
    });
  }

  Future<void> registerForUser() async {
    final session = _client.auth.currentSession;
    if (session == null) return;
    debugPrint('[push] registerForUser: user=${session.user.id}');
    final ok = await initAndRequestPermission();
    debugPrint('[push] permission ok: $ok');
    if (!ok) return;
    if (kIsWeb) {
      await _requestWebPermissionAndLogToken();
    }
    final token = await _getToken();
    debugPrint('[push] token fetched: $token');
    if (token != null) {
      await _registerToken(token);
    }
  }

  Future<void> unregister() async {
    final deviceId = await _deviceId();
    await _repo.deleteToken(deviceId: deviceId);
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('[push] deleteToken error: $e');
    }
  }

  Future<bool> initAndRequestPermission() async {
    final ok = await _ensureFirebaseInitialized();
    if (!ok) return false;
    if (_askedPermission) return true;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      _askedPermission = true;
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('[push] permission request failed: $e');
      return false;
    }
  }

  /* ───────────────────────── helpers ───────────────────────── */

  Future<bool> _ensureFirebaseInitialized() async {
    try {
      if (Firebase.apps.isNotEmpty) return true;

      if (kIsWeb) {
        final opts = _webOptionsFromEnv();
        if (opts == null) {
          debugPrint('[push] missing FIREBASE_WEB_* env vars; web push disabled');
          return false;
        }
        await Firebase.initializeApp(options: opts);
        return true;
      }

      await Firebase.initializeApp();
      return true;
    } catch (e) {
      debugPrint('[push] Firebase init failed (likely missing google-services/Info.plist): $e');
      return false;
    }
  }

  Future<String?> _getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb ? (_webVapidKey.isEmpty ? null : _webVapidKey) : null,
      );
    } catch (e) {
      debugPrint('[push] getToken failed: $e');
      return null;
    }
  }

  Future<void> _registerToken(String token) async {
    final deviceId = await _deviceId();
    final platform = _platformLabel();
    debugPrint('[push] registering token for platform=$platform deviceId=$deviceId');
    await _repo.upsertToken(token: token, platform: platform, deviceId: deviceId);
  }

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('push.deviceId');
    if (cached != null && cached.isNotEmpty) return cached;
    final id = const Uuid().v4();
    await prefs.setString('push.deviceId', id);
    return id;
  }

  FirebaseOptions? _webOptionsFromEnv() {
    if (_webApiKey.isEmpty || _webAppId.isEmpty || _webSender.isEmpty || _webProjectId.isEmpty) {
      return null;
    }
    return FirebaseOptions(
      apiKey: _webApiKey,
      appId: _webAppId,
      messagingSenderId: _webSender,
      projectId: _webProjectId,
    );
  }

  /// Web-only: request permission explicitly and log the token for debugging.
  Future<void> _requestWebPermissionAndLogToken() async {
    if (!kIsWeb) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[push] web permission: ${settings.authorizationStatus}');
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: _webVapidKey.isEmpty ? null : _webVapidKey,
      );
      debugPrint('[push] web token: $token');
    } catch (e) {
      debugPrint('[push] web permission/token failed: $e');
    }
  }
}

String _platformLabel() {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.android:
      return 'android';
    default:
      return 'unknown';
  }
}
