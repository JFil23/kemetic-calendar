import 'package:flutter/foundation.dart';

@immutable
class CalendarPushOpenIntent {
  const CalendarPushOpenIntent({
    required this.clientEventId,
    required this.nonce,
  });

  final String clientEventId;
  final int nonce;
}

final ValueNotifier<CalendarPushOpenIntent?> calendarPushOpenIntent =
    ValueNotifier<CalendarPushOpenIntent?>(null);

void emitCalendarPushOpenIntent(String clientEventId) {
  final normalized = clientEventId.trim();
  if (normalized.isEmpty) return;

  calendarPushOpenIntent.value = CalendarPushOpenIntent(
    clientEventId: normalized,
    nonce: DateTime.now().microsecondsSinceEpoch,
  );
}
