import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pages/pages_arrangement.dart';
import 'package:mobile/features/pages/pages_models.dart';

void main() {
  final day = DateTime(2026, 9, 28);
  final todo = PagesPlannerItem(
    'Open commitment',
    isNutrition: false,
    at: day.add(const Duration(hours: 9)),
  );
  final food = PagesPlannerItem(
    'Morning nutrition',
    isNutrition: true,
    isDecanNutrition: true,
    at: day.add(const Duration(hours: 7)),
  );
  test('Planner changes from note to unfinished decan nutrition to scale', () {
    for (final entry in [
      (5, 0, PagesPlannerDisplay.note),
      (11, 29, PagesPlannerDisplay.note),
      (11, 30, PagesPlannerDisplay.nutrition),
      (17, 29, PagesPlannerDisplay.nutrition),
      (17, 30, PagesPlannerDisplay.scale),
      (4, 59, PagesPlannerDisplay.scale),
    ]) {
      final selected = selectPagesPlannerEdition(
        now: DateTime(2026, 9, 28, entry.$1, entry.$2),
        note: 'Say no to burnout',
        records: [todo, food],
      );
      expect(selected.display, entry.$3);
      if (entry.$3 == PagesPlannerDisplay.nutrition) {
        expect(selected.item, same(food));
      }
    }
  });
  test(
    'morning todo fallback and midday priority keep earlier unfinished items',
    () {
      expect(
        selectPagesPlannerEdition(
          now: day.add(const Duration(hours: 8)),
          note: ' ',
          records: [food, todo],
        ).item,
        same(todo),
      );
      expect(
        selectPagesPlanner([todo, food], day.add(const Duration(hours: 12))),
        same(food),
      );
      final overdue = PagesPlannerItem(
        'Overdue',
        isNutrition: false,
        at: day.subtract(const Duration(days: 1)),
      );
      expect(
        selectPagesPlanner([todo, overdue], day.add(const Duration(hours: 12))),
        same(overdue),
      );
    },
  );
  test(
    'completed, weekday, future-day and previous-day nutrition cannot take the pane',
    () {
      final records = [
        PagesPlannerItem(
          'Tomorrow todo',
          isNutrition: false,
          at: day.add(const Duration(days: 1)),
        ),
        PagesPlannerItem(
          'Yesterday nutrition',
          isNutrition: true,
          isDecanNutrition: true,
          at: day.subtract(const Duration(hours: 1)),
        ),
        PagesPlannerItem(
          'Tomorrow nutrition',
          isNutrition: true,
          isDecanNutrition: true,
          at: day.add(const Duration(days: 1)),
        ),
        PagesPlannerItem(
          'Completed',
          isNutrition: true,
          isDecanNutrition: true,
          done: true,
          at: day,
        ),
        PagesPlannerItem('Weekday', isNutrition: true, at: day),
        const PagesPlannerItem('Done todo', isNutrition: false, done: true),
      ];
      expect(
        selectPagesPlanner(records, day.add(const Duration(hours: 12))),
        isNull,
      );
      expect(
        selectPagesPlannerEdition(
          now: day.add(const Duration(hours: 12)),
          note: '',
          records: records,
        ).display,
        PagesPlannerDisplay.scale,
      );
      expect(
        selectPagesPlannerEdition(
          now: day.add(const Duration(hours: 12)),
          note: 'A note',
          records: records,
        ).display,
        PagesPlannerDisplay.note,
      );
    },
  );
}
