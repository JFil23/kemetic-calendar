import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/planner_launch_intent.dart';

void main() {
  group('PlannerLaunchIntent.parse', () {
    test('parses canonical widget planner links', () {
      final intent = PlannerLaunchIntent.parse(
        Uri.parse(
          'https://maat.app/rhythm/today?openDayCard=1&source=ios_widget&date=2026-05-09&tz=America%2FLos_Angeles',
        ),
      );

      expect(intent, isNotNull);
      expect(intent!.route, '/rhythm/today');
      expect(intent.openDayCard, isTrue);
      expect(intent.localDate, DateTime(2026, 5, 9));
      expect(intent.timezone, 'America/Los_Angeles');
      expect(intent.source, 'ios_widget');
      expect(
        intent.routeLocation,
        '/rhythm/today?openDayCard=1&source=ios_widget&date=2026-05-09&tz=America%2FLos_Angeles',
      );
    });

  test('normalizes todo launch links to the canonical planner route', () {
    final intent = PlannerLaunchIntent.parse(
      Uri.parse('/rhythm/todo?openDayCard=true&source=shortcut'),
    );

      expect(intent, isNotNull);
      expect(intent!.route, '/rhythm/todo');
      expect(intent.openDayCard, isTrue);
    expect(
      intent.routeLocation,
      '/rhythm/today?openDayCard=1&source=shortcut',
    );
  });

  test('preserves internal launch tokens for repeated widget opens', () {
    final intent = PlannerLaunchIntent.parse(
      Uri.parse(
        '/rhythm/today?openDayCard=1&source=ios_widget&_launch=abc123',
      ),
    );

    expect(intent, isNotNull);
    expect(intent!.launchToken, 'abc123');
    expect(
      intent.routeLocation,
      '/rhythm/today?openDayCard=1&source=ios_widget&_launch=abc123',
    );
  });

    test('ignores malformed dates without rejecting the launch', () {
      final intent = PlannerLaunchIntent.parse(
        Uri.parse('/rhythm/today?openDayCard=1&date=tomorrow'),
      );

      expect(intent, isNotNull);
      expect(intent!.openDayCard, isTrue);
      expect(intent.localDate, isNull);
      expect(intent.routeLocation, '/rhythm/today?openDayCard=1');
    });

    test('parses custom-scheme rhythm links for future native routing', () {
      final intent = PlannerLaunchIntent.parse(
        Uri.parse('maat://rhythm/today?openDayCard=1&date=2026-05-09'),
      );

      expect(intent, isNotNull);
      expect(intent!.route, '/rhythm/today');
      expect(intent.localDate, DateTime(2026, 5, 9));
    });

    test('ignores unsupported routes', () {
      expect(PlannerLaunchIntent.parse(Uri.parse('/settings')), isNull);
    });
  });
}
