import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import '../../core/pinch_gesture_surface.dart';
import '../../services/app_haptics.dart';
import '../../services/app_restoration_service.dart';
import '../../widgets/calendar_floating_shortcuts.dart';
import '../../widgets/month_name_text.dart';
import 'day_view.dart';
import 'calendar_page.dart' show CalendarPage, EndFlowOutcome, KemeticMath;
import 'kemetic_month_metadata.dart';
import 'landscape_timeline_viewport.dart';
import 'maat_flow_response_journal_blocks.dart';

const Color _landscapeGold = Color(0xFFD4AE43);
const double kLandscapeHeaderHeight = 58;

class LandscapeMonthView extends StatelessWidget {
  final int initialKy;
  final int initialKm;
  final int? initialKd; // Optional - from day view
  final DateTime Function()? clock;
  final void Function(int ky, int km, int kd)? onVisibleDayChanged;
  final VoidCallback? onClose;
  final VoidCallback? onOpenCalendars;
  final VoidCallback? onOpenInbox;
  final VoidCallback? onToggleCalendar;
  final Future<void> Function(BuildContext context)? onOpenSearch;
  final Future<void> Function(BuildContext context)? onOpenProfile;
  final bool showGregorian;
  final ValueListenable<int>? dataVersion;
  final List<NoteData> Function(int ky, int km, int kd) notesForDay;
  final Map<int, FlowData> flowIndex;
  final Set<int> activeLedgerFlowIds;
  final String Function(int km) getMonthName;
  final void Function(int? flowId)? onManageFlows;
  final Future<void> Function(BuildContext context)? onOpenQuickAdd;
  final void Function(int ky, int km, int kd)? onAddNote;
  final void Function(int ky, int km)? onMonthChanged; // ✅ NEW CALLBACK
  final void Function(int ky, int km)? onVisibleMonthCommitted;
  final ValueChanged<VoidCallback?>? onTodayActionChanged;
  final Future<EndFlowOutcome> Function(int flowId)? onEndFlow;
  final Future<void> Function(int ky, int km, int kd, EventItem evt)?
  onDeleteNote;
  final Future<void> Function(int ky, int km, int kd, EventItem evt)?
  onEditNote;
  final Future<void> Function(String reminderId)? onEditReminder;
  final Future<void> Function(String reminderId)? onEndReminder;
  final Future<void> Function(EventItem evt)? onShareReminder;
  final Future<void> Function(
    int ky,
    int km,
    int kd,
    EventItem evt,
    int newStartMin,
  )?
  onMoveEventTime;
  final DayViewMoveFollowSkyEventTime? onMoveFollowSkyEventTime;
  final Future<bool> Function({
    required int ky,
    required int km,
    required int kd,
    required EventItem event,
    required Duration extension,
  })?
  onRequestEndChange;
  final Future<void> Function(EventItem evt)? onShareNote;
  final Future<void> Function(String text)? onAppendToJournal;
  final MaatJournalResponseBlockWriter? onWriteJournalResponse;
  final Future<void> Function(int flowId)? onSaveFlow;
  final Future<void> Function({
    required String clientEventId,
    required int flowId,
    required DateTime completedOnDate,
    Map<String, dynamic>? metadata,
  })?
  onRecordCompletion;
  final Future<void> Function(String clientEventId)? onUnrecordCompletion;
  final Future<void> Function(String badgeId)? onRemoveCompletionBadge;
  final EventDetailRestorationState? initialEventDetailRestorationState;
  final ValueChanged<EventDetailRestorationState?>?
  onEventDetailRestorationChanged;
  final bool Function()? shouldPreserveEventDetailRestorationOnClose;
  final bool embeddedInCalendarScaffold;

  const LandscapeMonthView({
    super.key,
    required this.initialKy,
    required this.initialKm,
    this.initialKd,
    required this.showGregorian,
    this.clock,
    this.onClose,
    this.onOpenCalendars,
    this.onOpenInbox,
    this.onToggleCalendar,
    this.onOpenSearch,
    this.onOpenProfile,
    this.onVisibleDayChanged,
    this.dataVersion,
    required this.notesForDay,
    required this.flowIndex,
    this.activeLedgerFlowIds = const <int>{},
    required this.getMonthName,
    this.onManageFlows,
    this.onOpenQuickAdd,
    this.onAddNote,
    this.onMonthChanged, // ✅ NEW CALLBACK
    this.onVisibleMonthCommitted,
    this.onTodayActionChanged,
    this.onEndFlow,
    this.onDeleteNote,
    this.onEditNote,
    this.onEditReminder,
    this.onEndReminder,
    this.onShareReminder,
    this.onMoveEventTime,
    this.onMoveFollowSkyEventTime,
    this.onRequestEndChange,
    this.onShareNote,
    this.onAppendToJournal,
    this.onWriteJournalResponse,
    this.onSaveFlow,
    this.onRecordCompletion,
    this.onUnrecordCompletion,
    this.onRemoveCompletionBadge,
    this.initialEventDetailRestorationState,
    this.onEventDetailRestorationChanged,
    this.shouldPreserveEventDetailRestorationOnClose,
    this.embeddedInCalendarScaffold = false,
  });

  @override
  Widget build(BuildContext context) {
    return LandscapeMonthPager(
      initialKy: initialKy,
      initialKm: initialKm,
      initialDay: initialKd,
      showGregorian: showGregorian,
      clock: clock,
      onClose: onClose,
      onOpenCalendars: onOpenCalendars,
      onOpenInbox: onOpenInbox,
      onToggleCalendar: onToggleCalendar,
      onOpenSearch: onOpenSearch,
      onOpenProfile: onOpenProfile,
      onVisibleDayChanged: onVisibleDayChanged,
      dataVersion: dataVersion,
      notesForDay: notesForDay,
      flowIndex: flowIndex,
      activeLedgerFlowIds: activeLedgerFlowIds,
      getMonthName: getMonthName,
      onManageFlows: onManageFlows,
      onOpenQuickAdd: onOpenQuickAdd,
      onAddNote: onAddNote,
      onMonthChanged: onMonthChanged, // ✅ PASS CALLBACK DOWN
      onVisibleMonthCommitted: onVisibleMonthCommitted,
      onTodayActionChanged: onTodayActionChanged,
      onEndFlow: onEndFlow,
      onDeleteNote: onDeleteNote,
      onEditNote: onEditNote,
      onEditReminder: onEditReminder,
      onEndReminder: onEndReminder,
      onShareReminder: onShareReminder,
      onMoveEventTime: onMoveEventTime,
      onMoveFollowSkyEventTime: onMoveFollowSkyEventTime,
      onRequestEndChange: onRequestEndChange,
      onShareNote: onShareNote,
      onAppendToJournal: onAppendToJournal,
      onWriteJournalResponse: onWriteJournalResponse,
      onSaveFlow: onSaveFlow,
      onRecordCompletion: onRecordCompletion,
      onUnrecordCompletion: onUnrecordCompletion,
      onRemoveCompletionBadge: onRemoveCompletionBadge,
      initialEventDetailRestorationState: initialEventDetailRestorationState,
      onEventDetailRestorationChanged: onEventDetailRestorationChanged,
      shouldPreserveEventDetailRestorationOnClose:
          shouldPreserveEventDetailRestorationOnClose,
      embeddedInCalendarScaffold: embeddedInCalendarScaffold,
    );
  }
}

// ========================================
// SHARED LANDSCAPE SURFACE
// Retains the entry API while scrolling continuous civil days.
// ========================================

class LandscapeMonthPager extends StatefulWidget {
  final int initialKy;
  final int initialKm;
  final int? initialDay;
  final DateTime Function()? clock;
  final void Function(int ky, int km, int kd)? onVisibleDayChanged;
  final VoidCallback? onClose;
  final VoidCallback? onOpenCalendars;
  final VoidCallback? onOpenInbox;
  final VoidCallback? onToggleCalendar;
  final Future<void> Function(BuildContext context)? onOpenSearch;
  final Future<void> Function(BuildContext context)? onOpenProfile;
  final bool showGregorian;
  final ValueListenable<int>? dataVersion;
  final List<NoteData> Function(int ky, int km, int kd) notesForDay;
  final Map<int, FlowData> flowIndex;
  final Set<int> activeLedgerFlowIds;
  final String Function(int km) getMonthName;
  final void Function(int? flowId)? onManageFlows;
  final Future<void> Function(BuildContext context)? onOpenQuickAdd;
  final void Function(int ky, int km, int kd)? onAddNote;
  final void Function(int ky, int km)? onMonthChanged; // ✅ NEW CALLBACK
  final void Function(int ky, int km)? onVisibleMonthCommitted;
  final ValueChanged<VoidCallback?>? onTodayActionChanged;
  final Future<EndFlowOutcome> Function(int flowId)? onEndFlow;
  final Future<void> Function(int ky, int km, int kd, EventItem evt)?
  onDeleteNote;
  final Future<void> Function(int ky, int km, int kd, EventItem evt)?
  onEditNote;
  final Future<void> Function(String reminderId)? onEditReminder;
  final Future<void> Function(String reminderId)? onEndReminder;
  final Future<void> Function(EventItem evt)? onShareReminder;
  final Future<void> Function(
    int ky,
    int km,
    int kd,
    EventItem evt,
    int newStartMin,
  )?
  onMoveEventTime;
  final DayViewMoveFollowSkyEventTime? onMoveFollowSkyEventTime;
  final Future<bool> Function({
    required int ky,
    required int km,
    required int kd,
    required EventItem event,
    required Duration extension,
  })?
  onRequestEndChange;
  final Future<void> Function(EventItem evt)? onShareNote;
  final Future<void> Function(String text)? onAppendToJournal;
  final MaatJournalResponseBlockWriter? onWriteJournalResponse;
  final Future<void> Function(int flowId)? onSaveFlow;
  final Future<void> Function({
    required String clientEventId,
    required int flowId,
    required DateTime completedOnDate,
    Map<String, dynamic>? metadata,
  })?
  onRecordCompletion;
  final Future<void> Function(String clientEventId)? onUnrecordCompletion;
  final Future<void> Function(String badgeId)? onRemoveCompletionBadge;
  final EventDetailRestorationState? initialEventDetailRestorationState;
  final ValueChanged<EventDetailRestorationState?>?
  onEventDetailRestorationChanged;
  final bool Function()? shouldPreserveEventDetailRestorationOnClose;
  final bool embeddedInCalendarScaffold;

  const LandscapeMonthPager({
    super.key,
    required this.initialKy,
    required this.initialKm,
    this.initialDay,
    required this.showGregorian,
    this.clock,
    this.onClose,
    this.onOpenCalendars,
    this.onOpenInbox,
    this.onToggleCalendar,
    this.onOpenSearch,
    this.onOpenProfile,
    this.onVisibleDayChanged,
    this.dataVersion,
    required this.notesForDay,
    required this.flowIndex,
    this.activeLedgerFlowIds = const <int>{},
    required this.getMonthName,
    this.onManageFlows,
    this.onOpenQuickAdd,
    this.onAddNote,
    this.onMonthChanged, // ✅ NEW CALLBACK
    this.onVisibleMonthCommitted,
    this.onTodayActionChanged,
    this.onEndFlow,
    this.onDeleteNote,
    this.onEditNote,
    this.onEditReminder,
    this.onEndReminder,
    this.onShareReminder,
    this.onMoveEventTime,
    this.onMoveFollowSkyEventTime,
    this.onRequestEndChange,
    this.onShareNote,
    this.onAppendToJournal,
    this.onWriteJournalResponse,
    this.onSaveFlow,
    this.onRecordCompletion,
    this.onUnrecordCompletion,
    this.onRemoveCompletionBadge,
    this.initialEventDetailRestorationState,
    this.onEventDetailRestorationChanged,
    this.shouldPreserveEventDetailRestorationOnClose,
    this.embeddedInCalendarScaffold = false,
  });

  @override
  State<LandscapeMonthPager> createState() => _LandscapeMonthPagerState();
}

class _LandscapeMonthPagerState extends State<LandscapeMonthPager> {
  static const _origin = 100000;
  static const _dayCount = 200001;
  static const _maximumHourHeight = 58.0;
  double _hourHeight = _maximumHourHeight;
  double _minimumHourHeight = 0;
  double _timedViewportHeight = 0;
  bool _isTimePinching = false;
  final _calendarTouchPointers = <int>{};
  double _pinchStartHourHeight = _maximumHourHeight;
  double _pinchAnchorMinute = 0;
  int _pinchPointerCount = 0;
  int _pinchGeneration = 0;
  double _trackpadScaleBaseline = 1;
  static const _gutterWidth = 38.0;
  static const _monthHeight = 26.0;
  static const _headerHeight = 58.0;
  static const _todayBottom = 28.0;
  static const _bone = Color(0xFFE5DED3);
  static const _stone = Color(0xFF7A746C);
  static const _serif = 'CormorantGaramond';
  late DateTime _originDate;
  late DateTime _visibleDate;
  ScrollController? _days;
  late ScrollController _hours;
  final _ledger = ScrollController();
  final _calendarNavigator = GlobalKey<NavigatorState>();
  final _calendarPaneKey = GlobalKey();
  final _visibleMonth = ValueNotifier<DateTime>(DateTime.utc(2000));
  final _selectedEvent = ValueNotifier<String?>(null);
  final _pulse = ValueNotifier<String?>(null);
  final _ledgerHeights = <String, double>{};
  List<double>? _ledgerOffsets;
  Timer? _settleTimer, _pulseTimer;
  DateTime? _reportedDate;
  String? _syncKey;
  Timer? _suppressLinkTimer;
  Future<void>? _detailFuture;
  VoidCallback? _releaseActiveDetail;
  String? _openDetailKey;
  int _openRequest = 0;
  final _events = <DateTime, List<EventItem>>{};
  final _ledgerRows = <({DateTime date, EventItem? event})>[];
  double _columnWidth = 0;
  double _ledgerWidth = 0;
  String? _upcomingKey;
  static const _ledgerTitleStyle = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: ['GentiumPlus'],
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    height: 1.06,
    letterSpacing: 0,
    color: _bone,
  );
  bool _linkedLedger = true;
  bool _movingLedger = false;
  bool _scrollUpdateScheduled = false;
  late DateTime _ledgerStart, _ledgerEnd;
  String? _selection;
  Timer? _clockTimer;
  String? _initialEventDetailRestoreKey;
  String _eventDetailPresentation = eventWorkspacePresentationDetail;
  bool _initialEventDetailRestoreInFlight = false;

  DateTime get _now => (widget.clock ?? DateTime.now)().toLocal();
  ({int kYear, int kMonth, int kDay}) get _visibleKemetic =>
      KemeticMath.fromGregorian(_visibleDate);
  DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);
  DateTime _dateAt(int index) =>
      _originDate.add(Duration(days: index - _origin));
  int _indexOf(DateTime date) =>
      _origin + _dateOnly(date).difference(_originDate).inDays;
  String _keyFor(DateTime date, EventItem event) =>
      '${date.toIso8601String()}:${eventItemIdentityKey(event)}';

  @override
  void initState() {
    super.initState();
    final maxDay = widget.initialKm == 13
        ? (KemeticMath.isLeapKemeticYear(widget.initialKy) ? 6 : 5)
        : 30;
    _originDate = KemeticMath.toGregorian(
      widget.initialKy,
      widget.initialKm,
      (widget.initialDay ?? 1).clamp(1, maxDay),
    );
    _visibleDate = _originDate.subtract(const Duration(days: 1));
    _visibleMonth.value = _visibleDate;
    final isToday = _originDate == _dateOnly(_now);
    final initialMinute = isToday
        ? math.max(0, _now.hour * 60 + _now.minute - 81)
        : 0;
    _hours = ScrollController(
      initialScrollOffset: initialMinute / 60 * _hourHeight,
    )..addListener(_syncHours);
    _resetLedger(_visibleDate);
    widget.dataVersion?.addListener(_dataChanged);
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(_updateUpcomingAnchor);
      _syncLinkedLedger();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onTodayActionChanged?.call(_jumpToToday);
      if (isToday) {
        _syncLedgerToUpcoming();
      } else {
        _syncLinkedLedger(smooth: false);
      }
    });
    _scheduleInitialEventDetailRestore();
  }

  @override
  void didUpdateWidget(covariant LandscapeMonthPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataVersion != widget.dataVersion) {
      oldWidget.dataVersion?.removeListener(_dataChanged);
      widget.dataVersion?.addListener(_dataChanged);
    }
    if (widget.dataVersion == null &&
        (oldWidget.flowIndex != widget.flowIndex ||
            oldWidget.notesForDay != widget.notesForDay)) {
      _events.clear();
      _buildLedgerRows();
    }
    // Parent month notifications report the viewport; they must not reset it.
    if (oldWidget.initialEventDetailRestorationState !=
        widget.initialEventDetailRestorationState) {
      _scheduleInitialEventDetailRestore();
    }
  }

  @override
  void dispose() {
    final k = KemeticMath.fromGregorian(_focusedDate);
    widget.onVisibleMonthCommitted?.call(k.kYear, k.kMonth);
    _releaseActiveDetail?.call();
    _settleTimer?.cancel();
    _pulseTimer?.cancel();
    _suppressLinkTimer?.cancel();
    _visibleMonth.dispose();
    _selectedEvent.dispose();
    _pulse.dispose();
    widget.onTodayActionChanged?.call(null);
    widget.dataVersion?.removeListener(_dataChanged);
    _clockTimer?.cancel();
    _days?.dispose();
    _hours.dispose();
    _ledger.dispose();
    super.dispose();
  }

  void _dataChanged() {
    if (!mounted) return;
    setState(() {
      _events.clear();
      _buildLedgerRows();
    });
  }

  List<EventItem> _eventsForDate(DateTime date) =>
      _events.putIfAbsent(date, () {
        final k = KemeticMath.fromGregorian(date);
        return _eventsForKemeticDay(k.kYear, k.kMonth, k.kDay);
      });

  FlowData? _chromeFlowForId(int? flowId) => widget.flowIndex[flowId];

  List<EventItem> _eventsForKemeticDay(int ky, int km, int kd) =>
      calendarEventsForNotes(
        notes: widget.notesForDay(ky, km, kd),
        flowIndex: widget.flowIndex,
      );

  void _configureColumns(double width) {
    if (_columnWidth == width) return;
    _columnWidth = width;
    final offset = _indexOf(_visibleDate) * width;
    if (_days == null) {
      _days = ScrollController(initialScrollOffset: offset)
        ..addListener(_syncDays);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_days!.hasClients) return;
        _days!.jumpTo(offset);
      });
    }
  }

  DateTime get _focusedDate => _visibleDate.add(const Duration(days: 1));

  void _syncDays() {
    if (!(_days?.hasClients ?? false)) return;
    final date = _dateAt((_days!.offset / _columnWidth).round());
    if (date != _visibleDate) {
      _visibleDate = date;
      _visibleMonth.value = date;
      _dayKeys.removeWhere((d, _) => d.difference(date).inDays.abs() > 10);
    }
    _scheduleViewportSync();
    // Parent date/restoration updates happen after motion settles. Rebuilding
    // Day View on every crossed day interrupted the same gesture it owned.
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 140), _reportViewport);
  }

  void _reportViewport() {
    if (!mounted) return;
    if (_isTimePinching ||
        (_days?.position.isScrollingNotifier.value ?? false) ||
        _hours.position.isScrollingNotifier.value) {
      _settleTimer = Timer(const Duration(milliseconds: 140), _reportViewport);
      return;
    }
    // Match the reference's proximity snapping only after free momentum ends.
    final days = _days!;
    final aligned = (days.offset / _columnWidth).round() * _columnWidth;
    final distance = (aligned - days.offset).abs();
    if (distance > .5 && distance < _columnWidth * .12) {
      unawaited(
        days.animateTo(
          aligned,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
        ),
      );
      return;
    }
    if (_reportedDate == _focusedDate) return;
    final previous = _reportedDate == null
        ? null
        : KemeticMath.fromGregorian(_reportedDate!);
    _reportedDate = _focusedDate;
    final k = KemeticMath.fromGregorian(_focusedDate);
    if (previous == null ||
        previous.kYear != k.kYear ||
        previous.kMonth != k.kMonth) {
      widget.onMonthChanged?.call(k.kYear, k.kMonth);
    }
    widget.onVisibleDayChanged?.call(k.kYear, k.kMonth, k.kDay);
    _events.removeWhere(
      (d, _) =>
          d.difference(_visibleDate).inDays.abs() > 150 &&
          (d.isBefore(_ledgerStart) || d.isAfter(_ledgerEnd)),
    );
  }

  double _timeFocalY(Offset globalPoint) {
    final box =
        _calendarPaneKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return 0;
    return (box.globalToLocal(globalPoint).dy - _monthHeight - _headerHeight)
        .clamp(0.0, _timedViewportHeight);
  }

  void _startTimePinch(ScaleStartDetails details) {
    if (details.pointerCount < 2 || !_hours.hasClients) return;
    ++_pinchGeneration;
    _settleTimer?.cancel();
    (_days?.position as ScrollPositionWithSingleContext?)?.goIdle();
    (_hours.position as ScrollPositionWithSingleContext).goIdle();
    _pinchStartHourHeight = _hourHeight;
    _pinchAnchorMinute =
        (_hours.offset + _timeFocalY(details.focalPoint)) / _hourHeight * 60;
    _pinchPointerCount = details.pointerCount;
    setState(() => _isTimePinching = true);
  }

  void _updateTimePinch(ScaleUpdateDetails details) {
    if (!_isTimePinching || !details.scale.isFinite || details.scale <= 0) {
      return;
    }
    final focalY = _timeFocalY(details.focalPoint);
    // The shared recognizer rebases when another finger joins or leaves.
    if (details.pointerCount != _pinchPointerCount) {
      _pinchPointerCount = details.pointerCount;
      _pinchStartHourHeight = _hourHeight / details.scale;
      _pinchAnchorMinute = (_hours.offset + focalY) / _hourHeight * 60;
    }
    final height = (_pinchStartHourHeight * details.scale).clamp(
      _minimumHourHeight,
      _maximumHourHeight,
    );
    final offset = (_pinchAnchorMinute / 60 * height - focalY)
        .clamp(0.0, math.max(0.0, 24 * height - _timedViewportHeight))
        .toDouble();
    if ((height - _hourHeight).abs() < .0001 &&
        (offset - _hours.offset).abs() < .0001) {
      return;
    }
    setState(() => _hourHeight = height);
    // Update the shared scroll offset in the same frame as the scale. A zoom
    // in can exceed the old extent until layout catches up; cancel jumpTo's
    // old-extent ballistic correction immediately rather than fighting it.
    _hours.jumpTo(offset);
    (_hours.position as ScrollPositionWithSingleContext).goIdle();
  }

  void _endTimePinch() {
    if (!_isTimePinching || _calendarTouchPointers.isNotEmpty) return;
    final generation = _pinchGeneration;
    // Keep taps suppressed through the final pointer-up dispatch. A stationary
    // second finger must not open the event underneath it when pinch ends.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_isTimePinching ||
          generation != _pinchGeneration ||
          _calendarTouchPointers.isNotEmpty) {
        return;
      }
      setState(() => _isTimePinching = false);
      _settleTimer?.cancel();
      _settleTimer = Timer(const Duration(milliseconds: 140), _reportViewport);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _calendarPointerFinished(PointerEvent event) {
    _calendarTouchPointers.remove(event.pointer);
    _endTimePinch();
  }

  Widget _timePinchSurface(Widget child) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (event) {
      if (event.kind == PointerDeviceKind.touch) {
        _calendarTouchPointers.add(event.pointer);
      }
    },
    onPointerUp: _calendarPointerFinished,
    onPointerCancel: _calendarPointerFinished,
    onPointerPanZoomStart: (_) => _trackpadScaleBaseline = 1,
    onPointerPanZoomUpdate: (event) {
      if (!_isTimePinching) {
        if ((event.scale - 1).abs() < .01) return;
        _trackpadScaleBaseline = event.scale;
        _startTimePinch(
          ScaleStartDetails(
            focalPoint: event.position + event.pan,
            pointerCount: 2,
          ),
        );
      }
      _updateTimePinch(
        ScaleUpdateDetails(
          focalPoint: event.position + event.pan,
          scale: event.scale / _trackpadScaleBaseline,
          pointerCount: 2,
        ),
      );
    },
    onPointerPanZoomEnd: (_) => _endTimePinch(),
    onPointerSignal: (event) {
      if (event is! PointerScaleEvent) return;
      GestureBinding.instance.pointerSignalResolver.register(event, (_) {
        _startTimePinch(
          ScaleStartDetails(focalPoint: event.position, pointerCount: 2),
        );
        _updateTimePinch(
          ScaleUpdateDetails(
            focalPoint: event.position,
            scale: event.scale,
            pointerCount: 2,
          ),
        );
        _endTimePinch();
      });
    },
    child: PinchGestureSurface(
      key: const ValueKey('landscape-time-pinch'),
      touchScaleSlop: 3,
      touchScaleRatioSlop: .01,
      onScaleStart: _startTimePinch,
      onScaleUpdate: _updateTimePinch,
      onScaleEnd: (_) => _endTimePinch(),
      child: child,
    ),
  );

  void _syncHours() => _scheduleViewportSync();

  void _scheduleViewportSync() {
    if (_isTimePinching || _scrollUpdateScheduled) return;
    _scrollUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollUpdateScheduled = false;
      if (mounted && !_isTimePinching) _syncLinkedLedger();
    });
  }

  DateTime _eventEnd(DateTime date, EventItem event) {
    final canonical = event.canonicalEnd?.toLocal();
    if (canonical != null) {
      return DateTime.utc(
        canonical.year,
        canonical.month,
        canonical.day,
        canonical.hour,
        canonical.minute,
      );
    }
    var end = event.allDay ? 1440 : event.endMin;
    if (!event.allDay && end < event.startMin) end += 1440;
    return date.add(Duration(minutes: end));
  }

  ({DateTime date, EventItem event})? _firstEventAt(
    DateTime target, {
    int lookBack = 0,
    int lookAhead = 120,
  }) {
    final start = _dateOnly(target).subtract(Duration(days: lookBack));
    for (var i = 0; i < lookBack + lookAhead; i++) {
      final date = start.add(Duration(days: i));
      for (final event in _eventsForDate(date)) {
        if (!_eventEnd(date, event).isBefore(target)) {
          return (date: date, event: event);
        }
      }
    }
    return null;
  }

  DateTime get _civilNow =>
      DateTime.utc(_now.year, _now.month, _now.day, _now.hour, _now.minute);

  void _syncLinkedLedger({bool smooth = true}) {
    if (_isTimePinching ||
        !_linkedLedger ||
        (_suppressLinkTimer?.isActive ?? false)) {
      return;
    }
    final minute =
        ((_hours.hasClients ? _hours.offset : _hours.initialScrollOffset) /
                    _hourHeight *
                    60 +
                81)
            .floor()
            .clamp(0, 1439);
    var target = _visibleDate.add(Duration(minutes: minute));
    final today = _dateOnly(_now);
    if (!today.isBefore(_visibleDate) &&
        today.isBefore(_visibleDate.add(const Duration(days: 3))) &&
        (minute - (_now.hour * 60 + _now.minute)).abs() <= 30) {
      target = _civilNow;
    }
    final row = _firstEventAt(target);
    if (row != null) _syncLedgerToEvent(row.date, row.event, smooth: smooth);
  }

  void _syncLedgerToUpcoming() {
    final row = _firstEventAt(_civilNow, lookBack: 30, lookAhead: 500);
    if (row != null) _syncLedgerToEvent(row.date, row.event, smooth: false);
  }

  void _moveScroll(
    ScrollController controller,
    double offset, {
    bool smooth = true,
  }) {
    if (!controller.hasClients) return;
    if (smooth && !MediaQuery.disableAnimationsOf(context)) {
      unawaited(
        controller.animateTo(
          offset,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic,
        ),
      );
    } else {
      controller.jumpTo(offset);
    }
  }

  void _locateDate(
    DateTime date, {
    int? minute,
    bool center = false,
    bool smooth = true,
  }) {
    _suppressLinkTimer?.cancel();
    _suppressLinkTimer = Timer(const Duration(milliseconds: 450), () {});
    if (_days?.hasClients ?? false) {
      _moveScroll(
        _days!,
        ((_indexOf(date) - (center ? 1 : 0)) * _columnWidth).clamp(
          0,
          _days!.position.maxScrollExtent,
        ),
        smooth: smooth,
      );
    }
    if (minute != null && _hours.hasClients) {
      _moveScroll(
        _hours,
        (math.max(0, minute) / 60 * _hourHeight).clamp(
          0,
          _hours.position.maxScrollExtent,
        ),
        smooth: smooth,
      );
    }
  }

  void _jumpToToday() {
    _linkedLedger = true;
    _syncKey = null;
    if (_openDetailKey == null) _select(null);
    final now = _now;
    _locateDate(
      _dateOnly(now),
      minute: now.hour * 60 + now.minute - 81,
      center: true,
      smooth: false,
    );
    _syncLedgerToUpcoming();
  }

  void _resetLedger(DateTime date) {
    _ledgerStart = date.subtract(const Duration(days: 30));
    _ledgerEnd = date.add(const Duration(days: 30));
    _buildLedgerRows();
  }

  void _buildLedgerRows() {
    _ledgerRows.clear();
    _ledgerHeights.clear();
    _ledgerOffsets = null;
    for (
      var date = _ledgerStart;
      !date.isAfter(_ledgerEnd);
      date = date.add(const Duration(days: 1))
    ) {
      final events = _eventsForDate(date);
      if (events.isEmpty) continue;
      _ledgerRows.add((date: date, event: null));
      for (final event in events) {
        _ledgerRows.add((date: date, event: event));
      }
    }
    _updateUpcomingAnchor();
  }

  void _updateUpcomingAnchor() {
    final previous = _upcomingKey;
    _upcomingKey = null;
    for (final row in _ledgerRows) {
      final event = row.event;
      if (event != null && !_eventEnd(row.date, event).isBefore(_civilNow)) {
        _upcomingKey = _keyFor(row.date, event);
        break;
      }
    }
    if (previous != _upcomingKey) {
      _ledgerHeights.clear();
      _ledgerOffsets = null;
    }
  }

  double _ledgerHeight(({DateTime date, EventItem? event}) row) {
    if (row.event == null) return 28;
    final key = _keyFor(row.date, row.event!);
    return _ledgerHeights.putIfAbsent(key, () {
      final painter = TextPainter(
        text: TextSpan(text: row.event!.title, style: _ledgerTitleStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: math.max(1, _ledgerWidth - 53));
      final textHeight = painter.height;
      painter.dispose();
      return textHeight + 13 + (key == _upcomingKey ? 8 : 0);
    });
  }

  List<double> get _offsets => _ledgerOffsets ??= (() {
    final offsets = <double>[0];
    for (final row in _ledgerRows) {
      offsets.add(offsets.last + _ledgerHeight(row));
    }
    return offsets;
  })();

  void _syncLedgerToEvent(
    DateTime date,
    EventItem event, {
    bool smooth = true,
  }) {
    final key = _keyFor(date, event);
    if (_syncKey == key) return;
    _syncKey = key;
    if (date.isBefore(_ledgerStart) || date.isAfter(_ledgerEnd)) {
      setState(() => _resetLedger(date));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_linkedLedger ||
          !_ledger.hasClients ||
          _syncKey != key) {
        return;
      }
      final index = _ledgerRows.indexWhere(
        (r) => r.event != null && _keyFor(r.date, r.event!) == key,
      );
      if (index < 0) return;
      final offset = math.max(0.0, _offsets[index] - 18);
      _movingLedger = true;
      _moveScroll(_ledger, offset, smooth: smooth);
      _movingLedger = false;
    });
    // A linked update can originate during the timeline's post-frame callback.
    // Schedule the next frame even when the gesture ended on this frame.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _releaseLedgerLink() {
    _linkedLedger = false;
    _syncKey = null;
    if (_ledger.hasClients && _ledger.position.isScrollingNotifier.value) {
      _ledger.jumpTo(_ledger.offset);
    }
  }

  bool _ledgerScrolled(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is UserScrollNotification &&
        n.direction != ScrollDirection.idle &&
        !_movingLedger) {
      _linkedLedger = false;
    }
    if (n is ScrollEndNotification && !_movingLedger && !_linkedLedger) {
      final prepend = n.metrics.pixels < 80;
      final append = n.metrics.extentAfter < 80;
      if (prepend || append) {
        final oldHeight = _ledgerRows.fold<double>(
          0,
          (h, row) => h + _ledgerHeight(row),
        );
        final offset = _ledger.offset;
        setState(() {
          if (prepend) {
            _ledgerStart = _ledgerStart.subtract(const Duration(days: 30));
          }
          if (append) _ledgerEnd = _ledgerEnd.add(const Duration(days: 30));
          _buildLedgerRows();
        });
        if (prepend) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_ledger.hasClients) return;
            final newHeight = _ledgerRows.fold<double>(
              0,
              (h, row) => h + _ledgerHeight(row),
            );
            _ledger.jumpTo(
              (offset + newHeight - oldHeight).clamp(
                0,
                _ledger.position.maxScrollExtent,
              ),
            );
          });
        }
      }
    }
    return false;
  }

  String _timeLabel(int minute) {
    final h = minute ~/ 60;
    final m = minute % 60;
    return '${h % 12 == 0 ? 12 : h % 12}${m == 0 ? '' : ':${m.toString().padLeft(2, '0')}'} ${h < 12 ? 'AM' : 'PM'}';
  }

  void _select(String? key) {
    _selection = key;
    _selectedEvent.value = key;
  }

  bool _isEventVisible(DateTime date, EventItem event) {
    if (!(_days?.hasClients ?? false) || !_hours.hasClients) return false;
    final x = _indexOf(date) * _columnWidth - _days!.offset;
    final width = _days!.position.viewportDimension;
    final y = event.startMin / 60 * _hourHeight - _hours.offset;
    return x >= -1 &&
        x + _columnWidth <= width + 1 &&
        (event.allDay ||
            (y >= -1 &&
                y + _eventHeight(event) <=
                    _hours.position.viewportDimension - _headerHeight + 1));
  }

  Future<void> _closeDetail() async {
    final future = _detailFuture;
    if (future == null) return;
    _calendarNavigator.currentState?.popUntil((route) => route.isFirst);
    await future;
  }

  Future<void> _openEvent(
    DateTime date,
    EventItem event, {
    bool fromLedger = false,
  }) async {
    final request = ++_openRequest;
    final key = _keyFor(date, event);
    _select(key);
    if (fromLedger) {
      _releaseLedgerLink();
      if (!_isEventVisible(date, event)) {
        await _closeDetail();
        if (!mounted || request != _openRequest) return;
        final x = _indexOf(date) * _columnWidth - _days!.offset;
        final width = _days!.position.viewportDimension;
        if (x < -1 || x + _columnWidth > width + 1) _locateDate(date);
        if (!event.allDay) {
          final top = event.startMin / 60 * _hourHeight;
          final height = _hours.position.viewportDimension - _headerHeight;
          if (top < _hours.offset ||
              top + _eventHeight(event) > _hours.offset + height) {
            _moveScroll(
              _hours,
              math.max(0.0, top - 22).clamp(0, _hours.position.maxScrollExtent),
            );
          }
        }
        _pulse.value = key;
        _pulseTimer?.cancel();
        _pulseTimer = Timer(const Duration(milliseconds: 1350), () {
          if (mounted) _pulse.value = null;
        });
        return;
      }
    }
    if (_openDetailKey == key) return;
    await _closeDetail();
    if (!mounted || request != _openRequest) return;
    final k = KemeticMath.fromGregorian(date);
    _showEventDetail(
      event,
      k.kDay,
      initialTarget: DayViewSheetEventTarget(
        ky: k.kYear,
        km: k.kMonth,
        kd: k.kDay,
        event: event,
      ),
    );
  }

  Widget _buildLedger() => Listener(
    onPointerDown: (_) => _releaseLedgerLink(),
    onPointerSignal: (_) => _releaseLedgerLink(),
    onPointerPanZoomStart: (_) => _releaseLedgerLink(),
    child: Focus(
      onKeyEvent: (_, _) {
        _releaseLedgerLink();
        return KeyEventResult.ignored;
      },
      child: ValueListenableBuilder<String?>(
        valueListenable: _selectedEvent,
        builder: (context, selection, _) =>
            NotificationListener<ScrollNotification>(
              onNotification: _ledgerScrolled,
              child: ListView.builder(
                key: const ValueKey('landscape-ledger'),
                controller: _ledger,
                padding: const EdgeInsets.fromLTRB(0, 0, 8, 80),
                itemCount: _ledgerRows.isEmpty ? 1 : _ledgerRows.length,
                itemExtentBuilder: (index, _) => _ledgerRows.isEmpty
                    ? 60
                    : _ledgerHeight(_ledgerRows[index]),
                itemBuilder: (context, index) {
                  if (_ledgerRows.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Text(
                        'No events nearby',
                        style: TextStyle(color: _stone, fontSize: 12),
                      ),
                    );
                  }
                  final row = _ledgerRows[index];
                  final k = KemeticMath.fromGregorian(row.date);
                  final event = row.event;
                  if (event == null) {
                    return SizedBox(
                      height: 28,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Row(
                          children: [
                            Flexible(
                              child: MonthNameText(
                                '${getMonthById(k.kMonth).displayShort} ${k.kDay}',
                                maxLines: 1,
                                style: const TextStyle(
                                  fontFamily: _serif,
                                  fontSize: 11,
                                  color: Color(0xB8D4AE43),
                                ),
                              ),
                            ),
                            if (widget.showGregorian) ...[
                              const SizedBox(width: 6),
                              Text(
                                '${row.date.month}/${row.date.day}',
                                style: const TextStyle(
                                  fontSize: 7,
                                  color: Color(0xFF49453F),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }
                  final selected = _selection == _keyFor(row.date, event);
                  return SizedBox(
                    height: _ledgerHeight(row),
                    child: Column(
                      children: [
                        if (_keyFor(row.date, event) == _upcomingKey)
                          const SizedBox(
                            key: ValueKey('landscape-ledger-now'),
                            height: 8,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 37,
                                  child: Text(
                                    'NOW',
                                    style: TextStyle(
                                      color: Color(0xC7D4AE43),
                                      fontSize: 6.5,
                                      letterSpacing: .8,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Color(0x4DD4AE43),
                                  ),
                                ),
                                SizedBox(width: 18),
                              ],
                            ),
                          ),
                        Expanded(
                          child: InkWell(
                            key: ValueKey(
                              'landscape-ledger-${_keyFor(row.date, event)}',
                            ),
                            onTap: () =>
                                _openEvent(row.date, event, fromLedger: true),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6, bottom: 7),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 37,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        event.allDay
                                            ? 'all-day'
                                            : _timeLabel(event.startMin),
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: selected
                                              ? _landscapeGold
                                              : _stone,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      event.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: _ledgerTitleStyle.copyWith(
                                        color: selected
                                            ? const Color(0xFFE2C45E)
                                            : _bone,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
      ),
    ),
  );

  Widget _buildHeader(DateTime date) {
    final k = KemeticMath.fromGregorian(date);
    final today = date == _dateOnly(_now);
    final allDay = _eventsForDate(date).where((e) => e.allDay).toList();
    return Column(
      children: [
        SizedBox(
          height: 31,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(
              children: [
                Text(
                  const [
                    'MON',
                    'TUE',
                    'WED',
                    'THU',
                    'FRI',
                    'SAT',
                    'SUN',
                  ][date.weekday - 1],
                  style: const TextStyle(
                    fontSize: 7,
                    color: Color(0xFF4E4943),
                    letterSpacing: .5,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  width: 25,
                  height: 25,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: today ? _landscapeGold : null,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${k.kDay}',
                    style: TextStyle(
                      fontFamily: _serif,
                      fontSize: 18,
                      color: today ? Colors.black : _bone,
                    ),
                  ),
                ),
                if (k.kDay == 1)
                  Expanded(
                    child: MonthNameText(
                      getMonthById(k.kMonth).displayShort,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 7,
                        color: Color(0x88D4AE43),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 27,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: allDay.length,
            itemBuilder: (context, i) => SizedBox(
              height: 24,
              child: InkWell(
                onTap: () {
                  if (!_isTimePinching) unawaited(_openEvent(date, allDay[i]));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 4,
                  ),
                  child: Text(
                    allDay[i].title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: allDay[i].color),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _eventHeight(EventItem event) =>
      calendarLandscapeEventHeight(
        event,
        _chromeFlowForId(event.flowId),
        hourHeight: _maximumHourHeight,
      ) *
      (_hourHeight / _maximumHourHeight);

  List<Widget> _buildEventsForDay(DateTime date) {
    final events = _eventsForDate(date).where((e) => !e.allDay).toList();
    final k = KemeticMath.fromGregorian(date);
    final cards = <Widget>[];
    var index = 0;
    while (index < events.length) {
      final group = <EventItem>[];
      var end = -1.0;
      do {
        final event = events[index++];
        group.add(event);
        end = math.max(
          end,
          event.startMin + _eventHeight(event) / _hourHeight * 60,
        );
      } while (index < events.length && events[index].startMin < end);
      final laneEnds = <double>[];
      final lanes = <EventItem, int>{};
      for (final event in group) {
        var lane = laneEnds.indexWhere((e) => e <= event.startMin);
        if (lane < 0) {
          lane = laneEnds.length;
          laneEnds.add(0);
        }
        laneEnds[lane] =
            event.startMin + _eventHeight(event) / _hourHeight * 60;
        lanes[event] = lane;
      }
      final width = (_columnWidth - 4) / laneEnds.length - 3;
      for (final event in group) {
        final height = _eventHeight(event);
        Widget face() {
          final scale = _hourHeight / _maximumHourHeight;
          final nativeFace = CalendarDayEventBlock(
            event: event,
            flow: _chromeFlowForId(event.flowId),
            ky: k.kYear,
            km: k.kMonth,
            kd: k.kDay,
            width: width / scale,
            height: height / scale,
            clock: widget.clock,
          );
          return SizedBox(
            width: width,
            height: height,
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width / scale,
                height: height / scale,
                child: nativeFace,
              ),
            ),
          );
        }

        Widget card = Semantics(
          label: '${event.title}, ${_timeLabel(event.startMin)}',
          button: true,
          child: GestureDetector(
            onTap: () {
              if (!_isTimePinching) unawaited(_openEvent(date, event));
            },
            child: face(),
          ),
        );
        if (widget.onMoveEventTime != null &&
            (event.flowId == null || event.flowId == -1) &&
            !event.isReminder) {
          card = LongPressDraggable<({DateTime date, EventItem event})>(
            data: (date: date, event: event),
            maxSimultaneousDrags: _isTimePinching ? 0 : 1,
            feedback: Material(color: Colors.transparent, child: face()),
            onDragStarted: () => unawaited(AppHaptics.selection()),
            childWhenDragging: Opacity(opacity: .35, child: face()),
            child: card,
          );
        }
        cards.add(
          Positioned(
            left: 2 + lanes[event]! * (width + 3),
            top: event.startMin / 60 * _hourHeight,
            width: width,
            height: height,
            child: KeyedSubtree(
              key: ValueKey('landscape-event-${_keyFor(date, event)}'),
              child: AnimatedBuilder(
                animation: Listenable.merge([_selectedEvent, _pulse]),
                child: card,
                builder: (context, child) {
                  final key = _keyFor(date, event);
                  Widget decorate(double glow) => DecoratedBox(
                    key: _selectedEvent.value == key
                        ? ValueKey('landscape-selection-$key')
                        : null,
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: _selectedEvent.value == key
                          ? Border.all(color: _landscapeGold)
                          : null,
                      boxShadow: glow > 0
                          ? [
                              BoxShadow(
                                color: _landscapeGold.withValues(
                                  alpha: glow * .35,
                                ),
                                blurRadius: 14,
                              ),
                            ]
                          : const [],
                    ),
                    child: child,
                  );
                  if (_pulse.value == key) {
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 1350),
                      builder: (_, value, _) =>
                          decorate(math.sin(value * math.pi)),
                    );
                  }
                  return decorate(0);
                },
              ),
            ),
          ),
        );
      }
    }
    return cards;
  }

  Widget _buildDay(DateTime date) =>
      DragTarget<({DateTime date, EventItem event})>(
        onWillAcceptWithDetails: (d) => !_isTimePinching && d.data.date == date,
        onAcceptWithDetails: (details) {
          if (_isTimePinching) return;
          final box =
              _dayKeys[date]?.currentContext?.findRenderObject() as RenderBox?;
          if (box == null) return;
          final minute =
              ((box.globalToLocal(details.offset).dy / _hourHeight * 60 / 15)
                          .round() *
                      15)
                  .clamp(0, 1439);
          final k = KemeticMath.fromGregorian(date);
          widget.onMoveEventTime?.call(
            k.kYear,
            k.kMonth,
            k.kDay,
            details.data.event,
            minute,
          );
        },
        builder: (context, candidates, rejected) => SizedBox(
          key: _dayKeys.putIfAbsent(date, () => GlobalKey()),
          height: 24 * _hourHeight,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              ..._buildEventsForDay(date),
              if (date == _dateOnly(_now))
                Positioned(
                  left: 2,
                  right: 2,
                  top: (_now.hour + _now.minute / 60) * _hourHeight,
                  child: IgnorePointer(
                    child: Container(
                      height: 1,
                      color: _landscapeGold.withValues(alpha: .54),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
  final _dayKeys = <DateTime, GlobalKey>{};

  @override
  Widget build(BuildContext context) {
    final outerPadding = MediaQuery.paddingOf(context);
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wasFullDay = (_hourHeight - _minimumHourHeight).abs() < .001;
            _timedViewportHeight = math.max(
              0.0,
              constraints.maxHeight - _monthHeight - _headerHeight,
            );
            _minimumHourHeight = math.min(
              _maximumHourHeight,
              math.max(
                    1.0,
                    _timedViewportHeight -
                        math.max(
                          outerPadding.bottom,
                          _todayBottom + kCalendarFloatingShortcutsHeight + 8,
                        ),
                  ) /
                  24,
            );
            _hourHeight = wasFullDay
                ? _minimumHourHeight
                : _hourHeight.clamp(_minimumHourHeight, _maximumHourHeight);
            final ledgerWidth = math.max(
              144.0,
              (constraints.maxWidth + outerPadding.horizontal) / 3 -
                  outerPadding.left -
                  48,
            );
            if (_ledgerWidth != ledgerWidth) {
              _ledgerHeights.clear();
              _ledgerOffsets = null;
            }
            _ledgerWidth = ledgerWidth;
            final calendarWidth = constraints.maxWidth - ledgerWidth;
            _configureColumns((calendarWidth - _gutterWidth - 8) / 3);
            return Row(
              children: [
                SizedBox(width: ledgerWidth, child: _buildLedger()),
                Expanded(
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: Size(calendarWidth, constraints.maxHeight),
                    ),
                    child: NavigatorPopHandler(
                      onPopWithResult: (result) =>
                          _calendarNavigator.currentState!.pop(result),
                      child: Navigator(
                        key: _calendarNavigator,
                        onDidRemovePage: (_) {},
                        pages: [
                          MaterialPage<void>(
                            key: const ValueKey('landscape-calendar-page'),
                            child: KeyedSubtree(
                              key: const ValueKey('landscape-calendar-pane'),
                              child: _timePinchSurface(
                                Stack(
                                  key: _calendarPaneKey,
                                  children: [
                                    Positioned(
                                      left: _gutterWidth,
                                      right: 48,
                                      top: 0,
                                      height: _monthHeight,
                                      child: ValueListenableBuilder<DateTime>(
                                        valueListenable: _visibleMonth,
                                        builder: (context, date, _) {
                                          final k = KemeticMath.fromGregorian(
                                            date,
                                          );
                                          final month = getMonthById(k.kMonth);
                                          return GestureDetector(
                                            onTap: () {
                                              if (!_isTimePinching) {
                                                widget.onToggleCalendar?.call();
                                              }
                                            },
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Flexible(
                                                  child: MonthNameText(
                                                    month.displayShort
                                                        .toUpperCase(),
                                                    maxLines: 1,
                                                    style: const TextStyle(
                                                      fontFamily: _serif,
                                                      fontSize: 13,
                                                      color: Color(0xCCD4AE43),
                                                      letterSpacing: .5,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 2,
                                                      ),
                                                  child: MonthNameText(
                                                    '${month.displayTransliteration} · ${KemeticMath.toGregorian(k.kYear, k.kMonth, 1).year}',
                                                    style: const TextStyle(
                                                      fontSize: 7,
                                                      color: Color(0xFF4C4842),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      top: _monthHeight,
                                      width: _gutterWidth,
                                      height: _headerHeight,
                                      child: const Align(
                                        alignment: Alignment.bottomRight,
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            right: 3,
                                            bottom: 6,
                                          ),
                                          child: Text(
                                            'all-day',
                                            style: TextStyle(
                                              fontSize: 7,
                                              color: Color(0xFF46423D),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      top: _monthHeight + _headerHeight,
                                      bottom: 0,
                                      width: _gutterWidth,
                                      child: ClipRect(
                                        child: AnimatedBuilder(
                                          animation: _hours,
                                          child: SizedBox(
                                            height: 24 * _hourHeight,
                                            child: Stack(
                                              children: [
                                                for (
                                                  var hour =
                                                      _hourHeight <
                                                          _maximumHourHeight
                                                      ? 0
                                                      : 2;
                                                  hour <=
                                                      (_hourHeight <
                                                              _maximumHourHeight
                                                          ? 24
                                                          : 22);
                                                  hour += 2
                                                )
                                                  Positioned(
                                                    right: 3,
                                                    top:
                                                        (hour * _hourHeight - 5)
                                                            .clamp(
                                                              0.0,
                                                              24 * _hourHeight -
                                                                  10,
                                                            ),
                                                    child: Text(
                                                      hour == 12
                                                          ? 'Noon'
                                                          : _timeLabel(
                                                              (hour % 24) * 60,
                                                            ),
                                                      style: TextStyle(
                                                        fontSize: 8,
                                                        color: Color(
                                                          hour % 6 == 0
                                                              ? 0xFF6B655E
                                                              : 0xFF55514B,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          builder: (context, child) => OverflowBox(
                                            alignment: Alignment.topLeft,
                                            minHeight: 24 * _hourHeight,
                                            maxHeight: 24 * _hourHeight,
                                            child: Transform.translate(
                                              offset: Offset(
                                                0,
                                                -(_hours.hasClients
                                                    ? _hours.offset
                                                    : _hours
                                                          .initialScrollOffset),
                                              ),
                                              child: child,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: _gutterWidth,
                                      right: 8,
                                      top: _monthHeight,
                                      bottom: 0,
                                      child: LandscapeTimeline(
                                        key: const ValueKey(
                                          'landscape-timeline',
                                        ),
                                        days: _days!,
                                        hours: _hours,
                                        columnWidth: _columnWidth,
                                        dayCount: _dayCount,
                                        headerHeight: _headerHeight,
                                        dayHeight: 24 * _hourHeight,
                                        scrollEnabled: !_isTimePinching,
                                        dayBuilder: (context, index) =>
                                            _buildDay(_dateAt(index)),
                                        headerBuilder: (context, index) =>
                                            _buildHeader(_dateAt(index)),
                                      ),
                                    ),
                                    // Keep the entire touch target above the pinned
                                    // day header, which starts below the month label.
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      width: 48,
                                      height: 48,
                                      child: IconButton(
                                        tooltip: 'Add note, reminder, or flow',
                                        padding: EdgeInsets.zero,
                                        iconSize: 24,
                                        color: _landscapeGold,
                                        icon: const Icon(Icons.add),
                                        onPressed: () async {
                                          if (_isTimePinching) return;
                                          final openQuickAdd =
                                              widget.onOpenQuickAdd;
                                          if (openQuickAdd != null) {
                                            await openQuickAdd(context);
                                            return;
                                          }
                                          await CalendarPage.openQuickAddFromAnyContext(
                                            context,
                                          );
                                        },
                                      ),
                                    ),
                                    Positioned(
                                      left: 28,
                                      bottom: _todayBottom,
                                      child: CalendarFloatingTodayButton(
                                        key: const ValueKey('landscape-today'),
                                        onPressed: () {
                                          if (!_isTimePinching) _jumpToToday();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String? _eventDetailRestoreKey(EventDetailRestorationState? state) {
    if (state == null) return null;
    return '${state.kYear}:${state.kMonth}:${state.kDay}:'
        '${state.identityType}:${state.identityValue}';
  }

  EventDetailRestorationState? _detailRestorationStateForTarget(
    DayViewSheetEventTarget target,
  ) {
    return eventDetailRestorationStateForTarget(
      target,
      presentation: _eventDetailPresentation,
    );
  }

  void _publishEventDetailRestorationTarget(DayViewSheetEventTarget target) {
    final state = _detailRestorationStateForTarget(target);
    final key = _eventDetailRestoreKey(state);
    if (key != null) {
      _initialEventDetailRestoreKey = key;
      _initialEventDetailRestoreInFlight = false;
    }
    widget.onEventDetailRestorationChanged?.call(state);
  }

  void _clearEventDetailRestorationIfAllowed() {
    if (widget.shouldPreserveEventDetailRestorationOnClose?.call() ?? false) {
      return;
    }
    widget.onEventDetailRestorationChanged?.call(null);
  }

  void _scheduleInitialEventDetailRestore() {
    final state = widget.initialEventDetailRestorationState;
    final key = _eventDetailRestoreKey(state);
    if (state == null ||
        key == null ||
        key == _initialEventDetailRestoreKey ||
        _initialEventDetailRestoreInFlight) {
      return;
    }
    _initialEventDetailRestoreInFlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreInitialEventDetailIfNeeded(state, key));
    });
  }

  Future<void> _restoreInitialEventDetailIfNeeded(
    EventDetailRestorationState state,
    String key, [
    int attempt = 0,
  ]) async {
    if (!mounted) return;
    if (_eventDetailRestoreKey(widget.initialEventDetailRestorationState) !=
        key) {
      _initialEventDetailRestoreInFlight = false;
      _scheduleInitialEventDetailRestore();
      return;
    }
    if (_initialEventDetailRestoreKey == key) {
      _initialEventDetailRestoreInFlight = false;
      return;
    }

    final target = eventDetailTargetFromRestorationState(
      state: state,
      events: _eventsForKemeticDay(state.kYear, state.kMonth, state.kDay),
    );
    if (target == null) {
      if (attempt < 20) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        return _restoreInitialEventDetailIfNeeded(state, key, attempt + 1);
      }
      _initialEventDetailRestoreKey = key;
      _initialEventDetailRestoreInFlight = false;
      widget.onEventDetailRestorationChanged?.call(null);
      return;
    }

    _initialEventDetailRestoreKey = key;
    _initialEventDetailRestoreInFlight = false;
    _locateDate(KemeticMath.toGregorian(state.kYear, state.kMonth, state.kDay));
    _showEventDetail(
      target.event,
      state.kDay,
      initialTarget: target,
      initialPresentation: state.presentation,
    );
  }

  DayViewSheetEventTarget _resolveCurrentEventTarget(
    DayViewSheetEventTarget target,
  ) {
    final currentEvents = _eventsForKemeticDay(target.ky, target.km, target.kd);
    if (currentEvents.isEmpty) return target;

    for (final candidate in currentEvents) {
      if (!eventsShareStableIdentity(candidate, target.event)) continue;
      return DayViewSheetEventTarget(
        ky: target.ky,
        km: target.km,
        kd: target.kd,
        event: candidate,
      );
    }

    return target;
  }

  DayViewSheetEventTarget? _resolveAdjacentEventTarget({
    required int ky,
    required int km,
    required int kd,
    required EventItem event,
    required bool forward,
  }) {
    final currentEvents = _eventsForKemeticDay(ky, km, kd);
    final currentIndex = currentEvents.indexWhere(
      (candidate) => eventsShareStableIdentity(candidate, event),
    );

    if (currentIndex >= 0) {
      final sameDayIndex = forward ? currentIndex + 1 : currentIndex - 1;
      if (sameDayIndex >= 0 && sameDayIndex < currentEvents.length) {
        return DayViewSheetEventTarget(
          ky: ky,
          km: km,
          kd: kd,
          event: currentEvents[sameDayIndex],
        );
      }
    }

    final date = KemeticMath.toGregorian(ky, km, kd);
    for (var offset = 1; offset <= 366; offset++) {
      final next = KemeticMath.fromGregorian(
        date.add(Duration(days: forward ? offset : -offset)),
      );
      final events = _eventsForKemeticDay(next.kYear, next.kMonth, next.kDay);
      if (events.isEmpty) continue;
      return DayViewSheetEventTarget(
        ky: next.kYear,
        km: next.kMonth,
        kd: next.kDay,
        event: forward ? events.first : events.last,
      );
    }

    return null;
  }

  void _showEventDetail(
    EventItem event,
    int day, {
    DayViewSheetEventTarget? initialTarget,
    String? initialPresentation,
  }) {
    if (!CalendarEventDetailSheetCoordinator.tryMarkOpenOrOpening()) {
      return;
    }
    _eventDetailPresentation = normalizeEventWorkspacePresentation(
      initialPresentation,
    );
    final rootContext = context;
    final sheetTarget =
        initialTarget ??
        DayViewSheetEventTarget(
          ky: _visibleKemetic.kYear,
          km: _visibleKemetic.kMonth,
          kd: day,
          event: event,
        );
    _publishEventDetailRestorationTarget(sheetTarget);
    var sheetReleased = false;
    var activeTarget = sheetTarget;

    void moveToTarget(DayViewSheetEventTarget nextTarget) {
      if (!mounted) return;
      final previousTarget = activeTarget;
      activeTarget = nextTarget;
      final date = KemeticMath.toGregorian(
        nextTarget.ky,
        nextTarget.km,
        nextTarget.kd,
      );
      _openDetailKey = _keyFor(date, nextTarget.event);
      _select(_openDetailKey);
      _publishEventDetailRestorationTarget(nextTarget);
      if (nextTarget.ky != previousTarget.ky ||
          nextTarget.km != previousTarget.km ||
          nextTarget.kd != previousTarget.kd) {
        _locateDate(
          KemeticMath.toGregorian(nextTarget.ky, nextTarget.km, nextTarget.kd),
        );
      }
    }

    void releaseSheet() {
      if (sheetReleased) return;
      sheetReleased = true;
      _clearEventDetailRestorationIfAllowed();
      CalendarEventDetailSheetCoordinator.markClosed();
      _detailFuture = null;
      _openDetailKey = null;
      _releaseActiveDetail = null;
    }

    _openDetailKey = _keyFor(
      KemeticMath.toGregorian(sheetTarget.ky, sheetTarget.km, sheetTarget.kd),
      sheetTarget.event,
    );
    _releaseActiveDetail = releaseSheet;
    try {
      _detailFuture = showCalendarEventDetailSheetModal<void>(
        context: _calendarPaneKey.currentContext!,
        builder: (sheetContext) => CalendarEventDetailSheet(
          hostContext: rootContext,
          initialTarget: sheetTarget,
          flowResolver: _chromeFlowForId,
          activeLedgerFlowIds: widget.activeLedgerFlowIds,
          resolveCurrentEventTarget: _resolveCurrentEventTarget,
          resolveAdjacentEventTarget: _resolveAdjacentEventTarget,
          onTargetChanged: moveToTarget,
          onRequestEndChange: widget.onRequestEndChange,
          onMoveFollowSkyEventTime: widget.onMoveFollowSkyEventTime,
          initialPresentation: _eventDetailPresentation,
          onPresentationChanged: (presentation) {
            _eventDetailPresentation = normalizeEventWorkspacePresentation(
              presentation,
            );
            _publishEventDetailRestorationTarget(activeTarget);
          },
          onManageFlows: widget.onManageFlows,
          onEditNote: widget.onEditNote,
          onDeleteNote: widget.onDeleteNote,
          onShareNote: widget.onShareNote,
          onEditReminder: widget.onEditReminder,
          onEndReminder: widget.onEndReminder,
          onShareReminder: widget.onShareReminder,
          onEndFlow: widget.onEndFlow,
          onAppendToJournal: widget.onAppendToJournal,
          onWriteJournalResponse: widget.onWriteJournalResponse,
          onSaveFlow: widget.onSaveFlow,
          dataVersion: widget.dataVersion,
          onRecordCompletion: widget.onRecordCompletion,
          onUnrecordCompletion: widget.onUnrecordCompletion,
          onRemoveCompletionBadge: widget.onRemoveCompletionBadge,
        ),
      ).whenComplete(releaseSheet);
    } catch (_) {
      releaseSheet();
      rethrow;
    }
  }
}
