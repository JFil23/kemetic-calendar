import 'package:flutter/foundation.dart';

import 'onboarding_progress.dart';

@immutable
class OnboardingDecanIdentity {
  const OnboardingDecanIdentity({
    required this.kYear,
    required this.kMonth,
    required this.decan,
  });

  factory OnboardingDecanIdentity.fromKemeticDay({
    required int kYear,
    required int kMonth,
    required int kDay,
  }) {
    final decan = kMonth == 13 ? 0 : (((kDay - 1).clamp(0, 29) ~/ 10) + 1);
    return OnboardingDecanIdentity(kYear: kYear, kMonth: kMonth, decan: decan);
  }

  final int kYear;
  final int kMonth;
  final int decan;

  static OnboardingDecanIdentity? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length != 3) return null;
    final kYear = int.tryParse(parts[0]);
    final kMonth = int.tryParse(parts[1]);
    final decan = int.tryParse(parts[2]);
    if (kYear == null || kMonth == null || decan == null) return null;
    return OnboardingDecanIdentity(kYear: kYear, kMonth: kMonth, decan: decan);
  }

  String get wireName => '$kYear:$kMonth:$decan';

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is OnboardingDecanIdentity &&
            other.kYear == kYear &&
            other.kMonth == kMonth &&
            other.decan == decan;
  }

  @override
  int get hashCode => Object.hash(kYear, kMonth, decan);

  @override
  String toString() => wireName;
}

enum DecanReflectionOnboardingBlockReason {
  allowed,
  onboardingIncomplete,
  menuExploreIncomplete,
  currentDecanIsSignupDecan,
  firstBoundaryNotCrossed,
  promptIsSignupDecan,
}

class DecanReflectionOnboardingGate {
  const DecanReflectionOnboardingGate._();

  static bool hasCrossedBoundary({
    required String? signupDecanIdentity,
    required OnboardingDecanIdentity? currentDecanIdentity,
  }) {
    final signup = OnboardingDecanIdentity.tryParse(signupDecanIdentity);
    return signup != null &&
        currentDecanIdentity != null &&
        currentDecanIdentity != signup;
  }

  static DecanReflectionOnboardingBlockReason blockReason({
    required OnboardingProgress progress,
    required OnboardingDecanIdentity? currentDecanIdentity,
    required OnboardingDecanIdentity? promptDecanIdentity,
  }) {
    if (!progress.completedOnboarding) {
      return DecanReflectionOnboardingBlockReason.onboardingIncomplete;
    }
    if (!progress.hasSeenMenuPrompt ||
        progress.currentStep != TrueOnboardingStep.complete) {
      return DecanReflectionOnboardingBlockReason.menuExploreIncomplete;
    }

    final signup = OnboardingDecanIdentity.tryParse(
      progress.reflectionSignupDecanIdentity,
    );
    if (signup == null) {
      return DecanReflectionOnboardingBlockReason.allowed;
    }
    if (currentDecanIdentity == signup) {
      return DecanReflectionOnboardingBlockReason.currentDecanIsSignupDecan;
    }
    if (!progress.hasCrossedFirstDecanBoundary) {
      return DecanReflectionOnboardingBlockReason.firstBoundaryNotCrossed;
    }
    if (promptDecanIdentity == signup) {
      return DecanReflectionOnboardingBlockReason.promptIsSignupDecan;
    }
    return DecanReflectionOnboardingBlockReason.allowed;
  }

  static bool shouldBlock({
    required OnboardingProgress progress,
    required OnboardingDecanIdentity? currentDecanIdentity,
    required OnboardingDecanIdentity? promptDecanIdentity,
  }) {
    return blockReason(
          progress: progress,
          currentDecanIdentity: currentDecanIdentity,
          promptDecanIdentity: promptDecanIdentity,
        ) !=
        DecanReflectionOnboardingBlockReason.allowed;
  }
}
