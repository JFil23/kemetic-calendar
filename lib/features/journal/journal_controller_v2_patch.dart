// ============================================================================
// JOURNAL CONTROLLER V2 INTEGRATION PATCH
// ============================================================================
// FILE: lib/features/journal/journal_controller_v2_patch.dart
// PURPOSE: Shows exact changes needed to upgrade JournalController to V2
//
// INSTRUCTIONS:
// 1. Copy the imports and classes from journal_v2_document_model.dart
// 2. Apply the changes marked with "// V2 ADD" and "// V2 REPLACE"
// 3. Keep all existing V1 functionality working
// 4. V2 features only activate when FeatureFlags.journalV2Enabled = true
// ============================================================================

// STEP 1: Add these imports to the top of journal_controller.dart
// V2 ADD: Import document model and feature flags
import '../../core/feature_flags.dart';
import 'journal_v2_document_model.dart';

// STEP 2: Add these fields to JournalController class (after existing fields)
// V2 ADD: Document model support
JournalDocument? _currentDocument;
bool _isDocumentMode = false;

// STEP 3: Replace the init() method with this enhanced version
// V2 REPLACE: Enhanced init method with document support
Future<void> init() async {
  _log('init: starting (V2 enabled: ${FeatureFlags.isJournalV2Active})');
  
  if (FeatureFlags.isJournalV2Active) {
    await _loadDocumentForToday();
  } else {
    await _loadDraftForToday(); // Keep V1 behavior
  }
  
  await finalizeYesterdayIfNeeded();
  _log('init: complete');
}

// STEP 4: Add this new method for V2 document loading
// V2 ADD: Load document for today
Future<void> _loadDocumentForToday() async {
  final today = _today;
  _currentDate = today;
  _isDocumentMode = true;

  // Try local storage first
  final prefs = await SharedPreferences.getInstance();
  final localDocJson = prefs.getString('document:$_todayKey');

  if (localDocJson != null && localDocJson.isNotEmpty) {
    try {
      final docMap = jsonDecode(localDocJson) as Map<String, dynamic>;
      _currentDocument = JournalDocument.fromJson(docMap);
      _currentDraft = _documentToPlainText(_currentDocument!);
      _log('_loadDocumentForToday: loaded from local storage (${_currentDraft.length} chars)');
      onDraftChanged?.call();
      return;
    } catch (e) {
      _log('_loadDocumentForToday: local JSON corrupted, falling back to server');
    }
  }

  // Fallback to server
  try {
    final entry = await _repo.getByDate(today);
    if (entry != null) {
      // Check if entry is already a document
      if (entry.body.startsWith('{') && entry.body.contains('"version"')) {
        // It's a document
        final docMap = jsonDecode(entry.body) as Map<String, dynamic>;
        _currentDocument = JournalDocument.fromJson(docMap);
        _currentDraft = _documentToPlainText(_currentDocument!);
        _log('_loadDocumentForToday: loaded document from server (${_currentDraft.length} chars)');
      } else {
        // It's plain text - migrate to document
        _currentDocument = JournalDocument.fromPlainText(
          gregDate: _todayKey,
          text: entry.body,
          meta: entry.meta ?? {},
          updatedAt: DateTime.now(),
        );
        _currentDraft = entry.body;
        _log('_loadDocumentForToday: migrated plain text to document (${_currentDraft.length} chars)');
      }
      
      await _saveLocalDocument(); // Cache it locally
    } else {
      // Create new empty document
      _currentDocument = JournalDocument.fromPlainText(
        gregDate: _todayKey,
        text: '',
        meta: {},
        updatedAt: DateTime.now(),
      );
      _currentDraft = '';
      _log('_loadDocumentForToday: no entry found, created new document');
    }
  } catch (e) {
    _log('_loadDocumentForToday error: $e');
    // Fallback to plain text
    _currentDocument = JournalDocument.fromPlainText(
      gregDate: _todayKey,
      text: '',
      meta: {},
      updatedAt: DateTime.now(),
    );
    _currentDraft = '';
  }

  onDraftChanged?.call();
}

// STEP 5: Add these helper methods for document conversion
// V2 ADD: Convert document to plain text for UI
String _documentToPlainText(JournalDocument doc) {
  final buffer = StringBuffer();
  for (final block in doc.blocks) {
    if (block is ParagraphBlock) {
      for (final op in block.ops) {
        buffer.write(op.insert);
      }
    }
  }
  return buffer.toString();
}

// V2 ADD: Convert plain text to document
JournalDocument _plainTextToDocument(String text) {
  if (_currentDocument != null) {
    // Update existing document's first paragraph
    final blocks = List<JournalBlock>.from(_currentDocument!.blocks);
    if (blocks.isNotEmpty && blocks.first is ParagraphBlock) {
      final firstBlock = blocks.first as ParagraphBlock;
      blocks[0] = ParagraphBlock(
        id: firstBlock.id,
        ops: [TextOp(insert: text.isEmpty ? '\n' : text)],
      );
    } else {
      // No paragraph block, create one
      blocks.insert(0, ParagraphBlock(
        id: 'p-${DateTime.now().millisecondsSinceEpoch}',
        ops: [TextOp(insert: text.isEmpty ? '\n' : text)],
      ));
    }
    
    return JournalDocument(
      version: _currentDocument!.version,
      gregDate: _currentDocument!.gregDate,
      blocks: blocks,
      meta: _currentDocument!.meta,
      updatedAt: DateTime.now(),
    );
  } else {
    // Create new document
    return JournalDocument.fromPlainText(
      gregDate: _todayKey,
      text: text,
      meta: {},
      updatedAt: DateTime.now(),
    );
  }
}

// STEP 6: Replace the updateDraft method with this enhanced version
// V2 REPLACE: Enhanced updateDraft with document support
Future<void> updateDraft(String text) async {
  if (_currentDraft == text) return;

  _currentDraft = text;
  _hasUnsavedChanges = true;
  
  if (_isDocumentMode && _currentDocument != null) {
    // Update document
    _currentDocument = _plainTextToDocument(text);
    await _saveLocalDocument();
  } else {
    // Save locally immediately (V1 behavior)
    await _saveLocalDraft();
  }

  // Debounce server save
  _autosaveTimer?.cancel();
  _autosaveTimer = Timer(
    const Duration(milliseconds: kJournalAutosaveDebounceMs),
    _autosave,
  );

  onDraftChanged?.call();
}

// STEP 7: Add this method for saving documents locally
// V2 ADD: Save document to local storage
Future<void> _saveLocalDocument() async {
  if (_currentDocument == null) return;
  
  try {
    final prefs = await SharedPreferences.getInstance();
    final docJson = jsonEncode(_currentDocument!.toJson());
    await prefs.setString('document:$_todayKey', docJson);
    await prefs.setString('lastOpenDay', _todayKey);
    _log('_saveLocalDocument: ✓ cached locally');
  } catch (e) {
    _log('_saveLocalDocument error: $e');
  }
}

// STEP 8: Replace the _autosave method with this enhanced version
// V2 REPLACE: Enhanced autosave with document support
Future<void> _autosave() async {
  if (!_hasUnsavedChanges) return;

  try {
    _log('_autosave: saving to server (${_currentDraft.length} chars)');
    
    String bodyToSave;
    Map<String, dynamic> metaToSave = {
      'chars': _currentDraft.length,
      'last_autosave': DateTime.now().toUtc().toIso8601String(),
    };
    
    if (_isDocumentMode && _currentDocument != null) {
      // Save as document
      bodyToSave = jsonEncode(_currentDocument!.toJson());
      metaToSave['document_version'] = _currentDocument!.version;
      metaToSave['block_count'] = _currentDocument!.blocks.length;
    } else {
      // Save as plain text (V1 behavior)
      bodyToSave = _currentDraft;
    }
    
    await _repo.upsert(
      localDate: _currentDate ?? _today,
      body: bodyToSave,
      meta: metaToSave,
    );

    _hasUnsavedChanges = false;
    _log('_autosave: ✓ saved to server');
    
    // Track autosave event
    Events.trackIfAuthed('journal_autosave', {
      'chars': _currentDraft.length,
      'appended_block': false,
      'document_mode': _isDocumentMode,
    });
  } catch (e) {
    _log('_autosave error: $e (will retry later)');
    // Keep _hasUnsavedChanges = true so it retries
  }
}

// STEP 9: Add these new methods for V2 features
// V2 ADD: Get current document (for toolbar/UI)
JournalDocument? get currentDocument => _currentDocument;

// V2 ADD: Update document directly (for rich text editing)
Future<void> updateDocument(JournalDocument document) async {
  if (_currentDocument == document) return;
  
  _currentDocument = document;
  _currentDraft = _documentToPlainText(document);
  _hasUnsavedChanges = true;
  
  await _saveLocalDocument();
  
  // Debounce server save
  _autosaveTimer?.cancel();
  _autosaveTimer = Timer(
    const Duration(milliseconds: kJournalAutosaveDebounceMs),
    _autosave,
  );

  onDraftChanged?.call();
}

// V2 ADD: Append content to document (for daily review)
Future<int> appendToDocument(String content) async {
  if (content.trim().isEmpty) return 0;
  
  if (_isDocumentMode && _currentDocument != null) {
    // Append to last paragraph block
    final blocks = List<JournalBlock>.from(_currentDocument!.blocks);
    if (blocks.isNotEmpty && blocks.last is ParagraphBlock) {
      final lastBlock = blocks.last as ParagraphBlock;
      final newOps = List<TextOp>.from(lastBlock.ops);
      newOps.add(TextOp(insert: '\n\n$content'));
      
      blocks[blocks.length - 1] = ParagraphBlock(
        id: lastBlock.id,
        ops: newOps,
      );
      
      _currentDocument = JournalDocument(
        version: _currentDocument!.version,
        gregDate: _currentDocument!.gregDate,
        blocks: blocks,
        meta: _currentDocument!.meta,
        updatedAt: DateTime.now(),
      );
      
      _currentDraft = _documentToPlainText(_currentDocument!);
      await updateDocument(_currentDocument!);
      
      return _currentDraft.length - content.length;
    }
  }
  
  // Fallback to plain text append
  return await appendToToday(content);
}

// STEP 10: Update dispose method
// V2 REPLACE: Enhanced dispose with document cleanup
void dispose() {
  _autosaveTimer?.cancel();
  _currentDocument = null;
  _isDocumentMode = false;
}
