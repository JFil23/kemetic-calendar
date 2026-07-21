import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobile/core/navigation_fallback.dart';
import 'package:mobile/core/navigation_persistence_policy.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show CalendarPage;
import 'package:mobile/main.dart' as production;
import 'package:mobile/services/app_navigation_restoration_controller.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';
import 'package:mobile/services/calendar_snapshot_repository.dart';
import 'package:mobile/services/restoration_coordinator.dart';
import 'package:mobile/services/session_resume_service.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart';

const String _buildFingerprint = String.fromEnvironment(
  'BUILD_VERSION',
  defaultValue: 'restoration-harness-local',
);

final ValueNotifier<String> _harnessState = ValueNotifier<String>('booting');
final ValueNotifier<List<String>> _harnessLogs = ValueNotifier<List<String>>(
  <String>[],
);
Completer<void>? _releaseOlderMutation;
final ValueNotifier<int> _calendarViewportRevision = ValueNotifier<int>(0);
CalendarRestorationState? _savedCalendarViewport;
CalendarRestorationState? _visibleCalendarViewport;
String _calendarViewportDecision = 'none';
bool _calendarViewportSeedRequired = false;

bool get _calendarViewportMode =>
    Uri.base.queryParameters['mode'] == 'calendar-viewport';
bool get _todayPostProcessMode =>
    Uri.base.queryParameters['mode'] == 'today-post-process';

String _calendarAnchorLabel(CalendarRestorationState? state) => state == null
    ? 'none'
    : '${state.kYear}-${state.kMonth}-${state.kDay}'
          '@${state.anchorTarget ?? 'none'}:'
          '${state.anchorAlignment?.toStringAsFixed(6) ?? 'none'}';

CalendarRestorationState _futureCalendarViewportFor(
  ({int kYear, int kMonth, int kDay}) today,
) => CalendarRestorationState(
  kYear: today.kYear + 3,
  kMonth: 2,
  kDay: 17,
  showGregorian: false,
  expansion: 'labeled',
  anchorTarget: 'monthBody',
  anchorAlignment: 0.4375,
  viewportHeight: 844,
  layoutRevision: 2,
);

Future<void> _selectFutureCalendarViewport() async {
  final today = KemeticMath.fromGregorian(DateTime.now());
  final selected = _futureCalendarViewportFor(today);
  final result = await AppRestorationService.instance.saveCalendarState(
    selected,
  );
  if (result.status != AppRestorationMutationStatus.persisted) {
    _harnessState.value = 'calendar-viewport-${result.status.name}';
    _appendLog('Calendar viewport save result=${result.status.name}');
    return;
  }
  _savedCalendarViewport = selected;
  _visibleCalendarViewport = selected;
  _calendarViewportDecision = 'explicit_user_scroll';
  _calendarViewportRevision.value++;
  _harnessState.value = 'calendar-viewport-saved';
  _appendLog(
    'Calendar viewport saved anchor=${_calendarAnchorLabel(selected)}',
  );
}

String _documentTitle(String label, String route) {
  if (!_calendarViewportMode) {
    return 'LOCK_GATE|$_buildFingerprint|$label|$route';
  }
  return 'CAL_VIEWPORT_GATE|$_buildFingerprint|$label|$route|'
      'saved=${_calendarAnchorLabel(_savedCalendarViewport)}|'
      'visible=${_calendarAnchorLabel(_visibleCalendarViewport)}|'
      'decision=$_calendarViewportDecision';
}

String _accountFromUri() {
  final requested = Uri.base.queryParameters['account']?.trim();
  return requested == null || requested.isEmpty
      ? 'restoration-e2e-user-a'
      : 'restoration-e2e-$requested';
}

void _appendLog(String message) {
  final next = <String>[..._harnessLogs.value, message];
  _harnessLogs.value = next.length <= 40
      ? next
      : next.sublist(next.length - 40);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final account = _accountFromUri();
  if (_todayPostProcessMode) {
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'anon-key-0123456789012345678901234567890123456789',
      httpClient: _TodayProcessEmptyBackend(),
    );
    final expiresAt =
        DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/
        1000;
    await Supabase.instance.client.auth.recoverSession(
      jsonEncode(<String, Object?>{
        'access_token': 'today-process-access-$expiresAt',
        'expires_in': 31536000,
        'refresh_token': 'today-process-refresh',
        'token_type': 'bearer',
        'user': <String, Object?>{
          'id': account,
          'app_metadata': <String, Object?>{
            'provider': 'email',
            'providers': <String>['email'],
          },
          'user_metadata': <String, Object?>{},
          'aud': 'authenticated',
          'email': 'today-process@example.com',
          'phone': '',
          'created_at': '2026-01-01T00:00:00.000000Z',
          'email_confirmed_at': '2026-01-01T00:00:00.000000Z',
          'role': 'authenticated',
          'updated_at': '2026-01-01T00:00:00.000000Z',
        },
        'expiresAt': expiresAt,
      }),
    );
    SessionResumeService.debugUserIdResolver = () => account;
    CalendarPage.debugSuppressPendingEventInviteOverlay = true;
    CalendarPage.debugSuppressCalendarOnboardingHelpers = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_v1_completed:$account', true);
    await prefs.setBool('calendar:cid_migration_done', true);
    final now = DateTime.now();
    final todayKey =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    await prefs.setString(
      'daily_cosmic_context:last_shown_gregorian_date:$account',
      todayKey,
    );
    await _seedTodayProcessWarmSnapshot(account);
  }
  AppRestorationService.debugUserIdResolver = () => account;
  AppRestorationService.debugRemoteSnapshotWriter =
      (userId, deviceId, windowId, snapshot) async {};
  AppRestorationService.debugLogWriter = _appendLog;

  await AppWindowService.instance.ensureInitialized();
  await AppRestorationService.instance.initialize();
  if (_calendarViewportMode) {
    final today = KemeticMath.fromGregorian(DateTime.now());
    _savedCalendarViewport = await AppRestorationService.instance
        .readCalendarState();
    final saved = _savedCalendarViewport;
    if (saved == null) {
      _visibleCalendarViewport = CalendarRestorationState(
        kYear: today.kYear,
        kMonth: today.kMonth,
        kDay: today.kDay,
        showGregorian: false,
        expansion: 'labeled',
        anchorTarget: 'dayChip',
        anchorAlignment: 0.5,
        viewportHeight: 844,
        layoutRevision: 2,
      );
      _calendarViewportDecision = 'today_no_saved_anchor';
      _calendarViewportSeedRequired = true;
    } else {
      _visibleCalendarViewport = resolveCalendarViewportRestoration(
        saved: saved,
      );
      _calendarViewportDecision = 'restored_persisted_anchor';
    }
  }
  final restored = await AppNavigationRestorationController.instance
      .restoreLaunchDestination(isAuthenticated: true);
  _appendLog(
    'harness boot account=$account route=${restored.route} '
    'source=${restored.decisionSource}',
  );
  _harnessState.value = 'ready';
  if (_todayPostProcessMode) {
    runApp(
      _TodayPostProcessHarness(
        initialLocation: restored.route,
        account: account,
      ),
    );
    return;
  }
  runApp(_HarnessApp(initialLocation: restored.route, account: account));
  if (_calendarViewportSeedRequired) {
    unawaited(_selectFutureCalendarViewport());
  }
}

Future<void> _seedTodayProcessWarmSnapshot(String account) async {
  final identity = CalendarSnapshotIdentity(
    projectRef: 'example',
    userId: account,
  );
  if (await CalendarSnapshotRepository.instance.restore(identity) != null) {
    return;
  }
  final today = KemeticMath.fromGregorian(DateTime.now());
  final coverageStart = KemeticMath.toGregorian(today.kYear - 4, 1, 1);
  final coverageEnd = KemeticMath.toGregorian(today.kYear + 4, 13, 5);
  await CalendarSnapshotRepository.instance.promote(
    CalendarSnapshotCandidate(
      identity: identity,
      coverage: CalendarSnapshotCoverage(
        startUtc: coverageStart.toUtc(),
        endUtc: coverageEnd.add(const Duration(days: 1)).toUtc(),
      ),
      completedLanes: calendarSnapshotRequiredLanes,
      generation: 1,
      payload: <String, Object?>{
        'nextFlowId': 1,
        'flows': const <Object?>[],
        'notes': <String, Object?>{
          '${today.kYear}-${today.kMonth}-${today.kDay}': <Object?>[
            <String, Object?>{
              'id': 'today-process-warm-event',
              'clientEventId': 'today-process-warm-event',
              'title': 'Today process restoration harness',
              'detail': 'Identity-scoped deterministic warm snapshot',
              'allDay': true,
              'startMinutes': null,
              'endMinutes': null,
              'flowId': -1,
              'resolvedColor': 0xFFB0B6C3,
              'category': 'note',
              'isReminder': false,
              'reminderId': null,
            },
          ],
        },
        'calendarSummaries': const <Object?>[],
        'hiddenCalendarIds': const <String>[],
        'personalCalendarId': null,
        'flowTotalEventCounts': const <String, Object?>{},
        'flowRemainingEventCounts': const <String, Object?>{},
      },
      source: 'today_process_harness_seed',
    ),
  );
}

class _TodayProcessEmptyBackend extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final isRead = request.method == 'GET' || request.method == 'HEAD';
    final body = isRead ? '[]' : '{}';
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
      headers: const <String, String>{
        'content-type': 'application/json',
        'content-range': '0-0/0',
      },
    );
  }
}

class _TodayPostProcessHarness extends StatefulWidget {
  const _TodayPostProcessHarness({
    required this.initialLocation,
    required this.account,
  });

  final String initialLocation;
  final String account;

  @override
  State<_TodayPostProcessHarness> createState() =>
      _TodayPostProcessHarnessState();
}

class _TodayPostProcessHarnessState extends State<_TodayPostProcessHarness> {
  late final GoRouter _router = production.createProductionRouterForTesting(
    initialLocation: widget.initialLocation,
  );
  Timer? _probeTimer;

  @override
  void initState() {
    super.initState();
    _router.routerDelegate.addListener(_scheduleProbeRefresh);
    _probeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _scheduleProbeRefresh(),
    );
  }

  void _scheduleProbeRefresh() {
    if (mounted) setState(() {});
  }

  String _routePath() {
    final uri = _router.routerDelegate.currentConfiguration.uri;
    return uri.path.isEmpty ? '/' : uri.path;
  }

  String _probeTitle() {
    final state = CalendarPage.globalKey.currentState;
    final today = KemeticMath.fromGregorian(DateTime.now());
    final view = state?.debugCurrentViewForTesting;
    final viewLabel = view?.kYear == null
        ? 'none'
        : '${view!.kYear}-${view.kMonth}-${view.kDay}';
    return 'TODAY_PROCESS_GATE|$_buildFingerprint|${_routePath()}|'
        'today=${today.kYear}-${today.kMonth}-${today.kDay}|'
        'view=$viewLabel|'
        'todayVisible=${state?.debugTodayAnchorVisibleForTesting ?? false}|'
        'todayMounted=${state?.debugTodayAnchorMountedForTesting ?? false}|'
        'disposition=${state?.debugTodayCommandDispositionForTesting ?? 'none'}|'
        'commandGeneration=${state?.debugTodayCommandGenerationForTesting ?? 0}|'
        'intentGeneration=${RestorationCoordinator.instance.debugUserIntentGenerationForTesting}|'
        'hydrating=${state?.debugHydrationInFlightForTesting ?? false}|'
        'settled=${state?.debugInitialViewportSettledForTesting ?? false}|'
        'stateIdentity=${state == null ? 0 : identityHashCode(state)}';
  }

  @override
  void dispose() {
    _probeTimer?.cancel();
    _router.routerDelegate.removeListener(_scheduleProbeRefresh);
    _router.dispose();
    production.resetGlobalFloatingMenuShellForTesting();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Today post-process restoration harness',
      routerConfig: _router,
      builder: (context, child) => CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyC): () =>
              openPrimarySection(context, AppSection.calendar, router: _router),
          const SingleActivator(LogicalKeyboardKey.keyP): () =>
              openPrimarySection(context, AppSection.planner, router: _router),
          const SingleActivator(LogicalKeyboardKey.keyT): () =>
              CalendarPage.openMainCalendarAtToday(context),
        },
        child: Focus(
          autofocus: true,
          child: Title(
            color: Colors.transparent,
            title: _probeTitle(),
            child: production.buildGlobalFloatingMenuShellForTesting(
              router: _router,
              dailyCosmicContextUserId: widget.account,
              dailyCosmicContextAuthenticated: true,
              dailyCosmicContextOnboardingComplete: true,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

class _HarnessApp extends StatefulWidget {
  const _HarnessApp({required this.initialLocation, required this.account});

  final String initialLocation;
  final String account;

  @override
  State<_HarnessApp> createState() => _HarnessAppState();
}

class _HarnessAppState extends State<_HarnessApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: widget.initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => NoTransitionPage<void>(
          child: _HarnessRoutePage(
            label: 'Calendar',
            route: '/',
            account: widget.account,
          ),
        ),
      ),
      GoRoute(
        path: '/rhythm/today',
        pageBuilder: (context, state) => NoTransitionPage<void>(
          child: _HarnessRoutePage(
            label: 'Planner',
            route: '/rhythm/today',
            account: widget.account,
          ),
        ),
      ),
      GoRoute(
        path: '/nodes',
        pageBuilder: (context, state) => NoTransitionPage<void>(
          child: _HarnessRoutePage(
            label: 'Library',
            route: '/nodes',
            account: widget.account,
          ),
        ),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Restoration process-death harness',
      routerConfig: _router,
    );
  }
}

class _HarnessRoutePage extends StatelessWidget {
  const _HarnessRoutePage({
    required this.label,
    required this.route,
    required this.account,
  });

  final String label;
  final String route;
  final String account;

  Future<void> _startOlderCalendarMutation() async {
    if (_releaseOlderMutation != null) return;
    final reachedHold = Completer<void>();
    final release = Completer<void>();
    final holdNewerSecondary = Completer<void>();
    _releaseOlderMutation = release;
    var mutationInvocation = 0;
    AppRestorationService.debugBeforeMutationProvenanceRead = () async {
      mutationInvocation += 1;
      if (mutationInvocation == 1) {
        if (!reachedHold.isCompleted) reachedHold.complete();
        await release.future;
        return;
      }
      _harnessState.value = 'newer-secondary-mutation-held';
      _appendLog('newer secondary mutation held before durable write');
      await holdNewerSecondary.future;
    };
    _harnessState.value = 'older-mutation-starting';
    unawaited(
      AppRestorationService.instance
          .saveCacheHints(const <String, dynamic>{
            // NAVIGATION.md UX-RESTORE-002/003 process-death race marker.
            'restorationHarness': 'older-calendar-full-snapshot',
          })
          .then((result) {
            _harnessState.value = 'older-mutation-${result.status.name}';
            _appendLog('older mutation result=${result.status.name}');
          }),
    );
    await reachedHold.future;
    _harnessState.value = 'older-mutation-held';
    _appendLog('older mutation held before provenance read');
  }

  void _releaseOlderCalendarMutation() {
    final release = _releaseOlderMutation;
    if (release == null || release.isCompleted) return;
    release.complete();
    _harnessState.value = 'older-mutation-released';
    _appendLog('older mutation released');
  }

  @override
  Widget build(BuildContext context) {
    final windowId = AppWindowService.instance.currentWindowId ?? '<none>';
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyC): () =>
            openPrimarySection(context, AppSection.calendar),
        const SingleActivator(LogicalKeyboardKey.keyP): () =>
            openPrimarySection(context, AppSection.planner),
        const SingleActivator(LogicalKeyboardKey.keyL): () =>
            openPrimarySection(context, AppSection.library),
        const SingleActivator(LogicalKeyboardKey.keyV): () =>
            unawaited(_selectFutureCalendarViewport()),
      },
      child: Focus(
        autofocus: true,
        child: ValueListenableBuilder<int>(
          valueListenable: _calendarViewportRevision,
          builder: (context, revision, child) => Title(
            color: Colors.transparent,
            title: _documentTitle(label, route),
            child: Scaffold(
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: <Widget>[
                    Text(
                      '$label visible',
                      key: const ValueKey<String>('visible-route'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text('Route: $route'),
                    Text('Account: $account'),
                    Text('Window: $windowId'),
                    Text('Build: $_buildFingerprint'),
                    if (_calendarViewportMode) ...<Widget>[
                      Text(
                        'Saved Calendar: '
                        '${_calendarAnchorLabel(_savedCalendarViewport)}',
                        key: const ValueKey<String>('saved-calendar-viewport'),
                      ),
                      Text(
                        'Visible Calendar: '
                        '${_calendarAnchorLabel(_visibleCalendarViewport)}',
                        key: const ValueKey<String>(
                          'visible-calendar-viewport',
                        ),
                      ),
                      Text(
                        'Viewport decision: $_calendarViewportDecision',
                        key: const ValueKey<String>(
                          'calendar-viewport-decision',
                        ),
                      ),
                    ],
                    ValueListenableBuilder<String>(
                      valueListenable: _harnessState,
                      builder: (context, value, child) => Text('State: $value'),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const ValueKey<String>('select-calendar'),
                      onPressed: () =>
                          openPrimarySection(context, AppSection.calendar),
                      child: const Text('Select Calendar'),
                    ),
                    FilledButton(
                      key: const ValueKey<String>('select-planner'),
                      onPressed: () =>
                          openPrimarySection(context, AppSection.planner),
                      child: const Text('Select Planner'),
                    ),
                    FilledButton(
                      key: const ValueKey<String>('select-library'),
                      onPressed: () =>
                          openPrimarySection(context, AppSection.library),
                      child: const Text('Select Library'),
                    ),
                    if (_calendarViewportMode)
                      FilledButton(
                        key: const ValueKey<String>(
                          'select-future-calendar-viewport',
                        ),
                        onPressed: _selectFutureCalendarViewport,
                        child: const Text('Select future Calendar viewport'),
                      ),
                    OutlinedButton(
                      key: const ValueKey<String>('start-older-mutation'),
                      onPressed: _startOlderCalendarMutation,
                      child: const Text('Start older Calendar mutation'),
                    ),
                    OutlinedButton(
                      key: const ValueKey<String>('release-older-mutation'),
                      onPressed: _releaseOlderCalendarMutation,
                      child: const Text('Release older Calendar mutation'),
                    ),
                    const Divider(height: 32),
                    ValueListenableBuilder<List<String>>(
                      valueListenable: _harnessLogs,
                      builder: (context, logs, child) => SelectableText(
                        logs.join('\n'),
                        key: const ValueKey<String>('restoration-logs'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
