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

enum SharedPracticeRequestAudience {
  nobody,
  creatorFriends,
  participantFriends,
  anyone,
}

extension SharedPracticeRequestAudienceX on SharedPracticeRequestAudience {
  String get wireName {
    switch (this) {
      case SharedPracticeRequestAudience.nobody:
        return 'nobody';
      case SharedPracticeRequestAudience.creatorFriends:
        return 'creator_friends';
      case SharedPracticeRequestAudience.participantFriends:
        return 'participant_friends';
      case SharedPracticeRequestAudience.anyone:
        return 'anyone';
    }
  }

  String get label {
    switch (this) {
      case SharedPracticeRequestAudience.nobody:
        return 'Nobody';
      case SharedPracticeRequestAudience.creatorFriends:
        return 'Friends of creator';
      case SharedPracticeRequestAudience.participantFriends:
        return 'Friends of participants';
      case SharedPracticeRequestAudience.anyone:
        return 'Anyone';
    }
  }

  static SharedPracticeRequestAudience fromWireName(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'nobody':
        return SharedPracticeRequestAudience.nobody;
      case 'participant_friends':
        return SharedPracticeRequestAudience.participantFriends;
      case 'anyone':
        return SharedPracticeRequestAudience.anyone;
      case 'creator_friends':
      default:
        return SharedPracticeRequestAudience.creatorFriends;
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
    this.requestAudience = SharedPracticeRequestAudience.creatorFriends,
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
  final SharedPracticeRequestAudience requestAudience;
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
      requestAudience: SharedPracticeRequestAudienceX.fromWireName(
        _cleanString(json['request_audience']),
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
    this.publicIdentity = false,
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
  final bool publicIdentity;

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
      publicIdentity: json['public_identity'] == true,
    );
  }
}

class SharedPracticeMessage {
  const SharedPracticeMessage({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.flowDay,
    required this.bodyText,
    this.hostClientEventId,
    this.flowId,
    this.createdAt,
    this.updatedAt,
    this.authorHandle,
    this.authorDisplayName,
    this.authorAvatarUrl,
  });

  final String id;
  final String roomId;
  final String userId;
  final DateTime flowDay;
  final String bodyText;
  final String? hostClientEventId;
  final int? flowId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? authorHandle;
  final String? authorDisplayName;
  final String? authorAvatarUrl;

  String get authorLabel {
    final display = authorDisplayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final handle = authorHandle?.trim();
    if (handle != null && handle.isNotEmpty) return '@$handle';
    return 'Member';
  }

  factory SharedPracticeMessage.fromJson(Map<String, dynamic> json) {
    return SharedPracticeMessage(
      id: _cleanString(json['id']) ?? '',
      roomId: _cleanString(json['room_id']) ?? '',
      userId: _cleanString(json['user_id']) ?? '',
      flowDay: _parseDate(json['flow_day']) ?? DateTime.now(),
      bodyText: _cleanString(json['body_text']) ?? '',
      hostClientEventId: _cleanString(json['host_client_event_id']),
      flowId: _parseInt(json['flow_id']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      authorHandle: _cleanString(json['author_handle']),
      authorDisplayName: _cleanString(json['author_display_name']),
      authorAvatarUrl: _cleanString(json['author_avatar_url']),
    );
  }
}

class SharedPracticeQuoteComment {
  const SharedPracticeQuoteComment({
    required this.id,
    required this.quotePostId,
    required this.userId,
    required this.bodyText,
    this.createdAt,
    this.updatedAt,
    this.authorHandle,
    this.authorDisplayName,
    this.authorAvatarUrl,
  });

  final String id;
  final String quotePostId;
  final String userId;
  final String bodyText;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? authorHandle;
  final String? authorDisplayName;
  final String? authorAvatarUrl;

  String get authorLabel {
    final display = authorDisplayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final handle = authorHandle?.trim();
    if (handle != null && handle.isNotEmpty) return '@$handle';
    return 'Practitioner';
  }

  factory SharedPracticeQuoteComment.fromJson(Map<String, dynamic> json) {
    return SharedPracticeQuoteComment(
      id: _cleanString(json['id']) ?? '',
      quotePostId: _cleanString(json['quote_post_id']) ?? '',
      userId: _cleanString(json['user_id']) ?? '',
      bodyText: _cleanString(json['body_text']) ?? '',
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      authorHandle: _cleanString(json['author_handle']),
      authorDisplayName: _cleanString(json['author_display_name']),
      authorAvatarUrl: _cleanString(json['author_avatar_url']),
    );
  }
}

class SharedPracticeQuotePost {
  const SharedPracticeQuotePost({
    required this.id,
    required this.roomId,
    required this.sourceMessageId,
    required this.quotedUserId,
    required this.submittedBy,
    required this.bodyText,
    required this.status,
    this.flowTitle,
    this.sourceFlowId,
    this.authorHandle,
    this.authorDisplayName,
    this.authorAvatarUrl,
    this.authorIsPublic = false,
    this.likesCount = 0,
    this.likedByMe = false,
    this.comments = const <SharedPracticeQuoteComment>[],
    this.approvalRequired = false,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String roomId;
  final String sourceMessageId;
  final String quotedUserId;
  final String submittedBy;
  final String bodyText;
  final String status;
  final String? flowTitle;
  final int? sourceFlowId;
  final String? authorHandle;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final bool authorIsPublic;
  final int likesCount;
  final bool likedByMe;
  final List<SharedPracticeQuoteComment> comments;
  final bool approvalRequired;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get authorLabel {
    if (!authorIsPublic) return 'A participant';
    final display = authorDisplayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final handle = authorHandle?.trim();
    if (handle != null && handle.isNotEmpty) return '@$handle';
    return 'A participant';
  }

  factory SharedPracticeQuotePost.fromJson(Map<String, dynamic> json) {
    return SharedPracticeQuotePost(
      id: _cleanString(json['id']) ?? '',
      roomId: _cleanString(json['room_id']) ?? '',
      sourceMessageId: _cleanString(json['source_message_id']) ?? '',
      quotedUserId: _cleanString(json['quoted_user_id']) ?? '',
      submittedBy: _cleanString(json['submitted_by']) ?? '',
      bodyText: _cleanString(json['body_text']) ?? '',
      status: _cleanString(json['status']) ?? 'pending',
      flowTitle: _cleanString(json['flow_title']),
      sourceFlowId: _parseInt(json['source_flow_id']),
      authorHandle: _cleanString(json['author_handle']),
      authorDisplayName: _cleanString(json['author_display_name']),
      authorAvatarUrl: _cleanString(json['author_avatar_url']),
      authorIsPublic: json['author_is_public'] == true,
      likesCount: _parseInt(json['likes_count']) ?? 0,
      likedByMe: json['liked_by_me'] == true,
      comments: _parseObjectList(
        json['comments'],
        SharedPracticeQuoteComment.fromJson,
      ),
      approvalRequired: json['approval_required'] == true,
      publishedAt: _parseDateTime(json['published_at']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }
}

class TogetherQuoteApproval {
  const TogetherQuoteApproval({
    required this.id,
    required this.roomId,
    required this.sourceMessageId,
    required this.submittedBy,
    required this.bodyText,
    required this.flowTitle,
    this.submitterHandle,
    this.submitterDisplayName,
    this.submitterAvatarUrl,
    this.createdAt,
  });

  final String id;
  final String roomId;
  final String sourceMessageId;
  final String submittedBy;
  final String bodyText;
  final String flowTitle;
  final String? submitterHandle;
  final String? submitterDisplayName;
  final String? submitterAvatarUrl;
  final DateTime? createdAt;

  String get submitterLabel {
    final display = submitterDisplayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final handle = submitterHandle?.trim();
    if (handle != null && handle.isNotEmpty) return '@$handle';
    return 'A participant';
  }

  factory TogetherQuoteApproval.fromJson(Map<String, dynamic> json) {
    return TogetherQuoteApproval(
      id: _cleanString(json['id']) ?? '',
      roomId: _cleanString(json['room_id']) ?? '',
      sourceMessageId: _cleanString(json['source_message_id']) ?? '',
      submittedBy: _cleanString(json['submitted_by']) ?? '',
      bodyText: _cleanString(json['body_text']) ?? '',
      flowTitle: _cleanString(json['flow_title']) ?? 'Group flow',
      submitterHandle: _cleanString(json['submitter_handle']),
      submitterDisplayName: _cleanString(json['submitter_display_name']),
      submitterAvatarUrl: _cleanString(json['submitter_avatar_url']),
      createdAt: _parseDateTime(json['created_at']),
    );
  }
}

class TogetherRequestDecision {
  const TogetherRequestDecision({
    required this.id,
    required this.roomId,
    required this.status,
    required this.title,
    required this.hostId,
    this.sourceFlowId,
    this.hostHandle,
    this.hostDisplayName,
    this.hostAvatarUrl,
    this.respondedAt,
  });

  final String id;
  final String roomId;
  final String status;
  final String title;
  final String hostId;
  final int? sourceFlowId;
  final String? hostHandle;
  final String? hostDisplayName;
  final String? hostAvatarUrl;
  final DateTime? respondedAt;

  bool get approved => status == 'approved';

  String get hostLabel {
    final display = hostDisplayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final handle = hostHandle?.trim();
    if (handle != null && handle.isNotEmpty) return '@$handle';
    return 'The creator';
  }

  factory TogetherRequestDecision.fromJson(Map<String, dynamic> json) {
    return TogetherRequestDecision(
      id: _cleanString(json['id']) ?? '',
      roomId: _cleanString(json['room_id']) ?? '',
      status: _cleanString(json['status']) ?? 'denied',
      title: _cleanString(json['title']) ?? 'Group flow',
      hostId: _cleanString(json['host_id']) ?? '',
      sourceFlowId: _parseInt(json['source_flow_id']),
      hostHandle: _cleanString(json['host_handle']),
      hostDisplayName: _cleanString(json['host_display_name']),
      hostAvatarUrl: _cleanString(json['host_avatar_url']),
      respondedAt: _parseDateTime(json['responded_at']),
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
    this.title,
    this.sourceFlowId,
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
  final String? title;
  final int? sourceFlowId;

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
      title: _cleanString(json['title']),
      sourceFlowId: _parseInt(json['source_flow_id']),
    );
  }
}

class TogetherInboxInvitation {
  const TogetherInboxInvitation({
    required this.roomId,
    required this.userId,
    required this.hostId,
    required this.title,
    this.sourceFlowId,
    this.hostHandle,
    this.hostDisplayName,
    this.hostAvatarUrl,
    this.createdAt,
  });

  final String roomId;
  final String userId;
  final String hostId;
  final String title;
  final int? sourceFlowId;
  final String? hostHandle;
  final String? hostDisplayName;
  final String? hostAvatarUrl;
  final DateTime? createdAt;

  String get hostLabel {
    final display = hostDisplayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final handle = hostHandle?.trim();
    return handle == null || handle.isEmpty ? 'A friend' : '@$handle';
  }

  factory TogetherInboxInvitation.fromJson(Map<String, dynamic> json) {
    return TogetherInboxInvitation(
      roomId: _cleanString(json['room_id']) ?? '',
      userId: _cleanString(json['user_id']) ?? '',
      hostId: _cleanString(json['invited_by']) ?? '',
      title: _cleanString(json['title']) ?? 'Group flow',
      sourceFlowId: _parseInt(json['source_flow_id']),
      hostHandle: _cleanString(json['host_handle']),
      hostDisplayName: _cleanString(json['host_display_name']),
      hostAvatarUrl: _cleanString(json['host_avatar_url']),
      createdAt: _parseDateTime(json['created_at']),
    );
  }
}

class TogetherPolicyPrompt {
  const TogetherPolicyPrompt({
    required this.roomId,
    required this.title,
    required this.memberCount,
    required this.visibility,
    required this.requestAudience,
    this.sourceFlowId,
    this.joinedUserId,
    this.joinedHandle,
    this.joinedDisplayName,
    this.joinedAvatarUrl,
    this.joinedAt,
  });

  final String roomId;
  final String title;
  final int memberCount;
  final SharedPracticeRoomVisibility visibility;
  final SharedPracticeRequestAudience requestAudience;
  final int? sourceFlowId;
  final String? joinedUserId;
  final String? joinedHandle;
  final String? joinedDisplayName;
  final String? joinedAvatarUrl;
  final DateTime? joinedAt;

  String get joinedLabel {
    final display = joinedDisplayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final handle = joinedHandle?.trim();
    return handle == null || handle.isEmpty ? 'A friend' : '@$handle';
  }

  factory TogetherPolicyPrompt.fromJson(Map<String, dynamic> json) {
    return TogetherPolicyPrompt(
      roomId: _cleanString(json['room_id']) ?? '',
      title: _cleanString(json['title']) ?? 'Group flow',
      memberCount: _parseInt(json['member_count']) ?? 2,
      visibility: SharedPracticeRoomVisibilityX.fromWireName(
        _cleanString(json['visibility']),
      ),
      requestAudience: SharedPracticeRequestAudienceX.fromWireName(
        _cleanString(json['request_audience']),
      ),
      sourceFlowId: _parseInt(json['source_flow_id']),
      joinedUserId: _cleanString(json['joined_user_id']),
      joinedHandle: _cleanString(json['joined_handle']),
      joinedDisplayName: _cleanString(json['joined_display_name']),
      joinedAvatarUrl: _cleanString(json['joined_avatar_url']),
      joinedAt: _parseDateTime(json['joined_at']),
    );
  }
}

class TogetherInboxRoom {
  const TogetherInboxRoom({
    required this.roomId,
    required this.title,
    required this.memberCount,
    required this.visibility,
    required this.requestAudience,
    required this.createdBy,
    this.sourceFlowId,
    this.hostHandle,
    this.hostDisplayName,
    this.hostAvatarUrl,
    this.updatedAt,
  });

  final String roomId;
  final String title;
  final int memberCount;
  final SharedPracticeRoomVisibility visibility;
  final SharedPracticeRequestAudience requestAudience;
  final String createdBy;
  final int? sourceFlowId;
  final String? hostHandle;
  final String? hostDisplayName;
  final String? hostAvatarUrl;
  final DateTime? updatedAt;

  String get hostLabel {
    final display = hostDisplayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final handle = hostHandle?.trim();
    return handle == null || handle.isEmpty ? 'Group flow' : '@$handle';
  }

  factory TogetherInboxRoom.fromJson(Map<String, dynamic> json) {
    return TogetherInboxRoom(
      roomId: _cleanString(json['room_id']) ?? '',
      title: _cleanString(json['title']) ?? 'Group flow',
      memberCount: _parseInt(json['member_count']) ?? 2,
      visibility: SharedPracticeRoomVisibilityX.fromWireName(
        _cleanString(json['visibility']),
      ),
      requestAudience: SharedPracticeRequestAudienceX.fromWireName(
        _cleanString(json['request_audience']),
      ),
      createdBy: _cleanString(json['created_by']) ?? '',
      sourceFlowId: _parseInt(json['source_flow_id']),
      hostHandle: _cleanString(json['host_handle']),
      hostDisplayName: _cleanString(json['host_display_name']),
      hostAvatarUrl: _cleanString(json['host_avatar_url']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }
}

class TogetherInboxSnapshot {
  const TogetherInboxSnapshot({
    this.joinRequests = const <SharedPracticeJoinRequest>[],
    this.invitations = const <TogetherInboxInvitation>[],
    this.policyPrompts = const <TogetherPolicyPrompt>[],
    this.quoteApprovals = const <TogetherQuoteApproval>[],
    this.requestDecisions = const <TogetherRequestDecision>[],
    this.activeRooms = const <TogetherInboxRoom>[],
  });

  final List<SharedPracticeJoinRequest> joinRequests;
  final List<TogetherInboxInvitation> invitations;
  final List<TogetherPolicyPrompt> policyPrompts;
  final List<TogetherQuoteApproval> quoteApprovals;
  final List<TogetherRequestDecision> requestDecisions;
  final List<TogetherInboxRoom> activeRooms;

  bool get isEmpty =>
      joinRequests.isEmpty &&
      invitations.isEmpty &&
      policyPrompts.isEmpty &&
      quoteApprovals.isEmpty &&
      requestDecisions.isEmpty &&
      activeRooms.isEmpty;

  factory TogetherInboxSnapshot.fromJson(Map<String, dynamic> json) {
    return TogetherInboxSnapshot(
      joinRequests: _parseObjectList(
        json['join_requests'],
        SharedPracticeJoinRequest.fromJson,
      ),
      invitations: _parseObjectList(
        json['invitations'],
        TogetherInboxInvitation.fromJson,
      ),
      policyPrompts: _parseObjectList(
        json['policy_prompts'],
        TogetherPolicyPrompt.fromJson,
      ),
      quoteApprovals: _parseObjectList(
        json['quote_approvals'],
        TogetherQuoteApproval.fromJson,
      ),
      requestDecisions: _parseObjectList(
        json['request_decisions'],
        TogetherRequestDecision.fromJson,
      ),
      activeRooms: _parseObjectList(
        json['active_rooms'],
        TogetherInboxRoom.fromJson,
      ),
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
    this.messages = const <SharedPracticeMessage>[],
    this.joinRequests = const <SharedPracticeJoinRequest>[],
    this.sourceFlow,
    this.viewerCanEdit = false,
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
  final List<SharedPracticeMessage> messages;
  final List<SharedPracticeJoinRequest> joinRequests;
  final Map<String, dynamic>? sourceFlow;
  final bool viewerCanEdit;
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
    final messagesRaw = json['messages'];
    final joinRequestsRaw = json['join_requests'];
    final sourceFlowRaw = json['source_flow'];
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
      messages: messagesRaw is List
          ? messagesRaw
                .whereType<Map>()
                .map(
                  (row) => SharedPracticeMessage.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .where(
                  (message) =>
                      message.id.isNotEmpty && message.bodyText.isNotEmpty,
                )
                .toList(growable: false)
          : const <SharedPracticeMessage>[],
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
      sourceFlow: sourceFlowRaw is Map
          ? Map<String, dynamic>.unmodifiable(
              Map<String, dynamic>.from(sourceFlowRaw),
            )
          : null,
      viewerCanEdit: json['viewer_can_edit'] == true,
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

List<T> _parseObjectList<T>(
  Object? value,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (value is! List) return <T>[];
  return value
      .whereType<Map>()
      .map((row) => fromJson(Map<String, dynamic>.from(row)))
      .toList(growable: false);
}
