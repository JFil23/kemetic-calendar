// ============================================================================
// IMPLEMENTATION GUIDE
// ============================================================================
// FILE: lib/features/calendar/daily_review_handler.dart
// PURPOSE: Helper for Phase 1.1 daily review notification integration
// 
// STEPS TO IMPLEMENT:
// 1. Create file: lib/features/calendar/daily_review_handler.dart
// 2. Copy and paste this ENTIRE file
// 3. Don't integrate yet - wait for Phase 1.1 per-flow notifications
//
// ⚠️ PHASE DEPENDENCY:
// This is a HELPER for Phase 1.1 (per-flow notification options).
// The journal core feature works WITHOUT this file.
// Only integrate when implementing Phase 1.1's daily review notifications.
//
// WHEN TO USE (Phase 1.1):
// When the daily review notification fires, call:
//
//   final handler = DailyReviewHandler(_journalController);
//   
//   // Check if there's content to add
//   final content = handler.checkForDailyReviewContent(
//     completedFlows: ['Morning Routine', 'Exercise'],
//     completedTasks: ['Meditation', 'Run 5k'],
//   );
//   
//   if (content != null) {
//     // Show "Review your day?" alert
//     // If user taps "Add to journal":
//     final position = await handler.addToJournal(content);
//   }
//
// WHAT THIS DOES:
// - Formats completed tasks into "✅ Wins:" block
// - Returns null if no content (so alert doesn't show)
// - Appends to journal when user confirms
// - Returns append position for highlight animation
//
// INTEGRATION WITH PHASE 1.4:
// Phase 1.4 adds swipe-to-complete for flows.
// You'll need to track completion state and pass to this handler.
// ============================================================================

// lib/features/calendar/daily_review_handler.dart
// This will be used in Phase 1.1 when per-flow notifications are implemented

import 'package:flutter/foundation.dart';
import '../journal/journal_controller.dart';

class DailyReviewHandler {
  final JournalController _journalController;

  DailyReviewHandler(this._journalController);

  void _log(String msg) {
    if (kDebugMode) {
      debugPrint('[DailyReview] $msg');
    }
  }

  /// Check if daily review should be shown
  /// Returns null if no content, otherwise returns the formatted content
  String? checkForDailyReviewContent({
    required List<String> completedFlows,
    required List<String> completedTasks,
  }) {
    if (completedFlows.isEmpty && completedTasks.isEmpty) {
      _log('No completed items, skipping review');
      return null;
    }

    final buffer = StringBuffer();
    buffer.writeln('✅ Wins:');

    // Add completed flows
    for (final flow in completedFlows) {
      buffer.writeln('• $flow');
    }

    // Add completed tasks
    for (final task in completedTasks) {
      buffer.writeln('• $task');
    }

    final content = buffer.toString().trim();
    _log('Generated review content: ${content.length} chars');
    return content;
  }

  /// Add content to journal (called when user taps "Add to journal")
  /// Returns the position where content was appended (for highlighting)
  Future<int> addToJournal(String content) async {
    _log('Adding to journal: ${content.length} chars');
    final position = await _journalController.appendToToday(content);
    _log('Appended at position $position');
    return position;
  }

  /// Get summary for notification body
  String getNotificationBody({
    required int completedFlowsCount,
    required int completedTasksCount,
  }) {
    final total = completedFlowsCount + completedTasksCount;
    if (total == 0) return '';
    
    if (total == 1) {
      return 'You completed 1 task today.';
    }
    
    return 'You completed $total tasks today.';
  }
}
