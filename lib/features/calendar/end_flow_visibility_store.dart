import 'package:flutter/foundation.dart';

enum EndFlowVisibilityState { pending, committed }

/// Process-local display authority for flows being ended.
///
/// Source snapshots remain untouched. Consumers synchronously combine their
/// latest source snapshot with this store, so late mounts and stale refreshes
/// cannot resurrect a pending or committed End Flow operation.
class EndFlowVisibilityStore extends ChangeNotifier {
  EndFlowVisibilityStore._();

  static final EndFlowVisibilityStore instance = EndFlowVisibilityStore._();

  final Map<int, EndFlowVisibilityState> _entries =
      <int, EndFlowVisibilityState>{};

  EndFlowVisibilityState? stateFor(int flowId) => _entries[flowId];

  bool isHidden(int flowId) => _entries.containsKey(flowId);

  Set<int> get hiddenFlowIds => Set<int>.unmodifiable(_entries.keys);

  void markPending(int flowId) {
    if (flowId <= 0 || _entries.containsKey(flowId)) return;
    _entries[flowId] = EndFlowVisibilityState.pending;
    notifyListeners();
  }

  void markCommitted(int flowId) {
    if (flowId <= 0 || _entries[flowId] == EndFlowVisibilityState.committed) {
      return;
    }
    _entries[flowId] = EndFlowVisibilityState.committed;
    notifyListeners();
  }

  void remove(int flowId) {
    if (_entries.remove(flowId) == null) return;
    notifyListeners();
  }

  void removePending(int flowId) {
    if (_entries[flowId] != EndFlowVisibilityState.pending) return;
    _entries.remove(flowId);
    notifyListeners();
  }

  void debugReset() {
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
  }
}
