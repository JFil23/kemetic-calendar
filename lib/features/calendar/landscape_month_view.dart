import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import '../../services/app_haptics.dart';
import '../../services/app_restoration_service.dart';
import '../../widgets/calendar_floating_shortcuts.dart';
import '../../widgets/month_name_text.dart';
import 'day_view.dart';
import 'calendar_page.dart' show CalendarPage, EndFlowOutcome, KemeticMath;
import 'kemetic_month_metadata.dart';
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
  static const _hourHeight = 58.0;
  static const _gutterWidth = 38.0;
  static const _monthHeight = 26.0;
  static const _headerHeight = 58.0;
  static const _bone = Color(0xFFE5DED3);
  static const _stone = Color(0xFF7A746C);
  static const _serif = 'CormorantGaramond';
  late DateTime _originDate;
  late DateTime _visibleDate;
  ScrollController? _days;
  ScrollController? _headers;
  late ScrollController _hours;
  late ScrollController _hourLabels;
  final _ledger = ScrollController();
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
    _visibleDate = _originDate;
    final isToday = _visibleDate == _dateOnly(_now);
    final initialMinute = isToday
        ? math.max(0, _now.hour * 60 + _now.minute - 60)
        : 0;
    _hours = ScrollController(
      initialScrollOffset: initialMinute / 60 * _hourHeight,
    )..addListener(_syncHours);
    _hourLabels = ScrollController(
      initialScrollOffset: initialMinute / 60 * _hourHeight,
    );
    _resetLedger(_visibleDate);
    widget.dataVersion?.addListener(_dataChanged);
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(_updateUpcomingAnchor);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onTodayActionChanged?.call(_jumpToToday);
      _syncLedgerToDate(_visibleDate, upcoming: isToday);
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
    if (oldWidget.flowIndex != widget.flowIndex ||
        oldWidget.notesForDay != widget.notesForDay) {
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
    final k = _visibleKemetic;
    widget.onVisibleMonthCommitted?.call(k.kYear, k.kMonth);
    widget.onTodayActionChanged?.call(null);
    widget.dataVersion?.removeListener(_dataChanged);
    _clockTimer?.cancel();
    _days?.dispose();
    _headers?.dispose();
    _hours.dispose();
    _hourLabels.dispose();
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
      _headers = ScrollController(initialScrollOffset: offset);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_days!.hasClients) return;
        _days!.jumpTo(offset);
      });
    }
  }

  void _syncDays() {
    final days = _days!;
    if (!days.hasClients) return;
    if (_headers!.hasClients) {
      _headers!.jumpTo(
        days.offset.clamp(0, _headers!.position.maxScrollExtent),
      );
    }
    if (_scrollUpdateScheduled) return;
    _scrollUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollUpdateScheduled = false;
      if (!mounted || !_days!.hasClients) return;
      final date = _dateAt((_days!.offset / _columnWidth).round());
      if (date == _visibleDate) return;
      final previous = _visibleKemetic;
      setState(() => _visibleDate = date);
      final k = _visibleKemetic;
      if (previous.kYear != k.kYear || previous.kMonth != k.kMonth) {
        widget.onMonthChanged?.call(k.kYear, k.kMonth);
      }
      widget.onVisibleDayChanged?.call(k.kYear, k.kMonth, k.kDay);
      if (_linkedLedger) {
        _syncLedgerToDate(date, upcoming: date == _dateOnly(_now));
      }
      _dayKeys.removeWhere((d, _) => d.difference(date).inDays.abs() > 10);
      // Keep the display cache bounded while both lists travel indefinitely.
      _events.removeWhere(
        (d, _) =>
            d.difference(date).inDays.abs() > 90 &&
            (d.isBefore(_ledgerStart) || d.isAfter(_ledgerEnd)),
      );
    });
  }

  void _syncHours() {
    if (_hourLabels.hasClients) {
      _hourLabels.jumpTo(
        _hours.offset.clamp(0, _hourLabels.position.maxScrollExtent),
      );
    }
  }

  void _locateDate(DateTime date, {int? minute}) {
    if (_days?.hasClients ?? false) {
      _days!.jumpTo(
        (_indexOf(date) * _columnWidth).clamp(
          0,
          _days!.position.maxScrollExtent,
        ),
      );
    }
    if (minute != null && _hours.hasClients) {
      _hours.jumpTo(
        (math.max(0, minute - 45) / 60 * _hourHeight).clamp(
          0,
          _hours.position.maxScrollExtent,
        ),
      );
    }
  }

  void _jumpToToday() {
    _linkedLedger = true;
    final now = _now;
    final date = _dateOnly(now);
    _locateDate(date, minute: now.hour * 60 + now.minute);
    _syncLedgerToDate(date, upcoming: true);
  }

  void _resetLedger(DateTime date) {
    _ledgerStart = date.subtract(const Duration(days: 30));
    _ledgerEnd = date.add(const Duration(days: 30));
    _buildLedgerRows();
  }

  void _buildLedgerRows() {
    _ledgerRows.clear();
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
    _upcomingKey = null;
    final today = _dateOnly(_now);
    final minute = _now.hour * 60 + _now.minute;
    for (final row in _ledgerRows) {
      final event = row.event;
      if (event == null || row.date.isBefore(today)) continue;
      if (row.date == today && !event.allDay && event.endMin < minute) continue;
      _upcomingKey = _keyFor(row.date, event);
      break;
    }
  }

  double _ledgerHeight(({DateTime date, EventItem? event}) row) {
    if (row.event == null) return 28;
    final painter = TextPainter(
      text: TextSpan(text: row.event!.title, style: _ledgerTitleStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: math.max(1, _ledgerWidth - 53));
    final textHeight = painter.height;
    painter.dispose();
    return textHeight +
        13 +
        (_keyFor(row.date, row.event!) == _upcomingKey ? 8 : 0);
  }

  void _syncLedgerToDate(DateTime date, {bool upcoming = false}) {
    if (date.isBefore(_ledgerStart) || date.isAfter(_ledgerEnd)) {
      setState(() => _resetLedger(date));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_ledger.hasClients) return;
      var offset = 0.0;
      for (final row in _ledgerRows) {
        final beforeDate = row.date.isBefore(date);
        final beforeTime =
            upcoming &&
            row.date == date &&
            (row.event == null ||
                (!row.event!.allDay &&
                    row.event!.endMin < _now.hour * 60 + _now.minute));
        if (!beforeDate && !beforeTime) break;
        offset += _ledgerHeight(row);
      }
      _movingLedger = true;
      _ledger.jumpTo(offset.clamp(0, _ledger.position.maxScrollExtent));
      _movingLedger = false;
    });
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

  void _openEvent(DateTime date, EventItem event) {
    setState(() => _selection = _keyFor(date, event));
    _locateDate(date, minute: event.allDay ? null : event.startMin);
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

  Widget _buildLedger() => NotificationListener<ScrollNotification>(
    onNotification: _ledgerScrolled,
    child: ListView.builder(
      key: const ValueKey('landscape-ledger'),
      controller: _ledger,
      padding: const EdgeInsets.fromLTRB(0, 0, 8, 80),
      itemCount: _ledgerRows.isEmpty ? 1 : _ledgerRows.length,
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
                  key: ValueKey('landscape-ledger-${_keyFor(row.date, event)}'),
                  onTap: () => _openEvent(row.date, event),
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
                                color: selected ? _landscapeGold : _stone,
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
                              color: selected ? const Color(0xFFE2C45E) : _bone,
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
                onTap: () => _openEvent(date, allDay[i]),
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

  double _eventHeight(EventItem event) => calendarLandscapeEventHeight(
    event,
    _chromeFlowForId(event.flowId),
    hourHeight: _hourHeight,
  );

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
        Widget face() => CalendarDayEventBlock(
          event: event,
          flow: _chromeFlowForId(event.flowId),
          ky: k.kYear,
          km: k.kMonth,
          kd: k.kDay,
          width: width,
          height: height,
          clock: widget.clock,
        );
        Widget card = Semantics(
          label: '${event.title}, ${_timeLabel(event.startMin)}',
          button: true,
          child: GestureDetector(
            onTap: () => _openEvent(date, event),
            child: face(),
          ),
        );
        if (widget.onMoveEventTime != null &&
            (event.flowId == null || event.flowId == -1) &&
            !event.isReminder) {
          card = LongPressDraggable<({DateTime date, EventItem event})>(
            data: (date: date, event: event),
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
              child: card,
            ),
          ),
        );
      }
    }
    return cards;
  }

  Widget _buildDay(DateTime date) =>
      DragTarget<({DateTime date, EventItem event})>(
        onWillAcceptWithDetails: (d) => d.data.date == date,
        onAcceptWithDetails: (details) {
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
                  child: Container(
                    height: 1,
                    color: _landscapeGold.withValues(alpha: .54),
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
            final ledgerWidth =
                (constraints.maxWidth + outerPadding.horizontal) / 3 -
                outerPadding.left;
            _ledgerWidth = ledgerWidth;
            final calendarWidth = constraints.maxWidth - ledgerWidth;
            // Half-point extents remain exact at distant scroll offsets;
            // repeating thirds can violate the fixed-sliver precision bound.
            _configureColumns(
              ((calendarWidth - _gutterWidth - 8) / 3 * 2).ceilToDouble() / 2,
            );
            final k = _visibleKemetic;
            final month = getMonthById(k.kMonth);
            return Row(
              children: [
                SizedBox(width: ledgerWidth, child: _buildLedger()),
                Expanded(
                  child: Stack(
                    key: const ValueKey('landscape-calendar-pane'),
                    children: [
                      Positioned(
                        left: _gutterWidth,
                        right: 64,
                        top: 0,
                        height: _monthHeight,
                        child: GestureDetector(
                          onTap: widget.onToggleCalendar,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Flexible(
                                child: MonthNameText(
                                  month.displayShort.toUpperCase(),
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
                                padding: const EdgeInsets.only(bottom: 2),
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
                        ),
                      ),
                      Positioned(
                        right: 32,
                        top: 0,
                        width: 32,
                        height: 28,
                        child: IconButton(
                          tooltip: 'New note',
                          padding: EdgeInsets.zero,
                          iconSize: 17,
                          color: _landscapeGold,
                          icon: const Icon(Icons.add),
                          onPressed: () async {
                            final openQuickAdd = widget.onOpenQuickAdd;
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
                        right: 0,
                        top: 0,
                        width: 32,
                        height: 28,
                        child: PopupMenuButton<String>(
                          tooltip: 'Calendar actions',
                          padding: EdgeInsets.zero,
                          iconSize: 17,
                          icon: const Icon(
                            Icons.more_horiz,
                            color: _landscapeGold,
                          ),
                          itemBuilder: (_) => [
                            if (widget.onOpenCalendars != null)
                              const PopupMenuItem(
                                value: 'calendars',
                                child: Text('Calendars'),
                              ),
                            if (widget.onOpenInbox != null)
                              const PopupMenuItem(
                                value: 'inbox',
                                child: Text('Inbox'),
                              ),
                            const PopupMenuItem(
                              value: 'menu',
                              child: Text('Calendar menu'),
                            ),
                            const PopupMenuItem(
                              value: 'search',
                              child: Text('Search notes'),
                            ),
                            const PopupMenuItem(
                              value: 'profile',
                              child: Text('My Profile'),
                            ),
                            if (widget.onManageFlows != null)
                              const PopupMenuItem(
                                value: 'flows',
                                child: Text('Flow Studio'),
                              ),
                            if (widget.onClose != null ||
                                Navigator.of(context).canPop())
                              PopupMenuItem(
                                value: 'close',
                                child: Text(
                                  widget.embeddedInCalendarScaffold
                                      ? 'Pages'
                                      : 'Close Day View',
                                ),
                              ),
                          ],
                          onSelected: (value) async {
                            switch (value) {
                              case 'calendars':
                                widget.onOpenCalendars?.call();
                              case 'inbox':
                                widget.onOpenInbox?.call();
                              case 'menu':
                                await CalendarPage.showActionsMenuFromAnyContext(
                                  context,
                                );
                              case 'search':
                                await (widget.onOpenSearch ??
                                    CalendarPage.openSearchFromAnyContext)(
                                  context,
                                );
                              case 'profile':
                                await (widget.onOpenProfile ??
                                    CalendarPage.openProfileFromAnyContext)(
                                  context,
                                );
                              case 'flows':
                                widget.onManageFlows?.call(null);
                              case 'close':
                                if (widget.onClose != null) {
                                  widget.onClose!();
                                } else {
                                  Navigator.of(context).maybePop();
                                }
                            }
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
                            padding: EdgeInsets.only(right: 3, bottom: 6),
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
                        left: _gutterWidth,
                        right: 8,
                        top: _monthHeight,
                        height: _headerHeight,
                        child: IgnorePointer(
                          ignoring: false,
                          child: ListView.builder(
                            key: const ValueKey('landscape-day-headers'),
                            controller: _headers,
                            scrollDirection: Axis.horizontal,
                            physics: const NeverScrollableScrollPhysics(),
                            itemExtent: _columnWidth,
                            itemCount: _dayCount,
                            itemBuilder: (context, index) =>
                                _buildHeader(_dateAt(index)),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: _monthHeight + _headerHeight,
                        bottom: 0,
                        width: _gutterWidth,
                        child: SingleChildScrollView(
                          controller: _hourLabels,
                          physics: const NeverScrollableScrollPhysics(),
                          child: SizedBox(
                            height: 24 * _hourHeight,
                            child: Stack(
                              children: [
                                for (var hour = 2; hour < 24; hour += 2)
                                  Positioned(
                                    right: 3,
                                    top: hour * _hourHeight - 5,
                                    child: Text(
                                      hour == 12
                                          ? 'Noon'
                                          : _timeLabel(hour * 60),
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: Color(0xFF6B655E),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: _gutterWidth,
                        right: 8,
                        top: _monthHeight + _headerHeight,
                        bottom: 0,
                        child: SingleChildScrollView(
                          key: const ValueKey('landscape-hours'),
                          controller: _hours,
                          child: SizedBox(
                            height: 24 * _hourHeight,
                            child: ListView.builder(
                              key: const ValueKey('landscape-days'),
                              controller: _days,
                              cacheExtent: _columnWidth,
                              scrollDirection: Axis.horizontal,
                              itemExtent: _columnWidth,
                              itemCount: _dayCount,
                              itemBuilder: (context, index) =>
                                  _buildDay(_dateAt(index)),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 28,
                        bottom: 28,
                        child: CalendarFloatingTodayButton(
                          key: const ValueKey('landscape-today'),
                          onPressed: _jumpToToday,
                        ),
                      ),
                    ],
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
    }

    try {
      showCalendarEventDetailSheetModal(
        context: context,
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
