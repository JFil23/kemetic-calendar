import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/nutrition_repo.dart';
import 'package:mobile/features/rhythm/models/rhythm_models.dart';
import 'package:mobile/features/rhythm/planner/planner_input_helpers.dart';

NutritionItem _nutritionItem({
  required String id,
  Set<int> decanDays = const <int>{4},
}) {
  return NutritionItem(
    id: id,
    nutrient: 'Magnesium',
    source: 'Pumpkin seeds',
    purpose: 'Rest',
    schedule: IntakeSchedule(
      mode: IntakeMode.decan,
      decanDays: decanDays,
      repeat: true,
      time: const TimeOfDay(hour: 21, minute: 0),
    ),
  );
}

void main() {
  group('planner nutrition input helpers', () {
    test(
      'unchecked Every day maps a new entry only to the active decan day',
      () {
        final item = plannerNutritionWithEveryDayMapping(
          _nutritionItem(id: 'nutrition-1', decanDays: const <int>{1, 2}),
          activeDecanDay: 6,
          everyDay: false,
        );

        expect(item.schedule.mode, IntakeMode.decan);
        expect(item.schedule.decanDays, const <int>{6});
        expect(item.schedule.daysOfWeek, isEmpty);
        expect(plannerNutritionAppliesEveryDay(item), isFalse);
      },
    );

    test('checked Every day maps a new entry to all 10 decan days', () {
      final item = plannerNutritionWithEveryDayMapping(
        _nutritionItem(id: 'nutrition-1'),
        activeDecanDay: 6,
        everyDay: true,
      );

      expect(item.schedule.decanDays, plannerNutritionEveryDecanDay);
      expect(plannerNutritionAppliesEveryDay(item), isTrue);
    });

    test('editing a single-day entry to Every day maps all 10 decan days', () {
      final item = plannerNutritionWithEveryDayMapping(
        _nutritionItem(id: 'nutrition-1', decanDays: const <int>{3}),
        activeDecanDay: 3,
        everyDay: true,
      );

      expect(item.schedule.decanDays, plannerNutritionEveryDecanDay);
    });

    test('unchecking Every day narrows the entry to the viewed decan day', () {
      final item = plannerNutritionWithEveryDayMapping(
        _nutritionItem(
          id: 'nutrition-1',
          decanDays: plannerNutritionEveryDecanDay,
        ),
        activeDecanDay: 8,
        everyDay: false,
      );

      expect(item.schedule.decanDays, const <int>{8});
      expect(plannerNutritionAppliesEveryDay(item), isFalse);
    });

    test(
      'Delete all removes current-day mappings without global destruction',
      () {
        final result = plannerRemoveNutritionDayMappings([
          _nutritionItem(id: 'every', decanDays: plannerNutritionEveryDecanDay),
          _nutritionItem(id: 'single', decanDays: const <int>{4}),
          _nutritionItem(id: 'other', decanDays: const <int>{5}),
        ], decanDay: 4);

        expect(result.deletedItemIds, const <String>{'single'});
        expect(result.updatedItemIds, const <String>{'every'});
        final every = result.items.singleWhere((item) => item.id == 'every');
        expect(every.schedule.decanDays, isNot(contains(4)));
        expect(every.schedule.decanDays, contains(5));
        expect(result.items.map((item) => item.id), contains('other'));
      },
    );

    test('Delete all keeps shrinking multi-day items until no days remain', () {
      var items = <NutritionItem>[
        _nutritionItem(id: 'every', decanDays: plannerNutritionEveryDecanDay),
      ];

      final firstResult = plannerRemoveNutritionDayMappings(items, decanDay: 5);
      expect(firstResult.deletedItemIds, isEmpty);
      expect(firstResult.updatedItemIds, const <String>{'every'});
      items = firstResult.items;
      expect(items.single.schedule.decanDays, isNot(contains(5)));
      expect(items.single.schedule.decanDays, containsAll([1, 4, 6, 10]));

      final secondResult = plannerRemoveNutritionDayMappings(
        items,
        decanDay: 6,
      );
      expect(secondResult.deletedItemIds, isEmpty);
      items = secondResult.items;
      expect(items.single.schedule.decanDays, isNot(contains(6)));
      expect(items.single.schedule.decanDays, containsAll([1, 4, 10]));

      for (final day in const [1, 2, 3, 4, 7, 8, 9]) {
        final result = plannerRemoveNutritionDayMappings(items, decanDay: day);
        expect(result.deletedItemIds, isEmpty);
        items = result.items;
      }

      expect(items.single.schedule.decanDays, const <int>{10});

      final finalResult = plannerRemoveNutritionDayMappings(
        items,
        decanDay: 10,
      );
      expect(finalResult.deletedItemIds, const <String>{'every'});
      expect(finalResult.items, isEmpty);
    });

    test(
      'focused editor owns long text editing instead of inline DataTable',
      () {
        final source = File(
          'lib/features/rhythm/pages/todays_alignment_page.dart',
        ).readAsStringSync();

        expect(source, contains('Future<bool> _showNutritionItemEditor'));
        expect(source, contains('maxLines: null'));
        expect(source, isNot(contains('_buildNutritionEditableCell')));
        expect(
          source,
          isNot(contains('onDoubleTap: () => _showNutritionFullscreen')),
        );
        expect(
          source,
          contains(
            'onTap: () => _showNutritionFullscreen(decanDay, decanName)',
          ),
        );
        expect(source, isNot(contains('onTap: items.isEmpty')));
      },
    );
  });

  group('planner todo move helpers', () {
    test('Move to tomorrow updates due date to viewed date plus one day', () {
      const todo = RhythmTodo(id: 'todo-1', title: 'Review');
      final moved = plannerTodoMovedToDay(todo, DateTime(2026, 7, 4, 18));

      expect(moved.dueDate, DateTime(2026, 7, 4));
      expect(moved.state, RhythmItemState.pending);
    });

    test('moved todo disappears from current day and appears on next day', () {
      final sourceDay = DateTime(2026, 7, 3);
      final result = plannerMoveTodoToNextDayInMap(
        todosByDay: {
          sourceDay: const [
            RhythmTodo(id: 'todo-1', title: 'Review'),
            RhythmTodo(id: 'todo-2', title: 'Keep'),
          ],
        },
        sourceDay: sourceDay,
        sourceIndex: 0,
      );

      expect(result, isNotNull);
      expect(
        result!.todosByDay[sourceDay]!.map((todo) => todo.id).toList(),
        const ['todo-2'],
      );
      expect(
        result.todosByDay[DateTime(2026, 7, 4)]!
            .map((todo) => todo.id)
            .toList(),
        const ['todo-1'],
      );
      expect(result.movedTodo.dueDate, DateTime(2026, 7, 4));
    });

    test('completed todos are not treated as movable unfinished tasks', () {
      final sourceDay = DateTime(2026, 7, 3);
      final result = plannerMoveTodoToNextDayInMap(
        todosByDay: {
          sourceDay: const [
            RhythmTodo(
              id: 'todo-1',
              title: 'Done',
              state: RhythmItemState.done,
            ),
          ],
        },
        sourceDay: sourceDay,
        sourceIndex: 0,
      );

      expect(result, isNull);
    });
  });
}
