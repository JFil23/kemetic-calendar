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
import 'journal_event_badge.dart';
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
  Future<void>? _initFuture;
  Future<void>? _reloadTodayFuture;
  int _localEditRevision = 0;
  int _initRunCount = 0;
  int _reloadTodayRunCount = 0;

  // Callbacks for UI updates
  void Function()? onDraftChanged;
  void Function()? onSyncStatusChanged;
  Future<void> Function(List<EventBadgeToken> badges)?
  onCompletionBadgesRemoved;

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

  String _documentKey(String dateKey) => _cacheKey('document', dateKey);

  String _documentDirtyKey(String dateKey) =>
      _cacheKey('document_dirty', dateKey);

  String _documentModifiedKey(String dateKey) =>
      _cacheKey('document_modified_at', dateKey);

  String _localDocumentKey(String dateKey) =>
      _cacheKeyForScope('local', 'document', dateKey);

  String _localDocumentDirtyKey(String dateKey) =>
      _cacheKeyForScope('local', 'document_dirty', dateKey);

  String _localDocumentModifiedKey(String dateKey) =>
      _cacheKeyForScope('local', 'document_modified_at', dateKey);

  JournalSyncStatus get syncStatus => _syncStatus;

  Object? get lastSyncError => _lastSyncError;

  bool get hasUnsavedChanges => _hasUnsavedChanges;

  @visibleForTesting
  int get initRunCount => _initRunCount;

  @visibleForTesting
  int get reloadTodayRunCount => _reloadTodayRunCount;

  @visibleForTesting
  bool debugFailV2MigrationWriteConfirmation = false;

  void _setSyncStatus(JournalSyncStatus status, [Object? error]) {
    if (_syncStatus == status && _lastSyncError == error) return;
    _syncStatus = status;
    _lastSyncError = error;
    onSyncStatusChanged?.call();
  }

  void _markLocalEdit() {
    _localEditRevision += 1;
  }

  bool _shouldAbortReloadApply({
    required String dateKey,
    required String cacheScope,
    required int editRevision,
    required String source,
  }) {
    if (_cacheScope != cacheScope) {
      _log('$source: discarded stale load after cache scope changed');
      return true;
    }
    if (_activeDateKey != dateKey) {
      _log('$source: discarded stale load after active date changed');
      return true;
    }
    if (_localEditRevision != editRevision) {
      _log('$source: discarded stale load after local editor changes');
      return true;
    }
    return false;
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

  bool _v1DraftShouldReplaceExistingV2({
    required bool v1Dirty,
    required DateTime? v1ModifiedAt,
    required DateTime? v2ModifiedAt,
    required bool v2Exists,
  }) {
    if (!v2Exists) return true;
    if (!v1Dirty) return false;
    if (v1ModifiedAt == null) return false;
    if (v2ModifiedAt == null) return true;
    return v1ModifiedAt.isAfter(v2ModifiedAt);
  }

  Iterable<String> _v1DraftDateKeys(SharedPreferences prefs, String scope) {
    final prefix = 'journal:$scope:draft:';
    return prefs.getKeys().where((key) => key.startsWith(prefix)).map((key) {
      return key.substring(prefix.length);
    });
  }

  Future<void> _removeV1DraftKeys(
    SharedPreferences prefs, {
    required String scope,
    required String dateKey,
  }) async {
    await prefs.remove(_cacheKeyForScope(scope, 'draft', dateKey));
    await prefs.remove(_cacheKeyForScope(scope, 'draft_dirty', dateKey));
    await prefs.remove(_cacheKeyForScope(scope, 'draft_modified_at', dateKey));
  }

  Future<bool> _confirmPrefsWrite(
    SharedPreferences prefs, {
    required String key,
    required Object expected,
  }) async {
    if (debugFailV2MigrationWriteConfirmation) return false;
    final stored = prefs.get(key);
    return stored == expected;
  }

  Future<void> _migrateOneV1Draft(
    SharedPreferences prefs, {
    required String scope,
    required String dateKey,
  }) async {
    final draftKey = _cacheKeyForScope(scope, 'draft', dateKey);
    final dirtyKey = _cacheKeyForScope(scope, 'draft_dirty', dateKey);
    final modifiedKey = _cacheKeyForScope(scope, 'draft_modified_at', dateKey);
    final text = prefs.getString(draftKey);
    if (text == null || text.isEmpty) {
      await _removeV1DraftKeys(prefs, scope: scope, dateKey: dateKey);
      return;
    }

    final v1Dirty = prefs.getBool(dirtyKey) ?? false;
    final v1ModifiedRaw = prefs.getString(modifiedKey);
    final v1Modified = _parsePrefsDate(v1ModifiedRaw);
    final documentKey = _cacheKeyForScope(scope, 'document', dateKey);
    final documentDirtyKey = _cacheKeyForScope(
      scope,
      'document_dirty',
      dateKey,
    );
    final documentModifiedKey = _cacheKeyForScope(
      scope,
      'document_modified_at',
      dateKey,
    );
    final existingV2 = prefs.getString(documentKey);
    final v2Exists = existingV2 != null && existingV2.isNotEmpty;
    final v2Modified = _parsePrefsDate(prefs.getString(documentModifiedKey));

    if (_v1DraftShouldReplaceExistingV2(
      v1Dirty: v1Dirty,
      v1ModifiedAt: v1Modified,
      v2ModifiedAt: v2Modified,
      v2Exists: v2Exists,
    )) {
      final json = jsonEncode(JournalDocument.fromPlainText(text).toJson());
      final written = await prefs.setString(documentKey, json);
      if (!written ||
          !await _confirmPrefsWrite(prefs, key: documentKey, expected: json)) {
        _log(
          '_migrateV1Draft: V2 write unconfirmed for $scope $dateKey; keeping V1',
        );
        return;
      }

      final dirtyWritten = await prefs.setBool(documentDirtyKey, v1Dirty);
      if (!dirtyWritten ||
          !await _confirmPrefsWrite(
            prefs,
            key: documentDirtyKey,
            expected: v1Dirty,
          )) {
        _log(
          '_migrateV1Draft: V2 dirty flag unconfirmed for $scope $dateKey; keeping V1',
        );
        return;
      }

      if (v1Dirty && v1ModifiedRaw != null && v1ModifiedRaw.isNotEmpty) {
        final modifiedWritten = await prefs.setString(
          documentModifiedKey,
          v1ModifiedRaw,
        );
        if (!modifiedWritten ||
            !await _confirmPrefsWrite(
              prefs,
              key: documentModifiedKey,
              expected: v1ModifiedRaw,
            )) {
          _log(
            '_migrateV1Draft: V2 modified_at unconfirmed for $scope $dateKey; keeping V1',
          );
          return;
        }
      }
    } else if (!v2Exists) {
      return;
    }

    final confirmedV2 = prefs.getString(documentKey);
    if (confirmedV2 == null || confirmedV2.isEmpty) {
      _log('_migrateV1Draft: V2 still missing for $scope $dateKey; keeping V1');
      return;
    }

    await _removeV1DraftKeys(prefs, scope: scope, dateKey: dateKey);
    _log('_migrateV1Draft: upgraded $scope $dateKey to V2 document');
  }

  Future<void> _migrateV1DraftsIfNeeded(SharedPreferences prefs) async {
    final scopes = <String>{_cacheScope, 'local'};
    for (final scope in scopes) {
      for (final dateKey in _v1DraftDateKeys(prefs, scope).toList()) {
        await _migrateOneV1Draft(prefs, scope: scope, dateKey: dateKey);
      }
    }
  }

  Future<void> _setLocalDirty({
    required SharedPreferences prefs,
    required String dateKey,
    required bool dirty,
  }) async {
    await prefs.setBool(_documentDirtyKey(dateKey), dirty);
    if (dirty) {
      await prefs.setString(
        _documentModifiedKey(dateKey),
        DateTime.now().toUtc().toIso8601String(),
      );
    }
  }

  Future<void> _markLocalClean({required String dateKey}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _setLocalDirty(prefs: prefs, dateKey: dateKey, dirty: false);
    } catch (e) {
      _log('_markLocalClean error: $e');
    }
  }

  Future<void> _removeLocalScopeDocument(
    SharedPreferences prefs,
    String dateKey,
  ) async {
    await prefs.remove(_localDocumentKey(dateKey));
    await prefs.remove(_localDocumentDirtyKey(dateKey));
    await prefs.remove(_localDocumentModifiedKey(dateKey));
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
    final existing = _initFuture;
    if (existing != null) {
      _log('init: joining existing initialization');
      return existing;
    }

    final future = _runInit();
    _initFuture = future;
    try {
      await future;
    } catch (_) {
      if (identical(_initFuture, future)) {
        _initFuture = null;
      }
      rethrow;
    }
  }

  Future<void> _runInit() async {
    _initRunCount += 1;
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
    final existing = _reloadTodayFuture;
    if (existing != null) {
      _log('reloadToday: joining existing reload');
      return existing;
    }

    final future = _runReloadToday();
    _reloadTodayFuture = future;
    try {
      await future;
    } finally {
      if (identical(_reloadTodayFuture, future)) {
        _reloadTodayFuture = null;
      }
    }
  }

  Future<void> _runReloadToday() async {
    _reloadTodayRunCount += 1;
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

    await _loadDocumentForToday();

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

  /// Load document for today (V2 behavior)
  Future<void> _loadDocumentForToday() async {
    final today = _today;
    _currentDate = today;
    final dateKey = _formatDate(today);
    final cacheScope = _cacheScope;
    final editRevision = _localEditRevision;

    final prefs = await SharedPreferences.getInstance();
    await _migrateV1DraftsIfNeeded(prefs);
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
    Object? serverError;
    try {
      entry = await _repo.getByDateStrict(today);
    } catch (e) {
      serverReadFailed = true;
      serverError = e;
      _log('_loadDocumentForToday server error: $e');
    }

    if (_shouldAbortReloadApply(
      dateKey: dateKey,
      cacheScope: cacheScope,
      editRevision: editRevision,
      source: '_loadDocumentForToday',
    )) {
      return;
    }

    if (serverReadFailed) {
      _setSyncStatus(JournalSyncStatus.saveFailed, serverError);
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

    _markLocalEdit();
    _currentDraft = text;
    _hasUnsavedChanges = true;
    _setSyncStatus(JournalSyncStatus.unsavedLocal);

    _currentDocument = _plainTextToDocument(text);
    await _saveLocalDocument(markDirty: true);

    _scheduleAutosave();

    onDraftChanged?.call();
  }

  List<EventBadgeToken> _completionBadgesFromCurrentEntry() {
    final doc = _currentDocument;
    if (doc != null) {
      return JournalBadgeUtils.completionTokensFromDocument(doc);
    }
    return JournalBadgeUtils.completionTokensFromPlainText(_currentDraft);
  }

  List<EventBadgeToken> _removedCompletionBadges(
    List<EventBadgeToken> before,
    JournalDocument after,
  ) {
    if (before.isEmpty) return const <EventBadgeToken>[];
    final afterIds = JournalBadgeUtils.completionTokensFromDocument(
      after,
    ).map((token) => token.id).toSet();
    final removed = <EventBadgeToken>[];
    final seen = <String>{};
    for (final token in before) {
      if (afterIds.contains(token.id) || !seen.add(token.id)) continue;
      removed.add(token);
    }
    return removed;
  }

  Future<void> _notifyCompletionBadgesRemoved(
    List<EventBadgeToken> badges,
  ) async {
    if (badges.isEmpty) return;
    try {
      await onCompletionBadgesRemoved?.call(badges);
    } catch (e) {
      _log('completion badge removal sync error: $e');
    }
  }

  /// Update document directly (V2)
  Future<void> updateDocument(JournalDocument document) async {
    final beforeCompletionBadges = _completionBadgesFromCurrentEntry();
    final normalized = JournalBadgeUtils.normalizeDocument(document);
    if (_currentDocument == normalized) return;
    final removedCompletionBadges = _removedCompletionBadges(
      beforeCompletionBadges,
      normalized,
    );

    _markLocalEdit();
    _currentDocument = normalized;
    _currentDraft = _documentToPlainText(normalized);
    _hasUnsavedChanges = true;
    _setSyncStatus(JournalSyncStatus.unsavedLocal);

    await _saveLocalDocument(markDirty: true);

    _scheduleAutosave();

    onDraftChanged?.call();
    await _notifyCompletionBadgesRemoved(removedCompletionBadges);
  }

  Future<void> removeBadge(String badgeId) async {
    final id = badgeId.trim();
    if (id.isEmpty) return;

    final doc =
        _currentDocument ?? JournalDocument.fromPlainText(_currentDraft);
    final nextDoc = JournalBadgeUtils.removeBadgesById(doc, <String>{id});
    await updateDocument(nextDoc);
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
      await _setLocalDirty(prefs: prefs, dateKey: dateKey, dirty: markDirty);
      _log('_saveLocalDocument: ✓ cached locally');
    } catch (e) {
      _log('_saveLocalDocument error: $e');
    }
  }

  /// Autosave to server (debounced)
  Future<bool> _autosave() async {
    if (!_hasUnsavedChanges) return true;

    try {
      final saveRevision = _localEditRevision;
      _setSyncStatus(JournalSyncStatus.saving);
      _log('_autosave: saving to server (${_currentDraft.length} chars)');

      _currentDocument ??= JournalDocument.fromPlainText(_currentDraft);
      final bodyToSave = jsonEncode(_currentDocument!.toJson());
      final metaToSave = {
        'chars': _currentDraft.length,
        'last_autosave': DateTime.now().toUtc().toIso8601String(),
        'document_version': _currentDocument!.version,
        'block_count': _currentDocument!.blocks.length,
      };

      final saveDate = _currentDate ?? _today;
      final dateKey = _formatDate(saveDate);
      await _repo.upsert(
        localDate: saveDate,
        body: bodyToSave,
        meta: metaToSave,
      );

      if (_localEditRevision != saveRevision) {
        _setSyncStatus(JournalSyncStatus.unsavedLocal);
        _scheduleAutosave();
        _log('_autosave: saved earlier revision; local edits remain pending');
        return true;
      }

      _hasUnsavedChanges = false;
      await _markLocalClean(dateKey: dateKey);
      _setSyncStatus(JournalSyncStatus.synced);
      _log('_autosave: ✓ saved to server');

      // Track autosave event
      try {
        unawaited(
          Events.trackIfAuthed('journal_autosave', {
            'chars': _currentDraft.length,
            'appended_block': false,
            'document_mode': true,
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
      final removedCompletionBadges = _completionBadgesFromCurrentEntry();
      _markLocalEdit();
      _currentDocument = JournalDocument.fromPlainText('');
      _currentDraft = '';
      _hasUnsavedChanges = true;
      _setSyncStatus(JournalSyncStatus.unsavedLocal);
      await _saveLocalDocument(markDirty: true);
      onDraftChanged?.call();
      await _autosave();
      await _notifyCompletionBadgesRemoved(removedCompletionBadges);
    } catch (e) {
      _log('clearToday error: $e');
    }
  }

  /// Finalize yesterday's entry if we detected a day rollover
  Future<void> finalizeYesterdayIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _migrateV1DraftsIfNeeded(prefs);
      final lastOpenDay = prefs.getString(_lastOpenDayKey);

      if (lastOpenDay == null || lastOpenDay == _todayKey) {
        _log('finalizeYesterdayIfNeeded: no rollover detected');
        return;
      }

      _log(
        'finalizeYesterdayIfNeeded: detected rollover from $lastOpenDay to $_todayKey',
      );

      final yesterdayContent = prefs.getString(_documentKey(lastOpenDay));

      if (yesterdayContent != null && yesterdayContent.isNotEmpty) {
        final parts = lastOpenDay.split('-');
        final yesterdayDate = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );

        await _repo.upsert(
          localDate: yesterdayDate,
          body: yesterdayContent,
          meta: {
            'chars': yesterdayContent.length,
            'finalized': true,
            'finalized_at': DateTime.now().toUtc().toIso8601String(),
          },
        );

        await prefs.remove(_documentKey(lastOpenDay));
        await prefs.remove(_documentDirtyKey(lastOpenDay));
        await prefs.remove(_documentModifiedKey(lastOpenDay));

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

    _currentDocument ??= JournalDocument.fromPlainText(_currentDraft);
    final appendedAt = await appendToDocument(content);
    _log(
      'appendToToday: appended ${content.length} chars at position $appendedAt',
    );
    return appendedAt;
  }

  /// Append content to document (V2)
  Future<int> appendToDocument(String content) async {
    if (content.trim().isEmpty) return 0;
    final appendStart = _currentDraft.length;

    _currentDocument ??= JournalDocument.fromPlainText(_currentDraft);

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

      _currentDate = date;
      final dateKey = _formatDate(date);

      final prefs = await SharedPreferences.getInstance();
      await _migrateV1DraftsIfNeeded(prefs);

      final entry = await _repo.getByDate(date);

      if (entry != null) {
        _log('loadDate: found entry with ${entry.body.length} chars');

        if (entry.body.startsWith('{') && entry.body.contains('"version"')) {
          try {
            final docJson = jsonDecode(entry.body) as Map<String, dynamic>;
            await _applyDocument(JournalDocument.fromJson(docJson));
            _log('loadDate: loaded V2 document');
          } catch (e) {
            _log(
              'loadDate: failed to parse document, migrating stripped body: $e',
            );
            await _applyDocument(
              JournalDocument.fromPlainText(
                JournalBadgeUtils.stripBadgesFromPlainText(entry.body),
              ),
            );
          }
        } else {
          await _applyDocument(
            JournalDocument.fromPlainText(
              JournalBadgeUtils.stripBadgesFromPlainText(entry.body),
            ),
          );
          _log('loadDate: migrated V1 plain text to document');
        }
      } else {
        _log('loadDate: no entry found for $dateKey');
        await _applyDocument(_emptyEditorDocument());
      }

      await prefs.setString(_lastOpenDayKey, dateKey);

      _hasUnsavedChanges = false;
      _setSyncStatus(JournalSyncStatus.synced);
      onDraftChanged?.call();

      _log('loadDate: ✓ loaded entry for $dateKey');
    } catch (e) {
      _log('loadDate error: $e');
      await _applyDocument(_emptyEditorDocument());
      _setSyncStatus(JournalSyncStatus.saveFailed, e);
    }
  }

  /// Empty archive/editor face: no leftover newline, still a V2 document.
  JournalDocument _emptyEditorDocument() {
    return JournalDocument(
      version: kJournalDocVersion,
      blocks: [
        ParagraphBlock(
          id: 'p-${DateTime.now().millisecondsSinceEpoch}',
          ops: const [TextOp(insert: '')],
        ),
      ],
    );
  }

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
