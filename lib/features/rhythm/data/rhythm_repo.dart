import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/rhythm_models.dart';
import '../viewmodels/rhythm_draft.dart';

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
  String get _projectRef => Uri.tryParse(_supabaseUrl)?.host.split('.').first ?? '';

  void _logNoteAction(
    String action, {
    bool? missingTables,
    String? friendlyError,
    Object? error,
    String? detail,
  }) {
    final uid = _userId ?? '<null>';
    final url = _supabaseUrl;
    final buf = StringBuffer('[planner-notes] $action uid=$uid url=$url ref=$_projectRef');
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

  /// Load the user's cycle fields + schedule rules, mapped to UI-friendly sections.
  Future<RhythmRepoResult<List<RhythmSection>>> fetchMyCycle() async {
    final uid = _userId;
    if (uid == null) {
      return RhythmRepoResult(data: const []);
    }
    try {
      final fields = await _client
          .from('cycle_fields')
          .select(
              'id, title, description, slug, checklist_enabled, reminder_enabled, tracker_enabled, metadata, value_json')
          .eq('user_id', uid)
          .order('created_at', ascending: true);

      final rules = await _client
          .from('cycle_schedule_rules')
          .select(
              'id, field_id, title, days_of_week, all_day, start_time_local, end_time_local, reminder_offset_minutes, is_optional')
          .eq('user_id', uid)
          .order('created_at', ascending: true);

      final ruleByField = <String, List<Map<String, dynamic>>>{};
      for (final r in rules) {
        final fieldId = r['field_id'] as String?;
        if (fieldId == null) continue;
        ruleByField.putIfAbsent(fieldId, () => []).add(Map<String, dynamic>.from(r));
      }

      final sections = _groupFieldsIntoSections(fields, ruleByField);
      return RhythmRepoResult(data: sections);
    } catch (e) {
      if (_isMissingTable(e)) {
        return const RhythmRepoResult(data: <RhythmSection>[], missingTables: true);
      }
      return RhythmRepoResult(
        data: const [],
        friendlyError: _friendlyMessage(e),
      );
    }
  }

  /// Today's alignment: cycle fields (checklist-enabled) plus any checklist state (if present).
  Future<RhythmRepoResult<List<RhythmItem>>> fetchTodaysAlignment() async {
    final uid = _userId;
    if (uid == null) {
      return RhythmRepoResult(data: const []);
    }
    try {
      final today = DateTime.now();
      final todayIso = DateFormat('yyyy-MM-dd').format(
        DateTime(today.year, today.month, today.day),
      );

      final fields = await _client
          .from('cycle_fields')
          .select('id, title, description, slug, checklist_enabled, reminder_enabled, tracker_enabled, metadata, value_json')
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
            if (row['field_id'] != null) row['field_id'] as String: row['status'] as String
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
        return const RhythmRepoResult(data: <RhythmItem>[], missingTables: true);
      }
      return RhythmRepoResult(data: const [], friendlyError: _friendlyMessage(e));
    }
  }

  Future<RhythmRepoResult<List<RhythmTodo>>> fetchTodos() async {
    final uid = _userId;
    if (uid == null) return RhythmRepoResult(data: const []);
    try {
      final rows = await _client
          .from('todos')
          .select(
              'id, title, notes, due_date, due_time, show_on_checklist, show_on_calendar, status')
          .eq('user_id', uid)
          .order('created_at', ascending: true);

      final todos = rows.map<RhythmTodo>((row) {
        final dueDate = row['due_date'] != null ? DateTime.parse(row['due_date'] as String) : null;
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
      }).toList();
      return RhythmRepoResult(data: todos);
    } catch (e) {
      if (_isMissingTable(e)) {
        return const RhythmRepoResult(data: <RhythmTodo>[], missingTables: true);
      }
      return RhythmRepoResult(data: const [], friendlyError: _friendlyMessage(e));
    }
  }

  /// Quick-add from Today's Alignment: title only, due today, on checklist.
  Future<RhythmRepoResult<bool>> insertTodaysCommitment(String title) async {
    final uid = _userId;
    if (uid == null) {
      return const RhythmRepoResult(data: false, friendlyError: 'Not signed in');
    }
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return const RhythmRepoResult(data: false);
    }
    final todayIso = DateFormat('yyyy-MM-dd').format(
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    );
    try {
      await _client.from('todos').insert({
        'user_id': uid,
        'title': trimmed,
        'due_date': todayIso,
        'show_on_checklist': true,
        'show_on_calendar': true,
        'status': 'pending',
      });
      return const RhythmRepoResult(data: true);
    } catch (e) {
      if (_isMissingTable(e)) {
        return const RhythmRepoResult(data: false, missingTables: true);
      }
      return RhythmRepoResult(data: false, friendlyError: _friendlyMessage(e));
    }
  }

  Future<RhythmRepoResult<bool>> updateTodoState(String todoId, RhythmItemState state) async {
    final uid = _userId;
    if (uid == null) {
      return const RhythmRepoResult(data: false, friendlyError: 'Not signed in');
    }
    final status = _stateToDbString(state);
    final payload = <String, dynamic>{
      'status': status,
      'completed_at': state == RhythmItemState.done ? DateTime.now().toUtc().toIso8601String() : null,
    };
    try {
      await _client.from('todos').update(payload).eq('id', todoId).eq('user_id', uid);
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
          .select('id, title, tracker_enabled, reminder_enabled, checklist_enabled')
          .eq('user_id', uid)
          .eq('tracker_enabled', true);

      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(
        DateTime(today.year, today.month, today.day),
      );
      final daysBack = switch (scope) {
        'Weekly' => 6,
        'Monthly' => 29,
        _ => 364,
      };
      final start = today.subtract(Duration(days: daysBack));
      final startStr = DateFormat('yyyy-MM-dd').format(
        DateTime(start.year, start.month, start.day),
      );
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
        final completed = raw.where((b) => b == ContinuityBlockState.done).length;
        final planned = raw.isEmpty ? slotCount : raw.length;
        final percent = planned == 0 ? 0.0 : completed / planned;
        final blocks = raw.isEmpty
            ? List<ContinuityBlockState>.filled(slotCount, ContinuityBlockState.unscheduled)
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
        return const RhythmRepoResult(data: <ContinuitySnapshot>[], missingTables: true);
      }
      return RhythmRepoResult(data: const [], friendlyError: _friendlyMessage(e));
    }
  }

  /// Upsert a rhythm field (timed or untimed). Returns field id on success.
  Future<RhythmRepoResult<String>> saveDraft(RhythmDraft draft) async {
    final uid = _userId;
    if (uid == null) return RhythmRepoResult(data: '');
    try {
      final slug = _slugify(draft.title, draft.id);
      final sectionKey = _displayCategoryToSectionKey(draft.category);
      final payload = {
        'user_id': uid,
        'slug': slug,
        'title': draft.title,
        'description': draft.description,
        'checklist_enabled': draft.showInAlignment,
        'reminder_enabled': draft.sendReminders,
        'tracker_enabled': draft.trackContinuity,
        'metadata': {
          'category': draft.category,
          'section_key': sectionKey,
          'is_timed': draft.isTimed,
        },
        'value_json': {
          'category': draft.category,
          'section_key': sectionKey,
          'is_timed': draft.isTimed,
        },
      };

      String fieldId;
      final existingId = draft.id;
      if (existingId != null) {
        final res = await _client
            .from('cycle_fields')
            .update(payload)
            .eq('id', existingId)
            .eq('user_id', uid)
            .select('id')
            .maybeSingle();
        fieldId = (res?['id'] as String?) ?? existingId;
      } else {
        final res = await _client.from('cycle_fields').insert(payload).select('id').maybeSingle();
        fieldId = res?['id'] as String? ?? '';
      }

      // Replace schedule rules for this field based on patterns.
      try {
        await _client.from('cycle_schedule_rules').delete().eq('field_id', fieldId).eq('user_id', uid);
        if (draft.patterns.isNotEmpty) {
          final rows = draft.patterns.map((p) {
            return {
              'user_id': uid,
              'field_id': fieldId,
              'days_of_week': p.daysOfWeek,
              'all_day': p.allDay,
              'start_time_local': _formatDbTime(p.start),
              'end_time_local': _formatDbTime(p.end),
              'is_optional': p.isOptional,
            };
          }).toList();
          await _client.from('cycle_schedule_rules').insert(rows);
        }
      } catch (e) {
        if (!_isMissingTable(e)) rethrow;
      }

      return RhythmRepoResult(data: fieldId);
    } catch (e) {
      if (_isMissingTable(e)) {
        return const RhythmRepoResult(data: '', missingTables: true);
      }
      return RhythmRepoResult(data: '', friendlyError: _friendlyMessage(e));
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
          createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ??
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
      return RhythmRepoResult(
        data: const [],
        friendlyError: friendly,
      );
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
      return const RhythmRepoResult(
        data: null,
        friendlyError: 'Not signed in',
      );
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const RhythmRepoResult(data: null);
    }
    _logNoteAction(
      'insert_alignment_note:start',
      detail: 'position=$position',
    );
    try {
      final row = await _client
          .from('alignment_notes')
          .insert({
            'user_id': uid,
            'body': trimmed,
            'position': position,
          })
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
          createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
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
      return RhythmRepoResult(
        data: null,
        friendlyError: friendly,
      );
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
      return const RhythmRepoResult(data: false, friendlyError: 'Not signed in');
    }
    _logNoteAction(
      'update_alignment_note:start',
      detail: 'noteId=$noteId',
    );
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
      return const RhythmRepoResult(data: false, friendlyError: 'Not signed in');
    }
    _logNoteAction(
      'delete_alignment_note:start',
      detail: 'noteId=$noteId',
    );
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
      return const RhythmRepoResult(data: false, friendlyError: 'Not signed in');
    }
    if (notes.isEmpty) return const RhythmRepoResult(data: true);
    _logNoteAction(
      'reorder_alignment_notes:start',
      detail: 'count=${notes.length}',
    );
    try {
      final payload = [
        for (final n in notes)
          {
            'id': n.id,
            'user_id': uid,
            'position': n.position,
          },
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

  /// Maps UI section names to stable keys stored in metadata (never shown in UI).
  String _displayCategoryToSectionKey(String display) {
    switch (display.trim()) {
      case 'Rhythm of Day':
        return 'rhythm_of_day';
      case 'Body & Nourishment':
        return 'body_nourishment';
      case 'Restoration':
        return 'restoration';
      case 'Anchors':
        return 'anchors';
      case 'Nourishing Activities':
        return 'activities';
      case 'Custom':
      default:
        return 'custom';
    }
  }

  String? _formatDbTime(TimeOfDay? t) {
    if (t == null) return null;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm:00';
  }

  String _slugify(String title, String? id) {
    final base = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final suffix = id ?? DateTime.now().millisecondsSinceEpoch.toString();
    return '$base-$suffix';
  }

  List<RhythmSection> _groupFieldsIntoSections(
    List<dynamic> fields,
    Map<String, List<Map<String, dynamic>>> rules,
  ) {
    final Map<String, List<RhythmItem>> grouped = {};
    for (final f in fields) {
      final id = f['id'] as String? ?? '';
      final title = f['title'] as String? ?? 'Rhythm item';
      final description = f['description'] as String? ?? '';
      final meta = _asMap(f['metadata']) ?? _asMap(f['value_json']) ?? {};
      final category = _categoryLabel(meta['section_key'] ?? meta['category']);
      final itemRules = rules[id] ?? const [];
      final pattern = itemRules.isEmpty ? null : _describeRules(itemRules);

      grouped.putIfAbsent(category, () => []).add(
            RhythmItem(
              title: title,
              summary: description.isEmpty ? 'Keep this beat gentle.' : description,
              pattern: pattern,
              chips: _chipsForFlags(
                checklist: (f['checklist_enabled'] as bool?) ?? false,
                reminder: (f['reminder_enabled'] as bool?) ?? false,
                tracker: (f['tracker_enabled'] as bool?) ?? false,
              ),
              isTimed: _isTimed(f),
              isCustom: category == 'Custom',
            ),
          );
    }

    const order = [
      'Rhythm of Day',
      'Body & Nourishment',
      'Restoration',
      'Anchors',
      'Nourishing Activities',
      'Custom',
    ];
    final out = <RhythmSection>[];
    for (final title in order) {
      final items = grouped[title];
      if (items != null && items.isNotEmpty) {
        out.add(RhythmSection(title: title, items: items));
      }
    }
    for (final e in grouped.entries) {
      if (!order.contains(e.key)) {
        out.add(RhythmSection(title: e.key, items: e.value));
      }
    }
    return out;
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

  String _categoryLabel(dynamic value) {
    final v = (value as String? ?? '').toLowerCase();
    switch (v) {
      case 'rhythm_of_day':
      case 'rhythm of day':
        return 'Rhythm of Day';
      case 'body':
      case 'body & nourishment':
        return 'Body & Nourishment';
      case 'restoration':
        return 'Restoration';
      case 'anchors':
        return 'Anchors';
      case 'nourishing':
      case 'nourishing activities':
      case 'activities':
        return 'Nourishing Activities';
      case 'custom':
      case '':
        return 'Custom';
      default:
        return v.isEmpty ? 'Custom' : _titleCase(v);
    }
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value
        .split(RegExp(r'[\s_]+'))
        .where((s) => s.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.length > 1 ? w.substring(1).toLowerCase() : ''}')
        .join(' ');
  }

  String _describeRules(List<Map<String, dynamic>> rules) {
    // Show the first rule succinctly; more rules can be appended.
    if (rules.isEmpty) return '';
    final primary = rules.first;
    final days = (primary['days_of_week'] as List?)?.cast<int>() ?? const [];
    final start = primary['start_time_local'] as String?;
    final end = primary['end_time_local'] as String?;
    final allDay = (primary['all_day'] as bool?) ?? false;

    final dayLabel = _daysLabel(days);
    if (allDay) return '$dayLabel — No fixed time';

    final startLabel = start != null ? _formatTime(start) : null;
    final endLabel = end != null ? _formatTime(end) : null;
    if (startLabel != null && endLabel != null) {
      return '$dayLabel — $startLabel–$endLabel';
    } else if (startLabel != null) {
      return '$dayLabel — $startLabel';
    } else if (endLabel != null) {
      return '$dayLabel — ends $endLabel';
    }
    return dayLabel;
  }

  String _daysLabel(List<int> days) {
    if (days.isEmpty) return 'Every day';
    final sorted = [...days]..sort();
    const weekdays = [1, 2, 3, 4, 5];
    const weekends = [6, 7];
    if (sorted.length == 7) return 'Every day';
    if (_listEquals(sorted, weekdays)) return 'Weekdays';
    if (_listEquals(sorted, weekends)) return 'Weekends';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return sorted.map((d) => names[(d - 1).clamp(0, 6)]).join(' / ');
  }

  String _formatTime(String value) {
    try {
      final parts = value.split(':');
      if (parts.length < 2) return value;
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1].split(':').first);
      final isPm = h >= 12;
      final h12 = h % 12 == 0 ? 12 : h % 12;
      final mm = m.toString().padLeft(2, '0');
      return '$h12:$mm ${isPm ? 'PM' : 'AM'}';
    } catch (_) {
      return value;
    }
  }

  TimeOfDay? _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
