import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/shared_practice_repo.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:mobile/features/calendar/the_reading_house/reading_house_room_repository.dart';
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
    await WarmSnapshotStore.instance.forgetAccount(uid);
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
    await store.flushed;
  }

  test(
    'old Reading House envelope restores without network; full Together cache stays separate from Pages',
    () async {
      final store = WarmSnapshotStore.instance;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'warm_snapshot:v1:$uid:readingHouse.summaries',
        jsonEncode({
          'schema': 1,
          'userId': uid,
          'updatedAt': '2026-10-07T00:00:00Z',
          'data': [summary],
        }),
      );
      await prefs.setString(
        'warm_snapshot:v1:$uid:social.together.inbox.40',
        jsonEncode({
          'schema': 1,
          'resourceSchema': 1,
          'userId': uid,
          'updatedAt': '2026-10-07T00:00:00Z',
          'data': together,
        }),
      );
      final repo = SupabaseReadingHouseRoomRepository(Supabase.instance.client);
      expect(
        (await repo.listSummaries(cachedOnly: true)).single.title,
        'The Odyssey',
      );
      expect(
        (await SharedPracticeRepo(
          Supabase.instance.client,
        ).getTogetherInbox(cachedOnly: true)).isEmpty,
        isTrue,
      );
      expect(requests, isEmpty);
      expect(store.peek(uid, 'pages.together'), isNull);
    },
  );
  test(
    'Together writes preserve warm content on failure and fence old reads after acknowledgement',
    () async {
      await seed();
      final repo = SharedPracticeRepo(Supabase.instance.client);
      failMutation = true;
      await expectLater(
        repo.markTogetherRequestDecisionSeen('request'),
        throwsA(isA<PostgrestException>()),
      );
      expect(repo.cachedTogetherInbox(), isNotNull);
      failMutation = false;
      pending = Completer<void>();
      final oldRead = repo.getTogetherInbox();
      final cancelled = expectLater(oldRead, throwsA(isA<WarmReadCancelled>()));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await repo.markTogetherRequestDecisionSeen('request');
      expect(repo.cachedTogetherInbox(), isNull);
      pending!.complete();
      await cancelled;
      expect(repo.cachedTogetherInbox(), isNull);
      expect((await repo.getTogetherInbox()).isEmpty, isTrue);
    },
  );

  test(
    'A-B-A account changes reject old Reading House and Together results',
    () async {
      pending = Completer<void>();
      final houseRead = SupabaseReadingHouseRoomRepository(
        Supabase.instance.client,
      ).listSummaries();
      final togetherRead = SharedPracticeRepo(
        Supabase.instance.client,
      ).getTogetherInbox();
      final houseCancelled = expectLater(
        houseRead,
        throwsA(isA<WarmReadCancelled>()),
      );
      final togetherCancelled = expectLater(
        togetherRead,
        throwsA(isA<WarmReadCancelled>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await Supabase.instance.client.auth.recoverSession(
        session().replaceAll(uid, '27d63169-a28a-4550-a0a0-8fee0e8e7b96'),
      );
      await Supabase.instance.client.auth.recoverSession(session());
      pending!.complete();
      await Future.wait([houseCancelled, togetherCancelled]);
      expect(
        WarmSnapshotStore.instance.peek(uid, 'readingHouse.summaries'),
        isNull,
      );
      expect(
        WarmSnapshotStore.instance.peek(uid, 'social.together.inbox.40'),
        isNull,
      );
    },
  );
  test(
    'confirmed practice reads persist and reconstruct in a new store without requests',
    () async {
      final client = Supabase.instance.client;
      await SupabaseReadingHouseRoomRepository(client).listSummaries();
      await SharedPracticeRepo(client).getTogetherInbox();
      await WarmSnapshotStore.instance.flushed;
      requests.clear();
      final restarted = WarmSnapshotStore();
      await restarted.restore(uid);
      expect(
        (restarted.peek(uid, 'readingHouse.summaries')!.data as List)
            .single['house_title'],
        'The Odyssey',
      );
      expect(restarted.peek(uid, 'social.together.inbox.40')!.data, together);
      expect(requests, isEmpty);
    },
  );

  test(
    'malformed Together cache is a miss, never a confirmed empty Inbox',
    () async {
      final store = WarmSnapshotStore.instance;
      await store.refresh(
        uid,
        'social.together.inbox.40',
        () async => {'active_rooms': 'invalid'},
        isCurrent: () => true,
      );
      final repo = SharedPracticeRepo(Supabase.instance.client);
      expect(repo.cachedTogetherInbox(), isNull);
      await expectLater(
        repo.getTogetherInbox(cachedOnly: true),
        throwsFormatException,
      );
      expect(requests, isEmpty);
    },
  );
}
