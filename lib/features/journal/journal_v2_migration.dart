// ============================================================================
// JOURNAL V2 MIGRATION SCRIPT
// ============================================================================
// FILE: lib/features/journal/journal_v2_migration.dart
// PURPOSE: Migrate existing plain text entries to document format
//
// USAGE:
// 1. Run this script once when enabling Journal V2
// 2. It will convert all existing plain text entries to documents
// 3. Safe to run multiple times (idempotent)
// ============================================================================

import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'journal_v2_document_model.dart';
import '../../data/journal_repo.dart';

class JournalV2Migration {
  final SupabaseClient _client;
  final JournalRepo _repo;
  
  JournalV2Migration(this._client) : _repo = JournalRepo(_client);

  /// Migrate all plain text entries to document format
  Future<MigrationResult> migrateAllEntries() async {
    final result = MigrationResult();
    
    try {
      // Get all journal entries
      final response = await _client
          .from('journal_entries')
          .select('*')
          .order('local_date', ascending: false);
      
      final entries = response as List<dynamic>;
      
      for (final entry in entries) {
        final entryMap = entry as Map<String, dynamic>;
        final body = entryMap['body'] as String? ?? '';
        
        // Skip if already a document
        if (body.startsWith('{') && body.contains('"version"')) {
          result.skipped++;
          continue;
        }
        
        // Skip if empty
        if (body.trim().isEmpty) {
          result.skipped++;
          continue;
        }
        
        // Convert to document
        final document = JournalDocument.fromPlainText(body);
        
        // Update in database
        await _client
            .from('journal_entries')
            .update({
              'body': jsonEncode(document.toJson()),
              'meta': {
                ...entryMap['meta'] as Map<String, dynamic>? ?? {},
                'migrated_to_v2': true,
                'migration_date': DateTime.now().toUtc().toIso8601String(),
                'original_chars': body.length,
                'document_version': document.version,
              },
            })
            .eq('id', entryMap['id']);
        
        result.migrated++;
      }
      
      result.success = true;
      result.message = 'Successfully migrated ${result.migrated} entries';
      
    } catch (e) {
      result.success = false;
      result.message = 'Migration failed: $e';
    }
    
    return result;
  }
  
  /// Migrate a single entry by date
  Future<bool> migrateEntryByDate(DateTime localDate) async {
    try {
      final entry = await _repo.getByDate(localDate);
      if (entry == null) return false;
      
      final body = entry.body;
      
      // Skip if already a document
      if (body.startsWith('{') && body.contains('"version"')) {
        return true; // Already migrated
      }
      
      // Convert to document
      final document = JournalDocument.fromPlainText(body);
      
      // Update in database
      await _repo.upsert(
        localDate: localDate,
        body: jsonEncode(document.toJson()),
        meta: {
          ...entry.meta ?? {},
          'migrated_to_v2': true,
          'migration_date': DateTime.now().toUtc().toIso8601String(),
          'original_chars': body.length,
          'document_version': document.version,
        },
      );
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Check migration status
  Future<MigrationStatus> checkMigrationStatus() async {
    try {
      final response = await _client
          .from('journal_entries')
          .select('body, meta')
          .order('local_date', ascending: false);
      
      final entries = response as List<dynamic>;
      int total = 0;
      int migrated = 0;
      int plainText = 0;
      
      for (final entry in entries) {
        final entryMap = entry as Map<String, dynamic>;
        final body = entryMap['body'] as String? ?? '';
        
        total++;
        
        if (body.startsWith('{') && body.contains('"version"')) {
          migrated++;
        } else if (body.trim().isNotEmpty) {
          plainText++;
        }
      }
      
      return MigrationStatus(
        totalEntries: total,
        migratedEntries: migrated,
        plainTextEntries: plainText,
        migrationComplete: plainText == 0,
      );
    } catch (e) {
      return MigrationStatus(
        totalEntries: 0,
        migratedEntries: 0,
        plainTextEntries: 0,
        migrationComplete: false,
        error: e.toString(),
      );
    }
  }
}

class MigrationResult {
  bool success = false;
  String message = '';
  int migrated = 0;
  int skipped = 0;
  
  MigrationResult();
}

class MigrationStatus {
  final int totalEntries;
  final int migratedEntries;
  final int plainTextEntries;
  final bool migrationComplete;
  final String? error;
  
  MigrationStatus({
    required this.totalEntries,
    required this.migratedEntries,
    required this.plainTextEntries,
    required this.migrationComplete,
    this.error,
  });
  
  double get migrationProgress {
    if (totalEntries == 0) return 0.0;
    return migratedEntries / totalEntries;
  }
  
  String get statusText {
    if (error != null) return 'Error: $error';
    if (migrationComplete) return 'Migration complete';
    return '${migratedEntries}/${totalEntries} entries migrated';
  }
}

