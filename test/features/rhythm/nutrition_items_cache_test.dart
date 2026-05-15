import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/nutrition_repo.dart';
import 'package:mobile/features/rhythm/data/nutrition_items_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('round trips nutrition items per user', () async {
    final item = NutritionItem(
      id: 'local_1',
      nutrient: 'Magnesium',
      source: 'Supplement',
      purpose: 'Sleep',
      schedule: const IntakeSchedule(
        mode: IntakeMode.decan,
        decanDays: {6},
        repeat: true,
        time: TimeOfDay(hour: 21, minute: 30),
      ),
    );

    await NutritionItemsCache.save([item], uid: 'user-a');

    expect(await NutritionItemsCache.load('user-b'), isEmpty);

    final loaded = await NutritionItemsCache.load('user-a');
    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'local_1');
    expect(loaded.single.nutrient, 'Magnesium');
    expect(loaded.single.source, 'Supplement');
    expect(loaded.single.purpose, 'Sleep');
    expect(loaded.single.schedule.mode, IntakeMode.decan);
    expect(loaded.single.schedule.decanDays, {6});
    expect(loaded.single.schedule.time.hour, 21);
    expect(loaded.single.schedule.time.minute, 30);
  });

  test('ignores malformed cached rows', () async {
    SharedPreferences.setMockInitialValues({
      NutritionItemsCache.keyForUser('user-a'): [
        'not-json',
        '{"id":"local_empty","nutrient":"","source":""}',
      ],
    });

    expect(await NutritionItemsCache.load('user-a'), isEmpty);
  });
}
