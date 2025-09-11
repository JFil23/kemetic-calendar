import 'package:flutter/foundation.dart';
import '../core/kemetic_converter.dart';
import 'models.dart';

class LocalEventsRepo with ChangeNotifier {
  final _items = <Event>[];
  final _conv = KemeticConverter();

  List<Event> onKemeticDay(int year, int month, int day) =>
      _items.where((e) => e.kYear == year && e.kMonth == month && e.kDay == day).toList();

  /// Adds a quick sample event (handy for testing with long-press in grid).
  void addSampleForDate(DateTime localGregorianMidnight) {
    final kd = _conv.fromGregorian(localGregorianMidnight);
    final id = 'e_${_items.length + 1}';
    final start = localGregorianMidnight.add(const Duration(hours: 10)).toUtc();
    final end = start.add(const Duration(hours: 1));
    _items.add(Event(
      id: id,
      ownerId: 'local',
      title: 'Sample on ${kd.monthName} ${kd.day}',
      notes: null,
      allDay: false,
      startUtc: start,
      endUtc: end,
      timeZone: 'UTC',
      kYear: kd.year,
      kMonth: kd.month,
      kDay: kd.day,
      isEpagomenal: kd.epagomenal,
      kSeason: kd.season,
    ));
    notifyListeners();
  }

  /// Adds a custom event with title + optional notes.
  void addEvent({
    required DateTime startUtc,
    required int kYear,
    required int kMonth,
    required int kDay,
    String? title,
    String? notes,
    bool allDay = true,
  }) {
    final id = 'e_${_items.length + 1}';
    final endUtc = allDay
        ? startUtc.add(const Duration(hours: 23, minutes: 59))
        : startUtc.add(const Duration(hours: 1));

    _items.add(Event(
      id: id,
      ownerId: 'local',
      title: title ?? 'Untitled',
      notes: notes,
      allDay: allDay,
      startUtc: startUtc,
      endUtc: endUtc,
      timeZone: 'UTC',
      kYear: kYear,
      kMonth: kMonth,
      kDay: kDay,
      isEpagomenal: false,
      kSeason: kemeticSeasonsByMonth[kMonth]!,
    ));
    notifyListeners();
  }

  /// Removes an event by ID.
  void removeEvent(String id) {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}
