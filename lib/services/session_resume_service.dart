import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef SessionJsonMap = Map<String, dynamic>;

class SessionResumeEntry {
  const SessionResumeEntry({
    required this.baseRoute,
    required this.kind,
    required this.payload,
  });

  final String baseRoute;
  final String kind;
  final SessionJsonMap payload;
}

class SessionResumeService {
  static const Duration ttl = Duration(minutes: 10);
  static const String _prefsKey = 'session_resume_state_v1';

  static String? Function()? debugUserIdResolver;

  static String? _currentUserId() {
    final debugResolver = debugUserIdResolver;
    if (debugResolver != null) {
      return debugResolver();
    }
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  static bool _isExpired(SessionJsonMap raw, DateTime now) {
    final updatedAtMs = (raw['updatedAtMs'] as num?)?.toInt();
    if (updatedAtMs == null) return true;
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtMs);
    return now.difference(updatedAt) > ttl;
  }

  static bool _belongsToDifferentUser(SessionJsonMap raw) {
    final activeUserId = _currentUserId();
    final savedUserId = raw['userId'] as String?;
    if (activeUserId == null || savedUserId == null) {
      return false;
    }
    return activeUserId != savedUserId;
  }

  static Future<void> _clearStored() async {
    final prefs = await _prefs();
    await prefs.remove(_prefsKey);
  }

  static Future<SessionJsonMap?> _loadRaw({bool clearIfInvalid = true}) async {
    final prefs = await _prefs();
    final rawString = prefs.getString(_prefsKey);
    if (rawString == null || rawString.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawString);
      if (decoded is! Map<String, dynamic>) {
        if (clearIfInvalid) {
          await prefs.remove(_prefsKey);
        }
        return null;
      }

      final raw = Map<String, dynamic>.from(decoded);
      final now = DateTime.now();
      if (_isExpired(raw, now) || _belongsToDifferentUser(raw)) {
        if (clearIfInvalid) {
          await prefs.remove(_prefsKey);
        }
        return null;
      }
      return raw;
    } catch (_) {
      if (clearIfInvalid) {
        await prefs.remove(_prefsKey);
      }
      return null;
    }
  }

  static Future<void> _saveRaw(SessionJsonMap raw) async {
    final prefs = await _prefs();
    await prefs.setString(_prefsKey, jsonEncode(raw));
  }

  static Future<void> _mutate(
    SessionJsonMap Function(SessionJsonMap current) mutate,
  ) async {
    final now = DateTime.now();
    final current =
        await _loadRaw(clearIfInvalid: false) ?? <String, dynamic>{};
    if (_isExpired(current, now) || _belongsToDifferentUser(current)) {
      current.clear();
    }

    final next = mutate(Map<String, dynamic>.from(current));
    next['updatedAtMs'] = now.millisecondsSinceEpoch;
    final activeUserId = _currentUserId();
    if (activeUserId != null && activeUserId.isNotEmpty) {
      next['userId'] = activeUserId;
    } else {
      next.remove('userId');
    }
    await _saveRaw(next);
  }

  static Future<void> touch() async {
    await _mutate((current) => current);
  }

  static Future<void> clearAll() => _clearStored();

  static Future<String?> readRouteLocation() async {
    final raw = await _loadRaw();
    final location = raw?['routeLocation'] as String?;
    if (location == null || location.isEmpty) {
      return null;
    }
    return location;
  }

  static Future<void> saveRouteLocation(String location) async {
    final normalized = location.trim();
    if (normalized.isEmpty) return;
    await _mutate((current) {
      current['routeLocation'] = normalized;
      return current;
    });
  }

  static Future<void> saveResumeEntry({
    required String baseRoute,
    required String kind,
    SessionJsonMap payload = const <String, dynamic>{},
  }) async {
    await _mutate((current) {
      current['resumeEntry'] = <String, dynamic>{
        'baseRoute': baseRoute,
        'kind': kind,
        'payload': payload,
      };
      return current;
    });
  }

  static SessionResumeEntry? _entryFromRaw(
    SessionJsonMap? raw, {
    String? kind,
    String? baseRoute,
  }) {
    final entryRaw = raw?['resumeEntry'];
    if (entryRaw is! Map<String, dynamic>) return null;

    final entryKind = entryRaw['kind'] as String?;
    final entryBaseRoute = entryRaw['baseRoute'] as String?;
    if (entryKind == null || entryBaseRoute == null) return null;
    if (kind != null && entryKind != kind) return null;
    if (baseRoute != null && entryBaseRoute != baseRoute) return null;

    final payloadRaw = entryRaw['payload'];
    final payload = payloadRaw is Map<String, dynamic>
        ? Map<String, dynamic>.from(payloadRaw)
        : <String, dynamic>{};
    return SessionResumeEntry(
      baseRoute: entryBaseRoute,
      kind: entryKind,
      payload: payload,
    );
  }

  static Future<SessionResumeEntry?> readResumeEntry({
    String? kind,
    String? baseRoute,
  }) async {
    final raw = await _loadRaw();
    return _entryFromRaw(raw, kind: kind, baseRoute: baseRoute);
  }

  static Future<SessionResumeEntry?> consumeResumeEntry({
    String? kind,
    String? baseRoute,
  }) async {
    final raw = await _loadRaw();
    final entry = _entryFromRaw(raw, kind: kind, baseRoute: baseRoute);
    if (entry == null) return null;

    await _mutate((current) {
      current.remove('resumeEntry');
      return current;
    });
    return entry;
  }

  static Future<void> clearResumeEntry({String? kind}) async {
    await _mutate((current) {
      if (kind == null) {
        current.remove('resumeEntry');
        return current;
      }
      final entry = _entryFromRaw(current, kind: kind);
      if (entry != null) {
        current.remove('resumeEntry');
      }
      return current;
    });
  }

  static Future<void> saveScopedState(String key, SessionJsonMap? state) async {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) return;

    await _mutate((current) {
      final scopedStates =
          (current['scopedStates'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      if (state == null || state.isEmpty) {
        scopedStates.remove(normalizedKey);
      } else {
        scopedStates[normalizedKey] = state;
      }
      if (scopedStates.isEmpty) {
        current.remove('scopedStates');
      } else {
        current['scopedStates'] = scopedStates;
      }
      return current;
    });
  }

  static Future<SessionJsonMap?> readScopedState(String key) async {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) return null;
    final raw = await _loadRaw();
    final scopedStates = raw?['scopedStates'];
    if (scopedStates is! Map<String, dynamic>) return null;
    final state = scopedStates[normalizedKey];
    if (state is! Map<String, dynamic>) return null;
    return Map<String, dynamic>.from(state);
  }
}

class SessionTrackedRoute extends StatefulWidget {
  const SessionTrackedRoute({
    super.key,
    required this.location,
    required this.child,
    this.enabled = true,
  });

  final String location;
  final Widget child;
  final bool enabled;

  @override
  State<SessionTrackedRoute> createState() => _SessionTrackedRouteState();
}

class _SessionTrackedRouteState extends State<SessionTrackedRoute> {
  @override
  void initState() {
    super.initState();
    _persistRoute();
  }

  @override
  void didUpdateWidget(covariant SessionTrackedRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location ||
        oldWidget.enabled != widget.enabled) {
      _persistRoute();
    }
  }

  void _persistRoute() {
    if (!widget.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(SessionResumeService.saveRouteLocation(widget.location));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class SessionLifecycleBridge extends StatefulWidget {
  const SessionLifecycleBridge({super.key, required this.child});

  final Widget child;

  @override
  State<SessionLifecycleBridge> createState() => _SessionLifecycleBridgeState();
}

class _SessionLifecycleBridgeState extends State<SessionLifecycleBridge>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(SessionResumeService.touch());
        break;
      case AppLifecycleState.resumed:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
