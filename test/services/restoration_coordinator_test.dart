import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/restoration_coordinator.dart';

void main() {
  group('RestorationCoordinator restore ownership', () {
    test('launch surfaces are consumed once', () {
      final coordinator = RestorationCoordinator.instance
        ..beginLaunchRestore(
          reason: RestorationRestoreReason.coldLaunch,
          targetLocation: '/',
        );

      expect(
        coordinator.claimRestoreSurface(
          RestorationCoordinator.calendarDayViewSurface,
          requireRootTarget: true,
        ),
        isTrue,
      );
      expect(
        coordinator.claimRestoreSurface(
          RestorationCoordinator.calendarDayViewSurface,
          requireRootTarget: true,
        ),
        isFalse,
      );
    });

    test('non-root launch target cannot consume root calendar surfaces', () {
      final coordinator = RestorationCoordinator.instance
        ..beginLaunchRestore(
          reason: RestorationRestoreReason.coldLaunch,
          targetLocation: '/profile/user-1',
        );

      expect(
        coordinator.canRestoreSurface(
          RestorationCoordinator.calendarDayViewSurface,
          requireRootTarget: true,
        ),
        isFalse,
      );
      expect(
        coordinator.canRestoreSurface(
          '${RestorationCoordinator.calendarOverlayStackSurface}|calendar.flowStudio|/profile/user-1',
        ),
        isTrue,
      );
    });

    test('non-root launch target defers default root persistence', () {
      final coordinator = RestorationCoordinator.instance
        ..beginLaunchRestore(
          reason: RestorationRestoreReason.coldLaunch,
          targetLocation: '/inbox',
        );

      expect(coordinator.shouldDeferRootRoutePersistenceForLaunch, isTrue);

      coordinator.beginLaunchRestore(
        reason: RestorationRestoreReason.coldLaunch,
        targetLocation: '/',
      );

      expect(coordinator.shouldDeferRootRoutePersistenceForLaunch, isFalse);

      coordinator.suppressRestoreForUserNavigation(reason: 'manual_home');

      expect(coordinator.shouldDeferRootRoutePersistenceForLaunch, isFalse);
    });

    test('detached overlay surfaces restore only on their parent route', () {
      final coordinator = RestorationCoordinator.instance
        ..beginLaunchRestore(
          reason: RestorationRestoreReason.coldLaunch,
          targetLocation: '/',
        );
      const plannerOverlay =
          '${RestorationCoordinator.calendarOverlayStackSurface}'
          '|calendar.flowStudio|/rhythm/today';

      expect(coordinator.canRestoreSurface(plannerOverlay), isFalse);

      coordinator.beginLaunchRestore(
        reason: RestorationRestoreReason.coldLaunch,
        targetLocation: '/rhythm/today',
      );

      expect(coordinator.canRestoreSurface(plannerOverlay), isTrue);
    });

    test('detached overlay target beats stale root day view state', () {
      final coordinator = RestorationCoordinator.instance
        ..beginLaunchRestore(
          reason: RestorationRestoreReason.coldLaunch,
          targetLocation: '/profile/user-1',
        );
      const profileCalendarSheet =
          '${RestorationCoordinator.calendarOverlayStackSurface}'
          '|calendar.sharedCalendars|/profile/user-1';

      expect(
        coordinator.canRestoreSurface(
          RestorationCoordinator.calendarDayViewSurface,
          requireRootTarget: true,
        ),
        isFalse,
      );
      expect(coordinator.canRestoreSurface(profileCalendarSheet), isTrue);
      expect(coordinator.claimRestoreSurface(profileCalendarSheet), isTrue);
      expect(coordinator.canRestoreSurface(profileCalendarSheet), isFalse);
    });

    test('lifecycle interruption preserves restore surfaces', () {
      final coordinator = RestorationCoordinator.instance
        ..beginLaunchRestore(
          reason: RestorationRestoreReason.coldLaunch,
          targetLocation: '/',
        )
        ..noteLifecycleState(AppLifecycleState.paused);

      expect(coordinator.shouldPreserveOverlayForLifecycleClose, isTrue);

      coordinator.noteLifecycleState(AppLifecycleState.resumed);

      expect(coordinator.shouldPreserveOverlayForLifecycleClose, isTrue);
      expect(
        coordinator.canRestoreSurface(
          RestorationCoordinator.calendarDayViewSurface,
          requireRootTarget: true,
        ),
        isTrue,
      );
    });

    test('explicit user navigation suppresses stale restore surfaces', () {
      final coordinator = RestorationCoordinator.instance
        ..beginLaunchRestore(
          reason: RestorationRestoreReason.coldLaunch,
          targetLocation: '/',
        )
        ..suppressRestoreForUserNavigation(
          reason: 'today',
          surfaces: const <String>[
            RestorationCoordinator.calendarDayViewSurface,
            RestorationCoordinator.calendarOverlayStackSurface,
          ],
        );

      expect(
        coordinator.canRestoreSurface(
          RestorationCoordinator.calendarDayViewSurface,
          requireRootTarget: true,
        ),
        isFalse,
      );
      expect(
        coordinator.canRestoreSurface(
          '${RestorationCoordinator.calendarOverlayStackSurface}|calendar.sharedCalendars|/',
        ),
        isFalse,
      );
    });

    test('explicit launch intent suppression is scoped to that launch', () {
      final coordinator = RestorationCoordinator.instance
        ..beginLaunchRestore(
          reason: RestorationRestoreReason.coldLaunch,
          targetLocation: '/',
        )
        ..suppressRestoreForExplicitIntent(
          reason: 'notification',
          surfaces: const <String>[
            RestorationCoordinator.calendarDayViewSurface,
            RestorationCoordinator.calendarOverlayStackSurface,
          ],
        );

      expect(
        coordinator.canRestoreSurface(
          RestorationCoordinator.calendarDayViewSurface,
          requireRootTarget: true,
        ),
        isFalse,
      );
      expect(
        coordinator.canRestoreSurface(
          '${RestorationCoordinator.calendarOverlayStackSurface}|calendar.flowStudio|/',
          requireRootTarget: true,
        ),
        isFalse,
      );

      coordinator.beginLaunchRestore(
        reason: RestorationRestoreReason.coldLaunch,
        targetLocation: '/',
      );

      expect(
        coordinator.canRestoreSurface(
          RestorationCoordinator.calendarDayViewSurface,
          requireRootTarget: true,
        ),
        isTrue,
      );
    });
  });
}
