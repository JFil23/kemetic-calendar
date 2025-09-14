import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/* ───────────────────── Premium Dark Theme (library-scope constants) ───────────────────── */

const Color _bg = Color(0xFF0E0E10); // charcoal
const Color _gold = Color(0xFFD4AF37);
const Color _silver = Color(0xFFC8CCD2);
const Color _cardBorderGold = _gold;
const Color _chipFill = Color(0x1AFFFFFF); // faint pill fill
const Color _chipFillToday = Color(0x33212121); // slightly brighter + thin glow ring

const TextStyle _titleGold =
TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: _gold);
const TextStyle _monthTitleGold =
TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: _gold);
const TextStyle _rightSmall =
TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: _silver);
const TextStyle _seasonStyle =
TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _gold);
const TextStyle _decanStyle =
TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: _silver);

/*  ──────────────────────────────────────────────────────────────────────
    KEMETIC CALENDAR
    ────────────────────────────────────────────────────────────────────── */

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  /* ───── today + notes state ───── */

  late final ({int kYear, int kMonth, int kDay}) _today =
  KemeticMath.fromGregorian(DateTime.now());

  final Map<String, List<_Note>> _notes = {};

  // for centering and for snapping to today
  final _centerKey = GlobalKey();
  final _todayMonthKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday());
  }

  /* ───── helpers ───── */

  String _kKey(int ky, int km, int kd) => '$ky-$km-$kd';

  List<_Note> _getNotes(int kYear, int kMonth, int kDay) =>
      _notes[_kKey(kYear, kMonth, kDay)] ?? const [];

  void _addNote(
      int kYear,
      int kMonth,
      int kDay,
      String title,
      String? detail, {
        String? location,
        bool allDay = false,
        TimeOfDay? start,
        TimeOfDay? end,
      }) {
    final k = _kKey(kYear, kMonth, kDay);
    final list = _notes.putIfAbsent(k, () => <_Note>[]);
    list.add(_Note(
      title: title.trim(),
      detail: detail?.trim(),
      location: location?.trim().isEmpty ?? true ? null : location!.trim(),
      allDay: allDay,
      start: allDay ? null : start,
      end: allDay ? null : end,
    ));
    setState(() {});
  }

  void _deleteNote(int kYear, int kMonth, int kDay, int index) {
    final k = _kKey(kYear, kMonth, kDay);
    final list = _notes[k];
    if (list == null) return;
    list.removeAt(index);
    if (list.isEmpty) _notes.remove(k);
    setState(() {});
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;
  TimeOfDay _addMinutes(TimeOfDay t, int delta) {
    final m = (_toMinutes(t) + delta) % (24 * 60);
    return TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  String _timeRangeLabel({required bool allDay, TimeOfDay? start, TimeOfDay? end}) {
    if (allDay) return 'All-day';
    String s(TimeOfDay t) => _formatTimeOfDay(t);
    if (start != null && end != null) return '${s(start)} – ${s(end)}';
    if (start != null) return s(start);
    if (end != null) return '… – ${s(end)}';
    return '';
  }

  /// Gregorian label for a Kemetic month/year (handles epagomenal spanning years).
  String _gregYearLabelFor(int kYear, int kMonth) {
    final lastDay = (kMonth == 13) ? (KemeticMath.isLeapKemeticYear(kYear) ? 6 : 5) : 30;
    final yStart = KemeticMath.toGregorian(kYear, kMonth, 1).year;
    final yEnd = KemeticMath.toGregorian(kYear, kMonth, lastDay).year;
    return (yStart == yEnd) ? '$yStart' : '$yStart/$yEnd';
  }

  String _monthLabel(int kMonth) =>
      kMonth == 13 ? 'Epagomenal' : _MonthCard.monthNames[kMonth];

  /* ───── TODAY snap/center ───── */

  void _scrollToToday() {
    final ctx = _todayMonthKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /* ───── Search ───── */

  void _openSearch() {
    showSearch(
      context: context,
      delegate: _EventSearchDelegate(
        notes: _notes,
        monthName: (km) => km == 13 ? 'Epagomenal' : _MonthCard.monthNames[km],
        gregYearLabelFor: _gregYearLabelFor,
        openDay: (ky, km, kd) {
          Navigator.of(context).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _openDaySheet(context, ky, km, kd);
          });
        },
      ),
    );
  }

  /* ───── Day Sheet ───── */

  void _openDaySheet(
      BuildContext ctx,
      int kYear,
      int kMonth,
      int kDay, {
        bool allowDateChange = false,
      }) {
    int selYear = kYear;
    int selMonth = kMonth;
    int selDay = kDay;

    final int yearStart = _today.kYear - 200;
    final int yearItem = kYear - yearStart;
    final yearCtrl =
    FixedExtentScrollController(initialItem: yearItem.clamp(0, 400));
    final monthCtrl =
    FixedExtentScrollController(initialItem: (kMonth - 1).clamp(0, 12));
    final dayCtrl = FixedExtentScrollController(initialItem: (kDay - 1));

    final controllerTitle = TextEditingController();
    final controllerLocation = TextEditingController();
    final controllerDetail = TextEditingController();

    bool allDay = false;
    TimeOfDay? startTime = const TimeOfDay(hour: 12, minute: 0);
    TimeOfDay? endTime = const TimeOfDay(hour: 13, minute: 0);

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121214),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        final media = MediaQuery.of(sheetCtx);

        final labelStyleWhite = const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        );

        final fieldLabel =
        const TextStyle(fontSize: 12, color: Color(0xFFBFC3C7));

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final titleG = KemeticMath.toGregorian(selYear, selMonth, selDay);
            final titleText =
                '${_monthLabel(selMonth)} $selDay • ${titleG.year}';
            final int dayCount = (selMonth == 13)
                ? (KemeticMath.isLeapKemeticYear(selYear) ? 6 : 5)
                : 30;

            if (selDay > dayCount) {
              selDay = dayCount;
              if (allowDateChange && dayCtrl.hasClients) {
                WidgetsBinding.instance.addPostFrameCallback(
                      (_) => dayCtrl.jumpToItem(selDay - 1),
                );
              }
            }

            final dayNotes = _getNotes(selYear, selMonth, selDay);

            Future<void> pickStart() async {
              final t = await showTimePicker(
                context: sheetCtx,
                initialTime: startTime ?? const TimeOfDay(hour: 12, minute: 0),
                builder: (c, w) => Theme(
                  data: Theme.of(c).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: _gold,
                      surface: _bg,
                      onSurface: Colors.white,
                    ),
                  ),
                  child: w!,
                ),
              );
              if (t == null) return;
              setSheetState(() {
                startTime = t;
                if (endTime != null && _toMinutes(endTime!) <= _toMinutes(t)) {
                  endTime = _addMinutes(t, 60);
                }
              });
            }

            Future<void> pickEnd() async {
              final t = await showTimePicker(
                context: sheetCtx,
                initialTime: endTime ??
                    (startTime != null
                        ? _addMinutes(startTime!, 60)
                        : const TimeOfDay(hour: 13, minute: 0)),
                builder: (c, w) => Theme(
                  data: Theme.of(c).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: _gold,
                      surface: _bg,
                      onSurface: Colors.white,
                    ),
                  ),
                  child: w!,
                ),
              );
              if (t == null) return;
              setSheetState(() {
                endTime = t;
                if (startTime != null &&
                    _toMinutes(t) <= _toMinutes(startTime!)) {
                  startTime = _addMinutes(t, -60);
                }
              });
            }

            Widget timeButton({
              required String label,
              required TimeOfDay? value,
              required VoidCallback onTap,
              required bool enabled,
            }) {
              final text = value == null ? '--:--' : _formatTimeOfDay(value);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: fieldLabel),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: _silver, width: 1),
                      ),
                      onPressed: enabled ? onTap : null,
                      child: Text(text),
                    ),
                  ),
                ],
              );
            }

            Widget datePicker() {
              if (!allowDateChange) {
                return Text(titleText, style: labelStyleWhite);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(titleText,
                      textAlign: TextAlign.center, style: labelStyleWhite),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 128,
                    child: Row(
                      children: [
                        // Month
                        Expanded(
                          flex: 4,
                          child: CupertinoPicker(
                            scrollController: monthCtrl,
                            itemExtent: 32,
                            looping: true,
                            backgroundColor: const Color(0x00121214),
                            onSelectedItemChanged: (i) =>
                                setSheetState(() => selMonth = (i % 13) + 1),
                            children: List<Widget>.generate(13, (i) {
                              final m = i + 1;
                              final label = (m == 13)
                                  ? 'Epagomenal'
                                  : _MonthCard.monthNames[m];
                              return Center(
                                child: Text(label,
                                    style:
                                    const TextStyle(color: _silver)),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Day
                        Expanded(
                          flex: 3,
                          child: CupertinoPicker(
                            scrollController: dayCtrl,
                            itemExtent: 32,
                            looping: true,
                            backgroundColor: const Color(0x00121214),
                            onSelectedItemChanged: (i) {
                              setSheetState(() {
                                final max = (selMonth == 13)
                                    ? (KemeticMath.isLeapKemeticYear(selYear)
                                    ? 6
                                    : 5)
                                    : 30;
                                selDay = (i % max) + 1;
                              });
                            },
                            children: List<Widget>.generate(dayCount, (i) {
                              final d = i + 1;
                              return Center(
                                  child: Text('$d',
                                      style: const TextStyle(
                                          color: _silver)));
                            }),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Year (gregorian label)
                        Expanded(
                          flex: 4,
                          child: CupertinoPicker(
                            scrollController: yearCtrl,
                            itemExtent: 32,
                            looping: false,
                            backgroundColor: const Color(0x00121214),
                            onSelectedItemChanged: (i) =>
                                setSheetState(() => selYear = yearStart + i),
                            children: List<Widget>.generate(401, (i) {
                              final ky = yearStart + i;
                              final label =
                              _gregYearLabelFor(ky, selMonth);
                              return Center(
                                  child: Text(label,
                                      style: const TextStyle(
                                          color: _silver)));
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: media.viewInsets.bottom + 12,
              ),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // drag handle
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Date (static or wheels)
                    datePicker(),
                    const SizedBox(height: 12),

                    // Existing notes
                    if (dayNotes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No notes yet',
                            style: TextStyle(color: _silver)),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: dayNotes.length,
                          separatorBuilder: (_, __) =>
                          const Divider(height: 12, color: Colors.white10),
                          itemBuilder: (_, i) {
                            final n = dayNotes[i];
                            final timeLine = _timeRangeLabel(
                                allDay: n.allDay,
                                start: n.start,
                                end: n.end);
                            final location =
                            (n.location?.isEmpty ?? true)
                                ? null
                                : n.location!;
                            final detail =
                            (n.detail?.isEmpty ?? true)
                                ? null
                                : n.detail!;
                            final sub = [
                              if (timeLine.isNotEmpty) timeLine,
                              if (location != null) location,
                              if (detail != null) detail,
                            ].join('\n');

                            return ListTile(
                              dense: true,
                              title: Text(n.title,
                                  style: const TextStyle(
                                      color: Colors.white)),
                              subtitle: sub.isEmpty
                                  ? null
                                  : Text(sub,
                                  style: const TextStyle(
                                      color: _silver)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: _silver),
                                onPressed: () {
                                  _deleteNote(selYear, selMonth, selDay, i);
                                  Navigator.pop(sheetCtx);
                                  _openDaySheet(
                                    ctx,
                                    selYear,
                                    selMonth,
                                    selDay,
                                    allowDateChange: allowDateChange,
                                  ); // reopen
                                },
                              ),
                            );
                          },
                        ),
                      ),

                    const Divider(height: 16, color: Colors.white12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Add note',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Title
                    TextField(
                      controller: controllerTitle,
                      style: const TextStyle(color: Colors.white),
                      decoration: _darkInput('Title'),
                    ),
                    const SizedBox(height: 8),

                    // Location
                    TextField(
                      controller: controllerLocation,
                      style: const TextStyle(color: Colors.white),
                      decoration: _darkInput(
                        'Location or Video Call',
                        hint: 'e.g., Home • Zoom • https://meet…',
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Details
                    TextField(
                      controller: controllerDetail,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: _darkInput('Details (optional)'),
                    ),

                    const SizedBox(height: 10),
                    // (activeColor is still accepted; can theme if needed)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: allDay,
                      onChanged: (v) => setSheetState(() => allDay = v),
                      title: const Text('All-day', style: TextStyle(color: Colors.white)),
                      activeThumbColor: _gold, // ✅ new API
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        Expanded(
                          child: timeButton(
                            label: 'Starts',
                            value: startTime,
                            onTap: pickStart,
                            enabled: !allDay,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: timeButton(
                            label: 'Ends',
                            value: endTime,
                            onTap: pickEnd,
                            enabled: !allDay,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () {
                          final t = controllerTitle.text.trim();
                          final loc = controllerLocation.text.trim();
                          final d = controllerDetail.text.trim();
                          if (t.isEmpty) return;

                          if (!allDay &&
                              startTime != null &&
                              endTime != null) {
                            if (_toMinutes(endTime!) <=
                                _toMinutes(startTime!)) {
                              endTime = _addMinutes(startTime!, 60);
                            }
                          }

                          _addNote(
                            selYear,
                            selMonth,
                            selDay,
                            t,
                            d.isEmpty ? null : d,
                            location: loc.isEmpty ? null : loc,
                            allDay: allDay,
                            start: startTime,
                            end: endTime,
                          );
                          Navigator.pop(sheetCtx);
                          _openDaySheet(ctx, selYear, selMonth, selDay,
                              allowDateChange: allowDateChange);
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static InputDecoration _darkInput(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: _silver),
      hintStyle: const TextStyle(color: _silver),
      filled: true,
      fillColor: const Color(0xFF1A1B1F),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _gold, width: 1.2),
      ),
    );
  }

  /* ───── UI ───── */

  @override
  Widget build(BuildContext context) {
    final kToday = _today;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111215),
        elevation: 0.5,
        title: const Text('Kemetic Calendar', style: _titleGold),
        actionsIconTheme: const IconThemeData(color: _silver),
        actions: [
          IconButton(
            tooltip: 'Today',
            icon: const Icon(Icons.calendar_today),
            onPressed: _scrollToToday,
          ),
          IconButton(
            tooltip: 'Search events',
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
          ),
          IconButton(
            tooltip: 'New event',
            icon: const Icon(Icons.add),
            onPressed: () => _openDaySheet(
              context,
              kToday.kYear,
              kToday.kMonth,
              kToday.kDay,
              allowDateChange: true,
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        anchor: 0.5, // center the "center" sliver in the viewport
        center: _centerKey, // current Kemetic year is the center
        slivers: [
          // PAST years
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                final kYear = kToday.kYear - (i + 1);
                return _YearSection(
                  kYear: kYear,
                  todayMonth: null,
                  todayDay: null,
                  onDayTap: (c, m, d) => _openDaySheet(c, kYear, m, d),
                  notesGetter: (m, d) => _getNotes(kYear, m, d),
                );
              },
            ),
          ),

          // CENTER: current Kemetic year
          SliverToBoxAdapter(
            key: _centerKey,
            child: _YearSection(
              kYear: kToday.kYear,
              todayMonth: kToday.kMonth,
              todayDay: kToday.kDay,
              monthAnchorKeyProvider: (m) =>
              m == kToday.kMonth ? _todayMonthKey : null,
              onDayTap: (c, m, d) => _openDaySheet(c, kToday.kYear, m, d),
              notesGetter: (m, d) => _getNotes(kToday.kYear, m, d),
            ),
          ),

          // FUTURE years
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                final kYear = kToday.kYear + (i + 1);
                return _YearSection(
                  kYear: kYear,
                  todayMonth: null,
                  todayDay: null,
                  onDayTap: (c, m, d) => _openDaySheet(c, kYear, m, d),
                  notesGetter: (m, d) => _getNotes(kYear, m, d),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────────── Year Section (12 months + epagomenal at the end) ───────────── */

class _YearSection extends StatelessWidget {
  const _YearSection({
    required this.kYear,
    required this.todayMonth,
    required this.todayDay,
    required this.notesGetter,
    required this.onDayTap,
    this.monthAnchorKeyProvider,
  });

  final int kYear;
  final int? todayMonth;
  final int? todayDay;
  final List<_Note> Function(int kMonth, int kDay) notesGetter;
  final void Function(BuildContext, int kMonth, int kDay) onDayTap;
  final Key? Function(int kMonth)? monthAnchorKeyProvider;

  @override
  Widget build(BuildContext context) {
    final (tm, td) = (todayMonth, todayDay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SeasonHeader(title: 'Flood season (Akhet)'),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(1),
          kYear: kYear,
          kMonth: 1,
          seasonShort: 'Akhet',
          todayMonth: tm,
          todayDay: td,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
        ),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(2),
          kYear: kYear,
          kMonth: 2,
          seasonShort: 'Akhet',
          todayMonth: tm,
          todayDay: td,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
        ),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(3),
          kYear: kYear,
          kMonth: 3,
          seasonShort: 'Akhet',
          todayMonth: tm,
          todayDay: td,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
        ),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(4),
          kYear: kYear,
          kMonth: 4,
          seasonShort: 'Akhet',
          todayMonth: tm,
          todayDay: td,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
        ),

        const _SeasonHeader(title: 'Emergence season (Peret)'),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(5),
          kYear: kYear,
          kMonth: 5,
          seasonShort: 'Peret',
          todayMonth: tm,
          todayDay: td,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
        ),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(6),
          kYear: kYear,
          kMonth: 6,
          seasonShort: 'Peret',
          todayMonth: tm,
          todayDay: td,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
        ),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(7),
          kYear: kYear,
          kMonth: 7,
          seasonShort: 'Peret',
          todayMonth: tm,
          todayDay: td,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
        ),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(8),
          kYear: kYear,
          kMonth: 8,
          seasonShort: 'Peret',
          todayMonth: tm,
          todayDay: td,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
        ),

        const _SeasonHeader(title: 'Harvest season (Shemu)'),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(9),
          kYear: kYear,
          kMonth: 9,
          seasonShort: 'Shemu',
          todayMonth: tm,
          todayDay: td,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
        ),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(10),
          kYear: kYear,
          kMonth: 10,
          seasonShort: 'Shemu',
          todayMonth: tm,
          todayDay: td,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
        ),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(11),
          kYear: kYear,
          kMonth: 11,
          seasonShort: 'Shemu',
          todayMonth: tm,
          todayDay: td,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
        ),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(12),
          kYear: kYear,
          kMonth: 12,
          seasonShort: 'Shemu',
          todayMonth: tm,
          todayDay: td,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
        ),

        _EpagomenalCard(
          kYear: kYear,
          todayMonth: tm,
          todayDay: td,
          notesGetter: (m, d) => notesGetter(13, d),
          onDayTap: (c, m, d) => onDayTap(c, 13, d),
        ),
      ],
    );
  }
}

/* ───────────────────────── KEMETIC MATH ───────────────────────── */

class KemeticMath {
  // Anchor: Toth 1, Year 1 = 2025-03-20 (UTC).
  static final DateTime _epochUtc = DateTime.utc(2025, 3, 20);

  // Repeating 4-year cycle lengths starting at Year 1: [365, 365, 366, 365]
  static const List<int> _cycle = [365, 365, 366, 365];
  static const int _cycleSum = 1461; // 365*4 + 1

  static int _mod(int a, int n) => ((a % n) + n) % n;

  static int _daysBeforeYear(int kYear) {
    if (kYear == 1) return 0;
    final y = kYear - 1;

    if (y > 0) {
      final full = y ~/ 4;
      final rem = y % 4;
      var sum = full * _cycleSum;
      for (int i = 0; i < rem; i++) {
        sum += _cycle[i];
      }
      return sum;
    } else {
      final n = -y;
      final full = n ~/ 4;
      final rem = n % 4;
      var sum = full * _cycleSum;
      for (int i = 0; i < rem; i++) {
        sum += _cycle[3 - i];
      }
      return -sum;
    }
  }

  static ({int kYear, int kMonth, int kDay}) fromGregorian(DateTime gLocal) {
    final g = DateUtils.dateOnly(gLocal).toUtc();
    final diff = g.difference(_epochUtc).inDays;

    if (diff >= 0) {
      int kYear = 1;
      int rem = diff;

      final cycles = rem ~/ _cycleSum;
      kYear += cycles * 4;
      rem -= cycles * _cycleSum;

      int idx = 0;
      while (rem >= _cycle[idx]) {
        rem -= _cycle[idx];
        kYear++;
        idx = (idx + 1) & 3;
      }

      final dayOfYear = rem;
      if (dayOfYear < 360) {
        final kMonth = (dayOfYear ~/ 30) + 1;
        final kDay = (dayOfYear % 30) + 1;
        return (kYear: kYear, kMonth: kMonth, kDay: kDay);
      } else {
        final kMonth = 13;
        final kDay = dayOfYear - 360 + 1;
        return (kYear: kYear, kMonth: kMonth, kDay: kDay);
      }
    }

    int rem = -diff - 1;
    rem %= _cycleSum;

    int year = 0;
    final rev = [_cycle[3], _cycle[2], _cycle[1], _cycle[0]];

    for (int i = 0; i < 4; i++) {
      final len = rev[i];
      if (rem < len) {
        final dayOfYear = len - 1 - rem;
        year -= i;
        if (dayOfYear < 360) {
          final kMonth = (dayOfYear ~/ 30) + 1;
          final kDay = (dayOfYear % 30) + 1;
          return (kYear: year, kMonth: kMonth, kDay: kDay);
        } else {
          final kMonth = 13;
          final kDay = dayOfYear - 360 + 1;
          return (kYear: year, kMonth: kMonth, kDay: kDay);
        }
      }
      rem -= len;
    }

    return (kYear: -3, kMonth: 13, kDay: 1);
  }

  static DateTime toGregorian(int kYear, int kMonth, int kDay) {
    if (kMonth < 1 || kMonth > 13) {
      throw ArgumentError('kMonth 1..13');
    }
    if (kMonth == 13) {
      final maxEpi = isLeapKemeticYear(kYear) ? 6 : 5;
      if (kDay < 1 || kDay > maxEpi) {
        throw ArgumentError('kDay 1..$maxEpi for epagomenal in year $kYear');
      }
    } else {
      if (kDay < 1 || kDay > 30) throw ArgumentError('kDay 1..30');
    }

    final base = _daysBeforeYear(kYear);
    final dayIndex =
    (kMonth == 13) ? (360 + (kDay - 1)) : ((kMonth - 1) * 30 + (kDay - 1));
    final days = base + dayIndex;
    return _epochUtc.add(Duration(days: days)).toLocal();
  }

  static bool isLeapKemeticYear(int kYear) => _mod(kYear - 1, 4) == 2;
}

/* ───────────────────────── SUPPORTING WIDGETS ───────────────────────── */

class _SeasonHeader extends StatelessWidget {
  final String title;
  const _SeasonHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: _seasonStyle),
    );
  }
}

class _MonthCard extends StatelessWidget {
  final Key? anchorKey;
  final int kYear;
  final int kMonth; // 1..12
  final String seasonShort; // Akhet/Peret/Shemu
  final int? todayMonth;
  final int? todayDay;

  final List<_Note> Function(int kMonth, int kDay) notesGetter;
  final void Function(BuildContext, int kMonth, int kDay) onDayTap;

  const _MonthCard({
    this.anchorKey,
    required this.kYear,
    required this.kMonth,
    required this.seasonShort,
    required this.todayMonth,
    required this.todayDay,
    required this.notesGetter,
    required this.onDayTap,
  });

  static const monthNames = [
    '',
    'Toth (Tekh)',
    'Menkhet (Paopi)',
    'Hathor (Athyr)',
    'Ka-ḥer-ka (Khoiak)',
    'Šef-Bedet (Tybi/Tobi)',
    'Rekeh-Wer (Mechir)',
    'Rekeh-Neds (Phamenoth)',
    'Renwet (Pharmuthi)',
    'Pakhons (Payni)',
    'Payni (Paoni)',
    'Ipi (Epiphi)',
    'Mesore (Mesori)',
  ];

  static const Map<int, List<String>> decans = {
    1: ['ṯmꜣt ḥrt', 'ṯmꜣt ẖrt', 'wšꜣty bkꜣty'],
    2: ['ı͗pḏs', 'sbšsn', 'ḫntt ḥrt'],
    3: ['ḫntt ẖrt', 'ṯms n ḫntt', 'ḳdty'],
    4: ['ḫnwy', 'ḥry-ı͗b wı͗ꜣ', '“crew”'],
    5: ['knmw', 'smd srt', 'srt'],
    6: ['sꜣwy srt', 'ẖry ḫpd srt', 'tpy-ꜥ ꜣḫwy'],
    7: ['ꜣḫwy', 'ı͗my-ḫt ꜣḫwy', 'bꜣwy'],
    8: ['ḳd', 'ḫꜣw', 'ꜥrt'],
    9: ['ẖry ꜥrt', 'rmn ḥry sꜣḥ', 'rmn ẖry sꜣḥ'],
    10: ['ꜥbwt', 'wꜥrt ẖrt sꜣḥ', 'tpy-ꜥ spdt'],
    11: ['spdt (Sopdet/Sothis)', 'knmt', 'sꜣwy knmt'],
    12: ['ẖry ḫpd n knmt', 'ḥꜣt ḫꜣw', 'pḥwy ḫꜣw'],
  };

  @override
  Widget build(BuildContext context) {
    final names = decans[kMonth] ?? const ['Decan A', 'Decan B', 'Decan C'];

    final yStart = KemeticMath.toGregorian(kYear, kMonth, 1).year;
    final yEnd = KemeticMath.toGregorian(kYear, kMonth, 30).year;
    final rightLabel =
    (yStart == yEnd) ? '$seasonShort $yStart' : '$seasonShort $yStart/$yEnd';

    return Padding(
      key: anchorKey,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: Card(
        color: const Color(0xFF121315),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _cardBorderGold, width: 1.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(monthNames[kMonth], style: _monthTitleGold),
                  const Spacer(),
                  Text(rightLabel, style: _rightSmall),
                ],
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < 3; i++) ...[
                Text(names[i], style: _decanStyle),
                const SizedBox(height: 6),
                _DecanRow(
                  kMonth: kMonth,
                  decanIndex: i,
                  todayMonth: todayMonth,
                  todayDay: todayDay,
                  notesGetter: notesGetter,
                  onDayTap: onDayTap,
                ),
                if (i < 2) const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DecanRow extends StatelessWidget {
  final int kMonth; // 1..12
  final int decanIndex; // 0..2
  final int? todayMonth;
  final int? todayDay;

  final List<_Note> Function(int kMonth, int kDay) notesGetter;
  final void Function(BuildContext, int kMonth, int kDay) onDayTap;

  const _DecanRow({
    required this.kMonth,
    required this.decanIndex,
    required this.todayMonth,
    required this.todayDay,
    required this.notesGetter,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMonthToday = (todayMonth != null && todayMonth == kMonth);
    return Row(
      children: List.generate(10, (j) {
        final day = decanIndex * 10 + (j + 1); // 1..30
        final isToday = isMonthToday && (todayDay == day);
        final noteCount = notesGetter(kMonth, day).length;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: j == 9 ? 0 : 6),
            child: _DayChip(
              label: '$day',
              isToday: isToday,
              noteCount: noteCount,
              onTap: () => onDayTap(context, kMonth, day),
            ),
          ),
        );
      }),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool isToday;
  final int noteCount;
  final VoidCallback onTap;

  const _DayChip({
    required this.label,
    required this.isToday,
    required this.noteCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isToday ? _chipFillToday : _chipFill;
    final textStyle = TextStyle(
      color: isToday ? _gold : _silver,
      fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
      fontSize: 12,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isToday
              ? const [
            BoxShadow(
              color: _gold,
              blurRadius: 0,
              spreadRadius: 0.6, // faint gold ring
            )
          ]
              : null,
        ),
        child: Stack(
          children: [
            Align(alignment: Alignment.center, child: Text(label, style: textStyle)),
            if (noteCount > 0)
              Positioned(
                right: 4,
                bottom: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(noteCount.clamp(1, 3), (i) {
                    return Container(
                      width: 4.5,
                      height: 4.5,
                      margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
                      decoration: const BoxDecoration(
                        color: _silver,
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EpagomenalCard extends StatelessWidget {
  const _EpagomenalCard({
    required this.kYear,
    this.todayMonth,
    this.todayDay,
    required this.notesGetter,
    required this.onDayTap,
  });

  final int kYear;
  final int? todayMonth;
  final int? todayDay;
  final List<_Note> Function(int kMonth, int kDay) notesGetter;
  final void Function(BuildContext, int kMonth, int kDay) onDayTap;

  @override
  Widget build(BuildContext context) {
    final isMonthToday = (todayMonth != null && todayMonth == 13);
    final epiCount = KemeticMath.isLeapKemeticYear(kYear) ? 6 : 5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      child: Card(
        color: const Color(0xFF121315),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _cardBorderGold, width: 1.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Epagomenal Days (Ḥeriu rnp.t)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: _gold),
              ),
              const SizedBox(height: 10),
              Row(
                children: List.generate(epiCount, (i) {
                  final n = i + 1; // 1..5 or 1..6
                  final isToday = isMonthToday && (todayDay == n);
                  final noteCount = notesGetter(13, n).length;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i == epiCount - 1 ? 0 : 6),
                      child: _DayChip(
                        label: '$n',
                        isToday: isToday,
                        noteCount: noteCount,
                        onTap: () => onDayTap(context, 13, n),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ───────────── Search Delegate ───────────── */

class _SearchHit {
  final int ky, km, kd;
  final _Note note;
  _SearchHit(this.ky, this.km, this.kd, this.note);
}

class _EventSearchDelegate extends SearchDelegate<void> {
  _EventSearchDelegate({
    required Map<String, List<_Note>> notes,
    required this.monthName,
    required this.gregYearLabelFor,
    required this.openDay,
  }) : _notes = notes;

  final Map<String, List<_Note>> _notes;
  final String Function(int km) monthName;
  final String Function(int ky, int km) gregYearLabelFor;
  final void Function(int ky, int km, int kd) openDay;

  List<_SearchHit> _search(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return const [];

    final hits = <_SearchHit>[];
    _notes.forEach((key, list) {
      final parts = key.split('-');
      if (parts.length != 3) return;
      final ky = int.tryParse(parts[0]) ?? 0;
      final km = int.tryParse(parts[1]) ?? 0;
      final kd = int.tryParse(parts[2]) ?? 0;

      for (final n in list) {
        final hay = [
          n.title,
          if (n.detail != null) n.detail!,
          if (n.location != null) n.location!,
        ].join(' ').toLowerCase();
        if (hay.contains(query)) {
          hits.add(_SearchHit(ky, km, kd, n));
        }
      }
    });
    // Newest first by Gregorian date
    hits.sort((a, b) {
      final ga = KemeticMath.toGregorian(a.ky, a.km, a.kd);
      final gb = KemeticMath.toGregorian(b.ky, b.km, b.kd);
      return gb.compareTo(ga);
    });
    return hits;
  }

  String _fmtTime(_Note n) {
    if (n.allDay) return 'All-day';
    String f(TimeOfDay t) {
      final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
      final m = t.minute.toString().padLeft(2, '0');
      final ap = t.period == DayPeriod.am ? 'AM' : 'PM';
      return '$h:$m $ap';
    }

    if (n.start != null && n.end != null) return '${f(n.start!)} – ${f(n.end!)}';
    if (n.start != null) return f(n.start!);
    if (n.end != null) return '… – ${f(n.end!)}';
    return '';
  }

  @override
  String get searchFieldLabel => 'Search events…';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF111215)),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: _silver),
      ),
      textTheme: base.textTheme.apply(bodyColor: _silver, displayColor: _silver),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: 'Clear',
        icon: const Icon(Icons.clear, color: _silver),
        onPressed: () => query = '',
      )
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    tooltip: 'Back',
    icon: const Icon(Icons.arrow_back, color: _silver),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final results = _search(query);
    if (results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('No matching events', style: TextStyle(color: _silver)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.length,
      separatorBuilder: (_, __) =>
      const Divider(height: 1, color: Colors.white12),
      itemBuilder: (ctx, i) {
        final h = results[i];
        final g = KemeticMath.toGregorian(h.ky, h.km, h.kd);
        final subParts = <String>[
          '${monthName(h.km)} ${h.kd} • ${gregYearLabelFor(h.ky, h.km)}',
          if (_fmtTime(h.note).isNotEmpty) _fmtTime(h.note),
          if ((h.note.location?.isNotEmpty ?? false)) h.note.location!,
          'Greg: ${g.year}-${g.month.toString().padLeft(2, '0')}-${g.day.toString().padLeft(2, '0')}',
        ];
        final subtitle = subParts.join('\n');

        return ListTile(
          title: const Text('', style: TextStyle(color: Colors.white)),
          // show the real title:
          titleTextStyle: const TextStyle(color: Colors.white),
          subtitle: Text(subtitle, style: const TextStyle(color: _silver)),
          // workaround for titleTextStyle: set in "title" directly
          // (older SDKs ignore titleTextStyle)
          trailing: const SizedBox.shrink(),
          onTap: () {
            close(context, null);
            openDay(h.ky, h.km, h.kd);
          },
        );
      },
    );
  }
}

/* ───────────── tiny note model ───────────── */

class _Note {
  final String title;
  final String? detail;
  final String? location;
  final bool allDay;
  final TimeOfDay? start;
  final TimeOfDay? end;

  _Note({
    required this.title,
    this.detail,
    this.location,
    this.allDay = false,
    this.start,
    this.end,
  });
}
