import 'dart:async';

import '../models/rhythm_models.dart';

/// Temporary controller that supplies mock data until the repository layer is wired.
class RhythmController {
  Future<List<RhythmSection>> loadMyCycle() async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    return RhythmMockData.myCycleSections();
  }

  Future<List<RhythmItem>> loadTodaysAlignment() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return RhythmMockData.todaysAlignment();
  }

  Future<List<RhythmTodo>> loadTodos() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return RhythmMockData.todos();
  }

  Future<List<ContinuitySnapshot>> loadContinuity() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return RhythmMockData.continuity();
  }
}
