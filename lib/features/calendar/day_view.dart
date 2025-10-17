// lib/features/calendar/day_view.dart
// 
// Day View - 24-hour timeline with pixel-perfect event layout
// Uses EventLayoutEngine for consistent positioning
//

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'calendar_page.dart';

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
  final VoidCallback? onManageFlows; // NEW: Callback to open My Flows

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

  @override
  void initState() {
    super.initState();
    _currentKy = widget.initialKy;
    _currentKm = widget.initialKm;
    _currentKd = widget.initialKd;
    _initialGregorian = KemeticMath.toGregorian(_currentKy, _currentKm, _currentKd);
    _pageController = PageController(initialPage: _centerPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
  }

  void _onScrollChanged(double offset) {
    _savedScrollOffset = offset;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000), // True black
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFFFFC145)), // Gold
          onPressed: () => Navigator.pop(context),
        ),
        title: _buildDayHeader(),
        actions: [
          // Today button
          TextButton(
            onPressed: () {
              // Get today's date in BOTH calendars
              final nowG = DateTime.now();
              final todayGregorian = DateTime(nowG.year, nowG.month, nowG.day); // Date only
              final today = KemeticMath.fromGregorian(todayGregorian);
              
              // Calculate offset using GREGORIAN ARITHMETIC (same as _dateForPage)
              // _dateForPage does: _initialGregorian.add(Duration(days: offset))
              // So reverse that: offset = (today - _initialGregorian) in days
              final offsetDays = todayGregorian.difference(_initialGregorian).inDays;
              final targetPage = _centerPage + offsetDays;
              
              // Jump to that page
              _pageController.jumpToPage(targetPage);
              
              // Update state to reflect today
              setState(() {
                _currentKy = today.kYear;
                _currentKm = today.kMonth;
                _currentKd = today.kDay;
                // DON'T update _initialGregorian - that's our anchor point!
                // If we change it, all the other pages will shift too
              });
            },
            child: const Text(
              'Today',
              style: TextStyle(color: Color(0xFFFFC145)), // Gold
            ),
          ),
        ],
      ),
      body: PageView.builder(
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

  String _formatGregorianDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
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
  final VoidCallback? onManageFlows; // NEW

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

  int _computeNotesHash() {
    return Object.hashAll(widget.notes.map((n) => Object.hash(
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
    // 🔧 OPTIMIZATION: Only recalculate layout if notes changed
    final notesHash = _computeNotesHash();
    if (_cachedBlocks == null || _cachedNotesHash != notesHash) {
      final screenWidth = MediaQuery.of(context).size.width;
      final columnWidth = (screenWidth - 100) / 3; // 3 columns max
      
      _cachedBlocks = EventLayoutEngine.layoutEventsForDay(
        notes: widget.notes,
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
    
    final durationMinutes = event.endMin - event.startMin;
    
    // 🔧 NEW: Look up flow name to display in the block
    final flow = widget.flowIndex[event.flowId];
    final bool hasFlow = flow != null;
    
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔧 NEW: Show flow name first if available
          if (hasFlow) ...[
            Text(
              flow!.name,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: event.color,  // Use flow color for name
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
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            maxLines: hasFlow ? 1 : 2,  // Less space if flow name shown
            overflow: TextOverflow.ellipsis,
          ),
          
          // Location (if space allows)
          if (event.location != null && event.location!.isNotEmpty && durationMinutes > 45)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                event.location!,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
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
      backgroundColor: const Color(0xFF0D0D0F),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Flow name badge
              if (flow != null) ...[
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
                      widget.onManageFlows!(); // Navigate to My Flows
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
