import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/data/share_repo.dart';
import 'package:mobile/features/calendar/calendar_invalidation.dart';
import 'package:mobile/features/calendar/daily_cosmic_context_badge.dart';
import 'package:mobile/features/calendar/calendar_page.dart'
    show
        CalendarPage,
        CalendarPageState,
        KemeticMath,
        calendarDebugLogWriterForTesting;
import 'package:mobile/features/calendar/calendar_warm_start_cache_identity.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_navigation_restoration_controller.dart';
import 'package:mobile/services/app_window_service.dart';
import 'package:mobile/services/calendar_snapshot_repository.dart';
import 'package:mobile/services/navigation_trace.dart';
import 'package:mobile/core/navigation_persistence_policy.dart';
import 'package:mobile/services/restoration_coordinator.dart';
import 'package:mobile/services/session_resume_service.dart';
import 'package:mobile/main.dart' as app;
import 'package:mobile/widgets/global_side_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _testUserId = '4d2583da-8de4-49d3-9cd1-37a9a74f55bd';
const String _testWindowId = 'calendar-swr-first-paint-test-window';
const String _supabaseUrl = 'https://example.supabase.co';
const String _cachedTitle = 'Cached Akhet Anchor';
const String _freshTitle = 'Fresh Akhet Anchor';
const String _gestureHydratedTitle = 'Gesture-safe hydrated anchor';
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
  const sharingMessages = MethodChannel('receive_sharing_intent/messages');
  const sharingEvents = MethodChannel('receive_sharing_intent/events-media');
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
  messenger.setMockMethodCallHandler(sharingMessages, (methodCall) async {
    if (methodCall.method == 'getInitialMedia') return '[]';
    return null;
  });
  messenger.setMockMethodCallHandler(sharingEvents, (_) async => null);
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
    SessionResumeService.debugUserIdResolver = () => _testUserId;
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
    SessionResumeService.debugUserIdResolver = null;
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

        final calendarScrollView = find
            .byWidgetPredicate(
              (widget) =>
                  widget is CustomScrollView && widget.controller != null,
            )
            .first;
        expect(calendarScrollView, findsOneWidget);
        await tester.drag(calendarScrollView, const Offset(0, -600));
        await tester.pump(const Duration(milliseconds: 500));
        final departingOffset = tester
            .widget<CustomScrollView>(calendarScrollView)
            .controller!
            .offset;
        expect(departingOffset, greaterThan(0));

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
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason:
              'A populated same-process Calendar remount must paint directly; '
              'viewport settlement cannot replace it with a loading wheel.',
        );
        final returnedScrollView = find
            .byWidgetPredicate(
              (widget) =>
                  widget is CustomScrollView && widget.controller != null,
            )
            .first;
        expect(returnedScrollView, findsOneWidget);
        final returnedOffset = tester
            .widget<CustomScrollView>(returnedScrollView)
            .controller!
            .offset;
        expect(
          returnedOffset,
          closeTo(departingOffset, 1),
          reason:
              'Drawer route navigation must retain the exact Calendar offset '
              'rather than replaying a logical approximation later.',
        );
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
      'leaving without a new scroll still hands the exact Calendar viewport to the next route instance',
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

        final calendarScrollView = find
            .byWidgetPredicate(
              (widget) =>
                  widget is CustomScrollView && widget.controller != null,
            )
            .first;
        final departingOffset = tester
            .widget<CustomScrollView>(calendarScrollView)
            .controller!
            .offset;

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('Settings'))),
        );
        await tester.pump();
        await _seedWarmSnapshot(
          includeEvent: false,
          replaceRetainedMemory: false,
        );

        await tester.pumpWidget(
          MaterialApp(home: CalendarPage(key: UniqueKey())),
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text(_cachedTitle), findsOneWidget);
        final returnedScrollView = find
            .byWidgetPredicate(
              (widget) =>
                  widget is CustomScrollView && widget.controller != null,
            )
            .first;
        final returnedOffset = tester
            .widget<CustomScrollView>(returnedScrollView)
            .controller!
            .offset;
        expect(returnedOffset, closeTo(departingOffset, 1));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 25));
        }
      },
    );

    testWidgets(
      'scroll end updates viewport handoff without rebuilding unchanged snapshot payload',
      (tester) async {
        await _setPhoneViewport(tester);
        await _seedWarmSnapshot(title: _cachedTitle);
        _backend.blockRefresh = true;
        final messages = <String>[];
        final originalDebugPrint = debugPrint;
        debugPrint = (message, {wrapWidth}) {
          if (message != null) messages.add(message);
        };
        addTearDown(() async {
          debugPrint = originalDebugPrint;
          _backend.release();
          await tester.pumpWidget(const SizedBox.shrink());
        });

        await tester.pumpWidget(
          MaterialApp(home: CalendarPage(key: UniqueKey())),
        );
        await tester.pump();
        await _pumpWarmRestoreWindow(tester);
        expect(find.text(_cachedTitle), findsOneWidget);

        final identity = _currentSnapshotIdentity();
        final kToday = KemeticMath.fromGregorian(DateTime.now());
        final today = DateUtils.dateOnly(DateTime.now());
        CalendarSnapshotRepository.instance.retainForProcessRemount(
          CalendarSnapshotCandidate(
            identity: identity,
            coverage: CalendarSnapshotCoverage(
              startUtc: today.subtract(const Duration(days: 120)).toUtc(),
              endUtc: today.add(const Duration(days: 120)).toUtc(),
            ),
            completedLanes: calendarSnapshotRequiredLanes,
            generation: 1,
            payload: Map<String, dynamic>.from(
              _warmSnapshot(
                title: _cachedTitle,
                includeEvent: true,
                target: kToday,
              ),
            ),
            source: 'pre_scroll_authoritative_snapshot',
          ),
        );

        final calendarScrollView = find
            .byWidgetPredicate(
              (widget) =>
                  widget is CustomScrollView && widget.controller != null,
            )
            .first;
        await tester.drag(calendarScrollView, const Offset(0, -600));
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          tester
              .widget<CustomScrollView>(calendarScrollView)
              .controller!
              .offset,
          greaterThan(0),
        );

        debugPrint = originalDebugPrint;
        expect(
          messages.where(
            (message) => message.contains(
              '[calendar] retained process route handoff '
              'source=calendar_scroll_end',
            ),
          ),
          isNotEmpty,
          reason: 'ScrollEnd must still retain the latest viewport handoff.',
        );
        expect(
          messages.where(
            (message) => message.contains(
              '[warmStart] retained process remount '
              'source=calendar_scroll_end',
            ),
          ),
          isEmpty,
          reason:
              'Scrolling changes only viewport authority. Re-encoding the '
              'complete event payload synchronously at every ScrollEnd '
              'introduces avoidable gesture-end jank.',
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

    testWidgets('logical saved month wins over a stale portrait pixel offset', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      final today = KemeticMath.fromGregorian(DateTime.now());
      final target = _nonTodayRestorationTarget(today);
      final prefs = await SharedPreferences.getInstance();
      await _seedCalendarRestorationPrefs(
        prefs,
        target: target,
        includeAnchor: false,
        scrollOffset: 100000,
      );
      await _seedWarmSnapshot(title: _cachedTitle, target: target);
      _backend.blockRefresh = true;

      final frames = <_CalendarMovementFrame>[];
      await _pumpCalendar(tester);
      for (var i = 0; i < 40; i++) {
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
        firstMeaningful.savedMonthVisible,
        isTrue,
        reason:
            'The logical Kemetic month is authoritative across a rebuilt '
            'scroll tree; a stale raw pixel offset must not publish another '
            'month first. frames=${_movementFrameSummary(frames)}',
      );
    });

    testWidgets(
      'portrait scroll does not use PageStorage as a second restore authority',
      (tester) async {
        await _setPhoneViewport(tester);
        await _seedWarmSnapshot(title: _cachedTitle);
        _backend.blockRefresh = true;

        await _pumpCalendar(tester);
        final scrollView = tester.widget<CustomScrollView>(
          find.byKey(const PageStorageKey('calendar_portrait_scroll')),
        );

        expect(
          scrollView.controller?.keepScrollOffset,
          isFalse,
          reason:
              'AppRestorationService owns cross-recreation calendar position; '
              'PageStorage must not apply an unrelated raw pixel offset first.',
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

    group('physical iPhone Today sequence matrix', () {
      testWidgets(
        'A fresh Calendar scroll away then Today completes in place',
        (tester) async {
          final result = await _runTodaySequenceMatrixCase(
            tester,
            _TodaySequenceCase.freshCalendar,
          );
          _expectTodaySequenceContract(result);
        },
      );

      testWidgets('B background resume then Today completes in place', (
        tester,
      ) async {
        final result = await _runTodaySequenceMatrixCase(
          tester,
          _TodaySequenceCase.backgroundResume,
        );
        _expectTodaySequenceContract(result);
      });

      testWidgets(
        'C Calendar Planner Calendar without termination then Today completes in place',
        (tester) async {
          final result = await _runTodaySequenceMatrixCase(
            tester,
            _TodaySequenceCase.plannerRoundTrip,
          );
          _expectTodaySequenceContract(result);
        },
      );

      testWidgets(
        'D restored Planner Calendar Today complete physical sequence stays authoritative',
        (tester) async {
          final result = await _runTodaySequenceMatrixCase(
            tester,
            _TodaySequenceCase.restoredPlannerImmediate,
          );
          _expectTodaySequenceContract(result);
        },
      );

      testWidgets(
        'E restored Planner Calendar quiescent hydration then Today completes in place',
        (tester) async {
          final result = await _runTodaySequenceMatrixCase(
            tester,
            _TodaySequenceCase.restoredPlannerQuiescent,
          );
          _expectTodaySequenceContract(result);
        },
      );

      testWidgets(
        'F restored Planner Calendar Today during hydration cannot replay distant viewport',
        (tester) async {
          final result = await _runTodaySequenceMatrixCase(
            tester,
            _TodaySequenceCase.restoredPlannerDuringHydration,
          );
          _expectTodaySequenceContract(result);
        },
      );

      testWidgets(
        'G restored Planner Calendar extra drawer round trip then Today completes in place',
        (tester) async {
          final result = await _runTodaySequenceMatrixCase(
            tester,
            _TodaySequenceCase.restoredPlannerDrawerRoundTrip,
          );
          _expectTodaySequenceContract(result);
        },
      );

      testWidgets(
        'H1 far process-restored Planner Calendar immediate Today completes in place',
        (tester) async {
          final result = await _runTodaySequenceMatrixCase(
            tester,
            _TodaySequenceCase.restoredPlannerFarImmediate,
          );
          _expectTodaySequenceContract(result);
        },
      );

      testWidgets(
        'H2 far process-restored Planner Calendar painted hydration-active Today completes in place',
        (tester) async {
          final result = await _runTodaySequenceMatrixCase(
            tester,
            _TodaySequenceCase.restoredPlannerFarDuringHydration,
          );
          _expectTodaySequenceContract(result);
          expect(result.hydrationInFlightAtTap, isTrue);
        },
      );

      testWidgets(
        'H3 far process-restored Planner Calendar quiescent Today completes in place',
        (tester) async {
          final result = await _runTodaySequenceMatrixCase(
            tester,
            _TodaySequenceCase.restoredPlannerFarQuiescent,
          );
          _expectTodaySequenceContract(result);
          expect(result.hydrationInFlightAtTap, isFalse);
        },
      );

      testWidgets(
        'H4 far process-restored Planner Calendar completed manual scroll then Today completes in place',
        (tester) async {
          final result = await _runTodaySequenceMatrixCase(
            tester,
            _TodaySequenceCase.restoredPlannerFarManualScroll,
          );
          _expectTodaySequenceContract(result);
        },
      );
    });

    group('Calendar logical viewport process-restoration matrix', () {
      for (final matrixCase in _ViewportProcessRestoreCase.values) {
        testWidgets(matrixCase.testName, (tester) async {
          final result = await _runViewportProcessRestoreMatrixCase(
            tester,
            matrixCase,
          );
          _expectViewportProcessRestoreContract(result);
        });
      }
    });

    testWidgets(
      'pointer down before scroll start prevents same-gesture hydration viewport replay',
      (tester) async {
        final fixture = await _mountSettledGestureHydrationCalendar(tester);
        final preservedOffset = fixture.controller.offset;
        final gesture = await tester.startGesture(
          tester.getCenter(fixture.scrollView),
        );
        var gestureReleased = false;
        addTearDown(() async {
          if (!gestureReleased) await gesture.up();
        });
        await tester.pump();

        final hydration = fixture.state.reloadFromOutside();
        await _pumpUntilRefreshBlocked(tester);
        expect(fixture.controller.offset, preservedOffset);

        await gesture.moveBy(const Offset(0, -140));
        await tester.pump(const Duration(milliseconds: 120));
        final userControlledOffset = fixture.controller.offset;
        expect(userControlledOffset, greaterThan(preservedOffset + 80));

        final replaySamples = await _releaseHydrationDuringGesture(
          tester,
          gesture: gesture,
          state: fixture.state,
          controller: fixture.controller,
          hydration: hydration,
        );
        expect(
          replaySamples,
          everyElement(greaterThanOrEqualTo(userControlledOffset - 2)),
          reason:
              'Hydration must not snap the Calendar back to the offset captured '
              'after pointer-down while the same gesture controls the viewport. '
              'samples=$replaySamples preserved=$preservedOffset',
        );

        await gesture.up();
        gestureReleased = true;
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          fixture.controller.offset,
          greaterThan(userControlledOffset - 2),
          reason:
              'Pointer release must not apply a delayed hydration snap-back.',
        );
      },
    );

    testWidgets(
      'hydration begun after scroll start cannot replay during the continuing gesture',
      (tester) async {
        final fixture = await _mountSettledGestureHydrationCalendar(tester);
        final initialOffset = fixture.controller.offset;
        final gesture = await tester.startGesture(
          tester.getCenter(fixture.scrollView),
        );
        var gestureReleased = false;
        addTearDown(() async {
          if (!gestureReleased) await gesture.up();
        });

        await gesture.moveBy(const Offset(0, -140));
        await tester.pump(const Duration(milliseconds: 120));
        final offsetAtHydrationStart = fixture.controller.offset;
        expect(offsetAtHydrationStart, greaterThan(initialOffset + 80));

        final hydration = fixture.state.reloadFromOutside();
        await _pumpUntilRefreshBlocked(tester);

        await gesture.moveBy(const Offset(0, -140));
        await tester.pump(const Duration(milliseconds: 120));
        final userControlledOffset = fixture.controller.offset;
        expect(userControlledOffset, greaterThan(offsetAtHydrationStart + 80));

        final replaySamples = await _releaseHydrationDuringGesture(
          tester,
          gesture: gesture,
          state: fixture.state,
          controller: fixture.controller,
          hydration: hydration,
        );
        expect(
          replaySamples,
          everyElement(greaterThanOrEqualTo(userControlledOffset - 2)),
          reason:
              'A hydration that starts after ScrollStart must still yield to '
              'later movement from the same held pointer. samples=$replaySamples '
              'captured=$offsetAtHydrationStart',
        );

        await gesture.up();
        gestureReleased = true;
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          fixture.controller.offset,
          greaterThan(userControlledOffset - 2),
          reason:
              'Pointer release must not apply a delayed hydration snap-back.',
        );
      },
    );

    testWidgets(
      'dispose cancels Calendar resume retries before they can publish or navigate',
      (tester) async {
        await _setPhoneViewport(tester);
        await _seedWarmSnapshot(title: _cachedTitle);
        await _seedDaySheetResumeEntry(
          title: 'Disposed lifecycle must not restore this draft',
        );
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

        final retryTimers = _CalendarResumeRetryTimerTracker();
        final navigator = _RecordingNavigatorObserver();
        await runZoned(
          () => _pumpCalendar(
            tester,
            navigatorObservers: <NavigatorObserver>[navigator],
          ),
          zoneSpecification: retryTimers.zoneSpecification,
        );

        expect(
          retryTimers.activeCount,
          greaterThan(0),
          reason: 'The blocked startup must schedule the real 120 ms retry.',
        );
        final state = tester.state<CalendarPageState>(
          find.byType(CalendarPage),
        );
        final viewBeforeDispose = state.debugCurrentViewForTesting;
        final callbacksBeforeDispose = retryTimers.callbackCount;
        final navigationBeforeDispose = navigator.navigationCount;

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('Disposed'))),
        );
        await tester.pump();

        expect(
          retryTimers.activeCount,
          0,
          reason:
              'CalendarPage.dispose must synchronously cancel every owned '
              'resume-retry timer; waiting for it to expire is insufficient.',
        );

        // Twenty attempts at 120 ms is the complete production retry window.
        await tester.pump(const Duration(milliseconds: 20 * 120 + 120));
        await tester.pump();

        expect(retryTimers.callbackCount, callbacksBeforeDispose);
        expect(state.debugCurrentViewForTesting, viewBeforeDispose);
        expect(navigator.navigationCount, navigationBeforeDispose);
        expect(
          find.text('Disposed lifecycle must not restore this draft'),
          findsNothing,
        );
        expect(
          await SessionResumeService.readResumeEntry(
            kind: 'calendar_day_sheet',
            baseRoute: '/',
          ),
          isNotNull,
          reason:
              'A disposed Calendar must not consume or publish pending '
              'restoration state.',
        );
        expect(retryTimers.activeCount, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Calendar resume retry still restores while mounted', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      await _seedWarmSnapshot(title: _cachedTitle);
      const resumedTitle = 'Mounted lifecycle restores this draft';
      await _seedDaySheetResumeEntry(title: resumedTitle);
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

      final retryTimers = _CalendarResumeRetryTimerTracker();
      await runZoned(
        () => _pumpCalendar(tester),
        zoneSpecification: retryTimers.zoneSpecification,
      );
      expect(retryTimers.activeCount, greaterThan(0));

      restorationReady.complete();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (i % 4 == 0) {
          await tester.runAsync<void>(() async {
            await Future<void>.delayed(Duration.zero);
          });
        }
      }

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is EditableText && widget.controller.text == resumedTitle,
        ),
        findsOneWidget,
        reason:
            'The same retry must consume and display the day-sheet resume '
            'entry once persisted restoration completes while mounted.',
      );
      final activeResumeEntry = await SessionResumeService.readResumeEntry(
        kind: 'calendar_day_sheet',
        baseRoute: '/',
      );
      expect(activeResumeEntry?.payload['title'], resumedTitle);
      expect(retryTimers.callbackCount, greaterThan(0));
      expect(retryTimers.activeCount, 0);
      expect(tester.takeException(), isNull);
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
      'enabled trace records hydration model continuity through the next frame',
      (tester) async {
        await _setPhoneViewport(tester);
        await _seedWarmSnapshot(title: _cachedTitle);
        _backend.blockRefresh = true;
        _backend.freshStandaloneEvents = <Map<String, Object?>>[
          _standaloneEventRow(title: _freshTitle),
        ];
        await NavigationTrace.instance.setEnabled(true);
        addTearDown(() => NavigationTrace.instance.setEnabled(false));

        await _pumpCalendar(tester);
        await _releaseAndPumpUntilTextVisible(tester, _freshTitle, <String>[]);
        await tester.pump();

        final entries = NavigationTrace.instance.entries;
        expect(
          entries.any((entry) => entry.contains('calendar hydration commit')),
          isTrue,
          reason:
              'The trace must capture model counts at the hydration commit.',
        );
        expect(
          entries.any(
            (entry) => entry.contains('calendar hydration post-frame'),
          ),
          isTrue,
          reason:
              'The trace must sample the same model again after Flutter paints.',
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

Future<void> _pumpCalendar(
  WidgetTester tester, {
  Key? key,
  List<NavigatorObserver> navigatorObservers = const <NavigatorObserver>[],
}) async {
  addTearDown(() async {
    _backend.release();
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 8; i++) {
      _backend.release();
      await tester.pump(const Duration(milliseconds: 250));
    }
  });
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: navigatorObservers,
      home: CalendarPage(key: key ?? UniqueKey()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
}

enum _TodaySequenceCase {
  freshCalendar,
  backgroundResume,
  plannerRoundTrip,
  restoredPlannerImmediate,
  restoredPlannerQuiescent,
  restoredPlannerDuringHydration,
  restoredPlannerDrawerRoundTrip,
  restoredPlannerFarImmediate,
  restoredPlannerFarDuringHydration,
  restoredPlannerFarQuiescent,
  restoredPlannerFarManualScroll,
}

class _TodaySequenceObservation {
  const _TodaySequenceObservation({
    required this.sequence,
    required this.routerPath,
    required this.stateIdentity,
    required this.stateIdentityAfter,
    required this.elementIdentity,
    required this.elementIdentityAfter,
    required this.scrollControllerIdentity,
    required this.scrollControllerIdentityAfter,
    required this.scrollAttached,
    required this.scrollClientCount,
    required this.offsetBeforeToday,
    required this.targetOffset,
    required this.offsetSamples,
    required this.hydrationGenerationBefore,
    required this.hydrationGenerationAfter,
    required this.authoritativeGenerationBefore,
    required this.authoritativeGenerationAfter,
    required this.principalGeneration,
    required this.lifecycleGeneration,
    required this.gestureIntentGenerationBefore,
    required this.gestureIntentGenerationAfter,
    required this.todayCommandGeneration,
    required this.dispatchDisposition,
    required this.animationStarted,
    required this.animationCompleted,
    required this.laterReplayOverwroteToday,
    required this.hydrationInFlightAtTap,
    required this.viewportSettledAtTap,
    required this.todayAnchorMountedAtTap,
    required this.trace,
  });

  final String sequence;
  final String routerPath;
  final int stateIdentity;
  final int stateIdentityAfter;
  final int elementIdentity;
  final int elementIdentityAfter;
  final int scrollControllerIdentity;
  final int scrollControllerIdentityAfter;
  final bool scrollAttached;
  final int scrollClientCount;
  final double offsetBeforeToday;
  final double? targetOffset;
  final List<double> offsetSamples;
  final int hydrationGenerationBefore;
  final int hydrationGenerationAfter;
  final int authoritativeGenerationBefore;
  final int authoritativeGenerationAfter;
  final int principalGeneration;
  final int lifecycleGeneration;
  final int gestureIntentGenerationBefore;
  final int gestureIntentGenerationAfter;
  final int todayCommandGeneration;
  final String dispatchDisposition;
  final bool animationStarted;
  final bool animationCompleted;
  final bool laterReplayOverwroteToday;
  final bool hydrationInFlightAtTap;
  final bool viewportSettledAtTap;
  final bool todayAnchorMountedAtTap;
  final List<String> trace;

  bool get contractSatisfied =>
      routerPath == '/' &&
      stateIdentityAfter == stateIdentity &&
      elementIdentityAfter == elementIdentity &&
      scrollControllerIdentityAfter == scrollControllerIdentity &&
      dispatchDisposition == 'accepted' &&
      gestureIntentGenerationAfter > gestureIntentGenerationBefore &&
      animationStarted &&
      animationCompleted &&
      !laterReplayOverwroteToday;

  Map<String, Object?> toJson() => <String, Object?>{
    'sequence': sequence,
    'routerPath': routerPath,
    'stateIdentity': stateIdentity,
    'stateIdentityAfter': stateIdentityAfter,
    'elementIdentity': elementIdentity,
    'elementIdentityAfter': elementIdentityAfter,
    'scrollControllerIdentity': scrollControllerIdentity,
    'scrollControllerIdentityAfter': scrollControllerIdentityAfter,
    'scrollAttached': scrollAttached,
    'scrollClientCount': scrollClientCount,
    'offsetBeforeToday': offsetBeforeToday,
    'targetOffset': targetOffset,
    'offsetSamples': offsetSamples,
    'hydrationGenerationBefore': hydrationGenerationBefore,
    'hydrationGenerationAfter': hydrationGenerationAfter,
    'authoritativeGenerationBefore': authoritativeGenerationBefore,
    'authoritativeGenerationAfter': authoritativeGenerationAfter,
    'principalGeneration': principalGeneration,
    'lifecycleGeneration': lifecycleGeneration,
    'gestureIntentGenerationBefore': gestureIntentGenerationBefore,
    'gestureIntentGenerationAfter': gestureIntentGenerationAfter,
    'todayCommandGeneration': todayCommandGeneration,
    'dispatchDisposition': dispatchDisposition,
    'animationStarted': animationStarted,
    'animationCompleted': animationCompleted,
    'laterReplayOverwroteToday': laterReplayOverwroteToday,
    'hydrationInFlightAtTap': hydrationInFlightAtTap,
    'viewportSettledAtTap': viewportSettledAtTap,
    'todayAnchorMountedAtTap': todayAnchorMountedAtTap,
    'trace': trace,
  };
}

void _expectTodaySequenceContract(_TodaySequenceObservation result) {
  debugPrint('TODAY_SEQUENCE_MATRIX ${jsonEncode(result.toJson())}');
  expect(
    result.contractSatisfied,
    isTrue,
    reason:
        'One Today tap on the visible mounted Calendar must own one in-place '
        'animated viewport command. observation=${jsonEncode(result.toJson())}',
  );
}

Future<_TodaySequenceObservation> _runTodaySequenceMatrixCase(
  WidgetTester tester,
  _TodaySequenceCase sequence,
) async {
  await _setPhoneViewport(tester);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
  final today = KemeticMath.fromGregorian(DateTime.now());
  final usesFarProcessViewport =
      sequence == _TodaySequenceCase.restoredPlannerFarImmediate ||
      sequence == _TodaySequenceCase.restoredPlannerFarDuringHydration ||
      sequence == _TodaySequenceCase.restoredPlannerFarQuiescent ||
      sequence == _TodaySequenceCase.restoredPlannerFarManualScroll;
  final target = usesFarProcessViewport
      ? (kYear: today.kYear + 3, kMonth: 2, kDay: 17)
      : _nonTodayRestorationTarget(today);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    DailyCosmicContextPrefs.lastShownGregorianDateKeyForUser(_testUserId),
    dailyCosmicContextGregorianDateKey(DateTime.now()),
  );
  await _seedCalendarRestorationPrefs(prefs, target: target);
  await _seedWarmSnapshot(title: _cachedTitle, target: target);
  _backend.blockRefresh = false;
  AppRestorationService.instance.resetForTesting();
  AppNavigationRestorationController.instance.resetForTesting();
  RestorationCoordinator.instance.resetForTesting();
  RestorationCoordinator.instance.suppressRestoreForExplicitIntent(
    reason: 'today_sequence_matrix',
    surfaces: const <String>[
      RestorationCoordinator.calendarOverlayStackSurface,
    ],
  );
  ShareRepo.debugDisableUnreadTrackingForTesting = true;
  await NavigationTrace.instance.setEnabled(true);

  final routers = <GoRouter>[];
  addTearDown(() async {
    _backend.release();
    await tester.runAsync<void>(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync<void>(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    // The production shell schedules a two-second, mounted-guarded guidance
    // refresh after auth. Let that unrelated shell callback observe disposal.
    await tester.pump(const Duration(milliseconds: 2100));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    Supabase.instance.client.auth.stopAutoRefresh();
    await tester.pump();
    ShareRepo.debugDisableUnreadTrackingForTesting = false;
    for (final router in routers.reversed) {
      router.dispose();
    }
    app.resetGlobalFloatingMenuShellForTesting();
    await NavigationTrace.instance.setEnabled(false);
  });

  Future<GoRouter> mountRouter(String initialLocation) async {
    RestorationCoordinator.instance.beginLaunchRestore(
      reason: RestorationRestoreReason.coldLaunch,
      targetLocation: initialLocation,
    );
    RestorationCoordinator.instance.suppressRestoreForExplicitIntent(
      reason: 'today_sequence_matrix_no_overlay',
      surfaces: const <String>[
        RestorationCoordinator.calendarOverlayStackSurface,
      ],
    );
    final router = app.createProductionRouterForTesting(
      initialLocation: initialLocation,
    );
    routers.add(router);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => app.buildGlobalFloatingMenuShellForTesting(
          router: router,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    return router;
  }

  Future<void> waitForCalendar() async {
    for (var i = 0; i < 240; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      if (i % 4 == 0) {
        await tester.runAsync<void>(() async {
          await Future<void>.delayed(Duration.zero);
        });
      }
      if (find.byType(CalendarPage).evaluate().isNotEmpty &&
          find
              .byKey(const PageStorageKey<String>('calendar_portrait_scroll'))
              .evaluate()
              .isNotEmpty) {
        return;
      }
    }
    fail('Production router never mounted the Calendar scroll surface.');
  }

  Future<void> waitForHydrationQuiescence(CalendarPageState state) async {
    var stableFrames = 0;
    for (var i = 0; i < 320; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      if (i % 4 == 0) {
        await tester.runAsync<void>(() async {
          await Future<void>.delayed(Duration.zero);
        });
      }
      if (!state.debugHydrationInFlightForTesting &&
          state.debugInitialViewportSettledForTesting) {
        stableFrames++;
        if (stableFrames >= 12) return;
      } else {
        stableFrames = 0;
      }
    }
    fail('Calendar hydration never became stably quiescent.');
  }

  Future<void> releaseControlledHydration(
    CalendarPageState state,
    Future<void> hydration,
  ) async {
    _backend.release();
    for (var i = 0; i < 320; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      if (i % 4 == 0) {
        await tester.runAsync<void>(() async {
          await Future<void>.delayed(Duration.zero);
        });
      }
      if (!state.debugHydrationInFlightForTesting) {
        await hydration;
        return;
      }
    }
    fail('The controlled Calendar hydration did not finish after release.');
  }

  Future<void> openDrawerDestination(
    GoRouter router,
    String label,
    String expectedPath,
  ) async {
    final menu = find.byKey(app.globalMenuButtonKey);
    expect(menu, findsOneWidget);
    await tester.tap(menu);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    final destination = find.byKey(
      ValueKey<String>('global-side-drawer-item-$label'),
    );
    expect(destination, findsOneWidget);
    await tester.tap(destination);
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      if (i % 4 == 0) {
        await tester.runAsync<void>(() async {
          await Future<void>.delayed(Duration.zero);
        });
      }
      if (router.routerDelegate.currentConfiguration.uri.path == expectedPath &&
          find.byKey(globalSideDrawerKey).evaluate().isEmpty) {
        return;
      }
    }
    fail(
      'Drawer destination $label did not settle at $expectedPath; '
      'actual=${router.routerDelegate.currentConfiguration.uri}',
    );
  }

  Future<void> scrollCalendarAway() async {
    final scrollView = find.byKey(
      const PageStorageKey<String>('calendar_portrait_scroll'),
    );
    expect(scrollView, findsOneWidget);
    final controller = tester.widget<CustomScrollView>(scrollView).controller!;
    for (var i = 0; i < 3; i++) {
      await tester.drag(scrollView, const Offset(0, -700));
      await tester.pump(const Duration(milliseconds: 160));
    }
    expect(controller.hasClients, isTrue);
    expect(controller.offset.abs(), greaterThan(500));
    await tester.pump(const Duration(milliseconds: 650));
  }

  var router = await mountRouter('/');
  await waitForCalendar();
  var state = tester.state<CalendarPageState>(find.byType(CalendarPage));
  await waitForHydrationQuiescence(state);
  await scrollCalendarAway();

  if (sequence == _TodaySequenceCase.backgroundResume) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 300));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 350));
  }

  final usesPlanner =
      sequence != _TodaySequenceCase.freshCalendar &&
      sequence != _TodaySequenceCase.backgroundResume;
  final usesProcessRestore =
      sequence == _TodaySequenceCase.restoredPlannerImmediate ||
      sequence == _TodaySequenceCase.restoredPlannerQuiescent ||
      sequence == _TodaySequenceCase.restoredPlannerDuringHydration ||
      sequence == _TodaySequenceCase.restoredPlannerDrawerRoundTrip ||
      sequence == _TodaySequenceCase.restoredPlannerFarImmediate ||
      sequence == _TodaySequenceCase.restoredPlannerFarDuringHydration ||
      sequence == _TodaySequenceCase.restoredPlannerFarQuiescent ||
      sequence == _TodaySequenceCase.restoredPlannerFarManualScroll;

  if (usesPlanner) {
    await openDrawerDestination(router, 'Planner', '/rhythm/today');

    if (usesProcessRestore) {
      await AppNavigationRestorationController.instance
          .recordPrimaryTabSelection(AppSection.planner);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      CalendarPage.debugResetWarmStateStoreForTesting();
      app.resetGlobalFloatingMenuShellForTesting();
      RestorationCoordinator.instance.resetForTesting();
      final restored = await AppNavigationRestorationController.instance
          .restoreLaunchDestination(isAuthenticated: true);
      expect(
        restored.route,
        '/rhythm/today',
        reason: 'The reconstructed launch must restore Planner first.',
      );
      router = await mountRouter(restored.route);
    }

    await openDrawerDestination(router, 'Calendar', '/');
    await waitForCalendar();
    state = tester.state<CalendarPageState>(find.byType(CalendarPage));
    if (sequence != _TodaySequenceCase.restoredPlannerFarImmediate) {
      await waitForHydrationQuiescence(state);
    }
    if (!usesFarProcessViewport ||
        sequence == _TodaySequenceCase.restoredPlannerFarManualScroll) {
      await scrollCalendarAway();
    }
  }

  Future<void>? controlledHydration;
  final controlsHydration =
      sequence == _TodaySequenceCase.restoredPlannerImmediate ||
      sequence == _TodaySequenceCase.restoredPlannerQuiescent ||
      sequence == _TodaySequenceCase.restoredPlannerDuringHydration ||
      sequence == _TodaySequenceCase.restoredPlannerDrawerRoundTrip ||
      sequence == _TodaySequenceCase.restoredPlannerFarDuringHydration;
  if (controlsHydration) {
    _backend
      ..blockedRefreshRequests = 0
      ..blockRefresh = true;
    controlledHydration = state.reloadFromOutside();
    await _pumpUntilRefreshBlocked(tester);

    if (sequence == _TodaySequenceCase.restoredPlannerQuiescent) {
      await releaseControlledHydration(state, controlledHydration);
      await waitForHydrationQuiescence(state);
      controlledHydration = null;
    } else if (sequence == _TodaySequenceCase.restoredPlannerDrawerRoundTrip) {
      await openDrawerDestination(router, 'Calendar', '/');
    } else if (sequence == _TodaySequenceCase.restoredPlannerImmediate) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  final calendarElement = tester.element(find.byType(CalendarPage));
  final scrollView = find.byKey(
    const PageStorageKey<String>('calendar_portrait_scroll'),
  );
  final controller = tester.widget<CustomScrollView>(scrollView).controller!;
  final offsetBeforeToday = controller.offset;
  final hydrationGenerationBefore = state.debugHydrationGenerationForTesting;
  final authoritativeGenerationBefore =
      state.debugAuthoritativeSnapshotGenerationForTesting;
  final gestureGenerationBefore =
      RestorationCoordinator.instance.debugUserIntentGenerationForTesting;
  final hydrationInFlightAtTap = state.debugHydrationInFlightForTesting;
  final viewportSettledAtTap = state.debugInitialViewportSettledForTesting;
  final todayAnchorMountedAtTap = state.debugTodayAnchorMountedForTesting;
  final traceStart = NavigationTrace.instance.entries.length;

  expect(find.byTooltip('Today'), findsOneWidget);
  await tester.tap(find.byTooltip('Today'));
  final samples = <double>[];
  var reachedTodayBeforeRelease = false;
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 40));
    samples.add(controller.offset);
    reachedTodayBeforeRelease |= state.debugTodayAnchorVisibleForTesting;
  }

  if (controlledHydration != null) {
    await releaseControlledHydration(state, controlledHydration);
    await waitForHydrationQuiescence(state);
  }
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 40));
    samples.add(controller.offset);
  }

  final finalState = tester.state<CalendarPageState>(find.byType(CalendarPage));
  final finalElement = tester.element(find.byType(CalendarPage));
  final finalScrollView = find.byKey(
    const PageStorageKey<String>('calendar_portrait_scroll'),
  );
  final finalController = tester
      .widget<CustomScrollView>(finalScrollView)
      .controller!;
  final finalView = finalState.debugCurrentViewForTesting;
  final finalTodayVisible = finalState.debugTodayAnchorVisibleForTesting;
  final trace = NavigationTrace.instance.entries.skip(traceStart).toList();
  final dispatchAccepted = trace.any(
    (entry) => entry.contains('Calendar Today viewport command'),
  );
  final animationStarted = samples.any(
    (offset) => (offset - offsetBeforeToday).abs() > 1,
  );
  final animationCompleted =
      finalView.kYear == today.kYear &&
      finalView.kMonth == today.kMonth &&
      finalView.kDay == today.kDay &&
      finalTodayVisible;
  final laterReplayOverwroteToday =
      reachedTodayBeforeRelease && !finalTodayVisible;

  // Widget tests execute on the host platform, where supabase_flutter does
  // not stop its mobile auto-refresh ticker for lifecycle pauses.
  Supabase.instance.client.auth.stopAutoRefresh();

  return _TodaySequenceObservation(
    sequence: sequence.name,
    routerPath: router.routerDelegate.currentConfiguration.uri.path,
    stateIdentity: identityHashCode(state),
    stateIdentityAfter: identityHashCode(finalState),
    elementIdentity: identityHashCode(calendarElement),
    elementIdentityAfter: identityHashCode(finalElement),
    scrollControllerIdentity: identityHashCode(controller),
    scrollControllerIdentityAfter: identityHashCode(finalController),
    scrollAttached: controller.hasClients,
    scrollClientCount: controller.positions.length,
    offsetBeforeToday: offsetBeforeToday,
    targetOffset: samples.isEmpty ? null : samples.last,
    offsetSamples: samples,
    hydrationGenerationBefore: hydrationGenerationBefore,
    hydrationGenerationAfter: finalState.debugHydrationGenerationForTesting,
    authoritativeGenerationBefore: authoritativeGenerationBefore,
    authoritativeGenerationAfter:
        finalState.debugAuthoritativeSnapshotGenerationForTesting,
    principalGeneration: finalState.debugPrincipalGenerationForTesting,
    lifecycleGeneration: finalState.debugLifecycleGenerationForTesting,
    gestureIntentGenerationBefore: gestureGenerationBefore,
    gestureIntentGenerationAfter:
        RestorationCoordinator.instance.debugUserIntentGenerationForTesting,
    todayCommandGeneration: finalState.debugTodayCommandGenerationForTesting,
    dispatchDisposition: dispatchAccepted
        ? finalState.debugTodayCommandDispositionForTesting
        : 'ignored',
    animationStarted: animationStarted,
    animationCompleted: animationCompleted,
    laterReplayOverwroteToday: laterReplayOverwroteToday,
    hydrationInFlightAtTap: hydrationInFlightAtTap,
    viewportSettledAtTap: viewportSettledAtTap,
    todayAnchorMountedAtTap: todayAnchorMountedAtTap,
    trace: trace,
  );
}

typedef _LogicalCalendarAnchor = ({int kYear, int kMonth, int kDay});

enum _ViewportProcessRestoreCase {
  waitTenSeconds,
  waitThirtySeconds,
  terminateOnCalendar,
  plannerRoundTrip,
  backgroundResume,
  threeDistinctYears,
  todayThenLaterScroll,
  hydrationAfterRestore,
  threeRestoreScrollTodayCycles,
  postRestoreTodayThenLaterScroll;

  String get testName => switch (this) {
    waitTenSeconds =>
      'A ten-second settled future anchor survives Planner process termination',
    waitThirtySeconds =>
      'B thirty-second settled future anchor survives Planner process termination',
    terminateOnCalendar =>
      'C terminating directly on Calendar restores the latest logical anchor',
    plannerRoundTrip =>
      'D Calendar Planner Calendar without termination preserves the logical anchor',
    backgroundResume =>
      'E background resume without termination preserves the logical anchor',
    threeDistinctYears =>
      'F three newer distinct years replace the older durable Calendar anchor',
    todayThenLaterScroll =>
      'G a later explicit scroll remains authoritative after Today and termination',
    hydrationAfterRestore =>
      'H hydration cannot replace the restored logical Calendar anchor',
    threeRestoreScrollTodayCycles =>
      'I three process restore manual scroll Today cycles complete in place',
    postRestoreTodayThenLaterScroll =>
      'J post-restore Today yields to a later scroll across termination',
  };
}

class _ViewportProcessRestoreObservation {
  const _ViewportProcessRestoreObservation({
    required this.matrixCase,
    required this.routerPath,
    required this.selectedAnchors,
    required this.durableAnchors,
    required this.durableAnchorTargets,
    required this.durableAnchorAlignments,
    required this.restoredAnchors,
    required this.anchorTargets,
    required this.anchorAlignments,
    required this.restoredAnchorTargets,
    required this.restoredAnchorAlignments,
    required this.stateIdentitiesBefore,
    required this.stateIdentitiesAfter,
    required this.elementIdentitiesBefore,
    required this.elementIdentitiesAfter,
    required this.scrollControllerIdentitiesBefore,
    required this.scrollControllerIdentitiesAfter,
    required this.viewportIntentGenerations,
    required this.principalGenerations,
    required this.lifecycleGenerations,
    required this.storageKeys,
    required this.calendarLogs,
    required this.restorationLogs,
  });

  final String matrixCase;
  final String routerPath;
  final List<_LogicalCalendarAnchor> selectedAnchors;
  final List<_LogicalCalendarAnchor?> durableAnchors;
  final List<String?> durableAnchorTargets;
  final List<double?> durableAnchorAlignments;
  final List<_LogicalCalendarAnchor> restoredAnchors;
  final List<String?> anchorTargets;
  final List<double?> anchorAlignments;
  final List<String?> restoredAnchorTargets;
  final List<double?> restoredAnchorAlignments;
  final List<int> stateIdentitiesBefore;
  final List<int> stateIdentitiesAfter;
  final List<int> elementIdentitiesBefore;
  final List<int> elementIdentitiesAfter;
  final List<int> scrollControllerIdentitiesBefore;
  final List<int> scrollControllerIdentitiesAfter;
  final List<int> viewportIntentGenerations;
  final List<int> principalGenerations;
  final List<int> lifecycleGenerations;
  final List<String> storageKeys;
  final List<String> calendarLogs;
  final List<String> restorationLogs;

  bool get contractSatisfied {
    if (routerPath != '/' || selectedAnchors.isEmpty) return false;
    if (selectedAnchors.length != durableAnchors.length ||
        selectedAnchors.length != restoredAnchors.length ||
        selectedAnchors.length != durableAnchorTargets.length ||
        selectedAnchors.length != durableAnchorAlignments.length ||
        selectedAnchors.length != anchorTargets.length ||
        selectedAnchors.length != anchorAlignments.length ||
        selectedAnchors.length != restoredAnchorTargets.length ||
        selectedAnchors.length != restoredAnchorAlignments.length) {
      return false;
    }
    for (var i = 0; i < selectedAnchors.length; i++) {
      if (!_sameLogicalCalendarAnchor(selectedAnchors[i], durableAnchors[i]) ||
          !_sameLogicalCalendarAnchor(selectedAnchors[i], restoredAnchors[i]) ||
          anchorTargets[i] == null ||
          anchorTargets[i] != durableAnchorTargets[i] ||
          anchorTargets[i] != restoredAnchorTargets[i] ||
          anchorAlignments[i] == null ||
          durableAnchorAlignments[i] == null ||
          restoredAnchorAlignments[i] == null ||
          (anchorAlignments[i]! - durableAnchorAlignments[i]!).abs() > 0.02 ||
          (anchorAlignments[i]! - restoredAnchorAlignments[i]!).abs() > 0.02) {
        return false;
      }
    }
    return principalGenerations.every((generation) => generation == 1) &&
        !calendarLogs.any(
          (message) =>
              message.contains('fallback=today reason=future_persisted_date'),
        );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'matrixCase': matrixCase,
    'routerPath': routerPath,
    'selectedAnchors': selectedAnchors.map(_logicalAnchorJson).toList(),
    'durableAnchors': durableAnchors
        .map((anchor) => anchor == null ? null : _logicalAnchorJson(anchor))
        .toList(),
    'durableAnchorTargets': durableAnchorTargets,
    'durableAnchorAlignments': durableAnchorAlignments,
    'restoredAnchors': restoredAnchors.map(_logicalAnchorJson).toList(),
    'anchorTargets': anchorTargets,
    'anchorAlignments': anchorAlignments,
    'restoredAnchorTargets': restoredAnchorTargets,
    'restoredAnchorAlignments': restoredAnchorAlignments,
    'stateIdentitiesBefore': stateIdentitiesBefore,
    'stateIdentitiesAfter': stateIdentitiesAfter,
    'elementIdentitiesBefore': elementIdentitiesBefore,
    'elementIdentitiesAfter': elementIdentitiesAfter,
    'scrollControllerIdentitiesBefore': scrollControllerIdentitiesBefore,
    'scrollControllerIdentitiesAfter': scrollControllerIdentitiesAfter,
    'viewportIntentGenerations': viewportIntentGenerations,
    'principalGenerations': principalGenerations,
    'lifecycleGenerations': lifecycleGenerations,
    'storageKeys': storageKeys,
    'calendarLogs': calendarLogs,
    'restorationLogs': restorationLogs,
  };
}

bool _sameLogicalCalendarAnchor(
  _LogicalCalendarAnchor expected,
  _LogicalCalendarAnchor? actual,
) =>
    actual != null &&
    expected.kYear == actual.kYear &&
    expected.kMonth == actual.kMonth &&
    expected.kDay == actual.kDay;

Map<String, int> _logicalAnchorJson(_LogicalCalendarAnchor anchor) =>
    <String, int>{
      'kYear': anchor.kYear,
      'kMonth': anchor.kMonth,
      'kDay': anchor.kDay,
    };

void _expectViewportProcessRestoreContract(
  _ViewportProcessRestoreObservation result,
) {
  debugPrint('CAL_VIEWPORT_PROCESS_MATRIX ${jsonEncode(result.toJson())}');
  expect(
    result.contractSatisfied,
    isTrue,
    reason:
        'The latest settled logical Calendar anchor must remain durable and '
        'visible across route changes, lifecycle changes, hydration, and '
        'fresh-process reconstruction. observation=${jsonEncode(result.toJson())}',
  );
}

Future<_ViewportProcessRestoreObservation> _runViewportProcessRestoreMatrixCase(
  WidgetTester tester,
  _ViewportProcessRestoreCase matrixCase,
) async {
  await _setPhoneViewport(tester);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
  final today = KemeticMath.fromGregorian(DateTime.now());
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    DailyCosmicContextPrefs.lastShownGregorianDateKeyForUser(_testUserId),
    dailyCosmicContextGregorianDateKey(DateTime.now()),
  );
  await _seedWarmSnapshot(title: _cachedTitle, target: today);
  _backend.blockRefresh = false;
  AppRestorationService.instance.resetForTesting();
  AppNavigationRestorationController.instance.resetForTesting();
  RestorationCoordinator.instance.resetForTesting();
  RestorationCoordinator.instance.suppressRestoreForExplicitIntent(
    reason: 'calendar_viewport_process_matrix',
    surfaces: const <String>[
      RestorationCoordinator.calendarOverlayStackSurface,
    ],
  );
  ShareRepo.debugDisableUnreadTrackingForTesting = true;

  final calendarLogs = <String>[];
  final restorationLogs = <String>[];
  calendarDebugLogWriterForTesting = (message) {
    if (message.contains('[calendar]') ||
        message.contains('[restoration]') ||
        message.contains('[CALENDAR]')) {
      calendarLogs.add(message);
    }
  };
  AppRestorationService.debugLogWriter = restorationLogs.add;

  final routers = <GoRouter>[];
  var cleanedUp = false;
  Future<void> cleanUpHarness() async {
    if (cleanedUp) return;
    cleanedUp = true;
    calendarDebugLogWriterForTesting = null;
    AppRestorationService.debugLogWriter = null;
    _backend.release();
    await tester.pumpWidget(const SizedBox.shrink());
    // The production shell schedules a two-second, mounted-guarded guidance
    // refresh after auth. Let that unrelated shell callback observe disposal.
    await tester.pump(const Duration(milliseconds: 2100));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    Supabase.instance.client.auth.stopAutoRefresh();
    await tester.pump();
    ShareRepo.debugDisableUnreadTrackingForTesting = false;
    for (final router in routers.reversed) {
      router.dispose();
    }
    app.resetGlobalFloatingMenuShellForTesting();
  }

  addTearDown(cleanUpHarness);

  Future<GoRouter> mountRouter(String initialLocation) async {
    RestorationCoordinator.instance.beginLaunchRestore(
      reason: RestorationRestoreReason.coldLaunch,
      targetLocation: initialLocation,
    );
    RestorationCoordinator.instance.suppressRestoreForExplicitIntent(
      reason: 'calendar_viewport_process_matrix_no_overlay',
      surfaces: const <String>[
        RestorationCoordinator.calendarOverlayStackSurface,
      ],
    );
    final router = app.createProductionRouterForTesting(
      initialLocation: initialLocation,
    );
    routers.add(router);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => app.buildGlobalFloatingMenuShellForTesting(
          router: router,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    return router;
  }

  Future<CalendarPageState> waitForCalendar({
    bool requireQuiescent = true,
  }) async {
    var stableFrames = 0;
    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      if (i % 4 == 0) {
        await tester.runAsync<void>(() async {
          await Future<void>.delayed(Duration.zero);
        });
      }
      if (find.byType(CalendarPage).evaluate().isEmpty ||
          find
              .byKey(const PageStorageKey<String>('calendar_portrait_scroll'))
              .evaluate()
              .isEmpty) {
        stableFrames = 0;
        continue;
      }
      final state = tester.state<CalendarPageState>(find.byType(CalendarPage));
      final ready =
          state.debugInitialViewportSettledForTesting &&
          (!requireQuiescent || !state.debugHydrationInFlightForTesting);
      stableFrames = ready ? stableFrames + 1 : 0;
      if (stableFrames >= 8) return state;
    }
    fail('Production router never settled the Calendar viewport.');
  }

  Future<CalendarPageState> waitForMountedCalendar() async {
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      if (i % 4 == 0) {
        await tester.runAsync<void>(() async {
          await Future<void>.delayed(Duration.zero);
        });
      }
      if (find.byType(CalendarPage).evaluate().isNotEmpty) {
        final mountedState = tester.state<CalendarPageState>(
          find.byType(CalendarPage),
        );
        final view = mountedState.debugCurrentViewForTesting;
        if (view.kYear != null && view.kMonth != null && view.kDay != null) {
          return mountedState;
        }
      }
    }
    fail('Production router never mounted a Calendar logical viewport.');
  }

  Future<void> openDrawerDestination(
    GoRouter router,
    String label,
    String expectedPath,
  ) async {
    final menu = find.byKey(app.globalMenuButtonKey);
    expect(menu, findsOneWidget);
    await tester.tap(menu);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    final destination = find.byKey(
      ValueKey<String>('global-side-drawer-item-$label'),
    );
    expect(destination, findsOneWidget);
    await tester.tap(destination);
    for (var i = 0; i < 160; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      if (i % 4 == 0) {
        await tester.runAsync<void>(() async {
          await Future<void>.delayed(Duration.zero);
        });
      }
      if (router.routerDelegate.currentConfiguration.uri.path == expectedPath &&
          find.byKey(globalSideDrawerKey).evaluate().isEmpty) {
        return;
      }
    }
    fail('Drawer destination $label did not settle at $expectedPath.');
  }

  _LogicalCalendarAnchor currentLogicalAnchor(CalendarPageState state) {
    final view = state.debugCurrentViewForTesting;
    final kYear = view.kYear;
    final kMonth = view.kMonth;
    final kDay = view.kDay;
    if (kYear == null || kMonth == null || kDay == null) {
      fail('Calendar did not publish a complete logical viewport anchor.');
    }
    return (kYear: kYear, kMonth: kMonth, kDay: kDay);
  }

  Future<CalendarRestorationState> waitForDurableAnchor(
    _LogicalCalendarAnchor expected,
    Map<String, double> visibleAlignments,
  ) async {
    CalendarRestorationState? last;
    for (var i = 0; i < 160; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      if (i % 4 == 0) {
        await tester.runAsync<void>(() async {
          await Future<void>.delayed(Duration.zero);
        });
      }
      last = (await AppRestorationService.instance.readBestSnapshot())
          .snapshot
          ?.calendar;
      if (last != null &&
          last.kYear == expected.kYear &&
          last.kMonth == expected.kMonth &&
          last.kDay == expected.kDay &&
          last.anchorTarget != null &&
          last.anchorAlignment != null &&
          visibleAlignments[last.anchorTarget] != null &&
          (last.anchorAlignment! - visibleAlignments[last.anchorTarget]!)
                  .abs() <=
              0.02) {
        return last;
      }
    }
    fail(
      'Durable Calendar anchor never matched $expected; '
      'last=${last?.toJson()}',
    );
  }

  Future<_LogicalCalendarAnchor> scrollToFutureYear(
    CalendarPageState state,
    int minimumYear,
  ) async {
    final scrollView = find.byKey(
      const PageStorageKey<String>('calendar_portrait_scroll'),
    );
    expect(scrollView, findsOneWidget);
    for (var i = 0; i < 80; i++) {
      final current = currentLogicalAnchor(state);
      if (current.kYear >= minimumYear) break;
      await tester.drag(scrollView, const Offset(0, -1800));
      await tester.pump(const Duration(milliseconds: 220));
      if (i % 2 == 0) {
        await tester.runAsync<void>(() async {
          await Future<void>.delayed(Duration.zero);
        });
      }
    }
    await tester.pump(const Duration(milliseconds: 650));
    final selected = currentLogicalAnchor(state);
    expect(
      selected.kYear,
      greaterThanOrEqualTo(minimumYear),
      reason: 'A real pointer scroll must reach the requested future year.',
    );
    return selected;
  }

  final selectedAnchors = <_LogicalCalendarAnchor>[];
  final durableAnchors = <_LogicalCalendarAnchor?>[];
  final durableAnchorTargets = <String?>[];
  final durableAnchorAlignments = <double?>[];
  final restoredAnchors = <_LogicalCalendarAnchor>[];
  final anchorTargets = <String?>[];
  final anchorAlignments = <double?>[];
  final restoredAnchorTargets = <String?>[];
  final restoredAnchorAlignments = <double?>[];
  final stateIdentitiesBefore = <int>[];
  final stateIdentitiesAfter = <int>[];
  final elementIdentitiesBefore = <int>[];
  final elementIdentitiesAfter = <int>[];
  final scrollControllerIdentitiesBefore = <int>[];
  final scrollControllerIdentitiesAfter = <int>[];
  final viewportIntentGenerations = <int>[];
  final principalGenerations = <int>[];
  final lifecycleGenerations = <int>[];
  final preRouteVisibleAnchorAlignments = <Map<String, double>>[];

  var router = await mountRouter('/');
  var state = await waitForCalendar();

  Future<_LogicalCalendarAnchor> selectAnchor(int minimumYear) async {
    final selected = await scrollToFutureYear(state, minimumYear);
    final visibleAlignments = <String, double>{};
    for (final target in const <String>[
      'dayChip',
      'monthHeader',
      'monthBody',
    ]) {
      final anchor = state.debugViewportAnchorForTargetForTesting(target);
      if (anchor.alignment != null) {
        visibleAlignments[target] = anchor.alignment!;
      }
    }
    expect(
      visibleAlignments,
      isNotEmpty,
      reason: 'At least one logical Calendar marker must be visible.',
    );
    selectedAnchors.add(selected);
    preRouteVisibleAnchorAlignments.add(visibleAlignments);
    stateIdentitiesBefore.add(identityHashCode(state));
    elementIdentitiesBefore.add(
      identityHashCode(tester.element(find.byType(CalendarPage))),
    );
    scrollControllerIdentitiesBefore.add(
      identityHashCode(
        tester
            .widget<CustomScrollView>(
              find.byKey(
                const PageStorageKey<String>('calendar_portrait_scroll'),
              ),
            )
            .controller,
      ),
    );
    viewportIntentGenerations.add(
      RestorationCoordinator.instance.debugUserIntentGenerationForTesting,
    );
    principalGenerations.add(state.debugPrincipalGenerationForTesting);
    lifecycleGenerations.add(state.debugLifecycleGenerationForTesting);
    return selected;
  }

  Future<void> recordLatestDurableAnchor() async {
    final index = durableAnchors.length;
    final selected = selectedAnchors[index];
    final visibleAlignments = preRouteVisibleAnchorAlignments[index];
    final durable = await waitForDurableAnchor(selected, visibleAlignments);
    final durableTarget = durable.anchorTarget!;
    durableAnchors.add((
      kYear: durable.kYear,
      kMonth: durable.kMonth,
      kDay: durable.kDay,
    ));
    durableAnchorTargets.add(durableTarget);
    durableAnchorAlignments.add(durable.anchorAlignment);
    anchorTargets.add(durableTarget);
    anchorAlignments.add(visibleAlignments[durableTarget]);
  }

  void recordRestored(CalendarPageState restoredState) {
    restoredAnchors.add(currentLogicalAnchor(restoredState));
    final selectedTarget = anchorTargets[restoredAnchors.length - 1];
    final restoredViewportAnchor = restoredState
        .debugViewportAnchorForTargetForTesting(selectedTarget);
    restoredAnchorTargets.add(restoredViewportAnchor.target);
    restoredAnchorAlignments.add(restoredViewportAnchor.alignment);
    stateIdentitiesAfter.add(identityHashCode(restoredState));
    elementIdentitiesAfter.add(
      identityHashCode(tester.element(find.byType(CalendarPage))),
    );
    scrollControllerIdentitiesAfter.add(
      identityHashCode(
        tester
            .widget<CustomScrollView>(
              find.byKey(
                const PageStorageKey<String>('calendar_portrait_scroll'),
              ),
            )
            .controller,
      ),
    );
  }

  Future<void> resetProcessState() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync<void>(() async {
      await Future<void>.delayed(Duration.zero);
    });
    CalendarPage.debugResetWarmStateStoreForTesting();
    app.resetGlobalFloatingMenuShellForTesting();
    RestorationCoordinator.instance.resetForTesting();
    AppNavigationRestorationController.instance.resetForTesting();
    AppRestorationService.instance.resetForTesting();
    AppRestorationService.debugLogWriter = restorationLogs.add;
    AppWindowService.instance.resetForTesting();
  }

  Future<void> restoreThroughPlanner({bool blockHydration = false}) async {
    await openDrawerDestination(router, 'Planner', '/rhythm/today');
    await AppNavigationRestorationController.instance.recordPrimaryTabSelection(
      AppSection.planner,
    );
    await recordLatestDurableAnchor();
    if (blockHydration) _backend.blockRefresh = true;
    await resetProcessState();
    final launch = await AppNavigationRestorationController.instance
        .restoreLaunchDestination(isAuthenticated: true);
    expect(launch.route, '/rhythm/today');
    router = await mountRouter(launch.route);
    await openDrawerDestination(router, 'Calendar', '/');
    if (blockHydration) {
      state = await waitForMountedCalendar();
      final restoredBeforeHydration = currentLogicalAnchor(state);
      _backend.release();
      state = await waitForCalendar();
      final restoredAfterHydration = currentLogicalAnchor(state);
      expect(
        restoredAfterHydration,
        restoredBeforeHydration,
        reason: 'Hydration must not replace the restored logical anchor.',
      );
    } else {
      state = await waitForCalendar();
    }
    recordRestored(state);
  }

  Future<void> tapTodayAfterProcessRestore({
    required String reason,
    required bool requireMovement,
  }) async {
    final calendarElement = tester.element(find.byType(CalendarPage));
    final scrollView = find.byKey(
      const PageStorageKey<String>('calendar_portrait_scroll'),
    );
    final controller = tester.widget<CustomScrollView>(scrollView).controller!;
    final stateBefore = state;
    final controllerIdentity = identityHashCode(controller);
    final offsetBefore = controller.offset;
    final commandGeneration = state.debugTodayCommandGenerationForTesting;
    final intentGeneration =
        RestorationCoordinator.instance.debugUserIntentGenerationForTesting;

    expect(find.byTooltip('Today'), findsOneWidget);
    await tester.tap(find.byTooltip('Today'));
    final offsets = <double>[];
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      offsets.add(controller.offset);
    }

    state = tester.state<CalendarPageState>(find.byType(CalendarPage));
    final view = state.debugCurrentViewForTesting;
    final movement = offsets.any((offset) => (offset - offsetBefore).abs() > 1);
    final evidence = <String, Object?>{
      'reason': reason,
      'stateIdentityBefore': identityHashCode(stateBefore),
      'stateIdentityAfter': identityHashCode(state),
      'elementIdentityBefore': identityHashCode(calendarElement),
      'elementIdentityAfter': identityHashCode(
        tester.element(find.byType(CalendarPage)),
      ),
      'scrollControllerIdentityBefore': controllerIdentity,
      'scrollControllerIdentityAfter': identityHashCode(
        tester.widget<CustomScrollView>(scrollView).controller,
      ),
      'offsetBefore': offsetBefore,
      'offsets': offsets,
      'todayCommandGenerationBefore': commandGeneration,
      'todayCommandGenerationAfter':
          state.debugTodayCommandGenerationForTesting,
      'dispatchDisposition': state.debugTodayCommandDispositionForTesting,
      'intentGenerationBefore': intentGeneration,
      'intentGenerationAfter':
          RestorationCoordinator.instance.debugUserIntentGenerationForTesting,
      'todayVisible': state.debugTodayAnchorVisibleForTesting,
      'view': <String, int?>{
        'kYear': view.kYear,
        'kMonth': view.kMonth,
        'kDay': view.kDay,
      },
    };
    debugPrint('TODAY_POST_PROCESS_CYCLE ${jsonEncode(evidence)}');

    expect(identityHashCode(state), identityHashCode(stateBefore));
    expect(
      identityHashCode(tester.element(find.byType(CalendarPage))),
      identityHashCode(calendarElement),
    );
    expect(
      identityHashCode(tester.widget<CustomScrollView>(scrollView).controller),
      controllerIdentity,
    );
    expect(state.debugTodayCommandGenerationForTesting, commandGeneration + 1);
    expect(state.debugTodayCommandDispositionForTesting, 'accepted');
    expect(
      RestorationCoordinator.instance.debugUserIntentGenerationForTesting,
      greaterThan(intentGeneration),
    );
    if (requireMovement) expect(movement, isTrue);
    expect(view, (kYear: today.kYear, kMonth: today.kMonth, kDay: today.kDay));
    expect(state.debugTodayAnchorVisibleForTesting, isTrue);
  }

  switch (matrixCase) {
    case _ViewportProcessRestoreCase.waitTenSeconds:
      await selectAnchor(today.kYear + 3);
      await tester.pump(const Duration(seconds: 10));
      await restoreThroughPlanner();
    case _ViewportProcessRestoreCase.waitThirtySeconds:
      await selectAnchor(today.kYear + 3);
      await tester.pump(const Duration(seconds: 30));
      await restoreThroughPlanner();
    case _ViewportProcessRestoreCase.terminateOnCalendar:
      await selectAnchor(today.kYear + 3);
      await resetProcessState();
      await recordLatestDurableAnchor();
      router = await mountRouter('/');
      state = await waitForCalendar();
      recordRestored(state);
    case _ViewportProcessRestoreCase.plannerRoundTrip:
      await selectAnchor(today.kYear + 3);
      await openDrawerDestination(router, 'Planner', '/rhythm/today');
      await recordLatestDurableAnchor();
      await openDrawerDestination(router, 'Calendar', '/');
      state = await waitForCalendar();
      recordRestored(state);
    case _ViewportProcessRestoreCase.backgroundResume:
      await selectAnchor(today.kYear + 3);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(milliseconds: 300));
      await recordLatestDurableAnchor();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      state = await waitForCalendar();
      recordRestored(state);
    case _ViewportProcessRestoreCase.threeDistinctYears:
      for (var cycle = 0; cycle < 3; cycle++) {
        await selectAnchor(today.kYear + 3 + cycle);
        await restoreThroughPlanner();
      }
    case _ViewportProcessRestoreCase.todayThenLaterScroll:
      expect(find.byTooltip('Today'), findsOneWidget);
      await tester.tap(find.byTooltip('Today'));
      await tester.pump(const Duration(milliseconds: 400));
      await selectAnchor(today.kYear + 3);
      await restoreThroughPlanner();
    case _ViewportProcessRestoreCase.hydrationAfterRestore:
      await selectAnchor(today.kYear + 3);
      await restoreThroughPlanner(blockHydration: true);
    case _ViewportProcessRestoreCase.threeRestoreScrollTodayCycles:
      for (var cycle = 0; cycle < 3; cycle++) {
        await selectAnchor(today.kYear + 3 + cycle);
        await restoreThroughPlanner();
        final restored = currentLogicalAnchor(state);
        await scrollToFutureYear(state, restored.kYear + 1);
        await tapTodayAfterProcessRestore(
          reason: 'cycle_${cycle + 1}',
          requireMovement: true,
        );
      }
    case _ViewportProcessRestoreCase.postRestoreTodayThenLaterScroll:
      await selectAnchor(today.kYear + 3);
      await restoreThroughPlanner();
      await tapTodayAfterProcessRestore(
        reason: 'today_before_later_manual_scroll',
        requireMovement: true,
      );
      await selectAnchor(today.kYear + 4);
      await restoreThroughPlanner();
  }

  final storageKeys =
      prefs
          .getKeys()
          .where(
            (key) =>
                key.contains('app_restoration') || key.contains('restoration'),
          )
          .toList()
        ..sort();
  final relevantCalendarLogs = calendarLogs.where((message) {
    return message.contains('persisting current restoration source=') ||
        message.contains('retained process route handoff source=') ||
        message.contains('lifecycle state=') ||
        message.contains('saved restoration reason=') ||
        message.contains('saved calendar reason=') ||
        message.contains('scheduled calendar reason=') ||
        message.contains('Restored ') ||
        message.contains('Future persisted date') ||
        message.contains('fallback=today') ||
        message.contains('hydration');
  }).toList();
  final filteredRestorationLogs = restorationLogs.where((message) {
    return message.contains('write local start') ||
        message.contains('write local done') ||
        message.contains('read status=') ||
        message.contains('critical primary route committed');
  }).toList();
  final relevantRestorationLogs = filteredRestorationLogs.length <= 24
      ? filteredRestorationLogs
      : <String>[
          filteredRestorationLogs.first,
          ...filteredRestorationLogs.sublist(
            filteredRestorationLogs.length - 23,
          ),
        ];
  final observation = _ViewportProcessRestoreObservation(
    matrixCase: matrixCase.name,
    routerPath: router.routerDelegate.currentConfiguration.uri.path,
    selectedAnchors: selectedAnchors,
    durableAnchors: durableAnchors,
    durableAnchorTargets: durableAnchorTargets,
    durableAnchorAlignments: durableAnchorAlignments,
    restoredAnchors: restoredAnchors,
    anchorTargets: anchorTargets,
    anchorAlignments: anchorAlignments,
    restoredAnchorTargets: restoredAnchorTargets,
    restoredAnchorAlignments: restoredAnchorAlignments,
    stateIdentitiesBefore: stateIdentitiesBefore,
    stateIdentitiesAfter: stateIdentitiesAfter,
    elementIdentitiesBefore: elementIdentitiesBefore,
    elementIdentitiesAfter: elementIdentitiesAfter,
    scrollControllerIdentitiesBefore: scrollControllerIdentitiesBefore,
    scrollControllerIdentitiesAfter: scrollControllerIdentitiesAfter,
    viewportIntentGenerations: viewportIntentGenerations,
    principalGenerations: principalGenerations,
    lifecycleGenerations: lifecycleGenerations,
    storageKeys: storageKeys,
    calendarLogs: relevantCalendarLogs,
    restorationLogs: relevantRestorationLogs,
  );
  await cleanUpHarness();
  return observation;
}

Future<void> _seedDaySheetResumeEntry({required String title}) async {
  final day = KemeticMath.fromGregorian(DateTime.now());
  await SessionResumeService.saveResumeEntry(
    baseRoute: '/',
    kind: 'calendar_day_sheet',
    payload: <String, dynamic>{
      'kYear': day.kYear,
      'kMonth': day.kMonth,
      'kDay': day.kDay,
      'title': title,
      'allowDateChange': true,
      'allDay': true,
    },
  );
}

class _CalendarResumeRetryTimerTracker {
  static const Duration _retryDelay = Duration(milliseconds: 120);

  final List<Timer> _timers = <Timer>[];
  int callbackCount = 0;

  int get activeCount => _timers.where((timer) => timer.isActive).length;

  late final ZoneSpecification zoneSpecification = ZoneSpecification(
    createTimer: (self, parent, zone, duration, callback) {
      final creationStack = StackTrace.current.toString();
      final isCalendarResumeRetry =
          duration == _retryDelay &&
          (creationStack.contains('_restoreDaySheetIfNeeded') ||
              creationStack.contains('_restorePushEventIfNeeded'));
      if (!isCalendarResumeRetry) {
        return parent.createTimer(zone, duration, callback);
      }

      final timer = parent.createTimer(zone, duration, () {
        callbackCount++;
        callback();
      });
      _timers.add(timer);
      return timer;
    },
  );
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  int navigationCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    navigationCount++;
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    navigationCount++;
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    navigationCount++;
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    navigationCount++;
    super.didRemove(route, previousRoute);
  }
}

Future<void> _pumpWarmRestoreWindow(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<
  ({CalendarPageState state, ScrollController controller, Finder scrollView})
>
_mountSettledGestureHydrationCalendar(WidgetTester tester) async {
  await _setPhoneViewport(tester);
  await _seedWarmSnapshot(title: _cachedTitle);
  _backend.freshStandaloneEvents = <Map<String, Object?>>[
    _standaloneEventRow(title: _freshTitle),
  ];
  final key = GlobalKey<CalendarPageState>();
  await _pumpCalendar(tester, key: key);
  await _pumpUntilLoadedEventTitle(tester, key, _freshTitle);

  final scrollView = find.byKey(
    const PageStorageKey<String>('calendar_portrait_scroll'),
  );
  expect(scrollView, findsOneWidget);
  final controller = tester.widget<CustomScrollView>(scrollView).controller!;
  expect(controller.hasClients, isTrue);
  expect(controller.position.maxScrollExtent, greaterThan(1000));
  controller.jumpTo(600);
  await tester.pump();

  _backend
    ..freshStandaloneEvents = <Map<String, Object?>>[
      _standaloneEventRow(title: _gestureHydratedTitle),
    ]
    ..blockRefresh = true;

  return (
    state: key.currentState!,
    controller: controller,
    scrollView: scrollView,
  );
}

Future<void> _pumpUntilLoadedEventTitle(
  WidgetTester tester,
  GlobalKey<CalendarPageState> key,
  String title,
) async {
  for (var i = 0; i < 160; i++) {
    await tester.pump(const Duration(milliseconds: 25));
    if (i % 4 == 0) {
      await tester.runAsync<void>(() async {
        await Future<void>.delayed(Duration.zero);
      });
    }
    if (key.currentState?.debugLoadedEventTitlesForTesting.contains(title) ==
        true) {
      return;
    }
  }
  fail('Calendar never loaded the expected event title: $title');
}

Future<void> _pumpUntilRefreshBlocked(WidgetTester tester) async {
  for (var i = 0; i < 120; i++) {
    await tester.pump(const Duration(milliseconds: 25));
    if (i % 4 == 0) {
      await tester.runAsync<void>(() async {
        await Future<void>.delayed(Duration.zero);
      });
    }
    if (_backend.blockedRefreshRequests > 0) return;
  }
  fail('The real Calendar hydration never reached the blocked backend.');
}

Future<List<double>> _releaseHydrationDuringGesture(
  WidgetTester tester, {
  required TestGesture gesture,
  required CalendarPageState state,
  required ScrollController controller,
  required Future<void> hydration,
}) async {
  final samples = <double>[];
  _backend.release();
  var hydrated = false;
  for (var i = 0; i < 160; i++) {
    if (i % 4 == 0) {
      await gesture.moveBy(const Offset(0, -8));
    }
    await tester.pump(const Duration(milliseconds: 25));
    if (i % 4 == 0) {
      await tester.runAsync<void>(() async {
        await Future<void>.delayed(Duration.zero);
      });
    }
    samples.add(controller.offset);
    hydrated = state.debugLoadedEventTitlesForTesting.contains(
      _gestureHydratedTitle,
    );
    if (hydrated && i >= 8) break;
  }
  expect(
    hydrated,
    isTrue,
    reason: 'The blocked hydration must commit in-test.',
  );
  await hydration;
  for (var i = 0; i < 3; i++) {
    await gesture.moveBy(const Offset(0, -8));
    await tester.pump(const Duration(milliseconds: 25));
    samples.add(controller.offset);
  }
  return samples;
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
  bool includeAnchor = true,
  double? scrollOffset,
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
      if (includeAnchor) 'anchorTarget': 'dayChip',
      if (includeAnchor) 'anchorAlignment': 0.5,
      'viewportHeight': 1200.0,
      'layoutRevision': 1,
      if (scrollOffset != null) 'scrollOffset': scrollOffset,
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
  int blockedRefreshRequests = 0;

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
    blockedRefreshRequests = 0;
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
      if (blockRefresh) {
        blockedRefreshRequests++;
        await _release.future;
      }
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
