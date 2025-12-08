import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/user_events_repo.dart';

class _Holiday {
  final String name;
  final DateTime date;

  const _Holiday(this.name, this.date);
}

class UsHolidaySeeder {
  static const String clientIdPrefix = 'holiday:us:';
  static const int _defaultStartHour = 9;
  static const int _defaultStartMinute = 0;

  static String _slug(String input) {
    final lower = input.toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return cleaned.replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  }

  static String _clientEventId(_Holiday h) {
    final isoDay = h.date.toIso8601String().split('T').first;
    return '$clientIdPrefix$isoDay:${_slug(h.name)}';
  }

  static DateTime _observed(DateTime date) {
    if (date.weekday == DateTime.saturday) return date.subtract(const Duration(days: 1));
    if (date.weekday == DateTime.sunday) return date.add(const Duration(days: 1));
    return date;
  }

  static DateTime _nthWeekdayOfMonth(int year, int month, int weekday, int n) {
    var date = DateTime(year, month, 1);
    int count = 0;
    while (date.month == month) {
      if (date.weekday == weekday) {
        count++;
        if (count == n) return date;
      }
      date = date.add(const Duration(days: 1));
    }
    return DateTime(year, month, 1); // fallback (should not hit)
  }

  static DateTime _lastWeekdayOfMonth(int year, int month, int weekday) {
    var date = DateTime(year, month + 1, 0);
    while (date.weekday != weekday) {
      date = date.subtract(const Duration(days: 1));
    }
    return date;
  }

  static List<_Holiday> _holidaysForYear(int year) {
    return [
      _Holiday("New Year's Day", _observed(DateTime(year, 1, 1))),
      _Holiday('Martin Luther King Jr. Day', _nthWeekdayOfMonth(year, 1, DateTime.monday, 3)),
      _Holiday("Presidents' Day", _nthWeekdayOfMonth(year, 2, DateTime.monday, 3)),
      _Holiday('Memorial Day', _lastWeekdayOfMonth(year, 5, DateTime.monday)),
      _Holiday('Juneteenth', _observed(DateTime(year, 6, 19))),
      _Holiday('Independence Day', _observed(DateTime(year, 7, 4))),
      _Holiday('Labor Day', _nthWeekdayOfMonth(year, 9, DateTime.monday, 1)),
      _Holiday("Indigenous Peoples' Day", _nthWeekdayOfMonth(year, 10, DateTime.monday, 2)),
      _Holiday('Veterans Day', _observed(DateTime(year, 11, 11))),
      _Holiday('Thanksgiving Day', _nthWeekdayOfMonth(year, 11, DateTime.thursday, 4)),
      _Holiday('Christmas Day', _observed(DateTime(year, 12, 25))),
    ];
  }

  /// Seed holiday events for the given number of years starting at [startYear].
  /// Returns how many events were upserted (including overwrites).
  static Future<int> seed({
    int? startYear,
    int years = 1,
    UserEventsRepo? repo,
  }) async {
    final r = repo ?? UserEventsRepo(Supabase.instance.client);
    final baseYear = startYear ?? DateTime.now().year;
    int inserted = 0;

    for (int i = 0; i < years; i++) {
      final year = baseYear + i;
      for (final h in _holidaysForYear(year)) {
        final clientEventId = _clientEventId(h);
        final startLocal = DateTime(
          h.date.year,
          h.date.month,
          h.date.day,
          _defaultStartHour,
          _defaultStartMinute,
        );
        await r.upsertByClientId(
          clientEventId: clientEventId,
          title: h.name,
          startsAtUtc: startLocal.toUtc(),
          detail: 'US holiday (auto-added from Settings)',
          allDay: true,
        );
        inserted++;
      }
    }

    return inserted;
  }

  /// Remove all auto-seeded holiday events for the current user.
  static Future<void> clear({UserEventsRepo? repo}) async {
    final r = repo ?? UserEventsRepo(Supabase.instance.client);
    await r.deleteByClientIdPrefix(clientIdPrefix);
  }
}
