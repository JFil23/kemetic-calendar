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
}
