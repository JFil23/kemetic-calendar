import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/day_key.dart';
import '../widgets/kemetic_day_info.dart';
import '../widgets/kemetic_date_picker.dart' show KemeticMath;

class DecanReflectionScheduler {
  static const Duration _refreshThrottle = Duration(hours: 6);

  final SupabaseClient _client;
  final DateTime Function() _now;
  final VoidCallback? onMaatGuidanceEnsured;
  DateTime? _lastSuccessfulEnsureAt;
  Future<void>? _ensureInFlight;
  String? _ensureAccountId;
  int _ensureGeneration = 0;

  DecanReflectionScheduler(
    this._client, {
    this.onMaatGuidanceEnsured,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  String _detectTimeZone() {
    final zoneName = _now().timeZoneName.toUpperCase();
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

    final offsetHours = _now().timeZoneOffset.inHours;
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

    final decanDay = KemeticDayData.getFlowForDay(dayKey);

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
        body: {'timezone': timezone, 'day_card': _dayCardPayloadFor(_now())},
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
    final accountId = _client.auth.currentUser?.id;
    if (accountId != _ensureAccountId) {
      _ensureAccountId = accountId;
      _ensureGeneration++;
      _lastSuccessfulEnsureAt = null;
      _ensureInFlight = null;
    }
    if (accountId == null) return Future.value();
    final inFlight = _ensureInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final lastSuccessfulEnsureAt = _lastSuccessfulEnsureAt;
    if (!force &&
        lastSuccessfulEnsureAt != null &&
        _now().difference(lastSuccessfulEnsureAt) < _refreshThrottle) {
      return Future.value();
    }

    late final Future<void> future;
    future = _runEnsureCurrentAndNextScheduled(accountId, _ensureGeneration)
        .whenComplete(() {
          if (identical(_ensureInFlight, future)) {
            _ensureInFlight = null;
          }
        });
    _ensureInFlight = future;
    return future;
  }

  Future<void> _runEnsureCurrentAndNextScheduled(
    String accountId,
    int generation,
  ) async {
    final now = _now();
    final guidanceEnsured = await _ensureUserGuidance();
    if (_client.auth.currentUser?.id != accountId ||
        _ensureAccountId != accountId ||
        generation != _ensureGeneration) {
      return;
    }
    if (guidanceEnsured) {
      onMaatGuidanceEnsured?.call();
    }

    if (guidanceEnsured) {
      _lastSuccessfulEnsureAt = now;
    }
  }
}
