bool shouldCompleteStagedFlowAdd({
  required bool hasSavedFlow,
  required bool completionRequired,
  required bool hasPlannedNotes,
}) => hasSavedFlow && completionRequired && hasPlannedNotes;

/// Lifecycle for a staged flow whose persistence and UI completion can finish
/// in either order.
///
/// This type is public only so the transition contract can be tested directly;
/// product code owns instances through `_PendingStagedFlow`.
class StagedFlowLifecycle {
  StagedFlowLifecycle({required this.completionRequired});

  final bool completionRequired;
  bool persistenceStarted = false;
  bool persistenceCompleted = false;
  bool completionConsumed = false;
  Object? persistenceFailure;

  bool beginPersistence() {
    if (persistenceStarted) return false;
    persistenceStarted = true;
    return true;
  }

  void completePersistence({Object? failure}) {
    persistenceCompleted = true;
    persistenceFailure = failure;
  }

  /// Resolves the UI side of this lifecycle.
  ///
  /// A completion is also considered consumed when it is deliberately
  /// abandoned (for example after persistence failure or intent supersession).
  void consumeCompletion() {
    completionConsumed = true;
  }

  bool get shouldCleanup =>
      persistenceCompleted && (!completionRequired || completionConsumed);
}

/// Registry that keeps an armed staged payload until both sides of its
/// lifecycle have resolved.
class StagedFlowLifecycleRegistry<T extends StagedFlowLifecycle> {
  final Map<int, T> _entries = <int, T>{};

  T? operator [](int flowId) => _entries[flowId];

  void register(int flowId, T entry) {
    _entries[flowId] = entry;
  }

  bool contains(int flowId) => _entries.containsKey(flowId);

  void cleanupIfTerminal(int flowId) {
    final entry = _entries[flowId];
    if (entry?.shouldCleanup ?? false) {
      _entries.remove(flowId);
    }
  }
}
