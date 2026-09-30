import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:mobile/data/warm_state/warm_resource_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/warm_state/release_f96c7b57.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    SharedPreferences.setMockInitialValues(Map<String, Object>.from(fixture));
  });
  test(
    'deployed pre-upgrade snapshots restore without a network or build-version key',
    () async {
      final upgraded = WarmSnapshotStore();
      expect(
        (await upgraded.cached('upgrade-user', 'rhythm.notes.rows') as List)
            .single['body'],
        'A preserved note',
      );
      expect(await upgraded.cached('upgrade-user', 'pages.flows'), isEmpty);
    },
  );
  test(
    'resource migration upgrades only its family while retaining unrelated warmth',
    () async {
      final upgraded = WarmSnapshotStore(
        schemaFor: (key) => key.startsWith('rhythm.')
            ? WarmResourceSchema(
                version: 2,
                migrations: {
                  1: (data) => (data as List)
                      .map((r) => {...r as Map, 'newField': 'default'})
                      .toList(),
                },
              )
            : const WarmResourceSchema(),
      );
      expect(
        (await upgraded.cached('upgrade-user', 'rhythm.notes.rows') as List)
            .single['newField'],
        'default',
      );
      expect(await upgraded.cached('upgrade-user', 'pages.flows'), isEmpty);
    },
  );
  test(
    'unsupported cache schema is a miss, never an empty successful value',
    () async {
      final upgraded = WarmSnapshotStore(
        schemaFor: (_) => const WarmResourceSchema(version: 2),
      );
      await expectLater(
        upgraded.cached('upgrade-user', 'rhythm.notes.rows'),
        throwsA(isA<WarmCacheMiss>()),
      );
      expect(
        (await SharedPreferences.getInstance()).getString(
          'warm_snapshot:v1:upgrade-user:rhythm.notes.rows',
        ),
        contains('A preserved note'),
      );
    },
  );
  test(
    'cache eviction and logout cannot delete pending account writes',
    () async {
      final store = WarmSnapshotStore(maxEntries: 1);
      await store.restore('upgrade-user');
      await store.refresh(
        'upgrade-user',
        'pages.flows',
        () async => [],
        isCurrent: () => true,
      );
      await store.forgetAccount('upgrade-user');
      expect(
        (await SharedPreferences.getInstance()).getString(
          'planner_account:v1:upgrade-user',
        ),
        contains('Not a cache'),
      );
    },
  );
  test('new repository domains require an explicit warm contract', () {
    expect(
      () => WarmResourceContract.requireRegistered('newFeature.rows'),
      throwsStateError,
    );
    for (final key in [
      'pages.flows',
      'readingHouse.messages.room',
      'rhythm.notes.rows',
    ]) {
      expect(
        () => WarmResourceContract.requireRegistered(key),
        returnsNormally,
      );
    }
  });
}
