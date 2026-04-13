/// User-facing copy for rhythm surfaces. Prefer these over raw API errors in UI.
abstract final class RhythmUserMessages {
  static const loadFailedMyCycle =
      'Can’t load your cycle right now. Check your connection, then try again.';
  static const loadFailedTodayAlignment =
      'Can’t load today’s alignment right now. Check your connection, then try again.';
  static const loadFailedTodo =
      'Can’t load your tasks right now. Check your connection, then try again.';
  static const loadFailedTracker =
      'Can’t load continuity right now. Check your connection, then try again.';
  static const loadInterrupted =
      'Something interrupted loading. Please try again.';
  static const saveFailed =
      'Could not save this item. Check your connection and try again.';
}
