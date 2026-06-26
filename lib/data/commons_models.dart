import 'insight_post_model.dart';
import 'profile_avatar_glyphs.dart';
import 'profile_feed_item_model.dart';
import 'shared_practice_models.dart';

class CommonsRhythmSummary {
  const CommonsRhythmSummary({
    required this.activeUsersTodayLabel,
    required this.flowsKeptTodayLabel,
    required this.publicFragmentsTodayLabel,
    required this.publicRoomsOpenLabel,
    this.topFlowTitle,
    this.topFlowCountLabel,
  });

  final String activeUsersTodayLabel;
  final String flowsKeptTodayLabel;
  final String publicFragmentsTodayLabel;
  final String publicRoomsOpenLabel;
  final String? topFlowTitle;
  final String? topFlowCountLabel;

  factory CommonsRhythmSummary.empty() {
    return const CommonsRhythmSummary(
      activeUsersTodayLabel: '0',
      flowsKeptTodayLabel: '0',
      publicFragmentsTodayLabel: '0',
      publicRoomsOpenLabel: '0',
    );
  }

  factory CommonsRhythmSummary.fromJson(Map<String, dynamic> json) {
    final topFlow = _mapOrNull(json['top_flow']);
    return CommonsRhythmSummary(
      activeUsersTodayLabel: _metricLabel(
        json,
        labelKey: 'active_users_today_label',
        countKey: 'active_users_today',
      ),
      flowsKeptTodayLabel: _metricLabel(
        json,
        labelKey: 'flows_kept_today_label',
        countKey: 'flows_kept_today',
      ),
      publicFragmentsTodayLabel: _metricLabel(
        json,
        labelKey: 'public_fragments_today_label',
        countKey: 'public_fragments_today',
      ),
      publicRoomsOpenLabel: _metricLabel(
        json,
        labelKey: 'public_rooms_open_label',
        countKey: 'public_rooms_open',
      ),
      topFlowTitle: _cleanString(topFlow?['title']),
      topFlowCountLabel: _cleanString(topFlow?['count_label']),
    );
  }

  CommonsRhythmSummary copyWith({
    String? activeUsersTodayLabel,
    String? flowsKeptTodayLabel,
    String? publicFragmentsTodayLabel,
    String? publicRoomsOpenLabel,
    String? topFlowTitle,
    String? topFlowCountLabel,
  }) {
    return CommonsRhythmSummary(
      activeUsersTodayLabel:
          activeUsersTodayLabel ?? this.activeUsersTodayLabel,
      flowsKeptTodayLabel: flowsKeptTodayLabel ?? this.flowsKeptTodayLabel,
      publicFragmentsTodayLabel:
          publicFragmentsTodayLabel ?? this.publicFragmentsTodayLabel,
      publicRoomsOpenLabel: publicRoomsOpenLabel ?? this.publicRoomsOpenLabel,
      topFlowTitle: topFlowTitle ?? this.topFlowTitle,
      topFlowCountLabel: topFlowCountLabel ?? this.topFlowCountLabel,
    );
  }
}

class CommonsAnswer {
  const CommonsAnswer({
    required this.id,
    required this.questionId,
    required this.userId,
    required this.bodyText,
    this.questionText,
    this.authorHandle,
    this.authorDisplayName,
    this.authorAvatarUrl,
    this.authorAvatarGlyphIds = const <String>[],
    this.isMine = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String questionId;
  final String userId;
  final String bodyText;
  final String? questionText;
  final String? authorHandle;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final List<String> authorAvatarGlyphIds;
  final bool isMine;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get authorLabel {
    final display = authorDisplayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final cleanHandle = authorHandle?.trim();
    if (cleanHandle != null && cleanHandle.isNotEmpty) return '@$cleanHandle';
    return 'Practitioner';
  }

  factory CommonsAnswer.fromJson(Map<String, dynamic> json) {
    return CommonsAnswer(
      id: _cleanString(json['id']) ?? '',
      questionId: _cleanString(json['question_id']) ?? '',
      userId: _cleanString(json['user_id']) ?? '',
      bodyText: _cleanString(json['body_text']) ?? '',
      questionText: _cleanString(json['question_text']),
      authorHandle: _cleanString(json['author_handle']),
      authorDisplayName: _cleanString(json['author_display_name']),
      authorAvatarUrl: _cleanString(json['author_avatar_url']),
      authorAvatarGlyphIds: parseProfileAvatarGlyphIds(
        json['author_avatar_glyphs'],
      ),
      isMine: json['is_mine'] == true,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }
}

class CommonsQuestion {
  const CommonsQuestion({
    required this.id,
    required this.question,
    this.answers = const <CommonsAnswer>[],
    this.myAnswer,
  });

  final String id;
  final String question;
  final List<CommonsAnswer> answers;
  final CommonsAnswer? myAnswer;

  factory CommonsQuestion.fromJson(Map<String, dynamic> json) {
    final answersRaw = json['answers'];
    final myAnswerRaw = json['my_answer'];
    final answers = answersRaw is List
        ? answersRaw
              .whereType<Map>()
              .map(
                (row) => CommonsAnswer.fromJson(Map<String, dynamic>.from(row)),
              )
              .where((answer) => answer.id.isNotEmpty)
              .toList(growable: false)
        : const <CommonsAnswer>[];
    final myAnswer = myAnswerRaw is Map
        ? CommonsAnswer.fromJson(Map<String, dynamic>.from(myAnswerRaw))
        : null;
    return CommonsQuestion(
      id: _cleanString(json['id']) ?? '',
      question: _cleanString(json['question']) ?? '',
      answers: answers,
      myAnswer: myAnswer?.id.isEmpty == true ? null : myAnswer,
    );
  }
}

class CommonsPracticeRoom {
  const CommonsPracticeRoom({
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
    required this.visibility,
    required this.joinPolicy,
    this.calendarName,
    this.calendarColor,
    this.ownerHandle,
    this.ownerDisplayName,
    this.ownerAvatarUrl,
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
  final String? calendarName;
  final int? calendarColor;
  final String? ownerHandle;
  final String? ownerDisplayName;
  final String? ownerAvatarUrl;
  final int memberCount;
  final int pendingJoinRequestCount;
  final bool viewerIsMember;
  final bool viewerCanManage;
  final String? viewerRequestStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get ownerLabel {
    final display = ownerDisplayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final cleanHandle = ownerHandle?.trim();
    if (cleanHandle != null && cleanHandle.isNotEmpty) return '@$cleanHandle';
    return 'Community';
  }

  String get visibilityLabel => visibility.label;

  String get requestLabel {
    switch (viewerRequestStatus?.trim().toLowerCase()) {
      case 'pending':
        return 'Requested';
      case 'approved':
        return 'Joined';
      case 'denied':
        return 'Ask again';
      case 'cancelled':
      default:
        return 'Ask to join';
    }
  }

  factory CommonsPracticeRoom.fromJson(Map<String, dynamic> json) {
    return CommonsPracticeRoom(
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
      calendarName: _cleanString(json['calendar_name']),
      calendarColor: _parseInt(json['calendar_color']),
      ownerHandle: _cleanString(json['owner_handle']),
      ownerDisplayName: _cleanString(json['owner_display_name']),
      ownerAvatarUrl: _cleanString(json['owner_avatar_url']),
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

class CommonsHomeSnapshot {
  const CommonsHomeSnapshot({
    required this.rhythm,
    this.questions = const <CommonsQuestion>[],
    this.mySharedPractices = const <CommonsPracticeRoom>[],
    this.publicSharedPractices = const <CommonsPracticeRoom>[],
    this.fragments = const <InsightPost>[],
    this.discover = const <ProfileFeedItem>[],
  });

  final CommonsRhythmSummary rhythm;
  final List<CommonsQuestion> questions;
  final List<CommonsPracticeRoom> mySharedPractices;
  final List<CommonsPracticeRoom> publicSharedPractices;
  final List<InsightPost> fragments;
  final List<ProfileFeedItem> discover;

  factory CommonsHomeSnapshot.empty() {
    return CommonsHomeSnapshot(rhythm: CommonsRhythmSummary.empty());
  }

  factory CommonsHomeSnapshot.fromJson(Map<String, dynamic> json) {
    return CommonsHomeSnapshot(
      rhythm: CommonsRhythmSummary.fromJson(
        _mapOrNull(json['rhythm']) ?? const <String, dynamic>{},
      ),
      questions: _parseList(
        json['questions'],
        (row) => CommonsQuestion.fromJson(row),
      ),
      mySharedPractices: _parseList(
        json['my_shared_practices'],
        (row) => CommonsPracticeRoom.fromJson(row),
      ),
      publicSharedPractices: _parseList(
        json['public_shared_practices'],
        (row) => CommonsPracticeRoom.fromJson(row),
      ),
      fragments: _parseList(
        json['fragments'],
        (row) => InsightPost.fromJson(row),
      ),
      discover: _parseList(
        json['discover'],
        (row) => ProfileFeedItem.fromJson(row),
      ),
    );
  }

  CommonsHomeSnapshot copyWith({
    CommonsRhythmSummary? rhythm,
    List<CommonsQuestion>? questions,
    List<CommonsPracticeRoom>? mySharedPractices,
    List<CommonsPracticeRoom>? publicSharedPractices,
    List<InsightPost>? fragments,
    List<ProfileFeedItem>? discover,
  }) {
    return CommonsHomeSnapshot(
      rhythm: rhythm ?? this.rhythm,
      questions: questions ?? this.questions,
      mySharedPractices: mySharedPractices ?? this.mySharedPractices,
      publicSharedPractices:
          publicSharedPractices ?? this.publicSharedPractices,
      fragments: fragments ?? this.fragments,
      discover: discover ?? this.discover,
    );
  }
}

List<T> _parseList<T>(Object? raw, T Function(Map<String, dynamic> row) parse) {
  if (raw is! List) return <T>[];
  return raw
      .whereType<Map>()
      .map((row) => parse(Map<String, dynamic>.from(row)))
      .toList(growable: false);
}

String _metricLabel(
  Map<String, dynamic> json, {
  required String labelKey,
  required String countKey,
}) {
  final label = _cleanString(json[labelKey]);
  if (label != null) return label;
  final count = _parseInt(json[countKey]);
  return count?.toString() ?? '0';
}

Map<String, dynamic>? _mapOrNull(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
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
