import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/journal_repo.dart';
import '../../core/feature_flags.dart';
import 'journal_v2_document_model.dart';
import 'journal_constants.dart';
import '../../main.dart';

class JournalController {
  final JournalRepo _repo;
  final SupabaseClient _client;
  
  Timer? _autosaveTimer;
  String _currentDraft = '';
  DateTime? _currentDate;
  bool _hasUnsavedChanges = false;
  
  // V2 ADDITIONS
  JournalDocument? _currentDocument;
  bool _isDocumentMode = false;
  
  // Callbacks for UI updates
  void Function()? onDraftChanged;
  
  JournalController(this._client) : _repo = JournalRepo(_client);

  void _log(String msg) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      print('[JournalController $timestamp] $msg');
    }
  }

  /// Get the local date key for today
  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String get _todayKey {
    final d = _today;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Initialize controller - load today's draft
  Future<void> init() async {
    _log('init: starting (V2 enabled: ${FeatureFlags.isJournalV2Active})');
    
    if (FeatureFlags.isJournalV2Active) {
      await _loadDocumentForToday();
    } else {
      await _loadDraftForToday();
    }
    
    await finalizeYesterdayIfNeeded();
    _log('init: complete');
  }

  /// Load draft for today (V1 behavior)
  Future<void> _loadDraftForToday() async {
    final today = _today;
    _currentDate = today;

    // Try local storage first
    final prefs = await SharedPreferences.getInstance();
    final localDraft = prefs.getString('draft:$_todayKey');

    if (localDraft != null && localDraft.isNotEmpty) {
      _currentDraft = localDraft;
      _log('_loadDraftForToday: loaded from local storage (${_currentDraft.length} chars)');
      onDraftChanged?.call();
      return;
    }

    // Fallback to server
    try {
      final entry = await _repo.getByDate(today);
      if (entry != null) {
        _currentDraft = entry.body;
        await _saveLocalDraft();
        _log('_loadDraftForToday: loaded from server (${_currentDraft.length} chars)');
      } else {
        _currentDraft = '';
        _log('_loadDraftForToday: no entry found, starting fresh');
      }
    } catch (e) {
      _log('_loadDraftForToday error: $e');
      _currentDraft = '';
    }

    onDraftChanged?.call();
  }

  /// Load document for today (V2 behavior)
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
          _currentDocument = JournalDocument.fromPlainText(entry.body);
          _currentDraft = entry.body;
          _log('_loadDocumentForToday: migrated plain text to document (${_currentDraft.length} chars)');
        }
        
        await _saveLocalDocument();
      } else {
        // Create new empty document
        _currentDocument = JournalDocument.fromPlainText('');
        _currentDraft = '';
        _log('_loadDocumentForToday: no entry found, created new document');
      }
    } catch (e) {
      _log('_loadDocumentForToday error: $e');
      // Fallback to empty document
      _currentDocument = JournalDocument.fromPlainText('');
      _currentDraft = '';
    }

    onDraftChanged?.call();
  }

  /// Convert document to plain text for UI
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

  /// Convert plain text to document
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
        blocks: blocks,
        meta: _currentDocument!.meta,
      );
    } else {
      // Create new document
      return JournalDocument.fromPlainText(text);
    }
  }

  /// Get current draft text
  String get currentDraft => _currentDraft;

  /// Get current document (V2)
  JournalDocument? get currentDocument => _currentDocument;

  /// Update draft text and trigger autosave
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

  /// Update document directly (V2)
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

  /// Save draft to local storage (V1)
  Future<void> _saveLocalDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('draft:$_todayKey', _currentDraft);
      await prefs.setString('lastOpenDay', _todayKey);
      _log('_saveLocalDraft: ✓ cached locally');
    } catch (e) {
      _log('_saveLocalDraft error: $e');
    }
  }

  /// Save document to local storage (V2)
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

  /// Autosave to server (debounced)
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

  /// Force save immediately (on overlay close)
  Future<void> forceSave() async {
    _autosaveTimer?.cancel();
    if (_hasUnsavedChanges) {
      await _autosave();
    }
  }

  /// Finalize yesterday's entry if we detected a day rollover
  Future<void> finalizeYesterdayIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastOpenDay = prefs.getString('lastOpenDay');
      
      if (lastOpenDay == null || lastOpenDay == _todayKey) {
        _log('finalizeYesterdayIfNeeded: no rollover detected');
        return;
      }

      _log('finalizeYesterdayIfNeeded: detected rollover from $lastOpenDay to $_todayKey');

      // Load yesterday's draft/document from local storage
      String? yesterdayContent;
      
      if (_isDocumentMode) {
        yesterdayContent = prefs.getString('document:$lastOpenDay');
      } else {
        yesterdayContent = prefs.getString('draft:$lastOpenDay');
      }
      
      if (yesterdayContent != null && yesterdayContent.isNotEmpty) {
        final parts = lastOpenDay.split('-');
        final yesterdayDate = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );

        // Finalize to server
        await _repo.upsert(
          localDate: yesterdayDate,
          body: yesterdayContent,
          meta: {
            'chars': yesterdayContent.length,
            'finalized': true,
            'finalized_at': DateTime.now().toUtc().toIso8601String(),
          },
        );

        // Clean up old local draft/document
        if (_isDocumentMode) {
          await prefs.remove('document:$lastOpenDay');
        } else {
          await prefs.remove('draft:$lastOpenDay');
        }
        
        _log('finalizeYesterdayIfNeeded: ✓ finalized $lastOpenDay');
      }

      // Update last open day
      await prefs.setString('lastOpenDay', _todayKey);
    } catch (e) {
      _log('finalizeYesterdayIfNeeded error: $e');
    }
  }

  /// Append content to today's journal (for daily review integration)
  Future<int> appendToToday(String content) async {
    if (content.trim().isEmpty) return 0;

    if (_isDocumentMode && _currentDocument != null) {
      return await appendToDocument(content);
    }

    final appendPosition = _currentDraft.length;
    final newText = _currentDraft.isEmpty
        ? content
        : '$_currentDraft\n\n$content';

    await updateDraft(newText);
    
    _log('appendToToday: appended ${content.length} chars at position $appendPosition');
    return appendPosition;
  }

  /// Append content to document (V2)
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
          blocks: blocks,
          meta: _currentDocument!.meta,
        );
        
        _currentDraft = _documentToPlainText(_currentDocument!);
        await updateDocument(_currentDocument!);
        
        return _currentDraft.length - content.length;
      }
    }
    
    // Fallback to plain text append
    return await appendToToday(content);
  }

  /// Dispose controller
  void dispose() {
    _autosaveTimer?.cancel();
    _currentDocument = null;
    _isDocumentMode = false;
  }
}