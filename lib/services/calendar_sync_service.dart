import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/user_events_repo.dart';

const _channelName = 'com.kemetic.calendar/sync';

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
      'end': (end ?? start.add(const Duration(hours: 1))).millisecondsSinceEpoch,
      'calendarId': calendarId,
      'timeZone': timeZone ?? DateTime.now().timeZoneName,
      'clientEventId': clientEventId,
    };
  }

  static NativeCalendarEvent fromMap(Map<dynamic, dynamic> raw, {required String source}) {
    DateTime _parseMs(dynamic v) {
      final num? n = v as num?;
      return DateTime.fromMillisecondsSinceEpoch((n?.toInt() ?? 0), isUtc: false);
    }

    final desc = raw['description'] as String?;
    final extractedCid = raw['clientEventId'] as String?;

    return NativeCalendarEvent(
      nativeId: raw['eventId']?.toString(),
      title: (raw['title'] as String?) ?? '',
      description: desc,
      location: raw['location'] as String?,
      allDay: (raw['allDay'] as bool?) ?? false,
      start: _parseMs(raw['start']),
      end: raw['end'] == null ? null : _parseMs(raw['end']),
      calendarId: raw['calendarId']?.toString(),
      timeZone: raw['timeZone'] as String?,
      lastModified: raw['lastModified'] == null ? null : _parseMs(raw['lastModified']),
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

  static _SyncCacheEntry? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    return _SyncCacheEntry(
      nativeId: raw['nativeId'] as String?,
      nativeCalendarId: raw['nativeCalendarId'] as String?,
      nativeModified: raw['nativeModified'] == null ? null : DateTime.tryParse(raw['nativeModified'] as String),
      supabaseUpdated: raw['supabaseUpdated'] == null ? null : DateTime.tryParse(raw['supabaseUpdated'] as String),
      nativeFingerprint: raw['nativeFingerprint'] as String?,
      supabaseFingerprint: raw['supabaseFingerprint'] as String?,
    );
  }
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

  Future<List<NativeCalendarEvent>> fetchEvents(DateTime start, DateTime end) async {
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
      final res = await _channel.invokeMethod<String>('upsertEvent', event.toMapForUpsert());
      return res;
    } catch (e) {
      debugPrint('[calendar-sync] upsertEvent error: $e');
      return null;
    }
  }

  Future<bool> deleteEvent(String nativeId) async {
    if (kIsWeb) return false;
    try {
      final deleted = await _channel.invokeMethod<bool>('deleteEvent', {'eventId': nativeId});
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
  CalendarSyncService(this._client, {CalendarPlatformBridge? platform})
      : _platform = platform ?? CalendarPlatformBridge(),
        _eventsRepo = UserEventsRepo(_client);

  final SupabaseClient _client;
  final CalendarPlatformBridge _platform;
  final UserEventsRepo _eventsRepo;

  static const _cacheBoxName = 'calendar_sync.cache.v1';
  static const _stateBoxName = 'calendar_sync.state.v1';

  Box<dynamic>? _cacheBox;
  Box<dynamic>? _stateBox;
  bool _initialized = false;
  bool _syncing = false;
  Timer? _timer;

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
    _initialized = true;
  }

  Future<void> start() async {
    if (kIsWeb) return;
    await ensureInitialized();
    await sync();
    _timer ??= Timer.periodic(const Duration(minutes: 15), (_) => sync());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> dispose() async {
    stop();
    await _cacheBox?.close();
    await _stateBox?.close();
    _initialized = false;
  }

  Future<void> sync({DateTime? windowStart, DateTime? windowEnd}) async {
    if (kIsWeb || _syncing) return;
    if (_client.auth.currentSession == null) return;

    await ensureInitialized();
    final start = windowStart ?? DateTime.now().subtract(const Duration(days: 30));
    final end = windowEnd ?? DateTime.now().add(const Duration(days: 180));

    _syncing = true;
    try {
      final granted = await _platform.requestPermissions();
      if (!granted) {
        _stateBox?.put('lastPermissionDenied', DateTime.now().toIso8601String());
        return;
      }

      final nativeEvents = await _platform.fetchEvents(start, end);
      final supabaseEvents = await _loadSupabaseEvents(start, end);

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

      await _mergeNativeIntoSupabase(nativeByCid, supByCid);
      await _mergeSupabaseIntoNative(nativeByCid, supByCid);

      _stateBox?.put('lastSync', DateTime.now().toIso8601String());
    } catch (e, st) {
      debugPrint('[calendar-sync] sync failed: $e');
      debugPrint('$st');
    } finally {
      _syncing = false;
    }
  }

  /* ───────────────────────── Merging helpers ───────────────────────── */

  Future<void> _mergeNativeIntoSupabase(
    Map<String, NativeCalendarEvent> nativeByCid,
    Map<String, UserEvent> supByCid,
  ) async {
    for (final entry in nativeByCid.entries) {
      final cid = entry.key;
      final native = entry.value;
      final sup = supByCid[cid];
      final cache = _readCache(cid);

      final nativeFingerprint = native.fingerprint;
      final nativeModified = native.lastModified ?? native.start;
      final supFingerprint = sup == null ? null : _fingerprintFromSupabase(sup);
      final supUpdated = sup?.updatedAt ?? sup?.startsAt ?? DateTime.fromMillisecondsSinceEpoch(0);

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
        );
      } else if (nativeFingerprint != supFingerprint && nativeModified.isAfter(supUpdated)) {
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
  ) async {
    for (final entry in supByCid.entries) {
      final cid = entry.key;
      final sup = entry.value;
      final native = nativeByCid[cid];
      final cache = _readCache(cid);

      final supFingerprint = _fingerprintFromSupabase(sup);
      final supUpdated = sup.updatedAt ?? sup.startsAt;

      if (native == null) {
        final created = await _platform.upsertEvent(_fromSupabase(sup, cid: cid));
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
        continue;
      }

      final nativeFingerprint = native.fingerprint;
      final nativeModified = native.lastModified ?? native.start;

      final supNewer = supUpdated.isAfter(nativeModified) && supFingerprint != nativeFingerprint;
      if (supNewer) {
        final updatedId = await _platform.upsertEvent(
          native.copyWith(
            title: sup.title,
            description: sup.detail,
            location: sup.location,
            allDay: sup.allDay,
            start: sup.startsAt.toLocal(),
            end: sup.endsAt?.toLocal() ?? sup.startsAt.toLocal().add(const Duration(hours: 1)),
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

  Future<List<UserEvent>> _loadSupabaseEvents(DateTime start, DateTime end) async {
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

  _SyncCacheEntry? _readCache(String cid) => _SyncCacheEntry.fromJson(_cacheBox?.get(cid));

  void _writeCache(String cid, _SyncCacheEntry entry) {
    _cacheBox?.put(cid, entry.toJson());
  }

  String? _resolveCid(NativeCalendarEvent e) {
    if (e.clientEventId != null && e.clientEventId!.isNotEmpty) return e.clientEventId;
    final cachedById = e.nativeId == null ? null : _stateBox?.get('cid-for-native-${e.nativeId}');
    if (cachedById is String && cachedById.isNotEmpty) return cachedById;
    if (e.nativeId != null && e.nativeId!.isNotEmpty) {
      return 'native:${e.source}:${e.nativeId}';
    }
    return 'native:${e.source}:${e.fingerprint}';
  }

  NativeCalendarEvent _fromSupabase(UserEvent e, {required String cid}) {
    final localStart = e.startsAt.toLocal();
    final localEnd = (e.endsAt ?? e.startsAt.add(const Duration(hours: 1))).toLocal();
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
