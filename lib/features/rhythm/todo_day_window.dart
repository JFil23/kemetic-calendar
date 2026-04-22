const int defaultTodoPreviousDayCount = 2;
const int defaultTodoFutureDayCount = 2;

DateTime normalizeTodoDayWindowDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

bool isSameTodoDayWindowDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

List<DateTime> buildTodoDayWindow({
  required DateTime anchorDay,
  int previousDays = defaultTodoPreviousDayCount,
  int futureDays = defaultTodoFutureDayCount,
}) {
  final normalizedAnchor = normalizeTodoDayWindowDate(anchorDay);
  return [
    for (int offset = -previousDays; offset <= futureDays; offset++)
      normalizeTodoDayWindowDate(normalizedAnchor.add(Duration(days: offset))),
  ];
}

int resolveTodoDayWindowIndex(
  List<DateTime> days, {
  required DateTime today,
  DateTime? focusDay,
}) {
  if (days.isEmpty) return 0;
  final normalizedToday = normalizeTodoDayWindowDate(today);
  final normalizedFocus = normalizeTodoDayWindowDate(focusDay ?? today);

  final focusIndex = days.indexWhere(
    (day) => isSameTodoDayWindowDate(day, normalizedFocus),
  );
  if (focusIndex >= 0) return focusIndex;

  final todayIndex = days.indexWhere(
    (day) => isSameTodoDayWindowDate(day, normalizedToday),
  );
  return todayIndex >= 0 ? todayIndex : 0;
}
