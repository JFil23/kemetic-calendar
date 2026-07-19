import 'dart:async';

typedef WebLifecycleLogger =
    void Function(String event, Map<String, Object?> detail);

const bool supportsSynchronousCriticalSnapshotStorage = false;

Future<String> resolvePlatformWindowId() async => 'primary';

void installWebLifecycleLogging(WebLifecycleLogger onEvent) {}

void registerCriticalSnapshotWindow(String windowId) {}

String? readCriticalSnapshot(String windowId) => null;

void updateCriticalSnapshot(String windowId, String? serialized) {}

void clearCriticalSnapshot(String windowId) {}

String? readLatestCriticalSnapshot(String userId) => null;

void updateLatestCriticalSnapshot(String userId, String? serialized) {}

void clearLatestCriticalSnapshot(String userId) {}

String? readPlatformLastActiveUserId() => null;

void updatePlatformLastActiveUserId(String? userId) {}
