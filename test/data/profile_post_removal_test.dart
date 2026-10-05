import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/account_view_cache.dart';
import 'package:mobile/data/account_operation_fence.dart';
import 'package:mobile/data/profile_repo.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Exercise the installed preferences adapter's actual write ordering.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _DelayedPreferences extends InMemorySharedPreferencesStore {
  _DelayedPreferences() : super.empty();
  final firstStarted = Completer<void>();
  final releaseFirst = Completer<void>();
  int writes = 0;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key.contains('profile:flow_posts:v1:')) {
      writes++;
      if (writes == 1) {
        firstStarted.complete();
        await releaseFirst.future;
      }
    }
    return super.setValue(type, key, value);
  }
}

class _Fixture {
  _Fixture(this.owner) {
    rows = [post('remove'), post('keep')];
    client = SupabaseClient(
      'https://example.supabase.co',
      'fixture-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        http.Response reply(Object? data, {int status = 200}) => http.Response(
          jsonEncode(data),
          status,
          headers: {'content-type': 'application/json'},
          request: request,
        );
        final path = request.url.path.split('/').last;
        if (path == 'token') {
          return reply(jsonDecode(session(client.auth.currentUser!.id)));
        }
        if (path == 'flow_posts') {
          if (request.method == 'PATCH') {
            final id = request.url.queryParameters['id']!.substring(3);
            writes.add((id, request.url.queryParameters['user_id']));
            if (!deleteStarted.isCompleted) deleteStarted.complete();
            await holdDelete?.future;
            if (failDelete) {
              return reply({'message': 'write unavailable'}, status: 503);
            }
            if (emptyDelete) return reply(null);
            for (final row in rows.where((r) => r['id'] == id)) {
              row['is_hidden'] = true;
            }
            return reply({'id': id});
          }
          if (!readStarted.isCompleted) readStarted.complete();
          final snapshot = jsonDecode(jsonEncode(rows));
          await holdRead?.future;
          if (failRead) {
            return reply({'message': 'read unavailable'}, status: 503);
          }
          final id = request.url.queryParameters['id'];
          if (id != null) {
            return reply(
              (snapshot as List).firstWhere((r) => r['id'] == id.substring(3)),
            );
          }
          return reply(snapshot);
        }
        return reply([]);
      }),
    );
    repo = ProfileRepo(client);
  }
  final String owner;
  late List<Map<String, dynamic>> rows;
  late SupabaseClient client;
  late ProfileRepo repo;
  final writes = <(String, String?)>[];
  final deleteStarted = Completer<void>();
  final readStarted = Completer<void>();
  Completer<void>? holdDelete, holdRead;
  bool failDelete = false, emptyDelete = false, failRead = false;
  String get cacheKey => 'profile:flow_posts:v1:$owner';
  Map<String, dynamic> post(String id, {bool hidden = false}) => {
    'id': id,
    'user_id': owner,
    'name': 'Flow $id',
    'rules': [],
    'color': 0xFF917742,
    'created_at': '2026-10-05T00:00:00Z',
    'is_hidden': hidden,
  };
  Future<List<String>> persistedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (jsonDecode(prefs.getString(cacheKey)!) as List)
        .map((r) => r['id'] as String)
        .toList();
  }
}

String session(String id) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final expires = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  return jsonEncode({
    'access_token':
        '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': id, 'exp': expires})}.sig',
    'refresh_token': 'fixture-refresh',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': id,
      'app_metadata': {},
      'user_metadata': {},
      'aud': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var serial = 0;
  Future<_Fixture> fixture() async {
    final f = _Fixture('profile-removal-${serial++}');
    SharedPreferences.setMockInitialValues({f.cacheKey: jsonEncode(f.rows)});
    await f.client.auth.recoverSession(session(f.owner));
    AccountViewCache.instance.enterAccount(f.owner);
    addTearDown(f.client.dispose);
    return f;
  }

  test(
    'hidden posts stay out of deployed list and detail caches and owner reads',
    () async {
      final f = await fixture();
      f.rows.add(f.post('hidden', hidden: true));
      SharedPreferences.setMockInitialValues({f.cacheKey: jsonEncode(f.rows)});
      expect((await f.repo.restoreCachedFlowPosts(f.owner))!.map((p) => p.id), [
        'remove',
        'keep',
      ]);
      expect((await f.repo.getFlowPosts(f.owner)).map((p) => p.id), [
        'remove',
        'keep',
      ]);
      await WarmSnapshotStore.instance.refresh(
        f.owner,
        'social.post.hidden',
        () async => f.rows.last,
        isCurrent: () => true,
      );
      expect(f.repo.cachedFlowPostById('hidden'), isNull);
      expect(await f.repo.getFlowPostById('hidden', cachedOnly: true), isNull);
      expect(await f.repo.getFlowPostById('hidden', strict: true), isNull);
    },
  );

  test(
    'removal waits for ACK then survives disk restore and failed refresh',
    () async {
      final f = await fixture();
      f.holdDelete = Completer<void>();
      final removal = f.repo.deleteFlowPost('remove');
      await f.deleteStarted.future;
      expect(f.repo.getCachedFlowPostsSync(f.owner)!.map((p) => p.id), [
        'remove',
        'keep',
      ]);
      expect(await f.persistedIds(), ['remove', 'keep']);
      f.holdDelete!.complete();
      expect(await removal, isTrue);
      expect(f.writes, [('remove', 'eq.${f.owner}')]);
      expect(await f.persistedIds(), ['keep']);
      f.failRead = true;
      expect(
        (await ProfileRepo(f.client).getFlowPosts(f.owner)).map((p) => p.id),
        ['keep'],
      );
      expect((await f.repo.restoreCachedFlowPosts(f.owner))!.map((p) => p.id), [
        'keep',
      ]);
    },
  );

  test('failed and zero-row removals retain content and allow retry', () async {
    final f = await fixture();
    f.failDelete = true;
    expect(await f.repo.deleteFlowPost('remove'), isFalse);
    expect(await f.persistedIds(), ['remove', 'keep']);
    f.failDelete = false;
    f.emptyDelete = true;
    expect(await f.repo.deleteFlowPost('remove'), isFalse);
    expect(f.repo.getCachedFlowPostsSync(f.owner)!.map((p) => p.id), [
      'remove',
      'keep',
    ]);
    f.emptyDelete = false;
    expect(await f.repo.deleteFlowPost('remove'), isTrue);
    expect(await f.persistedIds(), ['keep']);
  });

  test('a read started before ACK cannot republish the removed post', () async {
    final f = await fixture();
    await f.repo.restoreCachedFlowPosts(f.owner);
    f.holdRead = Completer<void>();
    final oldRead = f.repo.getFlowPosts(f.owner);
    await f.readStarted.future;
    expect(await ProfileRepo(f.client).deleteFlowPost('remove'), isTrue);
    f.holdRead!.complete();
    expect((await oldRead).map((p) => p.id), ['keep']);
    expect(await f.persistedIds(), ['keep']);
  });

  test(
    'ACK after account departure prunes only the initiating account cache',
    () async {
      final f = await fixture();
      f.holdDelete = Completer<void>();
      final removal = f.repo.deleteFlowPost('remove');
      await f.deleteStarted.future;
      await f.client.auth.recoverSession(session('other-account'));
      AccountViewCache.instance.enterAccount('other-account');
      AccountViewCache.instance.publish(
        'other-account',
        'social.posts',
        <String>['other-post'],
      );
      f.holdDelete!.complete();
      expect(await removal, isFalse);
      expect(await f.persistedIds(), ['keep']);
      expect(
        AccountViewCache.instance.peek<List<String>>(
          'other-account',
          'social.posts',
        ),
        ['other-post'],
      );
      await f.client.auth.recoverSession(session(f.owner));
      f.failRead = true;
      expect((await f.repo.getFlowPosts(f.owner)).map((p) => p.id), ['keep']);
    },
  );

  test(
    'same-account token refresh preserves a read and removal acknowledgement',
    () async {
      final f = await fixture();
      f.holdRead = Completer<void>();
      final reading = f.repo.getFlowPosts(f.owner);
      await f.readStarted.future;
      final before = f.client.auth.currentSession;
      await f.client.auth.refreshSession();
      expect(identical(before, f.client.auth.currentSession), isFalse);
      f.holdRead!.complete();
      expect((await reading).map((p) => p.id), ['remove', 'keep']);
      f.holdDelete = Completer<void>();
      final removal = f.repo.deleteFlowPost('remove');
      await f.deleteStarted.future;
      await f.client.auth.refreshSession();
      f.holdDelete!.complete();
      expect(await removal, isTrue);
      expect(await f.persistedIds(), ['keep']);
    },
  );

  test(
    'passive account fence retains identity on auth errors and fences signout',
    () async {
      final f = await fixture();
      final fence = AccountOperationFence(f.client);
      addTearDown(fence.dispose);
      // Exercise the pinned GoTrue stream error channel without network retries.
      // ignore: invalid_use_of_internal_member
      f.client.auth.notifyException(
        AuthRetryableFetchException(message: 'offline'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(fence.isCurrent, isTrue);
      await f.client.auth.signOut(scope: SignOutScope.local);
      await Future<void>.delayed(Duration.zero);
      expect(fence.isCurrent, isFalse);
    },
  );

  test('a round-trip account change fences a previous-session read', () async {
    final f = await fixture();
    await f.repo.restoreCachedFlowPosts(f.owner);
    f.holdRead = Completer<void>();
    f.rows = [f.post('stale-session')];
    final oldRead = f.repo.getFlowPosts(f.owner);
    await f.readStarted.future;
    await f.client.auth.recoverSession(session('other-account'));
    await f.client.auth.recoverSession(session(f.owner));
    f.holdRead!.complete();
    expect((await oldRead).map((p) => p.id), ['remove', 'keep']);
    expect(f.repo.getCachedFlowPostsSync(f.owner)!.map((p) => p.id), [
      'remove',
      'keep',
    ]);
    expect(await f.persistedIds(), ['remove', 'keep']);
  });

  test(
    'slow earlier cache write cannot complete after acknowledged removal',
    () async {
      final f = await fixture();
      final platform = _DelayedPreferences();
      final original = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = platform;
      addTearDown(() => SharedPreferencesStorePlatform.instance = original);
      await f.repo.getFlowPosts(f.owner);
      await platform.firstStarted.future;
      final removal = f.repo.deleteFlowPost('remove');
      await f.deleteStarted.future;
      await Future<void>.delayed(Duration.zero);
      expect(platform.writes, 1);
      platform.releaseFirst.complete();
      expect(await removal, isTrue);
      final disk = await platform.getAll();
      expect(
        (jsonDecode(disk['flutter.${f.cacheKey}']! as String) as List).map(
          (r) => r['id'],
        ),
        ['keep'],
      );
      expect(platform.writes, 2);
    },
  );
}
