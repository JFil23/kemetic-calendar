import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
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

  Future<bool> upsertToken({
    required String token,
    required String platform,
    required String deviceId,
  }) async {
    final user = _client.auth.currentUser;
    final uid = user?.id;
    if (uid == null) {
      debugPrint('[push] upsert skipped: no user');
      return false;
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
      return true;
    } catch (e) {
      debugPrint('[push] token upsert failed: $e');
      return false;
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

@immutable
class PushRegistrationDiagnostics {
  const PushRegistrationDiagnostics({
    required this.checkedAt,
    required this.firebaseReady,
    required this.permissionStatus,
    required this.permissionGranted,
    required this.platform,
    required this.hasSession,
    required this.databaseRegistered,
    this.deviceId,
    this.registeredToken,
    this.lastSeenAt,
    this.error,
  });

  final DateTime checkedAt;
  final bool firebaseReady;
  final String permissionStatus;
  final bool permissionGranted;
  final String platform;
  final bool hasSession;
  final bool databaseRegistered;
  final String? deviceId;
  final String? registeredToken;
  final DateTime? lastSeenAt;
  final String? error;

  String get tokenSummary => summarizePushToken(registeredToken);
}

@immutable
class PushSelfTestResult {
  const PushSelfTestResult({required this.ok, required this.message});

  final bool ok;
  final String message;
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
  bool _initialMessageChecked = false;
  final StreamController<Map<String, dynamic>> _openedMessages =
      StreamController.broadcast();
  final Set<String> _handledOpenedMessageSignatures = <String>{};
  String? _resolvedWebVapidKey;

  Stream<Map<String, dynamic>> get openedMessages => _openedMessages.stream;

  static const _webApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const _webSender = String.fromEnvironment('FIREBASE_WEB_SENDER_ID');
  static const _webProjectId = String.fromEnvironment(
    'FIREBASE_WEB_PROJECT_ID',
  );
  static const _webVapidKey = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');

  /// Request permission, fetch token, and upsert it. Returns the token if available.
  Future<String?> requestAndRegisterToken() async {
    final currentSession = _client.auth.currentSession;
    final currentUser = _client.auth.currentUser;
    debugPrint('[push] currentSession? ${currentSession != null}');
    debugPrint(
      '[push] currentUser? ${currentUser != null}, id=${currentUser?.id}',
    );
    debugPrint('[push] session.expiresAt: ${currentSession?.expiresAt}');

    if (currentSession == null || currentUser?.id == null) {
      debugPrint(
        '[push] no authenticated user; aborting token upsert. Prompt user to sign in.',
      );
      return null;
    }

    final ok = await initAndRequestPermission();
    if (!ok) {
      debugPrint('[push] permission not granted');
      return null;
    }

    return _registerCurrentToken();
  }

  Future<bool> init() async {
    if (_initialized) return true;
    final ok = await _ensureFirebaseInitialized();
    if (!ok) {
      debugPrint('[push] Firebase init failed; push disabled');
      return false;
    }

    // Foreground presentation (iOS/macOS/web)
    try {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
    } catch (e) {
      debugPrint('[push] foreground presentation setup failed: $e');
    }

    _initialized = true;
    _attachListeners();
    return true;
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

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _emitOpenedMessage(message.data, messageId: message.messageId);
    });
  }

  Future<bool> registerForUser() async {
    final session = _client.auth.currentSession;
    if (session == null) return false;
    debugPrint('[push] registerForUser: user=${session.user.id}');
    final ok = await initAndRequestPermission();
    debugPrint('[push] permission ok: $ok');
    if (!ok) return false;
    final token = await _registerCurrentToken();
    if (token == null) {
      debugPrint('[push] token fetched: <null>');
      return false;
    }
    if (kDebugMode) {
      final suffix = token.length > 8
          ? token.substring(token.length - 8)
          : token;
      debugPrint(
        '[push] token registered=true len=${token.length} suffix=$suffix',
      );
    }
    return true;
  }

  /// Re-register the current device only when permission was already granted.
  /// On web/PWA this avoids prompting outside an explicit user gesture while
  /// still keeping the stored token fresh after sign-in or app resume.
  Future<bool> refreshRegistrationIfAuthorized() async {
    final session = _client.auth.currentSession;
    if (session == null) return false;
    final ok = await init();
    if (!ok) return false;

    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (!pushAuthorizationAllowsRegistration(
        settings.authorizationStatus,
      )) {
        debugPrint(
          '[push] refreshRegistrationIfAuthorized skipped: permission=${describePushAuthorizationStatus(settings.authorizationStatus)}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('[push] refreshRegistrationIfAuthorized failed: $e');
      return false;
    }

    final token = await _registerCurrentToken();
    return token != null;
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
    final ok = await init();
    if (!ok) return false;

    try {
      final currentSettings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (pushAuthorizationAllowsRegistration(
        currentSettings.authorizationStatus,
      )) {
        return true;
      }

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      return pushAuthorizationAllowsRegistration(
        settings.authorizationStatus,
      );
    } catch (e) {
      debugPrint('[push] permission request failed: $e');
      return false;
    }
  }

  Future<PushRegistrationDiagnostics> getDiagnostics() async {
    final checkedAt = DateTime.now();
    final session = _client.auth.currentSession;
    final user = _client.auth.currentUser;
    final hasSession = session != null && user != null;

    String? error;
    String? deviceId;
    String? registeredToken;
    DateTime? lastSeenAt;
    var databaseRegistered = false;
    AuthorizationStatus? authorizationStatus;

    final firebaseReady = await init();
    if (firebaseReady) {
      try {
        final settings = await FirebaseMessaging.instance
            .getNotificationSettings();
        authorizationStatus = settings.authorizationStatus;
      } catch (e) {
        error = 'permission check failed: $e';
      }
    }

    if (hasSession) {
      deviceId = await _deviceId();
      try {
        final row = await _client
            .from('push_tokens')
            .select('token, is_active, last_seen_at, updated_at')
            .eq('user_id', user.id)
            .eq('device_id', deviceId)
            .maybeSingle();
        final data = row is Map ? Map<String, dynamic>.from(row as Map) : null;
        databaseRegistered = data?['is_active'] == true;
        registeredToken = data?['token'] as String?;
        final lastSeenRaw =
            data?['last_seen_at'] ?? data?['updated_at'];
        if (lastSeenRaw is String && lastSeenRaw.isNotEmpty) {
          lastSeenAt = DateTime.tryParse(lastSeenRaw);
        }
      } catch (e) {
        error = error ?? 'push_tokens lookup failed: $e';
      }
    }

    return PushRegistrationDiagnostics(
      checkedAt: checkedAt,
      firebaseReady: firebaseReady,
      permissionStatus: firebaseReady
          ? describePushAuthorizationStatus(authorizationStatus)
          : 'firebase unavailable',
      permissionGranted: pushAuthorizationAllowsRegistration(
        authorizationStatus,
      ),
      platform: _platformLabel(),
      hasSession: hasSession,
      databaseRegistered: databaseRegistered,
      deviceId: deviceId,
      registeredToken: registeredToken,
      lastSeenAt: lastSeenAt,
      error: error,
    );
  }

  Future<PushSelfTestResult> sendSelfTestPush() async {
    final session = _client.auth.currentSession;
    final user = _client.auth.currentUser;
    if (session == null || user == null) {
      return const PushSelfTestResult(
        ok: false,
        message: 'Sign in before sending a test push.',
      );
    }

    final token = await requestAndRegisterToken();
    if (token == null) {
      return const PushSelfTestResult(
        ok: false,
        message:
            'This device could not create and register a push token. Check permission and Firebase config first.',
      );
    }

    final sentAt = DateTime.now().toUtc();
    try {
      final response = await _client.functions.invoke(
        'send_push',
        body: {
          'userIds': [user.id],
          'notification': {
            'title': 'Kemetic push test',
            'body':
                'Push path check at ${sentAt.toLocal().toIso8601String()}',
          },
          'data': {
            'type': 'push_test',
            'kind': 'push_test',
            'sent_at': sentAt.toIso8601String(),
          },
        },
      );

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : (response.data is Map
                ? Map<String, dynamic>.from(response.data as Map)
                : <String, dynamic>{});
      if (response.status >= 400) {
        final message =
            data['error']?.toString() ??
            'send_push returned HTTP ${response.status}';
        return PushSelfTestResult(ok: false, message: message);
      }

      final sent = (data['sent'] as num?)?.toInt() ?? 0;
      final delivered = data['delivered'] == true || sent > 0;
      if (!delivered) {
        final failedReasons = (data['failedReasons'] as List<dynamic>? ?? const [])
            .map((entry) => entry.toString())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false);
        final reason =
            data['reason']?.toString() ??
            (failedReasons.isNotEmpty
                ? failedReasons.join(', ')
                : 'No active push token matched this device.');
        return PushSelfTestResult(ok: false, message: reason);
      }

      return const PushSelfTestResult(
        ok: true,
        message:
            'Test push dispatched. If the app is open, a foreground alert should appear; if it is backgrounded, the device or PWA notification should appear.',
      );
    } catch (e) {
      return PushSelfTestResult(
        ok: false,
        message: 'send_push failed: $e',
      );
    }
  }

  /* ───────────────────────── helpers ───────────────────────── */

  Future<bool> _ensureFirebaseInitialized() async {
    try {
      if (Firebase.apps.isNotEmpty) return true;

      if (kIsWeb) {
        final opts = await _resolveWebOptions();
        if (opts == null) {
          debugPrint(
            '[push] missing web Firebase config; set FIREBASE_WEB_* or web/env.json',
          );
          return false;
        }
        await Firebase.initializeApp(options: opts);
        return true;
      }

      await Firebase.initializeApp();
      return true;
    } catch (e) {
      debugPrint(
        '[push] Firebase init failed (likely missing google-services/Info.plist): $e',
      );
      return false;
    }
  }

  Future<String?> _getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb
            ? (_resolvedWebVapidKey?.isNotEmpty == true
                  ? _resolvedWebVapidKey
                  : (_webVapidKey.isEmpty ? null : _webVapidKey))
            : null,
      );
    } catch (e) {
      debugPrint('[push] getToken failed: $e');
      return null;
    }
  }

  Future<String?> _registerCurrentToken() async {
    final token = await _getToken();
    debugPrint('[push] current token: ${summarizePushToken(token)}');
    if (token == null) {
      return null;
    }
    final okReg = await _registerToken(token);
    if (!okReg) {
      return null;
    }
    return token;
  }

  Future<bool> _registerToken(String token) async {
    final deviceId = await _deviceId();
    final platform = _platformLabel();
    debugPrint(
      '[push] registering token for platform=$platform deviceId=$deviceId',
    );
    return await _repo.upsertToken(
      token: token,
      platform: platform,
      deviceId: deviceId,
    );
  }

  Future<void> emitInitialMessage() async {
    if (_initialMessageChecked) return;
    final ok = await _ensureFirebaseInitialized();
    if (!ok) return;
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      _initialMessageChecked = true;
      if (initial != null) {
        _emitOpenedMessage(initial.data, messageId: initial.messageId);
      }
    } catch (e) {
      debugPrint('[push] emitInitialMessage error: $e');
    }
  }

  void _emitOpenedMessage(Map<String, dynamic> data, {String? messageId}) {
    final signature = buildPushOpenedMessageSignature(
      data,
      messageId: messageId,
    );
    if (_handledOpenedMessageSignatures.contains(signature)) {
      if (kDebugMode) {
        debugPrint('[push] skip duplicate opened message: $signature');
      }
      return;
    }
    _handledOpenedMessageSignatures.add(signature);
    while (_handledOpenedMessageSignatures.length > 24) {
      _handledOpenedMessageSignatures.remove(
        _handledOpenedMessageSignatures.first,
      );
    }
    _openedMessages.add(data);
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
    if (_webApiKey.isEmpty ||
        _webAppId.isEmpty ||
        _webSender.isEmpty ||
        _webProjectId.isEmpty) {
      return null;
    }
    return FirebaseOptions(
      apiKey: _webApiKey,
      appId: _webAppId,
      messagingSenderId: _webSender,
      projectId: _webProjectId,
    );
  }

  Future<FirebaseOptions?> _resolveWebOptions() async {
    final fromEnv = _webOptionsFromEnv();
    if (fromEnv != null) {
      _resolvedWebVapidKey = _webVapidKey;
      return fromEnv;
    }

    // Fallback: try to load web/env.json for hosted builds that rely on that file.
    try {
      final uri = Uri.base.resolve('env.json');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final apiKey = (json['FIREBASE_WEB_API_KEY'] as String?) ?? '';
        final appId = (json['FIREBASE_WEB_APP_ID'] as String?) ?? '';
        final senderId = (json['FIREBASE_WEB_SENDER_ID'] as String?) ?? '';
        final projectId = (json['FIREBASE_WEB_PROJECT_ID'] as String?) ?? '';
        final vapid = (json['FIREBASE_WEB_VAPID_KEY'] as String?) ?? '';
        if (apiKey.isNotEmpty &&
            appId.isNotEmpty &&
            senderId.isNotEmpty &&
            projectId.isNotEmpty) {
          _resolvedWebVapidKey = vapid;
          return FirebaseOptions(
            apiKey: apiKey,
            appId: appId,
            messagingSenderId: senderId,
            projectId: projectId,
          );
        }
      }
      debugPrint(
        '[push] env.json missing FIREBASE_WEB_* keys (status=${resp.statusCode})',
      );
    } catch (e) {
      debugPrint('[push] failed to load env.json for web Firebase config: $e');
    }
    return null;
  }
}

@visibleForTesting
String buildPushOpenedMessageSignature(
  Map<String, dynamic> data, {
  String? messageId,
}) {
  final normalizedId = messageId?.trim();
  if (normalizedId != null && normalizedId.isNotEmpty) {
    return 'id:$normalizedId';
  }
  return 'payload:${jsonEncode(_normalizePushMessageData(data))}';
}

Object? _normalizePushMessageData(Object? value) {
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    return <String, Object?>{
      for (final entry in entries)
        entry.key.toString(): _normalizePushMessageData(entry.value),
    };
  }
  if (value is Iterable) {
    return value.map(_normalizePushMessageData).toList(growable: false);
  }
  if (value == null || value is num || value is String || value is bool) {
    return value;
  }
  return value.toString();
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

bool pushAuthorizationAllowsRegistration(AuthorizationStatus? status) {
  return status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;
}

String describePushAuthorizationStatus(AuthorizationStatus? status) {
  switch (status) {
    case AuthorizationStatus.authorized:
      return 'authorized';
    case AuthorizationStatus.provisional:
      return 'provisional';
    case AuthorizationStatus.denied:
      return 'denied';
    case AuthorizationStatus.notDetermined:
      return 'not determined';
    case null:
      return 'unknown';
  }
}

String summarizePushToken(String? token) {
  if (token == null || token.isEmpty) {
    return 'not available';
  }
  if (token.length <= 16) {
    return token;
  }
  return '${token.substring(0, 8)}...${token.substring(token.length - 8)}';
}
