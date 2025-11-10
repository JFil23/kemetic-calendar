class FeatureFlags {
  // =========================================================================
  // PHASE 1: DOCUMENT MODEL (START HERE)
  // =========================================================================
  
  /// Enable V2 document model (invisible to users, just data format)
  /// Set to TRUE to start Phase 1
  static const bool enableV2DocumentModel = true;  // ← PHASE 1 ENABLED
  
  // =========================================================================
  // PHASE 2: RICH TEXT (ENABLE AFTER PHASE 1 WORKS)
  // =========================================================================
  
  /// Enable rich text toolbar and formatting
  /// Set to TRUE to start Phase 2
  static const bool enableRichText = true;  // ← PHASE 2 ENABLED
  
  // =========================================================================
  // PHASE 3: DRAWING + CHARTS (ENABLE AFTER PHASE 2 WORKS)
  // =========================================================================
  
  /// Enable drawing canvas (pen + highlighter + eraser)
  /// Set to TRUE to start Phase 3
  static const bool enableDrawing = true;  // ← PHASE 3 ENABLED
  
  /// Enable chart insertion
  /// Set to TRUE to start Phase 3
  static const bool enableCharts = false;  // ← SET TO TRUE FOR PHASE 3
  
  // =========================================================================
  // PHASE 4: POLISH (OPTIONAL - NOT IN THIS ARTIFACT)
  // =========================================================================
  
  /// Enable undo/redo
  static const bool enableUndoRedo = false;
  
  // =========================================================================
  // NUTRITION FEATURE
  // =========================================================================
  
  /// Enable nutrition grid and scheduling feature
  /// Set to TRUE to enable the Nutrition tab in the journal overlay
  static const bool enableNutrition = true;  // ← ENABLED
  
  // =========================================================================
  // DEBUG FLAGS
  // =========================================================================
  
  /// Show verbose V2 logs
  static const bool journalV2DebugMode = true;  // ← SET TO FALSE IN PRODUCTION
  
  // =========================================================================
  // HELPER METHODS
  // =========================================================================
  
  /// Check if V2 is active
  static bool get isJournalV2Active => enableV2DocumentModel;
  
  /// Check if rich text should be shown
  static bool get hasRichText => isJournalV2Active && enableRichText;
  
  /// Check if drawing should be shown
  static bool get hasDrawing => isJournalV2Active && enableDrawing;
  
  /// Check if charts should be shown
  static bool get hasCharts => isJournalV2Active && enableCharts;
  
  /// Check if nutrition feature is enabled
  static bool get hasNutrition => enableNutrition;
  
  /// Get enabled features (for analytics)
  static List<String> get enabledFeatures {
    final features = <String>[];
    if (enableV2DocumentModel) features.add('v2_document_model');
    if (enableRichText) features.add('rich_text');
    if (enableDrawing) features.add('drawing');
    if (enableCharts) features.add('charts');
    if (enableUndoRedo) features.add('undo_redo');
    if (enableNutrition) features.add('nutrition');
    return features;
  }
}