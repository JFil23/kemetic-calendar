part of 'calendar_page.dart';

enum _DetailSheetEndAction { flow, reminder, note, none }

/* ───────────── Year Section (12 months + epagomenal) ───────────── */

class _YearSection extends StatelessWidget {
  const _YearSection({
    required this.kYear,
    required this.todayMonth,
    required this.todayDay,
    required this.notesGetter,
    required this.flowColorsGetter,
    required this.onDayTap,
    required this.showGregorian,
    this.expansionLevel = MonthExpansionLevel.compact,
    this.noteColorResolver = _defaultNoteColor,
    this.flowNameGetter,
    this.onManageFlows,
    this.onEditNote,
    this.onDeleteNote,
    this.onShareNote,
    this.onEditReminder,
    this.onEndReminder,
    this.onShareReminder,
    this.onEndFlow,
    this.onAppendToJournal,
    this.monthAnchorKeyProvider,
    this.monthHeaderKeyProvider,
    this.dayAnchorKeyProvider,
    this.onMonthHeaderTap,
    this.onDecanTap,
    this.todayDayKey,
  });

  final int kYear;
  final int? todayMonth;
  final int? todayDay;
  final bool showGregorian;
  final MonthExpansionLevel expansionLevel;
  final Color Function(_Note) noteColorResolver;
  final String? Function(_Note)? flowNameGetter;
  final void Function(int?)? onManageFlows;
  final Future<void> Function(int kYear, int kMonth, int kDay, EventItem event)?
  onEditNote;
  final Future<void> Function(int kYear, int kMonth, int kDay, EventItem event)?
  onDeleteNote;
  final Future<void> Function(EventItem event)? onShareNote;
  final Future<void> Function(String reminderId)? onEditReminder;
  final Future<void> Function(String reminderId)? onEndReminder;
  final Future<void> Function(EventItem event)? onShareReminder;
  final void Function(int flowId)? onEndFlow;
  final Future<void> Function(String text)? onAppendToJournal;

  // existing notes
  final List<_Note> Function(int kMonth, int kDay) notesGetter;
  final List<Color> Function(int kYear, int kMonth, int kDay) flowColorsGetter;

  final void Function(BuildContext context, int kMonth)? onMonthHeaderTap;
  final void Function(BuildContext context, int kMonth, int decanIndex)?
  onDecanTap;
  final void Function(BuildContext, int kMonth, int kDay) onDayTap;
  final Key? Function(int kMonth)? monthAnchorKeyProvider;
  final Key? Function(int kMonth)? monthHeaderKeyProvider;
  final Key? Function(int kMonth, int kDay)? dayAnchorKeyProvider;
  final Key? todayDayKey; // 🔑

  @override
  Widget build(BuildContext context) {
    final (tm, td) = (todayMonth, todayDay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SeasonHeader(title: 'Flood season (Akhet)'),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(1),
          monthHeaderKey: monthHeaderKeyProvider?.call(1),
          dayAnchorKeyProvider: dayAnchorKeyProvider,
          kYear: kYear,
          kMonth: 1,
          seasonShort: 'Akhet',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowColorsGetter: flowColorsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
          expansionLevel: expansionLevel,
          noteColorResolver: noteColorResolver,
          flowNameGetter: flowNameGetter,
          onManageFlows: onManageFlows,
          onEditNote: onEditNote,
          onDeleteNote: onDeleteNote,
          onShareNote: onShareNote,
          onEditReminder: onEditReminder,
          onEndReminder: onEndReminder,
          onShareReminder: onShareReminder,
          onEndFlow: onEndFlow,
          onAppendToJournal: onAppendToJournal,
          onMonthHeaderTap: onMonthHeaderTap == null
              ? null
              : (context) => onMonthHeaderTap!(context, 1),
          onDecanTap: onDecanTap == null
              ? null
              : (context, decanIndex) => onDecanTap!(context, 1, decanIndex),
        ),
        const _GoldDivider(),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(2),
          monthHeaderKey: monthHeaderKeyProvider?.call(2),
          dayAnchorKeyProvider: dayAnchorKeyProvider,
          kYear: kYear,
          kMonth: 2,
          seasonShort: 'Akhet',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowColorsGetter: flowColorsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
          expansionLevel: expansionLevel,
          noteColorResolver: noteColorResolver,
          flowNameGetter: flowNameGetter,
          onManageFlows: onManageFlows,
          onEditNote: onEditNote,
          onDeleteNote: onDeleteNote,
          onShareNote: onShareNote,
          onEditReminder: onEditReminder,
          onEndReminder: onEndReminder,
          onShareReminder: onShareReminder,
          onEndFlow: onEndFlow,
          onAppendToJournal: onAppendToJournal,
          onMonthHeaderTap: onMonthHeaderTap == null
              ? null
              : (context) => onMonthHeaderTap!(context, 2),
          onDecanTap: onDecanTap == null
              ? null
              : (context, decanIndex) => onDecanTap!(context, 2, decanIndex),
        ),
        const _GoldDivider(),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(3),
          monthHeaderKey: monthHeaderKeyProvider?.call(3),
          dayAnchorKeyProvider: dayAnchorKeyProvider,
          kYear: kYear,
          kMonth: 3,
          seasonShort: 'Akhet',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowColorsGetter: flowColorsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
          expansionLevel: expansionLevel,
          noteColorResolver: noteColorResolver,
          flowNameGetter: flowNameGetter,
          onManageFlows: onManageFlows,
          onEditNote: onEditNote,
          onDeleteNote: onDeleteNote,
          onShareNote: onShareNote,
          onEditReminder: onEditReminder,
          onEndReminder: onEndReminder,
          onShareReminder: onShareReminder,
          onEndFlow: onEndFlow,
          onAppendToJournal: onAppendToJournal,
          onMonthHeaderTap: onMonthHeaderTap == null
              ? null
              : (context) => onMonthHeaderTap!(context, 3),
          onDecanTap: onDecanTap == null
              ? null
              : (context, decanIndex) => onDecanTap!(context, 3, decanIndex),
        ),
        const _GoldDivider(),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(4),
          monthHeaderKey: monthHeaderKeyProvider?.call(4),
          dayAnchorKeyProvider: dayAnchorKeyProvider,
          kYear: kYear,
          kMonth: 4,
          seasonShort: 'Akhet',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowColorsGetter: flowColorsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
          expansionLevel: expansionLevel,
          noteColorResolver: noteColorResolver,
          flowNameGetter: flowNameGetter,
          onManageFlows: onManageFlows,
          onEditNote: onEditNote,
          onDeleteNote: onDeleteNote,
          onShareNote: onShareNote,
          onEditReminder: onEditReminder,
          onEndReminder: onEndReminder,
          onShareReminder: onShareReminder,
          onEndFlow: onEndFlow,
          onAppendToJournal: onAppendToJournal,
          onMonthHeaderTap: onMonthHeaderTap == null
              ? null
              : (context) => onMonthHeaderTap!(context, 4),
          onDecanTap: onDecanTap == null
              ? null
              : (context, decanIndex) => onDecanTap!(context, 4, decanIndex),
        ),
        const _GoldDivider(),

        const _SeasonHeader(title: 'Emergence season (Peret)'),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(5),
          monthHeaderKey: monthHeaderKeyProvider?.call(5),
          dayAnchorKeyProvider: dayAnchorKeyProvider,
          kYear: kYear,
          kMonth: 5,
          seasonShort: 'Peret',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowColorsGetter: flowColorsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
          expansionLevel: expansionLevel,
          noteColorResolver: noteColorResolver,
          flowNameGetter: flowNameGetter,
          onManageFlows: onManageFlows,
          onEditNote: onEditNote,
          onDeleteNote: onDeleteNote,
          onShareNote: onShareNote,
          onEditReminder: onEditReminder,
          onEndReminder: onEndReminder,
          onShareReminder: onShareReminder,
          onEndFlow: onEndFlow,
          onAppendToJournal: onAppendToJournal,
          onMonthHeaderTap: onMonthHeaderTap == null
              ? null
              : (context) => onMonthHeaderTap!(context, 5),
          onDecanTap: onDecanTap == null
              ? null
              : (context, decanIndex) => onDecanTap!(context, 5, decanIndex),
        ),
        const _GoldDivider(),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(6),
          monthHeaderKey: monthHeaderKeyProvider?.call(6),
          dayAnchorKeyProvider: dayAnchorKeyProvider,
          kYear: kYear,
          kMonth: 6,
          seasonShort: 'Peret',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowColorsGetter: flowColorsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
          expansionLevel: expansionLevel,
          noteColorResolver: noteColorResolver,
          flowNameGetter: flowNameGetter,
          onManageFlows: onManageFlows,
          onEditNote: onEditNote,
          onDeleteNote: onDeleteNote,
          onShareNote: onShareNote,
          onEditReminder: onEditReminder,
          onEndReminder: onEndReminder,
          onShareReminder: onShareReminder,
          onEndFlow: onEndFlow,
          onAppendToJournal: onAppendToJournal,
          onMonthHeaderTap: onMonthHeaderTap == null
              ? null
              : (context) => onMonthHeaderTap!(context, 6),
          onDecanTap: onDecanTap == null
              ? null
              : (context, decanIndex) => onDecanTap!(context, 6, decanIndex),
        ),
        const _GoldDivider(),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(7),
          monthHeaderKey: monthHeaderKeyProvider?.call(7),
          dayAnchorKeyProvider: dayAnchorKeyProvider,
          kYear: kYear,
          kMonth: 7,
          seasonShort: 'Peret',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowColorsGetter: flowColorsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
          expansionLevel: expansionLevel,
          noteColorResolver: noteColorResolver,
          flowNameGetter: flowNameGetter,
          onManageFlows: onManageFlows,
          onEditNote: onEditNote,
          onDeleteNote: onDeleteNote,
          onShareNote: onShareNote,
          onEditReminder: onEditReminder,
          onEndReminder: onEndReminder,
          onShareReminder: onShareReminder,
          onEndFlow: onEndFlow,
          onAppendToJournal: onAppendToJournal,
          onMonthHeaderTap: onMonthHeaderTap == null
              ? null
              : (context) => onMonthHeaderTap!(context, 7),
          onDecanTap: onDecanTap == null
              ? null
              : (context, decanIndex) => onDecanTap!(context, 7, decanIndex),
        ),
        const _GoldDivider(),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(8),
          monthHeaderKey: monthHeaderKeyProvider?.call(8),
          dayAnchorKeyProvider: dayAnchorKeyProvider,
          kYear: kYear,
          kMonth: 8,
          seasonShort: 'Peret',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowColorsGetter: flowColorsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
          expansionLevel: expansionLevel,
          noteColorResolver: noteColorResolver,
          flowNameGetter: flowNameGetter,
          onManageFlows: onManageFlows,
          onEditNote: onEditNote,
          onDeleteNote: onDeleteNote,
          onShareNote: onShareNote,
          onEditReminder: onEditReminder,
          onEndReminder: onEndReminder,
          onShareReminder: onShareReminder,
          onEndFlow: onEndFlow,
          onAppendToJournal: onAppendToJournal,
          onMonthHeaderTap: onMonthHeaderTap == null
              ? null
              : (context) => onMonthHeaderTap!(context, 8),
          onDecanTap: onDecanTap == null
              ? null
              : (context, decanIndex) => onDecanTap!(context, 8, decanIndex),
        ),
        const _GoldDivider(),

        const _SeasonHeader(title: 'Harvest season (Shemu)'),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(9),
          monthHeaderKey: monthHeaderKeyProvider?.call(9),
          dayAnchorKeyProvider: dayAnchorKeyProvider,
          kYear: kYear,
          kMonth: 9,
          seasonShort: 'Shemu',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowColorsGetter: flowColorsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
          expansionLevel: expansionLevel,
          noteColorResolver: noteColorResolver,
          flowNameGetter: flowNameGetter,
          onManageFlows: onManageFlows,
          onEditNote: onEditNote,
          onDeleteNote: onDeleteNote,
          onShareNote: onShareNote,
          onEditReminder: onEditReminder,
          onEndReminder: onEndReminder,
          onShareReminder: onShareReminder,
          onEndFlow: onEndFlow,
          onAppendToJournal: onAppendToJournal,
          onMonthHeaderTap: onMonthHeaderTap == null
              ? null
              : (context) => onMonthHeaderTap!(context, 9),
          onDecanTap: onDecanTap == null
              ? null
              : (context, decanIndex) => onDecanTap!(context, 9, decanIndex),
        ),
        const _GoldDivider(),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(10),
          monthHeaderKey: monthHeaderKeyProvider?.call(10),
          dayAnchorKeyProvider: dayAnchorKeyProvider,
          kYear: kYear,
          kMonth: 10,
          seasonShort: 'Shemu',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowColorsGetter: flowColorsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
          expansionLevel: expansionLevel,
          noteColorResolver: noteColorResolver,
          flowNameGetter: flowNameGetter,
          onManageFlows: onManageFlows,
          onEditNote: onEditNote,
          onDeleteNote: onDeleteNote,
          onShareNote: onShareNote,
          onEditReminder: onEditReminder,
          onEndReminder: onEndReminder,
          onShareReminder: onShareReminder,
          onEndFlow: onEndFlow,
          onAppendToJournal: onAppendToJournal,
          onMonthHeaderTap: onMonthHeaderTap == null
              ? null
              : (context) => onMonthHeaderTap!(context, 10),
          onDecanTap: onDecanTap == null
              ? null
              : (context, decanIndex) => onDecanTap!(context, 10, decanIndex),
        ),
        const _GoldDivider(),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(11),
          monthHeaderKey: monthHeaderKeyProvider?.call(11),
          dayAnchorKeyProvider: dayAnchorKeyProvider,
          kYear: kYear,
          kMonth: 11,
          seasonShort: 'Shemu',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowColorsGetter: flowColorsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
          expansionLevel: expansionLevel,
          noteColorResolver: noteColorResolver,
          flowNameGetter: flowNameGetter,
          onManageFlows: onManageFlows,
          onEditNote: onEditNote,
          onDeleteNote: onDeleteNote,
          onShareNote: onShareNote,
          onEditReminder: onEditReminder,
          onEndReminder: onEndReminder,
          onShareReminder: onShareReminder,
          onEndFlow: onEndFlow,
          onAppendToJournal: onAppendToJournal,
          onMonthHeaderTap: onMonthHeaderTap == null
              ? null
              : (context) => onMonthHeaderTap!(context, 11),
          onDecanTap: onDecanTap == null
              ? null
              : (context, decanIndex) => onDecanTap!(context, 11, decanIndex),
        ),
        const _GoldDivider(),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(12),
          monthHeaderKey: monthHeaderKeyProvider?.call(12),
          dayAnchorKeyProvider: dayAnchorKeyProvider,
          kYear: kYear,
          kMonth: 12,
          seasonShort: 'Shemu',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          flowColorsGetter: flowColorsGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
          expansionLevel: expansionLevel,
          noteColorResolver: noteColorResolver,
          flowNameGetter: flowNameGetter,
          onManageFlows: onManageFlows,
          onEditNote: onEditNote,
          onDeleteNote: onDeleteNote,
          onShareNote: onShareNote,
          onEditReminder: onEditReminder,
          onEndReminder: onEndReminder,
          onShareReminder: onShareReminder,
          onEndFlow: onEndFlow,
          onAppendToJournal: onAppendToJournal,
          onMonthHeaderTap: onMonthHeaderTap == null
              ? null
              : (context) => onMonthHeaderTap!(context, 12),
          onDecanTap: onDecanTap == null
              ? null
              : (context, decanIndex) => onDecanTap!(context, 12, decanIndex),
        ),
        const _GoldDivider(),

        _EpagomenalCard(
          kYear: kYear,
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: (m, d) => notesGetter(13, d),
          flowColorsGetter: flowColorsGetter,
          onDayTap: (c, m, d) => onDayTap(c, 13, d),
          showGregorian: showGregorian,
          expansionLevel: expansionLevel,
          noteColorResolver: noteColorResolver,
          flowNameGetter: flowNameGetter,
          onManageFlows: onManageFlows,
          onEditNote: onEditNote,
          onDeleteNote: onDeleteNote,
          onShareNote: onShareNote,
          onEditReminder: onEditReminder,
          onEndReminder: onEndReminder,
          onShareReminder: onShareReminder,
          onEndFlow: onEndFlow,
          onAppendToJournal: onAppendToJournal,
        ),
        const _GoldDivider(),
      ],
    );
  }
}

/* ───────────────────────── Month & Day Cards ───────────────────────── */

class _MonthCard extends StatelessWidget {
  final Key? anchorKey;
  final Key? monthHeaderKey;
  final Key? Function(int kMonth, int kDay)? dayAnchorKeyProvider;
  final int kYear;
  final int kMonth; // 1..12
  final String seasonShort; // Akhet/Peret/Shemu
  final int? todayMonth;
  final int? todayDay;
  final Key? todayDayKey; // 🔑 day anchor to center
  final bool showGregorian;
  final MonthExpansionLevel expansionLevel;

  final List<_Note> Function(int kMonth, int kDay) notesGetter;
  final List<Color> Function(int kYear, int kMonth, int kDay) flowColorsGetter;
  final void Function(BuildContext, int kMonth, int kDay) onDayTap;
  final Color Function(_Note) noteColorResolver;
  final String? Function(_Note)? flowNameGetter;
  final void Function(int?)? onManageFlows;
  final Future<void> Function(int kYear, int kMonth, int kDay, EventItem event)?
  onEditNote;
  final Future<void> Function(int kYear, int kMonth, int kDay, EventItem event)?
  onDeleteNote;
  final Future<void> Function(EventItem event)? onShareNote;
  final Future<void> Function(String reminderId)? onEditReminder;
  final Future<void> Function(String reminderId)? onEndReminder;
  final Future<void> Function(EventItem event)? onShareReminder;
  final void Function(int flowId)? onEndFlow;
  final Future<void> Function(String text)? onAppendToJournal;

  // Optional overrides for taps (used by the detail page)
  final void Function(BuildContext context)? onMonthHeaderTap;
  final void Function(BuildContext context, int decanIndex)? onDecanTap;

  const _MonthCard({
    this.anchorKey,
    this.monthHeaderKey,
    this.dayAnchorKeyProvider,
    required this.kYear,
    required this.kMonth,
    required this.seasonShort,
    required this.todayMonth,
    required this.todayDay,
    required this.notesGetter,
    required this.flowColorsGetter,
    required this.onDayTap,
    required this.showGregorian,
    this.expansionLevel = MonthExpansionLevel.compact,
    this.noteColorResolver = _defaultNoteColor,
    this.flowNameGetter,
    this.onManageFlows,
    this.onEditNote,
    this.onDeleteNote,
    this.onShareNote,
    this.onEditReminder,
    this.onEndReminder,
    this.onShareReminder,
    this.onEndFlow,
    this.onAppendToJournal,
    this.todayDayKey,
    this.onMonthHeaderTap,
    this.onDecanTap,
  });

  // monthNames removed - use getMonthById(kMonth).displayFull instead

  String? _gregLabelForDecanRow(int ky, int km, int decanIndex) {
    final start = decanIndex * 10 + 1;
    final end = start + 9;
    for (int d = start; d <= end; d++) {
      final g = KemeticMath.toGregorian(ky, km, d);
      if (g.day == 1) {
        return _gregMonthNames[g.month];
      }
    }
    return null;
  }

  void _openMonthInfo(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MonthDetailPage(
          kYear: kYear,
          kMonth: kMonth,
          todayMonth: todayMonth,
          todayDay: todayDay,
          showGregorian: showGregorian,
          notesGetter: notesGetter,
          flowColorsGetter: flowColorsGetter,
          onDayTap: onDayTap,
          noteColorResolver: noteColorResolver,
          flowNameGetter: flowNameGetter,
          onManageFlows: onManageFlows,
          onEditNote: onEditNote,
          onDeleteNote: onDeleteNote,
          onShareNote: onShareNote,
          onEditReminder: onEditReminder,
          onEndReminder: onEndReminder,
          onShareReminder: onShareReminder,
          onEndFlow: onEndFlow,
          onAppendToJournal: onAppendToJournal,
          decanIndex: null,
        ),
      ),
    );
  }

  void _openDecanInfo(BuildContext context, int decanIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MonthDetailPage(
          kYear: kYear,
          kMonth: kMonth,
          todayMonth: todayMonth,
          todayDay: todayDay,
          showGregorian: showGregorian,
          notesGetter: notesGetter,
          flowColorsGetter: flowColorsGetter,
          onDayTap: onDayTap,
          noteColorResolver: noteColorResolver,
          flowNameGetter: flowNameGetter,
          onManageFlows: onManageFlows,
          onEditNote: onEditNote,
          onDeleteNote: onDeleteNote,
          onShareNote: onShareNote,
          onEditReminder: onEditReminder,
          onEndReminder: onEndReminder,
          onShareReminder: onShareReminder,
          onEndFlow: onEndFlow,
          onAppendToJournal: onAppendToJournal,
          decanIndex: decanIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final names =
        DecanMetadata.decanNames[kMonth] ??
        const ['Decan A', 'Decan B', 'Decan C'];
    final currentDecanIndex = todayMonth == kMonth && todayDay != null
        ? decanForDay(todayDay!) - 1
        : null;

    double decanHeightFor(int decanIndex) {
      // Only adjust in details mode; otherwise use the global sizing.
      if (expansionLevel != MonthExpansionLevel.details) {
        return _chipHeightFor(expansionLevel);
      }
      // Estimate visible pills for this decan (capped at 5) and derive a height.
      // Measurements: label area ~24px; first pill ~50px; subsequent pills ~56px (includes spacing).
      const double labelAreaHeight = 24.0;
      const double firstPillHeight = 50.0;
      const double subsequentPillHeight = 56.0;
      const double minHeight =
          80.0; // keep some presence for empty/one-pill decans
      const double maxHeight = 250.0; // cap at original height

      final startDay = decanIndex * 10 + 1;
      int maxVisible = 0;
      for (int d = startDay; d < startDay + 10; d++) {
        final notes = notesGetter(kMonth, d);
        final visible = notes.length > 5 ? 5 : notes.length;
        if (visible > maxVisible) maxVisible = visible;
      }

      double pillsHeight = 0.0;
      if (maxVisible > 0) {
        pillsHeight = firstPillHeight;
        if (maxVisible > 1) {
          pillsHeight += subsequentPillHeight * (maxVisible - 1);
        }
      }

      final double estimated = labelAreaHeight + pillsHeight;
      return estimated.clamp(minHeight, maxHeight);
    }

    final decanHeights = List<double>.generate(3, (i) => decanHeightFor(i));

    final yStart = KemeticMath.toGregorian(kYear, kMonth, 1).year;
    final yEnd = KemeticMath.toGregorian(kYear, kMonth, 30).year;
    final rightLabel = (yStart == yEnd)
        ? '$seasonShort $yStart'
        : '$seasonShort $yStart/$yEnd';

    final isMonthToday = (todayMonth != null && todayMonth == kMonth);
    final gapBeforeRow = expansionLevel == MonthExpansionLevel.details
        ? 0.0
        : 6.0;

    return Padding(
      key: anchorKey,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: Card(
        color: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.none, // avoids unnecessary AA clip
        shape: RoundedRectangleBorder(
          side: BorderSide.none,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Kemetic month name (left), Season+Year (right)
                Row(
                  children: [
                    RepaintBoundary(
                      key: monthHeaderKey,
                      child: GestureDetector(
                        onTap: () {
                          if (onMonthHeaderTap != null) {
                            onMonthHeaderTap!(context);
                          } else {
                            _openMonthInfo(context);
                          }
                        },
                        child: _GlossyMonthNameText(
                          text: getMonthById(kMonth).displayFull,
                          style:
                              _monthTitleGold, // MonthNameText handles font families
                          gradient: goldGloss,
                        ),
                      ),
                    ),
                    const Spacer(),
                    RepaintBoundary(
                      child: Text(
                        rightLabel,
                        style: _neutralOnBlack.copyWith(
                          fontFamilyFallback: const [
                            'NotoSans',
                            'Roboto',
                            'Arial',
                            'sans-serif',
                          ],
                          letterSpacing: 0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Three decans
                for (var i = 0; i < 3; i++) ...[
                  // Label row: decan on left (Kemetic), Gregorian month on right when needed
                  Row(
                    children: [
                      // Kemetic decan name
                      Expanded(
                        child: Visibility(
                          visible: !showGregorian,
                          maintainState: true,
                          maintainAnimation: true,
                          maintainSize: true,
                          child: KeyedSubtree(
                            key: currentDecanIndex == i
                                ? keyForCurrentDecanHeader(kYear, kMonth, i)
                                : null,
                            child: GestureDetector(
                              onTap: () {
                                if (onDecanTap != null) {
                                  onDecanTap!(context, i);
                                } else {
                                  _openDecanInfo(context, i);
                                }
                              },
                              child: GlossyText(
                                text: names[i],
                                style: _decanStyle,
                                gradient: silverGloss,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Gregorian month name right-aligned (only when needed)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Visibility(
                            visible:
                                showGregorian &&
                                _gregLabelForDecanRow(kYear, kMonth, i) != null,
                            maintainState: true,
                            maintainAnimation: true,
                            maintainSize: true,
                            child: GlossyText(
                              text:
                                  _gregLabelForDecanRow(kYear, kMonth, i) ?? '',
                              style: _decanStyle,
                              gradient: blueGloss,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: gapBeforeRow),
                  _WeekdayRow(
                    kYear: kYear,
                    kMonth: kMonth,
                    decanIndex: i,
                    showGregorian: showGregorian,
                  ),
                  const SizedBox(height: 4),

                  _DecanRow(
                    kYear: kYear,
                    kMonth: kMonth,
                    decanIndex: i,
                    todayMonth: todayMonth,
                    todayDay: todayDay,
                    todayDayKey: isMonthToday ? todayDayKey : null,
                    highlightDayKeyProvider: dayAnchorKeyProvider,
                    notesGetter: notesGetter,
                    flowColorsGetter: flowColorsGetter,
                    onDayTap: onDayTap,
                    showGregorian: showGregorian,
                    expansionLevel: expansionLevel,
                    noteColorResolver: noteColorResolver,
                    flowNameGetter: flowNameGetter,
                    decanHeight: decanHeights[i],
                    onManageFlows: onManageFlows,
                    onEditNote: onEditNote,
                    onDeleteNote: onDeleteNote,
                    onShareNote: onShareNote,
                    onEditReminder: onEditReminder,
                    onEndReminder: onEndReminder,
                    onShareReminder: onShareReminder,
                    onEndFlow: onEndFlow,
                    onAppendToJournal: onAppendToJournal,
                  ),
                  if (i < 2) SizedBox(height: gapBeforeRow),
                ],
              ],
            ),
          ),
        ),
      ), // Close Card
    ); // Close Padding and return
  }
}

/// Helper function to generate Kemetic day keys for the info dropdown
String _getKemeticDayKey(int kYear, int kMonth, int kDay) {
  // Use stable keys from metadata

  // Safety fallback if somehow we're out of normal 1–13 range
  if (kMonth < 1 || kMonth > 13) {
    return 'unknown_${kDay}_$kYear';
  }

  // final key format must match kemetic_day_info.dart exactly
  // e.g. thoth_11_2
  return kemeticDayKey(kMonth, kDay);
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({
    required this.kYear,
    required this.kMonth,
    required this.decanIndex,
    required this.showGregorian,
  });

  final int kYear;
  final int kMonth;
  final int decanIndex; // 0..2
  final bool showGregorian;

  static const List<String> _weekdayLetters = [
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  @override
  Widget build(BuildContext context) {
    final labels = List<String>.generate(10, (i) {
      final day = decanIndex * 10 + i + 1;
      final gregorian = safeLocalDisplay(
        KemeticMath.toGregorian(kYear, kMonth, day),
      );
      final idx = gregorian.weekday - 1; // Monday = 1
      return _weekdayLetters[idx];
    });

    return Row(
      children: [
        for (int i = 0; i < labels.length; i++) ...[
          Expanded(
            child: Center(
              child: Text(
                labels[i],
                style: _weekdayLabelStyle.copyWith(
                  color: showGregorian ? _blueLight : _goldLight,
                ),
              ),
            ),
          ),
          if (i < labels.length - 1) const SizedBox(width: 3),
        ],
      ],
    );
  }
}

class _DecanRow extends StatelessWidget {
  final int kYear; // to compute Gregorian numbers
  final int kMonth; // 1..12
  final int decanIndex; // 0..2
  final int? todayMonth;
  final int? todayDay;
  final Key? todayDayKey;
  final Key? Function(int kMonth, int kDay)? highlightDayKeyProvider;
  final bool showGregorian;

  final List<_Note> Function(int kMonth, int kDay) notesGetter;
  final List<Color> Function(int kYear, int kMonth, int kDay) flowColorsGetter;
  final void Function(BuildContext, int kMonth, int kDay) onDayTap;
  final MonthExpansionLevel expansionLevel;
  final Color Function(_Note) noteColorResolver;
  final double? decanHeight;
  final String? Function(_Note)? flowNameGetter;
  final void Function(int?)? onManageFlows;
  final Future<void> Function(int kYear, int kMonth, int kDay, EventItem event)?
  onEditNote;
  final Future<void> Function(int kYear, int kMonth, int kDay, EventItem event)?
  onDeleteNote;
  final Future<void> Function(EventItem event)? onShareNote;
  final Future<void> Function(String reminderId)? onEditReminder;
  final Future<void> Function(String reminderId)? onEndReminder;
  final Future<void> Function(EventItem event)? onShareReminder;
  final void Function(int flowId)? onEndFlow;
  final Future<void> Function(String text)? onAppendToJournal;

  const _DecanRow({
    required this.kYear,
    required this.kMonth,
    required this.decanIndex,
    required this.todayMonth,
    required this.todayDay,
    required this.notesGetter,
    required this.flowColorsGetter,
    required this.onDayTap,
    required this.showGregorian,
    required this.todayDayKey,
    this.highlightDayKeyProvider,
    this.expansionLevel = MonthExpansionLevel.compact,
    this.noteColorResolver = _defaultNoteColor,
    this.decanHeight,
    this.flowNameGetter,
    this.onManageFlows,
    this.onEditNote,
    this.onDeleteNote,
    this.onShareNote,
    this.onEditReminder,
    this.onEndReminder,
    this.onShareReminder,
    this.onEndFlow,
    this.onAppendToJournal,
  });

  @override
  Widget build(BuildContext context) {
    final isMonthToday = (todayMonth != null && todayMonth == kMonth);
    return Row(
      children: [
        for (int j = 0; j < 10; j++) ...[
          Builder(
            builder: (_) {
              final day = decanIndex * 10 + (j + 1); // 1..30
              final isToday = isMonthToday && (todayDay == day);

              final notes = notesGetter(kMonth, day);
              final flowColors = flowColorsGetter(kYear, kMonth, day);

              final label = showGregorian
                  ? '${safeLocalDisplay(KemeticMath.toGregorian(kYear, kMonth, day)).day}'
                  : '$day';

              return Expanded(
                child: _DayChip(
                  key: ValueKey(
                    'k:$kYear-$kMonth-$day|${showGregorian ? "G" : "K"}',
                  ), // 🔑 Unique key with mode
                  anchorKey: isToday ? todayDayKey : null, // 🔑 attach
                  highlightAnchorKey: highlightDayKeyProvider?.call(
                    kMonth,
                    day,
                  ),
                  label: label,
                  isToday: isToday,
                  notes: notes,
                  flowColors: flowColors,
                  onTap: () => onDayTap(context, kMonth, day),
                  showGregorian: showGregorian,
                  dayKey: _getKemeticDayKey(kYear, kMonth, day),
                  expansionLevel: expansionLevel,
                  noteColorResolver: noteColorResolver,
                  flowNameGetter: flowNameGetter,
                  decanHeight: decanHeight,
                  kYear: kYear,
                  kMonth: kMonth,
                  kDay: day,
                  onManageFlows: onManageFlows,
                  onEditNote: onEditNote,
                  onDeleteNote: onDeleteNote,
                  onShareNote: onShareNote,
                  onEditReminder: onEditReminder,
                  onEndReminder: onEndReminder,
                  onShareReminder: onShareReminder,
                  onEndFlow: onEndFlow,
                  onAppendToJournal: onAppendToJournal,
                ),
              );
            },
          ),
          if (j < 9) const SizedBox(width: 3),
        ],
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool isToday;
  final List<_Note> notes;
  final List<Color> flowColors;
  final VoidCallback onTap;
  final Key? anchorKey;
  final Key? highlightAnchorKey;
  final bool showGregorian;
  final String dayKey;
  final MonthExpansionLevel expansionLevel;
  final Color Function(_Note) noteColorResolver;
  final String? Function(_Note)? flowNameGetter;
  final double? decanHeight;
  final int kYear;
  final int kMonth;
  final int kDay;
  final void Function(int?)? onManageFlows;
  final Future<void> Function(int kYear, int kMonth, int kDay, EventItem event)?
  onEditNote;
  final Future<void> Function(int kYear, int kMonth, int kDay, EventItem event)?
  onDeleteNote;
  final Future<void> Function(EventItem event)? onShareNote;
  final Future<void> Function(String reminderId)? onEditReminder;
  final Future<void> Function(String reminderId)? onEndReminder;
  final Future<void> Function(EventItem event)? onShareReminder;
  final void Function(int flowId)? onEndFlow;
  final Future<void> Function(String text)? onAppendToJournal;

  const _DayChip({
    super.key, // Add key parameter
    required this.label,
    required this.isToday,
    required this.notes,
    required this.flowColors,
    required this.onTap,
    required this.showGregorian,
    this.anchorKey,
    this.highlightAnchorKey,
    required this.dayKey,
    required this.expansionLevel,
    required this.noteColorResolver,
    this.flowNameGetter,
    this.decanHeight,
    required this.kYear,
    required this.kMonth,
    required this.kDay,
    this.onManageFlows,
    this.onEditNote,
    this.onDeleteNote,
    this.onShareNote,
    this.onEditReminder,
    this.onEndReminder,
    this.onShareReminder,
    this.onEndFlow,
    this.onAppendToJournal,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w400,
      fontSize: 16.0, // <- round to whole px to avoid subpixel blur
      letterSpacing: 0.0, // <- reduce fuzz on CanvasKit
    );

    final gradient = isToday
        ? goldGloss
        : (showGregorian ? blueGloss : silverGloss);
    _Note? trackSkyHeaderNote;
    for (final note in notes) {
      if (_isTrackSkyFlowName(flowNameGetter?.call(note))) {
        trackSkyHeaderNote = note;
        break;
      }
    }
    final isCompact = expansionLevel == MonthExpansionLevel.compact;
    final chipHeight = decanHeight ?? _chipHeightFor(expansionLevel);
    final nonCompactHeaderHeight = 24.0;

    Widget buildMiniBlocksCompact({required double maxWidth}) {
      const spacing = 2.5;
      const maxMarkersCap = 3;
      const trackSkyMarkerWidth = 7.0;
      const colorDotWidth = 5.0;

      final double safeMaxWidth = maxWidth.isFinite
          ? (maxWidth > 1 ? maxWidth - 1 : 0)
          : 0;
      final noteCount = notes.length;
      final trackSkyNotes = notes
          .where((note) => _isTrackSkyFlowName(flowNameGetter?.call(note)))
          .toList();

      int fitCount(double itemWidth) {
        if (safeMaxWidth <= 0) return 0;
        return ((safeMaxWidth + spacing) / (itemWidth + spacing)).floor().clamp(
          0,
          maxMarkersCap,
        );
      }

      Widget buildRow<T>(List<T> items, Widget Function(T item) builder) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: spacing),
              builder(items[i]),
            ],
          ],
        );
      }

      if (trackSkyNotes.isNotEmpty) {
        // Compact month view only needs one sky signifier per day. Multiple
        // sky events on the same date should not stack duplicate moon glyphs.
        if (fitCount(trackSkyMarkerWidth) <= 0) return const SizedBox.shrink();
        return _TrackSkyMicroSignifier(note: trackSkyNotes.first);
      }

      // Show a single dot set: flow colors if present; otherwise a single silver dot when notes exist.
      if (flowColors.isNotEmpty) {
        final visibleFlowColors = flowColors
            .take(fitCount(colorDotWidth))
            .toList(growable: false);
        if (visibleFlowColors.isEmpty) return const SizedBox.shrink();
        return buildRow<Color>(
          visibleFlowColors,
          (color) => _ColorDot(color: color),
        );
      }

      if (noteCount > 0 && safeMaxWidth >= colorDotWidth) {
        return const _GlossyDot(gradient: silverGloss);
      }

      return const SizedBox.shrink();
    }

    Widget buildMiniBlocks({double? availableHeight}) {
      if (isCompact) {
        return const SizedBox.shrink();
      }

      final sorted = [...notes]
        ..sort((a, b) {
          if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
          final aStart = a.start;
          final bStart = b.start;
          if (aStart != null && bStart != null) {
            final cmpH = aStart.hour.compareTo(bStart.hour);
            if (cmpH != 0) return cmpH;
            final cmpM = aStart.minute.compareTo(bStart.minute);
            if (cmpM != 0) return cmpM;
          } else if (aStart != null || bStart != null) {
            return aStart != null ? -1 : 1;
          }
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
      final maxBlocks = expansionLevel == MonthExpansionLevel.stacked
          ? 2
          : (expansionLevel == MonthExpansionLevel.details ? 5 : 1);

      int visibleCount = maxBlocks;
      if (expansionLevel == MonthExpansionLevel.details &&
          availableHeight != null &&
          availableHeight.isFinite) {
        const double estimatedPillHeight = 40.0;
        const double spacingHeight = 6.0;
        const double overflowIndicatorHeight = 15.0;

        double used = 0;
        int count = 0;
        while (count < sorted.length && count < maxBlocks) {
          final next = estimatedPillHeight + (count == 0 ? 0 : spacingHeight);
          if (used + next > availableHeight) break;
          used += next;
          count++;
        }

        final hasHidden = count < sorted.length;
        if (hasHidden &&
            count > 0 &&
            used + overflowIndicatorHeight > availableHeight) {
          count = (count - 1).clamp(0, maxBlocks);
        }

        visibleCount = count.clamp(0, maxBlocks);
      }

      final visible = sorted.take(visibleCount).toList();
      final remaining = sorted.length - visible.length;

      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < visible.length; i++) ...[
            _MiniEventBlock(
              note: visible[i],
              color: noteColorResolver(visible[i]),
              isTrackSky: _isTrackSkyFlowName(flowNameGetter?.call(visible[i])),
              dense: expansionLevel == MonthExpansionLevel.stacked,
              label: expansionLevel == MonthExpansionLevel.details
                  ? _labelFor(visible[i])
                  : null,
              expand: expansionLevel == MonthExpansionLevel.details,
              onTap: expansionLevel == MonthExpansionLevel.details
                  ? () => _showEventDetailFromNote(context, visible[i])
                  : null,
            ),
            if (i != visible.length - 1)
              SizedBox(
                height: expansionLevel == MonthExpansionLevel.details ? 6 : 3,
              ),
          ],
          if (remaining > 0 && expansionLevel == MonthExpansionLevel.details)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '+$remaining',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      );
    }

    return KemeticDayButton(
      dayKey: dayKey,
      kYear: kYear,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          key: anchorKey,
          width: double.infinity,
          height: chipHeight,
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (highlightAnchorKey != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: KeyedSubtree(
                        key: highlightAnchorKey,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                if (isCompact)
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      GlossyText(
                        text: label,
                        style: textStyle,
                        gradient: gradient,
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                right: 4,
                                bottom: 4,
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final maxWidth = constraints.maxWidth.isFinite
                                      ? constraints.maxWidth
                                      : 0.0;
                                  return ClipRect(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: maxWidth,
                                      ),
                                      child: Align(
                                        alignment: Alignment.bottomRight,
                                        child: buildMiniBlocksCompact(
                                          maxWidth: maxWidth,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: nonCompactHeaderHeight,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final maxWidth = constraints.maxWidth.isFinite
                                ? constraints.maxWidth
                                : 0.0;
                            final canShowTrackSkyMotif =
                                trackSkyHeaderNote != null && maxWidth >= 14;
                            final motifWidth = canShowTrackSkyMotif
                                ? math.min(14.0, maxWidth * 0.4)
                                : 0.0;
                            final motifOffset = canShowTrackSkyMotif
                                ? (motifWidth / 2) + 1.5
                                : 0.0;
                            final motifOnLeftEdge = kDay % 10 == 0;
                            final motifSpec = trackSkyHeaderNote == null
                                ? null
                                : _trackSkyBadgeSpecForNote(trackSkyHeaderNote);

                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: nonCompactHeaderHeight,
                                  child: Center(
                                    child: GlossyText(
                                      text: label,
                                      style: textStyle,
                                      gradient: gradient,
                                    ),
                                  ),
                                ),
                                if (canShowTrackSkyMotif && motifSpec != null)
                                  Positioned(
                                    top: 10,
                                    left: motifOnLeftEdge ? -motifOffset : null,
                                    right: motifOnLeftEdge
                                        ? null
                                        : -motifOffset,
                                    child: IgnorePointer(
                                      child: SizedBox(
                                        width: motifWidth,
                                        height: 10,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Align(
                                              alignment: Alignment.topCenter,
                                              child: SizedBox(
                                                height: 6.2,
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment:
                                                      Alignment.topCenter,
                                                  child:
                                                      _buildTrackSkyBadgeMotif(
                                                        spec: motifSpec,
                                                        title:
                                                            trackSkyHeaderNote
                                                                .title,
                                                        dense: false,
                                                      ),
                                                ),
                                              ),
                                            ),
                                            Align(
                                              alignment: Alignment.bottomCenter,
                                              child: Container(
                                                height: 1.8,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      motifSpec.accentColor
                                                          .withValues(
                                                            alpha: 0.0,
                                                          ),
                                                      motifSpec.accentColor
                                                          .withValues(
                                                            alpha: 0.75,
                                                          ),
                                                      motifSpec
                                                          .secondaryAccentColor
                                                          .withValues(
                                                            alpha: 0.95,
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
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return ClipRect(
                              child: buildMiniBlocks(
                                availableHeight: constraints.maxHeight,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _labelFor(_Note note) {
    String short(String text, int max) {
      if (text.isEmpty) return '';
      return text.length <= max ? text : '${text.substring(0, max - 1)}…';
    }

    final flowNameRaw = flowNameGetter?.call(note);
    final flowName = (flowNameRaw != null && flowNameRaw.trim().isNotEmpty)
        ? flowNameRaw.trim()
        : null;
    final hasFlow = flowName != null;

    var titleRaw = note.title.trim();

    // Safety: if the title is just a time (even malformed), ignore it.
    final timePattern = RegExp(
      r'^\s*\d{1,2}\s*[:]\s*\d{0,2}(?:\s+\d+)?\s*(?:AM|PM|am|pm)?\s*$',
      caseSensitive: false,
    );
    if (timePattern.hasMatch(titleRaw)) {
      titleRaw = '';
    }

    final hasMeaningfulTitle = titleRaw.isNotEmpty && titleRaw != 'Event';

    // For details mode, show flow name + title (or just flow name, or just title). No time.
    if (expansionLevel == MonthExpansionLevel.details) {
      if (hasFlow) {
        if (hasMeaningfulTitle) {
          final title = short(titleRaw, 50);
          return '$flowName $title';
        } else {
          return flowName;
        }
      } else {
        if (hasMeaningfulTitle) {
          return short(titleRaw, 60);
        } else {
          return '';
        }
      }
    }

    // For non-details mode (stacked/compact), same logic
    if (hasFlow) {
      if (hasMeaningfulTitle) {
        final title = short(titleRaw, 50);
        return '$flowName $title';
      } else {
        return flowName;
      }
    }

    if (hasMeaningfulTitle) {
      return short(titleRaw, 60);
    } else {
      return '';
    }
  }

  EventItem _noteToEventItem(_Note note) {
    final startMin = note.allDay
        ? 9 * 60
        : (note.start?.hour ?? 9) * 60 + (note.start?.minute ?? 0);
    final endMin = note.allDay
        ? 17 * 60
        : (note.end?.hour ?? 17) * 60 + (note.end?.minute ?? 0);

    return EventItem(
      id: note.id,
      clientEventId: note.clientEventId,
      calendarId: note.calendarId,
      calendarName: note.calendarName,
      title: note.title,
      detail: note.detail,
      location: note.location,
      startMin: startMin,
      endMin: endMin,
      flowId: note.flowId,
      color: noteColorResolver(note),
      manualColor: note.manualColor,
      allDay: note.allDay,
      category: note.category,
      isReminder: note.isReminder,
      reminderId: note.reminderId,
    );
  }

  void _showEventDetailFromNote(BuildContext context, _Note note) {
    if (!CalendarEventDetailSheetCoordinator.tryMarkOpenOrOpening()) {
      return;
    }
    final state = CalendarPage.globalKey.currentState;
    final initialTarget = DayViewSheetEventTarget(
      ky: kYear,
      km: kMonth,
      kd: kDay,
      event: _noteToEventItem(note),
    );
    unawaited(state?._saveCalendarEventDetailOverlayForTarget(initialTarget));

    void releaseSheet() {
      final currentState = CalendarPage.globalKey.currentState;
      unawaited(currentState?._clearCalendarEventDetailOverlayState());
      CalendarEventDetailSheetCoordinator.markClosed();
    }

    try {
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF000000),
        isScrollControlled: true,
        builder: (_) => _MainCalendarEventDetailSheet(
          hostContext: context,
          initialTarget: initialTarget,
          flowResolver: state?._calendarChromeFlowDataForId,
          activeLedgerFlowIds:
              state?._buildActiveLedgerFlowIds() ?? const <int>{},
          resolveCurrentEventTarget: state?._resolveCalendarCurrentEventTarget,
          resolveAdjacentEventTarget:
              state?._resolveCalendarAdjacentEventTarget,
          onTargetChanged: (target) {
            final currentState = CalendarPage.globalKey.currentState;
            unawaited(
              currentState?._saveCalendarEventDetailOverlayForTarget(target),
            );
          },
          onManageFlows: onManageFlows,
          onEditNote: onEditNote,
          onDeleteNote: onDeleteNote,
          onShareNote: onShareNote,
          onEditReminder: onEditReminder,
          onEndReminder: onEndReminder,
          onShareReminder: onShareReminder,
          onEndFlow: onEndFlow,
          onAppendToJournal: onAppendToJournal,
        ),
      ).whenComplete(releaseSheet);
    } catch (_) {
      releaseSheet();
      rethrow;
    }
  }
}

class _MainCalendarEventDetailSheet extends StatefulWidget {
  const _MainCalendarEventDetailSheet({
    required this.hostContext,
    required this.initialTarget,
    this.flowResolver,
    this.activeLedgerFlowIds = const <int>{},
    this.resolveCurrentEventTarget,
    this.resolveAdjacentEventTarget,
    this.onTargetChanged,
    this.onManageFlows,
    this.onEditNote,
    this.onDeleteNote,
    this.onShareNote,
    this.onEditReminder,
    this.onEndReminder,
    this.onShareReminder,
    this.onEndFlow,
    this.onAppendToJournal,
  });

  final BuildContext hostContext;
  final DayViewSheetEventTarget initialTarget;
  final FlowData? Function(int? flowId)? flowResolver;
  final Set<int> activeLedgerFlowIds;
  final DayViewSheetEventTarget Function(DayViewSheetEventTarget target)?
  resolveCurrentEventTarget;
  final DayViewSheetEventTarget? Function({
    required int ky,
    required int km,
    required int kd,
    required EventItem event,
    required bool forward,
  })?
  resolveAdjacentEventTarget;
  final ValueChanged<DayViewSheetEventTarget>? onTargetChanged;
  final void Function(int?)? onManageFlows;
  final Future<void> Function(int kYear, int kMonth, int kDay, EventItem event)?
  onEditNote;
  final Future<void> Function(int kYear, int kMonth, int kDay, EventItem event)?
  onDeleteNote;
  final Future<void> Function(EventItem event)? onShareNote;
  final Future<void> Function(String reminderId)? onEditReminder;
  final Future<void> Function(String reminderId)? onEndReminder;
  final Future<void> Function(EventItem event)? onShareReminder;
  final void Function(int flowId)? onEndFlow;
  final Future<void> Function(String text)? onAppendToJournal;

  @override
  State<_MainCalendarEventDetailSheet> createState() =>
      _MainCalendarEventDetailSheetState();
}

class _MainCalendarEventDetailSheetState
    extends State<_MainCalendarEventDetailSheet> {
  static const TextStyle _actionTextStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    fontFamily: 'GentiumPlus',
    fontFamilyFallback: ['NotoSans', 'Roboto', 'Arial', 'sans-serif'],
  );

  late DayViewSheetEventTarget _currentTarget;
  late PageController _pageController;
  Map<String, double> _measuredHeights = {};

  FlowData? _flowForId(int? flowId) => widget.flowResolver?.call(flowId);

  bool _isRepeatingNoteFlowId(int? flowId) {
    final flow = _flowForId(flowId);
    return flow != null && hasRepeatingNoteFlowMetadata(flow.notes);
  }

  bool _shouldShowEndFlowForId(int? flowId) {
    final flow = _flowForId(flowId);
    return flow != null && !hasRepeatingNoteFlowMetadata(flow.notes);
  }

  _DetailSheetEndAction _endActionFor(
    EventItem event, {
    required FlowData? flow,
  }) {
    if (_shouldShowEndFlowForId(event.flowId)) {
      return _DetailSheetEndAction.flow;
    }
    if (flow == null && event.isReminder) {
      return _DetailSheetEndAction.reminder;
    }
    if ((flow == null || _isRepeatingNoteFlowId(event.flowId)) &&
        widget.onDeleteNote != null) {
      return _DetailSheetEndAction.note;
    }
    return _DetailSheetEndAction.none;
  }

  bool _shouldPromoteJournalToPill(EventItem event, FlowData? flow) =>
      widget.onAppendToJournal != null &&
      _endActionFor(event, flow: flow) != _DetailSheetEndAction.none;

  bool _isActionableFlowId(int? flowId) {
    if (flowId == null) return false;
    if (widget.activeLedgerFlowIds.contains(flowId)) return true;
    final flow = _flowForId(flowId);
    if (flow == null) return false;
    return flow.active && !hasRepeatingNoteFlowMetadata(flow.notes);
  }

  @override
  void initState() {
    super.initState();
    _currentTarget =
        widget.resolveCurrentEventTarget?.call(widget.initialTarget) ??
        widget.initialTarget;
    final initialPages = _detailSheetPagesForTarget(_currentTarget);
    _pageController = PageController(initialPage: initialPages.currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onTargetChanged?.call(_currentTarget);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

  String _detailSheetTargetKey(DayViewSheetEventTarget target) =>
      '${target.ky}:${target.km}:${target.kd}:${_sheetEventIdentityKey(target.event)}';

  ({List<DayViewSheetEventTarget> pages, int currentIndex})
  _detailSheetPagesForTarget(DayViewSheetEventTarget target) {
    final previous = widget.resolveAdjacentEventTarget?.call(
      ky: target.ky,
      km: target.km,
      kd: target.kd,
      event: target.event,
      forward: false,
    );
    final next = widget.resolveAdjacentEventTarget?.call(
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

  void _updateMeasuredHeight(String key, double height) {
    final normalized = height.ceilToDouble();
    if (normalized <= 0) return;
    final previous = _measuredHeights[key];
    if (previous != null && (previous - normalized).abs() < 1) return;
    setState(() {
      _measuredHeights = Map<String, double>.from(_measuredHeights)
        ..[key] = normalized;
    });
  }

  void _resetPageController(int initialPage) {
    final previous = _pageController;
    _pageController = PageController(initialPage: initialPage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      previous.dispose();
    });
  }

  void _moveToTarget(DayViewSheetEventTarget nextTarget) {
    setState(() {
      _currentTarget = nextTarget;
    });
    widget.onTargetChanged?.call(nextTarget);
  }

  String _cleanDetail(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final decoded = _decodeDetailMetadata(raw);
    var detail = decoded.detail ?? '';
    if (detail.startsWith('flowLocalId=')) {
      final semi = detail.indexOf(';');
      if (semi > 0 && semi < detail.length - 1) {
        detail = detail.substring(semi + 1).trim();
      } else {
        return '';
      }
    }
    if (detail.startsWith('repeat=')) {
      final semi = detail.indexOf(';');
      if (semi > 0 && semi < detail.length - 1) {
        detail = detail.substring(semi + 1).trim();
      } else {
        return '';
      }
    }
    return normalizeTrackSkyDetailText(_stripCidLines(detail).trim());
  }

  String _formatTimeRange(int startMin, int endMin, {bool allDay = false}) {
    if (allDay) return 'All day';
    final startHour = startMin ~/ 60;
    final startMinute = startMin % 60;
    final endHour = endMin ~/ 60;
    final endMinute = endMin % 60;

    String formatTime(int hour, int minute) {
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$hour12:${minute.toString().padLeft(2, '0')} $period';
    }

    if (startMin == endMin) return formatTime(startHour, startMinute);
    return '${formatTime(startHour, startMinute)} – ${formatTime(endHour, endMinute)}';
  }

  ButtonStyle _endActionStyle(BuildContext context) {
    return withExpandedTouchTargets(
      context,
      OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFFFC145)),
        foregroundColor: const Color(0xFFFFC145),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        minimumSize: const Size(0, 35),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
      ),
    );
  }

  ButtonStyle _journalPillStyle(BuildContext context) {
    const touchMinHeight = kMinInteractiveDimension * 0.8;
    return withExpandedTouchTargets(
      context,
      OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFFFC145)),
        foregroundColor: const Color(0xFFFFC145),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
        iconSize: 18,
      ),
      minimumSize: const Size(kMinInteractiveDimension, touchMinHeight),
    );
  }

  Future<void> _saveFlow(int flowId) async {
    final messenger = ScaffoldMessenger.maybeOf(widget.hostContext);
    try {
      await UserEventsRepo(
        Supabase.instance.client,
      ).setFlowSaved(flowId: flowId, isSaved: true);
      if (!mounted) return;
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Saved to Saved Flows'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Unable to save flow: $e')),
      );
    }
  }

  Future<void> _handleAddToJournal(
    EventItem event, {
    required BuildContext sheetContext,
  }) async {
    final cb = widget.onAppendToJournal;
    if (cb == null) return;
    Navigator.pop(sheetContext);
    final flow = widget.flowResolver?.call(event.flowId);
    final isTrackSky = _isTrackSkyFlowName(flow?.name);
    final rawDetail = _cleanDetail(event.detail);
    final detail = isTrackSky
        ? buildTrackSkyNarrativeSummary(
            title: event.title,
            category: event.category,
            fallbackGuidance: rawDetail,
          )
        : rawDetail;
    final text = '${event.title}${detail.isNotEmpty ? '\n\n$detail' : ''}';
    await cb(text);
  }

  Widget _buildEventDetailSheetPage({
    required DayViewSheetEventTarget target,
    bool scrollable = true,
  }) {
    final currentEvent = target.event;
    final flow = widget.flowResolver?.call(currentEvent.flowId);
    final isReminder = currentEvent.isReminder;
    final isTrackSky = _isTrackSkyFlowName(flow?.name);
    final rawDetail = _cleanDetail(currentEvent.detail);
    final detail = isTrackSky
        ? buildTrackSkyNarrativeSummary(
            title: currentEvent.title,
            category: currentEvent.category,
            fallbackGuidance: rawDetail,
          )
        : rawDetail;
    final isNutrition = detail.contains('Source:');
    final trackSkySpec = isTrackSky
        ? _trackSkyBadgeSpecForTitle(currentEvent.title)
        : null;

    Widget? metaChip;
    if (flow != null) {
      metaChip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: isTrackSky ? trackSkySpec!.background : null,
          color: isTrackSky ? null : flow.color.withValues(alpha: 0.16),
          border: isTrackSky
              ? Border.all(
                  color: trackSkySpec!.borderColor.withValues(alpha: 0.78),
                )
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: isTrackSky
            ? Text(
                flow.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: trackSkySpec!.textColor,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.42),
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              )
            : Text(
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
          color: KemeticGold.base.withValues(alpha: 0.16),
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
          color: KemeticGold.base.withValues(alpha: 0.16),
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
            onTap: () =>
                _launchExternalPreviewTarget(currentEvent.location!.trim()),
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
              children: _buildExternalLinkSpans(detail),
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
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _gold.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
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

  Widget _buildEndFlowButton(
    BuildContext context,
    DayViewSheetEventTarget target,
  ) {
    final flowId = target.event.flowId;
    final canEndFlow =
        widget.onEndFlow != null && _shouldShowEndFlowForId(flowId);
    return OutlinedButton.icon(
      style: _endActionStyle(context),
      onPressed: flowId == null || !canEndFlow
          ? null
          : () async {
              Navigator.pop(context);
              final routedThroughCalendarPage =
                  await CalendarPage.endFlowFromEventTarget(target);
              if (!routedThroughCalendarPage) {
                widget.onEndFlow?.call(flowId);
              }
            },
      icon: const Icon(Icons.stop_circle),
      label: const Text('End Flow'),
    );
  }

  Widget _buildAddToJournalButton(BuildContext context, EventItem event) {
    final enabled = widget.onAppendToJournal != null;
    return OutlinedButton.icon(
      style: _journalPillStyle(context),
      onPressed: enabled
          ? () => _handleAddToJournal(event, sheetContext: context)
          : null,
      icon: const Icon(Icons.library_add_check),
      label: const Text('Add to journal'),
    );
  }

  Widget _buildEndNoteButton(
    BuildContext context,
    DayViewSheetEventTarget target,
  ) {
    final enabled = widget.onDeleteNote != null;
    return OutlinedButton.icon(
      style: _endActionStyle(context),
      onPressed: enabled
          ? () async {
              Navigator.pop(context);
              await widget.onDeleteNote!(
                target.ky,
                target.km,
                target.kd,
                target.event,
              );
            }
          : null,
      icon: const Icon(Icons.delete_outline),
      label: const Text('End Note'),
    );
  }

  Widget _buildEndReminderButton(BuildContext context, EventItem event) {
    final reminderId = event.reminderId;
    final enabled = widget.onEndReminder != null && reminderId != null;
    return OutlinedButton.icon(
      style: _endActionStyle(context),
      onPressed: enabled
          ? () async {
              Navigator.pop(context);
              await widget.onEndReminder!(reminderId);
            }
          : null,
      icon: const Icon(Icons.stop_circle),
      label: const Text('End Reminder'),
    );
  }

  Widget _buildEventDetailTopActionRow({
    required BuildContext sheetContext,
    required DayViewSheetEventTarget target,
  }) {
    final currentEvent = target.event;
    final flow = _flowForId(currentEvent.flowId);
    final endAction = _endActionFor(currentEvent, flow: flow);

    return Row(
      children: [
        const Spacer(),
        if (_shouldPromoteJournalToPill(currentEvent, flow))
          _buildAddToJournalButton(sheetContext, currentEvent)
        else if (endAction == _DetailSheetEndAction.flow)
          _buildEndFlowButton(sheetContext, target)
        else if (endAction == _DetailSheetEndAction.reminder)
          _buildEndReminderButton(sheetContext, currentEvent)
        else if (endAction == _DetailSheetEndAction.note)
          _buildEndNoteButton(sheetContext, target),
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
    return TextButton.icon(
      onPressed: () async {
        Navigator.pop(sheetContext);
        final handled = await CalendarPage.makeTodoFromEventTarget(target);
        if (!handled && widget.hostContext.mounted) {
          ScaffoldMessenger.maybeOf(widget.hostContext)?.showSnackBar(
            const SnackBar(content: Text('Could not add to-do.')),
          );
        }
      },
      icon: KemeticGold.icon(Icons.playlist_add_check),
      label: KemeticGold.text(
        'Make to-do',
        style: _actionTextStyle.copyWith(fontSize: 15),
      ),
    );
  }

  Widget _buildEventDetailOverflowButton({
    required BuildContext sheetContext,
    required DayViewSheetEventTarget target,
  }) {
    final currentEvent = target.event;
    final flow = widget.flowResolver?.call(currentEvent.flowId);
    final actionableFlow = _isActionableFlowId(currentEvent.flowId);
    final isReminder = currentEvent.isReminder;
    final hasFlow = flow != null;
    final endAction = _endActionFor(currentEvent, flow: flow);
    final promoteJournalAction = _shouldPromoteJournalToPill(
      currentEvent,
      flow,
    );

    return PopupMenuButton<String>(
      icon: KemeticGold.icon(Icons.more_vert),
      tooltip: 'Event options',
      color: const Color(0xFF000000),
      onSelected: (value) async {
        if (value == 'end_flow') {
          Navigator.pop(sheetContext);
          final flowId = currentEvent.flowId;
          if (flowId != null && widget.onEndFlow != null) {
            final routedThroughCalendarPage =
                await CalendarPage.endFlowFromEventTarget(target);
            if (!routedThroughCalendarPage) {
              widget.onEndFlow!(flowId);
            }
          }
        } else if (value == 'end_reminder') {
          Navigator.pop(sheetContext);
          final reminderId = currentEvent.reminderId;
          if (reminderId != null && widget.onEndReminder != null) {
            await widget.onEndReminder!(reminderId);
          }
        } else if (value == 'end_note') {
          Navigator.pop(sheetContext);
          if (widget.onDeleteNote != null) {
            await widget.onDeleteNote!(
              target.ky,
              target.km,
              target.kd,
              currentEvent,
            );
          }
        } else if (value == 'journal') {
          await _handleAddToJournal(currentEvent, sheetContext: sheetContext);
        } else if (value == 'share') {
          Navigator.pop(sheetContext);
          if (hasFlow && !isReminder) {
            await CalendarPage.shareFlowFromEvent(currentEvent);
          } else if (isReminder && widget.onShareReminder != null) {
            await widget.onShareReminder!(currentEvent);
          } else if (widget.onShareNote != null) {
            await widget.onShareNote!(currentEvent);
          }
        } else if (value == 'edit' &&
            actionableFlow &&
            widget.onManageFlows != null) {
          Navigator.pop(sheetContext);
          widget.onManageFlows!(flow!.id);
        } else if (value == 'save' && actionableFlow && flow != null) {
          Navigator.pop(sheetContext);
          await _saveFlow(flow.id);
        } else if (value == 'edit_reminder' &&
            isReminder &&
            currentEvent.reminderId != null &&
            widget.onEditReminder != null) {
          Navigator.pop(sheetContext);
          await widget.onEditReminder!(currentEvent.reminderId!);
        } else if (value == 'edit_note' &&
            !hasFlow &&
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
        if (widget.onAppendToJournal != null && !promoteJournalAction)
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
        if (hasFlow ||
            (isReminder && widget.onShareReminder != null) ||
            (!hasFlow && !isReminder && widget.onShareNote != null))
          PopupMenuItem(
            value: 'share',
            child: Row(
              children: [
                KemeticGold.icon(Icons.share_outlined),
                const SizedBox(width: 12),
                Text(
                  hasFlow
                      ? 'Share Flow'
                      : isReminder
                      ? 'Share Reminder'
                      : 'Share Note',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        if (hasFlow && actionableFlow && !isReminder)
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
        if (hasFlow &&
            actionableFlow &&
            !isReminder &&
            widget.onManageFlows != null)
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
        if (!hasFlow && !isReminder && widget.onEditNote != null)
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
        if (promoteJournalAction &&
            endAction == _DetailSheetEndAction.flow &&
            widget.onEndFlow != null)
          PopupMenuItem(
            value: 'end_flow',
            child: Row(
              children: [
                KemeticGold.icon(Icons.stop_circle),
                const SizedBox(width: 12),
                const Text('End Flow', style: TextStyle(color: Colors.white)),
              ],
            ),
          )
        else if (promoteJournalAction &&
            endAction == _DetailSheetEndAction.reminder &&
            widget.onEndReminder != null &&
            currentEvent.reminderId != null)
          PopupMenuItem(
            value: 'end_reminder',
            child: Row(
              children: [
                KemeticGold.icon(Icons.stop_circle),
                const SizedBox(width: 12),
                const Text(
                  'End Reminder',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          )
        else if (promoteJournalAction &&
            endAction == _DetailSheetEndAction.note &&
            widget.onDeleteNote != null)
          PopupMenuItem(
            value: 'end_note',
            child: Row(
              children: [
                KemeticGold.icon(Icons.delete_outline),
                const SizedBox(width: 12),
                const Text('End Note', style: TextStyle(color: Colors.white)),
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
            style: _actionTextStyle.copyWith(fontSize: 15),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final target =
        widget.resolveCurrentEventTarget?.call(_currentTarget) ??
        _currentTarget;
    final pages = _detailSheetPagesForTarget(target);
    final currentKey = _detailSheetTargetKey(target);
    final pageViewKey = ValueKey<String>(
      '$currentKey:${pages.currentIndex}:${pages.pages.length}',
    );
    final maxSheetHeight = math.min(
      MediaQuery.sizeOf(context).height * 0.72,
      560.0,
    );
    final sheetHeight = (_measuredHeights[currentKey] ?? 200.0)
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
                    key: ValueKey<String>(_detailSheetTargetKey(pageTarget)),
                    onChange: (size) {
                      _updateMeasuredHeight(
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
                  sheetContext: context,
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
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: pages.pages.length,
                      onPageChanged: (index) {
                        if (index == pages.currentIndex) return;
                        final nextTarget = pages.pages[index];
                        final nextPages = _detailSheetPagesForTarget(
                          nextTarget,
                        );
                        _resetPageController(nextPages.currentIndex);
                        _moveToTarget(nextTarget);
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
                  sheetContext: context,
                  target: target,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({super.key, required this.onChange, required super.child});

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

class _ColorDot extends StatelessWidget {
  final Color color;
  const _ColorDot({required this.color});
  @override
  Widget build(BuildContext context) {
    return _Glossy(
      gradient: _glossFromColor(color), // uses helper from Block 1
      child: Container(
        width: 4.5,
        height: 4.5,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _TrackSkyMicroSignifier extends StatelessWidget {
  final _Note note;
  const _TrackSkyMicroSignifier({required this.note});

  @override
  Widget build(BuildContext context) {
    final spec = _trackSkyBadgeSpecForNote(note);
    return Container(
      width: 6.5,
      height: 6.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: spec.background,
        border: Border.all(
          color: spec.borderColor.withValues(alpha: 0.8),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 1.4,
            offset: const Offset(0, 0.5),
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          children: [
            ..._buildTrackSkyStars(
              seed: '${note.title}|micro',
              showLabel: false,
              dense: true,
              tint: spec.accentColor,
            ),
            ..._buildTrackSkyAccentWidgets(
              spec: spec,
              title: note.title,
              dense: true,
              showLabel: false,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildTrackSkyBadgeMotif({
  required _TrackSkyBadgeSpec spec,
  required String title,
  required bool dense,
}) {
  final lower = title.toLowerCase();
  final double size = dense ? 10.0 : 16.0;
  final double ringSize = dense ? 1.0 : 1.4;

  Widget planet({
    required Color color,
    double? diameter,
    BoxBorder? border,
    List<BoxShadow>? shadow,
  }) {
    final d = diameter ?? size;
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: border,
        boxShadow: shadow,
      ),
    );
  }

  switch (spec.kind) {
    case _TrackSkyBadgeKind.moon:
      return planet(
        color: spec.accentColor,
        shadow: [
          BoxShadow(
            color: spec.glowColor.withValues(alpha: 0.42),
            blurRadius: dense ? 3 : 6,
          ),
        ],
      );
    case _TrackSkyBadgeKind.lunarEclipse:
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            planet(
              color: spec.accentColor,
              shadow: [
                BoxShadow(
                  color: spec.glowColor.withValues(alpha: 0.35),
                  blurRadius: dense ? 3 : 6,
                ),
              ],
            ),
            Positioned(
              left: size * (lower.contains('penumbral') ? 0.16 : 0.28),
              top: size * 0.05,
              child: planet(
                color: const Color(0xCC03050B),
                diameter: size * 0.82,
              ),
            ),
          ],
        ),
      );
    case _TrackSkyBadgeKind.solarEclipse:
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            planet(
              color: Colors.transparent,
              border: Border.all(color: spec.accentColor, width: ringSize),
              shadow: [
                BoxShadow(
                  color: spec.glowColor.withValues(alpha: 0.5),
                  blurRadius: dense ? 4 : 7,
                ),
              ],
            ),
            planet(color: const Color(0xFF04060D), diameter: size * 0.64),
          ],
        ),
      );
    case _TrackSkyBadgeKind.meteor:
      return SizedBox(
        width: size + (dense ? 4 : 7),
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: 0,
              top: dense ? 2.0 : 3.0,
              child: planet(
                color: Colors.white,
                diameter: dense ? 3.2 : 5.0,
                shadow: [
                  BoxShadow(
                    color: spec.glowColor.withValues(alpha: 0.55),
                    blurRadius: dense ? 3 : 6,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: dense ? 3.0 : 5.0,
              child: Transform.rotate(
                angle: -0.35,
                child: Container(
                  width: dense ? 10 : 15,
                  height: dense ? 1.2 : 1.8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        spec.accentColor.withValues(alpha: 0.18),
                        spec.accentColor.withValues(alpha: 0.72),
                        Colors.white,
                      ],
                      stops: const [0.0, 0.34, 0.72, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    case _TrackSkyBadgeKind.planet:
      if (lower.contains('saturn')) {
        return SizedBox(
          width: size + (dense ? 2 : 4),
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: -0.25,
                child: Container(
                  width: size + (dense ? 2 : 5),
                  height: dense ? 3.0 : 5.0,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: spec.secondaryAccentColor.withValues(alpha: 0.82),
                      width: dense ? 0.8 : 1.1,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              planet(color: spec.accentColor, diameter: size * 0.64),
            ],
          ),
        );
      }
      if (lower.contains('conjunction')) {
        return SizedBox(
          width: size + (dense ? 2 : 5),
          height: size,
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: dense ? 0.6 : 1.3,
                child: planet(
                  color: spec.secondaryAccentColor,
                  diameter: size * 0.52,
                ),
              ),
              Positioned(
                left: 0,
                bottom: dense ? 0.6 : 1.4,
                child: planet(color: spec.accentColor, diameter: size * 0.64),
              ),
            ],
          ),
        );
      }
      if (lower.contains('parade')) {
        final colors = [
          spec.accentColor,
          spec.secondaryAccentColor,
          const Color(0xFFE7C8FF),
        ];
        return SizedBox(
          width: size + (dense ? 5 : 9),
          height: size,
          child: Stack(
            children: [
              for (int i = 0; i < colors.length; i++)
                Positioned(
                  left: i * (dense ? 3.0 : 5.0),
                  top: i.isEven ? 0 : (dense ? 1.8 : 2.5),
                  child: planet(color: colors[i], diameter: dense ? 3.0 : 4.4),
                ),
            ],
          ),
        );
      }
      return planet(
        color: spec.accentColor,
        shadow: [
          BoxShadow(
            color: spec.glowColor.withValues(alpha: 0.4),
            blurRadius: dense ? 3 : 6,
          ),
        ],
      );
    case _TrackSkyBadgeKind.solarSeason:
      return SizedBox(
        width: size + (dense ? 4 : 8),
        height: size,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: dense ? 1.0 : 2.0,
              child: Container(
                height: dense ? 1.0 : 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      spec.secondaryAccentColor.withValues(alpha: 0.5),
                      spec.secondaryAccentColor,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              right: dense ? 2.0 : 4.0,
              bottom: dense ? 1.2 : 2.1,
              child: planet(
                color: spec.accentColor,
                diameter: dense ? 4.2 : 6.8,
                shadow: [
                  BoxShadow(
                    color: spec.glowColor.withValues(alpha: 0.45),
                    blurRadius: dense ? 3 : 6,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    case _TrackSkyBadgeKind.genericSky:
      return planet(
        color: spec.secondaryAccentColor,
        diameter: dense ? 4.0 : 6.0,
        shadow: [
          BoxShadow(
            color: spec.glowColor.withValues(alpha: 0.4),
            blurRadius: dense ? 3 : 6,
          ),
        ],
      );
  }
}

class _TrackSkyMiniBadge extends StatelessWidget {
  final _Note note;
  final bool dense;
  final bool expand;
  final String? label;
  final VoidCallback? onTap;

  const _TrackSkyMiniBadge({
    required this.note,
    this.dense = true,
    this.expand = false,
    this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final showLabel = label != null && !dense;
    final isDetailPill = expand && showLabel;
    final spec = _trackSkyBadgeSpecForNote(note);
    final motif = _buildTrackSkyBadgeMotif(
      spec: spec,
      title: note.title,
      dense: dense,
    );
    final double badgeHeight = isDetailPill ? 40 : (dense ? 10 : 26);
    final double motifBoxWidth = showLabel ? 16 : (dense ? 12 : 18);
    final double motifBoxHeight = dense ? 10 : 14;
    final EdgeInsetsGeometry padding = showLabel
        ? const EdgeInsets.fromLTRB(7, 6, 6, 6)
        : const EdgeInsets.symmetric(horizontal: 4, vertical: 2);
    final BorderRadius radius = BorderRadius.circular(
      isDetailPill ? 12 : (dense ? 5 : 10),
    );

    final labelStyle = TextStyle(
      color: spec.textColor,
      fontSize: isDetailPill ? 10.5 : 10,
      height: 1.18,
      fontWeight: isDetailPill ? FontWeight.w600 : FontWeight.w500,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.68),
          offset: const Offset(0, 1.2),
          blurRadius: 2.8,
        ),
        Shadow(
          color: spec.glowColor.withValues(alpha: 0.36),
          offset: Offset.zero,
          blurRadius: 5,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final double minW = dense
            ? (outerConstraints.maxWidth.isFinite
                  ? math.min(24.0, outerConstraints.maxWidth)
                  : 24.0)
            : 0.0;
        final badge = RepaintBoundary(
          child: Container(
            width: expand ? double.infinity : null,
            height: badgeHeight,
            constraints: BoxConstraints(minWidth: minW),
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: spec.background,
              border: Border.all(
                color: spec.borderColor.withValues(alpha: dense ? 0.95 : 1.0),
                width: dense ? 0.95 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.26),
                  blurRadius: dense ? 2 : 5,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final canShowMotifWithLabel =
                      showLabel && constraints.maxWidth >= 44;

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ..._buildTrackSkyStars(
                        seed: note.title,
                        showLabel: showLabel,
                        dense: dense,
                        tint: spec.accentColor,
                      ),
                      if (showLabel)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  const Color(0xAA04060C),
                                  const Color(0x7204060C),
                                  const Color(0x1204060C),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.38, 0.64, 1.0],
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: padding,
                        child: showLabel
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(
                                      right: canShowMotifWithLabel
                                          ? motifBoxWidth + 2
                                          : 0,
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        label!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: true,
                                        textAlign: TextAlign.left,
                                        style: labelStyle,
                                      ),
                                    ),
                                  ),
                                  if (canShowMotifWithLabel)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      bottom: 0,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: SizedBox(
                                          width: motifBoxWidth,
                                          height: motifBoxHeight,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerRight,
                                            child: motif,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : Center(
                                child: SizedBox(
                                  width: motifBoxWidth,
                                  height: motifBoxHeight,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.center,
                                    child: motif,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        if (expand && !dense && onTap != null) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: badge,
          );
        }

        return IgnorePointer(child: badge);
      },
    );
  }
}

class _MiniEventBlock extends StatelessWidget {
  final _Note note;
  final Color color;
  final bool isTrackSky;
  final bool dense;
  final bool expand;
  final String? label;
  const _MiniEventBlock({
    required this.note,
    required this.color,
    this.isTrackSky = false,
    this.dense = true,
    this.expand = false,
    this.label,
    this.onTap,
  });

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (isTrackSky) {
      return _TrackSkyMiniBadge(
        note: note,
        dense: dense,
        expand: expand,
        label: label,
        onTap: onTap,
      );
    }

    final showLabel = label != null && !dense;
    final isDetailPill = expand && showLabel;
    final bg = color.withValues(alpha: dense ? 0.28 : 0.22);
    final border = color.withValues(alpha: 0.9);
    final double badgeHeight = isDetailPill ? 38 : (dense ? 8 : 24);
    final EdgeInsetsGeometry padding = showLabel
        ? (isDetailPill
              ? const EdgeInsets.symmetric(horizontal: 3, vertical: 6)
              : const EdgeInsets.symmetric(horizontal: 7, vertical: 3))
        : EdgeInsets.zero;
    final BorderRadius radius = BorderRadius.circular(
      isDetailPill ? 12 : (dense ? 5 : 10),
    );
    final TextStyle labelStyle = TextStyle(
      color: Colors.white,
      fontSize: isDetailPill ? 10.5 : 10,
      height: 1.2,
      fontWeight: isDetailPill ? FontWeight.w600 : FontWeight.w500,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final double minW = dense
            ? (constraints.maxWidth.isFinite
                  ? math.min(24.0, constraints.maxWidth)
                  : 24.0)
            : 0.0;
        final container = Container(
          width: expand ? double.infinity : null,
          height: badgeHeight,
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: Border.all(color: border, width: dense ? 0.8 : 1.0),
          ),
          constraints: BoxConstraints(minWidth: minW),
          alignment: Alignment.centerLeft,
          child: showLabel
              ? Text(
                  label!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  textAlign: TextAlign.left,
                  style: labelStyle,
                )
              : null,
        );

        if (expand && !dense && onTap != null) {
          return GestureDetector(onTap: onTap, child: container);
        }
        return container;
      },
    );
  }
}

/* ───────────── Epagomenal (5 or 6 extra days) ───────────── */

class _EpagomenalCard extends StatelessWidget {
  const _EpagomenalCard({
    required this.kYear,
    this.todayMonth,
    this.todayDay,
    required this.notesGetter,
    required this.flowColorsGetter,
    required this.onDayTap,
    required this.showGregorian,
    this.expansionLevel = MonthExpansionLevel.compact,
    this.noteColorResolver = _defaultNoteColor,
    this.flowNameGetter,
    this.onManageFlows,
    this.onEditNote,
    this.onDeleteNote,
    this.onShareNote,
    this.onEditReminder,
    this.onEndReminder,
    this.onShareReminder,
    this.onEndFlow,
    this.onAppendToJournal,
    this.todayDayKey,
  });

  final int kYear;
  final int? todayMonth;
  final int? todayDay;
  final List<_Note> Function(int kMonth, int kDay) notesGetter;
  final List<Color> Function(int kYear, int kMonth, int kDay) flowColorsGetter;
  final void Function(BuildContext, int kMonth, int kDay) onDayTap;
  final Key? todayDayKey;
  final bool showGregorian;
  final MonthExpansionLevel expansionLevel;
  final Color Function(_Note) noteColorResolver;
  final String? Function(_Note)? flowNameGetter;
  final void Function(int?)? onManageFlows;
  final Future<void> Function(int kYear, int kMonth, int kDay, EventItem event)?
  onEditNote;
  final Future<void> Function(int kYear, int kMonth, int kDay, EventItem event)?
  onDeleteNote;
  final Future<void> Function(EventItem event)? onShareNote;
  final Future<void> Function(String reminderId)? onEditReminder;
  final Future<void> Function(String reminderId)? onEndReminder;
  final Future<void> Function(EventItem event)? onShareReminder;
  final void Function(int flowId)? onEndFlow;
  final Future<void> Function(String text)? onAppendToJournal;

  // Weekday labels row for epagomenal days (5 or 6 days)
  Widget _epagomenalWeekdayRow(int dayCount) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final labels = List<String>.generate(dayCount, (i) {
      final gregorian = safeLocalDisplay(
        KemeticMath.toGregorian(kYear, 13, i + 1),
      );
      final idx = gregorian.weekday - 1; // Monday = 1
      return letters[idx];
    });

    return Row(
      children: [
        for (int i = 0; i < labels.length; i++) ...[
          Expanded(
            child: Center(
              child: Text(
                labels[i],
                style: _weekdayLabelStyle.copyWith(
                  color: showGregorian ? _blueLight : _goldLight,
                ),
              ),
            ),
          ),
          if (i < labels.length - 1) const SizedBox(width: 3),
        ],
      ],
    );
  }

  String? _gregMonthForEpagomenal(int ky, int epiCount) {
    for (int d = 1; d <= epiCount; d++) {
      final g = KemeticMath.toGregorian(ky, 13, d);
      if (g.day == 1) return _gregMonthNames[g.month];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isMonthToday = (todayMonth != null && todayMonth == 13);
    final epiCount = KemeticMath.isLeapKemeticYear(kYear) ? 6 : 5;

    final gLabel = _gregMonthForEpagomenal(kYear, epiCount);

    // Dynamic height for epagomenal days (parallels regular decan sizing).
    double epagomenalHeightForLayout() {
      if (expansionLevel != MonthExpansionLevel.details) {
        return _chipHeightFor(expansionLevel);
      }
      const double labelAreaHeight = 24.0;
      const double firstPillHeight = 50.0;
      const double subsequentPillHeight = 56.0;
      const double minHeight = 80.0;
      const double maxHeight = 250.0;

      int maxVisible = 0;
      for (int d = 1; d <= epiCount; d++) {
        final notes = notesGetter(13, d);
        final visible = notes.length > 5 ? 5 : notes.length;
        if (visible > maxVisible) maxVisible = visible;
      }

      double pillsHeight = 0.0;
      if (maxVisible > 0) {
        pillsHeight = firstPillHeight;
        if (maxVisible > 1) {
          pillsHeight += subsequentPillHeight * (maxVisible - 1);
        }
      }

      final double estimated = labelAreaHeight + pillsHeight;
      return estimated.clamp(minHeight, maxHeight);
    }

    final double epagomenalHeight = epagomenalHeightForLayout();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        6,
        16,
        expansionLevel == MonthExpansionLevel.details ? 6 : 24,
      ),
      child: Card(
        color: Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide.none,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Kemetic header (left) and Gregorian month (right when present)
              Row(
                children: [
                  Visibility(
                    visible: !showGregorian, // visually removed in Gregorian
                    maintainState: true,
                    maintainAnimation: true,
                    maintainSize: true, // keep height so layout doesn't jump
                    child: GlossyText(
                      text: 'Heriu Renpet (ḥr.w rnpt)',
                      style: _monthTitleGold.copyWith(
                        fontFamily: 'GentiumPlus',
                        fontFamilyFallback: const ['NotoSans', 'Roboto'],
                      ),
                      gradient: goldGloss,
                    ),
                  ),
                  const Spacer(),
                  Visibility(
                    visible: showGregorian && gLabel != null,
                    maintainState: true,
                    maintainAnimation: true,
                    maintainSize: true,
                    child: GlossyText(
                      text: gLabel ?? '',
                      style: _decanStyle,
                      gradient: blueGloss,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: expansionLevel == MonthExpansionLevel.details ? 0 : 10,
              ),

              _epagomenalWeekdayRow(epiCount),
              const SizedBox(height: 4),

              Row(
                children: [
                  for (int i = 0; i < epiCount; i++) ...[
                    Expanded(
                      child: _DayChip(
                        anchorKey: isMonthToday && (todayDay == i + 1)
                            ? todayDayKey
                            : null, // 🔑
                        label: showGregorian
                            ? '${KemeticMath.toGregorian(kYear, 13, i + 1).day}'
                            : '${i + 1}',
                        isToday: isMonthToday && (todayDay == i + 1),
                        notes: notesGetter(13, i + 1),
                        flowColors: flowColorsGetter(kYear, 13, i + 1),
                        onTap: () => onDayTap(context, 13, i + 1),
                        showGregorian: showGregorian,
                        dayKey:
                            'epagomenal_${i + 1}_$kYear', // Epagomenal days use their own key format
                        expansionLevel: expansionLevel,
                        noteColorResolver: noteColorResolver,
                        flowNameGetter: flowNameGetter,
                        decanHeight: epagomenalHeight,
                        kYear: kYear,
                        kMonth: 13,
                        kDay: i + 1,
                        onManageFlows: onManageFlows,
                        onEditNote: onEditNote,
                        onDeleteNote: onDeleteNote,
                        onShareNote: onShareNote,
                        onEditReminder: onEditReminder,
                        onEndReminder: onEndReminder,
                        onShareReminder: onShareReminder,
                        onEndFlow: onEndFlow,
                        onAppendToJournal: onAppendToJournal,
                      ),
                    ),
                    if (i < epiCount - 1) const SizedBox(width: 3),
                  ],
                ],
              ),
            ],
          ), // Close Column
        ), // Close inner Padding
      ), // Close Card
    ); // Close outer Padding and return
  }
}

/* ───────────── Detail Page (single-window behavior, flows-aware) ───────────── */
