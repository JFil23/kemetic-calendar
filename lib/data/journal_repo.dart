import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'account_operation_fence.dart';
import 'warm_state/warm_mutation.dart';
import 'warm_state/warm_snapshot_store.dart';
import 'warm_state/warm_json_reads.dart';
import 'pages_read_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../telemetry/telemetry.dart';

class JournalEntry {
  final String id;
  final String userId;
  final DateTime gregDate; // Local date only (no time component)
  final String body;
  final Map<String, dynamic> meta;
  final String? category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;

  JournalEntry({
    required this.id,
    required this.userId,
    required this.gregDate,
    required this.body,
    required this.meta,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.revision = 1,
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
      revision: (json['revision'] as num?)?.toInt() ?? 1,
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
      'revision': revision,
    };
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class JournalRecoveryDraft {
  const JournalRecoveryDraft(
    this.id, {
    this.createdAt,
    this.characterCount = 0,
  });
  final String id;
  final DateTime? createdAt;
  final int characterCount;
}

class JournalRevisionConflict implements Exception {
  const JournalRevisionConflict(this.revision, this.serverEntry);
  final int revision;
  final JournalEntry? serverEntry;
  @override
  String toString() =>
      'This day changed elsewhere. Your local writing is kept. Review the saved version before trying again.';
}

class JournalRepo {
  final SupabaseClient _client;

  JournalRepo(this._client);
  String? get accountId => _client.auth.currentUser?.id;
  Stream<String?> get accountChanges => _client.auth.onAuthStateChange
      .map((state) => state.session?.user.id)
      .distinct();
  final Map<String, int> _baseRevisions = {};
  final Map<String, List<JournalRecoveryDraft>> _recovery = {};
  List<JournalRecoveryDraft> recoveryForDate(DateTime date) =>
      _recovery[_revisionKey(date)] ?? const [];
  String _revisionKey(DateTime date) =>
      '${_client.auth.currentUser?.id}:${JournalEntry._formatDate(date)}';
  int revisionForDate(DateTime date) => _baseRevisions[_revisionKey(date)] ?? 0;
  void restoreBaseRevision(DateTime date, int revision) =>
      _baseRevisions[_revisionKey(date)] = revision;
  JournalEntry _remember(JournalEntry entry) {
    _baseRevisions['${entry.userId}:${JournalEntry._formatDate(entry.gregDate)}'] =
        entry.revision;
    return entry;
  }

  Future<String> readRecoveryDraft(JournalRecoveryDraft draft) async {
    final fence = AccountOperationFence(_client);
    try {
      if (fence.userId == null)
        throw StateError('Sign in to open your writing');
      final row = await _client
          .from('journal_mutation_receipts')
          .select('request')
          .eq('user_id', fence.userId!)
          .eq('mutation_id', draft.id)
          .single();
      if (!fence.isCurrent)
        throw StateError('Account changed while opening your writing');
      return (row['request'] as Map)['body'] as String;
    } finally {
      fence.dispose();
    }
  }

  void _log(String msg) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      debugPrint('[JournalRepo $timestamp] ${redactLogText(msg)}');
    }
  }

  /// Get entry for a specific local date
  Future<JournalEntry?> getByDate(DateTime localDate) async {
    try {
      return await getByDateStrict(localDate);
    } catch (e) {
      _log('getByDate error: $e');
      return null;
    }
  }

  /// Get entry for a specific local date, surfacing network/RLS errors.
  Future<JournalEntry?> getByDateStrict(DateTime localDate) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      _log('getByDateStrict: no user logged in');
      return null;
    }

    final dateStr = JournalEntry._formatDate(localDate);
    _log(
      'getByDateStrict: fetching $dateStr for user=${safeLogIdentifier(userId)}',
    );

    final fence = AccountOperationFence(_client);
    try {
      final raw = await _client.rpc(
        'read_journal_state_v1',
        params: {'p_account': userId, 'p_date': dateStr},
      );
      if (!fence.isCurrent)
        throw StateError('Account changed while reading Journal');
      final state = Map<String, dynamic>.from(raw as Map);
      _recovery[_revisionKey(
        localDate,
      )] = (state['recovery'] as List? ?? const [])
          .whereType<Map>()
          .where((r) => r['mutation_id'] is String)
          .map(
            (r) => JournalRecoveryDraft(
              r['mutation_id'] as String,
              createdAt: DateTime.tryParse(r['created_at']?.toString() ?? ''),
              characterCount: (r['character_count'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList();
      restoreBaseRevision(localDate, (state['revision'] as num).toInt());
      final row = state['row'];
      return row == null
          ? null
          : _remember(
              JournalEntry.fromJson(Map<String, dynamic>.from(row as Map)),
            );
    } finally {
      fence.dispose();
    }
  }

  /// Fetch the most recent journal entry for the user.
  Future<JournalEntry?> getLatest() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;
      final response = await _client
          .from('journal_entries')
          .select()
          .eq('user_id', userId)
          .order('greg_date', ascending: false)
          .limit(1)
          .maybeSingle();
      if (response == null) return null;
      return _remember(JournalEntry.fromJson(response));
    } catch (e) {
      _log('getLatest error: $e');
      return null;
    }
  }

  Future<JournalEntry?> getById(
    String id, {
    bool cachedOnly = false,
    bool strict = false,
  }) async {
    final fence = AccountOperationFence(_client);
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;
      final res =
          await WarmJsonReads(
            _client,
            cachedOnly: cachedOnly,
            mayFetch: () => fence.isCurrent,
          ).value(
            'journal.entry.$id',
            () async => _client
                .from('journal_entries')
                .select()
                .eq('user_id', userId)
                .eq('id', id)
                .maybeSingle(),
          );
      if (!fence.isCurrent) throw StateError('Account changed while reading');
      if (res == null) return null;
      return _remember(
        JournalEntry.fromJson(Map<String, dynamic>.from(res as Map)),
      );
    } catch (e) {
      if (cachedOnly || strict) rethrow;
      _log('getById error: $e');
      return null;
    } finally {
      fence.dispose();
    }
  }

  /// Get recent entries (for future features like browsing history)
  Future<List<JournalEntry>> listRecent({
    int days = 30,
    bool cachedOnly = false,
    bool strict = false,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        _log('listRecent: no user logged in');
        return [];
      }

      final cutoff = DateTime.now().subtract(Duration(days: days));
      final cutoffStr = JournalEntry._formatDate(cutoff);

      _log('listRecent: fetching entries since $cutoffStr');

      final response = await WarmJsonReads(_client, cachedOnly: cachedOnly)
          .rows(
            'journal.recent.$days.$cutoffStr',
            () async => _client
                .from('journal_entries')
                .select()
                .eq('user_id', userId)
                .gte('greg_date', cutoffStr)
                .order('greg_date', ascending: false),
          );

      final entries = (response as List)
          .map(
            (json) =>
                _remember(JournalEntry.fromJson(json as Map<String, dynamic>)),
          )
          .toList();

      _log('listRecent: found ${entries.length} entries');
      return entries;
    } catch (e) {
      if (cachedOnly || strict) rethrow;
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
          .map(
            (json) =>
                _remember(JournalEntry.fromJson(json as Map<String, dynamic>)),
          )
          .toList();

      _log('listRange: found ${entries.length} entries');
      return entries;
    } catch (e) {
      _log('listRange error: $e');
      return [];
    }
  }

  /// All Journal writers use the same acknowledged CAS boundary. The pending
  /// request belongs to the account repository, never to disposable warm cache.
  Future<void> upsert({
    required DateTime localDate,
    required String body,
    Map<String, dynamic>? meta,
    String? category,
  }) =>
      _mutate(localDate: localDate, body: body, meta: meta, category: category);

  Future<void> deleteByDate(DateTime localDate) =>
      _mutate(localDate: localDate, delete: true);

  // Timestamps describe delivery attempts, not new authored intent. A lost
  // acknowledgement must retry the original complete request and mutation ID.
  String _intentMeta(Map? raw) {
    final value = Map<String, dynamic>.from(raw ?? const {});
    value.remove('last_autosave');
    value.remove('finalized_at');
    return jsonEncode(value);
  }

  Future<void> _mutate({
    required DateTime localDate,
    String? body,
    Map<String, dynamic>? meta,
    String? category,
    bool delete = false,
  }) async {
    final fence = AccountOperationFence(_client);
    final account = fence.userId;
    if (account == null) {
      fence.dispose();
      throw StateError('Sign in to save Journal');
    }
    final date = JournalEntry._formatDate(localDate);
    final key = 'journal:user:$account:mutation:$date';
    final expected = revisionForDate(localDate);
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic>? request;
      final pending = prefs.getString(key);
      if (pending != null) {
        final old = Map<String, dynamic>.from(jsonDecode(pending) as Map);
        if (old['p_body'] == body &&
            old['p_expected_revision'] == expected &&
            old['p_delete'] == delete &&
            old['p_category'] == category &&
            _intentMeta(old['p_meta'] as Map?) == _intentMeta(meta))
          request = old;
      }
      request ??= {
        'p_account': account,
        'p_mutation': const Uuid().v4(),
        'p_date': date,
        'p_expected_revision': expected,
        'p_body': body,
        'p_meta': meta ?? <String, dynamic>{},
        'p_category': category,
        'p_delete': delete,
      };
      final encoded = jsonEncode(request);
      if (!await prefs.setString(key, encoded))
        throw StateError('Could not keep Journal draft on this device');
      if (!fence.isCurrent)
        throw StateError('Account changed before Journal save');
      final raw = await _client.rpc(
        'apply_journal_mutation_v1',
        params: request,
      );
      if (!fence.isCurrent)
        throw StateError('Account changed during Journal save');
      final result = Map<String, dynamic>.from(raw as Map);
      final row = result['row'];
      final entry = row == null
          ? null
          : JournalEntry.fromJson(Map<String, dynamic>.from(row as Map));
      final revision = (result['revision'] as num).toInt();
      if (result['status'] != 'applied')
        throw JournalRevisionConflict(revision, entry);
      // Receipts acknowledge an earlier write. Check current truth before
      // clearing a draft or warming a row that might since have been removed.
      final current = Map<String, dynamic>.from(
        await _client.rpc(
              'read_journal_state_v1',
              params: {'p_account': account, 'p_date': date},
            )
            as Map,
      );
      if (!fence.isCurrent)
        throw StateError('Account changed after Journal save');
      final currentRevision = (current['revision'] as num).toInt();
      if (currentRevision != revision) {
        throw JournalRevisionConflict(
          currentRevision,
          current['row'] == null
              ? null
              : JournalEntry.fromJson(
                  Map<String, dynamic>.from(current['row'] as Map),
                ),
        );
      }
      invalidateWarmDomains(account, ['journal.', 'pages.journal.']);
      if (entry != null) {
        await WarmSnapshotStore.instance.refresh(
          account,
          'journal.entry.${entry.id}',
          () async => entry.toJson(),
          isCurrent: () => fence.isCurrent,
        );
      }
      if (!fence.isCurrent)
        throw StateError('Account changed after Journal save');
      restoreBaseRevision(localDate, revision);
      if (prefs.getString(key) == encoded) await prefs.remove(key);
      publishJournalOverview(account, localDate, entry?.body ?? '');
    } catch (_) {
      invalidateWarmDomains(account, ['journal.', 'pages.journal.']);
      rethrow;
    } finally {
      fence.dispose();
    }
  }
}
