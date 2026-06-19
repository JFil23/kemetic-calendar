import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/data/journal_repo.dart';
import 'package:mobile/features/calendar/calendar_reflection_context.dart';
import 'package:mobile/features/journal/journal_badge_utils.dart';
import 'package:mobile/features/journal/journal_controller.dart';
import 'package:mobile/features/journal/journal_overlay.dart';
import 'package:mobile/features/journal/journal_v2_toolbar.dart';
import 'package:mobile/main.dart' as app;
import 'package:mobile/services/session_resume_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {}

  await Supabase.initialize(
    url: 'https://example.supabase.co',
    anonKey: 'anon-key-0123456789012345678901234567890123456789',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await _ensureSupabaseInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('badge section and toolbar stay visible while keyboard is open', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final client = SupabaseClient(
      'https://example.com',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final controller = JournalController(client);

    await tester.pumpWidget(
      _JournalHarness(controller: controller, bottomInset: 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Badges'), findsOneWidget);
    expect(find.byType(JournalV2Toolbar), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_hide), findsNothing);

    await tester.pumpWidget(
      _JournalHarness(controller: controller, bottomInset: 320),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Badges'), findsOneWidget);
    expect(find.byType(JournalV2Toolbar), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_hide), findsNothing);

    await tester.pumpWidget(
      _JournalHarness(controller: controller, bottomInset: 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Badges'), findsOneWidget);
    expect(find.byType(JournalV2Toolbar), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_hide), findsNothing);
  });

  testWidgets('typing does not show sync pending banner', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = JournalController.withRepo(
      _NoopJournalRepo(),
      currentUserId: () => 'user-a',
    );
    await controller.updateDraft('Unsaved local text');

    await tester.pumpWidget(
      _JournalHarness(controller: controller, bottomInset: 320),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.syncStatus, JournalSyncStatus.unsavedLocal);
    expect(find.textContaining('Sync pending'), findsNothing);
    expect(find.textContaining('Saved on this device'), findsNothing);

    await controller.forceSave();
  });

  testWidgets('page journal text field accepts focus and typed input', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = JournalController.withRepo(
      _NoopJournalRepo(),
      currentUserId: () => 'user-a',
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _JournalHarness(controller: controller, bottomInset: 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final fieldFinder = find.byType(TextField);
    expect(fieldFinder, findsOneWidget);

    await tester.tap(fieldFinder);
    await tester.pump();

    final field = tester.widget<TextField>(fieldFinder);
    expect(field.readOnly, isFalse);
    expect(field.enabled, isNot(false));
    expect(field.focusNode?.hasFocus, isTrue);
    expect(field.decoration?.filled, isFalse);
    expect(field.decoration?.fillColor, Colors.transparent);

    await tester.enterText(fieldFinder, 'Today I can write.');
    await tester.pump();

    expect(controller.currentDraft, 'Today I can write.');
    expect(field.focusNode?.hasFocus, isTrue);

    await controller.forceSave();
  });

  testWidgets(
    'journal text field accepts input under app chrome after menu activity',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() async {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        app.resetGlobalFloatingMenuShellForTesting();
      });

      final controller = JournalController.withRepo(
        _NoopJournalRepo(),
        currentUserId: () => 'user-a',
      );
      addTearDown(controller.dispose);

      var bottomInset = 0.0;
      final router = GoRouter(
        initialLocation: '/journal',
        routes: [
          GoRoute(
            path: '/journal',
            builder: (context, state) => SessionTrackedRoute(
              location: state.uri.toString(),
              child: JournalOverlay(
                controller: controller,
                isPortrait: true,
                onClose: () {},
                presentationMode: JournalPresentationMode.page,
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      Widget buildChrome() {
        return MaterialApp.router(
          routerConfig: router,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(
              context,
            ).copyWith(viewInsets: EdgeInsets.only(bottom: bottomInset));
            return MediaQuery(
              data: mediaQuery,
              child: app.buildGlobalFloatingMenuShellForTesting(
                router: router,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
        );
      }

      await tester.pumpWidget(buildChrome());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(app.globalMenuButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      bottomInset = 320;
      await tester.pumpWidget(buildChrome());
      await tester.pump();

      final fieldFinder = find.byType(TextField);
      expect(fieldFinder, findsOneWidget);

      await tester.tap(fieldFinder);
      await tester.pump();

      final field = tester.widget<TextField>(fieldFinder);
      expect(field.readOnly, isFalse);
      expect(field.enabled, isNot(false));
      expect(field.focusNode?.hasFocus, isTrue);

      await tester.enterText(fieldFinder, 'Chrome route input works.');
      await tester.pump();

      expect(controller.currentDraft, 'Chrome route input works.');
      expect(field.focusNode?.hasFocus, isTrue);

      await controller.forceSave();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets('delayed empty load cannot replace focused journal editor text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = _DelayedJournalRepo();
    final controller = JournalController.withRepo(
      repo,
      currentUserId: () => 'user-a',
    );
    addTearDown(controller.dispose);

    final initFuture = controller.init();
    await repo.requested.future;

    var bottomInset = 0.0;
    await tester.pumpWidget(
      _JournalHarness(controller: controller, bottomInset: bottomInset),
    );
    await tester.pump();

    var fieldFinder = find.byType(TextField);
    expect(fieldFinder, findsOneWidget);

    await tester.tap(fieldFinder);
    await tester.pump();
    await tester.enterText(fieldFinder, 'Focus text survives async load.');
    await tester.pump();

    bottomInset = 320;
    await tester.pumpWidget(
      _JournalHarness(controller: controller, bottomInset: bottomInset),
    );
    await tester.pump();

    repo.completeWith(null);
    await initFuture;
    await tester.pumpWidget(
      _JournalHarness(controller: controller, bottomInset: bottomInset),
    );
    await tester.pump();

    fieldFinder = find.byType(TextField);
    final field = tester.widget<TextField>(fieldFinder);
    expect(controller.currentDraft, 'Focus text survives async load.');
    expect(field.focusNode?.hasFocus, isTrue);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'Focus text survives async load.',
    );

    await controller.forceSave();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets(
    'JournalRoutePage carries reflection context without creating badges',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() async {
        tester.view.reset();
      });

      final repo = _NoopJournalRepo();
      final controller = _TrackingJournalController(repo);
      final reflectionContext = CalendarReflectionContext(
        sourceType: CompletionSourceType.userFlow,
        sourceId: 'cid:event-1',
        title: 'Practice',
        calendarDate: DateTime(2026, 6, 9),
        occurrenceId: 'occ-1',
        eventId: 'event-1',
        flowId: 7,
        completionStatus: CompletionStatus.observed,
        reflectionPrompt: 'What did this help me see?',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: app.JournalRoutePage(
            controllerForTesting: controller,
            reflectionContext: reflectionContext,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.appendToTodayCalls, 0);
      expect(repo.upsertCalls, 0);
      expect(controller.loadedDate, DateTime(2026, 6, 9));
      expect(controller.currentDraft, isEmpty);
      expect(find.text('𓂝'), findsOneWidget);
      expect(find.text('No badges yet'), findsNothing);
      expect(
        find.text('Event badges you add from day view will appear here.'),
        findsNothing,
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, isEmpty);
      expect(field.decoration?.hintText, 'What did this help me see?');
      expect(field.decoration?.hintText, isNot(contains('Reflection on')));
      expect(field.decoration?.hintText, isNot(contains('Date:')));
      expect(field.decoration?.hintText, isNot(contains('Source:')));
      expect(field.decoration?.hintText, isNot(contains('Source id:')));
      expect(field.decoration?.hintText, isNot(contains('Occurrence id:')));
      expect(field.decoration?.hintText, isNot(contains('Event id:')));
      expect(field.decoration?.hintText, isNot(contains('source_type')));
      expect(field.decoration?.hintText, isNot(contains('user_flow')));
      expect(reflectionContext.sourceId, 'cid:event-1');
      expect(reflectionContext.occurrenceId, 'occ-1');
      expect(reflectionContext.eventId, 'event-1');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
      expect(repo.upsertCalls, 0);
    },
  );

  testWidgets(
    'JournalRoutePage saves user reflection text without placeholder metadata',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() async {
        tester.view.reset();
      });

      final repo = _NoopJournalRepo();
      final controller = _TrackingJournalController(repo);
      final reflectionContext = CalendarReflectionContext(
        sourceType: CompletionSourceType.userFlow,
        sourceId: 'cid:event-1',
        title: 'Practice',
        calendarDate: DateTime(2026, 6, 9),
        occurrenceId: 'occ-1',
        eventId: 'event-1',
        flowId: 7,
        completionStatus: CompletionStatus.observed,
        reflectionPrompt: 'What did this help me see?',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: app.JournalRoutePage(
            controllerForTesting: controller,
            reflectionContext: reflectionContext,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fieldFinder = find.byType(TextField);
      await tester.enterText(fieldFinder, 'I noticed support.');
      await tester.pump();
      await controller.forceSave();

      expect(repo.upsertCalls, 1);
      expect(repo.lastSavedBody, contains('I noticed support.'));
      expect(repo.lastSavedBody, isNot(contains('What did this help me see?')));
      expect(repo.lastSavedBody, isNot(contains('Source id:')));
      expect(repo.lastSavedBody, isNot(contains('cid:event-1')));
      expect(repo.lastSavedBody, isNot(contains('Occurrence id:')));
      expect(repo.lastSavedBody, isNot(contains('Event id:')));
      expect(repo.lastSavedBody, isNot(contains('event-1')));
      expect(JournalBadgeUtils.hasBadges(repo.lastSavedBody ?? ''), isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets(
    'JournalRoutePage stays stable under app chrome after flow route activity',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() async {
        tester.view.reset();
        app.resetGlobalFloatingMenuShellForTesting();
      });

      final controller = JournalController.withRepo(
        _NoopJournalRepo(),
        currentUserId: () => 'user-a',
      );

      late GoRouter router;
      router = GoRouter(
        initialLocation: '/calendar',
        routes: [
          GoRoute(
            path: '/calendar',
            builder: (context, state) => SessionTrackedRoute(
              location: state.uri.toString(),
              child: Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => context.go('/flows/42/edit'),
                    child: const Text('Edit Flow'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/flows/:flowId/edit',
            builder: (context, state) => SessionTrackedRoute(
              location: state.uri.toString(),
              child: Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => context.go('/journal'),
                    child: const Text('Open Journal'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/journal',
            builder: (context, state) => SessionTrackedRoute(
              location: state.uri.toString(),
              child: app.JournalRoutePage(controllerForTesting: controller),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      Widget buildChrome() {
        return MaterialApp.router(
          routerConfig: router,
          builder: (context, child) {
            return app.buildGlobalFloatingMenuShellForTesting(
              router: router,
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      }

      await tester.pumpWidget(buildChrome());
      await tester.pump();

      await tester.tap(find.text('Edit Flow'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Journal'));
      await tester.pumpAndSettle();

      final fieldFinder = find.byType(TextField);
      expect(fieldFinder, findsOneWidget);

      await tester.tap(fieldFinder);
      await tester.pump();
      await tester.enterText(fieldFinder, 'Route chrome input works.');
      await tester.pump();

      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pump();
      await tester.pump();

      expect(fieldFinder, findsOneWidget);
      final field = tester.widget<TextField>(fieldFinder);
      expect(controller.currentDraft, 'Route chrome input works.');
      expect(field.focusNode?.hasFocus, isTrue);
      expect(controller.initRunCount, 1);
      expect(controller.reloadTodayRunCount, 1);

      await controller.forceSave();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
    },
  );
}

class _NoopJournalRepo extends JournalRepo {
  _NoopJournalRepo()
    : super(
        SupabaseClient(
          'https://example.com',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  int getByDateStrictCalls = 0;
  int upsertCalls = 0;
  String? lastSavedBody;
  Map<String, dynamic>? lastSavedMeta;

  @override
  Future<JournalEntry?> getByDate(DateTime localDate) =>
      getByDateStrict(localDate);

  @override
  Future<JournalEntry?> getByDateStrict(DateTime localDate) async {
    getByDateStrictCalls += 1;
    return null;
  }

  @override
  Future<void> upsert({
    required DateTime localDate,
    required String body,
    Map<String, dynamic>? meta,
    String? category,
  }) async {
    upsertCalls += 1;
    lastSavedBody = body;
    lastSavedMeta = meta;
  }
}

class _TrackingJournalController extends JournalController {
  _TrackingJournalController(super.repo)
    : super.withRepo(currentUserId: () => 'user-a');

  int appendToTodayCalls = 0;
  DateTime? loadedDate;

  @override
  Future<int> appendToToday(String content) async {
    appendToTodayCalls += 1;
    return super.appendToToday(content);
  }

  @override
  Future<void> loadDate(DateTime date) async {
    loadedDate = DateTime(date.year, date.month, date.day);
    await super.loadDate(date);
  }
}

class _DelayedJournalRepo extends _NoopJournalRepo {
  final Completer<void> requested = Completer<void>();
  final Completer<JournalEntry?> _response = Completer<JournalEntry?>();

  void completeWith(JournalEntry? entry) {
    if (!_response.isCompleted) {
      _response.complete(entry);
    }
  }

  @override
  Future<JournalEntry?> getByDateStrict(DateTime localDate) {
    getByDateStrictCalls += 1;
    if (!requested.isCompleted) {
      requested.complete();
    }
    return _response.future;
  }
}

class _JournalHarness extends StatelessWidget {
  const _JournalHarness({required this.controller, required this.bottomInset});

  final JournalController controller;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        viewInsets: EdgeInsets.only(bottom: bottomInset),
      ),
      child: MaterialApp(
        home: JournalOverlay(
          controller: controller,
          isPortrait: true,
          onClose: () {},
          presentationMode: JournalPresentationMode.page,
        ),
      ),
    );
  }
}
