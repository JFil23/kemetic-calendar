import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/user_events_repo.dart';

const _channelName = 'com.kemetic.calendar/sync';
const _permissionRetryCooldown = Duration(hours: 12);
const _autoStartSyncCooldown = Duration(minutes: 2);

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

@immutable
class CalendarSyncStatus {
  const CalendarSyncStatus({this.lastSyncAt, this.lastPermissionDeniedAt});

  final DateTime? lastSyncAt;
  final DateTime? lastPermissionDeniedAt;
}

enum CalendarSyncRunState {
  synced,
  permissionDenied,
  skippedWeb,
  skippedNoSession,
  skippedInProgress,
  skippedPermissionBackoff,
  failed,
}

@immutable
class CalendarSyncRunResult {
  const CalendarSyncRunResult._(this.state, {this.error});

  const CalendarSyncRunResult.synced() : this._(CalendarSyncRunState.synced);

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

  bool get didSync => state == CalendarSyncRunState.synced;
}

bool _isLikelyHolidayTitle(String title) {
  final t = title.trim().toLowerCase();
  const holidayTokens = <String>[
    'new year',
    'new years',
    'new year\'s eve',
    'new years eve',
    'christmas eve',
    'martin luther king',
    'presidents day',
    'washington\'s birthday',
    'memorial day',
    'juneteenth',
    'independence day',
    'labor day',
    'indigenous',
    'veterans day',
    'thanksgiving',
    'christmas',
    'easter',
    'hanukkah',
    'diwali',
    'passover',
    'good friday',
    'mlk',
    'boxing day',
    'saint patrick',
    'patriots day',
    'rosh hashanah',
    'yom kippur',
    'eid',
    'ramadan',
    'lunar new year',
    'columbus day',
    'holi',
  ];
  return holidayTokens.any((token) => t.contains(token));
}

bool _looksLikeHolidayDescription(String? detail) {
  if (detail == null) return false;
  final d = detail.toLowerCase();
  return d.contains('public holiday') ||
      d.contains('observance') ||
      d.contains('bank holiday') ||
      d.contains('to hide observances');
}

bool _shouldImportNativeEvent(NativeCalendarEvent native) {
  if (_isHolidayLikeNative(native)) return false;
  return true;
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

String _normalizeTitleForCompare(String title) {
  final trimmed = title.trim().toLowerCase();
  return trimmed.replaceAll(RegExp(r'\s+'), ' ');
}

String _slugifyTitle(String title) {
  final normalized = _normalizeTitleForCompare(title);
  final slug = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return slug.replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
}

DateTime _localDay(DateTime dt) {
  final local = dt.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String _holidayKey(DateTime date, String title) {
  final day = _localDay(date);
  return '${day.toIso8601String()}|${_slugifyTitle(title)}';
}

bool _isHolidayLikeNative(NativeCalendarEvent native) {
  final src = native.source.toLowerCase();
  if (src.contains('holiday') || src.contains('observance')) {
    return true;
  }
  final calId = native.calendarId?.toLowerCase() ?? '';
  if (calId.contains('holiday') || calId.contains('observance')) {
    return true;
  }
  final titleLooksHoliday = _isLikelyHolidayTitle(native.title);
  if (titleLooksHoliday && native.allDay) {
    return true;
  }
  if (_looksLikeHolidayDescription(native.description)) {
    return true;
  }
  final title = native.title.toLowerCase();
  if (title.contains('observed') || title.contains('observance')) {
    return true;
  }
  return false;
}

bool _isHolidayLikeSup(UserEvent e) {
  final cid = e.clientEventId ?? '';
  if (cid.startsWith('holiday:')) return true;
  final category = e.category?.toLowerCase() ?? '';
  if (category.contains('holiday')) return true;
  if (e.allDay && _isLikelyHolidayTitle(e.title)) return true;
  final detail = e.detail?.toLowerCase() ?? '';
  if (detail.contains('holiday')) return true;
  return false;
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

  Map<String, dynamic> toMapForUpsert() {
    return {
      if (nativeId != null) 'eventId': nativeId,
      'title': title,
      'description': description ?? '',
      'location': location,
      'allDay': allDay,
      'start': start.millisecondsSinceEpoch,
      'end':
          (end ?? start.add(const Duration(hours: 1))).millisecondsSinceEpoch,
      'calendarId': calendarId,
      'timeZone': timeZone ?? DateTime.now().timeZoneName,
      'clientEventId': clientEventId,
    };
  }

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
    : _channel = channel ?? const MethodChannel(_channelName);

  final MethodChannel _channel;

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermissions');
      return granted ?? false;
    } catch (e) {
      debugPrint('[calendar-sync] requestPermissions error: $e');
      return false;
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
      debugPrint('[calendar-sync] fetchEvents error: $e');
      return const [];
    }
  }

  Future<String?> upsertEvent(NativeCalendarEvent event) async {
    if (kIsWeb) return null;
    try {
      final res = await _channel.invokeMethod<String>(
        'upsertEvent',
        event.toMapForUpsert(),
      );
      return res;
    } catch (e) {
      debugPrint('[calendar-sync] upsertEvent error: $e');
      return null;
    }
  }

  Future<bool> deleteEvent(String nativeId) async {
    if (kIsWeb) return false;
    try {
      final deleted = await _channel.invokeMethod<bool>('deleteEvent', {
        'eventId': nativeId,
      });
      return deleted ?? false;
    } catch (e) {
      debugPrint('[calendar-sync] deleteEvent error: $e');
      return false;
    }
  }
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

/// Sync engine that reconciles native calendars with the Supabase user_events table.
class CalendarSyncService {
  CalendarSyncService(
    this._client, {
    CalendarPlatformBridge? platform,
    DateTime Function()? now,
  }) : _platform = platform ?? CalendarPlatformBridge(),
       _now = now ?? DateTime.now,
       _eventsRepo = UserEventsRepo(_client);

  final SupabaseClient _client;
  final CalendarPlatformBridge _platform;
  final DateTime Function() _now;
  final UserEventsRepo _eventsRepo;

  static const _cacheBoxName = 'calendar_sync.cache.v1';
  static const _stateBoxName = 'calendar_sync.state.v1';
  static const _deletedCidsKey = 'deleted_cids';

  Box<dynamic>? _cacheBox;
  Box<dynamic>? _stateBox;
  bool _initialized = false;
  bool _started = false;
  bool _syncing = false;
  Future<void>? _startFuture;
  Timer? _timer;
  Set<String> _deletedCids = <String>{};

  Future<void> ensureInitialized() async {
    if (_initialized || kIsWeb) return;
    if (!Hive.isBoxOpen(_cacheBoxName) && !Hive.isBoxOpen(_stateBoxName)) {
      try {
        await Hive.initFlutter();
      } catch (_) {
        // Hive may already be initialized elsewhere; safe to continue.
      }
    }
    _cacheBox = await Hive.openBox<dynamic>(_cacheBoxName);
    _stateBox = await Hive.openBox<dynamic>(_stateBoxName);
    final rawDeleted = _stateBox?.get(_deletedCidsKey);
    if (rawDeleted is List) {
      _deletedCids = rawDeleted.whereType<String>().toSet();
    }
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
    _started = false;
    _startFuture = null;
  }

  Future<void> dispose() async {
    stop();
    await _cacheBox?.close();
    await _stateBox?.close();
    _initialized = false;
  }

  Future<CalendarSyncStatus> getStatus() async {
    if (kIsWeb) return const CalendarSyncStatus();
    await ensureInitialized();
    return CalendarSyncStatus(
      lastSyncAt: parseCalendarSyncTimestamp(_stateBox?.get('lastSync')),
      lastPermissionDeniedAt: parseCalendarSyncTimestamp(
        _stateBox?.get('lastPermissionDenied'),
      ),
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

    final start = windowStart ?? now.subtract(const Duration(days: 30));
    final end = windowEnd ?? now.add(const Duration(days: 180));

    _syncing = true;
    try {
      final granted = await _platform.requestPermissions();
      if (!granted) {
        await _stateBox?.put('lastPermissionDenied', now.toIso8601String());
        return const CalendarSyncRunResult.permissionDenied();
      }
      await _stateBox?.delete('lastPermissionDenied');

      final nativeEvents = await _platform.fetchEvents(start, end);
      final supabaseEvents = await _loadSupabaseEvents(start, end);
      final supWindowLimitHit = supabaseEvents.length >= 2000;
      final supHolidayKeys = _holidayKeysFromSupabase(supabaseEvents);
      final nativeHolidayKeys = _holidayKeysFromNative(nativeEvents);

      final nativeByCid = <String, NativeCalendarEvent>{};
      for (final e in nativeEvents) {
        final cid = _resolveCid(e);
        if (cid == null) continue;
        nativeByCid[cid] = e.copyWith(clientEventId: cid);
        if (e.nativeId != null) {
          _stateBox?.put('cid-for-native-${e.nativeId}', cid);
        }
      }

      final supByCid = <String, UserEvent>{};
      for (final e in supabaseEvents) {
        final cid = e.clientEventId;
        if (cid == null || cid.isEmpty) continue;
        supByCid[cid] = e;
      }

      await _mergeNativeIntoSupabase(nativeByCid, supByCid, supHolidayKeys);
      await _mergeSupabaseIntoNative(nativeByCid, supByCid, nativeHolidayKeys);
      await _removeStaleNativeEvents(
        nativeByCid,
        supByCid,
        suppressDeletes: supWindowLimitHit,
      );

      await _stateBox?.put('lastSync', _now().toIso8601String());
      return const CalendarSyncRunResult.synced();
    } catch (e, st) {
      debugPrint('[calendar-sync] sync failed: $e');
      debugPrint('$st');
      return CalendarSyncRunResult.failed(e);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _startInternal() async {
    if (_started) return;

    await ensureInitialized();
    _timer ??= Timer.periodic(const Duration(minutes: 15), (_) {
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

  Future<void> _mergeNativeIntoSupabase(
    Map<String, NativeCalendarEvent> nativeByCid,
    Map<String, UserEvent> supByCid,
    Set<String> supHolidayKeys,
  ) async {
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
      final nativeHolidayKey = _isHolidayLikeNative(native)
          ? _holidayKey(native.start, native.title)
          : null;

      if (!_shouldImportNativeEvent(native)) {
        debugPrint(
          '[calendar-sync] skip native holiday/observance cid=$cid title=${native.title}',
        );
        continue;
      }

      if (sup == null &&
          nativeHolidayKey != null &&
          supHolidayKeys.contains(nativeHolidayKey)) {
        debugPrint(
          '[calendar-sync] skip duplicate holiday from native cid=$cid title=${native.title}',
        );
        continue;
      }

      if (_isAppOwnedCid(cid) || _hasAppOwnedMarker(native)) {
        debugPrint(
          '[calendar-sync] skip app-owned cid=$cid title=${native.title}',
        );
        continue;
      }

      if (!cid.startsWith('native:')) {
        debugPrint(
          '[calendar-sync] skip non-native cid=$cid title=${native.title}',
        );
        continue;
      }

      if (sup == null && _deletedCids.contains(cid)) {
        debugPrint(
          '[calendar-sync] skipping upsert for deleted-in-app cid=$cid',
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
      } else if (nativeFingerprint != supFingerprint &&
          nativeModified.isAfter(supUpdated)) {
        await _eventsRepo.update(
          id: sup.id,
          title: native.title,
          detail: native.description,
          location: native.location,
          allDay: native.allDay,
          startsAt: native.start.toUtc(),
          endsAt: native.end?.toUtc(),
        );
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
  }

  Future<void> _mergeSupabaseIntoNative(
    Map<String, NativeCalendarEvent> nativeByCid,
    Map<String, UserEvent> supByCid,
    Set<String> nativeHolidayKeys,
  ) async {
    for (final entry in supByCid.entries) {
      final cid = entry.key;
      final sup = entry.value;
      final native = nativeByCid[cid];

      final supFingerprint = _fingerprintFromSupabase(sup);
      final supUpdated = sup.updatedAt ?? sup.startsAt;
      final supHolidayKey = _isHolidayLikeSup(sup)
          ? _holidayKey(sup.startsAt, sup.title)
          : null;

      if (native == null) {
        if (supHolidayKey != null &&
            nativeHolidayKeys.contains(supHolidayKey)) {
          debugPrint(
            '[calendar-sync] skip exporting holiday duplicate cid=$cid title=${sup.title}',
          );
          continue;
        }
        final created = await _platform.upsertEvent(
          _fromSupabase(sup, cid: cid),
        );
        _writeCache(
          cid,
          _SyncCacheEntry(
            nativeId: created,
            nativeCalendarId: null,
            nativeModified: DateTime.now(),
            supabaseUpdated: supUpdated,
            nativeFingerprint: supFingerprint,
            supabaseFingerprint: supFingerprint,
          ),
        );
        if (supHolidayKey != null) {
          nativeHolidayKeys.add(supHolidayKey);
        }
        continue;
      }

      final nativeFingerprint = native.fingerprint;
      final nativeModified = native.lastModified ?? native.start;

      final supNewer =
          supUpdated.isAfter(nativeModified) &&
          supFingerprint != nativeFingerprint;
      if (supNewer) {
        final updatedId = await _platform.upsertEvent(
          native.copyWith(
            title: sup.title,
            description: sup.detail,
            location: sup.location,
            allDay: sup.allDay,
            start: sup.startsAt.toLocal(),
            end:
                sup.endsAt?.toLocal() ??
                sup.startsAt.toLocal().add(const Duration(hours: 1)),
            clientEventId: cid,
          ),
        );
        _writeCache(
          cid,
          _SyncCacheEntry(
            nativeId: updatedId ?? native.nativeId,
            nativeCalendarId: native.calendarId,
            nativeModified: supUpdated,
            supabaseUpdated: supUpdated,
            nativeFingerprint: supFingerprint,
            supabaseFingerprint: supFingerprint,
          ),
        );
        if (supHolidayKey != null) {
          nativeHolidayKeys.add(supHolidayKey);
        }
      } else {
        // Cache the current state to avoid reprocessing unchanged rows.
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
    }
  }

  /* ───────────────────────── Utilities ───────────────────────── */

  Future<void> _removeStaleNativeEvents(
    Map<String, NativeCalendarEvent> nativeByCid,
    Map<String, UserEvent> supByCid, {
    bool suppressDeletes = false,
  }) async {
    if (suppressDeletes) {
      debugPrint('[calendar-sync] skip native cleanup (window at limit)');
      return;
    }
    for (final entry in nativeByCid.entries) {
      final cid = entry.key;
      final native = entry.value;
      if (!_isAppOwnedCid(cid) && !_hasAppOwnedMarker(native)) {
        continue;
      }
      if (supByCid.containsKey(cid)) continue;

      final nativeId = native.nativeId;
      if (nativeId == null || nativeId.isEmpty) continue;

      try {
        final deleted = await _platform.deleteEvent(nativeId);
        if (deleted) {
          _cacheBox?.delete(cid);
          _stateBox?.delete('cid-for-native-$nativeId');
          debugPrint(
            '[calendar-sync] deleted stale native event cid=$cid nativeId=$nativeId',
          );
        }
      } catch (e) {
        debugPrint(
          '[calendar-sync] delete native failed cid=$cid nativeId=$nativeId err=$e',
        );
      }
    }
  }

  Set<String> _holidayKeysFromSupabase(List<UserEvent> events) {
    final keys = <String>{};
    for (final e in events) {
      if (_isHolidayLikeSup(e)) {
        keys.add(_holidayKey(e.startsAt, e.title));
      }
    }
    return keys;
  }

  Set<String> _holidayKeysFromNative(List<NativeCalendarEvent> events) {
    final keys = <String>{};
    for (final e in events) {
      if (_isHolidayLikeNative(e)) {
        keys.add(_holidayKey(e.start, e.title));
      }
    }
    return keys;
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
      debugPrint('[calendar-sync] supabase load failed: $e');
      return const [];
    }
  }

  void _writeCache(String cid, _SyncCacheEntry entry) {
    _cacheBox?.put(cid, entry.toJson());
  }

  String? _resolveCid(NativeCalendarEvent e) {
    if (e.clientEventId != null && e.clientEventId!.isNotEmpty) {
      return e.clientEventId;
    }
    final cachedById = e.nativeId == null
        ? null
        : _stateBox?.get('cid-for-native-${e.nativeId}');
    if (cachedById is String && cachedById.isNotEmpty) return cachedById;
    if (e.nativeId != null && e.nativeId!.isNotEmpty) {
      return 'native:${e.source}:${e.nativeId}';
    }
    return 'native:${e.source}:${e.fingerprint}';
  }

  NativeCalendarEvent _fromSupabase(UserEvent e, {required String cid}) {
    final localStart = e.startsAt.toLocal();
    final localEnd = (e.endsAt ?? e.startsAt.add(const Duration(hours: 1)))
        .toLocal();
    return NativeCalendarEvent(
      nativeId: null,
      title: e.title,
      description: e.detail,
      location: e.location,
      allDay: e.allDay,
      start: localStart,
      end: localEnd,
      calendarId: null,
      timeZone: localStart.timeZoneName,
      lastModified: e.updatedAt ?? e.startsAt,
      clientEventId: cid,
      source: _platformLabel(),
    );
  }

  Future<void> recordDeletedInApp(String cid) async {
    if (cid.isEmpty || kIsWeb) return;
    await ensureInitialized();
    _deletedCids.add(cid);
    await _stateBox?.put(_deletedCidsKey, _deletedCids.toList());
    debugPrint('[calendar-sync] recorded deleted-in-app cid=$cid');
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
