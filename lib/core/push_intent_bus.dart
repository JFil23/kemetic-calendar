import 'dart:convert';

import 'package:flutter/foundation.dart';

const String calendarPushItemTypeFlowEvent = 'flow_event';
const String calendarPushItemTypeNote = 'note';
const String calendarPushItemTypeReminder = 'reminder';

@immutable
class CalendarPushOpenIntent {
  const CalendarPushOpenIntent({
    this.itemType,
    this.kYear,
    this.kMonth,
    this.kDay,
    this.eventId,
    this.clientEventId,
    this.reminderId,
    this.flowId,
    required this.nonce,
  });

  final String? itemType;
  final int? kYear;
  final int? kMonth;
  final int? kDay;
  final String? eventId;
  final String? clientEventId;
  final String? reminderId;
  final int? flowId;
  final int nonce;

  bool get hasKemeticDate => kYear != null && kMonth != null && kDay != null;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (itemType != null) 'itemType': itemType,
      if (kYear != null) 'kYear': kYear,
      if (kMonth != null) 'kMonth': kMonth,
      if (kDay != null) 'kDay': kDay,
      if (eventId != null) 'eventId': eventId,
      if (clientEventId != null) 'clientEventId': clientEventId,
      if (reminderId != null) 'reminderId': reminderId,
      if (flowId != null) 'flowId': flowId,
    };
  }

  static CalendarPushOpenIntent? fromPayloadString(
    String? payload, {
    int? nonce,
  }) {
    final raw = payload?.trim();
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return fromNotificationData(
          Map<String, dynamic>.from(decoded),
          nonce: nonce,
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static CalendarPushOpenIntent? fromNotificationData(
    Map<String, dynamic> data, {
    int? nonce,
  }) {
    final payload = _payloadMap(data['payload']);
    final merged = <String, dynamic>{...data, if (payload != null) ...payload};

    final clientEventId = _trimmed(
      merged['client_event_id'] ?? merged['clientEventId'],
    );
    final eventId = _trimmed(merged['event_id'] ?? merged['eventId']);
    final reminderId = _trimmed(merged['reminder_id'] ?? merged['reminderId']);
    final flowId = _intValue(merged['flow_id'] ?? merged['flowId']);
    final itemType = _normalizeItemType(
      merged['item_type'] ??
          merged['itemType'] ??
          merged['calendar_item_type'] ??
          merged['calendarItemType'],
    );
    final kYear = _intValue(
      merged['k_year'] ?? merged['kYear'] ?? merged['ky'],
    );
    final kMonth = _intValue(
      merged['k_month'] ?? merged['kMonth'] ?? merged['km'],
    );
    final kDay = _intValue(merged['k_day'] ?? merged['kDay'] ?? merged['kd']);

    if (clientEventId == null && eventId == null && reminderId == null) {
      return null;
    }

    return CalendarPushOpenIntent(
      itemType: itemType,
      kYear: kYear,
      kMonth: kMonth,
      kDay: kDay,
      eventId: eventId,
      clientEventId: clientEventId,
      reminderId: reminderId,
      flowId: flowId,
      nonce: nonce ?? DateTime.now().microsecondsSinceEpoch,
    );
  }
}

final ValueNotifier<CalendarPushOpenIntent?> calendarPushOpenIntent =
    ValueNotifier<CalendarPushOpenIntent?>(null);

void emitCalendarPushOpenIntent(CalendarPushOpenIntent intent) {
  if (intent.clientEventId == null &&
      intent.eventId == null &&
      intent.reminderId == null) {
    return;
  }

  calendarPushOpenIntent.value = intent;
}

void emitCalendarPushOpenClientEventId(String clientEventId) {
  final normalized = clientEventId.trim();
  if (normalized.isEmpty) return;

  emitCalendarPushOpenIntent(
    CalendarPushOpenIntent(
      clientEventId: normalized,
      nonce: DateTime.now().microsecondsSinceEpoch,
    ),
  );
}

Map<String, dynamic>? _payloadMap(Object? raw) {
  if (raw is Map) {
    return raw.map<String, dynamic>(
      (dynamic key, dynamic value) => MapEntry(key.toString(), value),
    );
  }
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map<String, dynamic>(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      return null;
    }
  }
  return null;
}

String? _trimmed(Object? raw) {
  final value = raw?.toString().trim();
  return value == null || value.isEmpty || value == 'null' ? null : value;
}

int? _intValue(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString().trim() ?? '');
}

String? _normalizeItemType(Object? raw) {
  final value = _trimmed(raw)?.toLowerCase().replaceAll('-', '_');
  switch (value) {
    case 'flow_event':
    case 'flowevent':
      return calendarPushItemTypeFlowEvent;
    case 'note':
      return calendarPushItemTypeNote;
    case 'reminder':
      return calendarPushItemTypeReminder;
  }
  return null;
}
