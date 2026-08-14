import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:mobile/widgets/calendar_floating_shortcuts.dart';

void main() {
  testWidgets('matches the Apple Calendar capsule size and screen insets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: CalendarFloatingShortcutsLayer(
          onTodayPressed: () {},
          onCalendarsPressed: () {},
          onInboxPressed: () {},
          child: const ColoredBox(color: Colors.black),
        ),
      ),
    );

    final rect = tester.getRect(
      find.byKey(calendarFloatingShortcutsSurfaceKey),
    );
    final todayRect = tester.getRect(
      find.byKey(calendarFloatingTodaySurfaceKey),
    );
    expect(rect.width, kCalendarFloatingShortcutsWidth);
    expect(rect.height, kCalendarFloatingShortcutsHeight);
    expect(rect.right, 390 - kCalendarFloatingShortcutsTrailing);
    expect(rect.bottom, 844 - kCalendarFloatingShortcutsBottom);
    expect(todayRect.width, kCalendarFloatingTodayWidth);
    expect(todayRect.height, kCalendarFloatingShortcutsHeight);
    expect(todayRect.left, kCalendarFloatingShortcutsLeading);
    expect(todayRect.bottom, rect.bottom);

    final surface = tester.widget<DecoratedBox>(
      find.byKey(calendarFloatingShortcutsSurfaceKey),
    );
    final decoration = surface.decoration as BoxDecoration;
    expect(
      decoration.borderRadius,
      BorderRadius.circular(kCalendarFloatingShortcutsHeight / 2),
    );
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors, const <Color>[
      Color(0xB32B2B2E),
      Color(0xB31B1B1D),
    ]);
    final todaySurface = tester.widget<DecoratedBox>(
      find.byKey(calendarFloatingTodaySurfaceKey),
    );
    expect(todaySurface.decoration, decoration);
  });

  testWidgets('offers two equal tappable actions with live inbox count copy', (
    tester,
  ) async {
    var calendarsTaps = 0;
    var inboxTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CalendarFloatingShortcuts(
              unreadInboxCount: 4,
              onCalendarsPressed: () => calendarsTaps += 1,
              onInboxPressed: () => inboxTaps += 1,
            ),
          ),
        ),
      ),
    );

    final calendarsRect = tester.getRect(
      find.byKey(calendarFloatingCalendarsButtonKey),
    );
    final inboxRect = tester.getRect(
      find.byKey(calendarFloatingInboxButtonKey),
    );
    expect(calendarsRect.size, const Size(70, 48));
    expect(inboxRect.size, const Size(70, 48));
    expect(find.text('4'), findsOneWidget);
    expect(find.bySemanticsLabel('Calendars'), findsOneWidget);
    expect(find.bySemanticsLabel('Inbox, 4 unread'), findsOneWidget);

    await tester.tap(find.byKey(calendarFloatingCalendarsButtonKey));
    await tester.tap(find.byKey(calendarFloatingInboxButtonKey));
    expect(calendarsTaps, 1);
    expect(inboxTaps, 1);
  });

  testWidgets('Today capsule uses the Apple-sized label and dispatches', (
    tester,
  ) async {
    var todayTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CalendarFloatingTodayButton(onPressed: () => todayTaps += 1),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(CalendarFloatingTodayButton)),
      const Size(kCalendarFloatingTodayWidth, kCalendarFloatingShortcutsHeight),
    );
    expect(find.bySemanticsLabel('Today'), findsOneWidget);
    final label = tester.widget<GlossyText>(find.byType(GlossyText));
    expect(label.text, 'Today');
    expect(label.gradient, KemeticGold.gloss);
    expect(label.style.fontSize, 17);
    expect(label.style.fontWeight, FontWeight.w600);
    expect(label.style.fontFamily, 'CormorantGaramond');
    expect(label.style.fontFamilyFallback, const <String>[
      'GentiumPlus',
      'Georgia',
      'serif',
    ]);

    await tester.tap(find.text('Today'));
    expect(todayTaps, 1);
  });

  testWidgets('stays out of the way while the keyboard is visible', (
    tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        home: CalendarFloatingShortcutsLayer(
          onTodayPressed: () {},
          onCalendarsPressed: () {},
          onInboxPressed: () {},
          child: const ColoredBox(color: Colors.black),
        ),
      ),
    );

    expect(find.byKey(calendarFloatingShortcutsKey), findsNothing);
    expect(find.byKey(calendarFloatingTodaySurfaceKey), findsNothing);
  });
}
