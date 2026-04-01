// lib/data/flow_post_comment_model.dart

class FlowPostComment {
  final String id;
  final String flowPostId;
  final String userId;
  final String body;
  final DateTime createdAt;
  final String? displayName;
  final String? handle;
  final String? avatarUrl;

  FlowPostComment({
    required this.id,
    required this.flowPostId,
    required this.userId,
    required this.body,
    required this.createdAt,
    this.displayName,
    this.handle,
    this.avatarUrl,
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
      body: json['body'] as String? ?? '',
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      displayName: profile?['display_name'] as String?,
      handle: profile?['handle'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
    );
  }
}
