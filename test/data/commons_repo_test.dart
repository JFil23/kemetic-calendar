import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/data/commons_repo.dart';
import 'package:mobile/data/commons_models.dart';
import 'package:mobile/data/profile_repo.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import '../features/pages/pages_resource_test.dart' show session, uid;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final date = DateTime(2026, 10, 6);
  const q = 'daily-reflection:2026:test';
  Map<String, Object?> answer(int n) => {
    'id': '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}',
    'question_id': q,
    'user_id': uid,
    'body_text': 'Public answer $n',
    'created_at': '2026-10-06T12:00:00.123456Z',
  };
  late SupabaseClient client;
  late CommonsRepo repo;
  final requests = <http.Request>[];
  late Future<http.Response> Function(http.Request) handler;
  http.Response json(Object? value) => http.Response(
    jsonEncode(value),
    200,
    headers: {'content-type': 'application/json'},
  );
  Future<CommonsHomeSnapshot> home({bool cached = false}) =>
      repo.getCommonsHome(
        localDate: date,
        questionId: q,
        questionText: 'What is visible?',
        cachedOnly: cached,
      );
  Future<CommonsAnswerPage> page({bool cached = false}) =>
      repo.getQuestionAnswers(
        questionId: q,
        before: CommonsAnswer.fromJson(answer(12)),
        cachedOnly: cached,
      );
  setUp(() async {
    await WarmSnapshotStore.instance.forgetAccount(uid);
    SharedPreferences.setMockInitialValues({});
    requests.clear();
    handler = (r) async {
      if (r.url.path.endsWith('get_shared_practice_quote_posts')) {
        return json([]);
      }
      if (r.url.path.endsWith('get_commons_question_answers')) {
        return json({
          'answers': [answer(11), answer(10)],
          'has_more': false,
        });
      }
      return json({
        'rhythm': {
          'scope': 'following',
          'active_users_today': 2,
          'flows_kept_today': 7,
          'public_fragments_today': 3,
          'public_rooms_open': 1,
        },
        'questions': [
          {
            'id': q,
            'question': 'What is visible?',
            'answers': [answer(12)],
            'answers_has_more': true,
          },
        ],
      });
    };
    client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        requests.add(r);
        final response = await handler(r);
        return http.Response(
          response.body,
          response.statusCode,
          headers: response.headers,
          request: r,
        );
      }),
    );
    await client.auth.recoverSession(session());
    repo = CommonsRepo(client);
  });
  tearDown(() async {
    await client.dispose();
    await WarmSnapshotStore.instance.forgetAccount(uid);
  });

  test(
    'cold and warm home preserve separate followed metrics and all paged answers',
    () async {
      final first = await home();
      expect(first.rhythm.activeUsersTodayLabel, '2');
      expect(first.rhythm.flowsKeptTodayLabel, '7');
      expect(first.rhythm.isFollowingOnly, isTrue);
      expect(first.questions.single.hasMoreAnswers, isTrue);
      final next = await page();
      final merged = first.questions.single.appendAnswers(next);
      expect(merged.answers.map((a) => a.bodyText), [
        'Public answer 12',
        'Public answer 11',
        'Public answer 10',
      ]);
      expect(merged.hasMoreAnswers, isFalse);
      final params = jsonDecode(requests.last.body) as Map;
      expect(params['p_before_created_at'], '2026-10-06T12:00:00.123456Z');
      expect(params['p_before_id'], answer(12)['id']);
      final count = requests.length;
      expect((await home(cached: true)).rhythm.flowsKeptTodayLabel, '7');
      expect((await page(cached: true)).answers.length, 2);
      expect(requests.length, count);
    },
  );

  test(
    'failed and malformed refresh retain the last confirmed answer page',
    () async {
      await page();
      handler = (_) async => throw const FormatException('offline');
      await expectLater(page(), throwsFormatException);
      expect((await page(cached: true)).answers.length, 2);
      handler = (_) async => json({
        'answers': [
          {'id': 'broken'},
        ],
        'has_more': true,
      });
      await expectLater(page(), throwsFormatException);
      expect((await page(cached: true)).answers.length, 2);
    },
  );

  test(
    'home failure cannot fall back to global counts or a fake empty success',
    () async {
      handler = (_) async => throw const FormatException('offline');
      await expectLater(home(), throwsFormatException);
      expect(
        requests.any(
          (r) => r.url.path.endsWith('get_community_rhythm_rollups'),
        ),
        isFalse,
      );
    },
  );

  test(
    'public save and delete invalidate both home and later answer pages',
    () async {
      await home();
      await page();
      handler = (r) async => r.url.path.endsWith('answer_commons_question')
          ? json(answer(13))
          : json(null);
      expect(
        (await repo.answerQuestion(
          questionId: q,
          questionText: 'What is visible?',
          body: 'Public answer 13',
        )).bodyText,
        'Public answer 13',
      );
      await expectLater(home(cached: true), throwsA(isA<WarmCacheMiss>()));
      await expectLater(page(cached: true), throwsA(isA<WarmCacheMiss>()));
      final request = requests.last;
      expect(jsonDecode(request.body)['p_body'], 'Public answer 13');
      await repo.deleteAnswer(answer(13)['id']! as String);
      expect(requests.last.url.path, endsWith('delete_commons_answer'));
    },
  );

  test(
    'unfollow invalidates followed statistics and public-answer working sets',
    () async {
      await home();
      await page();
      handler = (_) async => json(null);
      expect(await ProfileRepo(client).unfollowUser('other'), isTrue);
      await expectLater(home(cached: true), throwsA(isA<WarmCacheMiss>()));
      await expectLater(page(cached: true), throwsA(isA<WarmCacheMiss>()));
    },
  );

  test('late answer page is fenced across account A to B to A', () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    handler = (_) {
      started.complete();
      return pending.future;
    };
    final result = page();
    final assertion = expectLater(result, throwsA(isA<WarmReadCancelled>()));
    await started.future;
    await client.auth.recoverSession(
      session().replaceAll(uid, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
    );
    await client.auth.recoverSession(session());
    await Future<void>.delayed(Duration.zero);
    pending.complete(
      json({
        'answers': [answer(11)],
        'has_more': false,
      }),
    );
    await assertion;
    await expectLater(page(cached: true), throwsA(isA<WarmCacheMiss>()));
  });

  test('access denial invalidates cached answer content', () async {
    await page();
    handler = (_) async => http.Response(
      jsonEncode({'code': '42501', 'message': 'denied'}),
      403,
      headers: {'content-type': 'application/json'},
    );
    await expectLater(page(), throwsA(isA<WarmAccessDenied>()));
    await expectLater(page(cached: true), throwsA(isA<WarmCacheMiss>()));
  });
}
