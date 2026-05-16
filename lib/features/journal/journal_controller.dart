import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/journal_repo.dart';
import '../../core/feature_flags.dart';
import 'journal_v2_document_model.dart';
import 'journal_constants.dart';
import 'journal_badge_utils.dart';
import '../../main.dart';

enum JournalSyncStatus { synced, unsavedLocal, saving, saveFailed }

class JournalController {
  final JournalRepo _repo;
  final String? Function() _currentUserId;

  Timer? _autosaveTimer;
  String _currentDraft = '';
  DateTime? _currentDate;
  bool _hasUnsavedChanges = false;
  JournalSyncStatus _syncStatus = JournalSyncStatus.synced;
  Object? _lastSyncError;

  // V2 ADDITIONS
  JournalDocument? _currentDocument;
  bool _isDocumentMode = false;

  // Callbacks for UI updates
  void Function()? onDraftChanged;
  void Function()? onSyncStatusChanged;

  JournalController(SupabaseClient client)
    : _repo = JournalRepo(client),
      _currentUserId = (() => client.auth.currentUser?.id);

  @visibleForTesting
  JournalController.withRepo(this._repo, {String? Function()? currentUserId})
    : _currentUserId = currentUserId ?? (() => null);

  void _log(String msg) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      debugPrint('[JournalController $timestamp] $msg');
    }
  }

  /// Get the local date key for today
  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Current journal date (local, no time). Defaults to today after init.
  DateTime? get currentDate => _currentDate;

  String get _todayKey {
    final d = _today;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String get _activeDateKey => _formatDate(_currentDate ?? _today);

  bool get canSyncToCloud {
    final userId = _currentUserId()?.trim();
    return userId != null && userId.isNotEmpty;
  }

  String _cacheScopeForUserId(String? userId) {
    final normalized = userId?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return 'user:$normalized';
    }
    return 'local';
  }

  String get _cacheScope => _cacheScopeForUserId(_currentUserId());

  String get _lastOpenDayKey => 'journal:$_cacheScope:lastOpenDay';

  String _cacheKeyForScope(String scope, String kind, String dateKey) =>
      'journal:$scope:$kind:$dateKey';

  String _cacheKey(String kind, String dateKey) =>
      _cacheKeyForScope(_cacheScope, kind, dateKey);

  String _draftKey(String dateKey) => _cacheKey('draft', dateKey);

  String _documentKey(String dateKey) => _cacheKey('document', dateKey);

  String _draftDirtyKey(String dateKey) => _cacheKey('draft_dirty', dateKey);

  String _documentDirtyKey(String dateKey) =>
      _cacheKey('document_dirty', dateKey);

  String _draftModifiedKey(String dateKey) =>
      _cacheKey('draft_modified_at', dateKey);

  String _documentModifiedKey(String dateKey) =>
      _cacheKey('document_modified_at', dateKey);

  String _localDraftKey(String dateKey) =>
      _cacheKeyForScope('local', 'draft', dateKey);

  String _localDocumentKey(String dateKey) =>
      _cacheKeyForScope('local', 'document', dateKey);

  String _localDraftDirtyKey(String dateKey) =>
      _cacheKeyForScope('local', 'draft_dirty', dateKey);

  String _localDocumentDirtyKey(String dateKey) =>
      _cacheKeyForScope('local', 'document_dirty', dateKey);

  String _localDraftModifiedKey(String dateKey) =>
      _cacheKeyForScope('local', 'draft_modified_at', dateKey);

  String _localDocumentModifiedKey(String dateKey) =>
      _cacheKeyForScope('local', 'document_modified_at', dateKey);

  JournalSyncStatus get syncStatus => _syncStatus;

  Object? get lastSyncError => _lastSyncError;

  bool get hasUnsavedChanges => _hasUnsavedChanges;

  void _setSyncStatus(JournalSyncStatus status, [Object? error]) {
    if (_syncStatus == status && _lastSyncError == error) return;
    _syncStatus = status;
    _lastSyncError = error;
    onSyncStatusChanged?.call();
  }

  DateTime? _parsePrefsDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  bool _shouldPreferDirtyLocal({
    required bool localDirty,
    required DateTime? localModifiedAt,
    required JournalEntry? serverEntry,
  }) {
    if (!localDirty) return false;
    if (serverEntry == null) return true;
    if (localModifiedAt == null) return false;
    return !localModifiedAt.isBefore(serverEntry.updatedAt.toUtc());
  }

  Future<void> _setLocalDirty({
    required SharedPreferences prefs,
    required String dateKey,
    required bool documentMode,
    required bool dirty,
  }) async {
    final dirtyKey = documentMode
        ? _documentDirtyKey(dateKey)
        : _draftDirtyKey(dateKey);
    final modifiedKey = documentMode
        ? _documentModifiedKey(dateKey)
        : _draftModifiedKey(dateKey);

    await prefs.setBool(dirtyKey, dirty);
    if (dirty) {
      await prefs.setString(
        modifiedKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    }
  }

  Future<void> _markLocalClean({
    required String dateKey,
    required bool documentMode,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _setLocalDirty(
        prefs: prefs,
        dateKey: dateKey,
        documentMode: documentMode,
        dirty: false,
      );
    } catch (e) {
      _log('_markLocalClean error: $e');
    }
  }

  Future<void> _removeLocalScopeDraft(
    SharedPreferences prefs,
    String dateKey,
  ) async {
    await prefs.remove(_localDraftKey(dateKey));
    await prefs.remove(_localDraftDirtyKey(dateKey));
    await prefs.remove(_localDraftModifiedKey(dateKey));
  }

  Future<void> _removeLocalScopeDocument(
    SharedPreferences prefs,
    String dateKey,
  ) async {
    await prefs.remove(_localDocumentKey(dateKey));
    await prefs.remove(_localDocumentDirtyKey(dateKey));
    await prefs.remove(_localDocumentModifiedKey(dateKey));
  }

  String? _dirtyLocalScopeDraft(SharedPreferences prefs, String dateKey) {
    if (!canSyncToCloud || _cacheScope == 'local') return null;
    final dirty = prefs.getBool(_localDraftDirtyKey(dateKey)) ?? false;
    if (!dirty) return null;
    final draft = prefs.getString(_localDraftKey(dateKey));
    if (draft == null || draft.isEmpty) return null;
    return draft;
  }

  JournalDocument? _dirtyLocalScopeDocument(
    SharedPreferences prefs,
    String dateKey,
  ) {
    if (!canSyncToCloud || _cacheScope == 'local') return null;
    final dirty = prefs.getBool(_localDocumentDirtyKey(dateKey)) ?? false;
    if (!dirty) return null;
    final docJson = prefs.getString(_localDocumentKey(dateKey));
    if (docJson == null || docJson.isEmpty) return null;
    try {
      final docMap = jsonDecode(docJson) as Map<String, dynamic>;
      return JournalDocument.fromJson(docMap);
    } catch (e) {
      _log('_dirtyLocalScopeDocument: local JSON corrupted: $e');
      return null;
    }
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(
      const Duration(milliseconds: kJournalAutosaveDebounceMs),
      () => unawaited(_autosave()),
    );
  }

  /// Initialize controller - load today's draft
  Future<void> init() async {
    _log('init: starting (V2 enabled: ${FeatureFlags.isJournalV2Active})');

    await reloadToday();
    await finalizeYesterdayIfNeeded();
    _log('init: complete');
  }

  /// Reload today's entry from the server/cache decision path.
  ///
  /// Clean local cache never blocks server data. Dirty local edits still win
  /// when they are newer than the server row or when no server row is
  /// reachable, so this is safe to call when returning from another route.
  Future<void> reloadToday() async {
    _log(
      'reloadToday: starting (V2 enabled: ${FeatureFlags.isJournalV2Active})',
    );

    if (_hasUnsavedChanges) {
      final saved = await forceSave();
      if (!saved && _hasUnsavedChanges) {
        _log('reloadToday: skipped reload because local changes are unsaved');
        return;
      }
    }

    if (FeatureFlags.isJournalV2Active) {
      await _loadDocumentForToday();
    } else {
      await _loadDraftForToday();
    }

    _log('reloadToday: complete');
  }

  Future<void> _applyDocument(
    JournalDocument doc, {
    bool saveLocal = false,
    bool markDirty = false,
  }) async {
    final normalized = JournalBadgeUtils.normalizeDocument(doc);
    _currentDocument = normalized;
    _currentDraft = _documentToPlainText(normalized);

    if (saveLocal) {
      await _saveLocalDocument(markDirty: markDirty);
    }
  }

  /// Load draft for today (V1 behavior)
  Future<void> _loadDraftForToday() async {
    final today = _today;
    _currentDate = today;
    _isDocumentMode = false;
    final dateKey = _formatDate(today);

    final prefs = await SharedPreferences.getInstance();
    var localDraft = prefs.getString(_draftKey(dateKey));
    final localDirty = prefs.getBool(_draftDirtyKey(dateKey)) ?? false;
    final localModifiedAt = _parsePrefsDate(
      prefs.getString(_draftModifiedKey(dateKey)),
    );

    JournalEntry? entry;
    var serverReadFailed = false;
    try {
      entry = await _repo.getByDateStrict(today);
    } catch (e) {
      serverReadFailed = true;
      _setSyncStatus(JournalSyncStatus.saveFailed, e);
      _log('_loadDraftForToday server error: $e');
    }

    if (entry == null &&
        !serverReadFailed &&
        (localDraft == null || localDraft.isEmpty)) {
      final localScopeDraft = _dirtyLocalScopeDraft(prefs, dateKey);
      if (localScopeDraft != null) {
        localDraft = localScopeDraft;
        _currentDraft = localScopeDraft;
        _currentDocument = null;
        _hasUnsavedChanges = true;
        await _saveLocalDraft(markDirty: true);
        await _removeLocalScopeDraft(prefs, dateKey);
        _setSyncStatus(JournalSyncStatus.unsavedLocal);
        _scheduleAutosave();
        _log(
          '_loadDraftForToday: imported dirty local-scope draft for signed-in user (${_currentDraft.length} chars)',
        );
        onDraftChanged?.call();
        return;
      }
    }

    if (localDraft != null &&
        localDraft.isNotEmpty &&
        _shouldPreferDirtyLocal(
          localDirty: localDirty,
          localModifiedAt: localModifiedAt,
          serverEntry: entry,
        )) {
      _currentDraft = localDraft;
      _hasUnsavedChanges = true;
      _setSyncStatus(JournalSyncStatus.unsavedLocal);
      _scheduleAutosave();
      _log(
        '_loadDraftForToday: loaded dirty local draft (${_currentDraft.length} chars)',
      );
      onDraftChanged?.call();
      return;
    }

    if (entry != null) {
      _currentDraft = entry.body;
      _currentDocument = null;
      _hasUnsavedChanges = false;
      await _saveLocalDraft(markDirty: false);
      _setSyncStatus(JournalSyncStatus.synced);
      _log(
        '_loadDraftForToday: loaded from server (${_currentDraft.length} chars)',
      );
    } else if (localDraft != null && localDraft.isNotEmpty) {
      _currentDraft = localDraft;
      _hasUnsavedChanges = localDirty;
      if (localDirty) {
        _setSyncStatus(JournalSyncStatus.unsavedLocal);
        _scheduleAutosave();
      } else {
        _setSyncStatus(
          canSyncToCloud
              ? JournalSyncStatus.synced
              : JournalSyncStatus.unsavedLocal,
        );
      }
      _log(
        '_loadDraftForToday: server empty/unavailable, loaded local draft (${_currentDraft.length} chars)',
      );
    } else {
      _currentDraft = '';
      _currentDocument = null;
      _hasUnsavedChanges = false;
      if (!serverReadFailed) {
        _setSyncStatus(JournalSyncStatus.synced);
      }
      _log('_loadDraftForToday: no entry found, starting fresh');
    }

    onDraftChanged?.call();
  }

  /// Load document for today (V2 behavior)
  Future<void> _loadDocumentForToday() async {
    final today = _today;
    _currentDate = today;
    _isDocumentMode = true;
    final dateKey = _formatDate(today);

    final prefs = await SharedPreferences.getInstance();
    final localDocJson = prefs.getString(_documentKey(dateKey));
    final localDirty = prefs.getBool(_documentDirtyKey(dateKey)) ?? false;
    final localModifiedAt = _parsePrefsDate(
      prefs.getString(_documentModifiedKey(dateKey)),
    );
    JournalDocument? localDocument;

    if (localDocJson != null && localDocJson.isNotEmpty) {
      try {
        final docMap = jsonDecode(localDocJson) as Map<String, dynamic>;
        localDocument = JournalDocument.fromJson(docMap);
      } catch (e) {
        _log(
          '_loadDocumentForToday: local JSON corrupted, falling back to server',
        );
      }
    }

    JournalEntry? entry;
    var serverReadFailed = false;
    try {
      entry = await _repo.getByDateStrict(today);
    } catch (e) {
      serverReadFailed = true;
      _setSyncStatus(JournalSyncStatus.saveFailed, e);
      _log('_loadDocumentForToday server error: $e');
    }

    if (entry == null && !serverReadFailed && localDocument == null) {
      final localScopeDocument = _dirtyLocalScopeDocument(prefs, dateKey);
      if (localScopeDocument != null) {
        await _applyDocument(
          localScopeDocument,
          saveLocal: true,
          markDirty: true,
        );
        await _removeLocalScopeDocument(prefs, dateKey);
        _hasUnsavedChanges = true;
        _setSyncStatus(JournalSyncStatus.unsavedLocal);
        _scheduleAutosave();
        _log(
          '_loadDocumentForToday: imported dirty local-scope document for signed-in user (${_currentDraft.length} chars)',
        );
        onDraftChanged?.call();
        return;
      }
    }

    if (localDocument != null &&
        _shouldPreferDirtyLocal(
          localDirty: localDirty,
          localModifiedAt: localModifiedAt,
          serverEntry: entry,
        )) {
      await _applyDocument(localDocument);
      _hasUnsavedChanges = true;
      _setSyncStatus(JournalSyncStatus.unsavedLocal);
      _scheduleAutosave();
      _log(
        '_loadDocumentForToday: loaded dirty local document (${_currentDraft.length} chars)',
      );
      onDraftChanged?.call();
      return;
    }

    if (entry != null) {
      try {
        if (entry.body.startsWith('{') && entry.body.contains('"version"')) {
          final docMap = jsonDecode(entry.body) as Map<String, dynamic>;
          await _applyDocument(JournalDocument.fromJson(docMap));
          _log(
            '_loadDocumentForToday: loaded document from server (${_currentDraft.length} chars)',
          );
        } else {
          // It's plain text - migrate to document
          await _applyDocument(JournalDocument.fromPlainText(entry.body));
          _log(
            '_loadDocumentForToday: migrated plain text to document (${_currentDraft.length} chars)',
          );
        }

        _hasUnsavedChanges = false;
        await _saveLocalDocument(markDirty: false);
        _setSyncStatus(JournalSyncStatus.synced);
      } catch (e) {
        _log('_loadDocumentForToday server parse error: $e');
        if (localDocument != null) {
          await _applyDocument(localDocument);
          _hasUnsavedChanges = localDirty;
          if (localDirty) {
            _setSyncStatus(JournalSyncStatus.unsavedLocal);
            _scheduleAutosave();
          } else {
            _setSyncStatus(JournalSyncStatus.saveFailed, e);
          }
          _log(
            '_loadDocumentForToday: loaded local document after server parse failure',
          );
        } else {
          await _applyDocument(JournalDocument.fromPlainText(''));
          _hasUnsavedChanges = false;
          _setSyncStatus(JournalSyncStatus.saveFailed, e);
        }
      }
    } else if (localDocument != null) {
      await _applyDocument(localDocument);
      _hasUnsavedChanges = localDirty;
      if (localDirty) {
        _setSyncStatus(JournalSyncStatus.unsavedLocal);
        _scheduleAutosave();
      } else {
        _setSyncStatus(
          canSyncToCloud
              ? JournalSyncStatus.synced
              : JournalSyncStatus.unsavedLocal,
        );
      }
      _log(
        '_loadDocumentForToday: server empty/unavailable, loaded local document (${_currentDraft.length} chars)',
      );
    } else {
      await _applyDocument(JournalDocument.fromPlainText(''));
      _hasUnsavedChanges = false;
      if (!serverReadFailed) {
        _setSyncStatus(JournalSyncStatus.synced);
      }
      _log('_loadDocumentForToday: no entry found, created new document');
    }

    onDraftChanged?.call();
  }

  /// Convert document to plain text for UI
  String _documentToPlainText(JournalDocument doc) {
    final buffer = StringBuffer();
    for (final block in doc.blocks) {
      if (block is ParagraphBlock) {
        for (final op in block.ops) {
          buffer.write(JournalBadgeUtils.stripBadges(op.insert));
        }
      }
    }
    return buffer.toString();
  }

  /// Convert plain text to document
  JournalDocument _plainTextToDocument(String text) {
    final cleanedText = JournalBadgeUtils.stripBadges(text);
    if (_currentDocument != null) {
      // Update existing document's first paragraph
      final blocks = List<JournalBlock>.from(_currentDocument!.blocks);
      if (blocks.isNotEmpty && blocks.first is ParagraphBlock) {
        final firstBlock = blocks.first as ParagraphBlock;
        blocks[0] = ParagraphBlock(
          id: firstBlock.id,
          ops: [TextOp(insert: cleanedText.isEmpty ? '\n' : cleanedText)],
        );
      } else {
        // No paragraph block, create one
        blocks.insert(
          0,
          ParagraphBlock(
            id: 'p-${DateTime.now().millisecondsSinceEpoch}',
            ops: [TextOp(insert: cleanedText.isEmpty ? '\n' : cleanedText)],
          ),
        );
      }

      return JournalDocument(
        version: _currentDocument!.version,
        blocks: blocks,
        meta: _currentDocument!.meta,
      );
    } else {
      // Create new document
      return JournalDocument.fromPlainText(cleanedText);
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
    _setSyncStatus(JournalSyncStatus.unsavedLocal);

    if (_isDocumentMode && _currentDocument != null) {
      // Update document
      _currentDocument = _plainTextToDocument(text);
      await _saveLocalDocument(markDirty: true);
    } else {
      // Save locally immediately (V1 behavior)
      await _saveLocalDraft(markDirty: true);
    }

    _scheduleAutosave();

    onDraftChanged?.call();
  }

  /// Update document directly (V2)
  Future<void> updateDocument(JournalDocument document) async {
    final normalized = JournalBadgeUtils.normalizeDocument(document);
    if (_currentDocument == normalized) return;

    _isDocumentMode = true;
    _currentDocument = normalized;
    _currentDraft = _documentToPlainText(normalized);
    _hasUnsavedChanges = true;
    _setSyncStatus(JournalSyncStatus.unsavedLocal);

    await _saveLocalDocument(markDirty: true);

    _scheduleAutosave();

    onDraftChanged?.call();
  }

  /// Save draft to local storage (V1)
  Future<void> _saveLocalDraft({required bool markDirty}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey = _activeDateKey;
      await prefs.setString(_draftKey(dateKey), _currentDraft);
      await prefs.setString(_lastOpenDayKey, dateKey);
      await _setLocalDirty(
        prefs: prefs,
        dateKey: dateKey,
        documentMode: false,
        dirty: markDirty,
      );
      _log('_saveLocalDraft: ✓ cached locally');
    } catch (e) {
      _log('_saveLocalDraft error: $e');
    }
  }

  /// Save document to local storage (V2)
  Future<void> _saveLocalDocument({required bool markDirty}) async {
    if (_currentDocument == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey = _activeDateKey;
      final docJson = jsonEncode(_currentDocument!.toJson());
      await prefs.setString(_documentKey(dateKey), docJson);
      await prefs.setString(_lastOpenDayKey, dateKey);
      await _setLocalDirty(
        prefs: prefs,
        dateKey: dateKey,
        documentMode: true,
        dirty: markDirty,
      );
      _log('_saveLocalDocument: ✓ cached locally');
    } catch (e) {
      _log('_saveLocalDocument error: $e');
    }
  }

  /// Autosave to server (debounced)
  Future<bool> _autosave() async {
    if (!_hasUnsavedChanges) return true;

    try {
      _setSyncStatus(JournalSyncStatus.saving);
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

      final saveDate = _currentDate ?? _today;
      final dateKey = _formatDate(saveDate);
      final documentMode = _isDocumentMode && _currentDocument != null;
      await _repo.upsert(
        localDate: saveDate,
        body: bodyToSave,
        meta: metaToSave,
      );

      _hasUnsavedChanges = false;
      await _markLocalClean(dateKey: dateKey, documentMode: documentMode);
      _setSyncStatus(JournalSyncStatus.synced);
      _log('_autosave: ✓ saved to server');

      // Track autosave event
      try {
        unawaited(
          Events.trackIfAuthed('journal_autosave', {
            'chars': _currentDraft.length,
            'appended_block': false,
            'document_mode': _isDocumentMode,
          }).catchError((Object error, StackTrace stackTrace) {
            _log('_autosave tracking error: $error');
          }),
        );
      } catch (e) {
        _log('_autosave tracking skipped: $e');
      }
      return true;
    } catch (e) {
      _log('_autosave error: $e (will retry later)');
      _setSyncStatus(JournalSyncStatus.saveFailed, e);
      // Keep _hasUnsavedChanges = true so it retries
      return false;
    }
  }

  /// Force save immediately (on overlay close)
  Future<bool> forceSave() async {
    _autosaveTimer?.cancel();
    if (_hasUnsavedChanges) {
      return _autosave();
    }
    return true;
  }

  /// Clear today's entry (draft/document) and persist immediately.
  Future<void> clearToday() async {
    try {
      if (_isDocumentMode) {
        _currentDocument = JournalDocument.fromPlainText('');
        _currentDraft = '';
        _hasUnsavedChanges = true;
        _setSyncStatus(JournalSyncStatus.unsavedLocal);
        await _saveLocalDocument(markDirty: true);
      } else {
        _currentDraft = '';
        _currentDocument = null;
        _hasUnsavedChanges = true;
        _setSyncStatus(JournalSyncStatus.unsavedLocal);
        await _saveLocalDraft(markDirty: true);
      }
      onDraftChanged?.call();
      await _autosave();
    } catch (e) {
      _log('clearToday error: $e');
    }
  }

  /// Finalize yesterday's entry if we detected a day rollover
  Future<void> finalizeYesterdayIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastOpenDay = prefs.getString(_lastOpenDayKey);

      if (lastOpenDay == null || lastOpenDay == _todayKey) {
        _log('finalizeYesterdayIfNeeded: no rollover detected');
        return;
      }

      _log(
        'finalizeYesterdayIfNeeded: detected rollover from $lastOpenDay to $_todayKey',
      );

      // Load yesterday's draft/document from local storage
      String? yesterdayContent;

      if (_isDocumentMode) {
        yesterdayContent = prefs.getString(_documentKey(lastOpenDay));
      } else {
        yesterdayContent = prefs.getString(_draftKey(lastOpenDay));
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
          await prefs.remove(_documentKey(lastOpenDay));
          await prefs.remove(_documentDirtyKey(lastOpenDay));
          await prefs.remove(_documentModifiedKey(lastOpenDay));
        } else {
          await prefs.remove(_draftKey(lastOpenDay));
          await prefs.remove(_draftDirtyKey(lastOpenDay));
          await prefs.remove(_draftModifiedKey(lastOpenDay));
        }

        _log('finalizeYesterdayIfNeeded: ✓ finalized $lastOpenDay');
      }

      // Update last open day
      await prefs.setString(_lastOpenDayKey, _todayKey);
    } catch (e) {
      _log('finalizeYesterdayIfNeeded error: $e');
    }
  }

  /// Append content to today's journal (for daily review integration)
  Future<int> appendToToday(String content) async {
    if (content.trim().isEmpty) return 0;

    final appendPosition = _currentDraft.length;
    final containsBadges = JournalBadgeUtils.hasBadges(content);

    if ((_isDocumentMode && _currentDocument != null) ||
        (containsBadges && FeatureFlags.isJournalV2Active)) {
      _currentDocument ??= JournalDocument.fromPlainText(_currentDraft);
      _isDocumentMode = true;
      final appendedAt = await appendToDocument(content);
      _log(
        'appendToToday: appended ${content.length} chars at position $appendedAt',
      );
      return appendedAt;
    }

    final newText = _currentDraft.isEmpty
        ? content
        : '$_currentDraft\n\n$content';

    await updateDraft(newText);

    _log(
      'appendToToday: appended ${content.length} chars at position $appendPosition',
    );
    return appendPosition;
  }

  /// Append content to document (V2)
  Future<int> appendToDocument(String content) async {
    if (content.trim().isEmpty) return 0;
    final appendStart = _currentDraft.length;

    // Ensure we have a document to append to
    if (!_isDocumentMode || _currentDocument == null) {
      _currentDocument ??= JournalDocument.fromPlainText(_currentDraft);
      _isDocumentMode = true;
    }

    var doc = JournalBadgeUtils.normalizeDocument(_currentDocument!);
    final badgeTokens = JournalBadgeUtils.extractRawTokens(content);
    if (badgeTokens.isNotEmpty) {
      doc = JournalBadgeUtils.mergeBadges(doc, badgeTokens);
    }

    final cleanedContent = JournalBadgeUtils.stripBadges(content).trim();

    if (cleanedContent.isEmpty) {
      await updateDocument(doc);
      return appendStart;
    }

    final blocks = List<JournalBlock>.from(doc.blocks);

    // Find first paragraph block or create one
    int paragraphIndex = blocks.indexWhere((b) => b is ParagraphBlock);
    if (paragraphIndex == -1) {
      blocks.add(
        ParagraphBlock(
          id: 'p-${DateTime.now().millisecondsSinceEpoch}',
          ops: [TextOp(insert: '\n')],
        ),
      );
      paragraphIndex = blocks.length - 1;
    }

    final paragraph = blocks[paragraphIndex] as ParagraphBlock;
    final newOps = List<TextOp>.from(paragraph.ops);
    final needsSpacing =
        newOps.isNotEmpty && !newOps.last.insert.endsWith('\n');
    final insertText = needsSpacing ? '\n\n$cleanedContent' : cleanedContent;
    newOps.add(TextOp(insert: insertText));

    blocks[paragraphIndex] = ParagraphBlock(id: paragraph.id, ops: newOps);

    final newDoc = JournalDocument(
      version: doc.version,
      blocks: blocks,
      meta: doc.meta,
    );

    await updateDocument(newDoc);

    return appendStart;
  }

  /// Load journal entry for a specific date
  /// Used when opening an entry from the archive
  Future<void> loadDate(DateTime date) async {
    try {
      _log('loadDate: loading entry for ${_formatDate(date)}');

      // Update current date
      _currentDate = date;
      final dateKey = _formatDate(date);

      // Try to load from server first
      final entry = await _repo.getByDate(date);

      if (entry != null) {
        _log('loadDate: found entry with ${entry.body.length} chars');

        // Check if it's a V2 document or plain text
        if (entry.body.startsWith('{') && entry.body.contains('"version"')) {
          // V2 document format
          try {
            final docJson = jsonDecode(entry.body) as Map<String, dynamic>;
            await _applyDocument(JournalDocument.fromJson(docJson));
            _isDocumentMode = true;
            _log('loadDate: loaded V2 document');
          } catch (e) {
            _log(
              'loadDate: failed to parse document, falling back to plain text: $e',
            );
            _currentDraft = JournalBadgeUtils.stripBadgesFromPlainText(
              entry.body,
            );
            _currentDocument = null;
            _isDocumentMode = false;
          }
        } else {
          // Plain text format (V1)
          _currentDraft = JournalBadgeUtils.stripBadgesFromPlainText(
            entry.body,
          );
          _currentDocument = null;
          _isDocumentMode = false;
          _log('loadDate: loaded V1 plain text');
        }
      } else {
        // No entry found for this date
        _log('loadDate: no entry found for $dateKey');
        _currentDraft = '';
        _currentDocument = null;
        _isDocumentMode = FeatureFlags.isJournalV2Active;
      }

      // Update local storage tracking
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastOpenDayKey, dateKey);

      _hasUnsavedChanges = false;
      _setSyncStatus(JournalSyncStatus.synced);
      onDraftChanged?.call();

      _log('loadDate: ✓ loaded entry for $dateKey');
    } catch (e) {
      _log('loadDate error: $e');
      // On error, show empty entry
      _currentDraft = '';
      _currentDocument = null;
      _setSyncStatus(JournalSyncStatus.saveFailed, e);
    }
  }

  /// Helper to format date as 'yyyy-mm-dd'
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Dispose controller
  void dispose() {
    if (_hasUnsavedChanges) {
      unawaited(forceSave());
    }
    _autosaveTimer?.cancel();
  }
}
