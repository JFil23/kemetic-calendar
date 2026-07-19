import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'composition_models.dart';

abstract class CompositionUsageStore {
  Future<List<CompositionUsageRecord>> load();

  Future<void> recordAll(List<CompositionUsageRecord> records);
}

class SharedPreferencesCompositionUsageStore implements CompositionUsageStore {
  const SharedPreferencesCompositionUsageStore({
    this.preferencesKey = 'composition:phrase_usage:v1',
    this.pruneAfter = const Duration(days: 120),
  });

  final String preferencesKey;
  final Duration pruneAfter;

  @override
  Future<List<CompositionUsageRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(preferencesKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (json) => CompositionUsageRecord.fromJson(
              Map<String, dynamic>.from(json),
            ),
          )
          .whereType<CompositionUsageRecord>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> recordAll(List<CompositionUsageRecord> records) async {
    if (records.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = await load();
    final cutoff = DateTime.now().subtract(pruneAfter);
    final merged = <CompositionUsageRecord>[
      ...existing.where((record) => !record.date.isBefore(cutoff)),
      ...records,
    ];
    await prefs.setString(
      preferencesKey,
      jsonEncode(merged.map((record) => record.toJson()).toList()),
    );
  }
}
