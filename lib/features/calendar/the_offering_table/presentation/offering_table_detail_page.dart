import 'package:flutter/material.dart';
import 'package:mobile/widgets/keyboard_aware.dart';
import 'package:mobile/widgets/maat_flow_date_picker.dart';

import 'package:mobile/features/calendar/calendar_event_visual_style.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_calendar_preview.dart';
import 'package:mobile/features/calendar/maat_flow_visual_tokens.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_preview_day.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_thirty_day_calendar.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_day_sheet.dart';
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
    this.alreadyJoined = false,
    this.showBackButton = true,
    this.resizeToAvoidBottomInset = true,
    this.onJoined,
    this.localStore = const OfferingTableLocalStore(),
  });

  final TrackSkyTimeZone timezone;
  final OfferingTableJoinCallback onJoin;
  final FollowSkyCalendarPreview calendarPreview;
  final DateTime? initialStartDate;
  final bool alreadyJoined;
  final bool showBackButton;
  final bool resizeToAvoidBottomInset;
  final Future<void> Function(int flowId)? onJoined;
  final OfferingTableLocalStore localStore;

  @override
  State<OfferingTableDetailPage> createState() =>
      _OfferingTableDetailPageState();
}

class _OfferingTableDetailPageState extends State<OfferingTableDetailPage> {
  late DateTime _startDate;
  late bool _joined;
  final OfferingTableLens _lens = OfferingTableLens.neutral;
  final bool _noCupMode = false;
  final TextEditingController _initialEntryController = TextEditingController();
  bool _joining = false;
  bool _showAllDays = false;

  @override
  void initState() {
    super.initState();
    _startDate = DateUtils.dateOnly(
      widget.initialStartDate ?? defaultOfferingTableStartDate(widget.timezone),
    );
    _joined = widget.alreadyJoined;
  }

  @override
  void didUpdateWidget(covariant OfferingTableDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.alreadyJoined != oldWidget.alreadyJoined) {
      _joined = widget.alreadyJoined;
    }
  }

  @override
  void dispose() {
    _initialEntryController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_joining || _joined) return;
    setState(() => _joining = true);
    try {
      final id = await widget.onJoin(
        startDate: _startDate,
        timezone: widget.timezone,
        lens: _lens,
        noCupMode: _noCupMode,
      );
      if (id > 0) {
        await widget.localStore.saveNeed(id, _initialEntryController.text);
        if (!mounted) return;
        final onJoined = widget.onJoined;
        if (onJoined != null) {
          await onJoined(id);
        } else if (mounted) {
          setState(() {
            _joined = true;
            _joining = false;
          });
        }
        return;
      }
      if (!mounted) return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not join The Offering Table. Please retry.'),
        ),
      );
    }
    if (mounted) setState(() => _joining = false);
  }

  Future<void> _openOfferingDaySheet(
    OfferingTablePreviewOccurrence occurrence,
  ) async {
    await showOfferingTableDaySheet(
      context: context,
      occurrence: occurrence,
      lens: _lens,
      noCupMode: _noCupMode,
    );
  }

  Future<void> _pickStartDate() async {
    final result = await MaatFlowDatePicker.show(
      context: context,
      initialDate: _startDate,
      initialMode: MaatFlowDatePickerMode.gregorian,
    );
    if (result == null || !mounted) return;

    setState(() {
      _startDate = DateUtils.dateOnly(result.date);
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
    return [
      for (final day in kOfferingTableDays)
        () {
          final date = _startDate.add(Duration(days: day.dayNumber - 1));
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
                onTopLabelTap: occurrence.day.dayNumber == 1
                    ? _pickStartDate
                    : null,
                topLabelSemanticLabel: occurrence.day.dayNumber == 1
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
  });

  final TextEditingController controller;
  final String introText;

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
