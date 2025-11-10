import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

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

  // Column widths for header and body alignment (fixed widths for perfect alignment)
  static const double _rowHeight = 48;
  static const TextStyle _hdrStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.w600);
  static const TextStyle _cellStyle = TextStyle(color: Colors.white);

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
  Widget _headerCell(String text, {double? width}) {
    return Container(
      color: Colors.black,
      width: width,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        text,
        style: _hdrStyle,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
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
  // Fractions must sum ~1.0; tune if you like
  static const List<double> _FRACTIONS = [0.22, 0.18, 0.28, 0.22, 0.06, 0.04];

  // Public entry point for responsive table (uses _items field)
  Widget buildNutritionTableResponsive() {
    return Column(
      children: [
        // Header (flex columns)
        Table(
          columnWidths: {
            for (int i = 0; i < _FRACTIONS.length; i++) i: FlexColumnWidth(_FRACTIONS[i]),
          },
          border: _gridBorder(),
          defaultVerticalAlignment: TableCellVerticalAlignment.top, // top for wrapping
          children: [
            TableRow(children: [
              _headerCell('Nutrient'),     // width optional; not needed w/ Flex
              _headerCell('Source'),
              _headerCell('Purpose'),
              _headerCell('When to take'),
              _headerCell('Repeat'),
              _headerCell(''),             // Delete (blank header)
            ]),
          ],
        ),

        // Body (vertical scroll only)
        Expanded(
          child: SingleChildScrollView(
            child: Table(
              columnWidths: {
                for (int i = 0; i < _FRACTIONS.length; i++) i: FlexColumnWidth(_FRACTIONS[i]),
              },
              border: _gridBorder(),
              defaultVerticalAlignment: TableCellVerticalAlignment.top,
              children: [for (final it in _items) _buildRowFractional(it)],
            ),
          ),
        ),
      ],
    );
  }

  // Header table with fractional widths
  Widget _buildHeaderTableFractional(List<double> widths) {
    return Table(
      columnWidths: {
        for (int i = 0; i < widths.length; i++) i: FixedColumnWidth(widths[i]),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: _gridBorder(),
      children: [
        TableRow(
          children: [
            _headerCell('Nutrient', width: widths[0]),
            _headerCell('Source',   width: widths[1]),
            _headerCell('Purpose',  width: widths[2]),
            _headerCell('When to take', width: widths[3]),
            _headerCell('Repeat',   width: widths[4]),
            _headerCell('',         width: widths[5]),
          ],
        ),
      ],
    );
  }

  // Body table with fractional widths (legacy method - not used by new responsive table)
  Widget _buildBodyTableFractional(List<double> widths, List<NutritionItem> items) {
    return Table(
      columnWidths: {
        for (int i = 0; i < widths.length; i++) i: FixedColumnWidth(widths[i]),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: _gridBorder(),
      children: [
        for (final it in items) _buildRowFractional(it),  // Fixed: removed widths parameter
      ],
    );
  }

  // Row builder (uses FlexColumnWidth, so no pixel widths needed)
  TableRow _buildRowFractional(NutritionItem item) {
    return TableRow(children: [
      _cellTextField(item, field: 'nutrient', hint: 'e.g., Magnesium', width: null),
      _cellTextField(item, field: 'source',   hint: 'e.g., 200mg caps', width: null),
      // Purpose grows freely (null = wrap)
      _cellTextField(item, field: 'purpose',  hint: 'e.g., sleep, recovery', maxLines: null, width: null),
      _cellSchedule(item, width: null),  // label wraps
      _cellRepeat(item, width: null),
      _cellDelete(item, width: null),
    ]);
  }

  // === CELLS ===
  Widget _cellShell(
    Widget child, {
    Alignment align = Alignment.centerLeft,
    double? width,       // kept for compatibility
    double? minHeight,   // new: lets rows grow
  }) {
    return Container(
      color: Colors.black,
      width: width,
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      constraints: BoxConstraints(minHeight: minHeight ?? 44), // no max height
      child: child,
    );
  }

  Widget _cellTextField(
    NutritionItem item, {
    required String field,
    String? hint,
    int? maxLines = 1,   // nullable; null => wrap & grow
    double? width,       // kept for compatibility
  }) {
    final initial = switch (field) {
      'nutrient' => item.nutrient,
      'source' => item.source,
      'purpose' => item.purpose,
      _ => '',
    };

    // Purpose grows fully; others keep provided cap
    final lines = (field == 'purpose') ? null : maxLines;

    return _cellShell(
      TextFormField(
        initialValue: initial,
        style: _cellStyle,
        textAlignVertical: TextAlignVertical.top,  // top aligns multi-line
        maxLines: lines,                           // null => wrap & grow
        minLines: 1,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (v) {
          switch (field) {
            case 'nutrient':
              item.nutrient = v;
              break;
            case 'source':
              item.source = v;
              break;
            case 'purpose':
              item.purpose = v;
              break;
          }
          _saveDebounced(item, resync: false); // text-only change
        },
      ),
      width: width,
    );
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

  Widget _cellSchedule(NutritionItem item, {double? width}) {
    final label = _scheduleLabel(context, item.schedule);
    return InkWell(
      onTap: () async {
        final updated = await _openSchedulePicker(context, item.schedule);
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
      child: _cellShell(
        Text(
          label.isEmpty ? 'Tap to set' : label,
          style: TextStyle(
            color: label.isEmpty ? Colors.white38 : Colors.blueAccent,
            fontStyle: label.isEmpty ? FontStyle.italic : FontStyle.normal,
          ),
          maxLines: null,  // wrap & grow
        ),
        width: width,
      ),
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
    return _cellShell(
      Center(
        child: IconButton(
          tooltip: 'Delete',
          onPressed: () => _deleteItem(item),
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          splashRadius: 18,
          padding: EdgeInsets.zero,
        ),
      ),
      align: Alignment.center,
      width: width,
    );
  }

  Future<IntakeSchedule?> _openSchedulePicker(BuildContext context, IntakeSchedule initial) async {
    final result = await showModalBottomSheet<IntakeSchedule>(
      context: context,
      useRootNavigator: true,  // ensures it appears above the modal
      backgroundColor: Colors.black,
      isScrollControlled: true,
      builder: (ctx) {
        IntakeMode mode = initial.mode;
        Set<int> dows = {...initial.daysOfWeek};
        Set<int> decan = {...initial.decanDays};
        bool repeat = initial.repeat;
        TimeOfDay time = initial.time;

        return StatefulBuilder(
          builder: (context, setM) {
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

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mode toggle
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Weekdays'),
                        selected: mode == IntakeMode.weekday,
                        onSelected: (v) => setM(() => mode = IntakeMode.weekday),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Decan days'),
                        selected: mode == IntakeMode.decan,
                        onSelected: (v) => setM(() => mode = IntakeMode.decan),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Multi-select
                  if (mode == IntakeMode.weekday) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(7, (i) {
                        final dayNum = i + 1; // 1..7
                        const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        final selected = dows.contains(dayNum);
                        return chip(selected, labels[i], () {
                          setM(() {
                            if (selected) {
                              dows.remove(dayNum);
                            } else {
                              dows.add(dayNum);
                            }
                          });
                        });
                      }),
                    ),
                  ] else ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(10, (i) {
                        final dayNum = i + 1; // 1..10
                        final selected = decan.contains(dayNum);
                        return chip(selected, 'Day $dayNum', () {
                          setM(() {
                            if (selected) {
                              decan.remove(dayNum);
                            } else {
                              decan.add(dayNum);
                            }
                          });
                        });
                      }),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Time + repeat
                  Row(
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.schedule, color: Colors.white70),
                        label: Text(
                          time.format(context),
                          style: const TextStyle(color: Colors.white),
                        ),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: time,
                            useRootNavigator: true,  // ensures it appears above the modal
                          );
                          if (picked != null) setM(() => time = picked);
                        },
                      ),
                      const Spacer(),
                      const Text('Repeat', style: TextStyle(color: Colors.white70)),
                      Checkbox(
                        value: repeat,
                        onChanged: (v) => setM(() => repeat = v ?? true),
                        activeColor: Colors.white,
                        checkColor: Colors.black,
                        side: const BorderSide(color: Colors.white54),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () {
                        final s = initial.copyWith(
                          mode: mode,
                          daysOfWeek: dows,
                          decanDays: decan,
                          repeat: repeat,
                          time: time,
                        );
                        Navigator.pop(context, s);
                      },
                      style: FilledButton.styleFrom(backgroundColor: Colors.white),
                      child: const Text('Save', style: TextStyle(color: Colors.black)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
    return result;
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
        final idx = _items.indexWhere((e) => e.id == item.id);
        if (idx >= 0) {
          setState(() => _items[idx] = saved);
        }
        if (resync && _scheduleChanged[saved.id] == true) {
          await _syncToCalendar(saved);
          _scheduleChanged[saved.id] = false;
        }
      } catch (_) {
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

