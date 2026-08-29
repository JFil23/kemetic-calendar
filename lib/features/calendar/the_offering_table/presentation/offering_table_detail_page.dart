import 'package:flutter/material.dart';
import 'package:mobile/widgets/keyboard_aware.dart';
import 'package:mobile/widgets/maat_flow_date_picker.dart';

import 'package:mobile/features/calendar/calendar_event_visual_style.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_calendar_preview.dart';
import 'package:mobile/features/calendar/maat_flow_visual_tokens.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_preview_day.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_thirty_day_calendar.dart';
import 'package:mobile/features/calendar/presentation/instrument_event_presentation_frame.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_day_components.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_day_presentation.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_event_block_visual.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_presentation_copy.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/the_offering_table_local_store.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';

typedef OfferingTableJoinCallback =
    Future<int> Function({
      required DateTime startDate,
      required TrackSkyTimeZone timezone,
      required OfferingTableLens lens,
      required bool noCupMode,
    });

abstract final class OfferingTableDetailTokens {
  static const Color pageBackground = Color(0xFF070502);
  static const Color sheetBackground = Color(0xFF0C0905);
  static const Color warmGold = Color(0xFFC99A3D);
  static const Color deepBrown = Color(0xFF5C3918);
  static const Color mutedIvory = Color(0xFFD7CDBA);
  static const Color silver = Color(0xFFA59D91);
  static const Color muted = Color(0xFF756C60);
  static const Color glow = Color(0xFFF0C96A);
  static const Color separator = Color(0xFF302313);
  static const String heroAsset = 'assets/the_offering_table/hero.png';
  static const double heroImageAlignmentY = 0.5;

  static const MaatFlowDetailTheme theme = MaatFlowDetailTheme(
    pageBackground: pageBackground,
    sheetBackground: sheetBackground,
    sheetBorder: Color(0x4AC99A3D),
    accent: warmGold,
    primaryText: mutedIvory,
    secondaryText: silver,
    mutedText: muted,
    separator: separator,
    glow: glow,
  );

  static const MaatFlowThirtyDayCalendarTheme thirtyDayCalendarTheme =
      MaatFlowThirtyDayCalendarTheme(
        introText: mutedIvory,
        introEmphasis: silver,
        border: Color(0x3DC99A3D),
        month: warmGold,
        monthTransliteration: Color(0xFF9A7635),
        decan: Color(0xFFA9853D),
        day: Color(0xFFB59150),
        today: glow,
        highlight: warmGold,
      );

  static const MaatFlowPreviewTheme previewTheme = MaatFlowPreviewTheme(
    surface: Color(0xFF160F07),
    border: Color(0x3DC99A3D),
    shadow: Color(0x0AC99A3D),
    kemeticDate: warmGold,
    gregorianDate: Color(0xFFD3B06A),
    divider: Color(0x2BC99A3D),
    primaryText: mutedIvory,
    secondaryText: silver,
  );

  static const CalendarEventGraphicStyle eventGraphic =
      CalendarEventGraphicStyle(
        kind: CalendarEventGraphicKind.offeringTable,
        background: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF120B04), Color(0xFF38210D), Color(0xFF8A5723)],
        ),
        flowLabelGradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [glow, warmGold, mutedIvory, warmGold],
        ),
        borderColor: warmGold,
        accentColor: glow,
        accentSecondaryColor: mutedIvory,
        titleColor: Color(0xFFFFF2D7),
        labelColor: glow,
        detailColor: mutedIvory,
        glowColor: warmGold,
      );
}

/// Dedicated Offering Table presentation. The preview is derived locally from
/// existing domain schedules; join generation and persistence remain unchanged.
class OfferingTableDetailPage extends StatefulWidget {
  const OfferingTableDetailPage({
    super.key,
    required this.timezone,
    required this.onJoin,
    this.calendarPreview = FollowSkyCalendarPreview.empty,
    this.initialStartDate,
    this.joinedFlowId,
    this.joinedStartDate,
    this.joinedScheduleDates = const <DateTime>[],
    this.lens = OfferingTableLens.neutral,
    this.noCupMode = false,
    this.showBackButton = true,
    this.resizeToAvoidBottomInset = true,
    this.localStore = const OfferingTableLocalStore(),
  });

  final TrackSkyTimeZone timezone;
  final OfferingTableJoinCallback onJoin;
  final FollowSkyCalendarPreview calendarPreview;
  final DateTime? initialStartDate;
  final int? joinedFlowId;
  final DateTime? joinedStartDate;
  final List<DateTime> joinedScheduleDates;
  final OfferingTableLens lens;
  final bool noCupMode;
  final bool showBackButton;
  final bool resizeToAvoidBottomInset;
  final OfferingTableLocalStore localStore;

  @override
  State<OfferingTableDetailPage> createState() =>
      _OfferingTableDetailPageState();
}

class _OfferingTableDetailPageState extends State<OfferingTableDetailPage> {
  late DateTime _draftStartDate;
  int? _carriedFlowId;
  final TextEditingController _initialEntryController = TextEditingController();
  bool _joining = false;
  bool _showAllDays = false;

  @override
  void initState() {
    super.initState();
    _draftStartDate = DateUtils.dateOnly(
      widget.initialStartDate ?? defaultOfferingTableStartDate(widget.timezone),
    );
    _carriedFlowId = widget.joinedFlowId;
    _loadJoinedNeed();
  }

  @override
  void didUpdateWidget(covariant OfferingTableDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.joinedFlowId != oldWidget.joinedFlowId) {
      _carriedFlowId = widget.joinedFlowId;
      _loadJoinedNeed();
    }
  }

  bool get _joined => _carriedFlowId != null;

  DateTime get _startDate {
    if (widget.joinedFlowId == null) return _draftStartDate;
    final joinedStart = widget.joinedStartDate;
    if (joinedStart != null) return DateUtils.dateOnly(joinedStart);
    if (widget.joinedScheduleDates.isNotEmpty) {
      final ordered =
          widget.joinedScheduleDates.map(DateUtils.dateOnly).toList()..sort();
      return ordered.first;
    }
    throw StateError('A joined Offering Table must have a persisted schedule.');
  }

  Future<void> _loadJoinedNeed() async {
    final flowId = _carriedFlowId;
    if (flowId == null) return;
    final need = await widget.localStore.loadNeed(flowId);
    if (!mounted || _carriedFlowId != flowId) return;
    _initialEntryController.text = need;
  }

  @override
  void dispose() {
    _initialEntryController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_joining || _joined) return;
    setState(() => _joining = true);
    int id;
    try {
      id = await widget.onJoin(
        startDate: _startDate,
        timezone: widget.timezone,
        lens: widget.lens,
        noCupMode: widget.noCupMode,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not join The Offering Table. Please retry.'),
        ),
      );
      setState(() => _joining = false);
      return;
    }
    if (id <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not join The Offering Table. Please retry.'),
        ),
      );
      setState(() => _joining = false);
      return;
    }

    // The staged flow is the join authority. Private local copy must never
    // turn a successful calendar join into a retryable second enrollment.
    try {
      await widget.localStore.saveNeed(id, _initialEntryController.text);
    } catch (error, stackTrace) {
      debugPrint('[OfferingTable] private need save failed after join: $error');
      debugPrint('$stackTrace');
    }
    if (!mounted) return;
    setState(() {
      _carriedFlowId = id;
      _joining = false;
    });
  }

  Future<void> _openOfferingDaySheet(
    OfferingTablePreviewOccurrence occurrence,
  ) async {
    var extent = 0.58;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useRootNavigator: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final media = MediaQuery.of(context);
          final availableHeight =
              media.size.height - media.padding.top - media.padding.bottom - 12;
          return SizedBox(
            key: const ValueKey<String>('offering-table-preview-sheet-host'),
            height: availableHeight * extent,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: DayViewBottomSheetFrame(
                child: Column(
                  children: <Widget>[
                    InstrumentEventSheetTopBar(
                      semanticLabel: 'Resize Offering Table preview',
                      handleColor: const Color(0x7AD4AE43),
                      onVerticalDragUpdate: (details) {
                        final delta = details.primaryDelta;
                        if (delta == null || availableHeight <= 0) return;
                        setSheetState(() {
                          extent = (extent - delta / availableHeight)
                              .clamp(0.58, 1.0)
                              .toDouble();
                        });
                      },
                      trailing: IconButton(
                        key: const ValueKey<String>(
                          'offering-table-preview-sheet-close',
                        ),
                        tooltip: 'Close Offering Table practice',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Color(0xFFA59D91),
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        child: OfferingTableDayPresentation(
                          day: occurrence.day,
                          localDate: occurrence.date,
                          startMinute:
                              occurrence.startLocal.hour * 60 +
                              occurrence.startLocal.minute,
                          initialNeed: _initialEntryController.text,
                          lens: widget.lens,
                          persistResponses: false,
                          completionPanel:
                              const _OfferingPreviewCompletionPanel(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickStartDate() async {
    if (_joined) return;
    final result = await MaatFlowDatePicker.show(
      context: context,
      initialDate: _startDate,
      initialMode: MaatFlowDatePickerMode.gregorian,
    );
    if (result == null || !mounted) return;

    setState(() {
      _draftStartDate = DateUtils.dateOnly(result.date);
    });
  }

  String _initialEntryIntro() {
    final today = DateUtils.dateOnly(offeringTableNowInZone(widget.timezone));
    final tomorrow = today.add(const Duration(days: 1));
    final timing = DateUtils.isSameDay(_startDate, tomorrow)
        ? 'Tomorrow'
        : DateUtils.isSameDay(_startDate, today)
        ? 'Today'
        : 'On ${_shortMonthDay(_startDate)}';
    return 'Provision begins with the most basic need. '
        '$timing you practice noticing yours before the day takes over.';
  }

  List<OfferingTablePreviewOccurrence> _previewOccurrences() {
    final persistedDates = _joined
        ? (widget.joinedScheduleDates.map(DateUtils.dateOnly).toList()..sort())
        : const <DateTime>[];
    return [
      for (final day in kOfferingTableDays)
        () {
          final index = day.dayNumber - 1;
          final date = index < persistedDates.length
              ? persistedDates[index]
              : _startDate.add(Duration(days: index));
          final schedule = offeringTableScheduleForDate(
            day,
            date,
            widget.timezone,
          );
          return OfferingTablePreviewOccurrence(
            day: day,
            date: DateUtils.dateOnly(schedule.startLocal),
            startLocal: schedule.startLocal,
          );
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final body = MaatFlowDetailShell(
      theme: OfferingTableDetailTokens.theme,
      scrollKey: const ValueKey<String>('offering-table-scroll'),
      heroLayerKey: const ValueKey<String>('offering-table-hero-layer'),
      sheetKey: const ValueKey<String>('offering-table-sheet'),
      hero: const _OfferingTableHero(),
      bottomDock: MaatFlowDetailDock(
        theme: OfferingTableDetailTokens.theme,
        joined: _joined,
        busy: _joining,
        onPressed: _join,
        actionLabel: 'Carry this table',
        actionNote: 'Nothing is added until you carry it.',
        joinedLabel: 'In your calendar',
        joinedNote: 'Return to the table each morning. Change anything later.',
        actionKey: const ValueKey<String>('offering-table-join'),
        joinedKey: const ValueKey<String>('offering-table-joined'),
      ),
      sheet: _buildSheet(),
    );

    return Scaffold(
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      backgroundColor: OfferingTableDetailTokens.pageBackground,
      body: Stack(
        children: [
          body,
          if (widget.showBackButton)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 4,
              left: 4,
              child: IconButton(
                tooltip: 'Back',
                icon: const Icon(
                  Icons.arrow_back,
                  color: OfferingTableDetailTokens.warmGold,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSheet() {
    final occurrences = _previewOccurrences();
    final today = DateUtils.dateOnly(offeringTableNowInZone(widget.timezone));
    final surfaced = occurrences.take(5).toList(growable: false);
    final remaining = occurrences.skip(5).toList(growable: false);
    final ordinaryRowsByDay = _ordinaryRowsByDay(occurrences);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MaatFlowThirtyDayCalendar(
          key: const ValueKey<String>('offering-table-thirty-day-calendar'),
          windowStart: _startDate,
          markers: [
            for (final occurrence in occurrences)
              MaatFlowThirtyDayMarker(
                date: occurrence.date,
                isToday: DateUtils.isSameDay(occurrence.date, today),
                highlighted: true,
                filled: _joined,
                accent: OfferingTableDetailTokens.warmGold,
                topLabel: occurrence.day.dayNumber == 1 ? 'START DATE' : null,
                onTopLabelTap: occurrence.day.dayNumber == 1 && !_joined
                    ? _pickStartDate
                    : null,
                topLabelSemanticLabel: occurrence.day.dayNumber == 1 && !_joined
                    ? 'Change start date'
                    : null,
                secondaryColors:
                    ordinaryRowsByDay[occurrence.date]
                        ?.map((row) => row.eventColor)
                        .toList() ??
                    const <Color>[],
              ),
          ],
          theme: OfferingTableDetailTokens.thirtyDayCalendarTheme,
          introFirstLine: 'Here is your table.',
          introSecondLine: 'For the next thirty days.',
          keyPrefix: 'offering-table-calendar',
        ),
        _OfferingTableInitialEntry(
          controller: _initialEntryController,
          introText: _initialEntryIntro(),
          readOnly: _joined,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < surfaced.length; i++) ...[
                _OfferingPreviewDay(
                  occurrence: surfaced[i],
                  carried: _joined,
                  calendarRows:
                      ordinaryRowsByDay[surfaced[i].date] ??
                      const <FollowSkyCalendarPreviewRow>[],
                  onOpenOfferingDay: _openOfferingDaySheet,
                ),
                if (i != surfaced.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        _OfferingAllDaysList(
          remaining: remaining,
          expanded: _showAllDays,
          onToggle: () => setState(() => _showAllDays = !_showAllDays),
          onOpenOfferingDay: _openOfferingDaySheet,
        ),
      ],
    );
  }

  Map<DateTime, List<FollowSkyCalendarPreviewRow>> _ordinaryRowsByDay(
    List<OfferingTablePreviewOccurrence> occurrences,
  ) {
    final windowDays = <DateTime>{
      for (final occurrence in occurrences) occurrence.date,
    };
    final rowsByDay = <DateTime, List<FollowSkyCalendarPreviewRow>>{};
    for (final row in widget.calendarPreview.rows) {
      if (isOfferingTableFlowReference(flowName: row.flowName)) continue;
      final day = DateUtils.dateOnly(row.localDay);
      if (!windowDays.contains(day)) continue;
      rowsByDay.putIfAbsent(day, () => []).add(row);
    }
    for (final rows in rowsByDay.values) {
      rows.sort((a, b) => a.start.compareTo(b.start));
    }
    return rowsByDay;
  }
}

class _OfferingTableHero extends StatelessWidget {
  const _OfferingTableHero();

  @override
  Widget build(BuildContext context) {
    return MaatFlowDetailHero(
      key: const ValueKey<String>('offering-table-hero'),
      theme: OfferingTableDetailTokens.theme,
      background: const _OfferingTableHeroBackdrop(),
      glyph: kOfferingTableGlyph,
      glyphKey: const ValueKey<String>('offering-table-hero-glyph'),
      glyphGradient: const RadialGradient(
        center: Alignment(-0.28, -0.42),
        radius: 0.92,
        colors: [Color(0xFFE2B559), Color(0xFF62401D), Color(0xFF120B04)],
      ),
      glyphBorder: OfferingTableDetailTokens.warmGold,
      glyphGlow: OfferingTableDetailTokens.glow,
      title: 'The Offering\nTable',
      subtitle: kOfferingTableTagline,
    );
  }
}

class _OfferingTableHeroBackdrop extends StatelessWidget {
  const _OfferingTableHeroBackdrop();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            OfferingTableDetailTokens.heroAsset,
            key: const ValueKey<String>('offering-table-hero-image'),
            fit: BoxFit.cover,
            alignment: Alignment(
              0,
              OfferingTableDetailTokens.heroImageAlignmentY * 2 - 1,
            ),
            errorBuilder: (context, error, stackTrace) => const ColoredBox(
              color: OfferingTableDetailTokens.pageBackground,
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x10070502),
                  Color(0x18070502),
                  Color(0x4D070502),
                  Color(0xB3070502),
                ],
                stops: [0.0, 0.46, 0.70, 1.0],
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 200,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x24070502),
                    OfferingTableDetailTokens.pageBackground,
                    OfferingTableDetailTokens.pageBackground,
                  ],
                  stops: [0.0, 0.38, 0.92, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferingTableInitialEntry extends StatelessWidget {
  const _OfferingTableInitialEntry({
    required this.controller,
    required this.introText,
    required this.readOnly,
  });

  final TextEditingController controller;
  final String introText;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('offering-table-initial-entry'),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: OfferingTableDetailTokens.separator),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'HOW THE TABLE WORKS',
                style: TextStyle(
                  color: OfferingTableDetailTokens.warmGold,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 2.2,
                  height: 1,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Divider(
                  color: OfferingTableDetailTokens.separator,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            introText,
            style: const TextStyle(
              color: OfferingTableDetailTokens.mutedIvory,
              fontFamily: MaatFlowListTokens.fontFamily,
              fontFamilyFallback: MaatFlowListTokens.fontFallback,
              fontSize: 17,
              height: 1.42,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'WHAT NEEDS FEEDING?',
            style: TextStyle(
              color: OfferingTableDetailTokens.warmGold,
              fontFamily: MaatFlowListTokens.fontFamily,
              fontFamilyFallback: MaatFlowListTokens.fontFallback,
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              letterSpacing: 2.73,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Name one need you have been putting off',
            style: TextStyle(
              color: OfferingTableDetailTokens.mutedIvory,
              fontFamily: MaatFlowListTokens.fontFamily,
              fontFamilyFallback: MaatFlowListTokens.fontFallback,
              fontSize: 23.5,
              fontWeight: FontWeight.w400,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 24),
          Focus(
            child: TextField(
              key: const ValueKey<String>('offering-table-initial-input'),
              controller: controller,
              readOnly: readOnly,
              scrollPadding: keyboardManagedTextFieldScrollPadding,
              cursorColor: OfferingTableDetailTokens.warmGold,
              style: const TextStyle(
                color: OfferingTableDetailTokens.glow,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 21,
                fontWeight: FontWeight.w300,
                fontStyle: FontStyle.italic,
                height: 1.3,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Name the need…',
                hintStyle: TextStyle(
                  color: OfferingTableDetailTokens.muted.withValues(alpha: 0.8),
                ),
                contentPadding: const EdgeInsets.fromLTRB(2, 4, 2, 11),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: OfferingTableDetailTokens.glow.withValues(
                      alpha: 0.30,
                    ),
                  ),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: OfferingTableDetailTokens.glow.withValues(
                      alpha: 0.30,
                    ),
                  ),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: OfferingTableDetailTokens.warmGold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferingPreviewDay extends StatelessWidget {
  const _OfferingPreviewDay({
    required this.occurrence,
    required this.carried,
    required this.onOpenOfferingDay,
    this.calendarRows = const <FollowSkyCalendarPreviewRow>[],
  });

  final OfferingTablePreviewOccurrence occurrence;
  final bool carried;
  final ValueChanged<OfferingTablePreviewOccurrence> onOpenOfferingDay;
  final List<FollowSkyCalendarPreviewRow> calendarRows;

  @override
  Widget build(BuildContext context) {
    final day = occurrence.day;
    final rows = <({DateTime start, Widget child})>[
      (
        start: occurrence.startLocal,
        child: _OfferingFlowEventCard(
          occurrence: occurrence,
          carried: carried,
          onTap: () => onOpenOfferingDay(occurrence),
        ),
      ),
      for (final row in calendarRows)
        (
          start: row.start,
          child: MaatFlowPreviewEventRow(
            timeLabel: row.allDay ? 'All day' : _formatTime(row.start),
            title: row.title,
            accent: row.eventColor,
            theme: OfferingTableDetailTokens.previewTheme,
          ),
        ),
    ]..sort((a, b) => a.start.compareTo(b.start));
    return MaatFlowPreviewDayCard(
      key: ValueKey<String>('offering-table-preview-day-${day.dayNumber}'),
      date: occurrence.date,
      theme: OfferingTableDetailTokens.previewTheme,
      children: [for (final row in rows) row.child],
    );
  }
}

class _OfferingFlowEventCard extends StatelessWidget {
  const _OfferingFlowEventCard({
    required this.occurrence,
    required this.carried,
    required this.onTap,
  });

  final OfferingTablePreviewOccurrence occurrence;
  final bool carried;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final day = occurrence.day;
    final title = offeringTableEventTitle(day);
    final isNarrow = MediaQuery.sizeOf(context).width <= 350;
    return Semantics(
      button: true,
      label: 'View practice for $title',
      child: GestureDetector(
        key: ValueKey<String>('offering-table-preview-event-${day.dayNumber}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: OfferingTableEventBlockVisual(
            graphic: OfferingTableDetailTokens.eventGraphic,
            height: 100,
            width: double.infinity,
            isPreview: !carried,
            dashedBorder: !carried,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 27, bottom: 11),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          color: carried
                              ? OfferingTableDetailTokens.warmGold
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: OfferingTableDetailTokens.glow,
                            width: 1,
                          ),
                        ),
                      ),
                      SizedBox(width: isNarrow ? 9 : 11),
                      SizedBox(
                        width: isNarrow ? 51 : 56,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Text(
                            _formatTime(occurrence.startLocal),
                            style: TextStyle(
                              color: OfferingTableDetailTokens.glow.withValues(
                                alpha: 0.72,
                              ),
                              fontFamily: MaatFlowListTokens.fontFamily,
                              fontFamilyFallback:
                                  MaatFlowListTokens.fontFallback,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xFFFFF2D7),
                                  fontFamily: MaatFlowListTokens.fontFamily,
                                  fontFamilyFallback:
                                      MaatFlowListTokens.fontFallback,
                                  fontSize: isNarrow ? 15.5 : 18,
                                  fontWeight: FontWeight.w500,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                offeringTablePracticePresentation(
                                  day,
                                ).previewSummary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: OfferingTableDetailTokens.silver,
                                  fontFamily: MaatFlowListTokens.fontFamily,
                                  fontFamilyFallback:
                                      MaatFlowListTokens.fontFallback,
                                  fontSize: isNarrow ? 12.5 : 13,
                                  fontStyle: FontStyle.italic,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 35,
                  child: Icon(
                    Icons.chevron_right,
                    key: ValueKey<String>(
                      'offering-table-preview-chevron-${day.dayNumber}',
                    ),
                    size: 19,
                    color: OfferingTableDetailTokens.glow.withValues(
                      alpha: 0.88,
                    ),
                  ),
                ),
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Text(
                    'VIEW PRACTICE',
                    key: ValueKey<String>(
                      'offering-table-preview-affordance-${day.dayNumber}',
                    ),
                    style: TextStyle(
                      color: OfferingTableDetailTokens.glow.withValues(
                        alpha: 0.78,
                      ),
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.05,
                      height: 1,
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

class _OfferingAllDaysList extends StatelessWidget {
  const _OfferingAllDaysList({
    required this.remaining,
    required this.expanded,
    required this.onToggle,
    required this.onOpenOfferingDay,
  });

  final List<OfferingTablePreviewOccurrence> remaining;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<OfferingTablePreviewOccurrence> onOpenOfferingDay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: InkWell(
              key: ValueKey<String>(
                expanded
                    ? 'offering-table-show-fewer'
                    : 'offering-table-show-all',
              ),
              onTap: onToggle,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 2,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0x3DC99A3D)),
                    bottom: BorderSide(color: Color(0x3DC99A3D)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        expanded ? 'Show first 5 days' : 'All 30 offerings',
                        style: const TextStyle(
                          color: OfferingTableDetailTokens.mutedIvory,
                          fontFamily: MaatFlowListTokens.fontFamily,
                          fontFamilyFallback: MaatFlowListTokens.fontFallback,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          height: 1,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: const Icon(
                        Icons.expand_more,
                        size: 16,
                        color: OfferingTableDetailTokens.warmGold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              alignment: Alignment.topCenter,
              duration: const Duration(milliseconds: 450),
              curve: Curves.ease,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                      child: Column(
                        children: [
                          for (final occurrence in remaining)
                            _OfferingAllDayRow(
                              occurrence: occurrence,
                              onTap: () => onOpenOfferingDay(occurrence),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 22, 24, 0),
            child: Text(
              'The table keeps the rhythm either way.',
              style: TextStyle(
                color: OfferingTableDetailTokens.silver,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferingAllDayRow extends StatelessWidget {
  const _OfferingAllDayRow({required this.occurrence, required this.onTap});

  final OfferingTablePreviewOccurrence occurrence;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final day = occurrence.day;
    return InkWell(
      key: ValueKey<String>('offering-table-all-day-${day.dayNumber}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                day.dayNumber.toString().padLeft(2, '0'),
                style: const TextStyle(
                  color: OfferingTableDetailTokens.warmGold,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.76,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    day.title,
                    style: const TextStyle(
                      color: OfferingTableDetailTokens.warmGold,
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
                      fontSize: 19,
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.italic,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    '${_shortDate(occurrence.date)} · ${_formatTime(occurrence.startLocal)}',
                    style: const TextStyle(
                      color: OfferingTableDetailTokens.silver,
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  Text(
                    day.section,
                    style: const TextStyle(
                      color: OfferingTableDetailTokens.silver,
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
                      fontSize: 14.5,
                      fontStyle: FontStyle.italic,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: OfferingTableDetailTokens.warmGold,
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferingPreviewCompletionPanel extends StatelessWidget {
  const _OfferingPreviewCompletionPanel();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final label in const <String>[
          'Observed',
          'Partly',
          'Skipped',
        ]) ...<Widget>[
          Expanded(
            child: Container(
              height: 45,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x2EE8E2D6)),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF9E9A94),
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 16.5,
                ),
              ),
            ),
          ),
          if (label != 'Skipped') const SizedBox(width: 9),
        ],
      ],
    );
  }
}

String _shortDate(DateTime date) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _shortMonthDay(DateTime date) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

String _formatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}
