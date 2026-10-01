import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/snapshot/calendar_snapshot_runtime.dart';
import 'package:mobile/features/calendar/presentation/instrument_event_presentation_frame.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_day_presentation.dart';
import 'package:mobile/widgets/kemetic_keyboard.dart';
import 'package:mobile/main.dart' show AuthGate;
import 'package:mobile/widgets/keyboard_viewport_metrics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/maat_flow_visual_test_fonts.dart';
import '../pages/pages_resource_test.dart' show session;
import 'landscape_split_view_test.dart' show fixtureFlows, fixtureNotes;

// Exercise the signed-in AuthGate as well as both direct page scaffolds and
// their nested navigator, with the populated Reading House presentation.
// HTTP responses use fixtures; only disposable local test storage is used.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'haw_keyboard_route.',
    );
    Hive.init(hiveDirectory.path);
    await calendarSnapshotStore.initialize();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'com.llfbandit.app_links/messages',
      'com.llfbandit.app_links/events',
      'receive_sharing_intent/messages',
      'receive_sharing_intent/events-media',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        if (name.contains('/events') && call.method == 'listen') {
          scheduleMicrotask(
            () => messenger.handlePlatformMessage(name, null, (_) {}),
          );
        }
        return null;
      });
    }
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
          request: r,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await loadMaatFlowVisualTestFonts();
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  for (final mode in ['native', 'web-layout', 'web-visual']) {
    for (final host in ['calendar', 'authenticated-calendar', 'day']) {
      final hostName = '$host-$mode';
      testWidgets(
        '$hostName landscape composer survives keyboard open and close',
        (tester) async {
          if (host == 'authenticated-calendar') {
            await tester.runAsync(
              () => Supabase.instance.client.auth.recoverSession(session()),
            );
          }
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
                builder: (_, _) => host == 'authenticated-calendar'
                    ? const AuthGate()
                    : host == 'calendar'
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
          final sentMessages = <String>[];
          unawaited(
            showCalendarEventDetailSheetModal<void>(
              context: tester.element(pane),
              builder: (_) => MaatDayViewSheetHost(
                flow: MaatDayViewFlow.readingHouse,
                leading: const Text('Add reflection'),
                trailing: const Icon(Icons.more_vert),
                body: ReadingHouseDayPresentation(
                  onSendMessage: sentMessages.add,
                ),
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
          await tester.enterText(field, 'Visible draft');
          await _capture(tester, '$hostName-before');
          for (final inset in [
            if (host == 'authenticated-calendar') 270.0,
            100.0,
            200.0,
            240.0,
            270.0,
            290.0,
          ]) {
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
            // Finish caret reveal scheduled after the viewport relayout.
            await tester.pump(const Duration(milliseconds: 400));
            await _capture(tester, '$hostName-pane-${inset.toInt()}');
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
            await _capture(tester, '$hostName-keyboard-${inset.toInt()}');
            _expectFullyVisible(tester, field);
            final send = find.byKey(const ValueKey('reading-house-chat-send'));
            _expectFullyVisible(tester, send);
            final toggle = tester.getRect(
              find.byKey(const ValueKey('kemetic-toggle-hit-target')),
            );
            expect(
              tester.getRect(send).overlaps(toggle),
              isFalse,
              reason: 'The keyboard switch must not cover Send.',
            );
            expect(find.text('Add reflection'), findsNothing);
            expect(state.widget.controller.text, 'Visible draft');
            expect(field.hitTestable(), findsOneWidget);
            expect(tester.state<EditableTextState>(editable), same(state));
            expect(state.widget.focusNode.hasFocus, isTrue);
            expect(tester.takeException(), isNull);
          }
          keyboardInset.value = 0;
          tester.view.physicalSize = const Size(852, 393);
          tester.view.viewInsets = const FakeViewPadding();
          state.widget.focusNode.unfocus();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.getRect(pane), originalPane);
          expect(state.widget.controller.text, 'Visible draft');
          expect(find.text('Add reflection'), findsOneWidget);
          expect(find.byType(MaatDayViewFooterActions), findsOneWidget);
          expect(tester.takeException(), isNull);
          await _capture(tester, '$hostName-after');
          await tester.tap(field);
          keyboardInset.value = 270;
          tester.view.viewInsets = FakeViewPadding(
            bottom: mode == 'web-layout' ? 0 : 270,
          );
          if (mode == 'web-visual') {
            tester.view.physicalSize = const Size(852, 123);
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          _expectFullyVisible(tester, field);
          final send = find.byKey(const ValueKey('reading-house-chat-send'));
          _expectFullyVisible(tester, send);
          await tester.tap(send);
          await tester.pump();
          expect(sentMessages, ['Visible draft']);
          keyboardInset.value = 0;
          tester.view.physicalSize = const Size(852, 393);
          tester.view.viewInsets = const FakeViewPadding();
          state.widget.focusNode.unfocus();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
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
          // Finish the signed-in fixture's real I/O outside fake time, including
          // failed socket setup against the dummy endpoint. No retries may leak
          // into a later viewport case.
          await tester.runAsync(() async {
            final client = Supabase.instance.client;
            await client.removeAllChannels();
            await client.realtime.disconnect();
            client.realtime.reconnectTimer.reset();
            if (host == 'authenticated-calendar') {
              await client.auth.signOut(scope: SignOutScope.local);
            }
          });
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

// A tappable center and a rectangle above the keyboard do not prove that the
// field is painted in full. Intersect every ancestor's actual paint clip.
void _expectFullyVisible(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  final rect = MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
  var visible = rect;
  RenderObject child = box;
  while (child.parent != null) {
    final parent = child.parent!;
    final clip = parent.describeApproximatePaintClip(child);
    if (clip != null) {
      visible = visible.intersect(
        MatrixUtils.transformRect(parent.getTransformTo(null), clip),
      );
    }
    child = parent;
  }
  expect(
    visible.width,
    closeTo(rect.width, .01),
    reason: '$finder must not be clipped horizontally.',
  );
  expect(
    visible.height,
    closeTo(rect.height, .01),
    reason: '$finder must not be clipped vertically.',
  );
}
