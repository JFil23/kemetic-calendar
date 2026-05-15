import 'dart:convert';

import 'package:mobile/data/nutrition_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NutritionItemsCache {
  const NutritionItemsCache._();

  static String keyForUser(String? uid) =>
      'today_alignment_nutrition_items${uid == null ? '' : '_$uid'}';

  static bool isLocal(NutritionItem item) => item.id.startsWith('local_');

  static Future<List<NutritionItem>> load(String? uid) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(keyForUser(uid)) ?? const <String>[];
    final items = <NutritionItem>[];
    for (final raw in stored) {
      final item = _decodeItem(raw);
      if (item != null) items.add(item);
    }
    return items;
  }

  static Future<void> save(List<NutritionItem> items, {String? uid}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      keyForUser(uid),
      items.map((item) => jsonEncode(_encodeItem(item))).toList(),
    );
  }

  static NutritionItem? _decodeItem(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final id = decoded['id'] as String? ?? '';
      final nutrient = decoded['nutrient'] as String? ?? '';
      final source = decoded['source'] as String? ?? '';
      final purpose = decoded['purpose'] as String? ?? '';
      if (id.isEmpty || (nutrient.trim().isEmpty && source.trim().isEmpty)) {
        return null;
      }
      return NutritionItem(
        id: id,
        nutrient: nutrient,
        source: source,
        purpose: purpose,
        enabled: decoded['enabled'] as bool? ?? true,
        schedule: IntakeSchedule.fromJson(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _encodeItem(NutritionItem item) => {
    'id': item.id,
    'nutrient': item.nutrient,
    'source': item.source,
    'purpose': item.purpose,
    'enabled': item.enabled,
    ...item.schedule.toJson(),
  };
}
