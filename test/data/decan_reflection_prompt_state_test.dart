import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/decan_reflection_prompt_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'keeps every interacted decan instead of overwriting the last one',
    () async {
      final promptState = DecanReflectionPromptState.withUserIdProvider(
        () => 'user-a',
      );
      final firstDecan = DateTime.utc(2026, 5, 1);
      final secondDecan = DateTime.utc(2026, 5, 11);

      await promptState.markInteracted(firstDecan);
      await promptState.markInteracted(secondDecan);

      expect(await promptState.hasInteracted(firstDecan), isTrue);
      expect(await promptState.hasInteracted(secondDecan), isTrue);
    },
  );

  test(
    'matches the same decan when UTC and stored date-only shapes differ',
    () async {
      final promptState = DecanReflectionPromptState.withUserIdProvider(
        () => 'user-a',
      );

      await promptState.markInteracted(DateTime(2026, 5, 11));

      expect(
        await promptState.hasInteracted(DateTime.utc(2026, 5, 11)),
        isTrue,
      );
    },
  );

  test('continues to read old single-date preference values', () async {
    SharedPreferences.setMockInitialValues({
      DecanReflectionPromptState.dismissedPrefKey: jsonEncode({
        'user-a': '2026-05-11',
      }),
    });
    final promptState = DecanReflectionPromptState.withUserIdProvider(
      () => 'user-a',
    );

    expect(await promptState.hasDismissed(DateTime.utc(2026, 5, 11)), isTrue);
  });
}
