import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/flow_post_model.dart';
import 'package:mobile/data/profile_repo.dart';
import 'package:mobile/data/share_models.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:mobile/features/profile/flow_post_detail_page.dart';
import 'package:mobile/features/profile/profile_page.dart';
import 'package:mobile/features/profile/profile_flow_post_tile.dart';
import 'package:mobile/main.dart' show createAppRouterForTesting;
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

const owner = '40bef9d0-2209-4fe3-9132-d5a385fbc418';
const nextOwner = '50bef9d0-2209-4fe3-9132-d5a385fbc418';
int serial = 0;
List<Map<String, dynamic>> rows = [];
List<String> removals = [];
Completer<void>? holdRemoval;
bool failRemoval = false;
final captureKey = GlobalKey();

String session(String id) {
  final expiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return jsonEncode({
    'access_token':
        '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': id, 'exp': expiresAt})}.signature',
    'refresh_token': 'fixture-refresh',
    'expires_in': 3600,
    'token_type': 'bearer',
    'user': {
      'id': id,
      'app_metadata': {},
      'user_metadata': {},
      'aud': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
    },
  });
}

Map<String, dynamic> row(int index) {
  final name = [
    'Eight-day Math Flow',
    'Dawn House Rite',
    '10-Day Yoga Plan',
  ][index];
  final event = [
    'Visual Math Exercise',
    'Dawn Offering',
    'Evening Yoga',
  ][index];
  return {
    'id': 'post-$serial-$index',
    'user_id': owner,
    'name': name,
    'color': [0xFF407F92, 0xFFBA883C, 0xFF8964D4][index],
    'notes': 'A distinct practice for $name.',
    'rules': [],
    'is_hidden': false,
    'start_date': '2026-10-05',
    'end_date': '2026-10-12',
    'created_at': '2026-10-0${3 - index}T00:00:00Z',
    'payload': {
      'name': name,
      'color': [0xFF407F92, 0xFFBA883C, 0xFF8964D4][index],
      'notes': 'A distinct practice for $name.',
      'rules': [],
      'start_date': '2026-10-05',
      'end_date': '2026-10-12',
      'events': [
        {
          'offset_days': 0,
          'title': event,
          'detail': 'Practice $event.',
          'all_day': true,
        },
      ],
    },
  };
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['HAW_PROFILE_POSTS_CAPTURE_DIR'];
  if (directory == null) return;
  await tester.runAsync(() async {
    final boundary =
        captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<({GoRouter router, GoRouter appRouter})> pumpRouter(
  WidgetTester tester, {
  bool profile = false,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final appRouter = createAppRouterForTesting();
  final route = appRouter.configuration.routes.whereType<GoRoute>().singleWhere(
    (r) => r.path == '/flow-post/:postId',
  );
  final router = GoRouter(
    initialLocation: '/profile/me',
    routes: [
      GoRoute(
        path: '/profile/me',
        builder: (_, _) => profile
            ? const ProfilePage(userId: owner, isMyProfile: true)
            : const Scaffold(body: Text('Profile background')),
      ),
      route,
    ],
  );
  await tester.pumpWidget(
    RepaintBoundary(
      key: captureKey,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          textTheme: ThemeData.dark().textTheme.apply(
            fontFamily: 'GentiumPlus',
            fontFamilyFallback: const ['Noto Sans Egyptian Hieroglyphs'],
          ),
        ),
        routerConfig: router,
      ),
    ),
  );
  await settle(tester);
  return (router: router, appRouter: appRouter);
}

Future<void> close(
  WidgetTester tester,
  ({GoRouter router, GoRouter appRouter}) harness,
) async {
  await tester.pumpWidget(const SizedBox());
  await settle(tester);
  harness.router.dispose();
  harness.appRouter.dispose();
}

Future<void> tapRemovePost(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey('user-flow-detail-options')).hitTestable(),
  );
  await settle(tester);
  await tester.tap(
    find.byKey(const ValueKey('flow-detail-action-remove-profile-post')),
  );
  await tester.pump();
}

Future<void> warmPosts(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final row in rows) {
      await WarmSnapshotStore.instance.refresh(
        owner,
        'social.post.${row['id']}',
        () async => row,
        isCurrent: () => true,
      );
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
        final table = request.url.path.split('/').last;
        if (table == 'token') {
          result = jsonDecode(
            session(Supabase.instance.client.auth.currentUser!.id),
          );
        } else if (table == 'flow_posts') {
          final id = request.url.queryParameters['id']?.substring(3);
          if (request.method == 'PATCH') {
            removals.add(id!);
            await holdRemoval?.future;
            if (failRemoval) {
              return http.Response(
                '{"message":"unavailable"}',
                503,
                request: request,
              );
            }
            for (final row in rows.where((r) => r['id'] == id)) {
              row['is_hidden'] = true;
            }
            result = {'id': id};
          } else if (id != null) {
            final found = rows.where((r) => r['id'] == id).toList();
            result = found.isEmpty ? null : found.single;
          } else {
            // Owner RLS deliberately retains hidden posts. The repository must
            // enforce publication visibility in both live and cached readers.
            result = rows;
          }
        } else if (table == 'profile_stats' || table == 'profiles') {
          result = {
            'id': owner,
            'display_name': 'BigJFil',
            'handle': 'bigjfil',
            'created_at': '2026-01-01T00:00:00Z',
          };
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
  setUp(() async {
    serial++;
    rows = List.generate(3, row);
    removals = [];
    holdRemoval = null;
    failRemoval = false;
    SharedPreferences.setMockInitialValues({'app:has_seen_onboarding': true});
    await Supabase.instance.client.auth.recoverSession(session(owner));
    AppRestorationService.debugUserIdResolver = () => owner;
    AppWindowService.debugWindowIdResolver = () async => 'profile-navigation';
    AppRestorationService.debugRemoteSnapshotWriter = (_, _, _, _) async {};
  });
  tearDown(() {
    AppRestorationService.debugUserIdResolver = null;
    AppWindowService.debugWindowIdResolver = null;
    AppRestorationService.debugRemoteSnapshotWriter = null;
  });

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('existing owner detail visual at $size', (tester) async {
      final h = await pumpRouter(tester, size: size);
      final post = FlowPost.fromJson(rows[1]);
      unawaited(h.router.push<bool>('/flow-post/${post.id}', extra: post));
      await settle(tester);
      expect(find.text('Dawn House Rite'), findsWidgets);
      expect(
        find.byKey(const ValueKey('user-flow-detail-options')),
        findsOneWidget,
      );
      await capture(tester, 'owner-detail-${size.width.toInt()}');
      expect(tester.takeException(), isNull);
      await close(tester, h);
    });
  }

  testWidgets('archived landscape reference without a profile action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final appRouter = createAppRouterForTesting();
    final route = appRouter.configuration.routes
        .whereType<GoRoute>()
        .singleWhere((r) => r.path == '/shared-flow/:shareId');
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        route,
      ],
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp.router(
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
    unawaited(
      router.push<void>(
        '/shared-flow/reference',
        extra: InboxShareItem(
          shareId: 'reference',
          kind: InboxShareKind.flow,
          recipientId: owner,
          senderId: nextOwner,
          payloadId: '42',
          title: 'Dawn House Rite',
          createdAt: DateTime(2026, 10, 5),
          payloadJson: rows[1]['payload'],
        ),
      ),
    );
    await settle(tester);
    await capture(tester, 'archived-landscape-without-action');
    await close(tester, (router: router, appRouter: appRouter));
  });

  testWidgets(
    'warm route opens every selected post with its own title and events',
    (tester) async {
      await warmPosts(tester);
      final h = await pumpRouter(tester);
      final posts = rows.map(FlowPost.fromJson).toList();
      for (var index = 0; index < posts.length; index++) {
        final post = posts[index];
        unawaited(
          h.router.push<bool>(
            '/flow-post/${post.id}',
            extra: {'post': post, 'posts': posts, 'initialIndex': index},
          ),
        );
        await settle(tester);
        final title = find.text(post.name).first;
        expect(title, findsOneWidget);
        final titleBounds = tester.getRect(title);
        expect(titleBounds.center.dx, inInclusiveRange(0.0, 390.0));
        expect(titleBounds.center.dy, inInclusiveRange(0.0, 844.0));
        final event = find.text(
          ['Visual Math Exercise', 'Dawn Offering', 'Evening Yoga'][index],
        );
        expect(event, findsWidgets);
        final pager = tester.widget<PageView>(
          find
              .descendant(
                of: find.byType(FlowPostDetailPage),
                matching: find.byType(PageView),
              )
              .first,
        );
        expect(pager.controller!.page, index.toDouble());
        await capture(tester, 'selected-detail-$index');
        await tester.ensureVisible(event.first);
        await settle(tester);
        expect(event.hitTestable(), findsWidgets);
        h.router.pop();
        await settle(tester);
      }
      await close(tester, h);
    },
  );

  testWidgets('profile menu removal stays removed after owner refresh', (
    tester,
  ) async {
    final h = await pumpRouter(tester, profile: true);
    await tester.ensureVisible(
      find.byKey(const ValueKey('profile-posts-section')),
    );
    await settle(tester);
    final menu = find
        .byKey(const ValueKey('profile-flow-post-menu'))
        .hitTestable()
        .first;
    final tile = tester.widget<ProfileFlowPostTile>(
      find.ancestor(of: menu, matching: find.byType(ProfileFlowPostTile)).first,
    );
    final removedId = tile.post.id;
    await tester.tap(menu);
    await settle(tester);
    await tester.tap(find.text('Remove post'));
    await settle(tester);
    expect(find.text('Delete this post?'), findsOneWidget);
    await tester.tap(find.text('Delete post'));
    await settle(tester);
    expect(removals, [removedId]);
    expect(find.byKey(ValueKey('profile-flow-post-$removedId')), findsNothing);
    expect(
      ProfileRepo(
        Supabase.instance.client,
      ).getCachedFlowPostsSync(owner)!.map((p) => p.id),
      isNot(contains(removedId)),
    );
    await close(tester, h);
  });

  testWidgets(
    'detail removal acknowledges once and refreshes profile across token refresh',
    (tester) async {
      await warmPosts(tester);
      final h = await pumpRouter(tester, profile: true);
      final target = find.byKey(
        ValueKey('open-profile-flow-post-${rows.first['id']}'),
      );
      await tester.ensureVisible(target);
      await settle(tester);
      await tester.tap(target);
      await settle(tester);
      await Supabase.instance.client.auth.refreshSession();
      holdRemoval = Completer<void>();
      await tapRemovePost(tester);
      await tester.tap(
        find.byKey(const ValueKey('user-flow-detail-options')).hitTestable(),
      );
      await settle(tester);
      final action = tester.widget<PopupMenuItem>(
        find.byKey(const ValueKey('flow-detail-action-remove-profile-post')),
      );
      expect(action.enabled, false);
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      expect(removals, [rows.first['id']]);
      expect(find.byType(FlowPostDetailPage), findsOneWidget);
      await Supabase.instance.client.auth.refreshSession();
      holdRemoval!.complete();
      await settle(tester);
      expect(find.byType(FlowPostDetailPage), findsNothing);
      expect(
        find.byKey(ValueKey('profile-flow-post-${rows.first['id']}')),
        findsNothing,
      );
      expect(
        ProfileRepo(
          Supabase.instance.client,
        ).getCachedFlowPostsSync(owner)!.map((p) => p.id),
        isNot(contains(rows.first['id'])),
      );
      expect(tester.takeException(), isNull);
      await close(tester, h);
    },
  );

  testWidgets('failed detail removal retains the post and permits retry', (
    tester,
  ) async {
    final h = await pumpRouter(tester);
    final post = FlowPost.fromJson(rows[1]);
    unawaited(h.router.push<bool>('/flow-post/${post.id}', extra: post));
    await settle(tester);
    failRemoval = true;
    await tapRemovePost(tester);
    await settle(tester);
    expect(find.byType(FlowPostDetailPage), findsOneWidget);
    expect(find.text('Unable to remove this flow.'), findsWidgets);
    expect(rows[1]['is_hidden'], false);
    failRemoval = false;
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    await tapRemovePost(tester);
    await settle(tester);
    expect(find.byType(FlowPostDetailPage), findsNothing);
    expect(removals, [post.id, post.id]);
    await close(tester, h);
  });

  testWidgets('departed account removal cannot pop the next account route', (
    tester,
  ) async {
    final h = await pumpRouter(tester);
    final post = FlowPost.fromJson(rows[1]);
    unawaited(h.router.push<bool>('/flow-post/${post.id}', extra: post));
    await settle(tester);
    holdRemoval = Completer<void>();
    await tapRemovePost(tester);
    await tester.pump();
    await Supabase.instance.client.auth.recoverSession(session(nextOwner));
    holdRemoval!.complete();
    await settle(tester);
    expect(find.byType(FlowPostDetailPage), findsOneWidget);
    expect(find.text('Unable to remove this flow.'), findsNothing);
    await close(tester, h);
  });
}
