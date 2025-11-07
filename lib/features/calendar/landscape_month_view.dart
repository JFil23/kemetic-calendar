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
    this.onAddNote, // 🔧 NEW
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
      onAddNote: onAddNote, // 🔧 NEW: Pass it down
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
    this.onAddNote, // 🔧 NEW
  });

  @override
  State<LandscapeMonthPager> createState() => _LandscapeMonthPagerState();
}

class _LandscapeMonthPagerState extends State<LandscapeMonthPager> {
  late PageController _pageController;
  static const int _centerPage = 100000; // Match your _LandscapePager's _origin
  
  // 🔧 NEW: Track current page for AppBar display
  int _currentPage = 100000;
  
  // 🔧 NEW: Track drag accumulation for manual gesture control
  double _dragAccum = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _centerPage);
    _currentPage = _centerPage; // 🔧 NEW: Initialize
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LandscapeMonthPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (kDebugMode) {
      print('🔄 [PAGER] didUpdateWidget()');
      print('   Old onAddNote: ${oldWidget.onAddNote != null ? "PROVIDED" : "NULL"}');
      print('   New onAddNote: ${widget.onAddNote != null ? "PROVIDED" : "NULL"}');
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

  // Calculate which month to show based on page offset
  // EXACTLY matches your _LandscapePager._addMonths logic
  ({int kYear, int kMonth}) _monthForPage(int page) {
    final delta = page - _centerPage;
    
    // Use INITIAL year/month (never changes) + delta
    final zero = (widget.initialKy * 13) + (widget.initialKm - 1) + delta;
    final ky = zero ~/ 13;
    final km = (zero % 13) + 1;
    
    return (kYear: ky, kMonth: km);
  }

  void _jumpToToday() {
    final now = DateTime.now();
    final today = KemeticMath.fromGregorian(now);
    
    // Calculate which page shows today's month
    final todayTotalMonths = (today.kYear * 13) + (today.kMonth - 1);
    final initialTotalMonths = (widget.initialKy * 13) + (widget.initialKm - 1);
    final delta = todayTotalMonths - initialTotalMonths;
    final targetPage = _centerPage + delta;
    
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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

  // 🔧 NEW: Custom header (like day_view pattern) with month swipe gesture
  Widget _buildCustomHeader(BuildContext context) {
    final currentMonth = _monthForPage(_currentPage);
    final monthName = widget.getMonthName(currentMonth.kMonth);
    final yearLabel = _getYearLabel(currentMonth.kYear, currentMonth.kMonth);
    
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (details) {
        _dragAccum = 0.0;
      },
      onHorizontalDragUpdate: (details) {
        _dragAccum += details.delta.dx;
      },
      onHorizontalDragEnd: (details) async {
        const double distThreshold = 40.0;
        const double velThreshold = 600.0;
        final vx = details.primaryVelocity ?? 0.0;

        if (vx <= -velThreshold || _dragAccum <= -distThreshold) {
          // Swipe left → next month
          if (_pageController.hasClients) {
            await _pageController.nextPage(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
            );
          }
        } else if (vx >= velThreshold || _dragAccum >= distThreshold) {
          // Swipe right → previous month
          if (_pageController.hasClients) {
            await _pageController.previousPage(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
            );
          }
        }
        _dragAccum = 0.0;
      },
      child: Container(
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
                // Month/Year title
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
                // Flow Studio button
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
                // Add Note button
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
                // Today button
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
      ),
    );
  }

  // 🔧 NEW: Body with PageView (no gesture handling - grid handles its own)
  Widget _buildBodyWithSwipeGate(BuildContext context) {
    return PageView.builder(
      key: ValueKey('landscape-pager-${widget.initialKy}-${widget.initialKm}-${widget.onAddNote?.hashCode ?? "null"}'),
      controller: _pageController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(), // Month changes via header only
      pageSnapping: true,
      onPageChanged: (page) {
        setState(() {
          _currentPage = page;
        });
      },
      itemBuilder: (context, index) {
        final month = _monthForPage(index);
        
        if (kDebugMode) {
          print('🔧 [PAGER] Creating LandscapeMonthGridBody for page $index');
          print('   Month: ${month.kYear}-${month.kMonth}');
        }
        
        return LandscapeMonthGridBody(
          key: ValueKey('grid-body-${month.kYear}-${month.kMonth}'),
          kYear: month.kYear,
          kMonth: month.kMonth,
          initialDay: index == _centerPage ? widget.initialDay : null,
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
    
    // ✅ NEW: Dedupe notes before rendering to handle legacy duplicates
    final notes = _dedupeNotesForUI(rawNotes);
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
      final height = ((event.endMin - event.startMin) / 60.0) * _rowH;

      widgets.add(
        Positioned(
          left: left,
          top: top,
          width: columnWidth,
          height: height,
          child: GestureDetector(
            onTap: () => _showEventDetail(event),
            child: Container(
              margin: const EdgeInsets.only(right: 4, bottom: 2),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: event.color.withOpacity(0.2),
                border: Border(
                  left: BorderSide(color: event.color, width: 3),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _buildEventBlockContent(event),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildEventBlockContent(_EventItem event) {
    final flow = widget.flowIndex[event.flowId];
    final hasFlow = flow != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Flow name first (if available)
        if (hasFlow) ...[
          Text(
            flow!.name,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: event.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
        ],
        
        // Note title
        Text(
          event.title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          maxLines: hasFlow ? 1 : 2,
          overflow: TextOverflow.ellipsis,
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

