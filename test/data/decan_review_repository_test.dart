import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/data/decan_reflection_repo.dart';
import 'package:mobile/data/journal_repo.dart';
import 'package:mobile/data/profile_repo.dart';
import 'package:mobile/features/journal/journal_controller.dart';
import 'package:mobile/features/journal/journal_v2_document_model.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:mobile/features/reflections/decan_review_context.dart';
import 'package:mobile/features/reflections/decan_review_controller.dart';
import 'package:mobile/features/nodes/kemetic_node_library.dart';
import '../features/pages/pages_resource_test.dart' show session, uid;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late Future<http.Response> Function(http.Request) handler;
  final requests = <http.Request>[];
  final date = DateTime(2026, 9, 21);
  final end = DateTime(2026, 9, 30);
  http.Response json(Object? value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );
  Map<String, dynamic> body(http.Request r) =>
      Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  Map<String, dynamic> entry(String words, int revision) => {
    'id': 'journal-one',
    'user_id': uid,
    'greg_date': '2026-10-07',
    'body': words,
    'meta': {},
    'created_at': '2026-10-07T12:00:00Z',
    'updated_at': '2026-10-07T12:00:00Z',
    'revision': revision,
  };
  final review = {
    'id': 'review-one',
    'decan_name': 'First decan',
    'decan_start': '2026-09-21',
    'decan_end': '2026-09-30',
    'created_at': '2026-10-07T12:00:00Z',
    'review_revision': 1,
    'review_context': const DecanReviewContext(
      questionId: 'carry',
      question: 'What would you like to carry forward?',
      moments: [],
    ).toJson(),
  };
  setUp(() async {
    await WarmSnapshotStore.instance.forgetAccount(uid);
    SharedPreferences.setMockInitialValues({});
    requests.clear();
    handler = (r) async {
      if (r.url.path.endsWith('read_decan_activity_v1'))
        return json({'items': [], 'next_cursor': null});
      if (r.url.path.endsWith('read_journal_state_v1'))
        return json({'row': null, 'revision': 0});
      if (r.url.path.endsWith('decan_reflections')) return json(review);
      if (r.url.path.endsWith('decan_journal_sources') ||
          r.url.path.endsWith('insight_posts'))
        return json(null);
      return json([]);
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
  });
  tearDown(() async {
    await client.dispose();
    await WarmSnapshotStore.instance.forgetAccount(uid);
  });

  test(
    'a rejected removal requires a fresh deliberate request at the current revision',
    () async {
      var revision = 4;
      var hidden = false;
      final attempts = <Map<String, dynamic>>[];
      handler = (r) async {
        if (r.url.path.endsWith('insight_posts'))
          return json(
            hidden
                ? null
                : {
                    'id': 'conflicted-removal',
                    'user_id': uid,
                    'source_kind': 'decan',
                    'source_reflection_id': 'review-one',
                    'revision': revision,
                    'entry_date': '2026-10-07',
                  },
          );
        if (r.url.path.endsWith('apply_decan_post_v1')) {
          attempts.add(body(r));
          if (attempts.length == 1) {
            revision = 5;
            return json({'status': 'conflict', 'revision': revision});
          }
          expect(body(r)['p_expected_revision'], 5);
          hidden = true;
          return json({'status': 'applied'});
        }
        return json([]);
      };
      final repo = ProfileRepo(client);
      expect(await repo.deleteInsightPost('conflicted-removal'), isFalse);
      expect(hidden, isFalse);
      expect(attempts, hasLength(1), reason: 'No automatic destructive retry');
      expect(await repo.deleteInsightPost('conflicted-removal'), isTrue);
      expect(attempts[0]['p_mutation'], isNot(attempts[1]['p_mutation']));
    },
  );

  for (final appliedBeforeDisconnect in [false, true]) {
    test(
      'post removal retains its request across restart; server applied: $appliedBeforeDisconnect',
      () async {
        final postId = 'removal-$appliedBeforeDisconnect';
        final post = {
          'id': postId,
          'user_id': uid,
          'source_kind': 'decan',
          'source_reflection_id': 'review-one',
          'body_text': 'Public words',
          'revision': 4,
          'entry_date': '2026-10-07',
          'created_at': '2026-10-07T12:00:00Z',
          'updated_at': '2026-10-07T12:00:00Z',
        };
        var hidden = false;
        var attempts = 0;
        handler = (r) async {
          if (r.url.path.endsWith('insight_posts')) {
            expect(r.method, 'GET');
            return json(hidden ? null : post);
          }
          if (r.url.path.endsWith('apply_decan_post_v1')) {
            attempts++;
            expect(body(r)['p_expected_revision'], 4);
            expect(body(r)['p_remove'], isTrue);
            if (attempts == 1) {
              hidden = appliedBeforeDisconnect;
              return json({'message': 'connection lost'}, 503);
            }
            hidden = true;
            return json({'status': 'applied'});
          }
          return json([]);
        };
        expect(await ProfileRepo(client).deleteInsightPost(postId), isFalse);
        final prefs = await SharedPreferences.getInstance();
        final key = 'profile:decan_remove:$uid:$postId';
        final pending = prefs.getString(key);
        expect(pending, isNotNull);
        final intent = jsonDecode(pending!) as Map;
        expect(intent['p_post'], postId);
        expect(intent['p_account'], uid);
        expect(await ProfileRepo(client).deleteInsightPost(postId), isTrue);
        final removals = requests
            .where((r) => r.url.path.endsWith('apply_decan_post_v1'))
            .map(body)
            .toList();
        expect(removals, hasLength(appliedBeforeDisconnect ? 1 : 2));
        for (final request in removals) {
          expect(request, intent, reason: 'Retry must retain exact intent');
        }
        expect(prefs.getString(key), isNull);
        expect(
          ProfileRepo(client).getCachedInsightPostsSync(uid)?.map((p) => p.id),
          isNot(contains(postId)),
        );
      },
    );
  }

  test(
    'bounded activity restores warm without network and keeps pagination and factual labels',
    () async {
      handler = (r) async => json({
        'items': [
          {
            'id': 'c:1',
            'kind': 'flow',
            'source_id': 'e1',
            'occurred_on': '2026-09-22',
            'text': 'My own practice',
            'flow_id': 19,
            'flow_key': 'the-kar',
            'status': 'raised',
            'event_number': 3,
          },
        ],
        'next_cursor': 'next',
      });
      final repo = DecanReflectionRepo(client);
      final first = await repo.reviewActivity(
        start: date,
        end: end,
        source: 'flows',
      );
      expect(first.items.single.actionLabel, 'Raised');
      expect(first.items.single.eventNumber, 3);
      expect(first.items.single.dayIn(date), 2);
      expect(body(requests.single)['p_account'], uid);
      expect(body(requests.single)['p_end'], '2026-09-30');
      final warm = await repo.reviewActivity(
        start: date,
        end: end,
        source: 'flows',
        cachedOnly: true,
      );
      expect(warm.items.single.text, 'My own practice');
      expect(warm.nextCursor, 'next');
      expect(requests, hasLength(1));
      handler = (r) async => json({'message': 'offline'}, 503);
      await expectLater(
        repo.reviewActivity(start: date, end: end, source: 'flows'),
        throwsA(anything),
      );
      expect(
        (await repo.reviewActivity(
          start: date,
          end: end,
          source: 'flows',
          cachedOnly: true,
        )).items,
        hasLength(1),
      );
    },
  );

  test('A-B-A departure rejects late activity and does not warm it', () async {
    final started = Completer<void>(), release = Completer<void>();
    handler = (r) async {
      started.complete();
      await release.future;
      return json({'items': [], 'next_cursor': null});
    };
    final repo = DecanReflectionRepo(client);
    final pending = repo.reviewActivity(start: date, end: end, source: 'flows');
    final rejected = expectLater(pending, throwsA(anything));
    await started.future;
    await client.auth.recoverSession(
      session().replaceAll(uid, '11111111-1111-4111-8111-111111111111'),
    );
    await client.auth.recoverSession(session());
    release.complete();
    await rejected;
    await expectLater(
      repo.reviewActivity(
        start: date,
        end: end,
        source: 'flows',
        cachedOnly: true,
      ),
      throwsA(anything),
    );
  });

  test(
    'Journal retry after lost acknowledgement reuses durable identity across repository restart',
    () async {
      var attempts = 0;
      handler = (r) async {
        if (r.url.path.endsWith('read_journal_state_v1'))
          return json({'row': entry('my words', 1), 'revision': 1});
        attempts++;
        if (attempts == 1) return json({'message': 'connection lost'}, 503);
        return json({
          'status': 'applied',
          'revision': 1,
          'row': entry('my words', 1),
        });
      };
      await expectLater(
        JournalRepo(client).upsert(
          localDate: date,
          body: 'my words',
          meta: {'last_autosave': 'first attempt', 'chars': 8},
        ),
        throwsA(anything),
      );
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('journal:user:$uid:mutation:2026-09-21');
      expect(saved, isNotNull);
      await JournalRepo(client).upsert(
        localDate: date,
        body: 'my words',
        meta: {'last_autosave': 'retry attempt', 'chars': 8},
      );
      expect(body(requests[0]), body(requests[1]));
      expect(prefs.getString('journal:user:$uid:mutation:2026-09-21'), isNull);
    },
  );

  test(
    'Journal conflict retains request and does not adopt the remote base implicitly',
    () async {
      handler = (r) async => json({
        'status': 'conflict',
        'revision': 8,
        'row': entry('newer remote writing', 8),
      });
      final repo = JournalRepo(client);
      repo.restoreBaseRevision(date, 3);
      await expectLater(
        repo.upsert(localDate: date, body: 'my offline writing'),
        throwsA(isA<JournalRevisionConflict>()),
      );
      expect(repo.revisionForDate(date), 3);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('journal:user:$uid:mutation:2026-09-21'),
        contains('my offline writing'),
      );
    },
  );

  test(
    'a replayed acknowledgement cannot revive a deleted Journal or reflection contribution',
    () async {
      handler = (r) async => r.url.path.endsWith('read_journal_state_v1')
          ? json({'revision': 4, 'row': null})
          : json({
              'status': 'applied',
              'revision': 1,
              'row': entry('removed words', 1),
            });
      final repo = JournalRepo(client);
      await expectLater(
        repo.upsert(localDate: date, body: 'removed words'),
        throwsA(isA<JournalRevisionConflict>()),
      );
      expect(repo.revisionForDate(date), 0);
      expect(
        WarmSnapshotStore.instance.peek(uid, 'journal.entry.journal-one'),
        isNull,
      );
      await expectLater(
        DecanReflectionRepo(client).saveReviewAnswerRequest({
          'p_account': uid,
          'p_reflection': 'review-one',
          'p_date': '2026-10-07',
        }),
        throwsA(isA<DecanReviewConflict>()),
      );
      expect(
        WarmSnapshotStore.instance.peek(uid, 'journal.entry.journal-one'),
        isNull,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('journal:user:$uid:mutation:2026-09-21'),
        contains('removed words'),
      );
    },
  );

  test(
    'first review creation is versioned and retires interpretation generation',
    () async {
      Map<String, dynamic>? persisted;
      handler = (r) async {
        final path = r.url.path.split('/').last;
        if (path == 'decan_reflections') return json(persisted);
        if (path == 'apply_decan_review_v1') {
          final req = body(r);
          expect(req['p_expected_revision'], 0);
          persisted = {
            ...review,
            'id': req['p_id'],
            'review_context': req['p_context'],
            'review_revision': 1,
          };
          return json({'status': 'applied', 'row': persisted});
        }
        if (path == 'read_decan_activity_v1')
          return json({'items': [], 'next_cursor': null});
        if (path == 'read_journal_state_v1')
          return json({'row': null, 'revision': 0});
        return json(null);
      };
      final c = DecanReviewController(
        client: client,
        window: DecanReviewWindow(start: date, end: end, name: 'Closing decan'),
      );
      addTearDown(c.dispose);
      await c.initialize();
      expect(c.error, isNull);
      expect(c.review!.question, DecanReviewQuestions.catalog['unrecorded']);
      expect(c.selectedMoments, isEmpty);
      expect(c.reflection!.reviewRevision, 1);
      final writes = requests
          .where((r) => r.url.path.contains('/apply_'))
          .toList();
      expect(writes, hasLength(1));
      expect(writes.single.url.path, endsWith('apply_decan_review_v1'));
      expect((body(writes.single)['p_context'] as Map)['question_version'], 1);
    },
  );

  test(
    'newer keystrokes survive an earlier reflection acknowledgement',
    () async {
      final started = Completer<void>(), release = Completer<void>();
      final original = handler;
      Map<String, dynamic>? saved;
      handler = (r) async {
        if (r.url.path.endsWith('apply_decan_journal_v1')) {
          started.complete();
          await release.future;
          saved = entry(
            jsonEncode(
              JournalDocument.fromPlainText(
                body(r)['p_words'] as String,
              ).toJson(),
            ),
            1,
          );
          return json({'status': 'applied', 'row': saved, 'revision': 1});
        }
        if (r.url.path.endsWith('read_journal_state_v1') && saved != null)
          return json({'row': saved, 'revision': 1});
        return original(r);
      };
      final c = DecanReviewController(
        client: client,
        window: DecanReviewWindow(start: date, end: end, name: 'Closing decan'),
      );
      addTearDown(c.dispose);
      await c.initialize();
      c.changeAnswer('Earlier sentence');
      final pending = c.saveAnswer();
      await started.future;
      c.changeAnswer('The sentence I kept writing');
      release.complete();
      await pending;
      expect(c.savedAnswer, 'Earlier sentence');
      expect(c.answer, 'The sentence I kept writing');
      expect(c.stage, DecanReviewStage.writing);
      final prefs = await SharedPreferences.getInstance();
      final draft = jsonDecode(prefs.getString(c.draftKey)!) as Map;
      expect(draft['answer_dirty'], true);
      expect(draft['answer'], c.answer);
      expect(draft['journal_revision'], 1);
      final interaction = requests.singleWhere(
        (r) =>
            r.method == 'POST' &&
            r.url.path.endsWith('decan_reflection_prompt_interactions'),
      );
      expect(body(interaction)['interaction_kind'], 'interacted');
      expect(body(interaction)['decan_start'], '2026-09-21');
    },
  );

  test(
    'an empty-device Journal can discover and compare account-preserved conflicting writing',
    () async {
      final saved = entry(
        jsonEncode(JournalDocument.fromPlainText('Newer saved words').toJson()),
        8,
      );
      final recovered = jsonEncode(
        JournalDocument.fromPlainText('My interrupted words').toJson(),
      );
      handler = (r) async => r.url.path.endsWith('journal_mutation_receipts')
          ? json({
              'request': {'body': recovered},
            })
          : json({
              'row': saved,
              'revision': 8,
              'recovery': [
                {
                  'mutation_id': 'preserved',
                  'character_count': recovered.length,
                },
              ],
            });
      final repo = JournalRepo(client);
      final c = JournalController(client, repository: repo);
      addTearDown(c.dispose);
      await c.loadDate(DateTime(2026, 10, 7));
      expect(c.currentDraft, contains('Newer saved words'));
      expect(c.recoveryDrafts.single.characterCount, recovered.length);
      expect(
        requests.where((r) => r.url.path.endsWith('journal_mutation_receipts')),
        isEmpty,
      );
      await c.chooseRecoveredDraft(c.recoveryDrafts.single);
      expect(c.currentDraft, contains('My interrupted words'));
      final conflict = c.lastSyncError as JournalRevisionConflict;
      expect(conflict.revision, 8);
      expect(conflict.serverEntry!.body, contains('Newer saved words'));
      expect(requests.where((r) => r.url.path.contains('apply_')), isEmpty);
      expect(await c.resolveConflict(conflict, keepDraft: false), true);
      expect(c.currentDraft, contains('Newer saved words'));
      expect(
        (await SharedPreferences.getInstance()).getString(
          'journal:user:$uid:document:2026-10-07:before_resolution',
        ),
        contains('My interrupted words'),
      );
    },
  );

  test(
    'new review uses four bounded providers and never collects Journal or private margins automatically',
    () async {
      final c = DecanReviewController(
        client: client,
        window: DecanReviewWindow(start: date, end: end, name: 'First decan'),
      );
      addTearDown(c.dispose);
      await c.initialize();
      expect(c.error, isNull);
      expect(c.review?.question, contains('carry forward'));
      final sources = requests
          .where((r) => r.url.path.endsWith('read_decan_activity_v1'))
          .map((r) => body(r)['p_source'])
          .toSet();
      expect(sources, {'flows', 'library', 'responses', 'previous'});
      expect(requests.where((r) => r.url.path.contains('apply_')), isEmpty);
      c.changeAnswer('Keep this before the power goes out.');
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(c.draftKey),
        contains('Keep this before the power goes out.'),
      );
    },
  );

  test(
    'partial source failure stays explicit instead of becoming an empty successful decan',
    () async {
      final original = handler;
      handler = (r) async =>
          r.url.path.endsWith('read_decan_activity_v1') &&
              body(r)['p_source'] == 'flows'
          ? json({'message': 'offline'}, 503)
          : original(r);
      final c = DecanReviewController(
        client: client,
        window: DecanReviewWindow(start: date, end: end, name: 'First decan'),
      );
      addTearDown(c.dispose);
      await c.initialize();
      expect(c.failedSources, {'flows'});
      expect(c.notice, contains('could not load'));
      expect(c.hasMore, isTrue);
      handler = original;
      await c.moreMoments();
      expect(c.failedSources, isEmpty);
    },
  );

  test(
    'suggestions use available Library titles and respect selections, dismissals and membership',
    () {
      final moment = decanMomentFromActivity({
        'id': 'l',
        'kind': 'library',
        'source_id': 'maat',
        'library_id': 'maat',
        'action': 'read',
        'occurred_on': '2026-09-21T09:00:00Z',
      })!;
      final suggestions = DecanReviewSuggestions.build(moments: [moment]);
      expect(
        suggestions.where((s) => s.isReading).length,
        lessThanOrEqualTo(1),
      );
      expect(
        suggestions.where((s) => !s.isReading).length,
        lessThanOrEqualTo(1),
      );
      expect(
        suggestions
            .where((s) => s.isReading)
            .every((s) => KemeticNodeLibrary.resolve(s.libraryId!) != null),
        isTrue,
      );
      expect(suggestions.any((s) => s.libraryId == 'maat'), isFalse);
      expect(
        DecanReviewSuggestions.build(
          moments: [moment],
          excluded: suggestions.map((s) => s.id).toSet(),
          joinedFlowKeys: DecanReviewSuggestions.flowTitles.keys.toSet(),
        ).any((s) => suggestions.map((s) => s.id).contains(s.id)),
        isFalse,
      );
      for (final ids in DecanReviewSuggestions.flowReadings.values) {
        for (final id in ids) {
          expect(KemeticNodeLibrary.resolve(id), isNotNull, reason: id);
        }
      }
    },
  );
}
