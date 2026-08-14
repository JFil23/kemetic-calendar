import 'calendar_snapshot_backend_factory.dart';
import 'calendar_snapshot_store.dart';

/// Process-wide durable calendar owner. Opening is lazy; importing this file
/// performs no storage work before the first read or commit.
final CalendarSnapshotStore calendarSnapshotStore = CalendarSnapshotStore(
  createCalendarSnapshotBackend(),
);
