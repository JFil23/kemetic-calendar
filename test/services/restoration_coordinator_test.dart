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
  });
}
