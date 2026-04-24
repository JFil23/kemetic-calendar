// lib/features/calendar/landscape_month_view.dart
//
// Landscape Month View - Full month grid with INFINITE scrolling
// Styled to match day_view.dart's beautiful detail sheets
//

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'; // For DragStartBehavior
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile/core/touch_targets.dart';
import 'day_view.dart'; // For NoteData, FlowData
import 'calendar_page.dart' show CalendarPage, KemeticMath;
import '../journal/journal_event_badge.dart';
import 'package:mobile/features/calendar/kemetic_time_constants.dart';
import 'dart:math' as math;
import 'package:mobile/shared/glossy_text.dart';
import 'package:mobile/widgets/month_name_text.dart';

// ========================================
// SHARED CONSTANTS FOR LANDSCAPE VIEW
// ========================================
const Color _landscapeGold = KemeticGold.base;
const Color _landscapeBg = Color(0xFF000000); // True black
const Color _landscapeSurface = Color(0xFF0D0D0F); // Dark surface
const Color _landscapeDivider = Color(0xFF1A1A1A); // Divider lines
const double kLandscapeHeaderHeight = 58.0; // Day number header height
const TextStyle _landscapeActionTextStyle = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w600,
  fontFamily: 'GentiumPlus',
  fontFamilyFallback: ['NotoSans', 'Roboto', 'Arial', 'sans-serif'],
);

class _ConstantIntListenable implements ValueListenable<int> {
  const _ConstantIntListenable(this.value);

  @override
  final int value;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

const _kLandscapeZeroListenable = _ConstantIntListenable(0);

void _logLandscape(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

class _LandscapeDragPayload {
  final EventItem event;
  final int day;

  _LandscapeDragPayload(this.event, this.day);

  int get durationMin => (event.endMin - event.startMin).clamp(15, 12 * 60);
}

// ========================================
// MAIN LANDSCAPE MONTH VIEW WIDGET
// Entry point from both Main Calendar and Day View
// ========================================

class LandscapeMonthView extends StatelessWidget {
  final int initialKy;
  final int initialKm;
  final int? initialKd; // Optional - from day view
  final bool showGregorian;
  final ValueListenable<int>? dataVersion;
  final List<NoteData> Function(int ky, int km, int kd) notesForDay;
  final Map<int, FlowData> flowIndex;
  final String Function(int km) getMonthName;
  final void Function(int? flowId)? onManageFlows;
  final void Function(int ky, int km, int kd)? onAddNote;
  final void Function(int ky, int km)? onMonthChanged; // ✅ NEW CALLBACK
  final ValueChanged<VoidCallback?>? onTodayActionChanged;
  final void Function(int flowId)? onEndFlow;
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
  final Future<void> Function(EventItem evt)? onShareNote;
  final Future<void> Function(String text)? onAppendToJournal;
  final Future<void> Function(int flowId)? onSaveFlow;
  final bool embeddedInCalendarScaffold;

  const LandscapeMonthView({
    super.key,
    required this.initialKy,
    required this.initialKm,
    this.initialKd,
    required this.showGregorian,
    this.dataVersion,
    required this.notesForDay,
    required this.flowIndex,
    required this.getMonthName,
    this.onManageFlows,
    this.onAddNote,
    this.onMonthChanged, // ✅ NEW CALLBACK
    this.onTodayActionChanged,
    this.onEndFlow,
    this.onDeleteNote,
    this.onEditNote,
    this.onEditReminder,
    this.onEndReminder,
    this.onShareReminder,
    this.onMoveEventTime,
    this.onShareNote,
    this.onAppendToJournal,
    this.onSaveFlow,
    this.embeddedInCalendarScaffold = false,
  });

  @override
  Widget build(BuildContext context) {
    return LandscapeMonthPager(
      initialKy: initialKy,
      initialKm: initialKm,
      initialDay: initialKd,
      showGregorian: showGregorian,
      dataVersion: dataVersion,
      notesForDay: notesForDay,
      flowIndex: flowIndex,
      getMonthName: getMonthName,
      onManageFlows: onManageFlows,
      onAddNote: onAddNote,
      onMonthChanged: onMonthChanged, // ✅ PASS CALLBACK DOWN
      onTodayActionChanged: onTodayActionChanged,
      onEndFlow: onEndFlow,
      onDeleteNote: onDeleteNote,
      onEditNote: onEditNote,
      onEditReminder: onEditReminder,
      onEndReminder: onEndReminder,
      onShareReminder: onShareReminder,
      onMoveEventTime: onMoveEventTime,
      onShareNote: onShareNote,
      onAppendToJournal: onAppendToJournal,
      onSaveFlow: onSaveFlow,
      embeddedInCalendarScaffold: embeddedInCalendarScaffold,
    );
  }
}

// ========================================
// LANDSCAPE MONTH PAGER
// PageView for infinite month scrolling
// ========================================

class LandscapeMonthPager extends StatefulWidget {
  final int initialKy;
  final int initialKm;
  final int? initialDay;
  final bool showGregorian;
  final ValueListenable<int>? dataVersion;
  final List<NoteData> Function(int ky, int km, int kd) notesForDay;
  final Map<int, FlowData> flowIndex;
  final String Function(int km) getMonthName;
  final void Function(int? flowId)? onManageFlows;
  final void Function(int ky, int km, int kd)? onAddNote;
  final void Function(int ky, int km)? onMonthChanged; // ✅ NEW CALLBACK
  final ValueChanged<VoidCallback?>? onTodayActionChanged;
  final void Function(int flowId)? onEndFlow;
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
  final Future<void> Function(EventItem evt)? onShareNote;
  final Future<void> Function(String text)? onAppendToJournal;
  final Future<void> Function(int flowId)? onSaveFlow;
  final bool embeddedInCalendarScaffold;

  const LandscapeMonthPager({
    super.key,
    required this.initialKy,
    required this.initialKm,
    this.initialDay,
    required this.showGregorian,
    this.dataVersion,
    required this.notesForDay,
    required this.flowIndex,
    required this.getMonthName,
    this.onManageFlows,
    this.onAddNote,
    this.onMonthChanged, // ✅ NEW CALLBACK
    this.onTodayActionChanged,
    this.onEndFlow,
    this.onDeleteNote,
    this.onEditNote,
    this.onEditReminder,
    this.onEndReminder,
    this.onShareReminder,
    this.onMoveEventTime,
    this.onShareNote,
    this.onAppendToJournal,
    this.onSaveFlow,
    this.embeddedInCalendarScaffold = false,
  });

  @override
  State<LandscapeMonthPager> createState() => _LandscapeMonthPagerState();
}

class _LandscapeMonthPagerState extends State<LandscapeMonthPager> {
  late PageController _pageController;
  static const int _centerPage = 100000; // Match your _LandscapePager's _origin

  // 🔧 NEW: Track current page for AppBar display
  int _currentPage = 100000;

  // ✅ HARDENING 3: Debounce onPageChanged to prevent redundant callbacks
  int? _lastNotifiedPage;

  // ✅ FIX 3: Animation guard to prevent remapping during animation
  bool _isAnimating = false;

  // ✅ FIX 1: Track actual displayed month (avoids stale widget.initialKy/Km)
  ({int kYear, int kMonth})? _actualMonth;

  // ✅ Today Button Fix: Stable internal base (doesn't depend on widget props)
  late int _baseTotalMonths; // ✅ Use late (safer than = 0)

  // ✅ Today Button Fix: Dual flags to prevent shuffle
  bool _isJumpingToToday = false; // Blocks onPageChanged during Today jump
  bool _suppressRemap = false; // Blocks didUpdateWidget remap

  Gradient get _monthTitleGradient =>
      widget.showGregorian ? whiteGloss : goldGloss;

  void _publishTodayAction() {
    widget.onTodayActionChanged?.call(_jumpToToday);
  }

  // ✅ FIX A: Canonical month math - Year 1, Month 1 = index 0
  /// Absolute month index where (Year 1, Month 1) == 0
  int _toTotalMonths(int ky, int km) {
    // km expected 1..13, ky can be any integer (…,-1,0,1,2,…)
    return (ky - 1) * 13 + (km - 1); // ✅ Year 1, Month 1 = 0
  }

  /// Calculate absolute page for a month using stable internal base
  /// This avoids dependency on potentially stale widget.initialKy/Km
  int _pageForAbsolute(int ky, int km) {
    final total = _toTotalMonths(ky, km);
    return _centerPage + (total - _baseTotalMonths);
  }

  /// Inverse of _toTotalMonths with Euclidean normalization
  ({int kYear, int kMonth}) _fromTotalMonths(int total) {
    // m0 in 0..12 even for negative totals
    final m0 = ((total % 13) + 13) % 13;
    // Floor-like division because we removed the remainder first
    final y0 = (total - m0) ~/ 13;
    return (kYear: y0 + 1, kMonth: m0 + 1); // ✅ Convert back to 1-indexed
  }

  ({int kYear, int kMonth}) _monthForPage(int page) {
    final delta = page - _centerPage;
    final total = _baseTotalMonths + delta; // ✅ Use canonical base
    return _fromTotalMonths(total);
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _centerPage);
    _currentPage = _centerPage; // 🔧 NEW: Initialize
    _lastNotifiedPage = _centerPage; // Optional: for consistency
    // ✅ Initialize stable base
    _baseTotalMonths = _toTotalMonths(widget.initialKy, widget.initialKm);
    _publishTodayAction();
  }

  @override
  void dispose() {
    widget.onTodayActionChanged?.call(null);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LandscapeMonthPager oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.onTodayActionChanged != widget.onTodayActionChanged) {
      oldWidget.onTodayActionChanged?.call(null);
      _publishTodayAction();
    }

    final newBase = _toTotalMonths(widget.initialKy, widget.initialKm);
    if (newBase == _baseTotalMonths) return;

    final oldBase = _baseTotalMonths;
    _baseTotalMonths = newBase; // ✅ Update base immediately

    if (_suppressRemap || _isAnimating) {
      // ✅ Keep header consistent while suppressed
      if (_pageController.hasClients) {
        final pageNow = _pageController.page?.round() ?? _currentPage;
        final total = _baseTotalMonths + (pageNow - _centerPage);
        _actualMonth = _fromTotalMonths(total);
      }
      if (kDebugMode && _suppressRemap) {
        _logLandscape(
          '✓ [PAGER] Updated base during suppression: $oldBase → $newBase',
        );
      }
      return;
    }

    // ✅ Preserve same absolute month on screen
    final delta = _currentPage - _centerPage;
    final curTotal = oldBase + delta;
    final newDelta = curTotal - newBase;
    final newPage = _centerPage + newDelta;

    if (kDebugMode) {
      _logLandscape('🔄 [PAGER] Base changed: $oldBase → $newBase');
      _logLandscape('   Preserving absolute month: $curTotal');
      _logLandscape('   New page: $newPage');
    }

    if (_pageController.hasClients && newPage != _currentPage) {
      _pageController.jumpToPage(newPage);
      _currentPage = newPage;
      _lastNotifiedPage = newPage;
      _actualMonth = _monthForPage(newPage);

      if (kDebugMode) {
        _logLandscape('✓ [PAGER] Remap complete');
      }
    }

    // When callback becomes available, force PageView to rebuild current page
    if (oldWidget.onAddNote == null && widget.onAddNote != null) {
      if (kDebugMode) {
        _logLandscape('⚡ [PAGER] Callback just arrived! Forcing rebuild...');
      }
      setState(() {
        // This will cause PageView.builder to call itemBuilder again
        // with the now-available callback
      });
    }
  }

  // ✅ FIX 3: Old _monthForPage removed - now using helper method from Fix 1

  Future<void> _jumpToToday() async {
    if (!_pageController.hasClients) return;

    final t = KemeticMath.fromGregorian(DateTime.now());

    // ✅ NEW: refresh base first so header math is correct on first press
    _baseTotalMonths = _toTotalMonths(t.kYear, t.kMonth);

    final targetPage = _pageForAbsolute(t.kYear, t.kMonth);

    _isJumpingToToday = true;
    _isAnimating = true;
    _suppressRemap = true;

    await _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );

    setState(() {
      _currentPage = targetPage;
      _actualMonth = (kYear: t.kYear, kMonth: t.kMonth);
    });

    widget.onMonthChanged?.call(t.kYear, t.kMonth);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isJumpingToToday = false;
      _isAnimating = false;
      _suppressRemap = false;
    });
  }

  // 🔧 NEW: Get days in month (needed for year label calculation)
  int _getDaysInMonth(int kYear, int kMonth) {
    if (kMonth == 13) {
      return KemeticMath.isLeapKemeticYear(kYear) ? 6 : 5;
    }
    return 30;
  }

  // 🔧 NEW: Get year label - always Gregorian (matching current behavior)
  String _getYearLabel(int kYear, int kMonth) {
    final firstDayG = KemeticMath.toGregorian(kYear, kMonth, 1);
    final lastDay = _getDaysInMonth(kYear, kMonth);
    final lastDayG = KemeticMath.toGregorian(kYear, kMonth, lastDay);

    if (firstDayG.year == lastDayG.year) {
      return '${firstDayG.year}';
    } else {
      return '${firstDayG.year}/${lastDayG.year}';
    }
  }

  Widget _buildMonthInfo(String monthName, String yearLabel) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (Rect bounds) =>
              _monthTitleGradient.createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: MonthNameText(
            monthName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            softWrap: false,
            maxLines: 1,
            overflow: TextOverflow.fade,
          ),
        ),
        GlossyText(
          text: yearLabel,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          gradient: _monthTitleGradient,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embeddedInCalendarScaffold) {
      return ColoredBox(
        color: _landscapeBg,
        child: _buildBodyWithSwipeGate(context),
      );
    }

    return Scaffold(
      backgroundColor: _landscapeBg,
      body: Column(
        children: [
          _buildCustomHeader(context),
          Expanded(child: _buildBodyWithSwipeGate(context)),
        ],
      ),
    );
  }

  // 🔧 FIXED: Custom header with month swipe gesture - GestureDetector only wraps title area
  Widget _buildCustomHeader(BuildContext context) {
    // ✅ FIX 1: Prefer _actualMonth to avoid stale widget.initialKy/Km
    final currentMonth = _actualMonth ?? _monthForPage(_currentPage);
    final monthName = widget.getMonthName(currentMonth.kMonth);
    final yearLabel = _getYearLabel(currentMonth.kYear, currentMonth.kMonth);

    return Container(
      color: _landscapeSurface,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: kToolbarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _landscapeSurface,
            border: Border(
              bottom: BorderSide(
                color: _landscapeGold.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Month/Year title - REMOVED GestureDetector, PageView handles swipes
              Expanded(child: _buildMonthInfo(monthName, yearLabel)),
              // Flow Studio button - OUTSIDE GestureDetector (no gesture interference)
              IconButton(
                tooltip: 'Flow Studio',
                icon: KemeticGold.icon(Icons.view_timeline),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onPressed: widget.onManageFlows != null
                    ? () {
                        if (kDebugMode) {
                          _logLandscape('🔘 [LANDSCAPE] Flow Studio tapped');
                        }
                        widget.onManageFlows!(null);
                      }
                    : null,
              ),
              // Add Note button - OUTSIDE GestureDetector (no gesture interference)
              IconButton(
                tooltip: 'New note',
                icon: KemeticGold.icon(Icons.add),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onPressed: widget.onAddNote != null
                    ? () {
                        if (kDebugMode) {
                          _logLandscape('🔘 [LANDSCAPE] Add Note tapped');
                        }
                        final now = DateTime.now();
                        final today = KemeticMath.fromGregorian(now);
                        final currentMonth = _monthForPage(_currentPage);
                        final kd =
                            (currentMonth.kYear == today.kYear &&
                                currentMonth.kMonth == today.kMonth)
                            ? today.kDay
                            : 1;

                        if (currentMonth.kMonth == 13 && kDebugMode) {
                          _logLandscape(
                            '⚠️ [LANDSCAPE] Creating note in sacred Month 13 (Heriu Renpet)',
                          );
                          _logLandscape('   Day: $kd');
                        }

                        widget.onAddNote!(
                          currentMonth.kYear,
                          currentMonth.kMonth,
                          kd,
                        );
                      }
                    : null,
              ),
              // Today button - OUTSIDE GestureDetector (no gesture interference)
              TextButton(
                onPressed: _jumpToToday,
                child: const Text(
                  'Today',
                  style: TextStyle(
                    color: _landscapeGold,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  // 🔧 NEW: Body with PageView (no gesture handling - grid handles its own)
  Widget _buildBodyWithSwipeGate(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.horizontal,
      physics:
          const PageScrollPhysics(), // ✅ Allows gesture AND animateToPage()
      pageSnapping: true,
      onPageChanged: (page) {
        // ✅ HARDENING 3: Debounce to prevent redundant callbacks
        if (_lastNotifiedPage == page) return;

        final m = _monthForPage(page);

        // ✅ Always keep local truth in sync for UI
        setState(() {
          _currentPage = page;
          _actualMonth = m;
        });
        _lastNotifiedPage = page;

        // ✅ If in middle of Today jump, don't ping parent again
        if (_isJumpingToToday) {
          if (kDebugMode) {
            _logLandscape(
              '📄 [PAGER] Page changed to $page during Today jump - state updated, parent notification blocked',
            );
          }
          return;
        }

        // ✅ Normal swipe → notify parent so it sends correct data
        if (kDebugMode) {
          _logLandscape('📄 [PAGER] Page changed to: $page');
          _logLandscape('   Month: ${m.kYear}-${m.kMonth}');
        }
        widget.onMonthChanged?.call(m.kYear, m.kMonth);
      },
      itemBuilder: (context, index) {
        final m = _monthForPage(index);
        final pageInitialDay =
            (widget.initialDay != null &&
                m.kYear == widget.initialKy &&
                m.kMonth == widget.initialKm)
            ? widget.initialDay
            : null;

        if (kDebugMode) {
          _logLandscape(
            '🔧 [PAGER] Creating LandscapeMonthGridBody for page $index',
          );
          _logLandscape('   Month: ${m.kYear}-${m.kMonth}');
        }

        return LandscapeMonthGridBody(
          key: ValueKey('grid-body-${m.kYear}-${m.kMonth}'),
          kYear: m.kYear,
          kMonth: m.kMonth,
          initialDay: pageInitialDay, // ✅ use 'initialDay'
          showGregorian: widget.showGregorian,
          dataVersion: widget.dataVersion,
          notesForDay: widget.notesForDay,
          flowIndex: widget.flowIndex,
          getMonthName: widget.getMonthName,
          onManageFlows: widget.onManageFlows,
          onAddNote: widget.onAddNote,
          onEndFlow: widget.onEndFlow,
          onDeleteNote: widget.onDeleteNote,
          onEditNote: widget.onEditNote,
          onEditReminder: widget.onEditReminder,
          onEndReminder: widget.onEndReminder,
          onShareReminder: widget.onShareReminder,
          onMoveEventTime: widget.onMoveEventTime,
          onShareNote: widget.onShareNote,
          onAppendToJournal: widget.onAppendToJournal,
          onSaveFlow: widget.onSaveFlow,
        );
      },
    );
  }
}

// ========================================
// LANDSCAPE MONTH GRID BODY
// The actual scrollable month grid (single month) - no Scaffold/AppBar
// ========================================

class LandscapeMonthGridBody extends StatefulWidget {
  final int kYear;
  final int kMonth;
  final int? initialDay;
  final bool showGregorian;
  final ValueListenable<int>? dataVersion;
  final List<NoteData> Function(int ky, int km, int kd) notesForDay;
  final Map<int, FlowData> flowIndex;
  final String Function(int km) getMonthName;
  final void Function(int? flowId)? onManageFlows;
  final void Function(int ky, int km, int kd)? onAddNote;
  final void Function(int flowId)? onEndFlow;
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
  final Future<void> Function(EventItem evt)? onShareNote;
  final Future<void> Function(String text)? onAppendToJournal;
  final Future<void> Function(int flowId)? onSaveFlow;

  const LandscapeMonthGridBody({
    super.key,
    required this.kYear,
    required this.kMonth,
    this.initialDay,
    required this.showGregorian,
    this.dataVersion,
    required this.notesForDay,
    required this.flowIndex,
    required this.getMonthName,
    this.onManageFlows,
    this.onAddNote,
    this.onEndFlow,
    this.onDeleteNote,
    this.onEditNote,
    this.onEditReminder,
    this.onEndReminder,
    this.onShareReminder,
    this.onMoveEventTime,
    this.onShareNote,
    this.onAppendToJournal,
    this.onSaveFlow,
  });

  @override
  State<LandscapeMonthGridBody> createState() => _LandscapeMonthGridBodyState();
}

class _LandscapeMonthGridBodyState extends State<LandscapeMonthGridBody> {
  // Layout constants (matching existing landscape)
  static const double _rowH = 64.0; // hour row height
  static const double _gutterW = 56.0; // time gutter width
  static const double _headerH =
      kLandscapeHeaderHeight; // day number header (shared constant)
  static const double _daySepW = 1.0; // day separator
  static const double _hourSepH = 1.0; // hour separator
  static const double _kLandscapeEventMinHeight = 64.0;

  // 🔧 UPDATED: Use shared color constants
  static const Color _gold = _landscapeGold;
  static const Color _bg = _landscapeBg;
  static const Color _surface = _landscapeSurface;
  static const Color _divider = _landscapeDivider;

  // 4 synchronized scroll controllers
  late ScrollController _hHeader;
  late ScrollController _hGrid;
  late ScrollController _vGutter;
  late ScrollController _vGrid;
  final GlobalKey _gridKey = GlobalKey();

  // 🔍 NEW: Debug tracking
  int _buttonTapCount = 0;
  bool _isDisposed = false;

  bool _syncingH = false;
  bool _syncingV = false;

  @override
  void initState() {
    super.initState();

    if (kDebugMode) {
      _logLandscape('🟢 [LANDSCAPE] LandscapeMonthGridBody initState()');
      _logLandscape('   kYear: ${widget.kYear}, kMonth: ${widget.kMonth}');
      _logLandscape(
        '   onAddNote callback: ${widget.onAddNote != null ? "PROVIDED" : "NULL"}',
      );
    }

    _hHeader = ScrollController();
    _hGrid = ScrollController();
    _vGutter = ScrollController();
    _vGrid = ScrollController();

    // Sync horizontal scrolling (grid → header only, since header is non-scrollable)
    // REMOVED: _hHeader.addListener - header can't scroll, so no need to sync header→grid

    _hGrid.addListener(() {
      if (_syncingH) return;
      _syncingH = true;
      if (_hHeader.hasClients) {
        _hHeader.jumpTo(
          _hGrid.offset.clamp(0.0, _hHeader.position.maxScrollExtent),
        );
      }
      _syncingH = false;
    });

    // Sync vertical scrolling
    _vGutter.addListener(() {
      if (_syncingV) return;
      _syncingV = true;
      if (_vGrid.hasClients) {
        _vGrid.jumpTo(
          _vGutter.offset.clamp(0.0, _vGrid.position.maxScrollExtent),
        );
      }
      _syncingV = false;
    });

    _vGrid.addListener(() {
      if (_syncingV) return;
      _syncingV = true;
      if (_vGutter.hasClients) {
        _vGutter.jumpTo(
          _vGrid.offset.clamp(0.0, _vGutter.position.maxScrollExtent),
        );
      }
      _syncingV = false;
    });

    // Scroll to initial day if provided (from day view)
    if (widget.initialDay != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToDay(widget.initialDay!);
      });
    }
  }

  @override
  void didUpdateWidget(covariant LandscapeMonthGridBody old) {
    super.didUpdateWidget(old);
    if (old.initialDay != widget.initialDay && widget.initialDay != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToDay(widget.initialDay!),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (kDebugMode) {
      _logLandscape('🔴 [LANDSCAPE] LandscapeMonthGridBody dispose()');
      _logLandscape(
        '   Button was tapped $_buttonTapCount times before disposal',
      );
    }
    _hHeader.dispose();
    _hGrid.dispose();
    _vGutter.dispose();
    _vGrid.dispose();
    super.dispose();
  }

  void _scrollToDay(int day) {
    if (!_hGrid.hasClients) return;

    final width = MediaQuery.of(context).size.width;
    final colW = (width - _gutterW) / 5.0; // ~5 visible days
    final targetOffset = (day - 3) * (colW + _daySepW); // Center on day

    _hGrid.animateTo(
      targetOffset.clamp(0.0, _hGrid.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode && _buttonTapCount == 0) {
      _logLandscape('🏗️  [LANDSCAPE] build() - FIRST TIME');
      _logLandscape('   Context: $context');
      _logLandscape('   Mounted: $mounted');
      _logLandscape('   Disposed: $_isDisposed');
    }

    final width = MediaQuery.of(context).size.width;

    final dayCount = _getDaysInMonth();
    final colW = (width - _gutterW) / 5.0; // ~5 visible days
    final gridW = colW * dayCount + (_daySepW * (dayCount - 1));
    final gridH = _rowH * 24 + (_hourSepH * 23);

    // 🔧 CHANGED: Return Container with Stack directly (no Scaffold/AppBar)
    return Container(
      color: _bg, // True black background
      child: Stack(
        children: [
          // Top-left corner (empty space above gutter)
          Positioned(
            left: 0,
            top: 0,
            width: _gutterW,
            height: _headerH,
            child: Container(color: _surface),
          ),

          // Day headers (scrollable horizontally)
          Positioned(
            left: _gutterW,
            top: 0,
            right: 0,
            height: _headerH,
            child: IgnorePointer(
              ignoring:
                  true, // Prevent any gesture recognizers from header subtree
              child: SingleChildScrollView(
                controller: _hHeader,
                scrollDirection: Axis.horizontal,
                physics:
                    const NeverScrollableScrollPhysics(), // 🔧 REMOVES FROM GESTURE ARENA
                child: Row(
                  children: [
                    for (int day = 1; day <= dayCount; day++)
                      _buildDayHeader(day, colW),
                  ],
                ),
              ),
            ),
          ),

          // Hour labels (scrollable vertically)
          Positioned(
            left: 0,
            top: _headerH,
            width: _gutterW,
            bottom: 0,
            child: Container(
              color: _surface,
              child: SingleChildScrollView(
                controller: _vGutter,
                physics:
                    const ClampingScrollPhysics(), // 🔧 Prevent gesture conflicts
                child: Column(
                  children: [
                    for (int hour = 0; hour < 24; hour++)
                      Container(
                        height: _rowH,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 8, top: 4),
                        child: Text(
                          _formatHour(hour),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF808080),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Main grid (scrollable in both directions)
          Positioned(
            left: _gutterW,
            top: _headerH,
            right: 0,
            bottom: 0,
            child: SingleChildScrollView(
              controller: _vGrid,
              physics:
                  const ClampingScrollPhysics(), // 🔧 Prevent gesture conflicts
              child: SingleChildScrollView(
                controller: _hGrid,
                scrollDirection: Axis.horizontal,
                physics:
                    const ClampingScrollPhysics(), // ✅ Re-enabled for horizontal scrolling
                child: DragTarget<_LandscapeDragPayload>(
                  key: _gridKey,
                  builder: (context, candidateData, rejectedData) {
                    return SizedBox(
                      width: gridW,
                      height: gridH,
                      child: Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.none,
                        children: [
                          // Grid lines
                          _buildGridLines(dayCount, colW),

                          // Event blocks
                          for (int day = 1; day <= dayCount; day++)
                            ..._buildEventsForDay(day, colW),
                        ],
                      ),
                    );
                  },
                  onWillAccept: (data) => data != null,
                  onAcceptWithDetails: (details) {
                    if (kDebugMode) {
                      debugPrint(
                        '[Landscape] DragTarget onAcceptWithDetails day=${details.data.day}',
                      );
                    }
                    final box =
                        _gridKey.currentContext?.findRenderObject()
                            as RenderBox?;
                    if (box == null) {
                      if (kDebugMode) {
                        debugPrint(
                          '[Landscape] DragTarget: box is null, skipping move',
                        );
                      }
                      return;
                    }
                    final local = box.globalToLocal(details.offset);
                    final double x =
                        local.dx + (_hGrid.hasClients ? _hGrid.offset : 0.0);
                    final double y =
                        local.dy + (_vGrid.hasClients ? _vGrid.offset : 0.0);
                    int day = (x / (colW + _daySepW)).floor() + 1;
                    final maxDay = _getDaysInMonth();
                    day = day.clamp(1, maxDay).toInt();
                    if (day != details.data.day) {
                      if (kDebugMode) {
                        debugPrint(
                          '[Landscape] drop rejected (cross-day) dropDay=$day eventDay=${details.data.day}',
                        );
                      }
                      return;
                    }
                    int totalMin = ((y / _rowH) * 60).round();
                    totalMin = totalMin.clamp(0, 24 * 60 - 1).toInt();
                    int snapped = ((totalMin / 15).round() * 15)
                        .clamp(0, 24 * 60 - 1)
                        .toInt();
                    widget.onMoveEventTime?.call(
                      widget.kYear,
                      widget.kMonth,
                      day,
                      details.data.event,
                      snapped,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(int day, double colW) {
    // Check if this is today
    final now = DateTime.now();
    final today = KemeticMath.fromGregorian(now);
    final isToday =
        today.kYear == widget.kYear &&
        today.kMonth == widget.kMonth &&
        today.kDay == day;

    // Get Gregorian date
    // FIXED: Convert UTC result to local at noon to avoid DST issues
    final gregorianDate = safeLocalDisplay(
      KemeticMath.toGregorian(widget.kYear, widget.kMonth, day),
    );
    final primaryLabel = widget.showGregorian ? '${gregorianDate.day}' : '$day';
    final primaryColor = isToday
        ? _gold
        : (widget.showGregorian ? blueLight : Colors.white);

    return Container(
      width: colW,
      height: _headerH,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: isToday ? _gold.withOpacity(0.1) : null,
        border: Border(
          right: const BorderSide(color: _divider, width: _daySepW),
          bottom: BorderSide(
            color: isToday ? _gold : _divider,
            width: isToday ? 2 : 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            primaryLabel,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
              color: primaryColor,
            ),
          ),
          if (widget.showGregorian)
            Text(
              '${gregorianDate.month}/${gregorianDate.day}',
              style: TextStyle(
                fontSize: 9,
                color: isToday
                    ? _gold.withOpacity(0.7)
                    : blueLight.withOpacity(0.8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGridLines(int dayCount, double colW) {
    return Stack(
      children: [
        // Horizontal hour lines
        for (int hour = 0; hour < 24; hour++)
          Positioned(
            left: 0,
            right: 0,
            top: hour * _rowH,
            child: Container(height: _hourSepH, color: _divider),
          ),

        // Vertical day lines
        for (int day = 0; day < dayCount; day++)
          Positioned(
            left: day * (colW + _daySepW) + colW,
            top: 0,
            bottom: 0,
            child: Container(width: _daySepW, color: _divider),
          ),
      ],
    );
  }

  /// Dedupe notes before rendering to handle legacy duplicates
  /// Two notes are duplicates if they have:
  /// - Same flow ID
  /// - Same start time (to the minute, or both all-day)
  /// - Same end time (to the minute, or both all-day)
  /// - Same title (normalized)
  List<NoteData> _dedupeNotesForUI(List<NoteData> notes) {
    if (notes.isEmpty) return notes;

    final seen = <String, NoteData>{};

    for (final note in notes) {
      // Build unique key from note properties
      final flowKey = note.flowId?.toString() ?? 'NO_FLOW';

      // Normalize timestamps (handle both all-day and timed events)
      String startKey;
      String endKey;

      if (note.allDay) {
        startKey = 'ALLDAY';
        endKey = 'ALLDAY';
      } else {
        // For timed events, normalize to minutes since midnight for comparison
        if (note.start != null && note.end != null) {
          final startMin = note.start!.hour * 60 + note.start!.minute;
          final endMin = note.end!.hour * 60 + note.end!.minute;
          startKey = startMin.toString();
          endKey = endMin.toString();
        } else {
          startKey = 'NO_START';
          endKey = 'NO_END';
        }
      }

      // Title normalized (trim + lowercase for consistency)
      final titleKey = note.title.trim().toLowerCase();

      // Build composite key
      final key = '$flowKey|$startKey|$endKey|$titleKey';

      if (!seen.containsKey(key)) {
        seen[key] = note;
        continue;
      }

      final existing = seen[key]!;
      bool hasIdentity(NoteData n) =>
          (n.id != null && n.id!.trim().isNotEmpty) ||
          (n.clientEventId != null && n.clientEventId!.trim().isNotEmpty);

      if (!hasIdentity(existing) && hasIdentity(note)) {
        seen[key] = note;
      }
    }

    return seen.values.toList();
  }

  EventItem _eventItemFromNote(NoteData note) {
    final startMin = note.allDay
        ? 9 * 60
        : (note.start?.hour ?? 9) * 60 + (note.start?.minute ?? 0);
    final endMin = note.allDay
        ? 17 * 60
        : (note.end?.hour ?? 17) * 60 + (note.end?.minute ?? 0);

    Color eventColor = Colors.blue;
    if (note.manualColor != null) {
      eventColor = note.manualColor!;
    } else if (note.flowId != null) {
      final flow = widget.flowIndex[note.flowId];
      if (flow != null) {
        eventColor = flow.color;
      }
    }

    return EventItem(
      id: note.id,
      clientEventId: note.clientEventId,
      title: note.title,
      detail: note.detail,
      location: note.location,
      startMin: startMin,
      endMin: endMin,
      flowId: note.flowId,
      color: eventColor,
      manualColor: note.manualColor,
      allDay: note.allDay,
      category: note.category,
      isReminder: note.isReminder,
      reminderId: note.reminderId,
    );
  }

  String _sheetEventIdentityKey(EventItem event) {
    final id = event.id?.trim();
    if (id != null && id.isNotEmpty) return 'id:$id';

    final clientEventId = event.clientEventId?.trim();
    if (clientEventId != null && clientEventId.isNotEmpty) {
      return 'cid:$clientEventId';
    }

    final reminderId = event.reminderId?.trim();
    if (reminderId != null && reminderId.isNotEmpty) {
      return 'rid:$reminderId';
    }

    return [
      event.title.trim().toLowerCase(),
      event.startMin,
      event.endMin,
      event.flowId ?? '',
      event.location?.trim().toLowerCase() ?? '',
      event.detail?.trim().toLowerCase() ?? '',
      event.allDay,
      event.isReminder,
    ].join('|');
  }

  bool _eventsShareStableIdentity(EventItem a, EventItem b) {
    final aId = a.id?.trim();
    final bId = b.id?.trim();
    if (aId != null && aId.isNotEmpty && bId != null && bId.isNotEmpty) {
      return aId == bId;
    }

    final aClientId = a.clientEventId?.trim();
    final bClientId = b.clientEventId?.trim();
    if (aClientId != null &&
        aClientId.isNotEmpty &&
        bClientId != null &&
        bClientId.isNotEmpty) {
      return aClientId == bClientId;
    }

    final aReminderId = a.reminderId?.trim();
    final bReminderId = b.reminderId?.trim();
    if (aReminderId != null &&
        aReminderId.isNotEmpty &&
        bReminderId != null &&
        bReminderId.isNotEmpty) {
      return aReminderId == bReminderId;
    }

    return _sheetEventIdentityKey(a) == _sheetEventIdentityKey(b);
  }

  int _compareEventItemsBySchedule(EventItem a, EventItem b) {
    final startCmp = a.startMin.compareTo(b.startMin);
    if (startCmp != 0) return startCmp;

    final endCmp = a.endMin.compareTo(b.endMin);
    if (endCmp != 0) return endCmp;

    return _sheetEventIdentityKey(a).compareTo(_sheetEventIdentityKey(b));
  }

  List<EventItem> _eventsForKemeticDay(int ky, int km, int kd) {
    final notes = _dedupeNotesForUI(widget.notesForDay(ky, km, kd));
    final events = [for (final note in notes) _eventItemFromNote(note)];
    events.sort(_compareEventItemsBySchedule);
    return events;
  }

  DayViewSheetEventTarget _resolveCurrentEventTarget(
    DayViewSheetEventTarget target,
  ) {
    final currentEvents = _eventsForKemeticDay(target.ky, target.km, target.kd);
    if (currentEvents.isEmpty) return target;

    for (final candidate in currentEvents) {
      if (!_eventsShareStableIdentity(candidate, target.event)) continue;
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
    if (ky != widget.kYear || km != widget.kMonth) return null;

    final currentEvents = _eventsForKemeticDay(ky, km, kd);
    final currentIndex = currentEvents.indexWhere(
      (candidate) => _eventsShareStableIdentity(candidate, event),
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

    final dayRange = forward
        ? Iterable<int>.generate(
            _getDaysInMonth() - kd,
            (index) => kd + index + 1,
          )
        : Iterable<int>.generate(kd - 1, (index) => kd - index - 1);

    for (final nextDay in dayRange) {
      final nextDayEvents = _eventsForKemeticDay(ky, km, nextDay);
      if (nextDayEvents.isEmpty) continue;
      return DayViewSheetEventTarget(
        ky: ky,
        km: km,
        kd: nextDay,
        event: forward ? nextDayEvents.first : nextDayEvents.last,
      );
    }

    return null;
  }

  List<Widget> _buildEventsForDay(int day, double colW) {
    final rawNotes = widget.notesForDay(widget.kYear, widget.kMonth, day);

    // ✅ ADD DEBUG LOGGING
    if (kDebugMode && rawNotes.isNotEmpty) {
      _logLandscape('📅 [LANDSCAPE] Building events for day $day');
      _logLandscape('   Year: ${widget.kYear}, Month: ${widget.kMonth}');
      _logLandscape('   Raw notes: ${rawNotes.length}');
      _logLandscape('   FlowIndex keys: ${widget.flowIndex.keys.toList()}');
      for (final note in rawNotes) {
        _logLandscape('   - Note: "${note.title}", flowId: ${note.flowId}');
        if (note.flowId != null) {
          final flow = widget.flowIndex[note.flowId];
          _logLandscape('     Flow color: ${flow?.color}');
        }
      }
    }

    // ✅ NEW: Dedupe notes before rendering to handle legacy duplicates
    final notes = _dedupeNotesForUI(rawNotes);

    if (kDebugMode && rawNotes.isNotEmpty && notes.isEmpty) {
      _logLandscape('⚠️ [LANDSCAPE] All notes deduped for day $day!');
    }
    if (notes.isEmpty) return [];

    if (kDebugMode) {
      final originalCount = rawNotes.length;
      final dedupedCount = notes.length;
      if (originalCount != dedupedCount) {
        _logLandscape(
          '[LandscapeMonthView] Deduplicated events for day $day: $originalCount → $dedupedCount (removed ${originalCount - dedupedCount} duplicates)',
        );
      }
    }

    final events = [for (final note in notes) _eventItemFromNote(note)];

    if (events.isEmpty) return [];

    events.sort(_compareEventItemsBySchedule);

    const columnGap = 4.0;
    final widgets = <Widget>[];

    // Cluster events by overlap so width is only reduced when events overlap in time
    int idx = 0;
    while (idx < events.length) {
      final cluster = <EventItem>[];
      int clusterEnd = events[idx].endMin;
      cluster.add(events[idx]);
      int j = idx + 1;
      while (j < events.length && events[j].startMin < clusterEnd) {
        cluster.add(events[j]);
        clusterEnd = math.max(clusterEnd, events[j].endMin);
        j++;
      }

      final columnAssignments = _assignColumns(cluster);
      final maxCols = columnAssignments.values.isEmpty
          ? 1
          : (columnAssignments.values.reduce((a, b) => a > b ? a : b) + 1);
      final availableWidth = colW - (columnGap * (maxCols - 1));
      final columnWidth = availableWidth / maxCols;

      for (final event in cluster) {
        final col = columnAssignments[event] ?? 0;
        final left =
            (day - 1) * (colW + _daySepW) + (col * (columnWidth + columnGap));
        final top = (event.startMin / 60.0) * _rowH;

        int durationMinutes = event.endMin - event.startMin;
        if (durationMinutes <= 0) {
          durationMinutes = 15;
        }
        if (durationMinutes > 180) {
          durationMinutes = 180;
        }
        final double rawHeight = (durationMinutes / 60.0) * _rowH;
        final double height = rawHeight < _kLandscapeEventMinHeight
            ? _kLandscapeEventMinHeight
            : rawHeight;

        widgets.add(
          Positioned(
            left: left,
            top: top,
            width: columnWidth,
            height: height,
            child: _buildInteractiveEventBlock(
              event: event,
              day: day,
              width: columnWidth,
              height: height,
              durationMinutes: durationMinutes,
            ),
          ),
        );
      }

      idx = j;
    }

    return widgets;
  }

  bool _isEventDraggable(EventItem event) {
    final flowId = event.flowId ?? -1;
    return (event.flowId == null || flowId == -1) &&
        !event.isReminder &&
        !event.allDay;
  }

  Widget _buildEventCard(EventItem event, int durationMinutes) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 4,
        vertical: event.isReminder ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: event.color.withOpacity(0.20),
        border: Border(left: BorderSide(color: event.color, width: 3)),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.hardEdge,
      child: _buildEventBlockContent(event, durationMinutes),
    );
  }

  Widget _buildInteractiveEventBlock({
    required EventItem event,
    required int day,
    required double width,
    required double height,
    required int durationMinutes,
  }) {
    final card = _buildEventCard(event, durationMinutes);
    final tappable = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showEventDetail(event, day),
      child: SizedBox(width: width, height: height, child: card),
    );

    if (!_isEventDraggable(event)) {
      return tappable;
    }

    return LongPressDraggable<_LandscapeDragPayload>(
      data: _LandscapeDragPayload(event, day),
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.8,
          child: SizedBox(
            width: width,
            height: height,
            child: _buildEventCard(event, durationMinutes),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: SizedBox(
          width: width,
          height: height,
          child: _buildEventCard(event, durationMinutes),
        ),
      ),
      onDragStarted: () {
        HapticFeedback.selectionClick();
      },
      onDraggableCanceled: (_, __) {},
      onDragEnd: (_) {},
      child: tappable,
    );
  }

  Widget _buildEventBlockContent(EventItem event, int durationMinutes) {
    final flow = widget.flowIndex[event.flowId];
    final hasFlow = flow != null;

    final showTitle = event.title.trim().isNotEmpty;
    final showLocation =
        event.location != null && event.location!.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min, // ✅ Don't expand unnecessarily
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Flow name first (if available). Skip for reminders to avoid overflow in short block.
        if (hasFlow && !event.isReminder) ...[
          Text(
            flow!.name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: event.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
        ],

        // Note title - only render if meaningful
        if (showTitle)
          Text(
            event.title.trim(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500, // ✅ w500 not w600
              color: Colors.white,
            ),
            maxLines: (event.isReminder || hasFlow || durationMinutes < 90)
                ? 1
                : 2, // ✅ Conditional line limit
            overflow: TextOverflow.ellipsis,
          )
        else
          Text(
            // ✅ No const - text is conditional
            hasFlow ? '(flow block)' : '(scheduled)', // ✅ Match day view logic
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.white70, // ✅ Exact day view color
              fontStyle: FontStyle.italic,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

        // Location (clickable)
        if (showLocation)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: InkWell(
              onTap: () => _launchLocation(event.location!.trim()),
              child: Text(
                event.location!.trim(),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.7),
                  decoration: TextDecoration.underline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }

  String _detailSheetTargetKey(DayViewSheetEventTarget target) =>
      '${target.ky}:${target.km}:${target.kd}:${_sheetEventIdentityKey(target.event)}';

  ({List<DayViewSheetEventTarget> pages, int currentIndex})
  _detailSheetPagesForTarget(DayViewSheetEventTarget target) {
    final previous = _resolveAdjacentEventTarget(
      ky: target.ky,
      km: target.km,
      kd: target.kd,
      event: target.event,
      forward: false,
    );
    final next = _resolveAdjacentEventTarget(
      ky: target.ky,
      km: target.km,
      kd: target.kd,
      event: target.event,
      forward: true,
    );

    final pages = <DayViewSheetEventTarget>[
      if (previous != null) previous,
      target,
      if (next != null) next,
    ];
    return (pages: pages, currentIndex: previous != null ? 1 : 0);
  }

  ButtonStyle _endButtonStyle(BuildContext context) {
    return withExpandedTouchTargets(
      context,
      OutlinedButton.styleFrom(
        side: const BorderSide(color: _gold),
        foregroundColor: _gold,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        minimumSize: const Size(0, 35),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
      ),
    );
  }

  Widget _buildEndFlowButton(
    int? flowId, {
    required BuildContext actionContext,
  }) {
    final onEndFlow = widget.onEndFlow;
    final id = flowId;
    final enabled = onEndFlow != null && id != null;
    return OutlinedButton.icon(
      style: _endButtonStyle(actionContext),
      onPressed: enabled
          ? () {
              Navigator.pop(actionContext);
              onEndFlow(id);
            }
          : null,
      icon: const Icon(Icons.stop_circle),
      label: const Text('End Flow'),
    );
  }

  Widget _buildEndNoteButton(
    EventItem event, {
    required int ky,
    required int km,
    required int kd,
    required BuildContext actionContext,
  }) {
    final enabled = widget.onDeleteNote != null;
    return OutlinedButton.icon(
      style: _endButtonStyle(actionContext),
      onPressed: enabled
          ? () async {
              Navigator.pop(actionContext);
              await widget.onDeleteNote!(ky, km, kd, event);
            }
          : null,
      icon: const Icon(Icons.delete_outline),
      label: const Text('End Note'),
    );
  }

  Widget _buildEndReminderButton(
    EventItem event, {
    required BuildContext actionContext,
  }) {
    final enabled = widget.onEndReminder != null && event.reminderId != null;
    return OutlinedButton.icon(
      style: _endButtonStyle(actionContext),
      onPressed: enabled
          ? () async {
              Navigator.pop(actionContext);
              final reminderId = event.reminderId;
              if (reminderId != null) {
                await widget.onEndReminder?.call(reminderId);
              }
            }
          : null,
      icon: const Icon(Icons.stop_circle),
      label: const Text('End Reminder'),
    );
  }

  String _cleanEventDetail(String? rawDetail) {
    if (rawDetail == null || rawDetail.isEmpty) return '';

    var displayDetail = rawDetail.trim();
    if (displayDetail.startsWith('flowLocalId=')) {
      final semi = displayDetail.indexOf(';');
      if (semi > 0 && semi < displayDetail.length - 1) {
        displayDetail = displayDetail.substring(semi + 1).trim();
      } else {
        return '';
      }
    }

    displayDetail = _stripCidLines(displayDetail);
    if (displayDetail.isEmpty || _looksLikeCidDetail(displayDetail)) {
      return '';
    }

    return displayDetail;
  }

  Widget _buildEventDetailSheetPage({
    required DayViewSheetEventTarget target,
    bool scrollable = true,
  }) {
    final currentEvent = target.event;
    final flow = widget.flowIndex[currentEvent.flowId];
    final isReminder = currentEvent.isReminder;
    final detail = _cleanEventDetail(currentEvent.detail);
    final isNutrition = detail.contains('Source:');

    Widget? metaChip;
    if (flow != null) {
      metaChip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: flow.color.withOpacity(0.16),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          flow.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: flow.color,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else if (isReminder) {
      metaChip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: KemeticGold.base.withOpacity(0.16),
          borderRadius: BorderRadius.circular(8),
        ),
        child: KemeticGold.text(
          'Reminder',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    } else if (isNutrition) {
      metaChip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: KemeticGold.base.withOpacity(0.16),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KemeticGold.icon(Icons.local_drink, size: 14),
            const SizedBox(width: 4),
            KemeticGold.text(
              'Nutrition',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (metaChip != null) metaChip,
        if (metaChip != null) const SizedBox(height: 12),
        KemeticGold.text(
          currentEvent.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: Color(0xFF808080)),
            const SizedBox(width: 8),
            Text(
              _formatTimeRange(
                currentEvent.startMin,
                currentEvent.endMin,
                allDay: currentEvent.allDay,
              ),
              style: const TextStyle(color: Color(0xFF808080)),
            ),
          ],
        ),
        if (currentEvent.location != null &&
            currentEvent.location!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _launchLocation(currentEvent.location!.trim()),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 16,
                  color: Color(0xFF808080),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentEvent.location!.trim(),
                    style: const TextStyle(
                      color: Color(0xFF808080),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (detail.isNotEmpty) ...[
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: Colors.white),
              children: _buildTextSpans(detail),
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _gold.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: scrollable
            ? SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: body,
              )
            : body,
      ),
    );
  }

  Widget _buildEventDetailTopActionRow({
    required BuildContext sheetContext,
    required DayViewSheetEventTarget target,
  }) {
    final currentEvent = target.event;
    final flow = widget.flowIndex[currentEvent.flowId];
    final isReminder = currentEvent.isReminder;

    return Row(
      children: [
        const Spacer(),
        if (flow != null)
          _buildEndFlowButton(flow.id, actionContext: sheetContext)
        else if (isReminder)
          _buildEndReminderButton(currentEvent, actionContext: sheetContext)
        else if (widget.onDeleteNote != null)
          _buildEndNoteButton(
            currentEvent,
            ky: target.ky,
            km: target.km,
            kd: target.kd,
            actionContext: sheetContext,
          ),
        const SizedBox(width: 8),
        _buildEventDetailOverflowButton(
          sheetContext: sheetContext,
          target: target,
        ),
      ],
    );
  }

  Widget _buildEventDetailPrimaryAction({
    required BuildContext sheetContext,
    required DayViewSheetEventTarget target,
  }) {
    final currentEvent = target.event;
    final flow = widget.flowIndex[currentEvent.flowId];
    final isReminder = currentEvent.isReminder;

    if (flow != null) {
      final enabled = CalendarPage.globalKey.currentState?.mounted ?? false;
      return TextButton.icon(
        onPressed: enabled
            ? () async {
                Navigator.pop(sheetContext);
                await CalendarPage.shareFlowFromEvent(currentEvent);
              }
            : null,
        icon: enabled
            ? KemeticGold.icon(Icons.share_outlined)
            : const Icon(Icons.share_outlined, color: Color(0xFF404040)),
        label: enabled
            ? KemeticGold.text(
                'Share Flow',
                style: _landscapeActionTextStyle.copyWith(fontSize: 15),
              )
            : const Text(
                'Share Flow',
                style: TextStyle(color: Color(0xFF404040)),
              ),
      );
    }

    if (isReminder) {
      final enabled =
          widget.onEditReminder != null && currentEvent.reminderId != null;
      return TextButton.icon(
        onPressed: enabled
            ? () async {
                Navigator.pop(sheetContext);
                await widget.onEditReminder!(currentEvent.reminderId!);
              }
            : null,
        icon: enabled
            ? KemeticGold.icon(Icons.notifications_active_outlined)
            : const Icon(
                Icons.notifications_active_outlined,
                color: Color(0xFF404040),
              ),
        label: enabled
            ? KemeticGold.text(
                'Reminder',
                style: _landscapeActionTextStyle.copyWith(fontSize: 15),
              )
            : const Text(
                'Reminder',
                style: TextStyle(color: Color(0xFF404040)),
              ),
      );
    }

    final enabled = widget.onEditNote != null;
    return TextButton.icon(
      onPressed: enabled
          ? () async {
              Navigator.pop(sheetContext);
              await widget.onEditNote!(
                target.ky,
                target.km,
                target.kd,
                currentEvent,
              );
            }
          : null,
      icon: enabled
          ? KemeticGold.icon(Icons.note_alt_outlined)
          : const Icon(Icons.note_alt_outlined, color: Color(0xFF404040)),
      label: enabled
          ? KemeticGold.text(
              'Note',
              style: _landscapeActionTextStyle.copyWith(fontSize: 15),
            )
          : const Text('Note', style: TextStyle(color: Color(0xFF404040))),
    );
  }

  Widget _buildEventDetailOverflowButton({
    required BuildContext sheetContext,
    required DayViewSheetEventTarget target,
  }) {
    final currentEvent = target.event;
    final flow = widget.flowIndex[currentEvent.flowId];
    final isReminder = currentEvent.isReminder;

    return PopupMenuButton<String>(
      icon: KemeticGold.icon(Icons.more_vert),
      tooltip: 'Event options',
      color: const Color(0xFF000000),
      onSelected: (value) async {
        if (value == 'journal') {
          await _handleAddToJournal(
            currentEvent,
            target.kd,
            sheetContext: sheetContext,
          );
        } else if (value == 'edit' && flow != null) {
          Navigator.pop(sheetContext);
          widget.onManageFlows?.call(flow.id);
        } else if (value == 'invite_people') {
          Navigator.pop(sheetContext);
          if (isReminder && widget.onShareReminder != null) {
            await widget.onShareReminder!(currentEvent);
          } else if (widget.onShareNote != null) {
            await widget.onShareNote!(currentEvent);
          }
        } else if (value == 'save' &&
            flow != null &&
            widget.onSaveFlow != null) {
          Navigator.pop(sheetContext);
          await widget.onSaveFlow!(flow.id);
        } else if (value == 'edit_reminder' &&
            isReminder &&
            widget.onEditReminder != null &&
            currentEvent.reminderId != null) {
          Navigator.pop(sheetContext);
          await widget.onEditReminder!(currentEvent.reminderId!);
        } else if (value == 'edit_note' &&
            flow == null &&
            !isReminder &&
            widget.onEditNote != null) {
          Navigator.pop(sheetContext);
          await widget.onEditNote!(
            target.ky,
            target.km,
            target.kd,
            currentEvent,
          );
        }
      },
      itemBuilder: (context) => [
        if (widget.onAppendToJournal != null)
          PopupMenuItem(
            value: 'journal',
            child: Row(
              children: [
                KemeticGold.icon(Icons.library_add_check),
                const SizedBox(width: 12),
                const Text(
                  'Add to journal',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        if (flow != null && !isReminder && widget.onManageFlows != null)
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                KemeticGold.icon(Icons.edit),
                const SizedBox(width: 12),
                const Text('Edit Flow', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        if (flow != null && !isReminder && widget.onShareNote != null)
          PopupMenuItem(
            value: 'invite_people',
            child: Row(
              children: [
                KemeticGold.icon(Icons.person_add_alt_1),
                const SizedBox(width: 12),
                const Text(
                  'Invite People',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        if (flow != null && !isReminder && widget.onSaveFlow != null)
          PopupMenuItem(
            value: 'save',
            child: Row(
              children: [
                KemeticGold.icon(Icons.bookmark_add),
                const SizedBox(width: 12),
                const Text('Save Flow', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        if (isReminder &&
            widget.onEditReminder != null &&
            currentEvent.reminderId != null)
          PopupMenuItem(
            value: 'edit_reminder',
            child: Row(
              children: [
                KemeticGold.icon(Icons.edit),
                const SizedBox(width: 12),
                const Text(
                  'Edit Reminder',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        if (isReminder && widget.onShareReminder != null)
          PopupMenuItem(
            value: 'invite_people',
            child: Row(
              children: [
                KemeticGold.icon(Icons.person_add_alt_1),
                const SizedBox(width: 12),
                const Text(
                  'Invite People',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        if (flow == null && !isReminder && widget.onEditNote != null)
          PopupMenuItem(
            value: 'edit_note',
            child: Row(
              children: [
                KemeticGold.icon(Icons.edit),
                const SizedBox(width: 12),
                const Text('Edit Note', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        if (flow == null && !isReminder && widget.onShareNote != null)
          PopupMenuItem(
            value: 'invite_people',
            child: Row(
              children: [
                KemeticGold.icon(Icons.person_add_alt_1),
                const SizedBox(width: 12),
                const Text(
                  'Invite People',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEventDetailBottomActionRow({
    required BuildContext sheetContext,
    required DayViewSheetEventTarget target,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildEventDetailPrimaryAction(
          sheetContext: sheetContext,
          target: target,
        ),
        TextButton(
          onPressed: () => Navigator.pop(sheetContext),
          child: KemeticGold.text(
            'Close',
            style: _landscapeActionTextStyle.copyWith(fontSize: 15),
          ),
        ),
      ],
    );
  }

  void _showEventDetail(EventItem event, int day) {
    final sheetDataListenable = widget.dataVersion ?? _kLandscapeZeroListenable;
    final currentTarget = ValueNotifier<DayViewSheetEventTarget>(
      DayViewSheetEventTarget(
        ky: widget.kYear,
        km: widget.kMonth,
        kd: day,
        event: event,
      ),
    );
    final measuredHeights = ValueNotifier<Map<String, double>>({});
    final initialPages = _detailSheetPagesForTarget(currentTarget.value);
    PageController sheetPageController = PageController(
      initialPage: initialPages.currentIndex,
    );

    void updateMeasuredHeight(String key, double height) {
      final normalized = height.ceilToDouble();
      if (normalized <= 0) return;
      final previous = measuredHeights.value[key];
      if (previous != null && (previous - normalized).abs() < 1) return;
      measuredHeights.value = Map<String, double>.from(measuredHeights.value)
        ..[key] = normalized;
    }

    void resetSheetPageController(int initialPage) {
      final previous = sheetPageController;
      sheetPageController = PageController(initialPage: initialPage);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        previous.dispose();
      });
    }

    void moveToTarget(DayViewSheetEventTarget nextTarget) {
      final previousTarget = currentTarget.value;
      currentTarget.value = nextTarget;
      if (mounted && nextTarget.kd != previousTarget.kd) {
        _scrollToDay(nextTarget.kd);
      }
      HapticFeedback.selectionClick();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: _bg,
      isScrollControlled: true,
      builder: (sheetContext) {
        return ValueListenableBuilder<int>(
          valueListenable: sheetDataListenable,
          builder: (context, _, __) {
            return ValueListenableBuilder<DayViewSheetEventTarget>(
              valueListenable: currentTarget,
              builder: (context, rawTarget, __) {
                final target = _resolveCurrentEventTarget(rawTarget);
                final pages = _detailSheetPagesForTarget(target);
                final currentKey = _detailSheetTargetKey(target);
                final pageViewKey = ValueKey<String>(
                  '$currentKey:${pages.currentIndex}:${pages.pages.length}',
                );

                return ValueListenableBuilder<Map<String, double>>(
                  valueListenable: measuredHeights,
                  builder: (context, heights, __) {
                    final maxSheetHeight = math.min(
                      MediaQuery.sizeOf(context).height * 0.72,
                      560.0,
                    );
                    final sheetHeight = (heights[currentKey] ?? 200.0)
                        .clamp(0.0, math.max(180.0, maxSheetHeight - 112.0))
                        .toDouble();

                    return SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Offstage(
                            child: Column(
                              children: [
                                for (final pageTarget in pages.pages)
                                  _MeasureSize(
                                    onChange: (size) {
                                      updateMeasuredHeight(
                                        _detailSheetTargetKey(pageTarget),
                                        size.height,
                                      );
                                    },
                                    child: SizedBox(
                                      width: MediaQuery.sizeOf(context).width,
                                      child: _buildEventDetailSheetPage(
                                        target: pageTarget,
                                        scrollable: false,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildEventDetailTopActionRow(
                                  sheetContext: sheetContext,
                                  target: target,
                                ),
                                const SizedBox(height: 10),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.bottomCenter,
                                  child: SizedBox(
                                    height: sheetHeight,
                                    child: PageView.builder(
                                      key: pageViewKey,
                                      controller: sheetPageController,
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: pages.pages.length,
                                      onPageChanged: (index) {
                                        if (index == pages.currentIndex) return;
                                        final nextTarget = pages.pages[index];
                                        final nextPages =
                                            _detailSheetPagesForTarget(
                                              nextTarget,
                                            );
                                        resetSheetPageController(
                                          nextPages.currentIndex,
                                        );
                                        moveToTarget(nextTarget);
                                      },
                                      itemBuilder: (context, index) {
                                        return _buildEventDetailSheetPage(
                                          target: pages.pages[index],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildEventDetailBottomActionRow(
                                  sheetContext: sheetContext,
                                  target: target,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    ).whenComplete(() {
      currentTarget.dispose();
      measuredHeights.dispose();
      sheetPageController.dispose();
    });
  }

  Map<EventItem, int> _assignColumns(List<EventItem> events) {
    final assignments = <EventItem, int>{};
    final columnEndTimes = <int, int>{};

    for (final event in events) {
      int column = 0;
      while (columnEndTimes.containsKey(column) &&
          columnEndTimes[column]! > event.startMin) {
        column++;
      }

      assignments[event] = column;
      columnEndTimes[column] = event.endMin;
    }

    return assignments;
  }

  int _getDaysInMonth() {
    if (widget.kMonth == 13) {
      return KemeticMath.isLeapKemeticYear(widget.kYear) ? 6 : 5;
    }
    return 30;
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  String _stripCidLines(String detail) {
    final lines = detail.split(RegExp(r'\r?\n'));
    final cidRegex = RegExp(
      r'^(kemet_cid:)?ky=\d+-km=\d+-kd=\d+\|s=\d+\|t=[^|]+\|f=[^|]+$',
    );
    final kept = lines.where((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return false;
      if (trimmed.startsWith('flowLocalId=')) return false;
      final norm = trimmed.replaceAll(RegExp(r'\s+'), '');
      if (cidRegex.hasMatch(norm)) return false;
      if (norm.toLowerCase().startsWith('kemet_cid:reminder:')) return false;
      if (norm.toLowerCase().startsWith('reminder:')) return false;
      return true;
    }).toList();
    return kept.join('\n').trim();
  }

  bool _looksLikeCidDetail(String text) {
    final trimmed = text.trim().replaceAll(RegExp(r'\s+'), '');
    final withPrefix = trimmed.startsWith('kemet_cid:')
        ? trimmed.substring('kemet_cid:'.length)
        : trimmed;
    final cidPattern = RegExp(
      r'^ky=\d+-km=\d+-kd=\d+\|s=\d+\|t=[^|]+\|f=[^|]+$',
    );
    return cidPattern.hasMatch(withPrefix);
  }

  String _buildBadgeToken(EventItem event, int day) {
    final g = KemeticMath.toGregorian(widget.kYear, widget.kMonth, day);
    final dayStart = DateTime(g.year, g.month, g.day);
    final start = dayStart.add(Duration(minutes: event.startMin));
    final end = dayStart.add(Duration(minutes: event.endMin));
    final id = 'badge-${DateTime.now().microsecondsSinceEpoch}';
    final rawDesc = event.detail?.trim() ?? '';
    final cleanedDesc = rawDesc.isEmpty ? null : _stripCidLines(rawDesc);
    final descForToken = (cleanedDesc == null || cleanedDesc.isEmpty)
        ? null
        : cleanedDesc;
    return EventBadgeToken.buildToken(
      id: id,
      title: event.title.isEmpty ? 'Scheduled block' : event.title,
      start: start,
      end: end,
      color: event.color,
      description: descForToken,
    );
  }

  Future<void> _quickAddToJournal(EventItem event, int day) async {
    final cb = widget.onAppendToJournal;
    if (cb == null) return;
    final token = _buildBadgeToken(event, day);
    try {
      await cb('$token ');
    } catch (_) {
      // silent catch – journaling should not block UI
    }
  }

  Future<void> _handleAddToJournal(
    EventItem event,
    int day, {
    BuildContext? sheetContext,
  }) async {
    if (sheetContext != null) {
      Navigator.pop(sheetContext);
    }
    await _quickAddToJournal(event, day);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to journal'),
          backgroundColor: Color(0xFFFFC145),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Detect whether a string looks like a URL, email, or phone number.
  bool _isLikelyUrl(String text) {
    final lower = text.toLowerCase().trim();

    // Already has protocol
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return true;
    }

    // Email pattern (check early - most specific)
    if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(lower)) {
      return true;
    }

    // Phone number pattern (check for phone-like formatting)
    final phonePattern = RegExp(
      r'^[\+]?[(]?[0-9]{3}[)]?[-\s\.]?[0-9]{3}[-\s\.]?[0-9]{4,6}$',
    );
    final digitsOnly = lower.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    if (phonePattern.hasMatch(lower) ||
        (digitsOnly.length >= 10 &&
            digitsOnly.length <= 15 &&
            RegExp(r'^\+?[0-9]+$').hasMatch(digitsOnly))) {
      return true;
    }

    // Known service domains (most reliable)
    final knownServices = [
      r'zoom\.us',
      r'meet\.google\.com',
      r'youtube\.com',
      r'youtu\.be',
      r'facebook\.com',
      r'instagram\.com',
      r'twitter\.com',
      r'linkedin\.com',
      r'tiktok\.com',
      r'discord\.gg',
      r'slack\.com',
      r'teams\.microsoft\.com',
    ];

    for (final service in knownServices) {
      if (RegExp(service).hasMatch(lower)) {
        return true;
      }
    }

    // Generic domain pattern (but require at least one dot and TLD, no spaces)
    if (RegExp(
          r'^[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,}(/.*)?$',
        ).hasMatch(lower) &&
        lower.contains('.') &&
        !lower.contains(' ')) {
      // No spaces = likely URL, not address
      return true;
    }

    // www. prefix
    if (lower.startsWith('www\.')) {
      return true;
    }

    return false;
  }

  /// Launch URL/email/phone, or treat as address and open in Maps.
  Future<void> _launchLocation(String raw) async {
    final loc = raw.trim();
    if (loc.isEmpty) return;

    Uri uri;

    if (_isLikelyUrl(loc)) {
      final lower = loc.toLowerCase();

      // Already a full URL
      if (lower.startsWith('http://') || lower.startsWith('https://')) {
        uri = Uri.parse(loc);
      }
      // Email
      else if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(lower)) {
        uri = Uri.parse('mailto:$loc');
      }
      // Phone
      else {
        final digitsOnly = lower.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
        final phonePattern = RegExp(r'^\+?[0-9]{7,15}$');
        if (phonePattern.hasMatch(digitsOnly)) {
          uri = Uri.parse('tel:$loc');
        } else {
          // Bare domain or known service → assume https
          uri = Uri.parse('https://$loc');
        }
      }
    } else {
      // Not URL/email/phone → treat as address (Maps)
      final q = Uri.encodeComponent(loc);
      uri = Uri.parse('https://maps.google.com/?q=$q');
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Turn a block of text into TextSpans with clickable URLs.
  List<TextSpan> _buildTextSpans(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(https?://\S+)', multiLine: true);
    int start = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: const TextStyle(
            decoration: TextDecoration.underline,
            color: Color(0xFF4DA3FF),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
        ),
      );
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return spans;
  }

  String _formatTimeRange(int startMin, int endMin, {bool allDay = false}) {
    if (allDay) return 'All day';
    final startHour = startMin ~/ 60;
    final startMinute = startMin % 60;
    final endHour = endMin ~/ 60;
    final endMinute = endMin % 60;

    String formatTime(int h, int m) {
      final period = h >= 12 ? 'PM' : 'AM';
      final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$hour12:${m.toString().padLeft(2, '0')} $period';
    }

    return '${formatTime(startHour, startMinute)} – ${formatTime(endHour, endMinute)}';
  }
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _MeasureSizeRenderObject(onChange);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _MeasureSizeRenderObject renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _MeasureSizeRenderObject extends RenderProxyBox {
  _MeasureSizeRenderObject(this.onChange);

  ValueChanged<Size> onChange;
  Size? _oldSize;

  @override
  void performLayout() {
    super.performLayout();
    final newSize = child?.size;
    if (newSize == null || newSize == _oldSize) return;
    _oldSize = newSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onChange(newSize);
    });
  }
}
