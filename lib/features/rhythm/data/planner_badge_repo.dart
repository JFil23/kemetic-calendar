import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobile/data/nutrition_repo.dart';
import 'package:mobile/features/journal/journal_event_badge.dart';

import '../models/rhythm_models.dart';

enum PlannerBadgeKind { todo, nutrition }

class PlannerBadgeRecord {
  const PlannerBadgeRecord({
    required this.badgeId,
    required this.eventId,
    required this.kind,
    required this.state,
    required this.title,
    required this.details,
    required this.tags,
    required this.occurredOn,
  });

  final String badgeId;
  final String eventId;
  final PlannerBadgeKind kind;
  final RhythmItemState state;
  final String title;
  final String details;
  final List<String> tags;
  final DateTime occurredOn;

  EventBadgeToken toEventBadgeToken() {
    return EventBadgeToken(
      id: badgeId,
      eventId: eventId,
      title: title,
      color: PlannerBadgeRepo.colorForState(state),
      description: details.trim().isEmpty ? null : details.trim(),
    );
  }
}

class PlannerBadgeRepo {
  PlannerBadgeRepo(this._client);

  final SupabaseClient _client;
  static final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');

  String? get _userId => _client.auth.currentUser?.id;

  static String dateKey(DateTime date) =>
      _dateFormatter.format(DateUtils.dateOnly(date));

  static String nutritionStateKey(String itemId, DateTime date) =>
      '${dateKey(date)}::$itemId';

  static String todoEventId(String todoId, DateTime date) =>
      'planner-todo:${dateKey(date)}:$todoId';

  static String nutritionEventId(String itemId, DateTime date) =>
      'planner-nutrition:${dateKey(date)}:$itemId';

  static Color colorForState(RhythmItemState state) {
    switch (state) {
      case RhythmItemState.done:
        return const Color(0xFFF4C200);
      case RhythmItemState.partial:
        return const Color(0xFFFFB347);
      case RhythmItemState.skipped:
        return Colors.redAccent;
      case RhythmItemState.pending:
        return Colors.white54;
    }
  }

  static RhythmItemState stateFromTags(
    Iterable<String> tags, {
    RhythmItemState fallback = RhythmItemState.done,
  }) {
    for (final raw in tags) {
      final tag = raw.trim().toLowerCase();
      if (tag == 'state:done') return RhythmItemState.done;
      if (tag == 'state:partial' || tag == 'state:in_progress') {
        return RhythmItemState.partial;
      }
      if (tag == 'state:skipped') return RhythmItemState.skipped;
      if (tag == 'state:pending') return RhythmItemState.pending;
    }
    return fallback;
  }

  static PlannerBadgeKind? kindFromEventId(String? eventId) {
    if (eventId == null) return null;
    if (eventId.startsWith('planner-todo:')) return PlannerBadgeKind.todo;
    if (eventId.startsWith('planner-nutrition:')) {
      return PlannerBadgeKind.nutrition;
    }
    return null;
  }

  static String? nutritionStateKeyFromEventId(String? eventId) {
    if (eventId == null || !eventId.startsWith('planner-nutrition:')) {
      return null;
    }
    final parts = eventId.split(':');
    if (parts.length < 3) return null;
    final date = parts[1];
    final itemId = parts.sublist(2).join(':');
    if (date.isEmpty || itemId.isEmpty) return null;
    return '$date::$itemId';
  }

  List<String> _buildTags(PlannerBadgeKind kind, RhythmItemState state) {
    final normalizedState = switch (state) {
      RhythmItemState.done => 'done',
      RhythmItemState.partial => 'partial',
      RhythmItemState.skipped => 'skipped',
      RhythmItemState.pending => 'pending',
    };
    return <String>['planner', 'kind:${kind.name}', 'state:$normalizedState'];
  }

  String _todoTitle(RhythmTodo todo, RhythmItemState state) {
    final base = todo.title.trim().isEmpty ? 'Task' : todo.title.trim();
    switch (state) {
      case RhythmItemState.done:
        return 'Completed to-do: $base';
      case RhythmItemState.partial:
        return 'In-progress to-do: $base';
      case RhythmItemState.skipped:
        return 'Skipped to-do: $base';
      case RhythmItemState.pending:
        return 'To-do: $base';
    }
  }

  String _nutritionTitle(NutritionItem item, RhythmItemState state) {
    final label = item.nutrient.trim().isNotEmpty
        ? item.nutrient.trim()
        : (item.source.trim().isNotEmpty ? item.source.trim() : 'Nutrition');
    switch (state) {
      case RhythmItemState.done:
        return 'Completed nutrition: $label';
      case RhythmItemState.partial:
        return 'Partial nutrition: $label';
      case RhythmItemState.skipped:
        return 'Skipped nutrition: $label';
      case RhythmItemState.pending:
        return 'Nutrition: $label';
    }
  }

  String _todoDetails(RhythmTodo todo, DateTime date, RhythmItemState state) {
    final parts = <String>[
      'Planner to-do for ${dateKey(date)}.',
      'State: ${state.name}.',
    ];
    final notes = todo.notes?.trim();
    if (notes != null && notes.isNotEmpty) {
      parts.add(notes);
    }
    return parts.join(' ');
  }

  String _nutritionDetails(
    NutritionItem item,
    DateTime date,
    RhythmItemState state,
  ) {
    final parts = <String>[
      'Planner nutrition entry for ${dateKey(date)}.',
      'State: ${state.name}.',
    ];
    if (item.source.trim().isNotEmpty) {
      parts.add('Source: ${item.source.trim()}.');
    }
    if (item.purpose.trim().isNotEmpty) {
      parts.add('Purpose: ${item.purpose.trim()}.');
    }
    return parts.join(' ');
  }

  bool _isMissingColumn(Object error) {
    if (error is PostgrestException) {
      final code = error.code ?? '';
      if (code == '42703') return true;
    }
    final message = error.toString().toLowerCase();
    return message.contains('column') && message.contains('does not exist');
  }

  bool _isUnavailable(Object error) {
    if (error is PostgrestException) {
      final code = error.code ?? '';
      if (code == '42P01' || code == '42501') return true;
    }
    final message = error.toString().toLowerCase();
    return message.contains('journal_badges') &&
        (message.contains('does not exist') ||
            message.contains('permission denied') ||
            message.contains('not authorized'));
  }

  Future<void> _deleteByEventId(String eventId) async {
    final uid = _userId;
    if (uid == null || eventId.isEmpty) return;
    await _client
        .from('journal_badges')
        .delete()
        .eq('user_id', uid)
        .eq('event_id', eventId);
  }

  Future<void> _insertBadge({
    required String badgeId,
    required String eventId,
    required String title,
    required String details,
    required List<String> tags,
    required DateTime occurredOn,
  }) async {
    final uid = _userId;
    if (uid == null) return;

    final basePayload = <String, dynamic>{
      'user_id': uid,
      'event_id': eventId,
      'title': title,
      'details': details,
      'tags': tags,
      'occurred_on': dateKey(occurredOn),
    };

    final payloads = <Map<String, dynamic>>[
      {...basePayload, 'badge_id': badgeId},
      basePayload,
    ];

    Object? lastError;
    for (final payload in payloads) {
      try {
        await _client.from('journal_badges').insert(payload);
        return;
      } catch (error) {
        lastError = error;
        if (_isMissingColumn(error)) {
          continue;
        }
        rethrow;
      }
    }

    if (lastError != null) {
      throw lastError;
    }
  }

  Future<void> syncTodoState({
    required RhythmTodo todo,
    required DateTime date,
  }) async {
    final uid = _userId;
    if (uid == null || todo.id.isEmpty) return;
    final eventId = todoEventId(todo.id, date);
    try {
      await _deleteByEventId(eventId);
      if (todo.state == RhythmItemState.pending) {
        return;
      }
      await _insertBadge(
        badgeId: eventId,
        eventId: eventId,
        title: _todoTitle(todo, todo.state),
        details: _todoDetails(todo, date, todo.state),
        tags: _buildTags(PlannerBadgeKind.todo, todo.state),
        occurredOn: date,
      );
    } catch (error) {
      if (_isUnavailable(error)) {
        debugPrint('[PlannerBadgeRepo] todo sync skipped: $error');
        return;
      }
      rethrow;
    }
  }

  Future<void> syncNutritionState({
    required NutritionItem item,
    required DateTime date,
    required RhythmItemState state,
  }) async {
    final uid = _userId;
    if (uid == null || item.id.isEmpty) return;
    final eventId = nutritionEventId(item.id, date);
    try {
      await _deleteByEventId(eventId);
      if (state == RhythmItemState.pending) {
        return;
      }
      await _insertBadge(
        badgeId: eventId,
        eventId: eventId,
        title: _nutritionTitle(item, state),
        details: _nutritionDetails(item, date, state),
        tags: _buildTags(PlannerBadgeKind.nutrition, state),
        occurredOn: date,
      );
    } catch (error) {
      if (_isUnavailable(error)) {
        debugPrint('[PlannerBadgeRepo] nutrition sync skipped: $error');
        return;
      }
      rethrow;
    }
  }

  Future<List<PlannerBadgeRecord>> fetchPlannerBadges({
    required DateTime start,
    required DateTime end,
  }) async {
    final uid = _userId;
    if (uid == null) return const <PlannerBadgeRecord>[];

    final startKey = dateKey(start);
    final endKey = dateKey(end);
    final selectClauses = <String>[
      'badge_id,event_id,title,details,tags,occurred_on',
      'event_id,title,details,tags,occurred_on',
    ];

    Object? lastError;
    for (final selectClause in selectClauses) {
      try {
        final rows = await _client
            .from('journal_badges')
            .select(selectClause)
            .eq('user_id', uid)
            .gte('occurred_on', startKey)
            .lte('occurred_on', endKey)
            .like('event_id', 'planner-%')
            .order('occurred_on', ascending: true);

        return (rows as List)
            .map((row) => _recordFromRow(row as Map<String, dynamic>))
            .whereType<PlannerBadgeRecord>()
            .toList();
      } catch (error) {
        lastError = error;
        if (_isMissingColumn(error)) {
          continue;
        }
        if (_isUnavailable(error)) {
          debugPrint('[PlannerBadgeRepo] fetch skipped: $error');
          return const <PlannerBadgeRecord>[];
        }
        rethrow;
      }
    }

    if (lastError != null) {
      debugPrint('[PlannerBadgeRepo] fetch failed: $lastError');
    }
    return const <PlannerBadgeRecord>[];
  }

  Future<Map<String, RhythmItemState>> fetchNutritionStateMap({
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await fetchPlannerBadges(start: start, end: end);
    final states = <String, RhythmItemState>{};
    for (final row in rows) {
      if (row.kind != PlannerBadgeKind.nutrition) continue;
      final key = nutritionStateKeyFromEventId(row.eventId);
      if (key == null) continue;
      states[key] = row.state;
    }
    return states;
  }

  Future<void> refreshKnowledgeGraph() async {
    try {
      await _client.functions.invoke(
        'rebuild_personal_graph',
        body: <String, dynamic>{'date_window_days': 90},
      );
    } catch (error) {
      debugPrint('[PlannerBadgeRepo] graph refresh skipped: $error');
    }
  }

  PlannerBadgeRecord? _recordFromRow(Map<String, dynamic> row) {
    final eventId = (row['event_id'] as String?)?.trim();
    final kind = kindFromEventId(eventId);
    if (eventId == null || eventId.isEmpty || kind == null) {
      return null;
    }

    final rawTags = row['tags'];
    final tags = rawTags is List
        ? rawTags
              .map((value) => value == null ? '' : value.toString())
              .where((value) => value.isNotEmpty)
              .toList()
        : const <String>[];
    final occurredOnRaw = row['occurred_on'] as String?;
    final occurredOn = occurredOnRaw != null && occurredOnRaw.isNotEmpty
        ? DateTime.tryParse(occurredOnRaw) ?? DateTime.now()
        : DateTime.now();
    final badgeId = (row['badge_id'] as String?)?.trim();

    return PlannerBadgeRecord(
      badgeId: (badgeId == null || badgeId.isEmpty) ? eventId : badgeId,
      eventId: eventId,
      kind: kind,
      state: stateFromTags(tags),
      title: (row['title'] as String?)?.trim().isNotEmpty == true
          ? (row['title'] as String).trim()
          : 'Planner badge',
      details: (row['details'] as String?)?.trim() ?? '',
      tags: tags,
      occurredOn: DateUtils.dateOnly(occurredOn),
    );
  }
}
