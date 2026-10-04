import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Exercise actual rejected platform writes, including the optimistic memory cache.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:mobile/features/onboarding/onboarding_progress.dart';
import 'package:mobile/features/onboarding/onboarding_overlay.dart';
import 'package:mobile/features/onboarding/haw_calendar_connection.dart';
import 'package:mobile/features/onboarding/starter_maat_flow_recommendation.dart';
import 'haw_onboarding_visual_test.dart' show compass;

class RejectingPreferences extends InMemorySharedPreferencesStore {
  RejectingPreferences(super.data) : super.withData();
  bool reject = true;
  bool throwFailure = false;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (reject) {
      if (throwFailure) throw StateError('storage unavailable');
      return false;
    }
    return super.setValue(type, key, value);
  }
}

class DelayedPreferences extends InMemorySharedPreferencesStore {
  DelayedPreferences() : super.withData({});
  final firstStarted = Completer<void>();
  final releaseFirst = Completer<void>();
  int callsForA = 0;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key.endsWith(':a') && ++callsForA == 1) {
      firstStarted.complete();
      await releaseFirst.future;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'replay restarts presentation and preserves account history across reload',
    () async {
      final original = OnboardingProgress(
        currentStep: TrueOnboardingStep.complete,
        completedOnboarding: true,
        skippedOnboarding: true,
        hawSlide: 'complete',
        entryIntent: 'reading',
        calendarConnectionPending: true,
        firstMaatFlowId: '42',
        firstMaatFlowTemplateId: 'reading-house',
        firstMaatFlowEventDate: DateTime(2026, 10, 5),
        firstMaatFlowEventClientEventId: 'saved-sitting',
        seenHelpers: const {'calendar_toggle'},
      );
      final replay = original.restartForReplay();
      final storage = OnboardingProgressStorage();
      await storage.saveRequired('a', replay);
      final restored = await storage.load('a');
      expect(restored.replayActive, isTrue);
      expect(restored.hawSlide, 'exhale');
      expect(restored.entryIntent, isNull);
      expect(restored.calendarConnectionPending, isFalse);
      expect(restored.completedOnboarding, isTrue);
      expect(restored.skippedOnboarding, isFalse);
      expect(restored.firstMaatFlowId, original.firstMaatFlowId);
      expect(restored.firstMaatFlowEventDate, original.firstMaatFlowEventDate);
      expect(restored.firstMaatFlowEventClientEventId, 'saved-sitting');
      expect(restored.seenHelpers, original.seenHelpers);
      expect((await storage.load('b')).replayActive, isFalse);
      expect(
        OnboardingProgress.fromJson({'completedOnboarding': true}).replayActive,
        isFalse,
      );
    },
  );

  test(
    'additive checkpoint survives restart under the deployed account key',
    () async {
      final progress = OnboardingProgress(
        hawSlide: 'recommendedFlow',
        entryIntent: 'imagination',
        calendarConnectionPending: true,
        firstMaatFlowId: '42',
        firstMaatFlowTemplateId: 'the-kar',
        firstMaatFlowEventDate: DateTime(2027, 1, 9),
        firstMaatFlowEventClientEventId: 'cid-42',
        seenHelpers: const {'calendar_toggle'},
      );
      await OnboardingProgressStorage().saveRequired('a', progress);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {'onboarding_v2_progress:a'});
      final raw = prefs.getString('onboarding_v2_progress:a')!;
      SharedPreferences.setMockInitialValues({'onboarding_v2_progress:a': raw});
      final restored = await OnboardingProgressStorage().load('a');
      expect(restored.toJson(), progress.toJson());
      final other = await OnboardingProgressStorage().load('b');
      expect(other.entryIntent, isNull);
      expect(other.firstMaatFlowId, isNull);
      expect(other.calendarConnectionPending, isFalse);
    },
  );

  test(
    'old checkpoint keeps enrollment and history without inventing an intent',
    () {
      final old = <String, dynamic>{
        'onboardingVersion': 2,
        'currentStep': 'firstFlowDayEvent',
        'firstMaatFlowId': '81',
        'firstMaatFlowTemplateId': 'evening-threshold',
        'firstMaatFlowEventDate': '2026-09-18T00:00:00.000',
        'firstMaatFlowEventClientEventId': 'old-cid',
        'hasChosenFirstMaatFlow': true,
        'completedOnboarding': true,
        'seenHelpers': ['calendar_toggle'],
      };
      final restored = OnboardingProgress.fromJson(old);
      expect(restored.firstMaatFlowId, '81');
      expect(restored.firstMaatFlowEventClientEventId, 'old-cid');
      expect(restored.firstMaatFlowEventDate, DateTime(2026, 9, 18));
      expect(restored.completedOnboarding, isTrue);
      expect(restored.seenHelpers, contains('calendar_toggle'));
      expect(restored.entryIntent, isNull);
      expect(restored.hawSlide, isNull);
      expect(restored.calendarConnectionPending, isFalse);
    },
  );

  test(
    'same-flow retry preserves exact event; a new enrollment clears the old target',
    () {
      final original = OnboardingProgress(
        firstMaatFlowId: '41',
        firstMaatFlowTemplateId: 'old-flow',
        firstMaatFlowEventClientEventId: 'old-event',
        firstMaatFlowEventDate: DateTime(2026, 9, 1),
        hasOpenedFirstFlowEvent: true,
        seenHelpers: const {'calendar_toggle'},
      );
      final resumed = original.withHawEnrollment(
        flowId: 41,
        templateKey: 'old-flow',
      );
      expect(resumed.firstMaatFlowEventClientEventId, 'old-event');
      expect(resumed.firstMaatFlowEventDate, original.firstMaatFlowEventDate);
      final changed = original.withHawEnrollment(
        flowId: 42,
        templateKey: 'the-kar',
      );
      expect(changed.firstMaatFlowId, '42');
      expect(changed.firstMaatFlowEventDate, isNull);
      expect(changed.firstMaatFlowEventClientEventId, isNull);
      expect(changed.hasOpenedFirstFlowEvent, isFalse);
      expect(changed.seenHelpers, original.seenHelpers);
    },
  );

  test(
    'a slow earlier checkpoint cannot overwrite completion or block another account',
    () async {
      final platform = DelayedPreferences();
      SharedPreferencesStorePlatform.instance = platform;
      final storage = OnboardingProgressStorage();
      final opening = storage.saveRequired(
        'a',
        const OnboardingProgress(hawSlide: 'closing'),
      );
      await platform.firstStarted.future;
      final completed = storage.saveRequired(
        'a',
        const OnboardingProgress(
          hawSlide: 'complete',
          completedOnboarding: true,
        ),
      );
      await storage.saveRequired(
        'b',
        const OnboardingProgress(entryIntent: 'reading'),
      );
      expect(platform.callsForA, 1);
      expect((await storage.load('b')).entryIntent, 'reading');
      platform.releaseFirst.complete();
      await Future.wait([opening, completed]);
      expect((await storage.load('a')).completedOnboarding, isTrue);
      expect((await storage.load('a')).hawSlide, 'complete');
      final disk = await platform.getAll();
      expect(
        jsonDecode(
          disk['flutter.onboarding_v2_progress:a']! as String,
        )['completedOnboarding'],
        isTrue,
      );
    },
  );

  for (final throwing in [false, true]) {
    test(
      'rejected checkpoint ($throwing) is not adopted and retry preserves content',
      () async {
        final original = jsonEncode(
          const OnboardingProgress(hawSlide: 'exhale').toJson(),
        );
        final store = RejectingPreferences({
          'flutter.onboarding_v2_progress:a': original,
          'flutter.planner_account:v1:a': 'pending-write',
        })..throwFailure = throwing;
        SharedPreferencesStorePlatform.instance = store;
        final storage = OnboardingProgressStorage();
        const pending = OnboardingProgress(
          hawSlide: 'calendarConnection',
          calendarConnectionPending: true,
        );
        await expectLater(storage.saveRequired('a', pending), throwsStateError);
        expect((await storage.load('a')).hawSlide, 'exhale');
        expect((await storage.load('a')).calendarConnectionPending, isFalse);
        expect(
          (await SharedPreferences.getInstance()).getString(
            'planner_account:v1:a',
          ),
          'pending-write',
        );
        store.reject = false;
        await storage.saveRequired('a', pending);
        expect((await storage.load('a')).calendarConnectionPending, isTrue);
      },
    );
  }

  Future<void> overlay(
    WidgetTester tester, {
    HawOnboardingSlide initial = HawOnboardingSlide.calendarConnection,
    Future<void> Function()? connect,
    Future<void> Function(String)? select,
    Future<void> Function(HawOnboardingSlide)? save,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: OnboardingOverlay(
            initialSlide: initial,
            compassCopy: compass,
            onConnectCalendar: connect,
            onEntryStateSelected: select ?? (_) async {},
            onBeforeSlideChanged: save,
            recommendedFlowBuilder: (_, _) => const SizedBox(),
            dayViewBuilder: (_, _, _) => const SizedBox(),
            dayViewEventTargetKey: GlobalKey(),
            onSkip: () {},
            onComplete: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'optional calendar step requests nothing until explicit connect',
    (tester) async {
      var connections = 0;
      await overlay(tester, connect: () async => connections++);
      expect(connections, 0);
      await tester.tap(find.text('not now'));
      await tester.pumpAndSettle();
      expect(connections, 0);
      expect(find.text('What brought you here today?'), findsOneWidget);
    },
  );

  testWidgets(
    'cancel or denied return continues; pending authorization cannot double launch',
    (tester) async {
      final returned = Completer<void>();
      var connections = 0;
      await overlay(
        tester,
        connect: () {
          connections++;
          return returned.future;
        },
      );
      await tester.tap(find.text('Connect calendar'));
      await tester.pump();
      expect(connections, 1);
      expect(find.text('What brought you here today?'), findsNothing);
      returned.complete();
      await tester.pumpAndSettle();
      expect(find.text('What brought you here today?'), findsOneWidget);
      expect(connections, 1);
    },
  );

  testWidgets('failed connection retains optional escape', (tester) async {
    await overlay(tester, connect: () async => throw StateError('offline'));
    await tester.tap(find.text('Connect calendar'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not open calendar connection'),
      findsOneWidget,
    );
    await tester.tap(find.text('not now'));
    await tester.pumpAndSettle();
    expect(find.text('What brought you here today?'), findsOneWidget);
  });

  testWidgets(
    'selection failure unlocks the options and persists only successful choice',
    (tester) async {
      final choices = <String>[];
      await overlay(
        tester,
        initial: HawOnboardingSlide.segmentation,
        select: (value) async {
          if (choices.isEmpty) {
            choices.add('failed');
            throw StateError('offline');
          }
          choices.add(value);
        },
      );
      await tester.tap(find.text(HawEntryIntent.sky.label));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not save your choice'), findsOneWidget);
      await tester.tap(find.text(HawEntryIntent.nourishment.label));
      await tester.pumpAndSettle();
      expect(choices, ['failed', 'nourishment']);
      expect(find.text('Today is Ka-her-Ka 16'), findsOneWidget);
    },
  );

  testWidgets(
    'slide save failure stays on the current slide and Retry advances once',
    (tester) async {
      var calls = 0;
      await overlay(
        tester,
        initial: HawOnboardingSlide.orientation,
        save: (_) async {
          if (++calls == 1) throw StateError('full');
        },
      );
      await tester.tap(find.text('next'));
      await tester.pumpAndSettle();
      expect(find.text('Today is Ka-her-Ka 16'), findsOneWidget);
      expect(find.text('Recommended First Flow'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Recommended First Flow'), findsOneWidget);
      expect(calls, 2);
    },
  );

  testWidgets('calendar panels stay present after failed Continue checkpoint', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HawCalendarConnectionPage(
          googlePanel: const Text('Google consent panel'),
          devicePanel: const Text('Device consent panel'),
          onContinue: () async {
            if (++calls == 1) throw StateError('full');
          },
        ),
      ),
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Google consent panel'), findsOneWidget);
    expect(find.text('Device consent panel'), findsOneWidget);
    expect(find.textContaining('Could not save your place'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.textContaining('Could not save your place'), findsNothing);
  });

  testWidgets(
    'closing seal waits for acknowledgment, handles failure, and retries once',
    (tester) async {
      final saved = Completer<void>();
      var calls = 0, completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HawOnboardingClosingBanner(
              copy: HawEntryIntent.imagination.closingCopy,
              onCommit: () async {
                if (++calls == 1) throw StateError('offline');
                await saved.future;
              },
              onComplete: () => completed++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('×'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not finish saving'), findsOneWidget);
      expect(find.text('this is ḥꜣw'), findsNothing);
      await tester.tap(find.text('×'));
      await tester.pump();
      await tester.tap(find.text('×'));
      await tester.pump(const Duration(seconds: 4));
      expect(calls, 2);
      expect(completed, 0);
      expect(find.text('this is ḥꜣw'), findsNothing);
      saved.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.text('this is ḥꜣw'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(completed, 1);
    },
  );
}
