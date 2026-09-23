import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_post_model.dart';
import 'package:mobile/features/profile/flow_post_share_actions.dart';

void main() {
  test(
    'posted-flow share text carries voice, artifact title, and real route',
    () {
      final post = FlowPost(
        id: 'post id',
        userId: 'author-1',
        name: 'Evening Return',
        color: 0xFF6F93A8,
        rules: const <dynamic>[],
        aiMetadata: const <String, dynamic>{
          'shared_note': 'This flow changed the way I close the day.',
        },
        createdAt: DateTime.utc(2026, 9, 22),
      );

      final text = FlowPostShareActions.shareTextFor(post);

      expect(text, contains('This flow changed the way I close the day.'));
      expect(text, contains('Evening Return'));
      expect(text, contains('/flow-post/post%20id'));
      expect(text, isNot(contains('0 shares')));
    },
  );
}
