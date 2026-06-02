import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/onboarding/onboarding_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('complete step marks onboarding complete', () {
    final progress = const OnboardingProgress().copyWith(
      currentStep: TrueOnboardingStep.complete,
    );

    expect(progress.completedOnboarding, isTrue);
    expect(progress.currentStep, TrueOnboardingStep.complete);
  });

  test('profile basics require a glyph avatar and display name or handle', () {
    expect(
      hasCompletedProfileBasics(
        avatarGlyphIds: const ['glyph_a'],
        displayName: 'Jara',
        handle: null,
      ),
      isTrue,
    );
    expect(
      hasCompletedProfileBasics(
        avatarGlyphIds: const ['glyph_a'],
        displayName: null,
        handle: 'jara',
      ),
      isTrue,
    );
    expect(
      hasCompletedProfileBasics(
        avatarGlyphIds: const [],
        displayName: 'Jara',
        handle: 'jara',
      ),
      isFalse,
    );
    expect(
      hasCompletedProfileBasics(
        avatarGlyphIds: const ['glyph_a'],
        displayName: ' ',
        handle: null,
      ),
      isFalse,
    );
  });

  test('helper registry does not include a day view helper', () {
    expect(
      OnboardingHelperIds.all,
      isNot(contains(anyOf('dayView', 'dayViewHelper', 'dayViewReveal'))),
    );
  });

  test('storage persists progress per user', () async {
    final storage = OnboardingProgressStorage();
    final userAProgress = const OnboardingProgress().copyWith(
      hasChosenFirstMaatFlow: true,
      firstMaatFlowId: '42',
      currentStep: TrueOnboardingStep.firstFlowCalendarDay,
      seenHelpers: const {OnboardingHelperIds.calendarToggle},
    );

    await storage.save('user-a', userAProgress);

    expect(
      (await storage.load('user-a')).firstMaatFlowId,
      userAProgress.firstMaatFlowId,
    );
    expect(
      (await storage.load('user-a')).seenHelpers,
      contains(OnboardingHelperIds.calendarToggle),
    );
    expect((await storage.load('user-b')).firstMaatFlowId, isNull);
    expect((await storage.load('user-b')).seenHelpers, isEmpty);
  });

  test(
    'helper visibility is one-time for a completed onboarding user',
    () async {
      final storage = OnboardingProgressStorage();
      await storage.save(
        'user-a',
        const OnboardingProgress().copyWith(
          currentStep: TrueOnboardingStep.complete,
          completedOnboarding: true,
        ),
      );

      expect(
        await storage.shouldShowHelper(
          'user-a',
          OnboardingHelperIds.calendarToggle,
        ),
        isTrue,
      );

      await storage.markHelperCompleted(
        'user-a',
        OnboardingHelperIds.calendarToggle,
      );

      expect(
        await OnboardingProgressStorage().shouldShowHelper(
          'user-a',
          OnboardingHelperIds.calendarToggle,
        ),
        isFalse,
      );
    },
  );

  test('helpers do not show before onboarding is complete', () async {
    final storage = OnboardingProgressStorage();
    await storage.save('user-a', const OnboardingProgress());

    expect(
      await storage.shouldShowHelper(
        'user-a',
        OnboardingHelperIds.calendarToggle,
      ),
      isFalse,
    );
  });

  test('helper completion is scoped per user', () async {
    final storage = OnboardingProgressStorage();
    final completed = const OnboardingProgress().copyWith(
      currentStep: TrueOnboardingStep.complete,
      completedOnboarding: true,
    );
    await storage.save('user-a', completed);
    await storage.save('user-b', completed);

    await storage.markHelperCompleted(
      'user-a',
      OnboardingHelperIds.journalBadges,
    );

    expect(
      await storage.shouldShowHelper(
        'user-a',
        OnboardingHelperIds.journalBadges,
      ),
      isFalse,
    );
    expect(
      await storage.shouldShowHelper(
        'user-b',
        OnboardingHelperIds.journalBadges,
      ),
      isTrue,
    );
  });

  test('helper engagement merges with latest persisted helper state', () async {
    final storage = OnboardingProgressStorage();
    await storage.save(
      'user-a',
      const OnboardingProgress().copyWith(
        currentStep: TrueOnboardingStep.complete,
        completedOnboarding: true,
        seenHelpers: const {OnboardingHelperIds.calendarToggle},
      ),
    );

    await storage.markHelperCompleted(
      'user-a',
      OnboardingHelperIds.flowBuilder,
    );

    final reloaded = await OnboardingProgressStorage().load('user-a');
    expect(
      reloaded.seenHelpers,
      containsAll([
        OnboardingHelperIds.calendarToggle,
        OnboardingHelperIds.flowBuilder,
      ]),
    );
  });

  test('concurrent helper completions merge without dropping ids', () async {
    final storage = OnboardingProgressStorage();
    await storage.save(
      'user-a',
      const OnboardingProgress().copyWith(
        currentStep: TrueOnboardingStep.complete,
        completedOnboarding: true,
      ),
    );

    await Future.wait([
      storage.markHelperCompleted('user-a', OnboardingHelperIds.calendarToggle),
      storage.markHelperCompleted('user-a', OnboardingHelperIds.flowBuilder),
      storage.markHelperCompleted('user-a', OnboardingHelperIds.journalBadges),
    ]);

    final reloaded = await storage.load('user-a');
    expect(
      reloaded.seenHelpers,
      containsAll([
        OnboardingHelperIds.calendarToggle,
        OnboardingHelperIds.flowBuilder,
        OnboardingHelperIds.journalBadges,
      ]),
    );
  });

  test(
    'helper completed during onboarding stays hidden after completion',
    () async {
      final storage = OnboardingProgressStorage();
      await storage.markHelperCompleted(
        'user-a',
        OnboardingHelperIds.dayCardLongPress,
      );

      await storage.update(
        'user-a',
        (progress) => progress.copyWith(
          currentStep: TrueOnboardingStep.complete,
          completedOnboarding: true,
        ),
      );

      expect(
        await storage.shouldShowHelper(
          'user-a',
          OnboardingHelperIds.dayCardLongPress,
        ),
        isFalse,
      );
    },
  );
}
