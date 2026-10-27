import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/data/flows_repo.dart';
import 'package:mobile/data/user_events_repo.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/flow_detail_event_focus.dart';
import '../../support/maat_flow_visual_test_fonts.dart';
import '../pages/pages_resource_test.dart' show session, uid;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    for (final name in ['messages', 'events']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('com.llfbandit.app_links/$name'),
            (_) async => null,
          );
    }
    await Supabase.initialize(
      url: 'https://example.supabase.test',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async => http.Response('[]', 200)),
    );
    await Supabase.instance.client.auth.recoverSession(session());
    await loadMaatFlowVisualTestFonts();
  });
  tearDownAll(() async => Supabase.instance.dispose());
  for (final maat in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'owned ${maat ? 'Ma’at' : 'custom'} menu passes exact context at $scale',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final capture = GlobalKey();
          final events = <FlowEventRow>[
            (
              id: 'selected-event',
              clientEventId: 'selected-occurrence',
              calendarId: null,
              calendarName: null,
              calendarColor: null,
              calendarIsPersonal: true,
              title: 'A practice',
              detail: null,
              location: null,
              allDay: false,
              startsAtUtc: DateTime.now().toUtc(),
              endsAtUtc: DateTime.now().toUtc().add(
                const Duration(minutes: 20),
              ),
              flowLocalId: 42,
              category: null,
              actionId: null,
              behaviorPayload: null,
            ),
          ];
          await tester.pumpWidget(
            RepaintBoundary(
              key: capture,
              child: MaterialApp(
                theme: AppTheme.dark,
                debugShowCheckedModeBanner: false,
                home: CalendarPage.buildCanonicalOwnedFlowDetail(
                  row: FlowRow.fromRow({
                    'id': 42,
                    'user_id': uid,
                    'name': maat ? 'The Djed' : 'Reading practice',
                    'active': true,
                    'rules': [],
                    if (maat) 'notes': 'maat=the-djed',
                    'start_date': DateTime.now().toIso8601String(),
                  }),
                  events: events,
                  eventTarget: const FlowDetailEventTarget(
                    eventId: 'selected-event',
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 500));
          await tester.tap(
            find.byKey(const ValueKey('user-flow-detail-options')),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          final action = find.byKey(
            const ValueKey('flow-detail-action-ask_haw'),
          );
          expect(action, findsOneWidget);
          expect(find.text('Ask ḥꜣw'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (Platform.environment['HAW_ASK_CONTEXT_CAPTURE_DIR']
              case final String path when path.isNotEmpty) {
            await tester.runAsync(() async {
              final boundary =
                  capture.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File('$path/${maat ? 'maat' : 'custom'}-$scale.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          if (!const bool.fromEnvironment('ASK_CONTEXT_STATIC_ONLY')) {
            await tester.tap(action);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
            final dynamic sheet = tester.widget(
              find.byWidgetPredicate(
                (widget) => widget.runtimeType.toString() == '_QuickAddSheet',
              ),
            );
            expect(sheet.selectedFlowId, 42);
            expect(sheet.selectedEventId, 'selected-event');
            expect(sheet.selectedClientEventId, 'selected-occurrence');
            expect(
              find.byKey(const ValueKey('quick-add-input')),
              findsOneWidget,
            );
            await tester.tap(find.byKey(const ValueKey('quick-add-close')));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
            expect(
              find.byKey(const ValueKey('user-flow-detail-options')),
              findsOneWidget,
            );
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 300));
        },
      );
    }
  }
}
