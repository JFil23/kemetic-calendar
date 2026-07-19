import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app_restoration_service.dart';
import 'restoration_trace.dart';

enum RestorationRestoreReason {
  coldLaunch,
  authResume,
  foregroundResume,
  userNavigation,
}

class RestorationUserIntentLease {
  const RestorationUserIntentLease._(this._owner, this.generation);

  final RestorationCoordinator _owner;
  final int generation;

  bool get isCurrent => _owner._userIntentGeneration == generation;
}

class RestorationCoordinator {
  RestorationCoordinator._();

  static final RestorationCoordinator instance = RestorationCoordinator._();
  static const Duration _lifecycleOverlayPreserveWindow = Duration(seconds: 3);
  static const String calendarDayViewSurface = 'calendar.dayView';
  static const String calendarOverlayStackSurface = 'calendar.overlayStack';
  static const String plannerSurface = 'planner';

  AppLifecycleState _lastLifecycleState = AppLifecycleState.resumed;
  DateTime? _lastExitLifecycleAt;
  RestorationRestoreReason _restoreReason = RestorationRestoreReason.coldLaunch;
  String? _restoreTargetLocation = '/';
  final Set<String> _consumedRestoreSurfaces = <String>{};
  final Set<String> _suppressedRestoreSurfaces = <String>{};
  int _userIntentGeneration = 0;

  RestorationRestoreReason get restoreReason => _restoreReason;

  RestorationUserIntentLease captureUserIntentLease() {
    return RestorationUserIntentLease._(this, _userIntentGeneration);
  }

  void _advanceUserIntent({required String reason, required String source}) {
    assert(reason.trim().isNotEmpty);
    _userIntentGeneration += 1;
    traceRestoration(
      'user intent advanced generation=$_userIntentGeneration '
      'source=$source reason=$reason',
    );
  }

  void noteCalendarViewportIntent({required String reason}) {
    _advanceUserIntent(reason: reason, source: 'calendar_viewport');
  }

  void resetForTesting() {
    _lastLifecycleState = AppLifecycleState.resumed;
    _lastExitLifecycleAt = null;
    _restoreReason = RestorationRestoreReason.coldLaunch;
    _restoreTargetLocation = '/';
    _consumedRestoreSurfaces.clear();
    _suppressedRestoreSurfaces.clear();
    _userIntentGeneration = 0;
  }

  bool get shouldDeferRootRoutePersistenceForLaunch {
    final defer =
        _isLaunchRestoreReason(_restoreReason) &&
        !_isRootLocation(_restoreTargetLocation);
    if (defer) {
      traceRestoration(
        'root persistence defer active reason=${_restoreReason.name} '
        'target=${_restoreTargetLocation ?? '<none>'}',
      );
    }
    return defer;
  }

  void beginLaunchRestore({
    required RestorationRestoreReason reason,
    String? targetLocation,
  }) {
    assert(reason != RestorationRestoreReason.userNavigation);
    _restoreReason = reason;
    _restoreTargetLocation = _normalizeLocation(targetLocation) ?? '/';
    _consumedRestoreSurfaces.clear();
    _suppressedRestoreSurfaces.clear();
    traceRestoration(
      'launch restore begin reason=${reason.name} '
      'target=${_restoreTargetLocation ?? '<none>'}',
    );
  }

  void beginAuthResumeRestore({String? targetLocation}) {
    beginLaunchRestore(
      reason: RestorationRestoreReason.authResume,
      targetLocation: targetLocation,
    );
  }

  void suppressRestoreForUserNavigation({
    required String reason,
    Iterable<String> surfaces = const <String>[],
  }) {
    assert(reason.trim().isNotEmpty);
    _advanceUserIntent(reason: reason, source: 'navigation');
    _restoreReason = RestorationRestoreReason.userNavigation;
    _restoreTargetLocation = null;
    _suppressedRestoreSurfaces.addAll(
      surfaces.map((surface) => surface.trim()).where((surface) {
        return surface.isNotEmpty;
      }),
    );
  }

  void suppressRestoreForExplicitIntent({
    required String reason,
    Iterable<String> surfaces = const <String>[],
  }) {
    assert(reason.trim().isNotEmpty);
    _suppressedRestoreSurfaces.addAll(
      surfaces.map((surface) => surface.trim()).where((surface) {
        return surface.isNotEmpty;
      }),
    );
  }

  bool canRestoreSurface(String surface, {bool requireRootTarget = false}) {
    final normalized = surface.trim();
    if (normalized.isEmpty) return false;
    if (!_isLaunchRestoreReason(_restoreReason)) return false;
    if (_surfaceMatchesAny(normalized, _suppressedRestoreSurfaces)) {
      return false;
    }
    if (_consumedRestoreSurfaces.contains(normalized)) return false;
    if (requireRootTarget && !_isRootLocation(_restoreTargetLocation)) {
      return false;
    }
    final overlayParentRoute = _calendarOverlayParentRoute(normalized);
    if (overlayParentRoute != null &&
        !_isRootLocation(overlayParentRoute) &&
        !_sameLocation(overlayParentRoute, _restoreTargetLocation)) {
      return false;
    }
    return true;
  }

  bool claimRestoreSurface(String surface, {bool requireRootTarget = false}) {
    final normalized = surface.trim();
    if (!canRestoreSurface(normalized, requireRootTarget: requireRootTarget)) {
      return false;
    }
    _consumedRestoreSurfaces.add(normalized);
    return true;
  }

  void markRestoreSurfaceConsumed(String surface) {
    final normalized = surface.trim();
    if (normalized.isNotEmpty) {
      _consumedRestoreSurfaces.add(normalized);
    }
  }

  bool isRestoreSurfaceSuppressed(String surface) {
    final normalized = surface.trim();
    if (normalized.isEmpty) return false;
    return _surfaceMatchesAny(normalized, _suppressedRestoreSurfaces);
  }

  static bool _isLaunchRestoreReason(RestorationRestoreReason reason) {
    switch (reason) {
      case RestorationRestoreReason.coldLaunch:
      case RestorationRestoreReason.authResume:
      case RestorationRestoreReason.foregroundResume:
        return true;
      case RestorationRestoreReason.userNavigation:
        return false;
    }
  }

  static bool _surfaceMatchesAny(String surface, Set<String> candidates) {
    for (final candidate in candidates) {
      if (surface == candidate || surface.startsWith('$candidate|')) {
        return true;
      }
    }
    return false;
  }

  static String? _normalizeLocation(String? location) {
    final normalized = location?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  static bool _isRootLocation(String? location) {
    final normalized = _normalizeLocation(location);
    if (normalized == null) return true;
    final uri = Uri.tryParse(normalized);
    return uri == null || uri.path.isEmpty || uri.path == '/';
  }

  static bool _sameLocation(String? a, String? b) {
    final normalizedA = _normalizeLocation(a);
    final normalizedB = _normalizeLocation(b);
    if (normalizedA == null || normalizedB == null) {
      return _isRootLocation(normalizedA) && _isRootLocation(normalizedB);
    }
    final aUri = Uri.tryParse(normalizedA);
    final bUri = Uri.tryParse(normalizedB);
    if (aUri == null || bUri == null) return normalizedA == normalizedB;
    return aUri.path == bUri.path && aUri.query == bUri.query;
  }

  static String? _calendarOverlayParentRoute(String surface) {
    if (!surface.startsWith('$calendarOverlayStackSurface|')) return null;
    final parts = surface.split('|');
    if (parts.length < 3) return null;
    return _normalizeLocation(parts[2]);
  }

  Future<void> recordOverlayStackPageState(
    List<Map<String, dynamic>> overlayStack, {
    required String reason,
  }) {
    traceRestoration(
      'coordinator record overlay page_state reason=$reason '
      'overlayCount=${overlayStack.length}',
    );
    return AppRestorationService.instance.saveOverlayStack(overlayStack);
  }

  void noteLifecycleState(AppLifecycleState state) {
    _lastLifecycleState = state;
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _lastExitLifecycleAt = DateTime.now();
        break;
      case AppLifecycleState.resumed:
        break;
    }
  }

  bool get shouldPreserveOverlayForLifecycleClose {
    switch (_lastLifecycleState) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        return true;
      case AppLifecycleState.resumed:
        final lastExit = _lastExitLifecycleAt;
        return lastExit != null &&
            DateTime.now().difference(lastExit) <
                _lifecycleOverlayPreserveWindow;
    }
  }

  bool get shouldPreserveRouteForLifecycleClose =>
      shouldPreserveOverlayForLifecycleClose;

  Future<Map<String, dynamic>?> readSurfaceState(String key) {
    return AppRestorationService.instance.readSurfaceState(key);
  }

  Future<void> saveSurfaceState(String key, Map<String, dynamic>? state) {
    return AppRestorationService.instance.saveSurfaceState(key, state);
  }

  Future<void> clearProfileFeedContinuity(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return;
    }
    final surfaceKey = 'profile:$normalizedUserId';
    final state = await readSurfaceState(surfaceKey);
    if (state == null || state.isEmpty) {
      return;
    }

    final nextState = Map<String, dynamic>.from(state)
      ..['feedRevealed'] = false
      ..remove('expandedFeedItem')
      ..remove('feedScrollOffset');
    await saveSurfaceState(surfaceKey, nextState);
  }

  Future<List<Map<String, dynamic>>> readOverlayStack() {
    return AppRestorationService.instance.readOverlayStack();
  }

  Future<AppRestorationReadResult> readBestSnapshot({
    bool includeRemote = false,
  }) {
    return AppRestorationService.instance.readBestSnapshot(
      includeRemote: includeRemote,
    );
  }

  Future<void> saveOverlayStack(
    List<Map<String, dynamic>> overlayStack, {
    OverlayStackMutationReason reason = OverlayStackMutationReason.programmatic,
  }) {
    return AppRestorationService.instance.saveOverlayStack(
      overlayStack,
      reason: reason,
    );
  }

  Future<Map<String, dynamic>?> readEditorState(String key) {
    return AppRestorationService.instance.readEditorState(key);
  }

  Future<void> saveEditorState(String key, Map<String, dynamic>? state) {
    return AppRestorationService.instance.saveEditorState(key, state);
  }

  Future<void> saveTextEditingValue({
    required String key,
    required TextEditingValue value,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    return saveEditorState(key, <String, dynamic>{
      ...metadata,
      'text': value.text,
      'selectionBase': value.selection.baseOffset,
      'selectionExtent': value.selection.extentOffset,
      'selectionAffinity': value.selection.affinity.name,
      'selectionIsDirectional': value.selection.isDirectional,
      'composingBase': value.composing.start,
      'composingExtent': value.composing.end,
    });
  }

  Future<TextEditingValue?> readTextEditingValue(String key) async {
    final state = await readEditorState(key);
    if (state == null) {
      return null;
    }
    return textEditingValueFromJson(state);
  }

  TextEditingValue? textEditingValueFromJson(Map<String, dynamic> state) {
    final text = state['text'] as String?;
    if (text == null) {
      return null;
    }
    final selectionBase = (state['selectionBase'] as num?)?.toInt();
    final selectionExtent = (state['selectionExtent'] as num?)?.toInt();
    final composingBase = (state['composingBase'] as num?)?.toInt();
    final composingExtent = (state['composingExtent'] as num?)?.toInt();
    final maxOffset = text.length;

    int clampOffset(int? value) {
      if (value == null) {
        return -1;
      }
      return value.clamp(0, maxOffset).toInt();
    }

    final base = clampOffset(selectionBase);
    final extent = clampOffset(selectionExtent);
    final composingStart = clampOffset(composingBase);
    final composingEnd = clampOffset(composingExtent);
    final affinity = state['selectionAffinity'] == 'upstream'
        ? TextAffinity.upstream
        : TextAffinity.downstream;

    return TextEditingValue(
      text: text,
      selection: base < 0 || extent < 0
          ? const TextSelection.collapsed(offset: -1)
          : TextSelection(
              baseOffset: base,
              extentOffset: extent,
              affinity: affinity,
              isDirectional: state['selectionIsDirectional'] == true,
            ),
      composing:
          composingStart < 0 ||
              composingEnd < 0 ||
              composingStart > composingEnd
          ? TextRange.empty
          : TextRange(start: composingStart, end: composingEnd),
    );
  }

  Future<void> clearEditorState(String key) {
    return saveEditorState(key, null);
  }

  Future<void> saveCacheHints(Map<String, dynamic>? hints) {
    return AppRestorationService.instance.saveCacheHints(hints);
  }

  Future<Map<String, dynamic>?> readCacheHints() {
    return AppRestorationService.instance.readCacheHints();
  }

  Future<void> flush() {
    return AppRestorationService.instance.flushPendingWrites();
  }
}
