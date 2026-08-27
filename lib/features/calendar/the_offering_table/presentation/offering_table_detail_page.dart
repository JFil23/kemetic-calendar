import 'package:flutter/material.dart';
import 'package:mobile/widgets/keyboard_aware.dart';

import 'package:mobile/features/calendar/calendar_event_visual_style.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_calendar_preview.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/track_sky_event_block_visual.dart';
import 'package:mobile/features/calendar/maat_flow_visual_tokens.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_preview_day.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_thirty_day_calendar.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
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
        kind: CalendarEventGraphicKind.trackSky,
        trackSkyKind: CalendarTrackSkyCardKind.genericSky,
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

@immutable
class OfferingTablePreviewOccurrence {
  const OfferingTablePreviewOccurrence({
    required this.day,
    required this.date,
    required this.startLocal,
  });

  final OfferingTableDay day;
  final DateTime date;
  final DateTime startLocal;
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
  });

  final TrackSkyTimeZone timezone;
  final OfferingTableJoinCallback onJoin;
  final FollowSkyCalendarPreview calendarPreview;
  final DateTime? initialStartDate;
  final bool alreadyJoined;
  final bool showBackButton;
  final bool resizeToAvoidBottomInset;
  final Future<void> Function(int flowId)? onJoined;

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
      if (!mounted) return;
      if (id > 0) {
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
                secondaryColors: [
                  OfferingTableDetailTokens.warmGold,
                  for (final row
                      in ordinaryRowsByDay[occurrence.date] ??
                          const <FollowSkyCalendarPreviewRow>[])
                    row.eventColor,
                ],
              ),
          ],
          theme: OfferingTableDetailTokens.thirtyDayCalendarTheme,
          introFirstLine: 'Here is your table.',
          introSecondLine: 'For the next thirty days.',
          keyPrefix: 'offering-table-calendar',
        ),
        _OfferingTableInitialEntry(controller: _initialEntryController),
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
    return const SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF160E05),
                  Color(0xFF0C0804),
                  Color(0xFF070502),
                ],
                stops: [0.0, 0.58, 1.0],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.48, -0.50),
                radius: 0.72,
                colors: [
                  Color(0x526F451B),
                  Color(0x142B1909),
                  Colors.transparent,
                ],
                stops: [0.0, 0.54, 1.0],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.70, 0.82),
                radius: 0.78,
                colors: [Color(0x384A2D13), Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferingTableInitialEntry extends StatelessWidget {
  const _OfferingTableInitialEntry({required this.controller});

  final TextEditingController controller;

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
          const Text(
            'The first water comes before the day asks anything else.',
            style: TextStyle(
              color: OfferingTableDetailTokens.mutedIvory,
              fontFamily: MaatFlowListTokens.fontFamily,
              fontFamilyFallback: MaatFlowListTokens.fontFallback,
              fontSize: 17,
              height: 1.42,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'WHAT WAS FED?',
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
            'What did you provide today?',
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
                hintText: 'Name the provision…',
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
    this.calendarRows = const <FollowSkyCalendarPreviewRow>[],
  });

  final OfferingTablePreviewOccurrence occurrence;
  final bool carried;
  final List<FollowSkyCalendarPreviewRow> calendarRows;

  @override
  Widget build(BuildContext context) {
    final day = occurrence.day;
    final rows = <({DateTime start, Widget child})>[
      (
        start: occurrence.startLocal,
        child: _OfferingFlowEventCard(occurrence: occurrence, carried: carried),
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
  });

  final OfferingTablePreviewOccurrence occurrence;
  final bool carried;

  @override
  Widget build(BuildContext context) {
    final day = occurrence.day;
    final title = offeringTableEventTitle(day);
    return Padding(
      key: ValueKey<String>('offering-table-preview-event-${day.dayNumber}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TrackSkyEventBlockVisual(
        title: title,
        graphic: OfferingTableDetailTokens.eventGraphic,
        height: 100,
        width: double.infinity,
        compact: false,
        isPreview: !carried,
        dashedBorder: !carried,
        child: Padding(
          padding: const EdgeInsets.only(right: 24),
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
              const SizedBox(width: 11),
              SizedBox(
                width: 56,
                child: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    _formatTime(occurrence.startLocal),
                    style: TextStyle(
                      color: OfferingTableDetailTokens.glow.withValues(
                        alpha: 0.72,
                      ),
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
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
                        style: const TextStyle(
                          color: Color(0xFFFFF2D7),
                          fontFamily: MaatFlowListTokens.fontFamily,
                          fontFamilyFallback: MaatFlowListTokens.fontFallback,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${day.section} · ${day.provisionAct}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: OfferingTableDetailTokens.silver,
                          fontFamily: MaatFlowListTokens.fontFamily,
                          fontFamilyFallback: MaatFlowListTokens.fontFallback,
                          fontSize: 14.5,
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
      ),
    );
  }
}

class _OfferingAllDaysList extends StatelessWidget {
  const _OfferingAllDaysList({
    required this.remaining,
    required this.expanded,
    required this.onToggle,
  });

  final List<OfferingTablePreviewOccurrence> remaining;
  final bool expanded;
  final VoidCallback onToggle;

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
                            _OfferingAllDayRow(occurrence: occurrence),
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
  const _OfferingAllDayRow({required this.occurrence});

  final OfferingTablePreviewOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final day = occurrence.day;
    return Padding(
      key: ValueKey<String>('offering-table-all-day-${day.dayNumber}'),
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

String _formatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}
