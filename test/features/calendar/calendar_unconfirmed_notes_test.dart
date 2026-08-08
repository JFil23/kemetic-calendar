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

  test('5. mergeInto is after epoch/same-user guards in commitVisibleCalendarState', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final commitStart = source.indexOf('void commitVisibleCalendarState(');
    expect(commitStart, greaterThanOrEqualTo(0));
    final commitSlice = source.substring(
      commitStart,
      source.indexOf('Future<void> finishNonCriticalPostProcessing()', commitStart),
    );
    final isCurrentAt = commitSlice.indexOf(
      'if (!_loadCoordinator.isCurrent(epoch)) return;',
    );
    final sameUserAt = commitSlice.indexOf(
      'if (_activeWarmStartUserId() != loadUserId) return;',
    );
    final mergeAt = commitSlice.indexOf('_unconfirmed.mergeInto(');
    expect(isCurrentAt, greaterThanOrEqualTo(0));
    expect(sameUserAt, greaterThan(isCurrentAt));
    expect(mergeAt, greaterThan(sameUserAt));
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
