import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_post_comment_model.dart';

FlowPostComment _comment({
  required String id,
  String? parentCommentId,
  String userId = 'user-1',
}) {
  return FlowPostComment(
    id: id,
    flowPostId: 'post-1',
    userId: userId,
    parentCommentId: parentCommentId,
    body: 'Comment $id',
    createdAt: DateTime(2026, 4, 19),
  );
}

void main() {
  group('collectFlowPostThreadIds', () {
    test('collects the full descendant thread for a root comment', () {
      final comments = [
        _comment(id: 'root'),
        _comment(id: 'child-1', parentCommentId: 'root'),
        _comment(id: 'child-2', parentCommentId: 'root'),
        _comment(id: 'grandchild', parentCommentId: 'child-1'),
        _comment(id: 'other-root'),
      ];

      final ids = collectFlowPostThreadIds(comments, 'root');

      expect(ids, {'root', 'child-1', 'child-2', 'grandchild'});
    });

    test('returns only the target id when there are no replies', () {
      final comments = [_comment(id: 'solo'), _comment(id: 'other-root')];

      final ids = collectFlowPostThreadIds(comments, 'solo');

      expect(ids, {'solo'});
    });
  });
}
