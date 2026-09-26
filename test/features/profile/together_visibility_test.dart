import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/data/flow_post_model.dart';
import 'package:mobile/features/profile/social_flow_post_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'anon-key-0123456789012345678901234567890123456789',
      );
    }
  });

  testWidgets('Together is absent unless an eligible action is supplied', (
    tester,
  ) async {
    final post = FlowPost(
      id: 'eligibility-post',
      userId: 'author',
      name: 'Morning Practice',
      color: 0xFF6F93A8,
      rules: const <dynamic>[],
      createdAt: DateTime(2026, 9, 24),
      authorDisplayName: 'Amina',
      authorHandle: 'amina',
      likesCount: 0,
      commentsCount: 0,
      likedByMe: false,
      hasLikesCount: true,
      hasCommentsCount: true,
      hasLikedByMe: true,
    );

    Future<void> pumpTile({VoidCallback? onTogether, String? label}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: SocialFlowPostTile(
              post: post,
              appearance: FlowAppearance.empty,
              accent: const Color(0xFF6F93A8),
              relationshipLabel: 'Following',
              events: const <Map<String, dynamic>>[],
              postedDateLabel: 'Rekh-Nedjes 12',
              isOwner: false,
              onOpenAuthor: () {},
              onOpenFlow: () {},
              onShare: () {},
              onSaveOrEdit: () {},
              onTogether: onTogether,
              togetherLabel: label ?? 'Together',
            ),
          ),
        ),
      );
    }

    await pumpTile();
    await tester.pump();
    expect(find.text('Together'), findsNothing);
    expect(find.text('Requested'), findsNothing);

    await pumpTile(onTogether: () {});
    await tester.pump();
    expect(find.text('Together'), findsOneWidget);

    await pumpTile(onTogether: () {}, label: 'Requested');
    await tester.pump();
    expect(find.text('Requested'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
