import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/account_view_cache.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/data/flow_appearance_store.dart';
import 'package:mobile/data/flow_post_model.dart';
import 'package:mobile/data/profile_repo.dart';
import 'package:mobile/data/user_events_repo.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:mobile/features/calendar/calendar_invalidation.dart';
import 'package:mobile/features/profile/profile_page.dart';
import 'package:mobile/features/profile/profile_flow_post_tile.dart';
import 'package:mobile/features/profile/social_flow_post_tile.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/profile_post_removal_test.dart' show session;
import '../../support/maat_flow_visual_test_fonts.dart';

void main() => registerPhotoRefreshTests(feedScenario: false);

// Each retained surface runs in its own Flutter test environment so static
// Supabase/cache futures cannot retain a completed FakeAsync test zone.
void registerPhotoRefreshTests({required bool feedScenario}) {
  var serial = 0;
  late String owner;
  late Map<String, dynamic> row;
  late Object? confirmed;
  Completer<void>? holdWrite, writeStarted, holdNextFeed, feedStarted;
  Map<String, dynamic> image(String suffix) => {
    'version': 1,
    'image_object_path': '$owner/$suffix.jpg',
  };
  final pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aG/QAAAAASUVORK5CYII=',
  );

  setUpAll(() async {
    await loadMaatFlowVisualTestFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((request) async {
        Object? result = [];
        final path = request.url.path.split('/').last;
        switch (path) {
          case 'token':
            result = jsonDecode(session(owner));
          case 'profile_stats':
            result = {
              'id': owner,
              'display_name': 'October',
              'handle': 'potato',
            };
          case 'flow_posts':
            result = [jsonDecode(jsonEncode(row))];
          case 'get_profile_feed_together_cards':
            final snapshot = {
              'post_type': 'flow',
              ...jsonDecode(jsonEncode(row)) as Map<String, dynamic>,
            };
            final held = holdNextFeed;
            holdNextFeed = null;
            if (held != null) {
              feedStarted!.complete();
              await held.future;
            }
            result = [snapshot];
          case 'flows':
            if (request.method == 'PATCH') {
              writeStarted?.complete();
              await holdWrite?.future;
              row = FlowPost.fromJson(row).withAppearance(confirmed).toJson();
              result = {'id': 73, 'user_id': owner, 'appearance': confirmed};
            }
        }
        return http.Response(
          jsonEncode(result),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  Future<void> drain(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
  }

  Future<void> start(WidgetTester tester, {required bool feed}) async {
    owner = 'profile-photo-${serial++}';
    row = {
      'id': 'posted-$owner',
      'user_id': owner,
      'flow_id': 73,
      'name': 'Retained practice',
      'color': 0x986e3f,
      'rules': [],
      'created_at': '2026-10-05T10:00:00Z',
      'likes_count': 7,
      'comments_count': 2,
      'liked_by_me': false,
      'payload': {
        'appearance': image('a'),
        'events': [
          {'title': 'Same event', 'offset_days': 0},
        ],
      },
      'ai_metadata': {
        'shared_note': 'My unchanged caption',
        'payload': {'appearance': image('a')},
      },
    };
    confirmed = image('b');
    holdWrite = null;
    writeStarted = null;
    holdNextFeed = null;
    SharedPreferences.setMockInitialValues({
      'profile:summary:v1:$owner': jsonEncode({
        'id': owner,
        'display_name': 'October',
        'handle': 'potato',
      }),
      'profile:flow_posts:v1:$owner': jsonEncode([row]),
      'profile:insight_posts:v1:$owner': '[]',
    });
    AppRestorationService.debugUserIdResolver = () => owner;
    AppWindowService.debugWindowIdResolver = () async => 'photo-refresh';
    AppRestorationService.debugRemoteSnapshotWriter = (_, _, _, _) async {};
    FlowAppearanceStore.debugDownloadImageForTesting = (_, _) async => pixel;
    await tester.runAsync(() async {
      await Supabase.instance.client.auth.recoverSession(session(owner));
      AccountViewCache.instance.enterAccount(owner);
      final repo = ProfileRepo(Supabase.instance.client);
      await repo.restoreCachedProfile(owner);
      await repo.restoreCachedFlowPosts(owner);
      await repo.restoreCachedInsightPosts(owner);
    });
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          userId: owner,
          isMyProfile: true,
          initialFeedRevealed: feed,
        ),
      ),
    );
    await drain(tester);
    if (feed) {
      await tester.tap(find.text('FOR YOU'));
      await drain(tester);
    }
    expect(tester.takeException(), isNull);
  }

  Future<void> save(WidgetTester tester) async {
    final saving = UserEventsRepo(Supabase.instance.client).upsertFlow(
      id: 73,
      name: 'Retained practice',
      color: 0x986e3f,
      active: true,
      rules: '[]',
      appearance: FlowAppearance(imageObjectPath: '$owner/intent.jpg'),
    );
    await drain(tester);
    expect(await saving, 73);
    CalendarInvalidationBus.instance.publish(
      const CalendarInvalidated(
        reason: CalendarInvalidationReason.flowStudioPersisted,
        flowId: 73,
      ),
    );
    await drain(tester);
  }

  Future<void> stop(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await drain(tester);
    final flush = AppRestorationService.instance.flushPendingWrites();
    await drain(tester);
    await flush;
    final warmFlush = WarmSnapshotStore.instance.flushed;
    await drain(tester);
    await warmFlush;
    tester.view.reset();
  }

  tearDown(() {
    AppRestorationService.debugUserIdResolver = null;
    AppWindowService.debugWindowIdResolver = null;
    AppRestorationService.debugRemoteSnapshotWriter = null;
    FlowAppearanceStore.debugResetImageCacheForTesting();
  });

  if (!feedScenario) {
    testWidgets(
      'retained profile changes photo and clears it without moving or recreating its card',
      (tester) async {
        await start(tester, feed: false);
        final finder = find.byType(ProfileFlowPostTile);
        expect(finder, findsOneWidget);
        final state = tester.state(find.byType(ProfilePage));
        final original = tester.widget<ProfileFlowPostTile>(finder);
        final size = tester.getSize(finder);
        expect(original.appearance.imageObjectPath, '$owner/a.jpg');
        await save(tester);
        final updated = tester.widget<ProfileFlowPostTile>(finder);
        expect(updated.appearance.imageObjectPath, '$owner/b.jpg');
        expect(updated.post.id, original.post.id);
        expect(updated.post.sharedNote, original.post.sharedNote);
        expect(updated.events, original.events);
        expect(tester.getSize(finder), size);
        expect(
          identical(tester.state(find.byType(ProfilePage)), state),
          isTrue,
        );
        confirmed = null;
        await save(tester);
        expect(
          tester.widget<ProfileFlowPostTile>(finder).appearance.isEmpty,
          isTrue,
        );
        expect(tester.getSize(finder), size);
        expect(tester.takeException(), isNull);
        await stop(tester);
      },
    );
  }

  if (feedScenario) {
    testWidgets(
      'retained For You card refreshes past an older feed request and preserves engagement',
      (tester) async {
        await start(tester, feed: true);
        final finder = find.byType(SocialFlowPostTile);
        expect(finder, findsOneWidget);
        final old = tester.widget<SocialFlowPostTile>(finder);
        final state = tester.state(find.byType(ProfilePage));
        expect(old.appearance.imageObjectPath, '$owner/a.jpg');
        final held = Completer<void>();
        holdNextFeed = held;
        feedStarted = Completer<void>();
        CalendarInvalidationBus.instance.publish(
          const CalendarInvalidated(
            reason: CalendarInvalidationReason.flowStudioPersisted,
            flowId: 73,
          ),
        );
        await drain(tester);
        expect(feedStarted!.isCompleted, isTrue);
        await save(tester);
        expect(
          tester.widget<SocialFlowPostTile>(finder).appearance.imageObjectPath,
          '$owner/b.jpg',
        );
        held.complete();
        await drain(tester);
        final current = tester.widget<SocialFlowPostTile>(finder);
        expect(current.appearance.imageObjectPath, '$owner/b.jpg');
        expect(current.post.likesCount, 7);
        expect(current.post.commentsCount, 2);
        expect(current.post.id, old.post.id);
        expect(
          identical(tester.state(find.byType(ProfilePage)), state),
          isTrue,
        );
        confirmed = null;
        await save(tester);
        expect(
          tester.widget<SocialFlowPostTile>(finder).appearance.isEmpty,
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await stop(tester);
      },
    );
  }
}
