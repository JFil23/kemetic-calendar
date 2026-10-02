import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/calendar/calendar_invalidation.dart';
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
  });
  final String id, label;
  final bool selected;
  final String? color;
  factory ExternalCalendarSource.fromJson(Map<String, dynamic> json) =>
      ExternalCalendarSource(
        id: json['id'] as String,
        label: json['label'] as String,
        selected: json['selected'] == true,
        color: json['color'] as String?,
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
  final Map<String, List<Map<String, dynamic>>> _confirmedRanges = {};
  String? _visibleOwner;
  void forgetPresentation() {
    _projectionGeneration++;
    _confirmedRanges.clear();
    _readAttempts.clear();
    _visibleOwner = null;
  }

  final Set<void Function(DateTime, DateTime)> _rangeListeners = {};
  void addVisibleRangeListener(void Function(DateTime, DateTime) listener) =>
      _rangeListeners.add(listener);
  void removeVisibleRangeListener(void Function(DateTime, DateTime) listener) =>
      _rangeListeners.remove(listener);
  int _projectionGeneration = 0;
  ExternalCalendarFailure? readFailure;
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
    for (final listener in List.of(_rangeListeners)) {
      listener(from, until);
    }
    List<ExternalCalendarEvent> cached = const [];
    try {
      final rows =
          _confirmedRanges[key] ??
          await WarmJsonReads(
            client,
            cachedOnly: true,
          ).rows(key, () async => throw StateError('cache only'));
      cached = rows.map(ExternalCalendarEvent.fromJson).toList(growable: false);
    } catch (_) {
      /* A cache miss is not a confirmed empty provider calendar. */
    }
    if (accountId != owner) return const [];
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

  Future<void> _refreshRange(
    String owner,
    String key,
    DateTime from,
    DateTime until,
  ) async {
    final generation = _projectionGeneration;
    final before =
        _confirmedRanges[key] ??
        WarmSnapshotStore.instance.peek(owner, key)?.data;
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
      _confirmedRanges[key] = (result as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
      while (_confirmedRanges.length > 4) {
        _confirmedRanges.remove(_confirmedRanges.keys.first);
      }
      if (jsonEncode(before) != jsonEncode(result)) _publish();
      readFailure = null;
    } catch (failure) {
      if (accountId != owner || generation != _projectionGeneration) return;
      if (failure is WarmAccessDenied) {
        _confirmedRanges.remove(key);
        _publish();
      }
      readFailure = ExternalCalendarFailure(
        code: failure.runtimeType.toString(),
        retryable: true,
      );
      // Keep the last complete snapshot; never publish failure as [].
    } finally {
      if (accountId == owner && generation != _projectionGeneration) {
        _readFlights.remove('$owner:$key');
        _readAttempts.remove('$owner:$key');
        _publish();
      }
    }
  }

  void projectionChanged({bool removedSources = false}) {
    final owner = accountId;
    if (owner == null) return;
    _projectionGeneration++;
    _readAttempts.clear();
    if (removedSources) {
      _confirmedRanges.clear();
      WarmSnapshotStore.instance.invalidate(
        owner,
        prefix: 'externalCalendar.$lane.',
      );
    }
    _publish();
  }

  void _publish() => CalendarInvalidationBus.instance.publish(
    const CalendarInvalidated(
      reason: CalendarInvalidationReason.calendarImportSynced,
    ),
  );
}

final _externalRepositories = Expando<ExternalCalendarRepository>();
ExternalCalendarRepository externalCalendarRepository(SupabaseClient client) =>
    _externalRepositories[client] ??= ExternalCalendarRepository(client);
