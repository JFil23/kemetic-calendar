String localDateIso([DateTime? value]) {
  final local = (value ?? DateTime.now()).toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

bool isActiveThroughLocalEndDate(DateTime? endDate, {DateTime? now}) {
  if (endDate == null) return true;
  final localEnd = endDate.toLocal();
  final endDay = DateTime(localEnd.year, localEnd.month, localEnd.day);
  final localNow = (now ?? DateTime.now()).toLocal();
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  return !endDay.isBefore(today);
}

bool isExpiredAfterLocalEndDate(DateTime? endDate, {DateTime? now}) {
  if (endDate == null) return false;
  return !isActiveThroughLocalEndDate(endDate, now: now);
}
