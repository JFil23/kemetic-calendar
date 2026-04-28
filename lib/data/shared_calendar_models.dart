import 'package:flutter/material.dart';

enum SharedCalendarRole { owner, editor, viewer }

enum SharedCalendarInviteStatus { pending, accepted, declined }

SharedCalendarRole sharedCalendarRoleFromString(String raw) {
  switch (raw) {
    case 'owner':
      return SharedCalendarRole.owner;
    case 'viewer':
      return SharedCalendarRole.viewer;
    case 'editor':
    default:
      return SharedCalendarRole.editor;
  }
}

SharedCalendarInviteStatus sharedCalendarInviteStatusFromString(String raw) {
  switch (raw) {
    case 'accepted':
      return SharedCalendarInviteStatus.accepted;
    case 'declined':
      return SharedCalendarInviteStatus.declined;
    case 'pending':
    default:
      return SharedCalendarInviteStatus.pending;
  }
}

class SharedCalendarSummary {
  const SharedCalendarSummary({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.colorValue,
    required this.icon,
    required this.isPersonal,
    required this.role,
    required this.status,
    required this.memberCount,
    required this.pendingInviteCount,
    this.ownerHandle,
    this.ownerDisplayName,
  });

  final String id;
  final String ownerId;
  final String name;
  final int colorValue;
  final String icon;
  final bool isPersonal;
  final SharedCalendarRole role;
  final SharedCalendarInviteStatus status;
  final int memberCount;
  final int pendingInviteCount;
  final String? ownerHandle;
  final String? ownerDisplayName;

  factory SharedCalendarSummary.fromRow(Map<String, dynamic> row) {
    return SharedCalendarSummary(
      id: (row['id'] as String?) ?? '',
      ownerId: (row['owner_id'] as String?) ?? '',
      name: ((row['name'] as String?) ?? '').trim(),
      colorValue: (row['color'] as num?)?.toInt() ?? 5099745,
      icon: ((row['icon'] as String?) ?? 'calendar').trim(),
      isPersonal: row['is_personal'] == true,
      role: sharedCalendarRoleFromString((row['role'] as String?) ?? 'editor'),
      status: sharedCalendarInviteStatusFromString(
        (row['status'] as String?) ?? 'accepted',
      ),
      memberCount: (row['member_count'] as num?)?.toInt() ?? 1,
      pendingInviteCount: (row['pending_invite_count'] as num?)?.toInt() ?? 0,
      ownerHandle: (row['owner_handle'] as String?)?.trim(),
      ownerDisplayName: (row['owner_display_name'] as String?)?.trim(),
    );
  }

  Color get color => Color(colorValue);

  bool get canEdit =>
      role == SharedCalendarRole.owner || role == SharedCalendarRole.editor;

  bool get canManageMembers => canEdit && !isPersonal;

  String get roleLabel {
    switch (role) {
      case SharedCalendarRole.owner:
        return 'Owner';
      case SharedCalendarRole.editor:
        return 'Can edit';
      case SharedCalendarRole.viewer:
        return 'View only';
    }
  }

  String get ownerLabel {
    final display = ownerDisplayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final handle = ownerHandle?.trim();
    if (handle != null && handle.isNotEmpty) return '@$handle';
    return 'Unknown';
  }
}

class SharedCalendarInvite {
  const SharedCalendarInvite({
    required this.calendarId,
    required this.calendarName,
    required this.calendarColorValue,
    required this.role,
    required this.invitedAt,
    this.invitedBy,
    this.inviterHandle,
    this.inviterDisplayName,
  });

  final String calendarId;
  final String calendarName;
  final int calendarColorValue;
  final SharedCalendarRole role;
  final DateTime invitedAt;
  final String? invitedBy;
  final String? inviterHandle;
  final String? inviterDisplayName;

  factory SharedCalendarInvite.fromRow(Map<String, dynamic> row) {
    return SharedCalendarInvite(
      calendarId: (row['calendar_id'] as String?) ?? '',
      calendarName: ((row['calendar_name'] as String?) ?? '').trim(),
      calendarColorValue: (row['calendar_color'] as num?)?.toInt() ?? 5099745,
      role: sharedCalendarRoleFromString((row['role'] as String?) ?? 'editor'),
      invitedAt:
          DateTime.tryParse((row['invited_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      invitedBy: (row['invited_by'] as String?)?.trim(),
      inviterHandle: (row['inviter_handle'] as String?)?.trim(),
      inviterDisplayName: (row['inviter_display_name'] as String?)?.trim(),
    );
  }

  Color get color => Color(calendarColorValue);

  String get inviterLabel {
    final display = inviterDisplayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final handle = inviterHandle?.trim();
    if (handle != null && handle.isNotEmpty) return '@$handle';
    return 'Someone';
  }
}

class SharedCalendarSentInvite {
  const SharedCalendarSentInvite({
    required this.calendarId,
    required this.calendarName,
    required this.calendarColorValue,
    required this.role,
    required this.invitedAt,
    required this.inviteeId,
    required this.status,
    this.inviteeHandle,
    this.inviteeDisplayName,
    this.inviteeAvatarUrl,
  });

  final String calendarId;
  final String calendarName;
  final int calendarColorValue;
  final SharedCalendarRole role;
  final DateTime invitedAt;
  final String inviteeId;
  final SharedCalendarInviteStatus status;
  final String? inviteeHandle;
  final String? inviteeDisplayName;
  final String? inviteeAvatarUrl;

  factory SharedCalendarSentInvite.fromRow(Map<String, dynamic> row) {
    return SharedCalendarSentInvite(
      calendarId: (row['calendar_id'] as String?) ?? '',
      calendarName: ((row['calendar_name'] as String?) ?? '').trim(),
      calendarColorValue: (row['calendar_color'] as num?)?.toInt() ?? 5099745,
      role: sharedCalendarRoleFromString((row['role'] as String?) ?? 'editor'),
      invitedAt:
          DateTime.tryParse((row['invited_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      inviteeId: (row['invitee_id'] as String?) ?? '',
      status: sharedCalendarInviteStatusFromString(
        (row['status'] as String?) ?? 'pending',
      ),
      inviteeHandle: (row['invitee_handle'] as String?)?.trim(),
      inviteeDisplayName: (row['invitee_display_name'] as String?)?.trim(),
      inviteeAvatarUrl: (row['invitee_avatar_url'] as String?)?.trim(),
    );
  }

  Color get color => Color(calendarColorValue);

  String get inviteeLabel {
    final display = inviteeDisplayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final handle = inviteeHandle?.trim();
    if (handle != null && handle.isNotEmpty) return '@$handle';
    return 'Someone';
  }
}

class SharedCalendarsSnapshot {
  const SharedCalendarsSnapshot({
    required this.calendars,
    required this.pendingInvites,
    required this.hiddenCalendarIds,
  });

  final List<SharedCalendarSummary> calendars;
  final List<SharedCalendarInvite> pendingInvites;
  final Set<String> hiddenCalendarIds;

  String? get personalCalendarId {
    for (final calendar in calendars) {
      if (calendar.isPersonal) return calendar.id;
    }
    return null;
  }
}
