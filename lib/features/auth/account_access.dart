import 'package:flutter/material.dart';

/// The app-level account policy. Canonical views ask before beginning an
/// account action; they retain their own drafts, permissions and write owners.
class AccountAccess extends InheritedWidget {
  const AccountAccess({
    super.key,
    required this.signedIn,
    required this.requestAccount,
    this.deferAutomaticOnboarding = false,
    required super.child,
  });
  final bool signedIn;
  final Future<bool> Function({String? resumeLocation}) requestAccount;
  final bool deferAutomaticOnboarding;

  static bool automaticOnboardingDeferred(BuildContext context) =>
      context
          .getInheritedWidgetOfExactType<AccountAccess>()
          ?.deferAutomaticOnboarding ==
      true;

  static bool isGuest(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountAccess>()?.signedIn ==
      false;

  static Future<bool> require(
    BuildContext context, {
    String? resumeLocation,
  }) async {
    final policy = context.getInheritedWidgetOfExactType<AccountAccess>();
    // Isolated component hosts retain their supplied behavior. MyApp installs
    // the policy above every public route and guards private routes separately.
    if (policy == null || policy.signedIn) return true;
    return policy.requestAccount(resumeLocation: resumeLocation);
  }

  @override
  bool updateShouldNotify(AccountAccess oldWidget) =>
      signedIn != oldWidget.signedIn ||
      deferAutomaticOnboarding != oldWidget.deferAutomaticOnboarding;
}
