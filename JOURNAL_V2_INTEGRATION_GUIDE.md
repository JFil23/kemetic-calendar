# Journal V2 Integration Guide

## 🎯 **Overview**

This guide shows you exactly how to integrate Journal V2 into your existing working journal. The integration is designed to be **safe** and **gradual** - your V1 journal keeps working while V2 features are added incrementally.

## 📋 **Integration Steps**

### **Step 1: Add Feature Flags (2 minutes)**

1. **Create** `lib/core/feature_flags.dart` (already created above)
2. **Start with all flags FALSE** - this keeps V1 behavior
3. **Enable flags incrementally** as you test each feature

### **Step 2: Update JournalController (10 minutes)**

1. **Add imports** to `journal_controller.dart`:
   ```dart
   import '../../core/feature_flags.dart';
   import 'journal_v2_document_model.dart';
   ```

2. **Add fields** to `JournalController` class:
   ```dart
   JournalDocument? _currentDocument;
   bool _isDocumentMode = false;
   ```

3. **Replace methods** with the enhanced versions from `journal_controller_v2_patch.dart`

4. **Test**: Your journal should work exactly the same (V1 behavior)

### **Step 3: Update JournalOverlay (5 minutes)**

1. **Add imports** to `journal_overlay.dart`:
   ```dart
   import '../../core/feature_flags.dart';
   import 'journal_v2_toolbar.dart';
   import 'journal_v2_document_model.dart';
   ```

2. **Replace methods** with the enhanced versions from `journal_overlay_v2_patch.dart`

3. **Test**: Your journal should work exactly the same (V1 behavior)

### **Step 4: Test V1 Still Works (2 minutes)**

1. **Hot reload** your app
2. **Swipe L→R** to open journal
3. **Type some text** and close
4. **Reopen** - text should still be there
5. **Verify** no errors in console

### **Step 5: Enable V2 Document Mode (5 minutes)**

1. **Change** `journalV2Enabled = true` in `feature_flags.dart`
2. **Hot reload** your app
3. **Test**: Journal should work the same, but now uses document model internally
4. **Check console** for V2 debug messages

### **Step 6: Run Migration (5 minutes)**

1. **Add** this to your app's init or a debug button:
   ```dart
   final migration = JournalV2Migration(Supabase.instance.client);
   final result = await migration.migrateAllEntries();
   print('Migration result: ${result.message}');
   ```

2. **Run** the migration script
3. **Verify** existing entries are converted to documents

### **Step 7: Enable Rich Text (10 minutes)**

1. **Change** `journalV2RichText = true` in `feature_flags.dart`
2. **Hot reload** your app
3. **Test**: Toolbar should appear with B/I/U/S buttons
4. **Test**: Text formatting should work

### **Step 8: Enable Drawing (15 minutes)**

1. **Change** `journalV2Drawing = true` in `feature_flags.dart`
2. **Hot reload** your app
3. **Test**: Draw/Highlight modes should be available
4. **Test**: Drawing should work

### **Step 9: Enable Charts (10 minutes)**

1. **Change** `journalV2Charts = true` in `feature_flags.dart`
2. **Hot reload** your app
3. **Test**: Chart insertion should work
4. **Test**: Charts should render

## 🔧 **Testing Checklist**

### **V1 Compatibility Test**
- [ ] Journal opens with L→R swipe
- [ ] Text editing works
- [ ] Autosave works (500ms debounce)
- [ ] Day rollover works
- [ ] Analytics events fire
- [ ] No console errors

### **V2 Document Mode Test**
- [ ] Journal opens with L→R swipe
- [ ] Text editing works
- [ ] Autosave works (now saves as JSON)
- [ ] Day rollover works
- [ ] Migration script runs successfully
- [ ] Existing entries converted to documents
- [ ] No console errors

### **V2 Rich Text Test**
- [ ] Toolbar appears
- [ ] B/I/U/S buttons work
- [ ] Text formatting persists
- [ ] Autosave works with formatted text
- [ ] No console errors

### **V2 Drawing Test**
- [ ] Draw mode works
- [ ] Highlight mode works
- [ ] Strokes are saved
- [ ] Drawing persists
- [ ] No console errors

### **V2 Charts Test**
- [ ] Chart insertion works
- [ ] Charts render correctly
- [ ] Chart data persists
- [ ] No console errors

## 🚨 **Rollback Plan**

If anything breaks:

1. **Set all flags to FALSE** in `feature_flags.dart`
2. **Hot reload** - should return to V1 behavior
3. **Check console** for errors
4. **Report issues** with specific error messages

## 📊 **Feature Flag States**

### **Development Mode**
```dart
static const bool journalV2Enabled = true;
static const bool journalV2RichText = false;
static const bool journalV2Drawing = false;
static const bool journalV2Charts = false;
static const bool journalV2DebugMode = true;
```

### **Production Mode (Phase 1)**
```dart
static const bool journalV2Enabled = true;
static const bool journalV2RichText = true;
static const bool journalV2Drawing = false;
static const bool journalV2Charts = false;
static const bool journalV2DebugMode = false;
```

### **Production Mode (Full V2)**
```dart
static const bool journalV2Enabled = true;
static const bool journalV2RichText = true;
static const bool journalV2Drawing = true;
static const bool journalV2Charts = true;
static const bool journalV2DebugMode = false;
```

## 🎯 **Success Criteria**

- [ ] V1 journal works perfectly (no regressions)
- [ ] V2 document mode works (invisible to users)
- [ ] V2 rich text works (visible toolbar)
- [ ] V2 drawing works (draw/highlight modes)
- [ ] V2 charts work (chart insertion)
- [ ] Migration script runs successfully
- [ ] Zero compilation errors
- [ ] Zero runtime errors
- [ ] All existing functionality preserved

## 🚀 **Next Steps**

After successful integration:

1. **Test thoroughly** with all flags enabled
2. **Deploy to staging** environment
3. **Get user feedback** on V2 features
4. **Iterate and improve** based on feedback
5. **Deploy to production** when ready

The integration is designed to be **safe** and **reversible** - you can always roll back to V1 by setting flags to FALSE.
