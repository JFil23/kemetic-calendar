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
const int _coldFlowId = 731;

final _backend = _CalendarSwrBackend();

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
      'non-today restored warm snapshot keeps saved month stable through startup expansion',
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

        final frames = <_CalendarMovementFrame>[];
        addTearDown(() async {
          _backend.release();
          await tester.pumpWidget(const SizedBox.shrink());
        });

        await tester.pumpWidget(
          MaterialApp(home: CalendarPage(key: UniqueKey())),
        );
        await _recordMovementFrame(
          tester,
          frames,
          today: today,
          target: target,
        );
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
          isTrue,
          reason:
              'The test must exercise startup single-month mode. '
              'frames=${_movementFrameSummary(frames)}',
        );
        expect(
          frames.any((frame) => frame.fullCalendarScrollVisible),
          isTrue,
          reason:
              'The test must exercise full-scroll expansion. '
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
              'Full-scroll enablement must not visibly shift the restored '
              'cached event. frames=${_movementFrameSummary(frames)}',
        );
      },
    );

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
      'cold start keeps loading authority until the wide event snapshot is complete',
      (tester) async {
        await _setPhoneViewport(tester);
        final calendarKey = GlobalKey<CalendarPageState>();
        _backend
          ..freshFlows = <Map<String, Object?>>[_coldFlowRow()]
          ..freshFlowEvents = <Map<String, Object?>>[
            _flowEventRow(title: _focusedColdTitle, dayOffset: 0),
            _flowEventRow(title: _wideColdTitle, dayOffset: 180),
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
          reason:
              'The fixture must block the authoritative wide event request.',
        );
        expect(
          find.byType(CircularProgressIndicator),
          findsOneWidget,
          reason:
              'A focused subset is not an authoritative cold-start snapshot. '
              'The loader must remain until the wide request completes.',
        );
        expect(find.text(_focusedColdTitle), findsNothing);
        expect(
          calendarKey.currentState!.debugLoadedEventTitlesForTesting,
          isEmpty,
          reason:
              'Partial cold-start events must not be published behind the loader.',
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
              true) {
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
      },
    );
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

    testWidgets('corrupt warm snapshot payload is rejected safely', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_warmCacheKey(_testUserId), '{not valid json');
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
  String snapshotUserId = _testUserId,
  String supabaseUrl = _supabaseUrl,
  int schemaVersion = calendarWarmStartCacheSchemaVersion,
  bool loadCompleted = true,
  ({int kYear, int kMonth, int kDay})? target,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _warmCacheKey(_testUserId),
    jsonEncode(
      _warmSnapshot(
        title: title,
        includeEvent: includeEvent,
        snapshotUserId: snapshotUserId,
        supabaseUrl: supabaseUrl,
        schemaVersion: schemaVersion,
        loadCompleted: loadCompleted,
        target: target,
      ),
    ),
  );
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

String _warmCacheKey(String userId) {
  final key = calendarWarmStartCacheKeyForUrl(
    supabaseUrl: _supabaseUrl,
    userId: userId,
  );
  if (key == null) {
    throw StateError('Test Supabase URL must produce a warm-cache key.');
  }
  return key;
}

Map<String, Object?> _warmSnapshot({
  required String title,
  required bool includeEvent,
  required String snapshotUserId,
  required String supabaseUrl,
  required int schemaVersion,
  required bool loadCompleted,
  ({int kYear, int kMonth, int kDay})? target,
}) {
  final kToday = KemeticMath.fromGregorian(DateTime.now());
  final eventDate = target ?? kToday;
  final projectRef = calendarWarmStartProjectRefFromUrl(supabaseUrl);
  if (projectRef == null) {
    throw StateError('Test Supabase URL must produce a project ref.');
  }
  return <String, Object?>{
    'schemaVersion': schemaVersion,
    'projectRef': projectRef,
    'userId': snapshotUserId,
    'savedAt': DateTime.now().toUtc().toIso8601String(),
    'loadCompleted': loadCompleted,
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
                    'allDay': true,
                    'flowId': -1,
                    'resolvedColor': 0xFFB0B6C3,
                    'category': 'note',
                    'isReminder': false,
                  },
                ],
          }
        : const <String, Object?>{},
    'flowTotalEventCounts': const <String, Object?>{},
    'flowRemainingEventCounts': const <String, Object?>{},
  };
}

Map<String, Object?> _standaloneEventRow({
  required String title,
  ({int kYear, int kMonth, int kDay})? target,
}) {
  final kToday = KemeticMath.fromGregorian(DateTime.now());
  final eventDate = target ?? kToday;
  final start = KemeticMath.toGregorian(
    eventDate.kYear,
    eventDate.kMonth,
    eventDate.kDay,
  ).toUtc();
  return <String, Object?>{
    'id': 'fresh-event-1',
    'calendar_id': null,
    'calendar_name': null,
    'calendar_color': null,
    'calendar_is_personal': true,
    'client_event_id': _clientEventId,
    'title': title,
    'detail': 'Fresh backend event',
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

Future<void> _recordMovementFrame(
  WidgetTester tester,
  List<_CalendarMovementFrame> frames, {
  required ({int kYear, int kMonth, int kDay}) today,
  required ({int kYear, int kMonth, int kDay}) target,
}) async {
  final cachedEventFinder = find.text(_cachedTitle);
  final freshEventFinder = find.text(_freshTitle);
  final cachedEventVisible = cachedEventFinder.evaluate().isNotEmpty;
  final freshEventVisible = freshEventFinder.evaluate().isNotEmpty;
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
      ? tester.getTopLeft(cachedEventFinder.first).dy
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
  return find.text(month.displayShort).evaluate().isNotEmpty ||
      find.text('(${month.displayTransliteration})').evaluate().isNotEmpty;
}

bool _cachedEventDisappearedAfterFirstPaint(
  List<_CalendarMovementFrame> frames,
) {
  var painted = false;
  for (final frame in frames) {
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

class _CalendarSwrBackend extends http.BaseClient {
  Completer<void> _release = Completer<void>();
  Completer<void> _wideFlowRelease = Completer<void>();
  final List<String> requestLog = <String>[];
  List<Map<String, Object?>> freshStandaloneEvents = const [];
  List<Map<String, Object?>> freshFlows = const [];
  List<Map<String, Object?>> freshFlowEvents = const [];
  bool blockRefresh = false;
  bool blockWideFlowRefresh = false;
  bool wideFlowRequestStarted = false;
  bool failRefresh = false;

  void reset() {
    if (!_release.isCompleted) {
      _release.complete();
    }
    if (!_wideFlowRelease.isCompleted) {
      _wideFlowRelease.complete();
    }
    _release = Completer<void>();
    _wideFlowRelease = Completer<void>();
    requestLog.clear();
    freshStandaloneEvents = const [];
    freshFlows = const [];
    freshFlowEvents = const [];
    blockRefresh = false;
    blockWideFlowRefresh = false;
    wideFlowRequestStarted = false;
    failRefresh = false;
  }

  void release() {
    if (!_release.isCompleted) {
      _release.complete();
    }
    releaseWideFlowRefresh();
  }

  void releaseWideFlowRefresh() {
    if (!_wideFlowRelease.isCompleted) {
      _wideFlowRelease.complete();
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

    if (path.contains('/rest/v1/user_event_filing_items_client')) {
      if (blockRefresh) await _release.future;
      if (failRefresh) return _error(request);
      final itemKinds = request.url.queryParametersAll['item_kind'] ?? const [];
      if (itemKinds.any((value) => value == 'eq.flow')) {
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
