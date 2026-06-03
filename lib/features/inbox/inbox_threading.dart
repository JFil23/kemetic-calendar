import 'dart:convert';

import '../../data/share_models.dart';

const String sharedCalendarInboxCalendarQueryParam = 'calendarId';

class SharedCalendarInboxThread {
  const SharedCalendarInboxThread({
    required this.key,
    required this.calendarId,
    required this.notifications,
    required this.unreadCount,
  }) : assert(notifications.length > 0);

  final String key;
  final String? calendarId;
  final List<InboxShareItem> notifications;
  final int unreadCount;

  InboxShareItem get lastNotification => notifications.last;
  DateTime get createdAt => lastNotification.createdAt;
  bool get hasUnread => unreadCount > 0;
  String get title => lastNotification.calendarName ?? lastNotification.title;
  String get preview {
    final body = lastNotification.calendarBody?.trim();
    if (body != null && body.isNotEmpty) return body;
    return lastNotification.title;
  }

  int? get calendarColorValue => lastNotification.calendarColorValue;
}

Map<String, List<InboxShareItem>> directMessageConversationThreadsFromItems(
  List<InboxShareItem> items,
  String currentUserId,
) {
  final grouped = <String, List<InboxShareItem>>{};
  for (final item in items) {
    if (item.isDeleted || item.isEvent || item.isCalendar) continue;
    final otherId = otherUserIdForInboxItem(item, currentUserId);
    if (otherId == null) continue;
    grouped.putIfAbsent(otherId, () => <InboxShareItem>[]).add(item);
  }
  for (final list in grouped.values) {
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }
  return grouped;
}

String? otherUserIdForInboxItem(InboxShareItem item, String currentUserId) {
  if (item.senderId == currentUserId) return item.recipientId;
  if (item.recipientId == currentUserId) return item.senderId;
  return null;
}

List<SharedCalendarInboxThread> sharedCalendarInboxThreadsFromNotifications(
  Iterable<InboxShareItem> notifications, {
  Set<String> optimisticReadShareIds = const <String>{},
}) {
  final grouped = <String, List<InboxShareItem>>{};
  final calendarIdsByKey = <String, String?>{};

  for (final notification in notifications) {
    if (notification.isDeleted || !notification.isCalendarEventNotification) {
      continue;
    }
    final calendarId = notification.calendarId;
    final key = calendarId == null
        ? 'notification:${notification.shareId}'
        : 'calendar:$calendarId';
    grouped.putIfAbsent(key, () => <InboxShareItem>[]).add(notification);
    calendarIdsByKey.putIfAbsent(key, () => calendarId);
  }

  final threads = <SharedCalendarInboxThread>[];
  for (final entry in grouped.entries) {
    final items = entry.value
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final unreadCount = items
        .where(
          (item) =>
              item.isUnread && !optimisticReadShareIds.contains(item.shareId),
        )
        .length;
    threads.add(
      SharedCalendarInboxThread(
        key: entry.key,
        calendarId: calendarIdsByKey[entry.key],
        notifications: List<InboxShareItem>.unmodifiable(items),
        unreadCount: unreadCount,
      ),
    );
  }

  threads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return threads;
}

String sharedCalendarInboxRouteLocation(String calendarId) {
  final normalized = calendarId.trim();
  return Uri(
    path: '/inbox',
    queryParameters: <String, String>{
      sharedCalendarInboxCalendarQueryParam: normalized,
    },
  ).toString();
}

String? sharedCalendarInboxRouteLocationFromPushData(
  Map<String, dynamic> data,
) {
  final calendarId = sharedCalendarIdFromPushData(data);
  if (calendarId == null) return null;
  return sharedCalendarInboxRouteLocation(calendarId);
}

String? sharedCalendarIdFromPushData(Map<String, dynamic> data) {
  final merged = _mergedPayloadData(data);
  final calendarId = _trimmed(merged['calendar_id'] ?? merged['calendarId']);
  if (calendarId == null) return null;
  if (!isSharedCalendarUpdatePushData(merged)) return null;
  return calendarId;
}

bool isSharedCalendarUpdatePushData(Map<String, dynamic> data) {
  final merged = _mergedPayloadData(data);
  final kind = _trimmed(
    merged['push_kind'] ??
        merged['pushKind'] ??
        merged['kind'] ??
        merged['type'],
  );
  final notificationType = _trimmed(
    merged['notification_type'] ?? merged['notificationType'],
  );
  final notificationKind = _trimmed(
    merged['notification_kind'] ??
        merged['notificationKind'] ??
        merged['calendar_kind'] ??
        merged['calendarKind'],
  );
  final calendarId = _trimmed(merged['calendar_id'] ?? merged['calendarId']);

  if (kind == 'shared_calendar_item_added' ||
      notificationType == 'shared_calendar_item_added') {
    return calendarId != null;
  }

  return kind == 'calendar_event' &&
      calendarId != null &&
      (notificationKind == null || notificationKind == 'calendar_event');
}

Map<String, dynamic> _mergedPayloadData(Map<String, dynamic> data) {
  final payload = _payloadMap(data['payload']);
  return <String, dynamic>{...data, if (payload != null) ...payload};
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
