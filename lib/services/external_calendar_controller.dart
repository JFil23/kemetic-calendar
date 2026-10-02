import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/external_calendar_repository.dart';

class ExternalCalendarController extends ChangeNotifier
    with WidgetsBindingObserver {
  ExternalCalendarController(
    this.repository, {
    this.retryInterval = const Duration(minutes: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final ExternalCalendarRepository repository;
  final Duration retryInterval;
  final DateTime Function() _now;
  ExternalCalendarStatus? status;
  ExternalCalendarFailure? error;
  bool busy = false, choosingCalendars = false;
  Set<String> selectedSourceIds = {};
  Timer? _timer;
  Timer? _rangeTimer;
  (DateTime, DateTime)? _pendingRange;
  final Map<String, DateTime> _rangeRetryAt = {};
  String? _owner;
  int _generation = 0;
  bool _disposed = false, _started = false, _foreground = true;
  DateTime? _lastAttempt;
  int get generation => _generation;
  String? get accountId => repository.accountId;

  void _checkAccount() {
    if (_owner == accountId) return;
    _owner = accountId;
    _generation++;
    status = null;
    error = null;
    busy = false;
    choosingCalendars = false;
    selectedSourceIds = {};
    _lastAttempt = null;
    _rangeRetryAt.clear();
    _rangeTimer?.cancel();
    _pendingRange = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int generation, String? owner) =>
      !_disposed && generation == _generation && owner == accountId;

  Future<T?> _run<T>(
    Future<T> Function() operation,
    void Function(T) accept,
  ) async {
    if (_disposed) return null;
    _checkAccount();
    if (busy || accountId == null) return null;
    final generation = _generation;
    final owner = accountId;
    busy = true;
    error = null;
    _lastAttempt = _now();
    _notify();
    try {
      final result = await operation();
      if (!_current(generation, owner)) return null;
      accept(result);
      return result;
    } catch (failure) {
      if (_current(generation, owner)) {
        error = failure is ExternalCalendarFailure
            ? failure
            : const ExternalCalendarFailure(
                code: 'unavailable',
                retryable: true,
              );
      }
      return null;
    } finally {
      if (_current(generation, owner)) {
        busy = false;
        _notify();
      }
    }
  }

  void _accept(ExternalCalendarStatus value) {
    status = value;
    error = value.errorCode == null
        ? null
        : ExternalCalendarFailure(
            code: value.errorCode!,
            retryable: !value.requiresReconnect,
          );
  }

  Future<void> loadStatus() async {
    _checkAccount();
    if (choosingCalendars) return;
    await _run(() => repository.statusCommand('status'), (value) {
      _accept(value);
    });
  }

  Future<Uri?> connect() async => _run(() async {
    final response = await repository.command(
      'connect',
      arguments: {
        'return_target':
            !kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.iOS ||
                    defaultTargetPlatform == TargetPlatform.android)
            ? 'native'
            : 'web',
      },
    );
    final uri = Uri.tryParse(response['authorization_url'] as String? ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'accounts.google.com') {
      throw const ExternalCalendarFailure(code: 'invalid_authorization_url');
    }
    return uri;
  }, (_) {});

  Future<void> chooseCalendars() async {
    await _run(() => repository.statusCommand('sources'), (value) {
      _accept(value);
      selectedSourceIds = {
        for (final source in value.sources)
          if (source.selected) source.id,
      };
      choosingCalendars = true;
    });
  }

  void setSourceSelected(String id, bool selected) {
    _checkAccount();
    if (busy ||
        !choosingCalendars ||
        !(status?.sources.any((s) => s.id == id) ?? false)) {
      return;
    }
    selectedSourceIds = {...selectedSourceIds};
    if (selected) {
      selectedSourceIds.add(id);
    } else {
      selectedSourceIds.remove(id);
    }
    _notify();
  }

  void cancelSelection() {
    if (busy) return;
    choosingCalendars = false;
    selectedSourceIds = {};
    _notify();
  }

  Map<String, dynamic> get _revision => {'expected_revision': status?.revision};

  Future<void> saveSelection() async {
    _checkAccount();
    if (!choosingCalendars) return;
    final owner = accountId;
    final generation = _generation;
    final selected = selectedSourceIds.toList()..sort();
    final changed = await _run(
      () => repository.statusCommand(
        'select_sources',
        arguments: {..._revision, 'source_ids': selected},
      ),
      (value) {
        _accept(value);
        choosingCalendars = false;
        repository.projectionChanged(removedSources: true);
      },
    );
    if (changed != null && selected.isNotEmpty && _current(generation, owner)) {
      await refresh();
    }
  }

  Future<void> refresh() async {
    await _run(
      () {
        final now = _now();
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 30));
        final end = DateTime(now.year, now.month, now.day + 181);
        return repository.statusCommand(
          'refresh',
          arguments: {
            'start': start.toUtc().toIso8601String(),
            'end': end.toUtc().toIso8601String(),
            'time_zone': 'UTC',
          },
        );
      },
      (value) {
        _accept(value);
        repository.projectionChanged();
      },
    );
  }

  Future<void> setAutomatic(bool enabled) async {
    await _run(
      () => repository.statusCommand(
        enabled ? 'resume' : 'pause',
        arguments: _revision,
      ),
      (value) {
        _accept(value);
      },
    );
  }

  Future<void> disconnect() async {
    await _run(
      () => repository.statusCommand('disconnect', arguments: _revision),
      (value) {
        _accept(value);
        choosingCalendars = false;
        selectedSourceIds = {};
        repository.projectionChanged(removedSources: true);
      },
    );
  }

  /// Install retry/resume hooks before any network request. A failed initial
  /// status request must not disable future refresh for this app lifetime.
  void start() {
    if (_disposed) return;
    _checkAccount();
    if (!_started) {
      // stop() removes the observer, so a resume may have happened while this
      // account was inactive. Rejoin the actual lifecycle before doing work.
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
      _started = true;
      WidgetsBinding.instance.addObserver(this);
      repository.addVisibleRangeListener(ensureRange);
      _timer = Timer.periodic(retryInterval, (_) => unawaited(_tick()));
    }
    unawaited(_tick(force: true).then((_) => _drainRange()));
  }

  void ensureRange(DateTime from, DateTime until) {
    if (!_started ||
        !_foreground ||
        !until.isAfter(from) ||
        until.difference(from).inDays > 730) {
      return;
    }
    _pendingRange = (from, until);
    _rangeTimer?.cancel();
    _rangeTimer = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(_drainRange()),
    );
  }

  Future<void> _drainRange() async {
    if (_owner != accountId) {
      _checkAccount();
      return;
    }
    final pending = _pendingRange;
    if (!_started ||
        !_foreground ||
        busy ||
        pending == null ||
        status?.available != true ||
        status?.syncing == true ||
        status?.automatic != true ||
        status?.requiresReconnect == true ||
        (status?.retryAt?.isAfter(_now()) ?? false)) {
      return;
    }
    final (from, until) = pending;
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    if (!from.isBefore(today.subtract(const Duration(days: 29))) &&
        !until.isAfter(DateTime(now.year, now.month, now.day + 179))) {
      return;
    }
    final key = '${status?.connectionId}:${status?.revision}:$from:$until';
    final previous = _rangeRetryAt[key];
    if (previous != null && now.isBefore(previous)) {
      return;
    }
    _rangeRetryAt[key] = now.add(const Duration(minutes: 1));
    final result = await _run(
      () => repository.statusCommand(
        'refresh',
        arguments: {
          'start': from.toUtc().toIso8601String(),
          'end': until.toUtc().toIso8601String(),
          'time_zone': 'UTC',
        },
      ),
      (value) {
        _accept(value);
        repository.projectionChanged();
      },
    );
    if (result != null) {
      _rangeRetryAt[key] = _now().add(const Duration(minutes: 15));
    }
  }

  Future<void> _tick({bool force = false}) async {
    if (!_started || !_foreground || _disposed) return;
    _checkAccount();
    if (busy || choosingCalendars || accountId == null) return;
    if (!force &&
        _lastAttempt != null &&
        _now().difference(_lastAttempt!) < retryInterval) {
      return;
    }
    final owner = accountId;
    final generation = _generation;
    await loadStatus();
    if (!_current(generation, owner) ||
        !_started ||
        _disposed ||
        (error != null && status?.errorCode == null) ||
        status?.available != true ||
        status?.syncing == true ||
        status?.automatic != true ||
        status?.requiresReconnect == true ||
        (status?.retryAt?.isAfter(_now()) ?? false)) {
      return;
    }
    final lastSync = status?.lastSyncedAt;
    if (lastSync == null ||
        _now().difference(lastSync) >= const Duration(minutes: 15)) {
      await refresh();
    }
    if (_current(generation, owner) && error == null) await _drainRange();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(_tick(force: true));
  }

  void stop() {
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _started = false;
    _timer?.cancel();
    _timer = null;
    _rangeTimer?.cancel();
    _rangeTimer = null;
    _pendingRange = null;
    repository.removeVisibleRangeListener(ensureRange);
    repository.forgetPresentation();
    _generation++;
    _owner = null;
    status = null;
    error = null;
    busy = false;
    choosingCalendars = false;
    selectedSourceIds = {};
    _notify();
  }

  @override
  void dispose() {
    stop();
    _disposed = true;
    super.dispose();
  }
}

ExternalCalendarController? _sharedExternalController;
ExternalCalendarController externalCalendarController(SupabaseClient client) {
  final current = _sharedExternalController;
  if (current != null && identical(current.repository.client, client)) {
    return current;
  }
  current?.dispose();
  return _sharedExternalController = ExternalCalendarController(
    externalCalendarRepository(client),
  );
}

void disposeSharedExternalCalendarController() {
  _sharedExternalController?.dispose();
  _sharedExternalController = null;
}
