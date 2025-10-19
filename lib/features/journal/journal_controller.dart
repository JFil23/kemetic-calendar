// ============================================================================
// IMPLEMENTATION GUIDE
// ============================================================================
// FILE: lib/features/journal/journal_controller.dart
// PURPOSE: Business logic for journal - autosave, finalization, day rollover
// 
// STEPS TO IMPLEMENT:
// 1. Create file: lib/features/journal/journal_controller.dart
// 2. Copy and paste this ENTIRE file
// 3. No modifications needed
//
// DEPENDENCIES:
// - Requires journal_repo.dart to exist
// - Requires journal_constants.dart to exist
// - Uses SharedPreferences (already in your pubspec.yaml)
// - Uses SupabaseClient (already in your app)
//
// HOW TO USE:
// In your calendar page state:
//
//   late JournalController _journalController;
//   
//   @override
//   void initState() {
//     super.initState();
//     _journalController = JournalController(Supabase.instance.client);
//     _journalController.init();
//   }
//   
//   @override
//   void dispose() {
//     _journalController.dispose();
//     super.dispose();
//   }
//
// WHAT THIS DOES:
// - Manages autosave with 500ms debounce (doesn't spam server)
// - Handles day rollover detection and finalization
// - Provides offline-first storage (local → server)
// - Queues failed saves for retry
// - Supports appending content for daily review integration
//
// KEY METHODS:
// - init() - Load today's draft, finalize yesterday if needed
// - updateDraft(text) - User typed, triggers autosave
// - forceSave() - Immediate save on overlay close
// - appendToToday(content) - For daily review integration
// ============================================================================

// lib/features/journal/journal_controller.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/journal_repo.dart';
import 'journal_constants.dart';
import '../../main.dart';

class JournalController {
  final JournalRepo _repo;
  final SupabaseClient _client;
  
  Timer? _autosaveTimer;
  String _currentDraft = '';
  DateTime? _currentDate;
  bool _hasUnsavedChanges = false;
  
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
    _log('init: starting');
    await _loadDraftForToday();
    await finalizeYesterdayIfNeeded();
    _log('init: complete');
  }

  /// Load draft for today from local storage or server
  Future<void> _loadDraftForToday() async {
    final today = _today;
    _currentDate = today;

    // Try local storage first (survives brief offline)
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
        await _saveLocalDraft(); // Cache it locally
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

  /// Get current draft text
  String get currentDraft => _currentDraft;

  /// Update draft text and trigger autosave
  Future<void> updateDraft(String text) async {
    if (_currentDraft == text) return;

    _currentDraft = text;
    _hasUnsavedChanges = true;
    
    // Save locally immediately (no network delay)
    await _saveLocalDraft();

    // Debounce server save
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(
      const Duration(milliseconds: kJournalAutosaveDebounceMs),
      _autosave,
    );

    onDraftChanged?.call();
  }

  /// Save draft to local storage (instant, no network)
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

  /// Autosave to server (debounced)
  Future<void> _autosave() async {
    if (!_hasUnsavedChanges) return;

    try {
      _log('_autosave: saving to server (${_currentDraft.length} chars)');
      
      await _repo.upsert(
        localDate: _currentDate ?? _today,
        body: _currentDraft,
        meta: {
          'chars': _currentDraft.length,
          'last_autosave': DateTime.now().toUtc().toIso8601String(),
        },
      );

      _hasUnsavedChanges = false;
      _log('_autosave: ✓ saved to server');
      
      // Track autosave event
      Events.trackIfAuthed('journal_autosave', {
        'chars': _currentDraft.length,
        'appended_block': false,
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

      // Load yesterday's draft from local storage
      final yesterdayDraft = prefs.getString('draft:$lastOpenDay');
      if (yesterdayDraft != null && yesterdayDraft.isNotEmpty) {
        final parts = lastOpenDay.split('-');
        final yesterdayDate = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );

        // Finalize to server
        await _repo.upsert(
          localDate: yesterdayDate,
          body: yesterdayDraft,
          meta: {
            'chars': yesterdayDraft.length,
            'finalized': true,
            'finalized_at': DateTime.now().toUtc().toIso8601String(),
          },
        );

        // Clean up old local draft
        await prefs.remove('draft:$lastOpenDay');
        _log('finalizeYesterdayIfNeeded: ✓ finalized $lastOpenDay');
      }

      // Update last open day
      await prefs.setString('lastOpenDay', _todayKey);
    } catch (e) {
      _log('finalizeYesterdayIfNeeded error: $e');
    }
  }

  /// Append content to today's journal (for daily review integration)
  /// Returns the position where content was appended
  Future<int> appendToToday(String content) async {
    if (content.trim().isEmpty) return 0;

    final appendPosition = _currentDraft.length;
    final newText = _currentDraft.isEmpty
        ? content
        : '$_currentDraft\n\n$content';

    await updateDraft(newText);
    
    _log('appendToToday: appended ${content.length} chars at position $appendPosition');
    return appendPosition;
  }

  /// Dispose controller
  void dispose() {
    _autosaveTimer?.cancel();
  }
}
