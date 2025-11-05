// ============================================================================
// IMPLEMENTATION GUIDE
// ============================================================================
// FILE: lib/core/ui_guards.dart
// PURPOSE: Global state guard to prevent gesture conflicts
// 
// STEPS TO IMPLEMENT:
// 1. Create directory (if needed): lib/core/
// 2. Create file: lib/core/ui_guards.dart
// 3. Copy and paste this ENTIRE file
// 4. No modifications needed
//
// HOW TO USE:
// Whenever you open a Flow Runner, event sheet, or any overlay:
//
//   UiGuards.disableJournalSwipe();
//   Navigator.push(...).then((_) {
//     UiGuards.enableJournalSwipe(); // Re-enable when closed
//   });
//
// WHAT THIS DOES:
// - Prevents journal from opening when other overlays are active
// - Avoids confusing gesture conflicts
// - Simple boolean flag, no complex state management
//
// INTEGRATION POINTS:
// You'll need to add guards to:
// - Flow Runner (when implemented in Phase 1.3)
// - Event detail sheets
// - Flow preview cards
// - ICS preview cards
// - Any fullscreen overlay
// ============================================================================

// lib/core/ui_guards.dart

/// Global UI state guards to prevent conflicting gestures
/// Used to disable journal swipes when overlays/runners are active
class UiGuards {
  static bool _canOpenJournalSwipe = true;

  /// Check if journal swipe gestures are allowed
  static bool get canOpenJournalSwipe => _canOpenJournalSwipe;

  /// Enable journal swipe gestures
  static void enableJournalSwipe() {
    _canOpenJournalSwipe = true;
  }

  /// Disable journal swipe gestures (when overlay/runner is open)
  static void disableJournalSwipe() {
    _canOpenJournalSwipe = false;
  }
}

