import 'dart:async';

typedef ReminderSyncTask = Future<void> Function();

/// Coalesces reminder sync requests and lets orientation-critical rendering
/// pause non-urgent sync work without losing pending requests.
class ReminderSyncGate {
  Completer<void>? _orientationCriticalCompleter;
  Completer<void>? _syncFlightCompleter;
  int _pendingSyncRequests = 0;
  bool _taskRunning = false;
  bool _disposed = false;

  bool get isOrientationCritical => _orientationCriticalCompleter != null;

  bool get isSyncInFlight => _syncFlightCompleter != null;

  void beginOrientationCriticalSection() {
    if (_disposed || _orientationCriticalCompleter != null) return;
    _orientationCriticalCompleter = Completer<void>();
  }

  void endOrientationCriticalSection() {
    final completer = _orientationCriticalCompleter;
    _orientationCriticalCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> waitForOrientationCriticalSection() async {
    while (!_disposed) {
      final completer = _orientationCriticalCompleter;
      if (completer == null || completer.isCompleted) return;
      await completer.future;
    }
  }

  Future<void> runCoalesced(ReminderSyncTask task) {
    if (_disposed) return Future<void>.value();
    final existingFlight = _syncFlightCompleter;
    if (existingFlight != null) {
      if (_taskRunning) {
        _pendingSyncRequests = 1;
      }
      return existingFlight.future;
    }

    _pendingSyncRequests = 1;
    final flight = Completer<void>();
    _syncFlightCompleter = flight;
    unawaited(_drain(task, flight));
    return flight.future;
  }

  Future<void> _drain(ReminderSyncTask task, Completer<void> flight) async {
    try {
      while (!_disposed && _pendingSyncRequests > 0) {
        _pendingSyncRequests = 0;
        await waitForOrientationCriticalSection();
        if (_disposed) break;
        _taskRunning = true;
        try {
          await task();
        } finally {
          _taskRunning = false;
        }
      }
      if (!flight.isCompleted) {
        flight.complete();
      }
    } catch (error, stackTrace) {
      if (!flight.isCompleted) {
        flight.completeError(error, stackTrace);
      }
    } finally {
      if (identical(_syncFlightCompleter, flight)) {
        _syncFlightCompleter = null;
      }
    }
  }

  void dispose() {
    _disposed = true;
    _pendingSyncRequests = 0;
    _taskRunning = false;
    endOrientationCriticalSection();
    final flight = _syncFlightCompleter;
    _syncFlightCompleter = null;
    if (flight != null && !flight.isCompleted) {
      flight.complete();
    }
  }
}
