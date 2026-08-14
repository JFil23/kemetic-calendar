import 'calendar_snapshot_context_stub.dart'
    if (dart.library.js_interop) 'calendar_snapshot_context_web.dart';

abstract interface class CalendarSnapshotContextCoordinator {
  Future<T> withExclusiveLock<T>(String name, Future<T> Function() action);

  Stream<String> get changes;

  void publish(String key);

  Future<void> close();
}

CalendarSnapshotContextCoordinator createCalendarSnapshotContextCoordinator() =>
    createPlatformCalendarSnapshotContextCoordinator();
