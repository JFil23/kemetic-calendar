// lib/data/flows_repo.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';


const _kFlows = 'flows';

void _log(String msg) {
  if (kDebugMode) debugPrint('[flows] $msg');
}

@immutable
class FlowRow {
  final int id;
  final String userId;
  final String name;
  final int color;
  final bool active;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;
  final List<dynamic> rules; // store your _FlowRule list as JSON-serializable

  const FlowRow({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
    required this.active,
    required this.startDate,
    required this.endDate,
    required this.notes,
    required this.rules,
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
      color: (r['color'] as num).toInt(),
      active: (r['active'] as bool?) ?? true,
      startDate: _d(r['start_date']),
      endDate: _d(r['end_date']),
      notes: r['notes'] as String?,
      rules: _rulesList,
    );
  }

  Map<String, dynamic> toInsert({required String userId}) => {
    'user_id': userId,
    'name': name,
    'color': color,
    'active': active,
    'start_date': startDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'notes': notes,
    'rules': rules,
  };

  Map<String, dynamic> toUpdate() => {
    'name': name,
    'color': color,
    'active': active,
    'start_date': startDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'notes': notes,
    'rules': rules,
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
        .map((rows) => rows
        .cast<Map<String, dynamic>>()
        .map(FlowRow.fromRow)
        .where((f) =>
    f.userId == user.id && // guard if RLS is loose
        f.active == true &&
        f.endDate == null)
        .toList());
  }


  Future<FlowRow> upsert({
    int? id, // null → insert; non-null → update
    required String name,
    required int color,
    required bool active,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    List<dynamic>? rulesJson,
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
      'start_date': startDate?.toUtc().toIso8601String(),
      'end_date': endDate?.toUtc().toIso8601String(),
      'notes': notes,
      'rules': rulesJson ?? <dynamic>[],
    };

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
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    required List<dynamic> rulesJson,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('No user session.');
    final payload = {
      'user_id': user.id,
      'name': name,
      'color': color,
      'active': active,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'notes': notes,
      'rules': rulesJson,
    };
    _log('insert → $payload');
    final row =
    await _client.from(_kFlows).insert(payload).select().single() as Map<String, dynamic>;
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
  }) async {
    final patch = {
      'name': name,
      'color': color,
      'active': active,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'notes': notes,
      'rules': rulesJson,
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
    return (rows as List).map((r) => FlowRow.fromRow(r as Map<String, dynamic>)).toList();
  }
  Future<List<FlowRow>> listMyFlows({int limit = 200}) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    final rows = await _client
        .from(_kFlows)
        .select()
        .eq('user_id', user.id)
        .eq('active', true)
        .filter('end_date', 'is', null)
        .order('updated_at', ascending: false)
        .limit(limit) as List<dynamic>;
    return rows.cast<Map<String, dynamic>>().map(FlowRow.fromRow).toList();
  }


}
