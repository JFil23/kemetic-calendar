import 'package:flutter/material.dart';
import 'package:mobile/data/nutrition_repo.dart';

import '../models/rhythm_models.dart';

const Set<int> plannerNutritionEveryDecanDay = <int>{
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
};

bool plannerNutritionAppliesEveryDay(NutritionItem item) {
  if (item.schedule.mode != IntakeMode.decan) return false;
  return item.schedule.decanDays.containsAll(plannerNutritionEveryDecanDay);
}

NutritionItem plannerNutritionWithEveryDayMapping(
  NutritionItem item, {
  required int activeDecanDay,
  required bool everyDay,
}) {
  final clampedDay = activeDecanDay.clamp(1, 10).toInt();
  return item.copyWith(
    schedule: item.schedule.copyWith(
      mode: IntakeMode.decan,
      daysOfWeek: const <int>{},
      decanDays: everyDay ? plannerNutritionEveryDecanDay : <int>{clampedDay},
    ),
  );
}

class PlannerNutritionDayRemovalResult {
  const PlannerNutritionDayRemovalResult({
    required this.items,
    required this.deletedItemIds,
    required this.updatedItemIds,
  });

  final List<NutritionItem> items;
  final Set<String> deletedItemIds;
  final Set<String> updatedItemIds;
}

PlannerNutritionDayRemovalResult plannerRemoveNutritionDayMappings(
  Iterable<NutritionItem> items, {
  required int decanDay,
}) {
  final clampedDay = decanDay.clamp(1, 10).toInt();
  final updated = <NutritionItem>[];
  final deletedIds = <String>{};
  final updatedIds = <String>{};

  for (final item in items) {
    if (item.schedule.mode != IntakeMode.decan ||
        !item.schedule.decanDays.contains(clampedDay)) {
      updated.add(item);
      continue;
    }

    final remainingDays = <int>{...item.schedule.decanDays}..remove(clampedDay);
    if (remainingDays.isEmpty) {
      deletedIds.add(item.id);
      continue;
    }

    updatedIds.add(item.id);
    updated.add(
      item.copyWith(
        schedule: item.schedule.copyWith(
          mode: IntakeMode.decan,
          daysOfWeek: const <int>{},
          decanDays: remainingDays,
        ),
      ),
    );
  }

  return PlannerNutritionDayRemovalResult(
    items: updated,
    deletedItemIds: deletedIds,
    updatedItemIds: updatedIds,
  );
}

RhythmTodo plannerTodoMovedToDay(RhythmTodo todo, DateTime day) {
  final target = DateUtils.dateOnly(day);
  return todo.copyWith(dueDate: target, state: RhythmItemState.pending);
}

class PlannerTodoMoveResult {
  const PlannerTodoMoveResult({
    required this.todosByDay,
    required this.movedTodo,
  });

  final Map<DateTime, List<RhythmTodo>> todosByDay;
  final RhythmTodo movedTodo;
}

PlannerTodoMoveResult? plannerMoveTodoToNextDayInMap({
  required Map<DateTime, List<RhythmTodo>> todosByDay,
  required DateTime sourceDay,
  required int sourceIndex,
}) {
  final normalizedSource = DateUtils.dateOnly(sourceDay);
  final sourceTodos = todosByDay[normalizedSource] ?? const <RhythmTodo>[];
  if (sourceIndex < 0 || sourceIndex >= sourceTodos.length) return null;

  final todo = sourceTodos[sourceIndex];
  if (todo.state == RhythmItemState.done) return null;

  final targetDay = DateUtils.dateOnly(
    normalizedSource.add(const Duration(days: 1)),
  );
  final movedTodo = plannerTodoMovedToDay(todo, targetDay);
  final updated = <DateTime, List<RhythmTodo>>{
    for (final entry in todosByDay.entries)
      DateUtils.dateOnly(entry.key): List<RhythmTodo>.from(entry.value),
  };

  final updatedSource = List<RhythmTodo>.from(sourceTodos)
    ..removeAt(sourceIndex);
  updated[normalizedSource] = updatedSource;
  updated[targetDay] = <RhythmTodo>[
    ...(updated[targetDay] ?? const <RhythmTodo>[]),
    movedTodo,
  ];

  return PlannerTodoMoveResult(todosByDay: updated, movedTodo: movedTodo);
}
