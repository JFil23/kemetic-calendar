// lib/data/share_models.dart
// Share Models & Contracts for Flow Sharing System

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'flow_share_snapshot.dart';

/// Suggested schedule for shared flows
class SuggestedSchedule {
  final String startDate;
  final List<int> weekdays; // accepts either 0..6 (Sun..Sat) or 1..7 (Mon..Sun)
  final bool everyOtherDay;
  final int? perWeek; // null = every occurrence, 1-4 = every Nth occurrence
  final Map<String, String>
  timesByWeekday; // weekday -> time (e.g., "1" -> "09:00")

  SuggestedSchedule({
    required this.startDate,
    required this.weekdays,
    this.everyOtherDay = false,
    this.perWeek,
    this.timesByWeekday = const {},
  });

  factory SuggestedSchedule.fromJson(Map<String, dynamic> json) {
    final rawStartDate = json['start_date'] ?? json['startDate'];
    return SuggestedSchedule(
      startDate: rawStartDate is String ? rawStartDate.trim() : '',
      weekdays: _parseWeekdays(json['weekdays']),
      everyOtherDay: _parseBool(
        json['every_other_day'] ?? json['everyOtherDay'],
      ),
      perWeek: _parseInt(json['per_week'] ?? json['perWeek']),
      timesByWeekday: _parseTimesByWeekday(
        json['times_by_weekday'] ?? json['timesByWeekday'],
      ),
    );
  }

  String? get normalizedStartDate {
    final trimmed = startDate.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  List<String> get weekdayLabels {
    return weekdays.map(_weekdayLabel).toList(growable: false);
  }

  Map<String, dynamic> toJson() {
    return {
      'start_date': startDate,
      'weekdays': weekdays,
      'every_other_day': everyOtherDay,
      'per_week': perWeek,
      'times_by_weekday': timesByWeekday,
    };
  }

  static bool _parseBool(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      switch (raw.trim().toLowerCase()) {
        case '1':
        case 'true':
        case 'yes':
          return true;
        default:
          return false;
      }
    }
    return false;
  }

  static int? _parseInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  static List<int> _parseWeekdays(Object? raw) {
    if (raw is! List) return const [];

    final parsed = <int>[];
    final seen = <int>{};
    for (final item in raw) {
      final day = _parseInt(item);
      if (day == null) continue;
      if (!_isSupportedWeekday(day)) continue;
      if (seen.add(day)) {
        parsed.add(day);
      }
    }
    return parsed;
  }

  static Map<String, String> _parseTimesByWeekday(Object? raw) {
    if (raw is! Map) return const {};

    final times = <String, String>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString().trim();
      final value = entry.value?.toString().trim() ?? '';
      if (key.isEmpty || value.isEmpty) continue;
      times[key] = value;
    }
    return times;
  }

  static bool _isSupportedWeekday(int value) {
    return (value >= 0 && value <= 6) || (value >= 1 && value <= 7);
  }

  static String _weekdayLabel(int value) {
    const zeroBased = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const oneBased = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    if (value >= 0 && value <= 6) {
      return zeroBased[value];
    }
    if (value >= 1 && value <= 7) {
      return oneBased[value - 1];
    }
    return 'Day $value';
  }
}

/// Types of share recipients
enum ShareRecipientType {
  user, // In-app user by handle
  email, // External user by email
  phone, // External user by phone
}

/// A recipient for sharing flows
class ShareRecipient {
  final ShareRecipientType type;
  final String value; // handle, email, or phone number

  ShareRecipient({required this.type, required this.value});

  factory ShareRecipient.fromJson(Map<String, dynamic> json) {
    return ShareRecipient(
      type: ShareRecipientType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ShareRecipientType.user,
      ),
      value: (json['value'] as String).trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'type': type.name, 'value': value.trim()};
  }
}

String shareRecipientKey(ShareRecipient recipient) {
  final trimmed = recipient.value.trim();
  final normalized = recipient.type == ShareRecipientType.user
      ? trimmed
      : trimmed.toLowerCase();
  return '${recipient.type.name}:$normalized';
}

List<ShareRecipient> dedupeShareRecipients(
  Iterable<ShareRecipient> recipients,
) {
  final deduped = <ShareRecipient>[];
  final seen = <String>{};
  for (final recipient in recipients) {
    final normalized = ShareRecipient(
      type: recipient.type,
      value: recipient.value.trim(),
    );
    final key = shareRecipientKey(normalized);
    if (!seen.add(key)) continue;
    deduped.add(normalized);
  }
  return deduped;
}

/// Result of a share operation
class ShareResult {
  final ShareRecipient? recipient; // Optional - Edge function doesn't return it
  final String? status; // 'sent', 'viewed', 'imported', or null if error
  final String? shareId; // UUID of the share record
  final String? shareUrl; // Share URL for external shares (email/phone)
  final String? error; // Error message if status = 'failed'

  ShareResult({
    this.recipient,
    this.status,
    this.shareId,
    this.shareUrl,
    this.error,
  });

  factory ShareResult.fromJson(Map<String, dynamic> json) {
    ShareRecipient? recipient;
    final rawRecipient = json['recipient'];
    if (rawRecipient is Map) {
      recipient = ShareRecipient.fromJson(rawRecipient.cast<String, dynamic>());
    } else {
      final recipientId = (json['recipient_id'] as String?)?.trim();
      if (recipientId != null && recipientId.isNotEmpty) {
        recipient = ShareRecipient(
          type: ShareRecipientType.user,
          value: recipientId,
        );
      }
    }

    return ShareResult(
      recipient: recipient,
      status: json['status'] as String?,
      shareId:
          json['id'] as String?, // Edge returns 'id' from flow_shares table
      shareUrl: json['share_url'] as String?,
      error: null, // Errors are handled at the response level
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (recipient != null) 'recipient': recipient!.toJson(),
      'status': status,
      'share_id': shareId,
      'share_url': shareUrl,
      'error': error,
    };
  }

  bool get isSuccess =>
      error == null &&
      (status == 'sent' || status == 'viewed' || status == 'imported');
  bool get isError => error != null;
}

/// Type-safe enum for inbox share kinds
enum InboxShareKind {
  flow,
  event,
  calendar,
  message;

  static InboxShareKind? tryFromString(String raw) {
    switch (raw) {
      case 'flow':
        return InboxShareKind.flow;
      case 'event':
        return InboxShareKind.event;
      case 'calendar':
        return InboxShareKind.calendar;
      case 'message':
        return InboxShareKind.message;
      default:
        return null;
    }
  }

  static InboxShareKind fromString(String raw) {
    final kind = tryFromString(raw);
    if (kind == null && kDebugMode) {
      debugPrint('[InboxShareKind] Unknown kind: $raw, defaulting to flow');
    }
    return kind ?? InboxShareKind.flow;
  }

  String get asString {
    switch (this) {
      case InboxShareKind.flow:
        return 'flow';
      case InboxShareKind.event:
        return 'event';
      case InboxShareKind.calendar:
        return 'calendar';
      case InboxShareKind.message:
        return 'message';
    }
  }
}

enum EventInviteResponseStatus {
  noResponse,
  accepted,
  declined,
  maybe;

  static EventInviteResponseStatus fromDbValue(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'accepted':
        return EventInviteResponseStatus.accepted;
      case 'declined':
        return EventInviteResponseStatus.declined;
      case 'maybe':
        return EventInviteResponseStatus.maybe;
      case 'no_response':
      default:
        return EventInviteResponseStatus.noResponse;
    }
  }

  String get dbValue {
    switch (this) {
      case EventInviteResponseStatus.noResponse:
        return 'no_response';
      case EventInviteResponseStatus.accepted:
        return 'accepted';
      case EventInviteResponseStatus.declined:
        return 'declined';
      case EventInviteResponseStatus.maybe:
        return 'maybe';
    }
  }

  String get label {
    switch (this) {
      case EventInviteResponseStatus.noResponse:
        return 'Pending';
      case EventInviteResponseStatus.accepted:
        return 'Yes';
      case EventInviteResponseStatus.declined:
        return 'No';
      case EventInviteResponseStatus.maybe:
        return 'Maybe';
    }
  }

  bool get isPending => this == EventInviteResponseStatus.noResponse;
}

class EventSharePayload {
  final String? eventId;
  final String title;
  final String? detail;
  final String? location;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool allDay;

  const EventSharePayload({
    required this.eventId,
    required this.title,
    this.detail,
    this.location,
    this.startsAt,
    this.endsAt,
    required this.allDay,
  });

  factory EventSharePayload.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(Object? raw) {
      if (raw is DateTime) return raw;
      if (raw is! String || raw.trim().isEmpty) return null;
      return DateTime.tryParse(raw.trim());
    }

    bool parseBoolish(Object? raw) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is! String) return false;
      switch (raw.trim().toLowerCase()) {
        case '1':
        case 'true':
        case 't':
        case 'yes':
        case 'y':
          return true;
        case '0':
        case 'false':
        case 'f':
        case 'no':
        case 'n':
          return false;
        default:
          return false;
      }
    }

    return EventSharePayload(
      eventId: (json['event_id'] as String?)?.trim(),
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : ((json['name'] as String?)?.trim().isNotEmpty == true
                ? (json['name'] as String).trim()
                : 'Event Invite'),
      detail: (json['detail'] as String?)?.trim(),
      location: (json['location'] as String?)?.trim(),
      startsAt: parseDateTime(json['starts_at']),
      endsAt: parseDateTime(json['ends_at']),
      allDay: parseBoolish(json['all_day'] ?? json['allDay']),
    );
  }
}

class EventInviteeStatus {
  final String shareId;
  final String recipientId;
  final String? handle;
  final String? displayName;
  final String? avatarUrl;
  final EventInviteResponseStatus responseStatus;
  final DateTime? viewedAt;
  final DateTime? respondedAt;

  const EventInviteeStatus({
    required this.shareId,
    required this.recipientId,
    required this.handle,
    required this.displayName,
    required this.avatarUrl,
    required this.responseStatus,
    required this.viewedAt,
    required this.respondedAt,
  });

  factory EventInviteeStatus.fromJson(Map<String, dynamic> json) {
    final profile = json['recipient'] is Map
        ? Map<String, dynamic>.from(json['recipient'] as Map)
        : const <String, dynamic>{};
    return EventInviteeStatus(
      shareId: json['id'] as String,
      recipientId: json['recipient_id'] as String,
      handle: profile['handle'] as String?,
      displayName: profile['display_name'] as String?,
      avatarUrl: profile['avatar_url'] as String?,
      responseStatus: EventInviteResponseStatus.fromDbValue(
        json['response_status'] as String?,
      ),
      viewedAt: json['viewed_at'] != null
          ? DateTime.tryParse(json['viewed_at'] as String)
          : null,
      respondedAt: json['responded_at'] != null
          ? DateTime.tryParse(json['responded_at'] as String)
          : null,
    );
  }

  String get displayLabel {
    final name = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!.trim()
        : ((handle?.trim().isNotEmpty ?? false)
              ? '@${handle!.trim()}'
              : 'User');
    return '$name • ${responseStatus.label}';
  }
}

/// Unified inbox item for shared flows and events
class InboxShareItem {
  final String shareId;
  final InboxShareKind kind;
  final String recipientId;
  final String senderId;
  final String? senderHandle; // ✅ NULLABLE
  final String? senderName; // ✅ NULLABLE
  final String? senderAvatar;
  final String payloadId; // flow_id or event_id
  final String title;
  final DateTime createdAt;
  final DateTime? viewedAt;
  final DateTime? importedAt;
  final DateTime? deletedAt; // ✅ new - represents soft deletion
  final SuggestedSchedule? suggestedSchedule;
  final DateTime? eventDate; // For event shares
  final Map<String, dynamic>? payloadJson; // ✅ NULLABLE
  final EventInviteResponseStatus responseStatus;
  final DateTime? respondedAt;

  // Future-friendly recipient profile (currently null until backend adds)
  final String? recipientHandle;
  final String? recipientDisplayName;
  final String? recipientAvatarUrl;

  InboxShareItem({
    required this.shareId,
    required this.kind,
    required this.recipientId,
    required this.senderId,
    this.senderHandle, // ✅ NOT REQUIRED
    this.senderName, // ✅ NOT REQUIRED
    this.senderAvatar,
    required this.payloadId,
    required this.title,
    required this.createdAt,
    this.viewedAt,
    this.importedAt,
    this.deletedAt, // ✅ new
    this.suggestedSchedule,
    this.eventDate,
    this.payloadJson, // ✅ NOT REQUIRED
    this.responseStatus = EventInviteResponseStatus.noResponse,
    this.respondedAt,
    this.recipientHandle,
    this.recipientDisplayName,
    this.recipientAvatarUrl,
  });

  static InboxShareItem? tryFromJson(Map<String, dynamic> json) {
    try {
      return InboxShareItem.fromJson(json);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[InboxItem] Skipping malformed row: shareId=${json['share_id']} error=$e',
        );
      }
      return null;
    }
  }

  factory InboxShareItem.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      debugPrint(
        '[InboxItem] Parsing: shareId=${json['share_id']}, kind=${json['kind']}',
      );
    }

    final payload = _parseJsonMap(json['payload_json']);
    final shareId = _requireString(json, 'share_id');
    final kind = InboxShareKind.fromString(
      _nullableString(json['kind']) ?? 'flow',
    );
    final fallbackTitle =
        _nullableString(payload?['title']) ??
        _nullableString(payload?['name']) ??
        _nullableString(payload?['text']) ??
        (kind == InboxShareKind.message
            ? 'Message'
            : (kind == InboxShareKind.calendar
                  ? 'Calendar update'
                  : 'Shared item'));

    final result = InboxShareItem(
      shareId: shareId,
      kind: kind,
      recipientId: _requireString(json, 'recipient_id'),
      senderId: _requireString(json, 'sender_id'),

      // ✅ CRITICAL FIX: Handle NULL values with fallbacks
      senderHandle: _nullableString(json['sender_handle']) ?? 'unknown',
      senderName: _nullableString(json['sender_name']) ?? 'Unknown User',

      senderAvatar: _nullableString(json['sender_avatar']),
      payloadId: _nullableString(json['payload_id']) ?? shareId,
      title: _nullableString(json['title']) ?? fallbackTitle,
      createdAt:
          _parseDateTime(json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      viewedAt: _parseDateTime(json['viewed_at']),
      importedAt: _parseDateTime(json['imported_at']),
      deletedAt: _parseDateTime(json['deleted_at']),
      suggestedSchedule: _parseSuggestedSchedule(json['suggested_schedule']),
      eventDate: _parseDateTime(json['event_date']),

      // ✅ CRITICAL FIX: Keep payloadJson nullable (don't convert null to empty map)
      payloadJson: payload,
      responseStatus: EventInviteResponseStatus.fromDbValue(
        _nullableString(json['response_status']),
      ),
      respondedAt: _parseDateTime(json['responded_at']),

      // Future-friendly recipient profile fields (will be null until backend adds)
      recipientHandle: _nullableString(json['recipient_handle']),
      recipientDisplayName: _nullableString(json['recipient_display_name']),
      recipientAvatarUrl: _nullableString(json['recipient_avatar_url']),
    );

    if (kDebugMode) {
      debugPrint(
        '[InboxItem] Created: shareId=${result.shareId}, kind=${result.kind.asString}, isFlow=${result.isFlow}',
      );
    }

    return result;
  }

  Map<String, dynamic> toJson() {
    return {
      'share_id': shareId,
      'kind': kind.asString, // ✅ use enum's string representation
      'recipient_id': recipientId,
      'sender_id': senderId,
      'sender_handle': senderHandle,
      'sender_name': senderName,
      'sender_avatar': senderAvatar,
      'payload_id': payloadId,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'viewed_at': viewedAt?.toIso8601String(),
      'imported_at': importedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(), // ✅ new
      'suggested_schedule': suggestedSchedule?.toJson(),
      'event_date': eventDate?.toIso8601String(),
      'payload_json': payloadJson,
      'response_status': responseStatus.dbValue,
      'responded_at': respondedAt?.toIso8601String(),
      'recipient_handle': recipientHandle,
      'recipient_display_name': recipientDisplayName,
      'recipient_avatar_url': recipientAvatarUrl,
    };
  }

  // Computed properties
  bool get isFlow => kind == InboxShareKind.flow;
  bool get isEvent => kind == InboxShareKind.event;
  bool get isCalendar => kind == InboxShareKind.calendar;
  bool get isTextMessage =>
      kind == InboxShareKind.message ||
      (payloadJson?['type'] == 'message' || payloadJson?['kind'] == 'message');
  bool get isPendingEventInvite =>
      isEvent && !isDeleted && responseStatus.isPending;
  bool get isDeleted => deletedAt != null;
  bool get isUnread => viewedAt == null && !isDeleted;
  bool get isImported => importedAt != null && !isDeleted;

  /// Extracts a text body for chat-style messages if present.
  String? get messageText {
    if (payloadJson == null) return null;
    return (payloadJson?['text'] as String?) ??
        (payloadJson?['message'] as String?) ??
        (payloadJson?['name'] as String?);
  }

  String get subtitle {
    final handle = senderHandle ?? 'unknown';
    if (isTextMessage) {
      return messageText ?? 'Message';
    }
    if (isFlow) {
      return 'Flow shared by @$handle';
    }
    if (isCalendar) {
      return 'Calendar update from @$handle';
    } else {
      return 'Event shared by @$handle';
    }
  }

  String? get calendarNotificationKind {
    return _nullableString(
      payloadJson?['notification_kind'] ?? payloadJson?['calendar_kind'],
    );
  }

  bool get isCalendarInviteNotification =>
      isCalendar && calendarNotificationKind == 'calendar_invite';

  bool get isCalendarInviteResponseNotification =>
      isCalendar && calendarNotificationKind == 'calendar_invite_response';

  bool get isCalendarEventNotification =>
      isCalendar && calendarNotificationKind == 'calendar_event';

  String? get calendarName {
    return _nullableString(payloadJson?['calendar_name']);
  }

  String? get calendarBody {
    return _nullableString(payloadJson?['body']);
  }

  String? get calendarClientEventId {
    return _nullableString(
      payloadJson?['client_event_id'] ?? payloadJson?['clientEventId'],
    );
  }

  int? get calendarColorValue {
    final raw = payloadJson?['calendar_color'];
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  String? get calendarInviteStatus {
    return _nullableString(
      payloadJson?['invite_status'] ?? payloadJson?['inviteStatus'],
    );
  }

  /// Typed accessor for flow payload (parses payloadJson on-demand)
  FlowSharePayload? get flowPayload {
    if (!isFlow || payloadJson == null) return null;
    try {
      return FlowSharePayload.fromJson(payloadJson!);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[InboxShareItem] ⚠️ Failed to parse flow payload: $e');
        debugPrint(
          '[InboxShareItem] payloadJson keys: ${payloadJson!.keys.toList()}',
        );
      }
      return null;
    }
  }

  EventSharePayload? get eventPayload {
    if (!isEvent || payloadJson == null) return null;
    try {
      return EventSharePayload.fromJson(payloadJson!);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[InboxShareItem] ⚠️ Failed to parse event payload: $e');
      }
      return null;
    }
  }
}

String _requireString(Map<String, dynamic> json, String key) {
  final value = _nullableString(json[key]);
  if (value != null) return value;
  throw FormatException('Missing required inbox field: $key');
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  final text = value is String ? value : value.toString();
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _parseDateTime(Object? value) {
  final text = _nullableString(value);
  if (text == null) return null;
  return DateTime.tryParse(text);
}

Map<String, dynamic>? _parseJsonMap(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  final text = _nullableString(value);
  if (text == null) return null;
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {
    if (kDebugMode) {
      debugPrint('[InboxItem] Failed to decode JSON map payload');
    }
  }
  return null;
}

SuggestedSchedule? _parseSuggestedSchedule(Object? value) {
  final json = _parseJsonMap(value);
  if (json == null) return null;
  return SuggestedSchedule.fromJson(json);
}
