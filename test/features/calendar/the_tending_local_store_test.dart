import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/the_tending_flow.dart';
import 'package:mobile/features/calendar/the_tending_local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('care inventory round-trips in SharedPreferences only', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final store = TheTendingLocalStore(prefs: prefs);

    await store.saveCareList(42, const <CareListEntry>[
      CareListEntry(name: 'A', perceivedNeed: 'medicine', statusTag: 'partial'),
      CareListEntry(name: 'B', perceivedNeed: 'ride'),
    ]);

    final entries = await store.loadCareList(42);
    expect(entries, hasLength(2));
    expect(entries.first.name, 'A');
    expect(entries.first.perceivedNeed, 'medicine');
    expect(entries.first.statusTag, 'partial');
    expect(prefs.getKeys(), contains('tending_42_care_list'));
  });

  test('prompt text saves locally and parses event-one inventory', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final store = TheTendingLocalStore(prefs: prefs);

    await store.savePromptText(
      7,
      TheTendingLocalPromptKind.careInventory,
      'Name One - food\nName Two - appointment',
    );

    final text = await store.loadPromptText(
      7,
      TheTendingLocalPromptKind.careInventory,
    );
    final entries = await store.loadCareList(7);

    expect(text, contains('Name One'));
    expect(entries, hasLength(2));
    expect(entries.last.name, 'Name Two');
    expect(entries.last.perceivedNeed, 'appointment');
  });

  test('deleteFlowData removes only the selected tending flow keys', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'tending_7_prompt_day11_commitment': 'local',
      'tending_8_prompt_day11_commitment': 'other',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = TheTendingLocalStore(prefs: prefs);

    await store.deleteFlowData(7);

    expect(prefs.getString('tending_7_prompt_day11_commitment'), isNull);
    expect(prefs.getString('tending_8_prompt_day11_commitment'), 'other');
  });
}
