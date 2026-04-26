// lib/data/flow_post_model.dart

import 'profile_avatar_glyphs.dart';

class FlowPost {
  final String id;
  final String userId;
  final int? sourceFlowId;
  final String name;
  final int color;
  final String? notes;
  final List<dynamic> rules;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isHidden;
  final Map<String, dynamic>? aiMetadata;
  final Map<String, dynamic>? payloadJson;
  final DateTime createdAt;
  final String? authorHandle;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final List<String> authorAvatarGlyphIds;
  final int likesCount;
  final int commentsCount;
  final bool? likedByMe;
  final bool hasLikesCount;
  final bool hasCommentsCount;
  final bool hasLikedByMe;
  final double? feedScore;
  final bool isFollowingAuthor;

  FlowPost({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
    this.sourceFlowId,
    this.notes,
    required this.rules,
    this.startDate,
    this.endDate,
    this.isHidden = false,
    this.aiMetadata,
    this.payloadJson,
    required this.createdAt,
    this.authorHandle,
    this.authorDisplayName,
    this.authorAvatarUrl,
    this.authorAvatarGlyphIds = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    this.likedByMe,
    this.hasLikesCount = false,
    this.hasCommentsCount = false,
    this.hasLikedByMe = false,
    this.feedScore,
    this.isFollowingAuthor = false,
  });

  factory FlowPost.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) =>
        value == null ? null : DateTime.parse(value as String);

    final rawRules = json['rules'];
    final rules = rawRules is List ? rawRules : <dynamic>[];
    final profileMap = _extractProfileMap(json);
    final hasLikesCount = json.containsKey('likes_count');
    final hasCommentsCount = json.containsKey('comments_count');
    final hasLikedByMe = json.containsKey('liked_by_me');

    return FlowPost(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sourceFlowId: (json['flow_id'] as num?)?.toInt(),
      name: json['name'] as String? ?? 'Untitled Flow',
      color: (json['color'] as num?)?.toInt() ?? 0,
      notes: json['notes'] as String?,
      rules: rules,
      startDate: parseDate(json['start_date']),
      endDate: parseDate(json['end_date']),
      isHidden: (json['is_hidden'] as bool?) ?? false,
      aiMetadata: json['ai_metadata'] != null
          ? Map<String, dynamic>.from(json['ai_metadata'] as Map)
          : null,
      payloadJson: _extractPayload(json),
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      authorHandle:
          _stringOrNull(json['author_handle']) ??
          _stringOrNull(profileMap?['handle']),
      authorDisplayName:
          _stringOrNull(json['author_display_name']) ??
          _stringOrNull(json['author_name']) ??
          _stringOrNull(profileMap?['display_name']),
      authorAvatarUrl:
          _stringOrNull(json['author_avatar_url']) ??
          _stringOrNull(profileMap?['avatar_url']),
      authorAvatarGlyphIds: parseProfileAvatarGlyphIds(
        json['author_avatar_glyphs'] ?? profileMap?['avatar_glyphs'],
      ),
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      likedByMe: hasLikedByMe ? (json['liked_by_me'] as bool?) ?? false : null,
      hasLikesCount: hasLikesCount,
      hasCommentsCount: hasCommentsCount,
      hasLikedByMe: hasLikedByMe,
      feedScore: (json['score'] as num?)?.toDouble(),
      isFollowingAuthor: (json['is_following_author'] as bool?) ?? false,
    );
  }

  String get authorLabel {
    final display = authorDisplayName?.trim();
    if (display != null && display.isNotEmpty) {
      return display;
    }
    final handle = authorHandle?.trim();
    if (handle != null && handle.isNotEmpty) {
      return '@$handle';
    }
    return 'Community';
  }

  bool get hasAuthorIdentity {
    return (authorDisplayName?.trim().isNotEmpty ?? false) ||
        (authorHandle?.trim().isNotEmpty ?? false);
  }

  bool get hasEngagementSnapshot {
    return hasLikesCount || hasCommentsCount || hasLikedByMe;
  }

  static Map<String, dynamic>? _extractPayload(Map<String, dynamic> json) {
    if (json['payload'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(json['payload'] as Map);
    }
    final ai = json['ai_metadata'];
    if (ai is Map && ai['payload'] is Map) {
      return Map<String, dynamic>.from(ai['payload'] as Map);
    }
    return null;
  }

  static Map<String, dynamic>? _extractProfileMap(Map<String, dynamic> json) {
    final raw = json['profiles'];
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  static String? _stringOrNull(dynamic value) {
    final text = value as String?;
    if (text == null) return null;
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
