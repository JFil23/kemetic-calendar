import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/data/journal_repo.dart';
import 'package:mobile/features/calendar/calendar_completion.dart';
import 'package:mobile/features/calendar/the_days_outside_year_local_store.dart';
import 'package:mobile/features/calendar/the_decan_watch_local_store.dart';
import 'package:mobile/features/calendar/the_djed_flow.dart';
import 'package:mobile/features/calendar/the_djed_local_store.dart';
import 'package:mobile/features/calendar/the_kept_word_local_store.dart';
import 'package:mobile/features/calendar/the_open_hand_local_store.dart';
import 'package:mobile/features/calendar/the_tending_local_store.dart';
import 'package:mobile/features/calendar/the_wag_local_store.dart';
import 'package:mobile/features/journal/journal_badge_utils.dart';
import 'package:mobile/features/journal/journal_controller.dart';
import 'package:mobile/features/journal/journal_event_badge.dart';
import 'package:mobile/features/journal/journal_v2_document_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'calendar completion local store keeps the existing scoped key format',
    () async {
      final prefs = await SharedPreferences.getInstance();
      const store = CalendarCompletionLocalStore(scope: 'local');

      await store.save(
        identity: 'cid:phase0-flow-event',
        status: CompletionStatus.partial,
      );

      expect(
        prefs.getString('calendar_completion:local:cid:phase0-flow-event'),
        'partial',
      );
      expect(
        (await store.load('cid:phase0-flow-event')).completionStatus,
        CompletionStatus.partial,
      );

      await store.save(
        identity: 'cid:phase0-flow-event',
        status: CompletionStatus.none,
      );

      expect(
        prefs.containsKey('calendar_completion:local:cid:phase0-flow-event'),
        isFalse,
      );
    },
  );

  test(
    'existing interactive flow stores preserve their local namespaces',
    () async {
      final prefs = await SharedPreferences.getInstance();
      const flowId = 42;

      await TheTendingLocalStore(prefs: prefs).saveCareList(flowId, const [
        CareListEntry(name: 'Auntie', perceivedNeed: 'weekly call'),
      ]);
      await TheKeptWordLocalStore(
        prefs: prefs,
      ).saveConversationCompleted(flowId, true);
      await TheWagLocalStore(prefs: prefs).saveAncestorNames(flowId, const [
        AncestorNameEntry(display: 'Elder teacher'),
      ]);
      await DecanWatchLocalStore(prefs: prefs).saveRecord(
        flowId: flowId,
        kYear: 6268,
        globalDecanId: 12,
        record: const DecanWatchRecord(skyNote: 'clouded western horizon'),
      );
      await DaysOutsideYearLocalStore(
        prefs: prefs,
      ).saveReceipts(flowId, const <String, String>{'day_1': 'one word'});
      await TheOpenHandLocalStore(
        prefs: prefs,
      ).saveActCompleted(flowId, 3, true);
      await TheDjedLocalStore(prefs: prefs).saveSpineElements(flowId, const [
        SpineElement(label: 'sleep', condition: SpineCondition.underPressure),
      ]);

      expect(prefs.getKeys(), contains('tending_42_care_list'));
      expect(prefs.getKeys(), contains('kept_word_42_conversation_completed'));
      expect(prefs.getKeys(), contains('the_wag_42_ancestor_names'));
      expect(prefs.getKeys(), contains('decan_watch_42_6268_12'));
      expect(prefs.getKeys(), contains('days_outside_42_wep_receipts'));
      expect(prefs.getKeys(), contains('open_hand_42_act_completed_3'));
      expect(prefs.getKeys(), contains('djed_42_spine_elements'));

      expect(
        await TheTendingLocalStore(prefs: prefs).exportFlowData(flowId),
        containsPair('care_list', isA<String>()),
      );
      expect(
        await TheKeptWordLocalStore(
          prefs: prefs,
        ).loadConversationCompleted(flowId),
        isTrue,
      );
      expect(
        (await TheWagLocalStore(
          prefs: prefs,
        ).loadAncestorNames(flowId)).single.display,
        'Elder teacher',
      );
      expect(
        (await DecanWatchLocalStore(
          prefs: prefs,
        ).loadRecord(flowId: flowId, kYear: 6268, globalDecanId: 12)).skyNote,
        'clouded western horizon',
      );
      expect(
        await DaysOutsideYearLocalStore(prefs: prefs).loadReceipts(flowId),
        containsPair('day_1', 'one word'),
      );
      expect(
        await TheOpenHandLocalStore(prefs: prefs).loadActCompleted(flowId, 3),
        isTrue,
      );
      expect(
        (await TheDjedLocalStore(
          prefs: prefs,
        ).loadSpineElements(flowId)).single.label,
        'sleep',
      );
    },
  );

  test(
    'recording completion remains an update path, not duplicate insertion',
    () {
      final source = File('lib/data/user_events_repo.dart').readAsStringSync();
      final body = _sourceBetween(
        source,
        'Future<void> recordEventCompletion',
        '/// Undo completion by deleting the row for this client_event_id.',
      );

      expect(body, contains("rpc(\n      'record_event_completion'"));
      expect(body, contains("'p_client_event_id': clientEventId"));
      expect(body, contains("'p_flow_id': flowId"));
      expect(body, contains("'p_completed_on': dateStr"));
      expect(body, contains(".from('user_event_completions')"));
      expect(body, contains(".update({'metadata': metadata})"));
      expect(body, contains(".eq('user_id', user.id)"));
      expect(body, contains(".eq('client_event_id', clientEventId)"));
      expect(body, isNot(contains(".insert(")));
      expect(body, isNot(contains(".upsert(")));
    },
  );

  test(
    'journal completion badge append keeps user text and replaces by stable id',
    () async {
      final today = _today();
      final repo = _FakeJournalRepo(
        entry: _entry(
          date: today,
          body: _documentJson('User typed body.'),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      final controller = JournalController.withRepo(repo);

      await controller.init();
      await controller.appendToToday(
        _completionBadge(status: CompletionStatus.observed),
      );
      await controller.appendToToday(
        _completionBadge(status: CompletionStatus.partial),
      );

      expect(controller.currentDraft, 'User typed body.');
      expect(JournalBadgeUtils.hasBadges(controller.currentDraft), isFalse);

      final tokens = JournalBadgeUtils.tokensFromDocument(
        controller.currentDocument!,
      );
      expect(tokens, hasLength(1));
      expect(tokens.single.id, 'calendar:maat_flow:cid:moon-return-day-1');
      expect(tokens.single.completionStatus, CompletionStatus.partial);
      expect(tokens.single.completionClientEventId, 'moon-return-day-1');

      await controller.forceSave();
      expect(repo.upserts, hasLength(1));
      final savedDoc = JournalDocument.fromJson(
        jsonDecode(repo.upserts.single.body) as Map<String, dynamic>,
      );
      expect(JournalBadgeUtils.tokensFromDocument(savedDoc), hasLength(1));
      expect(
        JournalBadgeUtils.tokensFromDocument(savedDoc).single.completionStatus,
        CompletionStatus.partial,
      );
    },
  );
}

String _sourceBetween(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  expect(start, isNonNegative, reason: 'missing start marker: $startMarker');
  final end = source.indexOf(endMarker, start + startMarker.length);
  expect(end, isNonNegative, reason: 'missing end marker: $endMarker');
  return source.substring(start, end);
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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

String _completionBadge({required CompletionStatus status}) {
  return EventBadgeToken.buildToken(
    id: 'calendar:maat_flow:cid:moon-return-day-1',
    eventId: 'moon-return-day-1',
    title: 'Moon Return',
    color: Colors.amber,
    description: 'Completion: ${status.wireName}.',
    completionStatus: status,
    sourceType: CompletionSourceType.maatFlow,
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
  final upserts = <_UpsertCall>[];

  @override
  Future<JournalEntry?> getByDate(DateTime localDate) async =>
      getByDateStrict(localDate);

  @override
  Future<JournalEntry?> getByDateStrict(DateTime localDate) async => entry;

  @override
  Future<void> upsert({
    required DateTime localDate,
    required String body,
    Map<String, dynamic>? meta,
    String? category,
  }) async {
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
