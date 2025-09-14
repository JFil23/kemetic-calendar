import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/kemetic_converter.dart';
import '../data/models.dart';

/// Simple device-only store for events.
/// Keeps everything in memory and mirrors to `SharedPreferences` as a JSON list.
class LocalEventsRepo extends ChangeNotifier {
  static const _prefsKey = 'events.v1';

  final List<Event> _events = [];
  bool _ready = false;

  bool get isReady => _ready;
  List<Event> get all => List.unmodifiable(_events);

  /// Call once at app start.
  Future<void> init() async => _load();

  /* ------------------------ queries ------------------------ */

  /// Return all events on a Kemetic day.
  List<Event> onKemeticDay(int kYear, int kMonth, int kDay, {bool epagomenal = false}) {
    return _events
        .where((e) =>
    e.kYear == kYear &&
        e.kDay == kDay &&
        e.isEpagomenal == epagomenal &&
        (epagomenal ? e.kMonth == 0 : e.kMonth == kMonth))
        .toList()
      ..sort((a, b) => a.category.index.compareTo(b.category.index));
  }

  /* ------------------------ mutations ------------------------ */

  void addEvent({
    required DateTime startUtc,
    required int kYear,
    required int kMonth,
    required int kDay,
    required String? title,
    required String? notes,
    required bool allDay,
    required EventCategory category,
    required bool isEpagomenal,
  }) {
    final e = Event(
      id: _newId(),
      startUtc: startUtc,
      kYear: kYear,
      kMonth: isEpagomenal ? 0 : kMonth,
      kDay: kDay,
      title: (title == null || title.trim().isEmpty) ? '(Untitled)' : title.trim(),
      notes: (notes == null || notes.trim().isEmpty) ? null : notes.trim(),
      allDay: allDay,
      category: category,
      isEpagomenal: isEpagomenal,
    );
    _events.add(e);
    _save();
    notifyListeners();
  }

  void updateEvent(String id, Event updated) {
    final i = _events.indexWhere((e) => e.id == id);
    if (i == -1) return;
    _events[i] = updated;
    _save();
    notifyListeners();
  }

  void removeEvent(String id) {
    _events.removeWhere((e) => e.id == id);
    _save();
    notifyListeners();
  }

  /// Debug helper the UI can call on long-press to seed a quick note for a Gregorian date.
  Future<void> addSampleForDate(DateTime gMidnightLocal) async {
    final kd = KemeticConverter().fromGregorian(gMidnightLocal);
    addEvent(
      startUtc: gMidnightLocal.toUtc(),
      kYear: kd.year,
      kMonth: kd.epagomenal ? 0 : kd.month,
      kDay: kd.day,
      title: 'Sample',
      notes: '…',
      allDay: true,
      category: EventCategory.other,
      isEpagomenal: kd.epagomenal,
    );
  }

  /* ------------------------ persistence ------------------------ */

  Future<void> _load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List).cast<Object?>().toList();
        _events
          ..clear()
          ..addAll(list.map((o) => Event.fromMap((o as Map).cast<String, Object?>())));
      }
    } catch (_) {
      // ignore corrupt store
    } finally {
      _ready = true;
      notifyListeners();
    }
  }

  Future<void> _save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final list = _events.map((e) => e.toMap()).toList(growable: false);
      await sp.setString(_prefsKey, jsonEncode(list));
    } catch (_) {
      // ignore i/o errors in local demo app
    }
  }

  /* ------------------------ utilities ------------------------ */

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
