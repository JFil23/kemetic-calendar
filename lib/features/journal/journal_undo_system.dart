// lib/features/journal/journal_undo_system.dart
// Universal undo/redo for ALL journal actions (text, drawing, highlighting)

import 'journal_v2_document_model.dart';

enum JournalActionType {
  textEdit,
  drawStroke,
  highlightStroke,
}

class JournalAction {
  final JournalActionType type;
  final JournalDocument? documentBefore;
  final JournalDocument? documentAfter;
  final DateTime timestamp;

  JournalAction({
    required this.type,
    this.documentBefore,
    this.documentAfter,
    required this.timestamp,
  });
}

class JournalUndoSystem {
  final List<JournalAction> _undoStack = [];
  final List<JournalAction> _redoStack = [];
  final int maxStackSize;

  JournalUndoSystem({this.maxStackSize = 50});

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Record an action
  void recordAction({
    required JournalActionType type,
    required JournalDocument? before,
    required JournalDocument? after,
  }) {
    final action = JournalAction(
      type: type,
      documentBefore: before,
      documentAfter: after,
      timestamp: DateTime.now(),
    );

    _undoStack.add(action);
    _redoStack.clear(); // Clear redo stack when new action is recorded

    // Limit stack size
    if (_undoStack.length > maxStackSize) {
      _undoStack.removeAt(0);
    }
  }

  /// Undo last action
  JournalDocument? undo(JournalDocument current) {
    if (!canUndo) return null;

    final action = _undoStack.removeLast();
    _redoStack.add(action);

    return action.documentBefore;
  }

  /// Redo last undone action
  JournalDocument? redo(JournalDocument current) {
    if (!canRedo) return null;

    final action = _redoStack.removeLast();
    _undoStack.add(action);

    return action.documentAfter;
  }

  /// Clear all history
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }

  /// Get description of last action
  String? getLastActionDescription() {
    if (_undoStack.isEmpty) return null;

    final action = _undoStack.last;
    switch (action.type) {
      case JournalActionType.textEdit:
        return 'Text edit';
      case JournalActionType.drawStroke:
        return 'Drawing';
      case JournalActionType.highlightStroke:
        return 'Highlight';
    }
  }

  /// Update the last action with the final document state
  void updateLastAction(JournalDocument? after) {
    if (_undoStack.isNotEmpty) {
      final lastAction = _undoStack.last;
      _undoStack[_undoStack.length - 1] = JournalAction(
        type: lastAction.type,
        documentBefore: lastAction.documentBefore,
        documentAfter: after,
        timestamp: lastAction.timestamp,
      );
    }
  }
}
