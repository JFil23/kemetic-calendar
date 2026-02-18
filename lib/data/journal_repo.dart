// ============================================================================
// IMPLEMENTATION GUIDE
// ============================================================================
// FILE: lib/data/journal_repo.dart
// PURPOSE: Repository layer for journal database operations
// 
// STEPS TO IMPLEMENT:
// 1. Create the file: lib/data/journal_repo.dart
// 2. Copy and paste this ENTIRE file
// 3. No modifications needed - works out of the box
// 4. Verify imports resolve (should match your existing repo pattern)
//
// DEPENDENCIES:
// - Requires journal_schema.sql to be run in Supabase first
// - Uses existing SupabaseClient from your app
// - Follows same pattern as your UserEventsRepo
//
// WHAT THIS DOES:
// - Provides type-safe access to journal_entries table
// - Handles date formatting (local date only, no time component)
// - Implements UPSERT for idempotent saves
// - Supports offline-first via try-catch error handling
//
// USAGE EXAMPLE:
// final repo = JournalRepo(Supabase.instance.client);
// await repo.upsert(localDate: DateTime.now(), body: "My journal entry");
// final entry = await repo.getByDate(DateTime.now());
// ============================================================================

// lib/data/journal_repo.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JournalEntry {
  final String id;
  final String userId;
  final DateTime gregDate; // Local date only (no time component)
  final String body;
  final Map<String, dynamic> meta;
  final String? category;
  final DateTime createdAt;
  final DateTime updatedAt;

  JournalEntry({
    required this.id,
    required this.userId,
    required this.gregDate,
    required this.body,
    required this.meta,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      gregDate: DateTime.parse(json['greg_date'] as String),
      body: json['body'] as String? ?? '',
      meta: (json['meta'] as Map<String, dynamic>?) ?? {},
      category: json['category'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'greg_date': _formatDate(gregDate),
      'body': body,
      'meta': meta,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class JournalRepo {
  final SupabaseClient _client;

  JournalRepo(this._client);

  void _log(String msg) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      print('[JournalRepo $timestamp] $msg');
    }
  }

  /// Get entry for a specific local date
  Future<JournalEntry?> getByDate(DateTime localDate) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        _log('getByDate: no user logged in');
        return null;
      }

      final dateStr = JournalEntry._formatDate(localDate);
      _log('getByDate: fetching $dateStr for user $userId');

      final response = await _client
          .from('journal_entries')
          .select()
          .eq('user_id', userId)
          .eq('greg_date', dateStr)
          .maybeSingle();

      if (response == null) {
        _log('getByDate: no entry found for $dateStr');
        return null;
      }

      final entry = JournalEntry.fromJson(response);
      _log('getByDate: found entry with ${entry.body.length} chars');
      return entry;
    } catch (e) {
      _log('getByDate error: $e');
      return null;
    }
  }

  /// Get recent entries (for future features like browsing history)
  Future<List<JournalEntry>> listRecent({int days = 30}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        _log('listRecent: no user logged in');
        return [];
      }

      final cutoff = DateTime.now().subtract(Duration(days: days));
      final cutoffStr = JournalEntry._formatDate(cutoff);

      _log('listRecent: fetching entries since $cutoffStr');

      final response = await _client
          .from('journal_entries')
          .select()
          .eq('user_id', userId)
          .gte('greg_date', cutoffStr)
          .order('greg_date', ascending: false);

      final entries = (response as List)
          .map((json) => JournalEntry.fromJson(json as Map<String, dynamic>))
          .toList();

      _log('listRecent: found ${entries.length} entries');
      return entries;
    } catch (e) {
      _log('listRecent error: $e');
      return [];
    }
  }

  /// Get entries within a local-date window (inclusive).
  Future<List<JournalEntry>> listRange({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        _log('listRange: no user logged in');
        return [];
      }

      final startStr = JournalEntry._formatDate(start);
      final endStr = JournalEntry._formatDate(end);
      _log('listRange: fetching $startStr -> $endStr for $userId');

      final response = await _client
          .from('journal_entries')
          .select()
          .eq('user_id', userId)
          .gte('greg_date', startStr)
          .lte('greg_date', endStr)
          .order('greg_date', ascending: true);

      final entries = (response as List)
          .map((json) => JournalEntry.fromJson(json as Map<String, dynamic>))
          .toList();

      _log('listRange: found ${entries.length} entries');
      return entries;
    } catch (e) {
      _log('listRange error: $e');
      return [];
    }
  }

  /// Upsert (create or update) an entry for a specific date
  /// This is idempotent - safe to call multiple times with the same date
  Future<void> upsert({
    required DateTime localDate,
    required String body,
    Map<String, dynamic>? meta,
    String? category,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        _log('upsert: no user logged in, cannot save');
        throw Exception('User not authenticated');
      }

      final dateStr = JournalEntry._formatDate(localDate);
      _log('upsert: saving entry for $dateStr (${body.length} chars)');

      await _client.from('journal_entries').upsert({
        'user_id': userId,
        'greg_date': dateStr,
        'body': body,
        'meta': meta ?? {},
        if (category != null) 'category': category,
      }, onConflict: 'user_id,greg_date');

      _log('upsert: ✓ saved entry for $dateStr');
    } catch (e) {
      _log('upsert error: $e');
      rethrow;
    }
  }

  /// Delete entry for a specific date (for future features)
  Future<void> deleteByDate(DateTime localDate) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        _log('deleteByDate: no user logged in');
        return;
      }

      final dateStr = JournalEntry._formatDate(localDate);
      _log('deleteByDate: deleting $dateStr');

      await _client
          .from('journal_entries')
          .delete()
          .eq('user_id', userId)
          .eq('greg_date', dateStr);

      _log('deleteByDate: ✓ deleted $dateStr');
    } catch (e) {
      _log('deleteByDate error: $e');
    }
  }
}
