// ============================================================================
// IMPLEMENTATION GUIDE
// ============================================================================
// FILE: lib/features/journal/journal_constants.dart
// PURPOSE: Configuration constants for journal timing and UI
//
// STEPS TO IMPLEMENT:
// 1. Create directory: lib/features/journal/
// 2. Create file: lib/features/journal/journal_constants.dart
// 3. Copy and paste this ENTIRE file
// 4. No modifications needed initially
//
// WHAT THIS DOES:
// - Sets autosave timing (500ms debounce)
// - Configures UI dimensions and colors
// - All in one place for easy tweaking
// ============================================================================

// lib/features/journal/journal_constants.dart

// Autosave debounce delay (milliseconds)
const int kJournalAutosaveDebounceMs = 500;

// Highlight animation duration for appended content
const int kJournalHighlightDurationMs = 1500;

// Overlay sizes (percentage of screen)
const double kJournalPortraitWidthFraction = 0.92;
const double kJournalLandscapeHeightFraction = 0.70;

// Highlight color for appended content (pale gold)
const int kJournalHighlightColor = 0x40D4AF37; // 25% opacity gold

// Close thresholds for different orientations
const double kJournalPortraitCloseThreshold = 0.33;
const double kJournalLandscapeCloseThreshold = 0.33;
