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

  testWidgets('drawer renders partial-width row menu with renamed labels', (
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
          children: [
            GlobalSideDrawer(
              open: true,
              onDismiss: () {},
              items: _drawerItems(),
            ),
          ],
        ),
      ),
    );

    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Flows'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(find.text('Flow Studio'), findsNothing);

    final drawerWidth = tester.getSize(find.byKey(globalSideDrawerKey)).width;
    expect(drawerWidth, lessThan(390));
    expect(drawerWidth, closeTo(304, 0.1));
  });

  testWidgets('drawer dismisses from scrim and row tap', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _DrawerHarness()));

    expect(find.text('drawer open'), findsOneWidget);

    await tester.tapAt(const Offset(760, 120));
    await tester.pumpAndSettle();
    expect(find.text('drawer closed'), findsOneWidget);

    await tester.tap(find.text('reopen'));
    await tester.pumpAndSettle();
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

    expect(width, lessThanOrEqualTo(448));
    expect(width, lessThan(1366 / 2));
    expect(width, greaterThanOrEqualTo(400));
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
          onDismiss: () => setState(() => _open = false),
        ),
      ],
    );
  }
}
