import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/decan_reflection_onboarding_gate.dart';
import 'package:mobile/features/onboarding/onboarding_progress.dart';

void main() {
  const signupDecan = OnboardingDecanIdentity(kYear: 2026, kMonth: 4, decan: 2);
  const nextDecan = OnboardingDecanIdentity(kYear: 2026, kMonth: 4, decan: 3);
  const laterDecan = OnboardingDecanIdentity(kYear: 2026, kMonth: 5, decan: 1);

  OnboardingProgress completeProgress({
    bool crossed = false,
    String? firstEligibleDecan,
  }) {
    return OnboardingProgress(
      currentStep: TrueOnboardingStep.complete,
      completedOnboarding: true,
      hasSeenMenuPrompt: true,
      reflectionSignupDecanIdentity: signupDecan.wireName,
      hasCrossedFirstDecanBoundary: crossed,
      firstReflectionEligibleDecanIdentity: firstEligibleDecan,
    );
  }

  test('blocks reflections while onboarding or menu explore is incomplete', () {
    expect(
      DecanReflectionOnboardingGate.shouldBlock(
        progress: const OnboardingProgress(),
        currentDecanIdentity: signupDecan,
        promptDecanIdentity: signupDecan,
      ),
      isTrue,
    );

    expect(
      DecanReflectionOnboardingGate.shouldBlock(
        progress: const OnboardingProgress(
          currentStep: TrueOnboardingStep.menuExplore,
          completedOnboarding: false,
          hasSeenMenuPrompt: false,
        ),
        currentDecanIdentity: nextDecan,
        promptDecanIdentity: nextDecan,
      ),
      isTrue,
    );
  });

  test('blocks every reflection in the signup decan', () {
    expect(
      DecanReflectionOnboardingGate.blockReason(
        progress: completeProgress(),
        currentDecanIdentity: signupDecan,
        promptDecanIdentity: signupDecan,
      ),
      DecanReflectionOnboardingBlockReason.currentDecanIsSignupDecan,
    );
  });

  test('crossing is based on decan identity, not days since signup', () {
    expect(
      DecanReflectionOnboardingGate.hasCrossedBoundary(
        signupDecanIdentity: signupDecan.wireName,
        currentDecanIdentity: signupDecan,
      ),
      isFalse,
    );
    expect(
      DecanReflectionOnboardingGate.hasCrossedBoundary(
        signupDecanIdentity: signupDecan.wireName,
        currentDecanIdentity: nextDecan,
      ),
      isTrue,
    );
  });

  test('blocks previous signup decan prompt after first boundary crossing', () {
    expect(
      DecanReflectionOnboardingGate.blockReason(
        progress: completeProgress(
          crossed: true,
          firstEligibleDecan: nextDecan.wireName,
        ),
        currentDecanIdentity: nextDecan,
        promptDecanIdentity: signupDecan,
      ),
      DecanReflectionOnboardingBlockReason.promptIsSignupDecan,
    );
  });

  test('allows non-signup prompt only after the first boundary is crossed', () {
    expect(
      DecanReflectionOnboardingGate.shouldBlock(
        progress: completeProgress(),
        currentDecanIdentity: nextDecan,
        promptDecanIdentity: nextDecan,
      ),
      isTrue,
    );

    expect(
      DecanReflectionOnboardingGate.shouldBlock(
        progress: completeProgress(
          crossed: true,
          firstEligibleDecan: nextDecan.wireName,
        ),
        currentDecanIdentity: laterDecan,
        promptDecanIdentity: nextDecan,
      ),
      isFalse,
    );
  });

  test('same gate applies to all proactive decan UI', () {
    final duringMenuExplore =
        completeProgress(
          crossed: true,
          firstEligibleDecan: nextDecan.wireName,
        ).copyWith(
          currentStep: TrueOnboardingStep.menuExplore,
          completedOnboarding: false,
          hasSeenMenuPrompt: false,
        );

    expect(
      DecanReflectionOnboardingGate.shouldBlock(
        progress: duringMenuExplore,
        currentDecanIdentity: nextDecan,
        promptDecanIdentity: nextDecan,
      ),
      isTrue,
      reason:
          'The shared proactive-decan gate must suppress lower-thirds and guidance during menuExplore.',
    );
    expect(
      DecanReflectionOnboardingGate.shouldBlock(
        progress: completeProgress(
          crossed: true,
          firstEligibleDecan: nextDecan.wireName,
        ),
        currentDecanIdentity: nextDecan,
        promptDecanIdentity: signupDecan,
      ),
      isTrue,
      reason:
          'Queued signup-decan guidance must be discarded instead of shown later.',
    );
    expect(
      DecanReflectionOnboardingGate.shouldBlock(
        progress: completeProgress(
          crossed: true,
          firstEligibleDecan: nextDecan.wireName,
        ),
        currentDecanIdentity: laterDecan,
        promptDecanIdentity: laterDecan,
      ),
      isFalse,
    );
  });

  test('legacy completed users without a signup baseline remain eligible', () {
    expect(
      DecanReflectionOnboardingGate.shouldBlock(
        progress: const OnboardingProgress(
          currentStep: TrueOnboardingStep.complete,
          completedOnboarding: true,
          hasSeenMenuPrompt: true,
        ),
        currentDecanIdentity: nextDecan,
        promptDecanIdentity: nextDecan,
      ),
      isFalse,
    );
  });
}
