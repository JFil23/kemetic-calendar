import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/account_view_cache.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/data/flow_post_model.dart';
import 'package:mobile/data/pages_read_repository.dart';
import 'package:mobile/data/profile_repo.dart';
import 'package:mobile/data/user_events_repo.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_post_removal_test.dart' show session;

class _Fixture {
  _Fixture(this.owner) {
    rows = [post('linked', 73), post('unlinked', 74)];
    client = SupabaseClient(
      'https://example.supabase.co',
      'fixture-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        http.Response reply(Object? value, {int status = 200}) => http.Response(
          jsonEncode(value),
          status,
          headers: {'content-type': 'application/json'},
          request: request,
        );
        final table = request.url.path.split('/').last;
        if (table == 'token') {
          return reply(jsonDecode(session(client.auth.currentUser!.id)));
        }
        if (table == 'flows' && request.method == 'PATCH') {
          if (!writeStarted.isCompleted) writeStarted.complete();
          await holdWrite?.future;
          if (failWrite) return reply({'message': 'unavailable'}, status: 503);
          // Models the acknowledged backend projection; this fixture does not
          // claim to verify the backend trigger itself.
          if (returnedOwner == owner) {
            rows = rows.map((row) {
              final post = FlowPost.fromJson(row);
              return post.sourceFlowId == 73
                  ? post.withAppearance(confirmedAppearance).toJson()
                  : row;
            }).toList();
          }
          return reply({
            'id': 73,
            'user_id': returnedOwner,
            'appearance': confirmedAppearance,
          });
        }
        if (table == 'flow_posts' ||
            table == 'get_profile_feed_together_cards') {
          if (request.method != 'GET' && table == 'flow_posts') {
            throw StateError('The app must not write a second post update');
          }
          final snapshot = jsonDecode(jsonEncode(rows)) as List;
          final hold = holdRead;
          if (hold != null) {
            readStarted ??= Completer<void>();
            if (!readStarted!.isCompleted) readStarted!.complete();
            await hold.future;
          }
          if (failRead) return reply({'message': 'unavailable'}, status: 503);
          if (table == 'get_profile_feed_together_cards') {
            return reply(
              snapshot.map((row) => {'post_type': 'flow', ...row}).toList(),
            );
          }
          final id = request.url.queryParameters['id'];
          final flowId = request.url.queryParameters['flow_id'];
          var selected = snapshot.where(
            (row) =>
                (id == null || row['id'] == id.substring(3)) &&
                (flowId == null ||
                    row['flow_id'].toString() == flowId.substring(3)),
          );
          if (request.url.queryParameters['select']?.contains('appearance:') ==
              true) {
            return reply(
              selected
                  .map(
                    (row) => {
                      ...row,
                      'appearance': row['ai_metadata']['payload']['appearance'],
                    },
                  )
                  .toList(),
            );
          }
          if (request.headers['accept']?.contains('object') == true) {
            return reply(selected.firstOrNull);
          }
          return reply(selected.toList());
        }
        return reply([]);
      }),
    );
    repo = ProfileRepo(client);
    returnedOwner = owner;
    confirmedAppearance = image('server-b');
  }

  final String owner;
  late final SupabaseClient client;
  late final ProfileRepo repo;
  late List<Map<String, dynamic>> rows;
  late String returnedOwner;
  Object? confirmedAppearance;
  Completer<void>? holdWrite, holdRead, readStarted;
  final writeStarted = Completer<void>();
  final requests = <http.Request>[];
  bool failWrite = false, failRead = false;
  String get cacheKey => 'profile:flow_posts:v1:$owner';
  Map<String, dynamic> image(String name) => {
    'version': 1,
    'image_object_path': '$owner/$name.jpg',
    'future_normalization': 'retained',
  };
  Map<String, dynamic> post(String id, int flowId) => {
    'id': id,
    'user_id': owner,
    'flow_id': flowId,
    'name': 'Flow $id',
    'rules': [
      {'unknown_rule': 'keep'},
    ],
    'color': 0x917742,
    'notes': 'raw notes',
    'created_at': '2026-10-05T00:00:00Z',
    'payload': {
      'appearance': image('a'),
      'direct_extension': {'keep': true},
      'events': [
        {'id': 'same-event', 'client_event_id': 'same-cid', 'time': '07:00'},
      ],
    },
    'ai_metadata': {
      'shared_note': 'Keep my caption',
      'metadata_extension': [1, 2],
      'payload': {
        'appearance': image('a'),
        'nested_extension': {'keep': true},
        'events': [
          {'id': 'same-event', 'client_event_id': 'same-cid', 'time': '07:00'},
        ],
      },
    },
  };
  Future<int> save() => UserEventsRepo(client).upsertFlow(
    id: 73,
    name: 'Flow linked',
    color: 0x917742,
    active: true,
    rules: '[]',
    appearance: FlowAppearance(imageObjectPath: '$owner/intent.jpg'),
  );
  Future<List<FlowPost>> persisted() async {
    final prefs = await SharedPreferences.getInstance();
    return (jsonDecode(prefs.getString(cacheKey)!) as List)
        .map((row) => FlowPost.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }
}

Object? appearance(FlowPost post) => post.payloadJson?['appearance'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var serial = 0;
  Future<_Fixture> fixture() async {
    final f = _Fixture('appearance-owner-${serial++}');
    SharedPreferences.setMockInitialValues({f.cacheKey: jsonEncode(f.rows)});
    await f.client.auth.recoverSession(session(f.owner));
    AccountViewCache.instance.enterAccount(f.owner);
    addTearDown(f.client.dispose);
    return f;
  }

  test(
    'appearance replacement retains unknown payload fields and engagement readiness',
    () async {
      final f = await fixture();
      final original = FlowPost.fromJson(f.rows.first);
      final changed = original.withAppearance(f.confirmedAppearance);
      expect(changed.hasLikesCount, original.hasLikesCount);
      expect(changed.hasCommentsCount, original.hasCommentsCount);
      expect(changed.hasLikedByMe, original.hasLikedByMe);
      expect(changed.likedByMe, original.likedByMe);
      expect(changed.payloadJson!['direct_extension'], {'keep': true});
      expect(changed.aiMetadata!['payload']['nested_extension'], {
        'keep': true,
      });
    },
  );

  for (final warm in [false, true]) {
    for (final remove in [false, true]) {
      test(
        '${warm ? 'warm' : 'cold'} acknowledged ${remove ? 'removal' : 'photo'} corrects existing post caches only',
        () async {
          final f = await fixture();
          if (warm) await f.repo.restoreCachedFlowPosts(f.owner);
          if (remove) f.confirmedAppearance = null;
          final original = f.rows.map((row) => FlowPost.fromJson(row)).toList();
          f.holdWrite = Completer<void>();
          final saving = f.save();
          await f.writeStarted.future;
          expect(appearance((await f.persisted()).first), f.image('a'));
          f.holdWrite!.complete();
          expect(await saving, 73);
          final posts = f.repo.getCachedFlowPostsSync(f.owner)!;
          final disk = await f.persisted();
          expect(appearance(posts.first), f.confirmedAppearance);
          expect(appearance(disk.first), f.confirmedAppearance);
          expect(
            disk.first.aiMetadata!['payload']['appearance'],
            f.confirmedAppearance,
          );
          expect(
            posts.first.payloadJson!['events'],
            original.first.payloadJson!['events'],
          );
          expect(posts.first.payloadJson!['direct_extension'], {'keep': true});
          expect(posts.first.aiMetadata!['payload']['nested_extension'], {
            'keep': true,
          });
          expect(posts.first.aiMetadata!['metadata_extension'], [1, 2]);
          expect(posts.first.sharedNote, 'Keep my caption');
          expect(posts.first.rules, original.first.rules);
          expect(posts.last.toJson(), original.last.toJson());
          expect(
            AccountViewCache.instance
                .peek<List<FlowPost>>(f.owner, 'social.posts')!
                .first
                .payloadJson!['appearance'],
            f.confirmedAppearance,
          );
          expect(
            f.requests.where(
              (r) => r.url.path.endsWith('/flow_posts') && r.method != 'GET',
            ),
            isEmpty,
          );
          expect(
            f.requests
                .where((r) => r.url.path.endsWith('/flows'))
                .single
                .url
                .queryParameters['select'],
            'id,user_id,appearance',
          );
        },
      );
    }
  }

  test(
    'failed writes retain the original appearance and allow retry',
    () async {
      final f = await fixture();
      await f.repo.restoreCachedFlowPosts(f.owner);
      f.failWrite = true;
      await expectLater(f.save(), throwsA(isA<PostgrestException>()));
      expect(
        appearance(f.repo.getCachedFlowPostsSync(f.owner)!.first),
        f.image('a'),
      );
      expect(appearance((await f.persisted()).first), f.image('a'));
      f.failWrite = false;
      expect(await f.save(), 73);
      expect(appearance((await f.persisted()).first), f.confirmedAppearance);
    },
  );

  test(
    'shared-calendar write retains prior RLS boundary without projecting another author',
    () async {
      final f = await fixture();
      f.returnedOwner = 'another-author';
      await f.repo.restoreCachedFlowPosts(f.owner);
      expect(await f.save(), 73);
      final write = f.requests.singleWhere(
        (r) => r.url.path.endsWith('/flows'),
      );
      expect(write.url.queryParameters.containsKey('user_id'), isFalse);
      expect(appearance((await f.persisted()).first), f.image('a'));
    },
  );

  test(
    'an older profile read returns the acknowledged cache instead of restoring old photo',
    () async {
      final f = await fixture();
      await f.repo.restoreCachedFlowPosts(f.owner);
      f.holdRead = Completer<void>();
      final oldRead = f.repo.getFlowPosts(f.owner);
      while (f.readStarted == null) {
        await Future<void>.delayed(Duration.zero);
      }
      await f.readStarted!.future;
      await f.save();
      f.holdRead!.complete();
      expect(appearance((await oldRead).first), f.confirmedAppearance);
      expect(appearance((await f.persisted()).first), f.confirmedAppearance);
    },
  );

  test(
    'acknowledgement invalidates warm feed detail and activity snapshots',
    () async {
      final f = await fixture();
      final pages = PagesReadRepository(f.client, mayFetch: () => true);
      await f.repo.getProfileFeedResult();
      await f.repo.getFlowPostById('linked');
      await pages.activityPost(postId: 'linked');
      await f.save();
      for (final key in [
        'social.feed.24.0',
        'social.post.linked',
        'pages.activityPost.linked.null',
      ]) {
        expect(
          WarmSnapshotStore.instance.peek(f.owner, key),
          isNull,
          reason: key,
        );
      }
      expect(
        appearance((await f.repo.getProfileFeedResult()).data.first.flowPost!),
        f.confirmedAppearance,
      );
      expect(
        appearance((await f.repo.getFlowPostById('linked'))!),
        f.confirmedAppearance,
      );
      expect(
        appearance((await pages.activityPost(postId: 'linked')).single),
        f.confirmedAppearance,
      );
      expect(
        appearance(
          (await f.repo.getProfileFeedResult(
            cachedOnly: true,
          )).data.first.flowPost!,
        ),
        f.confirmedAppearance,
      );
    },
  );

  for (final kind in ['feed', 'detail', 'activity']) {
    test(
      'old $kind in-flight read cannot republish after acknowledgement',
      () async {
        final f = await fixture();
        final pages = PagesReadRepository(f.client, mayFetch: () => true);
        Future<Object?> read() => switch (kind) {
          'feed' => f.repo.getProfileFeedResult(),
          'detail' => f.repo.getFlowPostById('linked', strict: true),
          _ => pages.activityPost(postId: 'linked'),
        };
        f.holdRead = Completer<void>();
        final oldRead = read().then<Object?>(
          (value) => value,
          onError: (Object _) => null,
        );
        while (f.readStarted == null) {
          await Future<void>.delayed(Duration.zero);
        }
        await f.save();
        final held = f.holdRead!;
        f.holdRead = null;
        final fresh = await read();
        held.complete();
        final old = await oldRead;
        if (kind == 'feed') {
          expect((old as ProfileFeedResult).hasError, isTrue);
          expect(
            appearance((fresh as ProfileFeedResult).data.first.flowPost!),
            f.confirmedAppearance,
          );
        } else if (kind == 'detail') {
          expect(old, isNull);
          expect(appearance(fresh as FlowPost), f.confirmedAppearance);
        } else {
          expect(old, isNull);
          expect(
            appearance((fresh as List<FlowPost>).single),
            f.confirmedAppearance,
          );
        }
      },
    );
  }

  for (final returnToOriginal in [false, true]) {
    test(
      'late acknowledgement after account departure${returnToOriginal ? ' and return' : ''} cannot publish',
      () async {
        final f = await fixture();
        await f.repo.restoreCachedFlowPosts(f.owner);
        f.holdWrite = Completer<void>();
        final saving = f.save();
        final rejected = expectLater(saving, throwsA(isA<WarmReadCancelled>()));
        await f.writeStarted.future;
        await f.client.auth.recoverSession(session('other-account'));
        AccountViewCache.instance.enterAccount('other-account');
        if (returnToOriginal) {
          await f.client.auth.recoverSession(session(f.owner));
          AccountViewCache.instance.enterAccount(f.owner);
        }
        f.holdWrite!.complete();
        await rejected;
        expect(appearance((await f.persisted()).first), f.image('a'));
        expect(
          AccountViewCache.instance.peek<List<FlowPost>>(
            f.client.auth.currentUser!.id,
            'social.posts',
          ),
          isNull,
        );
      },
    );
  }

  for (final kind in ['feed', 'detail', 'activity']) {
    test(
      '$kind read fences A to B to A without relying on app lifecycle',
      () async {
        final f = await fixture();
        f.holdRead = Completer<void>();
        final read = switch (kind) {
          'feed' => f.repo.getProfileFeedResult().then<Object?>(
            (r) => r.hasError ? null : r,
          ),
          'detail' => f.repo.getFlowPostById('linked', strict: true),
          _ => PagesReadRepository(
            f.client,
            mayFetch: () => true,
          ).activityPost(postId: 'linked'),
        };
        final caught = read.then<Object?>(
          (r) => r,
          onError: (Object _) => null,
        );
        while (f.readStarted == null) {
          await Future<void>.delayed(Duration.zero);
        }
        await f.client.auth.recoverSession(session('other-account'));
        await f.client.auth.recoverSession(session(f.owner));
        f.holdRead!.complete();
        expect(await caught, isNull);
      },
    );
  }
}
