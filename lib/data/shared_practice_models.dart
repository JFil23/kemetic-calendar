import 'package:flutter/material.dart';

import '../core/completion_status.dart';
import 'shared_calendar_models.dart';

enum SharedPracticeVisibility { private, sharedWithCalendar, public }

extension SharedPracticeVisibilityX on SharedPracticeVisibility {
  String get wireName {
    switch (this) {
      case SharedPracticeVisibility.private:
        return 'private';
      case SharedPracticeVisibility.sharedWithCalendar:
        return 'shared_with_calendar';
      case SharedPracticeVisibility.public:
        return 'public';
    }
  }

  String labelForCalendar(String calendarName) {
    switch (this) {
      case SharedPracticeVisibility.private:
        return 'Private';
      case SharedPracticeVisibility.sharedWithCalendar:
        final name = calendarName.trim();
        return name.isEmpty ? 'Shared with calendar' : 'Shared with $name';
      case SharedPracticeVisibility.public:
        return 'Public';
    }
  }

  static SharedPracticeVisibility fromWireName(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'shared_with_calendar':
      case 'shared':
        return SharedPracticeVisibility.sharedWithCalendar;
      case 'public':
        return SharedPracticeVisibility.public;
      case 'private':
      default:
        return SharedPracticeVisibility.private;
    }
  }
}

enum SharedPracticePresenceStatus { carrying, notYet }

extension SharedPracticePresenceStatusX on SharedPracticePresenceStatus {
  String get wireName {
    switch (this) {
      case SharedPracticePresenceStatus.carrying:
        return 'carrying';
      case SharedPracticePresenceStatus.notYet:
        return 'not_yet';
    }
  }

  static SharedPracticePresenceStatus fromWireName(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'carrying':
        return SharedPracticePresenceStatus.carrying;
      case 'not_yet':
      default:
        return SharedPracticePresenceStatus.notYet;
    }
  }
}

enum SharedPracticeRoomVisibility { private, unlisted, public }

extension SharedPracticeRoomVisibilityX on SharedPracticeRoomVisibility {
  String get wireName {
    switch (this) {
      case SharedPracticeRoomVisibility.private:
        return 'private';
      case SharedPracticeRoomVisibility.unlisted:
        return 'unlisted';
      case SharedPracticeRoomVisibility.public:
        return 'public';
    }
  }

  String get label {
    switch (this) {
      case SharedPracticeRoomVisibility.private:
        return 'Private';
      case SharedPracticeRoomVisibility.unlisted:
        return 'Invite-only';
      case SharedPracticeRoomVisibility.public:
        return 'Public';
    }
  }

  static SharedPracticeRoomVisibility fromWireName(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'public':
        return SharedPracticeRoomVisibility.public;
      case 'unlisted':
      case 'invite_only':
      case 'invite-only':
        return SharedPracticeRoomVisibility.unlisted;
      case 'private':
      default:
        return SharedPracticeRoomVisibility.private;
    }
  }
}

enum SharedPracticeJoinPolicy { ownerApproval, open, closed }

extension SharedPracticeJoinPolicyX on SharedPracticeJoinPolicy {
  String get wireName {
    switch (this) {
      case SharedPracticeJoinPolicy.ownerApproval:
        return 'owner_approval';
      case SharedPracticeJoinPolicy.open:
        return 'open';
      case SharedPracticeJoinPolicy.closed:
        return 'closed';
    }
  }

  String get label {
    switch (this) {
      case SharedPracticeJoinPolicy.ownerApproval:
        return 'Ask to join';
      case SharedPracticeJoinPolicy.open:
        return 'Open join';
      case SharedPracticeJoinPolicy.closed:
        return 'Closed';
    }
  }

  static SharedPracticeJoinPolicy fromWireName(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'open':
        return SharedPracticeJoinPolicy.open;
      case 'closed':
        return SharedPracticeJoinPolicy.closed;
      case 'owner_approval':
      case 'approval':
      default:
        return SharedPracticeJoinPolicy.ownerApproval;
    }
  }
}

class SharedCalendarOption {
  const SharedCalendarOption({
    required this.calendar,
    this.members = const <SharedCalendarMember>[],
  });

  final SharedCalendarSummary calendar;
  final List<SharedCalendarMember> members;

  int get memberCount => calendar.memberCount;
}

class SharedPracticeRoom {
  const SharedPracticeRoom({
    required this.id,
    required this.calendarId,
    required this.sourceFlowId,
    this.sharedFlowId,
    required this.createdBy,
    required this.title,
    this.description,
    this.flowKey,
    this.startDate,
    this.endDate,
    required this.status,
    this.visibility = SharedPracticeRoomVisibility.private,
    this.joinPolicy = SharedPracticeJoinPolicy.ownerApproval,
    this.memberCount = 0,
    this.pendingJoinRequestCount = 0,
    this.viewerIsMember = false,
    this.viewerCanManage = false,
    this.viewerRequestStatus,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String calendarId;
  final int sourceFlowId;
  final int? sharedFlowId;
  final String createdBy;
  final String title;
  final String? description;
  final String? flowKey;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final SharedPracticeRoomVisibility visibility;
  final SharedPracticeJoinPolicy joinPolicy;
  final int memberCount;
  final int pendingJoinRequestCount;
  final bool viewerIsMember;
  final bool viewerCanManage;
  final String? viewerRequestStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory SharedPracticeRoom.fromJson(Map<String, dynamic> json) {
    return SharedPracticeRoom(
      id: _cleanString(json['id']) ?? '',
      calendarId: _cleanString(json['calendar_id']) ?? '',
      sourceFlowId: _parseInt(json['source_flow_id']) ?? 0,
      sharedFlowId: _parseInt(json['shared_flow_id']),
      createdBy: _cleanString(json['created_by']) ?? '',
      title: _cleanString(json['title']) ?? 'Shared Practice',
      description: _cleanString(json['description']),
      flowKey: _cleanString(json['flow_key']),
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      status: _cleanString(json['status']) ?? 'active',
      visibility: SharedPracticeRoomVisibilityX.fromWireName(
        _cleanString(json['visibility']),
      ),
      joinPolicy: SharedPracticeJoinPolicyX.fromWireName(
        _cleanString(json['join_policy']),
      ),
      memberCount: _parseInt(json['member_count']) ?? 0,
      pendingJoinRequestCount:
          _parseInt(json['pending_request_count']) ??
          _parseInt(json['pending_join_request_count']) ??
          0,
      viewerIsMember: json['viewer_is_member'] == true,
      viewerCanManage: json['viewer_can_manage'] == true,
      viewerRequestStatus: _cleanString(json['viewer_request_status']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }
}

class SharedPracticeCalendar {
  const SharedPracticeCalendar({
    required this.id,
    required this.name,
    required this.colorValue,
    this.icon,
    this.ownerId,
    this.isPersonal = false,
  });

  final String id;
  final String name;
  final int colorValue;
  final String? icon;
  final String? ownerId;
  final bool isPersonal;

  Color get color => Color(colorValue);

  factory SharedPracticeCalendar.fromJson(Map<String, dynamic> json) {
    return SharedPracticeCalendar(
      id: _cleanString(json['id']) ?? '',
      name: _cleanString(json['name']) ?? 'Shared Calendar',
      colorValue: _parseInt(json['color']) ?? 0xD4AE43,
      icon: _cleanString(json['icon']),
      ownerId: _cleanString(json['owner_id']),
      isPersonal: json['is_personal'] == true,
    );
  }
}

class SharedPracticeStep {
  const SharedPracticeStep({
    required this.id,
    required this.clientEventId,
    required this.flowId,
    required this.title,
    this.detail,
    this.startsAt,
    this.endsAt,
    this.allDay = false,
    this.stepIndex,
    this.totalSteps,
  });

  final String id;
  final String clientEventId;
  final int flowId;
  final String title;
  final String? detail;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool allDay;
  final int? stepIndex;
  final int? totalSteps;

  factory SharedPracticeStep.fromJson(Map<String, dynamic> json) {
    return SharedPracticeStep(
      id: _cleanString(json['id']) ?? '',
      clientEventId: _cleanString(json['client_event_id']) ?? '',
      flowId: _parseInt(json['flow_id']) ?? 0,
      title: _cleanString(json['title']) ?? 'Today\'s step',
      detail: _cleanString(json['detail']),
      startsAt: _parseDateTime(json['starts_at']),
      endsAt: _parseDateTime(json['ends_at']),
      allDay: json['all_day'] == true,
      stepIndex: _parseInt(json['step_index']),
      totalSteps: _parseInt(json['total_steps']),
    );
  }
}

class SharedPracticeMemberStatus {
  const SharedPracticeMemberStatus({
    required this.userId,
    this.role,
    this.handle,
    this.displayName,
    this.avatarUrl,
    required this.completionStatus,
    required this.presenceStatus,
    this.completedCount = 0,
    this.totalCount = 0,
    this.entryId,
    this.entryVisibility,
    this.entryHasBody = false,
    this.entryAvailableToViewer = false,
  });

  final String userId;
  final String? role;
  final String? handle;
  final String? displayName;
  final String? avatarUrl;
  final CompletionStatus completionStatus;
  final SharedPracticePresenceStatus presenceStatus;
  final int completedCount;
  final int totalCount;
  final String? entryId;
  final SharedPracticeVisibility? entryVisibility;
  final bool entryHasBody;
  final bool entryAvailableToViewer;

  String get displayLabel {
    final display = displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final cleanHandle = handle?.trim();
    if (cleanHandle != null && cleanHandle.isNotEmpty) return '@$cleanHandle';
    return 'Member';
  }

  String get progressLabel {
    if (totalCount <= 0) return '';
    return '$completedCount/$totalCount';
  }

  String get entryActionLabel {
    if (!entryHasBody) return 'No note shared';
    if (entryAvailableToViewer) return 'View entry';
    if (entryVisibility == SharedPracticeVisibility.private) {
      return 'Entry private';
    }
    return 'No note shared';
  }

  factory SharedPracticeMemberStatus.fromJson(Map<String, dynamic> json) {
    final completion = CompletionStatusX.fromWireName(
      _cleanString(json['completion_status']),
    );
    return SharedPracticeMemberStatus(
      userId: _cleanString(json['user_id']) ?? '',
      role: _cleanString(json['role']),
      handle: _cleanString(json['handle']),
      displayName: _cleanString(json['display_name']),
      avatarUrl: _cleanString(json['avatar_url']),
      completionStatus: completion,
      presenceStatus: completion == CompletionStatus.none
          ? SharedPracticePresenceStatusX.fromWireName(
              _cleanString(json['presence_status']),
            )
          : SharedPracticePresenceStatus.notYet,
      completedCount: _parseInt(json['completed_count']) ?? 0,
      totalCount: _parseInt(json['total_count']) ?? 0,
      entryId: _cleanString(json['entry_id']),
      entryVisibility: json['entry_visibility'] == null
          ? null
          : SharedPracticeVisibilityX.fromWireName(
              _cleanString(json['entry_visibility']),
            ),
      entryHasBody: json['entry_has_body'] == true,
      entryAvailableToViewer: json['entry_available_to_viewer'] == true,
    );
  }
}

class SharedPracticeEntry {
  const SharedPracticeEntry({
    required this.id,
    required this.roomId,
    required this.userId,
    this.clientEventId,
    this.flowId,
    required this.completedOn,
    required this.completionStatus,
    this.bodyText,
    required this.visibility,
    required this.moderationStatus,
    this.createdAt,
    this.updatedAt,
    this.authorHandle,
    this.authorDisplayName,
    this.authorAvatarUrl,
  });

  final String id;
  final String roomId;
  final String userId;
  final String? clientEventId;
  final int? flowId;
  final DateTime completedOn;
  final CompletionStatus completionStatus;
  final String? bodyText;
  final SharedPracticeVisibility visibility;
  final String moderationStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? authorHandle;
  final String? authorDisplayName;
  final String? authorAvatarUrl;

  String get authorLabel {
    final display = authorDisplayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final cleanHandle = authorHandle?.trim();
    if (cleanHandle != null && cleanHandle.isNotEmpty) return '@$cleanHandle';
    return 'Member';
  }

  bool get hasBody => bodyText?.trim().isNotEmpty == true;

  factory SharedPracticeEntry.fromJson(Map<String, dynamic> json) {
    return SharedPracticeEntry(
      id: _cleanString(json['id']) ?? '',
      roomId: _cleanString(json['room_id']) ?? '',
      userId: _cleanString(json['user_id']) ?? '',
      clientEventId: _cleanString(json['client_event_id']),
      flowId: _parseInt(json['flow_id']),
      completedOn: _parseDate(json['completed_on']) ?? DateTime.now(),
      completionStatus: CompletionStatusX.fromWireName(
        _cleanString(json['completion_status']),
      ),
      bodyText: _cleanString(json['body_text']),
      visibility: SharedPracticeVisibilityX.fromWireName(
        _cleanString(json['visibility']),
      ),
      moderationStatus: _cleanString(json['moderation_status']) ?? 'visible',
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      authorHandle: _cleanString(json['author_handle']),
      authorDisplayName: _cleanString(json['author_display_name']),
      authorAvatarUrl: _cleanString(json['author_avatar_url']),
    );
  }
}

class SharedPracticeJoinRequest {
  const SharedPracticeJoinRequest({
    required this.id,
    required this.roomId,
    required this.requesterId,
    this.message,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.respondedAt,
    this.requesterHandle,
    this.requesterDisplayName,
    this.requesterAvatarUrl,
  });

  final String id;
  final String roomId;
  final String requesterId;
  final String? message;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? respondedAt;
  final String? requesterHandle;
  final String? requesterDisplayName;
  final String? requesterAvatarUrl;

  String get requesterLabel {
    final display = requesterDisplayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final cleanHandle = requesterHandle?.trim();
    if (cleanHandle != null && cleanHandle.isNotEmpty) return '@$cleanHandle';
    return 'Practitioner';
  }

  factory SharedPracticeJoinRequest.fromJson(Map<String, dynamic> json) {
    return SharedPracticeJoinRequest(
      id: _cleanString(json['id']) ?? '',
      roomId: _cleanString(json['room_id']) ?? '',
      requesterId:
          _cleanString(json['requester_id']) ??
          _cleanString(json['user_id']) ??
          '',
      message: _cleanString(json['message']),
      status: _cleanString(json['status']) ?? 'pending',
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      respondedAt: _parseDateTime(json['responded_at']),
      requesterHandle: _cleanString(json['requester_handle']),
      requesterDisplayName: _cleanString(json['requester_display_name']),
      requesterAvatarUrl: _cleanString(json['requester_avatar_url']),
    );
  }
}

class SharedPracticeRoomSnapshot {
  const SharedPracticeRoomSnapshot({
    required this.room,
    required this.calendar,
    required this.localDate,
    required this.members,
    required this.entries,
    this.joinRequests = const <SharedPracticeJoinRequest>[],
    this.viewerCanManage = false,
    this.viewerIsMember = false,
    this.todayStep,
  });

  final SharedPracticeRoom room;
  final SharedPracticeCalendar calendar;
  final DateTime localDate;
  final SharedPracticeStep? todayStep;
  final List<SharedPracticeMemberStatus> members;
  final List<SharedPracticeEntry> entries;
  final List<SharedPracticeJoinRequest> joinRequests;
  final bool viewerCanManage;
  final bool viewerIsMember;

  factory SharedPracticeRoomSnapshot.fromJson(Map<String, dynamic> json) {
    final room = Map<String, dynamic>.from(json['room'] as Map? ?? const {});
    final calendar = Map<String, dynamic>.from(
      json['calendar'] as Map? ?? const {},
    );
    final stepRaw = json['today_step'];
    final membersRaw = json['members'];
    final entriesRaw = json['entries'];
    final joinRequestsRaw = json['join_requests'];
    return SharedPracticeRoomSnapshot(
      room: SharedPracticeRoom.fromJson(room),
      calendar: SharedPracticeCalendar.fromJson(calendar),
      localDate: _parseDate(json['local_date']) ?? DateTime.now(),
      todayStep: stepRaw is Map
          ? SharedPracticeStep.fromJson(Map<String, dynamic>.from(stepRaw))
          : null,
      members: membersRaw is List
          ? membersRaw
                .whereType<Map>()
                .map(
                  (row) => SharedPracticeMemberStatus.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .where((member) => member.userId.isNotEmpty)
                .toList(growable: false)
          : const <SharedPracticeMemberStatus>[],
      entries: entriesRaw is List
          ? entriesRaw
                .whereType<Map>()
                .map(
                  (row) => SharedPracticeEntry.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .where((entry) => entry.id.isNotEmpty && entry.hasBody)
                .toList(growable: false)
          : const <SharedPracticeEntry>[],
      joinRequests: joinRequestsRaw is List
          ? joinRequestsRaw
                .whereType<Map>()
                .map(
                  (row) => SharedPracticeJoinRequest.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .where((request) => request.id.isNotEmpty)
                .toList(growable: false)
          : const <SharedPracticeJoinRequest>[],
      viewerCanManage: json['viewer_can_manage'] == true,
      viewerIsMember: json['viewer_is_member'] == true,
    );
  }

  SharedPracticeEntry? visibleEntryById(String? id) {
    final clean = id?.trim();
    if (clean == null || clean.isEmpty) return null;
    for (final entry in entries) {
      if (entry.id == clean) return entry;
    }
    return null;
  }

  String get factualSummary {
    final observed = members
        .where((m) => m.completionStatus == CompletionStatus.observed)
        .length;
    final partial = members
        .where((m) => m.completionStatus == CompletionStatus.partial)
        .length;
    final skipped = members
        .where((m) => m.completionStatus == CompletionStatus.skipped)
        .length;
    final carrying = members
        .where(
          (m) =>
              m.completionStatus == CompletionStatus.none &&
              m.presenceStatus == SharedPracticePresenceStatus.carrying,
        )
        .length;
    final notYet = members
        .where(
          (m) =>
              m.completionStatus == CompletionStatus.none &&
              m.presenceStatus == SharedPracticePresenceStatus.notYet,
        )
        .length;

    return buildSharedPracticeSummary(
      observed: observed,
      partial: partial,
      skipped: skipped,
      carrying: carrying,
      notYet: notYet,
    );
  }
}

class JointFlowExperienceResult {
  const JointFlowExperienceResult({
    required this.calendarId,
    required this.flowId,
    required this.sharedPracticeRoomId,
    this.createdCalendar = false,
    this.reusedCalendar = false,
    this.createdFlow = false,
    this.participantUserIds = const <String>[],
  });

  final String calendarId;
  final int flowId;
  final String sharedPracticeRoomId;
  final bool createdCalendar;
  final bool reusedCalendar;
  final bool createdFlow;
  final List<String> participantUserIds;

  factory JointFlowExperienceResult.fromJson(Map<String, dynamic> json) {
    final participantsRaw = json['participant_user_ids'];
    return JointFlowExperienceResult(
      calendarId: _cleanString(json['calendar_id']) ?? '',
      flowId: _parseInt(json['flow_id']) ?? 0,
      sharedPracticeRoomId: _cleanString(json['shared_practice_room_id']) ?? '',
      createdCalendar: json['created_calendar'] == true,
      reusedCalendar: json['reused_calendar'] == true,
      createdFlow: json['created_flow'] == true,
      participantUserIds: participantsRaw is List
          ? participantsRaw
                .map(_cleanString)
                .whereType<String>()
                .toList(growable: false)
          : const <String>[],
    );
  }
}

String buildSharedPracticeSummary({
  required int observed,
  required int partial,
  required int skipped,
  required int carrying,
  required int notYet,
}) {
  if (observed == 0 && partial == 0 && skipped == 0 && carrying == 0) {
    return 'Nobody has recorded today\'s step yet.';
  }

  final parts = <String>[];
  if (observed == 1) {
    parts.add('1 person observed today.');
  } else if (observed > 1) {
    parts.add('$observed observed today.');
  }
  if (partial == 1) {
    parts.add('1 partly completed.');
  } else if (partial > 1) {
    parts.add('$partial partly completed.');
  }
  if (skipped == 1) {
    parts.add('1 skipped today.');
  } else if (skipped > 1) {
    parts.add('$skipped skipped today.');
  }
  if (carrying == 1) {
    parts.add('1 is carrying the step.');
  } else if (carrying > 1) {
    parts.add('$carrying are carrying the step.');
  }
  if (parts.length <= 1 && notYet > 0) {
    parts.add(
      notYet == 1
          ? '1 has not checked in yet.'
          : '$notYet have not checked in yet.',
    );
  }
  return parts.join(' ');
}

String? sharedPracticeRoomIdFromBehaviorPayload(Map<String, dynamic>? payload) {
  final value = payload?['shared_practice_room_id']?.toString().trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

int? _parseInt(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String? _cleanString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

DateTime? _parseDate(Object? value) {
  final text = _cleanString(value);
  if (text == null) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime? _parseDateTime(Object? value) {
  final text = _cleanString(value);
  if (text == null) return null;
  return DateTime.tryParse(text);
}
