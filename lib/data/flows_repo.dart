// lib/data/flows_repo.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

const _kFlows = 'flows';

void _log(String msg) {
  if (kDebugMode) debugPrint('[flows] $msg');
}

/// Returns true if the end date is unset or today-or-later (UTC date-only).
bool _isActiveByEndDate(DateTime? endDate) {
  if (endDate == null) return true;
  final endUtc = endDate.toUtc();
  final endDateOnly = DateTime.utc(endUtc.year, endUtc.month, endUtc.day);
  final now = DateTime.now().toUtc();
  final today = DateTime.utc(now.year, now.month, now.day);
  return !endDateOnly.isBefore(today);
}

@immutable
class FlowRow {
  final int id;
  final String userId;
  final String name;
  final int color;
  final bool active;
  final bool isSaved;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;
  final List<dynamic> rules; // store your _FlowRule list as JSON-serializable
  final Map<String, dynamic>? aiMetadata;
  final bool isHidden;
  final bool isReminder;
  final String? reminderUuid;

  const FlowRow({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
    required this.active,
    required this.isSaved,
    required this.startDate,
    required this.endDate,
    required this.notes,
    required this.rules,
    this.aiMetadata,
    this.isHidden = false,
    this.isReminder = false,
    this.reminderUuid,
  });

  factory FlowRow.fromRow(Map<String, dynamic> r) {
    dynamic _rules = r['rules'];
    List<dynamic> _rulesList;
    if (_rules == null) {
      _rulesList = const [];
    } else if (_rules is List) {
      _rulesList = _rules;
    } else {
      // In case the column was accidentally stored as an object/string.
      _rulesList = const [];
    }

    DateTime? _d(dynamic v) => v == null ? null : DateTime.parse(v as String);
    return FlowRow(
      id: (r['id'] as num).toInt(),
      userId: r['user_id'] as String,
      name: r['name'] as String,
      // Force 24-bit RGB and safe default matching the backend
      color: (((r['color'] as num?)?.toInt() ?? 0x4DD0E1) & 0x00FFFFFF),
      active: (r['active'] as bool?) ?? true,
      isSaved: (r['is_saved'] as bool?) ?? false,
      startDate: _d(r['start_date']),
      endDate: _d(r['end_date']),
      notes: r['notes'] as String?,
      rules: _rulesList,
      isHidden: (r['is_hidden'] as bool?) ?? false,
      isReminder: (r['is_reminder'] as bool?) ?? false,
      reminderUuid: r['reminder_uuid'] as String?,
      aiMetadata: r['ai_metadata'] != null
          ? Map<String, dynamic>.from(r['ai_metadata'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toInsert({required String userId}) => {
    'user_id': userId,
    'name': name,
    'color': color,
    'active': active,
    'is_saved': isSaved,
    'start_date': startDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'notes': notes,
    'rules': rules,
    'is_hidden': isHidden,
    'is_reminder': isReminder,
    'reminder_uuid': reminderUuid,
  };

  Map<String, dynamic> toUpdate() => {
    'name': name,
    'color': color,
    'active': active,
    'is_saved': isSaved,
    'start_date': startDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'notes': notes,
    'rules': rules,
    'is_hidden': isHidden,
    'is_reminder': isReminder,
    'reminder_uuid': reminderUuid,
  };
}

class FlowsRepo {
  FlowsRepo(this._client);
  final SupabaseClient _client;
  Stream<List<FlowRow>> streamMyFlows() {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _client
        .from('flows')
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false)
        .order('start_date', ascending: true)
        .map(
          (rows) => rows
              .cast<Map<String, dynamic>>()
              .map(FlowRow.fromRow)
              .where(
                (f) =>
                    f.userId == user.id && // guard if RLS is loose
                    f.active == true &&
                    _isActiveByEndDate(f.endDate),
              )
              .toList(),
        );
  }

  Future<FlowRow> upsert({
    int? id, // null → insert; non-null → update
    required String name,
    required int color,
    required bool active,
    bool isSaved = false,
    bool isHidden = false,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    List<dynamic>? rulesJson,
    bool isReminder = false,
    String? reminderUuid,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No user session. Please sign in.');
    }

    final payload = <String, dynamic>{
      'user_id': user.id,
      'name': name,
      'color': color,
      'active': active,
      'is_saved': isSaved,
      'rules': rulesJson ?? <dynamic>[],
      'is_hidden': isHidden,
      'is_reminder': isReminder,
    };
    if (startDate != null) {
      payload['start_date'] = startDate.toUtc().toIso8601String();
    }
    if (endDate != null) {
      payload['end_date'] = endDate.toUtc().toIso8601String();
    }
    if (notes != null) {
      payload['notes'] = notes;
    }
    if (reminderUuid != null) {
      payload['reminder_uuid'] = reminderUuid;
    }

    if (id == null) {
      final row = await _client.from(_kFlows).insert(payload).select().single();
      return FlowRow.fromRow(row as Map<String, dynamic>);
    } else {
      final patch = Map<String, dynamic>.from(payload)..remove('user_id');
      final row = await _client
          .from(_kFlows)
          .update(patch)
          .eq('id', id)
          .select()
          .single();
      return FlowRow.fromRow(row as Map<String, dynamic>);
    }
  }

  Future<int> insert({
    required String name,
    required int color,
    required bool active,
    bool isSaved = false,
    bool isHidden = false,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    required List<dynamic> rulesJson,
    bool isReminder = false,
    String? reminderUuid,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('No user session.');
    final payload = {
      'user_id': user.id,
      'name': name,
      'color': color,
      'active': active,
      'is_saved': isSaved,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'notes': notes,
      'rules': rulesJson,
      'is_hidden': isHidden,
      'is_reminder': isReminder,
      'reminder_uuid': reminderUuid,
    };
    _log('insert → $payload');
    final row =
        await _client.from(_kFlows).insert(payload).select().single()
            as Map<String, dynamic>;
    final id = (row['id'] as num).toInt();
    _log('insert ✓ id=$id');
    return id;
  }

  Future<void> update({
    required int id,
    required String name,
    required int color,
    required bool active,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    required List<dynamic> rulesJson,
    bool isReminder = false,
    String? reminderUuid,
  }) async {
    final patch = {
      'name': name,
      'color': color,
      'active': active,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'notes': notes,
      'rules': rulesJson,
      'is_reminder': isReminder,
      'reminder_uuid': reminderUuid,
    };
    _log('update($id) → $patch');
    await _client.from(_kFlows).update(patch).eq('id', id);
    _log('update ✓');
  }

  Future<void> delete(int id) async {
    _log('delete($id)');
    await _client.from(_kFlows).delete().eq('id', id);
    _log('delete ✓');
  }

  Future<List<FlowRow>> fetchAll() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No user session.');
    }

    _log('fetchAll');
    final rows = await _client
        .from(_kFlows)
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    _log('fetchAll ✓ ${rows.length} rows');
    final flows = (rows as List)
        .map((r) => FlowRow.fromRow(r as Map<String, dynamic>))
        .where((f) => _isActiveByEndDate(f.endDate))
        .toList();
    return flows;
  }

  Future<List<FlowRow>> listMyFlows({int limit = 200}) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    final rows =
        await _client
                .from(_kFlows)
                .select()
                .eq('user_id', user.id)
                .eq('active', true)
                .order('updated_at', ascending: false)
                .limit(limit)
            as List<dynamic>;
    final flows = rows
        .cast<Map<String, dynamic>>()
        .map(FlowRow.fromRow)
        .where((f) => _isActiveByEndDate(f.endDate))
        .toList();
    return flows;
  }

  /// List flows for the current user without filtering by active/end dates.
  /// Useful for chooser UIs where inactive or saved flows should still appear.
  Future<List<FlowRow>> listMyFlowsUnfiltered({int limit = 500}) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    final rows =
        await _client
                .from(_kFlows)
                .select()
                .eq('user_id', user.id)
                .order('created_at', ascending: false)
                .limit(limit)
            as List<dynamic>;
    return rows.cast<Map<String, dynamic>>().map(FlowRow.fromRow).toList();
  }

  /// Fetch a single flow by ID
  Future<FlowRow?> getFlowById(int id) async {
    final response = await _client
        .from(_kFlows)
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return FlowRow.fromRow(response as Map<String, dynamic>);
  }

  /// Fetch a flow id by reminder_uuid.
  Future<int?> getFlowIdByReminderUuid(String reminderUuid) async {
    try {
      final response = await _client
          .from(_kFlows)
          .select('id')
          .eq('reminder_uuid', reminderUuid)
          .maybeSingle();
      return response?['id'] as int?;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[flows] getFlowIdByReminderUuid failed: $e');
      }
      return null;
    }
  }
}
