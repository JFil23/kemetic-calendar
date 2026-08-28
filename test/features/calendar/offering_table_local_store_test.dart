import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/the_offering_table_local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'saves one trimmed local need per flow and survives store recreation',
    () async {
      const firstStore = OfferingTableLocalStore();
      await firstStore.saveNeed(41, '  Protect my sleep.  ');
      await firstStore.saveNeed(42, 'Drink more water.');

      const recreatedStore = OfferingTableLocalStore();
      expect(await recreatedStore.loadNeed(41), 'Protect my sleep.');
      expect(await recreatedStore.loadNeed(42), 'Drink more water.');
    },
  );

  test('missing, cleared, and deleted flow data degrade safely', () async {
    const store = OfferingTableLocalStore();
    expect(await store.loadNeed(99), isEmpty);

    await store.saveNeed(7, 'A private need');
    await store.saveNeed(8, 'Keep this one');
    await store.saveNeed(7, '   ');
    expect(await store.loadNeed(7), isEmpty);
    expect(await store.loadNeed(8), 'Keep this one');

    await store.saveNeed(7, 'A private need');
    await store.deleteFlowData(7);
    expect(await store.loadNeed(7), isEmpty);
    expect(await store.loadNeed(8), 'Keep this one');
  });
}
