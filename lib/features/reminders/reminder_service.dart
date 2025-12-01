import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'reminder_model.dart';

/// Lightweight client-side reminder cache. This is Flutter-only and meant to be
/// replaced/augmented by Supabase-backed reminders later.
class ReminderService {
  static const _prefsKey = 'local:reminders';
  final Map<String, Reminder> _reminders = {};
  final StreamController<List<Reminder>> _stream = StreamController.broadcast();

  ReminderService();

  Stream<List<Reminder>> get stream => _stream.stream;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    for (final r in Reminder.decodeList(raw)) {
      _reminders[r.id] = r;
    }
    _emit();
  }

  Future<void> addOrUpdate(Reminder reminder) async {
    final existing = _reminders[reminder.id];
    // If already completed, keep it completed and do not re-queue.
    if (existing != null && existing.status == ReminderStatus.completed) {
      return;
    }

    final merged = existing == null
        ? reminder
        : reminder.copyWith(
            status: existing.status,
            createdAt: existing.createdAt,
          );

    _reminders[reminder.id] = merged.copyWith(
      updatedAt: DateTime.now().toUtc(),
    );
    await _persist();
    _emit();
  }

  Future<void> markStatus(String id, ReminderStatus status) async {
    final r = _reminders[id];
    if (r == null) return;
    _reminders[id] = r.copyWith(status: status, updatedAt: DateTime.now().toUtc());
    await _persist();
    _emit();
  }

  List<Reminder> dueReminders(DateTime nowUtc) {
    return _reminders.values.where((r) {
      final due = r.alertAtUtc.isBefore(nowUtc) ||
          r.alertAtUtc.isAtSameMomentAs(nowUtc);
      final pending = r.status == ReminderStatus.pending ||
          r.status == ReminderStatus.sentPush;
      return due && pending;
    }).toList();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, Reminder.encodeList(_reminders.values.toList()));
  }

  void _emit() {
    _stream.add(_reminders.values.toList());
  }

  void dispose() {
    _stream.close();
  }
}
