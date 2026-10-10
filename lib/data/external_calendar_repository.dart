import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/calendar/calendar_invalidation.dart';
import '../features/calendar/snapshot/calendar_snapshot_models.dart';
import '../features/calendar/snapshot/calendar_snapshot_runtime.dart';
import 'warm_state/warm_json_reads.dart';
import 'warm_state/warm_snapshot_store.dart';

// Unknown/development builds must never silently address production data.
String? get externalCalendarBuildLane =>
    switch (const String.fromEnvironment('APP_ENV')) {
      'staging' => 'staging',
      'prod' => 'production',
      _ => null,
    };

class ExternalCalendarFailure implements Exception {
  const ExternalCalendarFailure({required this.code, this.retryable = false});
  final String code;
  final bool retryable;
  @override
  String toString() => 'ExternalCalendarFailure($code)';
}

class ExternalCalendarSource {
  const ExternalCalendarSource({
    required this.id,
    required this.label,
    this.selected = false,
    this.color,
    this.importedEventCount,
    this.lastSyncedAt,
  });
  final String id, label;
  final bool selected;
  final String? color;
  final int? importedEventCount;
  final DateTime? lastSyncedAt;
  factory ExternalCalendarSource.fromJson(Map<String, dynamic> json) =>
      ExternalCalendarSource(
        id: json['id'] as String,
        label: json['label'] as String,
        selected: json['selected'] == true,
        color: json['color'] as String?,
        importedEventCount: (json['imported_event_count'] as num?)?.toInt(),
        lastSyncedAt: DateTime.tryParse(
          json['last_synced_at'] as String? ?? '',
        ),
      );
}

class ExternalCalendarStatus {
  const ExternalCalendarStatus({
    this.available = true,
    this.connectionId,
    this.connectionState = 'disconnected',
    this.automatic = false,
    this.accountLabel,
    this.lastSyncedAt,
    this.sources = const [],
    this.revision,
    this.errorCode,
    this.retryAt,
    this.syncing = false,
    this.importedEventCount,
  });
  final bool available, automatic;
  final String? connectionId, accountLabel;
  final String connectionState;
  final DateTime? lastSyncedAt;
  final List<ExternalCalendarSource> sources;
  final int? revision;
  final String? errorCode;
  final DateTime? retryAt;
  final bool syncing;
  final int? importedEventCount;
  bool get hasSelection => sources.any((source) => source.selected);
  bool get connected =>
      connectionId != null && connectionState != 'disconnected';
  bool get requiresReconnect => connectionState == 'reconnect_required';
  factory ExternalCalendarStatus.fromJson(Map<String, dynamic> json) {
    final connection = json['connection'] as Map?;
    final rows = json['sources'];
    if (rows is! List) {
      throw const FormatException('Missing calendar inventory');
    }
    return ExternalCalendarStatus(
      available: json['available'] == true,
      connectionId: connection?['id'] as String?,
      connectionState: connection?['status'] as String? ?? 'disconnected',
      automatic: connection?['automatic'] == true,
      accountLabel: connection?['account_label'] as String?,
      lastSyncedAt: DateTime.tryParse(
        connection?['last_synced_at'] as String? ?? '',
      ),
      revision: (connection?['revision'] as num?)?.toInt(),
      errorCode: connection?['error_code'] as String?,
      retryAt: DateTime.tryParse(json['retry_at'] as String? ?? ''),
      syncing: json['syncing'] == true,
      importedEventCount: (json['imported_event_count'] as num?)?.toInt(),
      sources: List.unmodifiable(
        rows.map(
          (row) => ExternalCalendarSource.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        ),
      ),
    );
  }
}

/// An external projection cannot be passed to an authored-event writer.
class ExternalCalendarEvent {
  ExternalCalendarEvent.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      clientEventId = json['client_event_id'] as String,
      sourceId = json['source_id'] as String,
      title = json['title'] as String? ?? '',
      detail = json['detail'] as String?,
      location = json['location'] as String?,
      calendarName = json['calendar_name'] as String? ?? 'External calendar',
      color = json['calendar_color'] is num
          ? (json['calendar_color'] as num).toInt()
          : int.tryParse(
              '${json['calendar_color'] ?? json['color'] ?? ''}'.replaceFirst(
                '#',
                'ff',
              ),
              radix: 16,
            ),
      allDay = json['all_day'] == true,
      startsAtUtc = _date(json, true),
      endsAtUtc = _date(json, false) {
    if (!clientEventId.startsWith('external:') ||
        !endsAtUtc.isAfter(startsAtUtc)) {
      throw const FormatException('Invalid external projection');
    }
  }
  final String id, clientEventId, sourceId, title, calendarName;
  final String? detail, location;
  final int? color;
  final bool allDay;
  final DateTime startsAtUtc, endsAtUtc;
  static DateTime _date(Map<String, dynamic> json, bool start) {
    if (json['all_day'] == true) {
      final raw = json[start ? 'start_date' : 'end_date'] as String;
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
        throw const FormatException('Expected civil date');
      }
      final parts = raw.split('-').map(int.parse).toList();
      final local = DateTime(parts[0], parts[1], parts[2]);
      if (local.year != parts[0] ||
          local.month != parts[1] ||
          local.day != parts[2]) {
        throw const FormatException('Invalid civil date');
      }
      return local.toUtc();
    }
    final raw = json[start ? 'starts_at' : 'ends_at'] as String;
    if (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw)) {
      throw const FormatException('Expected instant');
    }
    return DateTime.parse(raw).toUtc();
  }
}

typedef ExternalCalendarRequest =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> body);

class ExternalCalendarRepository {
  ExternalCalendarRepository(
    this.client, {
    String? lane,
    ExternalCalendarRequest? request,
    String? Function()? currentAccount,
    this.requestTimeout = const Duration(seconds: 15),
    this.refreshTimeout = const Duration(seconds: 100),
  }) : lane = lane ?? externalCalendarBuildLane,
       _request = request,
       _currentAccount = currentAccount;
  final SupabaseClient client;
  final String? lane;
  final ExternalCalendarRequest? _request;
  final String? Function()? _currentAccount;
  final Duration requestTimeout, refreshTimeout;
  final Map<String, DateTime> _readAttempts = {};
  final Set<String> _readFlights = {};
  final Map<String, WarmSnapshot> _confirmedRanges = {};
  String? _visibleOwner;
  final Map<String, ExternalCalendarRange> _observedRanges = {};
  final Map<String, Set<String>> _removedSourcesByOwner = {};
  Future<void> _sourcePruneTail = Future<void>.value();

  bool isSourceRemoved(String? calendarId, {String? owner}) {
    if (calendarId == null || !calendarId.startsWith('external:')) return false;
    return _removedSourcesByOwner[owner ?? accountId]?.contains(
          calendarId.substring('external:'.length),
        ) ??
        false;
  }

  /// A prepared cache write may outlive an acknowledged source selection.
  /// Authored rows and other release lanes never participate in this filter.
  bool isRemovedSnapshotRow(Object? raw, {required String owner}) {
    if (raw is! Map) return false;
    final cid = raw['clientEventId'];
    final calendar = raw['calendarId'];
    return cid is String &&
        cid.startsWith('external:') &&
        raw['externalCalendarLane'] == lane &&
        calendar is String &&
        isSourceRemoved(calendar, owner: owner);
  }

  String filterSerializedWarmSnapshot(String raw, {required String owner}) {
    if (accountId != owner) return raw;
    try {
      final data = jsonDecode(raw);
      if (data is! Map || data['userId'] != owner || data['notes'] is! Map) {
        return raw;
      }
      var changed = false;
      final notes = <String, Object?>{};
      for (final entry in (data['notes'] as Map).entries) {
        if (entry.value is! List) {
          notes[entry.key.toString()] = entry.value;
          continue;
        }
        final before = entry.value as List;
        final kept = before
            .where((row) => !isRemovedSnapshotRow(row, owner: owner))
            .toList();
        changed = changed || kept.length != before.length;
        if (kept.isNotEmpty) notes[entry.key.toString()] = kept;
      }
      if (!changed) return raw;
      data['notes'] = notes;
      return jsonEncode(data);
    } catch (_) {
      return raw;
    }
  }

  void forgetPresentation() {
    _projectionGeneration++;
    _confirmedRanges.clear();
    _readAttempts.clear();
    _observedRanges.clear();
    _visibleOwner = null;
    _readFailures.clear();
    _notifyReadState();
  }

  final Set<void Function(DateTime, DateTime)> _rangeListeners = {};
  void addVisibleRangeListener(void Function(DateTime, DateTime) listener) =>
      _rangeListeners.add(listener);
  void removeVisibleRangeListener(void Function(DateTime, DateTime) listener) =>
      _rangeListeners.remove(listener);
  int _projectionGeneration = 0;
  final Map<String, ExternalCalendarFailure> _readFailures = {};
  final Set<void Function()> _readStateListeners = {};
  ExternalCalendarFailure? get readFailure =>
      _visibleOwner != accountId || _readFailures.isEmpty
      ? null
      : _readFailures.values.first;
  void addReadStateListener(void Function() listener) =>
      _readStateListeners.add(listener);
  void removeReadStateListener(void Function() listener) =>
      _readStateListeners.remove(listener);
  void _notifyReadState() {
    // A cache owner may be reset during a Calendar build. Publish presentation
    // changes after that frame's synchronous work, just like range invalidation.
    scheduleMicrotask(() {
      for (final listener in List.of(_readStateListeners)) {
        listener();
      }
    });
  }

  /// Retry failed projection reads without reconnecting or reimporting Google.
  Future<void> retryReads() async {
    final owner = accountId;
    final generation = _projectionGeneration;
    if (owner == null) return;
    for (final key in List.of(_readFailures.keys)) {
      if (owner != accountId || generation != _projectionGeneration) return;
      final range = _observedRanges[key];
      final attemptKey = '$owner:$key';
      if (range == null || !_readFlights.add(attemptKey)) continue;
      _readAttempts[attemptKey] = DateTime.now();
      try {
        await _refreshRange(owner, key, range.from, range.until);
      } finally {
        _readFlights.remove(attemptKey);
      }
    }
  }

  String? get accountId =>
      _currentAccount != null ? _currentAccount() : client.auth.currentUser?.id;

  Future<Map<String, dynamic>> command(
    String action, {
    Map<String, dynamic> arguments = const {},
  }) async {
    final owner = accountId;
    if (owner == null) {
      throw const ExternalCalendarFailure(code: 'unauthenticated');
    }
    if (lane != 'staging' && lane != 'production') {
      throw const ExternalCalendarFailure(code: 'not_configured');
    }
    final token = client.auth.currentSession?.accessToken;
    final body = <String, dynamic>{
      ...arguments,
      'action': action,
      'lane': lane,
    };
    try {
      final Map<String, dynamic> data;
      if (_request != null) {
        data = await _request(body).timeout(
          const {'refresh', 'sources', 'device_snapshot'}.contains(action)
              ? refreshTimeout
              : requestTimeout,
        );
      } else {
        if (token == null) {
          throw const ExternalCalendarFailure(code: 'unauthenticated');
        }
        final response = await client.functions
            .invoke(
              'external_calendar',
              body: body,
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(
              const {'refresh', 'sources', 'device_snapshot'}.contains(action)
                  ? refreshTimeout
                  : requestTimeout,
            );
        data = Map<String, dynamic>.from(response.data as Map);
      }
      if (accountId != owner) {
        throw const ExternalCalendarFailure(code: 'account_changed');
      }
      final failure = data['error'];
      if (failure is Map) {
        throw ExternalCalendarFailure(
          code: failure['code'] as String? ?? 'unavailable',
          retryable: failure['retryable'] == true,
        );
      }
      return data;
    } on ExternalCalendarFailure {
      rethrow;
    } on TimeoutException {
      throw const ExternalCalendarFailure(code: 'timeout', retryable: true);
    } on FunctionException catch (error) {
      final details = error.details;
      final failure = details is Map ? details['error'] : null;
      throw ExternalCalendarFailure(
        code: failure is Map
            ? failure['code'] as String? ?? 'unavailable'
            : error.status == 404
            ? 'not_configured'
            : 'unavailable',
        retryable: failure is Map
            ? failure['retryable'] == true
            : error.status >= 500,
      );
    } catch (_) {
      throw const ExternalCalendarFailure(code: 'unavailable', retryable: true);
    }
  }

  Future<ExternalCalendarStatus> statusCommand(
    String action, {
    Map<String, dynamic> arguments = const {},
  }) async => ExternalCalendarStatus.fromJson(
    await command(action, arguments: arguments),
  );

  String rangeKey(DateTime from, DateTime until) =>
      'externalCalendar.$lane.${from.toUtc().toIso8601String()}.${until.toUtc().toIso8601String()}';

  /// Calendar hydration consumes confirmed cached copies immediately. External
  /// network work cannot delay authored content or the first application frame.
  Future<List<ExternalCalendarEvent>> visibleEvents(
    DateTime from,
    DateTime until,
  ) async {
    final owner = accountId;
    if (owner != _visibleOwner) {
      forgetPresentation();
      _visibleOwner = owner;
    }
    if (owner == null || lane == null) return const [];
    final key = rangeKey(from, until);
    _observedRanges.remove(key);
    _observedRanges[key] = ExternalCalendarRange(from.toUtc(), until.toUtc());
    while (_observedRanges.length > 64) {
      final oldest = _observedRanges.keys.first;
      _observedRanges.remove(oldest);
      if (_readFailures.remove(oldest) != null) _notifyReadState();
    }
    for (final listener in List.of(_rangeListeners)) {
      listener(from, until);
    }
    final generation = _projectionGeneration;
    List<ExternalCalendarEvent> cached = const [];
    try {
      final snapshots = await WarmJsonReads(
        client,
        cachedOnly: true,
        mayFetch: () => generation == _projectionGeneration,
      ).cachedFamily('externalCalendar.$lane.');
      cached = _visibleSnapshotEvents(
        _rangeSnapshots(snapshots),
        from,
        until,
        owner,
      );
    } catch (_) {
      /* A cache miss is not a confirmed empty provider calendar. */
    }
    if (accountId != owner || generation != _projectionGeneration) {
      return const [];
    }
    final attemptKey = '$owner:$key';
    final last = _readAttempts[attemptKey];
    if (!_readFlights.contains(attemptKey) &&
        (last == null ||
            DateTime.now().difference(last) > const Duration(minutes: 1))) {
      _readAttempts[attemptKey] = DateTime.now();
      _readFlights.add(attemptKey);
      unawaited(
        _refreshRange(
          owner,
          key,
          from,
          until,
        ).whenComplete(() => _readFlights.remove(attemptKey)),
      );
    }
    return cached;
  }

  Map<String, WarmSnapshot> _rangeSnapshots(Map<String, WarmSnapshot> cached) {
    final combined = {...cached};
    for (final entry in _confirmedRanges.entries) {
      final existing = combined[entry.key];
      if (existing == null ||
          entry.value.updatedAt.isAfter(existing.updatedAt)) {
        combined[entry.key] = entry.value;
      }
    }
    return combined;
  }

  String _visibleFingerprint(String owner, DateTime from, DateTime until) =>
      jsonEncode([
        for (final event in _visibleSnapshotEvents(
          _rangeSnapshots(
            WarmSnapshotStore.instance.peekFamily(
              owner,
              'externalCalendar.$lane.',
            ),
          ),
          from,
          until,
          owner,
        ))
          [
            event.id,
            event.clientEventId,
            event.sourceId,
            event.title,
            event.detail,
            event.location,
            event.calendarName,
            event.color,
            event.allDay,
            event.startsAtUtc.toIso8601String(),
            event.endsAtUtc.toIso8601String(),
          ],
      ]);

  List<ExternalCalendarEvent> _visibleSnapshotEvents(
    Map<String, WarmSnapshot> snapshots,
    DateTime from,
    DateTime until,
    String owner,
  ) {
    final prefix = 'externalCalendar.$lane.';
    final ranges = <({DateTime from, DateTime until, WarmSnapshot snapshot})>[];
    for (final entry in snapshots.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      final parts = entry.key.substring(prefix.length).split('Z.');
      if (parts.length != 2) continue;
      final start = DateTime.tryParse('${parts[0]}Z');
      final end = DateTime.tryParse(parts[1]);
      if (start == null ||
          end == null ||
          !start.isBefore(end) ||
          !start.isBefore(until) ||
          !end.isAfter(from)) {
        continue;
      }
      ranges.add((from: start, until: end, snapshot: entry.value));
    }
    ranges.sort((a, b) => a.snapshot.updatedAt.compareTo(b.snapshot.updatedAt));
    final events = <String, ExternalCalendarEvent>{};
    bool overlaps(ExternalCalendarEvent event, DateTime start, DateTime end) =>
        event.startsAtUtc.isBefore(end) && event.endsAtUtc.isAfter(start);
    for (final range in ranges) {
      try {
        // Decode the complete snapshot before it can supersede confirmed rows.
        final rows = (range.snapshot.data as List)
            .map(
              (row) => ExternalCalendarEvent.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList(growable: false);
        // A newer confirmed empty window is authoritative too. Replaying by
        // confirmation time prevents an older broad range resurrecting removals.
        events.removeWhere(
          (_, event) => overlaps(event, range.from, range.until),
        );
        for (final event in rows) {
          if (overlaps(event, from, until) &&
              !isSourceRemoved('external:${event.sourceId}', owner: owner)) {
            events[event.clientEventId] = event;
          }
        }
      } on Object {
        // Unsupported or incomplete cache payloads provide no coverage.
      }
    }
    return events.values.toList(growable: false)..sort((a, b) {
      final order = a.startsAtUtc.compareTo(b.startsAtUtc);
      return order != 0 ? order : a.clientEventId.compareTo(b.clientEventId);
    });
  }

  Future<void> _refreshRange(
    String owner,
    String key,
    DateTime from,
    DateTime until,
  ) async {
    final generation = _projectionGeneration;
    final before = _visibleFingerprint(owner, from, until);
    final beforeRaw = _rangeSnapshots(
      WarmSnapshotStore.instance.peekFamily(owner, 'externalCalendar.$lane.'),
    )[key]?.data;
    var accessRevoked = false;
    try {
      final result =
          await WarmJsonReads(
            client,
            mayFetch: () => generation == _projectionGeneration,
          ).value(
            key,
            () async => await client
                .rpc(
                  'read_external_calendar_events_v1',
                  params: {
                    'p_lane': lane,
                    'p_from': from.toUtc().toIso8601String(),
                    'p_until': until.toUtc().toIso8601String(),
                  },
                )
                .timeout(requestTimeout),
            validate: (data) {
              if (data is! List) {
                throw const FormatException('Incomplete projection');
              }
              for (final row in data) {
                ExternalCalendarEvent.fromJson(
                  Map<String, dynamic>.from(row as Map),
                );
              }
            },
          );
      if (accountId != owner || generation != _projectionGeneration) return;
      // A confirmed result remains usable even when it exceeds the disk cache's
      // per-entry budget. Persistence is optional acceleration, not publication.
      _confirmedRanges.remove(key);
      _confirmedRanges[key] = WarmSnapshot(result, DateTime.now().toUtc());
      while (_confirmedRanges.length > 4) {
        _confirmedRanges.remove(_confirmedRanges.keys.first);
      }
      // Only a successful current-generation server read can lift an earlier
      // removal fence when the same source has been explicitly selected again.
      _removedSourcesByOwner[owner]?.removeAll(
        (result as List).map((row) => (row as Map)['source_id'] as String),
      );
      if (jsonEncode(beforeRaw) != jsonEncode(result) ||
          before != _visibleFingerprint(owner, from, until)) {
        _publish(ranges: [ExternalCalendarRange(from.toUtc(), until.toUtc())]);
      }
      if (_readFailures.remove(key) != null) _notifyReadState();
    } catch (failure) {
      if (accountId != owner || generation != _projectionGeneration) return;
      if (failure is WarmAccessDenied) {
        accessRevoked = true;
        // All windows use the same private projection permission. A denied
        // subrange must not fall back to a broader private snapshot.
        _projectionGeneration++;
        _confirmedRanges.clear();
        WarmSnapshotStore.instance.invalidate(
          owner,
          prefix: 'externalCalendar.$lane.',
        );
        _publish();
      }
      if (_observedRanges.containsKey(key)) {
        _readFailures[key] = ExternalCalendarFailure(
          code: failure.runtimeType.toString(),
          retryable: true,
        );
        _notifyReadState();
      }
      // Keep the last complete snapshot; never publish failure as [].
    } finally {
      if (!accessRevoked &&
          accountId == owner &&
          generation != _projectionGeneration) {
        _readFlights.remove('$owner:$key');
        _readAttempts.remove('$owner:$key');
        _publish();
      }
    }
  }

  Future<void> projectionChanged({
    bool removedSources = false,
    Iterable<String> removedSourceIds = const [],
  }) async {
    final owner = accountId;
    if (owner == null || lane == null) return;
    final removed = removedSourceIds.where((id) => id.isNotEmpty).toSet();
    _projectionGeneration++;
    _readAttempts.clear();
    if (removed.isNotEmpty) {
      _removedSourcesByOwner.putIfAbsent(owner, () => {}).addAll(removed);
    }
    if (removedSources || removed.isNotEmpty) {
      _confirmedRanges.clear();
      WarmSnapshotStore.instance.invalidate(
        owner,
        prefix: 'externalCalendar.$lane.',
      );
    }
    _publish(
      ranges: List.of(_observedRanges.values),
      removedSourceIds: removed,
    );
    if (removed.isNotEmpty) await pruneRemovedSources(owner, removed);
  }

  /// Rewrite only disposable imported copies in the existing snapshot owners.
  /// The page repeats this after its old write tails drain; no authored or
  /// pending-overlay records are deleted, and cache keys/schema stay unchanged.
  Future<void> pruneRemovedSources(String owner, Iterable<String> sourceIds) {
    final removed = sourceIds.toSet();
    final operation = _sourcePruneTail.then((_) async {
      if (removed.isEmpty || accountId != owner || lane == null) return;
      bool discard(Object? raw) =>
          isRemovedSnapshotRow(raw, owner: owner) &&
          removed.contains(
            (raw as Map)['calendarId'].substring('external:'.length),
          );

      try {
        for (var attempt = 0; attempt < 3; attempt++) {
          final existing = await calendarSnapshotStore.readLatest(owner);
          if (accountId != owner || existing == null) break;
          var changed = false;
          final notes = <String, List<Map<String, Object?>>>{};
          for (final entry in existing.eventsByDay.entries) {
            final kept = entry.value.where((row) => !discard(row)).toList();
            changed = changed || kept.length != entry.value.length;
            if (kept.isNotEmpty) notes[entry.key] = kept;
          }
          if (!changed) break;
          final commit = CalendarSnapshotCommit(
            userScope: owner,
            serverRevision: calendarSnapshotDigest(
              calendarCanonicalJson(notes),
            ),
            overlayRevision: existing.overlayRevision,
            catalogFingerprint: existing.catalogFingerprint,
            origin: 'external_source_removal',
            committedAtUtc: DateTime.now().toUtc(),
            lastSuccessfulRefreshAtUtc: existing.lastSuccessfulRefreshAtUtc,
            coverage: existing.coverage,
            eventsByDay: notes,
            flows: existing.flows,
            calendarMetadata: existing.calendarMetadata,
            overlayRecords: existing.overlayRecords,
          );
          if (accountId != owner) return;
          try {
            await calendarSnapshotStore.commit(
              commit,
              expectedGeneration: existing.generation,
              requireGenerationMatch: true,
            );
            break;
          } on CalendarSnapshotConflict {
            if (attempt == 2) rethrow;
          }
        }
      } catch (_) {
        // Cache work cannot reverse the acknowledged server selection.
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        if (accountId != owner) return;
        final key = 'calendar:warm_start:v1:$owner';
        final raw = prefs.getString(key);
        if (raw == null) return;
        final filtered = filterSerializedWarmSnapshot(raw, owner: owner);
        if (filtered != raw && accountId == owner) {
          await prefs.setString(key, filtered);
        }
      } catch (_) {
        // The last valid authored cache remains usable if storage is unavailable.
      }
    });
    _sourcePruneTail = operation.catchError((Object _) {});
    return _sourcePruneTail;
  }

  void _publish({
    List<ExternalCalendarRange> ranges = const [],
    Set<String> removedSourceIds = const {},
  }) {
    final owner = accountId;
    final releaseLane = lane;
    if (owner == null || releaseLane == null) return;
    CalendarInvalidationBus.instance.publish(
      CalendarInvalidated(
        reason: CalendarInvalidationReason.calendarImportSynced,
        externalCalendar: ExternalCalendarInvalidation(
          accountId: owner,
          lane: releaseLane,
          ranges: ranges,
          removedSourceIds: removedSourceIds,
        ),
      ),
    );
  }
}

final _externalRepositories = Expando<ExternalCalendarRepository>();
ExternalCalendarRepository externalCalendarRepository(SupabaseClient client) =>
    _externalRepositories[client] ??= ExternalCalendarRepository(client);

/// Supplies an explicit fixture lane without changing production build routing.
@visibleForTesting
void setExternalCalendarRepositoryForTesting(
  SupabaseClient client,
  ExternalCalendarRepository? repository,
) {
  assert(repository == null || identical(repository.client, client));
  _externalRepositories[client] = repository;
}
