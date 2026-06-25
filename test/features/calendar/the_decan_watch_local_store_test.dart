import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/the_decan_watch_flow.dart';
import 'package:mobile/features/calendar/the_decan_watch_local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'legacy Decan Watch local values still load from the existing key',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'decan_watch_42_6268_12': jsonEncode(<String, Object>{
          'sky_note': 'clouded western horizon',
          'decan_intention': 'carry steadiness',
          'observed_from_inside': true,
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final store = DecanWatchLocalStore(prefs: prefs);

      final record = await store.loadRecord(
        flowId: 42,
        kYear: 6268,
        globalDecanId: 12,
      );

      expect(record.skyNote, 'clouded western horizon');
      expect(record.decanIntention, 'carry steadiness');
      expect(record.observedFromInside, isTrue);
      expect(record.responseVisibility, kDecanWatchVisibilityInside);
      expect(prefs.getKeys(), contains('decan_watch_42_6268_12'));
    },
  );

  test(
    'visibility bridges through the existing Decan Watch namespace',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final store = DecanWatchLocalStore(prefs: prefs);

      await store.saveRecord(
        flowId: 42,
        kYear: 6268,
        globalDecanId: 12,
        record: const DecanWatchRecord(
          skyNote: 'clear western glow',
          decanIntention: 'steadiness',
          visibility: kDecanWatchVisibilityOutside,
        ),
      );

      final raw = prefs.getString('decan_watch_42_6268_12');
      expect(raw, isNotNull);
      final json = jsonDecode(raw!) as Map<String, dynamic>;
      expect(json['sky_note'], 'clear western glow');
      expect(json['decan_intention'], 'steadiness');
      expect(json['visibility'], kDecanWatchVisibilityOutside);
      expect(json['observed_from_inside'], isFalse);

      final record = await store.loadRecord(
        flowId: 42,
        kYear: 6268,
        globalDecanId: 12,
      );
      expect(record.responseVisibility, kDecanWatchVisibilityOutside);
      expect(await store.exportFlowData(42), contains('6268_12'));
    },
  );

  test(
    'clearing Decan Watch local values still removes the existing key',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final store = DecanWatchLocalStore(prefs: prefs);

      await store.saveRecord(
        flowId: 42,
        kYear: 6268,
        globalDecanId: 12,
        record: const DecanWatchRecord(
          visibility: kDecanWatchVisibilityClouded,
        ),
      );
      expect(prefs.getKeys(), contains('decan_watch_42_6268_12'));

      await store.saveRecord(
        flowId: 42,
        kYear: 6268,
        globalDecanId: 12,
        record: const DecanWatchRecord(),
      );

      expect(prefs.getKeys(), isNot(contains('decan_watch_42_6268_12')));
    },
  );
}
