import 'package:flutter/material.dart';

import '../core/completion_status.dart';
import 'shared_calendar_models.dart';

enum SharedPracticeVisibility { private, sharedWithCalendar }

extension SharedPracticeVisibilityX on SharedPracticeVisibility {
  String get wireName {
    switch (this) {
      case SharedPracticeVisibility.private:
        return 'private';
      case SharedPracticeVisibility.sharedWithCalendar:
        return 'shared_with_calendar';
    }
  }

  String labelForCalendar(String calendarName) {
    switch (this) {
      case SharedPracticeVisibility.private:
        return 'Private';
      case SharedPracticeVisibility.sharedWithCalendar:
        final name = calendarName.trim();
        return name.isEmpty ? 'Shared with calendar' : 'Shared with $name';
    }
  }

  static SharedPracticeVisibility fromWireName(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'shared_with_calendar':
      case 'shared':
        return SharedPracticeVisibility.sharedWithCalendar;
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
    this.flowKey,
    this.startDate,
    this.endDate,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String calendarId;
  final int sourceFlowId;
  final int? sharedFlowId;
  final String createdBy;
  final String title;
  final String? flowKey;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
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
      flowKey: _cleanString(json['flow_key']),
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      status: _cleanString(json['status']) ?? 'active',
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

class SharedPracticeRoomSnapshot {
  const SharedPracticeRoomSnapshot({
    required this.room,
    required this.calendar,
    required this.localDate,
    required this.members,
    required this.entries,
    this.todayStep,
  });

  final SharedPracticeRoom room;
  final SharedPracticeCalendar calendar;
  final DateTime localDate;
  final SharedPracticeStep? todayStep;
  final List<SharedPracticeMemberStatus> members;
  final List<SharedPracticeEntry> entries;

  factory SharedPracticeRoomSnapshot.fromJson(Map<String, dynamic> json) {
    final room = Map<String, dynamic>.from(json['room'] as Map? ?? const {});
    final calendar = Map<String, dynamic>.from(
      json['calendar'] as Map? ?? const {},
    );
    final stepRaw = json['today_step'];
    final membersRaw = json['members'];
    final entriesRaw = json['entries'];
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
