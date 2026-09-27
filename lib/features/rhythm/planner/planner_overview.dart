import '../../../data/nutrition_repo.dart';
import '../../../widgets/kemetic_date_picker.dart';
import '../models/rhythm_models.dart';
import '../../pages/pages_arrangement.dart';

/// Same completion weighting as the Planner header. No I/O or persistence.
double plannerCompletion(
  Iterable<RhythmItemState?> tracked,
  Iterable<RhythmItemState?> fallback,
) {
  final states = tracked.toList();
  final values = states.isEmpty ? fallback.toList() : states;
  if (values.isEmpty) return 0;
  return values.fold<double>(
        0,
        (n, s) =>
            n +
            (s == RhythmItemState.done
                ? 1
                : s == RhythmItemState.partial
                ? 0.5
                : 0),
      ) /
      values.length;
}

class PlannerOverview {
  const PlannerOverview({
    required this.todos,
    required this.nutrition,
    required this.nutritionStates,
    required this.alignment,
    required this.note,
  });
  final List<RhythmTodo> todos;
  final List<NutritionItem> nutrition;
  final Map<String, RhythmItemState> nutritionStates;
  final List<RhythmItem> alignment;
  final String note;
  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  RhythmItemState state(NutritionItem n, DateTime day) =>
      nutritionStates['${_dateKey(day)}::${n.id}'] ?? RhythmItemState.pending;
  bool hasTrackedItems(DateTime now) {
    final k = KemeticMath.fromGregorian(now);
    final decan = (k.kDay - 1) % 10 + 1;
    return todos.any(
          (t) => t.dueDate == null || _dateKey(t.dueDate!) == _dateKey(now),
        ) ||
        nutrition.any(
          (n) =>
              n.enabled &&
              n.schedule.mode == IntakeMode.decan &&
              n.schedule.decanDays.contains(decan),
        );
  }

  int percent(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    final k = KemeticMath.fromGregorian(day);
    final decan = (k.kDay - 1) % 10 + 1;
    // Planner's scale currently tracks decan nutrition, exactly as its header.
    final tracked = <RhythmItemState?>[
      for (final t in todos)
        if (t.dueDate == null || _dateKey(t.dueDate!) == _dateKey(day)) t.state,
      for (final n in nutrition)
        if (n.enabled &&
            n.schedule.mode == IntakeMode.decan &&
            n.schedule.decanDays.contains(decan))
          state(n, day),
    ];
    return (plannerCompletion(tracked, alignment.map((a) => a.state)) * 100)
        .round();
  }

  List<PagesPlannerItem> candidates(DateTime now) {
    final result = <PagesPlannerItem>[
      for (final t in todos)
        PagesPlannerItem(
          t.title,
          isNutrition: false,
          done:
              t.state == RhythmItemState.done ||
              t.state == RhythmItemState.skipped,
          at: t.dueDate == null
              ? null
              : DateTime(
                  t.dueDate!.year,
                  t.dueDate!.month,
                  t.dueDate!.day,
                  t.dueTime?.hour ?? 0,
                  t.dueTime?.minute ?? 0,
                ),
        ),
    ];
    for (var i = 0; i < 10; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      final k = KemeticMath.fromGregorian(day);
      final decan = (k.kDay - 1) % 10 + 1;
      for (final n in nutrition) {
        final schedule = n.schedule;
        if (!n.enabled || (i > 0 && !schedule.repeat)) continue;
        if (!(schedule.mode == IntakeMode.weekday
            ? schedule.daysOfWeek.contains(day.weekday)
            : schedule.decanDays.contains(decan))) {
          continue;
        }
        final status = state(n, day);
        result.add(
          PagesPlannerItem(
            n.nutrient.trim().isEmpty ? n.source : n.nutrient,
            isNutrition: true,
            done:
                status == RhythmItemState.done ||
                status == RhythmItemState.skipped,
            at: DateTime(
              day.year,
              day.month,
              day.day,
              schedule.time.hour,
              schedule.time.minute,
            ),
          ),
        );
      }
    }
    return result;
  }
}
