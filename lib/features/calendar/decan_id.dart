/// Compute global decan id (1..36) from month index and decan index.
/// monthIndex: 1..12, decanInMonth: 1..3
int decanIdFromMonthAndIndex({
  required int monthIndex,
  required int decanInMonth,
}) {
  return (monthIndex - 1) * 3 + decanInMonth;
}
