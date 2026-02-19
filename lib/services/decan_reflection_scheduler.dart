import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/kemetic_date_picker.dart' show KemeticMath;

class DecanWindow {
  final DateTime start;
  final DateTime end;
  const DecanWindow(this.start, this.end);
}

class DecanReflectionScheduler {
  final SupabaseClient _client;
  DecanReflectionScheduler(this._client);

  DecanWindow _windowFor(DateTime date) {
    final kem = KemeticMath.fromGregorian(date);
    final decanStartDay = ((kem.kDay - 1) ~/ 10) * 10 + 1;
    final maxDay = (kem.kMonth == 13)
        ? (KemeticMath.isLeapKemeticYear(kem.kYear) ? 6 : 5)
        : 30;
    final decanEndDay = (decanStartDay + 9) > maxDay ? maxDay : decanStartDay + 9;
    final start = KemeticMath.toGregorian(kem.kYear, kem.kMonth, decanStartDay);
    final end = KemeticMath.toGregorian(kem.kYear, kem.kMonth, decanEndDay);
    return DecanWindow(start, end);
  }

  Future<void> _scheduleWindow(DecanWindow window) async {
    final sendAt = DateTime(
      window.start.year,
      window.start.month,
      window.start.day + 9,
      20,
      30,
    );
    try {
      await _client.functions.invoke(
        'schedule_decan_reflection',
        body: {
          'decan_start': window.start.toIso8601String().split('T').first,
          'decan_end': window.end.toIso8601String().split('T').first,
          'send_at': sendAt.toIso8601String(),
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
