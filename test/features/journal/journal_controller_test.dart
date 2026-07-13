import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/data/journal_repo.dart';
import 'package:mobile/features/calendar/calendar_completion.dart';
import 'package:mobile/features/journal/journal_badge_utils.dart';
import 'package:mobile/features/journal/journal_controller.dart';
import 'package:mobile/features/journal/journal_event_badge.dart';
import 'package:mobile/features/journal/journal_v2_document_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads server document over a clean local cache for today', () async {
    final today = _today();
    final key = _dateKey(today);
    SharedPreferences.setMockInitialValues({
      _documentKey(key): _documentJson('local stale text'),
      _lastOpenDayKey(): key,
    });

    final repo = _FakeJournalRepo(
      entry: _entry(
        date: today,
        body: _documentJson('server text'),
        updatedAt: DateTime.now().toUtc(),
      ),
    );

    final controller = JournalController.withRepo(repo);
    await controller.init();

    expect(controller.currentDraft, 'server text');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_documentDirtyKey(key)), isFalse);
    expect(prefs.getString(_documentKey(key)), contains('server text'));
  });

  test('keeps a newer dirty local document and force saves it', () async {
    final today = _today();
    final key = _dateKey(today);
    final localModifiedAt = DateTime.now().toUtc();
    SharedPreferences.setMockInitialValues({
      _documentKey(key): _documentJson('local unsaved text'),
      _documentDirtyKey(key): true,
      _documentModifiedKey(key): localModifiedAt.toIso8601String(),
      _lastOpenDayKey(): key,
    });

    final repo = _FakeJournalRepo(
      entry: _entry(
        date: today,
        body: _documentJson('older server text'),
        updatedAt: localModifiedAt.subtract(const Duration(minutes: 5)),
      ),
    );

    final controller = JournalController.withRepo(repo);
    await controller.init();
    final saved = await controller.forceSave();

    expect(controller.currentDraft, 'local unsaved text');
    expect(saved, isTrue);
    expect(controller.syncStatus, JournalSyncStatus.synced);
    expect(repo.upserts, hasLength(1));
    expect(repo.upserts.single.body, contains('local unsaved text'));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_documentDirtyKey(key)), isFalse);
  });

  test(
    'server document wins over legacy dirty cache without timestamp',
    () async {
      final today = _today();
      final key = _dateKey(today);
      SharedPreferences.setMockInitialValues({
        _documentKey(key): _documentJson('legacy local text'),
        _documentDirtyKey(key): true,
        _lastOpenDayKey(): key,
      });

      final repo = _FakeJournalRepo(
        entry: _entry(
          date: today,
          body: _documentJson('server text'),
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      final controller = JournalController.withRepo(repo);
      await controller.init();

      expect(controller.currentDraft, 'server text');
      expect(repo.upserts, isEmpty);
    },
  );

  test('authenticated cache ignores unscoped legacy document', () async {
    final today = _today();
    final key = _dateKey(today);
    SharedPreferences.setMockInitialValues({
      'document:$key': _documentJson('other account text'),
      'document_dirty:$key': true,
      'document_modified_at:$key': DateTime.now().toUtc().toIso8601String(),
      'lastOpenDay': key,
    });

    final controller = JournalController.withRepo(
      _FakeJournalRepo(),
      currentUserId: () => 'user-a',
    );
    await controller.init();

    expect(controller.currentDraft, '\n');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_documentKey(key, uid: 'user-a')), isNull);
  });

  test('authenticated users keep separate dirty local documents', () async {
    final today = _today();
    final key = _dateKey(today);
    final modifiedAt = DateTime.now().toUtc().toIso8601String();
    SharedPreferences.setMockInitialValues({
      _documentKey(key, uid: 'user-a'): _documentJson('user a text'),
      _documentDirtyKey(key, uid: 'user-a'): true,
      _documentModifiedKey(key, uid: 'user-a'): modifiedAt,
      _documentKey(key, uid: 'user-b'): _documentJson('user b text'),
      _documentDirtyKey(key, uid: 'user-b'): true,
      _documentModifiedKey(key, uid: 'user-b'): modifiedAt,
    });

    final userA = JournalController.withRepo(
      _FakeJournalRepo(),
      currentUserId: () => 'user-a',
    );
    final userB = JournalController.withRepo(
      _FakeJournalRepo(),
      currentUserId: () => 'user-b',
    );

    await userA.init();
    await userB.init();

    expect(userA.currentDraft, 'user a text');
    expect(userB.currentDraft, 'user b text');
  });

  test('reloadToday refreshes a stale clean controller from server', () async {
    final today = _today();
    final repo = _FakeJournalRepo(
      entry: _entry(
        date: today,
        body: _documentJson('old server text'),
        updatedAt: DateTime.now().toUtc(),
      ),
    );

    final controller = JournalController.withRepo(repo);
    await controller.init();

    repo.entry = _entry(
      date: today,
      body: _documentJson('new server badge text'),
      updatedAt: DateTime.now().toUtc().add(const Duration(minutes: 1)),
    );
    await controller.reloadToday();

    expect(controller.currentDraft, 'new server badge text');
  });

  test(
    'init is idempotent while the first journal load is in flight',
    () async {
      final repo = _DelayedJournalRepo();
      final controller = JournalController.withRepo(repo);

      final firstInit = controller.init();
      final secondInit = controller.init();

      await repo.requested.future;
      repo.completeWith(null);
      await Future.wait([firstInit, secondInit]);

      expect(controller.initRunCount, 1);
      expect(controller.reloadTodayRunCount, 1);
      expect(repo.getByDateStrictCalls, 1);
      expect(controller.currentDraft, '\n');
    },
  );

  test(
    'delayed empty-entry load preserves local edits made after focus',
    () async {
      final today = _today();
      final key = _dateKey(today);
      final repo = _DelayedJournalRepo();
      final controller = JournalController.withRepo(
        repo,
        currentUserId: () => 'user-a',
      );

      final initFuture = controller.init();
      await repo.requested.future;

      await controller.updateDraft('Typed before the empty response.');
      repo.completeWith(null);
      await initFuture;

      expect(controller.currentDraft, 'Typed before the empty response.');
      expect(controller.currentDocument?.toPlainText(), contains('Typed'));
      expect(controller.hasUnsavedChanges, isTrue);
      expect(controller.syncStatus, JournalSyncStatus.unsavedLocal);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(_documentKey(key, uid: 'user-a')),
        contains('Typed before the empty response.'),
      );
      expect(prefs.getBool(_documentDirtyKey(key, uid: 'user-a')), isTrue);

      await controller.forceSave();
    },
  );

  test(
    'delayed existing-entry load preserves local edits made after focus',
    () async {
      final today = _today();
      final repo = _DelayedJournalRepo();
      final controller = JournalController.withRepo(
        repo,
        currentUserId: () => 'user-a',
      );

      final initFuture = controller.init();
      await repo.requested.future;

      await controller.updateDraft('Local typed text wins.');
      repo.completeWith(
        _entry(
          date: today,
          body: _documentJson('server text should not replace focus'),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await initFuture;

      expect(controller.currentDraft, 'Local typed text wins.');
      expect(controller.hasUnsavedChanges, isTrue);
      expect(repo.upserts, isEmpty);

      await controller.forceSave();
    },
  );

  test(
    'existing entry load populates once and editing does not reload',
    () async {
      final today = _today();
      final repo = _FakeJournalRepo(
        entry: _entry(
          date: today,
          body: _documentJson('server text'),
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      final controller = JournalController.withRepo(
        repo,
        currentUserId: () => 'user-a',
      );
      await controller.init();

      expect(controller.currentDraft, 'server text');
      expect(repo.getByDateStrictCalls, 1);

      await controller.updateDraft('server text plus local edit');

      expect(controller.currentDraft, 'server text plus local edit');
      expect(repo.getByDateStrictCalls, 1);

      await controller.forceSave();
    },
  );

  test(
    'reloadToday keeps unsaved local document when cloud save fails',
    () async {
      final today = _today();
      final repo = _FakeJournalRepo(
        entry: _entry(
          date: today,
          body: _documentJson('server text'),
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      final controller = JournalController.withRepo(
        repo,
        currentUserId: () => 'user-a',
      );
      await controller.init();

      repo.upsertError = Exception('RLS denied');
      repo.entry = _entry(
        date: today,
        body: _documentJson('newer server text'),
        updatedAt: DateTime.now().toUtc().add(const Duration(minutes: 1)),
      );
      await controller.updateDraft('local unsaved text');
      final saved = await controller.forceSave();
      await controller.reloadToday();

      expect(saved, isFalse);
      expect(controller.currentDraft, 'local unsaved text');
      expect(controller.hasUnsavedChanges, isTrue);
      expect(controller.syncStatus, JournalSyncStatus.saveFailed);
    },
  );

  test(
    'signed-in user imports dirty local-scope document for cloud sync',
    () async {
      final today = _today();
      final key = _dateKey(today);
      SharedPreferences.setMockInitialValues({
        _documentKey(key): _documentJson('guest draft with badge'),
        _documentDirtyKey(key): true,
        _documentModifiedKey(key): DateTime.now().toUtc().toIso8601String(),
      });

      final repo = _FakeJournalRepo();
      final controller = JournalController.withRepo(
        repo,
        currentUserId: () => 'user-a',
      );
      await controller.init();

      expect(controller.currentDraft, 'guest draft with badge');
      expect(
        controller.syncStatus,
        isIn([
          JournalSyncStatus.unsavedLocal,
          JournalSyncStatus.saving,
          JournalSyncStatus.synced,
        ]),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_documentKey(key, uid: 'user-a')), isNotNull);
      expect(prefs.getString(_documentKey(key)), isNull);

      final saved = await controller.forceSave();

      expect(saved, isTrue);
      expect(repo.upserts, hasLength(1));
      expect(repo.upserts.single.body, contains('guest draft with badge'));
      expect(prefs.getBool(_documentDirtyKey(key, uid: 'user-a')), isFalse);
    },
  );

  test(
    'removing a completion badge reports the related completion source',
    () async {
      final today = _today();
      final completion = _completionBadge(
        id: 'calendar:user_flow:cid:event-1',
        clientEventId: 'event-1',
        status: CompletionStatus.observed,
      );
      final ordinary = _ordinaryBadge('badge-note');
      final controller = JournalController.withRepo(
        _FakeJournalRepo(
          entry: _entry(
            date: today,
            body: _documentJsonWithBadges('body', [ordinary, completion]),
            updatedAt: DateTime.now().toUtc(),
          ),
        ),
      );
      final removed = <EventBadgeToken>[];
      controller.onCompletionBadgesRemoved = (badges) async {
        removed.addAll(badges);
      };

      await controller.init();
      await controller.removeBadge('calendar:user_flow:cid:event-1');

      expect(removed.map((badge) => badge.id), <String>[
        'calendar:user_flow:cid:event-1',
      ]);
      expect(removed.single.completionClientEventId, 'event-1');
      expect(
        JournalBadgeUtils.tokensFromDocument(
          controller.currentDocument!,
        ).map((badge) => badge.id),
        <String>['badge-note'],
      );
    },
  );

  test(
    'appendToToday replaces repeated completion continuity badge by identity',
    () async {
      final controller = JournalController.withRepo(_FakeJournalRepo());
      await controller.init();

      final observed = buildCalendarCompletionBadgeToken(
        identity: 'cid:event-1',
        sourceType: CompletionSourceType.userFlow,
        completionStatus: CompletionStatus.observed,
        eventId: 'event-1',
        title: 'Practice',
        color: Colors.green,
      );
      final partial = buildCalendarCompletionBadgeToken(
        identity: 'cid:event-1',
        sourceType: CompletionSourceType.userFlow,
        completionStatus: CompletionStatus.partial,
        eventId: 'event-1',
        title: 'Practice',
        color: Colors.green,
      );

      await controller.appendToToday('$observed ');
      await controller.appendToToday('$partial ');

      final tokens = JournalBadgeUtils.tokensFromDocument(
        controller.currentDocument!,
      );
      expect(tokens, hasLength(1));
      expect(tokens.single.id, 'calendar:user_flow:cid:event-1');
      expect(tokens.single.completionStatus, CompletionStatus.partial);
    },
  );

  test(
    'clearToday reports all completion badges but not ordinary badges',
    () async {
      final today = _today();
      final controller = JournalController.withRepo(
        _FakeJournalRepo(
          entry: _entry(
            date: today,
            body: _documentJsonWithBadges('body', [
              _ordinaryBadge('badge-note'),
              _completionBadge(
                id: 'calendar:user_flow:cid:event-1',
                clientEventId: 'event-1',
                status: CompletionStatus.observed,
              ),
              _completionBadge(
                id: 'calendar:maat_flow:cid:event-2',
                clientEventId: 'event-2',
                status: CompletionStatus.skipped,
              ),
            ]),
            updatedAt: DateTime.now().toUtc(),
          ),
        ),
      );
      final removed = <EventBadgeToken>[];
      controller.onCompletionBadgesRemoved = (badges) async {
        removed.addAll(badges);
      };

      await controller.init();
      await controller.clearToday();

      expect(removed.map((badge) => badge.completionClientEventId), <String>[
        'event-1',
        'event-2',
      ]);
    },
  );
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _scope({String? uid}) => uid == null ? 'local' : 'user:$uid';

String _lastOpenDayKey({String? uid}) =>
    'journal:${_scope(uid: uid)}:lastOpenDay';

String _documentKey(String dateKey, {String? uid}) =>
    'journal:${_scope(uid: uid)}:document:$dateKey';

String _documentDirtyKey(String dateKey, {String? uid}) =>
    'journal:${_scope(uid: uid)}:document_dirty:$dateKey';

String _documentModifiedKey(String dateKey, {String? uid}) =>
    'journal:${_scope(uid: uid)}:document_modified_at:$dateKey';

String _documentJson(String text) => jsonEncode(
  JournalDocument(
    version: kJournalDocVersion,
    blocks: [
      ParagraphBlock(
        id: 'p1',
        ops: [TextOp(insert: text)],
      ),
    ],
  ).toJson(),
);

String _documentJsonWithBadges(String text, List<String> badges) => jsonEncode(
  JournalDocument(
    version: kJournalDocVersion,
    blocks: [
      ParagraphBlock(
        id: 'p1',
        ops: [TextOp(insert: text)],
      ),
    ],
    meta: {'badges': badges},
  ).toJson(),
);

String _completionBadge({
  required String id,
  required String clientEventId,
  required CompletionStatus status,
}) {
  return EventBadgeToken.buildToken(
    id: id,
    eventId: clientEventId,
    title: 'Completion',
    color: Colors.amber,
    description: 'Completion: ${status.wireName}.',
    completionStatus: status,
    sourceType: CompletionSourceType.userFlow,
  );
}

String _ordinaryBadge(String id) {
  return EventBadgeToken.buildToken(
    id: id,
    title: 'Ordinary badge',
    color: Colors.blue,
  );
}

JournalEntry _entry({
  required DateTime date,
  required String body,
  required DateTime updatedAt,
}) {
  return JournalEntry(
    id: 'entry-${_dateKey(date)}',
    userId: 'user-1',
    gregDate: date,
    body: body,
    meta: const {},
    category: null,
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );
}

class _UpsertCall {
  const _UpsertCall({
    required this.localDate,
    required this.body,
    required this.meta,
    required this.category,
  });

  final DateTime localDate;
  final String body;
  final Map<String, dynamic>? meta;
  final String? category;
}

class _FakeJournalRepo extends JournalRepo {
  _FakeJournalRepo({this.entry})
    : super(
        SupabaseClient(
          'https://example.com',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  JournalEntry? entry;
  Object? getByDateError;
  Object? upsertError;
  int getByDateStrictCalls = 0;
  final upserts = <_UpsertCall>[];

  @override
  Future<JournalEntry?> getByDate(DateTime localDate) async =>
      getByDateStrict(localDate);

  @override
  Future<JournalEntry?> getByDateStrict(DateTime localDate) async {
    getByDateStrictCalls += 1;
    final error = getByDateError;
    if (error != null) throw error;
    return entry;
  }

  @override
  Future<void> upsert({
    required DateTime localDate,
    required String body,
    Map<String, dynamic>? meta,
    String? category,
  }) async {
    final error = upsertError;
    if (error != null) throw error;
    upserts.add(
      _UpsertCall(
        localDate: localDate,
        body: body,
        meta: meta,
        category: category,
      ),
    );
  }
}

class _DelayedJournalRepo extends _FakeJournalRepo {
  _DelayedJournalRepo();

  final Completer<void> requested = Completer<void>();
  final Completer<JournalEntry?> _response = Completer<JournalEntry?>();

  void completeWith(JournalEntry? entry) {
    if (!_response.isCompleted) {
      _response.complete(entry);
    }
  }

  @override
  Future<JournalEntry?> getByDateStrict(DateTime localDate) {
    getByDateStrictCalls += 1;
    if (!requested.isCompleted) {
      requested.complete();
    }
    return _response.future;
  }
}
