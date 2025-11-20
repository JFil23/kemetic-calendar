// lib/features/calendar/landscape_month_view.dart
//
// Landscape Month View - Full month grid with INFINITE scrolling
// Styled to match day_view.dart's beautiful detail sheets
//

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'; // For DragStartBehavior
import 'day_view.dart'; // For NoteData, FlowData
import 'calendar_page.dart'; // For KemeticMath
import '../sharing/share_flow_sheet.dart';
import 'package:mobile/features/calendar/kemetic_time_constants.dart';

// ========================================
// SHARED CONSTANTS FOR LANDSCAPE VIEW
// ========================================
const Color _landscapeGold = Color(0xFFFFC145);
const Color _landscapeBg = Color(0xFF000000);      // True black
const Color _landscapeSurface = Color(0xFF0D0D0F); // Dark surface
const Color _landscapeDivider = Color(0xFF1A1A1A); // Divider lines
const double kLandscapeHeaderHeight = 58.0;        // Day number header height

// ========================================
// MAIN LANDSCAPE MONTH VIEW WIDGET
// Entry point from both Main Calendar and Day View
// ========================================

class LandscapeMonthView extends StatelessWidget {
  final int initialKy;
  final int initialKm;
  final int? initialKd; // Optional - from day view
  final bool showGregorian;
  final List<NoteData> Function(int ky, int km, int kd) notesForDay;
  final Map<int, FlowData> flowIndex;
  final String Function(int km) getMonthName;
  final void Function(int? flowId)? onManageFlows;
  final void Function(int ky, int km, int kd)? onAddNote;
  final void Function(int ky, int km)? onMonthChanged; // ✅ NEW CALLBACK

  const LandscapeMonthView({
    super.key,
    required this.initialKy,
    required this.initialKm,
    this.initialKd,
    required this.showGregorian,
    required this.notesForDay,
    required this.flowIndex,
    required this.getMonthName,
    this.onManageFlows,
    this.onAddNote,
    this.onMonthChanged, // ✅ NEW CALLBACK
  });

  @override
  Widget build(BuildContext context) {
    return LandscapeMonthPager(
      initialKy: initialKy,
      initialKm: initialKm,
      initialDay: initialKd,
      showGregorian: showGregorian,
      notesForDay: notesForDay,
      flowIndex: flowIndex,
      getMonthName: getMonthName,
      onManageFlows: onManageFlows,
      onAddNote: onAddNote,
      onMonthChanged: onMonthChanged, // ✅ PASS CALLBACK DOWN
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
  final List<NoteData> Function(int ky, int km, int kd) notesForDay;
  final Map<int, FlowData> flowIndex;
  final String Function(int km) getMonthName;
  final void Function(int? flowId)? onManageFlows;
  final void Function(int ky, int km, int kd)? onAddNote;
  final void Function(int ky, int km)? onMonthChanged; // ✅ NEW CALLBACK

  const LandscapeMonthPager({
    super.key,
    required this.initialKy,
    required this.initialKm,
    this.initialDay,
    required this.showGregorian,
    required this.notesForDay,
    required this.flowIndex,
    required this.getMonthName,
    this.onManageFlows,
    this.onAddNote,
    this.onMonthChanged, // ✅ NEW CALLBACK
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
  late int _baseTotalMonths;  // ✅ Use late (safer than = 0)
  
  // ✅ Today Button Fix: Dual flags to prevent shuffle
  bool _isJumpingToToday = false;      // Blocks onPageChanged during Today jump
  bool _suppressRemap = false;         // Blocks didUpdateWidget remap

  // ✅ FIX A: Canonical month math - Year 1, Month 1 = index 0
  /// Absolute month index where (Year 1, Month 1) == 0
  int _toTotalMonths(int ky, int km) {
    // km expected 1..13, ky can be any integer (…,-1,0,1,2,…)
    return (ky - 1) * 13 + (km - 1);  // ✅ Year 1, Month 1 = 0
  }

  int _pageFor(int ky, int km) =>
    _centerPage + (_toTotalMonths(ky, km) - _toTotalMonths(widget.initialKy, widget.initialKm));

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
    return (kYear: y0 + 1, kMonth: m0 + 1);  // ✅ Convert back to 1-indexed
  }

  ({int kYear, int kMonth}) _monthForPage(int page) {
    final delta = page - _centerPage;
    final total = _baseTotalMonths + delta;  // ✅ Use canonical base
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
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LandscapeMonthPager oldWidget) {
    super.didUpdateWidget(oldWidget);

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
        print('✓ [PAGER] Updated base during suppression: $oldBase → $newBase');
      }
      return;
    }

    // ✅ Preserve same absolute month on screen
    final delta = _currentPage - _centerPage;
    final curTotal = oldBase + delta;
    final newDelta = curTotal - newBase;
    final newPage = _centerPage + newDelta;

    if (kDebugMode) {
      print('🔄 [PAGER] Base changed: $oldBase → $newBase');
      print('   Preserving absolute month: $curTotal');
      print('   New page: $newPage');
    }

    if (_pageController.hasClients && newPage != _currentPage) {
      _pageController.jumpToPage(newPage);
      _currentPage = newPage;
      _lastNotifiedPage = newPage;
      _actualMonth = _monthForPage(newPage);
      
      if (kDebugMode) {
        print('✓ [PAGER] Remap complete');
      }
    }
    
    // When callback becomes available, force PageView to rebuild current page
    if (oldWidget.onAddNote == null && widget.onAddNote != null) {
      if (kDebugMode) {
        print('⚡ [PAGER] Callback just arrived! Forcing rebuild...');
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

  // 🔧 NEW: Build month header for AppBar
  Widget _buildMonthHeader(String monthName, String yearLabel) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          monthName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _landscapeGold,
          ),
        ),
        Text(
          yearLabel,
          style: TextStyle(
            fontSize: 11,
            color: _landscapeGold.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _landscapeBg,
      body: Column(
        children: [
          _buildCustomHeader(context), // Custom header like day_view
          Expanded(
            child: _buildBodyWithSwipeGate(context), // PageView below
          ),
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
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monthName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _landscapeGold,
                      ),
                    ),
                    Text(
                      yearLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: _landscapeGold.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Flow Studio button - OUTSIDE GestureDetector (no gesture interference)
              IconButton(
                tooltip: 'Flow Studio',
                icon: const Icon(Icons.view_timeline, color: _landscapeGold),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onPressed: widget.onManageFlows != null
                    ? () {
                        if (kDebugMode) {
                          print('🔘 [LANDSCAPE] Flow Studio tapped');
                        }
                        widget.onManageFlows!(null);
                      }
                    : null,
              ),
              // Add Note button - OUTSIDE GestureDetector (no gesture interference)
              IconButton(
                tooltip: 'New note',
                icon: const Icon(Icons.add, color: _landscapeGold),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onPressed: widget.onAddNote != null
                    ? () {
                        if (kDebugMode) {
                          print('🔘 [LANDSCAPE] Add Note tapped');
                        }
                        final now = DateTime.now();
                        final today = KemeticMath.fromGregorian(now);
                        final currentMonth = _monthForPage(_currentPage);
                        final kd = (currentMonth.kYear == today.kYear && 
                                    currentMonth.kMonth == today.kMonth) 
                            ? today.kDay 
                            : 1;
                        
                        if (currentMonth.kMonth == 13 && kDebugMode) {
                          print('⚠️ [LANDSCAPE] Creating note in sacred Month 13 (Heriu Renpet)');
                          print('   Day: $kd');
                        }
                        
                        widget.onAddNote!(currentMonth.kYear, currentMonth.kMonth, kd);
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
      physics: const PageScrollPhysics(), // ✅ Allows gesture AND animateToPage()
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
            print('📄 [PAGER] Page changed to $page during Today jump - state updated, parent notification blocked');
          }
          return;
        }

        // ✅ Normal swipe → notify parent so it sends correct data
        if (kDebugMode) {
          print('📄 [PAGER] Page changed to: $page');
          print('   Month: ${m.kYear}-${m.kMonth}');
        }
        widget.onMonthChanged?.call(m.kYear, m.kMonth);
      },
      itemBuilder: (context, index) {
        final m = _monthForPage(index);
        final pageInitialDay = (widget.initialDay != null &&
                                m.kYear == widget.initialKy &&
                                m.kMonth == widget.initialKm)
                               ? widget.initialDay
                               : null;
        
        if (kDebugMode) {
          print('🔧 [PAGER] Creating LandscapeMonthGridBody for page $index');
          print('   Month: ${m.kYear}-${m.kMonth}');
        }
        
        return LandscapeMonthGridBody(
          key: ValueKey('grid-body-${m.kYear}-${m.kMonth}'),
          kYear: m.kYear,
          kMonth: m.kMonth,
          initialDay: pageInitialDay,          // ✅ use 'initialDay'
          showGregorian: widget.showGregorian,
          notesForDay: widget.notesForDay,
          flowIndex: widget.flowIndex,
          getMonthName: widget.getMonthName,
          onManageFlows: widget.onManageFlows,
          onAddNote: widget.onAddNote,
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
  final List<NoteData> Function(int ky, int km, int kd) notesForDay;
  final Map<int, FlowData> flowIndex;
  final String Function(int km) getMonthName;
  final void Function(int? flowId)? onManageFlows;
  final void Function(int ky, int km, int kd)? onAddNote;

  const LandscapeMonthGridBody({
    super.key,
    required this.kYear,
    required this.kMonth,
    this.initialDay,
    required this.showGregorian,
    required this.notesForDay,
    required this.flowIndex,
    required this.getMonthName,
    this.onManageFlows,
    this.onAddNote,
  });

  @override
  State<LandscapeMonthGridBody> createState() => _LandscapeMonthGridBodyState();
}

class _LandscapeMonthGridBodyState extends State<LandscapeMonthGridBody> {
  // Layout constants (matching existing landscape)
  static const double _rowH = 64.0;      // hour row height
  static const double _gutterW = 56.0;   // time gutter width
  static const double _headerH = kLandscapeHeaderHeight;   // day number header (shared constant)
  static const double _daySepW = 1.0;    // day separator
  static const double _hourSepH = 1.0;   // hour separator
  static const double _kLandscapeEventMinHeight = 56.0;  // was 32.0

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

  // 🔍 NEW: Debug tracking
  int _buttonTapCount = 0;
  bool _isDisposed = false;

  bool _syncingH = false;
  bool _syncingV = false;

  @override
  void initState() {
    super.initState();
    
    if (kDebugMode) {
      print('🟢 [LANDSCAPE] LandscapeMonthGridBody initState()');
      print('   kYear: ${widget.kYear}, kMonth: ${widget.kMonth}');
      print('   onAddNote callback: ${widget.onAddNote != null ? "PROVIDED" : "NULL"}');
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
        _hHeader.jumpTo(_hGrid.offset.clamp(0.0, _hHeader.position.maxScrollExtent));
      }
      _syncingH = false;
    });

    // Sync vertical scrolling
    _vGutter.addListener(() {
      if (_syncingV) return;
      _syncingV = true;
      if (_vGrid.hasClients) {
        _vGrid.jumpTo(_vGutter.offset.clamp(0.0, _vGrid.position.maxScrollExtent));
      }
      _syncingV = false;
    });

    _vGrid.addListener(() {
      if (_syncingV) return;
      _syncingV = true;
      if (_vGutter.hasClients) {
        _vGutter.jumpTo(_vGrid.offset.clamp(0.0, _vGutter.position.maxScrollExtent));
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToDay(widget.initialDay!));
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (kDebugMode) {
      print('🔴 [LANDSCAPE] LandscapeMonthGridBody dispose()');
      print('   Button was tapped $_buttonTapCount times before disposal');
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
      print('🏗️  [LANDSCAPE] build() - FIRST TIME');
      print('   Context: $context');
      print('   Mounted: ${mounted}');
      print('   Disposed: $_isDisposed}');
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
            child: Container(
              color: _surface,
            ),
          ),

          // Day headers (scrollable horizontally)
          Positioned(
            left: _gutterW,
            top: 0,
            right: 0,
            height: _headerH,
            child: IgnorePointer(
              ignoring: true, // Prevent any gesture recognizers from header subtree
              child: SingleChildScrollView(
                controller: _hHeader,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(), // 🔧 REMOVES FROM GESTURE ARENA
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
                physics: const ClampingScrollPhysics(), // 🔧 Prevent gesture conflicts
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
              physics: const ClampingScrollPhysics(), // 🔧 Prevent gesture conflicts
              child: SingleChildScrollView(
                controller: _hGrid,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(), // ✅ Re-enabled for horizontal scrolling
                child: SizedBox(
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
    final isToday = today.kYear == widget.kYear &&
                    today.kMonth == widget.kMonth &&
                    today.kDay == day;

    // Get Gregorian date
    // FIXED: Convert UTC result to local at noon to avoid DST issues
    final gregorianDate = safeLocalDisplay(KemeticMath.toGregorian(widget.kYear, widget.kMonth, day));

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
            '$day',
            style: TextStyle(
              fontSize: 16,
              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
              color: isToday ? _gold : Colors.white,
            ),
          ),
          if (widget.showGregorian)
            Text(
              '${gregorianDate.month}/${gregorianDate.day}',
              style: TextStyle(
                fontSize: 9,
                color: isToday 
                  ? _gold.withOpacity(0.7) 
                  : const Color(0xFF808080),
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
            child: Container(
              height: _hourSepH,
              color: _divider,
            ),
          ),
        
        // Vertical day lines
        for (int day = 0; day < dayCount; day++)
          Positioned(
            left: day * (colW + _daySepW) + colW,
            top: 0,
            bottom: 0,
            child: Container(
              width: _daySepW,
              color: _divider,
            ),
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
      
      // Only keep first occurrence
      if (!seen.containsKey(key)) {
        seen[key] = note;
      }
    }
    
    return seen.values.toList();
  }

  List<Widget> _buildEventsForDay(int day, double colW) {
    final rawNotes = widget.notesForDay(widget.kYear, widget.kMonth, day);
    
    // ✅ ADD DEBUG LOGGING
    if (kDebugMode && rawNotes.isNotEmpty) {
      print('📅 [LANDSCAPE] Building events for day $day');
      print('   Year: ${widget.kYear}, Month: ${widget.kMonth}');
      print('   Raw notes: ${rawNotes.length}');
      print('   FlowIndex keys: ${widget.flowIndex.keys.toList()}');
      for (var note in rawNotes) {
        print('   - Note: "${note.title}", flowId: ${note.flowId}');
        if (note.flowId != null) {
          final flow = widget.flowIndex[note.flowId];
          print('     Flow color: ${flow?.color}');
        }
      }
    }
    
    // ✅ NEW: Dedupe notes before rendering to handle legacy duplicates
    final notes = _dedupeNotesForUI(rawNotes);
    
    if (kDebugMode && rawNotes.isNotEmpty && notes.isEmpty) {
      print('⚠️ [LANDSCAPE] All notes deduped for day $day!');
    }
    if (notes.isEmpty) return [];

    if (kDebugMode) {
      final originalCount = rawNotes.length;
      final dedupedCount = notes.length;
      if (originalCount != dedupedCount) {
        print('[LandscapeMonthView] Deduplicated events for day $day: $originalCount → $dedupedCount (removed ${originalCount - dedupedCount} duplicates)');
      }
    }

    // Convert notes to events
    final events = <_EventItem>[];
    for (final note in notes) {
      final startMin = note.allDay ? 9 * 60 : (note.start?.hour ?? 9) * 60 + (note.start?.minute ?? 0);
      final endMin = note.allDay ? 17 * 60 : (note.end?.hour ?? 17) * 60 + (note.end?.minute ?? 0);

      Color eventColor = Colors.blue;
      if (note.flowId != null) {
        final flow = widget.flowIndex[note.flowId];
        if (flow != null) {
          eventColor = flow.color;
        }
      }

      events.add(_EventItem(
        title: note.title,
        detail: note.detail,
        location: note.location,
        startMin: startMin,
        endMin: endMin,
        flowId: note.flowId,
        color: eventColor,
      ));
    }

    if (events.isEmpty) return [];

    // Sort by start time, then title
    events.sort((a, b) {
      final timeCompare = a.startMin.compareTo(b.startMin);
      if (timeCompare != 0) return timeCompare;
      return a.title.compareTo(b.title);
    });

    // Assign columns to avoid overlaps
    final widgets = <Widget>[];
    const columnGap = 4.0;
    
    final columnAssignments = _assignColumns(events);
    final maxCols = columnAssignments.values.isEmpty 
      ? 1 
      : (columnAssignments.values.reduce((a, b) => a > b ? a : b) + 1);

    final availableWidth = colW - (columnGap * (maxCols - 1));
    final columnWidth = availableWidth / maxCols;

    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      final col = columnAssignments[event] ?? 0;
      final left = (day - 1) * (colW + _daySepW) + (col * (columnWidth + columnGap));
      final top = (event.startMin / 60.0) * _rowH;
      
      // ✅ FIX 5: Calculate and clamp duration like day view
      int durationMinutes = event.endMin - event.startMin;
      if (durationMinutes <= 0) {
        durationMinutes = 15;
      }
      if (durationMinutes > 180) {
        durationMinutes = 180;
      }
      // ✅ Add minimum height to prevent overflow (accounts for padding + text content)
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
          child: GestureDetector(
            behavior: HitTestBehavior.opaque, // ✅ full-rect hit target
            onTap: () => _showEventDetail(event),
            child: Container(
              margin: const EdgeInsets.only(right: 4, bottom: 2),
              padding: const EdgeInsets.all(4), // ✅ Match day view exactly
              decoration: BoxDecoration(
                color: event.color.withOpacity(0.20),
                border: Border(
                  left: BorderSide(color: event.color, width: 3), // ✅ Left border only
                ),
                borderRadius: BorderRadius.circular(4), // ✅ Radius 4 (not 6)
              ),
              clipBehavior: Clip.hardEdge, // ✅ Prevent overflow
              child: _buildEventBlockContent(event, durationMinutes),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildEventBlockContent(_EventItem event, int durationMinutes) {
    final flow = widget.flowIndex[event.flowId];
    final hasFlow = flow != null;

    final showTitle = event.title.trim().isNotEmpty;
    final showLocation = event.location != null &&
        event.location!.trim().isNotEmpty &&
        durationMinutes > 45;

    return Column(
      mainAxisSize: MainAxisSize.min, // ✅ Don't expand unnecessarily
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Flow name first (if available)
        if (hasFlow) ...[
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
            maxLines: (hasFlow || durationMinutes < 90) ? 1 : 2, // ✅ Conditional line limit
            overflow: TextOverflow.ellipsis,
          )
        else
          Text( // ✅ No const - text is conditional
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
        
        // Location (if space allows)
        if (showLocation)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              event.location!.trim(),
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.7), // ✅ NO fontWeight
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  void _showEventDetail(_EventItem event) {
    final flow = widget.flowIndex[event.flowId];

    showModalBottomSheet(
      context: context,
      backgroundColor: _surface, // Dark surface (matching day view)
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SingleChildScrollView( // Fix for overflow
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with flow badge and menu
                if (flow != null) ...[
                  Row(
                    children: [
                      // Flow name badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: flow.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: flow.color, width: 1),
                        ),
                        child: Text(
                          flow.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: flow.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // 3-dot menu
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Color(0xFFD4AF37)),
                        tooltip: 'Event options',
                        onSelected: (value) async {
                          if (value == 'edit') {
                            Navigator.pop(context);
                            if (widget.onManageFlows != null) {
                              widget.onManageFlows!(flow.id);
                            }
                          } else if (value == 'share') {
                            Navigator.pop(context);
                            final result = await showModalBottomSheet<bool>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => ShareFlowSheet(
                                flowId: flow.id,
                                flowTitle: flow.name,
                              ),
                            );
                            
                            if (result == true && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Flow shared successfully!'),
                                  backgroundColor: Color(0xFFD4AF37),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Color(0xFFD4AF37)),
                                SizedBox(width: 12),
                                Text('Edit Flow', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share, color: Color(0xFFD4AF37)),
                                SizedBox(width: 12),
                                Text('Share Flow', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                        color: const Color(0xFF000000),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Event title
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                // Time
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Color(0xFF808080)),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimeRange(event.startMin, event.endMin),
                      style: const TextStyle(color: Color(0xFF808080)),
                    ),
                  ],
                ),

                // Location
                if (event.location != null && event.location!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Color(0xFF808080)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event.location!,
                          style: const TextStyle(color: Color(0xFF808080)),
                        ),
                      ),
                    ],
                  ),
                ],

                // Details
                if (event.detail != null && event.detail!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    event.detail!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Action buttons (matching day view style)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: widget.onManageFlows == null ? null : () {
                        Navigator.pop(context);
                        widget.onManageFlows!(null);
                      },
                      icon: Icon(
                        Icons.view_timeline,
                        color: widget.onManageFlows == null
                          ? const Color(0xFF404040)
                          : _gold, // Gold
                      ),
                      label: Text(
                        'Manage Flows',
                        style: TextStyle(
                          color: widget.onManageFlows == null
                            ? const Color(0xFF404040)
                            : _gold, // Gold
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: _gold), // Gold
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<_EventItem, int> _assignColumns(List<_EventItem> events) {
    final assignments = <_EventItem, int>{};
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

  String _formatTimeRange(int startMin, int endMin) {
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

// ========================================
// HELPER CLASSES
// ========================================

class _EventItem {
  final String title;
  final String? detail;
  final String? location;
  final int startMin;
  final int endMin;
  final int? flowId;
  final Color color;

  const _EventItem({
    required this.title,
    this.detail,
    this.location,
    required this.startMin,
    required this.endMin,
    this.flowId,
    required this.color,
  });
}
// Landscape Month View - Full month grid with INFINITE scrolling
// Styled to match day_view.dart's beautiful detail sheets
//

