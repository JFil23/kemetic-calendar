class DayViewRestorationWriteGate {
  int _nextSessionId = 0;
  int? _activeSessionId;
  final Set<int> _closedSessionIds = <int>{};

  int beginOpen() {
    final sessionId = ++_nextSessionId;
    _activeSessionId = sessionId;
    return sessionId;
  }

  void markClosed(int sessionId) {
    _closedSessionIds.add(sessionId);
    if (_activeSessionId == sessionId) {
      _activeSessionId = null;
    }
  }

  void markActiveClosed() {
    final sessionId = _activeSessionId;
    if (sessionId != null) {
      markClosed(sessionId);
    }
  }

  bool canAcceptOpenWrite(int sessionId) {
    return _activeSessionId == sessionId &&
        !_closedSessionIds.contains(sessionId);
  }

  bool shouldPersist({required bool isOpen, int? sessionId}) {
    if (!isOpen) return true;
    if (sessionId != null) return canAcceptOpenWrite(sessionId);
    final activeSessionId = _activeSessionId;
    return activeSessionId != null &&
        !_closedSessionIds.contains(activeSessionId);
  }
}
