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

  DailyOrientationEntry copyWith({
    String? kemeticDayKey,
    String? entryState,
    String? chosenReturn,
    String? source,
    DateTime? setAt,
    String? landingStatus,
    DateTime? landedAt,
    String? badgeLabel,
    String? status,
  }) {
    return DailyOrientationEntry(
      userId: userId,
      localDate: localDate,
      kemeticDayKey: kemeticDayKey ?? this.kemeticDayKey,
      entryState: entryState ?? this.entryState,
      chosenReturn: chosenReturn ?? this.chosenReturn,
      source: source ?? this.source,
      setAt: setAt ?? this.setAt,
      landingStatus: landingStatus ?? this.landingStatus,
      landedAt: landedAt ?? this.landedAt,
      badgeLabel: badgeLabel ?? this.badgeLabel,
      status: status ?? this.status,
    );
  }

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

class DailyOrientationPersistenceException implements Exception {
  const DailyOrientationPersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause == null) return message;
    return '$message: $cause';
  }
}

class DailyOrientationCarryResolver {
  const DailyOrientationCarryResolver._();

  static DailyOrientationEntry? resolveEffectiveCarry({
    required String userId,
    required DateTime localDate,
    DailyOrientationEntry? exactEntry,
    DailyOrientationEntry? latestPriorCarry,
  }) {
    final targetDate = _dateOnly(localDate);
    final exact = _isEntryForUserOnDate(exactEntry, userId, targetDate)
        ? exactEntry
        : null;
    if (_hasText(exact?.chosenReturn)) return exact;

    final carry =
        _isEntryForUserOnOrBeforeDate(latestPriorCarry, userId, targetDate)
        ? latestPriorCarry
        : null;
    if (!_hasText(carry?.chosenReturn)) return exact;

    final base =
        exact ??
        DailyOrientationEntry(
          userId: userId,
          localDate: targetDate,
          status: 'started',
        );
    return base.copyWith(
      chosenReturn: carry!.chosenReturn,
      source: base.source ?? carry.source ?? 'carried_until_changed',
      setAt: base.setAt ?? carry.setAt,
    );
  }

  static bool _isEntryForUserOnDate(
    DailyOrientationEntry? entry,
    String userId,
    DateTime localDate,
  ) {
    if (entry == null || entry.userId != userId) return false;
    return _dateOnly(entry.localDate) == localDate;
  }

  static bool _isEntryForUserOnOrBeforeDate(
    DailyOrientationEntry? entry,
    String userId,
    DateTime localDate,
  ) {
    if (entry == null || entry.userId != userId) return false;
    return !_dateOnly(entry.localDate).isAfter(localDate);
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;
}

class DailyOrientationRepo {
  DailyOrientationRepo(this._client);

  final SupabaseClient _client;

  String _localKey({required String userId, required DateTime localDate}) {
    return 'daily_orientation:$userId:${_dateOnlyIso(localDate)}';
  }

  String _currentCarryKey({required String userId}) {
    return 'daily_orientation_current_carry:$userId';
  }

  Future<void> start({
    required String userId,
    required DateTime localDate,
    required String kemeticDayKey,
    required String entryState,
    String? chosenReturn,
  }) async {
    final trimmedReturn = chosenReturn?.trim();
    final hasChosenReturn = trimmedReturn != null && trimmedReturn.isNotEmpty;
    final setAtIso = hasChosenReturn
        ? DateTime.now().toUtc().toIso8601String()
        : null;
    final payload = <String, dynamic>{
      'user_id': userId,
      'local_date': _dateOnlyIso(localDate),
      'kemetic_day_key': kemeticDayKey,
      'entry_state': entryState,
      if (hasChosenReturn) 'chosen_return': trimmedReturn,
      if (hasChosenReturn) 'source': 'daily_orientation_start',
      if (hasChosenReturn) 'set_at': setAtIso,
      'status': 'started',
    };
    await _upsertRemote(payload);
    await _writeLocal(userId: userId, localDate: localDate, patch: payload);
    if (hasChosenReturn) {
      await _writeCurrentCarryLocal(
        userId: userId,
        localDate: localDate,
        chosenReturn: trimmedReturn,
        source: 'daily_orientation_start',
        setAtIso: setAtIso,
      );
    }
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

  Future<DailyOrientationEntry?> loadEffectiveCarry({
    required String userId,
    required DateTime localDate,
  }) async {
    final exactEntry = await load(userId: userId, localDate: localDate);
    if (_hasText(exactEntry?.chosenReturn)) return exactEntry;

    final carry = await _loadMostRecentCarry(
      userId: userId,
      localDate: localDate,
    );
    if (!_hasText(carry?.chosenReturn)) return exactEntry;

    return DailyOrientationCarryResolver.resolveEffectiveCarry(
      userId: userId,
      localDate: localDate,
      exactEntry: exactEntry,
      latestPriorCarry: carry,
    );
  }

  Future<void> setCarry({
    required String userId,
    required DateTime localDate,
    required String chosenReturn,
    required String source,
    String? kemeticDayKey,
  }) async {
    final payload = _setCarryPayload(
      userId: userId,
      localDate: localDate,
      chosenReturn: chosenReturn,
      source: source,
      kemeticDayKey: kemeticDayKey,
    );
    if (payload == null) return;
    await _upsertRemote(payload);
    await _writeCarryLocalFromPayload(payload);
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
    await _upsertRemote(payload);
    await _writeLocal(userId: userId, localDate: localDate, patch: payload);
  }

  Future<void> carryForward({
    required String userId,
    required DateTime localDate,
    required DateTime previousLocalDate,
    required String chosenReturn,
  }) async {
    final carryPayload = _setCarryPayload(
      userId: userId,
      localDate: localDate,
      chosenReturn: chosenReturn,
      source: 'carried_from_yesterday',
    );
    if (carryPayload == null) return;
    final previousPayload = <String, dynamic>{
      'user_id': userId,
      'local_date': _dateOnlyIso(previousLocalDate),
      'carryover_choice': 'carry_it_forward',
    };
    final decisionPayload = _decisionPayload(
      userId: userId,
      decisionDate: localDate,
      decision: 'carried',
    );
    if (decisionPayload == null) return;

    await _upsertRemote(carryPayload);
    await _upsertRemote(previousPayload);
    await _upsertDecisionRemote(decisionPayload);

    await _writeCarryLocalFromPayload(carryPayload);
    await _writeLocal(
      userId: userId,
      localDate: previousLocalDate,
      patch: previousPayload,
    );
    await _writeDecisionLocal(decisionPayload);
  }

  Future<void> releaseWithNewCarry({
    required String userId,
    required DateTime localDate,
    DateTime? previousLocalDate,
    required String chosenReturn,
  }) async {
    final carryPayload = _setCarryPayload(
      userId: userId,
      localDate: localDate,
      chosenReturn: chosenReturn,
      source: 'newly_set',
    );
    if (carryPayload == null) return;
    final previousPayload = previousLocalDate == null
        ? null
        : <String, dynamic>{
            'user_id': userId,
            'local_date': _dateOnlyIso(previousLocalDate),
            'carryover_choice': 'release_it',
          };
    final decisionPayload = _decisionPayload(
      userId: userId,
      decisionDate: localDate,
      decision: 'released',
      newCarryText: chosenReturn,
    );
    if (decisionPayload == null) return;

    await _upsertRemote(carryPayload);
    if (previousPayload != null) {
      await _upsertRemote(previousPayload);
    }
    await _upsertDecisionRemote(decisionPayload);

    await _writeCarryLocalFromPayload(carryPayload);
    if (previousPayload != null) {
      await _writeLocal(
        userId: userId,
        localDate: previousLocalDate!,
        patch: previousPayload,
      );
    }
    await _writeDecisionLocal(decisionPayload);
  }

  Future<void> recordEveningThresholdDecision({
    required String userId,
    required DateTime decisionDate,
    required String decision,
    String? newCarryText,
  }) async {
    final payload = _decisionPayload(
      userId: userId,
      decisionDate: decisionDate,
      decision: decision,
      newCarryText: newCarryText,
    );
    if (payload == null) return;
    await _upsertDecisionRemote(payload);
    await _writeDecisionLocal(payload);
  }

  Map<String, dynamic>? _setCarryPayload({
    required String userId,
    required DateTime localDate,
    required String chosenReturn,
    required String source,
    String? kemeticDayKey,
  }) {
    final trimmed = chosenReturn.trim();
    if (trimmed.isEmpty) return null;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    return <String, dynamic>{
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
  }

  Future<void> _writeCarryLocalFromPayload(Map<String, dynamic> payload) async {
    final userId = payload['user_id']?.toString().trim();
    final localDate = DateTime.tryParse(
      payload['local_date']?.toString() ?? '',
    );
    final chosenReturn = payload['chosen_return']?.toString().trim();
    final source = payload['source']?.toString().trim();
    if (userId == null ||
        userId.isEmpty ||
        localDate == null ||
        chosenReturn == null ||
        chosenReturn.isEmpty ||
        source == null ||
        source.isEmpty) {
      return;
    }
    await _writeLocal(userId: userId, localDate: localDate, patch: payload);
    await _writeCurrentCarryLocal(
      userId: userId,
      localDate: localDate,
      chosenReturn: chosenReturn,
      source: source,
      setAtIso: payload['set_at']?.toString(),
    );
  }

  Map<String, dynamic>? _decisionPayload({
    required String userId,
    required DateTime decisionDate,
    required String decision,
    String? newCarryText,
  }) {
    final normalized = decision.trim().toLowerCase();
    if (normalized != 'carried' && normalized != 'released') return null;
    return <String, dynamic>{
      'user_id': userId,
      'decision_date': _dateOnlyIso(decisionDate),
      'decision': normalized,
      if (newCarryText != null && newCarryText.trim().isNotEmpty)
        'new_carry_text': newCarryText.trim(),
    };
  }

  Future<void> _upsertDecisionRemote(Map<String, dynamic> payload) async {
    try {
      await _client
          .from('evening_threshold_decisions')
          .upsert(payload, onConflict: 'user_id,decision_date');
    } catch (e) {
      debugPrint('[DailyOrientationRepo] decision upsert failed: $e');
      throw DailyOrientationPersistenceException(
        'Could not save evening threshold decision.',
        e,
      );
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
      if (chosenReturn != null && chosenReturn.trim().isNotEmpty)
        'source': 'daily_orientation_complete',
      if (chosenReturn != null && chosenReturn.trim().isNotEmpty)
        'set_at': nowIso,
      if (badgeLabel != null && badgeLabel.trim().isNotEmpty)
        'badge_label': badgeLabel.trim(),
      'status': 'completed',
      'completed_at': nowIso,
    };
    await _upsertRemote(payload);
    await _writeLocal(userId: userId, localDate: localDate, patch: payload);
    if (chosenReturn != null && chosenReturn.trim().isNotEmpty) {
      await _writeCurrentCarryLocal(
        userId: userId,
        localDate: localDate,
        chosenReturn: chosenReturn,
        source: 'daily_orientation_complete',
        setAtIso: nowIso,
      );
    }
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
    await _upsertRemote(payload);
    await _writeLocal(userId: userId, localDate: localDate, patch: payload);
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

  Future<DailyOrientationEntry?> _loadMostRecentCarry({
    required String userId,
    required DateTime localDate,
  }) async {
    final localCarry = await _readCurrentCarryLocal(
      userId: userId,
      localDate: localDate,
    );
    try {
      final row = await _client
          .from('daily_orientation')
          .select()
          .eq('user_id', userId)
          .lte('local_date', _dateOnlyIso(localDate))
          .filter('chosen_return', 'not.is', null)
          .order('local_date', ascending: false)
          .limit(1)
          .maybeSingle();
      final entry = DailyOrientationEntry.fromJson(
        row == null ? null : Map<String, dynamic>.from(row),
      );
      if (_hasText(entry?.chosenReturn)) {
        await _writeCurrentCarryLocal(
          userId: userId,
          localDate: entry!.localDate,
          chosenReturn: entry.chosenReturn!,
          source: entry.source ?? 'remote_history',
          setAtIso: entry.setAt?.toUtc().toIso8601String(),
        );
        return entry;
      }
    } catch (e) {
      debugPrint('[DailyOrientationRepo] remote carry history load failed: $e');
    }
    return localCarry;
  }

  Future<void> _writeCurrentCarryLocal({
    required String userId,
    required DateTime localDate,
    required String chosenReturn,
    required String source,
    String? setAtIso,
  }) async {
    final trimmed = chosenReturn.trim();
    if (trimmed.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _currentCarryKey(userId: userId),
        jsonEncode(<String, dynamic>{
          'user_id': userId,
          'local_date': _dateOnlyIso(localDate),
          'chosen_return': trimmed,
          'source': source,
          if (setAtIso != null && setAtIso.trim().isNotEmpty)
            'set_at': setAtIso.trim(),
          'status': 'started',
        }),
      );
    } catch (e) {
      debugPrint('[DailyOrientationRepo] local current carry write failed: $e');
    }
  }

  Future<DailyOrientationEntry?> _readCurrentCarryLocal({
    required String userId,
    required DateTime localDate,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_currentCarryKey(userId: userId));
      if (raw == null || raw.trim().isEmpty) return null;
      final entry = DailyOrientationEntry.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      if (!_hasText(entry?.chosenReturn)) return null;
      final targetDate = DateTime(
        localDate.year,
        localDate.month,
        localDate.day,
      );
      final carryDate = DateTime(
        entry!.localDate.year,
        entry.localDate.month,
        entry.localDate.day,
      );
      if (carryDate.isAfter(targetDate)) return null;
      return entry;
    } catch (e) {
      debugPrint('[DailyOrientationRepo] local current carry read failed: $e');
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
      throw DailyOrientationPersistenceException(
        'Could not save daily orientation.',
        e,
      );
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

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;
}

String? _trimOrNull(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}
