import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppRestorationService.debugUserIdResolver = () => 'user-1';
    AppWindowService.debugWindowIdResolver = () async => 'window-1';
    AppWindowService.instance.resetForTesting();
  });

  tearDown(() {
    AppRestorationService.debugUserIdResolver = null;
    AppWindowService.debugWindowIdResolver = null;
    AppWindowService.instance.resetForTesting();
  });

  test('stores route, calendar, day view, and day sheet per window', () async {
    await AppRestorationService.instance.saveRouteLocation('/inbox');
    await AppRestorationService.instance.saveCalendarState(
      const CalendarRestorationState(
        kYear: 6267,
        kMonth: 4,
        kDay: 12,
        showGregorian: true,
        expansion: 'details',
        scrollOffset: 14320.5,
      ),
    );
    await AppRestorationService.instance.saveDayViewState(
      const DayViewRestorationState(
        isOpen: true,
        kYear: 6267,
        kMonth: 4,
        kDay: 12,
        showGregorian: false,
        scrollOffset: 680.0,
      ),
    );
    await AppRestorationService.instance.saveDaySheetState({
      'kYear': 6267,
      'kMonth': 4,
      'kDay': 12,
      'title': 'Morning offering',
    });

    expect(await AppRestorationService.instance.readRouteLocation(), '/inbox');

    final calendar = await AppRestorationService.instance.readCalendarState();
    expect(calendar, isNotNull);
    expect(calendar!.showGregorian, isTrue);
    expect(calendar.scrollOffset, 14320.5);

    final dayView = await AppRestorationService.instance.readDayViewState();
    expect(dayView, isNotNull);
    expect(dayView!.isOpen, isTrue);
    expect(dayView.scrollOffset, 680.0);

    final daySheet = await AppRestorationService.instance.readDaySheetState();
    expect(daySheet, isNotNull);
    expect(daySheet!['title'], 'Morning offering');
  });

  test('isolates snapshots by window id', () async {
    await AppRestorationService.instance.saveRouteLocation('/rhythm/today');

    AppWindowService.debugWindowIdResolver = () async => 'window-2';
    AppWindowService.instance.resetForTesting();
    expect(await AppRestorationService.instance.readRouteLocation(), isNull);

    await AppRestorationService.instance.saveRouteLocation('/inbox');
    expect(await AppRestorationService.instance.readRouteLocation(), '/inbox');

    AppWindowService.debugWindowIdResolver = () async => 'window-1';
    AppWindowService.instance.resetForTesting();
    expect(
      await AppRestorationService.instance.readRouteLocation(),
      '/rhythm/today',
    );
  });
}
