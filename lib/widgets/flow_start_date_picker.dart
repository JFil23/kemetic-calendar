// lib/widgets/flow_start_date_picker.dart
// Reusable date picker for flow start dates (Ma'at-style UI)
// Extracted from _MaatFlowTemplateDetailPage._pickDate

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show KemeticMath;
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:mobile/features/calendar/kemetic_time_constants.dart';
import 'package:mobile/widgets/month_name_text.dart';

class FlowStartDatePicker {
  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initialDate,
  }) async {
    // Local working state (so you can switch modes inside the sheet)
    bool localKemetic = false; // Default to Gregorian

    // ---- Gregorian seed (default = tomorrow or initialDate) ----
    final now = DateUtils.dateOnly(DateTime.now());
    DateTime gSeed = initialDate ?? (() {
      int y = now.year, m = now.month, d = now.day + 1;
      final maxD = DateUtils.getDaysInMonth(y, m);
      if (d > maxD) { d = 1; m = (m == 12) ? 1 : m + 1; if (m == 1) y++; }
      return DateTime(y, m, d);
    })();
    int gy = gSeed.year, gm = gSeed.month, gd = gSeed.day;

    // ---- Kemetic seed (use today's Kemetic by default) ----
    var kSeed = KemeticMath.fromGregorian(initialDate ?? now.add(const Duration(days: 1)));
    int ky = kSeed.kYear, km = kSeed.kMonth, kd = kSeed.kDay;

    int _gregDayMax(int y, int m) => DateUtils.getDaysInMonth(y, m);
    int _kemDayMax(int year, int month) =>
        (month == 13) ? (KemeticMath.isLeapKemeticYear(year) ? 6 : 5) : 30;

    // Controllers
    final int gYearStart = now.year; // show future-oriented years
    final gYearCtrl  = FixedExtentScrollController(initialItem: (gy - gYearStart).clamp(0, 399));
    final gMonthCtrl = FixedExtentScrollController(initialItem: (gm - 1).clamp(0, 11));
    final gDayCtrl   = FixedExtentScrollController(initialItem: (gd - 1).clamp(0, 30));

    final int kYearStart = ky; // centered on current Kemetic year
    final kYearCtrl  = FixedExtentScrollController(initialItem: (ky - kYearStart).clamp(0, 400));
    final kMonthCtrl = FixedExtentScrollController(initialItem: (km - 1).clamp(0, 12));
    final kDayCtrl   = FixedExtentScrollController(initialItem: (kd - 1).clamp(0, 29));

    // Gregorian month names
    const _gregMonthNames = {
      1: 'Jan', 2: 'Feb', 3: 'Mar', 4: 'Apr', 5: 'May', 6: 'Jun',
      7: 'Jul', 8: 'Aug', 9: 'Sep', 10: 'Oct', 11: 'Nov', 12: 'Dec',
    };

    return await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            // Clamp wheels when parents change
            final gMax = _gregDayMax(gy, gm);
            if (gd > gMax) gd = gMax;
            final kMax = _kemDayMax(ky, km);
            if (kd > kMax) kd = kMax;

            Widget _gregWheel() => SizedBox(
              height: 160,
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: CupertinoPicker(
                      scrollController: gMonthCtrl,
                      itemExtent: 32,
                      looping: true,
                      backgroundColor: const Color(0x00121214),
                      onSelectedItemChanged: (i) {
                        setSheetState(() {
                          gm = (i % 12) + 1;
                          final mx = _gregDayMax(gy, gm);
                          if (gd > mx && gDayCtrl.hasClients) {
                            gd = mx;
                            WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => gDayCtrl.jumpToItem(gd - 1),
                            );
                          }
                        });
                      },
                      children: List.generate(12, (i) {
                        return Center(
                          child: GlossyText(
                            text: _gregMonthNames[i + 1]!,
                            style: const TextStyle(fontSize: 14),
                            gradient: silverGloss,
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 3,
                    child: CupertinoPicker(
                      scrollController: gDayCtrl,
                      itemExtent: 32,
                      looping: true,
                      backgroundColor: const Color(0x00121214),
                      onSelectedItemChanged: (i) {
                        setSheetState(() {
                          final mx = _gregDayMax(gy, gm);
                          gd = (i % mx) + 1;
                        });
                      },
                      children: List.generate(_gregDayMax(gy, gm), (i) {
                        final dd = i + 1;
                        return Center(
                          child: GlossyText(
                            text: '$dd',
                            style: const TextStyle(fontSize: 14),
                            gradient: silverGloss,
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: CupertinoPicker(
                      scrollController: gYearCtrl,
                      itemExtent: 32,
                      looping: true,
                      backgroundColor: const Color(0x00121214),
                      onSelectedItemChanged: (i) {
                        setSheetState(() {
                          gy = gYearStart + i;
                          final mx = _gregDayMax(gy, gm);
                          if (gd > mx && gDayCtrl.hasClients) {
                            gd = mx;
                            WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => gDayCtrl.jumpToItem(gd - 1),
                            );
                          }
                        });
                      },
                      children: List.generate(40, (i) {
                        final yy = gYearStart + i;
                        return Center(
                          child: GlossyText(
                            text: '$yy',
                            style: const TextStyle(fontSize: 14),
                            gradient: silverGloss,
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            );

            Widget _kemWheel() => SizedBox(
              height: 160,
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: CupertinoPicker(
                      scrollController: kMonthCtrl,
                      itemExtent: 32,
                      looping: true,
                      backgroundColor: const Color(0x00121214),
                      onSelectedItemChanged: (i) {
                        setSheetState(() {
                          km = (i % 13) + 1;
                          final mx = _kemDayMax(ky, km);
                          if (kd > mx && kDayCtrl.hasClients) {
                            kd = mx;
                            WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => kDayCtrl.jumpToItem(kd - 1),
                            );
                          }
                        });
                      },
                      children: List.generate(13, (i) {
                        final m = i + 1;
                        return Center(
                          child: MonthNameText(
                            getMonthById(m).displayFull,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 3,
                    child: CupertinoPicker(
                      scrollController: kDayCtrl,
                      itemExtent: 32,
                      looping: true,
                      backgroundColor: const Color(0x00121214),
                      onSelectedItemChanged: (i) {
                        setSheetState(() {
                          final mx = _kemDayMax(ky, km);
                          kd = (i % mx) + 1;
                        });
                      },
                      children: List.generate(_kemDayMax(ky, km), (i) {
                        final dd = i + 1;
                        return Center(
                          child: GlossyText(
                            text: '$dd',
                            style: const TextStyle(fontSize: 14),
                            gradient: silverGloss,
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: CupertinoPicker(
                      scrollController: kYearCtrl,
                      itemExtent: 32,
                      looping: true,
                      backgroundColor: const Color(0x00121214),
                      onSelectedItemChanged: (i) {
                        setSheetState(() {
                          ky = kYearStart + i;
                          final mx = _kemDayMax(ky, km);
                          if (kd > mx && kDayCtrl.hasClients) {
                            kd = mx;
                            WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => kDayCtrl.jumpToItem(kd - 1),
                            );
                          }
                        });
                      },
                      children: List.generate(401, (i) {
                        final y = kYearStart + i;
                        // Show Gregorian year label for the chosen Kemetic month
                        final last =
                        (km == 13) ? (KemeticMath.isLeapKemeticYear(y) ? 6 : 5) : 30;
                        final yStart = KemeticMath.toGregorian(y, km, 1).year;
                        final yEnd   = KemeticMath.toGregorian(y, km, last).year;
                        final label  = (yStart == yEnd) ? '$yStart' : '$yStart/$yEnd';
                        return Center(
                          child: GlossyText(
                            text: label,
                            style: const TextStyle(fontSize: 14),
                            gradient: silverGloss,
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            );

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

                  // Mode toggle
                  CupertinoSegmentedControl<bool>(
                    groupValue: localKemetic,
                    padding: const EdgeInsets.all(2),
                    children: const {
                      true: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Text('Kemetic'),
                      ),
                      false: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Text('Gregorian'),
                      ),
                    },
                    onValueChanged: (v) {
                      setSheetState(() {
                        if (v) {
                          // Switch to Kemetic
                          final gNow = DateTime(gy, gm, gd);
                          final k = KemeticMath.fromGregorian(gNow);
                          ky = k.kYear;
                          km = k.kMonth;
                          kd = k.kDay;
                          final kMax = _kemDayMax(ky, km);
                          if (kd > kMax) kd = kMax;
                          localKemetic = true;

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            kYearCtrl.jumpToItem((ky - kYearStart).clamp(0, 400));
                            kMonthCtrl.jumpToItem((km - 1).clamp(0, 12));
                            kDayCtrl.jumpToItem((kd - 1).clamp(0, 29));
                          });
                        } else {
                          // Switch to Gregorian
                          final g = KemeticMath.toGregorian(ky, km, kd);
                          gy = g.year;
                          gm = g.month;
                          gd = g.day;
                          final gMax = _gregDayMax(gy, gm);
                          if (gd > gMax) gd = gMax;
                          localKemetic = false;

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            gYearCtrl.jumpToItem((gy - gYearStart).clamp(0, 39));
                            gMonthCtrl.jumpToItem((gm - 1).clamp(0, 11));
                            gDayCtrl.jumpToItem((gd - 1).clamp(0, 30));
                          });
                        }
                      });
                    },
                  ),

                  const SizedBox(height: 10),

                  // Title
                  GlossyText(
                    text: localKemetic ? 'Start date (Kemetic)' : 'Start date (Gregorian)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    gradient: localKemetic ? goldGloss : blueGloss,
                  ),
                  const SizedBox(height: 8),

                  // Wheels
                  localKemetic ? _kemWheel() : _gregWheel(),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: silver, width: 1.25),
                          ),
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () {
                            final result = localKemetic
                                ? KemeticMath.toGregorian(ky, km, kd)
                                : DateTime(gy, gm, gd);
                            Navigator.pop(sheetCtx, result);
                          },
                          child: const Text('Done'),
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
}

