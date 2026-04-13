import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:mobile/features/calendar/notify.dart';

import 'viewmodels/rhythm_draft.dart';

/// Schedules local (+ persisted) reminders for a saved cycle field when
/// "Send reminders" is on. Cancels prior `rhythm:field:*` rows for this field first.
class RhythmReminders {
  RhythmReminders._();

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<void> syncAfterSave({
    required String fieldId,
    required String title,
    required bool sendReminders,
    required bool isTimed,
    required List<TimePattern> patterns,
  }) async {
    if (fieldId.isEmpty) return;

    final prefix = 'rhythm:field:$fieldId:';
    await Notify.cancelByClientEventIdPrefix(prefix);
    if (!sendReminders) return;

    await Notify.init();

    final safeTitle = title.trim().isEmpty ? 'Rhythm' : title.trim();
    final body = 'Time for: $safeTitle';
    final now = DateTime.now();

    String payload() => jsonEncode(<String, dynamic>{
          'kind': 'rhythm_field',
          'field_id': fieldId,
        });

    const maxSlots = 28;

    Future<void> scheduleOne({
      required String clientEventId,
      required DateTime at,
    }) async {
      await Notify.scheduleAlertWithPersistence(
        clientEventId: clientEventId,
        scheduledAt: at,
        title: safeTitle,
        body: body,
        payload: payload(),
        type: NotificationType.flowReminder,
      );
    }

    if (!isTimed || patterns.isEmpty) {
      var slot = 0;
      for (var i = 0; i < 7 && slot < maxSlots; i++) {
        final d = DateTime(now.year, now.month, now.day).add(Duration(days: i));
        final at = DateTime(d.year, d.month, d.day, 9, 0);
        if (!at.isAfter(now.add(const Duration(seconds: 2)))) continue;
        await scheduleOne(
          clientEventId: '${prefix}d:${_dateKey(d)}:daily',
          at: at,
        );
        slot++;
      }
      return;
    }

    var slot = 0;
    for (var pi = 0; pi < patterns.length && slot < maxSlots; pi++) {
      final p = patterns[pi];
      for (var i = 0; i < 14 && slot < maxSlots; i++) {
        final d = DateTime(now.year, now.month, now.day).add(Duration(days: i));
        final wd = d.weekday;
        final days = p.daysOfWeek;
        if (days.isNotEmpty && !days.contains(wd)) continue;

        final TimeOfDay t;
        if (p.allDay) {
          t = const TimeOfDay(hour: 9, minute: 0);
        } else if (p.start != null) {
          t = p.start!;
        } else {
          continue;
        }

        final at = DateTime(d.year, d.month, d.day, t.hour, t.minute);
        if (!at.isAfter(now.add(const Duration(seconds: 2)))) continue;

        await scheduleOne(
          clientEventId: '${prefix}d:${_dateKey(d)}:p:$pi',
          at: at,
        );
        slot++;
      }
    }
  }
}
