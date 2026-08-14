import 'dart:async';

import 'calendar_snapshot_context.dart';

final Map<String, Future<void>> _tails = <String, Future<void>>{};
final StreamController<String> _changes = StreamController<String>.broadcast();

CalendarSnapshotContextCoordinator
createPlatformCalendarSnapshotContextCoordinator() =>
    _LocalCalendarSnapshotContextCoordinator();

final class _LocalCalendarSnapshotContextCoordinator
    implements CalendarSnapshotContextCoordinator {
  @override
  Future<T> withExclusiveLock<T>(
    String name,
    Future<T> Function() action,
  ) async {
    final predecessor = _tails[name] ?? Future<void>.value();
    final release = Completer<void>();
    _tails[name] = release.future;
    await predecessor;
    try {
      return await action();
    } finally {
      release.complete();
      if (identical(_tails[name], release.future)) _tails.remove(name);
    }
  }

  @override
  Stream<String> get changes => _changes.stream;

  @override
  void publish(String key) => _changes.add(key);

  @override
  Future<void> close() async {}
}
