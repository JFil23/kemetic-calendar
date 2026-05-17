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
    this.totalEventCount = 0,
    this.liveEventCount = 0,
    this.inactiveEventCount = 0,
    this.liveFlowCount = 0,
    this.filingLifecycle,
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
  final int totalEventCount;
  final int liveEventCount;
  final int inactiveEventCount;
  final int liveFlowCount;
  final String? filingLifecycle;
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
      totalEventCount: (row['total_event_count'] as num?)?.toInt() ?? 0,
      liveEventCount: (row['live_event_count'] as num?)?.toInt() ?? 0,
      inactiveEventCount: (row['inactive_event_count'] as num?)?.toInt() ?? 0,
      liveFlowCount: (row['live_flow_count'] as num?)?.toInt() ?? 0,
      filingLifecycle: (row['lifecycle'] as String?)?.trim(),
      ownerHandle: (row['owner_handle'] as String?)?.trim(),
      ownerDisplayName: (row['owner_display_name'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toCacheJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'color': colorValue,
      'icon': icon,
      'is_personal': isPersonal,
      'role': role.name,
      'status': status.name,
      'member_count': memberCount,
      'pending_invite_count': pendingInviteCount,
      'total_event_count': totalEventCount,
      'live_event_count': liveEventCount,
      'inactive_event_count': inactiveEventCount,
      'live_flow_count': liveFlowCount,
      'lifecycle': filingLifecycle,
      'owner_handle': ownerHandle,
      'owner_display_name': ownerDisplayName,
    };
  }

  Color get color => Color(colorValue);

  bool get isOwner => role == SharedCalendarRole.owner;

  bool get canEditEvents =>
      role == SharedCalendarRole.owner || role == SharedCalendarRole.editor;

  bool get canEdit => canEditEvents;

  bool get canSeeMemberRoster =>
      status == SharedCalendarInviteStatus.accepted && !isPersonal;

  bool get canSeePendingInvites => isOwner && !isPersonal;

  bool get canManageMembership => isOwner && !isPersonal;

  bool get canManageMembers => canManageMembership;

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

class SharedCalendarMember {
  const SharedCalendarMember({
    required this.userId,
    required this.role,
    required this.status,
    this.invitedBy,
    this.invitedAt,
    this.respondedAt,
    this.updatedAt,
    this.handle,
    this.displayName,
    this.avatarUrl,
  });

  final String userId;
  final SharedCalendarRole role;
  final SharedCalendarInviteStatus status;
  final String? invitedBy;
  final DateTime? invitedAt;
  final DateTime? respondedAt;
  final DateTime? updatedAt;
  final String? handle;
  final String? displayName;
  final String? avatarUrl;

  factory SharedCalendarMember.fromRow(Map<String, dynamic> row) {
    return SharedCalendarMember(
      userId: _cleanString(row['user_id']) ?? '',
      role: sharedCalendarRoleFromString(_cleanString(row['role']) ?? 'viewer'),
      status: sharedCalendarInviteStatusFromString(
        _cleanString(row['status']) ?? 'accepted',
      ),
      invitedBy: _cleanString(row['invited_by']),
      invitedAt: _dateTimeOrNull(row['invited_at']),
      respondedAt: _dateTimeOrNull(row['responded_at']),
      updatedAt: _dateTimeOrNull(row['updated_at']),
      handle: _cleanString(row['handle']),
      displayName: _cleanString(row['display_name']),
      avatarUrl: _cleanString(row['avatar_url']),
    );
  }

  bool get isOwner => role == SharedCalendarRole.owner;

  bool get isPending => status == SharedCalendarInviteStatus.pending;

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

  String get displayLabel {
    final display = displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final cleanHandle = handle?.trim();
    if (cleanHandle != null && cleanHandle.isNotEmpty) return '@$cleanHandle';
    return 'User';
  }

  String? get handleLabel {
    final cleanHandle = handle?.trim();
    if (cleanHandle == null || cleanHandle.isEmpty) return null;
    return '@$cleanHandle';
  }
}

String? _cleanString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? _dateTimeOrNull(Object? value) {
  final text = _cleanString(value);
  if (text == null) return null;
  return DateTime.tryParse(text);
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
    this.inviteDirection,
    this.filingLifecycle,
  });

  final String calendarId;
  final String calendarName;
  final int calendarColorValue;
  final SharedCalendarRole role;
  final DateTime invitedAt;
  final String? invitedBy;
  final String? inviterHandle;
  final String? inviterDisplayName;
  final String? inviteDirection;
  final String? filingLifecycle;

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
      inviteDirection: (row['invite_direction'] as String?)?.trim(),
      filingLifecycle: (row['lifecycle'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toCacheJson() {
    return {
      'calendar_id': calendarId,
      'calendar_name': calendarName,
      'calendar_color': calendarColorValue,
      'role': role.name,
      'invited_at': invitedAt.toUtc().toIso8601String(),
      'invited_by': invitedBy,
      'inviter_handle': inviterHandle,
      'inviter_display_name': inviterDisplayName,
      'invite_direction': inviteDirection,
      'lifecycle': filingLifecycle,
    };
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
    this.inviteDirection,
    this.filingLifecycle,
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
  final String? inviteDirection;
  final String? filingLifecycle;

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
      inviteDirection: (row['invite_direction'] as String?)?.trim(),
      filingLifecycle: (row['lifecycle'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toCacheJson() {
    return {
      'calendar_id': calendarId,
      'calendar_name': calendarName,
      'calendar_color': calendarColorValue,
      'role': role.name,
      'invited_at': invitedAt.toUtc().toIso8601String(),
      'invitee_id': inviteeId,
      'status': status.name,
      'invitee_handle': inviteeHandle,
      'invitee_display_name': inviteeDisplayName,
      'invitee_avatar_url': inviteeAvatarUrl,
      'invite_direction': inviteDirection,
      'lifecycle': filingLifecycle,
    };
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
