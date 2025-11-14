// lib/features/calendar/day_view.dart
// 
// Day View - 24-hour timeline with pixel-perfect event layout
// Uses EventLayoutEngine for consistent positioning
//

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'calendar_page.dart';
import 'landscape_month_view.dart';
import '../sharing/share_flow_sheet.dart';
import '../../widgets/kemetic_day_info.dart';
import 'package:mobile/core/day_key.dart';

// ========================================
// EVENT LAYOUT ENGINE
// ========================================

class EventLayoutEngine {
  static List<PositionedEventBlock> layoutEventsForDay({
    required List<NoteData> notes,
    required Map<int, FlowData> flowIndex,
    required double columnWidth,
    required double columnGap,
    required int day, // For debug logging
  }) {
    if (kDebugMode) {
      print('[EventLayoutEngine] Layout for day $day: ${notes.length} notes');
    }

    // Convert notes to events
    final events = <EventItem>[];
    for (final note in notes) {
      final startMin = note.allDay ? 9 * 60 : (note.start?.hour ?? 9) * 60 + (note.start?.minute ?? 0);
      final endMin = note.allDay ? 17 * 60 : (note.end?.hour ?? 17) * 60 + (note.end?.minute ?? 0);
      
      // Get flow color
      Color eventColor = Colors.blue;
      if (note.flowId != null) {
        final flow = flowIndex[note.flowId];
        if (flow != null) {
          eventColor = flow.color;
        }
      }

      events.add(EventItem(
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

    // Sort by start time
    events.sort((a, b) => a.startMin.compareTo(b.startMin));

    // Assign columns to avoid overlaps
    final columnAssignments = _assignColumns(events);

    // Create positioned blocks
    final blocks = <PositionedEventBlock>[];
    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      final column = columnAssignments[event] ?? 0;
      final leftOffset = column * (columnWidth + columnGap);
      
      blocks.add(PositionedEventBlock(
        event: event,
        leftOffset: leftOffset,
        width: columnWidth,
      ));
    }

    if (kDebugMode) {
      print('[EventLayoutEngine] Generated ${blocks.length} positioned blocks');
    }

    return blocks;
  }

  static Map<EventItem, int> _assignColumns(List<EventItem> events) {
    final assignments = <EventItem, int>{};
    final columnEndTimes = <int, int>{}; // column -> end time

    for (final event in events) {
      // Find first available column
      int column = 0;
      while (columnEndTimes.containsKey(column) && columnEndTimes[column]! > event.startMin) {
        column++;
      }
      
      assignments[event] = column;
      columnEndTimes[column] = event.endMin;
    }

    return assignments;
  }
}

// ========================================
// DATA MODELS
// ========================================

class NoteData {
  final String title;
  final String? detail;
  final String? location;
  final bool allDay;
  final TimeOfDay? start;
  final TimeOfDay? end;
  final int? flowId;

  const NoteData({
    required this.title,
    this.detail,
    this.location,
    required this.allDay,
    this.start,
    this.end,
    this.flowId,
  });
}

class FlowData {
  final int id;
  final String name;
  final Color color;
  final bool active;

  const FlowData({
    required this.id,
    required this.name,
    required this.color,
    required this.active,
  });
}

class EventItem {
  final String title;
  final String? detail;
  final String? location;
  final int startMin;
  final int endMin;
  final int? flowId;
  final Color color;

  const EventItem({
    required this.title,
    this.detail,
    this.location,
    required this.startMin,
    required this.endMin,
    this.flowId,
    required this.color,
  });

  @override
  String toString() {
    return 'EventItem(title: "$title", flowId: $flowId, color: $color, startMin: $startMin)';
  }
}

class PositionedEventBlock {
  final EventItem event;
  final double leftOffset;
  final double width;

  const PositionedEventBlock({
    required this.event,
    required this.leftOffset,
    required this.width,
  });
}

// ========================================
// DAY VIEW PAGE (Main entry point)
// ========================================

class DayViewPage extends StatefulWidget {
  final int initialKy;
  final int initialKm;
  final int initialKd;
  final bool showGregorian;
  final List<NoteData> Function(int ky, int km, int kd) notesForDay;
  final Map<int, FlowData> flowIndex;
  final String Function(int km) getMonthName;
  final void Function(int?)? onManageFlows; // NEW: Callback to open My Flows
  final void Function(int ky, int km, int kd)? onAddNote;

  const DayViewPage({
    super.key,
    required this.initialKy,
    required this.initialKm,
    required this.initialKd,
    required this.showGregorian,
    required this.notesForDay,
    required this.flowIndex,
    required this.getMonthName,
    this.onManageFlows, // NEW
    this.onAddNote, // 🔧 NEW
  });

  @override
  State<DayViewPage> createState() => _DayViewPageState();
}

class _DayViewPageState extends State<DayViewPage> {
  late PageController _pageController;
  late int _currentKy;
  late int _currentKm;
  late int _currentKd;
  late DateTime _initialGregorian; // Added for stable date arithmetic
  static const int _centerPage = 5000;
  double? _savedScrollOffset; // Added for scroll persistence
  
  // ✅ Today button guard to prevent duplicate state updates
  bool _isJumpingToToday = false;
  
  // 🔧 ADD THIS: Persistent scroll controller for mini calendar
  late ScrollController _miniCalendarScrollController;
  
  // 🔧 NEW: Orientation tracking for bidirectional lock
  Orientation? _lastOrientation;

  @override
  void initState() {
    super.initState();
    _currentKy = widget.initialKy;
    _currentKm = widget.initialKm;
    _currentKd = widget.initialKd;
    _initialGregorian = KemeticMath.toGregorian(_currentKy, _currentKm, _currentKd);
    _pageController = PageController(initialPage: _centerPage);
    
    // 🔧 Initialize mini calendar scroll controller with starting position
    final dayCount = _currentKm == 13 
        ? (KemeticMath.isLeapKemeticYear(_currentKy) ? 6 : 5)
        : 30;
    final initialScroll = ((_currentKd - 5).clamp(0, (dayCount - 10).clamp(0, dayCount))).toDouble() * 34; // 30 width + 4 margin
    _miniCalendarScrollController = ScrollController(initialScrollOffset: initialScroll);
  }

  @override
  void didUpdateWidget(covariant DayViewPage old) {
    super.didUpdateWidget(old);
    if (old.initialKy != widget.initialKy ||
        old.initialKm != widget.initialKm ||
        old.initialKd != widget.initialKd) {
      final g = KemeticMath.toGregorian(
        widget.initialKy, widget.initialKm, widget.initialKd ?? 1,
      );
      setState(() {
        _initialGregorian = g;
        _currentKy = widget.initialKy;
        _currentKm = widget.initialKm;
        _currentKd = widget.initialKd ?? 1;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_centerPage);  // reset paging anchor
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollMiniCalendarToCenter(_currentKd);     // keep gold circle centered
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _miniCalendarScrollController.dispose(); // 🔧 Don't forget to dispose
    super.dispose();
  }

  /// Generate the day key for Kemetic day info lookup
  String _getKemeticDayKey(int kYear, int kMonth, int kDay) {
    // kYear parameter kept for API consistency but not used in day key generation.
    // Day keys use DECAN (1-3), not year. Decan is computed from kDay in kemeticDayKey().
    // 
    // NOTE: This validates range 1-12 (not 1-13) because day_view.dart
    // doesn't handle epagomenal days currently.
    if (kMonth < 1 || kMonth > 12) {
      return 'unknown_${kDay}_$kYear';
    }
    return kemeticDayKey(kMonth, kDay);
  }

  ({int kYear, int kMonth, int kDay}) _dateForPage(int pageIndex) {
    final offset = pageIndex - _centerPage;
    final targetGregorian = _initialGregorian.add(Duration(days: offset));
    return KemeticMath.fromGregorian(targetGregorian);
  }

  void _onPageChanged(int pageIndex) {
    final kDate = _dateForPage(pageIndex);
    
    setState(() {
      _currentKy = kDate.kYear;
      _currentKm = kDate.kMonth;
      _currentKd = kDate.kDay;
    });
    
    // ✅ Don't duplicate state updates during Today jump
    if (_isJumpingToToday) return;
    
    // Animate mini calendar when day changes
    _scrollMiniCalendar();
  }

  void _onScrollChanged(double offset) {
    _savedScrollOffset = offset;
  }

  // 🔧 ADD THIS METHOD: Animates the mini calendar scroll
  void _scrollMiniCalendar() {
    if (!_miniCalendarScrollController.hasClients) return;
    
    final dayCount = _currentKm == 13 
        ? (KemeticMath.isLeapKemeticYear(_currentKy) ? 6 : 5)
        : 30;
    
    // Calculate target scroll position (keep current day around position 5)
    final targetScroll = ((_currentKd - 5).clamp(0, (dayCount - 10).clamp(0, dayCount))).toDouble() * 34; // 30 width + 4 margin
    
    // Animate to the new position
    _miniCalendarScrollController.animateTo(
      targetScroll,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _scrollMiniCalendarToCenter(int day) {
    // tune to your chip size/gaps; 34.0 is a common width
    const chipW = 34.0;
    const centerIndex = 5; // places selection near the middle of the row
    final target = (day - centerIndex).clamp(0, 27) * chipW;
    if (_miniCalendarScrollController.hasClients) {
      _miniCalendarScrollController.animateTo(
        target.toDouble(),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  // 🔧 NEW: Convert Kemetic date to total days for navigation
  int _kemeticToTotalDays(int ky, int km, int kd) {
    // Approximate total days since epoch
    return ky * 365 + (km - 1) * 30 + kd;
  }


  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    
    // Track orientation changes for debugging
    if (_lastOrientation != null && _lastOrientation != orientation) {
      if (kDebugMode) {
        print('\n📱 [DAY VIEW] Orientation changed: $_lastOrientation → $orientation');
      }
    }
    
    _lastOrientation = orientation;

    return Scaffold(
      backgroundColor: const Color(0xFF000000), // True black
      body: OrientationBuilder(
        builder: (context, orientation) {
          if (orientation == Orientation.landscape) {
            return LandscapeMonthView(
              initialKy: _currentKy,
              initialKm: _currentKm,
              initialKd: _currentKd,
              showGregorian: widget.showGregorian,
              notesForDay: widget.notesForDay,
              flowIndex: widget.flowIndex,
              getMonthName: widget.getMonthName,
              onManageFlows: widget.onManageFlows,
              onAddNote: widget.onAddNote,
              onMonthChanged: (ky, km) {
                // ✅ HANDLE MONTH CHANGE IN DAY VIEW
                if (kDebugMode) {
                  print('🔄 [DAY VIEW] Landscape month changed: Year $ky, Month $km');
                }
                setState(() {
                  _currentKy = ky;
                  _currentKm = km;
                  // Keep current day if still valid in new month
                  final maxDay = km == 13 
                      ? (KemeticMath.isLeapKemeticYear(ky) ? 6 : 5)
                      : 30;
                  if (_currentKd > maxDay) {
                    _currentKd = maxDay;
                  }
                });
              },
            );
          }
          
          // Portrait day view
          return Column(
            children: [
              // Custom Apple-style header
              _buildAppleStyleHeader(),
              
              // Existing page view with timeline
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final kDate = _dateForPage(index);
                    return DayViewGrid(
                      key: ValueKey('${kDate.kYear}-${kDate.kMonth}-${kDate.kDay}'), // Add key
                      ky: kDate.kYear,
                      km: kDate.kMonth,
                      kd: kDate.kDay,
                      notes: widget.notesForDay(kDate.kYear, kDate.kMonth, kDate.kDay),
                      showGregorian: widget.showGregorian,
                      flowIndex: widget.flowIndex,
                      initialScrollOffset: _savedScrollOffset,    // 🔧 NEW
                      onScrollChanged: _onScrollChanged,          // 🔧 NEW
                      onManageFlows: widget.onManageFlows, // NEW: Pass callback down
                      onAddNote: widget.onAddNote,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDayHeader() {
    final monthName = widget.getMonthName(_currentKm);
    
    return Text(
      '$monthName $_currentKy, Day $_currentKd',
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFFFFC145), // Gold
      ),
    );
  }

  Widget _buildAppleStyleHeader() {
    final monthName = widget.getMonthName(_currentKm);
    final dayCount = _currentKm == 13 
      ? (KemeticMath.isLeapKemeticYear(_currentKy) ? 6 : 5)
      : 30;
    
    // Get today's Kemetic date for highlighting
    final now = DateTime.now();
    final today = KemeticMath.fromGregorian(now);
    
    // 🔧 FIX 1: Get Gregorian year for the current Kemetic date
    final currentGregorian = KemeticMath.toGregorian(_currentKy, _currentKm, _currentKd);
    final gregorianYear = currentGregorian.year; // This is 2025
    
    return Container(
      color: const Color(0xFF0D0D0F), // Dark surface
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top row: Close button, Month name, Flow Studio, Today
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  // Close button
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFFFFC145)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  // Month name
                  Expanded(
                    child: Text(
                      monthName,
                      style: const TextStyle(
                        color: Color(0xFFFFC145),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Flow Studio button
                  IconButton(
                    tooltip: 'Flow Studio',
                    icon: const Icon(Icons.view_timeline, color: Color(0xFFFFC145)),
                    padding: const EdgeInsets.symmetric(horizontal: 4), // 🔧 Reduced padding
                    onPressed: widget.onManageFlows != null ? () => widget.onManageFlows!(null) : null,
                  ),
                  // 🔧 NEW: Add note button
                  IconButton(
                    tooltip: 'New note',
                    icon: const Icon(Icons.add, color: Color(0xFFFFC145)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onPressed: widget.onAddNote != null
                        ? () {
                            // ✅ NEW: Get fresh context at tap time
                            final BuildContext btnContext = context;
                            
                            // Get current page index
                            final currentPage = _pageController.page?.round() ?? 0;
                            final offsetDays = currentPage - _centerPage;
                            
                            // Calculate current Kemetic date directly from PageController
                            final currentGreg = _initialGregorian.add(Duration(days: offsetDays));
                            final currentKemetic = KemeticMath.fromGregorian(currentGreg);
                            
                            // Log for debugging
                            if (kDebugMode) {
                              print('➕ ADD NOTE BUTTON TAPPED (from Day View)');
                              print('   Context valid: ${btnContext.mounted}');
                            }
                            
                            // Call the callback directly
                            widget.onAddNote!(
                              currentKemetic.kYear,
                              currentKemetic.kMonth,
                              currentKemetic.kDay,
                            );
                          }
                        : null, // Disabled if no callback
                  ),
                  // Today button
                  TextButton(
                    onPressed: () async {
                      if (!_pageController.hasClients) return;

                      final t = KemeticMath.fromGregorian(DateTime.now());
                      final g = KemeticMath.toGregorian(t.kYear, t.kMonth, t.kDay);
                      final offsetDays = g.difference(_initialGregorian).inDays;
                      final targetPage = _centerPage + offsetDays;

                      _isJumpingToToday = true;

                      await _pageController.animateToPage(
                        targetPage, duration: const Duration(milliseconds: 280), curve: Curves.easeOut,
                      );

                      setState(() {
                        _currentKy = t.kYear;
                        _currentKm = t.kMonth;
                        _currentKd = t.kDay;
                      });

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollMiniCalendarToCenter(_currentKd);
                        _isJumpingToToday = false;
                      });
                    },
                    child: const Text(
                      'Today',
                      style: TextStyle(
                        color: Color(0xFFFFC145),
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 🔧 FIXED: Mini calendar now uses persistent controller (smaller size, closer spacing)
            SizedBox(
              height: 32, // Reduced from 40
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: dayCount,
                // Auto-scroll to keep current day visible and centered
                controller: _miniCalendarScrollController, // 🔧 Use persistent controller
                itemBuilder: (context, index) {
                  final day = index + 1;
                  final isCurrentDay = day == _currentKd;
                  final isToday = today.kYear == _currentKy && 
                                 today.kMonth == _currentKm && 
                                 today.kDay == day;
                  
                  return GestureDetector(
                    onTap: () {
                      final currentGregorian = KemeticMath.toGregorian(_currentKy, _currentKm, _currentKd);
                      final targetGregorian = KemeticMath.toGregorian(_currentKy, _currentKm, day);
                      final offsetDays = targetGregorian.difference(currentGregorian).inDays;
                      final targetPage = _pageController.page!.round() + offsetDays;
                      
                      _pageController.animateToPage(
                        targetPage,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                    child: Container(
                      width: 30, // Reduced from 36
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: isCurrentDay
                          ? Border.all(color: const Color(0xFFFFC145), width: 1.5)
                          : null,
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            color: isToday 
                              ? const Color(0xFFFFC145)
                              : (isCurrentDay 
                                ? const Color(0xFFAAAAAA)
                                : Colors.white54),
                            fontSize: 14, // Reduced from 16
                            fontWeight: isCurrentDay || isToday 
                              ? FontWeight.w600 
                              : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 8), // Reduced from 12
            
            // 🔧 FIX 1: Full date with GREGORIAN year - WITH KEMETIC DAY INFO
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              alignment: Alignment.center,
              child: KemeticDayButton(
                dayKey: _getKemeticDayKey(_currentKy, _currentKm, _currentKd),
                child: Text(
                  // Show: "Renwet 2, 2025" (Kemetic date + Gregorian year)
                  '${monthName.split(' ').first} $_currentKd, $gregorianYear',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            
            const Divider(height: 1, color: Color(0xFF1A1A1A)),
          ],
        ),
      ),
    );
  }

  String _formatGregorianDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  String _getGregorianMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}

// ========================================
// DAY VIEW GRID (Timeline view)
// ========================================

class DayViewGrid extends StatefulWidget {
  final int ky;
  final int km;
  final int kd;
  final List<NoteData> notes;
  final bool showGregorian;
  final Map<int, FlowData> flowIndex;
  final double? initialScrollOffset;              // 🔧 NEW
  final void Function(double offset)? onScrollChanged; // 🔧 NEW
  final void Function(int? flowId)? onManageFlows; // NEW
  final void Function(int ky, int km, int kd)? onAddNote;

  const DayViewGrid({
    super.key,
    required this.ky,
    required this.km,
    required this.kd,
    required this.notes,
    required this.showGregorian,
    required this.flowIndex,
    this.initialScrollOffset,     // 🔧 NEW
    this.onScrollChanged,          // 🔧 NEW
    this.onManageFlows, // NEW
    this.onAddNote, // 🔧 NEW
  });

  @override
  State<DayViewGrid> createState() => _DayViewGridState();
}

class _DayViewGridState extends State<DayViewGrid> {
  final ScrollController _scrollController = ScrollController();
  
  // 🔧 OPTIMIZATION: Cache layout results
  List<PositionedEventBlock>? _cachedBlocks;
  int? _cachedNotesHash;
  bool _hasScrolledToInitial = false; // Added for scroll persistence

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll); // Added listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSavedOrCurrentTime(); // Renamed method
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll); // Removed listener
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients && widget.onScrollChanged != null) {
      widget.onScrollChanged!(_scrollController.offset);
    }
  }

  void _scrollToSavedOrCurrentTime() {
    if (!_scrollController.hasClients) return;
    
    if (widget.initialScrollOffset != null && !_hasScrolledToInitial) {
      // Scroll to saved position
      _scrollController.jumpTo(widget.initialScrollOffset!);
      _hasScrolledToInitial = true;
    } else if (widget.initialScrollOffset == null) {
      // Auto-scroll to current time
      final now = DateTime.now();
      final minutesSinceMidnight = now.hour * 60 + now.minute;
      const hourHeight = 60.0;
      final targetOffset = (minutesSinceMidnight / 60) * hourHeight - 200; // 200px above current time
      
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
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
        // For timed events, normalize to ISO string for minute precision
        if (note.start != null && note.end != null) {
          // Convert to minutes since midnight for comparison
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

  int _computeNotesHash(List<NoteData> notes) {
    return Object.hashAll(notes.map((n) => Object.hash(
      n.title,
      n.detail,
      n.location,
      n.allDay,
      n.start?.hour,
      n.start?.minute,
      n.end?.hour,
      n.end?.minute,
      n.flowId,
    )));
  }

  @override
  Widget build(BuildContext context) {
    // ✅ NEW: Dedupe notes before rendering to handle legacy duplicates
    final dedupedNotes = _dedupeNotesForUI(widget.notes);
    
    // 🔧 OPTIMIZATION: Only recalculate layout if notes changed
    final notesHash = _computeNotesHash(dedupedNotes);
    if (_cachedBlocks == null || _cachedNotesHash != notesHash) {
      final screenWidth = MediaQuery.of(context).size.width;
      final columnWidth = (screenWidth - 100) / 3; // 3 columns max
      
      if (kDebugMode) {
        final originalCount = widget.notes.length;
        final dedupedCount = dedupedNotes.length;
        if (originalCount != dedupedCount) {
          print('[DayView] Deduplicated events: $originalCount → $dedupedCount (removed ${originalCount - dedupedCount} duplicates)');
        }
      }
      
      _cachedBlocks = EventLayoutEngine.layoutEventsForDay(
        notes: dedupedNotes, // ✅ Use deduped notes
        flowIndex: widget.flowIndex,
        columnWidth: columnWidth,
        columnGap: 4.0,
        day: widget.kd,
      );
      _cachedNotesHash = notesHash;
    }

    return Column(
      children: [
        // Gregorian date header (if enabled)
        if (widget.showGregorian) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF0D0D0F),
            child: Text(
              _formatGregorianDate(KemeticMath.toGregorian(widget.ky, widget.km, widget.kd)),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF808080),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        
        // Timeline grid
        Expanded(
          child: ListView.builder(
            clipBehavior: Clip.none,
            controller: _scrollController,
            cacheExtent: 600, // 🔧 OPTIMIZATION: Cache more items
            itemCount: 24,
            itemBuilder: (context, hour) {
              return _buildHourRow(hour);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHourRow(int hour) {
    final hourBlocks = _cachedBlocks?.where((b) => 
      b.event.startMin >= hour * 60 && b.event.startMin < (hour + 1) * 60
    ).toList() ?? [];

    return Container(
      height: 60,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF1A1A1A),
            width: 0.5,
          ),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none, // allow events to span into next hour
        children: [
          // Hour label
          Positioned(
            left: 8,
            top: 4,
            child: Text(
              _formatHour(hour),
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF808080),
              ),
            ),
          ),
          
          // Event blocks
          ...hourBlocks.map((block) {
            final minutesIntoHour = block.event.startMin % 60;
            return Positioned(
              left: 60 + block.leftOffset,
              top: minutesIntoHour.toDouble(),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque, // ✅ full-rect hit target (not just text)
                onTap: () => _showEventDetail(block.event),
                child: _buildEventBlock(block),
              ),
            );
          }),
          
          // Current time indicator (only on today)
          if (_isToday() && _isCurrentHour(hour)) _buildNowLine(),
        ],
      ),
    );
  }

  Widget _buildEventBlock(PositionedEventBlock block) {
    final event = block.event;
    
    // 🔍 DEBUG: Log block being rendered
    if (kDebugMode && event.flowId != null) {
      print('[_buildEventBlock] Rendering: title="${event.title}", flowId=${event.flowId}');
    }
    
    // ✅ FIX #2A: Calculate and clamp duration to prevent giant blocks
    int durationMinutes = event.endMin - event.startMin;
    
    // Fix garbage durations:
    // - if negative or zero -> minimum 15 min just so it's tappable
    if (durationMinutes <= 0) {
      durationMinutes = 15;
    }
    
    // - if way too long (overnight / malformed) -> cap at 180 min (3h) visually
    if (durationMinutes > 180) {
      durationMinutes = 180;
    }
    
    return Container(
      width: block.width,
      height: durationMinutes.toDouble(),
      margin: const EdgeInsets.only(right: 4, bottom: 2),
      decoration: BoxDecoration(
        color: event.color.withOpacity(0.2),
        border: Border(
          left: BorderSide(color: event.color, width: 3),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(4),
      child: _buildEventTextContents(event, durationMinutes),
    );
  }

  /// ✅ FIX #2B: Separate method for text content with empty title handling
  Widget _buildEventTextContents(EventItem event, int durationMinutes) {
    final flow = widget.flowIndex[event.flowId];
    final bool hasFlow = flow != null;
    
    final showTitle = event.title.trim().isNotEmpty;
    final showLocation = event.location != null &&
        event.location!.trim().isNotEmpty &&
        durationMinutes > 45;
    
    return Column(
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
            event.title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            maxLines: hasFlow ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          )
        else
          Text(
            // Fallback so you don't get giant red nothing-brick
            hasFlow ? '(flow block)' : '(scheduled)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.white70,
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
                color: Colors.white.withOpacity(0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Widget _buildNowLine() {
    final now = DateTime.now();
    final minutesIntoHour = now.minute.toDouble();
    
    // Calculate the hour row position (60px per hour)
    final currentHour = now.hour;
    final topPosition = (currentHour * 60.0) + minutesIntoHour;
    
    return Positioned(
      left: 0,
      right: 0,
      top: topPosition,
      child: Container(
        height: 2, // Made slightly thicker for visibility
        color: Colors.red,
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Container(
                height: 2,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isCurrentHour(int hour) {
    final now = DateTime.now();
    return now.hour == hour;
  }

  bool _isToday() {
    final now = DateTime.now();
    final todayK = KemeticMath.fromGregorian(now);
    return widget.ky == todayK.kYear &&
           widget.km == todayK.kMonth &&
           widget.kd == todayK.kDay;
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  String _formatGregorianDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  // Show event detail sheet
  void _showEventDetail(EventItem event) {
    final flow = widget.flowIndex[event.flowId];
    
    // 🔍 DEBUG: Comprehensive logging
    if (kDebugMode) {
      print('[_showEventDetail] Event: "${event.title}"');
      print('[_showEventDetail] Event flowId: ${event.flowId} (${event.flowId.runtimeType})');
      print('[_showEventDetail] Event color: ${event.color}');
      print('[_showEventDetail] FlowIndex keys: ${widget.flowIndex.keys.toList()}');
      print('[_showEventDetail] FlowIndex length: ${widget.flowIndex.length}');
      
      if (event.flowId != null) {
        final foundFlow = widget.flowIndex[event.flowId];
        if (foundFlow != null) {
          print('[_showEventDetail] ✅ Flow found: ID=${foundFlow.id}, name="${foundFlow.name}", color=${foundFlow.color}, active=${foundFlow.active}');
        } else {
          print('[_showEventDetail] ❌ Flow NOT found for flowId=${event.flowId}');
          print('[_showEventDetail] Available flow IDs: ${widget.flowIndex.keys.toList()}');
        }
      } else {
        print('[_showEventDetail] Event has no flowId');
      }
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF000000),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with flow badge and menu
              // Check if this is a nutrition event (detail contains "Source:" pattern)
              if (flow == null && event.detail != null && event.detail!.contains('Source:')) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_drink, size: 14, color: Color(0xFFD4AF37)),
                          SizedBox(width: 4),
                          Text(
                            'Nutrition',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFD4AF37),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (flow != null) ...[
                Row(
                  children: [
                    // Flow name badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: flow.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
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
              
              // Note title
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
              Builder(
                builder: (context) {
                  // Strip legacy flowLocalId prefix if present
                  String displayDetail = event.detail!;
                  if (displayDetail.startsWith('flowLocalId=')) {
                    final semi = displayDetail.indexOf(';');
                    if (semi > 0 && semi < displayDetail.length - 1) {
                      displayDetail = displayDetail.substring(semi + 1).trim();
                    } else {
                      // Only the prefix, no actual detail
                      return const SizedBox.shrink();
                    }
                  }
                  
                  // Only show if there's actual content after stripping
                  if (displayDetail.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  
                  return Text(
                    displayDetail,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ],
              
              const SizedBox(height: 20),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: widget.onManageFlows == null ? null : () {
                      Navigator.pop(context); // Close the detail sheet
                      widget.onManageFlows!(null); // Navigate to My Flows
                    },
                    icon: Icon(
                      Icons.view_timeline, 
                      color: widget.onManageFlows == null 
                        ? Color(0xFF404040) 
                        : Color(0xFFFFC145), // Gold when enabled
                    ),
                    label: Text(
                      'Manage Flows',
                      style: TextStyle(
                        color: widget.onManageFlows == null 
                          ? Color(0xFF404040) 
                          : Color(0xFFFFC145), // Gold when enabled
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: Color(0xFFFFC145)), // Gold
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

// Day View - 24-hour timeline with pixel-perfect event layout
// Uses EventLayoutEngine for consistent positioning
//

