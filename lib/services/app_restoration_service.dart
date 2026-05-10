import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/app_restoration_repo.dart';
import 'app_window_service.dart';
import 'app_window_platform_stub.dart'
    if (dart.library.html) 'app_window_platform_web.dart'
    as app_window_platform;

const Set<String> _validExpansionValues = <String>{
  'compact',
  'stacked',
  'details',
};

const Set<String> _validCalendarAnchorTargets = <String>{
  'dayChip',
  'monthHeader',
  'monthBody',
};

Map<String, dynamic>? _asJsonMap(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  return raw.map<String, dynamic>(
    (dynamic key, dynamic value) => MapEntry(key.toString(), value),
  );
}

Map<String, Map<String, dynamic>> _asJsonMapByKey(Object? raw) {
  if (raw is! Map) {
    return const <String, Map<String, dynamic>>{};
  }
  final result = <String, Map<String, dynamic>>{};
  for (final entry in raw.entries) {
    final key = entry.key.toString().trim();
    final value = _asJsonMap(entry.value);
    if (key.isNotEmpty && value != null) {
      result[key] = value;
    }
  }
  return Map<String, Map<String, dynamic>>.unmodifiable(result);
}

List<Map<String, dynamic>> _asJsonMapList(Object? raw) {
  if (raw is! Iterable) {
    return const <Map<String, dynamic>>[];
  }
  return raw
      .map(_asJsonMap)
      .whereType<Map<String, dynamic>>()
      .map((entry) => Map<String, dynamic>.unmodifiable(entry))
      .toList(growable: false);
}

Object? _coerceJsonValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is DateTime) {
    return value.toUtc().toIso8601String();
  }
  if (value is Map) {
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key.toString().trim();
      if (key.isNotEmpty) {
        result[key] = _coerceJsonValue(entry.value);
      }
    }
    return result;
  }
  if (value is Iterable) {
    return value.map(_coerceJsonValue).toList(growable: false);
  }
  return value.toString();
}

Map<String, dynamic> _coerceJsonMap(Map<String, dynamic> raw) {
  final result = <String, dynamic>{};
  for (final entry in raw.entries) {
    final key = entry.key.trim();
    if (key.isNotEmpty) {
      result[key] = _coerceJsonValue(entry.value);
    }
  }
  return result;
}

List<Map<String, dynamic>> _coerceOverlayStack(
  List<Map<String, dynamic>> overlayStack,
) {
  return overlayStack
      .where((entry) => entry.isNotEmpty)
      .map(_coerceJsonMap)
      .toList(growable: false);
}

int? _asInt(Object? raw) => (raw as num?)?.toInt();

bool _isLeapKemeticYear(int kYear) => ((kYear - 1) % 4 + 4) % 4 == 2;

bool _isValidKemeticMonth(int kMonth) => kMonth >= 1 && kMonth <= 13;

int _maxDayForKemeticMonth(int kYear, int kMonth) {
  if (kMonth == 13) {
    return _isLeapKemeticYear(kYear) ? 6 : 5;
  }
  return 30;
}

bool _isValidKemeticDay(int kYear, int kMonth, int kDay) {
  if (!_isValidKemeticMonth(kMonth)) {
    return false;
  }
  return kDay >= 1 && kDay <= _maxDayForKemeticMonth(kYear, kMonth);
}

double? _readOptionalScrollOffset(Map<String, dynamic> raw) {
  if (!raw.containsKey('scrollOffset') || raw['scrollOffset'] == null) {
    return null;
  }
  final scrollOffset = (raw['scrollOffset'] as num?)?.toDouble();
  if (scrollOffset == null || !scrollOffset.isFinite || scrollOffset < 0) {
    return null;
  }
  return scrollOffset;
}

class CalendarRestorationState {
  const CalendarRestorationState({
    required this.kYear,
    required this.kMonth,
    required this.kDay,
    required this.showGregorian,
    required this.expansion,
    this.anchorTarget,
    this.anchorAlignment,
    this.viewportHeight,
    this.layoutRevision,
    this.scrollOffset,
  });

  final int kYear;
  final int kMonth;
  final int kDay;
  final bool showGregorian;
  final String expansion;
  final String? anchorTarget;
  final double? anchorAlignment;
  final double? viewportHeight;
  final int? layoutRevision;
  final double? scrollOffset;

  CalendarRestorationState copyWith({
    int? kYear,
    int? kMonth,
    int? kDay,
    bool? showGregorian,
    String? expansion,
    String? anchorTarget,
    double? anchorAlignment,
    double? viewportHeight,
    int? layoutRevision,
    double? scrollOffset,
    bool clearAnchorTarget = false,
    bool clearAnchorAlignment = false,
    bool clearViewportHeight = false,
    bool clearLayoutRevision = false,
    bool clearScrollOffset = false,
  }) {
    return CalendarRestorationState(
      kYear: kYear ?? this.kYear,
      kMonth: kMonth ?? this.kMonth,
      kDay: kDay ?? this.kDay,
      showGregorian: showGregorian ?? this.showGregorian,
      expansion: expansion ?? this.expansion,
      anchorTarget: clearAnchorTarget
          ? null
          : (anchorTarget ?? this.anchorTarget),
      anchorAlignment: clearAnchorAlignment
          ? null
          : (anchorAlignment ?? this.anchorAlignment),
      viewportHeight: clearViewportHeight
          ? null
          : (viewportHeight ?? this.viewportHeight),
      layoutRevision: clearLayoutRevision
          ? null
          : (layoutRevision ?? this.layoutRevision),
      scrollOffset: clearScrollOffset
          ? null
          : (scrollOffset ?? this.scrollOffset),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kYear': kYear,
      'kMonth': kMonth,
      'kDay': kDay,
      'showGregorian': showGregorian,
      'expansion': expansion,
      if (anchorTarget != null) 'anchorTarget': anchorTarget,
      if (anchorAlignment != null) 'anchorAlignment': anchorAlignment,
      if (viewportHeight != null) 'viewportHeight': viewportHeight,
      if (layoutRevision != null) 'layoutRevision': layoutRevision,
      if (scrollOffset != null) 'scrollOffset': scrollOffset,
    };
  }

  static CalendarRestorationState? fromJson(Object? raw) {
    final json = _asJsonMap(raw);
    if (json == null) {
      return null;
    }
    final kYear = _asInt(json['kYear']);
    final kMonth = _asInt(json['kMonth']);
    final kDay = _asInt(json['kDay']);
    final showGregorian = json['showGregorian'] == true;
    final expansion = (json['expansion'] as String?)?.trim();
    final anchorTarget = (json['anchorTarget'] as String?)?.trim();
    final anchorAlignment = (json['anchorAlignment'] as num?)?.toDouble();
    final viewportHeight = (json['viewportHeight'] as num?)?.toDouble();
    final layoutRevision = _asInt(json['layoutRevision']);
    final scrollOffset = _readOptionalScrollOffset(json);
    if (kYear == null ||
        kMonth == null ||
        kDay == null ||
        expansion == null ||
        !_validExpansionValues.contains(expansion) ||
        !_isValidKemeticDay(kYear, kMonth, kDay) ||
        (json.containsKey('anchorTarget') &&
            json['anchorTarget'] != null &&
            (anchorTarget == null ||
                anchorTarget.isEmpty ||
                !_validCalendarAnchorTargets.contains(anchorTarget))) ||
        (json.containsKey('anchorAlignment') &&
            json['anchorAlignment'] != null &&
            (anchorAlignment == null ||
                !anchorAlignment.isFinite ||
                anchorAlignment < 0 ||
                anchorAlignment > 1)) ||
        (json.containsKey('viewportHeight') &&
            json['viewportHeight'] != null &&
            (viewportHeight == null ||
                !viewportHeight.isFinite ||
                viewportHeight <= 0)) ||
        (json.containsKey('layoutRevision') &&
            json['layoutRevision'] != null &&
            (layoutRevision == null || layoutRevision < 1)) ||
        (json.containsKey('scrollOffset') &&
            json['scrollOffset'] != null &&
            scrollOffset == null)) {
      return null;
    }
    return CalendarRestorationState(
      kYear: kYear,
      kMonth: kMonth,
      kDay: kDay,
      showGregorian: showGregorian,
      expansion: expansion,
      anchorTarget: anchorTarget,
      anchorAlignment: anchorAlignment,
      viewportHeight: viewportHeight,
      layoutRevision: layoutRevision,
      scrollOffset: scrollOffset,
    );
  }
}

class DayViewRestorationState {
  const DayViewRestorationState({
    required this.isOpen,
    required this.kYear,
    required this.kMonth,
    required this.kDay,
    required this.showGregorian,
    this.firstVisibleMinute,
    this.scrollOffset,
  });

  final bool isOpen;
  final int kYear;
  final int kMonth;
  final int kDay;
  final bool showGregorian;
  final int? firstVisibleMinute;
  final double? scrollOffset;

  DayViewRestorationState copyWith({
    bool? isOpen,
    int? kYear,
    int? kMonth,
    int? kDay,
    bool? showGregorian,
    int? firstVisibleMinute,
    double? scrollOffset,
    bool clearFirstVisibleMinute = false,
    bool clearScrollOffset = false,
  }) {
    return DayViewRestorationState(
      isOpen: isOpen ?? this.isOpen,
      kYear: kYear ?? this.kYear,
      kMonth: kMonth ?? this.kMonth,
      kDay: kDay ?? this.kDay,
      showGregorian: showGregorian ?? this.showGregorian,
      firstVisibleMinute: clearFirstVisibleMinute
          ? null
          : (firstVisibleMinute ?? this.firstVisibleMinute),
      scrollOffset: clearScrollOffset
          ? null
          : (scrollOffset ?? this.scrollOffset),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'isOpen': isOpen,
      'kYear': kYear,
      'kMonth': kMonth,
      'kDay': kDay,
      'showGregorian': showGregorian,
      if (firstVisibleMinute != null) 'firstVisibleMinute': firstVisibleMinute,
      if (scrollOffset != null) 'scrollOffset': scrollOffset,
    };
  }

  static DayViewRestorationState? fromJson(Object? raw) {
    final json = _asJsonMap(raw);
    if (json == null) {
      return null;
    }
    final kYear = _asInt(json['kYear']);
    final kMonth = _asInt(json['kMonth']);
    final kDay = _asInt(json['kDay']);
    final firstVisibleMinute = _asInt(json['firstVisibleMinute']);
    final scrollOffset = _readOptionalScrollOffset(json);
    if (kYear == null ||
        kMonth == null ||
        kDay == null ||
        !_isValidKemeticDay(kYear, kMonth, kDay) ||
        (json.containsKey('firstVisibleMinute') &&
            json['firstVisibleMinute'] != null &&
            (firstVisibleMinute == null ||
                firstVisibleMinute < 0 ||
                firstVisibleMinute > 24 * 60 - 1)) ||
        (json.containsKey('scrollOffset') &&
            json['scrollOffset'] != null &&
            scrollOffset == null)) {
      return null;
    }
    return DayViewRestorationState(
      isOpen: json['isOpen'] == true,
      kYear: kYear,
      kMonth: kMonth,
      kDay: kDay,
      showGregorian: json['showGregorian'] == true,
      firstVisibleMinute: firstVisibleMinute,
      scrollOffset: scrollOffset,
    );
  }
}

class AppRestorationSnapshot {
  const AppRestorationSnapshot({
    required this.userId,
    required this.windowId,
    required this.updatedAtMs,
    this.routeLocation,
    this.calendar,
    this.dayView,
    this.daySheet,
    this.surfaces = const <String, Map<String, dynamic>>{},
    this.overlayStack = const <Map<String, dynamic>>[],
    this.editors = const <String, Map<String, dynamic>>{},
    this.cacheHints,
  });

  final String userId;
  final String windowId;
  final int updatedAtMs;
  final String? routeLocation;
  final CalendarRestorationState? calendar;
  final DayViewRestorationState? dayView;
  final Map<String, dynamic>? daySheet;
  final Map<String, Map<String, dynamic>> surfaces;
  final List<Map<String, dynamic>> overlayStack;
  final Map<String, Map<String, dynamic>> editors;
  final Map<String, dynamic>? cacheHints;

  static AppRestorationSnapshot? fromJson(Map<String, dynamic> raw) {
    final userId = (raw['userId'] as String?)?.trim();
    final windowId = (raw['windowId'] as String?)?.trim();
    final updatedAtMs = _asInt(raw['updatedAtMs']);
    if (userId == null ||
        userId.isEmpty ||
        windowId == null ||
        windowId.isEmpty ||
        updatedAtMs == null) {
      return null;
    }

    final daySheetRaw = raw['daySheet'];
    return AppRestorationSnapshot(
      userId: userId,
      windowId: windowId,
      updatedAtMs: updatedAtMs,
      routeLocation: (raw['routeLocation'] as String?)?.trim(),
      calendar: CalendarRestorationState.fromJson(raw['calendar']),
      dayView: DayViewRestorationState.fromJson(raw['dayView']),
      daySheet: _asJsonMap(daySheetRaw),
      surfaces: _asJsonMapByKey(raw['surfaces']),
      overlayStack: _asJsonMapList(raw['overlayStack']),
      editors: _asJsonMapByKey(raw['editors']),
      cacheHints: _asJsonMap(raw['cacheHints']),
    );
  }
}

enum AppRestorationReadStatus { restored, tentative, noSnapshot, awaitingAuth }

class AppRestorationReadResult {
  const AppRestorationReadResult({
    required this.status,
    required this.windowId,
    required this.activeUserId,
    this.snapshot,
    this.source,
    this.reason,
  });

  final AppRestorationReadStatus status;
  final String windowId;
  final String? activeUserId;
  final AppRestorationSnapshot? snapshot;
  final String? source;
  final String? reason;

  bool get hasSnapshot => snapshot != null;
  bool get isTentative => status == AppRestorationReadStatus.tentative;
  bool get isAwaitingAuth => status == AppRestorationReadStatus.awaitingAuth;
}

class _SnapshotCandidate {
  const _SnapshotCandidate({
    required this.snapshot,
    required this.raw,
    required this.source,
  });

  final AppRestorationSnapshot snapshot;
  final Map<String, dynamic> raw;
  final String source;
}

class AppRestorationService {
  AppRestorationService._();

  static const int schemaVersion = 1;
  static const String _keyPrefix = 'app_restoration_v1';
  static const String _latestUserKeyPrefix = 'app_restoration_latest_v2';
  static const String _lastActiveUserKey = 'app_restoration_last_user_v2';
  static const String _deviceIdPrefsKey = 'app_restoration_device_id_v1';
  static final AppRestorationService instance = AppRestorationService._();

  static String? Function()? debugUserIdResolver;
  static Future<Map<String, dynamic>?> Function(
    String userId,
    String deviceId,
    String windowId,
  )?
  debugRemoteWindowSnapshotReader;
  static Future<Map<String, dynamic>?> Function(String userId)?
  debugRemoteLatestSnapshotReader;
  static Future<void> Function(
    String userId,
    String deviceId,
    String windowId,
    Map<String, dynamic> snapshot,
  )?
  debugRemoteSnapshotWriter;
  static String? Function(String windowId)? debugCriticalSnapshotReader;
  static void Function(String windowId, String? serialized)?
  debugCriticalSnapshotWriter;
  static String? Function(String userId)? debugLatestCriticalSnapshotReader;
  static void Function(String userId, String? serialized)?
  debugLatestCriticalSnapshotWriter;
  static String? Function()? debugPlatformLastActiveUserIdReader;
  static void Function(String? userId)? debugPlatformLastActiveUserIdWriter;

  String? _deviceId;
  Future<String>? _deviceIdFuture;
  Future<void> _mutationQueue = Future<void>.value();
  Future<void> _remoteWriteQueue = Future<void>.value();

  Future<void> initialize() async {
    final windowId = await AppWindowService.instance.ensureInitialized();
    app_window_platform.registerCriticalSnapshotWindow(windowId);
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[restoration] $message');
    }
  }

  Future<String?> _currentUserId() async {
    final debugResolver = debugUserIdResolver;
    if (debugResolver != null) {
      final resolved = debugResolver()?.trim();
      return resolved == null || resolved.isEmpty ? null : resolved;
    }
    try {
      final resolved = Supabase.instance.client.auth.currentUser?.id.trim();
      return resolved == null || resolved.isEmpty ? null : resolved;
    } catch (_) {
      return null;
    }
  }

  Future<String> _currentWindowId() =>
      AppWindowService.instance.ensureInitialized();

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<String> _currentDeviceId() {
    final cached = _deviceId;
    if (cached != null && cached.isNotEmpty) {
      return Future<String>.value(cached);
    }
    final inFlight = _deviceIdFuture;
    if (inFlight != null) {
      return inFlight;
    }
    _deviceIdFuture = () async {
      final prefs = await _prefs();
      final existing = prefs.getString(_deviceIdPrefsKey)?.trim();
      if (existing != null && existing.isNotEmpty) {
        _deviceId = existing;
        return existing;
      }
      final generated = const Uuid().v4();
      await prefs.setString(_deviceIdPrefsKey, generated);
      _deviceId = generated;
      return generated;
    }();
    return _deviceIdFuture!;
  }

  AppRestorationRepo? _remoteRepo() {
    try {
      return AppRestorationRepo(Supabase.instance.client);
    } catch (_) {
      return null;
    }
  }

  String _prefsKey(String userId, String windowId) =>
      '$_keyPrefix:$userId:$windowId';

  String _latestPrefsKey(String userId) => '$_latestUserKeyPrefix:$userId';

  Future<void> _clearSnapshotFor(String userId, String windowId) async {
    final prefs = await _prefs();
    await prefs.remove(_prefsKey(userId, windowId));
  }

  Future<void> _clearLatestSnapshotForUser(String userId) async {
    final prefs = await _prefs();
    await prefs.remove(_latestPrefsKey(userId));
  }

  Future<String?> _readLastActiveUserId() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_lastActiveUserKey)?.trim();
    return raw == null || raw.isEmpty ? null : raw;
  }

  String? _readPlatformLastActiveUserId() {
    final debugReader = debugPlatformLastActiveUserIdReader;
    final raw = debugReader != null
        ? debugReader()?.trim()
        : app_window_platform.readPlatformLastActiveUserId()?.trim();
    return raw == null || raw.isEmpty ? null : raw;
  }

  void _writePlatformLastActiveUserId(String? userId) {
    final debugWriter = debugPlatformLastActiveUserIdWriter;
    if (debugWriter != null) {
      debugWriter(userId);
      return;
    }
    app_window_platform.updatePlatformLastActiveUserId(userId);
  }

  Future<String?> _readBootFallbackUserId() async {
    final fromPrefs = await _readLastActiveUserId();
    if (fromPrefs != null) {
      return fromPrefs;
    }
    return _readPlatformLastActiveUserId();
  }

  Future<void> clearBootFallbackIdentity() async {
    final prefs = await _prefs();
    await prefs.remove(_lastActiveUserKey);
    _writePlatformLastActiveUserId(null);
    final windowId = await _currentWindowId();
    _writeCriticalSnapshot(windowId, null);
    _log('cleared boot fallback identity window=$windowId');
  }

  Map<String, dynamic>? _migrateRawSnapshot(Map<String, dynamic> raw) {
    final version = _asInt(raw['schemaVersion']);
    if (version == null) {
      return null;
    }
    switch (version) {
      case schemaVersion:
        return Map<String, dynamic>.from(raw);
      default:
        return null;
    }
  }

  Future<Map<String, dynamic>?> _loadRawFor(
    String userId,
    String windowId, {
    required bool clearIfInvalid,
  }) async {
    final prefs = await _prefs();
    final key = _prefsKey(userId, windowId);
    final rawString = prefs.getString(key);
    if (rawString == null || rawString.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawString);
      if (decoded is! Map<String, dynamic>) {
        if (clearIfInvalid) {
          await prefs.remove(key);
        }
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      if (clearIfInvalid) {
        await prefs.remove(key);
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> _loadLatestRawForUser(
    String userId, {
    required bool clearIfInvalid,
  }) async {
    final prefs = await _prefs();
    final key = _latestPrefsKey(userId);
    final rawString = prefs.getString(key);
    if (rawString == null || rawString.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawString);
      if (decoded is! Map<String, dynamic>) {
        if (clearIfInvalid) {
          await prefs.remove(key);
        }
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      if (clearIfInvalid) {
        await prefs.remove(key);
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> _loadCriticalRawFor(
    String windowId, {
    required bool clearIfInvalid,
  }) async {
    final debugReader = debugCriticalSnapshotReader;
    final rawString = debugReader != null
        ? debugReader(windowId)
        : app_window_platform.readCriticalSnapshot(windowId);
    if (rawString == null || rawString.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawString);
      if (decoded is! Map<String, dynamic>) {
        if (clearIfInvalid) {
          _writeCriticalSnapshot(windowId, null);
        }
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      if (clearIfInvalid) {
        _writeCriticalSnapshot(windowId, null);
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> _loadLatestCriticalRawForUser(
    String userId, {
    required bool clearIfInvalid,
  }) async {
    final debugReader = debugLatestCriticalSnapshotReader;
    final rawString = debugReader != null
        ? debugReader(userId)
        : app_window_platform.readLatestCriticalSnapshot(userId);
    if (rawString == null || rawString.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawString);
      if (decoded is! Map<String, dynamic>) {
        if (clearIfInvalid) {
          _writeLatestCriticalSnapshot(userId, null);
        }
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      if (clearIfInvalid) {
        _writeLatestCriticalSnapshot(userId, null);
      }
      return null;
    }
  }

  Future<_SnapshotCandidate?> _loadPrefsCandidate(
    String userId,
    String windowId, {
    required bool clearIfInvalid,
  }) async {
    final raw = await _loadRawFor(
      userId,
      windowId,
      clearIfInvalid: clearIfInvalid,
    );
    if (raw == null) {
      return null;
    }
    final migrated = _migrateRawSnapshot(raw);
    if (migrated == null) {
      if (clearIfInvalid) {
        await _clearSnapshotFor(userId, windowId);
      }
      return null;
    }
    final snapshot = AppRestorationSnapshot.fromJson(migrated);
    if (snapshot == null ||
        snapshot.userId != userId ||
        snapshot.windowId != windowId) {
      if (clearIfInvalid) {
        await _clearSnapshotFor(userId, windowId);
      }
      return null;
    }
    return _SnapshotCandidate(
      snapshot: snapshot,
      raw: migrated,
      source: 'prefs',
    );
  }

  Future<_SnapshotCandidate?> _loadCriticalCandidate(
    String windowId, {
    String? expectedUserId,
    required bool clearIfInvalid,
  }) async {
    final raw = await _loadCriticalRawFor(
      windowId,
      clearIfInvalid: clearIfInvalid,
    );
    if (raw == null) {
      return null;
    }
    final migrated = _migrateRawSnapshot(raw);
    if (migrated == null) {
      if (clearIfInvalid) {
        _writeCriticalSnapshot(windowId, null);
      }
      return null;
    }
    final snapshot = AppRestorationSnapshot.fromJson(migrated);
    final userMismatch =
        expectedUserId != null &&
        snapshot != null &&
        snapshot.userId != expectedUserId;
    if (snapshot == null || snapshot.windowId != windowId || userMismatch) {
      if (clearIfInvalid) {
        _writeCriticalSnapshot(windowId, null);
      }
      return null;
    }
    return _SnapshotCandidate(
      snapshot: snapshot,
      raw: migrated,
      source: 'critical',
    );
  }

  Future<_SnapshotCandidate?> _loadLatestPrefsCandidate(
    String userId, {
    required bool clearIfInvalid,
  }) async {
    final raw = await _loadLatestRawForUser(
      userId,
      clearIfInvalid: clearIfInvalid,
    );
    if (raw == null) {
      return null;
    }
    final migrated = _migrateRawSnapshot(raw);
    if (migrated == null) {
      if (clearIfInvalid) {
        await _clearLatestSnapshotForUser(userId);
      }
      return null;
    }
    final snapshot = AppRestorationSnapshot.fromJson(migrated);
    if (snapshot == null || snapshot.userId != userId) {
      if (clearIfInvalid) {
        await _clearLatestSnapshotForUser(userId);
      }
      return null;
    }
    return _SnapshotCandidate(
      snapshot: snapshot,
      raw: migrated,
      source: 'latest_prefs',
    );
  }

  Future<_SnapshotCandidate?> _loadLatestCriticalCandidate(
    String userId, {
    required bool clearIfInvalid,
  }) async {
    final raw = await _loadLatestCriticalRawForUser(
      userId,
      clearIfInvalid: clearIfInvalid,
    );
    if (raw == null) {
      return null;
    }
    final migrated = _migrateRawSnapshot(raw);
    if (migrated == null) {
      if (clearIfInvalid) {
        _writeLatestCriticalSnapshot(userId, null);
      }
      return null;
    }
    final snapshot = AppRestorationSnapshot.fromJson(migrated);
    if (snapshot == null || snapshot.userId != userId) {
      if (clearIfInvalid) {
        _writeLatestCriticalSnapshot(userId, null);
      }
      return null;
    }
    return _SnapshotCandidate(
      snapshot: snapshot,
      raw: migrated,
      source: 'latest_critical',
    );
  }

  Future<_SnapshotCandidate?> _candidateFromRemoteRaw(
    Map<String, dynamic>? raw, {
    required String expectedUserId,
    required String source,
  }) async {
    if (raw == null) {
      return null;
    }
    final migrated = _migrateRawSnapshot(raw);
    if (migrated == null) {
      return null;
    }
    final snapshot = AppRestorationSnapshot.fromJson(migrated);
    if (snapshot == null || snapshot.userId != expectedUserId) {
      return null;
    }
    return _SnapshotCandidate(
      snapshot: snapshot,
      raw: migrated,
      source: source,
    );
  }

  Future<_SnapshotCandidate?> _loadRemoteWindowCandidate(
    String userId,
    String windowId,
  ) async {
    final deviceId = await _currentDeviceId();
    final debugReader = debugRemoteWindowSnapshotReader;
    if (debugReader != null) {
      return _candidateFromRemoteRaw(
        await debugReader(userId, deviceId, windowId),
        expectedUserId: userId,
        source: 'remote_window',
      );
    }

    final repo = _remoteRepo();
    if (repo == null) {
      return null;
    }
    try {
      final remote = await repo.readWindowSnapshot(
        userId: userId,
        deviceId: deviceId,
        windowId: windowId,
      );
      return _candidateFromRemoteRaw(
        remote?.snapshot,
        expectedUserId: userId,
        source: remote?.source ?? 'remote_window',
      );
    } catch (error) {
      _log('remote window read skipped: $error');
      return null;
    }
  }

  Future<_SnapshotCandidate?> _loadRemoteLatestCandidate(String userId) async {
    final debugReader = debugRemoteLatestSnapshotReader;
    if (debugReader != null) {
      return _candidateFromRemoteRaw(
        await debugReader(userId),
        expectedUserId: userId,
        source: 'remote_latest',
      );
    }

    final repo = _remoteRepo();
    if (repo == null) {
      return null;
    }
    try {
      final remote = await repo.readLatestSnapshot(userId: userId);
      return _candidateFromRemoteRaw(
        remote?.snapshot,
        expectedUserId: userId,
        source: remote?.source ?? 'remote_latest',
      );
    } catch (error) {
      _log('remote latest read skipped: $error');
      return null;
    }
  }

  Future<_SnapshotCandidate?> _scanPrefsCandidatesForUser(
    String userId, {
    required bool clearIfInvalid,
  }) async {
    final prefs = await _prefs();
    final prefix = '$_keyPrefix:$userId:';
    final candidates = <_SnapshotCandidate>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) {
        continue;
      }
      final windowId = key.substring(prefix.length).trim();
      if (windowId.isEmpty) {
        if (clearIfInvalid) {
          await prefs.remove(key);
        }
        continue;
      }
      final candidate = await _loadPrefsCandidate(
        userId,
        windowId,
        clearIfInvalid: clearIfInvalid,
      );
      if (candidate != null) {
        candidates.add(candidate);
      }
    }
    return _pickNewestCandidate(candidates);
  }

  _SnapshotCandidate? _pickNewestCandidate(
    Iterable<_SnapshotCandidate> candidates,
  ) {
    _SnapshotCandidate? winner;
    for (final candidate in candidates) {
      final currentWinner = winner;
      if (currentWinner == null ||
          candidate.snapshot.updatedAtMs >=
              currentWinner.snapshot.updatedAtMs) {
        winner = candidate;
      }
    }
    return winner;
  }

  Future<_SnapshotCandidate?> _readSnapshotCandidateForUser(
    String userId,
    String windowId, {
    required bool clearIfInvalid,
  }) async {
    final prefsCandidate = await _loadPrefsCandidate(
      userId,
      windowId,
      clearIfInvalid: clearIfInvalid,
    );
    final criticalCandidate = await _loadCriticalCandidate(
      windowId,
      expectedUserId: userId,
      clearIfInvalid: clearIfInvalid,
    );
    return _pickNewestCandidate(<_SnapshotCandidate>[
      if (prefsCandidate != null) prefsCandidate,
      if (criticalCandidate != null) criticalCandidate,
    ]);
  }

  Future<_SnapshotCandidate?> _readLatestSnapshotCandidateForUser(
    String userId, {
    required bool clearIfInvalid,
    bool includeRemote = false,
  }) async {
    final latestPrefsCandidate = await _loadLatestPrefsCandidate(
      userId,
      clearIfInvalid: clearIfInvalid,
    );
    final latestCriticalCandidate = await _loadLatestCriticalCandidate(
      userId,
      clearIfInvalid: clearIfInvalid,
    );
    final scannedPrefsCandidate = await _scanPrefsCandidatesForUser(
      userId,
      clearIfInvalid: clearIfInvalid,
    );
    final remoteLatestCandidate = includeRemote
        ? await _loadRemoteLatestCandidate(userId)
        : null;
    return _pickNewestCandidate(<_SnapshotCandidate>[
      if (latestPrefsCandidate != null) latestPrefsCandidate,
      if (latestCriticalCandidate != null) latestCriticalCandidate,
      if (scannedPrefsCandidate != null) scannedPrefsCandidate,
      if (remoteLatestCandidate != null) remoteLatestCandidate,
    ]);
  }

  Future<_SnapshotCandidate?> _readStableSnapshotCandidateForUser(
    String userId,
    String windowId, {
    required bool clearIfInvalid,
    bool includeRemote = false,
  }) async {
    final currentWindowCandidate = await _readSnapshotCandidateForUser(
      userId,
      windowId,
      clearIfInvalid: clearIfInvalid,
    );
    final remoteWindowCandidate = includeRemote
        ? await _loadRemoteWindowCandidate(userId, windowId)
        : null;
    final latestUserCandidate = await _readLatestSnapshotCandidateForUser(
      userId,
      clearIfInvalid: clearIfInvalid,
      includeRemote: includeRemote,
    );
    if (currentWindowCandidate == null) {
      return _pickNewestCandidate(<_SnapshotCandidate>[
        if (remoteWindowCandidate != null) remoteWindowCandidate,
        if (latestUserCandidate != null) latestUserCandidate,
      ]);
    }
    if (!includeRemote) {
      return currentWindowCandidate;
    }

    if (remoteWindowCandidate != null &&
        remoteWindowCandidate.snapshot.updatedAtMs >
            currentWindowCandidate.snapshot.updatedAtMs) {
      return remoteWindowCandidate;
    }

    final currentRoute = currentWindowCandidate.snapshot.routeLocation?.trim();
    final currentIsRootOrEmpty =
        currentRoute == null || currentRoute.isEmpty || currentRoute == '/';
    final latestRoute = latestUserCandidate?.snapshot.routeLocation?.trim();
    final latestHasMeaningfulRoute =
        latestRoute != null && latestRoute.isNotEmpty && latestRoute != '/';
    if (currentIsRootOrEmpty &&
        latestUserCandidate != null &&
        latestHasMeaningfulRoute &&
        latestUserCandidate.snapshot.updatedAtMs >
            currentWindowCandidate.snapshot.updatedAtMs) {
      return latestUserCandidate;
    }

    final latestHasOverlay =
        latestUserCandidate?.snapshot.overlayStack.isNotEmpty == true;
    if (latestUserCandidate != null &&
        latestHasOverlay &&
        currentWindowCandidate.snapshot.overlayStack.isEmpty &&
        latestUserCandidate.snapshot.updatedAtMs >
            currentWindowCandidate.snapshot.updatedAtMs) {
      return latestUserCandidate;
    }

    return currentWindowCandidate;
  }

  void _writeCriticalSnapshot(String windowId, String? serialized) {
    final debugWriter = debugCriticalSnapshotWriter;
    if (debugWriter != null) {
      debugWriter(windowId, serialized);
      return;
    }
    if (serialized == null || serialized.trim().isEmpty) {
      app_window_platform.clearCriticalSnapshot(windowId);
      return;
    }
    app_window_platform.updateCriticalSnapshot(windowId, serialized);
  }

  void _writeLatestCriticalSnapshot(String userId, String? serialized) {
    final debugWriter = debugLatestCriticalSnapshotWriter;
    if (debugWriter != null) {
      debugWriter(userId, serialized);
      return;
    }
    if (serialized == null || serialized.trim().isEmpty) {
      app_window_platform.clearLatestCriticalSnapshot(userId);
      return;
    }
    app_window_platform.updateLatestCriticalSnapshot(userId, serialized);
  }

  bool _isRemoteSource(String? source) =>
      source != null && source.startsWith('remote_');

  Future<void> _persistRawSnapshotLocally(
    String userId,
    String windowId,
    Map<String, dynamic> raw,
  ) async {
    final encoded = jsonEncode(raw);
    _writeCriticalSnapshot(windowId, encoded);
    _writeLatestCriticalSnapshot(userId, encoded);
    _writePlatformLastActiveUserId(userId);
    final prefs = await _prefs();
    await Future.wait<bool>(<Future<bool>>[
      prefs.setString(_prefsKey(userId, windowId), encoded),
      prefs.setString(_latestPrefsKey(userId), encoded),
      prefs.setString(_lastActiveUserKey, userId),
    ]);
  }

  Future<AppRestorationSnapshot?> _adoptRemoteSnapshot(
    _SnapshotCandidate candidate,
    String userId,
    String windowId,
  ) async {
    final raw = Map<String, dynamic>.from(candidate.raw);
    raw['schemaVersion'] = schemaVersion;
    raw['userId'] = userId;
    raw['windowId'] = windowId;
    raw['updatedAtMs'] = DateTime.now().millisecondsSinceEpoch;
    final snapshot = AppRestorationSnapshot.fromJson(raw);
    if (snapshot == null) {
      return null;
    }
    await _persistRawSnapshotLocally(userId, windowId, raw);
    _log('adopted ${candidate.source} snapshot user=$userId window=$windowId');
    return snapshot;
  }

  Future<AppRestorationSnapshot?> readSnapshotForUser(
    String userId, {
    String? windowId,
    bool includeRemote = false,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return null;
    }
    final resolvedWindowId = windowId ?? await _currentWindowId();
    final candidate = await _readStableSnapshotCandidateForUser(
      normalizedUserId,
      resolvedWindowId,
      clearIfInvalid: true,
      includeRemote: includeRemote,
    );
    if (candidate != null && _isRemoteSource(candidate.source)) {
      return _adoptRemoteSnapshot(
        candidate,
        normalizedUserId,
        resolvedWindowId,
      );
    }
    return candidate?.snapshot;
  }

  Future<AppRestorationReadResult> readBestSnapshot({
    bool includeRemote = false,
  }) async {
    final windowId = await _currentWindowId();
    app_window_platform.registerCriticalSnapshotWindow(windowId);
    final activeUserId = await _currentUserId();
    if (activeUserId != null) {
      final candidate = await _readStableSnapshotCandidateForUser(
        activeUserId,
        windowId,
        clearIfInvalid: true,
        includeRemote: includeRemote,
      );
      if (candidate != null) {
        final snapshot = _isRemoteSource(candidate.source)
            ? await _adoptRemoteSnapshot(candidate, activeUserId, windowId)
            : candidate.snapshot;
        if (snapshot == null) {
          return AppRestorationReadResult(
            status: AppRestorationReadStatus.noSnapshot,
            windowId: windowId,
            activeUserId: activeUserId,
            source: 'none',
            reason: 'invalid_adopted_remote_snapshot',
          );
        }
        _log(
          'read status=restored source=${candidate.source} '
          'user=$activeUserId window=$windowId',
        );
        return AppRestorationReadResult(
          status: AppRestorationReadStatus.restored,
          windowId: windowId,
          activeUserId: activeUserId,
          snapshot: snapshot,
          source: candidate.source,
          reason: 'matched_current_user',
        );
      }
      _log(
        'read status=no_snapshot user=$activeUserId window=$windowId '
        'reason=no_snapshot_for_current_user',
      );
      return AppRestorationReadResult(
        status: AppRestorationReadStatus.noSnapshot,
        windowId: windowId,
        activeUserId: activeUserId,
        source: 'none',
        reason: 'no_snapshot_for_current_user',
      );
    }

    final lastActiveUserId = await _readBootFallbackUserId();
    final tentativeCandidate = lastActiveUserId == null
        ? await _loadCriticalCandidate(windowId, clearIfInvalid: true)
        : await _pickNewestTentativeCandidate(lastActiveUserId, windowId);
    if (tentativeCandidate != null) {
      _log(
        'read status=tentative source=${tentativeCandidate.source} '
        'snapshot_user=${tentativeCandidate.snapshot.userId} window=$windowId '
        'reason=auth_not_ready',
      );
      return AppRestorationReadResult(
        status: AppRestorationReadStatus.tentative,
        windowId: windowId,
        activeUserId: null,
        snapshot: tentativeCandidate.snapshot,
        source: tentativeCandidate.source,
        reason: 'auth_not_ready',
      );
    }

    _log(
      'read status=awaiting_auth window=$windowId '
      'reason=no_authenticated_user',
    );
    return AppRestorationReadResult(
      status: AppRestorationReadStatus.awaitingAuth,
      windowId: windowId,
      activeUserId: null,
      source: 'none',
      reason: 'no_authenticated_user',
    );
  }

  Future<_SnapshotCandidate?> _pickNewestTentativeCandidate(
    String lastActiveUserId,
    String windowId,
  ) async {
    final userScopedCandidate = await _readStableSnapshotCandidateForUser(
      lastActiveUserId,
      windowId,
      clearIfInvalid: true,
    );
    final currentWindowCriticalCandidate = await _loadCriticalCandidate(
      windowId,
      expectedUserId: lastActiveUserId,
      clearIfInvalid: true,
    );
    return _pickNewestCandidate(<_SnapshotCandidate>[
      if (userScopedCandidate != null) userScopedCandidate,
      if (currentWindowCriticalCandidate != null)
        currentWindowCriticalCandidate,
    ]);
  }

  Future<AppRestorationSnapshot?> readSnapshot({
    bool includeRemote = false,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      return null;
    }
    return readSnapshotForUser(userId, includeRemote: includeRemote);
  }

  Future<void> _mutate(
    void Function(Map<String, dynamic> current) update,
  ) async {
    final next = _mutationQueue.then((_) => _mutateNow(update));
    _mutationQueue = next.catchError((_) {});
    return next;
  }

  Future<void> _mutateNow(
    void Function(Map<String, dynamic> current) update,
  ) async {
    final userId = await _currentUserId();
    if (userId == null) {
      return;
    }
    final windowId = await _currentWindowId();
    app_window_platform.registerCriticalSnapshotWindow(windowId);
    final snapshotCandidate = await _readStableSnapshotCandidateForUser(
      userId,
      windowId,
      clearIfInvalid: false,
    );
    final baseline =
        snapshotCandidate?.raw ??
        await _loadRawFor(userId, windowId, clearIfInvalid: false) ??
        <String, dynamic>{};
    final current = Map<String, dynamic>.from(baseline);
    update(current);
    current['schemaVersion'] = schemaVersion;
    current['userId'] = userId;
    current['windowId'] = windowId;
    current['updatedAtMs'] = DateTime.now().millisecondsSinceEpoch;
    await _persistRawSnapshotLocally(userId, windowId, current);
    _scheduleRemoteSnapshotWrite(current);
  }

  void _scheduleRemoteSnapshotWrite(Map<String, dynamic> raw) {
    final snapshot = Map<String, dynamic>.from(raw);
    final next = _remoteWriteQueue.then(
      (_) => _writeRemoteSnapshot(snapshot),
      onError: (_) => _writeRemoteSnapshot(snapshot),
    );
    _remoteWriteQueue = next.catchError((_) {});
    unawaited(_remoteWriteQueue);
  }

  Future<void> _writeRemoteSnapshot(Map<String, dynamic> raw) async {
    final userId = (raw['userId'] as String?)?.trim();
    final windowId = (raw['windowId'] as String?)?.trim();
    final updatedAtMs = _asInt(raw['updatedAtMs']);
    if (userId == null ||
        userId.isEmpty ||
        windowId == null ||
        windowId.isEmpty ||
        updatedAtMs == null) {
      return;
    }

    final deviceId = await _currentDeviceId();
    final debugWriter = debugRemoteSnapshotWriter;
    if (debugWriter != null) {
      await debugWriter(
        userId,
        deviceId,
        windowId,
        Map<String, dynamic>.from(raw),
      );
      return;
    }

    final repo = _remoteRepo();
    if (repo == null) {
      return;
    }
    try {
      await repo.upsertSnapshots(
        userId: userId,
        deviceId: deviceId,
        windowId: windowId,
        schemaVersion: schemaVersion,
        updatedAtMs: updatedAtMs,
        snapshot: Map<String, dynamic>.from(raw),
      );
    } catch (error) {
      _log('remote write skipped: $error');
    }
  }

  Future<void> flushPendingWrites() async {
    await _mutationQueue;
    await _remoteWriteQueue;
  }

  Future<void> clearCurrentSnapshot() async {
    final userId = await _currentUserId();
    if (userId == null) {
      return;
    }
    final windowId = await _currentWindowId();
    final prefs = await _prefs();
    await prefs.remove(_prefsKey(userId, windowId));
    _writeCriticalSnapshot(windowId, null);
  }

  Future<String?> readRouteLocation({bool includeRemote = false}) async {
    final snapshot = await readSnapshot(includeRemote: includeRemote);
    final location = snapshot?.routeLocation?.trim();
    if (location == null || location.isEmpty) {
      return null;
    }
    return location;
  }

  Future<void> saveRouteLocation(String location) async {
    final normalized = location.trim();
    if (normalized.isEmpty) {
      return;
    }
    await _mutate((current) {
      current['routeLocation'] = normalized;
    });
  }

  Future<void> saveRouteLocationWithOverlayStack(
    String location,
    List<Map<String, dynamic>> overlayStack,
  ) async {
    final normalized = location.trim();
    if (normalized.isEmpty) {
      return;
    }
    await _mutate((current) {
      current['routeLocation'] = normalized;
      final next = _coerceOverlayStack(overlayStack);
      if (next.isEmpty) {
        current.remove('overlayStack');
      } else {
        current['overlayStack'] = next;
      }
    });
  }

  Future<CalendarRestorationState?> readCalendarState() async {
    return (await readSnapshot())?.calendar;
  }

  Future<void> saveCalendarState(CalendarRestorationState state) async {
    final validated = CalendarRestorationState.fromJson(state.toJson());
    if (validated == null) {
      return;
    }
    await _mutate((current) {
      current['calendar'] = validated.toJson();
    });
  }

  Future<DayViewRestorationState?> readDayViewState() async {
    return (await readSnapshot())?.dayView;
  }

  Future<void> saveDayViewState(DayViewRestorationState? state) async {
    await _mutate((current) {
      if (state == null) {
        current.remove('dayView');
        return;
      }
      final validated = DayViewRestorationState.fromJson(state.toJson());
      if (validated == null) {
        return;
      }
      current['dayView'] = validated.toJson();
    });
  }

  Future<Map<String, dynamic>?> readDaySheetState() async {
    final snapshot = await readSnapshot();
    final raw = snapshot?.daySheet;
    if (raw == null) {
      return null;
    }
    return Map<String, dynamic>.from(raw);
  }

  Future<void> saveDaySheetState(Map<String, dynamic>? state) async {
    await _mutate((current) {
      if (state == null || state.isEmpty) {
        current.remove('daySheet');
      } else {
        current['daySheet'] = _coerceJsonMap(state);
      }
    });
  }

  Future<Map<String, dynamic>?> readSurfaceState(String key) async {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return null;
    }
    final snapshot = await readSnapshot();
    final state = snapshot?.surfaces[normalizedKey];
    return state == null ? null : Map<String, dynamic>.from(state);
  }

  Future<void> saveSurfaceState(String key, Map<String, dynamic>? state) async {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return;
    }
    await _mutate((current) {
      final surfaces = _asJsonMapByKey(current['surfaces']);
      final next = <String, Map<String, dynamic>>{...surfaces};
      if (state == null || state.isEmpty) {
        next.remove(normalizedKey);
      } else {
        next[normalizedKey] = _coerceJsonMap(state);
      }
      if (next.isEmpty) {
        current.remove('surfaces');
      } else {
        current['surfaces'] = next;
      }
    });
  }

  Future<List<Map<String, dynamic>>> readOverlayStack() async {
    final snapshot = await readSnapshot();
    return snapshot?.overlayStack
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(growable: false) ??
        const <Map<String, dynamic>>[];
  }

  Future<void> saveOverlayStack(List<Map<String, dynamic>> overlayStack) async {
    await _mutate((current) {
      final next = _coerceOverlayStack(overlayStack);
      if (next.isEmpty) {
        current.remove('overlayStack');
      } else {
        current['overlayStack'] = next;
      }
    });
  }

  Future<Map<String, dynamic>?> readEditorState(String key) async {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return null;
    }
    final snapshot = await readSnapshot();
    final state = snapshot?.editors[normalizedKey];
    return state == null ? null : Map<String, dynamic>.from(state);
  }

  Future<void> saveEditorState(String key, Map<String, dynamic>? state) async {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return;
    }
    await _mutate((current) {
      final editors = _asJsonMapByKey(current['editors']);
      final next = <String, Map<String, dynamic>>{...editors};
      if (state == null || state.isEmpty) {
        next.remove(normalizedKey);
      } else {
        next[normalizedKey] = _coerceJsonMap(state);
      }
      if (next.isEmpty) {
        current.remove('editors');
      } else {
        current['editors'] = next;
      }
    });
  }

  Future<Map<String, dynamic>?> readCacheHints() async {
    final snapshot = await readSnapshot();
    final hints = snapshot?.cacheHints;
    return hints == null ? null : Map<String, dynamic>.from(hints);
  }

  Future<void> saveCacheHints(Map<String, dynamic>? hints) async {
    await _mutate((current) {
      if (hints == null || hints.isEmpty) {
        current.remove('cacheHints');
      } else {
        current['cacheHints'] = _coerceJsonMap(hints);
      }
    });
  }
}
