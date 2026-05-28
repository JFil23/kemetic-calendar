import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('restoration architecture guard', () {
    test('scoped session persistence stays in the approved files', () async {
      final matches = await _filesContainingAny(<String>[
        'SessionResumeService.saveScopedState',
        'SessionResumeService.readScopedState',
      ]);

      expect(
        matches,
        unorderedEquals(<String>[
          'lib/features/calendar/calendar_page.dart',
          'lib/features/rhythm/pages/todays_alignment_page.dart',
        ]),
      );
    });

    test('permanent restoration writes stay in the approved files', () async {
      final saveCalendarMatches = await _filesContainingAny(<String>[
        'AppRestorationService.instance.saveCalendarState',
      ]);
      expect(
        saveCalendarMatches,
        unorderedEquals(<String>['lib/features/calendar/calendar_page.dart']),
      );

      final saveDayViewMatches = await _filesContainingAny(<String>[
        'AppRestorationService.instance.saveDayViewState',
      ]);
      expect(
        saveDayViewMatches,
        unorderedEquals(<String>['lib/features/calendar/calendar_page.dart']),
      );

      final saveDaySheetMatches = await _filesContainingAny(<String>[
        'AppRestorationService.instance.saveDaySheetState',
      ]);
      expect(
        saveDaySheetMatches,
        unorderedEquals(<String>['lib/features/calendar/calendar_page.dart']),
      );

      final saveRouteMatches = await _filesContainingAny(<String>[
        'AppRestorationService.instance.saveRouteLocation',
      ]);
      expect(
        saveRouteMatches,
        unorderedEquals(<String>['lib/services/restoration_coordinator.dart']),
      );
    });

    test('calendar action entrypoints stay centralized', () async {
      final menuMatches = await _filesContainingAny(<String>[
        'showActionsMenuFromOutside(',
        'openQuickAddFromOutside(',
      ]);
      expect(
        menuMatches,
        unorderedEquals(<String>['lib/features/calendar/calendar_page.dart']),
      );

      final unavailableMatches = await _filesContainingAny(<String>[
        'Menu is unavailable right now.',
        'Calendar actions are unavailable right now.',
        'New note is unavailable right now.',
      ]);
      expect(unavailableMatches, isEmpty);
    });

    test('today toolbar actions use the calendar glyph', () async {
      final deprecatedTodayIconMatches = await _filesContainingAny(<String>[
        'Icons.calendar_today_outlined',
        'Icons.today',
      ]);
      expect(deprecatedTodayIconMatches, isEmpty);

      final todayGlyphMatches = await _filesContainingAny(<String>[
        'KemeticAppBarTodayIcon',
      ]);
      expect(
        todayGlyphMatches,
        containsAll(<String>[
          'lib/features/calendar/calendar_page.dart',
          'lib/features/calendar/day_view_chrome.dart',
          'lib/features/profile/profile_page.dart',
          'lib/features/rhythm/pages/todays_alignment_page.dart',
          'lib/widgets/kemetic_app_bar_action.dart',
        ]),
      );

      final glyphDefinitionMatches = await _filesContainingAny(<String>[
        "static const String today = '𓇳'",
      ]);
      expect(glyphDefinitionMatches, <String>['lib/shared/glossy_text.dart']);
    });

    test('calendar sheet continuity keeps the boot retry restorer', () async {
      final main = await File('lib/main.dart').readAsString();
      final calendar = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();

      expect(main, contains('_restoreDetachedCalendarOverlayAfterBoot'));
      expect(main, contains('restoreDetachedCalendarOverlayFromAnyContext'));
      expect(
        calendar,
        contains('RestorationCoordinator.instance.readBestSnapshot'),
      );
      expect(main, isNot(contains('CalendarContinuityOverlayHost')));
      expect(calendar, isNot(contains('CalendarContinuityOverlayHost')));
    });

    test(
      'overlay lifecycle preserve window survives resumed callbacks',
      () async {
        final coordinator = await File(
          'lib/services/restoration_coordinator.dart',
        ).readAsString();
        final noteLifecycle = _sourceBetween(
          coordinator,
          'void noteLifecycleState(AppLifecycleState state)',
          'bool get shouldPreserveOverlayForLifecycleClose',
        );
        final preserveWindow = _sourceBetween(
          coordinator,
          'bool get shouldPreserveOverlayForLifecycleClose',
          'Future<Map<String, dynamic>?> readSurfaceState',
        );

        expect(noteLifecycle, contains('case AppLifecycleState.resumed:'));
        expect(noteLifecycle, isNot(contains('_lastExitLifecycleAt = null')));
        expect(preserveWindow, contains('DateTime.now().difference(lastExit)'));
        expect(preserveWindow, contains('_lifecycleOverlayPreserveWindow'));
      },
    );

    test(
      'calendar sheet continuity retries after route and auth settle',
      () async {
        final main = await File('lib/main.dart').readAsString();
        final bootRetry = _sourceBetween(
          main,
          'Future<void> _restoreDetachedCalendarOverlayAfterBoot() async',
          'Future<void> _dismissOverlay() async',
        );
        final authResume = _sourceBetween(
          main,
          'Future<void> _maybeResumeSessionRoute() async',
          '// -- Log app_open once per cold start after auth is present',
        );

        expect(
          main,
          contains('unawaited(_restoreDetachedCalendarOverlayAfterBoot())'),
        );
        expect(bootRetry, contains('attempt < 30'));
        expect(bootRetry, contains('Duration(milliseconds: 150)'));
        expect(bootRetry, contains('_rootNavigatorKey.currentContext'));
        expect(bootRetry, contains('currentConfiguration.uri'));
        expect(
          bootRetry,
          contains('restoreDetachedCalendarOverlayFromAnyContext'),
        );
        expect(bootRetry, contains('currentLocation: currentLocation'));

        expect(authResume, contains('restorableOverlayParentRouteFromStack'));
        expect(authResume, contains('readOverlayStack()'));
        expect(authResume, contains('readRouteLocation('));
        expect(authResume, contains('includeRemote: true'));
        expect(authResume, contains('_router.go(savedLocation)'));
        expect(
          authResume,
          isNot(contains('restorableRouteLocationFromSnapshot')),
        );
        expect(
          authResume,
          isNot(contains("savedLocation.startsWith('/calendar/')")),
        );
        expect(authResume, contains('addPostFrameCallback'));
        expect(
          authResume,
          contains('restoreDetachedCalendarOverlayFromAnyContext'),
        );
        expect(authResume, contains('currentLocation: savedLocation'));
      },
    );

    test('calendar action menus preserve non-calendar parent routes', () async {
      final calendar = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final actionEntrypoints = _sourceBetween(
        calendar,
        'static Future<void> showActionsMenuFromAnyContext',
        'static Future<void> openMyFlowsFromAnyContext',
      );

      expect(actionEntrypoints, contains('_shouldUseMountedCalendarHost'));
      expect(actionEntrypoints, contains('_showDetachedActionsMenu'));
      expect(
        actionEntrypoints,
        isNot(
          contains(
            'final state = _mountedState;\n'
            '    if (state != null)',
          ),
        ),
      );

      final sharedCalendarEntrypoint = _sourceBetween(
        calendar,
        'static Future<void> openSharedCalendarsFromAnyContext',
        'static Future<void> openFlowStudioFromAnyContext',
      );
      expect(
        sharedCalendarEntrypoint,
        contains('_shouldUseMountedCalendarHost'),
      );
      expect(sharedCalendarEntrypoint, contains('_openSharedCalendarsSheet'));
      expect(
        sharedCalendarEntrypoint,
        contains('_openDetachedSharedCalendarsSheet'),
      );

      final detachedActions = _sourceBetween(
        calendar,
        'static Future<void> _showDetachedActionsMenu',
        'static Future<void> _openDetachedSharedCalendarsSheet',
      );
      expect(detachedActions, contains('_detachedCalendarActions'));
      expect(detachedActions, contains('void navigate(String location)'));
      expect(detachedActions, contains('onNavigate(location)'));
      expect(detachedActions, contains('context.go(location)'));
      expect(detachedActions, contains('openSharedCalendarsFromAnyContext'));
      expect(detachedActions, isNot(contains('_routeHomeForDetachedLaunch')));

      final detachedSharedCalendars = _sourceBetween(
        calendar,
        'static Future<void> _openDetachedSharedCalendarsSheet',
        'static Future<void> _openDetachedFlowStudioSheet',
      );
      expect(
        detachedSharedCalendars,
        contains('_currentRouteLocationForContext(context)'),
      );
      expect(
        detachedSharedCalendars,
        contains('_saveDetachedCalendarOverlayState'),
      );
      expect(detachedSharedCalendars, contains('parentRoute: parentRoute'));
      expect(
        detachedSharedCalendars,
        contains('_kCalendarOverlayKindSharedCalendars'),
      );
      expect(detachedSharedCalendars, contains('SharedCalendarsSheet.show'));
      expect(detachedSharedCalendars, contains('onContinuityChanged'));
      expect(
        detachedSharedCalendars,
        contains('_clearDetachedCalendarOverlayState'),
      );
    });

    test('calendar launch restores app-owned route and sheet state', () async {
      final main = await File('lib/main.dart').readAsString();
      final calendar = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final bootRestore = _sourceBetween(
        main,
        'Future<String?> _readBootRestoredLocation() async',
        'String? _redirectExternalAppLink(Uri uri)',
      );
      final routes = _sourceBetween(
        main,
        'final _router = GoRouter(',
        '/* ───────────────────────── App Widgets',
      );
      final nodeRoutes = _sourceBetween(
        routes,
        "path: '/nodes',",
        "path: '/reflections',",
      );
      final parentResolver = _sourceBetween(
        calendar,
        'static String? restorableOverlayParentRouteFromStack',
        'static Future<void> _saveDetachedCalendarOverlayState',
      );
      final authRoot = _sourceBetween(main, '// Authenticated', '  }\n}');
      final authedApp = _sourceBetween(
        main,
        'Widget _buildAuthedApp()',
        '@override\n  Widget build',
      );
      final initialLocation = _sourceBetween(
        main,
        'String _resolveInitialLocation()',
        'Future<void> _readBootInitialPushIntent() async',
      );

      expect(bootRestore, contains('readBestSnapshot'));
      expect(bootRestore, contains('AppRestorationReadStatus.restored'));
      expect(bootRestore, contains('AppRestorationReadStatus.tentative'));
      expect(bootRestore, contains('restorableOverlayParentRouteFromStack'));
      expect(bootRestore, contains('result.snapshot?.routeLocation?.trim()'));
      expect(bootRestore, contains('SessionResumeService.readRouteLocation'));
      expect(bootRestore, contains('_restorableLaunchLocation'));
      expect(bootRestore, contains('_isContinuityRouteLocation'));
      expect(
        bootRestore,
        isNot(contains('restorableRouteLocationFromSnapshot')),
      );
      expect(bootRestore, isNot(contains('dayView')));
      expect(main, contains('Future<void> _readBootInitialPushIntent() async'));
      expect(
        main,
        contains('Future<void> _readBootInitialAppLinkIntent() async'),
      );
      expect(main, contains('Future<Uri?> _readInitialAppLinkUri() async'));
      expect(main, contains('_initialLocationFromAppLinkIntent'));
      expect(main, contains('_isBootInitialAppLinkUri'));
      expect(main, contains('String? _bootExplicitIntentLocation'));
      expect(
        main.indexOf('await _readBootInitialAppLinkIntent();'),
        lessThan(main.indexOf('await _readBootInitialPushIntent();')),
      );
      expect(
        main.indexOf('await _readBootInitialAppLinkIntent();'),
        lessThan(main.indexOf('_bootRestoredLocation =')),
      );
      expect(
        main.indexOf('await _readBootInitialPushIntent();'),
        lessThan(main.indexOf('_bootRestoredLocation =')),
      );
      expect(
        initialLocation.indexOf('_bootExplicitIntentLocation'),
        lessThan(initialLocation.indexOf('_bootRestoredLocation')),
      );
      expect(
        main,
        contains('_suppressPassiveLaunchSurfacesForExplicitIntentIfNeeded'),
      );
      expect(main, contains('suppressRestoreForExplicitIntent'));
      expect(main, contains('_deferSessionResumeForPushNavigation = true;'));

      expect(parentResolver, contains('_isRootRouteLocation(parentRoute)'));
      expect(parentResolver, contains('return null;'));
      expect(parentResolver, contains('return parentRoute;'));

      expect(routes, isNot(contains('restorationScopeId:')));
      expect(authedApp, isNot(contains('restorationScopeId:')));
      expect(nodeRoutes, isNot(contains('enabled: false')));
      expect(authRoot, contains("SessionTrackedRoute(location: '/'"));
      expect(routes, isNot(contains("path: '/calendar'")));
      expect(routes, isNot(contains("path: 'day/:kYear/:kMonth/:kDay'")));
      expect(routes, isNot(contains("path: 'shared-calendars'")));
      expect(routes, isNot(contains("path: 'flow-studio'")));
      expect(main, isNot(contains('ModalBottomSheetRoute<Object?>')));
      expect(calendar, isNot(contains('restorableRouteLocationFromSnapshot')));
      expect(calendar, isNot(contains('/calendar/day/')));
      expect(calendar, isNot(contains('_CalendarMountedStateBuilder')));
      expect(calendar, isNot(contains('_buildRestoredFlowStudioRouteSheet')));
    });

    test('secondary pages can become launch routes from persistence', () async {
      final main = await File('lib/main.dart').readAsString();
      final bootRestore = _sourceBetween(
        main,
        'Future<String?> _readBootRestoredLocation() async',
        'String? _redirectExternalAppLink(Uri uri)',
      );
      final authResume = _sourceBetween(
        main,
        'Future<void> _maybeResumeSessionRoute() async',
        '// -- Log app_open once per cold start after auth is present',
      );
      final routes = _sourceBetween(
        main,
        'final _router = GoRouter(',
        '/* ───────────────────────── App Widgets',
      );
      final appLinkRedirect = _sourceBetween(
        main,
        'String? _redirectExternalAppLink(Uri uri)',
        'String? _redirectRetiredRhythmRoute(Uri uri)',
      );
      final appLinkHandler = _sourceBetween(
        main,
        'Future<void> _handleIncomingAppLink(Uri uri) async',
        'bool _shouldSkipDuplicateLink(String signature)',
      );
      final initialLocation = _sourceBetween(
        main,
        'String _resolveInitialLocation()',
        'Future<String?> _readBootRestoredLocation() async',
      );

      for (final route in const <String>[
        "path: '/rhythm/today'",
        "path: '/nodes'",
        "path: '/settings'",
        "path: '/profile/:userId'",
      ]) {
        expect(routes, contains(route));
      }

      expect(main, contains('bool _isContinuityRouteLocation'));
      expect(bootRestore, contains('readBestSnapshot'));
      expect(bootRestore, contains('routeLocation'));
      expect(bootRestore, contains('SessionResumeService.readRouteLocation'));
      expect(authResume, contains('readOverlayStack'));
      expect(authResume, contains('readRouteLocation'));
      expect(authResume, contains('SessionResumeService.readRouteLocation'));
      expect(authResume, contains('_router.go(savedLocation)'));
      expect(routes, isNot(contains('restorationScopeId:')));

      expect(initialLocation, contains('defaultRouteName'));
      expect(
        initialLocation.indexOf('defaultRoute'),
        lessThan(initialLocation.indexOf('_bootRestoredLocation')),
      );
      expect(
        initialLocation.indexOf('defaultRoute'),
        lessThan(initialLocation.indexOf('_bootExplicitIntentLocation')),
      );
      expect(main, contains('bool _hasExplicitBootIntent()'));
      expect(main, contains('defaultRoute != Navigator.defaultRouteName'));
      expect(authResume, contains('_deferSessionResumeForPushNavigation'));
      expect(main, contains('getInitialAppLink()'));
      expect(main, contains('getInitialLink()'));
      expect(main, contains('!_isBootInitialAppLinkUri(initialUri)'));
      expect(appLinkRedirect, contains('AppLinkIntent.parse(uri)'));
      expect(appLinkRedirect, contains('PlannerAppLinkIntent'));
      expect(appLinkRedirect, contains('ShareAppLinkIntent'));
      expect(appLinkHandler, contains('_routeToSharedFlow(intent)'));
      expect(appLinkHandler, contains('_routeToPlanner(intent.plannerIntent)'));
    });

    test('Ma’at template restoration seeds initial routes', () async {
      final calendar = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final rootRestore = _sourceBetween(
        calendar,
        'Future<void> _restoreFlowStudioOverlay',
        '_MaatFlowTemplate? _maatTemplateForKey',
      );
      final detachedRestore = _sourceBetween(
        calendar,
        'static List<Route<dynamic>> _detachedFlowStudioInitialRoutes({',
        'static Future<void> _openDetachedFlowStudioSheet',
      );

      expect(rootRestore, contains('initialRoutesBuilder'));
      expect(rootRestore, contains('listRoute, detailRoute'));
      expect(rootRestore, isNot(contains('addPostFrameCallback')));
      expect(detachedRestore, contains('listRoute, detailRoute'));
      expect(detachedRestore, isNot(contains('addPostFrameCallback')));
    });

    test(
      'day view continuity restores open routes without startup clearing',
      () async {
        final calendar = await File(
          'lib/features/calendar/calendar_page.dart',
        ).readAsString();
        final loadPersistedViewState = _sourceBetween(
          calendar,
          'Future<void> _loadPersistedViewState',
          '/// ✅ Helper: Calculate max days in a Kemetic month',
        );
        final restoreDayView = _sourceBetween(
          calendar,
          'Future<void> _restorePersistentDayViewIfNeeded',
          'void _applyTodayFallbackAfterRestore',
        );
        final dayViewNavigation = _sourceBetween(
          calendar,
          'void _openDayView',
          '/* ───── Day Sheet ───── */',
        );

        expect(
          calendar,
          contains('static const bool _restoreDayViewRouteOnStartup = true;'),
        );
        expect(
          calendar,
          isNot(contains("reason: 'startup_calendar_fallback'")),
        );
        expect(
          loadPersistedViewState,
          isNot(contains('_clearPersistedDayViewOpenState')),
        );
        expect(
          loadPersistedViewState,
          contains('_pendingPersistentDayViewState'),
        );
        expect(loadPersistedViewState, contains('savedDayView.isOpen'));
        expect(
          loadPersistedViewState,
          contains('_schedulePersistentDayViewRestore'),
        );

        expect(restoreDayView, contains('_openDayView('));
        expect(restoreDayView, contains('if (attempt >= 20)'));
        expect(
          restoreDayView.indexOf('_persistentDayViewRestoreAttempted = true'),
          lessThan(restoreDayView.indexOf('_openDayView(')),
        );

        expect(
          dayViewNavigation,
          contains('shouldPreserveOverlayForLifecycleClose'),
        );
        expect(dayViewNavigation, contains("reason: 'day_view_closed'"));
        expect(
          dayViewNavigation.indexOf('if (!preserveForLifecycle)'),
          lessThan(dayViewNavigation.indexOf("reason: 'day_view_closed'")),
        );
      },
    );

    test(
      'calendar sheets save and restore from atomic overlay snapshots',
      () async {
        final calendar = await File(
          'lib/features/calendar/calendar_page.dart',
        ).readAsString();
        final saveDetached = _sourceBetween(
          calendar,
          'static Future<void> _saveDetachedCalendarOverlayState({',
          'static Future<void> _clearDetachedCalendarOverlayState',
        );
        final clearDetached = _sourceBetween(
          calendar,
          'static Future<void> _clearDetachedCalendarOverlayState',
          'static Future<void> showActionsMenuFromAnyContext',
        );
        final restoreDetached = _sourceBetween(
          calendar,
          'static Future<bool> restoreDetachedCalendarOverlayFromAnyContext',
          'static Future<void> shareFlowFromEvent',
        );
        final rootRestore = _sourceBetween(
          calendar,
          'Future<void> _restorePersistentCalendarOverlayWithRetries',
          'Future<void> _restoreFlowStudioOverlay',
        );

        expect(saveDetached, contains('recordRouteLocationWithOverlayStack'));
        expect(saveDetached, contains("'parentRoute': normalizedParentRoute"));
        expect(saveDetached, contains("'parentSurface'"));
        expect(
          saveDetached,
          contains('SessionResumeService.saveRouteLocation'),
        );
        expect(saveDetached, contains('RestorationCoordinator.instance.flush'));

        expect(
          clearDetached,
          contains('shouldPreserveOverlayForLifecycleClose'),
        );
        expect(clearDetached, contains('readOverlayStack()'));
        expect(clearDetached, contains('saveOverlayStack(next)'));

        expect(restoreDetached, contains('readBestSnapshot'));
        expect(
          restoreDetached,
          contains(
            'includeRemote: Supabase.instance.client.auth.currentSession != null',
          ),
        );
        expect(
          restoreDetached,
          contains('_sameRouteLocation(activeLocation, parentRoute)'),
        );
        expect(
          restoreDetached,
          contains('_lastDetachedCalendarOverlayRestoreKey'),
        );
        expect(restoreDetached, contains('_openDetachedSharedCalendarsSheet'));
        expect(restoreDetached, contains('_openDetachedFlowStudioSheet'));

        expect(rootRestore, contains('attempt < 30'));
        expect(rootRestore, contains('Duration(milliseconds: 150)'));
        expect(rootRestore, contains('readBestSnapshot'));
        expect(rootRestore, contains('savedDayView'));
        expect(rootRestore, contains('_persistentDayViewRestoreAttempted'));
        expect(rootRestore, contains('claimRestoreSurface'));
        expect(rootRestore, contains('_openSharedCalendarsSheet'));
        expect(rootRestore, contains('_restoreFlowStudioOverlay'));
      },
    );

    test(
      'restore ownership is launch scoped and user navigation can suppress it',
      () async {
        final main = await File('lib/main.dart').readAsString();
        final calendar = await File(
          'lib/features/calendar/calendar_page.dart',
        ).readAsString();
        final coordinator = await File(
          'lib/services/restoration_coordinator.dart',
        ).readAsString();
        final todayCommand = _sourceBetween(
          calendar,
          'static void openMainCalendarAtToday',
          '// Static method for parsing rules from JSON',
        );
        final dayViewRestore = _sourceBetween(
          calendar,
          'Future<void> _restorePersistentDayViewIfNeeded',
          'void _applyTodayFallbackAfterRestore',
        );
        final launchDismiss = _sourceBetween(
          main,
          'Future<void> _dismissOverlay() async',
          '@override\n  void dispose()',
        );

        expect(coordinator, contains('enum RestorationRestoreReason'));
        expect(coordinator, contains('claimRestoreSurface'));
        expect(coordinator, contains('suppressRestoreForUserNavigation'));
        expect(coordinator, contains('calendarDayViewSurface'));
        expect(coordinator, contains('calendarOverlayStackSurface'));

        expect(main, contains('beginLaunchRestore'));
        expect(main, contains('RestorationRestoreReason.coldLaunch'));
        expect(main, contains('RestorationRestoreReason.authResume'));
        expect(
          launchDismiss,
          contains('waitForInitialCalendarRestorationToSettle'),
        );

        expect(todayCommand, contains('suppressRestoreForUserNavigation'));
        expect(todayCommand, contains('recordRouteLocation'));
        expect(todayCommand, contains("router.go('/')"));
        expect(todayCommand, isNot(contains('return;\n    }\n    router.go')));

        expect(dayViewRestore, contains('canRestoreSurface'));
        expect(dayViewRestore, contains('claimRestoreSurface'));
        expect(dayViewRestore, contains('requireRootTarget: true'));
      },
    );

    test(
      'calendar sheet entrypoints de-dupe active presentations only',
      () async {
        final main = await File('lib/main.dart').readAsString();
        final calendar = await File(
          'lib/features/calendar/calendar_page.dart',
        ).readAsString();
        final detachedShared = _sourceBetween(
          calendar,
          'static Future<void> _openDetachedSharedCalendarsSheet',
          'static bool _isTabletForContext',
        );
        final detachedFlow = _sourceBetween(
          calendar,
          'static Future<void> _openDetachedFlowStudioSheet',
          'static bool _sameRouteLocation',
        );
        final rootShared = _sourceBetween(
          calendar,
          'Future<void> _openSharedCalendarsSheet',
          'Future<bool> _openCalendarScopedNoteDialog',
        );
        final rootFlow = _sourceBetween(
          calendar,
          'Future<void> _openFlowStudioSheet',
          '// Directly open My Flows list',
        );
        final myFlows = _sourceBetween(
          calendar,
          'void _openMyFlowsList',
          '/// Public entrypoint so other screens',
        );

        expect(main, contains('_dismissOverlay();'));
        expect(
          main,
          isNot(contains('waitForInitialCalendarOverlayPresentation')),
        );
        expect(calendar, isNot(contains('restoreWithoutAnimation')));
        expect(calendar, isNot(contains('AnimationStyle.noAnimation')));

        expect(
          calendar,
          contains('static bool _detachedSharedCalendarsSheetOpenOrOpening'),
        );
        expect(
          calendar,
          contains('static bool _detachedFlowStudioSheetOpenOrOpening'),
        );
        expect(calendar, contains('bool _sharedCalendarsSheetOpenOrOpening'));
        expect(calendar, contains('bool _flowStudioSheetOpenOrOpening'));

        expect(
          detachedShared,
          contains('if (_detachedSharedCalendarsSheetOpenOrOpening) return;'),
        );
        expect(detachedShared, contains('!context.mounted'));
        expect(
          detachedShared,
          contains('shouldPreserveOverlayForLifecycleClose'),
        );
        expect(detachedShared, contains('if (!preserveForLifecycle)'));
        expect(
          detachedFlow,
          contains('if (_detachedFlowStudioSheetOpenOrOpening) return;'),
        );
        expect(detachedFlow, contains('!context.mounted'));
        expect(
          detachedFlow,
          contains('shouldPreserveOverlayForLifecycleClose'),
        );
        expect(detachedFlow, contains('if (!preserveForLifecycle)'));
        expect(
          rootShared,
          contains('if (_sharedCalendarsSheetOpenOrOpening) return;'),
        );
        expect(
          rootFlow,
          contains('if (!mounted || _flowStudioSheetOpenOrOpening) return;'),
        );
        expect(rootFlow, contains('shouldPreserveOverlayForLifecycleClose'));
        expect(rootFlow, contains('if (!preserveForLifecycle)'));
        expect(
          myFlows,
          contains('if (!mounted || _flowStudioSheetOpenOrOpening) return;'),
        );

        expect(
          detachedShared.indexOf('_saveDetachedCalendarOverlayState'),
          lessThan(
            detachedShared.indexOf(
              'if (_detachedSharedCalendarsSheetOpenOrOpening) return;',
            ),
          ),
        );
        expect(
          detachedFlow.indexOf('_saveDetachedCalendarOverlayState'),
          lessThan(
            detachedFlow.indexOf(
              'if (_detachedFlowStudioSheetOpenOrOpening) return;',
            ),
          ),
        );
        expect(
          rootShared.indexOf('_saveCalendarOverlayState'),
          lessThan(
            rootShared.indexOf(
              'if (_sharedCalendarsSheetOpenOrOpening) return;',
            ),
          ),
        );
        expect(
          rootFlow.indexOf('_saveCalendarOverlayState'),
          lessThan(
            rootFlow.indexOf(
              'if (!mounted || _flowStudioSheetOpenOrOpening) return;',
            ),
          ),
        );
        expect(
          myFlows.indexOf('_saveCalendarOverlayState'),
          lessThan(
            myFlows.indexOf(
              'if (!mounted || _flowStudioSheetOpenOrOpening) return;',
            ),
          ),
        );
      },
    );
  });
}

Future<List<String>> _filesContainingAny(List<String> needles) async {
  final matches = <String>[];
  await for (final entity in Directory('lib').list(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    final contents = await entity.readAsString();
    if (needles.any(contents.contains)) {
      matches.add(_normalizePath(entity.path));
    }
  }
  matches.sort();
  return matches;
}

String _normalizePath(String path) => path.replaceAll('\\', '/');

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNot(-1), reason: 'Missing source marker: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNot(-1), reason: 'Missing source marker: $end');
  return source.substring(startIndex, endIndex);
}
