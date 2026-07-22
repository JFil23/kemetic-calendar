@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/restoration_durable_store.dart';

void main() {
  test(
    'WEB-RESTORE-DURABILITY-001 IndexedDB transaction completion is monotonic and process-readable',
    () async {
      const store = PlatformRestorationDurableStore();
      expect(store.isSupported, isTrue);
      final nonce = DateTime.now().microsecondsSinceEpoch.toString();
      final userId = 'web-durability-$nonce';
      final windowId = 'window-$nonce';
      final snapshot = jsonEncode(<String, Object>{
        'schemaVersion': 1,
        'userId': userId,
        'windowId': windowId,
        'updatedAtMs': 200,
        'routeLocation': '/rhythm/today',
        'calendar': <String, Object>{
          'kYear': 6269,
          'kMonth': 5,
          'kDay': 3,
          'anchorAlignment': 0.34,
        },
      });
      final newer = DurableRestorationEnvelope.create(
        snapshotSchemaVersion: 1,
        userId: userId,
        windowId: windowId,
        generation: 200,
        snapshotJson: snapshot,
      );
      final older = DurableRestorationEnvelope.create(
        snapshotSchemaVersion: 1,
        userId: userId,
        windowId: windowId,
        generation: 199,
        snapshotJson: snapshot,
      );

      expect(
        await store.writeEnvelope(newer),
        DurableSnapshotWriteStatus.committed,
      );
      expect(
        await store.writeEnvelope(older),
        DurableSnapshotWriteStatus.superseded,
      );
      final current = DurableRestorationEnvelope.tryDecode(
        await store.readWindowEnvelope(userId, windowId),
        expectedUserId: userId,
        expectedWindowId: windowId,
      );
      final latest = DurableRestorationEnvelope.tryDecode(
        await store.readLatestEnvelope(userId),
        expectedUserId: userId,
      );
      expect(current?.generation, 200);
      expect(latest?.generation, 200);
      expect(current?.snapshotJson, snapshot);
      expect(await store.readLastActiveUserId(), userId);
      expect(await store.readLatestEnvelope('foreign-$nonce'), isNull);

      await store.clearWindow(userId, windowId);
      await store.clearLastActiveUser();
      expect(await store.readWindowEnvelope(userId, windowId), isNull);
    },
  );
}
