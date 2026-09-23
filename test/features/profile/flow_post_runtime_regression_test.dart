import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_post_model.dart';
import 'package:mobile/features/profile/flow_post_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {}
  await Supabase.initialize(
    url: 'https://example.supabase.co',
    anonKey: 'anon-key-0123456789012345678901234567890123456789',
  );
}

FlowPost _post({required String id, required DateTime createdAt}) {
  final events = <Map<String, Object?>>[
    for (var index = 0; index < 90; index++)
      <String, Object?>{
        'offset_days': index,
        'title': 'Visual Math Day ${index + 1}',
        'detail': 'Watch the linked video and reflect.',
        'all_day': false,
        'start_time': '12:00 PM',
        'end_time': '1:00 PM',
        'location': 'https://example.com/video/$index',
      },
  ];
  final payload = <String, dynamic>{
    'name': 'Daily Math Visuals: 90-Day Visual Math Ladder.',
    'color': 16739179,
    'notes':
        'mode=gregorian;split=1;ov=A%2090-day%20visual%20math%20learning%20flow.',
    'rules': <dynamic>[],
    'start_date': '2026-05-25',
    'end_date': '2026-08-22',
    'events': events,
  };
  return FlowPost(
    id: id,
    userId: '27d63169-a28a-4550-a0a0-8fee0e8e7b95',
    name: payload['name']! as String,
    color: payload['color']! as int,
    notes: payload['notes']! as String,
    rules: const <dynamic>[],
    startDate: DateTime(2026, 5, 25),
    endDate: DateTime(2026, 8, 22),
    payloadJson: payload,
    createdAt: createdAt,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _ensureSupabaseInitialized();
  });

  testWidgets('a real 90-day social snapshot paints its full detail route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final posts = <FlowPost>[
      _post(id: 'post-1', createdAt: DateTime(2026, 5, 29)),
      _post(id: 'post-2', createdAt: DateTime(2026, 5, 28)),
      _post(id: 'post-3', createdAt: DateTime(2026, 5, 27)),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: FlowPostDetailPage(
          post: posts.first,
          posts: posts,
          isOwner: true,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Daily Math Visuals: 90-Day Visual Math Ladder.'),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey<String>('user-flow-external-action')),
      findsOneWidget,
    );
  });

  test(
    'community feed cannot substitute profile-owned posts for feed data',
    () {
      final source = File(
        'lib/features/profile/profile_page.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('seedProfileFeedFromOwnedPosts')));
      expect(source, isNot(contains('_primeFeedFromOwnedPosts')));
      expect(source, contains('getProfileFeedResult'));
    },
  );

  test('a post without profile names still exposes a unique owner label', () {
    final post = _post(id: 'owner-fallback', createdAt: DateTime(2026, 9, 22));

    expect(post.authorLabel, 'Hꜣw member 27D631');
    expect(post.authorLabel, isNot('Community'));
  });
}
