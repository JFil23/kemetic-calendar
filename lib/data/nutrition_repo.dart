import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Defines the modes for a nutrition schedule.
///
/// When [IntakeMode.weekday], the user specifies one or more ISO weekday
/// numbers (1 = Monday, 7 = Sunday) in [IntakeSchedule.daysOfWeek] and the
/// schedule repeats on those days of the week.
///
/// When [IntakeMode.decan], the user specifies one or more decan days
/// (1‑10) in [IntakeSchedule.decanDays]. A decan day refers to the day
/// index within a ten‑day decan period on the Kemetic calendar (e.g. Day 3
/// means the third day of any decan). The schedule repeats on those decan
/// days.
enum IntakeMode { weekday, decan }

/// A serializable definition of when a nutrient should be taken.
///
/// Clients are free to choose either weekdays or decan days. Exactly one of
/// [daysOfWeek] or [decanDays] must be non‑empty depending on [mode].
///
/// All times are stored in the user's local timezone by capturing only the
/// hour and minute parts. When syncing to a calendar, the local timezone
/// should be used to construct the full DateTime before converting to UTC.
class IntakeSchedule {
  final IntakeMode mode;
  final Set<int> daysOfWeek;
  final Set<int> decanDays;
  final bool repeat;
  final TimeOfDay time;
  final Duration? alertOffset;

  const IntakeSchedule({
    required this.mode,
    this.daysOfWeek = const {},
    this.decanDays = const {},
    required this.repeat,
    required this.time,
    this.alertOffset,
  });

  /// Serializes this schedule into a map suitable for Supabase JSON columns.
  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'days_of_week': daysOfWeek.toList(),
        'decan_days': decanDays.toList(),
        'repeat': repeat,
        'time_h': time.hour,
        'time_m': time.minute,
        'alert_offset_minutes': alertOffset?.inMinutes,
      };

  /// Creates a new schedule from a JSON map.
  factory IntakeSchedule.fromJson(Map<String, dynamic> json) => IntakeSchedule(
        mode: IntakeMode.values
            .firstWhere((e) => e.name == json['mode'] as String),
        daysOfWeek: (json['days_of_week'] as List?)
                ?.map((e) => e as int)
                .toSet() ??
            {},
        decanDays: (json['decan_days'] as List?)
                ?.map((e) => e as int)
                .toSet() ??
            {},
        repeat: json['repeat'] as bool? ?? true,
        time: TimeOfDay(
          hour: json['time_h'] as int? ?? 9,
          minute: json['time_m'] as int? ?? 0,
        ),
        alertOffset: json['alert_offset_minutes'] != null
            ? Duration(minutes: json['alert_offset_minutes'] as int)
            : null,
      );
}

/// Extension to add copyWith method to IntakeSchedule
extension IntakeScheduleCopyWith on IntakeSchedule {
  IntakeSchedule copyWith({
    IntakeMode? mode,
    Set<int>? daysOfWeek,
    Set<int>? decanDays,
    bool? repeat,
    TimeOfDay? time,
    Duration? alertOffset,
  }) {
    return IntakeSchedule(
      mode: mode ?? this.mode,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      decanDays: decanDays ?? this.decanDays,
      repeat: repeat ?? this.repeat,
      time: time ?? this.time,
      alertOffset: alertOffset ?? this.alertOffset,
    );
  }
}

/// Represents a single row in the nutrition table. Each item holds a nutrient
/// along with optional source and purpose fields and an intake schedule. An
/// item can be disabled to temporarily suppress event creation.
class NutritionItem {
  final String id;
  String nutrient;
  String source;
  String purpose;
  IntakeSchedule schedule;
  bool enabled;

  NutritionItem({
    required this.id,
    required this.nutrient,
    required this.source,
    required this.purpose,
    required this.schedule,
    this.enabled = true,
  });

  /// Builds a map for inserting/upserting into Supabase. The user_id must be
  /// supplied by the caller since it comes from the current session.
  Map<String, dynamic> toInsert({required String userId}) {
    return {
      'user_id': userId,
      'nutrient': nutrient,
      'source': source,
      'purpose': purpose,
      'mode': schedule.mode.name,
      'days_of_week': schedule.daysOfWeek.toList(),
      'decan_days': schedule.decanDays.toList(),
      'repeat': schedule.repeat,
      'time_h': schedule.time.hour,
      'time_m': schedule.time.minute,
      'alert_offset_minutes': schedule.alertOffset?.inMinutes,
      'enabled': enabled,
    };
  }

  /// Creates a new [NutritionItem] from a Supabase row.
  factory NutritionItem.fromRow(Map<String, dynamic> row) => NutritionItem(
        id: row['id'] as String,
        nutrient: row['nutrient'] as String,
        source: row['source'] as String? ?? '',
        purpose: row['purpose'] as String? ?? '',
        schedule: IntakeSchedule.fromJson(row),
        enabled: (row['enabled'] as bool?) ?? true,
      );
}

/// Extension to add copyWith method to NutritionItem
extension NutritionItemCopy on NutritionItem {
  NutritionItem copyWith({
    String? id,
    String? nutrient,
    String? source,
    String? purpose,
    IntakeSchedule? schedule,
    bool? enabled,
  }) {
    return NutritionItem(
      id: id ?? this.id,
      nutrient: nutrient ?? this.nutrient,
      source: source ?? this.source,
      purpose: purpose ?? this.purpose,
      schedule: schedule ?? this.schedule,
      enabled: enabled ?? this.enabled,
    );
  }
}

/// UUID validation helper - checks if a string is a valid UUID format
bool _isRealUuid(String s) {
  // Accepts v1–v5 UUIDs (with hyphens)
  final re = RegExp(
    r'^[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'[1-5][0-9a-fA-F]{3}-'
    r'[89abAB][0-9a-fA-F]{3}-'
    r'[0-9a-fA-F]{12}$'
  );
  return re.hasMatch(s);
}

/// Repository for CRUD operations on nutrition items. This uses Supabase
/// directly and applies row level security so that each user only sees
/// their own items. Use [NutritionRepo.getAll] to fetch existing items,
/// [NutritionRepo.upsert] to insert or update an item, and
/// [NutritionRepo.delete] to remove an item.
class NutritionRepo {
  final SupabaseClient _client;

  NutritionRepo(this._client);

  /// Retrieves all nutrition items for the current user. Returns an empty
  /// list if there is no active session.
  Future<List<NutritionItem>> getAll() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    
    try {
      final rows = await _client
          .from('nutrition_items')
          .select()
          .eq('user_id', user.id)
          .order('created_at')
          .timeout(const Duration(seconds: 10));
      return (rows as List)
          .map((r) => NutritionItem.fromRow(r as Map<String, dynamic>))
          .toList();
    } on TimeoutException catch (e) {
      debugPrint('[NutritionRepo] Timeout loading items: $e');
      rethrow;
    } catch (e, st) {
      final msg = e.toString().toLowerCase();
      final code = e is PostgrestException ? (e.code ?? '') : '';
      debugPrint('[NutritionRepo] Error: $e');
      debugPrint('[NutritionRepo] Code: $code');
      debugPrint('[NutritionRepo] Stack: $st');
      
      // 42P01 = undefined_table
      if (code.contains('42P01') ||
          (msg.contains('relation') && msg.contains('nutrition_items')) ||
          msg.contains('does not exist')) {
        throw StateError('relation "nutrition_items" does not exist');
      }
      rethrow;
    }
  }

  /// Inserts or updates a nutrition item. When [item.id] is empty or a temp ID,
  /// the database generates a new UUID and returns it in the response.
  Future<NutritionItem> upsert(NutritionItem item) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('No user session');

    final payload = item.toInsert(userId: user.id)
      ..removeWhere((k, v) => v == null);

    // ✅ Only include id when it's a real UUID (not a temp/string placeholder)
    if (item.id.isNotEmpty && _isRealUuid(item.id)) {
      payload['id'] = item.id;
    }

    try {
      final row = await _client
          .from('nutrition_items')
          .upsert(payload, onConflict: 'id')
          .select()
          .single();
      return NutritionItem.fromRow(row as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[NutritionRepo] upsert error: $e');
      rethrow;
    }
  }

  /// Deletes a nutrition item by id.
  Future<void> delete(String id) async {
    await _client
        .from('nutrition_items')
        .delete()
        .eq('id', id);
  }
}

