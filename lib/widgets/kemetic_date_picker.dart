import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/* ═══════════════════════ KEMETIC MATH (FIXED) ═══════════════════════ */

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
    return _epoch.add(Duration(days: days));
  }

  // ✅ FIXED: Simple one-liner, no circular dependency
  static bool isLeapKemeticYear(int kYear) => _mod(kYear - 1, 4) == 2;
}

/* ═══════════════════════ STYLING CONSTANTS ═══════════════════════ */

const Color _gold = Color(0xFFD4AF37);
const Color _silver = Color(0xFFC8CCD2);

const Color _goldLight = Color(0xFFFFE8A3);
const Color _goldDeep = Color(0xFF8A6B16);
const Color _silverLight = Color(0xFFF5F7FA);
const Color _silverDeep = Color(0xFF7A838C);

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

const Gradient _whiteGloss = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Colors.white, Colors.white, Colors.white],
);

/* ═══════════════════════ GLOSSY TEXT WIDGETS ═══════════════════════ */

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

/* ═══════════════════════ KEMETIC MONTH NAMES ═══════════════════════ */

const List<String> _kemeticMonthNames = [
  '',
  'Thoth (Ḏḥwty)',
  'Paopi (Pȝ ỉp.t)',
  'Hathor (Ḥwt-Ḥr)',
  'Ka-ḥer-Ka (Kȝ-ḥr-Kȝ)',
  'Šef-Bedet (Šf-bdt)',
  'Rekh-Wer (Rḫ-wr)',
  'Rekh-Nedjes (Rḫ-nḏs)',
  'Renwet (Rnnwt)',
  'Hnsw (Ḥnsw)',
  'Ḥenti-ḥet (Ḥnt-ḥtj)',
  'Pa-Ipi (Ỉpt-ḥmt)',
  'Mesut-Ra (Mswt-Rꜥ)',
];

/* ═══════════════════════ KEMETIC DATE PICKER ═══════════════════════ */

Future<DateTime?> showKemeticDatePicker({
  required BuildContext context,
  DateTime? initialDate,
}) async {
  final initK = KemeticMath.fromGregorian(initialDate ?? DateTime.now());
  int ky = initK.kYear, km = initK.kMonth, kd = initK.kDay;

  int maxDayFor(int year, int month) =>
      (month == 13) ? (KemeticMath.isLeapKemeticYear(year) ? 6 : 5) : 30;

  final yearStart = initK.kYear - 200;
  final yearCtrl =
      FixedExtentScrollController(initialItem: (ky - yearStart).clamp(0, 400));
  final monthCtrl =
      FixedExtentScrollController(initialItem: (km - 1).clamp(0, 12));
  final dayCtrl = FixedExtentScrollController(initialItem: (kd - 1));

  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.black,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) {
      int localKy = ky, localKm = km, localKd = kd;

      int dayMax() => maxDayFor(localKy, localKm);

      // Helper to format year label with Gregorian equivalent
      String gregYearLabelFor(int kYear, int kMonth) {
        final lastDay = maxDayFor(kYear, kMonth);
        final yStart = KemeticMath.toGregorian(kYear, kMonth, 1).year;
        final yEnd = KemeticMath.toGregorian(kYear, kMonth, lastDay).year;
        return (yStart == yEnd) ? '$yStart' : '$yStart/$yEnd';
      }

      return StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          if (localKd > dayMax()) localKd = dayMax();

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Title
                const _GlossyText(
                  text: 'Pick Kemetic date',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  gradient: _goldGloss,
                ),
                const SizedBox(height: 8),

                // 3-Wheel Picker
                SizedBox(
                  height: 160,
                  child: Row(
                    children: [
                      // Month wheel
                      Expanded(
                        flex: 4,
                        child: CupertinoPicker(
                          scrollController: monthCtrl,
                          itemExtent: 32,
                          looping: true,
                          backgroundColor: const Color(0x00121214),
                          onSelectedItemChanged: (i) {
                            setSheetState(() {
                              localKm = (i % 13) + 1;
                              final max = maxDayFor(localKy, localKm);
                              if (localKd > max) {
                                localKd = max;
                                if (dayCtrl.hasClients) {
                                  WidgetsBinding.instance.addPostFrameCallback(
                                      (_) => dayCtrl.jumpToItem(localKd - 1));
                                }
                              }
                            });
                          },
                          children: List<Widget>.generate(13, (i) {
                            final m = i + 1;
                            final label = (m == 13)
                                ? 'Heriu Renpet (ḥr.w rnpt)'
                                : _kemeticMonthNames[m];
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
                      
                      // Day wheel
                      Expanded(
                        flex: 3,
                        child: CupertinoPicker(
                          scrollController: dayCtrl,
                          itemExtent: 32,
                          looping: true,
                          backgroundColor: const Color(0x00121214),
                          onSelectedItemChanged: (i) {
                            setSheetState(() {
                              final max = maxDayFor(localKy, localKm);
                              localKd = (i % max) + 1;
                            });
                          },
                          children: List<Widget>.generate(dayMax(), (i) {
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
                      
                      // Year wheel (with Gregorian equivalent)
                      Expanded(
                        flex: 4,
                        child: CupertinoPicker(
                          scrollController: yearCtrl,
                          itemExtent: 32,
                          looping: false,
                          backgroundColor: const Color(0x00121214),
                          onSelectedItemChanged: (i) {
                            setSheetState(() {
                              localKy = yearStart + i;
                              final max = maxDayFor(localKy, localKm);
                              if (localKd > max) {
                                localKd = max;
                                if (dayCtrl.hasClients) {
                                  WidgetsBinding.instance.addPostFrameCallback(
                                      (_) => dayCtrl.jumpToItem(localKd - 1));
                                }
                              }
                            });
                          },
                          children: List<Widget>.generate(401, (i) {
                            final ky = yearStart + i;
                            final label = gregYearLabelFor(ky, localKm);
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

                const SizedBox(height: 12),
                
                // Cancel / Done buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: _silver),
                        ),
                        onPressed: () => Navigator.pop(sheetCtx, null),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          final g = KemeticMath.toGregorian(localKy, localKm, localKd);
                          Navigator.pop(sheetCtx, DateUtils.dateOnly(g));
                        },
                        child: const _GlossyText(
                          text: 'Done',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          gradient: _whiteGloss,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
