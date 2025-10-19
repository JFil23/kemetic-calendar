// ============================================================================
// IMPLEMENTATION GUIDE
// ============================================================================
// FILE: lib/features/journal/journal_constants.dart
// PURPOSE: Configuration constants for journal gestures and UI
// 
// STEPS TO IMPLEMENT:
// 1. Create directory: lib/features/journal/
// 2. Create file: lib/features/journal/journal_constants.dart
// 3. Copy and paste this ENTIRE file
// 4. No modifications needed initially
//
// TUNING GUIDE:
// If gestures feel too sensitive/insensitive, adjust these values:
// - kJournalSwipeDominance: Higher = harder to trigger (less accidental opens)
// - kJournalSwipeMinDelta: Higher = need longer swipe to trigger
// - kJournalSwipeMinVelocity: Higher = need faster flick to trigger
// - kJournalCloseTravelFraction: Higher = need to drag further to close
//
// Test on real devices before changing - these are tuned for good feel!
//
// WHAT THIS DOES:
// - Defines gesture detection thresholds
// - Sets autosave timing (500ms debounce)
// - Configures UI dimensions and colors
// - All in one place for easy tweaking
// ============================================================================

// lib/features/journal/journal_constants.dart

/// Gesture thresholds for journal overlay open/close
/// Tuned for smooth, conflict-free gestures with text scrolling

// Directional dominance: |primary| must be > |secondary| * dominance
const double kJournalSwipeDominance = 1.6;

// Minimum delta (pixels) to trigger open/close
const double kJournalSwipeMinDelta = 48.0;

// Minimum velocity (px/s) for flick-to-close
const double kJournalSwipeMinVelocity = 600.0;

// Fraction of overlay span to commit close (33% of width/height)
const double kJournalCloseTravelFraction = 0.33;

// Autosave debounce delay (milliseconds)
const int kJournalAutosaveDebounceMs = 500;

// Highlight animation duration for appended content
const int kJournalHighlightDurationMs = 1500;

// Overlay sizes (percentage of screen)
const double kJournalPortraitWidthFraction = 0.92;
const double kJournalLandscapeHeightFraction = 0.70;

// Highlight color for appended content (pale gold)
const int kJournalHighlightColor = 0x40D4AF37; // 25% opacity gold
