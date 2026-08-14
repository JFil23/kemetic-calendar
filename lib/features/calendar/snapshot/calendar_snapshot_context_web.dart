import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'calendar_snapshot_context.dart';

CalendarSnapshotContextCoordinator
createPlatformCalendarSnapshotContextCoordinator() =>
    _WebCalendarSnapshotContextCoordinator();

final class _WebCalendarSnapshotContextCoordinator
    implements CalendarSnapshotContextCoordinator {
  _WebCalendarSnapshotContextCoordinator() {
    _channel.onmessage = _handleMessage.toJS;
  }

  static const String _channelName = 'kemet.calendar.snapshot.v1';
  final web.BroadcastChannel _channel = web.BroadcastChannel(_channelName);
  final StreamController<String> _changes = StreamController.broadcast();

  void _handleMessage(web.Event event) {
    if (!event.isA<web.MessageEvent>()) return;
    final value = (event as web.MessageEvent).data.dartify();
    if (value is String && value.isNotEmpty) _changes.add(value);
  }

  @override
  Future<T> withExclusiveLock<T>(
    String name,
    Future<T> Function() action,
  ) async {
    T? result;
    Object? failure;
    StackTrace? failureStack;

    Future<JSAny?> run() async {
      try {
        result = await action();
      } catch (error, stackTrace) {
        failure = error;
        failureStack = stackTrace;
      }
      return null;
    }

    await web.window.navigator.locks
        .request(
          name,
          web.LockOptions(mode: 'exclusive'),
          ((web.Lock _) => run().toJS).toJS,
        )
        .toDart;
    if (failure != null) {
      Error.throwWithStackTrace(failure!, failureStack ?? StackTrace.current);
    }
    return result as T;
  }

  @override
  Stream<String> get changes => _changes.stream;

  @override
  void publish(String key) => _channel.postMessage(key.toJS);

  @override
  Future<void> close() async {
    _channel.close();
    await _changes.close();
  }
}
