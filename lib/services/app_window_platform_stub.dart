import 'dart:async';

typedef WebLifecycleLogger =
    void Function(String event, Map<String, Object?> detail);

Future<String> resolvePlatformWindowId() async => 'primary';

void installWebLifecycleLogging(WebLifecycleLogger onEvent) {}
