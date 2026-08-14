import 'calendar_snapshot_backend.dart';
import 'hive_calendar_snapshot_backend.dart';

CalendarSnapshotBackend createPlatformCalendarSnapshotBackend() =>
    HiveCalendarSnapshotBackend();
