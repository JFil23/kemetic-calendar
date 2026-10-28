import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mobile/data/account_operation_fence.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/landscape_month_view.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/pages_resource_test.dart' show session, uid;

const _target = NoteData(
  id: 'acknowledged-event-row',
  clientEventId: 'acknowledged-event-client-id',
  title: 'Same titled event',
  detail: 'The acknowledged exact event',
  allDay: false,
  start: TimeOfDay(hour: 10, minute: 0),
  end: TimeOfDay(hour: 10, minute: 45),
);

const _decoy = NoteData(
  id: 'different-event-row',
  clientEventId: 'different-event-client-id',
  title: 'Same titled event',
  detail: 'A different persisted event',
  allDay: false,
  start: TimeOfDay(hour: 11, minute: 0),
  end: TimeOfDay(hour: 11, minute: 45),
);

class _DetailRouteObserver extends NavigatorObserver {
  int popupPushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PopupRoute<dynamic>) popupPushes++;
  }
}

// Based on the canonical restored-detail and mutable-grid fixtures in
// day_view_test.dart. Updates retain the same grid and pending stable identity.
class _PendingFocusHarness extends StatelessWidget {
  const _PendingFocusHarness({
    required this.notes,
    required this.restoration,
    required this.onRestorationChanged,
    required this.observer,
  });

  final ValueNotifier<List<NoteData>> notes;
  final EventDetailRestorationState restoration;
  final ValueChanged<EventDetailRestorationState?> onRestorationChanged;
  final NavigatorObserver observer;

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorObservers: [observer],
    home: Scaffold(
      body: ValueListenableBuilder<List<NoteData>>(
        valueListenable: notes,
        builder: (context, value, _) => DayViewGrid(
          key: const ValueKey('pending-focus-grid'),
          ky: 1,
          km: 1,
          kd: 1,
          notes: value,
          showGregorian: false,
          flowIndex: const {},
          initialScrollOffset: 9 * 60,
          initialEventDetailRestorationState: restoration,
          onEventDetailRestorationChanged: onRestorationChanged,
        ),
      ),
    ),
  );
}

// Uses the existing landscape pager fixture's notesForDay boundary, through
// LandscapeMonthView so the origin permission must reach the actual pager.
class _LandscapePendingFocusHarness extends StatelessWidget {
  const _LandscapePendingFocusHarness({
    required this.notes,
    required this.restoration,
    required this.originIsCurrent,
    required this.onRestorationChanged,
    required this.observer,
  });

  final ValueNotifier<List<NoteData>> notes;
  final EventDetailRestorationState restoration;
  final bool Function() originIsCurrent;
  final ValueChanged<EventDetailRestorationState?> onRestorationChanged;
  final NavigatorObserver observer;

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorObservers: [observer],
    home: Scaffold(
      body: ValueListenableBuilder<List<NoteData>>(
        valueListenable: notes,
        builder: (context, value, _) => LandscapeMonthView(
          key: const ValueKey('pending-landscape-focus-view'),
          initialKy: 6267,
          initialKm: 4,
          initialKd: 1,
          showGregorian: false,
          notesForDay: (ky, km, kd) =>
              ky == 6267 && km == 4 && kd == 1 ? value : const <NoteData>[],
          flowIndex: const {},
          getMonthName: (month) => 'Month $month',
          initialEventDetailRestorationState: restoration,
          eventDetailAccountIsCurrent: originIsCurrent,
          onEventDetailRestorationChanged: onRestorationChanged,
        ),
      ),
    ),
  );
}

Future<void> _setLandscapeViewport(WidgetTester tester) async {
  final binding = tester.binding;
  await binding.setSurfaceSize(const Size(1000, 420));
  binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  addTearDown(() async {
    await binding.setSurfaceSize(null);
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });
}

Future<void> _waitBeyondFormerFocusDeadline(WidgetTester tester) async {
  // Advance each scheduled interval, so the former 20 x 150 ms expiry would
  // actually run out rather than skipping its chained timers in one pump.
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'anon-key-0123456789012345678901234567890123456789',
        authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (_) => throw StateError('Unexpected raw request'),
        ),
      );
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CalendarEventDetailSheetCoordinator.debugResetForTests();
  });

  tearDown(CalendarEventDetailSheetCoordinator.debugResetForTests);
  tearDownAll(() => Supabase.instance.dispose());

  for (final identity in [
    (
      label: 'client event ID',
      type: eventDetailIdentityClientEventId,
      value: _target.clientEventId!,
    ),
    (
      label: 'persisted event row ID',
      type: eventDetailIdentityEventId,
      value: _target.id!,
    ),
  ]) {
    testWidgets(
      'late ${identity.label} focus survives missing data and opens only once',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final notes = ValueNotifier<List<NoteData>>([]);
        addTearDown(notes.dispose);
        final published = <EventDetailRestorationState?>[];
        final observer = _DetailRouteObserver();
        await tester.pumpWidget(
          _PendingFocusHarness(
            notes: notes,
            restoration: EventDetailRestorationState(
              kYear: 1,
              kMonth: 1,
              kDay: 1,
              identityType: identity.type,
              identityValue: identity.value,
            ),
            onRestorationChanged: published.add,
            observer: observer,
          ),
        );
        final originalGridState = tester.state(find.byType(DayViewGrid));
        await _waitBeyondFormerFocusDeadline(tester);
        expect(find.byType(CalendarEventDetailSheet), findsNothing);
        expect(published, isEmpty);

        // A matching title is insufficient: only the acknowledged identity may
        // satisfy the request when later authoritative data arrives.
        notes.value = [_decoy];
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(DayViewGrid)), same(originalGridState));
        expect(find.text('Same titled event'), findsOneWidget);
        expect(find.byType(CalendarEventDetailSheet), findsNothing);
        expect(published, isEmpty);

        notes.value = [_decoy, _target];
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(DayViewGrid)), same(originalGridState));
        expect(find.byType(CalendarEventDetailSheet), findsOneWidget);
        final detail = tester.widget<CalendarEventDetailSheet>(
          find.byType(CalendarEventDetailSheet),
        );
        expect(detail.initialTarget.event.id, _target.id);
        expect(detail.initialTarget.event.clientEventId, _target.clientEventId);
        expect(find.text('10:00 AM – 10:45 AM'), findsOneWidget);
        expect(detail.initialTarget.event.detail, _target.detail);
        expect(detail.initialTarget.event.detail, isNot(_decoy.detail));
        expect(observer.popupPushes, 1);
        expect(published.whereType<EventDetailRestorationState>(), isNotEmpty);
        // The canonical owner publishes the resolved target's preferred CID,
        // including when the incoming request used its persisted row ID.
        expect(
          published.whereType<EventDetailRestorationState>().every(
            (state) =>
                state.identityType == eventDetailIdentityClientEventId &&
                state.identityValue == _target.clientEventId,
          ),
          isTrue,
        );

        Navigator.of(
          tester.element(find.byType(CalendarEventDetailSheet)),
        ).pop();
        await tester.pumpAndSettle();
        expect(find.byType(CalendarEventDetailSheet), findsNothing);
        expect(published.last, isNull);

        // The owner still receives the original initial-focus state. A normal
        // refresh after dismissal must not replay that consumed request.
        notes.value = [_target, _decoy];
        await tester.pumpAndSettle();
        await _waitBeyondFormerFocusDeadline(tester);
        expect(tester.state(find.byType(DayViewGrid)), same(originalGridState));
        expect(find.byType(CalendarEventDetailSheet), findsNothing);
        expect(observer.popupPushes, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'landscape late row-ID focus opens its exact event once after hydration',
    (tester) async {
      await _setLandscapeViewport(tester);
      final notes = ValueNotifier<List<NoteData>>([]);
      addTearDown(notes.dispose);
      final published = <EventDetailRestorationState?>[];
      final observer = _DetailRouteObserver();
      await tester.pumpWidget(
        _LandscapePendingFocusHarness(
          notes: notes,
          restoration: const EventDetailRestorationState(
            kYear: 6267,
            kMonth: 4,
            kDay: 1,
            identityType: eventDetailIdentityEventId,
            identityValue: 'acknowledged-event-row',
          ),
          originIsCurrent: () => true,
          onRestorationChanged: published.add,
          observer: observer,
        ),
      );
      final originalPagerState = tester.state(find.byType(LandscapeMonthPager));
      await _waitBeyondFormerFocusDeadline(tester);
      expect(find.byType(CalendarEventDetailSheet), findsNothing);
      expect(published, isEmpty);
      notes.value = [_decoy];
      await tester.pumpAndSettle();
      expect(
        tester.state(find.byType(LandscapeMonthPager)),
        same(originalPagerState),
      );
      expect(find.byType(CalendarEventDetailSheet), findsNothing);
      expect(observer.popupPushes, 0);

      notes.value = [_decoy, _target];
      await tester.pumpAndSettle();
      expect(
        tester.state(find.byType(LandscapeMonthPager)),
        same(originalPagerState),
      );
      expect(find.byType(CalendarEventDetailSheet), findsOneWidget);
      final detailState = tester.state(find.byType(CalendarEventDetailSheet));
      final detail = tester.widget<CalendarEventDetailSheet>(
        find.byType(CalendarEventDetailSheet),
      );
      expect(detail.initialTarget.event.id, _target.id);
      expect(detail.initialTarget.event.clientEventId, _target.clientEventId);
      expect(detail.initialTarget.event.detail, _target.detail);
      expect(find.text('10:00 AM – 10:45 AM'), findsOneWidget);
      expect(
        observer.popupPushes,
        0,
        reason: 'The canonical landscape detail stays in its pane Navigator.',
      );
      expect(published.whereType<EventDetailRestorationState>(), isNotEmpty);
      expect(
        published.whereType<EventDetailRestorationState>().every(
          (state) =>
              state.identityType == eventDetailIdentityClientEventId &&
              state.identityValue == _target.clientEventId,
        ),
        isTrue,
      );

      Navigator.of(tester.element(find.byType(CalendarEventDetailSheet))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(CalendarEventDetailSheet), findsNothing);
      expect(published.last, isNull);
      expect(detailState.mounted, isFalse);
      notes.value = [_target, _decoy];
      await tester.pumpAndSettle();
      await _waitBeyondFormerFocusDeadline(tester);
      expect(
        tester.state(find.byType(LandscapeMonthPager)),
        same(originalPagerState),
      );
      expect(find.byType(CalendarEventDetailSheet), findsNothing);
      expect(
        observer.popupPushes,
        0,
        reason: 'The canonical landscape detail stays in its pane Navigator.',
      );
      expect(detailState.mounted, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'landscape origin policy rejects pending focus after account A to B to A',
    (tester) async {
      await _setLandscapeViewport(tester);
      final client = Supabase.instance.client;
      await client.auth.recoverSession(session());
      await tester.pump();
      final origin = AccountOperationFence(client);
      addTearDown(origin.dispose);
      final notes = ValueNotifier<List<NoteData>>([]);
      addTearDown(notes.dispose);
      final published = <EventDetailRestorationState?>[];
      final observer = _DetailRouteObserver();
      await tester.pumpWidget(
        _LandscapePendingFocusHarness(
          notes: notes,
          restoration: const EventDetailRestorationState(
            kYear: 6267,
            kMonth: 4,
            kDay: 1,
            identityType: eventDetailIdentityClientEventId,
            identityValue: 'acknowledged-event-client-id',
          ),
          originIsCurrent: () => origin.isCurrent,
          onRestorationChanged: published.add,
          observer: observer,
        ),
      );
      final originalPagerState = tester.state(find.byType(LandscapeMonthPager));
      await _waitBeyondFormerFocusDeadline(tester);
      expect(observer.popupPushes, 0);
      const other = '27d63169-a28a-4550-a0a0-8fee0e8e7b96';
      await client.auth.recoverSession(session().replaceAll(uid, other));
      await tester.pump();
      await client.auth.recoverSession(session());
      await tester.pump();
      expect(client.auth.currentUser!.id, uid);
      expect(origin.isCurrent, isFalse);

      notes.value = [_target];
      await tester.pumpAndSettle();
      await _waitBeyondFormerFocusDeadline(tester);
      expect(
        tester.state(find.byType(LandscapeMonthPager)),
        same(originalPagerState),
      );
      expect(find.byType(CalendarEventDetailSheet), findsNothing);
      expect(observer.popupPushes, 0);
      expect(published, isEmpty);
      notes.value = [_target, _decoy];
      await tester.pumpAndSettle();
      expect(find.byType(CalendarEventDetailSheet), findsNothing);
      expect(observer.popupPushes, 0);
      expect(published, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending exact focus cannot resume after account A to B to A', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = Supabase.instance.client;
    await client.auth.recoverSession(session());
    await tester.pump();
    final notes = ValueNotifier<List<NoteData>>([]);
    addTearDown(notes.dispose);
    final published = <EventDetailRestorationState?>[];
    final observer = _DetailRouteObserver();
    await tester.pumpWidget(
      _PendingFocusHarness(
        notes: notes,
        restoration: const EventDetailRestorationState(
          kYear: 1,
          kMonth: 1,
          kDay: 1,
          identityType: eventDetailIdentityClientEventId,
          identityValue: 'acknowledged-event-client-id',
        ),
        onRestorationChanged: published.add,
        observer: observer,
      ),
    );
    final originalGridState = tester.state(find.byType(DayViewGrid));
    await _waitBeyondFormerFocusDeadline(tester);
    expect(observer.popupPushes, 0);
    const other = '27d63169-a28a-4550-a0a0-8fee0e8e7b96';
    await client.auth.recoverSession(session().replaceAll(uid, other));
    await tester.pump();
    await client.auth.recoverSession(session());
    await tester.pump();
    expect(client.auth.currentUser!.id, uid);

    notes.value = [_target];
    await tester.pumpAndSettle();
    await _waitBeyondFormerFocusDeadline(tester);
    expect(tester.state(find.byType(DayViewGrid)), same(originalGridState));
    expect(find.byType(CalendarEventDetailSheet), findsNothing);
    expect(observer.popupPushes, 0);
    expect(published, isEmpty);

    notes.value = [_target, _decoy];
    await tester.pumpAndSettle();
    expect(find.byType(CalendarEventDetailSheet), findsNothing);
    expect(observer.popupPushes, 0);
    expect(published, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
