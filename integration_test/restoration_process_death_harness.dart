import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/core/navigation_fallback.dart';
import 'package:mobile/core/navigation_persistence_policy.dart';
import 'package:mobile/services/app_navigation_restoration_controller.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';
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
  runApp(_HarnessApp(initialLocation: restored.route, account: account));
  if (_calendarViewportSeedRequired) {
    unawaited(_selectFutureCalendarViewport());
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
