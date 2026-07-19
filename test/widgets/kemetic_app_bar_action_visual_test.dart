import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/day_view_chrome.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:mobile/widgets/kemetic_app_bar_action.dart';

void main() {
  testWidgets(
    'calendar action row keeps search visible between new and today',
    (tester) async {
      tester.view.physicalSize = const Size(353, 120);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              title: const Text(''),
              actions: [
                KemeticAppBarAction(
                  tooltip: 'New note',
                  icon: const GlossyIcon(
                    icon: Icons.add,
                    gradient: goldGloss,
                    size: 23,
                  ),
                  onPressed: () {},
                ),
                KemeticAppBarAction(
                  tooltip: 'Search notes',
                  icon: const KemeticAppBarSearchIcon(),
                  onPressed: () {},
                ),
                KemeticAppBarAction(
                  tooltip: 'Today',
                  icon: const KemeticAppBarTodayIcon(),
                  onPressed: () {},
                ),
                KemeticAppBarAction(
                  tooltip: 'My Profile',
                  icon: const KemeticAppBarProfileIcon(),
                  onPressed: () {},
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final newRect = tester.getRect(find.byTooltip('New note'));
      final searchRect = tester.getRect(find.byTooltip('Search notes'));
      final todayRect = tester.getRect(find.byTooltip('Today'));
      final profileRect = tester.getRect(find.byTooltip('My Profile'));
      final appBarRect = tester.getRect(find.byType(AppBar));

      expect(newRect.right, lessThanOrEqualTo(searchRect.left));
      expect(searchRect.right, lessThanOrEqualTo(todayRect.left));
      expect(todayRect.right, lessThanOrEqualTo(profileRect.left));

      for (final rect in [newRect, searchRect, todayRect, profileRect]) {
        expect(rect.top, greaterThanOrEqualTo(appBarRect.top));
        expect(rect.bottom, lessThanOrEqualTo(appBarRect.bottom));
      }

      expect(find.byType(KemeticAppBarSearchIcon), findsOneWidget);
      expect(find.byType(KemeticAppBarTodayIcon), findsOneWidget);
      expect(tester.getRect(find.byType(KemeticAppBarSearchIcon)).width, 28);
      expect(tester.getRect(find.byType(KemeticAppBarTodayIcon)).width, 28);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('today glyph keeps app bar visual placement across widths', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in <double>[320, 420]) {
      tester.view.physicalSize = Size(width, 120);

      const compactIconKey = Key('compact-today-icon');
      const actionIconKey = Key('action-today-icon');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              title: TextButton.icon(
                onPressed: () {},
                icon: const KemeticAppBarTodayIcon(
                  key: compactIconKey,
                  boxSize: 20,
                  glyphSize: 16,
                  glyphOffset: Offset(1.5, -1),
                ),
                label: const Text(
                  'Today',
                  style: TextStyle(color: KemeticGold.base),
                ),
              ),
              actions: [
                KemeticAppBarAction(
                  tooltip: 'Today',
                  icon: const KemeticAppBarTodayIcon(key: actionIconKey),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(KemeticAppBarTodayIcon), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      final appBarRect = tester.getRect(find.byType(AppBar));
      final compactIconRect = tester.getRect(find.byKey(compactIconKey));
      expect(compactIconRect.width, 20);
      expect(compactIconRect.height, 20);
      expect(compactIconRect.top, greaterThan(appBarRect.top));
      expect(compactIconRect.bottom, lessThan(appBarRect.bottom));

      final actionButtonRect = tester.getRect(find.byTooltip('Today'));
      final actionIconRect = tester.getRect(find.byKey(actionIconKey));
      expect(actionIconRect.width, 28);
      expect(actionIconRect.height, 28);
      expect(
        (actionIconRect.center - actionButtonRect.center).distance,
        lessThan(0.5),
      );
      expect(actionIconRect.top, greaterThan(actionButtonRect.top));
      expect(actionIconRect.bottom, lessThan(actionButtonRect.bottom));
    }
  });

  testWidgets('day view header keeps search visible and wired', (tester) async {
    tester.view.physicalSize = const Size(393, 220);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var searchCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: KemeticDayViewHeader(
            currentKy: 2,
            currentKm: 2,
            currentKd: 25,
            showGregorian: false,
            getMonthName: (_) => 'Paopi (Mnht)',
            dateButtonBuilder: (_, _) => const SizedBox.shrink(),
            onClose: () {},
            onJumpToToday: () {},
            onOpenQuickAdd: (_) async {},
            onOpenSearch: (_) async {
              searchCount += 1;
            },
            onOpenProfile: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Search notes'), findsOneWidget);
    expect(find.byType(KemeticAppBarSearchIcon), findsOneWidget);
    expect(find.byType(KemeticAppBarTodayIcon), findsOneWidget);

    await tester.tap(find.byTooltip('Search notes'));
    await tester.pump();

    expect(searchCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('day view header uses taller row only on wide screens', (
    tester,
  ) async {
    Future<double> pumpHeader(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: KemeticDayViewHeader(
              currentKy: 2,
              currentKm: 4,
              currentKd: 17,
              showGregorian: false,
              getMonthName: (_) => 'Ka-her-Ka (Kꜣ-hr-Kꜣ)',
              dateButtonBuilder: (_, _) => const SizedBox.shrink(),
              onClose: () {},
              onJumpToToday: () {},
              onOpenQuickAdd: (_) async {},
              onOpenSearch: (_) async {},
              onOpenProfile: (_) async {},
            ),
          ),
        ),
      );
      await tester.pump();
      return tester
          .getRect(find.byKey(const ValueKey('day_view_mini_calendar')))
          .top;
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    expect(await pumpHeader(const Size(1024, 768)), 56);
    expect(await pumpHeader(const Size(390, 844)), 48);
    expect(tester.takeException(), isNull);
  });
}
