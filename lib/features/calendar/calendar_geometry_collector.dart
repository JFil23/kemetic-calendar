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
  final Set<RenderCalendarGeometryMonthBody> _mountedBodies =
      <RenderCalendarGeometryMonthBody>{};
  final Set<RenderCalendarGeometryFinalDayBlock> _mountedFinalDayBlocks =
      <RenderCalendarGeometryFinalDayBlock>{};

  CalendarGeometrySnapshot? _snapshot;
  List<CalendarSectionGeometry> _lastCandidate = const [];
  bool _publicationScheduled = false;
  bool _disposed = false;
  int _nextGeneration = 0;
  int _scheduledPublicationCount = 0;
  int _publicationCount = 0;
  int _rejectedPublicationCount = 0;
  Object? _lastRejection;
  String? _presentationRevision;

  CalendarGeometrySnapshot? get snapshot => _snapshot;

  int get debugMountedSectionCount => _mountedSections.length;

  int get debugMountedBodyCount => _mountedBodies.length;

  int get debugMountedFinalDayBlockCount => _mountedFinalDayBlocks.length;

  int get debugScheduledPublicationCount => _scheduledPublicationCount;

  int get debugPublicationCount => _publicationCount;

  int get debugRejectedPublicationCount => _rejectedPublicationCount;

  @visibleForTesting
  Object? get debugLastRejection => _lastRejection;

  String? get presentationRevision => _presentationRevision;

  /// Invalidates the old geometry view before an extent-affecting projection
  /// is installed. Consumers observe either the previous coherent epoch or no
  /// geometry until layout publishes the matching revision.
  void beginPresentationEpoch(String revision) {
    final normalized = revision.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(revision, 'revision', 'must not be empty');
    }
    _presentationRevision = normalized;
    _snapshot = null;
    _lastCandidate = const [];
    _markNeedsPublication();
  }

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

  void _registerBody(RenderCalendarGeometryMonthBody body) {
    if (_disposed) return;
    if (_mountedBodies.add(body)) _markNeedsPublication();
  }

  void _unregisterBody(RenderCalendarGeometryMonthBody body) {
    if (_disposed) return;
    if (_mountedBodies.remove(body)) _markNeedsPublication();
  }

  void _didLayoutBody(RenderCalendarGeometryMonthBody body) {
    if (_disposed || !_mountedBodies.contains(body)) return;
    _markNeedsPublication();
  }

  void _didChangeBodyIdentity(RenderCalendarGeometryMonthBody body) {
    if (_disposed || !_mountedBodies.contains(body)) return;
    _markNeedsPublication();
  }

  void _registerFinalDayBlock(RenderCalendarGeometryFinalDayBlock block) {
    if (_disposed) return;
    if (_mountedFinalDayBlocks.add(block)) _markNeedsPublication();
  }

  void _unregisterFinalDayBlock(RenderCalendarGeometryFinalDayBlock block) {
    if (_disposed) return;
    if (_mountedFinalDayBlocks.remove(block)) _markNeedsPublication();
  }

  void _didLayoutFinalDayBlock(RenderCalendarGeometryFinalDayBlock block) {
    if (_disposed || !_mountedFinalDayBlocks.contains(block)) return;
    _markNeedsPublication();
  }

  void _didChangeFinalDayBlockIdentity(
    RenderCalendarGeometryFinalDayBlock block,
  ) {
    if (_disposed || !_mountedFinalDayBlocks.contains(block)) return;
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
    final bodyLeadingByMonth = <MonthRef, double>{};
    for (final body in _mountedBodies) {
      if (!body.attached || !body.hasSize || body.size.height <= 0) continue;
      final viewport = RenderAbstractViewport.maybeOf(body);
      if (viewport == null) continue;
      final leading = viewport.getOffsetToReveal(body, 0).offset;
      if (!leading.isFinite) continue;
      bodyLeadingByMonth[body.month] = leading;
    }

    final finalDayBlockLeadingByMonth = <MonthRef, double>{};
    for (final block in _mountedFinalDayBlocks) {
      if (!block.attached || !block.hasSize || block.size.height <= 0) continue;
      final viewport = RenderAbstractViewport.maybeOf(block);
      if (viewport == null) continue;
      final leading = viewport.getOffsetToReveal(block, 0).offset;
      if (!leading.isFinite) continue;
      finalDayBlockLeadingByMonth[block.month] = leading;
    }

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
          bodyLeading: bodyLeadingByMonth[section.month],
          finalDayBlockLeading: finalDayBlockLeadingByMonth[section.month],
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
        presentationRevision: _presentationRevision,
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
    _mountedBodies.clear();
    _mountedFinalDayBlocks.clear();
    _lastCandidate = const [];
    super.dispose();
  }
}

/// Marks the measured handoff edge before a month's final visible day block.
///
/// For a regular month, the child starts immediately after the third-decan
/// label and contains the label-to-weekday gap plus the final weekday row. For
/// Heriu Renpet, the child is its sole weekday row. The collector never treats
/// this proxy's height as ownership.
final class CalendarGeometryFinalDayBlock
    extends SingleChildRenderObjectWidget {
  const CalendarGeometryFinalDayBlock({
    super.key,
    required this.month,
    required super.child,
  });

  final MonthRef month;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderCalendarGeometryFinalDayBlock(
      month: month,
      collector: CalendarGeometryCollectorScope.maybeOf(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCalendarGeometryFinalDayBlock renderObject,
  ) {
    renderObject
      ..collector = CalendarGeometryCollectorScope.maybeOf(context)
      ..month = month;
  }
}

/// Render proxy used by [CalendarGeometryFinalDayBlock].
final class RenderCalendarGeometryFinalDayBlock extends RenderProxyBox {
  RenderCalendarGeometryFinalDayBlock({
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
    _collector?._didChangeFinalDayBlockIdentity(this);
  }

  set collector(CalendarGeometryCollector? value) {
    if (_collector == value) return;
    if (attached) _collector?._unregisterFinalDayBlock(this);
    _collector = value;
    if (attached) _collector?._registerFinalDayBlock(this);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _collector?._registerFinalDayBlock(this);
  }

  @override
  void detach() {
    _collector?._unregisterFinalDayBlock(this);
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    _collector?._didLayoutFinalDayBlock(this);
  }
}

/// Marks the month-card boundary inside a complete logical month section.
///
/// The collector uses this only to distinguish a following-month divider or
/// season header from the month body in passive diagnostics.
final class CalendarGeometryMonthBody extends SingleChildRenderObjectWidget {
  const CalendarGeometryMonthBody({
    super.key,
    required this.month,
    required super.child,
  });

  final MonthRef month;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderCalendarGeometryMonthBody(
      month: month,
      collector: CalendarGeometryCollectorScope.maybeOf(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCalendarGeometryMonthBody renderObject,
  ) {
    renderObject
      ..collector = CalendarGeometryCollectorScope.maybeOf(context)
      ..month = month;
  }
}

/// Render proxy used by [CalendarGeometryMonthBody].
final class RenderCalendarGeometryMonthBody extends RenderProxyBox {
  RenderCalendarGeometryMonthBody({
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
    _collector?._didChangeBodyIdentity(this);
  }

  set collector(CalendarGeometryCollector? value) {
    if (_collector == value) return;
    if (attached) _collector?._unregisterBody(this);
    _collector = value;
    if (attached) _collector?._registerBody(this);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _collector?._registerBody(this);
  }

  @override
  void detach() {
    _collector?._unregisterBody(this);
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    _collector?._didLayoutBody(this);
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
