import 'package:flutter/material.dart';
import '../../core/navigation_fallback.dart';
import '../../data/insight_post_model.dart';
import '../nodes/kemetic_node_library.dart';
import '../reflections/decan_review_widgets.dart';

/// The decan publication kind has one renderer in profile, feed and detail.
/// Only the reviewed public snapshot is accepted here; never a private review.
class DecanInsightPost extends StatelessWidget {
  const DecanInsightPost({
    super.key,
    required this.post,
    this.onOpen,
    this.onRemove,
    this.onOpenAuthor,
  });
  final InsightPost post;
  final VoidCallback? onOpen, onRemove, onOpenAuthor;

  @override
  Widget build(BuildContext context) {
    final slug = post.readingLink?['slug'] as String?;
    final reading = slug == null ? null : KemeticNodeLibrary.resolve(slug);
    return Column(
      key: ValueKey('decan-insight-${post.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecanPublicReflectionCard(
          author: post.authorLabel,
          handle: post.authorHandle,
          onAuthor:
              onOpenAuthor ??
              () => openDetailRoute(
                context,
                '/profile/${Uri.encodeComponent(post.userId)}',
              ),
          body: post.bodyText,
          question: post.questionText,
          readingTitle: reading?.title,
          onReading: reading == null
              ? null
              : () => openDetailRoute(
                  context,
                  '/nodes/${Uri.encodeComponent(reading.id)}',
                ),
        ),
        if (onOpen != null || onRemove != null)
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 16,
            children: [
              if (onRemove != null)
                TextButton(
                  onPressed: onRemove,
                  child: Text('Remove post', style: DecanReviewStyle.ui(12.5)),
                ),
              if (onOpen != null)
                TextButton(
                  onPressed: onOpen,
                  child: Text(
                    'Open reflection ↗',
                    style: DecanReviewStyle.ui(12.5),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
