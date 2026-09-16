import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/the_offering_table_local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'saves one trimmed intention per flow day and survives recreation',
    () async {
      const firstStore = OfferingTableLocalStore();
      await firstStore.saveIntention(41, 1, '  Protect my sleep.  ');
      await firstStore.saveIntention(41, 2, 'Call my mother.');
      await firstStore.saveIntention(42, 1, 'Drink more water.');

      const recreatedStore = OfferingTableLocalStore();
      expect(await recreatedStore.loadIntention(41, 1), 'Protect my sleep.');
      expect(await recreatedStore.loadIntention(41, 2), 'Call my mother.');
      expect(await recreatedStore.loadIntention(41, 3), isEmpty);
      expect(await recreatedStore.loadIntention(42, 1), 'Drink more water.');
    },
  );

  test('missing, cleared, and deleted flow data degrade safely', () async {
    const store = OfferingTableLocalStore();
    expect(await store.loadIntention(99, 1), isEmpty);

    await store.saveIntention(7, 2, 'A private intention');
    await store.saveIntention(8, 2, 'Keep this one');
    await store.saveIntention(7, 2, '   ');
    expect(await store.loadIntention(7, 2), isEmpty);
    expect(await store.loadIntention(8, 2), 'Keep this one');

    await store.saveIntention(7, 30, 'A private intention');
    await store.deleteFlowData(7);
    expect(await store.loadIntention(7, 30), isEmpty);
    expect(await store.loadIntention(8, 2), 'Keep this one');
  });

  test('legacy flow value migrates to Day 1 only and is removed', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'offering_table_957_initial_need': '  Protect my sleep.  ',
    });
    const store = OfferingTableLocalStore();

    expect(await store.loadIntention(957, 2), isEmpty);
    final beforeMigration = await SharedPreferences.getInstance();
    expect(
      beforeMigration.containsKey('offering_table_957_initial_need'),
      true,
    );

    expect(await store.loadIntention(957, 1), 'Protect my sleep.');
    expect(await store.loadIntention(957, 2), isEmpty);
    expect(await store.loadIntention(957, 30), isEmpty);

    final afterMigration = await SharedPreferences.getInstance();
    expect(
      afterMigration.getString('offering_table_957_day_01_intention'),
      'Protect my sleep.',
    );
    expect(
      afterMigration.containsKey('offering_table_957_initial_need'),
      false,
    );
  });

  test('Day View state is isolated per day and survives recreation', () async {
    const store = OfferingTableLocalStore();
    await store.saveDayViewState(41, 8, <String, dynamic>{
      'version': 1,
      'words': <String, String>{'hunger': 'quiet'},
      'actions': <String, bool>{'portion': true},
    });
    await store.saveDayViewState(41, 23, <String, dynamic>{
      'version': 1,
      'words': <String, String>{'delayed': 'reply'},
      'actions': <String, bool>{'truth': true},
    });

    const recreated = OfferingTableLocalStore();
    expect(
      await recreated.loadDayViewState(41, 8),
      containsPair('words', <String, String>{'hunger': 'quiet'}),
    );
    expect(
      await recreated.loadDayViewState(41, 23),
      containsPair('actions', <String, bool>{'truth': true}),
    );
    expect(await recreated.loadDayViewState(41, 9), isEmpty);
  });

  test(
    'invalid Day View JSON is ignored and flow deletion removes it',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'offering_table_91_day_04_day_view_v1': '{not json',
      });
      const store = OfferingTableLocalStore();
      expect(await store.loadDayViewState(91, 4), isEmpty);

      await store.saveDayViewState(91, 4, <String, dynamic>{
        'version': 1,
        'words': <String, String>{'care': 'appointment'},
      });
      await store.deleteFlowData(91);
      expect(await store.loadDayViewState(91, 4), isEmpty);
    },
  );
}
