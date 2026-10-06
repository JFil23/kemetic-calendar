import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/sharing/share_flow_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_post_model.dart';
import 'package:mobile/features/profile/flow_post_share_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'key',
    );
  });

  testWidgets('Send in Inbox opens a rich published-flow share', (
    tester,
  ) async {
    final post = FlowPost(
      id: 'post-1',
      userId: 'author',
      name: 'Evening Return',
      color: 0x6f93a8,
      rules: [],
      createdAt: DateTime(2026, 10, 6),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => FlowPostShareActions.open(context, post),
              child: const Text('Share flow'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Share flow'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send in Inbox'));
    await tester.pumpAndSettle();
    final sheet = tester.widget<ShareFlowSheet>(find.byType(ShareFlowSheet));
    expect(sheet.flowPostId, 'post-1');
    expect(sheet.flowId, isNull);
    expect(sheet.noteShareText, isNull);
    expect(sheet.sendTextInInbox, isFalse);
    expect(tester.takeException(), isNull);
  });

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
