import 'calendar_snapshot_backend.dart';
import 'calendar_snapshot_backend_factory_native.dart'
    if (dart.library.js_interop) 'calendar_snapshot_backend_factory_web.dart';

CalendarSnapshotBackend createCalendarSnapshotBackend() =>
    createPlatformCalendarSnapshotBackend();
