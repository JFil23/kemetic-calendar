import 'package:flutter/material.dart';
import 'package:mobile/widgets/keyboard_aware.dart';
import 'package:mobile/widgets/maat_flow_date_picker.dart';

import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_calendar_preview.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/calendar/maat_flow_identity.dart';
import 'package:mobile/features/calendar/maat_flow_temporal_controller.dart';
import 'package:mobile/features/calendar/maat_flow_temporal_policy.dart';
import 'package:mobile/features/calendar/maat_flow_temporal_resolver.dart';
import 'package:mobile/features/calendar/maat_flow_visual_tokens.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_thirty_day_calendar.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_day_components.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_event_block_visual.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_preview_day_sheet.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/the_offering_table_local_store.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart' show KemeticMath;

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
    this.backFallbackLocation = kMaatFlowsListRoute,
    this.resizeToAvoidBottomInset = true,
    this.localStore = const OfferingTableLocalStore(),
    this.clock,
    this.presentDayIanaTimeZone,
    this.ianaTimeZoneProvider,
    this.temporalScheduler,
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
  final String backFallbackLocation;
  final bool resizeToAvoidBottomInset;
  final OfferingTableLocalStore localStore;
  final MaatFlowClock? clock;
  final String? presentDayIanaTimeZone;
  final MaatFlowIanaTimeZoneProvider? ianaTimeZoneProvider;
  final MaatFlowTemporalScheduler? temporalScheduler;

  @override
  State<OfferingTableDetailPage> createState() =>
      _OfferingTableDetailPageState();
}

class _OfferingTableDetailPageState extends State<OfferingTableDetailPage> {
  late MaatFlowTemporalController _temporalController;
  int? _carriedFlowId;
  final TextEditingController _initialEntryController = TextEditingController();
  bool _joining = false;
  bool _showAllDays = false;

  @override
  void initState() {
    super.initState();
    _carriedFlowId = widget.joinedFlowId;
    _temporalController = _createTemporalController()..start();
    _temporalController.addListener(_handleTemporalChange);
    _loadJoinedIntention();
  }

  @override
  void didUpdateWidget(covariant OfferingTableDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.joinedFlowId != oldWidget.joinedFlowId) {
      _carriedFlowId = widget.joinedFlowId;
      if (_joined) {
        _temporalController.lockCarried(
          persistedStartDate: _joinedPersistedStartDate,
        );
      } else {
        _temporalController.unlock();
      }
      _loadJoinedIntention();
    }
    if (widget.clock != oldWidget.clock ||
        widget.presentDayIanaTimeZone != oldWidget.presentDayIanaTimeZone ||
        widget.ianaTimeZoneProvider != oldWidget.ianaTimeZoneProvider ||
        widget.temporalScheduler != oldWidget.temporalScheduler) {
      _replaceTemporalController();
    } else if (widget.initialStartDate != oldWidget.initialStartDate &&
        widget.initialStartDate != null &&
        !_joined) {
      _temporalController.lockExplicitDate(widget.initialStartDate!);
    }
  }

  bool get _joined => _carriedFlowId != null;

  MaatFlowTemporalContext get _temporalContext => _temporalController.context;

  DateTime? get _joinedPersistedStartDate {
    final joinedStart = widget.joinedStartDate;
    if (joinedStart != null) return DateUtils.dateOnly(joinedStart);
    if (widget.joinedScheduleDates.isEmpty) return null;
    final ordered = widget.joinedScheduleDates.map(DateUtils.dateOnly).toList()
      ..sort();
    return ordered.first;
  }

  DateTime get _startDate {
    if (widget.joinedFlowId == null) {
      return _temporalController.renderedStartDate;
    }
    final joinedStart = widget.joinedStartDate;
    if (joinedStart != null) return DateUtils.dateOnly(joinedStart);
    if (widget.joinedScheduleDates.isNotEmpty) {
      final ordered =
          widget.joinedScheduleDates.map(DateUtils.dateOnly).toList()..sort();
      return ordered.first;
    }
    throw StateError('A joined Offering Table must have a persisted schedule.');
  }

  Future<void> _loadJoinedIntention() async {
    final flowId = _carriedFlowId;
    if (flowId == null) return;
    final intention = await widget.localStore.loadIntention(flowId, 1);
    if (!mounted || _carriedFlowId != flowId) return;
    _initialEntryController.text = intention;
  }

  @override
  void dispose() {
    _temporalController.removeListener(_handleTemporalChange);
    _temporalController.dispose();
    _initialEntryController.dispose();
    super.dispose();
  }

  MaatFlowTemporalController _createTemporalController() {
    return MaatFlowTemporalController(
      ianaTimeZone:
          widget.presentDayIanaTimeZone ??
          MaatFlowDeviceTimeZone.currentIanaTimeZone,
      ianaTimeZoneProvider:
          widget.ianaTimeZoneProvider ??
          (widget.presentDayIanaTimeZone == null
              ? MaatFlowDeviceTimeZone.refresh
              : () async => widget.presentDayIanaTimeZone!),
      clock: widget.clock ?? maatFlowSystemClock,
      scheduler: widget.temporalScheduler ?? scheduleMaatFlowTemporalCallback,
      resolve: (context) => const MaatFlowTemporalResolver().resolve(
        kind: MaatFlowKind.offeringTable,
        context: context,
      ),
      explicitStartDate: _joined ? null : widget.initialStartDate,
      carried: _joined,
    );
  }

  void _replaceTemporalController() {
    final old = _temporalController;
    final explicitDate = old.isExplicitlyLocked ? old.renderedStartDate : null;
    old.removeListener(_handleTemporalChange);
    old.dispose();
    _temporalController = _createTemporalController();
    if (explicitDate != null && !_joined) {
      _temporalController.lockExplicitDate(explicitDate);
    }
    _temporalController.addListener(_handleTemporalChange);
    _temporalController.start();
  }

  void _handleTemporalChange() {
    if (mounted) setState(() {});
  }

  Future<void> _join() async {
    if (_joining || _joined) return;
    final renderedStartDate = _temporalController.startDateForCarry;
    setState(() => _joining = true);
    int id;
    try {
      id = await widget.onJoin(
        startDate: renderedStartDate,
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
      await widget.localStore.saveIntention(
        id,
        1,
        _initialEntryController.text,
      );
    } catch (error, stackTrace) {
      debugPrint('[OfferingTable] private need save failed after join: $error');
      debugPrint('$stackTrace');
    }
    if (!mounted) return;
    setState(() {
      _carriedFlowId = id;
      _joining = false;
    });
    _temporalController.lockCarried(persistedStartDate: renderedStartDate);
  }

  Future<void> _openOfferingDaySheet(
    OfferingTablePreviewOccurrence occurrence,
  ) async {
    await showOfferingTablePreviewDaySheet(
      context: context,
      occurrence: occurrence,
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

    _temporalController.lockExplicitDate(result.date);
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
      referenceHeroHeight: 258,
      referenceSheetOverlap: 26,
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
      body: KeyboardAwareEditableSurface(
        child: Stack(
          children: [
            body,
            if (widget.showBackButton)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 4,
                left: 4,
                child: BackButton(
                  key: const ValueKey<String>('offering-table-back'),
                  color: OfferingTableDetailTokens.warmGold,
                  onPressed: () => popMaatFlowDetailOrGo(
                    context,
                    fallbackLocation: widget.backFallbackLocation,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheet() {
    final occurrences = _previewOccurrences();
    final today = _temporalContext.presentLocalDate;
    final remaining = occurrences.skip(5).toList(growable: false);
    final firstFive = occurrences.take(5).toList(growable: false);
    final ordinaryRowsByDay = _ordinaryRowsByDay(occurrences);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _OfferingTableHandle(),
        _OfferingTableFirstMorning(
          occurrence: occurrences.first,
          carried: _joined,
          onOpenOfferingDay: _openOfferingDaySheet,
        ),
        _OfferingTableInitialEntry(
          controller: _initialEntryController,
          readOnly: _joined,
        ),
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
          introFirstLine:
              'Each day begins by noticing something you’ve been putting off,',
          introSecondLine: 'then giving it a simple place.',
          keyPrefix: 'offering-table-calendar',
        ),
        _OfferingAllDaysList(
          firstFive: firstFive,
          remaining: remaining,
          ordinaryRowsByDay: ordinaryRowsByDay,
          carried: _joined,
          expanded: _showAllDays,
          onToggle: () => setState(() => _showAllDays = !_showAllDays),
          onOpenOfferingDay: _openOfferingDaySheet,
        ),
        const _OfferingTableKemetNote(),
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
      contentBottom: 25,
      glyphToTitleSpacing: 10,
      titleFontSize: 48,
      subtitleSpacing: 8,
      subtitleWidth: 250,
      subtitleFontSize: 19,
      glyph: kOfferingTableGlyph,
      glyphKey: const ValueKey<String>('offering-table-hero-glyph'),
      glyphContent: const _OfferingTableGlyph(),
      glyphOffset: const Offset(0, 15),
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

class _OfferingTableGlyph extends StatelessWidget {
  const _OfferingTableGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 35,
      height: 35,
      child: CustomPaint(painter: _OfferingTableGlyphPainter()),
    );
  }
}

class _OfferingTableGlyphPainter extends CustomPainter {
  const _OfferingTableGlyphPainter();

  static const _gold = Color(0xFFF0C96A);

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 35;
    final scaleY = size.height / 35;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    final line = Paint()
      ..color = _gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // The R3 offering-table sign as it appears in the supplied HTML: two
    // offerings flank a tall central vessel above a low, tapered table.
    canvas.drawOval(const Rect.fromLTWH(4.5, 12.5, 10.5, 11.5), line);
    canvas.drawOval(const Rect.fromLTWH(22.5, 10.5, 9.5, 14), line);

    final vessel = Path()
      ..moveTo(16.5, 4)
      ..lineTo(22, 4)
      ..moveTo(17.3, 6)
      ..lineTo(21.2, 6)
      ..lineTo(20.5, 9)
      ..lineTo(20.5, 22.5)
      ..lineTo(17.8, 22.5)
      ..lineTo(17.8, 9)
      ..close();
    canvas.drawPath(vessel, line);
    canvas.drawLine(const Offset(16.2, 9), const Offset(22.2, 9), line);

    final table = Path()
      ..moveTo(3.5, 23.5)
      ..lineTo(31.5, 23.5)
      ..lineTo(34, 30.5)
      ..quadraticBezierTo(28, 34, 17.5, 34)
      ..quadraticBezierTo(7, 34, 1, 30.5)
      ..close();
    canvas.drawPath(table, line);
    canvas.drawLine(const Offset(2, 28), const Offset(33, 28), line);
    canvas.drawLine(const Offset(8, 23.5), const Offset(8, 19), line);
    canvas.drawLine(const Offset(27.5, 23.5), const Offset(27.5, 19), line);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OfferingTableGlyphPainter oldDelegate) => false;
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

class _OfferingTableHandle extends StatelessWidget {
  const _OfferingTableHandle();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 15,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 11),
          child: SizedBox(
            width: 44,
            height: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF3B2B14),
                borderRadius: BorderRadius.all(Radius.circular(99)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfferingTableFirstMorning extends StatelessWidget {
  const _OfferingTableFirstMorning({
    required this.occurrence,
    required this.carried,
    required this.onOpenOfferingDay,
  });

  final OfferingTablePreviewOccurrence occurrence;
  final bool carried;
  final ValueChanged<OfferingTablePreviewOccurrence> onOpenOfferingDay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              const Expanded(
                child: Text(
                  'YOUR FIRST MORNING',
                  style: TextStyle(
                    color: Color(0xFF9A7635),
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Text(
                '${_shortWeekday(occurrence.date)} · ${_shortMonth(occurrence.date)} ${occurrence.date.day} · ${_formatTime(occurrence.startLocal)}',
                style: const TextStyle(
                  color: OfferingTableDetailTokens.muted,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _OfferingFlowEventCard(
            occurrence: occurrence,
            carried: carried,
            onTap: () => onOpenOfferingDay(occurrence),
          ),
        ],
      ),
    );
  }
}

class _OfferingTableInitialEntry extends StatelessWidget {
  const _OfferingTableInitialEntry({
    required this.controller,
    required this.readOnly,
  });

  final TextEditingController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('offering-table-initial-entry'),
      margin: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      padding: const EdgeInsets.fromLTRB(0, 22, 0, 22),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: OfferingTableDetailTokens.separator),
          bottom: BorderSide(color: OfferingTableDetailTokens.separator),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WHAT ARE YOU RUNNING LOW ON?',
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
          Focus(
            child: TextField(
              key: const ValueKey<String>('offering-table-initial-input'),
              controller: controller,
              readOnly: readOnly,
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
                hintText: 'Medication, groceries, soap…',
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
    final title = day.title;
    final isNarrow = MediaQuery.sizeOf(context).width <= 350;
    return Semantics(
      button: true,
      label: 'View practice for Day ${day.dayNumber}: $title',
      child: GestureDetector(
        key: ValueKey<String>('offering-table-preview-event-${day.dayNumber}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: OfferingTableEventBlockVisual(
            dayNumber: day.dayNumber,
            title: title,
            prompt: day.eventBlockPrompt,
            height: 100,
            width: double.infinity,
            isPreview: !carried,
            dashedBorder: !carried,
            overlay: Stack(
              children: [
                Positioned(
                  left: 13,
                  bottom: 7,
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
                Positioned(
                  right: 5,
                  bottom: 3,
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
                  right: isNarrow ? 68 : 74,
                  bottom: 7,
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
    required this.firstFive,
    required this.remaining,
    required this.ordinaryRowsByDay,
    required this.carried,
    required this.expanded,
    required this.onToggle,
    required this.onOpenOfferingDay,
  });

  final List<OfferingTablePreviewOccurrence> firstFive;
  final List<OfferingTablePreviewOccurrence> remaining;
  final Map<DateTime, List<FollowSkyCalendarPreviewRow>> ordinaryRowsByDay;
  final bool carried;
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
                        expanded ? 'Show first 5 days' : 'See all 30 offerings',
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final occurrence in firstFive)
                            _OfferingScheduleDay(
                              occurrence: occurrence,
                              carried: carried,
                              ordinaryRows:
                                  ordinaryRowsByDay[occurrence.date] ??
                                  const <FollowSkyCalendarPreviewRow>[],
                              onOpenOfferingDay: onOpenOfferingDay,
                            ),
                          const Padding(
                            padding: EdgeInsets.only(top: 6, bottom: 5),
                            child: Text(
                              'OFFERINGS 06–30',
                              style: TextStyle(
                                color: Color(0xFF8A7030),
                                fontFamily: MaatFlowListTokens.fontFamily,
                                fontSize: 9.5,
                                letterSpacing: 1.8,
                                height: 1,
                              ),
                            ),
                          ),
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
              'The table keeps the rhythm even if you miss a day.',
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
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
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
            const Padding(
              padding: EdgeInsets.only(top: 5, left: 8),
              child: Icon(
                Icons.chevron_right,
                size: 16,
                color: OfferingTableDetailTokens.warmGold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferingScheduleDay extends StatelessWidget {
  const _OfferingScheduleDay({
    required this.occurrence,
    required this.carried,
    required this.ordinaryRows,
    required this.onOpenOfferingDay,
  });

  final OfferingTablePreviewOccurrence occurrence;
  final bool carried;
  final List<FollowSkyCalendarPreviewRow> ordinaryRows;
  final ValueChanged<OfferingTablePreviewOccurrence> onOpenOfferingDay;

  @override
  Widget build(BuildContext context) {
    final kemetic = KemeticMath.fromGregorian(occurrence.date);
    final month = getMonthById(kemetic.kMonth);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF120F08),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0x45C99A3D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  '${month.displayShort} ${kemetic.kDay}',
                  style: const TextStyle(
                    color: OfferingTableDetailTokens.warmGold,
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
              ),
              Text(
                '${_shortWeekday(occurrence.date)} · ${_shortMonth(occurrence.date)} ${occurrence.date.day}',
                style: const TextStyle(
                  color: Color(0xFFC39B4C),
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontSize: 10.5,
                  letterSpacing: 1.65,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _OfferingFlowEventCard(
            occurrence: occurrence,
            carried: carried,
            onTap: () => onOpenOfferingDay(occurrence),
          ),
          if (ordinaryRows.isNotEmpty)
            DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x2BC99A3D))),
              ),
              child: Column(
                children: [
                  for (final row in ordinaryRows)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 12,
                            margin: const EdgeInsets.only(right: 8),
                            color: row.eventColor,
                          ),
                          Text(
                            _formatTime(row.start),
                            style: const TextStyle(
                              color: OfferingTableDetailTokens.silver,
                              fontFamily: MaatFlowListTokens.fontFamily,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              row.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: OfferingTableDetailTokens.mutedIvory,
                                fontFamily: MaatFlowListTokens.fontFamily,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
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

class _OfferingTableKemetNote extends StatelessWidget {
  const _OfferingTableKemetNote();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(22, 26, 22, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: OfferingTableDetailTokens.separator)),
        ),
        child: Padding(
          padding: EdgeInsets.only(top: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'IN KEMET',
                style: TextStyle(
                  color: OfferingTableDetailTokens.warmGold,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontSize: 10.5,
                  letterSpacing: 2.7,
                  height: 1,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Kemetic offering practice treats provision as material and relational: food, water, care, reciprocity, and what keeps life functioning.',
                style: TextStyle(
                  color: OfferingTableDetailTokens.mutedIvory,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontSize: 16,
                  height: 1.48,
                ),
              ),
              SizedBox(height: 10),
              Text(
                '“Wash yourself and your Ka will wash itself. Your Ka will sit and eat bread with you without ceasing.”',
                style: TextStyle(
                  color: Color(0xFF8E867C),
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  height: 1.48,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _shortWeekday(DateTime date) => const <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
][date.weekday - 1];

String _shortMonth(DateTime date) => const <String>[
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
][date.month - 1];

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
