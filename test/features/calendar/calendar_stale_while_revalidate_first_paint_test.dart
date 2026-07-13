import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/features/calendar/calendar_invalidation.dart';
import 'package:mobile/features/calendar/calendar_page.dart'
    show CalendarPage, CalendarPageState, KemeticMath;
import 'package:mobile/features/calendar/calendar_warm_start_cache_identity.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';
import 'package:mobile/services/calendar_snapshot_repository.dart';
import 'package:mobile/services/restoration_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _testUserId = '4d2583da-8de4-49d3-9cd1-37a9a74f55bd';
const String _testWindowId = 'calendar-swr-first-paint-test-window';
const String _supabaseUrl = 'https://example.supabase.co';
const String _cachedTitle = 'Cached Akhet Anchor';
const String _freshTitle = 'Fresh Akhet Anchor';
const String _rejectedTitle = 'Rejected Warm Anchor';
const String _clientEventId = 'cid-stale-while-revalidate-anchor';
const String _focusedColdTitle = 'Focused cold-start event';
const String _wideColdTitle = 'Wide cold-start event';
const String _standaloneColdTitle = 'Cold standalone event';
const int _coldFlowId = 731;
const String _reminderTitle = 'Journal every night';
const String _reminderUuid = '8f2cb620-f01e-4bf8-b0f7-5a5c4ad32db1';
const int _reminderFlowId = 732;

final _backend = _CalendarSwrBackend();
late MemoryCalendarSnapshotStore _snapshotStore;

void _mockAppLinksChannels() {
  const messages = MethodChannel('com.llfbandit.app_links/messages');
  const events = MethodChannel('com.llfbandit.app_links/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(messages, (_) async => null);
  messenger.setMockMethodCallHandler(events, (methodCall) async {
    if (methodCall.method == 'listen') {
      messenger.handlePlatformMessage(
        events.name,
        const StandardMethodCodec().encodeSuccessEnvelope(null),
        (_) {},
      );
    }
    return null;
  });
}

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {}

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: 'anon-key-0123456789012345678901234567890123456789',
    httpClient: _backend,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _mockAppLinksChannels();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppWindowService.debugWindowIdResolver = () async => _testWindowId;
    await _ensureSupabaseInitialized();
  });

  tearDownAll(() {
    AppWindowService.debugWindowIdResolver = null;
    AppRestorationService.debugUserIdResolver = null;
    AppRestorationService.debugRemoteWindowSnapshotReader = null;
    AppRestorationService.debugRemoteLatestSnapshotReader = null;
    AppRestorationService.debugRemoteSnapshotWriter = null;
    CalendarPage.debugSuppressPendingEventInviteOverlay = false;
    CalendarPage.debugSuppressCalendarOnboardingHelpers = false;
  });

  setUp(() async {
    _backend.reset();
    _snapshotStore = MemoryCalendarSnapshotStore();
    CalendarSnapshotRepository.instance.debugReplaceStore(_snapshotStore);
    CalendarPage.debugResetWarmStateStoreForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppWindowService.instance.resetForTesting();
    CalendarPage.debugSuppressPendingEventInviteOverlay = true;
    CalendarPage.debugSuppressCalendarOnboardingHelpers = true;
    RestorationCoordinator.instance.suppressRestoreForExplicitIntent(
      reason: 'calendar_swr_first_paint_test',
      surfaces: const <String>[
        RestorationCoordinator.calendarOverlayStackSurface,
      ],
    );
    AppRestorationService.debugUserIdResolver = () => _testUserId;
    AppRestorationService.debugRemoteWindowSnapshotReader = (_, _, _) async =>
        null;
    AppRestorationService.debugRemoteLatestSnapshotReader = (_) async => null;
    AppRestorationService.debugRemoteSnapshotWriter = (_, _, _, _) async {};
    if (Supabase.instance.client.auth.currentUser?.id != _testUserId) {
      await _recoverTestSession();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_v1_completed:$_testUserId', true);
    await prefs.setBool('calendar:cid_migration_done', true);
    await _seedCalendarRestorationPrefs(prefs);
  });

  tearDown(() {
    _backend.release();
  });

  group('CalendarPage startup stale-while-revalidate first paint', () {
    testWidgets(
      'valid warm snapshot paints cached event before fresh repositories complete',
      (tester) async {
        await _setPhoneViewport(tester);
        await _seedWarmSnapshot(title: _cachedTitle);
        _backend.blockRefresh = true;

        final frames = <String>[];
        await _pumpCalendar(tester);
        frames.add(_visibleFrameForTitle(tester, 'Journal every day'));

        expect(
          _hasCalendarBody(tester),
          isTrue,
          reason:
              'A valid warm snapshot must render the calendar body on the '
              'first frame, before delayed fresh repositories finish. '
              'frames=$frames requests=${_backend.requestLog}',
        );
        expect(
          find.text(_cachedTitle),
          findsOneWidget,
          reason:
              'Cached event should be visible before the fake backend refresh '
              'is released. frames=$frames requests=${_backend.requestLog}',
        );
        expect(
          frames,
          isNot(contains('blank')),
          reason: 'No blank frame is allowed when warm state exists.',
        );
      },
    );

    testWidgets(
      'restoring durable last-good does not rewrite it before reconciliation',
      (tester) async {
        await _setPhoneViewport(tester);
        await _seedWarmSnapshot(title: _cachedTitle);
        final blockingStore = _BlockingCalendarSnapshotStore()
          ..values.addAll(_snapshotStore.values);
        _snapshotStore = blockingStore;
        CalendarSnapshotRepository.instance.debugReplaceStore(blockingStore);
        _backend.blockRefresh = true;

        await _pumpCalendar(tester);
        await _pumpWarmRestoreWindow(tester);
        await tester.pump();

        expect(find.text(_cachedTitle), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          blockingStore.writeStarted,
          isFalse,
          reason:
              'Reading an already-confirmed snapshot must not immediately '
              'schedule the same large payload for durable promotion.',
        );
      },
    );

    testWidgets(
      'returning to calendar keeps populated process state when disk cache is empty',
      (tester) async {
        await _setPhoneViewport(tester);
        await _seedWarmSnapshot(title: _cachedTitle);
        _backend.blockRefresh = true;
        addTearDown(() async {
          _backend.release();
          await tester.pumpWidget(const SizedBox.shrink());
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 250));
          }
        });

        await tester.pumpWidget(
          MaterialApp(home: CalendarPage(key: UniqueKey())),
        );
        await tester.pump();
        await _pumpWarmRestoreWindow(tester);
        expect(find.text(_cachedTitle), findsOneWidget);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('Journal'))),
        );
        await tester.pump();
        await tester.runAsync<void>(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await _seedWarmSnapshot(
          includeEvent: false,
          replaceRetainedMemory: false,
        );

        final frames = <String>[];
        await tester.pumpWidget(
          MaterialApp(home: CalendarPage(key: UniqueKey())),
        );
        frames.add(_visibleFrame(tester));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 25));
          frames.add(_visibleFrame(tester));
        }

        expect(
          find.text(_cachedTitle),
          findsOneWidget,
          reason:
              'Route recreation must reuse the populated same-process calendar '
              'snapshot instead of replacing it with an empty persisted cache. '
              'frames=$frames requests=${_backend.requestLog}',
        );
        expect(
          frames.where((frame) => frame == 'empty'),
          isEmpty,
          reason:
              'Calendar -> Journal -> Calendar must never publish an empty '
              'frame while populated process state still exists. '
              'frames=$frames',
        );
        expect(
          frames.skip(1),
          everyElement('cached'),
          reason:
              'After the route transition frame, populated process state must '
              'remain continuously visible. frames=$frames',
        );
      },
    );

    testWidgets(
      'returning from journal keeps saved month authoritative over warm first paint',
      (tester) async {
        await _setPhoneViewport(tester);
        final today = KemeticMath.fromGregorian(DateTime.now());
        final target = _nonTodayRestorationTarget(today);
        final prefs = await SharedPreferences.getInstance();
        await _seedCalendarRestorationPrefs(prefs, target: target);
        await _seedWarmSnapshot(title: _cachedTitle, target: target);
        _backend.blockRefresh = true;
        _backend.freshStandaloneEvents = <Map<String, Object?>>[
          _standaloneEventRow(title: _freshTitle, target: target),
        ];

        final restorationReady = Completer<void>();
        AppWindowService.debugWindowIdResolver = () async {
          await restorationReady.future;
          return _testWindowId;
        };
        AppWindowService.instance.resetForTesting();

        final frames = <_CalendarMovementFrame>[];
        addTearDown(() async {
          if (!restorationReady.isCompleted) restorationReady.complete();
          AppWindowService.debugWindowIdResolver = () async => _testWindowId;
          AppWindowService.instance.resetForTesting();
          _backend.release();
          await tester.pumpWidget(const SizedBox.shrink());
        });

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('Journal'))),
        );
        await tester.pumpWidget(
          MaterialApp(home: CalendarPage(key: UniqueKey())),
        );
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 25));
          await _recordMovementFrame(
            tester,
            frames,
            today: today,
            target: target,
          );
          await tester.runAsync<void>(() async {
            await Future<void>.delayed(Duration.zero);
          });
        }

        restorationReady.complete();
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 25));
          await _recordMovementFrame(
            tester,
            frames,
            today: today,
            target: target,
          );
          if (i % 4 == 0) {
            await tester.runAsync<void>(() async {
              await Future<void>.delayed(Duration.zero);
            });
          }
        }

        final firstMeaningful = frames.where((frame) => frame.meaningful).first;
        expect(
          frames.any((frame) => frame.startupSingleMonthVisible),
          isFalse,
          reason:
              'No temporary one-month calendar may become a visible authority. '
              'frames=${_movementFrameSummary(frames)}',
        );
        expect(
          frames.any((frame) => frame.fullCalendarScrollVisible),
          isTrue,
          reason:
              'The first calendar tree must be the persistent full scroll. '
              'frames=${_movementFrameSummary(frames)}',
        );
        expect(
          firstMeaningful.savedMonthVisible,
          isTrue,
          reason:
              'The first meaningful calendar frame must be the restored '
              'non-today month. frames=${_movementFrameSummary(frames)}',
        );
        expect(
          firstMeaningful.cachedEventVisible,
          isTrue,
          reason:
              'The cached event on the restored month must be visible before '
              'fresh repositories complete. frames=${_movementFrameSummary(frames)}',
        );
        expect(
          frames.any((frame) => frame.todayOnlyVisible),
          isFalse,
          reason:
              'Today/current month must not appear as an intermediate restored '
              'position. frames=${_movementFrameSummary(frames)}',
        );
        expect(
          frames.any((frame) => frame.emptyVisible),
          isFalse,
          reason:
              'Startup must not flash an empty calendar state while a valid '
              'warm snapshot exists. frames=${_movementFrameSummary(frames)}',
        );
        expect(
          _cachedEventDisappearedAfterFirstPaint(frames),
          isFalse,
          reason:
              'Cached events must remain visible until fresh reconciliation. '
              'frames=${_movementFrameSummary(frames)}',
        );
        expect(
          _cachedEventShiftedAfterFirstPaint(frames),
          isFalse,
          reason:
              'Warm reconciliation must not visibly shift the restored '
              'cached event. frames=${_movementFrameSummary(frames)}',
        );
      },
    );

    testWidgets('one Today tap wins over an in-flight persisted restore', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      final today = KemeticMath.fromGregorian(DateTime.now());
      final target = _nonTodayRestorationTarget(today);
      final prefs = await SharedPreferences.getInstance();
      await _seedCalendarRestorationPrefs(prefs, target: target);
      await _seedWarmSnapshot(title: _cachedTitle);
      _backend.blockRefresh = true;

      final restorationReady = Completer<void>();
      AppWindowService.debugWindowIdResolver = () async {
        await restorationReady.future;
        return _testWindowId;
      };
      AppWindowService.instance.resetForTesting();
      addTearDown(() {
        if (!restorationReady.isCompleted) restorationReady.complete();
        AppWindowService.debugWindowIdResolver = () async => _testWindowId;
        AppWindowService.instance.resetForTesting();
      });

      await _pumpCalendar(tester);
      expect(find.byTooltip('Today'), findsOneWidget);
      await tester.tap(find.byTooltip('Today'));
      await tester.pump(const Duration(milliseconds: 400));

      restorationReady.complete();
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        if (i % 4 == 0) {
          await tester.runAsync<void>(() async {
            await Future<void>.delayed(Duration.zero);
          });
        }
      }

      final state = tester.state<CalendarPageState>(find.byType(CalendarPage));
      expect(state.debugCurrentViewForTesting, (
        kYear: today.kYear,
        kMonth: today.kMonth,
        kDay: today.kDay,
      ));
      expect(state.debugTodayAnchorVisibleForTesting, isTrue);
    });

    testWidgets(
      'successful refresh keeps cached state visible until fresh state replaces it',
      (tester) async {
        await _setPhoneViewport(tester);
        await _seedWarmSnapshot(title: _cachedTitle);
        _backend.blockRefresh = true;
        _backend.freshStandaloneEvents = <Map<String, Object?>>[
          _standaloneEventRow(title: _freshTitle),
        ];

        final frames = <String>[];
        await _pumpCalendar(tester);
        frames.add(_visibleFrame(tester));

        expect(
          find.text(_cachedTitle),
          findsOneWidget,
          reason:
              'Cached event must be visible while fresh repositories are still '
              'blocked. frames=$frames',
        );

        await _releaseAndPumpUntilTextVisible(tester, _freshTitle, frames);

        expect(
          frames,
          isNot(anyOf(contains('blank'), contains('empty'))),
          reason:
              'Refresh must not pass through blank or empty visible frames. '
              'frames=$frames',
        );
        expect(find.text(_freshTitle), findsOneWidget);
        expect(
          find.text(_cachedTitle),
          findsNothing,
          reason:
              'Fresh row has the same client_event_id and should replace the '
              'warm copy without duplication. frames=$frames',
        );
      },
    );

    testWidgets(
      'startup backfill without standalone authority does not erase warm standalone event',
      (tester) async {
        await _setPhoneViewport(tester);
        await _seedWarmSnapshot(title: 'Journal every day');
        _backend.blockRefresh = true;
        _backend.freshStandaloneEvents = const <Map<String, Object?>>[];

        final frames = <String>[];
        await _pumpCalendar(tester);
        frames.add(_visibleFrame(tester));

        expect(
          find.text('Journal every day'),
          findsOneWidget,
          reason:
              'The warm standalone event must paint before the startup '
              'backfill completes. frames=$frames requests=${_backend.requestLog}',
        );

        _backend.release();
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          if (i % 4 == 0) {
            await tester.runAsync<void>(() async {
              await Future<void>.delayed(Duration.zero);
            });
          }
          frames.add(_visibleFrameForTitle(tester, 'Journal every day'));
        }

        expect(
          find.text('Journal every day'),
          findsOneWidget,
          reason:
              'A startup backfill that did not authoritatively load the '
              'standalone/reminder lane must not erase the painted warm event. '
              'frames=$frames requests=${_backend.requestLog}',
        );
        expect(
          _eventFrameDisappearedAfterFirstPaint(frames),
          isFalse,
          reason:
              'No intermediate frame may clear the warm standalone lane. '
              'frames=$frames',
        );
      },
    );

    testWidgets(
      'startup reminder reconciliation never drops an already visible occurrence',
      (tester) async {
        await _setPhoneViewport(tester);
        await _seedWarmSnapshot(
          title: _reminderTitle,
          isReminder: true,
          reminderId: _reminderUuid,
          allDay: false,
          startMinutes: 20 * 60,
          endMinutes: 20 * 60 + 30,
        );
        _backend.blockRefresh = true;
        _backend.blockReminderLookup = true;
        _backend.freshFlows = <Map<String, Object?>>[_reminderFlowRow()];
        addTearDown(_backend.releaseReminderLookup);

        final frames = <String>[];
        await _pumpCalendar(tester);
        frames.add(_visibleFrameContaining(tester, _reminderTitle));

        expect(find.textContaining(_reminderTitle), findsOneWidget);

        _backend.release();
        for (var i = 0; i < 80; i++) {
          await tester.pump(const Duration(milliseconds: 25));
          if (i % 4 == 0) {
            await tester.runAsync<void>(() async {
              await Future<void>.delayed(Duration.zero);
            });
          }
          frames.add(_visibleFrameContaining(tester, _reminderTitle));
        }

        expect(
          find.textContaining(_reminderTitle),
          findsOneWidget,
          reason:
              'A reminder already visible from warm state must stay visible '
              'while its fresh occurrence is reconciled. frames=$frames',
        );
        expect(
          _eventFrameDisappearedAfterFirstPaint(frames),
          isFalse,
          reason:
              'Fresh hydration must not publish a temporary reminder-free '
              'calendar frame. frames=$frames',
        );

        _backend.releaseReminderLookup();
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 25));
          if (i % 4 == 0) {
            await tester.runAsync<void>(() async {
              await Future<void>.delayed(Duration.zero);
            });
          }
          frames.add(_visibleFrameContaining(tester, _reminderTitle));
          expect(
            find.textContaining(_reminderTitle).evaluate().length,
            lessThanOrEqualTo(1),
            reason: 'Reminder reconciliation must remain idempotent.',
          );
        }

        expect(find.textContaining(_reminderTitle), findsOneWidget);
        expect(_eventFrameDisappearedAfterFirstPaint(frames), isFalse);
      },
    );

    testWidgets(
      'authoritative standalone empty result removes warm event after partial preservation',
      (tester) async {
        const title = 'Journal every day';
        await _setPhoneViewport(tester);
        await _seedWarmSnapshot(title: title);
        _backend.blockRefresh = true;
        _backend.freshStandaloneEvents = const <Map<String, Object?>>[];

        final partialFrames = <String>[];
        await _pumpCalendar(tester);
        partialFrames.add(_visibleFrameForTitle(tester, title));

        expect(
          find.text(title),
          findsOneWidget,
          reason:
              'The warm standalone event must paint before the startup '
              'backfill completes. frames=$partialFrames requests=${_backend.requestLog}',
        );

        _backend.release();
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          if (i % 4 == 0) {
            await tester.runAsync<void>(() async {
              await Future<void>.delayed(Duration.zero);
            });
          }
          partialFrames.add(_visibleFrameForTitle(tester, title));
          expect(
            _visibleTitleCount(tester, title),
            lessThanOrEqualTo(1),
            reason:
                'Partial-authority preservation must not duplicate the warm '
                'standalone lane. frames=$partialFrames',
          );
        }

        expect(
          find.text(title),
          findsOneWidget,
          reason:
              'The partial startup backfill omitted standalone rows but must '
              'not remove the painted warm event. frames=$partialFrames',
        );
        expect(
          _eventFrameDisappearedAfterFirstPaint(partialFrames),
          isFalse,
          reason:
              'No disappearance is allowed before an authoritative standalone '
              'load has completed. frames=$partialFrames',
        );

        final authoritativeFrames = <String>[];
        CalendarInvalidationBus.instance.publish(
          const CalendarInvalidated(
            reason: CalendarInvalidationReason.eventSaved,
          ),
        );
        await _pumpUntilTitleGone(tester, title, authoritativeFrames);

        expect(
          find.text(title),
          findsNothing,
          reason:
              'Once a later authoritative standalone hydration returns empty, '
              'the stale warm standalone event must be removed. '
              'partial=$partialFrames authoritative=$authoritativeFrames '
              'requests=${_backend.requestLog}',
        );
        expect(
          _visibleTitleCount(tester, title),
          0,
          reason:
              'Authoritative removal must leave no duplicate or stale visible '
              'copy behind. frames=$authoritativeFrames',
        );
      },
    );

    testWidgets('failed refresh keeps cached state visible', (tester) async {
      await _setPhoneViewport(tester);
      await _seedWarmSnapshot(title: _cachedTitle);
      _backend.blockRefresh = true;
      _backend.failRefresh = true;

      final frames = <String>[];
      await _pumpCalendar(tester);
      frames.add(_visibleFrame(tester));

      expect(
        find.text(_cachedTitle),
        findsOneWidget,
        reason:
            'Cached event must be visible before a failing refresh completes. '
            'frames=$frames',
      );

      _backend.release();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        frames.add(_visibleFrame(tester));
      }

      expect(find.text(_cachedTitle), findsOneWidget);
      expect(
        frames,
        isNot(anyOf(contains('blank'), contains('empty'))),
        reason:
            'A failed refresh must not destructively reset visible cached '
            'state. frames=$frames',
      );
    });

    testWidgets(
      'flow-lane failure cannot publish or persist an empty replacement',
      (tester) async {
        await _setPhoneViewport(tester);
        await _seedWarmSnapshot(title: _cachedTitle);
        final before = await _readWarmSnapshotRaw();
        _backend
          ..freshFlows = <Map<String, Object?>>[_coldFlowRow()]
          ..failFlowEventRefresh = true;

        final frames = <String>[];
        await _pumpCalendar(tester);
        for (var i = 0; i < 80; i++) {
          await tester.pump(const Duration(milliseconds: 25));
          if (i % 4 == 0) {
            await tester.runAsync<void>(() async {
              await Future<void>.delayed(Duration.zero);
            });
          }
          frames.add(_visibleFrame(tester));
        }

        expect(find.text(_cachedTitle), findsOneWidget);
        expect(frames, isNot(contains('empty')));
        expect(before, isNotNull);
        final after = jsonDecode((await _readWarmSnapshotRaw())!) as Map;
        expect(after['eventCount'], 1);
        expect(_snapshotTitles(after), contains(_cachedTitle));
      },
    );

    testWidgets(
      'standalone-lane failure cannot publish or persist an empty replacement',
      (tester) async {
        await _setPhoneViewport(tester);
        await _seedWarmSnapshot(title: _cachedTitle);
        final before = await _readWarmSnapshotRaw();
        _backend.failStandaloneRefresh = true;

        final frames = <String>[];
        await _pumpCalendar(tester);
        for (var i = 0; i < 80; i++) {
          await tester.pump(const Duration(milliseconds: 25));
          if (i % 4 == 0) {
            await tester.runAsync<void>(() async {
              await Future<void>.delayed(Duration.zero);
            });
          }
          frames.add(_visibleFrame(tester));
        }

        expect(find.text(_cachedTitle), findsOneWidget);
        expect(frames, isNot(contains('empty')));
        expect(before, isNotNull);
        final after = jsonDecode((await _readWarmSnapshotRaw())!) as Map;
        expect(after['eventCount'], 1);
        expect(_snapshotTitles(after), contains(_cachedTitle));
      },
    );

    testWidgets(
      'valid empty warm snapshot paints shell until fresh state arrives',
      (tester) async {
        await _setPhoneViewport(tester);
        await _seedWarmSnapshot(includeEvent: false);
        _backend.blockRefresh = true;
        _backend.freshStandaloneEvents = <Map<String, Object?>>[
          _standaloneEventRow(title: _freshTitle),
        ];

        final frames = <String>[];
        await _pumpCalendar(tester);
        frames.add(_visibleFrame(tester));

        expect(_hasCalendarBody(tester), isTrue);
        expect(
          frames,
          isNot(contains('blank')),
          reason:
              'A valid empty snapshot is usable state and must paint the '
              'calendar shell before delayed fresh repositories finish. '
              'frames=$frames',
        );
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: 'A valid empty snapshot should not be treated as first load.',
        );

        await _releaseAndPumpUntilTextVisible(tester, _freshTitle, frames);

        expect(find.text(_freshTitle), findsOneWidget);
        expect(
          frames,
          isNot(contains('blank')),
          reason:
              'Fresh reconciliation after an empty snapshot must not hide the '
              'calendar shell. frames=$frames',
        );
      },
    );

    testWidgets(
      'no warm snapshot shows a restrained first-load indicator instead of a blank page',
      (tester) async {
        await _setPhoneViewport(tester);
        _backend.blockRefresh = true;

        await _pumpCalendar(tester);
        final frame = _visibleFrame(tester);

        expect(
          find.byType(CircularProgressIndicator),
          findsOneWidget,
          reason:
              'No warm snapshot may show a first-load indicator, but should '
              'not render a blank SizedBox. frame=$frame',
        );
        expect(_hasCalendarBody(tester), isTrue, reason: 'frame=$frame');
      },
    );

    testWidgets(
      'durable last-good restores after page and retained-memory destruction',
      (tester) async {
        await _setPhoneViewport(tester);
        _backend.freshStandaloneEvents = <Map<String, Object?>>[
          _standaloneEventRow(title: _freshTitle),
        ];

        await _pumpCalendar(tester);
        final frames = <String>[];
        await _pumpUntilTextVisible(tester, _freshTitle, frames, maxPumps: 240);
        expect(find.text(_freshTitle), findsOneWidget);

        String? durable;
        for (var i = 0; i < 80 && durable == null; i++) {
          await tester.pump(const Duration(milliseconds: 25));
          durable = await _readWarmSnapshotRaw();
        }
        expect(durable, isNotNull);

        await tester.pumpWidget(const SizedBox.shrink());
        CalendarSnapshotRepository.instance.clearRetainedSnapshotMemory();
        _backend.blockRefresh = true;

        await tester.pumpWidget(
          MaterialApp(home: CalendarPage(key: UniqueKey())),
        );
        await tester.pump();
        await _pumpWarmRestoreWindow(tester);

        expect(
          find.text(_freshTitle),
          findsOneWidget,
          reason:
              'A new page and empty process mirror must restore the confirmed '
              'durable snapshot before backend completion.',
        );
      },
    );

    testWidgets(
      'far restored viewport survives focused paint and wide backfill',
      (tester) async {
        await _setPhoneViewport(tester);
        final target = _farPastRestorationTarget();
        final targetDate = DateUtils.dateOnly(
          KemeticMath.toGregorian(target.kYear, target.kMonth, target.kDay),
        );
        final focusedOffset = targetDate
            .difference(DateUtils.dateOnly(DateTime.now()))
            .inDays;
        final prefs = await SharedPreferences.getInstance();
        await _seedCalendarRestorationPrefs(prefs, target: target);
        final calendarKey = GlobalKey<CalendarPageState>();
        _backend
          ..freshFlows = <Map<String, Object?>>[_coldFlowRow()]
          ..freshFlowEvents = <Map<String, Object?>>[
            _flowEventRow(title: _focusedColdTitle, dayOffset: focusedOffset),
            _flowEventRow(title: _wideColdTitle, dayOffset: 30),
          ]
          ..blockWideFlowRefresh = true;

        await _pumpCalendar(tester, key: calendarKey);
        for (var i = 0; i < 120 && !_backend.wideFlowRequestStarted; i++) {
          await tester.pump(const Duration(milliseconds: 25));
          if (i % 4 == 0) {
            await tester.runAsync<void>(() async {
              await Future<void>.delayed(Duration.zero);
            });
          }
        }

        expect(
          _backend.wideFlowRequestStarted,
          isTrue,
          reason: 'The fixture must block the non-visible wide backfill.',
        );
        for (
          var i = 0;
          i < 120 &&
              find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 25));
          if (i % 4 == 0) {
            await tester.runAsync<void>(() async {
              await Future<void>.delayed(Duration.zero);
            });
          }
        }
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason:
              'Complete focused coverage is authoritative for first paint; '
              'the broad history request must not hold the calendar blank.',
        );
        expect(
          calendarKey.currentState!.debugLoadedEventTitlesForTesting,
          contains(_focusedColdTitle),
          reason:
              'Focused flow and standalone lanes must publish atomically before '
              'the wide backfill.',
        );

        _backend.releaseWideFlowRefresh();
        for (var i = 0; i < 160; i++) {
          await tester.pump(const Duration(milliseconds: 25));
          if (i % 4 == 0) {
            await tester.runAsync<void>(() async {
              await Future<void>.delayed(Duration.zero);
            });
          }
          final titles =
              calendarKey.currentState?.debugLoadedEventTitlesForTesting;
          if (titles?.containsAll(const <String>{
                    _focusedColdTitle,
                    _wideColdTitle,
                  }) ==
                  true &&
              find.byType(CircularProgressIndicator).evaluate().isEmpty) {
            break;
          }
        }

        final titles =
            calendarKey.currentState!.debugLoadedEventTitlesForTesting;
        expect(
          titles,
          containsAll(const <String>{_focusedColdTitle, _wideColdTitle}),
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          _monthHeaderVisible(tester, target.kMonth),
          isTrue,
          reason:
              'A cold authoritative load must not exhaust restoration retries '
              'before the calendar tree is mounted.',
        );

        String? rawSnapshot;
        for (var i = 0; i < 40 && rawSnapshot == null; i++) {
          await tester.pump(const Duration(milliseconds: 25));
          if (i % 4 == 0) {
            await tester.runAsync<void>(() async {
              await Future<void>.delayed(Duration.zero);
            });
          }
          rawSnapshot = await _readWarmSnapshotRaw();
        }
        expect(rawSnapshot, isNotNull);
        final snapshot = jsonDecode(rawSnapshot!) as Map<String, dynamic>;
        expect(snapshot['schemaVersion'], calendarWarmStartCacheSchemaVersion);
        expect(snapshot['loadCompleted'], isTrue);
        final cachedTitles = <String>{
          for (final bucket in (snapshot['notes'] as Map).values)
            for (final note in bucket as List)
              (note as Map)['title']! as String,
        };
        expect(
          cachedTitles,
          containsAll(const <String>{_focusedColdTitle, _wideColdTitle}),
          reason:
              'The first trusted warm snapshot must contain the complete cold '
              'event candidate.',
        );
      },
    );

    testWidgets(
      'focused calendar paints while durable snapshot promotion is pending',
      (tester) async {
        await _setPhoneViewport(tester);
        final blockingStore = _BlockingCalendarSnapshotStore();
        _snapshotStore = blockingStore;
        CalendarSnapshotRepository.instance.debugReplaceStore(blockingStore);
        final calendarKey = GlobalKey<CalendarPageState>();
        _backend
          ..freshFlows = <Map<String, Object?>>[_coldFlowRow()]
          ..freshFlowEvents = <Map<String, Object?>>[
            _flowEventRow(title: _focusedColdTitle, dayOffset: 0),
          ]
          ..blockWideFlowRefresh = true;

        try {
          await _pumpCalendar(tester, key: calendarKey);
          for (
            var i = 0;
            i < 160 &&
                (!blockingStore.writeStarted ||
                    !_backend.wideFlowRequestStarted);
            i++
          ) {
            await tester.pump(const Duration(milliseconds: 25));
            if (i % 4 == 0) {
              await tester.runAsync<void>(() async {
                await Future<void>.delayed(Duration.zero);
              });
            }
          }
          await tester.pump();

          expect(blockingStore.writeStarted, isTrue);
          expect(
            _backend.wideFlowRequestStarted,
            isTrue,
            reason:
                'Durable promotion must not serialize the independent wide '
                'backfill behind storage latency.',
          );
          expect(
            calendarKey.currentState!.debugLoadedEventTitlesForTesting,
            contains(_focusedColdTitle),
          );
          expect(
            find.byType(CircularProgressIndicator),
            findsNothing,
            reason:
                'A confirmed complete in-memory candidate must paint before '
                'its durable last-good promotion finishes.',
          );
        } finally {
          blockingStore.releaseWrites();
          _backend.releaseWideFlowRefresh();
          await tester.pump();
        }
      },
    );

    testWidgets(
      'disposing during cold hydration cannot persist a flow-only warm snapshot',
      (tester) async {
        await _setPhoneViewport(tester);
        final calendarKey = GlobalKey<CalendarPageState>();
        _backend
          ..freshFlows = <Map<String, Object?>>[_coldFlowRow()]
          ..freshFlowEvents = <Map<String, Object?>>[
            _flowEventRow(title: _focusedColdTitle, dayOffset: 0),
          ]
          ..freshStandaloneEvents = <Map<String, Object?>>[
            _standaloneEventRow(title: _standaloneColdTitle),
          ]
          ..blockStandaloneRefresh = true;

        await _pumpCalendar(tester, key: calendarKey);
        for (var i = 0; i < 120 && !_backend.standaloneRequestStarted; i++) {
          await tester.pump(const Duration(milliseconds: 25));
          if (i % 4 == 0) {
            await tester.runAsync<void>(() async {
              await Future<void>.delayed(Duration.zero);
            });
          }
        }
        for (var i = 0; i < 32; i++) {
          await tester.pump(const Duration(milliseconds: 25));
          if (i % 4 == 0) {
            await tester.runAsync<void>(() async {
              await Future<void>.delayed(Duration.zero);
            });
          }
        }

        expect(
          _backend.standaloneRequestStarted,
          isTrue,
          reason: 'The fixture must hold the standalone lane open.',
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          calendarKey.currentState!.debugLoadedEventTitlesForTesting,
          isEmpty,
          reason:
              'A cold candidate is not authoritative until both flow and '
              'standalone lanes finish.',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync<void>(() async {
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pump();

        expect(
          await _readWarmSnapshotRaw(),
          isNull,
          reason:
              'Disposal must not flush a partial event candidate as a trusted '
              'warm-start snapshot.',
        );
      },
    );

    testWidgets('large authoritative calendar remains eligible for warm cache', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      final largeDetail = List<String>.filled(2000, 'x').join();
      _backend.freshStandaloneEvents = <Map<String, Object?>>[
        for (var index = 0; index < 480; index++)
          _standaloneEventRow(
            id: 'large-event-$index',
            clientEventId: 'large-event-cid-$index',
            title: 'Large warm event $index',
            detail: largeDetail,
            target: KemeticMath.fromGregorian(
              DateTime.now().add(Duration(days: index % 360)),
            ),
          ),
      ];

      await _pumpCalendar(tester);
      String? rawSnapshot;
      for (var i = 0; i < 300 && rawSnapshot == null; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        if (i % 4 == 0) {
          await tester.runAsync<void>(() async {
            await Future<void>.delayed(Duration.zero);
          });
        }
        rawSnapshot = await _readWarmSnapshotRaw();
      }

      expect(
        rawSnapshot,
        isNotNull,
        reason:
            'A production-sized authoritative snapshot must not silently lose '
            'warm-start eligibility and force every launch through cold fetch.',
      );
      expect(rawSnapshot!.length, greaterThan(850000));
    });
  });

  group('CalendarPage warm-start cache boundaries', () {
    testWidgets('wrong user warm snapshot is rejected', (tester) async {
      await _setPhoneViewport(tester);
      await _seedWarmSnapshot(
        title: _rejectedTitle,
        snapshotUserId: 'other-user',
      );
      _backend.blockRefresh = true;

      await _pumpCalendar(tester);
      await _pumpWarmRestoreWindow(tester);

      expect(find.text(_rejectedTitle), findsNothing);
    });

    testWidgets('wrong Supabase project warm snapshot is rejected', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      await _seedWarmSnapshot(
        title: _rejectedTitle,
        supabaseUrl: 'https://other-project.supabase.co',
      );
      _backend.blockRefresh = true;

      await _pumpCalendar(tester);
      await _pumpWarmRestoreWindow(tester);

      expect(
        find.text(_rejectedTitle),
        findsNothing,
        reason:
            'Warm cache must be scoped to the current Supabase project URL.',
      );
    });

    testWidgets('unsupported warm snapshot schema version is rejected', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      await _seedWarmSnapshot(title: _rejectedTitle, schemaVersion: 999);
      _backend.blockRefresh = true;

      await _pumpCalendar(tester);
      await _pumpWarmRestoreWindow(tester);

      expect(
        find.text(_rejectedTitle),
        findsNothing,
        reason: 'Unsupported warm cache schema versions should cold-load once.',
      );
    });

    testWidgets('legacy v2 warm snapshot is rejected after authority upgrade', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      await _seedWarmSnapshot(title: _rejectedTitle, schemaVersion: 2);
      _backend.blockRefresh = true;

      await _pumpCalendar(tester);
      await _pumpWarmRestoreWindow(tester);

      expect(
        find.text(_rejectedTitle),
        findsNothing,
        reason:
            'V2 snapshots may have been persisted from a flow-only candidate '
            'and must cold-load once under the authoritative schema.',
      );
    });

    testWidgets('v3 snapshot without lane integrity is rejected', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      await _seedWarmSnapshot(title: _rejectedTitle, schemaVersion: 3);
      _backend.blockRefresh = true;

      await _pumpCalendar(tester);
      await _pumpWarmRestoreWindow(tester);

      expect(
        find.text(_rejectedTitle),
        findsNothing,
        reason:
            'V3 stamped transport completion without coverage or lane '
            'integrity and must cold-load once.',
      );
    });

    testWidgets('corrupt warm snapshot payload is rejected safely', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      await CalendarSnapshotRepository.instance.debugWriteRaw(
        _currentSnapshotIdentity(),
        '{not valid json',
      );
      _backend.blockRefresh = true;

      await _pumpCalendar(tester);
      await _pumpWarmRestoreWindow(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(_rejectedTitle), findsNothing);
    });
  });
}

Future<void> _pumpCalendar(WidgetTester tester, {Key? key}) async {
  addTearDown(() async {
    _backend.release();
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 8; i++) {
      _backend.release();
      await tester.pump(const Duration(milliseconds: 250));
    }
  });
  await tester.pumpWidget(
    MaterialApp(home: CalendarPage(key: key ?? UniqueKey())),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
}

Future<void> _pumpWarmRestoreWindow(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _releaseAndPumpUntilTextVisible(
  WidgetTester tester,
  String text,
  List<String> frames,
) async {
  _backend.release();
  await _pumpUntilTextVisible(tester, text, frames, maxPumps: 600);
}

Future<void> _pumpUntilTextVisible(
  WidgetTester tester,
  String text,
  List<String> frames, {
  int maxPumps = 80,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    if (i % 4 == 0) {
      await tester.runAsync<void>(() async {
        await Future<void>.delayed(Duration.zero);
      });
    }
    frames.add(_visibleFrame(tester));
    if (find.text(text).evaluate().isNotEmpty) {
      return;
    }
  }
}

bool _hasCalendarBody(WidgetTester tester) {
  return find.byType(Scaffold).evaluate().isNotEmpty;
}

String _visibleFrame(WidgetTester tester) {
  if (!_hasCalendarBody(tester)) return 'blank';
  if (find.text(_freshTitle).evaluate().isNotEmpty) return 'fresh';
  if (find.text(_cachedTitle).evaluate().isNotEmpty) return 'cached';
  if (find.text(_rejectedTitle).evaluate().isNotEmpty) return 'rejected';
  if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
    return 'loading';
  }
  return 'empty';
}

String _visibleFrameForTitle(WidgetTester tester, String title) {
  if (!_hasCalendarBody(tester)) return 'blank';
  if (find.text(title).evaluate().isNotEmpty) return 'event';
  if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
    return 'loading';
  }
  return 'empty';
}

String _visibleFrameContaining(WidgetTester tester, String text) {
  if (!_hasCalendarBody(tester)) return 'blank';
  if (find.textContaining(text).evaluate().isNotEmpty) return 'event';
  if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
    return 'loading';
  }
  return 'empty';
}

bool _eventFrameDisappearedAfterFirstPaint(List<String> frames) {
  var painted = false;
  for (final frame in frames) {
    if (frame == 'event') {
      painted = true;
      continue;
    }
    if (painted && frame == 'empty') return true;
  }
  return false;
}

int _visibleTitleCount(WidgetTester tester, String title) {
  return find.text(title).evaluate().length;
}

Future<void> _pumpUntilTitleGone(
  WidgetTester tester,
  String title,
  List<String> frames, {
  int maxPumps = 120,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (i % 4 == 0) {
      await tester.runAsync<void>(() async {
        await Future<void>.delayed(Duration.zero);
      });
    }
    frames.add(_visibleFrameForTitle(tester, title));
    if (find.text(title).evaluate().isEmpty) {
      return;
    }
  }
}

Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(900, 1200);
  addTearDown(() async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _seedWarmSnapshot({
  String title = _cachedTitle,
  bool includeEvent = true,
  bool isReminder = false,
  String? reminderId,
  bool allDay = true,
  int? startMinutes,
  int? endMinutes,
  String snapshotUserId = _testUserId,
  String supabaseUrl = _supabaseUrl,
  int schemaVersion = calendarWarmStartCacheSchemaVersion,
  bool loadCompleted = true,
  bool replaceRetainedMemory = true,
  ({int kYear, int kMonth, int kDay})? target,
}) async {
  final projectRef = calendarWarmStartProjectRefFromUrl(supabaseUrl);
  if (projectRef == null) {
    throw StateError('Test Supabase URL must produce a project ref.');
  }
  final candidateIdentity = CalendarSnapshotIdentity(
    projectRef: projectRef,
    userId: snapshotUserId,
  );
  final kTarget = target ?? KemeticMath.fromGregorian(DateTime.now());
  final targetMonthStart = DateUtils.dateOnly(
    KemeticMath.toGregorian(kTarget.kYear, kTarget.kMonth, 1),
  );
  final targetMonthEnd = DateUtils.dateOnly(
    KemeticMath.toGregorian(
      kTarget.kYear,
      kTarget.kMonth,
      kTarget.kMonth == 13 ? 5 : 30,
    ),
  );
  final repository = CalendarSnapshotRepository.instance;
  final encoded = repository.encodeCandidate(
    CalendarSnapshotCandidate(
      identity: candidateIdentity,
      coverage: CalendarSnapshotCoverage(
        startUtc: targetMonthStart.subtract(const Duration(days: 45)).toUtc(),
        endUtc: targetMonthEnd.add(const Duration(days: 61)).toUtc(),
      ),
      completedLanes: calendarSnapshotRequiredLanes,
      generation: 1,
      payload: Map<String, dynamic>.from(
        _warmSnapshot(
          title: title,
          includeEvent: includeEvent,
          isReminder: isReminder,
          reminderId: reminderId,
          allDay: allDay,
          startMinutes: startMinutes,
          endMinutes: endMinutes,
          target: target,
        ),
      ),
      source: 'test_seed',
    ),
  );
  final decoded = jsonDecode(encoded) as Map<String, dynamic>;
  decoded['schemaVersion'] = schemaVersion;
  decoded['loadCompleted'] = loadCompleted;
  final raw = jsonEncode(decoded);
  if (replaceRetainedMemory) {
    await repository.debugWriteRaw(_currentSnapshotIdentity(), raw);
  } else {
    _snapshotStore.values[_currentSnapshotIdentity().storageKey] = raw;
  }
}

Future<void> _seedCalendarRestorationPrefs(
  SharedPreferences prefs, {
  ({int kYear, int kMonth, int kDay})? target,
}) async {
  final kToday = KemeticMath.fromGregorian(DateTime.now());
  final restored = target ?? kToday;
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final raw = <String, Object?>{
    'schemaVersion': AppRestorationService.schemaVersion,
    'userId': _testUserId,
    'windowId': _testWindowId,
    'updatedAtMs': nowMs,
    'calendar': <String, Object?>{
      'kYear': restored.kYear,
      'kMonth': restored.kMonth,
      'kDay': restored.kDay,
      'showGregorian': false,
      'expansion': 'details',
      'anchorTarget': 'dayChip',
      'anchorAlignment': 0.5,
      'viewportHeight': 1200.0,
      'layoutRevision': 1,
    },
  };

  final encoded = jsonEncode(raw);
  await prefs.setString(
    'app_restoration_v1:$_testUserId:$_testWindowId',
    encoded,
  );
  await prefs.setString('app_restoration_latest_v2:$_testUserId', encoded);
  await prefs.setString('app_restoration_last_user_v2', _testUserId);
}

CalendarSnapshotIdentity _currentSnapshotIdentity() {
  final projectRef = calendarWarmStartProjectRefFromUrl(_supabaseUrl);
  if (projectRef == null) {
    throw StateError('Test Supabase URL must produce a project ref.');
  }
  return CalendarSnapshotIdentity(projectRef: projectRef, userId: _testUserId);
}

Future<String?> _readWarmSnapshotRaw() => CalendarSnapshotRepository.instance
    .debugReadRaw(_currentSnapshotIdentity());

Set<String> _snapshotTitles(Map<dynamic, dynamic> snapshot) => <String>{
  for (final bucket in (snapshot['notes'] as Map).values)
    for (final note in bucket as List) (note as Map)['title']! as String,
};

Map<String, Object?> _warmSnapshot({
  required String title,
  required bool includeEvent,
  bool isReminder = false,
  String? reminderId,
  bool allDay = true,
  int? startMinutes,
  int? endMinutes,
  ({int kYear, int kMonth, int kDay})? target,
}) {
  final kToday = KemeticMath.fromGregorian(DateTime.now());
  final eventDate = target ?? kToday;
  return <String, Object?>{
    'nextFlowId': 1,
    'flows': const <Object?>[],
    'notes': includeEvent
        ? <String, Object?>{
            '${eventDate.kYear}-${eventDate.kMonth}-${eventDate.kDay}':
                <Object?>[
                  <String, Object?>{
                    'id': 'warm-event-1',
                    'clientEventId': _clientEventId,
                    'title': title,
                    'detail': 'Warm cached event',
                    'allDay': allDay,
                    'startMinutes': startMinutes,
                    'endMinutes': endMinutes,
                    'flowId': -1,
                    'resolvedColor': 0xFFB0B6C3,
                    'category': 'note',
                    'isReminder': isReminder,
                    'reminderId': reminderId,
                  },
                ],
          }
        : const <String, Object?>{},
    'calendarSummaries': const <Object?>[],
    'hiddenCalendarIds': const <String>[],
    'personalCalendarId': null,
    'flowTotalEventCounts': const <String, Object?>{},
    'flowRemainingEventCounts': const <String, Object?>{},
  };
}

Map<String, Object?> _standaloneEventRow({
  required String title,
  ({int kYear, int kMonth, int kDay})? target,
  String id = 'fresh-event-1',
  String clientEventId = _clientEventId,
  String detail = 'Fresh backend event',
}) {
  final kToday = KemeticMath.fromGregorian(DateTime.now());
  final eventDate = target ?? kToday;
  final start = KemeticMath.toGregorian(
    eventDate.kYear,
    eventDate.kMonth,
    eventDate.kDay,
  ).toUtc();
  return <String, Object?>{
    'id': id,
    'calendar_id': null,
    'calendar_name': null,
    'calendar_color': null,
    'calendar_is_personal': true,
    'client_event_id': clientEventId,
    'title': title,
    'detail': detail,
    'location': null,
    'all_day': true,
    'starts_at': start.toIso8601String(),
    'ends_at': start.add(const Duration(hours: 1)).toIso8601String(),
    'flow_local_id': null,
    'filed_flow_id': null,
    'item_kind': 'note',
    'category': 'note',
    'action_id': null,
    'behavior_payload': null,
  };
}

Map<String, Object?> _coldFlowRow() {
  final now = DateTime.now().toUtc();
  return <String, Object?>{
    'id': _coldFlowId,
    'user_id': _testUserId,
    'calendar_id': null,
    'name': 'Cold-start authority fixture',
    'color': 0xFFD4AF37,
    'active': true,
    'is_saved': false,
    'start_date': now.subtract(const Duration(days: 30)).toIso8601String(),
    'end_date': now.add(const Duration(days: 220)).toIso8601String(),
    'notes': null,
    'rules': const <Object?>[],
    'share_id': null,
    'is_hidden': false,
    'is_reminder': false,
    'reminder_uuid': null,
    'created_at': now.toIso8601String(),
    'updated_at': now.toIso8601String(),
  };
}

Map<String, Object?> _reminderFlowRow() {
  final now = DateTime.now();
  final rule = <String, Object?>{
    'id': _reminderUuid,
    'calendarId': null,
    'title': _reminderTitle,
    'startLocal': DateUtils.dateOnly(
      now.subtract(const Duration(days: 30)),
    ).add(const Duration(hours: 20)).toIso8601String(),
    'endLocal': DateUtils.dateOnly(now).toIso8601String(),
    'allDay': false,
    'color': 0xFFB0B6C3,
    'category': 'note',
    'active': true,
    'repeat': const <String, Object?>{
      'kind': 'everyNDays',
      'interval': 1,
      'weekdays': <int>[],
      'monthDay': null,
      'monthDays': <int>[],
      'decanDays': <int>[],
      'kemeticMonthDays': <int>[],
    },
    'alertOffsetMinutes': -1,
  };
  return <String, Object?>{
    'id': _reminderFlowId,
    'user_id': _testUserId,
    'calendar_id': null,
    'name': _reminderTitle,
    'color': 0xFFB0B6C3,
    'active': true,
    'is_saved': false,
    'start_date': now.subtract(const Duration(days: 30)).toIso8601String(),
    'end_date': now.toIso8601String(),
    'notes': jsonEncode(rule),
    'rules': const <Object?>[],
    'share_id': null,
    'is_hidden': false,
    'is_reminder': true,
    'reminder_uuid': _reminderUuid,
    'created_at': now.toUtc().toIso8601String(),
    'updated_at': now.toUtc().toIso8601String(),
  };
}

Map<String, Object?> _flowEventRow({
  required String title,
  required int dayOffset,
}) {
  final start = DateUtils.dateOnly(
    DateTime.now().add(Duration(days: dayOffset)),
  ).toUtc();
  return <String, Object?>{
    'id': 'flow-event-$dayOffset',
    'calendar_id': null,
    'calendar_name': null,
    'calendar_color': null,
    'calendar_is_personal': true,
    'client_event_id': 'cold-flow-event-$dayOffset',
    'title': title,
    'detail': 'Cold-start fixture event',
    'location': null,
    'all_day': true,
    'starts_at': start.toIso8601String(),
    'ends_at': start.add(const Duration(hours: 1)).toIso8601String(),
    'flow_local_id': _coldFlowId,
    'filed_flow_id': _coldFlowId,
    'item_kind': 'flow',
    'category': 'flow',
    'action_id': null,
    'behavior_payload': null,
  };
}

({int kYear, int kMonth, int kDay}) _nonTodayRestorationTarget(
  ({int kYear, int kMonth, int kDay}) today,
) {
  final targetMonth = today.kMonth == 8 ? 5 : 8;
  return (kYear: today.kYear, kMonth: targetMonth, kDay: 18);
}

({int kYear, int kMonth, int kDay}) _farPastRestorationTarget() {
  final target = KemeticMath.fromGregorian(
    DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 730)),
  );
  return (kYear: target.kYear, kMonth: target.kMonth, kDay: target.kDay);
}

Future<void> _recordMovementFrame(
  WidgetTester tester,
  List<_CalendarMovementFrame> frames, {
  required ({int kYear, int kMonth, int kDay}) today,
  required ({int kYear, int kMonth, int kDay}) target,
}) async {
  final cachedEventFinder = find.text(_cachedTitle);
  final freshEventFinder = find.text(_freshTitle);
  final cachedEventVisible = _finderVisibleInViewport(
    tester,
    cachedEventFinder,
  );
  final freshEventVisible = _finderVisibleInViewport(tester, freshEventFinder);
  final loading = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
  final hasScaffold = find.byType(Scaffold).evaluate().isNotEmpty;
  final startupSingleMonthVisible = find
      .byKey(const PageStorageKey('calendar_portrait_scroll_startup_month'))
      .evaluate()
      .isNotEmpty;
  final fullCalendarScrollVisible = find
      .byKey(const PageStorageKey('calendar_portrait_scroll'))
      .evaluate()
      .isNotEmpty;
  final savedMonthVisible = _monthHeaderVisible(tester, target.kMonth);
  final todayMonthVisible = _monthHeaderVisible(tester, today.kMonth);
  final cachedEventTop = cachedEventVisible
      ? _firstVisibleTop(tester, cachedEventFinder)
      : null;
  frames.add(
    _CalendarMovementFrame(
      index: frames.length,
      hasScaffold: hasScaffold,
      loading: loading,
      startupSingleMonthVisible: startupSingleMonthVisible,
      fullCalendarScrollVisible: fullCalendarScrollVisible,
      savedMonthVisible: savedMonthVisible,
      todayMonthVisible: todayMonthVisible,
      cachedEventVisible: cachedEventVisible,
      freshEventVisible: freshEventVisible,
      cachedEventTop: cachedEventTop,
    ),
  );
}

bool _monthHeaderVisible(WidgetTester tester, int kMonth) {
  final month = getMonthById(kMonth);
  return _finderVisibleInViewport(tester, find.text(month.displayShort)) ||
      _finderVisibleInViewport(
        tester,
        find.text('(${month.displayTransliteration})'),
      );
}

bool _finderVisibleInViewport(WidgetTester tester, Finder finder) {
  return _firstVisibleTop(tester, finder) != null;
}

double? _firstVisibleTop(WidgetTester tester, Finder finder) {
  final viewport = Offset.zero & tester.view.physicalSize;
  final matches = finder.evaluate().toList(growable: false);
  for (var i = 0; i < matches.length; i++) {
    try {
      final rect = tester.getRect(finder.at(i));
      if (rect.overlaps(viewport) && rect.width > 0 && rect.height > 0) {
        return rect.top;
      }
    } catch (_) {
      // A lazily disposed sliver child is not a visible match.
    }
  }
  return null;
}

bool _cachedEventDisappearedAfterFirstPaint(
  List<_CalendarMovementFrame> frames,
) {
  var painted = false;
  for (final frame in frames) {
    if (frame.loading) continue;
    if (frame.cachedEventVisible) painted = true;
    if (painted && !frame.cachedEventVisible && !frame.freshEventVisible) {
      return true;
    }
  }
  return false;
}

bool _cachedEventShiftedAfterFirstPaint(List<_CalendarMovementFrame> frames) {
  double? firstTop;
  for (final frame in frames) {
    if (frame.loading) continue;
    final top = frame.cachedEventTop;
    if (top == null) continue;
    firstTop ??= top;
    if ((top - firstTop).abs() > 2.0) {
      return true;
    }
  }
  return false;
}

String _movementFrameSummary(List<_CalendarMovementFrame> frames) {
  return frames
      .map(
        (frame) =>
            '#${frame.index}:${frame.label}'
            '${frame.cachedEventTop == null ? '' : '@${frame.cachedEventTop!.toStringAsFixed(1)}'}',
      )
      .join(' -> ');
}

class _CalendarMovementFrame {
  const _CalendarMovementFrame({
    required this.index,
    required this.hasScaffold,
    required this.loading,
    required this.startupSingleMonthVisible,
    required this.fullCalendarScrollVisible,
    required this.savedMonthVisible,
    required this.todayMonthVisible,
    required this.cachedEventVisible,
    required this.freshEventVisible,
    required this.cachedEventTop,
  });

  final int index;
  final bool hasScaffold;
  final bool loading;
  final bool startupSingleMonthVisible;
  final bool fullCalendarScrollVisible;
  final bool savedMonthVisible;
  final bool todayMonthVisible;
  final bool cachedEventVisible;
  final bool freshEventVisible;
  final double? cachedEventTop;

  bool get meaningful => hasScaffold && !loading;
  bool get emptyVisible =>
      meaningful && !cachedEventVisible && !freshEventVisible;
  bool get todayOnlyVisible =>
      meaningful && todayMonthVisible && !savedMonthVisible;

  String get label {
    if (!hasScaffold) return 'blank';
    if (loading) return 'loading';
    final month = savedMonthVisible
        ? 'saved'
        : todayMonthVisible
        ? 'today'
        : 'unknown';
    final event = freshEventVisible
        ? 'fresh'
        : cachedEventVisible
        ? 'cached'
        : 'empty';
    final mode = fullCalendarScrollVisible
        ? 'full'
        : startupSingleMonthVisible
        ? 'single'
        : 'none';
    return '$mode/$month/$event';
  }
}

Future<void> _recoverTestSession() async {
  final expiresAt =
      DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/
      1000;
  await Supabase.instance.client.auth.recoverSession(
    jsonEncode(<String, Object?>{
      'access_token': 'test-access-token-$expiresAt',
      'expires_in': 31536000,
      'refresh_token': 'test-refresh-token',
      'token_type': 'bearer',
      'user': <String, Object?>{
        'id': _testUserId,
        'app_metadata': <String, Object?>{
          'provider': 'email',
          'providers': <String>['email'],
        },
        'user_metadata': <String, Object?>{},
        'aud': 'authenticated',
        'email': 'calendar-swr-test@example.com',
        'phone': '',
        'created_at': '2026-01-01T00:00:00.000000Z',
        'email_confirmed_at': '2026-01-01T00:00:00.000000Z',
        'role': 'authenticated',
        'updated_at': '2026-01-01T00:00:00.000000Z',
      },
      'expiresAt': expiresAt,
    }),
  );
}

class _BlockingCalendarSnapshotStore extends MemoryCalendarSnapshotStore {
  final Completer<void> _writeStarted = Completer<void>();
  final Completer<void> _releaseWrites = Completer<void>();

  bool get writeStarted => _writeStarted.isCompleted;

  void releaseWrites() {
    if (!_releaseWrites.isCompleted) {
      _releaseWrites.complete();
    }
  }

  @override
  Future<void> write(String key, String value) async {
    if (!_writeStarted.isCompleted) {
      _writeStarted.complete();
    }
    await _releaseWrites.future;
    await super.write(key, value);
  }
}

class _CalendarSwrBackend extends http.BaseClient {
  Completer<void> _release = Completer<void>();
  Completer<void> _wideFlowRelease = Completer<void>();
  Completer<void> _standaloneRelease = Completer<void>();
  Completer<void> _reminderLookupRelease = Completer<void>();
  final List<String> requestLog = <String>[];
  List<Map<String, Object?>> freshStandaloneEvents = const [];
  List<Map<String, Object?>> freshFlows = const [];
  List<Map<String, Object?>> freshFlowEvents = const [];
  bool blockRefresh = false;
  bool blockWideFlowRefresh = false;
  bool wideFlowRequestStarted = false;
  bool blockStandaloneRefresh = false;
  bool standaloneRequestStarted = false;
  bool blockReminderLookup = false;
  bool reminderLookupStarted = false;
  bool failRefresh = false;
  bool failFlowEventRefresh = false;
  bool failStandaloneRefresh = false;

  void reset() {
    if (!_release.isCompleted) {
      _release.complete();
    }
    if (!_wideFlowRelease.isCompleted) {
      _wideFlowRelease.complete();
    }
    if (!_standaloneRelease.isCompleted) {
      _standaloneRelease.complete();
    }
    if (!_reminderLookupRelease.isCompleted) {
      _reminderLookupRelease.complete();
    }
    _release = Completer<void>();
    _wideFlowRelease = Completer<void>();
    _standaloneRelease = Completer<void>();
    _reminderLookupRelease = Completer<void>();
    requestLog.clear();
    freshStandaloneEvents = const [];
    freshFlows = const [];
    freshFlowEvents = const [];
    blockRefresh = false;
    blockWideFlowRefresh = false;
    wideFlowRequestStarted = false;
    blockStandaloneRefresh = false;
    standaloneRequestStarted = false;
    blockReminderLookup = false;
    reminderLookupStarted = false;
    failRefresh = false;
    failFlowEventRefresh = false;
    failStandaloneRefresh = false;
  }

  void release() {
    if (!_release.isCompleted) {
      _release.complete();
    }
    releaseWideFlowRefresh();
    releaseStandaloneRefresh();
  }

  void releaseWideFlowRefresh() {
    if (!_wideFlowRelease.isCompleted) {
      _wideFlowRelease.complete();
    }
  }

  void releaseStandaloneRefresh() {
    if (!_standaloneRelease.isCompleted) {
      _standaloneRelease.complete();
    }
  }

  void releaseReminderLookup() {
    if (!_reminderLookupRelease.isCompleted) {
      _reminderLookupRelease.complete();
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestLog.add('${request.method} ${request.url}');
    final path = request.url.path;

    if (path.contains('/auth/v1/')) {
      return _json(request, <String, Object?>{});
    }

    if (path.contains('/rest/v1/rpc/')) {
      return _json(request, null);
    }

    if (path.contains('/rest/v1/flows_with_calendars')) {
      if (blockRefresh) await _release.future;
      if (failRefresh) return _error(request);
      return _json(request, freshFlows);
    }

    if (path.endsWith('/rest/v1/flows') &&
        request.url.queryParameters['reminder_uuid'] != null) {
      reminderLookupStarted = true;
      if (blockReminderLookup) await _reminderLookupRelease.future;
      return _json(request, <String, Object?>{'id': _reminderFlowId});
    }

    if (path.contains('/rest/v1/user_event_filing_items_client')) {
      if (blockRefresh) await _release.future;
      if (failRefresh) return _error(request);
      final itemKinds = request.url.queryParametersAll['item_kind'] ?? const [];
      if (itemKinds.any((value) => value == 'eq.flow')) {
        if (failFlowEventRefresh) return _error(request);
        final bounds = request.url.queryParametersAll['starts_at'] ?? const [];
        final start = _queryDateBound(bounds, 'gte.');
        final end = _queryDateBound(bounds, 'lt.');
        final span = start == null || end == null
            ? null
            : end.difference(start);
        if (blockWideFlowRefresh &&
            span != null &&
            span > const Duration(days: 200)) {
          wideFlowRequestStarted = true;
          await _wideFlowRelease.future;
        }
        final rows = freshFlowEvents
            .where((row) {
              final startsAt = DateTime.parse(
                row['starts_at']! as String,
              ).toUtc();
              if (start != null && startsAt.isBefore(start)) return false;
              if (end != null && !startsAt.isBefore(end)) return false;
              return true;
            })
            .toList(growable: false);
        return _json(request, rows);
      }
      if (failStandaloneRefresh) return _error(request);
      if (blockStandaloneRefresh) {
        standaloneRequestStarted = true;
        await _standaloneRelease.future;
      }
      return _json(request, freshStandaloneEvents);
    }

    if (path.contains('/rest/v1/user_events') && request.method == 'POST') {
      final now = DateTime.now().toUtc().toIso8601String();
      return _json(request, <String, Object?>{
        'id': 'fake-upserted-user-event',
        'client_event_id': 'fake-client-event-id',
        'title': 'Fake upserted event',
        'detail': null,
        'location': null,
        'all_day': true,
        'starts_at': now,
        'ends_at': null,
        'flow_local_id': null,
        'category': null,
        'action_id': null,
        'behavior_payload': null,
        'updated_at': now,
        'created_at': now,
      });
    }

    if (path.contains('/rest/v1/')) {
      return _json(request, const <Object?>[]);
    }

    return _json(request, <String, Object?>{});
  }

  DateTime? _queryDateBound(List<String> values, String prefix) {
    for (final value in values) {
      if (!value.startsWith(prefix)) continue;
      return DateTime.tryParse(value.substring(prefix.length))?.toUtc();
    }
    return null;
  }

  http.StreamedResponse _json(http.BaseRequest request, Object? body) {
    final encoded = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream<List<int>>.value(encoded),
      200,
      request: request,
      headers: const <String, String>{
        'content-type': 'application/json; charset=utf-8',
      },
    );
  }

  http.StreamedResponse _error(http.BaseRequest request) {
    final encoded = utf8.encode(
      jsonEncode(<String, Object?>{'message': 'deliberate refresh failure'}),
    );
    return http.StreamedResponse(
      Stream<List<int>>.value(encoded),
      500,
      request: request,
      headers: const <String, String>{
        'content-type': 'application/json; charset=utf-8',
      },
    );
  }
}
