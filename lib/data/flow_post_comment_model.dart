// lib/data/flow_post_comment_model.dart

class FlowPostComment {
  final String id;
  final String flowPostId;
  final String userId;
  final String? parentCommentId;
  final String body;
  final DateTime createdAt;
  final String? displayName;
  final String? handle;
  final String? avatarUrl;
  final int likesCount;
  final bool likedByMe;

  FlowPostComment({
    required this.id,
    required this.flowPostId,
    required this.userId,
    this.parentCommentId,
    required this.body,
    required this.createdAt,
    this.displayName,
    this.handle,
    this.avatarUrl,
    this.likesCount = 0,
    this.likedByMe = false,
  });

  factory FlowPostComment.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      try {
        return DateTime.parse(raw as String);
      } catch (_) {
        return null;
      }
    }

    final profile = json['profiles'] as Map<String, dynamic>?;

    return FlowPostComment(
      id: json['id'] as String,
      flowPostId: json['flow_post_id'] as String,
      userId: json['user_id'] as String,
      parentCommentId: json['parent_comment_id'] as String?,
      body: json['body'] as String? ?? '',
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      displayName: profile?['display_name'] as String?,
      handle: profile?['handle'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      likedByMe: json['liked_by_me'] as bool? ?? false,
    );
  }

  bool get isReply => parentCommentId != null;

  FlowPostComment copyWith({
    String? id,
    String? flowPostId,
    String? userId,
    String? parentCommentId,
    bool clearParentCommentId = false,
    String? body,
    DateTime? createdAt,
    String? displayName,
    String? handle,
    String? avatarUrl,
    int? likesCount,
    bool? likedByMe,
  }) {
    return FlowPostComment(
      id: id ?? this.id,
      flowPostId: flowPostId ?? this.flowPostId,
      userId: userId ?? this.userId,
      parentCommentId: clearParentCommentId
          ? null
          : (parentCommentId ?? this.parentCommentId),
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      displayName: displayName ?? this.displayName,
      handle: handle ?? this.handle,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      likesCount: likesCount ?? this.likesCount,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }
}
