const bool supportsAcknowledgedDurableSnapshotStore = false;

Future<String?> readWindowEnvelope(String userId, String windowId) async =>
    null;

Future<String?> readLatestEnvelope(String userId) async => null;

Future<String?> readLastActiveUserId() async => null;

Future<String> writeEnvelope({
  required String userId,
  required String windowId,
  required int generation,
  required String encodedEnvelope,
}) async => 'committed';

Future<void> clearWindow(String userId, String windowId) async {}

Future<void> clearLastActiveUser() async {}
