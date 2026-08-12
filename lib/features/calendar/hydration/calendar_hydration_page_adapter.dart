part of '../calendar_page.dart';

enum _CalendarHydrationMode {
  provisionalViewport,
  catalogReconcile,
  backgroundWindow,
  targetedWindow,
}

@immutable
class _CalendarHydrationPassResult {
  const _CalendarHydrationPassResult({required this.catalogFingerprint});

  final String catalogFingerprint;
}

@immutable
class _CalendarHydrationRequest {
  const _CalendarHydrationRequest({
    required this.mode,
    required this.reason,
    required this.intentKind,
    required this.priority,
    required this.preserveViewport,
    this.interval,
    this.catalogFingerprint,
    this.catalogIsFresh = false,
    this.union,
    this.chunkIndex,
    this.chunkCount,
    this.isFinalChunk = false,
  });

  factory _CalendarHydrationRequest.provisionalViewport({
    required String reason,
    CalendarHydrationInterval? interval,
  }) => _CalendarHydrationRequest(
    mode: _CalendarHydrationMode.provisionalViewport,
    reason: reason,
    intentKind: CalendarHydrationIntentKind.viewport,
    priority: 100,
    preserveViewport: true,
    interval: interval,
  );

  factory _CalendarHydrationRequest.catalogReconcile({
    required String reason,
    CalendarHydrationInterval? interval,
  }) => _CalendarHydrationRequest(
    mode: _CalendarHydrationMode.catalogReconcile,
    reason: reason,
    intentKind: CalendarHydrationIntentKind.catalogReconcile,
    priority: 90,
    preserveViewport: true,
    interval: interval,
  );

  factory _CalendarHydrationRequest.targeted({
    required String reason,
    required CalendarHydrationIntentKind intentKind,
    CalendarHydrationInterval? interval,
  }) => _CalendarHydrationRequest(
    mode: _CalendarHydrationMode.targetedWindow,
    reason: reason,
    intentKind: intentKind,
    priority: 100,
    preserveViewport: true,
    interval: interval,
  );

  factory _CalendarHydrationRequest.background({
    required String reason,
    required CalendarHydrationIntentKind intentKind,
    required CalendarHydrationInterval interval,
    required String catalogFingerprint,
    required CalendarHydrationInterval union,
    required int chunkIndex,
    required int chunkCount,
    required bool isFinalChunk,
  }) => _CalendarHydrationRequest(
    mode: _CalendarHydrationMode.backgroundWindow,
    reason: reason,
    intentKind: intentKind,
    priority: intentKind == CalendarHydrationIntentKind.adjacentWindow
        ? 70
        : 50,
    preserveViewport: true,
    interval: interval,
    catalogFingerprint: catalogFingerprint,
    catalogIsFresh: true,
    union: union,
    chunkIndex: chunkIndex,
    chunkCount: chunkCount,
    isFinalChunk: isFinalChunk,
  );

  final _CalendarHydrationMode mode;
  final String reason;
  final CalendarHydrationIntentKind intentKind;
  final int priority;
  final bool preserveViewport;
  final CalendarHydrationInterval? interval;
  final String? catalogFingerprint;
  final bool catalogIsFresh;
  final CalendarHydrationInterval? union;
  final int? chunkIndex;
  final int? chunkCount;
  final bool isFinalChunk;

  bool get reusesCatalog => mode != _CalendarHydrationMode.catalogReconcile;
  bool get isForeground =>
      mode == _CalendarHydrationMode.provisionalViewport ||
      mode == _CalendarHydrationMode.targetedWindow;

  String get diagnosticSource => '${intentKind.name}:$reason';

  CalendarHydrationJobKey jobKey({
    required CalendarHydrationInterval resolvedInterval,
    required String? resolvedFingerprint,
  }) => CalendarHydrationJobKey(
    kind: intentKind,
    reason: reason,
    interval: resolvedInterval,
    catalogFingerprint: resolvedFingerprint,
  );
}
