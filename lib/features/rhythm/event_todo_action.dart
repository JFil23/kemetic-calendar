import 'package:flutter/material.dart';

import 'event_todo_builder.dart';
import 'models/rhythm_models.dart';
import 'data/rhythm_repo.dart';

typedef EventTodoInserter =
    Future<RhythmRepoResult<List<RhythmTodo>>> Function(
      List<RhythmTodoDraft> drafts,
    );

class EventTodoActionResult {
  const EventTodoActionResult({
    required this.success,
    required this.drafts,
    this.todos = const <RhythmTodo>[],
    this.plannerLocation,
    this.errorMessage,
  });

  final bool success;
  final List<RhythmTodoDraft> drafts;
  final List<RhythmTodo> todos;
  final String? plannerLocation;
  final String? errorMessage;
}

Future<EventTodoActionResult> makeEventTodos({
  required EventTodoSource source,
  required DateTime dueDate,
  required EventTodoInserter insertTodos,
  TimeOfDay? dueTime,
  Map<String, dynamic> metadata = const <String, dynamic>{},
  DateTime Function()? launchClock,
}) async {
  final dateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final drafts = buildEventTodoDrafts(source)
      .map(
        (draft) => draft.copyWith(
          dueDate: dateOnly,
          dueTime: dueTime,
          metadata: {...metadata, ...draft.metadata},
        ),
      )
      .toList(growable: false);
  if (drafts.isEmpty) {
    return const EventTodoActionResult(
      success: false,
      drafts: <RhythmTodoDraft>[],
      errorMessage: 'Could not find a task to add.',
    );
  }

  final result = await insertTodos(drafts);
  if (result.friendlyError != null || result.missingTables) {
    return EventTodoActionResult(
      success: false,
      drafts: drafts,
      errorMessage: result.missingTables
          ? 'To-do storage is not available in this environment yet.'
          : (result.friendlyError ?? 'Could not add to-do.'),
    );
  }
  if (result.data.isEmpty) {
    return EventTodoActionResult(
      success: false,
      drafts: drafts,
      errorMessage: 'Could not add to-do.',
    );
  }

  return EventTodoActionResult(
    success: true,
    drafts: drafts,
    todos: result.data,
    plannerLocation: plannerTodoLocationForDate(
      dateOnly,
      launchClock: launchClock,
    ),
  );
}

String plannerTodoLocationForDate(
  DateTime date, {
  DateTime Function()? launchClock,
}) {
  final localDate = DateTime(date.year, date.month, date.day);
  final dateParam = [
    localDate.year.toString().padLeft(4, '0'),
    localDate.month.toString().padLeft(2, '0'),
    localDate.day.toString().padLeft(2, '0'),
  ].join('-');
  final launchToken = (launchClock ?? DateTime.now)().microsecondsSinceEpoch
      .toString();
  return Uri(
    path: '/rhythm/todo',
    queryParameters: {
      'date': dateParam,
      'source': 'make_todo',
      '_launch': launchToken,
    },
  ).toString();
}
