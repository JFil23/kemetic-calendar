import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/day_key.dart';
import '../features/calendar/decan_metadata.dart';
import '../features/calendar/kemetic_month_metadata.dart';
import '../widgets/kemetic_day_info.dart';
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
  static const Duration _refreshThrottle = Duration(hours: 6);

  final SupabaseClient _client;
  DateTime? _lastSuccessfulEnsureAt;
  Future<void>? _ensureInFlight;

  DecanReflectionScheduler(this._client);

  String _detectTimeZone() {
    final zoneName = DateTime.now().timeZoneName.toUpperCase();
    const zoneNameMap = {
      'HST': 'Pacific/Honolulu',
      'AKST': 'America/Anchorage',
      'AKDT': 'America/Anchorage',
      'PST': 'America/Los_Angeles',
      'PDT': 'America/Los_Angeles',
      'MST': 'America/Denver',
      'MDT': 'America/Denver',
      'CST': 'America/Chicago',
      'CDT': 'America/Chicago',
      'EST': 'America/New_York',
      'EDT': 'America/New_York',
      'GMT': 'Europe/London',
      'BST': 'Europe/London',
      'CET': 'Europe/Paris',
      'CEST': 'Europe/Paris',
      'SGT': 'Asia/Singapore',
      'JST': 'Asia/Tokyo',
      'AEST': 'Australia/Sydney',
      'AEDT': 'Australia/Sydney',
    };
    final mappedByName = zoneNameMap[zoneName];
    if (mappedByName != null) {
      return mappedByName;
    }
    if (zoneName.contains('PACIFIC')) return 'America/Los_Angeles';
    if (zoneName.contains('MOUNTAIN')) return 'America/Denver';
    if (zoneName.contains('CENTRAL')) return 'America/Chicago';
    if (zoneName.contains('EASTERN')) return 'America/New_York';

    final offsetHours = DateTime.now().timeZoneOffset.inHours;
    const timezoneMap = {
      -10: 'Pacific/Honolulu',
      -9: 'America/Anchorage',
      -8: 'America/Los_Angeles',
      -7: 'America/Los_Angeles',
      -6: 'America/Chicago',
      -5: 'America/New_York',
      -4: 'America/New_York',
      0: 'Europe/London',
      1: 'Europe/Paris',
      8: 'Asia/Singapore',
      9: 'Asia/Tokyo',
      10: 'Australia/Sydney',
    };
    return timezoneMap[offsetHours] ?? 'America/Los_Angeles';
  }

  DecanWindow _windowFor(DateTime date) {
    final kem = KemeticMath.fromGregorian(date);
    final decanStartDay = ((kem.kDay - 1) ~/ 10) * 10 + 1;
    final decanIndex = ((decanStartDay - 1) ~/ 10) + 1;
    final maxDay = (kem.kMonth == 13)
        ? (KemeticMath.isLeapKemeticYear(kem.kYear) ? 6 : 5)
        : 30;
    final decanEndDay = (decanStartDay + 9) > maxDay
        ? maxDay
        : decanStartDay + 9;
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
    if (window.decanContextKey == null) {
      return;
    }
    final response = await _client.functions.invoke(
      'schedule_decan_reflection',
      body: {
        'decan_start': window.start.toIso8601String().split('T').first,
        'decan_end': window.end.toIso8601String().split('T').first,
        'decan_name': window.decanName,
        'decan_theme': window.decanTheme,
        'decan_context_key': window.decanContextKey,
        'timezone': _detectTimeZone(),
      },
    );

    if (response.status >= 200 && response.status < 300) {
      return;
    }

    final data = response.data;
    final detail = data is Map && data['error'] != null
        ? data['error'].toString()
        : data?.toString();
    throw StateError(
      'schedule_decan_reflection failed for ${window.decanContextKey} '
      '(status ${response.status})'
      '${detail == null || detail.isEmpty ? '' : ': $detail'}',
    );
  }

  Map<String, dynamic>? _dayCardPayloadFor(DateTime date) {
    final kemetic = KemeticMath.fromGregorian(date);
    if (kemetic.kMonth < 1 || kemetic.kMonth > 13) return null;
    final dayKey = kemeticDayKey(kemetic.kMonth, kemetic.kDay);
    final info = KemeticDayData.getInfoForDay(dayKey);
    if (info == null) return null;

    final dayInDecan = kemetic.kMonth == 13
        ? kemetic.kDay
        : ((kemetic.kDay - 1) % 10) + 1;
    DecanDayInfo? decanDay;
    for (final row in info.decanFlow) {
      if (row.day == dayInDecan) {
        decanDay = row;
        break;
      }
    }

    final local = DateTime(date.year, date.month, date.day);
    final yyyy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return <String, dynamic>{
      'date': '$yyyy-$mm-$dd',
      'maatPrinciple': info.maatPrinciple,
      'cosmicContext': info.cosmicContext,
      if (decanDay != null) ...{
        'decanDayTheme': decanDay.theme,
        'decanDayAction': decanDay.action,
        'decanDayReflection': decanDay.reflection,
      },
    };
  }

  Future<void> _ensureMaatGuidance(DecanWindow window) async {
    if (window.decanContextKey == null) return;
    final timezone = _detectTimeZone();
    try {
      await _client.functions.invoke(
        'cron_maat_decan_opening',
        body: {
          'decan_start': window.start.toIso8601String().split('T').first,
          'decan_end': window.end.toIso8601String().split('T').first,
          'decan_name': window.decanName,
          'decan_theme': window.decanTheme,
          'decan_context_key': window.decanContextKey,
          'timezone': timezone,
          'day_card': _dayCardPayloadFor(DateTime.now()),
        },
      );
      await _client.functions.invoke(
        'evaluate_maat_guidance',
        body: <String, dynamic>{'timezone': timezone},
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[DecanReflectionScheduler] guidance skipped: $error');
      }
    }
  }

  Future<void> ensureCurrentAndNextScheduled({bool force = false}) {
    final inFlight = _ensureInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final lastSuccessfulEnsureAt = _lastSuccessfulEnsureAt;
    if (!force &&
        lastSuccessfulEnsureAt != null &&
        DateTime.now().difference(lastSuccessfulEnsureAt) < _refreshThrottle) {
      return Future.value();
    }

    final future = _runEnsureCurrentAndNextScheduled();
    _ensureInFlight = future.whenComplete(() {
      if (identical(_ensureInFlight, future)) {
        _ensureInFlight = null;
      }
    });
    return _ensureInFlight!;
  }

  Future<void> _runEnsureCurrentAndNextScheduled() async {
    final now = DateTime.now();
    final current = _windowFor(now);
    await _scheduleWindow(current);
    await _ensureMaatGuidance(current);

    final nextStart = current.end.add(const Duration(days: 1));
    final next = _windowFor(nextStart);
    if (next.start != current.start || next.end != current.end) {
      await _scheduleWindow(next);
    }

    _lastSuccessfulEnsureAt = now;
  }
}
