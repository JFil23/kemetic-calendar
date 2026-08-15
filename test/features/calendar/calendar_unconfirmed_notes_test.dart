import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app:has_seen_onboarding': true,
      'app:onboarding:completed': true,
    });
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'test-anon-key',
      httpClient: _RejectingClient(),
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: false,
      ),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app:has_seen_onboarding': true,
      'app:onboarding:completed': true,
    });
  });

  Future<CalendarPageState> pumpCalendar(WidgetTester tester) async {
    final key = GlobalKey<CalendarPageState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CalendarPage(key: key)),
      ),
    );
    await tester.pump();
    final state = key.currentState;
    expect(state, isNotNull);
    return state!;
  }

  Future<void> disposeCalendar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // Drain debounce/restoration timers scheduled by CalendarPage.
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('1. unconfirmed note survives merge that lacks it', (
    tester,
  ) async {
    final state = await pumpCalendar(tester);
    const ky = 2;
    const km = 1;
    const kd = 1;
    expect(
      state.debugAddNote(
        ky,
        km,
        kd,
        'Unconfirmed solo',
        null,
        clientEventId: 'cid-survive-1',
        confirmation: NoteConfirmation.unconfirmed,
      ),
      isTrue,
    );
    expect(state.debugUnconfirmedCount, 1);
    expect(state.filteredNoteCountForDay(ky, km, kd), 1);

    final merge = state.debugMergeUnconfirmedInto(emptyIncoming: true);
    expect(merge.preserved, 1);
    expect(merge.confirmed, 0);
    expect(state.debugUnconfirmedCount, 1);
    expect(state.filteredNoteCountForDay(ky, km, kd), 1);
    await disposeCalendar(tester);
  });

  testWidgets('2. matching cid confirms and does not duplicate', (
    tester,
  ) async {
    final state = await pumpCalendar(tester);
    const ky = 2;
    const km = 1;
    const kd = 2;
    expect(
      state.debugAddNote(
        ky,
        km,
        kd,
        'Unconfirmed confirm',
        null,
        clientEventId: 'cid-confirm-1',
        confirmation: NoteConfirmation.unconfirmed,
      ),
      isTrue,
    );
    expect(state.debugUnconfirmedCount, 1);

    // Incoming hydration already contains the same cid (copy of live notes).
    final merge = state.debugMergeUnconfirmedInto();
    expect(merge.confirmed, 1);
    expect(merge.preserved, 0);
    expect(state.debugUnconfirmedCount, 0);
    expect(state.filteredNoteCountForDay(ky, km, kd), 1);
    await disposeCalendar(tester);
  });

  testWidgets('3. deleted unconfirmed note does not resurrect on merge', (
    tester,
  ) async {
    final state = await pumpCalendar(tester);
    const ky = 2;
    const km = 1;
    const kd = 3;
    expect(
      state.debugAddNote(
        ky,
        km,
        kd,
        'Unconfirmed delete',
        null,
        clientEventId: 'cid-delete-1',
        confirmation: NoteConfirmation.unconfirmed,
      ),
      isTrue,
    );
    expect(state.debugUnconfirmedCount, 1);
    expect(state.debugRemoveLocalNoteOnly(ky, km, kd, 0), isTrue);
    expect(state.debugUnconfirmedCount, 0);
    expect(state.filteredNoteCountForDay(ky, km, kd), 0);

    final merge = state.debugMergeUnconfirmedInto(emptyIncoming: true);
    expect(merge.preserved, 0);
    expect(state.debugUnconfirmedCount, 0);
    expect(state.filteredNoteCountForDay(ky, km, kd), 0);
    await disposeCalendar(tester);
  });

  testWidgets('4. unconfirmed register without cid is refused', (tester) async {
    final state = await pumpCalendar(tester);
    expect(
      state.debugAddNote(
        2,
        1,
        4,
        'No cid',
        null,
        confirmation: NoteConfirmation.unconfirmed,
      ),
      isTrue,
    );
    expect(state.debugUnconfirmedCount, 0);
    await disposeCalendar(tester);
  });

  test(
    '5. overlay is prepared before publish and persisted after acceptance',
    () {
      final source = File(
        'lib/features/calendar/hydration/calendar_hydration_engine.dart',
      ).readAsStringSync();
      final commitStart = source.indexOf(
        'Future<void> commitVisibleCalendarState(',
      );
      expect(commitStart, greaterThanOrEqualTo(0));
      final commitSlice = source.substring(
        commitStart,
        source.indexOf('hydrationPassSucceeded =', commitStart),
      );
      final isCurrentAt = commitSlice.indexOf('!jobContext.isCurrent');
      final sameUserAt = commitSlice.indexOf(
        '_activeWarmStartUserId() != loadUserId',
      );
      final mergeAt = commitSlice.indexOf('_unconfirmed.mergeInto(');
      final previewOnlyAt = commitSlice.indexOf('retireConfirmed: false');
      final preparedAt = commitSlice.indexOf('_buildCalendarSnapshotCommit(');
      final callbackAt = commitSlice.indexOf('void applyPreparedState()');
      final controllerCommitAt = commitSlice.indexOf(
        '_hydrationController.commitViewport(',
      );
      final acceptedAt = commitSlice.indexOf('if (!accepted) {');
      final retireAt = commitSlice.indexOf('_unconfirmed.forgetCids(');
      final persistenceAt = commitSlice.indexOf(
        '_enqueueCalendarSnapshotPersistence(',
      );
      expect(isCurrentAt, greaterThanOrEqualTo(0));
      expect(sameUserAt, greaterThan(isCurrentAt));
      expect(mergeAt, greaterThan(sameUserAt));
      expect(previewOnlyAt, greaterThan(mergeAt));
      expect(preparedAt, greaterThan(previewOnlyAt));
      expect(callbackAt, greaterThan(preparedAt));
      expect(controllerCommitAt, greaterThan(callbackAt));
      expect(acceptedAt, greaterThan(controllerCommitAt));
      expect(retireAt, greaterThan(acceptedAt));
      expect(persistenceAt, greaterThan(retireAt));
      expect(commitSlice, isNot(contains('snapshot_durable_commit_rejected')));
    },
  );

  testWidgets(
    '6. persisted pending note joins restored warm note and survives omitted complete snapshot',
    (tester) async {
      const userId = 'restart-user';
      const cid = 'cid-restart-warm';
      const ky = 2;
      const km = 1;
      const kd = 6;
      final createdAt = DateTime.utc(2026, 8, 10, 20);

      var state = await pumpCalendar(tester);
      expect(
        state.debugAddNote(
          ky,
          km,
          kd,
          'Restart-safe warm event',
          null,
          clientEventId: cid,
          confirmation: NoteConfirmation.unconfirmed,
        ),
        isTrue,
      );
      await state.debugPersistPendingNoteForTesting(
        userId: userId,
        kYear: ky,
        kMonth: km,
        kDay: kd,
        clientEventId: cid,
        createdAt: createdAt,
      );
      await disposeCalendar(tester);

      state = await pumpCalendar(tester);
      // This confirmed local row stands in for the separately restored warm
      // snapshot, whose serialized payload intentionally has no pending flag.
      state.debugAddNote(
        ky,
        km,
        kd,
        'Restart-safe warm event',
        null,
        clientEventId: cid,
      );
      await state.debugRestorePendingNotesForTesting(userId);
      expect(state.debugUnconfirmedCount, 1);
      expect(
        state.debugPendingNotesDueForVerification(
          createdAt.add(const Duration(minutes: 3)),
        ),
        1,
        reason: 'restore must retain the original createdAt',
      );

      final merge = state.debugMergeUnconfirmedInto(emptyIncoming: true);
      expect(merge.preserved, 1);
      expect(state.filteredNoteCountForDay(ky, km, kd), 1);
      await disposeCalendar(tester);
    },
  );

  testWidgets(
    '7. missing warm-cache note reconstructs from durable pending payload',
    (tester) async {
      const userId = 'payload-user';
      const cid = 'cid-restart-payload';
      const ky = 2;
      const km = 1;
      const kd = 7;

      var state = await pumpCalendar(tester);
      state.debugAddNote(
        ky,
        km,
        kd,
        'Reconstruct me',
        'payload detail',
        clientEventId: cid,
        confirmation: NoteConfirmation.unconfirmed,
      );
      await state.debugPersistPendingNoteForTesting(
        userId: userId,
        kYear: ky,
        kMonth: km,
        kDay: kd,
        clientEventId: cid,
        createdAt: DateTime.utc(2026, 8, 10, 21),
      );
      await disposeCalendar(tester);

      state = await pumpCalendar(tester);
      expect(state.filteredNoteCountForDay(ky, km, kd), 0);
      await state.debugRestorePendingNotesForTesting(userId);
      expect(state.debugUnconfirmedCount, 1);
      expect(state.filteredNoteCountForDay(ky, km, kd), 1);

      final restored = state.notesForDayForTesting(ky, km, kd).single;
      expect(restored.title, 'Reconstruct me');
      expect(restored.detail, 'payload detail');
      final merge = state.debugMergeUnconfirmedInto(emptyIncoming: true);
      expect(merge.preserved, 1);
      expect(state.filteredNoteCountForDay(ky, km, kd), 1);
      await disposeCalendar(tester);
    },
  );

  testWidgets(
    '8. expired pending note survives while forced-live verification is unavailable',
    (tester) async {
      final state = await pumpCalendar(tester);
      const ky = 2;
      const km = 1;
      const kd = 8;
      state.debugAddNote(
        ky,
        km,
        kd,
        'Verification unavailable',
        null,
        clientEventId: 'cid-verify-unavailable',
        confirmation: NoteConfirmation.unconfirmed,
      );
      expect(
        state.debugPendingNotesDueForVerification(
          DateTime.now().toUtc().add(const Duration(minutes: 3)),
        ),
        1,
      );

      final merge = state.debugMergeUnconfirmedInto(emptyIncoming: true);
      expect(merge.preserved, 1);
      expect(state.debugUnconfirmedCount, 1);
      expect(state.filteredNoteCountForDay(ky, km, kd), 1);
      await disposeCalendar(tester);
    },
  );

  testWidgets('9. hydrated read-only buckets remain addable and deletable', (
    tester,
  ) async {
    final state = await pumpCalendar(tester);
    const ky = 2;
    const km = 1;
    const kd = 9;

    state.debugReplaceLiveNotesFromReadOnlyProjectionForTesting(
      kYear: ky,
      kMonth: km,
      kDay: kd,
      title: 'Hydrated note',
      clientEventId: 'cid-hydrated-read-only',
    );

    expect(
      state.debugAddNote(
        ky,
        km,
        kd,
        'New local note',
        null,
        clientEventId: 'cid-new-local',
      ),
      isTrue,
    );
    expect(state.filteredNoteCountForDay(ky, km, kd), 2);

    expect(state.debugRemoveLocalNoteOnly(ky, km, kd, 0), isTrue);
    expect(state.filteredNoteCountForDay(ky, km, kd), 1);
    expect(
      state.notesForDayForTesting(ky, km, kd).single.title,
      'New local note',
    );
    await disposeCalendar(tester);
  });
}

class _RejectingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(const <int>[]),
      500,
      request: request,
    );
  }
}
