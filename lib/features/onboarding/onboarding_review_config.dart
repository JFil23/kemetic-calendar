const String kOnboardingReviewRoute = '/debug/onboarding-review';

const bool kEnableOnboardingReview = bool.fromEnvironment(
  'ENABLE_ONBOARDING_REVIEW',
);
const bool kPwaReviewMode = bool.fromEnvironment('PWA_REVIEW_MODE');
const String kOnboardingReviewAppEnv = String.fromEnvironment(
  'APP_ENV',
  defaultValue: 'dev',
);
const String kOnboardingReviewDebugRouteEnv = String.fromEnvironment(
  'H3W_DEBUG_ROUTE',
);
const String kOnboardingReviewHelperUserId = 'onboarding-review-helper';

bool get onboardingReviewRuntimeEnabled {
  final appEnv = kOnboardingReviewAppEnv.trim().toLowerCase();
  return appEnv != 'prod' && (kEnableOnboardingReview || kPwaReviewMode);
}

bool get onboardingReviewSessionRequested {
  if (!onboardingReviewRuntimeEnabled) return false;
  return isOnboardingReviewLocation(kOnboardingReviewDebugRouteEnv) ||
      isOnboardingReviewLocation(Uri.base.toString());
}

bool isOnboardingReviewLocation(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return false;
  final uri = Uri.tryParse(value);
  final fragment = uri?.fragment.trim();
  if (fragment != null && fragment.isNotEmpty) {
    final fragmentUri = Uri.tryParse(fragment);
    final fragmentPath = fragmentUri?.path.isNotEmpty == true
        ? fragmentUri!.path
        : fragment.split('?').first;
    if (fragmentPath == kOnboardingReviewRoute) return true;
  }
  final path = uri?.path.isNotEmpty == true
      ? uri!.path
      : value.split('?').first.split('#').first;
  return path == kOnboardingReviewRoute;
}
