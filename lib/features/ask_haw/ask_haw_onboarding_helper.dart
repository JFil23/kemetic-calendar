import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/account_operation_fence.dart';
import '../onboarding/guided_onboarding_overlay.dart';
import '../onboarding/onboarding_progress.dart';

/// Targets the existing + control. It owns no route, content, or account memory.
class AskHawOnboardingHelper extends StatefulWidget {
  const AskHawOnboardingHelper({
    super.key,
    required this.targetKey,
    required this.child,
  });
  final GlobalKey targetKey;
  final Widget child;

  /// Every Quick Add entry consumes the invitation, including detached sheets.
  static Future<void> consume(String userId) async {
    final service = OnboardingHelperCompletionService.instance;
    if (service.isHelperCompletedSync(
      userId,
      OnboardingHelperIds.askHawQuickAdd,
    )) {
      GuidedOnboardingController.instance.clearCompletedHelper(
        userId,
        OnboardingHelperIds.askHawQuickAdd,
      );
      return;
    }
    final completion = service.markHelperCompleted(
      userId,
      OnboardingHelperIds.askHawQuickAdd,
    );
    GuidedOnboardingController.instance.clearCompletedHelper(
      userId,
      OnboardingHelperIds.askHawQuickAdd,
    );
    try {
      await completion;
    } catch (_) {
      // Completion is already consumed in memory. Storage denial must not make
      // opening the existing editor fail or produce an unhandled future.
    }
  }

  @override
  State<AskHawOnboardingHelper> createState() => _AskHawOnboardingHelperState();
}

class _AskHawOnboardingHelperState extends State<AskHawOnboardingHelper>
    with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _auth;
  Timer? _timer;
  AccountOperationFence? _account;
  int _generation = 0;
  bool _scheduled = false;
  String? _shownFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    GuidedOnboardingController.instance.addListener(_schedule);
    OnboardingHelperCompletionService.instance.addListener(_schedule);
    _auth = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedOut ||
          state.session?.user.id != _account?.userId) {
        _invalidate();
        _schedule();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _schedule();
    } else {
      _invalidate();
    }
  }

  bool get _visible =>
      mounted &&
      ModalRoute.of(context)?.isCurrent != false &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  void _invalidate() {
    _generation++;
    _timer?.cancel();
    _account?.dispose();
    _account = null;
    final shown = _shownFor;
    _shownFor = null;
    if (shown != null) {
      GuidedOnboardingController.instance.clearCompletedHelper(
        shown,
        OnboardingHelperIds.askHawQuickAdd,
      );
    }
  }

  void _schedule() {
    if (!mounted || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      if (!_visible) {
        _invalidate();
        return;
      }
      if (_ownsVisibleHelper(_shownFor)) return;
      final overlay = GuidedOnboardingController.instance;
      if (overlay.suppressExternalOverlays) return;
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 450), () {
        unawaited(_showIfEligible());
      });
    });
  }

  bool _ownsVisibleHelper(String? owner) {
    if (owner == null) return false;
    final target = GuidedOnboardingController.instance.target;
    return target?.helperId == OnboardingHelperIds.askHawQuickAdd &&
        target?.helperUserId == owner &&
        identical(target?.key, widget.targetKey);
  }

  Future<void> _showIfEligible() async {
    if (!_visible || _ownsVisibleHelper(_shownFor)) return;
    _account?.dispose();
    final account = AccountOperationFence(Supabase.instance.client);
    _account = account;
    final owner = account.userId;
    if (owner == null) return;
    final generation = ++_generation;
    final service = OnboardingHelperCompletionService.instance;
    try {
      await service.hydrateUser(owner);
      if (!mounted ||
          !account.isCurrent ||
          generation != _generation ||
          !_visible ||
          _ownsVisibleHelper(owner) ||
          widget.targetKey.currentContext == null ||
          GuidedOnboardingController.instance.suppressExternalOverlays ||
          !service.shouldShowHelperSync(
            owner,
            OnboardingHelperIds.askHawQuickAdd,
          )) {
        return;
      }
      const helper = OnboardingHelperRegistry.askHawQuickAdd;
      _shownFor = owner;
      GuidedOnboardingController.instance.show(
        CoachmarkTarget(
          key: widget.targetKey,
          title: helper.title,
          body: helper.body,
          placement: CoachmarkPlacement.below,
          variant: CoachmarkVariant.helperBubble,
          showDismissButton: true,
          dismissLabel: 'Got it',
          helperId: helper.id,
          helperUserId: owner,
          sourceWidget: helper.sourceWidget,
          onDismiss: () => unawaited(consumeSafely(owner)),
        ),
      );
    } catch (_) {
      // A helper must never hold up the retained page or its + control.
    }
  }

  Future<void> consumeSafely(String owner) async {
    try {
      await AskHawOnboardingHelper.consume(owner);
    } catch (_) {
      // The service consumes in memory before persisting its existing marker.
    }
  }

  @override
  void dispose() {
    GuidedOnboardingController.instance.removeListener(_schedule);
    OnboardingHelperCompletionService.instance.removeListener(_schedule);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_auth?.cancel());
    _timer?.cancel();
    _account?.dispose();
    final shown = _shownFor;
    if (shown != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        GuidedOnboardingController.instance.clearCompletedHelper(
          shown,
          OnboardingHelperIds.askHawQuickAdd,
        );
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
