import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app_restoration_service.dart';

class RestorationCoordinator {
  RestorationCoordinator._();

  static final RestorationCoordinator instance = RestorationCoordinator._();
  static const Duration _lifecycleOverlayPreserveWindow = Duration(seconds: 3);

  AppLifecycleState _lastLifecycleState = AppLifecycleState.resumed;
  DateTime? _lastExitLifecycleAt;

  Future<void> recordRouteLocation(String location) {
    final normalized = location.trim();
    if (normalized.isEmpty) {
      return Future<void>.value();
    }
    return AppRestorationService.instance.saveRouteLocation(normalized);
  }

  Future<void> recordRouteLocationWithOverlayStack(
    String location,
    List<Map<String, dynamic>> overlayStack,
  ) {
    final normalized = location.trim();
    if (normalized.isEmpty) {
      return Future<void>.value();
    }
    return AppRestorationService.instance.saveRouteLocationWithOverlayStack(
      normalized,
      overlayStack,
    );
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

  Future<Map<String, dynamic>?> readSurfaceState(String key) {
    return AppRestorationService.instance.readSurfaceState(key);
  }

  Future<void> saveSurfaceState(String key, Map<String, dynamic>? state) {
    return AppRestorationService.instance.saveSurfaceState(key, state);
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

  Future<void> saveOverlayStack(List<Map<String, dynamic>> overlayStack) {
    return AppRestorationService.instance.saveOverlayStack(overlayStack);
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

void persistRouteContinuity(String location) {
  unawaited(RestorationCoordinator.instance.recordRouteLocation(location));
}
