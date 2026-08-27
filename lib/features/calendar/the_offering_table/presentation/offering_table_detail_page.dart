import 'package:flutter/material.dart';
import 'package:mobile/widgets/keyboard_aware.dart';

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
    this.initialStartDate,
    this.alreadyJoined = false,
    this.showBackButton = true,
    this.resizeToAvoidBottomInset = true,
    this.onJoined,
  });

  final TrackSkyTimeZone timezone;
  final OfferingTableJoinCallback onJoin;
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
      sheet: _buildSheet(context),
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

  Widget _buildSheet(BuildContext context) {
    final occurrences = _previewOccurrences();
    final today = DateUtils.dateOnly(offeringTableNowInZone(widget.timezone));
    final visible = _showAllDays ? occurrences : occurrences.take(5);

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
                secondaryColors: const [OfferingTableDetailTokens.warmGold],
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
              for (final occurrence in visible) ...[
                _OfferingPreviewDay(
                  occurrence: occurrence,
                  timeLabel: MaterialLocalizations.of(context).formatTimeOfDay(
                    TimeOfDay.fromDateTime(occurrence.startLocal),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (!_showAllDays)
                OutlinedButton(
                  key: const ValueKey<String>('offering-table-show-all'),
                  style: _showMoreButtonStyle(),
                  onPressed: () => setState(() => _showAllDays = true),
                  child: const Text('Show all 30 days'),
                )
              else
                TextButton(
                  key: const ValueKey<String>('offering-table-show-fewer'),
                  style: TextButton.styleFrom(
                    foregroundColor: OfferingTableDetailTokens.warmGold,
                  ),
                  onPressed: () => setState(() => _showAllDays = false),
                  child: const Text('Show fewer days'),
                ),
              const SizedBox(height: 18),
              const _OfferingDescription(overview: kOfferingTableOverview),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
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
                'WHAT WAS FED?',
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
          TextField(
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
                  color: OfferingTableDetailTokens.glow.withValues(alpha: 0.30),
                ),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: OfferingTableDetailTokens.glow.withValues(alpha: 0.30),
                ),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(
                  color: OfferingTableDetailTokens.warmGold,
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
    required this.timeLabel,
  });

  final OfferingTablePreviewOccurrence occurrence;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final day = occurrence.day;
    return MaatFlowPreviewDayCard(
      key: ValueKey<String>('offering-table-preview-day-${day.dayNumber}'),
      date: occurrence.date,
      theme: OfferingTableDetailTokens.previewTheme,
      children: [
        MaatFlowPreviewEventRow(
          key: ValueKey<String>(
            'offering-table-preview-event-${day.dayNumber}',
          ),
          timeLabel: timeLabel,
          title: offeringTableEventTitle(day),
          subtitle: '${day.section} · ${day.provisionAct}',
          accent: OfferingTableDetailTokens.warmGold,
          theme: OfferingTableDetailTokens.previewTheme,
        ),
      ],
    );
  }
}

class _OfferingDescription extends StatefulWidget {
  const _OfferingDescription({required this.overview});

  final String overview;

  @override
  State<_OfferingDescription> createState() => _OfferingDescriptionState();
}

class _OfferingDescriptionState extends State<_OfferingDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton(
          key: const ValueKey<String>('offering-table-description-toggle'),
          style: TextButton.styleFrom(
            foregroundColor: OfferingTableDetailTokens.warmGold,
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.zero,
          ),
          onPressed: () => setState(() => _expanded = !_expanded),
          child: Text(_expanded ? 'Hide full description' : 'Full description'),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Text(
            widget.overview,
            style: _bodyStyle(OfferingTableDetailTokens.silver),
          ),
        ),
      ],
    );
  }
}

ButtonStyle _showMoreButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: OfferingTableDetailTokens.mutedIvory,
    backgroundColor: Colors.transparent,
    side: const BorderSide(color: Color(0x52C99A3D)),
    minimumSize: const Size.fromHeight(52),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    textStyle: const TextStyle(
      fontFamily: MaatFlowListTokens.fontFamily,
      fontFamilyFallback: MaatFlowListTokens.fontFallback,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
  );
}

TextStyle _bodyStyle(Color color) {
  return TextStyle(
    color: color,
    fontFamily: MaatFlowListTokens.fontFamily,
    fontFamilyFallback: MaatFlowListTokens.fontFallback,
    fontSize: 14,
    fontWeight: FontWeight.w300,
    height: 1.42,
  );
}
