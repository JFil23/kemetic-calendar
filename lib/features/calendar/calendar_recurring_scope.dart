enum CalendarRecurringMutationScope {
  thisEventOnly,
  thisAndFuture,
  entireSeries,
}

extension CalendarRecurringMutationScopeLabel
    on CalendarRecurringMutationScope {
  String get label {
    switch (this) {
      case CalendarRecurringMutationScope.thisEventOnly:
        return 'This event only';
      case CalendarRecurringMutationScope.thisAndFuture:
        return 'This and future events';
      case CalendarRecurringMutationScope.entireSeries:
        return 'Entire series';
    }
  }
}

class CalendarRecurringDateScopePlan {
  const CalendarRecurringDateScopePlan({
    required this.keptOriginalDates,
    required this.affectedOriginalDates,
    required this.shiftedAffectedDates,
  });

  final Set<DateTime> keptOriginalDates;
  final Set<DateTime> affectedOriginalDates;
  final Set<DateTime> shiftedAffectedDates;
}

DateTime calendarRecurringDateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

CalendarRecurringDateScopePlan planCalendarRecurringDateScope({
  required Iterable<DateTime> originalDates,
  required DateTime selectedDate,
  required CalendarRecurringMutationScope scope,
  DateTime? targetSelectedDate,
}) {
  final selected = calendarRecurringDateOnly(selectedDate);
  final target = calendarRecurringDateOnly(targetSelectedDate ?? selected);
  final delta = target.difference(selected);
  final dates = originalDates.map(calendarRecurringDateOnly).toSet().toList()
    ..sort();

  bool isAffected(DateTime date) {
    switch (scope) {
      case CalendarRecurringMutationScope.thisEventOnly:
        return date == selected;
      case CalendarRecurringMutationScope.thisAndFuture:
        return !date.isBefore(selected);
      case CalendarRecurringMutationScope.entireSeries:
        return true;
    }
  }

  final kept = <DateTime>{};
  final affected = <DateTime>{};
  final shifted = <DateTime>{};

  for (final date in dates) {
    if (isAffected(date)) {
      affected.add(date);
      shifted.add(calendarRecurringDateOnly(date.add(delta)));
    } else {
      kept.add(date);
    }
  }

  return CalendarRecurringDateScopePlan(
    keptOriginalDates: kept,
    affectedOriginalDates: affected,
    shiftedAffectedDates: shifted,
  );
}
