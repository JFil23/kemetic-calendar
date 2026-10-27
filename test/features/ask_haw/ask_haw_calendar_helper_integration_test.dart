import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/ask_haw/ask_haw_onboarding_helper.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/landscape_month_view.dart';
import 'package:mobile/features/calendar/snapshot/calendar_snapshot_runtime.dart';
import 'package:mobile/features/onboarding/guided_onboarding_overlay.dart';
import 'package:mobile/features/onboarding/onboarding_progress.dart';
import 'package:mobile/widgets/kemetic_app_bar_action.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

const _owner = 'bd3f58ef-efdf-4990-b9a6-42ebf82aa8c8';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Remote remote;
  late _CompletionService service;
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'ask_calendar_helper.',
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
      url: 'https://example.supabase.test',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await loadMaatFlowVisualTestFonts();
  });

  setUp(() async {
    // These old flags must not authorize the new invitation. Its account-owned
    // progress deliberately starts incomplete below.
    SharedPreferences.setMockInitialValues({
      'app:has_seen_onboarding': true,
      'app:onboarding:completed': true,
    });
    await Supabase.instance.client.auth.recoverSession(_session());
    await calendarSnapshotStore.deleteUserScope(_owner);
    GuidedOnboardingController.instance.clear();
    GuidedOnboardingController.instance.setExternalOverlaySuppressed(false);
    OnboardingHelperCompletionService.instance.dispose();
    remote = _Remote();
    service = _CompletionService(remote);
    OnboardingHelperCompletionService.instance = service;
    await OnboardingProgressStorage().saveRequired(
      _owner,
      const OnboardingProgress(),
    );
    await service.hydrateUser(_owner);
    CalendarPage.debugCalendarTodayForTesting = DateTime(2026, 10, 27, 12);
  });

  tearDown(() {
    GuidedOnboardingController.instance.clear();
    GuidedOnboardingController.instance.setExternalOverlaySuppressed(false);
    CalendarPage.debugCalendarTodayForTesting = null;
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  for (final landscape in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'actual ${landscape ? 'landscape' : 'portrait'} Calendar + shares the post-guide helper at $scale',
        (tester) async {
          final size = landscape ? const Size(844, 390) : const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final capture = GlobalKey();
          final pageKey = GlobalKey<CalendarPageState>();
          final harness = CalendarBoundaryHarnessController(
            expansionLevel: MonthExpansionLevel.compact,
            content: CalendarBoundaryHarnessContent.empty,
            instrumentation: CalendarBoundaryInstrumentation.timingOnly,
          );
          var cleanedUp = false;
          Future<void> cleanUp() async {
            if (cleanedUp) return;
            // Detach the landscape pane while its owning Calendar context is
            // still active, as in a real rotation, before removing the route.
            tester.view.physicalSize = const Size(390, 844);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(seconds: 2));
            expect(harness.isAttached, isFalse);
            harness.dispose();
            cleanedUp = true;
          }

          addTearDown(cleanUp);
          var publications = 0;
          void published() {
            if (GuidedOnboardingController.instance.target?.helperId ==
                OnboardingHelperIds.askHawQuickAdd) {
              publications++;
            }
          }

          GuidedOnboardingController.instance.addListener(published);
          addTearDown(
            () => GuidedOnboardingController.instance.removeListener(published),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.dark,
              home: RepaintBoundary(
                key: capture,
                child: GuidedOnboardingOverlayHost(
                  child: CalendarPage(
                    key: pageKey,
                    calendarBoundaryHarnessController: harness,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump();
          expect(harness.isAttached, isTrue);
          expect(
            find.byType(LandscapeMonthView),
            landscape ? findsOneWidget : findsNothing,
          );
          final helper = tester.widget<AskHawOnboardingHelper>(
            find.byType(AskHawOnboardingHelper),
          );
          expect(
            helper.targetKey.currentWidget,
            landscape ? isA<IconButton>() : isA<KemeticAppBarAction>(),
          );
          expect(GuidedOnboardingController.instance.target, isNull);
          expect(publications, 0);
          const reference = OnboardingHelperRegistry.askHawQuickAdd;
          expect(find.text(reference.title), findsNothing);

          // The guide's existing saveRequired owner absorbs authoritative
          // progress into the already-hydrated service and notifies this same
          // mounted Calendar. No forced hydration or restart is involved.
          await OnboardingProgressStorage().saveRequired(
            _owner,
            const OnboardingProgress().copyWith(
              currentStep: TrueOnboardingStep.complete,
              completedOnboarding: true,
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump();
          expect(
            GuidedOnboardingController.instance.target?.helperId,
            reference.id,
          );
          expect(
            GuidedOnboardingController.instance.target?.helperUserId,
            _owner,
          );
          expect(
            GuidedOnboardingController.instance.target?.key,
            same(helper.targetKey),
          );
          expect(find.text(reference.title), findsOneWidget);
          final hydrationCalls = service.hydrationCalls;
          for (var frame = 0; frame < 4; frame++) {
            await tester.pump(const Duration(milliseconds: 600));
            await tester.pump();
          }
          expect(
            publications,
            1,
            reason: 'A visible helper must not republish on a timer.',
          );
          expect(service.hydrationCalls, hydrationCalls);
          expect(
            remote.loads,
            1,
            reason: 'Completed progress uses the existing hydrated owner.',
          );
          expect(tester.takeException(), isNull);

          if (Platform.environment['HAW_ASK_CALENDAR_HELPER_CAPTURE_DIR']
              case final String path when path.isNotEmpty) {
            await tester.runAsync(() async {
              final boundary =
                  capture.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                '$path/calendar-helper-${size.width.toInt()}-$scale.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }

          final away = Navigator.of(tester.element(find.byType(CalendarPage)))
              .push<void>(
                MaterialPageRoute(
                  builder: (_) =>
                      const Scaffold(body: Center(child: Text('Another page'))),
                ),
              );
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump();
          expect(GuidedOnboardingController.instance.target, isNull);
          expect(find.text(reference.title), findsNothing);
          expect(service.isHelperCompletedSync(_owner, reference.id), isFalse);
          expect(remote.writes, 0);
          Navigator.of(tester.element(find.text('Another page'))).pop();
          await tester.pump(const Duration(milliseconds: 400));
          await away;
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump();
          expect(
            GuidedOnboardingController.instance.target?.key,
            same(helper.targetKey),
          );
          expect(find.text(reference.title), findsOneWidget);
          expect(
            publications,
            2,
            reason:
                'Returning to the visible Calendar restores an unconsumed invitation.',
          );
          expect(remote.loads, 1);

          await tester.tap(
            find.byTooltip(
              landscape ? 'Add note, reminder, or flow' : 'New note',
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(service.isHelperCompletedSync(_owner, reference.id), isTrue);
          expect(GuidedOnboardingController.instance.target, isNull);
          expect(find.text(reference.title), findsNothing);
          final sheet = find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_QuickAddSheet',
          );
          expect(sheet, findsOneWidget);
          Navigator.of(tester.element(sheet)).pop();
          await tester.pump(const Duration(milliseconds: 400));
          // Rotation mounts the other canonical + owner, but the same account
          // marker must keep the invitation consumed across that entry.
          tester.view.physicalSize = Size(size.height, size.width);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 700));
          await tester.pump();
          expect(GuidedOnboardingController.instance.target, isNull);
          expect(find.text(reference.title), findsNothing);
          expect(remote.writes, 1);
          await cleanUp();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

class _CompletionService extends OnboardingHelperCompletionService {
  _CompletionService(_Remote remote) : super(remoteStore: remote);
  int hydrationCalls = 0;
  @override
  Future<OnboardingProgress> hydrateUser(String userId, {bool force = false}) {
    hydrationCalls++;
    return super.hydrateUser(userId, force: force);
  }
}

class _Remote implements OnboardingHelperCompletionRemoteStore {
  int loads = 0, writes = 0;
  final completed = <String, Set<String>>{};
  @override
  Future<Set<String>> loadCompletedHelperKeys(String userId) async {
    loads++;
    return completed[userId] ?? {};
  }

  @override
  Future<void> markCompleted(
    String userId,
    Iterable<String> completionKeys,
  ) async {
    writes++;
    completed.putIfAbsent(userId, () => {}).addAll(completionKeys);
  }
}

String _session() {
  final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  String enc(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return jsonEncode({
    'access_token':
        '${enc({'alg': 'HS256', 'typ': 'JWT'})}.${enc({'sub': _owner, 'exp': exp})}.signature',
    'refresh_token': 'fixture',
    'token_type': 'bearer',
    'expires_at': exp,
    'expires_in': 3600,
    'user': {
      'id': _owner,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'helper@example.test',
      'app_metadata': {},
      'user_metadata': {},
      'created_at': '2026-01-01T00:00:00Z',
    },
  });
}
