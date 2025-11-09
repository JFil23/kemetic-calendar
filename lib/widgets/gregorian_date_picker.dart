import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile/shared/glossy_text.dart';

/* ═══════════════════════ STYLING CONSTANTS ═══════════════════════ */
// Colors and gradients are now imported from shared/glossy_text.dart

/* ═══════════════════════ GREGORIAN MONTH NAMES ═══════════════════════ */

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

/* ═══════════════════════ GREGORIAN DATE PICKER ═══════════════════════ */

Future<DateTime?> showGregorianDatePicker({
  required BuildContext context,
  DateTime? initialDate,
}) async {
  final now = DateTime.now();
  DateTime seed = DateUtils.dateOnly(initialDate ?? now);

  int y = seed.year;
  int m = seed.month;
  int d = seed.day;

  final int yearStart = now.year - 200;
  final yearCtrl =
      FixedExtentScrollController(initialItem: (y - yearStart).clamp(0, 400));
  final monthCtrl = FixedExtentScrollController(initialItem: (m - 1).clamp(0, 11));
  final dayCtrl = FixedExtentScrollController(initialItem: (d - 1).clamp(0, 30));

  int _daysInGregorianMonth(int year, int month) {
    final leap = (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0));
    const days = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return (month == 2 && leap) ? 29 : days[month];
  }

  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.black,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) {
      int localY = y, localM = m, localD = d;

      int dayMax() => _daysInGregorianMonth(localY, localM);

      return StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final max = dayMax();
          if (localD > max) localD = max;

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
                const GlossyText(
                  text: 'Pick Gregorian date',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  gradient: blueGloss,
                ),
                const SizedBox(height: 8),

                // 3-Wheel Picker (Month | Day | Year)
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
                              localM = (i % 12) + 1;
                              final mx = dayMax();
                              if (localD > mx && dayCtrl.hasClients) {
                                localD = mx;
                                WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => dayCtrl.jumpToItem(localD - 1),
                                );
                              }
                            });
                          },
                          children: List<Widget>.generate(12, (i) {
                            final label = _gregMonthNames[i + 1];
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
                              final mx = dayMax();
                              localD = (i % mx) + 1;
                            });
                          },
                          children: List<Widget>.generate(dayMax(), (i) {
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
                      
                      // Year wheel
                      Expanded(
                        flex: 4,
                        child: CupertinoPicker(
                          scrollController: yearCtrl,
                          itemExtent: 32,
                          looping: false,
                          backgroundColor: const Color(0x00121214),
                          onSelectedItemChanged: (i) {
                            setSheetState(() {
                              localY = yearStart + i;
                              final mx = dayMax();
                              if (localD > mx && dayCtrl.hasClients) {
                                localD = mx;
                                WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => dayCtrl.jumpToItem(localD - 1),
                                );
                              }
                            });
                          },
                          children: List<Widget>.generate(401, (i) {
                            final yy = yearStart + i;
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
                ),

                const SizedBox(height: 12),
                
                // Cancel / Done buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: silver),
                        ),
                        onPressed: () => Navigator.pop(sheetCtx, null),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blue,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () {
                          final out =
                              DateUtils.dateOnly(DateTime(localY, localM, localD));
                          Navigator.pop(sheetCtx, out);
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


