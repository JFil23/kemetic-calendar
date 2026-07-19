import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/features/calendar/calendar_page.dart'
    show CalendarPage, CalendarPageState, KemeticMath;
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';
import 'package:mobile/services/calendar_snapshot_repository.dart';
import 'package:mobile/services/restoration_coordinator.dart';
import 'package:mobile/services/session_resume_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userA = '11111111-1111-4111-8111-111111111111';
const _userB = '22222222-2222-4222-8222-222222222222';
const _emailA = 'principal-a@example.com';
const _emailB = 'principal-b@example.com';
const _supabaseUrl = 'https://example.supabase.co';
const _windowId = 'calendar-principal-generation-test-window';
const _cachedATitle = 'A cached private event';
const _hydratedATitle = 'A delayed private event';
const _hydratedBTitle = 'B current private event';

final _backend = _PrincipalGenerationBackend();
late _RecordingCalendarSnapshotStore _snapshotStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _mockAppLinksChannels();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppWindowService.debugWindowIdResolver = () async => _windowId;
    await _ensureSupabaseInitialized();
  });

  setUp(() async {
    _backend.reset();
    _snapshotStore = _RecordingCalendarSnapshotStore();
    CalendarSnapshotRepository.instance.debugReplaceStore(_snapshotStore);
    CalendarPage.debugResetWarmStateStoreForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppWindowService.instance.resetForTesting();
    SessionResumeService.debugUserIdResolver = () =>
        Supabase.instance.client.auth.currentUser?.id;
    AppRestorationService.debugUserIdResolver = () =>
        Supabase.instance.client.auth.currentUser?.id;
    AppRestorationService.debugRemoteWindowSnapshotReader = (_, _, _) async =>
        null;
    AppRestorationService.debugRemoteLatestSnapshotReader = (_) async => null;
    AppRestorationService.debugRemoteSnapshotWriter = (_, _, _, _) async {};
    CalendarPage.debugSuppressPendingEventInviteOverlay = true;
    CalendarPage.debugSuppressCalendarOnboardingHelpers = true;
    RestorationCoordinator.instance.suppressRestoreForExplicitIntent(
      reason: 'calendar_principal_generation_test',
      surfaces: const <String>[
        RestorationCoordinator.calendarOverlayStackSurface,
      ],
    );
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    await _signIn(_emailA);
    await _seedCommonPreferences();
  });

  tearDown(() async {
    _backend.releaseA();
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    SessionResumeService.debugUserIdResolver = null;
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

  testWidgets(
    'A to B signedIn replacement commits only the current principal generation',
    (tester) async {
      await _setPhoneViewport(tester);
      await _seedWarmSnapshot(userId: _userA, title: _cachedATitle);
      _backend.blockAStandalone = true;
      final calendarKey = GlobalKey<CalendarPageState>();

      await _pumpCalendar(tester, calendarKey);
      await _pumpUntil(
        tester,
        () =>
            calendarKey.currentState?.debugLoadedEventTitlesForTesting.contains(
              _cachedATitle,
            ) ==
            true,
      );
      await _pumpUntil(tester, () => _backend.aStandaloneStarted);
      final mountedState = calendarKey.currentState;

      await _signIn(_emailB);
      await tester.pump();
      await _drainRealAsync(tester);

      final aVisibleImmediatelyAfterReplacement =
          calendarKey.currentState?.debugLoadedEventTitlesForTesting.contains(
            _cachedATitle,
          ) ==
          true;
      final sameStateMounted = identical(
        mountedState,
        calendarKey.currentState,
      );

      _backend.releaseA();
      var staleAPublishedUnderB = false;
      var staleARenderedUnderB = false;
      for (var i = 0; i < 360; i++) {
        final titles =
            calendarKey.currentState?.debugLoadedEventTitlesForTesting ??
            const <String>{};
        staleAPublishedUnderB |= titles.contains(_hydratedATitle);
        staleARenderedUnderB |= find
            .text(_hydratedATitle)
            .evaluate()
            .isNotEmpty;
        if (_backend.bStandaloneRequests > 0 &&
            titles.contains(_hydratedBTitle)) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 25));
        if (i % 4 == 0) await _drainRealAsync(tester);
      }
      await tester.pump(const Duration(milliseconds: 750));
      await _drainRealAsync(tester);

      final bKey = _snapshotIdentity(_userB).storageKey;
      final bWriteTitles =
          _snapshotStore.writeHistory[bKey]
              ?.map(_snapshotTitlesFromRaw)
              .toList(growable: false) ??
          const <Set<String>>[];
      final bNamespaceReceivedA = bWriteTitles.any(
        (titles) =>
            titles.contains(_hydratedATitle) || titles.contains(_cachedATitle),
      );
      final finalTitles =
          calendarKey.currentState?.debugLoadedEventTitlesForTesting ??
          const <String>{};
      final violations = <String>[
        if (!sameStateMounted) 'Calendar state was replaced during signedIn',
        if (aVisibleImmediatelyAfterReplacement)
          'A-scoped visible data survived the A to B replacement',
        if (staleAPublishedUnderB)
          'A delayed hydration published while B was active',
        if (staleARenderedUnderB)
          'A delayed hydration rendered while B was active',
        if (bNamespaceReceivedA) 'A payload entered B warm-cache namespace',
        if (_backend.bStandaloneRequests == 0)
          'B hydration was discarded behind A flight',
        if (!finalTitles.contains(_hydratedBTitle))
          'B did not receive a current hydration',
        if (finalTitles.contains(_cachedATitle) ||
            finalTitles.contains(_hydratedATitle))
          'Final B model retained A-scoped content',
      ];

      // This receipt intentionally exposes every invariant at once. A later B
      // overwrite cannot conceal a transient A write into B's namespace.
      // ignore: avoid_print
      print(
        '[principal-generation] same_state=$sameStateMounted '
        'a_visible_after_replace=$aVisibleImmediatelyAfterReplacement '
        'a_published_under_b=$staleAPublishedUnderB '
        'a_rendered_under_b=$staleARenderedUnderB '
        'b_requests=${_backend.bStandaloneRequests} '
        'b_namespace_received_a=$bNamespaceReceivedA '
        'b_write_titles=$bWriteTitles final_titles=$finalTitles',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 5));
      expect(violations, isEmpty);
    },
  );

  testWidgets('same-user token refresh retains principal-owned visible state', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    await _seedWarmSnapshot(userId: _userA, title: _cachedATitle);
    _backend.blockAStandalone = true;
    final calendarKey = GlobalKey<CalendarPageState>();
    final authEvents = <AuthChangeEvent>[];
    final sub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) => authEvents.add(data.event),
    );
    addTearDown(sub.cancel);

    await _pumpCalendar(tester, calendarKey);
    await _pumpUntil(
      tester,
      () =>
          calendarKey.currentState?.debugLoadedEventTitlesForTesting.contains(
            _cachedATitle,
          ) ==
          true,
    );
    final mountedState = calendarKey.currentState;

    await Supabase.instance.client.auth.refreshSession();
    await tester.pump();
    await _drainRealAsync(tester);

    expect(authEvents, contains(AuthChangeEvent.tokenRefreshed));
    expect(calendarKey.currentState, same(mountedState));
    expect(
      calendarKey.currentState!.debugLoadedEventTitlesForTesting,
      contains(_cachedATitle),
      reason:
          'A same-user token refresh must not masquerade as a cross-account '
          'replacement or clear A-owned visible state.',
    );
    _backend.releaseA();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 5));
  });

  testWidgets(
    'ordinary sign-out teardown followed by B login remains isolated',
    (tester) async {
      await _setPhoneViewport(tester);
      await _seedWarmSnapshot(userId: _userA, title: _cachedATitle);
      _backend.blockAStandalone = true;
      final calendarKey = GlobalKey<CalendarPageState>();

      await _pumpCalendar(tester, calendarKey);
      await _pumpUntil(
        tester,
        () =>
            calendarKey.currentState?.debugLoadedEventTitlesForTesting.contains(
              _cachedATitle,
            ) ==
            true,
      );

      _backend.releaseA();
      await _pumpUntil(
        tester,
        () =>
            calendarKey.currentState?.debugLoadedEventTitlesForTesting.contains(
              _hydratedATitle,
            ) ==
            true,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 5));

      await tester.runAsync<void>(() async {
        await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
        await _signIn(_emailB);
      });
      final bCalendarKey = GlobalKey<CalendarPageState>();
      await _pumpCalendar(tester, bCalendarKey);
      await _pumpUntil(
        tester,
        () =>
            bCalendarKey.currentState?.debugLoadedEventTitlesForTesting
                .contains(_hydratedBTitle) ==
            true,
        maxPumps: 360,
      );
      expect(
        bCalendarKey.currentState!.debugLoadedEventTitlesForTesting,
        contains(_hydratedBTitle),
      );
      expect(
        bCalendarKey.currentState!.debugLoadedEventTitlesForTesting,
        isNot(contains(_hydratedATitle)),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 5));
    },
  );
}

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

Future<void> _signIn(String email) => Supabase.instance.client.auth
    .signInWithPassword(email: email, password: 'fixture-password');

Future<void> _seedCommonPreferences() async {
  final prefs = await SharedPreferences.getInstance();
  for (final userId in const <String>[_userA, _userB]) {
    await prefs.setBool('onboarding_v1_completed:$userId', true);
  }
  await prefs.setBool('calendar:cid_migration_done', true);
  final today = KemeticMath.fromGregorian(DateTime.now());
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final raw = jsonEncode(<String, Object?>{
    'schemaVersion': AppRestorationService.schemaVersion,
    'userId': _userA,
    'windowId': _windowId,
    'updatedAtMs': nowMs,
    'calendar': <String, Object?>{
      'kYear': today.kYear,
      'kMonth': today.kMonth,
      'kDay': today.kDay,
      'showGregorian': false,
      'expansion': 'details',
      'anchorTarget': 'dayChip',
      'anchorAlignment': 0.5,
      'viewportHeight': 1200.0,
      'layoutRevision': 1,
    },
  });
  await prefs.setString('app_restoration_v1:$_userA:$_windowId', raw);
  await prefs.setString('app_restoration_latest_v2:$_userA', raw);
  await prefs.setString('app_restoration_last_user_v2', _userA);
}

Future<void> _seedWarmSnapshot({
  required String userId,
  required String title,
}) async {
  final today = KemeticMath.fromGregorian(DateTime.now());
  final start = DateUtils.dateOnly(
    DateTime.now(),
  ).subtract(const Duration(days: 60)).toUtc();
  final end = DateUtils.dateOnly(
    DateTime.now(),
  ).add(const Duration(days: 90)).toUtc();
  final identity = _snapshotIdentity(userId);
  final candidate = CalendarSnapshotCandidate(
    identity: identity,
    coverage: CalendarSnapshotCoverage(startUtc: start, endUtc: end),
    completedLanes: calendarSnapshotRequiredLanes,
    generation: 1,
    payload: <String, Object?>{
      'nextFlowId': 1,
      'flows': const <Object?>[],
      'notes': <String, Object?>{
        '${today.kYear}-${today.kMonth}-${today.kDay}': <Object?>[
          <String, Object?>{
            'id': 'cached-a-event',
            'clientEventId': 'cached-a-event-cid',
            'title': title,
            'detail': 'A-only cached payload',
            'allDay': true,
            'flowId': -1,
            'resolvedColor': 0xFFB0B6C3,
            'category': 'note',
            'isReminder': false,
          },
        ],
      },
      'calendarSummaries': const <Object?>[],
      'hiddenCalendarIds': const <String>[],
      'personalCalendarId': null,
      'flowTotalEventCounts': const <String, Object?>{},
      'flowRemainingEventCounts': const <String, Object?>{},
    },
    source: 'principal_generation_seed',
  );
  await CalendarSnapshotRepository.instance.debugWriteRaw(
    identity,
    CalendarSnapshotRepository.instance.encodeCandidate(candidate),
  );
}

CalendarSnapshotIdentity _snapshotIdentity(String userId) =>
    CalendarSnapshotIdentity(projectRef: 'example', userId: userId);

Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1200);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpCalendar(
  WidgetTester tester,
  GlobalKey<CalendarPageState> key,
) async {
  await tester.pumpWidget(MaterialApp(home: CalendarPage(key: key)));
  await tester.pump();
  await _drainRealAsync(tester);
}

Future<void> _drainRealAsync(WidgetTester tester) async {
  await tester.runAsync<void>(() async {
    await Future<void>.delayed(Duration.zero);
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxPumps = 240,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (condition()) return;
    await tester.pump(const Duration(milliseconds: 25));
    if (i % 4 == 0) await _drainRealAsync(tester);
  }
  expect(
    condition(),
    isTrue,
    reason: 'Timed out waiting for fixture condition.',
  );
}

Map<String, Object?> _sessionFor(
  String userId,
  String email, {
  String tokenSuffix = 'password',
}) {
  final expiresAt =
      DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/
      1000;
  final principal = userId == _userA ? 'a' : 'b';
  return <String, Object?>{
    'access_token': 'test-access-token-$principal-$tokenSuffix',
    'expires_in': 31536000,
    'refresh_token': 'test-refresh-token-$principal-$tokenSuffix',
    'token_type': 'bearer',
    'user': <String, Object?>{
      'id': userId,
      'app_metadata': <String, Object?>{
        'provider': 'email',
        'providers': <String>['email'],
      },
      'user_metadata': <String, Object?>{},
      'aud': 'authenticated',
      'email': email,
      'phone': '',
      'created_at': '2026-01-01T00:00:00.000000Z',
      'email_confirmed_at': '2026-01-01T00:00:00.000000Z',
      'role': 'authenticated',
      'updated_at': '2026-01-01T00:00:00.000000Z',
    },
    'expiresAt': expiresAt,
  };
}

Set<String> _snapshotTitlesFromRaw(String raw) {
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final notes = decoded['notes'];
  if (notes is! Map) return const <String>{};
  return <String>{
    for (final bucket in notes.values)
      if (bucket is List)
        for (final note in bucket)
          if (note is Map && note['title'] is String) note['title'] as String,
  };
}

Map<String, Object?> _standaloneRow(String principal) {
  final isA = principal == 'A';
  final start = DateUtils.dateOnly(DateTime.now()).toUtc();
  return <String, Object?>{
    'id': 'hydrated-${principal.toLowerCase()}-event',
    'calendar_id': null,
    'calendar_name': null,
    'calendar_color': null,
    'calendar_is_personal': true,
    'client_event_id': 'hydrated-${principal.toLowerCase()}-event-cid',
    'title': isA ? _hydratedATitle : _hydratedBTitle,
    'detail': '$principal-only delayed payload',
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

class _RecordingCalendarSnapshotStore extends MemoryCalendarSnapshotStore {
  final Map<String, List<String>> writeHistory = <String, List<String>>{};

  @override
  Future<void> write(String key, String value) async {
    writeHistory.putIfAbsent(key, () => <String>[]).add(value);
    await super.write(key, value);
  }
}

class _PrincipalGenerationBackend extends http.BaseClient {
  Completer<void> _releaseA = Completer<void>();
  bool blockAStandalone = false;
  bool aStandaloneStarted = false;
  int bStandaloneRequests = 0;

  void reset() {
    releaseA();
    _releaseA = Completer<void>();
    blockAStandalone = false;
    aStandaloneStarted = false;
    bStandaloneRequests = 0;
  }

  void releaseA() {
    if (!_releaseA.isCompleted) _releaseA.complete();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path.endsWith('/auth/v1/token') &&
        request.url.queryParameters['grant_type'] == 'password') {
      final body = jsonDecode((request as http.Request).body) as Map;
      final email = body['email'] as String;
      return _json(
        request,
        email == _emailA
            ? _sessionFor(_userA, _emailA)
            : _sessionFor(_userB, _emailB),
      );
    }
    if (path.endsWith('/auth/v1/token') &&
        request.url.queryParameters['grant_type'] == 'refresh_token') {
      return _json(
        request,
        _sessionFor(_userA, _emailA, tokenSuffix: 'refresh'),
      );
    }
    if (path.contains('/auth/v1/')) return _json(request, <String, Object?>{});
    if (path.contains('/rest/v1/rpc/')) return _json(request, null);
    if (path.contains('/rest/v1/flows_with_calendars')) {
      return _json(request, const <Object?>[]);
    }
    if (path.contains('/rest/v1/user_event_filing_items_client')) {
      final itemKinds = request.url.queryParametersAll['item_kind'] ?? const [];
      if (itemKinds.any((value) => value == 'eq.flow')) {
        return _json(request, const <Object?>[]);
      }
      final principal = _requestPrincipal(request);
      if (principal == 'A') {
        aStandaloneStarted = true;
        if (blockAStandalone) await _releaseA.future;
        return _json(request, <Object?>[_standaloneRow('A')]);
      }
      if (principal == 'B') {
        bStandaloneRequests++;
        return _json(request, <Object?>[_standaloneRow('B')]);
      }
      return _json(request, const <Object?>[]);
    }
    if (path.contains('/rest/v1/')) return _json(request, const <Object?>[]);
    return _json(request, <String, Object?>{});
  }

  String? _requestPrincipal(http.BaseRequest request) {
    final authorization = request.headers['authorization'] ?? '';
    if (authorization.contains('test-access-token-a-')) return 'A';
    if (authorization.contains('test-access-token-b-')) return 'B';
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
}
