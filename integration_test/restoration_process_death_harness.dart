import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/core/navigation_fallback.dart';
import 'package:mobile/core/navigation_persistence_policy.dart';
import 'package:mobile/services/app_navigation_restoration_controller.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';

const String _buildFingerprint = String.fromEnvironment(
  'BUILD_VERSION',
  defaultValue: 'restoration-harness-local',
);

final ValueNotifier<String> _harnessState = ValueNotifier<String>('booting');
final ValueNotifier<List<String>> _harnessLogs = ValueNotifier<List<String>>(
  <String>[],
);
Completer<void>? _releaseOlderMutation;

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
  final restored = await AppNavigationRestorationController.instance
      .restoreLaunchDestination(isAuthenticated: true);
  _appendLog(
    'harness boot account=$account route=${restored.route} '
    'source=${restored.decisionSource}',
  );
  _harnessState.value = 'ready';
  runApp(_HarnessApp(initialLocation: restored.route, account: account));
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
      },
      child: Focus(
        autofocus: true,
        child: Title(
          color: Colors.transparent,
          title: 'LOCK_GATE|$_buildFingerprint|$label|$route',
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
    );
  }
}
