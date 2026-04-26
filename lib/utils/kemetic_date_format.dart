import '../features/calendar/kemetic_month_metadata.dart';
import '../widgets/kemetic_date_picker.dart';

String gregorianYearLabelForKemeticMonth(int kYear, int kMonth) {
  final lastDay = (kMonth == 13)
      ? (KemeticMath.isLeapKemeticYear(kYear) ? 6 : 5)
      : 30;
  final yStart = KemeticMath.toGregorian(kYear, kMonth, 1).year;
  final yEnd = KemeticMath.toGregorian(kYear, kMonth, lastDay).year;
  return yStart == yEnd ? '$yStart' : '$yStart/$yEnd';
}

String formatKemeticDate(DateTime date, {bool includeGregorianYear = true}) {
  final kDate = KemeticMath.fromGregorian(date);
  final month = getMonthById(kDate.kMonth).displayFull;
  if (!includeGregorianYear) {
    return '$month ${kDate.kDay}';
  }
  final yearLabel = gregorianYearLabelForKemeticMonth(
    kDate.kYear,
    kDate.kMonth,
  );
  return '$month ${kDate.kDay} • $yearLabel';
}
