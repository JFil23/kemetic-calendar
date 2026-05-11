import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/rhythm/data/rhythm_repo.dart';
import 'package:mobile/features/rhythm/event_todo_action.dart';
import 'package:mobile/features/rhythm/event_todo_builder.dart';
import 'package:mobile/features/rhythm/models/rhythm_models.dart';

void main() {
  group('makeEventTodos', () {
    test('inserts generated drafts and returns planner todo route', () async {
      late List<RhythmTodoDraft> insertedDrafts;

      final result = await makeEventTodos(
        source: const EventTodoSource(
          title: 'Lymphatic Healing Flow',
          detail:
              'Ensure your space is comfortable and free of distractions. '
              'Use this link: https://www.youtube.com/watch?v=6l_2Lc9f-b0.',
          location: 'https://www.youtube.com/watch?v=6l_2Lc9f-b0',
          isFlow: true,
        ),
        dueDate: DateTime(2026, 5, 11),
        dueTime: const TimeOfDay(hour: 20, minute: 30),
        metadata: const {'source': 'calendar_event_make_todo', 'flow_id': 42},
        launchClock: () => DateTime.fromMicrosecondsSinceEpoch(123456),
        insertTodos: (drafts) async {
          insertedDrafts = drafts;
          return RhythmRepoResult(
            data: [
              RhythmTodo(
                id: 'todo-1',
                title: drafts.single.title,
                notes: drafts.single.notes,
                dueDate: drafts.single.dueDate,
                dueTime: drafts.single.dueTime,
              ),
            ],
          );
        },
      );

      expect(result.success, isTrue);
      expect(insertedDrafts, hasLength(1));
      expect(insertedDrafts.single.title, 'Do Lymphatic Healing Flow');
      expect(insertedDrafts.single.dueDate, DateTime(2026, 5, 11));
      expect(
        insertedDrafts.single.dueTime,
        const TimeOfDay(hour: 20, minute: 30),
      );
      expect(insertedDrafts.single.metadata['flow_id'], 42);
      expect(
        result.plannerLocation,
        '/rhythm/todo?date=2026-05-11&source=make_todo&_launch=123456',
      );
    });

    test('inserts each extracted practice step as its own todo', () async {
      late List<RhythmTodoDraft> insertedDrafts;

      final result = await makeEventTodos(
        source: const EventTodoSource(
          title: 'Starter signs and reading direction',
          detail:
              'Start with these ten Medu Neter unilateral signs: reed leaf = i/y, '
              'quail chick = w/u, owl = m, water ripple = n, mouth = r, '
              'stool = p, foot = b, basket handle = k, bread loaf = t, '
              'and hand = d. Copy each sign three times, say the value aloud, '
              'and note that many signs face the beginning of the text, so you '
              'read toward the faces of people, animals, or birds. You are done '
              'when you can cover the values and identify at least 7 of the 10 '
              'signs from memory.',
          isFlow: true,
        ),
        dueDate: DateTime(2026, 5, 11),
        dueTime: const TimeOfDay(hour: 9, minute: 0),
        insertTodos: (drafts) async {
          insertedDrafts = drafts;
          return RhythmRepoResult(
            data: [
              for (final (index, draft) in drafts.indexed)
                RhythmTodo(
                  id: 'todo-$index',
                  title: draft.title,
                  notes: draft.notes,
                  dueDate: draft.dueDate,
                  dueTime: draft.dueTime,
                ),
            ],
          );
        },
      );

      expect(result.success, isTrue);
      expect(insertedDrafts.map((draft) => draft.title), [
        'Copy each Medu Neter sign 3 times',
        'Say each Medu Neter sign value aloud',
        'Identify at least 7 of 10 Medu Neter signs from memory',
      ]);
      expect(
        insertedDrafts.every(
          (draft) =>
              draft.dueDate == DateTime(2026, 5, 11) &&
              draft.dueTime == const TimeOfDay(hour: 9, minute: 0),
        ),
        isTrue,
      );
    });

    test('surfaces missing table errors without a planner route', () async {
      final result = await makeEventTodos(
        source: const EventTodoSource(title: 'Theater'),
        dueDate: DateTime(2026, 5, 11),
        insertTodos: (_) async =>
            const RhythmRepoResult(data: <RhythmTodo>[], missingTables: true),
      );

      expect(result.success, isFalse);
      expect(result.plannerLocation, isNull);
      expect(
        result.errorMessage,
        'To-do storage is not available in this environment yet.',
      );
    });
  });

  test('plannerTodoLocationForDate encodes the selected date', () {
    final location = plannerTodoLocationForDate(
      DateTime(2026, 5, 11, 18, 45),
      launchClock: () => DateTime.fromMicrosecondsSinceEpoch(99),
    );

    expect(
      location,
      '/rhythm/todo?date=2026-05-11&source=make_todo&_launch=99',
    );
  });
}
