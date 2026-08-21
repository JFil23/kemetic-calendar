import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/user_events_repo.dart';
import '../features/calendar/calendar_invalidation.dart';
import '../features/settings/settings_prefs.dart';
import '../telemetry/telemetry.dart';

const _channelName = 'com.kemetic.calendar/sync';
const _permissionRetryCooldown = Duration(hours: 12);
const _autoStartSyncCooldown = Duration(minutes: 2);
const _fallbackPollInterval = Duration(minutes: 15);
const _nativeChangeDebounce = Duration(seconds: 2);
const _defaultPastSyncCoverage = Duration(days: 365);
const _defaultFutureSyncCoverage = Duration(days: 365 * 2);

@visibleForTesting
DateTime? parseCalendarSyncTimestamp(dynamic raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

@visibleForTesting
bool shouldBackOffCalendarPermissionRequest({
  required DateTime now,
  DateTime? lastPermissionDeniedAt,
  Duration cooldown = _permissionRetryCooldown,
}) {
  if (lastPermissionDeniedAt == null) return false;
  return now.difference(lastPermissionDeniedAt) < cooldown;
}

@visibleForTesting
bool shouldSkipCalendarAutoStartSync({
  required DateTime now,
  DateTime? lastSyncAt,
  Duration cooldown = _autoStartSyncCooldown,
}) {
  if (lastSyncAt == null) return false;
  return now.difference(lastSyncAt) < cooldown;
}

bool isImportedDeviceCalendarEvent({String? clientEventId, String? category}) {
  final cid = clientEventId?.trim().toLowerCase() ?? '';
  if (cid.startsWith('native:')) {
    return true;
  }
  final normalizedCategory = category?.trim().toLowerCase() ?? '';
  return normalizedCategory == 'native_sync';
}

String _calendarSyncCidSummary(String? cid) {
  final length = cid?.trim().length ?? 0;
  return length == 0 ? '<none>' : '<redacted chars=$length>';
}

String _calendarSyncTitleSummary(String? title) {
  final length = title?.trim().length ?? 0;
  return '<redacted chars=$length>';
}

String _calendarSyncNativeSummary(String cid, NativeCalendarEvent native) {
  return 'cid=${_calendarSyncCidSummary(cid)} '
      'title=${_calendarSyncTitleSummary(native.title)}';
}

String _calendarSyncError(Object error) => redactLogText(error.toString());

@immutable
class CalendarSyncStatus {
  const CalendarSyncStatus({
    this.lastSyncAt,
    this.lastPermissionDeniedAt,
    this.lastResetAt,
  });

  final DateTime? lastSyncAt;
  final DateTime? lastPermissionDeniedAt;
  final DateTime? lastResetAt;
}

enum CalendarSyncRunState {
  synced,
  unlinked,
  permissionDenied,
  skippedWeb,
  skippedNoSession,
  skippedInProgress,
  skippedPermissionBackoff,
  failed,
}

@immutable
class CalendarSyncRunResult {
  const CalendarSyncRunResult._(
    this.state, {
    this.error,
    this.changesApplied = 0,
  });

  const CalendarSyncRunResult.synced({int changesApplied = 0})
    : this._(CalendarSyncRunState.synced, changesApplied: changesApplied);

  const CalendarSyncRunResult.unlinked()
    : this._(CalendarSyncRunState.unlinked);

  const CalendarSyncRunResult.permissionDenied()
    : this._(CalendarSyncRunState.permissionDenied);

  const CalendarSyncRunResult.skippedWeb()
    : this._(CalendarSyncRunState.skippedWeb);

  const CalendarSyncRunResult.skippedNoSession()
    : this._(CalendarSyncRunState.skippedNoSession);

  const CalendarSyncRunResult.skippedInProgress()
    : this._(CalendarSyncRunState.skippedInProgress);

  const CalendarSyncRunResult.skippedPermissionBackoff()
    : this._(CalendarSyncRunState.skippedPermissionBackoff);

  const CalendarSyncRunResult.failed(Object error)
    : this._(CalendarSyncRunState.failed, error: error);

  final CalendarSyncRunState state;
  final Object? error;
  final int changesApplied;

  bool get didSync => state == CalendarSyncRunState.synced;
  bool get changedAnything => changesApplied > 0;
}

@immutable
class CalendarSyncResetResult {
  const CalendarSyncResetResult({
    required this.removedImportedEvents,
    required this.completed,
  });

  final int removedImportedEvents;
  final bool completed;

  bool get changedAnything => removedImportedEvents > 0;
}

bool _isAppOwnedCid(String cid) {
  final c = cid.trim().toLowerCase();
  return c.startsWith('reminder:') ||
      c.startsWith('nutrition:') ||
      c.startsWith('holiday:') ||
      c.startsWith('ky=');
}

bool _hasAppOwnedMarker(NativeCalendarEvent native) {
  final desc = native.description?.toLowerCase() ?? '';
  return desc.contains('kemet_cid:');
}

/// Represents a native calendar event returned from iOS EventKit / Android Calendar Provider.
@immutable
class NativeCalendarEvent {
  final String? nativeId;
  final String title;
  final String? description;
  final String? location;
  final bool allDay;
  final DateTime start;
  final DateTime? end;
  final String? calendarId;
  final String? timeZone;
  final DateTime? lastModified;
  final String? clientEventId;
  final String source;

  const NativeCalendarEvent({
    required this.nativeId,
    required this.title,
    required this.description,
    required this.location,
    required this.allDay,
    required this.start,
    required this.end,
    required this.calendarId,
    required this.timeZone,
    required this.lastModified,
    required this.clientEventId,
    required this.source,
  });

  NativeCalendarEvent copyWith({
    String? nativeId,
    String? title,
    String? description,
    String? location,
    bool? allDay,
    DateTime? start,
    DateTime? end,
    String? calendarId,
    String? timeZone,
    DateTime? lastModified,
    String? clientEventId,
  }) {
    return NativeCalendarEvent(
      nativeId: nativeId ?? this.nativeId,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      allDay: allDay ?? this.allDay,
      start: start ?? this.start,
      end: end ?? this.end,
      calendarId: calendarId ?? this.calendarId,
      timeZone: timeZone ?? this.timeZone,
      lastModified: lastModified ?? this.lastModified,
      clientEventId: clientEventId ?? this.clientEventId,
      source: source,
    );
  }

  String get fingerprint => _fingerprint(
    title: title,
    start: start,
    end: end,
    allDay: allDay,
    location: location,
    description: description,
  );

  static NativeCalendarEvent fromMap(
    Map<dynamic, dynamic> raw, {
    required String source,
  }) {
    DateTime parseMs(dynamic v) {
      final num? n = v as num?;
      return DateTime.fromMillisecondsSinceEpoch(
        (n?.toInt() ?? 0),
        isUtc: false,
      );
    }

    final desc = raw['description'] as String?;
    final extractedCid = raw['clientEventId'] as String?;

    return NativeCalendarEvent(
      nativeId: raw['eventId']?.toString(),
      title: (raw['title'] as String?) ?? '',
      description: desc,
      location: raw['location'] as String?,
      allDay: (raw['allDay'] as bool?) ?? false,
      start: parseMs(raw['start']),
      end: raw['end'] == null ? null : parseMs(raw['end']),
      calendarId: raw['calendarId']?.toString(),
      timeZone: raw['timeZone'] as String?,
      lastModified: raw['lastModified'] == null
          ? null
          : parseMs(raw['lastModified']),
      clientEventId: extractedCid,
      source: source,
    );
  }
}

/// Simple cache entry persisted in Hive to avoid duplicate writes.
class _SyncCacheEntry {
  final String? nativeId;
  final String? nativeCalendarId;
  final DateTime? nativeModified;
  final DateTime? supabaseUpdated;
  final String? nativeFingerprint;
  final String? supabaseFingerprint;

  _SyncCacheEntry({
    this.nativeId,
    this.nativeCalendarId,
    this.nativeModified,
    this.supabaseUpdated,
    this.nativeFingerprint,
    this.supabaseFingerprint,
  });

  Map<String, dynamic> toJson() => {
    'nativeId': nativeId,
    'nativeCalendarId': nativeCalendarId,
    'nativeModified': nativeModified?.toIso8601String(),
    'supabaseUpdated': supabaseUpdated?.toIso8601String(),
    'nativeFingerprint': nativeFingerprint,
    'supabaseFingerprint': supabaseFingerprint,
  };
}

/// Platform bridge wrapper around the method channel.
class CalendarPlatformBridge {
  CalendarPlatformBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName) {
    _channel.setMethodCallHandler(_handleNativeMethodCall);
  }

  final MethodChannel _channel;
  final StreamController<void> _calendarChanges =
      StreamController<void>.broadcast();

  Stream<void> get calendarChanges => _calendarChanges.stream;

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'calendarChanged' && !_calendarChanges.isClosed) {
      _calendarChanges.add(null);
    }
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermissions');
      return granted ?? false;
    } catch (e) {
      debugPrint(
        '[calendar-sync] requestPermissions error: ${_calendarSyncError(e)}',
      );
      return false;
    }
  }

  Future<bool> hasPermissions() async {
    if (kIsWeb) return false;
    try {
      final granted = await _channel.invokeMethod<bool>('hasPermissions');
      return granted ?? false;
    } catch (e) {
      debugPrint(
        '[calendar-sync] hasPermissions error: ${_calendarSyncError(e)}',
      );
      return false;
    }
  }

  Future<void> startMonitoring() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('startMonitoring');
    } catch (e) {
      debugPrint(
        '[calendar-sync] startMonitoring error: ${_calendarSyncError(e)}',
      );
    }
  }

  Future<void> stopMonitoring() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('stopMonitoring');
    } catch (e) {
      debugPrint(
        '[calendar-sync] stopMonitoring error: ${_calendarSyncError(e)}',
      );
    }
  }

  Future<List<NativeCalendarEvent>> fetchEvents(
    DateTime start,
    DateTime end,
  ) async {
    if (kIsWeb) return const [];
    try {
      final res = await _channel.invokeMethod<List<dynamic>>('fetchEvents', {
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
      });
      final platform = _platformLabel();
      return (res ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => NativeCalendarEvent.fromMap(m, source: platform))
          .toList();
    } catch (e) {
      debugPrint('[calendar-sync] fetchEvents error: ${_calendarSyncError(e)}');
      rethrow;
    }
  }

  Future<void> dispose() async {
    await stopMonitoring();
    _channel.setMethodCallHandler(null);
    await _calendarChanges.close();
  }
}

abstract class CalendarSyncEventStore {
  Future<UserEvent> upsertByClientId({
    required String clientEventId,
    required String title,
    required DateTime startsAtUtc,
    String? detail,
    String? location,
    bool allDay,
    DateTime? endsAtUtc,
    String? category,
    String? caller,
  });

  Future<UserEvent> update({
    required String id,
    String? title,
    String? detail,
    String? location,
    bool? allDay,
    DateTime? startsAt,
    DateTime? endsAt,
  });

  Future<List<UserEvent>> getEventsForWindow({
    required DateTime startUtc,
    required DateTime endUtc,
    int limit,
  });

  Future<void> deleteByClientId(
    String clientEventId, {
    String semantic,
    bool suppressesClient,
    String sourceFeature,
    String deleteScope,
  });

  Future<void> deleteByClientIdPrefix(
    String prefix, {
    String semantic,
    bool suppressesClient,
    String sourceFeature,
    String deleteScope,
  });

  Future<void> deleteByCategory(
    String category, {
    String semantic,
    bool suppressesClient,
    String sourceFeature,
    String deleteScope,
  });
}

class UserEventsCalendarSyncStore implements CalendarSyncEventStore {
  UserEventsCalendarSyncStore(this._repo);

  final UserEventsRepo _repo;

  @override
  Future<UserEvent> upsertByClientId({
    required String clientEventId,
    required String title,
    required DateTime startsAtUtc,
    String? detail,
    String? location,
    bool allDay = false,
    DateTime? endsAtUtc,
    String? category,
    String? caller,
  }) async {
    await _repo.clearNativeCalendarImportSuppression(clientEventId);
    return _repo.upsertByClientId(
      clientEventId: clientEventId,
      title: title,
      startsAtUtc: startsAtUtc,
      detail: detail,
      location: location,
      allDay: allDay,
      endsAtUtc: endsAtUtc,
      category: category,
      caller: caller,
    );
  }

  @override
  Future<UserEvent> update({
    required String id,
    String? title,
    String? detail,
    String? location,
    bool? allDay,
    DateTime? startsAt,
    DateTime? endsAt,
  }) => _repo.update(
    id: id,
    title: title,
    detail: detail,
    location: location,
    allDay: allDay,
    startsAt: startsAt,
    endsAt: endsAt,
  );

  @override
  Future<List<UserEvent>> getEventsForWindow({
    required DateTime startUtc,
    required DateTime endUtc,
    int limit = 2000,
  }) => _repo.getEventsForWindow(
    startUtc: startUtc,
    endUtc: endUtc,
    limit: limit,
  );

  @override
  Future<void> deleteByClientId(
    String clientEventId, {
    String semantic = 'native_calendar_prune',
    bool suppressesClient = false,
    String sourceFeature = 'CalendarSyncService',
    String deleteScope = 'native_missing_from_device',
  }) async {
    await _repo.deleteByClientId(
      clientEventId,
      semantic: semantic,
      suppressesClient: suppressesClient,
      sourceFeature: sourceFeature,
      deleteScope: deleteScope,
    );
  }

  @override
  Future<void> deleteByClientIdPrefix(
    String prefix, {
    String semantic = 'native_calendar_unlink',
    bool suppressesClient = false,
    String sourceFeature = 'CalendarSyncService',
    String deleteScope = 'native_client_id_prefix',
  }) => _repo.deleteByClientIdPrefix(
    prefix,
    semantic: semantic,
    suppressesClient: suppressesClient,
    sourceFeature: sourceFeature,
    deleteScope: deleteScope,
  );

  @override
  Future<void> deleteByCategory(
    String category, {
    String semantic = 'native_calendar_unlink',
    bool suppressesClient = false,
    String sourceFeature = 'CalendarSyncService',
    String deleteScope = 'native_sync_category',
  }) => _repo.deleteByCategory(
    category,
    semantic: semantic,
    suppressesClient: suppressesClient,
    sourceFeature: sourceFeature,
    deleteScope: deleteScope,
  );
}

// Shared instance helper so multiple screens reuse the same sync engine/timer.
CalendarSyncService? _singleton;

CalendarSyncService sharedCalendarSyncService(
  SupabaseClient client, {
  CalendarPlatformBridge? platform,
}) {
  _singleton ??= CalendarSyncService(client, platform: platform);
  return _singleton!;
}

Future<void> disposeSharedCalendarSyncService() async {
  await _singleton?.dispose();
  _singleton = null;
}

/// Sync engine that imports native device-calendar events into the app.
class CalendarSyncService {
  CalendarSyncService(
    this._client, {
    CalendarPlatformBridge? platform,
    DateTime Function()? now,
    @visibleForTesting CalendarSyncEventStore? eventsStore,
    @visibleForTesting Duration nativeChangeDebounce = _nativeChangeDebounce,
  }) : _platform = platform ?? CalendarPlatformBridge(),
       _now = now ?? DateTime.now,
       _eventsRepo =
           eventsStore ?? UserEventsCalendarSyncStore(UserEventsRepo(_client)),
       _nativeChangeDebounceDuration = nativeChangeDebounce;

  final SupabaseClient _client;
  final CalendarPlatformBridge _platform;
  final DateTime Function() _now;
  final CalendarSyncEventStore _eventsRepo;
  final Duration _nativeChangeDebounceDuration;

  static const _cacheBoxName = 'calendar_sync.cache.v1';
  static const _stateBoxName = 'calendar_sync.state.v1';
  static const _lastResetKey = 'lastReset';

  Box<dynamic>? _cacheBox;
  Box<dynamic>? _stateBox;
  bool _initialized = false;
  bool _started = false;
  bool _syncing = false;
  Future<void>? _startFuture;
  Timer? _timer;
  Timer? _changeDebounceTimer;
  StreamSubscription<void>? _calendarChangeSubscription;

  Future<void> ensureInitialized() async {
    if (kIsWeb) return;
    if (_initialized &&
        (_cacheBox?.isOpen ?? false) &&
        (_stateBox?.isOpen ?? false)) {
      return;
    }
    _initialized = false;
    if (!Hive.isBoxOpen(_cacheBoxName) && !Hive.isBoxOpen(_stateBoxName)) {
      try {
        await Hive.initFlutter();
      } catch (_) {
        // Hive may already be initialized elsewhere; safe to continue.
      }
    }
    _cacheBox = await Hive.openBox<dynamic>(_cacheBoxName);
    _stateBox = await Hive.openBox<dynamic>(_stateBoxName);
    _initialized = true;
  }

  Future<void> start() async {
    if (kIsWeb) return;
    final inFlight = _startFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    _startFuture = _startInternal();
    try {
      await _startFuture;
    } finally {
      _startFuture = null;
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _changeDebounceTimer?.cancel();
    _changeDebounceTimer = null;
    unawaited(_calendarChangeSubscription?.cancel());
    _calendarChangeSubscription = null;
    unawaited(_platform.stopMonitoring());
    _started = false;
    _startFuture = null;
  }

  Future<void> dispose() async {
    stop();
    final cacheBox = _cacheBox;
    final stateBox = _stateBox;
    _cacheBox = null;
    _stateBox = null;
    _initialized = false;
    if (cacheBox?.isOpen ?? false) {
      await cacheBox?.close();
    }
    if (stateBox?.isOpen ?? false) {
      await stateBox?.close();
    }
    await _platform.dispose();
  }

  Future<CalendarSyncRunResult> syncWindowIfActive({
    required DateTime windowStart,
    required DateTime windowEnd,
  }) async {
    if (!_started) return const CalendarSyncRunResult.unlinked();
    return sync(windowStart: windowStart, windowEnd: windowEnd);
  }

  Future<CalendarSyncStatus> getStatus() async {
    if (kIsWeb) return const CalendarSyncStatus();
    await ensureInitialized();
    return CalendarSyncStatus(
      lastSyncAt: parseCalendarSyncTimestamp(_stateBox?.get('lastSync')),
      lastPermissionDeniedAt: parseCalendarSyncTimestamp(
        _stateBox?.get('lastPermissionDenied'),
      ),
      lastResetAt: parseCalendarSyncTimestamp(_stateBox?.get(_lastResetKey)),
    );
  }

  Future<CalendarSyncRunResult> sync({
    DateTime? windowStart,
    DateTime? windowEnd,
    bool interactive = false,
  }) async {
    if (kIsWeb) return const CalendarSyncRunResult.skippedWeb();
    if (_syncing) return const CalendarSyncRunResult.skippedInProgress();
    if (_client.auth.currentSession == null) {
      return const CalendarSyncRunResult.skippedNoSession();
    }

    await ensureInitialized();

    final now = _now();
    final lastPermissionDeniedAt = parseCalendarSyncTimestamp(
      _stateBox?.get('lastPermissionDenied'),
    );
    if (!interactive &&
        shouldBackOffCalendarPermissionRequest(
          now: now,
          lastPermissionDeniedAt: lastPermissionDeniedAt,
        )) {
      if (kDebugMode) {
        debugPrint('[calendar-sync] skip permission retry (recent denial)');
      }
      return const CalendarSyncRunResult.skippedPermissionBackoff();
    }

    final start = windowStart ?? now.subtract(_defaultPastSyncCoverage);
    final end = windowEnd ?? now.add(_defaultFutureSyncCoverage);
    if (!end.isAfter(start)) {
      return CalendarSyncRunResult.failed(
        ArgumentError('Calendar sync window end must follow its start.'),
      );
    }

    _syncing = true;
    try {
      final granted = interactive
          ? await _platform.requestPermissions()
          : await _platform.hasPermissions();
      if (!granted) {
        if (interactive) {
          await _stateBox?.put('lastPermissionDenied', now.toIso8601String());
        }
        return const CalendarSyncRunResult.permissionDenied();
      }
      await _stateBox?.delete('lastPermissionDenied');

      final nativeEvents = await _platform.fetchEvents(start, end);
      final supabaseEvents = await _loadSupabaseEvents(start, end);

      final nativeByCid = <String, NativeCalendarEvent>{};
      for (final e in nativeEvents) {
        final cid = _resolveCid(e);
        if (cid == null) continue;
        nativeByCid[cid] = e.copyWith(clientEventId: cid);
      }

      final supByCid = <String, UserEvent>{};
      for (final e in supabaseEvents) {
        final cid = e.clientEventId;
        if (cid == null || cid.isEmpty) continue;
        supByCid[cid] = e;
      }

      final importedChanges = await _mergeNativeIntoSupabase(
        nativeByCid,
        supByCid,
      );
      final removedChanges = await _removeStaleSupabaseNativeImports(
        nativeByCid,
        supByCid,
      );
      final changesApplied = importedChanges + removedChanges;

      await _stateBox?.put('lastSync', _now().toIso8601String());
      if (changesApplied > 0) {
        CalendarInvalidationBus.instance.publish(
          const CalendarInvalidated(
            reason: CalendarInvalidationReason.calendarImportSynced,
          ),
        );
      }
      return CalendarSyncRunResult.synced(changesApplied: changesApplied);
    } catch (e, st) {
      debugPrint('[calendar-sync] sync failed: ${_calendarSyncError(e)}');
      debugPrint(redactLogText('$st'));
      return CalendarSyncRunResult.failed(e);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _startInternal() async {
    if (_started) return;

    await ensureInitialized();
    if (!await _platform.hasPermissions()) return;

    _calendarChangeSubscription ??= _platform.calendarChanges.listen((_) {
      _changeDebounceTimer?.cancel();
      _changeDebounceTimer = Timer(_nativeChangeDebounceDuration, () {
        _changeDebounceTimer = null;
        if (_started) unawaited(sync());
      });
    });
    await _platform.startMonitoring();
    _timer ??= Timer.periodic(_fallbackPollInterval, (_) {
      unawaited(sync());
    });
    _started = true;

    final lastSyncAt = parseCalendarSyncTimestamp(_stateBox?.get('lastSync'));
    if (shouldSkipCalendarAutoStartSync(now: _now(), lastSyncAt: lastSyncAt)) {
      if (kDebugMode) {
        debugPrint('[calendar-sync] skip auto-start sync (recent sync found)');
      }
      return;
    }

    await sync();
  }

  /* ───────────────────────── Merging helpers ───────────────────────── */

  Future<int> _mergeNativeIntoSupabase(
    Map<String, NativeCalendarEvent> nativeByCid,
    Map<String, UserEvent> supByCid,
  ) async {
    var changesApplied = 0;
    for (final entry in nativeByCid.entries) {
      final cid = entry.key;
      final native = entry.value;
      final sup = supByCid[cid];

      final nativeFingerprint = native.fingerprint;
      final nativeModified = native.lastModified ?? native.start;
      final supFingerprint = sup == null ? null : _fingerprintFromSupabase(sup);
      final supUpdated =
          sup?.updatedAt ??
          sup?.startsAt ??
          DateTime.fromMillisecondsSinceEpoch(0);

      if (_isAppOwnedCid(cid) || _hasAppOwnedMarker(native)) {
        debugPrint(
          '[calendar-sync] skip app-owned '
          '${_calendarSyncNativeSummary(cid, native)}',
        );
        continue;
      }

      if (!cid.startsWith('native:')) {
        debugPrint(
          '[calendar-sync] skip non-native '
          '${_calendarSyncNativeSummary(cid, native)}',
        );
        continue;
      }

      if (sup == null) {
        await _eventsRepo.upsertByClientId(
          clientEventId: cid,
          title: native.title,
          startsAtUtc: native.start.toUtc(),
          detail: native.description,
          location: native.location,
          allDay: native.allDay,
          endsAtUtc: native.end?.toUtc(),
          category: 'native_sync',
          caller: 'native_sync',
        );
        changesApplied += 1;
      } else if (nativeFingerprint != supFingerprint) {
        await _eventsRepo.update(
          id: sup.id,
          title: native.title,
          detail: native.description,
          location: native.location,
          allDay: native.allDay,
          startsAt: native.start.toUtc(),
          endsAt: native.end?.toUtc(),
        );
        changesApplied += 1;
      }

      _writeCache(
        cid,
        _SyncCacheEntry(
          nativeId: native.nativeId,
          nativeCalendarId: native.calendarId,
          nativeModified: nativeModified,
          supabaseUpdated: supUpdated,
          nativeFingerprint: nativeFingerprint,
          supabaseFingerprint: supFingerprint,
        ),
      );
    }
    return changesApplied;
  }

  /* ───────────────────────── Utilities ───────────────────────── */

  Future<CalendarSyncResetResult> unlinkImportedCalendarData() async {
    if (kIsWeb) {
      return const CalendarSyncResetResult(
        removedImportedEvents: 0,
        completed: false,
      );
    }

    await ensureInitialized();
    stop();

    final user = _client.auth.currentUser;
    if (user == null) {
      return const CalendarSyncResetResult(
        removedImportedEvents: 0,
        completed: false,
      );
    }

    final removedImported = await _purgeImportedNativeEventsFromSupabase();

    await _clearSyncState();
    await SettingsPrefs.setAutoCalendarSyncEnabled(false);
    await _stateBox?.put(_lastResetKey, _now().toIso8601String());
    if (removedImported > 0) {
      CalendarInvalidationBus.instance.publish(
        const CalendarInvalidated(
          reason: CalendarInvalidationReason.calendarImportSynced,
        ),
      );
    }

    return CalendarSyncResetResult(
      removedImportedEvents: removedImported,
      completed: true,
    );
  }

  Future<int> _purgeImportedNativeEventsFromSupabase() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;

    var deleted = 0;
    try {
      final rowsByCid = await _client
          .from('user_events')
          .select('id')
          .eq('user_id', user.id)
          .like('client_event_id', 'native:%');
      await _eventsRepo.deleteByClientIdPrefix(
        'native:',
        semantic: 'native_calendar_unlink',
        suppressesClient: false,
        sourceFeature:
            'CalendarSyncService._purgeImportedNativeEventsFromSupabase',
        deleteScope: 'native_client_id_prefix',
      );
      deleted += (rowsByCid as List).length;
    } catch (e) {
      debugPrint(
        '[calendar-sync] purge imported native rows by cid failed: '
        '${_calendarSyncError(e)}',
      );
    }

    try {
      final rowsByCategory = await _client
          .from('user_events')
          .select('id')
          .eq('user_id', user.id)
          .eq('category', 'native_sync');
      await _eventsRepo.deleteByCategory(
        'native_sync',
        semantic: 'native_calendar_unlink',
        suppressesClient: false,
        sourceFeature:
            'CalendarSyncService._purgeImportedNativeEventsFromSupabase',
        deleteScope: 'native_sync_category',
      );
      deleted += (rowsByCategory as List).length;
    } catch (e) {
      debugPrint(
        '[calendar-sync] purge imported native rows by category failed: '
        '${_calendarSyncError(e)}',
      );
    }

    return deleted;
  }

  Future<void> _clearSyncState() async {
    await _cacheBox?.clear();

    final keys = (_stateBox?.keys ?? const <dynamic>[])
        .map((key) => key.toString())
        .toList();
    for (final key in keys) {
      if (key == 'lastSync' ||
          key == 'lastPermissionDenied' ||
          key.startsWith('cid-for-native-')) {
        await _stateBox?.delete(key);
      }
    }
  }

  Future<int> _removeStaleSupabaseNativeImports(
    Map<String, NativeCalendarEvent> nativeByCid,
    Map<String, UserEvent> supByCid,
  ) async {
    var changesApplied = 0;
    for (final entry in supByCid.entries) {
      final cid = entry.key;
      final sup = entry.value;
      final isImportedNative = isImportedDeviceCalendarEvent(
        clientEventId: cid,
        category: sup.category,
      );
      if (!isImportedNative) continue;
      if (nativeByCid.containsKey(cid)) continue;

      try {
        await _eventsRepo.deleteByClientId(
          cid,
          semantic: 'native_calendar_prune',
          suppressesClient: false,
          sourceFeature:
              'CalendarSyncService._removeStaleSupabaseNativeImports',
          deleteScope: 'native_missing_from_device',
        );
        debugPrint(
          '[calendar-sync] deleted stale imported event '
          'cid=${_calendarSyncCidSummary(cid)}',
        );
        changesApplied += 1;
      } catch (e) {
        debugPrint(
          '[calendar-sync] delete stale imported event failed '
          'cid=${_calendarSyncCidSummary(cid)} err=${_calendarSyncError(e)}',
        );
      }
    }
    return changesApplied;
  }

  Future<List<UserEvent>> _loadSupabaseEvents(
    DateTime start,
    DateTime end,
  ) async {
    try {
      return await _eventsRepo.getEventsForWindow(
        startUtc: start.toUtc(),
        endUtc: end.toUtc(),
        limit: 2000,
      );
    } catch (e) {
      debugPrint(
        '[calendar-sync] supabase load failed: ${_calendarSyncError(e)}',
      );
      return const [];
    }
  }

  void _writeCache(String cid, _SyncCacheEntry entry) {
    final box = _cacheBox;
    if (box == null || !box.isOpen) return;
    unawaited(box.put(cid, entry.toJson()));
  }

  String? _resolveCid(NativeCalendarEvent e) {
    if (e.clientEventId != null && e.clientEventId!.isNotEmpty) {
      return e.clientEventId;
    }
    if (e.nativeId != null && e.nativeId!.isNotEmpty) {
      return 'native:${e.source}:${e.nativeId}';
    }
    return 'native:${e.source}:${e.fingerprint}';
  }
}

String _fingerprint({
  required String title,
  required DateTime start,
  DateTime? end,
  bool allDay = false,
  String? location,
  String? description,
}) {
  final sb = StringBuffer()
    ..write(title.trim())
    ..write('|')
    ..write(start.toUtc().millisecondsSinceEpoch)
    ..write('|')
    ..write((end ?? start).toUtc().millisecondsSinceEpoch)
    ..write('|')
    ..write(allDay ? '1' : '0')
    ..write('|')
    ..write((location ?? '').trim())
    ..write('|')
    ..write((description ?? '').trim());
  return base64Url.encode(utf8.encode(sb.toString()));
}

String _fingerprintFromSupabase(UserEvent e) {
  return _fingerprint(
    title: e.title,
    start: e.startsAt,
    end: e.endsAt,
    allDay: e.allDay,
    location: e.location,
    description: e.detail,
  );
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
