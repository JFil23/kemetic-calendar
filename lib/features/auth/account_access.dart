import 'package:flutter/material.dart';

/// The app-level account policy. Canonical views ask before beginning an
/// account action; they retain their own drafts, permissions and write owners.
class AccountAccess extends InheritedWidget {
  const AccountAccess({
    super.key,
    required this.signedIn,
    required this.requestAccount,
    this.deferAutomaticOnboarding = false,
    this.accountId,
    this.currentAccountId,
    required super.child,
  });
  final bool signedIn;
  final String? accountId;
  final String? Function()? currentAccountId;
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
    if (policy == null) return true;
    if (policy.signedIn) {
      if (policy.currentAccountId == null) return true;
      if (policy.accountId == null ||
          policy.accountId != policy.currentAccountId!())
        return false;
      final permitted = await policy.requestAccount(
        resumeLocation: resumeLocation,
      );
      return permitted && policy.accountId == policy.currentAccountId!();
    }
    return policy.requestAccount(resumeLocation: resumeLocation);
  }

  @override
  bool updateShouldNotify(AccountAccess oldWidget) =>
      signedIn != oldWidget.signedIn ||
      accountId != oldWidget.accountId ||
      deferAutomaticOnboarding != oldWidget.deferAutomaticOnboarding;
}
