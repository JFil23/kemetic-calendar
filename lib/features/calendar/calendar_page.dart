import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/* ───────────────────── Premium Dark Theme + Gloss ───────────────────── */

const Color _bg = Color(0xFF0E0E10); // charcoal
const Color _gold = Color(0xFFD4AF37);
const Color _silver = Color(0xFFC8CCD2);
const Color _cardBorderGold = _gold;

// Gregorian blue (high contrast on dark)
const Color _blue = Color(0xFF4DA3FF);
const Color _blueLight = Color(0xFFBFE0FF);
const Color _blueDeep = Color(0xFF0B64C0);

// Gentle highlight and depth shades for glossy gradients
const Color _goldLight = Color(0xFFFFE8A3);
const Color _goldDeep = Color(0xFF8A6B16);
const Color _silverLight = Color(0xFFF5F7FA);
const Color _silverDeep = Color(0xFF7A838C);

// Gradients for gloss (top-left to bottom-right)
const Gradient _goldGloss = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_goldLight, _gold, _goldDeep],
  stops: [0.0, 0.55, 1.0],
);

const Gradient _silverGloss = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_silverLight, _silver, _silverDeep],
  stops: [0.0, 0.55, 1.0],
);

const Gradient _blueGloss = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_blueLight, _blue, _blueDeep],
  stops: [0.0, 0.55, 1.0],
);

// "White" gloss for text that should render pure white via ShaderMask
const Gradient _whiteGloss = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Colors.white, Colors.white, Colors.white],
);

// Base text styles (color overridden to white inside gloss wrappers)
const TextStyle _titleGold =
TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Colors.white);
const TextStyle _monthTitleGold =
TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white);
const TextStyle _rightSmall =
TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white);
const TextStyle _seasonStyle =
TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white);
const TextStyle _decanStyle =
TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Colors.white);

/* Gregorian month names (1-based) */
const List<String> _gregMonthNames = [
  '',
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/* ─────────── Month / Decan info text (from user) ─────────── */

const Map<int, String> _monthInfo = {
  1: '''
Month 1 – Tekh (Thoth)
The year begins under Djehuty (Thoth), the ibis-headed god of writing, reckoning, and truth. Myth tells how Thoth restored balance after Set tore apart the moon’s eye, reassembling it into wholeness — a story the Kemites lived as they rebuilt their fields after the flood. Farmers in the Old Kingdom measured plots with cords, recorded in hieroglyphs on clay tablets, so every family’s share was fair. Priests invoked Thoth in dawn prayers, reminding all that life only thrives when truth and fairness rule. The first month was the season of renewal — when Maʿat was set back into place through survey, ritual, and careful planning.
''',
  2: '''
Month 2 – Menkhet (Paopi)
This month’s name is tied to “bringing” or “carrying,” hinting at offerings and sustenance. Ritual calendars mark feasts of Hathor, the golden cow who embodies fertility, love, and joy. She is the one who danced to save humanity when Ra’s wrath nearly destroyed it — a myth retold in feasting and music. In the fields, new shoots pushed through, and women often sang as they carried baskets of first greens. Harmony meant celebrating the sweetness of life after chaos, and so Paopi carried both food and joy into the year.
''',
  3: '''
Month 3 – Hathor (Athyr)
Here the goddess Hathor herself gave the month its name. Old Kingdom texts praise her as “Mistress of Turquoise” in the Sinai mines, and “Lady of Byblos” in trade ports, showing how her joy extended beyond the Nile. Families held festivals with beer and dance, mirroring her cosmic laughter that restored Ra’s heart. In practical life, cattle were tended and dairy produced, linking directly to her nurturing cow form. To live Maʿat was to live joy in balance: neither excess nor deprivation, but harmony between labor and delight.
''',
  4: '''
Month 4 – Ka-ḥer-ka (Khoiak/Nehebkau)
This month pulsed with the mystery of Osiris, god of the dead and green grain. His murder by Set, dismemberment, and resurrection through Isis was enacted in the Khoiak festival. Priests planted “Osiris beds” — trays of earth sprouting barley — and villagers too germinated seeds to honor life reborn from death. Funerary rituals reminded each family that ancestors live on in cycles of renewal. Farmers sowed their fields, their very labor mirroring Osiris rising. Here, Maʿat taught that even in decay, balance promises rebirth.
''',
  5: '''
Month 5 – Šef-Bedet (Tybi)
This month’s name recalls a protective goddess. Grain now stood high and green; farmers weeded and guarded fields. Priests honored Renenutet, cobra-goddess of harvest destiny, whose gaze determined each household’s fortune. The serpent, feared and revered, symbolized the double-edge of balance: poison and protection. Families poured beer offerings at the field’s edge, aligning themselves with her guardianship. Living Maʿat meant honoring both danger and blessing as parts of one order.
''',
  6: '''
Month 6 – Rekh-Wer (Mechir)
“Rekh” means knowledge. This was a month of close observation: water levels receded, and crops demanded care. Priests marked star risings to guide timing of rituals; farmers thinned seedlings and reinforced dikes. Myth connected this vigilance to Ra’s nightly journey — as he faced dangers in the Duat, so too must farmers face the uncertainty of weather and pests. Maʿat here meant foresight: balancing hope with discipline, care with patience.
''',
  7: '''
Month 7 – Rekh-Neds (Phamenoth)
Illness often rose this time of year as stagnant pools bred disease. The child-god Horus (Har-pa-khered), who was poisoned by Set but healed by Isis, was invoked in protective spells. Mothers recited “Horus is healed, may my child be healed” over their families. Fields thickened with ripening grain — the Eye of Horus restored to fullness, symbolizing health regained. Maʿat meant protection of the vulnerable and recognition of life’s fragility, balanced by the strength of recovery.
''',
  8: '''
Month 8 – Renwet (Pharmuthi)
Renenutet was fully honored now as the ripening fields belonged to her. The cobra goddess was shown coiled around sheaves, ensuring abundance if respected. Families left offerings of bread, milk, and honey in small shrines by canals. Farmers tied knots of papyrus reeds for protection, echoing the coiled serpent as guardian. Balance was gratitude: recognizing that the earth’s gifts required reciprocity. To withhold thanks was to court isfet (disorder).
''',
  9: '''
Month 9 – Pakhons (Pachons)
This month often bore martial imagery in later times, linked to Montu or Khonsu, warrior and moon gods. The harvest season demanded vigilance: pests, thieves, and storms threatened. Farmers and temple workers organized watch rotations, echoing the god’s guardianship. Priests emphasized Maʿat as strength with justice — not cruelty, but protection of the weak. Life demanded defense of balance against chaos, in fields as in myth.
''',
  10: '''
Month 10 – Payni (Paoni)
Granaries opened as reaping accelerated. Hymns to Ra praised his daily rebirth: as the sun was cut and reborn, so too was the crop. Processions carried solar barks in temple courts, mirroring the sun’s journey. Villagers joined in music, celebrating survival through another agricultural cycle. Maʿat was embodied in cycles themselves: endings feeding beginnings, labor balanced by festivity.
''',
  11: '''
Month 11 – Ipi (Epiphi)
The land turned dry and harsh; harvest completed, the focus shifted to storage. Priests watched the horizon for Sopdet (Sothis/Isis). Her heliacal rising heralded the flood’s return. Myth told how she, as star, searched for her brother Osiris — a search mirrored in the anticipation of inundation. Families prepared offerings at river shrines, asking for safe floodwaters. Balance was trust: surrender to the cosmic rhythm, knowing hardship gives way to renewal.
''',
  12: '''
Month 12 – Mesore (Mesori)
“Birth of the Sun” closed the year. The sun blazed fiercely; drought threatened, but hope rested on the rising flood. Rituals honored Ra’s strength and Horus’ kingship, ensuring cosmic order would hold. Farmers cleaned canals and prepared tools for the coming inundation. This was closure and readiness — storing wisdom as much as grain. Maʿat meant respecting limits: knowing that abundance ends, yet cycles renew.
''',
};

const List<String> _decanInfo = [
// 36, order-aligned: month 1 decan 0..2, then month 2, ...
  'ṯmꜣt ḥrt — Small faint cluster rising at dawn; symbolized new beginnings. Priests counted night hours from it; families used it to guide early planting.',
  'ṯmꜣt ẖrt — A continuation cluster; its slow rise reassured farmers that order persisted. Builders used its 10 days for measuring works.',
  'wšꜣty bkꜣty — Twin stars; seen as companions guiding irrigation crews. Symbolized cooperation in labor.',
  'ı͗pḏs — Bright spear-like star; heralded new duties. Priests tied it to Osiris’ germination.',
  'sbšsn — Scattered sparks; marked weeding time. Rituals asked for vigor in seedlings.',
  'ḫntt ḥrt — Leading star with faint trail; caravans used it to orient in desert routes.',
  'ḫntt ẖrt — Western set cluster; warned of illness; healers timed remedies to it.',
  'ṯms n ḫntt — Dense group; used for scheduling labor gangs, ensuring fairness.',
  'ḳdty — Pair of stars called “the Builders.” Workmen measured shifts by its rising.',
  'ḫnwy — Twin balance stars; priests linked them to Horus’ eyes, used in healing rites.',
  'ḥry-ı͗b wı͗ꜣ — Star group within Orion’s field; served as watch star for temple guards.',
  '“Crew” — Asterism of faint lights; represented collective workers rowing Ra’s bark. Its 10 days honored communal duty.',
  'knmw — Khnum’s cluster, linked to shaping clay; priests used it in potter’s rituals.',
  'smd srt — Scatter of faint stars; priests saw it as the threshing floor of the sky.',
  'srt — Serpentine arc; invoked in protective spells, reflecting snakes in the fields.',
  'sꜣwy srt — Companion stars; called twin serpents, balancing harm and healing.',
  'ẖry ḫpd srt — Western serpent group; time of rites against venom.',
  'tpy-ꜥ ꜣḫwy — “First of the Horizon Ones”; bright marker of mid-season. Used for timing canal duties.',
  'ꜣḫwy — Strong Orion-associated group; key in dividing night into hours.',
  'ı͗my-ḫt ꜣḫwy — Southern aspect of Orion; tracked for southern trade routes.',
  'bꜣwy — Twin stars called “Two Souls”; symbolized duality, life and death.',
  'ḳd — Builder’s star; temple masons aligned blocks in its 10-day span.',
  'ḫꜣw — “Shining Ones”; gleamed like ripening grain, used to time offerings.',
  'ꜥrt — Chamber stars; linked to tomb chambers; funerary rituals timed to them.',
  'ẖry ꜥrt — Overseer of chamber; honored by necropolis workers.',
  'rmn ḥry sꜣḥ — Part of Orion’s belt; Osiris’ spine; rituals marked it.',
  'rmn ẖry sꜣḥ — Companion star of Orion; priests aligned tomb shafts to it.',
  'ꜥbwt — Boat cluster; symbolized ancestral ferrymen in Duat.',
  'wꜥrt ẖrt sꜣḥ — Orion’s companion; tied to Osiris’ great rites.',
  'tpy-ꜥ spdt — Herald of Sirius; priests watched for it to ready for Sopdet.',
  'spdt (Sopdet) — Sirius, brightest star; her rising set the year’s rhythm, linked to Isis.',
  'knmt — Guarding cluster near Sirius; symbolized watchful protection.',
  'sꜣwy knmt — Twin guardians; invoked in protective charms.',
  'ẖry ḫpd n knmt — Overseer of Knmt; priests marked offerings at this time.',
  'ḥꜣt ḫꜣw — Foremost of the shining; gleamed at harvest’s climax, linked to Ra’s strength.',
  'pḥwy ḫꜣw — Rear of the shining; closed the cycle; rituals ensured rebirth of order.',
];

/* ─────────── Gloss helpers (lint-clean) ─────────── */

class _Glossy extends StatelessWidget {
  final Widget child;
  final Gradient gradient;
  const _Glossy({required this.child, required this.gradient});
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) => gradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: child,
    );
  }
}

class _GlossyText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient gradient;

  const _GlossyText({
    required this.text,
    required this.style,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return _Glossy(
      gradient: gradient,
      child: Text(
        text,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}

class _GlossyIcon extends StatelessWidget {
  final IconData icon;
  final Gradient gradient;
  const _GlossyIcon(this.icon, {required this.gradient});
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Icon(icon, color: Colors.white),
    );
  }
}

class _GlossyDot extends StatelessWidget {
  final Gradient gradient;
  const _GlossyDot({required this.gradient});
  @override
  Widget build(BuildContext context) {
    return _Glossy(
      gradient: gradient,
      child: Container(
        width: 4.5,
        height: 4.5,
        decoration:
        const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      ),
    );
  }
}

/* ──────────────────────────────────────────────────────────────────────
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

// toggle: Kemetic (false) <-> Gregorian overlay (true)
  bool _showGregorian = false;

// for centering and for snapping to today
  final _centerKey = GlobalKey();
  final _todayMonthKey = GlobalKey(); // month card
  final _todayDayKey = GlobalKey(); // 🔑 individual day chip

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday());
  }

/* ───── helpers ───── */

  String _kKey(int ky, int km, int kd) => '$ky-$km-$kd';

  List<_Note> _getNotes(int kYear, int kMonth, int kDay) =>
      _notes[_kKey(kYear, kMonth, kDay)] ?? const [];

  void _addNote(int kYear, int kMonth, int kDay, String title, String? detail,
      {String? location,
        bool allDay = false,
        TimeOfDay? start,
        TimeOfDay? end}) {
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
    final lastDay =
    (kMonth == 13) ? (KemeticMath.isLeapKemeticYear(kYear) ? 6 : 5) : 30;
    final yStart = KemeticMath.toGregorian(kYear, kMonth, 1).year;
    final yEnd = KemeticMath.toGregorian(kYear, kMonth, lastDay).year;
    return (yStart == yEnd) ? '$yStart' : '$yStart/$yEnd';
  }

  String _monthLabel(int kMonth) =>
      kMonth == 13 ? 'Epagomenal' : _MonthCard.monthNames[kMonth];

/* ───── TODAY snap/center ───── */

  void _scrollToToday() {
    final ctx = _todayDayKey.currentContext ?? _todayMonthKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5, // dead-center
        duration: const Duration(milliseconds: 300),
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
          Navigator.of(context).pop(); // dismiss search (single pop)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _openDaySheet(context, ky, km, kd);
          });
        },
      ),
    );
  }

/* ───── Day Sheet ───── */

  void _openDaySheet(BuildContext ctx, int kYear, int kMonth, int kDay,
      {bool allowDateChange = false}) {
    int selYear = kYear;
    int selMonth = kMonth;
    int selDay = kDay;

    int maxDayFor(int year, int month) =>
        (month == 13) ? (KemeticMath.isLeapKemeticYear(year) ? 6 : 5) : 30;

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
// Clamp before any toGregorian
            int dayCount = maxDayFor(selYear, selMonth);
            if (selDay > dayCount) {
              selDay = dayCount;
              if (allowDateChange && dayCtrl.hasClients) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => dayCtrl.jumpToItem(selDay - 1));
              }
            }

            final titleG =
            KemeticMath.toGregorian(selYear, selMonth, selDay); // safe
            final titleText =
                '${_monthLabel(selMonth)} $selDay • ${titleG.year}';

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
                            onSelectedItemChanged: (i) {
                              setSheetState(() {
                                selMonth = (i % 13) + 1;
                                final max = maxDayFor(selYear, selMonth);
                                if (selDay > max) {
                                  selDay = max;
                                  if (dayCtrl.hasClients) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback(
                                            (_) => dayCtrl.jumpToItem(selDay - 1));
                                  }
                                }
                              });
                            },
                            children: List<Widget>.generate(13, (i) {
                              final m = i + 1;
                              final label = (m == 13)
                                  ? 'Epagomenal'
                                  : _MonthCard.monthNames[m];
                              return Center(
                                child: _GlossyText(
                                  text: label,
                                  style: const TextStyle(fontSize: 14),
                                  gradient: _silverGloss,
                                ),
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
                                final max = maxDayFor(selYear, selMonth);
                                selDay = (i % max) + 1;
                              });
                            },
                            children: List<Widget>.generate(dayCount, (i) {
                              final d = i + 1;
                              return Center(
                                child: _GlossyText(
                                  text: '$d',
                                  style: const TextStyle(fontSize: 14),
                                  gradient: _silverGloss,
                                ),
                              );
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
                            onSelectedItemChanged: (i) {
                              setSheetState(() {
                                selYear = yearStart + i;
                                final max = maxDayFor(selYear, selMonth);
                                if (selDay > max) {
                                  selDay = max;
                                  if (dayCtrl.hasClients) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback(
                                            (_) => dayCtrl.jumpToItem(selDay - 1));
                                  }
                                }
                              });
                            },
                            children: List<Widget>.generate(401, (i) {
                              final ky = yearStart + i;
                              final label = _gregYearLabelFor(ky, selMonth);
                              return Center(
                                child: _GlossyText(
                                  text: label,
                                  style: const TextStyle(fontSize: 14),
                                  gradient: _silverGloss,
                                ),
                              );
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
                        child: _GlossyText(
                          text: 'No notes yet',
                          style: TextStyle(fontSize: 14),
                          gradient: _silverGloss,
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: dayNotes.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 12, color: Colors.white10),
                          itemBuilder: (_, i) {
                            final n = dayNotes[i];
                            final timeLine = _timeRangeLabel(
                                allDay: n.allDay,
                                start: n.start,
                                end: n.end);
                            final location =
                            (n.location?.isEmpty ?? true) ? null : n.location!;
                            final detail =
                            (n.detail?.isEmpty ?? true) ? null : n.detail!;
                            final sub = [
                              if (timeLine.isNotEmpty) timeLine,
                              if (location != null) location,
                              if (detail != null) detail,
                            ].join('\n');

                            return ListTile(
                              dense: true,
                              title: _GlossyText(
                                text: n.title,
                                style: const TextStyle(fontSize: 16),
                                gradient: _silverGloss,
                              ),
                              subtitle: sub.isEmpty
                                  ? null
                                  : _GlossyText(
                                text: sub,
                                style: const TextStyle(fontSize: 12),
                                gradient: _silverGloss,
                              ),
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
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: _GlossyText(
                        text: 'Add note',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        gradient: _silverGloss,
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
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: allDay,
                      onChanged: (v) => setSheetState(() => allDay = v),
                      title: const _GlossyText(
                        text: 'All-day',
                        style: TextStyle(fontSize: 14),
                        gradient: _silverGloss,
                      ),
                      activeThumbColor: _gold,
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

                          if (!allDay && startTime != null && endTime != null) {
                            if (_toMinutes(endTime!) <= _toMinutes(startTime!)) {
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
        title: GestureDetector(
          onTap: () => setState(() => _showGregorian = !_showGregorian),
          child: _GlossyText(
            text: "Ma'at",
            style: _titleGold,
            gradient: _showGregorian ? _whiteGloss : _goldGloss,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Today',
            icon:
            const _GlossyIcon(Icons.calendar_today, gradient: _silverGloss),
            onPressed: _scrollToToday,
          ),
          IconButton(
            tooltip: 'Search events',
            icon: const _GlossyIcon(Icons.search, gradient: _silverGloss),
            onPressed: _openSearch,
          ),
          IconButton(
            tooltip: 'New event',
            icon: const _GlossyIcon(Icons.add, gradient: _goldGloss),
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
                  todayDayKey: null, // no anchor in past/future lists
                  onDayTap: (c, m, d) => _openDaySheet(c, kYear, m, d),
                  notesGetter: (m, d) => _getNotes(kYear, m, d),
                  showGregorian: _showGregorian,
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
              todayDayKey: _todayDayKey, // 🔑 pass day anchor
              onDayTap: (c, m, d) => _openDaySheet(c, kToday.kYear, m, d),
              notesGetter: (m, d) => _getNotes(kToday.kYear, m, d),
              showGregorian: _showGregorian,
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
                  todayDayKey: null,
                  onDayTap: (c, m, d) => _openDaySheet(c, kYear, m, d),
                  notesGetter: (m, d) => _getNotes(kYear, m, d),
                  showGregorian: _showGregorian,
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
    required this.showGregorian,
    this.monthAnchorKeyProvider,
    this.todayDayKey,
  });

  final int kYear;
  final int? todayMonth;
  final int? todayDay;
  final bool showGregorian;
  final List<_Note> Function(int kMonth, int kDay) notesGetter;
  final void Function(BuildContext, int kMonth, int kDay) onDayTap;
  final Key? Function(int kMonth)? monthAnchorKeyProvider;
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
          kYear: kYear,
          kMonth: 1,
          seasonShort: 'Akhet',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(2),
          kYear: kYear,
          kMonth: 2,
          seasonShort: 'Akhet',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(3),
          kYear: kYear,
          kMonth: 3,
          seasonShort: 'Akhet',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(4),
          kYear: kYear,
          kMonth: 4,
          seasonShort: 'Akhet',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),

        const _SeasonHeader(title: 'Emergence season (Peret)'),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(5),
          kYear: kYear,
          kMonth: 5,
          seasonShort: 'Peret',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(6),
          kYear: kYear,
          kMonth: 6,
          seasonShort: 'Peret',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(7),
          kYear: kYear,
          kMonth: 7,
          seasonShort: 'Peret',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(8),
          kYear: kYear,
          kMonth: 8,
          seasonShort: 'Peret',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),

        const _SeasonHeader(title: 'Harvest season (Shemu)'),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(9),
          kYear: kYear,
          kMonth: 9,
          seasonShort: 'Shemu',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(10),
          kYear: kYear,
          kMonth: 10,
          seasonShort: 'Shemu',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(11),
          kYear: kYear,
          kMonth: 11,
          seasonShort: 'Shemu',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),
        _MonthCard(
          anchorKey: monthAnchorKeyProvider?.call(12),
          kYear: kYear,
          kMonth: 12,
          seasonShort: 'Shemu',
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
          showGregorian: showGregorian,
        ),

        _EpagomenalCard(
          kYear: kYear,
          todayMonth: tm,
          todayDay: td,
          todayDayKey: todayDayKey,
          notesGetter: (m, d) => notesGetter(13, d),
          onDayTap: (c, m, d) => onDayTap(c, 13, d),
          showGregorian: showGregorian,
        ),
      ],
    );
  }
}

/* ───────────────────────── KEMETIC MATH ───────────────────────── */

class KemeticMath {
// Epoch anchored to *local midnight*: Toth 1, Year 1 = 2025-03-20 (local).
  static final DateTime _epoch = DateTime(2025, 3, 20);

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
// Local date-only (no timezone math).
    final g = DateUtils.dateOnly(gLocal);
    final diff = g.difference(_epoch).inDays;

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
// Return local date (no UTC conversion).
    return _epoch.add(Duration(days: days));
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
      child:
      _GlossyText(text: title, style: _seasonStyle, gradient: _goldGloss),
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
  final Key? todayDayKey; // 🔑 day anchor to center
  final bool showGregorian;

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
    required this.showGregorian,
    this.todayDayKey,
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
          seasonShort: seasonShort,
          todayMonth: todayMonth,
          todayDay: todayDay,
          showGregorian: showGregorian,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
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
          seasonShort: seasonShort,
          todayMonth: todayMonth,
          todayDay: todayDay,
          showGregorian: showGregorian,
          notesGetter: notesGetter,
          onDayTap: onDayTap,
          decanIndex: decanIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final names = decans[kMonth] ?? const ['Decan A', 'Decan B', 'Decan C'];

    final yStart = KemeticMath.toGregorian(kYear, kMonth, 1).year;
    final yEnd = KemeticMath.toGregorian(kYear, kMonth, 30).year;
    final rightLabel =
    (yStart == yEnd) ? '$seasonShort $yStart' : '$seasonShort $yStart/$yEnd';

    final isMonthToday = (todayMonth != null && todayMonth == kMonth);

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
// Header row: Kemetic month name (left), Season+Year (right)
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _openMonthInfo(context),
                    child: _GlossyText(
                      text: monthNames[kMonth],
                      style: _monthTitleGold,
                      gradient: _goldGloss,
                    ),
                  ),
                  const Spacer(),
                  _GlossyText(
                    text: rightLabel,
                    style: _rightSmall,
                    gradient: _whiteGloss,
                  ),
                ],
              ),
              const SizedBox(height: 10),

// Three decans
              for (var i = 0; i < 3; i++) ...[
// Label row (stable height): decan on left (Kemetic), Gregorian month on right when needed
                Row(
                  children: [
// Kemetic decan name (button; hidden but size kept in Gregorian)
                    Expanded(
                      child: Visibility(
                        visible: !showGregorian,
                        maintainState: true,
                        maintainAnimation: true,
                        maintainSize: true,
                        child: GestureDetector(
                          onTap: () => _openDecanInfo(context, i),
                          child: _GlossyText(
                            text: names[i],
                            style: _decanStyle,
                            gradient: _silverGloss,
                          ),
                        ),
                      ),
                    ),
// Gregorian month name right-aligned (only when needed)
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Visibility(
                          visible: showGregorian &&
                              _gregLabelForDecanRow(kYear, kMonth, i) != null,
                          maintainState: true,
                          maintainAnimation: true,
                          maintainSize: true,
                          child: _GlossyText(
                            text: _gregLabelForDecanRow(kYear, kMonth, i) ?? '',
                            style: _decanStyle,
                            gradient: _blueGloss,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                _DecanRow(
                  kYear: kYear,
                  kMonth: kMonth,
                  decanIndex: i,
                  todayMonth: todayMonth,
                  todayDay: todayDay,
                  todayDayKey: isMonthToday ? todayDayKey : null,
                  notesGetter: notesGetter,
                  onDayTap: onDayTap,
                  showGregorian: showGregorian,
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
  final int kYear; // new: needed to compute Gregorian numbers
  final int kMonth; // 1..12
  final int decanIndex; // 0..2
  final int? todayMonth;
  final int? todayDay;
  final Key? todayDayKey;
  final bool showGregorian;

  final List<_Note> Function(int kMonth, int kDay) notesGetter;
  final void Function(BuildContext, int kMonth, int kDay) onDayTap;

  const _DecanRow({
    required this.kYear,
    required this.kMonth,
    required this.decanIndex,
    required this.todayMonth,
    required this.todayDay,
    required this.notesGetter,
    required this.onDayTap,
    required this.showGregorian,
    required this.todayDayKey,
  });

  @override
  Widget build(BuildContext context) {
    final isMonthToday = (todayMonth != null && todayMonth == kMonth);
    return Row(
      children: List.generate(10, (j) {
        final day = decanIndex * 10 + (j + 1); // 1..30
        final isToday = isMonthToday && (todayDay == day);
        final noteCount = notesGetter(kMonth, day).length;

        final label = showGregorian
            ? '${KemeticMath.toGregorian(kYear, kMonth, day).day}'
            : '$day';

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: j == 9 ? 0 : 6),
            child: _DayChip(
              anchorKey: isToday ? todayDayKey : null, // 🔑 attach
              label: label,
              isToday: isToday,
              noteCount: noteCount,
              onTap: () => onDayTap(context, kMonth, day),
              showGregorian: showGregorian,
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
  final Key? anchorKey; // allow anchoring
  final bool showGregorian;

  const _DayChip({
    required this.label,
    required this.isToday,
    required this.noteCount,
    required this.onTap,
    required this.showGregorian,
    this.anchorKey,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(
      color: Colors.white, // color comes from gradient
      fontWeight: FontWeight.w500,
      fontSize: 12,
    );

// Today is always gold (even in Gregorian); others: blue when Gregorian, silver in Kemetic.
    final gradient = isToday
        ? _goldGloss
        : (showGregorian ? _blueGloss : _silverGloss);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        key: anchorKey, // 🔑
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _GlossyText(
              text: label,
              style: textStyle,
              gradient: gradient,
            ),
            if (noteCount > 0)
              Positioned(
                right: 4,
                bottom: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(noteCount.clamp(1, 3), (i) {
                    return Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
                      child: const _GlossyDot(gradient: _silverGloss),
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
    required this.showGregorian,
    this.todayDayKey,
  });

  final int kYear;
  final int? todayMonth;
  final int? todayDay;
  final List<_Note> Function(int kMonth, int kDay) notesGetter;
  final void Function(BuildContext, int kMonth, int kDay) onDayTap;
  final Key? todayDayKey;
  final bool showGregorian;

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
// Header row: Kemetic header (left) and Gregorian month (right when present)
              Row(
                children: [
                  Expanded(
                    child: Visibility(
                      visible: !showGregorian, // visually removed in Gregorian
                      maintainState: true,
                      maintainAnimation: true,
                      maintainSize: true, // keep height so layout doesn't jump
                      child: const _GlossyText(
                        text: 'Epagomenal Days (Ḥeriu rnp.t)',
                        style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        gradient: _goldGloss,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Visibility(
                        visible: showGregorian && gLabel != null,
                        maintainState: true,
                        maintainAnimation: true,
                        maintainSize: true,
                        child: _GlossyText(
                          text: gLabel ?? '',
                          style: _decanStyle,
                          gradient: _blueGloss,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: List.generate(epiCount, (i) {
                  final n = i + 1; // 1..5 or 1..6
                  final isToday = isMonthToday && (todayDay == n);
                  final noteCount = notesGetter(13, n).length;

                  final label = showGregorian
                      ? '${KemeticMath.toGregorian(kYear, 13, n).day}'
                      : '$n';

                  return Expanded(
                    child: Padding(
                      padding:
                      EdgeInsets.only(right: i == epiCount - 1 ? 0 : 6),
                      child: _DayChip(
                        anchorKey: isToday ? todayDayKey : null, // 🔑
                        label: label,
                        isToday: isToday,
                        noteCount: noteCount,
                        onTap: () => onDayTap(context, 13, n),
                        showGregorian: showGregorian,
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

/* ───────────── Detail Page (private to allow _Note in signature) ───────────── */

class _MonthDetailPage extends StatefulWidget {
  const _MonthDetailPage({
    required this.kYear,
    required this.kMonth,
    required this.seasonShort,
    required this.todayMonth,
    required this.todayDay,
    required this.showGregorian,
    required this.notesGetter,
    required this.onDayTap,
    required this.decanIndex, // null => month view; 0..2 => specific decan
  });

  final int kYear;
  final int kMonth;
  final String seasonShort;
  final int? todayMonth;
  final int? todayDay;
  final bool showGregorian;
  final List<_Note> Function(int kMonth, int kDay) notesGetter;
  final void Function(BuildContext, int kMonth, int kDay) onDayTap;
  final int? decanIndex;

  @override
  State<_MonthDetailPage> createState() => _MonthDetailPageState();
}

class _MonthDetailPageState extends State<_MonthDetailPage> {
  @override
  Widget build(BuildContext context) {
    final infoTitle = widget.decanIndex == null
        ? _MonthCard.monthNames[widget.kMonth]
        : _MonthCard.decans[widget.kMonth]![widget.decanIndex!];

    final infoBody = widget.decanIndex == null
        ? (_monthInfo[widget.kMonth] ?? '')
        : _decanInfo[(widget.kMonth - 1) * 3 + widget.decanIndex!];

    final yStart = KemeticMath.toGregorian(widget.kYear, widget.kMonth, 1).year;
    final yEnd =
        KemeticMath.toGregorian(widget.kYear, widget.kMonth, 30).year;
    final rightLabel = (yStart == yEnd)
        ? '${widget.seasonShort} $yStart'
        : '${widget.seasonShort} $yStart/$yEnd';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111215),
        elevation: 0.5,
        title: _GlossyText(
          text: infoTitle,
          style: _monthTitleGold,
          gradient: _goldGloss,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: _GlossyText(
                text: rightLabel,
                style: _rightSmall,
                gradient: _whiteGloss,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
// Top: month card fills top half
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 10),
              children: [
                _MonthCard(
                  kYear: widget.kYear,
                  kMonth: widget.kMonth,
                  seasonShort: widget.seasonShort,
                  todayMonth: widget.todayMonth,
                  todayDay: widget.todayDay,
                  todayDayKey: null,
                  notesGetter: widget.notesGetter,
                  onDayTap: widget.onDayTap,
                  showGregorian: widget.showGregorian,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
// Bottom: scrollable info text
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GlossyText(
                    text: infoTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    gradient: _silverGloss,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    infoBody.trim(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
      colorScheme: const ColorScheme.dark(
        primary: _gold,
        surface: Color(0xFF111215),
        onSurface: _silver,
      ),
      scaffoldBackgroundColor: _bg,
      canvasColor: _bg,
      dividerColor: Colors.white12,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF111215),
      ),
      iconTheme: const IconThemeData(color: _silver),
      textTheme: base.textTheme.apply(bodyColor: _silver, displayColor: _silver),
      inputDecorationTheme:
      const InputDecorationTheme(hintStyle: TextStyle(color: _silver)),
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
          child: _GlossyText(
            text: 'No matching events',
            style: TextStyle(fontSize: 14),
            gradient: _silverGloss,
          ),
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
          title: _GlossyText(
            text: h.note.title,
            style: const TextStyle(fontSize: 16),
            gradient: _silverGloss,
          ),
          subtitle: _GlossyText(
            text: subtitle,
            style: const TextStyle(fontSize: 12),
            gradient: _silverGloss,
          ),
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