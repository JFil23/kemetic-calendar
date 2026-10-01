import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/presentation/instrument_event_presentation_frame.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_day_presentation.dart';
import 'package:mobile/widgets/kemetic_keyboard.dart';
import 'package:mobile/widgets/keyboard_viewport_metrics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/maat_flow_visual_test_fonts.dart';
import 'landscape_split_view_test.dart' show fixtureFlows, fixtureNotes;

// Use the actual page scaffolds and their nested navigator, with the existing
// populated Reading House presentation. No account writes are needed to prove
// the viewport contract that failed in the October 1 recording.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (r) async => http.Response(
          r.url.path.endsWith('get_together_inbox') ||
                  r.url.path.endsWith('get_commons_together_home_cards')
              ? '{}'
              : '[]',
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await loadMaatFlowVisualTestFonts();
  });
  tearDownAll(() => Supabase.instance.dispose());

  for (final mode in ['native', 'web-layout', 'web-visual']) {
    for (final calendarPage in [true, false]) {
      final hostName = '${calendarPage ? 'calendar' : 'day'}-$mode';
      testWidgets(
        '$hostName landscape composer survives keyboard open and close',
        (tester) async {
          tester.view.physicalSize = const Size(852, 393);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(
            left: 52,
            right: 44,
            bottom: 21,
          );
          addTearDown(tester.view.reset);
          final keyboardInset = ValueNotifier<double>(0);
          addTearDown(keyboardInset.dispose);
          final now = DateTime(2026, 9, 28, 8, 30);
          final k = KemeticMath.fromGregorian(now);
          final harness = CalendarBoundaryHarnessController(
            expansionLevel: MonthExpansionLevel.details,
            content: CalendarBoundaryHarnessContent.eventHeavy,
            instrumentation: CalendarBoundaryInstrumentation.timingOnly,
          );
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => calendarPage
                    ? CalendarPage(calendarBoundaryHarnessController: harness)
                    : DayViewPage(
                        initialKy: k.kYear,
                        initialKm: k.kMonth,
                        initialKd: k.kDay,
                        showGregorian: true,
                        notesForDay: fixtureNotes,
                        flowIndex: fixtureFlows,
                        getMonthName: (_) => 'Rekh-Nedjes',
                        clock: () => now,
                      ),
              ),
            ],
          );
          await tester.pumpWidget(
            MaterialApp.router(
              theme: ThemeData.dark().copyWith(
                textTheme: ThemeData.dark().textTheme.apply(
                  fontFamily: 'Inter',
                ),
              ),
              routerConfig: router,
              builder: (_, child) => RepaintBoundary(
                key: const ValueKey('keyboard-capture'),
                child: ValueListenableBuilder<double>(
                  valueListenable: keyboardInset,
                  builder: (_, inset, _) => KemeticKeyboardHost(
                    viewportMetricsResolver: (media) =>
                        KeyboardViewportMetrics.resolve(
                          media: media,
                          webViewport: mode == 'native'
                              ? null
                              : (
                                  height: 393 - inset,
                                  layoutHeight: 393,
                                  offsetTop: 0,
                                ),
                        ),
                    child: child!,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          final pane = find.byKey(const ValueKey('landscape-calendar-pane'));
          final originalPane = tester.getRect(pane);
          unawaited(
            showCalendarEventDetailSheetModal<void>(
              context: tester.element(pane),
              builder: (_) => MaatDayViewSheetHost(
                flow: MaatDayViewFlow.readingHouse,
                leading: const Text('Add reflection'),
                trailing: const Icon(Icons.more_vert),
                body: const ReadingHouseDayPresentation(),
                footer: MaatDayViewFooterActions(
                  onMakeTodo: () {},
                  calendarLabel: 'Calendar',
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          final field = find.byKey(
            const ValueKey('reading-house-chat-message-field'),
          );
          await tester.ensureVisible(field);
          await tester.tap(field);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          final editable = find.descendant(
            of: field,
            matching: find.byType(EditableText),
          );
          final state = tester.state<EditableTextState>(editable);
          expect(state.widget.focusNode.hasFocus, isTrue);
          await _capture(tester, '$hostName-before');
          for (final inset in [100.0, 200.0, 240.0]) {
            keyboardInset.value = inset;
            // Visual-sized web can briefly retain a stale raw inset. The host
            // must suppress it, and the scaffold must not resize behind its back.
            tester.view.viewInsets = FakeViewPadding(
              bottom: mode == 'web-layout' ? 0 : inset,
            );
            if (mode == 'web-visual') {
              tester.view.physicalSize = Size(852, 393 - inset);
            }
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            expect(
              tester.getRect(pane),
              mode == 'web-visual'
                  ? Rect.fromLTRB(
                      originalPane.left,
                      0,
                      originalPane.right,
                      393 - inset,
                    )
                  : originalPane,
              reason: 'The nested navigator must not consume keyboard space.',
            );
            final sheet = tester.getRect(find.byType(InstrumentEventSheetHost));
            expect(sheet.height, greaterThan(0));
            expect(sheet.left, greaterThanOrEqualTo(originalPane.left));
            expect(sheet.right, lessThanOrEqualTo(originalPane.right));
            final fieldRect = tester.getRect(field);
            expect(fieldRect.top, greaterThanOrEqualTo(sheet.top));
            expect(fieldRect.bottom, lessThanOrEqualTo(393 - inset));
            expect(field.hitTestable(), findsOneWidget);
            expect(tester.state<EditableTextState>(editable), same(state));
            expect(state.widget.focusNode.hasFocus, isTrue);
            expect(tester.takeException(), isNull);
            await _capture(tester, '$hostName-keyboard-${inset.toInt()}');
          }
          await tester.enterText(field, 'Visible draft');
          keyboardInset.value = 0;
          tester.view.physicalSize = const Size(852, 393);
          tester.view.viewInsets = const FakeViewPadding();
          state.widget.focusNode.unfocus();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.getRect(pane), originalPane);
          expect(state.widget.controller.text, 'Visible draft');
          expect(tester.takeException(), isNull);
          await _capture(tester, '$hostName-after');
          Navigator.of(tester.element(field)).pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          // Exercise the existing orientation handoff before disposing the page.
          tester.view.physicalSize = const Size(393, 852);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(
            find.byKey(const ValueKey('landscape-calendar-pane')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
          router.dispose();
        },
      );
    }
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_LANDSCAPE_KEYBOARD')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('keyboard-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('/tmp/haw-video-review/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
