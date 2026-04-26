import 'flow_post_model.dart';
import 'insight_post_model.dart';

enum ProfileFeedItemKind { flow, insight }

class ProfileFeedItem {
  final ProfileFeedItemKind kind;
  final FlowPost? flowPost;
  final InsightPost? insightPost;

  const ProfileFeedItem._({
    required this.kind,
    this.flowPost,
    this.insightPost,
  });

  const ProfileFeedItem.flow(FlowPost post)
    : this._(kind: ProfileFeedItemKind.flow, flowPost: post);

  const ProfileFeedItem.insight(InsightPost post)
    : this._(kind: ProfileFeedItemKind.insight, insightPost: post);

  factory ProfileFeedItem.fromJson(Map<String, dynamic> json) {
    final rawKind = (json['post_type'] as String? ?? 'flow')
        .trim()
        .toLowerCase();
    if (rawKind == 'insight') {
      return ProfileFeedItem.insight(InsightPost.fromJson(json));
    }
    return ProfileFeedItem.flow(FlowPost.fromJson(json));
  }

  String get id =>
      kind == ProfileFeedItemKind.flow ? flowPost!.id : insightPost!.id;

  String get userId =>
      kind == ProfileFeedItemKind.flow ? flowPost!.userId : insightPost!.userId;

  DateTime get createdAt => kind == ProfileFeedItemKind.flow
      ? flowPost!.createdAt
      : insightPost!.createdAt;
}
