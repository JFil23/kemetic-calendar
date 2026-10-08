import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/share_models.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:mobile/features/calendar/the_reading_house/reading_house_room_repository.dart';
import 'package:mobile/features/inbox/inbox_page.dart';
import 'package:mobile/features/inbox/presentation/reading_house_inbox_section.dart';
import 'package:mobile/features/inbox/presentation/group_flow_inbox_preview_section.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/pages_resource_test.dart' show session, uid;
import '../../support/maat_flow_visual_test_fonts.dart';

const summary = <String, dynamic>{
  'calendar_id': 'house-calendar',
  'flow_id': 41,
  'house_title': 'The Odyssey',
  'member_count': 3,
  'unread_count': 2,
  'active': true,
  'locked': false,
  'ended': false,
  'latest_message': 'Perfect. I’m finishing the opening section now.',
  'latest_author_id': 'amina',
  'latest_author_display_name': 'Amina',
  'members': [
    {'user_id': 'amina', 'role': 'host', 'display_name': 'Amina'},
  ],
};
const together = <String, dynamic>{
  'quote_approvals': [],
  'request_decisions': [],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  Completer<void>? pending;
  var status = 200;
  var failMutation = false;
  var summaries = <Map<String, dynamic>>[summary];
  setUpAll(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'com.llfbandit.app_links/messages',
      'com.llfbandit.app_links/events',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        if (name.endsWith('/events') && call.method == 'listen') {
          scheduleMicrotask(
            () => messenger.handlePlatformMessage(name, null, (_) {}),
          );
        }
        return null;
      });
    }

    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        requests.add(r);
        if (failMutation &&
            r.url.path.endsWith('mark_together_request_decision_seen')) {
          return http.Response(
            '{"code":"42501","message":"denied"}',
            403,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }
        final isHouse = r.url.path.endsWith('reading_house_room_summaries');
        final isTogether = r.url.path.contains('/get_together_');
        if (isHouse || isTogether) {
          final gate = pending;
          if (gate != null) await gate.future;
          if (status != 200) {
            return http.Response(
              jsonEncode({
                'code': status == 403 ? '42501' : 'XX000',
                'message': 'fixture unavailable',
              }),
              status,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }
        }
        final data = isHouse
            ? summaries
            : r.url.path.endsWith('get_together_inbox')
            ? <String, dynamic>{}
            : [];
        return http.Response(
          jsonEncode(data),
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await loadMaatFlowVisualTestFonts();
  });
  setUp(() async {
    pending = null;
    status = 200;
    failMutation = false;
    summaries = [summary];
    requests.clear();
    WarmSnapshotStore.instance.invalidate(uid);
    SharedPreferences.setMockInitialValues({});
    await Supabase.instance.client.auth.recoverSession(session());
  });
  tearDown(() async {
    if (pending != null && !pending!.isCompleted) pending!.complete();
  });
  tearDownAll(() async => Supabase.instance.dispose());
  Future<void> seed() async {
    final store = WarmSnapshotStore.instance;
    await store.refresh(
      uid,
      'readingHouse.summaries',
      () async => [summary],
      isCurrent: () => true,
    );
    await store.refresh(
      uid,
      'social.together.inbox.40',
      () async => together,
      isCurrent: () => true,
    );
  }

  Future<void> mount(WidgetTester tester, {Key? key}) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      home: InboxSheetRoutePage(
        childForTesting: InboxPage(
          key: key,
          sheet: true,
          inboxItemsStreamForTesting:
              const Stream<List<InboxShareItem>>.empty(),
        ),
      ),
    ),
  );
  Future<void> tick(WidgetTester tester) async {
    // Match the existing Inbox scenarios: drain real socket setup before fake frames.
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tick(tester);
    await tester.runAsync(() async {
      final client = Supabase.instance.client;
      client.realtime.reconnectTimer.reset();
      await client.removeAllChannels();
      await client.realtime.disconnect();
      client.realtime.reconnectTimer.reset();
    });
    await tester.pump();
  }

  testWidgets(
    'warm Reading House row and empty Together section paint immediately and survive failed refresh/reopen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(seed);
      pending = Completer<void>();
      await mount(tester, key: const ValueKey('first'));
      expect(find.byType(ReadingHouseInboxRoomRow), findsOneWidget);
      expect(find.byType(GroupFlowInboxSection), findsNothing);
      final rect = tester.getRect(find.byType(ReadingHouseInboxRoomRow));
      await tick(tester);
      expect(tester.getRect(find.byType(ReadingHouseInboxRoomRow)), rect);
      status = 503;
      pending!.complete();
      await tick(tester);
      expect(find.byType(ReadingHouseInboxRoomRow), findsOneWidget);
      expect(find.text('Reading Houses could not load.'), findsNothing);
      await mount(tester, key: const ValueKey('reopen'));
      expect(find.byType(ReadingHouseInboxRoomRow), findsOneWidget);
      expect(tester.getRect(find.byType(ReadingHouseInboxRoomRow)), rect);
      expect(find.byType(GroupFlowInboxSection), findsNothing);
      expect(
        requests.where(
          (r) =>
              r.url.path.contains('mark_read') ||
              r.url.path.contains('create_reading'),
        ),
        isEmpty,
      );
      await unmount(tester);
    },
  );
  testWidgets(
    'cold summary arrives then a background update replaces the row without remounting',
    (tester) async {
      pending = Completer<void>();
      await mount(tester);
      expect(find.byType(ReadingHouseInboxRoomRow), findsNothing);
      pending!.complete();
      await tick(tester);
      expect(find.byType(ReadingHouseInboxRoomRow), findsOneWidget);
      summaries = [
        {...summary, 'house_title': 'Updated book'},
      ];
      final refresh = SupabaseReadingHouseRoomRepository(
        Supabase.instance.client,
      ).listSummaries();
      await tick(tester);
      await refresh;
      expect(
        tester
            .widget<ReadingHouseInboxRoomRow>(
              find.byType(ReadingHouseInboxRoomRow),
            )
            .room
            .bookTitle,
        'Updated book',
      );
      await unmount(tester);
    },
  );
  testWidgets(
    'permission denial clears private cached row and account departure fences held refresh',
    (tester) async {
      await tester.runAsync(seed);
      pending = Completer<void>();
      await mount(tester);
      expect(find.byType(ReadingHouseInboxRoomRow), findsOneWidget);
      status = 403;
      pending!.complete();
      await tick(tester);
      expect(find.byType(ReadingHouseInboxRoomRow), findsNothing);
      expect(
        WarmSnapshotStore.instance.peek(uid, 'readingHouse.summaries'),
        isNull,
      );
      expect(
        WarmSnapshotStore.instance.peek(uid, 'social.together.inbox.40'),
        isNull,
      );
      await unmount(tester);

      final reseed = seed();
      await tick(tester);
      await reseed;

      status = 200;
      pending = Completer<void>();
      await mount(tester);
      expect(find.byType(ReadingHouseInboxRoomRow), findsOneWidget);

      await tester.runAsync(
        () => Supabase.instance.client.auth.signOut(scope: SignOutScope.local),
      );
      await tick(tester);
      expect(find.byType(ReadingHouseInboxRoomRow), findsNothing);

      pending!.complete();
      await tick(tester);
      expect(find.byType(ReadingHouseInboxRoomRow), findsNothing);
      await unmount(tester);
    },
  );
}
