import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/day_key.dart';
import '../widgets/kemetic_day_info.dart';
import '../widgets/kemetic_date_picker.dart' show KemeticMath;

class DecanReflectionScheduler {
  static const Duration _refreshThrottle = Duration(hours: 6);

  final SupabaseClient _client;
  final VoidCallback? onMaatGuidanceEnsured;
  DateTime? _lastSuccessfulEnsureAt;
  Future<void>? _ensureInFlight;

  DecanReflectionScheduler(this._client, {this.onMaatGuidanceEnsured});

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

  void _throwIfFunctionFailed(String functionName, FunctionResponse response) {
    if (response.status >= 200 && response.status < 300) return;
    final data = response.data;
    final detail = data is Map && data['error'] != null
        ? data['error'].toString()
        : data?.toString();
    throw StateError(
      '$functionName failed for Ma’at guidance '
      '(status ${response.status})'
      '${detail == null || detail.isEmpty ? '' : ': $detail'}',
    );
  }

  Future<bool> _ensureUserGuidance() async {
    final timezone = _detectTimeZone();
    try {
      final response = await _client.functions.invoke(
        'ensure_user_guidance',
        body: {
          'timezone': timezone,
          'day_card': _dayCardPayloadFor(DateTime.now()),
        },
      );
      _throwIfFunctionFailed('ensure_user_guidance', response);
      return true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[DecanReflectionScheduler] guidance skipped: $error');
      }
      return false;
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
    final guidanceEnsured = await _ensureUserGuidance();
    if (guidanceEnsured) {
      onMaatGuidanceEnsured?.call();
    }

    if (guidanceEnsured) {
      _lastSuccessfulEnsureAt = now;
    }
  }
}
