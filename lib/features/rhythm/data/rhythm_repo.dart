import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/rhythm_models.dart';

class RhythmRepoResult<T> {
  final T data;
  final bool missingTables;
  final String? friendlyError;

  const RhythmRepoResult({
    required this.data,
    this.missingTables = false,
    this.friendlyError,
  });
}

class RhythmRepo {
  RhythmRepo(this._client);

  final SupabaseClient _client;

  String get _supabaseUrl {
    const restSuffix = '/rest/v1';
    final restUrl = _client.rest.url;
    return restUrl.endsWith(restSuffix)
        ? restUrl.substring(0, restUrl.length - restSuffix.length)
        : restUrl;
  }

  String? get _userId => _client.auth.currentUser?.id;
  String get _projectRef =>
      Uri.tryParse(_supabaseUrl)?.host.split('.').first ?? '';

  void _logNoteAction(
    String action, {
    bool? missingTables,
    String? friendlyError,
    Object? error,
    String? detail,
  }) {
    final uid = _userId ?? '<null>';
    final url = _supabaseUrl;
    final buf = StringBuffer(
      '[planner-notes] $action uid=$uid url=$url ref=$_projectRef',
    );
    if (missingTables != null) buf.write(' missingTables=$missingTables');
    if (friendlyError != null) buf.write(' friendlyError="$friendlyError"');
    if (error != null) {
      if (error is PostgrestException) {
        buf.write(' postgrest=${error.code ?? ''}:${error.message}');
      } else {
        buf.write(' error=$error');
      }
    }
    if (detail != null) buf.write(' $detail');
    debugPrint(buf.toString());
  }

  /// Today's alignment: cycle fields (checklist-enabled) plus any checklist state (if present).
  Future<RhythmRepoResult<List<RhythmItem>>> fetchTodaysAlignment() async {
    final uid = _userId;
    if (uid == null) {
      return RhythmRepoResult(data: const []);
    }
    try {
      final today = DateTime.now();
      final todayIso = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(today.year, today.month, today.day));

      final fields = await _client
          .from('cycle_fields')
          .select(
            'id, title, description, slug, checklist_enabled, reminder_enabled, tracker_enabled, metadata, value_json',
          )
          .eq('user_id', uid)
          .eq('checklist_enabled', true);

      Map<String, String> statusByFieldId = {};
      try {
        final checklistRows = await _client
            .from('checklist_items')
            .select('field_id, status')
            .eq('user_id', uid)
            .eq('local_date', todayIso);
        statusByFieldId = {
          for (final row in checklistRows)
            if (row['field_id'] != null)
              row['field_id'] as String: row['status'] as String,
        };
      } catch (e) {
        // Missing checklist table is acceptable; leave empty.
        if (!_isMissingTable(e)) rethrow;
      }

      final items = <RhythmItem>[];
      for (final f in fields) {
        final id = f['id'] as String? ?? '';
        final title = f['title'] as String? ?? 'Rhythm item';
        final desc = f['description'] as String? ?? '';
        final status = statusByFieldId[id];
        items.add(
          RhythmItem(
            title: title,
            summary: desc.isEmpty ? 'Move with intention' : desc,
            chips: _chipsForFlags(
              checklist: (f['checklist_enabled'] as bool?) ?? false,
              reminder: (f['reminder_enabled'] as bool?) ?? false,
              tracker: (f['tracker_enabled'] as bool?) ?? false,
            ),
            state: _statusToState(status),
            isTimed: _isTimed(f),
          ),
        );
      }
      return RhythmRepoResult(data: items);
    } catch (e) {
      if (_isMissingTable(e)) {
        return const RhythmRepoResult(
          data: <RhythmItem>[],
          missingTables: true,
        );
      }
      return RhythmRepoResult(
        data: const [],
        friendlyError: _friendlyMessage(e),
      );
    }
  }

  Future<RhythmRepoResult<List<RhythmTodo>>> fetchTodos() async {
    final uid = _userId;
    if (uid == null) return RhythmRepoResult(data: const []);
    try {
      final rows = await _client
          .from('todos')
          .select(
            'id, title, notes, due_date, due_time, show_on_checklist, show_on_calendar, status',
          )
          .eq('user_id', uid)
          .order('created_at', ascending: true);

      final todos = rows
          .map<RhythmTodo>(
            (row) => _todoFromRow(Map<String, dynamic>.from(row)),
          )
          .toList();
      return RhythmRepoResult(data: todos);
    } catch (e) {
      if (_isMissingTable(e)) {
        return const RhythmRepoResult(
          data: <RhythmTodo>[],
          missingTables: true,
        );
      }
      return RhythmRepoResult(
        data: const [],
        friendlyError: _friendlyMessage(e),
      );
    }
  }

  /// Quick-add from Today's Alignment and return the saved row so the page
  /// can update locally without a full reload.
  Future<RhythmRepoResult<RhythmTodo?>> insertTodaysCommitment(
    String title, {
    DateTime? dueDate,
  }) async {
    final uid = _userId;
    if (uid == null) {
      return const RhythmRepoResult(data: null, friendlyError: 'Not signed in');
    }
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return const RhythmRepoResult(data: null);
    }
    final target = DateUtils.dateOnly(dueDate ?? DateTime.now());
    final todayIso = DateFormat('yyyy-MM-dd').format(target);
    try {
      final row = await _client
          .from('todos')
          .insert({
            'user_id': uid,
            'title': trimmed,
            'due_date': todayIso,
            'show_on_checklist': true,
            'show_on_calendar': true,
            'status': 'pending',
          })
          .select(
            'id, title, notes, due_date, due_time, show_on_checklist, show_on_calendar, status',
          )
          .maybeSingle();
      if (row == null) {
        return const RhythmRepoResult(data: null);
      }
      return RhythmRepoResult(
        data: _todoFromRow(Map<String, dynamic>.from(row)),
      );
    } catch (e) {
      if (_isMissingTable(e)) {
        return const RhythmRepoResult(data: null, missingTables: true);
      }
      return RhythmRepoResult(data: null, friendlyError: _friendlyMessage(e));
    }
  }

  Future<RhythmRepoResult<List<RhythmTodo>>> insertTodos(
    List<RhythmTodoDraft> drafts,
  ) async {
    final uid = _userId;
    if (uid == null) {
      return const RhythmRepoResult(
        data: <RhythmTodo>[],
        friendlyError: 'Not signed in',
      );
    }
    final rows = drafts
        .map((draft) {
          final title = draft.title.trim();
          if (title.isEmpty) return null;
          final dueDate = draft.dueDate == null
              ? null
              : DateFormat(
                  'yyyy-MM-dd',
                ).format(DateUtils.dateOnly(draft.dueDate!));
          return <String, dynamic>{
            'user_id': uid,
            'title': title,
            if (draft.notes?.trim().isNotEmpty == true)
              'notes': draft.notes!.trim(),
            if (dueDate != null) 'due_date': dueDate,
            if (draft.dueTime != null) 'due_time': _formatDbTime(draft.dueTime),
            'show_on_checklist': true,
            'show_on_calendar': true,
            'status': 'pending',
            if (draft.metadata.isNotEmpty) 'metadata': draft.metadata,
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    if (rows.isEmpty) return const RhythmRepoResult(data: <RhythmTodo>[]);

    try {
      final response = await _client
          .from('todos')
          .insert(rows)
          .select(
            'id, title, notes, due_date, due_time, show_on_checklist, show_on_calendar, status',
          );
      final todos = response
          .map<RhythmTodo>(
            (row) => _todoFromRow(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      return RhythmRepoResult(data: todos);
    } catch (e) {
      if (_isMissingTable(e)) {
        return const RhythmRepoResult(
          data: <RhythmTodo>[],
          missingTables: true,
        );
      }
      return RhythmRepoResult(
        data: const <RhythmTodo>[],
        friendlyError: _friendlyMessage(e),
      );
    }
  }

  Future<RhythmRepoResult<bool>> updateTodoState(
    String todoId,
    RhythmItemState state,
  ) async {
    final uid = _userId;
    if (uid == null) {
      return const RhythmRepoResult(
        data: false,
        friendlyError: 'Not signed in',
      );
    }
    final status = _stateToDbString(state);
    final payload = <String, dynamic>{
      'status': status,
      'completed_at': state == RhythmItemState.done
          ? DateTime.now().toUtc().toIso8601String()
          : null,
    };
    try {
      await _client
          .from('todos')
          .update(payload)
          .eq('id', todoId)
          .eq('user_id', uid);
      return const RhythmRepoResult(data: true);
    } catch (e) {
      if (_isMissingTable(e)) {
        return const RhythmRepoResult(data: false, missingTables: true);
      }
      return RhythmRepoResult(data: false, friendlyError: _friendlyMessage(e));
    }
  }

  Future<RhythmRepoResult<bool>> deleteTodo(String todoId) async {
    final uid = _userId;
    if (uid == null) {
      return const RhythmRepoResult(
        data: false,
        friendlyError: 'Not signed in',
      );
    }
    try {
      await _client.from('todos').delete().eq('id', todoId).eq('user_id', uid);
      return const RhythmRepoResult(data: true);
    } catch (e) {
      if (_isMissingTable(e)) {
        return const RhythmRepoResult(data: false, missingTables: true);
      }
      return RhythmRepoResult(data: false, friendlyError: _friendlyMessage(e));
    }
  }

  String _stateToDbString(RhythmItemState state) {
    switch (state) {
      case RhythmItemState.done:
        return 'done';
      case RhythmItemState.partial:
        return 'in_progress';
      case RhythmItemState.skipped:
        return 'skipped';
      case RhythmItemState.pending:
        return 'pending';
    }
  }

  /// Continuity view: derive simple progress counts from tracker-enabled fields and checklist data.
  Future<RhythmRepoResult<List<ContinuitySnapshot>>> fetchContinuity({
    String scope = 'Yearly',
  }) async {
    final uid = _userId;
    if (uid == null) return RhythmRepoResult(data: const []);
    try {
      final fields = await _client
          .from('cycle_fields')
          .select(
            'id, title, tracker_enabled, reminder_enabled, checklist_enabled',
          )
          .eq('user_id', uid)
          .eq('tracker_enabled', true);

      final today = DateTime.now();
      final todayStr = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(today.year, today.month, today.day));
      final daysBack = switch (scope) {
        'Weekly' => 6,
        'Monthly' => 29,
        _ => 364,
      };
      final start = today.subtract(Duration(days: daysBack));
      final startStr = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(start.year, start.month, start.day));
      List<Map<String, dynamic>> checklist = [];
      try {
        checklist = await _client
            .from('checklist_items')
            .select('field_id, status, local_date')
            .eq('user_id', uid)
            .gte('local_date', startStr)
            .lte('local_date', todayStr);
      } catch (e) {
        if (!_isMissingTable(e)) rethrow;
      }

      final byField = <String, List<ContinuityBlockState>>{};
      for (final row in checklist) {
        final fieldId = row['field_id'] as String?;
        if (fieldId == null) continue;
        byField.putIfAbsent(fieldId, () => []);
        byField[fieldId]!.add(_statusToBlock(row['status'] as String?));
      }

      final slotCount = daysBack + 1;
      final snapshots = fields.map<ContinuitySnapshot>((f) {
        final fieldId = f['id'] as String? ?? '';
        final raw = byField[fieldId] ?? const [];
        final completed = raw
            .where((b) => b == ContinuityBlockState.done)
            .length;
        final planned = raw.isEmpty ? slotCount : raw.length;
        final percent = planned == 0 ? 0.0 : completed / planned;
        final blocks = raw.isEmpty
            ? List<ContinuityBlockState>.filled(
                slotCount,
                ContinuityBlockState.unscheduled,
              )
            : raw;
        return ContinuitySnapshot(
          title: f['title'] as String? ?? 'Rhythm item',
          percent: percent,
          completed: completed,
          planned: planned,
          blocks: blocks,
        );
      }).toList();

      return RhythmRepoResult(data: snapshots);
    } catch (e) {
      if (_isMissingTable(e)) {
        return const RhythmRepoResult(
          data: <ContinuitySnapshot>[],
          missingTables: true,
        );
      }
      return RhythmRepoResult(
        data: const [],
        friendlyError: _friendlyMessage(e),
      );
    }
  }

  Future<RhythmRepoResult<List<RhythmNote>>> fetchAlignmentNotes() async {
    final uid = _userId;
    if (uid == null) {
      _logNoteAction(
        'fetch_alignment_notes',
        friendlyError: 'Not signed in',
        detail: 'skipped Supabase fetch (uid missing)',
      );
      return const RhythmRepoResult(data: <RhythmNote>[]);
    }
    _logNoteAction('fetch_alignment_notes:start');
    try {
      final rows = await _client
          .from('alignment_notes')
          .select('id, body, position, created_at')
          .eq('user_id', uid)
          .order('position', ascending: true)
          .order('created_at', ascending: true);

      final notes = rows.map<RhythmNote>((r) {
        return RhythmNote(
          id: r['id'] as String? ?? '',
          text: r['body'] as String? ?? '',
          position: (r['position'] as num?)?.toInt() ?? 0,
          createdAt:
              DateTime.tryParse(r['created_at'] as String? ?? '') ??
              DateTime.now(),
        );
      }).toList();

      _logNoteAction(
        'fetch_alignment_notes:success',
        missingTables: false,
        detail: 'count=${notes.length}',
      );
      return RhythmRepoResult(data: notes);
    } catch (e) {
      if (_isMissingTable(e)) {
        _logNoteAction(
          'fetch_alignment_notes:missing',
          missingTables: true,
          error: e,
        );
        return const RhythmRepoResult(
          data: <RhythmNote>[],
          missingTables: true,
        );
      }
      final friendly = _friendlyMessage(e);
      _logNoteAction(
        'fetch_alignment_notes:error',
        missingTables: false,
        friendlyError: friendly,
        error: e,
      );
      return RhythmRepoResult(data: const [], friendlyError: friendly);
    }
  }

  Future<RhythmRepoResult<RhythmNote?>> insertAlignmentNote(
    String text, {
    int position = 0,
  }) async {
    final uid = _userId;
    if (uid == null) {
      _logNoteAction(
        'insert_alignment_note',
        friendlyError: 'Not signed in',
        detail: 'skipped Supabase insert (uid missing)',
      );
      return const RhythmRepoResult(data: null, friendlyError: 'Not signed in');
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const RhythmRepoResult(data: null);
    }
    _logNoteAction('insert_alignment_note:start', detail: 'position=$position');
    try {
      final row = await _client
          .from('alignment_notes')
          .insert({'user_id': uid, 'body': trimmed, 'position': position})
          .select('id, body, position, created_at')
          .maybeSingle();

      if (row == null) return const RhythmRepoResult(data: null);

      _logNoteAction(
        'insert_alignment_note:success',
        missingTables: false,
        detail: 'noteId=${row['id'] ?? ''}',
      );
      return RhythmRepoResult(
        data: RhythmNote(
          id: row['id'] as String? ?? '',
          text: row['body'] as String? ?? trimmed,
          position: (row['position'] as num?)?.toInt() ?? position,
          createdAt:
              DateTime.tryParse(row['created_at'] as String? ?? '') ??
              DateTime.now(),
        ),
      );
    } catch (e) {
      if (_isMissingTable(e)) {
        _logNoteAction(
          'insert_alignment_note:missing',
          missingTables: true,
          error: e,
        );
        return const RhythmRepoResult(data: null, missingTables: true);
      }
      final friendly = _friendlyMessage(e);
      _logNoteAction(
        'insert_alignment_note:error',
        missingTables: false,
        friendlyError: friendly,
        error: e,
      );
      return RhythmRepoResult(data: null, friendlyError: friendly);
    }
  }

  Future<RhythmRepoResult<bool>> updateAlignmentNote(
    String noteId,
    String text,
  ) async {
    final uid = _userId;
    if (uid == null) {
      _logNoteAction(
        'update_alignment_note',
        friendlyError: 'Not signed in',
        detail: 'skipped Supabase update (uid missing) noteId=$noteId',
      );
      return const RhythmRepoResult(
        data: false,
        friendlyError: 'Not signed in',
      );
    }
    _logNoteAction('update_alignment_note:start', detail: 'noteId=$noteId');
    try {
      await _client
          .from('alignment_notes')
          .update({'body': text.trim()})
          .eq('id', noteId)
          .eq('user_id', uid);
      _logNoteAction(
        'update_alignment_note:success',
        missingTables: false,
        detail: 'noteId=$noteId',
      );
      return const RhythmRepoResult(data: true);
    } catch (e) {
      if (_isMissingTable(e)) {
        _logNoteAction(
          'update_alignment_note:missing',
          missingTables: true,
          error: e,
        );
        return const RhythmRepoResult(data: false, missingTables: true);
      }
      final friendly = _friendlyMessage(e);
      _logNoteAction(
        'update_alignment_note:error',
        missingTables: false,
        friendlyError: friendly,
        error: e,
      );
      return RhythmRepoResult(data: false, friendlyError: friendly);
    }
  }

  Future<RhythmRepoResult<bool>> deleteAlignmentNote(String noteId) async {
    final uid = _userId;
    if (uid == null) {
      _logNoteAction(
        'delete_alignment_note',
        friendlyError: 'Not signed in',
        detail: 'skipped Supabase delete (uid missing) noteId=$noteId',
      );
      return const RhythmRepoResult(
        data: false,
        friendlyError: 'Not signed in',
      );
    }
    _logNoteAction('delete_alignment_note:start', detail: 'noteId=$noteId');
    try {
      await _client
          .from('alignment_notes')
          .delete()
          .eq('id', noteId)
          .eq('user_id', uid);
      _logNoteAction(
        'delete_alignment_note:success',
        missingTables: false,
        detail: 'noteId=$noteId',
      );
      return const RhythmRepoResult(data: true);
    } catch (e) {
      if (_isMissingTable(e)) {
        _logNoteAction(
          'delete_alignment_note:missing',
          missingTables: true,
          error: e,
        );
        return const RhythmRepoResult(data: false, missingTables: true);
      }
      final friendly = _friendlyMessage(e);
      _logNoteAction(
        'delete_alignment_note:error',
        missingTables: false,
        friendlyError: friendly,
        error: e,
      );
      return RhythmRepoResult(data: false, friendlyError: friendly);
    }
  }

  Future<RhythmRepoResult<bool>> reorderAlignmentNotes(
    List<RhythmNote> notes,
  ) async {
    final uid = _userId;
    if (uid == null) {
      _logNoteAction(
        'reorder_alignment_notes',
        friendlyError: 'Not signed in',
        detail: 'skipped Supabase reorder (uid missing)',
      );
      return const RhythmRepoResult(
        data: false,
        friendlyError: 'Not signed in',
      );
    }
    if (notes.isEmpty) return const RhythmRepoResult(data: true);
    _logNoteAction(
      'reorder_alignment_notes:start',
      detail: 'count=${notes.length}',
    );
    try {
      final payload = [
        for (final n in notes)
          {'id': n.id, 'user_id': uid, 'position': n.position, 'body': n.text},
      ];
      await _client.from('alignment_notes').upsert(payload);
      _logNoteAction(
        'reorder_alignment_notes:success',
        missingTables: false,
        detail: 'count=${notes.length}',
      );
      return const RhythmRepoResult(data: true);
    } catch (e) {
      if (_isMissingTable(e)) {
        _logNoteAction(
          'reorder_alignment_notes:missing',
          missingTables: true,
          error: e,
        );
        return const RhythmRepoResult(data: false, missingTables: true);
      }
      final friendly = _friendlyMessage(e);
      _logNoteAction(
        'reorder_alignment_notes:error',
        missingTables: false,
        friendlyError: friendly,
        error: e,
      );
      return RhythmRepoResult(data: false, friendlyError: friendly);
    }
  }

  String? _formatDbTime(TimeOfDay? t) {
    if (t == null) return null;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm:00';
  }

  List<RhythmChipKind> _chipsForFlags({
    required bool checklist,
    required bool reminder,
    required bool tracker,
  }) {
    final chips = <RhythmChipKind>[];
    if (checklist) chips.add(RhythmChipKind.alignment);
    if (reminder) chips.add(RhythmChipKind.reminder);
    if (tracker) chips.add(RhythmChipKind.continuity);
    return chips;
  }

  TimeOfDay? _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  RhythmTodo _todoFromRow(Map<String, dynamic> row) {
    final dueDate = row['due_date'] != null
        ? DateTime.parse(row['due_date'] as String)
        : null;
    final dueTimeStr = row['due_time'] as String?;
    final time = dueTimeStr != null ? _parseTime(dueTimeStr) : null;
    return RhythmTodo(
      id: row['id'] as String? ?? '',
      title: row['title'] as String? ?? 'Task',
      notes: row['notes'] as String?,
      dueDate: dueDate,
      dueTime: time,
      isChecklist: (row['show_on_checklist'] as bool?) ?? true,
      isCalendar: (row['show_on_calendar'] as bool?) ?? true,
      state: _statusToState(row['status'] as String?),
    );
  }

  RhythmItemState _statusToState(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'done':
        return RhythmItemState.done;
      case 'partial':
      case 'in_progress':
        return RhythmItemState.partial;
      case 'skipped':
      case 'archived':
        return RhythmItemState.skipped;
      default:
        return RhythmItemState.pending;
    }
  }

  ContinuityBlockState _statusToBlock(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'done':
        return ContinuityBlockState.done;
      case 'partial':
      case 'in_progress':
        return ContinuityBlockState.partial;
      case 'skipped':
      case 'archived':
        return ContinuityBlockState.skipped;
      default:
        return ContinuityBlockState.unscheduled;
    }
  }

  bool _isTimed(Map<String, dynamic> field) {
    final meta = _asMap(field['metadata']) ?? _asMap(field['value_json']) ?? {};
    return (meta['is_timed'] as bool?) ?? false;
  }

  Map<String, dynamic>? _asMap(dynamic v) {
    if (v == null) return null;
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  bool _isMissingTable(Object e) {
    if (e is PostgrestException) {
      final msg = e.message.toLowerCase();
      final code = e.code?.toUpperCase() ?? '';
      return msg.contains('does not exist') ||
          msg.contains('could not find') ||
          msg.contains('schema cache') ||
          msg.contains('pgrst') ||
          code == 'PGRST205' ||
          code == '42P01';
    }
    return false;
  }

  String _friendlyMessage(Object e) {
    if (e is PostgrestException) {
      return 'We could not reach your rhythm data. Check your connection and try again.';
    }
    return 'We could not reach your rhythm data. Check your connection and try again.';
  }
}
