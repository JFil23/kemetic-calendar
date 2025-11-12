import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';   // LogicalKeyboardKey

import '../../core/kemetic_converter.dart';
import '../../data/nutrition_repo.dart';
import '../../data/user_events_repo.dart';
import '../../features/calendar/notify.dart';

/// A widget that displays and edits a table of nutrition items. Each row
/// corresponds to a [NutritionItem] and can be edited inline. The "When
/// to take" column opens a bottom sheet picker for editing the
/// [IntakeSchedule]. When rows change their schedule or are deleted, the
/// associated calendar events are updated via [UserEventsRepo].
class NutritionGridWidget extends StatefulWidget {
  final NutritionRepo repo;
  final UserEventsRepo eventsRepo;

  const NutritionGridWidget({Key? key, required this.repo, required this.eventsRepo}) : super(key: key);

  @override
  State<NutritionGridWidget> createState() => _NutritionGridWidgetState();
}

class _NutritionGridWidgetState extends State<NutritionGridWidget> {
  final Map<String, Timer> _debouncers = {};
  final Map<String, bool> _scheduleChanged = {};
  late bool _loading;
  List<NutritionItem> _items = [];
  String? _lastError;
  bool _adding = false; // prevents double-clicks while inserting
  bool _schedulePickerOpen = false; // prevents double-open from rapid taps

  // Column widths for header and body alignment (fixed widths for perfect alignment)
  static const double _rowHeight = 48;
  static const TextStyle _hdrStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.w600);
  static const TextStyle _cellStyle = TextStyle(color: Colors.white);

  // Typography (use with existing _hdrStyle/_cellStyle)
  static const double _hdrFontSize = 14;
  static const double _cellFontSize = 13;

  // Focus-based expansion constants
  static const int _expandedRowFactor = 5;
  static const double _whenIconSize = 20;

  // Focus state for row expansion
  String? _focusedRowId;
  final Map<String, FocusNode> _focusByCell = {};

  FocusNode _focusFor(String cellId) {
    return _focusByCell.putIfAbsent(cellId, () {
      final n = FocusNode();
      n.addListener(() {
        if (!mounted) return;
        final row = cellId.split(':').first;

        // Defer setState to after the current frame
        void _defer(VoidCallback f) =>
            WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) f(); });

        if (n.hasFocus) {
          if (_focusedRowId != row) _defer(() => setState(() => _focusedRowId = row));
        } else if (_focusedRowId == row) {
          final stillFocused = _focusByCell.entries.any(
            (e) => e.key.startsWith('$row:') && e.value.hasFocus,
          );
          if (!stillFocused) _defer(() => setState(() => _focusedRowId = null));
        }
      });
      return n;
    });
  }

  bool _isFocusedRow(String rowId) => _focusedRowId == rowId;

  double _expandedRowHeight(BuildContext context) {
    final cap = MediaQuery.of(context).size.height * 0.60;
    final target = _rowHeight * _expandedRowFactor;
    return target > cap ? cap : target;
  }

  // Row expand/collapse state (track by item.id) - kept for backward compatibility
  final Set<String> _expanded = <String>{};
  bool _isExpanded(NutritionItem it) => _expanded.contains(it.id);
  void _toggleExpanded(NutritionItem it) => setState(() {
    if (_expanded.contains(it.id)) {
      _expanded.remove(it.id);
    } else {
      _expanded.add(it.id);
    }
  });

  // Base & minimum widths for: Nutrient, Source, Purpose, When, Repeat, Delete
  static const List<double> _COL_BASE = [160, 140, 200, 190, 64, 48];
  static const List<double> _COL_MIN  = [110, 110, 150, 150, 56, 48];

  // New responsive width constants (for fractional approach)
  // Base widths (px) tuned for phone modal. Order: Nutrient, Source, Purpose, When, Repeat, Delete
  static const List<double> _BASE_WIDTHS = [160, 140, 200, 190, 64, 48];
  // Minimum clamped widths (px) before we give up and enable horizontal scroll
  static const List<double> _MIN_WIDTHS  = [110, 110, 150, 150, 56, 48];
  // Indices to shrink first when space is tight (Purpose, When)
  static const List<int> _FLEX_PRIORITY  = [2, 3, 0, 1]; // then Nutrient/Source if needed

  final Map<int, TableColumnWidth> _colWidths = const {
    0: FixedColumnWidth(180), // Nutrient
    1: FixedColumnWidth(160), // Source
    2: FixedColumnWidth(220), // Purpose
    3: FixedColumnWidth(220), // When to take
    4: FixedColumnWidth(68),  // Repeat
    5: FixedColumnWidth(48),  // Delete
  };

  TableBorder _gridBorder() => const TableBorder(
        top: BorderSide(color: Colors.white12, width: 1),
        bottom: BorderSide(color: Colors.white12, width: 1),
        left: BorderSide(color: Colors.white12, width: 1),
        right: BorderSide(color: Colors.white12, width: 1),
        horizontalInside: BorderSide(color: Colors.white12, width: 1),
        verticalInside: BorderSide(color: Colors.white12, width: 1),
      );

  // Column width calculator for responsive layout
  List<double> _computeNutritionColumnWidths(double available) {
    // total base and min
    final baseTotal = _COL_BASE.fold<double>(0, (a, b) => a + b);
    final minTotal  = _COL_MIN.fold<double>(0, (a, b) => a + b);

    // If the base fits, use base
    if (baseTotal <= available) return List<double>.from(_COL_BASE);

    // If even minimum doesn't fit, we'll still return minimums;
    // the caller will enable horizontal scroll fallback.
    if (minTotal >= available) return List<double>.from(_COL_MIN);

    // Otherwise, shrink proportionally toward MIN, prioritizing flexible columns:
    // We'll shrink Purpose (2) and When (3) first, then Nutrient (0) & Source (1) if needed.
    final widths = List<double>.from(_COL_BASE);

    double toShrink = baseTotal - available;
    // helpers
    double shrinkOne(int i, double want) {
      final can = widths[i] - _COL_MIN[i];
      final take = math.min(can, want);
      widths[i] -= take;
      return want - take;
    }

    // priority order: Purpose, When, Nutrient, Source
    for (final idx in [2, 3, 0, 1]) {
      if (toShrink <= 0) break;
      toShrink = shrinkOne(idx, toShrink);
    }
    // Repeat (4) and Delete (5) are fixed at MIN already

    return widths;
  }

  // New responsive width calculator with expansion logic
  List<double> _computeNutritionColWidths(double available) {
    final base = List<double>.from(_BASE_WIDTHS);
    final min  = _MIN_WIDTHS;
    double total = base.reduce((a, b) => a + b);

    if (total <= available) {
      // Mild proportional expansion to fill small remaining space (up to +8%)
      final extra = (available - total).clamp(0, available * 0.08);
      if (extra > 0) {
        // Expand the more readable columns a bit (Purpose, When, Nutrient)
        const grow = [2, 3, 0];
        final per = extra / grow.length;
        for (final i in grow) base[i] += per;
      }
      return base;
    }

    // Need to shrink. Take from flexible columns first down to their mins.
    double need = total - available;
    for (final idx in _FLEX_PRIORITY) {
      if (need <= 0) break;
      final spare = base[idx] - min[idx];
      if (spare <= 0) continue;
      final take = spare >= need ? need : spare;
      base[idx] -= take;
      need -= take;
    }

    // If still too big after hitting mins everywhere, we'll let the caller wrap with horizontal scroll
    return base;
  }

  @override
  void initState() {
    super.initState();
    _loading = true;
    _loadItems();
  }

  Future<void> _loadItems() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _lastError = null;
    });
    try {
      debugPrint('[NutritionGrid] Loading items…');
      final items = await widget.repo.getAll().timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _lastError = null;
      });
      debugPrint('[NutritionGrid] Loaded ${items.length} items');
    } on TimeoutException catch (e) {
      debugPrint('[NutritionGrid] Timeout: $e');
      if (!mounted) return;
      setState(() {
        _items = [];
        _loading = false;
        _lastError = 'Request timed out. Check your connection.';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request timed out. Check your connection.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('[NutritionGrid] Error: $e');
      debugPrint('[NutritionGrid] Error type: ${e.runtimeType}');
      debugPrint('[NutritionGrid] Stack: $st');
      if (!mounted) return;
      setState(() {
        _items = [];
        _loading = false;
        _lastError = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading nutrition items: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final t in _debouncers.values) {
      t.cancel();
    }
    for (final n in _focusByCell.values) {
      n.dispose();
    }
    _focusByCell.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_lastError != null) {
      return _ErrorState(
        message: _lastError!,
        onRetry: _loadItems,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _adding ? null : _addNewItem,
            icon: const Icon(Icons.add),
            label: const Text('Add nutrient'),
          ),
        ),
        Expanded(child: buildNutritionTableResponsive()),
      ],
    );
  }

  // === HEADER ===
  Widget _headerCell(String text, {double? width, IconData? icon}) {
    return _cellShell(
      icon != null
          ? Icon(icon, size: 16, color: Colors.white)
          : Text(
              text,
              style: _hdrStyle.copyWith(fontSize: _hdrFontSize),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
      width: width,
      minHeight: 44,
      align: Alignment.centerLeft,
    );
  }

  Widget _buildHeaderTable() {
    return Table(
      columnWidths: _colWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: _gridBorder(),
      children: [
        TableRow(
          children: [
            _headerCell('Nutrient'),
            _headerCell('Source'),
            _headerCell('Purpose'),
            _headerCell('When to take'),
            _headerCell('Repeat'),
            _headerCell(''), // Delete column (no header text)
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderTableWithWidths(List<double> widths) {
    final colWidths = <int, TableColumnWidth>{
      for (var i = 0; i < widths.length; i++) i: FixedColumnWidth(widths[i]),
    };
    return Table(
      columnWidths: colWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: _gridBorder(),
      children: [
        TableRow(
          children: [
            _headerCell('Nutrient',     width: widths[0]),
            _headerCell('Source',       width: widths[1]),
            _headerCell('Purpose',      width: widths[2]),
            _headerCell('When to take', width: widths[3]),
            _headerCell('Repeat',       width: widths[4]),
            _headerCell('',             width: widths[5]), // delete header blank
          ],
        ),
      ],
    );
  }

  // === BODY ===
  Widget _buildBodyTable(List<NutritionItem> items) {
    return Table(
      columnWidths: _colWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: _gridBorder(),
      children: [for (final it in items) _buildRow(it)],
    );
  }

  Widget _buildBodyTableWithWidths(List<NutritionItem> items, List<double> widths) {
    final colWidths = <int, TableColumnWidth>{
      for (var i = 0; i < widths.length; i++) i: FixedColumnWidth(widths[i]),
    };
    return Table(
      columnWidths: colWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: _gridBorder(),
      children: [for (final it in items) _buildRowWithWidths(it, widths)],
    );
  }

  TableRow _buildRow(NutritionItem item) {
    return TableRow(
      children: [
        _cellTextField(item, field: 'nutrient', hint: 'e.g., Magnesium'),
        _cellTextField(item, field: 'source', hint: 'e.g., 200mg caps'),
        _cellTextField(item, field: 'purpose', hint: 'e.g., sleep, recovery', maxLines: 2),
        _cellSchedule(item),
        _cellRepeat(item),
        _cellDelete(item),
      ],
    );
  }

  TableRow _buildRowWithWidths(NutritionItem item, List<double> w) {
    return TableRow(
      children: [
        _cellTextField(item, field: 'nutrient', hint: 'e.g., Magnesium',           width: w[0]),
        _cellTextField(item, field: 'source',   hint: 'e.g., 200mg caps',          width: w[1]),
        _cellTextField(item, field: 'purpose',  hint: 'e.g., sleep, recovery',     width: w[2], maxLines: 2),
        _cellSchedule(item, width: w[3]),
        _cellRepeat(item,   width: w[4]),
        _cellDelete(item,   width: w[5]),
      ],
    );
  }

  // ---------- NEW RESPONSIVE TABLE METHODS ----------
  // Column weights (sum = 1.0)  [Nutrient, Source, Purpose, When] - 4 columns
  static const List<double> _FRACTIONS = [0.30, 0.24, 0.35, 0.11];

  // Row background color for zebra striping
  Color _rowBg(int i) => i.isOdd ? Colors.white.withOpacity(0.03) : Colors.transparent;

  // Public entry point for responsive table (uses _items field)
  Widget buildNutritionTableResponsive() {
    final widths = <int, TableColumnWidth>{
      0: const FlexColumnWidth(0.30),
      1: const FlexColumnWidth(0.24),
      2: const FlexColumnWidth(0.35),
      3: const FlexColumnWidth(0.11), // icon
    };

    return Column(
      children: [
        Table(
          border: _gridBorder(),
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          columnWidths: widths,
          children: [_headerRow()],
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Table(
              border: _gridBorder(),
              defaultVerticalAlignment: TableCellVerticalAlignment.top,
              columnWidths: widths,
              children: [
                for (int i = 0; i < _items.length; i++)
                  _buildRowFractional(i, _items[i], bg: _rowBg(i)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Header row (4 columns: Nutrient, Source, Purpose, When)
  TableRow _headerRow() {
    return TableRow(children: [
      _cellShell(Text('Nutrient', style: _hdrStyle.copyWith(fontSize: _hdrFontSize))),
      _cellShell(Text('Source', style: _hdrStyle.copyWith(fontSize: _hdrFontSize))),
      _cellShell(Text('Purpose', style: _hdrStyle.copyWith(fontSize: _hdrFontSize))),
      _cellShell(
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: const Icon(Icons.event_note_rounded, size: _whenIconSize, color: Colors.white),
          ),
        ),
        align: Alignment.center,
        padding: EdgeInsets.zero,  // no padding for icon column
      ),
    ]);
  }

  // Header table with fractional widths (legacy - kept for compatibility)
  Widget _buildHeaderTableFractional(Map<int, TableColumnWidth> widths) {
    return Table(
      border: _gridBorder(),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: widths,
      children: [_headerRow()],
    );
  }

  // Body table with fractional widths (legacy method - not used by new responsive table)
  Widget _buildBodyTableFractional(List<double> widths, List<NutritionItem> items) {
    Color rowBg(int i) => i.isEven ? const Color(0xFF0D0D0D) : const Color(0xFF111111);
    return Table(
      columnWidths: {
        for (int i = 0; i < widths.length; i++) i: FixedColumnWidth(widths[i]),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: _gridBorder(),
      children: [
        for (int i = 0; i < items.length; i++)
          _buildRowFractional(i, items[i], bg: rowBg(i)),
      ],
    );
  }

  // Row builder (uses FlexColumnWidth, so no pixel widths needed)
  TableRow _buildRowFractional(int index, NutritionItem item, {Color? bg}) {
    final focused = _isFocusedRow(item.id);
    final minH = focused ? _expandedRowHeight(context) : _rowHeight;
    final bgCol = bg ?? _rowBg(index);

    return TableRow(children: [
      _cellTextField(item, field: 'nutrient', hint: 'e.g., Magnesium', rowId: item.id, bgColor: bgCol, maxLines: 1),
      _cellTextField(item, field: 'source', hint: 'e.g., Glycinate', rowId: item.id, bgColor: bgCol, maxLines: 1),
      // Purpose: wraps when focused; otherwise compact
      _cellTextField(item, field: 'purpose', hint: 'Why you take it', rowId: item.id, bgColor: bgCol, maxLines: focused ? null : 2, minHeight: minH),
      _cellSchedule(item, bgColor: bgCol, minHeight: minH),
    ]);
  }

  // === CELLS ===
  Widget _cellShell(
    Widget child, {
    Alignment align = Alignment.centerLeft,
    double? width,
    double? minHeight,
    Color? bgColor,  // null => transparent (no charcoal)
    EdgeInsets? padding,  // optional padding override
  }) {
    final core = Container(
      width: width,
      alignment: align,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 10),
      color: bgColor,  // null => transparent (no charcoal)
      constraints: (minHeight == null)
          ? const BoxConstraints()
          : BoxConstraints(minHeight: minHeight),
      child: child,
    );
    return AnimatedSize(
      duration: const Duration(milliseconds: 160),
      alignment: Alignment.topCenter,
      child: DefaultTextStyle.merge(
        style: TextStyle(fontSize: _cellFontSize),
        child: core,
      ),
    );
  }

  Widget _cellTextField(
    NutritionItem item, {
    required String field,
    String? hint,
    int? maxLines = 1,
    double? width,
    String? rowId,
    double? minHeight,
    Color? bgColor,
  }) {
    final id = rowId ?? item.id;
    final focused = _isFocusedRow(id);
    final lines = focused ? null : (maxLines ?? 1);

    final initial = switch (field) {
      'nutrient' => item.nutrient,
      'source'   => item.source,
      'purpose'  => item.purpose,
      _ => '',
    };

    final editor = TextFormField(
      initialValue: initial,
      focusNode: _focusFor('$id:$field'),
      style: _cellStyle.copyWith(fontSize: _hdrFontSize),
      maxLines: lines,
      expands: focused,  // scrolls inside when focused
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textAlignVertical: focused ? TextAlignVertical.top : TextAlignVertical.center,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
      ),
      onChanged: (txt) {
        switch (field) {
          case 'nutrient': item.nutrient = txt; break;
          case 'source':   item.source   = txt; break;
          case 'purpose':  item.purpose  = txt; break;
        }
        _saveDebounced(item, resync: false); // text-only changes
      },
    );

    final h = focused ? (minHeight ?? _expandedRowHeight(context)) : (minHeight ?? _rowHeight);
    final wrapped = focused ? SizedBox(height: h, child: editor) : editor;
    return _cellShell(wrapped, width: width, minHeight: focused ? null : h, bgColor: bgColor);
  }

  String _scheduleLabel(BuildContext context, IntakeSchedule s) {
    final t = s.time.format(context);
    if (s.mode == IntakeMode.weekday) {
      if (s.daysOfWeek.isEmpty) return '';
      const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final sel = s.daysOfWeek.map((d) => w[(d - 1).clamp(0, 6)]).join(', ');
      return '$sel • $t${s.repeat ? '' : ' (once)'}';
    } else {
      if (s.decanDays.isEmpty) return '';
      final sel = s.decanDays.map((d) => 'Day $d').join(', ');
      return 'Decan: $sel • $t${s.repeat ? '' : ' (once)'}';
    }
  }

  // Helpers for compact schedule preview chips
  String _dowShort(int d) => const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d - 1];

  Widget _chip(String t, {IconData? icon}) {
    return Container(
      margin: const EdgeInsets.only(right: 6, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12),
            const SizedBox(width: 4),
          ],
          Text(t, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  // Compact schedule preview text (no chips)
  String _schedulePreviewText(BuildContext context, IntakeSchedule s) {
    final daysText = (s.mode == IntakeMode.weekday)
        ? (s.daysOfWeek.isEmpty
            ? 'Tap to set'
            : s.daysOfWeek.map(_dowShort).join(' '))
        : (s.decanDays.isEmpty
            ? 'Tap to set'
            : 'Days ${s.decanDays.join(', ')}');
    return '$daysText • ${s.time.format(context)}';
  }

  Widget _cellSchedule(
    NutritionItem item, {
    double? width,
    double? minHeight,
    bool? collapsed,  // kept for back-compat; unused
    Color? bgColor,
  }) {
    final focused = _isFocusedRow(item.id);
    final h = focused ? (minHeight ?? _expandedRowHeight(context)) : (minHeight ?? _rowHeight);
    final tip = _schedulePreviewText(context, item.schedule);

    return _cellShell(
      Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              tooltip: tip,
              icon: const Icon(Icons.event_note_rounded, size: _whenIconSize, color: Colors.white),
              padding: EdgeInsets.zero,  // Remove default padding
              constraints: const BoxConstraints(),  // Remove default 48x48 constraint
              splashRadius: 18,  // slightly larger than icon for better touch feedback
              onPressed: () async {
                FocusScope.of(context).unfocus();
                final updated = await _openSchedulePicker(context, item);
                if (updated != null) {
                  setState(() {
                    item.schedule = updated;
                    item.enabled = (updated.mode == IntakeMode.weekday && updated.daysOfWeek.isNotEmpty) ||
                                   (updated.mode == IntakeMode.decan && updated.decanDays.isNotEmpty);
                    _scheduleChanged[item.id] = true;
                  });
                  _saveDebounced(item, resync: true);
                }
              },
            ),
          ),
        ),
      ),
      width: width,
      minHeight: h,
      bgColor: bgColor,
      align: Alignment.center,
      padding: EdgeInsets.zero,  // no padding for icon column
    );
  }

  Widget _cellRepeat(NutritionItem item, {double? width}) {
    return _cellShell(
      Center(
        child: Checkbox(
          value: item.schedule.repeat,
          onChanged: (v) {
            setState(() {
              item.schedule = item.schedule.copyWith(repeat: v ?? true);
              _scheduleChanged[item.id] = true;
            });
            _saveDebounced(item, resync: true);
          },
          activeColor: Colors.white,
          checkColor: Colors.black,
          side: const BorderSide(color: Colors.white54, width: 1),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
      width: width,
      align: Alignment.center,
    );
  }

  Widget _cellDelete(NutritionItem item, {double? width}) {
    final show = _isExpanded(item);
    return _cellShell(
      show
          ? Center(
              child: IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                onPressed: () => _deleteItem(item),
                tooltip: 'Delete',
              ),
            )
          : const SizedBox(height: 24), // reserve minimal height
      width: width,
      align: Alignment.center,
      minHeight: 44,
    );
  }

  Future<IntakeSchedule?> _openSchedulePicker(BuildContext ctx, NutritionItem item) {
    // ✅ Hardening: Prevent double-open from rapid taps
    if (_schedulePickerOpen) return Future.value(null);
    _schedulePickerOpen = true;

    final completer = Completer<IntakeSchedule?>();
    
    void finish(IntakeSchedule? r) {
      if (!_schedulePickerOpen) return;
      _schedulePickerOpen = false;
      if (!completer.isCompleted) {
        completer.complete(r);
      }
    }

    // ✅ Null-safe initial schedule fallback
    final initial = item.schedule ?? IntakeSchedule(
      mode: IntakeMode.weekday,
      daysOfWeek: const {1,2,3,4,5}, // Mon–Fri sensible default
      decanDays: const <int>{},
      time: TimeOfDay(hour: 9, minute: 0),
      repeat: true,
    );

    // Local working state
    var mode = initial.mode;
    var dows = Set<int>.from(initial.daysOfWeek);
    var decans = Set<int>.from(initial.decanDays);
    var time = initial.time;
    var repeat = initial.repeat;

    IntakeSchedule _build() => initial.copyWith(
          mode: mode,
          daysOfWeek: dows,
          decanDays: decans,
          time: time,
          repeat: repeat,
        );

    OverlayEntry? overlayEntry;

    void _close(IntakeSchedule? result) {
      overlayEntry?.remove();
      overlayEntry = null;
      finish(result);
    }

    // ✅ Dark theme fixes so buttons/text are readable on black
    final base = Theme.of(ctx);
    final darkOverlayTheme = base.copyWith(
      colorScheme: base.colorScheme.brightness == Brightness.dark
          ? base.colorScheme
          : base.colorScheme.copyWith(brightness: Brightness.dark),
      dialogBackgroundColor: Colors.black,
      scaffoldBackgroundColor: Colors.black,
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: Colors.white),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white24),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: Colors.white,
        ),
      ),
      checkboxTheme: const CheckboxThemeData(
        side: BorderSide(color: Colors.white54),
        checkColor: WidgetStatePropertyAll(Colors.black),
        fillColor: WidgetStatePropertyAll(Colors.white),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: Colors.white70),
      ),
    );

    // ✅ Robust toast helper (handles missing Scaffold)
    void _toast(BuildContext context, String msg) {
      final sm = ScaffoldMessenger.maybeOf(context);
      sm?.showSnackBar(SnackBar(content: Text(msg)));
    }

    Widget chip(bool selected, String label, VoidCallback onTap) {
      return FilterChip(
        label: Text(
          label,
          style: TextStyle(color: selected ? Colors.black : Colors.white),
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: Colors.white,
        backgroundColor: const Color(0xFF111111),
        checkmarkColor: Colors.black,
        side: const BorderSide(color: Colors.white24),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      );
    }

    overlayEntry = OverlayEntry(
      builder: (context) {
        final mq = MediaQuery.of(context);
        final size = mq.size;
        final maxH = (size.height * 0.75).clamp(320.0, 600.0);
        final kb = mq.viewInsets.bottom;

        return Stack(
          children: [
            // ✅ Patch A: Proper modal barrier (replaces GestureDetector)
            ModalBarrier(
              color: Colors.black54,
              dismissible: true,
              onDismiss: () => _close(null),
            ),
            // Centered picker
            SafeArea(
              minimum: EdgeInsets.only(bottom: kb),
              child: Center(
                child: Theme(
                  data: darkOverlayTheme,
                  child: BackButtonListener( // ✅ Patch B: Android back button
                    onBackButtonPressed: () async { _close(null); return true; },
                    child: Shortcuts( // ✅ Patch B: ESC to close on web/desktop
                      shortcuts: {
                        LogicalKeySet(LogicalKeyboardKey.escape): const ActivateIntent(),
                      },
                      child: Actions(
                        actions: {
                          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) { _close(null); return null; }),
                        },
                        child: TweenAnimationBuilder<double>( // ✅ Patch B: Entry animation
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOut,
                          tween: Tween(begin: 0.95, end: 1.0),
                          builder: (context, scale, child) => FadeTransition(
                            opacity: AlwaysStoppedAnimation(scale.clamp(0.95, 1.0)),
                            child: Transform.scale(scale: scale, child: child),
                          ),
                          child: Material(
                            elevation: 8,
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(16),
                            clipBehavior: Clip.antiAlias,
                            child: FocusScope( // ✅ Focus trap for desktop/web
                              autofocus: true,
                              canRequestFocus: true,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: 380, maxHeight: maxH),
                                child: StatefulBuilder(
                                  builder: (context, setM) {
                                    return ScrollConfiguration( // ✅ Remove overscroll glow
                                      behavior: const ScrollBehavior().copyWith(overscroll: false),
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            // Header row: mode toggles + actions
                                            Row(
                                              children: [
                                                ChoiceChip(
                                                  label: const Text('Weekdays'),
                                                  selected: mode == IntakeMode.weekday,
                                                  onSelected: (sel) => setM(() {
                                                    mode = IntakeMode.weekday;
                                                    decans.clear();
                                                  }),
                                                ),
                                                const SizedBox(width: 8),
                                                ChoiceChip(
                                                  label: const Text('Decan Days'),
                                                  selected: mode == IntakeMode.decan,
                                                  onSelected: (sel) => setM(() {
                                                    mode = IntakeMode.decan;
                                                    dows.clear();
                                                  }),
                                                ),
                                                const Spacer(),
                                                // Delete
                                                IconButton(
                                                  tooltip: 'Delete this nutrient',
                                                  icon: const Icon(Icons.delete_outline_rounded),
                                                  onPressed: () async {
                                                    final ok = await showDialog<bool>(
                                                      context: context,
                                                      builder: (dialogContext) => AlertDialog(
                                                        backgroundColor: Colors.black,
                                                        title: const Text('Delete?', style: TextStyle(color: Colors.white)),
                                                        content: Text(
                                                          'Remove "${item.nutrient.isEmpty ? 'this entry' : item.nutrient}"?',
                                                          style: const TextStyle(color: Colors.white70),
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(dialogContext, false),
                                                            child: const Text('Cancel'),
                                                          ),
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(dialogContext, true),
                                                            child: const Text('Delete'),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                    if (ok == true) {
                                                      await _deleteItem(item);
                                                      _close(null);
                                                    }
                                                  },
                                                ),
                                                // Close
                                                IconButton(
                                                  tooltip: 'Close',
                                                  icon: const Icon(Icons.close),
                                                  onPressed: () => _close(null),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 12),

                                            if (mode == IntakeMode.weekday)
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: List.generate(7, (i) {
                                                  final day = i + 1; // 1..7
                                                  return chip(
                                                    dows.contains(day),
                                                    const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][i],
                                                    () => setM(() {
                                                      if (dows.contains(day)) {
                                                        dows.remove(day);
                                                      } else {
                                                        dows.add(day);
                                                      }
                                                    }),
                                                  );
                                                }),
                                              ),

                                            if (mode == IntakeMode.decan)
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: List.generate(10, (i) {
                                                  final dd = i + 1; // 1..10
                                                  return chip(decans.contains(dd), 'Day $dd', () {
                                                    setM(() {
                                                      if (decans.contains(dd)) {
                                                        decans.remove(dd);
                                                      } else {
                                                        decans.add(dd);
                                                      }
                                                    });
                                                  });
                                                }),
                                              ),

                                            const SizedBox(height: 12),

                                            // Time & repeat
                                            Row(
                                              children: [
                                                OutlinedButton.icon(
                                                  icon: const Icon(Icons.schedule_rounded, size: 18),
                                                  label: Text(time.format(context)),
                                                  onPressed: () async {
                                                    final picked = await showTimePicker(
                                                      context: context,
                                                      initialTime: time,
                                                      useRootNavigator: true,
                                                      builder: (c, child) => Theme(data: darkOverlayTheme, child: child!),
                                                    );
                                                    if (picked != null) setM(() => time = picked);
                                                  },
                                                ),
                                                const SizedBox(width: 12),
                                                Checkbox(
                                                  value: repeat,
                                                  onChanged: (v) => setM(() => repeat = v ?? true),
                                                ),
                                                const Text('Repeat'),
                                              ],
                                            ),

                                            const SizedBox(height: 16),

                                            // Save (with empty-selection guard)
                                            FilledButton(
                                              onPressed: () {
                                                if (mode == IntakeMode.weekday && dows.isEmpty) {
                                                  _toast(context, 'Select at least one weekday');
                                                  return;
                                                }
                                                if (mode == IntakeMode.decan && decans.isEmpty) {
                                                  _toast(context, 'Select at least one decan day');
                                                  return;
                                                }
                                                _close(_build());
                                              },
                                              child: const Text('Save'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    // ✅ Patch C: Insert into root overlay (top-most)
    final overlay = Overlay.maybeOf(ctx, rootOverlay: true);
    if (overlay != null) {
      overlay.insert(overlayEntry!);
    } else {
      finish(null);
    }

    return completer.future;
  }

  void _addNewItem() async {
    if (_adding) return;
    setState(() => _adding = true);

    // placeholder row (disabled until schedule is set)
    final local = NutritionItem(
      id: '', // will be set after save
      nutrient: '',
      source: '',
      purpose: '',
      enabled: false,
      schedule: const IntakeSchedule(
        mode: IntakeMode.weekday,
        daysOfWeek: {}, // empty until user picks
        decanDays: {},
        repeat: true,
        time: TimeOfDay(hour: 9, minute: 0),
      ),
    );

    // show it immediately at the top
    setState(() => _items = [local, ..._items]);

    try {
      final saved = await widget.repo.upsert(local);
      if (!mounted) return;
      final i = _items.indexOf(local);
      if (i >= 0) setState(() => _items[i] = saved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not add row: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  void _saveDebounced(NutritionItem item, {required bool resync}) {
    final key = item.id.isNotEmpty ? item.id : item.hashCode.toString();
    _debouncers[key]?.cancel();
    _debouncers[key] = Timer(const Duration(milliseconds: 400), () async {
      try {
        final saved = await widget.repo.upsert(item);
        if (!mounted) return;
        
        // Find by ID, or by reference if ID is empty (new item)
        final idx = _items.indexWhere((e) => 
          e.id == saved.id || (item.id.isEmpty && identical(e, item))
        );
        
        if (idx >= 0) {
          setState(() {
            _items[idx] = saved;  // Update in place
          });
        } else {
          debugPrint('[NutritionGrid] Item not found in list: ${item.id}');
        }
        
        if (resync && _scheduleChanged[saved.id] == true) {
          await _syncToCalendar(saved);
          _scheduleChanged[saved.id] = false;
        }
      } catch (e) {
        debugPrint('[NutritionGrid] Error saving item: $e');
        // ignore backend here; UI remains usable
      }
    });
  }

  Future<void> _syncToCalendar(NutritionItem item) async {
    // Delete existing events for this item
    await widget.eventsRepo.deleteByClientIdPrefix('nutrition:${item.id}:');
    // If disabled, do not schedule further events
    if (!item.enabled) return;
    final converter = KemeticConverter();
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 120));
    for (var d = DateTime(now.year, now.month, now.day);
        d.isBefore(horizon);
        d = d.add(const Duration(days: 1))) {
      bool shouldSchedule;
      if (item.schedule.mode == IntakeMode.weekday) {
        shouldSchedule = item.schedule.daysOfWeek.contains(d.weekday);
      } else {
        final kd = converter.fromGregorian(d);
        if (kd.epagomenal) continue;
        final dayInDecan = ((kd.day - 1) % 10) + 1;
        shouldSchedule = item.schedule.decanDays.contains(dayInDecan);
      }
      if (!shouldSchedule) continue;
      final localStart = DateTime(
        d.year,
        d.month,
        d.day,
        item.schedule.time.hour,
        item.schedule.time.minute,
      );
      final dateKey = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      await widget.eventsRepo.upsertByClientId(
        clientEventId: 'nutrition:${item.id}:$dateKey',
        title: item.nutrient.isNotEmpty ? item.nutrient : 'Nutrient',
        detail: '${item.purpose}\nSource: ${item.source}',
        startsAtUtc: localStart.toUtc(),
        allDay: false,
      );
      if (!item.schedule.repeat) break;
    }
  }

  Future<void> _deleteItem(NutritionItem item) async {
    // Cancel notifications for all events related to this item
    try {
      final events = await widget.eventsRepo.getAllEvents();
      for (final evt in events) {
        if (evt.clientEventId?.startsWith('nutrition:${item.id}:') ?? false) {
          await Notify.cancelNotificationForEvent(evt.clientEventId!);
        }
      }
    } catch (e) {
      // Log but don't block deletion
      debugPrint('[nutrition] Failed to cancel notifications: $e');
    }
    
    // Delete events via prefix
    await widget.eventsRepo.deleteByClientIdPrefix('nutrition:${item.id}:');
    // Delete item
    await widget.repo.delete(item.id);
    setState(() => _items.removeWhere((i) => i.id == item.id));
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });
  
  @override
  Widget build(BuildContext context) {
    final isMissingTable = message.toLowerCase().contains('nutrition_items') && 
                           (message.toLowerCase().contains('does not exist') || 
                            message.toLowerCase().contains('42p01') ||
                            message.toLowerCase().contains('relation'));
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              isMissingTable
                  ? 'The nutrition table has not been created yet.'
                  : 'Could not load nutrition items.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (isMissingTable)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Run sql_migrations/nutrition_items.sql in Supabase, then tap Retry.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

