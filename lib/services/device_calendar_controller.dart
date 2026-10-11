import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/external_calendar_repository.dart';
import 'device_calendar_bridge.dart';

class DeviceCalendarSource {
  const DeviceCalendarSource({
    required this.id,
    required this.nativeId,
    required this.label,
    this.accountLabel = 'This phone',
    this.kind = 'device',
    this.ownedBy = 'device',
    this.selected = false,
    this.googleSourceId,
    this.available = true,
    this.color,
  });
  final String id, nativeId, label, accountLabel, kind, ownedBy;
  final bool selected, available;
  final String? googleSourceId, color;
  factory DeviceCalendarSource.fromJson(Map<String, dynamic> data) =>
      DeviceCalendarSource(
        id: data['id'] as String,
        nativeId: data['native_id'] as String,
        label: data['label'] as String,
        accountLabel: data['account_label'] as String? ?? 'This phone',
        kind: data['kind'] as String? ?? 'device',
        ownedBy:
            data['owned_by'] as String? ??
            (data['google_source_id'] == null ? 'device' : 'google'),
        selected: data['selected'] == true,
        googleSourceId: data['google_source_id'] as String?,
        available: data['available'] != false,
        color: data['color'] as String?,
      );
}

class DeviceCalendarStatus {
  const DeviceCalendarStatus({
    this.available = true,
    this.connectionId,
    this.ownerDeviceId,
    this.connectionState = 'disconnected',
    this.automatic = false,
    this.revision,
    this.lastSyncedAt,
    this.sources = const [],
  });
  final bool available, automatic;
  final String? connectionId, ownerDeviceId;
  final String connectionState;
  final int? revision;
  final DateTime? lastSyncedAt;
  final List<DeviceCalendarSource> sources;
  bool get connected =>
      connectionId != null && connectionState != 'disconnected';
  factory DeviceCalendarStatus.fromJson(Map<String, dynamic> data) {
    final connection = data['connection'] as Map?;
    final rows = data['sources'];
    if (rows is! List) throw const DeviceCalendarFailure('invalid_response');
    return DeviceCalendarStatus(
      available: data['available'] == true,
      connectionId: connection?['id'] as String?,
      ownerDeviceId: connection?['owner_device_id'] as String?,
      connectionState: connection?['status'] as String? ?? 'disconnected',
      automatic: connection?['automatic'] == true,
      revision: (connection?['revision'] as num?)?.toInt(),
      lastSyncedAt: DateTime.tryParse(
        connection?['last_synced_at'] is String
            ? connection!['last_synced_at'] as String
            : '',
      ),
      sources: List.unmodifiable(
        rows.map(
          (row) => DeviceCalendarSource.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        ),
      ),
    );
  }
}

/// Native imports are optional, post-authentication work. The account repository
/// remains the projection reader; this coordinator cannot write authored events.
class DeviceCalendarController extends ChangeNotifier
    with WidgetsBindingObserver {
  DeviceCalendarController({
    required this.repository,
    required this.bridge,
    this.operationTimeout = const Duration(seconds: 60),
    this.pollInterval = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  final ExternalCalendarRepository repository;
  final DeviceCalendarBridge bridge;
  final Duration operationTimeout, pollInterval;
  final DateTime Function() _clock;
  static DeviceCalendarController? _instance;
  static DeviceCalendarController get instance =>
      forClient(Supabase.instance.client);
  static DeviceCalendarController forClient(SupabaseClient client) {
    final current = _instance;
    if (current != null && identical(current.repository.client, client))
      return current;
    current?.dispose();
    return _instance = DeviceCalendarController(
      repository: externalCalendarRepository(client),
      bridge: MethodChannelDeviceCalendarBridge(),
    );
  }

  static void disposeShared() {
    _instance?.dispose();
    _instance = null;
  }

  static bool get supportedPlatform =>
      MethodChannelDeviceCalendarBridge.supportedPlatform;
  bool get supported => bridge.supported;
  String? get accountId => repository.accountId;
  DeviceCalendarStatus? get accountStatus =>
      _account == accountId ? status : null;
  int get generation => _generation;
  bool busy = false, choosing = false;
  String? errorCode;
  DeviceCalendarStatus status = const DeviceCalendarStatus();
  Set<String> selectedSources = {};
  Set<String> unresolvedCloudSources = {};
  Map<String, String> googleBindings = {};
  String? _account, _deviceId;
  // Only a connection created by this explicit setup may start automatically
  // after its first successful selection import. An existing pause is durable.
  String? _initialSetupConnectionId;
  int _generation = 0;
  bool _started = false, _disposed = false;
  Timer? _timer, _debounce;
  StreamSubscription<void>? _changes;
  DateTime? _rangeFrom, _rangeUntil;
  final List<({DateTime from, DateTime until, DateTime at})> _coverage = [];
  final List<({DateTime from, DateTime until})> _pendingRanges = [];
  bool get isOwner => _deviceId != null && status.ownerDeviceId == _deviceId;

  void startForAccount() {
    if (_disposed || !supported) return;
    final account = repository.accountId;
    if (_started && _account == account) return;
    stop();
    if (account == null) return;
    _account = account;
    _started = true;
    // Install recovery triggers before the first fallible request.
    WidgetsBinding.instance.addObserver(this);
    repository.addVisibleRangeListener(ensureRange);
    _timer = Timer.periodic(pollInterval, (_) => unawaited(_catchUp()));
    unawaited(_catchUp());
  }

  void stop() {
    _generation++;
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      repository.removeVisibleRangeListener(ensureRange);
    }
    _started = false;
    _timer?.cancel();
    _timer = null;
    _debounce?.cancel();
    _debounce = null;
    unawaited(_changes?.cancel());
    _changes = null;
    _account = null;
    _deviceId = null;
    _initialSetupConnectionId = null;
    _coverage.clear();
    _pendingRanges.clear();
    _rangeFrom = null;
    _rangeUntil = null;
    busy = false;
    choosing = false;
    errorCode = null;
    status = const DeviceCalendarStatus();
    selectedSources = {};
    unresolvedCloudSources = {};
    googleBindings = {};
    if (!_disposed) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_catchUp());
  }

  bool _active(int generation, String account) =>
      !_disposed &&
      generation == _generation &&
      repository.accountId == account &&
      _account == account;
  void _check(int generation, String account) {
    if (!_active(generation, account)) {
      throw const DeviceCalendarFailure('account_changed');
    }
  }

  Future<T> _step<T>(
    int generation,
    String account,
    Future<T> Function() work,
  ) async {
    _check(generation, account);
    final value = await work();
    _check(generation, account);
    return value;
  }

  Future<void> _run(
    Future<void> Function(int, String) work, {
    bool permission = false,
    bool requiresDevice = true,
  }) async {
    if (_disposed || (requiresDevice && !supported)) return;
    final account = repository.accountId;
    if (account == null) {
      stop();
      return;
    }
    if (_account != account) {
      stop();
      _account = account;
    }
    if (busy) return;
    final generation = ++_generation;
    busy = true;
    errorCode = null;
    notifyListeners();
    try {
      await work(
        generation,
        account,
      ).timeout(permission ? const Duration(seconds: 120) : operationTimeout);
    } catch (error) {
      if (_active(generation, account)) {
        errorCode = switch (error) {
          DeviceCalendarFailure(:final code) => code,
          ExternalCalendarFailure(:final code) => code,
          TimeoutException() => 'timeout',
          _ => 'unavailable',
        };
      }
    } finally {
      if (_active(generation, account)) {
        // Fence remaining work even when the deadline won the race.
        _generation++;
        busy = false;
        notifyListeners();
        if (errorCode == null) _drainRangeQueue();
      } else if (!_disposed && repository.accountId != _account) {
        stop();
      }
    }
  }

  void _accept(Map<String, dynamic> response) {
    final next = DeviceCalendarStatus.fromJson(response);
    if (next.connectionId != _initialSetupConnectionId) {
      _initialSetupConnectionId = null;
    }
    String selection(DeviceCalendarStatus value) =>
        (value.sources
                .where((source) => source.selected)
                .map(
                  (source) =>
                      '${source.id}:${source.ownedBy}:${source.googleSourceId}',
                )
                .toList()
              ..sort())
            .join('|');
    if (next.connectionId != status.connectionId ||
        selection(next) != selection(status)) {
      _coverage.clear();
    }
    status = next;
    selectedSources = status.sources
        .where((source) => source.selected)
        .map((source) => source.id)
        .toSet();
    unresolvedCloudSources = status.sources
        .where(
          (source) =>
              source.ownedBy == 'google' && source.googleSourceId == null,
        )
        .map((source) => source.id)
        .toSet();
    googleBindings = {
      for (final source in status.sources)
        if (source.googleSourceId != null) source.id: source.googleSourceId!,
    };
  }

  Future<void> _acceptServerStatus(
    Map<String, dynamic> response,
    int generation,
    String account,
  ) async {
    Set<String> owned(DeviceCalendarStatus value) => {
      for (final source in value.sources)
        if (source.selected && source.ownedBy == 'device') source.id,
    };
    final previous = status;
    final before = owned(previous);
    _accept(response);
    final after = owned(status);
    final removed = before.difference(after);
    if (previous.connectionId != status.connectionId ||
        previous.lastSyncedAt != status.lastSyncedAt ||
        before.length != after.length ||
        !before.containsAll(after)) {
      await repository.projectionChanged(
        removedSources: removed.isNotEmpty,
        removedSourceIds: removed,
      );
    }
    _check(generation, account);
  }

  Future<void> _load(int generation, String account) async {
    final response = await _step(
      generation,
      account,
      () => repository.command('device_status'),
    );
    final device = await _step(generation, account, bridge.deviceId);
    _deviceId = device;
    await _acceptServerStatus(response, generation, account);
  }

  Map<String, dynamic> _mutationArguments() {
    if (_deviceId == null || status.revision == null || !isOwner) {
      throw const DeviceCalendarFailure('device_owner_required');
    }
    return {'device_id': _deviceId, 'expected_revision': status.revision};
  }

  Future<void> _command(
    int generation,
    String account,
    String action, [
    Map<String, dynamic> arguments = const {},
  ]) async {
    final response = await _step(
      generation,
      account,
      () => repository.command(
        action,
        arguments: {..._mutationArguments(), ...arguments},
      ),
    );
    await _acceptServerStatus(response, generation, account);
  }

  Future<void> _permission(
    int generation,
    String account, {
    bool request = false,
  }) async {
    var value = await _step(generation, account, bridge.permissionStatus);
    if (request && value != 'granted') {
      value = await _step(generation, account, bridge.requestPermission);
    }
    if (value != 'granted') {
      throw const DeviceCalendarFailure('permission_denied');
    }
  }

  /// Account management works on web and other phones without native access.
  Future<void> loadAccountStatus() async {
    if (choosing && _account == accountId) return;
    await _run((generation, account) async {
      final response = await _step(
        generation,
        account,
        () => repository.command('device_status'),
      );
      await _acceptServerStatus(response, generation, account);
    }, requiresDevice: false);
  }

  Future<bool> removeSource(String id) async {
    var removed = false;
    await _run((generation, account) async {
      if (!status.sources.any(
        (source) =>
            source.id == id && source.selected && source.ownedBy == 'device',
      ))
        return;
      final draft = {...selectedSources}..remove(id);
      final bindings = {...googleBindings}..remove(id);
      final unresolved = {...unresolvedCloudSources}..remove(id);
      final response = await _step(
        generation,
        account,
        () => repository.command(
          'device_remove_source',
          arguments: {'source_id': id, 'expected_revision': status.revision},
        ),
      );
      await _acceptServerStatus(response, generation, account);
      if (choosing) {
        selectedSources = draft;
        googleBindings = bindings;
        unresolvedCloudSources = unresolved;
      }
      removed = !status.sources.any(
        (source) => source.id == id && source.selected,
      );
    }, requiresDevice: false);
    return removed;
  }

  Future<void> refreshStatus() => _run(_load);
  Future<void> _catchUp({bool force = false}) {
    if (choosing) return Future<void>.value();
    return _run((generation, account) async {
      await _load(generation, account);
      if (status.connected && isOwner && status.automatic && !choosing) {
        await _snapshot(generation, account, manual: false, force: force);
      }
    });
  }

  Future<void> connect({bool replaceDevice = false}) =>
      _run((generation, account) async {
        await _load(generation, account);
        final initialSetup = !status.connected || (replaceDevice && !isOwner);
        await _permission(generation, account, request: true);
        final sources = await _step(generation, account, bridge.listCalendars);
        final response = await _step(
          generation,
          account,
          () => repository.command(
            'device_connect',
            arguments: {
              'device_id': _deviceId,
              'replace_device': replaceDevice,
              if (status.revision != null) 'expected_revision': status.revision,
              'sources': sources.map((source) => source.toJson()).toList(),
            },
          ),
        );
        await _acceptServerStatus(response, generation, account);
        if (initialSetup) _initialSetupConnectionId = status.connectionId;
        choosing = true;
      }, permission: true);

  Future<void> chooseCalendars() => _run((generation, account) async {
    await _load(generation, account);
    if (!isOwner) throw const DeviceCalendarFailure('device_owner_required');
    await _permission(generation, account);
    final sources = await _step(generation, account, bridge.listCalendars);
    await _command(generation, account, 'device_connect', {
      'replace_device': false,
      'sources': sources.map((source) => source.toJson()).toList(),
    });
    choosing = true;
  });
  void selectSource(String id, bool selected) {
    if (busy ||
        !choosing ||
        !status.sources.any(
          (source) => source.id == id && (!selected || source.available),
        )) {
      return;
    }
    selectedSources = {...selectedSources};
    if (selected) {
      selectedSources.add(id);
    } else {
      selectedSources.remove(id);
      googleBindings.remove(id);
      unresolvedCloudSources.remove(id);
    }
    notifyListeners();
  }

  void bindCloudSource(String id, String? googleSourceId) {
    if (busy || !choosing || !selectedSources.contains(id)) return;
    googleBindings = {...googleBindings};
    unresolvedCloudSources.remove(id);
    if (googleSourceId == null) {
      googleBindings.remove(id);
      unresolvedCloudSources.remove(id);
    } else {
      googleBindings[id] = googleSourceId;
    }
    notifyListeners();
  }

  void cancelSelection() {
    if (busy) return;
    choosing = false;
    selectedSources = status.sources
        .where((source) => source.selected)
        .map((source) => source.id)
        .toSet();
    unresolvedCloudSources = status.sources
        .where(
          (source) =>
              source.ownedBy == 'google' && source.googleSourceId == null,
        )
        .map((source) => source.id)
        .toSet();
    googleBindings = {
      for (final source in status.sources)
        if (source.googleSourceId != null) source.id: source.googleSourceId!,
    };
    notifyListeners();
  }

  Future<void> saveSelection() => _run((generation, account) async {
    if (selectedSources.intersection(unresolvedCloudSources).isNotEmpty) {
      throw const DeviceCalendarFailure('source_ownership_required');
    }
    final selection = selectedSources.toList();
    final bindings = {...googleBindings};
    await _command(generation, account, 'device_select_sources', {
      'source_ids': selection,
      'google_bindings': bindings,
    });
    choosing = false;
    if (status.sources.any(
      (source) => source.selected && source.ownedBy == 'device',
    )) {
      await _snapshot(generation, account, manual: true);
      if (!status.automatic &&
          status.connectionId == _initialSetupConnectionId) {
        await _command(generation, account, 'device_resume');
      }
      _initialSetupConnectionId = null;
      _observe();
    }
  });

  Future<void> refresh() => _run((generation, account) async {
    await _load(generation, account);
    await _snapshot(generation, account, manual: true);
  });
  Future<void> setAutomatic(bool value) => _run((generation, account) async {
    await _load(generation, account);
    if (value) {
      await _snapshot(generation, account, manual: true);
      await _command(generation, account, 'device_resume');
      _observe();
    } else {
      await _command(generation, account, 'device_pause');
      unawaited(_changes?.cancel());
      _changes = null;
    }
    _initialSetupConnectionId = null;
  });
  Future<void> disconnect() => _run((generation, account) async {
    await _load(generation, account);
    await _command(generation, account, 'device_disconnect');
    choosing = false;
    unawaited(_changes?.cancel());
    _changes = null;
  });

  bool _covered(DateTime from, DateTime until) {
    final now = _clock().toUtc();
    return _coverage.any(
      (range) =>
          !from.isBefore(range.from) &&
          !until.isAfter(range.until) &&
          now.difference(range.at) >= Duration.zero &&
          now.difference(range.at) < const Duration(minutes: 2),
    );
  }

  void ensureRange(DateTime from, DateTime until) {
    if (!until.isAfter(from) ||
        until.difference(from) > const Duration(days: 730)) {
      return;
    }
    _rangeFrom = from;
    _rangeUntil = until;
    if (_covered(from, until) ||
        _pendingRanges.any(
          (range) => range.from == from && range.until == until,
        )) {
      return;
    }
    _pendingRanges.add((from: from, until: until));
    // Retain the newest visible windows if rapid navigation outruns native I/O.
    if (_pendingRanges.length > 24) _pendingRanges.removeAt(0);
    _drainRangeQueue();
  }

  void _drainRangeQueue() {
    if (!status.sources.any(
      (source) => source.selected && source.ownedBy == 'device',
    )) {
      _pendingRanges.clear();
      return;
    }
    if (busy ||
        !_started ||
        choosing ||
        !status.automatic ||
        !isOwner ||
        _pendingRanges.isEmpty) {
      return;
    }
    final range = _pendingRanges.last;
    unawaited(
      _run((generation, account) async {
        await _load(generation, account);
        if (!status.automatic || !isOwner) return;
        await _snapshot(
          generation,
          account,
          manual: false,
          force: true,
          requestedFrom: range.from,
          requestedUntil: range.until,
        );
      }),
    );
  }

  Future<void> _snapshot(
    int generation,
    String account, {
    required bool manual,
    bool force = false,
    DateTime? requestedFrom,
    DateTime? requestedUntil,
  }) async {
    if (!isOwner) throw const DeviceCalendarFailure('device_owner_required');
    final sources = status.sources
        .where((source) => source.selected && source.ownedBy == 'device')
        .toList();
    if (sources.isEmpty) return;
    if (sources.any((source) => !source.available)) {
      throw const DeviceCalendarFailure('source_unavailable');
    }
    await _permission(generation, account);
    final now = _clock().toUtc();
    final from =
        requestedFrom ??
        _rangeFrom ??
        DateTime.utc(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 180));
    final until =
        requestedUntil ??
        _rangeUntil ??
        DateTime.utc(
          now.year,
          now.month,
          now.day,
        ).add(const Duration(days: 365));
    if (!manual && !force && _covered(from, until)) return;
    final snapshot = await _step(
      generation,
      account,
      () => bridge.readSnapshot(
        sources.map((source) => source.nativeId).toList(),
        from,
        until,
      ),
    );
    await _permission(
      generation,
      account,
    ); // Access revoked during query must retain prior projections.
    await _command(generation, account, 'device_snapshot', {
      'manual': manual,
      'start': from.toUtc().toIso8601String(),
      'end': until.toUtc().toIso8601String(),
      'sources': [
        for (final source in sources)
          {
            'id': source.id,
            'events':
                snapshot.eventsByCalendar[source.nativeId] ??
                (throw const DeviceCalendarFailure('incomplete_snapshot')),
          },
      ],
    });
    _coverage.removeWhere(
      (range) => !range.from.isBefore(from) && !range.until.isAfter(until),
    );
    _coverage.add((from: from, until: until, at: now));
    if (_coverage.length > 24) _coverage.removeAt(0);
    _pendingRanges.removeWhere(
      (range) => !range.from.isBefore(from) && !range.until.isAfter(until),
    );
    repository.projectionChanged();
    if (status.automatic) _observe();
  }

  void _observe() {
    if (_changes != null || !_started || !status.automatic || !isOwner) return;
    _changes = bridge.changes.listen(
      (_) {
        _queueNativeRefresh();
      },
      onError: (Object _) {
        unawaited(_changes?.cancel());
        _changes = null;
      },
    );
  }

  void _queueNativeRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (!status.automatic || !isOwner || choosing || !_started) return;
      if (busy) {
        _queueNativeRefresh();
      } else {
        unawaited(_catchUp(force: true));
      }
    });
  }

  @override
  void dispose() {
    stop();
    _disposed = true;
    super.dispose();
  }
}
