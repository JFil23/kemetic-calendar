import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/navigation_trace.dart';
import 'package:mobile/services/swipe_landing_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    NavigationTrace.instance.resetForTesting();
    SwipeLandingCoordinator.instance.resetForTesting();
  });

  tearDown(() {
    NavigationTrace.instance.resetForTesting();
    SwipeLandingCoordinator.instance.resetForTesting();
  });

  test('helper deferral is temporary and does not complete helpers', () async {
    await NavigationTrace.instance.setEnabled(true);
    final swipeId = SwipeLandingCoordinator.instance.startCalendarSwipe(
      direction: 'rightToLeft',
    );
    SwipeLandingCoordinator.instance.markCommitted(swipeId);
    SwipeLandingCoordinator.instance.markRouteRequested(
      swipeId,
      destination: SwipeLandingDestination.profile,
      route: '/profile/me',
    );
    SwipeLandingCoordinator.instance.markDestinationFirstFrame(
      destination: SwipeLandingDestination.profile,
    );

    final deferred = await SwipeLandingCoordinator.instance.deferHelperIfNeeded(
      destination: SwipeLandingDestination.profile,
      helperKey: 'profile_community_feed',
      gracePeriod: Duration.zero,
    );
    SwipeLandingCoordinator.instance.recordHelperShown(
      destination: SwipeLandingDestination.profile,
      helperKey: 'profile_community_feed',
    );

    expect(deferred, isTrue);
    final entries = NavigationTrace.instance.entries.join('\n');
    expect(entries, contains('helper overlay deferred'));
    expect(entries, contains('helper overlay defer completed'));
    expect(entries, contains('helper overlay shown'));
    expect(entries, contains('swipeId=calendar-swipe-1'));

    SwipeLandingCoordinator.instance.resetForTesting();
    expect(
      await SwipeLandingCoordinator.instance.deferHelperIfNeeded(
        destination: SwipeLandingDestination.profile,
        helperKey: 'profile_community_feed',
        gracePeriod: Duration.zero,
      ),
      isFalse,
    );
  });

  test('landing marker stays in memory only', () async {
    final source = await File(
      'lib/services/swipe_landing_coordinator.dart',
    ).readAsString();

    expect(source, isNot(contains('SharedPreferences')));
    expect(source, isNot(contains('markHelperCompleted')));
    expect(source, isNot(contains('OnboardingHelperCompletionService')));
  });
}
