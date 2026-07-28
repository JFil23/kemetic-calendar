import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:uuid/uuid.dart';
import 'package:web/web.dart' as web;

typedef WebLifecycleLogger =
    void Function(String event, Map<String, Object?> detail);

const String _windowIdPrefix = 'kemetic_window:';
const String _windowIdStorageKey = 'kemetic.window_id.v1';
const String _criticalSnapshotStorageKeyPrefix =
    'kemetic.restoration.critical.v1:';
const String _latestCriticalSnapshotStorageKeyPrefix =
    'kemetic.restoration.critical.latest.v2:';
const String _lastActiveUserStorageKey = 'kemetic.restoration.last_user.v2';
const String _windowClaimStorageKeyPrefix = 'kemetic.window_claim.v1:';
const Duration _windowClaimHeartbeatInterval = Duration(seconds: 10);
const Duration _windowClaimLiveTtl = Duration(hours: 24);
const Duration _windowClaimReloadGrace = Duration(seconds: 8);

bool _lifecycleListenersInstalled = false;
final List<WebLifecycleLogger> _lifecycleLoggers = <WebLifecycleLogger>[];
String? _criticalSnapshotWindowId;
String? _latestCriticalSnapshot;
String? _claimedWindowId;
Timer? _windowClaimHeartbeat;

bool _isUsableWindowId(String? raw) {
  final value = raw?.trim();
  return value != null && value.length >= 8;
}

String _generateWindowId() => const Uuid().v4();

final String _pageInstanceId = _generateWindowId();

int? _readInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}

String? _readSessionStorageWindowId() {
  try {
    return web.window.sessionStorage.getItem(_windowIdStorageKey)?.trim();
  } catch (_) {
    return null;
  }
}

void _writeSessionStorageWindowId(String windowId) {
  try {
    web.window.sessionStorage.setItem(_windowIdStorageKey, windowId);
  } catch (_) {
    // Best-effort only on web.
  }
}

String? _readWindowNameWindowId() {
  try {
    final raw = web.window.name.trim();
    if (!raw.startsWith(_windowIdPrefix)) {
      return null;
    }
    return raw.substring(_windowIdPrefix.length).trim();
  } catch (_) {
    return null;
  }
}

void _mirrorWindowIdIntoWindowName(String windowId) {
  try {
    final currentName = web.window.name.trim();
    if (currentName.isEmpty || currentName.startsWith(_windowIdPrefix)) {
      web.window.name = '$_windowIdPrefix$windowId';
    }
  } catch (_) {
    // Best-effort only on web.
  }
}

String _windowClaimStorageKey(String windowId) =>
    '$_windowClaimStorageKeyPrefix$windowId';

Map<String, Object?>? _readWindowClaim(String windowId) {
  try {
    final raw = web.window.localStorage
        .getItem(_windowClaimStorageKey(windowId))
        ?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    return decoded.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), value),
    );
  } catch (_) {
    return null;
  }
}

void _writeWindowClaim(String windowId, {bool closing = false}) {
  final normalized = windowId.trim();
  if (normalized.isEmpty) {
    return;
  }
  final now = DateTime.now().millisecondsSinceEpoch;
  try {
    web.window.localStorage.setItem(
      _windowClaimStorageKey(normalized),
      jsonEncode(<String, Object?>{
        'owner': _pageInstanceId,
        'updatedAtMs': now,
        if (closing) 'closingAtMs': now,
      }),
    );
  } catch (_) {
    // Best-effort only on web.
  }
}

bool _isClaimActiveForAnotherPage(String windowId) {
  final claim = _readWindowClaim(windowId);
  final owner = claim?['owner']?.toString().trim();
  if (owner == null || owner.isEmpty || owner == _pageInstanceId) {
    return false;
  }
  final updatedAtMs = _readInt(claim?['updatedAtMs']);
  if (updatedAtMs == null) {
    return false;
  }
  final now = DateTime.now().millisecondsSinceEpoch;
  final closingAtMs = _readInt(claim?['closingAtMs']);
  if (closingAtMs != null &&
      now - closingAtMs <= _windowClaimReloadGrace.inMilliseconds) {
    return false;
  }
  return now - updatedAtMs <= _windowClaimLiveTtl.inMilliseconds;
}

void _markWindowClaimClosing() {
  final windowId = _claimedWindowId?.trim();
  if (windowId == null || windowId.isEmpty) {
    return;
  }
  _windowClaimHeartbeat?.cancel();
  _windowClaimHeartbeat = null;
  _writeWindowClaim(windowId, closing: true);
}

void _ensureWindowClaimHeartbeat(String windowId) {
  final normalized = windowId.trim();
  if (normalized.isEmpty) {
    return;
  }
  if (_claimedWindowId == normalized && _windowClaimHeartbeat != null) {
    _writeWindowClaim(normalized);
    return;
  }
  _windowClaimHeartbeat?.cancel();
  _claimedWindowId = normalized;
  _writeWindowClaim(normalized);
  _windowClaimHeartbeat = Timer.periodic(_windowClaimHeartbeatInterval, (_) {
    if (_claimedWindowId == normalized) {
      _writeWindowClaim(normalized);
    }
  });
  _ensureLifecycleListenersInstalled();
}

String _claimResolvedWindowId(String candidate) {
  var normalized = candidate.trim();
  if (!_isUsableWindowId(normalized)) {
    normalized = _generateWindowId();
  }
  if (_isClaimActiveForAnotherPage(normalized)) {
    for (var attempt = 0; attempt < 6; attempt++) {
      final forked = _generateWindowId();
      normalized = forked;
      if (!_isClaimActiveForAnotherPage(forked)) {
        break;
      }
    }
  }
  _writeSessionStorageWindowId(normalized);
  _mirrorWindowIdIntoWindowName(normalized);
  _ensureWindowClaimHeartbeat(normalized);
  return normalized;
}

Future<String> resolvePlatformWindowId() async {
  final sessionWindowId = _readSessionStorageWindowId();
  if (_isUsableWindowId(sessionWindowId)) {
    return _claimResolvedWindowId(sessionWindowId!.trim());
  }

  final namedWindowId = _readWindowNameWindowId();
  if (_isUsableWindowId(namedWindowId)) {
    return _claimResolvedWindowId(namedWindowId!.trim());
  }

  return _claimResolvedWindowId(_generateWindowId());
}

String _criticalSnapshotStorageKey(String windowId) =>
    '$_criticalSnapshotStorageKeyPrefix$windowId';

String _latestCriticalSnapshotStorageKey(String userId) =>
    '$_latestCriticalSnapshotStorageKeyPrefix$userId';

void _emitLifecycleEvent(String event, Map<String, Object?> detail) {
  for (final listener in List<WebLifecycleLogger>.from(_lifecycleLoggers)) {
    listener(event, detail);
  }
}

void _persistLatestCriticalSnapshot() {
  final windowId = _criticalSnapshotWindowId?.trim();
  if (windowId == null || windowId.isEmpty) {
    return;
  }
  final key = _criticalSnapshotStorageKey(windowId);
  try {
    final serialized = _latestCriticalSnapshot;
    if (serialized == null || serialized.trim().isEmpty) {
      web.window.localStorage.removeItem(key);
    } else {
      web.window.localStorage.setItem(key, serialized);
    }
  } catch (_) {
    // Best-effort only on web.
  }
}

void _ensureLifecycleListenersInstalled() {
  if (_lifecycleListenersInstalled) {
    return;
  }
  _lifecycleListenersInstalled = true;

  web.window.addEventListener(
    'pageshow',
    ((web.Event event) {
      final windowId = _claimedWindowId;
      if (windowId != null && windowId.isNotEmpty) {
        _ensureWindowClaimHeartbeat(windowId);
      }
      final persisted = (event as web.PageTransitionEvent).persisted;
      _emitLifecycleEvent('pageshow', <String, Object?>{
        'persisted': persisted,
      });
    }).toJS,
  );

  web.document.addEventListener(
    'visibilitychange',
    ((web.Event _) {
      final state = web.document.visibilityState;
      _emitLifecycleEvent('visibilitychange', <String, Object?>{
        'state': state,
      });
      if (state == 'hidden') {
        final windowId = _claimedWindowId;
        if (windowId != null && windowId.isNotEmpty) {
          _writeWindowClaim(windowId);
        }
        _persistLatestCriticalSnapshot();
      }
    }).toJS,
  );

  web.window.addEventListener(
    'pagehide',
    ((web.Event event) {
      final persisted = (event as web.PageTransitionEvent).persisted;
      _emitLifecycleEvent('pagehide', <String, Object?>{
        'persisted': persisted,
      });
      _persistLatestCriticalSnapshot();
      _markWindowClaimClosing();
    }).toJS,
  );

  web.window.addEventListener(
    'beforeunload',
    ((web.Event _) {
      _emitLifecycleEvent('beforeunload', const <String, Object?>{});
      _persistLatestCriticalSnapshot();
      _markWindowClaimClosing();
    }).toJS,
  );

  web.document.addEventListener(
    'freeze',
    ((web.Event _) {
      _emitLifecycleEvent('freeze', const <String, Object?>{});
      final windowId = _claimedWindowId;
      if (windowId != null && windowId.isNotEmpty) {
        _writeWindowClaim(windowId);
      }
      _persistLatestCriticalSnapshot();
    }).toJS,
  );
}

void installWebLifecycleLogging(WebLifecycleLogger onEvent) {
  if (!_lifecycleLoggers.contains(onEvent)) {
    _lifecycleLoggers.add(onEvent);
  }
  _ensureLifecycleListenersInstalled();
}

void registerCriticalSnapshotWindow(String windowId) {
  final normalized = windowId.trim();
  if (normalized.isEmpty) {
    return;
  }
  _criticalSnapshotWindowId = normalized;
  _latestCriticalSnapshot = readCriticalSnapshot(normalized);
  _ensureLifecycleListenersInstalled();
}

String? readCriticalSnapshot(String windowId) {
  final normalized = windowId.trim();
  if (normalized.isEmpty) {
    return null;
  }
  try {
    return web.window.localStorage
        .getItem(_criticalSnapshotStorageKey(normalized))
        ?.trim();
  } catch (_) {
    return null;
  }
}

void updateCriticalSnapshot(String windowId, String? serialized) {
  final normalized = windowId.trim();
  if (normalized.isEmpty) {
    return;
  }
  _criticalSnapshotWindowId = normalized;
  _latestCriticalSnapshot = serialized?.trim().isEmpty ?? true
      ? null
      : serialized;
  _ensureLifecycleListenersInstalled();
  _persistLatestCriticalSnapshot();
}

void clearCriticalSnapshot(String windowId) {
  final normalized = windowId.trim();
  if (normalized.isEmpty) {
    return;
  }
  if (_criticalSnapshotWindowId == normalized) {
    _latestCriticalSnapshot = null;
  }
  try {
    web.window.localStorage.removeItem(_criticalSnapshotStorageKey(normalized));
  } catch (_) {
    // Best-effort only on web.
  }
}

String? readLatestCriticalSnapshot(String userId) {
  final normalized = userId.trim();
  if (normalized.isEmpty) {
    return null;
  }
  try {
    return web.window.localStorage
        .getItem(_latestCriticalSnapshotStorageKey(normalized))
        ?.trim();
  } catch (_) {
    return null;
  }
}

void updateLatestCriticalSnapshot(String userId, String? serialized) {
  final normalized = userId.trim();
  if (normalized.isEmpty) {
    return;
  }
  try {
    if (serialized == null || serialized.trim().isEmpty) {
      web.window.localStorage.removeItem(
        _latestCriticalSnapshotStorageKey(normalized),
      );
    } else {
      web.window.localStorage.setItem(
        _latestCriticalSnapshotStorageKey(normalized),
        serialized,
      );
    }
  } catch (_) {
    // Best-effort only on web.
  }
}

void clearLatestCriticalSnapshot(String userId) {
  final normalized = userId.trim();
  if (normalized.isEmpty) {
    return;
  }
  try {
    web.window.localStorage.removeItem(
      _latestCriticalSnapshotStorageKey(normalized),
    );
  } catch (_) {
    // Best-effort only on web.
  }
}

String? readPlatformLastActiveUserId() {
  try {
    final raw = web.window.localStorage
        .getItem(_lastActiveUserStorageKey)
        ?.trim();
    return raw == null || raw.isEmpty ? null : raw;
  } catch (_) {
    return null;
  }
}

void updatePlatformLastActiveUserId(String? userId) {
  final normalized = userId?.trim();
  try {
    if (normalized == null || normalized.isEmpty) {
      web.window.localStorage.removeItem(_lastActiveUserStorageKey);
    } else {
      web.window.localStorage.setItem(_lastActiveUserStorageKey, normalized);
    }
  } catch (_) {
    // Best-effort only on web.
  }
}
