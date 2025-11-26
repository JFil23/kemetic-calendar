// lib/data/share_models.dart
// Share Models & Contracts for Flow Sharing System

import 'package:flutter/foundation.dart';

/// Suggested schedule for shared flows
class SuggestedSchedule {
  final String startDate;
  final List<int> weekdays; // 0=Sunday, 1=Monday, etc.
  final bool everyOtherDay;
  final int? perWeek; // null = every occurrence, 1-4 = every Nth occurrence
  final Map<String, String> timesByWeekday; // weekday -> time (e.g., "1" -> "09:00")

  SuggestedSchedule({
    required this.startDate,
    required this.weekdays,
    this.everyOtherDay = false,
    this.perWeek,
    this.timesByWeekday = const {},  // ✅ Made optional with default empty map
  });

  factory SuggestedSchedule.fromJson(Map<String, dynamic> json) {
    return SuggestedSchedule(
      startDate: json['start_date'] as String,  // ✅ Changed from 'startDate' to 'start_date'
      weekdays: List<int>.from(json['weekdays'] as List),
      everyOtherDay: json['every_other_day'] as bool? ?? false,  // ✅ Changed from 'everyOtherDay', made nullable
      perWeek: json['per_week'] as int?,  // ✅ Changed from 'perWeek' to 'per_week'
      timesByWeekday: json['times_by_weekday'] != null  // ✅ Changed from 'timesByWeekday', added null check
          ? Map<String, String>.from(json['times_by_weekday'] as Map)
          : {},  // Return empty map if not provided
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start_date': startDate,  // ✅ Using snake_case for database compatibility
      'weekdays': weekdays,
      'every_other_day': everyOtherDay,  // ✅ Using snake_case
      'per_week': perWeek,  // ✅ Using snake_case
      'times_by_weekday': timesByWeekday,  // ✅ Using snake_case
    };
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

  ShareRecipient({
    required this.type,
    required this.value,
  });

  factory ShareRecipient.fromJson(Map<String, dynamic> json) {
    return ShareRecipient(
      type: ShareRecipientType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ShareRecipientType.user,
      ),
      value: json['value'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'value': value,
    };
  }
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
    return ShareResult(
      recipient: null, // Edge function doesn't return recipient in the share row
      status: json['status'] as String?,
      shareId: json['id'] as String?, // Edge returns 'id' from flow_shares table
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

  bool get isSuccess => error == null && (status == 'sent' || status == 'viewed' || status == 'imported');
  bool get isError => error != null;
}

/// Type-safe enum for inbox share kinds
enum InboxShareKind {
  flow,
  event;

  static InboxShareKind? tryFromString(String raw) {
    switch (raw) {
      case 'flow':
        return InboxShareKind.flow;
      case 'event':
        return InboxShareKind.event;
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
    }
  }
}

/// Unified inbox item for shared flows and events
class InboxShareItem {
  final String shareId;
  final InboxShareKind kind;
  final String recipientId;
  final String senderId;
  final String? senderHandle;  // ✅ NULLABLE
  final String? senderName;    // ✅ NULLABLE
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
  
  // Future-friendly recipient profile (currently null until backend adds)
  final String? recipientHandle;
  final String? recipientDisplayName;
  final String? recipientAvatarUrl;

  InboxShareItem({
    required this.shareId,
    required this.kind,
    required this.recipientId,
    required this.senderId,
    this.senderHandle,      // ✅ NOT REQUIRED
    this.senderName,        // ✅ NOT REQUIRED
    this.senderAvatar,
    required this.payloadId,
    required this.title,
    required this.createdAt,
    this.viewedAt,
    this.importedAt,
    this.deletedAt,         // ✅ new
    this.suggestedSchedule,
    this.eventDate,
    this.payloadJson,       // ✅ NOT REQUIRED
    this.recipientHandle,
    this.recipientDisplayName,
    this.recipientAvatarUrl,
  });

  factory InboxShareItem.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      debugPrint('[InboxItem] Parsing: shareId=${json['share_id']}, kind=${json['kind']}');
    }
    
    final result = InboxShareItem(
      shareId: json['share_id'] as String,
      kind: InboxShareKind.fromString(json['kind'] as String? ?? 'flow'),
      recipientId: json['recipient_id'] as String,
      senderId: json['sender_id'] as String,
      
      // ✅ CRITICAL FIX: Handle NULL values with fallbacks
      senderHandle: json['sender_handle'] as String? ?? 'unknown',
      senderName: json['sender_name'] as String? ?? 'Unknown User',
      
      senderAvatar: json['sender_avatar'] as String?,
      payloadId: json['payload_id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      viewedAt: json['viewed_at'] != null 
          ? DateTime.parse(json['viewed_at'] as String) 
          : null,
      importedAt: json['imported_at'] != null 
          ? DateTime.parse(json['imported_at'] as String) 
          : null,
      deletedAt: json['deleted_at'] != null      // ✅ new
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      suggestedSchedule: json['suggested_schedule'] != null
          ? SuggestedSchedule.fromJson(json['suggested_schedule'] as Map<String, dynamic>)
          : null,
      eventDate: json['event_date'] != null 
          ? DateTime.parse(json['event_date'] as String) 
          : null,
      
      // ✅ CRITICAL FIX: Handle NULL payloadJson
      payloadJson: (json['payload_json'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      
      // Future-friendly recipient profile fields (will be null until backend adds)
      recipientHandle: json['recipient_handle'] as String?,
      recipientDisplayName: json['recipient_display_name'] as String?,
      recipientAvatarUrl: json['recipient_avatar_url'] as String?,
    );
    
    if (kDebugMode) {
      debugPrint('[InboxItem] Created: shareId=${result.shareId}, kind=${result.kind.asString}, isFlow=${result.isFlow}');
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
      'recipient_handle': recipientHandle,
      'recipient_display_name': recipientDisplayName,
      'recipient_avatar_url': recipientAvatarUrl,
    };
  }

  // Computed properties
  bool get isFlow => kind == InboxShareKind.flow;
  bool get isEvent => kind == InboxShareKind.event;
  bool get isDeleted => deletedAt != null;
  bool get isUnread => viewedAt == null && !isDeleted;
  bool get isImported => importedAt != null && !isDeleted;

  String get subtitle {
    final handle = senderHandle ?? 'unknown';
    if (isFlow) {
      return 'Flow shared by @$handle';
    } else {
      return 'Event shared by @$handle';
    }
  }
}



