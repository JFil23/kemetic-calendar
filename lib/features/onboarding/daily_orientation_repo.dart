import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DailyOrientationEntry {
  const DailyOrientationEntry({
    required this.userId,
    required this.localDate,
    this.kemeticDayKey,
    this.entryState,
    this.chosenReturn,
    this.source,
    this.setAt,
    this.landingStatus,
    this.landedAt,
    this.badgeLabel,
    this.status,
  });

  final String userId;
  final DateTime localDate;
  final String? kemeticDayKey;
  final String? entryState;
  final String? chosenReturn;
  final String? source;
  final DateTime? setAt;
  final String? landingStatus;
  final DateTime? landedAt;
  final String? badgeLabel;
  final String? status;

  static DailyOrientationEntry? fromJson(Map<String, dynamic>? map) {
    if (map == null) return null;
    final rawUserId = map['user_id']?.toString().trim();
    final rawDate = map['local_date']?.toString().trim();
    if (rawUserId == null ||
        rawUserId.isEmpty ||
        rawDate == null ||
        rawDate.isEmpty) {
      return null;
    }
    return DailyOrientationEntry(
      userId: rawUserId,
      localDate: DateTime.tryParse(rawDate) ?? DateTime.now(),
      kemeticDayKey: _trimOrNull(map['kemetic_day_key']),
      entryState: _trimOrNull(map['entry_state']),
      chosenReturn: _trimOrNull(map['chosen_return']),
      source: _trimOrNull(map['source']),
      setAt: DateTime.tryParse(map['set_at']?.toString() ?? ''),
      landingStatus: _trimOrNull(map['landing_status']),
      landedAt: DateTime.tryParse(map['landed_at']?.toString() ?? ''),
      badgeLabel: _trimOrNull(map['badge_label']),
      status: _trimOrNull(map['status']),
    );
  }
}

class EveningThresholdDecisionEntry {
  const EveningThresholdDecisionEntry({
    required this.userId,
    required this.decisionDate,
    required this.decision,
    this.newCarryText,
  });

  final String userId;
  final DateTime decisionDate;
  final String decision;
  final String? newCarryText;
}

class DailyOrientationRepo {
  DailyOrientationRepo(this._client);

  final SupabaseClient _client;

  String _localKey({required String userId, required DateTime localDate}) {
    return 'daily_orientation:$userId:${_dateOnlyIso(localDate)}';
  }

  Future<void> start({
    required String userId,
    required DateTime localDate,
    required String kemeticDayKey,
    required String entryState,
    String? chosenReturn,
  }) async {
    final payload = <String, dynamic>{
      'user_id': userId,
      'local_date': _dateOnlyIso(localDate),
      'kemetic_day_key': kemeticDayKey,
      'entry_state': entryState,
      if (chosenReturn != null && chosenReturn.trim().isNotEmpty)
        'chosen_return': chosenReturn.trim(),
      'status': 'started',
    };
    await _writeLocal(userId: userId, localDate: localDate, patch: payload);
    await _upsertRemote(payload);
  }

  Future<DailyOrientationEntry?> load({
    required String userId,
    required DateTime localDate,
  }) async {
    final localEntry = await _readLocal(userId: userId, localDate: localDate);
    try {
      final row = await _client
          .from('daily_orientation')
          .select()
          .eq('user_id', userId)
          .eq('local_date', _dateOnlyIso(localDate))
          .maybeSingle();
      final remoteEntry = DailyOrientationEntry.fromJson(
        row == null ? null : Map<String, dynamic>.from(row),
      );
      if (remoteEntry != null) {
        await _writeLocal(
          userId: userId,
          localDate: localDate,
          patch: Map<String, dynamic>.from(row!),
        );
        return remoteEntry;
      }
    } catch (e) {
      debugPrint('[DailyOrientationRepo] remote load failed: $e');
    }
    return localEntry;
  }

  Future<void> setCarry({
    required String userId,
    required DateTime localDate,
    required String chosenReturn,
    required String source,
    String? kemeticDayKey,
  }) async {
    final trimmed = chosenReturn.trim();
    if (trimmed.isEmpty) return;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'user_id': userId,
      'local_date': _dateOnlyIso(localDate),
      if (kemeticDayKey != null && kemeticDayKey.trim().isNotEmpty)
        'kemetic_day_key': kemeticDayKey.trim(),
      'chosen_return': trimmed,
      'source': source,
      'set_at': nowIso,
      'landing_status': null,
      'landed_at': null,
      'status': 'started',
    };
    await _writeLocal(userId: userId, localDate: localDate, patch: payload);
    await _upsertRemote(payload);
  }

  Future<void> recordLanding({
    required String userId,
    required DateTime localDate,
    required String landingStatus,
  }) async {
    final normalized = _normalizeLandingStatus(landingStatus);
    if (normalized == null) return;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'user_id': userId,
      'local_date': _dateOnlyIso(localDate),
      'landing_status': normalized,
      'landed_at': nowIso,
      'evening_reflection_status': 'completed',
      'status': 'completed',
      'completed_at': nowIso,
    };
    await _writeLocal(userId: userId, localDate: localDate, patch: payload);
    await _upsertRemote(payload);
  }

  Future<void> carryForward({
    required String userId,
    required DateTime localDate,
    required DateTime previousLocalDate,
    required String chosenReturn,
  }) async {
    await setCarry(
      userId: userId,
      localDate: localDate,
      chosenReturn: chosenReturn,
      source: 'carried_from_yesterday',
    );
    await recordEveningThresholdDecision(
      userId: userId,
      decisionDate: localDate,
      decision: 'carried',
    );
    await _writeLocal(
      userId: userId,
      localDate: previousLocalDate,
      patch: const <String, dynamic>{'carryover_choice': 'carry_it_forward'},
    );
  }

  Future<void> releaseWithNewCarry({
    required String userId,
    required DateTime localDate,
    required String chosenReturn,
  }) async {
    await setCarry(
      userId: userId,
      localDate: localDate,
      chosenReturn: chosenReturn,
      source: 'newly_set',
    );
    await recordEveningThresholdDecision(
      userId: userId,
      decisionDate: localDate,
      decision: 'released',
      newCarryText: chosenReturn,
    );
  }

  Future<void> recordEveningThresholdDecision({
    required String userId,
    required DateTime decisionDate,
    required String decision,
    String? newCarryText,
  }) async {
    final normalized = decision.trim().toLowerCase();
    if (normalized != 'carried' && normalized != 'released') return;
    final payload = <String, dynamic>{
      'user_id': userId,
      'decision_date': _dateOnlyIso(decisionDate),
      'decision': normalized,
      if (newCarryText != null && newCarryText.trim().isNotEmpty)
        'new_carry_text': newCarryText.trim(),
    };
    await _writeDecisionLocal(payload);
    try {
      await _client
          .from('evening_threshold_decisions')
          .upsert(payload, onConflict: 'user_id,decision_date');
    } catch (e) {
      debugPrint('[DailyOrientationRepo] decision upsert failed: $e');
    }
  }

  Future<void> complete({
    required String userId,
    required DateTime localDate,
    String? chosenReturn,
    String? badgeLabel,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'user_id': userId,
      'local_date': _dateOnlyIso(localDate),
      if (chosenReturn != null && chosenReturn.trim().isNotEmpty)
        'chosen_return': chosenReturn.trim(),
      if (badgeLabel != null && badgeLabel.trim().isNotEmpty)
        'badge_label': badgeLabel.trim(),
      'status': 'completed',
      'completed_at': nowIso,
    };
    await _writeLocal(userId: userId, localDate: localDate, patch: payload);
    await _upsertRemote(payload);
  }

  Future<void> skip({
    required String userId,
    required DateTime localDate,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'user_id': userId,
      'local_date': _dateOnlyIso(localDate),
      'status': 'skipped',
      'completed_at': nowIso,
    };
    await _writeLocal(userId: userId, localDate: localDate, patch: payload);
    await _upsertRemote(payload);
  }

  Future<void> _writeLocal({
    required String userId,
    required DateTime localDate,
    required Map<String, dynamic> patch,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _localKey(userId: userId, localDate: localDate);
      final existingRaw = prefs.getString(key);
      final existing = existingRaw == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(existingRaw) as Map);
      await prefs.setString(
        key,
        jsonEncode(<String, dynamic>{...existing, ...patch}),
      );
    } catch (e) {
      debugPrint('[DailyOrientationRepo] local write failed: $e');
    }
  }

  Future<DailyOrientationEntry?> _readLocal({
    required String userId,
    required DateTime localDate,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(
        _localKey(userId: userId, localDate: localDate),
      );
      if (raw == null || raw.trim().isEmpty) return null;
      return DailyOrientationEntry.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (e) {
      debugPrint('[DailyOrientationRepo] local read failed: $e');
      return null;
    }
  }

  Future<void> _writeDecisionLocal(Map<String, dynamic> payload) async {
    try {
      final userId = payload['user_id']?.toString().trim();
      final decisionDate = payload['decision_date']?.toString().trim();
      if (userId == null ||
          userId.isEmpty ||
          decisionDate == null ||
          decisionDate.isEmpty) {
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'evening_threshold_decision:$userId:$decisionDate',
        jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('[DailyOrientationRepo] local decision write failed: $e');
    }
  }

  Future<void> _upsertRemote(Map<String, dynamic> payload) async {
    try {
      await _client
          .from('daily_orientation')
          .upsert(payload, onConflict: 'user_id,local_date');
    } catch (e) {
      debugPrint('[DailyOrientationRepo] remote upsert failed: $e');
    }
  }

  static String _dateOnlyIso(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    return [
      local.year.toString().padLeft(4, '0'),
      local.month.toString().padLeft(2, '0'),
      local.day.toString().padLeft(2, '0'),
    ].join('-');
  }

  static String? _normalizeLandingStatus(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'held' || value == 'slipped') return value;
    if (value == 'working' || value == 'working_on_it') {
      return 'working_on_it';
    }
    return null;
  }
}

String? _trimOrNull(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}
