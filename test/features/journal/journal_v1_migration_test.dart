import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/journal_repo.dart';
import 'package:mobile/features/journal/journal_controller.dart';
import 'package:mobile/features/journal/journal_v2_document_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('signed-out V1 draft migrates into the local V2 document', () async {
    final today = _today();
    final key = _dateKey(today);
    SharedPreferences.setMockInitialValues({
      _draftKey(key): 'signed-out v1 draft',
      _lastOpenDayKey(): key,
    });

    final controller = JournalController.withRepo(_FakeJournalRepo());
    await controller.init();

    expect(controller.currentDraft, 'signed-out v1 draft');
    expect(controller.currentDocument?.meta['migrated_from_v1'], isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_documentKey(key)), contains('signed-out v1 draft'));
    expect(prefs.getString(_draftKey(key)), isNull);
    expect(prefs.getBool(_draftDirtyKey(key)), isNull);
  });

  test('dirty local V1 draft keeps dirty V2 metadata and text', () async {
    final today = _today();
    final key = _dateKey(today);
    final modifiedAt = DateTime.now().toUtc();
    SharedPreferences.setMockInitialValues({
      _draftKey(key): 'dirty v1 draft',
      _draftDirtyKey(key): true,
      _draftModifiedKey(key): modifiedAt.toIso8601String(),
      _lastOpenDayKey(): key,
    });

    final controller = JournalController.withRepo(_FakeJournalRepo());
    await controller.init();

    expect(controller.currentDraft, 'dirty v1 draft');
    expect(controller.hasUnsavedChanges, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_documentDirtyKey(key)), isTrue);
    expect(
      prefs.getString(_documentModifiedKey(key)),
      modifiedAt.toIso8601String(),
    );
    expect(prefs.getString(_draftKey(key)), isNull);
    expect(prefs.getBool(_draftDirtyKey(key)), isNull);
  });

  test(
    'server failure still upgrades dirty V1 and recovers the local text',
    () async {
      final today = _today();
      final key = _dateKey(today);
      final modifiedAt = DateTime.now().toUtc();
      SharedPreferences.setMockInitialValues({
        _draftKey(key): 'offline v1 draft',
        _draftDirtyKey(key): true,
        _draftModifiedKey(key): modifiedAt.toIso8601String(),
        _lastOpenDayKey(): key,
      });

      final repo = _FakeJournalRepo()
        ..getByDateError = Exception('unavailable');
      final controller = JournalController.withRepo(repo);
      await controller.init();

      expect(controller.currentDraft, 'offline v1 draft');
      expect(controller.hasUnsavedChanges, isTrue);
      expect(
        controller.syncStatus,
        isIn([JournalSyncStatus.unsavedLocal, JournalSyncStatus.saveFailed]),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_documentKey(key)), contains('offline v1 draft'));
      expect(prefs.getString(_draftKey(key)), isNull);
    },
  );

  test(
    'offline recovery keeps the migrated dirty draft over an older server row',
    () async {
      final today = _today();
      final key = _dateKey(today);
      final localModifiedAt = DateTime.now().toUtc();
      SharedPreferences.setMockInitialValues({
        _draftKey(key): 'recovered v1 draft',
        _draftDirtyKey(key): true,
        _draftModifiedKey(key): localModifiedAt.toIso8601String(),
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

      expect(controller.currentDraft, 'recovered v1 draft');
      expect(controller.hasUnsavedChanges, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(_documentKey(key)),
        contains('recovered v1 draft'),
      );
      expect(prefs.getString(_draftKey(key)), isNull);
    },
  );

  test(
    'signed-in user imports a dirty signed-out V1 draft into the user document',
    () async {
      final today = _today();
      final key = _dateKey(today);
      SharedPreferences.setMockInitialValues({
        _draftKey(key): 'guest v1 draft',
        _draftDirtyKey(key): true,
        _draftModifiedKey(key): DateTime.now().toUtc().toIso8601String(),
      });

      final repo = _FakeJournalRepo();
      final controller = JournalController.withRepo(
        repo,
        currentUserId: () => 'user-a',
      );
      await controller.init();

      expect(controller.currentDraft, 'guest v1 draft');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(_documentKey(key, uid: 'user-a')),
        contains('guest v1 draft'),
      );
      expect(prefs.getString(_draftKey(key)), isNull);
      expect(prefs.getString(_documentKey(key)), isNull);
    },
  );

  test(
    'existing saved V1 prefs for today and yesterday both upgrade',
    () async {
      final today = _today();
      final yesterday = today.subtract(const Duration(days: 1));
      final todayKey = _dateKey(today);
      final yesterdayKey = _dateKey(yesterday);
      SharedPreferences.setMockInitialValues({
        _draftKey(todayKey): 'saved today v1',
        _draftDirtyKey(todayKey): true,
        _draftModifiedKey(todayKey): DateTime.now().toUtc().toIso8601String(),
        _draftKey(yesterdayKey): 'saved yesterday v1',
        _lastOpenDayKey(): todayKey,
      });

      final controller = JournalController.withRepo(_FakeJournalRepo());
      await controller.init();

      expect(controller.currentDraft, 'saved today v1');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(_documentKey(todayKey)),
        contains('saved today v1'),
      );
      expect(
        prefs.getString(_documentKey(yesterdayKey)),
        contains('saved yesterday v1'),
      );
      expect(prefs.getString(_draftKey(todayKey)), isNull);
      expect(prefs.getString(_draftKey(yesterdayKey)), isNull);
    },
  );

  test('crash after V2 write keeps V1 until a later confirmed rerun', () async {
    final today = _today();
    final key = _dateKey(today);
    SharedPreferences.setMockInitialValues({
      _draftKey(key): 'crash retry v1',
      _draftDirtyKey(key): true,
      _draftModifiedKey(key): DateTime.now().toUtc().toIso8601String(),
      _lastOpenDayKey(): key,
    });

    final first = JournalController.withRepo(_FakeJournalRepo())
      ..debugFailV2MigrationWriteConfirmation = true;
    await first.init();

    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_draftKey(key)), 'crash retry v1');

    final second = JournalController.withRepo(_FakeJournalRepo());
    await second.init();

    expect(second.currentDraft, 'crash retry v1');
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_documentKey(key)), contains('crash retry v1'));
    expect(prefs.getString(_draftKey(key)), isNull);
  });

  test(
    'rerun does not overwrite a newer V2 document and then drops V1',
    () async {
      final today = _today();
      final key = _dateKey(today);
      final v2Modified = DateTime.now().toUtc();
      final v1Modified = v2Modified.subtract(const Duration(minutes: 10));
      SharedPreferences.setMockInitialValues({
        _documentKey(key): _documentJson('newer v2 text'),
        _documentDirtyKey(key): true,
        _documentModifiedKey(key): v2Modified.toIso8601String(),
        _draftKey(key): 'older v1 text',
        _draftDirtyKey(key): true,
        _draftModifiedKey(key): v1Modified.toIso8601String(),
        _lastOpenDayKey(): key,
      });

      final first = JournalController.withRepo(_FakeJournalRepo());
      await first.init();
      expect(first.currentDraft, 'newer v2 text');

      final prefsAfterFirst = await SharedPreferences.getInstance();
      expect(prefsAfterFirst.getString(_draftKey(key)), isNull);
      expect(
        prefsAfterFirst.getString(_documentKey(key)),
        contains('newer v2 text'),
      );

      final second = JournalController.withRepo(_FakeJournalRepo());
      await second.init();
      expect(second.currentDraft, 'newer v2 text');
    },
  );

  test(
    'user-scoped V1 prefs upgrade without touching another account',
    () async {
      final today = _today();
      final key = _dateKey(today);
      SharedPreferences.setMockInitialValues({
        _draftKey(key, uid: 'user-a'): 'user a v1',
        _draftDirtyKey(key, uid: 'user-a'): true,
        _draftModifiedKey(key, uid: 'user-a'): DateTime.now()
            .toUtc()
            .toIso8601String(),
        _draftKey(key, uid: 'user-b'): 'user b v1',
        _draftDirtyKey(key, uid: 'user-b'): true,
        _draftModifiedKey(key, uid: 'user-b'): DateTime.now()
            .toUtc()
            .toIso8601String(),
      });

      final controller = JournalController.withRepo(
        _FakeJournalRepo(),
        currentUserId: () => 'user-a',
      );
      await controller.init();

      expect(controller.currentDraft, 'user a v1');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(_documentKey(key, uid: 'user-a')),
        contains('user a v1'),
      );
      expect(prefs.getString(_draftKey(key, uid: 'user-a')), isNull);
      expect(prefs.getString(_draftKey(key, uid: 'user-b')), 'user b v1');
      expect(prefs.getString(_documentKey(key, uid: 'user-b')), isNull);
    },
  );

  test('editing after V1 upgrade writes V2 document keys only', () async {
    final today = _today();
    final key = _dateKey(today);
    SharedPreferences.setMockInitialValues({
      _draftKey(key): 'before edit',
      _lastOpenDayKey(): key,
    });

    final controller = JournalController.withRepo(_FakeJournalRepo());
    await controller.init();
    await controller.updateDraft('after edit');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_documentKey(key)), contains('after edit'));
    expect(prefs.getString(_draftKey(key)), isNull);
    expect(prefs.getBool(_documentDirtyKey(key)), isTrue);
  });

  test('V1 load and save branches are absent from active journal code', () {
    final source = File(
      'lib/features/journal/journal_controller.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('_loadDraftForToday')));
    expect(source, isNot(contains('_saveLocalDraft')));
    expect(source, isNot(contains('_isDocumentMode')));
    expect(source, isNot(contains('_draftKey(')));
    expect(source, isNot(contains('_dirtyLocalScopeDraft')));
  });
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

String _draftKey(String dateKey, {String? uid}) =>
    'journal:${_scope(uid: uid)}:draft:$dateKey';

String _draftDirtyKey(String dateKey, {String? uid}) =>
    'journal:${_scope(uid: uid)}:draft_dirty:$dateKey';

String _draftModifiedKey(String dateKey, {String? uid}) =>
    'journal:${_scope(uid: uid)}:draft_modified_at:$dateKey';

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

  @override
  Future<JournalEntry?> getByDate(DateTime localDate) async =>
      getByDateStrict(localDate);

  @override
  Future<JournalEntry?> getByDateStrict(DateTime localDate) async {
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
  }) async {}
}
