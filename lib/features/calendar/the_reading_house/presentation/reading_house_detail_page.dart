import 'package:flutter/material.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/calendar/maat_flow_visual_tokens.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_thirty_day_calendar.dart';
import 'package:mobile/features/calendar/the_reading_house_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart';
import 'package:mobile/widgets/maat_flow_date_picker.dart';

abstract final class ReadingHouseDetailTokens {
  static const Color pageBackground = Color(0xFF050504);
  static const Color sheetBackground = Color(0xFF080907);
  static const Color bone = Color(0xFFE8E2D6);
  static const Color gold = Color(0xFFD4AE43);
  static const Color goldDim = Color(0xFF8A7030);
  static const Color silver = Color(0xFF9E9A94);
  static const Color silverLow = Color(0xFF6A6660);
  static const Color house = Color(0xFF3FA98A);
  static const Color houseHighlight = Color(0xFF7FD9BC);
  static const Color houseDeep = Color(0xFF17362E);
  static const Color separator = Color(0xFF1E2A24);

  static const MaatFlowDetailTheme theme = MaatFlowDetailTheme(
    pageBackground: pageBackground,
    sheetBackground: sheetBackground,
    sheetBorder: Color(0x5C3FA98A),
    accent: house,
    primaryText: bone,
    secondaryText: silver,
    mutedText: silverLow,
    separator: separator,
    glow: houseHighlight,
  );

  static const MaatFlowThirtyDayCalendarTheme calendarTheme =
      MaatFlowThirtyDayCalendarTheme(
        introText: bone,
        introEmphasis: silver,
        border: Color(0x3D3FA98A),
        month: house,
        monthTransliteration: Color(0xFF507565),
        decan: Color(0xFF557566),
        day: Color(0xFF788079),
        today: houseHighlight,
        highlight: houseHighlight,
      );
}

/// Visual-first Reading House detail page.
///
/// All state in this page is deliberately ephemeral. The existing Reading
/// House domain, membership, invitation, and scheduling authorities are left
/// unchanged until the approved presentation is wired in a later pass.
class ReadingHouseDetailPage extends StatefulWidget {
  const ReadingHouseDetailPage({
    super.key,
    required this.timezone,
    this.initialStartDate,
    this.initialPlan = const ReadingHousePlan(),
    this.initialSittings = kReadingHouseSittings,
    this.initiallyHeld = false,
    this.showBackButton = true,
    this.resizeToAvoidBottomInset = true,
  });

  final TrackSkyTimeZone timezone;
  final DateTime? initialStartDate;
  final ReadingHousePlan initialPlan;
  final List<ReadingHouseSitting> initialSittings;
  final bool initiallyHeld;
  final bool showBackButton;
  final bool resizeToAvoidBottomInset;

  @override
  State<ReadingHouseDetailPage> createState() => _ReadingHouseDetailPageState();
}

class _ReadingHouseDetailPageState extends State<ReadingHouseDetailPage> {
  late final TextEditingController _bookController;
  late final TextEditingController _editionController;
  late DateTime _windowStart;
  late List<ReadingHouseSitting> _sittings;
  late bool _withReaders;
  late bool _held;
  bool _openDoors = false;
  final List<_ReaderSearchResult> _invitedReaders = <_ReaderSearchResult>[];

  @override
  void initState() {
    super.initState();
    final initialBook = widget.initialPlan.bookTitle.trim();
    _bookController = TextEditingController(
      text: initialBook == kReadingHouseDefaultBookTitle ? '' : initialBook,
    );
    _editionController = TextEditingController(
      text: widget.initialPlan.editionNote,
    );
    _windowStart = DateUtils.dateOnly(
      widget.initialStartDate ?? defaultReadingHouseStartDate(widget.timezone),
    );
    _sittings = List<ReadingHouseSitting>.of(widget.initialSittings);
    _withReaders = !widget.initialPlan.isSolo;
    _held = widget.initiallyHeld;
  }

  @override
  void dispose() {
    _bookController.dispose();
    _editionController.dispose();
    super.dispose();
  }

  int get _placedCount =>
      _sittings.where((sitting) => sitting.scheduledDate != null).length;

  List<MaatFlowThirtyDayMarker> _calendarMarkers() {
    final markers = <DateTime, MaatFlowThirtyDayMarker>{};
    final today = DateUtils.dateOnly(readingHouseNowInZone(widget.timezone));
    final end = _windowStart.add(const Duration(days: 29));
    if (!today.isBefore(_windowStart) && !today.isAfter(end)) {
      markers[today] = MaatFlowThirtyDayMarker(date: today, isToday: true);
    }
    for (final sitting in _sittings) {
      final scheduledDate = sitting.scheduledDate;
      if (scheduledDate == null) continue;
      final date = DateUtils.dateOnly(scheduledDate);
      if (date.isBefore(_windowStart) || date.isAfter(end)) continue;
      markers[date] = MaatFlowThirtyDayMarker(
        date: date,
        isToday: DateUtils.isSameDay(date, today),
        highlighted: true,
        filled: true,
        accent: ReadingHouseDetailTokens.houseHighlight,
        topLabel: 'SITTING ${sitting.eventNumber.toString().padLeft(2, '0')}',
      );
    }
    return markers.values.toList(growable: false);
  }

  void _placeReading() {
    setState(() {
      _sittings = <ReadingHouseSitting>[
        for (final sitting in _sittings)
          sitting.copyWith(
            scheduledDate: _windowStart.add(
              Duration(days: sitting.flowDay - 1),
            ),
          ),
      ];
    });
  }

  Future<void> _inviteReader() async {
    final result = await showModalBottomSheet<_ReaderSearchResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ReaderInviteSheet(),
    );
    if (result == null || !mounted) return;
    if (_invitedReaders.any((reader) => reader.handle == result.handle)) return;
    setState(() => _invitedReaders.add(result));
  }

  Future<void> _openSitting(ReadingHouseSitting sitting) async {
    final edited = await showModalBottomSheet<ReadingHouseSitting>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReadingHouseSittingSheet(sitting: sitting),
    );
    if (edited == null || !mounted) return;
    setState(() {
      _sittings = editReadingHouseSitting(
        _sittings,
        sitting.eventNumber,
        edited,
      );
    });
  }

  Future<void> _addSitting() async {
    final next = addReadingHouseSitting(_sittings);
    final added = next.last;
    setState(() => _sittings = next);
    await _openSitting(added);
  }

  @override
  Widget build(BuildContext context) {
    final body = MaatFlowDetailShell(
      theme: ReadingHouseDetailTokens.theme,
      scrollKey: const ValueKey<String>('reading-house-scroll'),
      heroLayerKey: const ValueKey<String>('reading-house-hero-layer'),
      sheetKey: const ValueKey<String>('reading-house-sheet'),
      hero: const _ReadingHouseHero(),
      bottomDock: MaatFlowDetailDock(
        theme: ReadingHouseDetailTokens.theme,
        joined: _held,
        busy: false,
        onPressed: () => setState(() => _held = true),
        actionLabel: 'Hold this house',
        actionNote:
            'This creates the house in My Flows. You do not need to schedule it yet.',
        joinedLabel: 'Held in your flows',
        joinedNote:
            'This house can stay partial while readers respond. Nothing needs to be scheduled yet.',
        actionKey: const ValueKey<String>('reading-house-hold'),
        joinedKey: const ValueKey<String>('reading-house-held'),
      ),
      sheet: _buildSheet(context),
    );

    return Scaffold(
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      backgroundColor: ReadingHouseDetailTokens.pageBackground,
      body: Stack(
        children: [
          body,
          if (widget.showBackButton)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 4,
              left: 4,
              child: IconButton(
                key: const ValueKey<String>('reading-house-back'),
                tooltip: 'Back',
                icon: const Icon(
                  Icons.arrow_back,
                  color: ReadingHouseDetailTokens.gold,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSheet(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHandle(),
        const _BeforeCalendarIntro(),
        _buildHouseSetup(),
        _buildCalendar(),
        _buildSittings(context),
        const _ReadingFrame(),
        const _HistoricalContext(),
      ],
    );
  }

  Widget _buildHouseSetup() {
    final inviteSummary = _invitedReaders.isEmpty
        ? 'No invites yet'
        : _invitedReaders.length == 1
        ? '1 invite pending'
        : '${_invitedReaders.length} invites pending';
    return Container(
      key: const ValueKey<String>('reading-house-setup'),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ReadingHouseDetailTokens.separator),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SetupTextField(
            label: 'BOOK',
            hintText: 'Name the book',
            controller: _bookController,
            topPadding: 0,
            fieldKey: const ValueKey<String>('reading-house-book'),
          ),
          _SetupTextField(
            label: 'EDITION',
            trailing: 'optional · can wait',
            hintText: 'Translator, edition, or link',
            controller: _editionController,
            fieldKey: const ValueKey<String>('reading-house-edition'),
          ),
          _SetupChoiceField(
            label: 'HOW ARE YOU READING?',
            firstLabel: 'Solo study',
            secondLabel: 'With readers',
            secondSelected: _withReaders,
            onFirst: () => setState(() => _withReaders = false),
            onSecond: () => setState(() => _withReaders = true),
            note: _withReaders
                ? 'Everyone who accepts sees this same house, even before it has dates.'
                : 'A solo house stays with you and your private calendar.',
            fieldKey: const ValueKey<String>('reading-house-mode'),
          ),
          IgnorePointer(
            ignoring: !_withReaders,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _withReaders ? 1 : 0.32,
              child: _SetupChoiceField(
                label: 'DOORS',
                firstLabel: 'Closed · invited',
                secondLabel: 'Open · Commons',
                secondSelected: _openDoors,
                onFirst: () => setState(() => _openDoors = false),
                onSecond: () => setState(() => _openDoors = true),
                note: _openDoors
                    ? 'Community members can discover this house in the Commons.'
                    : 'Closed houses only appear to people you invite.',
                highlightedNote: _openDoors,
                fieldKey: const ValueKey<String>('reading-house-doors'),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: !_withReaders
                ? const SizedBox.shrink()
                : Padding(
                    key: const ValueKey<String>('reading-house-readers'),
                    padding: const EdgeInsets.only(top: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const _UpperLabel('READERS'),
                            Text(
                              inviteSummary,
                              style: _uiStyle(
                                color: ReadingHouseDetailTokens.house,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const _ReaderRow(
                          initials: 'Y',
                          name: 'You',
                          status: 'HOST',
                          host: true,
                        ),
                        for (final reader in _invitedReaders) ...[
                          const SizedBox(height: 12),
                          _ReaderRow(
                            initials: reader.initials,
                            name: reader.name,
                            status: 'INVITED',
                          ),
                        ],
                        if (_invitedReaders.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 43, top: 12),
                            child: Text(
                              'No one else is here yet.',
                              style: _uiStyle(
                                color: const Color(0xFF59635E),
                                fontSize: 12.5,
                                fontStyle: FontStyle.italic,
                                height: 1.35,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        _DashedPillButton(
                          key: const ValueKey<String>(
                            'reading-house-invite-reader',
                          ),
                          label: '+  Invite a reader',
                          onTap: _inviteReader,
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 22),
          _HouseStateLine(
            held: _held,
            openDoors: _openDoors && _withReaders,
            invitedCount: _withReaders ? _invitedReaders.length : 0,
            placedCount: _placedCount,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final waiting = _sittings.length - _placedCount;
    final waitingCopy = waiting <= 0
        ? 'Every sitting has a date. You can still move each one later.'
        : '${_countWord(waiting)} ${waiting == 1 ? 'sitting is' : 'sittings are'} waiting for dates. Nothing about the house is lost while you wait.';
    return Container(
      key: const ValueKey<String>('reading-house-calendar-section'),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ReadingHouseDetailTokens.separator),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MaatFlowThirtyDayCalendar(
            key: const ValueKey<String>('reading-house-thirty-day-calendar'),
            windowStart: _windowStart,
            markers: _calendarMarkers(),
            theme: ReadingHouseDetailTokens.calendarTheme,
            introFirstLine: 'When the house is ready,',
            introSecondLine: 'place the reading.',
            keyPrefix: 'reading-house-calendar',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 11, 24, 0),
            child: Text(
              waitingCopy,
              style: _uiStyle(
                color: ReadingHouseDetailTokens.silverLow,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
            child: _OutlinePillButton(
              key: const ValueKey<String>('reading-house-place-reading'),
              label: waiting <= 0 ? 'Reading placed' : 'Place the reading',
              color: ReadingHouseDetailTokens.gold,
              onTap: waiting <= 0 ? null : _placeReading,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSittings(BuildContext context) {
    return Container(
      key: const ValueKey<String>('reading-house-sittings'),
      padding: const EdgeInsets.only(top: 30),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ReadingHouseDetailTokens.separator),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: _SectionEyebrow('THE SITTINGS'),
          ),
          for (final sitting in _sittings)
            _SittingRow(
              sitting: sitting,
              status: _sittingStatus(context, sitting),
              onTap: () => _openSitting(sitting),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 22),
            child: _DashedPillButton(
              key: const ValueKey<String>('reading-house-add-sitting'),
              label: '+  Add sitting',
              onTap: _addSitting,
            ),
          ),
        ],
      ),
    );
  }

  String _sittingStatus(BuildContext context, ReadingHouseSitting sitting) {
    final date = sitting.scheduledDate;
    if (date == null) return 'NOT PLACED';
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay(hour: sitting.hour, minute: sitting.minute));
    return '${_kemeticDate(date)} · $time';
  }
}

class _ReadingHouseHero extends StatelessWidget {
  const _ReadingHouseHero();

  @override
  Widget build(BuildContext context) {
    return MaatFlowDetailHero(
      key: const ValueKey<String>('reading-house-hero'),
      theme: ReadingHouseDetailTokens.theme,
      background: const _ReadingHouseHeroBackdrop(),
      glyph: kReadingHouseGlyph,
      glyphKey: const ValueKey<String>('reading-house-hero-glyph'),
      glyphGradient: const RadialGradient(
        center: Alignment(-0.24, -0.44),
        radius: 0.9,
        colors: [Color(0xFF3C9277), Color(0xFF1A4638), Color(0xFF08140F)],
      ),
      glyphBorder: ReadingHouseDetailTokens.houseHighlight,
      glyphGlow: ReadingHouseDetailTokens.houseHighlight,
      title: 'The Reading\nHouse',
      subtitle: 'A house kept around one book.',
    );
  }
}

class _ReadingHouseHeroBackdrop extends StatelessWidget {
  const _ReadingHouseHeroBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0C1812),
                Color(0xFF09110D),
                Color(0xFF060806),
                ReadingHouseDetailTokens.pageBackground,
              ],
              stops: [0, 0.44, 0.76, 1],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.64, -0.68),
              radius: 0.95,
              colors: [Color(0x4750B090), Colors.transparent],
            ),
          ),
        ),
        CustomPaint(painter: _HouseArchitecturePainter()),
        const Positioned(
          top: 42,
          right: -18,
          child: Text(
            kReadingHouseGlyph,
            style: TextStyle(
              color: Color(0x087FD9BC),
              fontFamily: 'Noto Sans Egyptian Hieroglyphs',
              fontSize: 224,
              height: 1,
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 210,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x29050504),
                  Color(0xD1050504),
                  ReadingHouseDetailTokens.pageBackground,
                ],
                stops: [0, 0.35, 0.86, 1],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HouseArchitecturePainter extends CustomPainter {
  const _HouseArchitecturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final vertical = Paint()
      ..color = ReadingHouseDetailTokens.houseHighlight.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (final x in <double>[0.08, 0.29, 0.71]) {
      canvas.drawLine(
        Offset(size.width * x, 0),
        Offset(size.width * x, size.height),
        vertical,
      );
    }
    final shelves = Paint()
      ..color = ReadingHouseDetailTokens.bone.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    for (double y = 38; y < size.height; y += 54) {
      canvas.drawLine(
        Offset.zero.translate(0, y),
        Offset(size.width, y),
        shelves,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 34,
      child: Align(
        alignment: Alignment(0, -0.35),
        child: SizedBox(
          width: 44,
          height: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFF31453D),
              borderRadius: BorderRadius.all(Radius.circular(99)),
            ),
          ),
        ),
      ),
    );
  }
}

class _BeforeCalendarIntro extends StatelessWidget {
  const _BeforeCalendarIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('reading-house-before-calendar'),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ReadingHouseDetailTokens.separator),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionEyebrow('BEFORE THE CALENDAR'),
          const SizedBox(height: 13),
          Text.rich(
            TextSpan(
              text: 'Open the house first.\n',
              children: [
                TextSpan(
                  text: 'The schedule can wait.',
                  style: TextStyle(
                    color: ReadingHouseDetailTokens.silver,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
            style: _displayStyle(
              color: ReadingHouseDetailTokens.bone,
              fontSize: 25,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Choose a book, decide who may enter, and give invited readers time to answer before anyone has to place a sitting.',
            style: _uiStyle(
              color: ReadingHouseDetailTokens.silverLow,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: _uiStyle(
            color: ReadingHouseDetailTokens.goldDim,
            fontSize: 10,
            letterSpacing: 2.3,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Divider(color: ReadingHouseDetailTokens.separator, height: 1),
        ),
      ],
    );
  }
}

class _UpperLabel extends StatelessWidget {
  const _UpperLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: _uiStyle(
        color: ReadingHouseDetailTokens.goldDim,
        fontSize: 10,
        letterSpacing: 2.1,
        height: 1.1,
      ),
    );
  }
}

class _SetupTextField extends StatelessWidget {
  const _SetupTextField({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.fieldKey,
    this.trailing,
    this.topPadding = 17,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final Key fieldKey;
  final String? trailing;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(0, topPadding, 0, 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1F3FA98A))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _UpperLabel(label),
              if (trailing != null)
                Text(
                  trailing!,
                  style: _uiStyle(
                    color: const Color(0xFF4F5B55),
                    fontSize: 10,
                    letterSpacing: 0.6,
                  ),
                ),
            ],
          ),
          TextField(
            key: fieldKey,
            controller: controller,
            cursorColor: ReadingHouseDetailTokens.houseHighlight,
            style: _displayStyle(
              color: ReadingHouseDetailTokens.houseHighlight,
              fontSize: 22,
              fontStyle: FontStyle.italic,
              height: 1.25,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.only(top: 9, bottom: 6),
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: _displayStyle(
                color: const Color(0xFF3F4A44),
                fontSize: 22,
                fontStyle: FontStyle.italic,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupChoiceField extends StatelessWidget {
  const _SetupChoiceField({
    required this.label,
    required this.firstLabel,
    required this.secondLabel,
    required this.secondSelected,
    required this.onFirst,
    required this.onSecond,
    required this.note,
    required this.fieldKey,
    this.highlightedNote = false,
  });

  final String label;
  final String firstLabel;
  final String secondLabel;
  final bool secondSelected;
  final VoidCallback onFirst;
  final VoidCallback onSecond;
  final String note;
  final Key fieldKey;
  final bool highlightedNote;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: fieldKey,
      padding: const EdgeInsets.fromLTRB(0, 17, 0, 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1F3FA98A))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _UpperLabel(label),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _ChoiceButton(
                  label: firstLabel,
                  selected: !secondSelected,
                  onTap: onFirst,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _ChoiceButton(
                  label: secondLabel,
                  selected: secondSelected,
                  onTap: onSecond,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: highlightedNote
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 11)
                : EdgeInsets.zero,
            decoration: highlightedNote
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: const Color(0x293FA98A)),
                    color: const Color(0x0E3FA98A),
                  )
                : null,
            child: Text(
              note,
              style: _uiStyle(
                color: highlightedNote
                    ? const Color(0xFF8BB5A6)
                    : const Color(0xFF68766F),
                fontSize: highlightedNote ? 12.5 : 12,
                fontStyle: FontStyle.italic,
                height: 1.38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xC27FD9BC)
                  : const Color(0x24E8E2D6),
            ),
            color: selected ? const Color(0x1A3FA98A) : Colors.transparent,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: _displayStyle(
              color: selected
                  ? ReadingHouseDetailTokens.houseHighlight
                  : ReadingHouseDetailTokens.silver,
              fontSize: 15.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderRow extends StatelessWidget {
  const _ReaderRow({
    required this.initials,
    required this.name,
    required this.status,
    this.host = false,
  });

  final String initials;
  final String name;
  final String status;
  final bool host;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x427FD9BC)),
            color: const Color(0x143FA98A),
          ),
          child: Text(
            initials,
            style: _uiStyle(
              color: ReadingHouseDetailTokens.houseHighlight,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            name,
            style: _displayStyle(
              color: ReadingHouseDetailTokens.bone,
              fontSize: 17,
              height: 1,
            ),
          ),
        ),
        Text(
          status,
          style: _uiStyle(
            color: host
                ? ReadingHouseDetailTokens.gold
                : ReadingHouseDetailTokens.houseHighlight,
            fontSize: 10,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _HouseStateLine extends StatelessWidget {
  const _HouseStateLine({
    required this.held,
    required this.openDoors,
    required this.invitedCount,
    required this.placedCount,
  });

  final bool held;
  final bool openDoors;
  final int invitedCount;
  final int placedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('reading-house-state-line'),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x243FA98A)),
        color: const Color(0x0A3FA98A),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 7,
        children: [
          _StateText(
            held ? 'Held in your flows' : 'Not yet held',
            emphasized: true,
          ),
          const _StateDot(),
          _StateText(openDoors ? 'Open in Commons' : 'Closed house'),
          const _StateDot(),
          _StateText(
            invitedCount == 0
                ? 'No readers invited'
                : 'Waiting on $invitedCount ${invitedCount == 1 ? 'reader' : 'readers'}',
          ),
          const _StateDot(),
          _StateText(
            placedCount == 0
                ? 'Not scheduled'
                : '$placedCount ${placedCount == 1 ? 'sitting' : 'sittings'} placed',
            muted: placedCount == 0,
          ),
        ],
      ),
    );
  }
}

class _StateText extends StatelessWidget {
  const _StateText(this.text, {this.emphasized = false, this.muted = false});

  final String text;
  final bool emphasized;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: _uiStyle(
        color: emphasized
            ? ReadingHouseDetailTokens.houseHighlight
            : muted
            ? const Color(0xFF59615D)
            : const Color(0xFF718179),
        fontSize: 11.5,
        height: 1.35,
      ),
    );
  }
}

class _StateDot extends StatelessWidget {
  const _StateDot();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 3,
      height: 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF32423B),
        ),
      ),
    );
  }
}

class _SittingRow extends StatelessWidget {
  const _SittingRow({
    required this.sitting,
    required this.status,
    required this.onTap,
  });

  final ReadingHouseSitting sitting;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final number = sitting.eventNumber.toString().padLeft(2, '0');
    return InkWell(
      key: ValueKey<String>('reading-house-sitting-${sitting.eventNumber}'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x173FA98A))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 32,
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  number,
                  style: _uiStyle(
                    color: ReadingHouseDetailTokens.goldDim,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sitting.title,
                    style: _displayStyle(
                      color: ReadingHouseDetailTokens.gold,
                      fontSize: 21,
                      fontStyle: FontStyle.italic,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    status,
                    style: _uiStyle(
                      color: const Color(0xFF59635E),
                      fontSize: 10.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    sitting.privatePrompt,
                    style: _displayStyle(
                      color: ReadingHouseDetailTokens.silver,
                      fontSize: 15.5,
                      fontStyle: FontStyle.italic,
                      height: 1.38,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Icon(
                Icons.chevron_right,
                size: 17,
                color: ReadingHouseDetailTokens.house,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingFrame extends StatelessWidget {
  const _ReadingFrame();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey<String>('reading-house-reading-frame'),
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionEyebrow('THE READING FRAME'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0x293FA98A)),
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0x0F3FA98A), Color(0x03FFFFFF)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _UpperLabel('HOUSE QUESTION · CAN WAIT'),
                const SizedBox(height: 9),
                Text(
                  kReadingHouseDefaultQuestion,
                  style: _displayStyle(
                    color: ReadingHouseDetailTokens.bone,
                    fontSize: 19,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Refine the question, sections, prompts, and sitting details whenever the house is ready.',
                  style: _uiStyle(
                    color: ReadingHouseDetailTokens.silverLow,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
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

class _HistoricalContext extends StatelessWidget {
  const _HistoricalContext();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey<String>('reading-house-historical-context'),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          key: const ValueKey<String>('reading-house-context-toggle'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 2),
          childrenPadding: const EdgeInsets.fromLTRB(2, 0, 2, 16),
          collapsedIconColor: const Color(0xFF386D5C),
          iconColor: const Color(0xFF386D5C),
          shape: const Border(
            top: BorderSide(color: ReadingHouseDetailTokens.separator),
            bottom: BorderSide(color: ReadingHouseDetailTokens.separator),
          ),
          collapsedShape: const Border(
            top: BorderSide(color: ReadingHouseDetailTokens.separator),
            bottom: BorderSide(color: ReadingHouseDetailTokens.separator),
          ),
          title: Text(
            'In Kemet',
            style: _displayStyle(
              color: ReadingHouseDetailTokens.silver,
              fontSize: 16.5,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                kReadingHouseHistoricalBadgeText,
                style: _displayStyle(
                  color: const Color(0xFF858B86),
                  fontSize: 16,
                  height: 1.48,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlinePillButton extends StatelessWidget {
  const _OutlinePillButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          disabledForegroundColor: ReadingHouseDetailTokens.silverLow,
          side: BorderSide(color: color.withValues(alpha: 0.38)),
          shape: const StadiumBorder(),
          textStyle: _displayStyle(fontSize: 16),
        ),
        child: Text(label),
      ),
    );
  }
}

class _DashedPillButton extends StatelessWidget {
  const _DashedPillButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: CustomPaint(
        foregroundPainter: const _DashedRoundedRectPainter(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: _displayStyle(
                  color: ReadingHouseDetailTokens.houseHighlight,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(999)),
      );
    final paint = Paint()
      ..color = ReadingHouseDetailTokens.houseHighlight.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _SittingSheetView { menu, edit, place }

class _ReadingHouseSittingSheet extends StatefulWidget {
  const _ReadingHouseSittingSheet({required this.sitting});

  final ReadingHouseSitting sitting;

  @override
  State<_ReadingHouseSittingSheet> createState() =>
      _ReadingHouseSittingSheetState();
}

class _ReadingHouseSittingSheetState extends State<_ReadingHouseSittingSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _sectionController;
  late final TextEditingController _themeController;
  late final TextEditingController _promptController;
  late final TextEditingController _hostNoteController;
  late DateTime _date;
  late TimeOfDay _time;
  _SittingSheetView _view = _SittingSheetView.menu;

  @override
  void initState() {
    super.initState();
    final sitting = widget.sitting;
    _titleController = TextEditingController(text: sitting.title);
    _sectionController = TextEditingController(text: sitting.section);
    _themeController = TextEditingController(text: sitting.theme);
    _promptController = TextEditingController(text: sitting.privatePrompt);
    _hostNoteController = TextEditingController(text: sitting.hostNote);
    _date = DateUtils.dateOnly(sitting.scheduledDate ?? DateTime.now());
    _time = TimeOfDay(hour: sitting.hour, minute: sitting.minute);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sectionController.dispose();
    _themeController.dispose();
    _promptController.dispose();
    _hostNoteController.dispose();
    super.dispose();
  }

  ReadingHouseSitting _draft({bool place = false}) {
    return widget.sitting.copyWith(
      title: _titleController.text.trim().isEmpty
          ? widget.sitting.title
          : _titleController.text.trim(),
      section: _sectionController.text.trim(),
      theme: _themeController.text.trim(),
      privatePrompt: _promptController.text.trim(),
      hostNote: _hostNoteController.text.trim(),
      scheduledDate: place ? _date : widget.sitting.scheduledDate,
      hour: _time.hour,
      minute: _time.minute,
    );
  }

  Future<void> _pickDate() async {
    final picked = await MaatFlowDatePicker.show(
      context: context,
      initialDate: _date,
      initialMode: MaatFlowDatePickerMode.kemetic,
    );
    if (picked == null || !mounted) return;
    setState(() => _date = DateUtils.dateOnly(picked.date));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.88,
        child: Material(
          key: const ValueKey<String>('reading-house-sitting-sheet'),
          color: const Color(0xFF0A0D0B),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            side: BorderSide(color: Color(0x427FD9BC)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    const SizedBox(
                      width: 42,
                      height: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFF33463E),
                          borderRadius: BorderRadius.all(Radius.circular(99)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          key: const ValueKey<String>(
                            'reading-house-sitting-close',
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close,
                            color: ReadingHouseDetailTokens.silver,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: switch (_view) {
                    _SittingSheetView.menu => _buildMenu(),
                    _SittingSheetView.edit => _buildEditor(),
                    _SittingSheetView.place => _buildPlacement(),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenu() {
    final number = widget.sitting.eventNumber.toString().padLeft(2, '0');
    return Column(
      key: const ValueKey<String>('reading-house-sitting-menu'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetKicker('SITTING $number'),
        const SizedBox(height: 8),
        _SheetHeading(widget.sitting.title),
        const SizedBox(height: 12),
        Text(
          widget.sitting.privatePrompt,
          style: _displayStyle(
            color: ReadingHouseDetailTokens.silver,
            fontSize: 16,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        _OutlinePillButton(
          key: const ValueKey<String>('reading-house-edit-sitting'),
          label: 'Edit reading section & prompt',
          color: ReadingHouseDetailTokens.houseHighlight,
          onTap: () => setState(() => _view = _SittingSheetView.edit),
        ),
        const SizedBox(height: 10),
        _OutlinePillButton(
          key: const ValueKey<String>('reading-house-place-sitting'),
          label: 'Choose date & time',
          color: ReadingHouseDetailTokens.houseHighlight,
          onTap: () => setState(() => _view = _SittingSheetView.place),
        ),
      ],
    );
  }

  Widget _buildEditor() {
    return Column(
      key: const ValueKey<String>('reading-house-sitting-editor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetBack(onTap: () => setState(() => _view = _SittingSheetView.menu)),
        const _SheetKicker('EDIT SITTING'),
        const SizedBox(height: 8),
        _SheetHeading(_titleController.text),
        _SheetField(label: 'Sitting title', controller: _titleController),
        _SheetField(
          label: 'Section',
          controller: _sectionController,
          hintText: 'Chapters, pages, maxims, or passage',
        ),
        _SheetField(label: 'Theme', controller: _themeController, maxLines: 2),
        _SheetField(
          label: 'Private prompt',
          controller: _promptController,
          maxLines: 3,
        ),
        _SheetField(
          label: 'Host note',
          trailing: 'optional',
          controller: _hostNoteController,
          hintText: 'Passage to watch, context, or note for the house',
          maxLines: 2,
        ),
        const SizedBox(height: 18),
        _SheetSaveButton(
          key: const ValueKey<String>('reading-house-save-sitting'),
          label: 'Save sitting',
          onTap: () => Navigator.of(context).pop(_draft()),
        ),
      ],
    );
  }

  Widget _buildPlacement() {
    return Column(
      key: const ValueKey<String>('reading-house-sitting-placement'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetBack(onTap: () => setState(() => _view = _SittingSheetView.menu)),
        const _SheetKicker('PLACE SITTING'),
        const SizedBox(height: 8),
        _SheetHeading(widget.sitting.title),
        const SizedBox(height: 14),
        Text(
          'Choose when this sitting should appear. You can move it again later.',
          style: _displayStyle(
            color: ReadingHouseDetailTokens.silver,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x2E3FA98A)),
            borderRadius: BorderRadius.circular(14),
            color: const Color(0x093FA98A),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetKicker('DATE'),
              InkWell(
                key: const ValueKey<String>('reading-house-sitting-date'),
                onTap: _pickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _kemeticDate(_date),
                              style: _displayStyle(
                                color: ReadingHouseDetailTokens.houseHighlight,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              MaterialLocalizations.of(
                                context,
                              ).formatMediumDate(_date),
                              style: _uiStyle(
                                color: ReadingHouseDetailTokens.silverLow,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: ReadingHouseDetailTokens.house,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(color: Color(0x247FD9BC), height: 1),
              const SizedBox(height: 12),
              const _SheetKicker('TIME'),
              const SizedBox(height: 9),
              Row(
                children: [
                  for (var hour = 18; hour <= 20; hour++) ...[
                    if (hour != 18) const SizedBox(width: 8),
                    Expanded(
                      child: _ChoiceButton(
                        label: '${hour - 12}:00 PM',
                        selected: _time.hour == hour,
                        onTap: () => setState(
                          () => _time = TimeOfDay(hour: hour, minute: 0),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SheetSaveButton(
          key: const ValueKey<String>('reading-house-save-placement'),
          label: 'Save date & time',
          onTap: () => Navigator.of(context).pop(_draft(place: true)),
        ),
      ],
    );
  }
}

class _SheetBack extends StatelessWidget {
  const _SheetBack({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: ReadingHouseDetailTokens.houseHighlight,
          padding: const EdgeInsets.only(bottom: 16),
        ),
        child: Text('←  Sitting', style: _uiStyle(fontSize: 14)),
      ),
    );
  }
}

class _SheetKicker extends StatelessWidget {
  const _SheetKicker(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: _uiStyle(
        color: ReadingHouseDetailTokens.house,
        fontSize: 10,
        letterSpacing: 2,
      ),
    );
  }
}

class _SheetHeading extends StatelessWidget {
  const _SheetHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: _displayStyle(
        color: ReadingHouseDetailTokens.gold,
        fontSize: 28,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.label,
    required this.controller,
    this.trailing,
    this.hintText,
    this.maxLines = 1,
  });

  final String label;
  final String? trailing;
  final String? hintText;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _UpperLabel(label.toUpperCase()),
              if (trailing != null)
                Text(
                  trailing!,
                  style: _uiStyle(color: const Color(0xFF56615B), fontSize: 10),
                ),
            ],
          ),
          const SizedBox(height: 7),
          TextField(
            controller: controller,
            maxLines: maxLines,
            cursorColor: ReadingHouseDetailTokens.houseHighlight,
            style: _uiStyle(
              color: ReadingHouseDetailTokens.bone,
              fontSize: 15,
              height: 1.35,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: hintText,
              hintStyle: _uiStyle(
                color: ReadingHouseDetailTokens.silverLow,
                fontSize: 15,
              ),
              filled: true,
              fillColor: const Color(0xFF080A08),
              contentPadding: const EdgeInsets.all(11),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0x337FD9BC)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xB87FD9BC)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetSaveButton extends StatelessWidget {
  const _SheetSaveButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: ReadingHouseDetailTokens.houseHighlight,
          backgroundColor: const Color(0x143FA98A),
          side: const BorderSide(color: Color(0x7A7FD9BC)),
          shape: const StadiumBorder(),
          textStyle: _displayStyle(fontSize: 17),
        ),
        child: Text(label),
      ),
    );
  }
}

class _ReaderSearchResult {
  const _ReaderSearchResult({
    required this.name,
    required this.handle,
    required this.initials,
  });

  final String name;
  final String handle;
  final String initials;
}

class _ReaderInviteSheet extends StatefulWidget {
  const _ReaderInviteSheet();

  @override
  State<_ReaderInviteSheet> createState() => _ReaderInviteSheetState();
}

class _ReaderInviteSheetState extends State<_ReaderInviteSheet> {
  static const _samples = <_ReaderSearchResult>[
    _ReaderSearchResult(
      name: 'Amina Reed',
      handle: '@aminareads',
      initials: 'AR',
    ),
    _ReaderSearchResult(name: 'Nia Morgan', handle: '@niam', initials: 'NM'),
    _ReaderSearchResult(
      name: 'Sam Carter',
      handle: '@samcarter',
      initials: 'SC',
    ),
  ];

  String _query = '';

  @override
  Widget build(BuildContext context) {
    final normalized = _query.trim().toLowerCase();
    final results = normalized.isEmpty
        ? const <_ReaderSearchResult>[]
        : _samples
              .where(
                (reader) =>
                    reader.name.toLowerCase().contains(normalized) ||
                    reader.handle.toLowerCase().contains(normalized),
              )
              .toList(growable: false);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        key: const ValueKey<String>('reading-house-invite-sheet'),
        color: const Color(0xFF0A0D0B),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: Color(0x427FD9BC)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 15, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Spacer(),
                  const SizedBox(
                    width: 42,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFF33463E),
                        borderRadius: BorderRadius.all(Radius.circular(99)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: ReadingHouseDetailTokens.silver,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const _SheetKicker('READERS'),
              const SizedBox(height: 8),
              const _SheetHeading('Invite a reader'),
              const SizedBox(height: 18),
              TextField(
                key: const ValueKey<String>('reading-house-reader-search'),
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                cursorColor: ReadingHouseDetailTokens.houseHighlight,
                style: _uiStyle(
                  color: ReadingHouseDetailTokens.bone,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF65756D),
                  ),
                  hintText: 'Search by @handle or display name',
                  hintStyle: _uiStyle(
                    color: const Color(0xFF59635E),
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF080A08),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0x427FD9BC)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xB87FD9BC)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                normalized.isEmpty
                    ? 'Type a name or @handle. Visual preview only — no invite will be sent.'
                    : results.isEmpty
                    ? 'No local preview results.'
                    : 'Choose a preview reader. No invite will be sent.',
                style: _uiStyle(
                  color: ReadingHouseDetailTokens.silverLow,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              for (final reader in results)
                InkWell(
                  key: ValueKey<String>(
                    'reading-house-reader-result-${reader.handle}',
                  ),
                  onTap: () => Navigator.of(context).pop(reader),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 54),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0x1A3FA98A)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0x143FA98A),
                          ),
                          child: Text(
                            reader.initials,
                            style: _uiStyle(
                              color: ReadingHouseDetailTokens.houseHighlight,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reader.name,
                                style: _displayStyle(
                                  color: ReadingHouseDetailTokens.bone,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                reader.handle,
                                style: _uiStyle(
                                  color: ReadingHouseDetailTokens.silverLow,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'ADD',
                          style: _uiStyle(
                            color: ReadingHouseDetailTokens.houseHighlight,
                            fontSize: 12,
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

String _kemeticDate(DateTime date) {
  final kemetic = KemeticMath.fromGregorian(date);
  final month = getMonthById(kemetic.kMonth).displayFull;
  return '$month ${kemetic.kDay}';
}

String _countWord(int value) {
  return switch (value) {
    1 => 'One',
    2 => 'Two',
    3 => 'Three',
    _ => '$value',
  };
}

TextStyle _displayStyle({
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    color: color,
    fontFamily: MaatFlowListTokens.fontFamily,
    fontFamilyFallback: MaatFlowListTokens.fontFallback,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    height: height,
    letterSpacing: letterSpacing,
  );
}

TextStyle _uiStyle({
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  double? height,
  double? letterSpacing,
}) {
  return _displayStyle(
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    height: height,
    letterSpacing: letterSpacing,
  );
}
