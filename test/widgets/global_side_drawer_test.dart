import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/global_side_drawer_metrics.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:mobile/widgets/global_side_drawer.dart';

void main() {
  testWidgets('bubble uses bottom-left safe area and accessible label', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(left: 8, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    var tapCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          fit: StackFit.expand,
          children: [
            GlobalMenuBubble(
              visible: true,
              open: false,
              onPressed: () => tapCount += 1,
            ),
          ],
        ),
      ),
    );

    final bubbleRect = tester.getRect(find.byKey(globalMenuBubbleKey));
    expect(bubbleRect.left, 24);
    expect(bubbleRect.bottom, 844 - 40);
    expect(find.bySemanticsLabel('Open navigation menu'), findsOneWidget);

    await tester.tap(find.byKey(globalMenuBubbleKey));
    expect(tapCount, 1);
  });

  testWidgets('phone portrait drawer is slim and below half width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          fit: StackFit.expand,
          children: [GlobalSideDrawer(open: true, items: _drawerItems())],
        ),
      ),
    );

    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Flows'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(find.text('Flow Studio'), findsNothing);

    final drawerWidth = tester.getSize(find.byKey(globalSideDrawerKey)).width;
    expect(drawerWidth, lessThanOrEqualTo(390 * 0.48));
    expect(drawerWidth, lessThan(220));
    expect(drawerWidth, closeTo(187.2, 0.1));
  });

  testWidgets('phone portrait drawer uses upper date header and lower nav', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          fit: StackFit.expand,
          children: [GlobalSideDrawer(open: true, items: _drawerItems())],
        ),
      ),
    );

    final headerRect = tester.getRect(
      find.byKey(globalSideDrawerDateHeaderKey),
    );
    final dividerRect = tester.getRect(
      find.byKey(globalSideDrawerDateDividerKey),
    );
    final calendarRect = tester.getRect(
      find.byKey(const ValueKey<String>('global-side-drawer-item-Calendar')),
    );
    final settingsRect = tester.getRect(
      find.byKey(const ValueKey<String>('global-side-drawer-item-Settings')),
    );

    expect(find.byKey(globalSideDrawerDateMonthKey), findsOneWidget);
    expect(find.byKey(globalSideDrawerDateDayKey), findsOneWidget);
    expect(headerRect.bottom, lessThan(calendarRect.top));
    expect(dividerRect.top, greaterThan(headerRect.bottom));
    expect(dividerRect.bottom, lessThan(calendarRect.top));
    expect(calendarRect.top, closeTo(844 * 0.30, 1));
    expect(settingsRect.center.dy, greaterThan(844 * 0.86));
    expect(settingsRect.bottom, lessThanOrEqualTo(844));
  });

  testWidgets('phone landscape drawer is capped as a side rail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    double? width;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            width = globalSideDrawerWidth(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(width, lessThanOrEqualTo(272));
    expect(width, lessThanOrEqualTo(844 * 0.38));
    expect(width, closeTo(272, 0.1));
  });

  testWidgets('tablet portrait drawer stays fixed width and not giant', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    double? width;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            width = globalSideDrawerWidth(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(width, closeTo(304, 0.1));
    expect(width, lessThan(820 / 2));
  });

  testWidgets('drawer rows keep a fixed glyph column without overlap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          fit: StackFit.expand,
          children: [GlobalSideDrawer(open: true, items: _drawerItems())],
        ),
      ),
    );

    final libraryGlyph = tester.getRect(
      find.byKey(const ValueKey<String>('global-side-drawer-glyph-Library')),
    );
    final libraryLabel = tester.getRect(
      find.byKey(const ValueKey<String>('global-side-drawer-label-Library')),
    );
    final calendarsGlyph = tester.getRect(
      find.byKey(const ValueKey<String>('global-side-drawer-glyph-Calendars')),
    );
    final calendarsLabel = tester.getRect(
      find.byKey(const ValueKey<String>('global-side-drawer-label-Calendars')),
    );
    final reflectionsLabel = tester.getRect(
      find.byKey(
        const ValueKey<String>('global-side-drawer-label-Reflections'),
      ),
    );
    final calendarsRow = tester.getRect(
      find.byKey(const ValueKey<String>('global-side-drawer-item-Calendars')),
    );

    expect(libraryGlyph.width, kGlobalSideDrawerGlyphColumnWidth);
    expect(calendarsGlyph.width, kGlobalSideDrawerGlyphColumnWidth);
    expect(libraryGlyph.right, lessThanOrEqualTo(libraryLabel.left - 7.9));
    expect(calendarsGlyph.right, lessThanOrEqualTo(calendarsLabel.left - 7.9));
    expect(calendarsGlyph.top, greaterThanOrEqualTo(calendarsRow.top));
    expect(calendarsGlyph.bottom, lessThanOrEqualTo(calendarsRow.bottom));
    expect(calendarsLabel.left, libraryLabel.left);
    expect(reflectionsLabel.left, libraryLabel.left);
  });

  testWidgets('drawer row tap dispatches selection', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _DrawerHarness()));

    expect(find.text('drawer open'), findsOneWidget);

    await tester.tap(find.text('Planner'));
    await tester.pumpAndSettle();

    expect(find.text('drawer closed'), findsOneWidget);
    expect(find.text('selected 1'), findsOneWidget);
  });

  testWidgets('tablet landscape drawer width is capped below full screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    double? width;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            width = globalSideDrawerWidth(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(width, lessThanOrEqualTo(340));
    expect(width, lessThan(1366 / 2));
    expect(width, greaterThanOrEqualTo(300));
    expect(width, closeTo(320, 0.1));
  });
}

List<GlobalSideDrawerItem> _drawerItems({VoidCallback? onSelected}) {
  return <GlobalSideDrawerItem>[
    GlobalSideDrawerItem(
      label: 'Calendar',
      glyph: MeduNeterGlyphs.home,
      selected: true,
      onSelected: onSelected ?? () {},
    ),
    GlobalSideDrawerItem(
      label: 'Planner',
      glyph: MeduNeterGlyphs.planner,
      onSelected: onSelected ?? () {},
    ),
    GlobalSideDrawerItem(
      label: 'Library',
      glyph: MeduNeterGlyphs.library,
      onSelected: onSelected ?? () {},
    ),
    GlobalSideDrawerItem(
      label: 'Journal',
      glyph: MeduNeterGlyphs.journal,
      onSelected: onSelected ?? () {},
    ),
    GlobalSideDrawerItem(
      label: 'Inbox',
      glyph: MeduNeterGlyphs.inbox,
      onSelected: onSelected ?? () {},
    ),
    GlobalSideDrawerItem(
      label: 'Calendars',
      glyph: MeduNeterGlyphs.calendars,
      onSelected: onSelected ?? () {},
    ),
    GlobalSideDrawerItem(
      label: 'Flows',
      glyph: MeduNeterGlyphs.flowStudio,
      onSelected: onSelected ?? () {},
    ),
    GlobalSideDrawerItem(
      label: 'Reflections',
      glyph: MeduNeterGlyphs.reflections,
      onSelected: onSelected ?? () {},
    ),
    GlobalSideDrawerItem(
      label: 'Profile',
      glyph: MeduNeterGlyphs.profile,
      onSelected: onSelected ?? () {},
    ),
    GlobalSideDrawerItem(
      label: 'Settings',
      glyph: MeduNeterGlyphs.settings,
      onSelected: onSelected ?? () {},
    ),
  ];
}

class _DrawerHarness extends StatefulWidget {
  const _DrawerHarness();

  @override
  State<_DrawerHarness> createState() => _DrawerHarnessState();
}

class _DrawerHarnessState extends State<_DrawerHarness> {
  bool _open = true;
  int _selectedCount = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.bottomRight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_open ? 'drawer open' : 'drawer closed'),
              Text('selected $_selectedCount'),
              TextButton(
                onPressed: () => setState(() => _open = true),
                child: const Text('reopen'),
              ),
            ],
          ),
        ),
        GlobalSideDrawer(
          open: _open,
          items: _drawerItems(
            onSelected: () => setState(() {
              _selectedCount += 1;
              _open = false;
            }),
          ),
        ),
      ],
    );
  }
}
