import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/profile_repo.dart';
import 'package:mobile/features/calendar/calendar_invalidation.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';
import 'package:mobile/features/profile/profile_page.dart';
import 'package:mobile/features/nodes/kemetic_node_library.dart';
import 'package:mobile/features/nodes/library_canon_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/maat_flow_visual_test_fonts.dart';
import '../pages/pages_resource_test.dart' show session, uid;

int fixtureSerial = 0;
List<Map<String, dynamic>> flows = [];
List<Map<String, dynamic>> insights = [];
String profileId = '';
Completer<void>? holdInsights;
bool failReads = false;
final captureKey = GlobalKey();

Map<String, dynamic> flow(String id, String posted) => {
  'id': id,
  'user_id': profileId,
  'name': 'Daily Math Visuals: 90-Day Visual Math Ladder.',
  'color': 0xFF986E3F,
  'notes': 'A 90-day visual math learning flow with one linked video each day.',
  'rules': <dynamic>[],
  'created_at': posted,
  'likes_count': 0,
  'comments_count': 0,
  'liked_by_me': false,
  'payload': {
    'appearance': {'sign_kind': 'palm_count'},
    'shared_note': "If you're curious about math you'll love this flow",
  },
};

Map<String, dynamic> insight(String id, String posted) => {
  'id': id,
  'user_id': profileId,
  'insight_entry_id': 'entry-$id',
  'node_slug': 'djehuty',
  'node_title': 'Djehuty',
  'node_glyph': '𓅝',
  'body_text': 'insight test for posting',
  'entry_date': '2026-07-08',
  'created_at': posted,
  'updated_at': posted,
};

Future<void> pumpProfile(
  WidgetTester tester, {
  Size size = const Size(390, 760),
  bool warm = true,
  bool resetPrefs = true,
  Map<String, dynamic>? restored,
  double textScale = 1,
  bool isMyProfile = true,
}) async {
  final viewer = isMyProfile ? profileId : uid;
  if (Supabase.instance.client.auth.currentUser?.id != viewer) {
    await tester.runAsync(
      () => Supabase.instance.client.auth.recoverSession(
        session().replaceAll(uid, viewer),
      ),
    );
  }
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (resetPrefs) {
    SharedPreferences.setMockInitialValues({
      if (warm)
        'profile:summary:v1:$profileId': jsonEncode({
          'id': profileId,
          'display_name': 'bigjfil',
          'handle': 'bigjfil',
        }),
      if (warm) 'profile:flow_posts:v1:$profileId': jsonEncode(flows),
      if (warm) 'profile:insight_posts:v1:$profileId': jsonEncode(insights),
    });
  }
  if (warm) {
    final repo = ProfileRepo(Supabase.instance.client);
    await tester.runAsync(() async {
      await repo.restoreCachedProfile(profileId);
      await repo.restoreCachedFlowPosts(profileId);
      await repo.restoreCachedInsightPosts(profileId);
    });
  }
  if (restored != null) {
    final save = AppRestorationService.instance.saveSurfaceState(
      'profile:$profileId',
      restored,
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await save;
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark().copyWith(
        textTheme: ThemeData.dark().textTheme.apply(
          fontFamily: 'GentiumPlus',
          fontFamilyFallback: const ['Noto Sans Egyptian Hieroglyphs'],
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: captureKey,
        child: ProfilePage(userId: profileId, isMyProfile: isMyProfile),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  final scroll = tester
      .widget<SingleChildScrollView>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('profile-posts-section')),
              matching: find.byType(SingleChildScrollView),
            )
            .first,
      )
      .controller!;
  final top = tester.getTopLeft(find.text('POSTS')).dy;
  scroll.jumpTo((top - 145).clamp(0, scroll.position.maxScrollExtent));
  await tester.pump();
  expect(tester.takeException(), isNull);
}

Future<void> capture(WidgetTester tester, String name) async {
  final dir = Platform.environment['HAW_PROFILE_POSTS_CAPTURE_DIR'];
  if (dir == null) return;
  await tester.runAsync(() async {
    final boundary =
        captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(dir).create(recursive: true);
    await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var frame = 0; frame < 15; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> next(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const ValueKey('profile-posts-pager')),
    const Offset(-290, 0),
  );
  await settle(tester);
}

Future<void> close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await settle(tester);
  final flush = AppRestorationService.instance.flushPendingWrites();
  await settle(tester);
  await flush;
}

void main() {
  final scenarios = <String, Future<void> Function(WidgetTester)>{};
  void scenario(String name, Future<void> Function(WidgetTester) body) {
    scenarios[name] = body;
  }

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
        if (request.url.path.endsWith('/insight_posts') &&
            request.method == 'GET') {
          await holdInsights?.future;
        }
        if (failReads) return http.Response('{}', 503, request: request);
        Object result = [];
        switch (request.url.path.split('/').last) {
          case 'profile_stats':
            result = {
              'id': profileId,
              'display_name': 'bigjfil',
              'handle': 'bigjfil',
            };
          case 'flow_posts':
            result = flows;
          case 'insight_posts':
            if (request.method == 'DELETE') {
              final id = request.url.queryParameters['id']!.substring(3);
              insights = insights.where((row) => row['id'] != id).toList();
            } else {
              result = insights;
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
  void resetFixture() {
    profileId = 'profile-posts-${fixtureSerial++}';
    flows = [];
    insights = [];
    holdInsights = null;
    failReads = false;
    AppRestorationService.debugUserIdResolver = () => profileId;
    AppWindowService.debugWindowIdResolver = () async =>
        'profile-carousel-test';
    AppRestorationService.debugRemoteSnapshotWriter = (_, _, _, _) async {};
  }

  tearDown(() {
    AppRestorationService.debugUserIdResolver = null;
    AppWindowService.debugWindowIdResolver = null;
    AppRestorationService.debugRemoteSnapshotWriter = null;
  });

  for (final width in [360.0, 390.0, 844.0]) {
    scenario('one shared posts frame at width $width', (tester) async {
      flows = [flow('flow-older', '2026-10-03T12:00:00Z')];
      insights = [insight('insight-newer', '2026-10-04T12:00:00Z')];
      await pumpProfile(tester, size: Size(width, 760));
      expect(find.text('POSTS'), findsOneWidget);
      expect(find.text('POSTED FLOWS'), findsNothing);
      expect(find.text('POSTED INSIGHTS'), findsNothing);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.text('Djehuty').hitTestable(), findsOneWidget);
      final excerpt = extractOpeningLine(
        KemeticNodeLibrary.resolve('djehuty')!.body,
      );
      expect(find.text(excerpt).hitTestable(), findsOneWidget);
      final insightCard = find.byKey(const ValueKey('posted-insight-artifact'));
      final insightSize = tester.getSize(insightCard);
      final insightTop = tester.getTopLeft(insightCard).dy;
      expect(insightSize.height, 236);
      expect(tester.getBottomLeft(find.text(excerpt)).dy, lessThan(insightTop));
      expect(
        tester.getTopLeft(find.text('Read more')).dy,
        greaterThan(tester.getBottomLeft(insightCard).dy),
      );
      await capture(tester, 'first-${width.toInt()}');
      await tester.drag(
        find.byKey(const ValueKey('profile-posts-pager')),
        Offset(-width * 0.75, 0),
      );
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('2 of 2'), findsOneWidget);
      expect(
        find
            .byKey(const ValueKey('profile-flow-post-flow-older'))
            .hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      final flowCard = find.byKey(const ValueKey('posted-flow-artifact'));
      expect(tester.getSize(flowCard), insightSize);
      expect(tester.getTopLeft(flowCard).dy, insightTop);
      await capture(tester, 'second-${width.toInt()}');
      await close(tester);
    });
  }
  for (final warm in [true, false]) {
    scenario(
      'mixed publication order with warm=$warm ignores entry dates and scores',
      (tester) async {
        flows = [
          flow('flow-oldest', '2026-10-01T12:00:00Z'),
          flow('flow-middle', '2026-10-03T12:00:00Z'),
        ];
        insights = [
          insight('insight-middle', '2026-10-02T12:00:00Z')
            ..['node_title'] = 'Middle insight',
          insight('insight-newest', '2026-10-04T12:00:00Z')..['score'] = -100,
        ];
        await pumpProfile(tester, warm: warm);
        expect(find.text('Djehuty').hitTestable(), findsOneWidget);
        await next(tester);
        expect(
          find
              .byKey(const ValueKey('profile-flow-post-flow-middle'))
              .hitTestable(),
          findsOneWidget,
        );
        await next(tester);
        expect(find.text('Middle insight').hitTestable(), findsOneWidget);
        await next(tester);
        expect(
          find
              .byKey(const ValueKey('profile-flow-post-flow-oldest'))
              .hitTestable(),
          findsOneWidget,
        );
        expect(find.text('4 of 4'), findsOneWidget);
        await close(tester);
      },
    );
  }

  for (final kind in ['empty', 'flow', 'insight']) {
    scenario('$kind is one coherent posts state', (tester) async {
      if (kind == 'flow') flows = [flow('single', '2026-10-01T12:00:00Z')];
      if (kind == 'insight') {
        insights = [insight('single', '2026-10-01T12:00:00Z')];
      }
      await pumpProfile(tester);
      expect(find.text('POSTS'), findsOneWidget);
      expect(
        find.text('Nothing posted yet'),
        kind == 'empty' ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('1 of 1'),
        kind == 'empty' ? findsNothing : findsOneWidget,
      );
      expect(find.bySemanticsLabel('Show post 1 of 1'), findsNothing);
      await close(tester);
    });
  }

  scenario(
    'missing Library node retains the posted identity without fabricated prose',
    (tester) async {
      insights = [
        insight('unknown-node', '2026-10-04T12:00:00Z')
          ..['node_slug'] = 'unavailable-node'
          ..['node_title'] = 'Preserved node title',
      ];
      await pumpProfile(tester);
      final excerpt = tester.widget<Text>(
        find.byKey(const ValueKey('profile-insight-node-excerpt')),
      );
      expect(excerpt.data, 'Preserved node title');
      expect(
        find.text('insight test for posting').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Read more').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );

  scenario('delayed insight read reorders a warm flow without hiding it', (
    tester,
  ) async {
    flows = [flow('warm-flow', '2026-10-01T12:00:00Z')];
    holdInsights = Completer<void>();
    await pumpProfile(tester);
    expect(
      find.byKey(const ValueKey('profile-flow-post-warm-flow')).hitTestable(),
      findsOneWidget,
    );
    insights = [insight('late-newest', '2026-10-04T12:00:00Z')];
    holdInsights!.complete();
    await settle(tester);
    expect(find.text('Djehuty').hitTestable(), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);
    await close(tester);
  });

  scenario('failed refresh retains both cached post types', (tester) async {
    flows = [flow('cached-flow', '2026-10-01T12:00:00Z')];
    insights = [insight('cached-insight', '2026-10-04T12:00:00Z')];
    failReads = true;
    await pumpProfile(tester);
    expect(find.text('Djehuty').hitTestable(), findsOneWidget);
    await next(tester);
    expect(
      find.byKey(const ValueKey('profile-flow-post-cached-flow')).hitTestable(),
      findsOneWidget,
    );
    await close(tester);
  });

  scenario('removing the last selected insight clamps the shared pager', (
    tester,
  ) async {
    flows = [flow('remaining', '2026-10-04T12:00:00Z')];
    insights = [insight('remove-me', '2026-10-01T12:00:00Z')];
    await pumpProfile(tester);
    await next(tester);
    await tester.tap(find.text('Remove'));
    await settle(tester);
    expect(find.text('1 of 1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('profile-flow-post-remaining')).hitTestable(),
      findsOneWidget,
    );
    expect(insights, isEmpty, reason: 'The owned post was actually removed');
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  scenario('selection survives a newer post and reopening the profile', (
    tester,
  ) async {
    flows = [flow('selected-flow', '2026-10-03T12:00:00Z')];
    insights = [insight('newest', '2026-10-04T12:00:00Z')];
    await pumpProfile(tester);
    await next(tester);
    insights = [insight('brand-new', '2026-10-05T12:00:00Z'), ...insights];
    CalendarInvalidationBus.instance.publish(
      const CalendarInvalidated(
        reason: CalendarInvalidationReason.flowEndedCommitted,
      ),
    );
    await settle(tester);
    await capture(tester, 'restored-selection');
    expect(find.text('3 of 3'), findsOneWidget);
    expect(
      find
          .byKey(const ValueKey('profile-flow-post-selected-flow'))
          .hitTestable(),
      findsOneWidget,
    );
    await close(tester);
    final saved = AppRestorationService.instance.readSurfaceState(
      'profile:$profileId',
    );
    await settle(tester);
    expect(
      await saved,
      containsPair('activeProfilePostKey', 'flow:selected-flow'),
    );
    await pumpProfile(tester, resetPrefs: false);
    await settle(tester);
    await capture(tester, 'restored-selection');
    expect(find.text('3 of 3'), findsOneWidget);
    expect(
      find
          .byKey(const ValueKey('profile-flow-post-selected-flow'))
          .hitTestable(),
      findsOneWidget,
    );
    await close(tester);
  });

  scenario('old flow-only restoration resolves its flow in the combined list', (
    tester,
  ) async {
    flows = [
      flow('flow-newer', '2026-10-03T12:00:00Z'),
      flow('flow-older', '2026-10-01T12:00:00Z'),
    ];
    insights = [insight('newest', '2026-10-04T12:00:00Z')];
    await pumpProfile(
      tester,
      restored: {
        'kind': 'profile',
        'activePostIndex': 1,
        'activeInsightPostIndex': 0,
      },
    );
    await settle(tester);
    expect(find.text('3 of 3'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('profile-flow-post-flow-older')).hitTestable(),
      findsOneWidget,
    );
    await close(tester);
  });
  scenario('many mixed posts keep the shared indicators within phone width', (
    tester,
  ) async {
    flows = [
      for (var i = 0; i < 20; i++) flow('flow-$i', '2026-10-02T12:00:00Z'),
    ];
    insights = [
      for (var i = 0; i < 20; i++)
        insight('insight-$i', '2026-10-04T12:00:00Z'),
    ];
    await pumpProfile(tester, size: const Size(360, 760));
    expect(find.text('1 of 40'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  scenario(
    'enlarged visitor insight retains read access and hides owner removal',
    (tester) async {
      insights = [
        insight('large', '2026-10-04T12:00:00Z')
          ..['body_text'] = List.filled(60, 'A longer reflection.').join(' '),
      ];
      await pumpProfile(
        tester,
        size: const Size(844, 760),
        textScale: 2,
        isMyProfile: false,
      );
      expect(find.text('Read more').hitTestable(), findsOneWidget);
      expect(find.text('Remove'), findsNothing);
      expect(tester.takeException(), isNull);
      await capture(tester, 'insight-large-text');
      await close(tester);
    },
  );
  // The production restoration owner serializes asynchronous writes. Keep all
  // scenarios on one widget clock so queued persistence never spans discarded
  // FakeAsync zones; every scenario still gets a separate account and storage.
  testWidgets('unified profile Posts visuals, ordering and continuity', (
    tester,
  ) async {
    for (final entry in scenarios.entries) {
      resetFixture();
      debugPrint('Profile Posts scenario: ${entry.key}');
      await entry.value(tester);
    }
  });
}
