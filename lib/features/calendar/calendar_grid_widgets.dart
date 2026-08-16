part of 'calendar_page.dart';

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
    this.monthRevisionListenable,
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
    this.temporalAnchorVisibleListenable,
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
  final Future<EndFlowOutcome> Function(int flowId)? onEndFlow;
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
  final ValueListenable<bool>? temporalAnchorVisibleListenable;
  final ValueListenable<int> Function(MonthRef month)? monthRevisionListenable;

  @override
  Widget build(BuildContext context) {
    final (tm, td) = (todayMonth, todayDay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (
          var kMonth = 1;
          kMonth <= CalendarSectionIndex.monthsPerYear;
          kMonth++
        )
          _buildMonthSection(kMonth, tm, td),
      ],
    );
  }

  Widget _buildMonthSection(int kMonth, int? tm, int? td) {
    final month = MonthRef(year: kYear, month: kMonth);
    Widget buildForVisibility(bool isTemporalAnchorVisible) {
      final revision = monthRevisionListenable?.call(month);
      if (revision == null) {
        return _buildMonthSectionContent(
          month,
          tm,
          td,
          isTemporalAnchorVisible,
        );
      }
      return ValueListenableBuilder<int>(
        valueListenable: revision,
        builder: (context, value, child) =>
            _buildMonthSectionContent(month, tm, td, isTemporalAnchorVisible),
      );
    }

    final visibility = temporalAnchorVisibleListenable;
    if (visibility != null && kMonth == tm) {
      return ValueListenableBuilder<bool>(
        valueListenable: visibility,
        builder: (context, value, child) => buildForVisibility(value),
      );
    }
    return buildForVisibility(true);
  }

  Widget _buildMonthSectionContent(
    MonthRef month,
    int? tm,
    int? td,
    bool isTemporalAnchorVisible,
  ) {
    final kMonth = month.month;
    final seasonHeader = switch (kMonth) {
      1 => 'Flood season (Akhet)',
      5 => 'Emergence season (Peret)',
      9 => 'Harvest season (Shemu)',
      _ => null,
    };

    return CalendarGeometrySection(
      month: month,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _GoldDivider(),
          if (seasonHeader != null) _SeasonHeader(title: seasonHeader),
          CalendarGeometryMonthBody(
            month: month,
            child: RepaintBoundary(
              child: _buildMonthBody(kMonth, tm, td, isTemporalAnchorVisible),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthBody(
    int kMonth,
    int? tm,
    int? td,
    bool isTemporalAnchorVisible,
  ) {
    if (kMonth == CalendarSectionIndex.monthsPerYear) {
      return _EpagomenalCard(
        anchorKey: monthAnchorKeyProvider?.call(kMonth),
        monthHeaderKey: monthHeaderKeyProvider?.call(kMonth),
        dayAnchorKeyProvider: dayAnchorKeyProvider,
        kYear: kYear,
        todayMonth: tm,
        todayDay: td,
        todayDayKey: todayDayKey,
        notesGetter: notesGetter,
        flowColorsGetter: flowColorsGetter,
        onDayTap: onDayTap,
        showGregorian: showGregorian,
        temporalAnchorVisible: isTemporalAnchorVisible,
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
      );
    }

    final seasonShort = switch (kMonth) {
      >= 1 && <= 4 => 'Akhet',
      >= 5 && <= 8 => 'Peret',
      >= 9 && <= 12 => 'Shemu',
      _ => throw StateError('Unsupported ordinary month: $kMonth'),
    };

    return _MonthCard(
      anchorKey: monthAnchorKeyProvider?.call(kMonth),
      monthHeaderKey: monthHeaderKeyProvider?.call(kMonth),
      dayAnchorKeyProvider: dayAnchorKeyProvider,
      kYear: kYear,
      kMonth: kMonth,
      seasonShort: seasonShort,
      todayMonth: tm,
      todayDay: td,
      todayDayKey: todayDayKey,
      notesGetter: notesGetter,
      flowColorsGetter: flowColorsGetter,
      temporalAnchorVisible: isTemporalAnchorVisible,
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
          : (context) => onMonthHeaderTap!(context, kMonth),
      onDecanTap: onDecanTap == null
          ? null
          : (context, decanIndex) => onDecanTap!(context, kMonth, decanIndex),
    );
  }
}

/* ───────────────────────── Month & Day Cards ───────────────────────── */

class _CalendarTone {
  static const Color calendarBlack = Color(0xFF060504);
  static const Color velvetBlack = Color(0xFF080705);
  static const Color previewCardBase = Color(0xFF0B0806);
  static const Color antiqueGold = Color(0xFFC4A64A);
  static const Color dimGold = Color(0xFF89733A);
  static const Color bodyStone = Color(0xFFBBB0A5);
  static const Color mutedStone = Color(0xFF9A8C7B);
  static const Color dayNumber = Color(0xFF987F45);
  static const Color weekday = Color(0xFF756238);
  static const Color decanLabel = Color(0xFF927A43);
  static const Color sectionLabel = Color(0xFF9A8245);
  static const Color gregorianBlue = Color(0xFF4DA3FF);
  static const Color transliteration = Color(0xFFA08648);

  static final Color dayCellFill = Color.alphaBlend(
    antiqueGold.withValues(alpha: 0.048),
    const Color(0xFF070604),
  );
  static final Color dayCellBorder = antiqueGold.withValues(alpha: 0.060);
  static final Color selectedDayFill = Color.alphaBlend(
    antiqueGold.withValues(alpha: 0.12),
    const Color(0xFF0A0705),
  );
  static final Color selectedDayBorder = antiqueGold.withValues(alpha: 0.54);
  static final Color softDivider = antiqueGold.withValues(alpha: 0.070);
  static final Color softCardBorder = antiqueGold.withValues(alpha: 0.090);

  static const Gradient mutedGoldGloss = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD3BD69), Color(0xFF9B803B), Color(0xFFC4A64A)],
    stops: [0.0, 0.52, 1.0],
  );

  static Color softenAccent(
    Color raw, {
    double saturationScale = 0.55,
    double lightness = 0.50,
    double goldBlend = 0.10,
  }) {
    final hsl = HSLColor.fromColor(raw);
    final muted = hsl
        .withSaturation((hsl.saturation * saturationScale).clamp(0.0, 0.52))
        .withLightness(lightness)
        .toColor();
    return Color.lerp(muted, antiqueGold, goldBlend)!;
  }

  static Color eventTitle(Color raw) {
    return Color.lerp(
      softenAccent(
        raw,
        saturationScale: 0.54,
        lightness: 0.52,
        goldBlend: 0.08,
      ),
      const Color(0xFFE5D1A0),
      0.22,
    )!;
  }

  static Color dot(Color raw) {
    return Color.lerp(
      softenAccent(
        raw,
        saturationScale: 0.62,
        lightness: 0.54,
        goldBlend: 0.05,
      ),
      antiqueGold,
      0.08,
    )!;
  }
}

class _CalendarScale {
  static const double monthTitleMain = 27.5;
  static const double monthTitleFramed = 24.75;
  static const double monthTransliterationRatio = 0.60;
  static const double rightSeasonMain = 13.8;
  static const double rightSeasonFramed = 13.2;
  static const double decanLabelMain = 12.3;
  static const double decanLabelFramed = 11.6;
  static const double dayNumber = 12.4;
  static const double dayDot = 2.35;
  static const double trackSkyDot = 4.2;
  static const double infoHeading = 23.0;
  static const double infoBody = 18.4;
  static const double infoMeta = 14.7;
  static const double eventEyebrow = 9.2;
  static const double eventTitle = 21.5;
  static const double eventChip = 10.8;
  static const double eventPurpose = 9.5;
  static const double eventPurposeBody = 15.2;
}

const Color _kSoftGridBackground = _CalendarTone.previewCardBase;
final Color _kSoftDayTileFill = _CalendarTone.dayCellFill;
const Color _kSoftDayTileLabel = _CalendarTone.weekday;
const double _kMonthCardHorizontalInset = 16.0;
const double _kMonthCardTopInset = 8.0;
const double _kMonthCardBottomInset = 14.0;
const double _kMonthCardInnerPadding = 10.0;
const double _kMonthCardRadius = 18.0;
const double _kDecanColumnGap = 3.0;
const double _kDecanLabelToWeekdayGap = 4.0;
const double _kWeekdayToTileGap = 3.0;
const double _kDecanRowGap = 6.0;
const double _kDayTileRadius = 3.0;
const double _kDayTileBorderWidth = 0.45;
const double _kTodayDayTileBorderWidth = 1.0;
const double _kTodayDayTileStrokeAlpha = 0.54;
const double _kDayTileCompactPadding = 4.0;
const double _kDayTileExpandedHorizontalPadding = 1.5;
const double _kDayTileExpandedVerticalPadding = 4.0;
const double _kCompactMarkerGap = 1.0;
const double _kTextlessPillGap = 3.0;
const double _kLabeledPillGap = 4.0;
const double _kDetailsPillGap = 6.0;
const double _kTextlessPillHeight = 12.0;
const double _kLabeledPillHeight = 30.0;
const double _kDetailsPillHeight = 52.0;
const double _kTextlessPillRadius = 4.0;
const double _kLabeledPillRadius = 6.0;
const double _kDetailsPillRadius = 7.0;
const int _kTextlessPillVisibleCap = 2;
const int _kLabeledPillVisibleCap = 2;
const double _kFocusedMonthHeaderHeight = 64.0;
const double _kFocusedDecanHeight = 112.0;
const double _kFocusedDecanLabelHeight = 34.0;

bool _usesTabletLandscapeMonthGrid(BuildContext context) {
  final media = MediaQuery.of(context);
  return media.orientation == Orientation.landscape &&
      media.size.shortestSide >= 600;
}

int _detailsMonthVisibleEventCap(BuildContext context) {
  return _usesTabletLandscapeMonthGrid(context) ? 4 : 5;
}

double _detailsMonthMaxDecanHeight(BuildContext _) {
  return 300.0;
}

Color _softDayTileFill() => _kSoftDayTileFill;

Color _softDayTileLabel() => _kSoftDayTileLabel;

enum _CalendarDayTone { neutral, pastFar, pastNear, today, future }

class _CalendarDayToneSpec {
  const _CalendarDayToneSpec({
    required this.fill,
    required this.border,
    required this.number,
  });

  final Color fill;
  final Color border;
  final Color number;
}

_CalendarDayTone _calendarDayTone({
  required bool isToday,
  required bool isMonthToday,
  required bool temporalAnchorVisible,
  required int day,
  required int? todayDay,
}) {
  if (!isMonthToday || !temporalAnchorVisible || todayDay == null) {
    return _CalendarDayTone.neutral;
  }
  if (isToday) return _CalendarDayTone.today;

  final currentDecanStart = ((todayDay - 1) ~/ 10) * 10 + 1;
  if (day < currentDecanStart) return _CalendarDayTone.pastFar;
  if (day < todayDay) return _CalendarDayTone.pastNear;
  return _CalendarDayTone.future;
}

_CalendarDayToneSpec _calendarDayToneSpec(_CalendarDayTone tone) {
  switch (tone) {
    case _CalendarDayTone.pastFar:
      return _CalendarDayToneSpec(
        fill: Color.alphaBlend(
          _CalendarTone.antiqueGold.withValues(alpha: 0.029),
          _CalendarTone.velvetBlack,
        ),
        border: _CalendarTone.antiqueGold.withValues(alpha: 0.039),
        number: const Color(0xFF826F44),
      );
    case _CalendarDayTone.pastNear:
      return _CalendarDayToneSpec(
        fill: Color.alphaBlend(
          _CalendarTone.antiqueGold.withValues(alpha: 0.036),
          _CalendarTone.velvetBlack,
        ),
        border: _CalendarTone.antiqueGold.withValues(alpha: 0.050),
        number: const Color(0xFF8D7747),
      );
    case _CalendarDayTone.today:
      return _CalendarDayToneSpec(
        fill: _CalendarTone.selectedDayFill,
        border: _CalendarTone.selectedDayBorder.withValues(
          alpha: _kTodayDayTileStrokeAlpha,
        ),
        number: const Color(0xFFE2C862),
      );
    case _CalendarDayTone.future:
      return _CalendarDayToneSpec(
        fill: Color.alphaBlend(
          _CalendarTone.antiqueGold.withValues(alpha: 0.043),
          _CalendarTone.velvetBlack,
        ),
        border: _CalendarTone.antiqueGold.withValues(alpha: 0.054),
        number: const Color(0xFF9D854C),
      );
    case _CalendarDayTone.neutral:
      return _CalendarDayToneSpec(
        fill: _softDayTileFill(),
        border: _CalendarTone.dayCellBorder,
        number: _CalendarTone.dayNumber,
      );
  }
}

double _eventPillFontSize({
  required double maxWidth,
  required bool isDetailPill,
}) {
  if (!maxWidth.isFinite) return isDetailPill ? 10.0 : 9.4;
  if (isDetailPill) {
    if (maxWidth < 32) return 8.5;
    if (maxWidth < 36) return 9.0;
    if (maxWidth < 42) return 9.5;
    return 10.0;
  }
  if (maxWidth < 32) return 8.4;
  if (maxWidth < 36) return 8.8;
  return 9.4;
}

@visibleForTesting
Widget buildCalendarMonthCardLayoutForTesting({
  required int kYear,
  required int kMonth,
  required List<NoteData> Function(int kDay) notesForDay,
  MonthExpansionLevel expansionLevel = MonthExpansionLevel.details,
  bool showGregorian = false,
}) {
  _Note convert(NoteData note) {
    return _Note(
      id: note.id,
      clientEventId: note.clientEventId,
      calendarId: note.calendarId,
      calendarName: note.calendarName,
      title: note.title,
      detail: note.detail,
      location: note.location,
      allDay: note.allDay,
      start: note.start,
      end: note.end,
      flowId: note.flowId,
      manualColor: note.manualColor,
      category: note.category,
      isReminder: note.isReminder,
      reminderId: note.reminderId,
      behaviorPayload: note.behaviorPayload,
    );
  }

  List<_Note> notesGetter(int _, int day) =>
      notesForDay(day).map(convert).toList();

  List<Color> flowColorsGetter(int _, int _, int day) => [
    for (final note in notesForDay(day))
      if (note.manualColor != null) note.manualColor!,
  ];

  if (kMonth == CalendarSectionIndex.monthsPerYear) {
    return _EpagomenalCard(
      kYear: kYear,
      notesGetter: notesGetter,
      flowColorsGetter: flowColorsGetter,
      onDayTap: (_, _, _) {},
      showGregorian: showGregorian,
      expansionLevel: expansionLevel,
      noteColorResolver: (note) => note.manualColor ?? _defaultNoteColor(note),
      flowNameGetter: (_) => null,
    );
  }

  return _MonthCard(
    kYear: kYear,
    kMonth: kMonth,
    seasonShort: 'Akhet',
    todayMonth: null,
    todayDay: null,
    notesGetter: notesGetter,
    flowColorsGetter: flowColorsGetter,
    onDayTap: (_, _, _) {},
    showGregorian: showGregorian,
    expansionLevel: expansionLevel,
    noteColorResolver: (note) => note.manualColor ?? _defaultNoteColor(note),
    flowNameGetter: (_) => null,
  );
}

@visibleForTesting
Widget buildFocusedCalendarMonthGridForTesting({
  required int kYear,
  required int kMonth,
  required List<NoteData> Function(int kDay) notesForDay,
  int? todayDay,
  int? selectedDay,
  bool showGregorian = false,
  double decanHeight = _kFocusedDecanHeight,
  void Function(int day)? onDayTap,
}) {
  _Note convert(NoteData note) {
    return _Note(
      id: note.id,
      clientEventId: note.clientEventId,
      calendarId: note.calendarId,
      calendarName: note.calendarName,
      title: note.title,
      detail: note.detail,
      location: note.location,
      allDay: note.allDay,
      start: note.start,
      end: note.end,
      flowId: note.flowId,
      manualColor: note.manualColor,
      category: note.category,
      isReminder: note.isReminder,
      reminderId: note.reminderId,
      behaviorPayload: note.behaviorPayload,
    );
  }

  return _FocusedMonthGrid(
    kYear: kYear,
    kMonth: kMonth,
    seasonShort: getMonthById(kMonth).season.label,
    todayYear: todayDay == null ? null : kYear,
    todayMonth: todayDay == null ? null : kMonth,
    todayDay: todayDay,
    selectedDay: selectedDay,
    notesGetter: (_, day) => notesForDay(day).map(convert).toList(),
    flowColorsGetter: (_, _, day) => [
      for (final note in notesForDay(day))
        if (note.manualColor != null) note.manualColor!,
    ],
    onDayTap: (_, _, day) => onDayTap?.call(day),
    showGregorian: showGregorian,
    flowNameGetter: (_) => null,
    onMonthHeaderTap: (_) {},
    onDecanTap: (_, _) {},
    decanHeight: decanHeight,
  );
}

@visibleForTesting
Widget buildFocusedEpagomenalGridForTesting({
  required int kYear,
  required List<NoteData> Function(int kDay) notesForDay,
  int? todayDay,
  int? selectedDay,
  bool showGregorian = false,
  double dayRowHeight = _kFocusedDecanHeight * 3,
  void Function(int day)? onDayTap,
}) {
  _Note convert(NoteData note) {
    return _Note(
      id: note.id,
      clientEventId: note.clientEventId,
      calendarId: note.calendarId,
      calendarName: note.calendarName,
      title: note.title,
      detail: note.detail,
      location: note.location,
      allDay: note.allDay,
      start: note.start,
      end: note.end,
      flowId: note.flowId,
      manualColor: note.manualColor,
      category: note.category,
      isReminder: note.isReminder,
      reminderId: note.reminderId,
      behaviorPayload: note.behaviorPayload,
    );
  }

  return _FocusedEpagomenalGrid(
    kYear: kYear,
    todayYear: todayDay == null ? null : kYear,
    todayMonth: todayDay == null ? null : 13,
    todayDay: todayDay,
    selectedDay: selectedDay,
    notesGetter: (_, day) => notesForDay(day).map(convert).toList(),
    flowColorsGetter: (_, _, day) => [
      for (final note in notesForDay(day))
        if (note.manualColor != null) note.manualColor!,
    ],
    onDayTap: (_, _, day) => onDayTap?.call(day),
    showGregorian: showGregorian,
    flowNameGetter: (_) => null,
    onMonthHeaderTap: (_) {},
    dayRowHeight: dayRowHeight,
  );
}

class _SoftMonthNameTitle extends StatelessWidget {
  const _SoftMonthNameTitle({
    required this.shortName,
    required this.transliteration,
    required this.fontSize,
    required this.opacity,
    this.showTransliteration = true,
  });

  final String shortName;
  final String transliteration;
  final double fontSize;
  final double opacity;
  final bool showTransliteration;

  @override
  Widget build(BuildContext context) {
    final trans = transliteration.trim();
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          MonthNameText(
            shortName,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: TextStyle(
              color: Color.lerp(
                _CalendarTone.antiqueGold,
                _CalendarTone.dimGold,
                0.04,
              )?.withValues(alpha: opacity),
              fontSize: fontSize,
              height: 1.02,
              fontWeight: FontWeight.w600,
              fontFamily: 'CormorantGaramond',
              fontFamilyFallback: const ['GentiumPlus', 'NotoSans', 'Roboto'],
            ),
          ),
          if (showTransliteration && trans.isNotEmpty) ...[
            const SizedBox(width: 8),
            MonthNameText(
              '($trans)',
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                color: _CalendarTone.transliteration.withValues(
                  alpha: 0.88 * opacity,
                ),
                fontSize: fontSize * _CalendarScale.monthTransliterationRatio,
                height: 1.02,
                fontWeight: FontWeight.w400,
                fontFamily: 'CormorantGaramond',
                fontFamilyFallback: const ['GentiumPlus', 'NotoSans', 'Roboto'],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
  final bool temporalAnchorVisible;
  final bool framedSurface;

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
  final Future<EndFlowOutcome> Function(int flowId)? onEndFlow;
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
    this.temporalAnchorVisible = true,
    this.framedSurface = false,
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
      _CalendarDrillInRoute<void>(
        settings: const RouteSettings(name: calendarMonthDetailRouteName),
        builder: (_) => _MonthDetailPage(
          kYear: kYear,
          kMonth: kMonth,
          todayYear: todayMonth == null ? null : kYear,
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
      _CalendarDrillInRoute<void>(
        settings: const RouteSettings(name: calendarMonthDetailRouteName),
        builder: (_) => _MonthDetailPage(
          kYear: kYear,
          kMonth: kMonth,
          todayYear: todayMonth == null ? null : kYear,
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
      // Estimate visible pills for this decan and derive a height.
      // Header + tile padding + safe slack; each pill uses the details
      // pill height plus the inter-pill gap after the first.
      const double labelAreaHeight = 50.0;
      const double firstPillHeight = _kDetailsPillHeight;
      const double subsequentPillHeight =
          _kDetailsPillHeight + _kDetailsPillGap;
      const double overflowIndicatorHeight = 19.0;
      const double minHeight =
          80.0; // keep some presence for empty/one-pill decans
      final double maxHeight = _detailsMonthMaxDecanHeight(context);
      final maxVisibleEvents = _detailsMonthVisibleEventCap(context);

      final startDay = decanIndex * 10 + 1;
      int maxVisible = 0;
      bool hasHiddenEvents = false;
      for (int d = startDay; d < startDay + 10; d++) {
        final notes = notesGetter(kMonth, d);
        final visible = notes.length > maxVisibleEvents
            ? maxVisibleEvents
            : notes.length;
        if (visible > maxVisible) maxVisible = visible;
        if (notes.length > visible) hasHiddenEvents = true;
      }

      double pillsHeight = 0.0;
      if (maxVisible > 0) {
        pillsHeight = firstPillHeight;
        if (maxVisible > 1) {
          pillsHeight += subsequentPillHeight * (maxVisible - 1);
        }
        if (hasHiddenEvents) {
          pillsHeight += overflowIndicatorHeight;
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
    final monthMeta = getMonthById(kMonth);

    final isMonthToday = (todayMonth != null && todayMonth == kMonth);
    final gapBeforeRow = expansionLevel == MonthExpansionLevel.details
        ? 0.0
        : _kDecanLabelToWeekdayGap;
    final monthTitleSize = framedSurface
        ? _CalendarScale.monthTitleFramed
        : _CalendarScale.monthTitleMain;
    final rightLabelStyle = TextStyle(
      color: const Color(
        0xFF927842,
      ).withValues(alpha: framedSurface ? 0.92 : 0.86),
      fontSize: framedSurface
          ? _CalendarScale.rightSeasonFramed
          : _CalendarScale.rightSeasonMain,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.italic,
      fontFamily: 'CormorantGaramond',
      fontFamilyFallback: const ['GentiumPlus', 'NotoSans', 'Roboto'],
      letterSpacing: 0,
    );
    final decanLabelFontSize = framedSurface
        ? _CalendarScale.decanLabelFramed
        : _CalendarScale.decanLabelMain;
    final decanLabelRowHeight = decanLabelFontSize + 3.0;
    final decanLabelStrut = StrutStyle(
      fontFamily: 'GentiumPlus',
      fontSize: decanLabelFontSize,
      height: 1.0,
      forceStrutHeight: true,
    );
    const decanTextHeightBehavior = TextHeightBehavior(
      applyHeightToFirstAscent: false,
      applyHeightToLastDescent: false,
    );
    final decanLabelStyle = TextStyle(
      color: _CalendarTone.decanLabel.withValues(
        alpha: framedSurface ? 0.98 : 0.94,
      ),
      fontSize: decanLabelFontSize,
      height: 1.0,
      fontWeight: FontWeight.w500,
      fontFamily: 'GentiumPlus',
      fontFamilyFallback: const ['NotoSans', 'Roboto'],
    );
    final gregorianDecanLabelStyle = decanLabelStyle.copyWith(
      color: _CalendarTone.gregorianBlue.withValues(
        alpha: framedSurface ? 0.90 : 0.84,
      ),
    );

    Widget decanLabelText(String text, TextStyle style) {
      return Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        strutStyle: decanLabelStrut,
        textHeightBehavior: decanTextHeightBehavior,
      );
    }

    return Padding(
      key: anchorKey,
      padding: const EdgeInsets.fromLTRB(
        _kMonthCardHorizontalInset,
        _kMonthCardTopInset,
        _kMonthCardHorizontalInset,
        _kMonthCardBottomInset,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        color: framedSurface ? _kSoftGridBackground : Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        clipBehavior: framedSurface ? Clip.antiAlias : Clip.none,
        shape: RoundedRectangleBorder(
          side: framedSurface
              ? BorderSide(color: _CalendarTone.softCardBorder, width: 0.7)
              : BorderSide.none,
          borderRadius: BorderRadius.circular(_kMonthCardRadius),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kMonthCardRadius),
            gradient: framedSurface
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _CalendarTone.antiqueGold.withValues(alpha: 0.029),
                      Colors.transparent,
                    ],
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(_kMonthCardInnerPadding),
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
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: KeyedSubtree(
                            key: monthHeaderKey,
                            child: GestureDetector(
                              onTap: () {
                                if (onMonthHeaderTap != null) {
                                  onMonthHeaderTap!(context);
                                } else {
                                  _openMonthInfo(context);
                                }
                              },
                              child: _SoftMonthNameTitle(
                                shortName: monthMeta.displayShort,
                                transliteration:
                                    monthMeta.displayTransliteration,
                                fontSize: monthTitleSize,
                                opacity: framedSurface ? 0.98 : 0.96,
                                showTransliteration: false,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            rightLabel,
                            style: rightLabelStyle,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Three decans
                  for (var i = 0; i < 3; i++) ...[
                    // Label row: decan on left (Kemetic), Gregorian month on right when needed
                    Builder(
                      builder: (context) {
                        final gregDecanLabel = _gregLabelForDecanRow(
                          kYear,
                          kMonth,
                          i,
                        );
                        return SizedBox(
                          height: decanLabelRowHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (!showGregorian)
                                KeyedSubtree(
                                  key: currentDecanIndex == i
                                      ? keyForCurrentDecanHeader(
                                          kYear,
                                          kMonth,
                                          i,
                                        )
                                      : null,
                                  child: GestureDetector(
                                    onTap: () {
                                      if (onDecanTap != null) {
                                        onDecanTap!(context, i);
                                      } else {
                                        _openDecanInfo(context, i);
                                      }
                                    },
                                    child: decanLabelText(
                                      names[i],
                                      decanLabelStyle,
                                    ),
                                  ),
                                ),
                              if (!showGregorian) const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  height: 0.5,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _CalendarTone.softDivider,
                                        _CalendarTone.antiqueGold.withValues(
                                          alpha: 0.022,
                                        ),
                                        _CalendarTone.antiqueGold.withValues(
                                          alpha: 0.0,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (showGregorian && gregDecanLabel != null) ...[
                                const SizedBox(width: 10),
                                decanLabelText(
                                  gregDecanLabel,
                                  gregorianDecanLabelStyle,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    if (i == 2)
                      CalendarGeometryFinalDayBlock(
                        month: MonthRef(year: kYear, month: kMonth),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(height: gapBeforeRow),
                            _WeekdayRow(
                              kYear: kYear,
                              kMonth: kMonth,
                              decanIndex: i,
                              showGregorian: showGregorian,
                            ),
                          ],
                        ),
                      )
                    else ...[
                      SizedBox(height: gapBeforeRow),
                      _WeekdayRow(
                        kYear: kYear,
                        kMonth: kMonth,
                        decanIndex: i,
                        showGregorian: showGregorian,
                      ),
                    ],
                    const SizedBox(height: _kWeekdayToTileGap),

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
                      temporalAnchorVisible: temporalAnchorVisible,
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
                    if (i < 2) const SizedBox(height: _kDecanRowGap),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ); // Close Padding and return
  }
}

/// The month grid used only by the focused month/decan route.
///
/// The scrolling calendar deliberately keeps [_MonthCard] and its four event
/// density modes. Focused view instead gives each decan a full-width band and
/// each day a tall column, matching the spatial rhythm of a conventional
/// calendar while retaining the Kemetic labels and compact event signifiers.
class _FocusedMonthGrid extends StatelessWidget {
  const _FocusedMonthGrid({
    required this.kYear,
    required this.kMonth,
    required this.seasonShort,
    required this.todayYear,
    required this.todayMonth,
    required this.todayDay,
    required this.selectedDay,
    required this.notesGetter,
    required this.flowColorsGetter,
    required this.onDayTap,
    required this.showGregorian,
    required this.flowNameGetter,
    required this.onMonthHeaderTap,
    required this.onDecanTap,
    this.decanHeight = _kFocusedDecanHeight,
  });

  final int kYear;
  final int kMonth;
  final String seasonShort;
  final int? todayYear;
  final int? todayMonth;
  final int? todayDay;
  final int? selectedDay;
  final List<_Note> Function(int kMonth, int kDay) notesGetter;
  final List<Color> Function(int kYear, int kMonth, int kDay) flowColorsGetter;
  final void Function(BuildContext, int kMonth, int kDay) onDayTap;
  final bool showGregorian;
  final String? Function(_Note)? flowNameGetter;
  final void Function(BuildContext context) onMonthHeaderTap;
  final void Function(BuildContext context, int decanIndex) onDecanTap;
  final double decanHeight;

  String _rightLabel() {
    final startYear = KemeticMath.toGregorian(kYear, kMonth, 1).year;
    final endYear = KemeticMath.toGregorian(kYear, kMonth, 30).year;
    return startYear == endYear
        ? '$seasonShort $startYear'
        : '$seasonShort $startYear/$endYear';
  }

  @override
  Widget build(BuildContext context) {
    final month = getMonthById(kMonth);
    final names =
        DecanMetadata.decanNames[kMonth] ??
        const ['Decan A', 'Decan B', 'Decan C'];

    return Padding(
      padding: const EdgeInsets.only(bottom: _kMonthCardBottomInset),
      child: DecoratedBox(
        key: const ValueKey<String>('focused-month-grid'),
        decoration: BoxDecoration(
          color: _CalendarTone.velvetBlack,
          border: Border.all(
            color: _CalendarTone.antiqueGold.withValues(alpha: 0.16),
            width: 0.8,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: _kFocusedMonthHeaderHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onMonthHeaderTap(context),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _SoftMonthNameTitle(
                            shortName: month.displayShort,
                            transliteration: month.displayTransliteration,
                            fontSize: 30.5,
                            opacity: 0.98,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _rightLabel(),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: const Color(
                            0xFF927842,
                          ).withValues(alpha: 0.92),
                          fontSize: 15.2,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'CormorantGaramond',
                          fontFamilyFallback: const [
                            'GentiumPlus',
                            'NotoSans',
                            'Roboto',
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (var decanIndex = 0; decanIndex < 3; decanIndex++)
              _FocusedDecanBand(
                kYear: kYear,
                kMonth: kMonth,
                decanIndex: decanIndex,
                decanName: names[decanIndex],
                todayYear: todayYear,
                todayMonth: todayMonth,
                todayDay: todayDay,
                selectedDay: selectedDay,
                notesGetter: notesGetter,
                flowColorsGetter: flowColorsGetter,
                onDayTap: onDayTap,
                onDecanTap: onDecanTap,
                showGregorian: showGregorian,
                flowNameGetter: flowNameGetter,
                height: decanHeight,
              ),
          ],
        ),
      ),
    );
  }
}

/// The Heriu Renpet counterpart to [_FocusedMonthGrid].
///
/// Heriu Renpet has no decans, so its five or six days share one large,
/// full-width row while keeping the same header, lattice, selection, and event
/// treatment as the regular focused-month grid.
class _FocusedEpagomenalGrid extends StatelessWidget {
  const _FocusedEpagomenalGrid({
    required this.kYear,
    required this.todayYear,
    required this.todayMonth,
    required this.todayDay,
    required this.selectedDay,
    required this.notesGetter,
    required this.flowColorsGetter,
    required this.onDayTap,
    required this.showGregorian,
    required this.flowNameGetter,
    required this.onMonthHeaderTap,
    required this.dayRowHeight,
  });

  final int kYear;
  final int? todayYear;
  final int? todayMonth;
  final int? todayDay;
  final int? selectedDay;
  final List<_Note> Function(int kMonth, int kDay) notesGetter;
  final List<Color> Function(int kYear, int kMonth, int kDay) flowColorsGetter;
  final void Function(BuildContext, int kMonth, int kDay) onDayTap;
  final bool showGregorian;
  final String? Function(_Note)? flowNameGetter;
  final void Function(BuildContext context) onMonthHeaderTap;
  final double dayRowHeight;

  String _rightLabel(int dayCount) {
    final startYear = KemeticMath.toGregorian(kYear, 13, 1).year;
    final endYear = KemeticMath.toGregorian(kYear, 13, dayCount).year;
    final yearLabel = startYear == endYear
        ? '$startYear'
        : '$startYear/$endYear';
    return '${getMonthById(13).season.label} $yearLabel';
  }

  @override
  Widget build(BuildContext context) {
    final month = getMonthById(13);
    final dayCount = KemeticMath.isLeapKemeticYear(kYear) ? 6 : 5;
    final isCurrentMonth = todayYear == kYear && todayMonth == 13;

    return Padding(
      padding: const EdgeInsets.only(bottom: _kMonthCardBottomInset),
      child: DecoratedBox(
        key: const ValueKey<String>('focused-epagomenal-grid'),
        decoration: BoxDecoration(
          color: _CalendarTone.velvetBlack,
          border: Border.all(
            color: _CalendarTone.antiqueGold.withValues(alpha: 0.16),
            width: 0.8,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: _kFocusedMonthHeaderHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onMonthHeaderTap(context),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _SoftMonthNameTitle(
                            shortName: month.displayShort,
                            transliteration: month.displayTransliteration,
                            fontSize: 30.5,
                            opacity: 0.98,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _rightLabel(dayCount),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: const Color(
                            0xFF927842,
                          ).withValues(alpha: 0.92),
                          fontSize: 15.2,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'CormorantGaramond',
                          fontFamilyFallback: const [
                            'GentiumPlus',
                            'NotoSans',
                            'Roboto',
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: dayRowHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var dayIndex = 0; dayIndex < dayCount; dayIndex++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final day = dayIndex + 1;
                          return _FocusedDayCell(
                            dayKey: 'epagomenal_${day}_$kYear',
                            kYear: kYear,
                            kMonth: 13,
                            kDay: day,
                            isToday:
                                isCurrentMonth &&
                                todayDay != null &&
                                day == todayDay,
                            isSelected: day == selectedDay,
                            notes: notesGetter(13, day),
                            flowColors: flowColorsGetter(kYear, 13, day),
                            onTap: () => onDayTap(context, 13, day),
                            showGregorian: showGregorian,
                            flowNameGetter: flowNameGetter,
                            drawRightDivider: dayIndex < dayCount - 1,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusedDecanBand extends StatelessWidget {
  const _FocusedDecanBand({
    required this.kYear,
    required this.kMonth,
    required this.decanIndex,
    required this.decanName,
    required this.todayYear,
    required this.todayMonth,
    required this.todayDay,
    required this.selectedDay,
    required this.notesGetter,
    required this.flowColorsGetter,
    required this.onDayTap,
    required this.onDecanTap,
    required this.showGregorian,
    required this.flowNameGetter,
    required this.height,
  });

  final int kYear;
  final int kMonth;
  final int decanIndex;
  final String decanName;
  final int? todayYear;
  final int? todayMonth;
  final int? todayDay;
  final int? selectedDay;
  final List<_Note> Function(int kMonth, int kDay) notesGetter;
  final List<Color> Function(int kYear, int kMonth, int kDay) flowColorsGetter;
  final void Function(BuildContext, int kMonth, int kDay) onDayTap;
  final void Function(BuildContext context, int decanIndex) onDecanTap;
  final bool showGregorian;
  final String? Function(_Note)? flowNameGetter;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isCurrentMonth = todayYear == kYear && todayMonth == kMonth;
    return Container(
      key: ValueKey<String>('focused-decan-$decanIndex'),
      height: height,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: _CalendarTone.antiqueGold.withValues(alpha: 0.16),
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _kFocusedDecanLabelHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onDecanTap(context, decanIndex),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    decanName,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: const TextStyle(
                      color: _CalendarTone.decanLabel,
                      fontSize: 15.5,
                      height: 1,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'GentiumPlus',
                      fontFamilyFallback: ['NotoSans', 'Roboto'],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var columnIndex = 0; columnIndex < 10; columnIndex++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final day = decanIndex * 10 + columnIndex + 1;
                        return _FocusedDayCell(
                          dayKey: _getKemeticDayKey(kYear, kMonth, day),
                          kYear: kYear,
                          kMonth: kMonth,
                          kDay: day,
                          isToday:
                              isCurrentMonth &&
                              todayDay != null &&
                              day == todayDay,
                          isSelected: day == selectedDay,
                          notes: notesGetter(kMonth, day),
                          flowColors: flowColorsGetter(kYear, kMonth, day),
                          onTap: () => onDayTap(context, kMonth, day),
                          showGregorian: showGregorian,
                          flowNameGetter: flowNameGetter,
                          drawRightDivider: columnIndex < 9,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusedDayCell extends StatelessWidget {
  const _FocusedDayCell({
    required this.dayKey,
    required this.kYear,
    required this.kMonth,
    required this.kDay,
    required this.isToday,
    required this.isSelected,
    required this.notes,
    required this.flowColors,
    required this.onTap,
    required this.showGregorian,
    required this.flowNameGetter,
    required this.drawRightDivider,
  });

  final String dayKey;
  final int kYear;
  final int kMonth;
  final int kDay;
  final bool isToday;
  final bool isSelected;
  final List<_Note> notes;
  final List<Color> flowColors;
  final VoidCallback onTap;
  final bool showGregorian;
  final String? Function(_Note)? flowNameGetter;
  final bool drawRightDivider;

  static const List<String> _weekdayLetters = [
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  Widget _eventMarkers() {
    _Note? trackSkyNote;
    for (final note in notes) {
      if (_isTrackSkyFlowName(flowNameGetter?.call(note))) {
        trackSkyNote = note;
        break;
      }
    }
    if (trackSkyNote != null) {
      return _TrackSkyMicroSignifier(note: trackSkyNote);
    }
    if (flowColors.isNotEmpty) {
      final visibleColors = flowColors.take(3).toList(growable: false);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < visibleColors.length; i++) ...[
            if (i > 0) const SizedBox(width: 1.8),
            _ColorDot(color: visibleColors[i]),
          ],
        ],
      );
    }
    if (notes.isNotEmpty) {
      return const _GlossyDot(gradient: silverGloss);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final gregorian = safeLocalDisplay(
      KemeticMath.toGregorian(kYear, kMonth, kDay),
    );
    final label = showGregorian ? '${gregorian.day}' : '$kDay';
    final weekday = _weekdayLetters[gregorian.weekday - 1];
    final neutralNumber = _calendarDayToneSpec(
      isToday ? _CalendarDayTone.today : _CalendarDayTone.neutral,
    ).number;
    final numberColor = showGregorian
        ? _CalendarTone.gregorianBlue.withValues(alpha: 0.90)
        : (isSelected ? const Color(0xFFE2C862) : neutralNumber);
    final gridLine = BorderSide(
      color: _CalendarTone.antiqueGold.withValues(alpha: 0.18),
      width: 0.8,
    );
    final selectedBorder = BorderSide(
      color: _CalendarTone.antiqueGold.withValues(alpha: 0.92),
      width: 1.15,
    );

    return KemeticDayButton(
      dayKey: dayKey,
      kYear: kYear,
      child: InkWell(
        key: ValueKey<String>(
          'focused-day:$kYear-$kMonth-$kDay|${showGregorian ? "G" : "K"}',
        ),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isSelected
                ? _CalendarTone.selectedDayFill.withValues(alpha: 0.66)
                : Colors.transparent,
            border: Border(
              left: isSelected ? selectedBorder : BorderSide.none,
              top: isSelected ? selectedBorder : gridLine,
              right: isSelected
                  ? selectedBorder
                  : (drawRightDivider ? gridLine : BorderSide.none),
              bottom: isSelected ? selectedBorder : gridLine,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(7, 10, 2, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: TextStyle(
                          color: numberColor,
                          fontSize: 16.4,
                          height: 1,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'CormorantGaramond',
                          fontFamilyFallback: const [
                            'GentiumPlus',
                            'NotoSans',
                            'Roboto',
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      weekday,
                      style: TextStyle(
                        color: _CalendarTone.weekday.withValues(alpha: 0.82),
                        fontSize: 9.5,
                        height: 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (isToday) ...[
                  const SizedBox(height: 5),
                  Container(
                    width: double.infinity,
                    height: 1.6,
                    color: _CalendarTone.antiqueGold,
                  ),
                ] else
                  const SizedBox(height: 6.6),
                SizedBox(
                  height: 10,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Transform.scale(
                      scale: 1.22,
                      alignment: Alignment.centerLeft,
                      child: _eventMarkers(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    final labelColor = _softDayTileLabel();
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
                style: _weekdayLabelStyle.copyWith(color: labelColor),
              ),
            ),
          ),
          if (i < labels.length - 1) const SizedBox(width: _kDecanColumnGap),
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
  final bool temporalAnchorVisible;
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
  final Future<EndFlowOutcome> Function(int flowId)? onEndFlow;
  final Future<void> Function(String text)? onAppendToJournal;

  const _DecanRow({
    required this.kYear,
    required this.kMonth,
    required this.decanIndex,
    required this.todayMonth,
    required this.todayDay,
    required this.notesGetter,
    required this.flowColorsGetter,
    required this.temporalAnchorVisible,
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
              final tone = _calendarDayTone(
                isToday: isToday,
                isMonthToday: isMonthToday,
                temporalAnchorVisible: temporalAnchorVisible,
                day: day,
                todayDay: todayDay,
              );

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
                  tone: tone,
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
          if (j < 9) const SizedBox(width: _kDecanColumnGap),
        ],
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool isToday;
  final _CalendarDayTone tone;
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
  final Future<EndFlowOutcome> Function(int flowId)? onEndFlow;
  final Future<void> Function(String text)? onAppendToJournal;

  const _DayChip({
    super.key, // Add key parameter
    required this.label,
    required this.isToday,
    this.tone = _CalendarDayTone.neutral,
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
      fontWeight: FontWeight.w500,
      fontSize: _CalendarScale.dayNumber,
      fontFamily: 'CormorantGaramond',
      fontFamilyFallback: ['GentiumPlus', 'NotoSans', 'Roboto', 'Arial'],
      letterSpacing: 0.0,
    );

    final toneSpec = _calendarDayToneSpec(tone);
    final numberColor = showGregorian
        ? _CalendarTone.gregorianBlue.withValues(alpha: 0.90)
        : toneSpec.number;
    final numberStyle = textStyle.copyWith(color: numberColor);
    _Note? trackSkyHeaderNote;
    for (final note in notes) {
      if (_isTrackSkyFlowName(flowNameGetter?.call(note))) {
        trackSkyHeaderNote = note;
        break;
      }
    }
    final isCompact = expansionLevel == MonthExpansionLevel.compact;
    final isTextlessPill = expansionLevel == MonthExpansionLevel.stacked;
    final isLabeledPill = expansionLevel == MonthExpansionLevel.labeled;
    final isDetailsPill = expansionLevel == MonthExpansionLevel.details;
    final chipHeight = decanHeight ?? _chipHeightFor(expansionLevel);
    final nonCompactHeaderHeight = 24.0;
    final tileRadius = BorderRadius.circular(_kDayTileRadius);
    final tileFill = toneSpec.fill;
    final tileBorderColor = toneSpec.border;
    final tilePadding = isCompact
        ? const EdgeInsets.all(_kDayTileCompactPadding)
        : const EdgeInsets.symmetric(
            horizontal: _kDayTileExpandedHorizontalPadding,
            vertical: _kDayTileExpandedVerticalPadding,
          );

    Widget buildMiniBlocksCompact({required double maxWidth}) {
      const spacing = 1.8;
      const maxMarkersCap = 3;
      const trackSkyMarkerWidth = _CalendarScale.trackSkyDot;
      const colorDotWidth = _CalendarScale.dayDot;

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
      final maxBlocks = isTextlessPill
          ? _kTextlessPillVisibleCap
          : (isLabeledPill
                ? _kLabeledPillVisibleCap
                : (isDetailsPill ? _detailsMonthVisibleEventCap(context) : 1));

      int visibleCount = maxBlocks;
      if (isDetailsPill &&
          availableHeight != null &&
          availableHeight.isFinite) {
        const double estimatedPillHeight = _kDetailsPillHeight;
        const double spacingHeight = _kDetailsPillGap;
        const double overflowIndicatorHeight = 19.0;
        final double safeAvailableHeight = math.max(0, availableHeight - 2.0);

        double used = 0;
        int count = 0;
        while (count < sorted.length && count < maxBlocks) {
          final next = estimatedPillHeight + (count == 0 ? 0 : spacingHeight);
          if (used + next > safeAvailableHeight) break;
          used += next;
          count++;
        }

        final hasHidden = count < sorted.length;
        if (hasHidden &&
            count > 0 &&
            used + overflowIndicatorHeight > safeAvailableHeight) {
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
              dense: isTextlessPill,
              singleLineLabel: isLabeledPill,
              label: isLabeledPill || isDetailsPill
                  ? _labelFor(visible[i])
                  : null,
              expand: isDetailsPill,
              onTap: isDetailsPill
                  ? () => _showEventDetailFromNote(context, visible[i])
                  : null,
            ),
            if (i != visible.length - 1)
              SizedBox(
                height: isDetailsPill
                    ? _kDetailsPillGap
                    : (isLabeledPill ? _kLabeledPillGap : _kTextlessPillGap),
              ),
          ],
          if (remaining > 0 && isDetailsPill)
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
        borderRadius: tileRadius,
        child: SizedBox(
          key: anchorKey,
          width: double.infinity,
          height: chipHeight,
          child: ClipRRect(
            borderRadius: tileRadius,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tileFill,
                borderRadius: tileRadius,
                border: Border.all(
                  color: tileBorderColor,
                  width: isToday
                      ? _kTodayDayTileBorderWidth
                      : _kDayTileBorderWidth,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isToday)
                    Positioned(
                      left: 1,
                      top: 0,
                      right: 1,
                      child: IgnorePointer(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            color: _CalendarTone.antiqueGold.withValues(
                              alpha: 0.62,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(_kDayTileRadius),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (highlightAnchorKey != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: KeyedSubtree(
                          key: highlightAnchorKey,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  Padding(
                    padding: tilePadding,
                    child: isCompact
                        ? LayoutBuilder(
                            builder: (context, constraints) {
                              final maxWidth = constraints.maxWidth.isFinite
                                  ? constraints.maxWidth
                                  : 0.0;
                              return Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Flexible(
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: Text(
                                        label,
                                        style: numberStyle,
                                        maxLines: 1,
                                        overflow: TextOverflow.fade,
                                        softWrap: false,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: _kCompactMarkerGap),
                                  KeyedSubtree(
                                    key: ValueKey<String>(
                                      'k:$kYear-$kMonth-$kDay-marker|${showGregorian ? "G" : "K"}',
                                    ),
                                    child: IgnorePointer(
                                      child: ClipRect(
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: maxWidth,
                                          ),
                                          child: Align(
                                            alignment: Alignment.bottomCenter,
                                            child: buildMiniBlocksCompact(
                                              maxWidth: maxWidth,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: nonCompactHeaderHeight,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final maxWidth =
                                        constraints.maxWidth.isFinite
                                        ? constraints.maxWidth
                                        : 0.0;
                                    final canShowTrackSkyMotif =
                                        trackSkyHeaderNote != null &&
                                        maxWidth >= 14;
                                    final motifWidth = canShowTrackSkyMotif
                                        ? math.min(14.0, maxWidth * 0.4)
                                        : 0.0;
                                    final motifOffset = canShowTrackSkyMotif
                                        ? (motifWidth / 2) + 1.5
                                        : 0.0;
                                    final motifOnLeftEdge = kDay % 10 == 0;
                                    final motifSpec = trackSkyHeaderNote == null
                                        ? null
                                        : _trackSkyBadgeSpecForNote(
                                            trackSkyHeaderNote,
                                          );

                                    return Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        SizedBox(
                                          width: double.infinity,
                                          height: nonCompactHeaderHeight,
                                          child: Center(
                                            child: Text(
                                              label,
                                              style: numberStyle,
                                              maxLines: 1,
                                              overflow: TextOverflow.fade,
                                              softWrap: false,
                                            ),
                                          ),
                                        ),
                                        if (canShowTrackSkyMotif &&
                                            motifSpec != null)
                                          Positioned(
                                            top: 10,
                                            left: motifOnLeftEdge
                                                ? -motifOffset
                                                : null,
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
                                                      alignment:
                                                          Alignment.topCenter,
                                                      child: SizedBox(
                                                        height: 6.2,
                                                        child: FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          alignment: Alignment
                                                              .topCenter,
                                                          child: _buildTrackSkyBadgeMotif(
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
                                                      alignment: Alignment
                                                          .bottomCenter,
                                                      child: Container(
                                                        height: 1.8,
                                                        decoration: BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                999,
                                                              ),
                                                          gradient: LinearGradient(
                                                            colors: [
                                                              motifSpec
                                                                  .accentColor
                                                                  .withValues(
                                                                    alpha: 0.0,
                                                                  ),
                                                              motifSpec
                                                                  .accentColor
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
                  ),
                ],
              ),
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

    // For non-details modes, keep labels short and deterministic.
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
      behaviorPayload: note.behaviorPayload,
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
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => CalendarEventDetailSheet(
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
          onSaveFlow: state?._saveFlowById,
          dataVersion: state?._dayViewDataVersion,
          onRecordCompletion: state?._recordEventCompletion,
          onUnrecordCompletion: state?._unrecordEventCompletion,
          onRemoveCompletionBadge: (badgeId) async {
            final currentState = CalendarPage.globalKey.currentState;
            if (currentState?._journalInitialized == true) {
              await currentState!._journalController.removeBadge(badgeId);
            }
          },
          onWriteJournalResponse: (block) async {
            await CalendarPage.globalKey.currentState
                ?._writeMaatJournalResponseBlockAndRefresh(block);
          },
        ),
      ).whenComplete(releaseSheet);
    } catch (_) {
      releaseSheet();
      rethrow;
    }
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  const _ColorDot({required this.color});
  @override
  Widget build(BuildContext context) {
    final softened = _CalendarTone.dot(color).withValues(alpha: 0.86);
    return Container(
      width: _CalendarScale.dayDot,
      height: _CalendarScale.dayDot,
      decoration: BoxDecoration(
        color: softened,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: softened.withValues(alpha: 0.129), blurRadius: 1.2),
        ],
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
      width: _CalendarScale.trackSkyDot,
      height: _CalendarScale.trackSkyDot,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: spec.background,
        border: Border.all(
          color: spec.borderColor.withValues(alpha: 0.42),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 1.0,
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
  final bool singleLineLabel;
  final String? label;
  final VoidCallback? onTap;

  const _TrackSkyMiniBadge({
    required this.note,
    this.dense = true,
    this.expand = false,
    this.singleLineLabel = false,
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
    final double badgeHeight = isDetailPill
        ? _kDetailsPillHeight
        : (dense ? _kTextlessPillHeight : _kLabeledPillHeight);
    final double motifBoxWidth = showLabel
        ? (isDetailPill ? 18 : 15)
        : (dense ? 12 : 18);
    final double motifBoxHeight = dense ? 10 : 14;
    final EdgeInsetsGeometry padding = showLabel
        ? EdgeInsets.symmetric(
            horizontal: isDetailPill ? 3 : 3,
            vertical: isDetailPill ? 6 : 4,
          )
        : const EdgeInsets.symmetric(horizontal: 4, vertical: 2);
    final BorderRadius radius = BorderRadius.circular(
      isDetailPill
          ? _kDetailsPillRadius
          : (dense ? _kTextlessPillRadius : _kLabeledPillRadius),
    );

    final baseLabelStyle = TextStyle(
      color: spec.textColor,
      fontSize: isDetailPill ? 10.2 : 9.8,
      height: isDetailPill ? 1.13 : 1.16,
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
        final badge = Container(
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
                final labelStyle = baseLabelStyle.copyWith(
                  fontSize: _eventPillFontSize(
                    maxWidth: constraints.maxWidth,
                    isDetailPill: isDetailPill,
                  ),
                );

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
                                      maxLines: singleLineLabel
                                          ? 1
                                          : (isDetailPill ? 3 : 2),
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: !singleLineLabel,
                                      textAlign: TextAlign.center,
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
  final bool singleLineLabel;
  final String? label;
  const _MiniEventBlock({
    required this.note,
    required this.color,
    this.isTrackSky = false,
    this.dense = true,
    this.expand = false,
    this.singleLineLabel = false,
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
        singleLineLabel: singleLineLabel,
        label: label,
        onTap: onTap,
      );
    }

    final showLabel = label != null && !dense;
    final isDetailPill = expand && showLabel;
    final bg = color.withValues(alpha: dense ? 0.32 : 0.26);
    final border = color.withValues(alpha: 0.95);
    final double badgeHeight = isDetailPill
        ? _kDetailsPillHeight
        : (dense ? _kTextlessPillHeight : _kLabeledPillHeight);
    final BorderRadius radius = BorderRadius.circular(
      isDetailPill
          ? _kDetailsPillRadius
          : (dense ? _kTextlessPillRadius : _kLabeledPillRadius),
    );
    final TextStyle baseLabelStyle = TextStyle(
      color: Colors.white,
      fontSize: isDetailPill ? 10.2 : 9.8,
      height: isDetailPill ? 1.13 : 1.16,
      fontWeight: isDetailPill ? FontWeight.w600 : FontWeight.w500,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final double minW = dense
            ? (constraints.maxWidth.isFinite
                  ? math.min(24.0, constraints.maxWidth)
                  : 24.0)
            : 0.0;
        final double labelHorizontalPadding = constraints.maxWidth < 42
            ? 2.0
            : (isDetailPill ? 4.0 : 4.0);
        final EdgeInsetsGeometry padding = showLabel
            ? EdgeInsets.symmetric(
                horizontal: labelHorizontalPadding,
                vertical: isDetailPill ? 6.0 : 4.0,
              )
            : EdgeInsets.zero;
        final labelStyle = baseLabelStyle.copyWith(
          fontSize: _eventPillFontSize(
            maxWidth: constraints.maxWidth,
            isDetailPill: isDetailPill,
          ),
        );
        final container = Container(
          width: expand ? double.infinity : null,
          height: badgeHeight,
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: Border.all(color: border, width: dense ? 1.15 : 1.1),
          ),
          constraints: BoxConstraints(minWidth: minW),
          alignment: Alignment.center,
          child: showLabel
              ? Text(
                  label!,
                  maxLines: singleLineLabel ? 1 : (isDetailPill ? 3 : 2),
                  overflow: TextOverflow.ellipsis,
                  softWrap: !singleLineLabel,
                  textAlign: TextAlign.center,
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
    this.anchorKey,
    this.monthHeaderKey,
    this.dayAnchorKeyProvider,
    required this.kYear,
    this.todayMonth,
    this.todayDay,
    required this.notesGetter,
    required this.flowColorsGetter,
    required this.onDayTap,
    required this.showGregorian,
    this.temporalAnchorVisible = true,
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

  final Key? anchorKey;
  final Key? monthHeaderKey;
  final Key? Function(int kMonth, int kDay)? dayAnchorKeyProvider;
  final int kYear;
  final int? todayMonth;
  final int? todayDay;
  final List<_Note> Function(int kMonth, int kDay) notesGetter;
  final List<Color> Function(int kYear, int kMonth, int kDay) flowColorsGetter;
  final void Function(BuildContext, int kMonth, int kDay) onDayTap;
  final Key? todayDayKey;
  final bool showGregorian;
  final bool temporalAnchorVisible;
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
  final Future<EndFlowOutcome> Function(int flowId)? onEndFlow;
  final Future<void> Function(String text)? onAppendToJournal;

  // Weekday labels row for epagomenal days (5 or 6 days)
  Widget _epagomenalWeekdayRow(int dayCount) {
    final labelColor = _softDayTileLabel();
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
                style: _weekdayLabelStyle.copyWith(color: labelColor),
              ),
            ),
          ),
          if (i < labels.length - 1) const SizedBox(width: _kDecanColumnGap),
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
    final epagomenalMeta = getMonthById(13);

    // Dynamic height for epagomenal days (parallels regular decan sizing).
    double epagomenalHeightForLayout() {
      if (expansionLevel != MonthExpansionLevel.details) {
        return _chipHeightFor(expansionLevel);
      }
      const double labelAreaHeight = 50.0;
      const double firstPillHeight = _kDetailsPillHeight;
      const double subsequentPillHeight =
          _kDetailsPillHeight + _kDetailsPillGap;
      const double overflowIndicatorHeight = 19.0;
      const double minHeight = 80.0;
      final double maxHeight = _detailsMonthMaxDecanHeight(context);
      final maxVisibleEvents = _detailsMonthVisibleEventCap(context);

      int maxVisible = 0;
      bool hasHiddenEvents = false;
      for (int d = 1; d <= epiCount; d++) {
        final notes = notesGetter(13, d);
        final visible = notes.length > maxVisibleEvents
            ? maxVisibleEvents
            : notes.length;
        if (visible > maxVisible) maxVisible = visible;
        if (notes.length > visible) hasHiddenEvents = true;
      }

      double pillsHeight = 0.0;
      if (maxVisible > 0) {
        pillsHeight = firstPillHeight;
        if (maxVisible > 1) {
          pillsHeight += subsequentPillHeight * (maxVisible - 1);
        }
        if (hasHiddenEvents) {
          pillsHeight += overflowIndicatorHeight;
        }
      }

      final double estimated = labelAreaHeight + pillsHeight;
      return estimated.clamp(minHeight, maxHeight);
    }

    final double epagomenalHeight = epagomenalHeightForLayout();

    return Padding(
      key: anchorKey,
      padding: EdgeInsets.fromLTRB(
        _kMonthCardHorizontalInset,
        6,
        _kMonthCardHorizontalInset,
        expansionLevel == MonthExpansionLevel.details ? 6 : 24,
      ),
      child: Card(
        color: _CalendarTone.calendarBlack,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide.none,
          borderRadius: BorderRadius.circular(_kMonthCardRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(_kMonthCardInnerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Kemetic header (left) and Gregorian month (right when present)
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Visibility(
                        visible: !showGregorian,
                        maintainState: true,
                        maintainAnimation: true,
                        maintainSize: true,
                        child: KeyedSubtree(
                          key: monthHeaderKey,
                          child: _SoftMonthNameTitle(
                            shortName: epagomenalMeta.displayShort,
                            transliteration:
                                epagomenalMeta.displayTransliteration,
                            fontSize: _CalendarScale.monthTitleMain,
                            opacity: 0.96,
                            showTransliteration: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Visibility(
                        visible: showGregorian && gLabel != null,
                        maintainState: true,
                        maintainAnimation: true,
                        maintainSize: true,
                        child: Text(
                          gLabel ?? '',
                          style: _decanStyle.copyWith(
                            color: _CalendarTone.gregorianBlue.withValues(
                              alpha: 0.82,
                            ),
                            fontSize: _CalendarScale.decanLabelMain,
                            height: 1.0,
                            fontFamily: 'GentiumPlus',
                            fontFamilyFallback: const ['NotoSans', 'Roboto'],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: expansionLevel == MonthExpansionLevel.details ? 0 : 10,
              ),

              CalendarGeometryFinalDayBlock(
                month: MonthRef(year: kYear, month: 13),
                child: _epagomenalWeekdayRow(epiCount),
              ),
              const SizedBox(height: _kWeekdayToTileGap),

              Row(
                children: [
                  for (int i = 0; i < epiCount; i++) ...[
                    Expanded(
                      child: _DayChip(
                        anchorKey: isMonthToday && (todayDay == i + 1)
                            ? todayDayKey
                            : null, // 🔑
                        highlightAnchorKey: dayAnchorKeyProvider?.call(
                          13,
                          i + 1,
                        ),
                        label: showGregorian
                            ? '${KemeticMath.toGregorian(kYear, 13, i + 1).day}'
                            : '${i + 1}',
                        isToday: isMonthToday && (todayDay == i + 1),
                        tone: _calendarDayTone(
                          isToday: isMonthToday && (todayDay == i + 1),
                          isMonthToday: isMonthToday,
                          temporalAnchorVisible: temporalAnchorVisible,
                          day: i + 1,
                          todayDay: todayDay,
                        ),
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
                    if (i < epiCount - 1)
                      const SizedBox(width: _kDecanColumnGap),
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
