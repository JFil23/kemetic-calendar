import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile/features/calendar/calendar_geometry_snapshot.dart';
import 'package:mobile/features/calendar/calendar_section_index.dart';

/// Owns the passive, mounted-only geometry view of the portrait calendar.
///
/// Render objects only mark this collector dirty during layout. Final
/// coordinates are read after the frame, when every ancestor has assigned its
/// child offsets. Publication is atomic and does not schedule another frame.
final class CalendarGeometryCollector extends ChangeNotifier {
  final Set<RenderCalendarGeometrySection> _mountedSections =
      <RenderCalendarGeometrySection>{};

  CalendarGeometrySnapshot? _snapshot;
  List<CalendarSectionGeometry> _lastCandidate = const [];
  bool _publicationScheduled = false;
  bool _disposed = false;
  int _nextGeneration = 0;
  int _scheduledPublicationCount = 0;
  int _publicationCount = 0;
  int _rejectedPublicationCount = 0;
  Object? _lastRejection;

  CalendarGeometrySnapshot? get snapshot => _snapshot;

  int get debugMountedSectionCount => _mountedSections.length;

  int get debugScheduledPublicationCount => _scheduledPublicationCount;

  int get debugPublicationCount => _publicationCount;

  int get debugRejectedPublicationCount => _rejectedPublicationCount;

  @visibleForTesting
  Object? get debugLastRejection => _lastRejection;

  @visibleForTesting
  List<CalendarSectionGeometry> get debugLastCandidate => _lastCandidate;

  void _register(RenderCalendarGeometrySection section) {
    if (_disposed) return;
    if (_mountedSections.add(section)) _markNeedsPublication();
  }

  void _unregister(RenderCalendarGeometrySection section) {
    if (_disposed) return;
    if (_mountedSections.remove(section)) _markNeedsPublication();
  }

  void _didLayout(RenderCalendarGeometrySection section) {
    if (_disposed || !_mountedSections.contains(section)) return;
    _markNeedsPublication();
  }

  void _didChangeIdentity(RenderCalendarGeometrySection section) {
    if (_disposed || !_mountedSections.contains(section)) return;
    _markNeedsPublication();
  }

  void _markNeedsPublication() {
    if (_disposed || _publicationScheduled) return;
    _publicationScheduled = true;
    _scheduledPublicationCount++;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _publicationScheduled = false;
      if (_disposed) return;
      _publishMountedGeometry();
    }, debugLabel: 'CalendarGeometryCollector.publish');
  }

  void _publishMountedGeometry() {
    final geometries = <CalendarSectionGeometry>[];
    for (final section in _mountedSections) {
      if (!section.attached || !section.hasSize || section.size.height <= 0) {
        continue;
      }
      final viewport = RenderAbstractViewport.maybeOf(section);
      if (viewport == null) continue;

      final leading = viewport.getOffsetToReveal(section, 0).offset;
      final trailing = leading + section.size.height;
      if (!leading.isFinite || !trailing.isFinite || trailing <= leading) {
        continue;
      }
      geometries.add(
        CalendarSectionGeometry(
          month: section.month,
          extent: CalendarCanonicalExtent(leading: leading, trailing: trailing),
        ),
      );
    }

    geometries.sort((left, right) => left.month.compareTo(right.month));
    if (_sameGeometry(_lastCandidate, geometries)) return;
    _lastCandidate = List<CalendarSectionGeometry>.unmodifiable(geometries);

    late final CalendarGeometrySnapshot next;
    try {
      next = CalendarGeometrySnapshot(
        generation: _nextGeneration,
        sections: geometries,
      );
    } on ArgumentError catch (error) {
      // Never replace the last coherent snapshot with a mixed or invalid
      // geometry generation. Phase gates inspect every rejection.
      _lastRejection = error;
      _rejectedPublicationCount++;
      return;
    }
    _nextGeneration++;
    _snapshot = next;
    _lastRejection = null;
    _publicationCount++;
    notifyListeners();
  }

  bool _sameGeometry(
    List<CalendarSectionGeometry>? previous,
    List<CalendarSectionGeometry> next,
  ) {
    if (previous == null || previous.length != next.length) return false;
    for (var index = 0; index < next.length; index++) {
      if (previous[index] != next[index]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _mountedSections.clear();
    _lastCandidate = const [];
    super.dispose();
  }
}

/// Makes one page-owned collector available without rebuilding for snapshots.
final class CalendarGeometryCollectorScope extends InheritedWidget {
  const CalendarGeometryCollectorScope({
    super.key,
    required this.collector,
    required super.child,
  });

  final CalendarGeometryCollector collector;

  static CalendarGeometryCollector? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<CalendarGeometryCollectorScope>()
        ?.collector;
  }

  @override
  bool updateShouldNotify(CalendarGeometryCollectorScope oldWidget) {
    return collector != oldWidget.collector;
  }
}

/// Marks one complete logical month section in the render tree.
final class CalendarGeometrySection extends SingleChildRenderObjectWidget {
  const CalendarGeometrySection({
    super.key,
    required this.month,
    required super.child,
  });

  final MonthRef month;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderCalendarGeometrySection(
      month: month,
      collector: CalendarGeometryCollectorScope.maybeOf(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCalendarGeometrySection renderObject,
  ) {
    renderObject
      ..collector = CalendarGeometryCollectorScope.maybeOf(context)
      ..month = month;
  }
}

/// Render proxy used by [CalendarGeometrySection].
///
/// It deliberately exposes no geometry-reading API. The page-level collector
/// reads all mounted proxies together after layout and publishes atomically.
final class RenderCalendarGeometrySection extends RenderProxyBox {
  RenderCalendarGeometrySection({
    required MonthRef month,
    required CalendarGeometryCollector? collector,
  }) : _month = month,
       _collector = collector;

  MonthRef _month;
  CalendarGeometryCollector? _collector;

  MonthRef get month => _month;

  set month(MonthRef value) {
    if (_month == value) return;
    _month = value;
    _collector?._didChangeIdentity(this);
  }

  set collector(CalendarGeometryCollector? value) {
    if (_collector == value) return;
    if (attached) _collector?._unregister(this);
    _collector = value;
    if (attached) _collector?._register(this);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _collector?._register(this);
  }

  @override
  void detach() {
    _collector?._unregister(this);
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    _collector?._didLayout(this);
  }
}
