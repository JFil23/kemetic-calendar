import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/calendar/decan_metadata.dart';
import '../features/calendar/kemetic_month_metadata.dart';
import '../widgets/kemetic_date_picker.dart' show KemeticMath;

class DecanWindow {
  final DateTime start;
  final DateTime end;
  final String decanName;
  final String? decanTheme;
  final String? decanContextKey;

  const DecanWindow({
    required this.start,
    required this.end,
    required this.decanName,
    required this.decanTheme,
    required this.decanContextKey,
  });
}

class DecanReflectionScheduler {
  final SupabaseClient _client;
  DecanReflectionScheduler(this._client);

  DecanWindow _windowFor(DateTime date) {
    final kem = KemeticMath.fromGregorian(date);
    final decanStartDay = ((kem.kDay - 1) ~/ 10) * 10 + 1;
    final decanIndex = ((decanStartDay - 1) ~/ 10) + 1;
    final maxDay = (kem.kMonth == 13)
        ? (KemeticMath.isLeapKemeticYear(kem.kYear) ? 6 : 5)
        : 30;
    final decanEndDay = (decanStartDay + 9) > maxDay ? maxDay : decanStartDay + 9;
    final start = KemeticMath.toGregorian(kem.kYear, kem.kMonth, decanStartDay);
    final end = KemeticMath.toGregorian(kem.kYear, kem.kMonth, decanEndDay);
    final hasCanonicalContext = kem.kMonth >= 1 && kem.kMonth <= 12;
    final monthLabel = hasCanonicalContext
        ? getMonthById(kem.kMonth).displayShort
        : 'Days Upon the Year';
    final decanTheme = hasCanonicalContext
        ? DecanMetadata.decanNameFor(
            kMonth: kem.kMonth,
            kDay: decanEndDay,
            expanded: true,
          )
        : null;
    return DecanWindow(
      start: start,
      end: end,
      decanName: decanTheme == null ? monthLabel : '$monthLabel — $decanTheme',
      decanTheme: decanTheme,
      decanContextKey: hasCanonicalContext ? '${kem.kMonth}-$decanIndex' : null,
    );
  }

  Future<void> _scheduleWindow(DecanWindow window) async {
    // Day 10 of the decan at 20:30 UTC to satisfy backend validation (day 10 check is UTC-based).
    final day10 = window.start.add(const Duration(days: 9));
    final sendAt = DateTime.utc(day10.year, day10.month, day10.day, 20, 30);
    try {
      await _client.functions.invoke(
        'schedule_decan_reflection',
        body: {
          'decan_start': window.start.toIso8601String().split('T').first,
          'decan_end': window.end.toIso8601String().split('T').first,
          'send_at': sendAt.toIso8601String(),
          'decan_name': window.decanName,
          'decan_theme': window.decanTheme,
          'decan_context_key': window.decanContextKey,
        },
      );
    } catch (e) {
      debugPrint('[DecanReflectionScheduler] schedule error: $e');
    }
  }

  Future<void> ensureCurrentAndNextScheduled() async {
    final now = DateTime.now();
    final current = _windowFor(now);
    await _scheduleWindow(current);

    final nextStart = current.end.add(const Duration(days: 1));
    final next = _windowFor(nextStart);
    if (next.start != current.start || next.end != current.end) {
      await _scheduleWindow(next);
    }
  }
}
