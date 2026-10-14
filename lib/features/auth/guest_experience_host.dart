import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../onboarding/onboarding_overlay.dart';
import '../calendar/calendar_page.dart';
import '../onboarding/guided_onboarding_overlay.dart';
import '../../services/restoration_coordinator.dart';
import 'account_access.dart';
import 'account_invitation_dialog.dart';
import 'guest_activity.dart';
import 'visitor_preferences.dart';
import 'visitor_presentation_scope.dart';

class GuestExperienceHost extends StatefulWidget {
  const GuestExperienceHost({
    super.key,
    required this.router,
    required this.onGoogleSignIn,
    required this.child,
    this.activityNow,
  });
  final GoRouter router;
  final Future<void> Function(BuildContext context) onGoogleSignIn;
  final Widget child;
  final Duration Function()? activityNow;
  @override
  State<GuestExperienceHost> createState() => _GuestExperienceHostState();
}

class _GuestExperienceHostState extends State<GuestExperienceHost>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _preferences = VisitorPreferences();
  late final _introFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
    // The requested dissolve is non-spatial, including with reduced motion.
    animationBehavior: AnimationBehavior.preserve,
  );
  late final _introOpacity = Tween<double>(
    begin: 1,
    end: 0,
  ).animate(_introFade);
  bool _dissolving = false;
  final _clock = Stopwatch()..start();
  late final _activity = GuestActivity(
    now: widget.activityNow ?? () => _clock.elapsed,
  );
  StreamSubscription<AuthState>? _auth;
  Timer? _timer;
  bool _ready = false, _intro = false, _invitationSeen = false;
  bool _continuingGuestAction = false;
  bool _dailyRhythmVisible = false;
  bool _disposing = false;
  Future<bool>? _accountRequest;
  BuildContext? _dialogContext;
  String? _handledAccountLocation;
  String? _accountOwner;
  String? _setupRetryOwner;
  bool get _signedIn => Supabase.instance.client.auth.currentSession != null;
  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.router.routerDelegate.addListener(_routeChanged);
    _accountOwner = Supabase.instance.client.auth.currentUser?.id;
    _auth = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (!mounted) return;
      final nextOwner = Supabase.instance.client.auth.currentUser?.id;
      if (_accountOwner != null && nextOwner != _accountOwner) {
        final departingContinuation =
            _continuingGuestAction || _accountRequest != null;
        _continuingGuestAction = false;
        _setupRetryOwner = null;
        widget.router.routerDelegate.navigatorKey.currentState?.popUntil(
          (route) => route.settings is Page,
        );
        if (!_signedIn || departingContinuation) widget.router.go('/pages');
        GuidedOnboardingController.instance.clear();
        GuidedOnboardingController.instance.setExternalOverlaySuppressed(false);
        unawaited(_preferences.clearLocation());
      }
      _accountOwner = nextOwner;
      if (_signedIn) {
        _invitationSeen = true;
        unawaited(_preferences.markIntroSeen());
        unawaited(_preferences.markInvitationSeen());
      }
      if (_signedIn && _accountRequest != null) _continuingGuestAction = true;
      _updateActivity();
      setState(() {
        if (_signedIn) {
          _intro = false;
        }
      });
      if (_signedIn && _dialogContext != null) {
        final dialog = _dialogContext!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (dialog.mounted && ModalRoute.of(dialog)?.isCurrent == true)
            Navigator.of(dialog).pop(true);
        });
      }
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    final seen = await _preferences.introSeen();
    final invited = await _preferences.invitationSeen();
    final pending = await _preferences.pendingLocation();
    if (!mounted) return;
    setState(() {
      _ready = true;
      _intro = !_signedIn && !seen;
      _invitationSeen = invited || _signedIn;
      _continuingGuestAction = _signedIn && pending != null;
    });
    if (_signedIn) {
      await _preferences.markIntroSeen();
      await _preferences.markInvitationSeen();
      if (pending != null && mounted) {
        _preserveVisitorNavigation();
        await _preferences.clearLocation();
        if (mounted) {
          widget.router.go(pending);
          await WidgetsBinding.instance.endOfFrame;
          final navigatorContext =
              widget.router.routerDelegate.navigatorKey.currentContext;
          final owner = Supabase.instance.client.auth.currentUser?.id;
          try {
            final completed =
                navigatorContext != null &&
                navigatorContext.mounted &&
                await CalendarPage.completeFirstAccountOnboarding(
                  navigatorContext,
                );
            _setupRetryOwner =
                completed &&
                    owner != null &&
                    Supabase.instance.client.auth.currentUser?.id == owner
                ? null
                : owner;
          } catch (_) {
            _setupRetryOwner = Supabase.instance.client.auth.currentUser?.id;
          } finally {
            if (mounted) setState(() => _continuingGuestAction = false);
          }
        }
      }
    } else if (_intro) {
      await _preferences.markIntroSeen();
    }
    if (!mounted) return;
    _updateActivity();
    _routeChanged();
  }

  Future<void> _finishIntro() async {
    await _preferences.markIntroSeen();
    if (!mounted || !_intro || _dissolving) return;
    _dissolving = true;
    try {
      await _introFade.forward().orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted || !_intro) return;
    setState(() => _intro = false);
    _updateActivity();
    _routeChanged();
  }

  void _updateActivity() {
    final enabled =
        _ready &&
        !_signedIn &&
        !_intro &&
        !_dailyRhythmVisible &&
        !_invitationSeen &&
        _accountRequest == null &&
        _foreground;
    _activity.setEnabled(enabled);
    _timer?.cancel();
    _timer = enabled
        ? Timer.periodic(const Duration(milliseconds: 100), (_) {
            if (_activity.sample()) {
              _activity.consume();
              unawaited(_requestAccount());
            }
          })
        : null;
  }

  void _setDailyRhythmVisible(bool visible) {
    if (!mounted || _disposing || _dailyRhythmVisible == visible) return;
    _dailyRhythmVisible = visible;
    _updateActivity();
  }

  void _interact() {
    if (_foreground) _activity.interact();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _updateActivity();
  }

  void _routeChanged() {
    if (!_ready || _intro || !mounted) return;
    final location = widget.router.state.uri.queryParameters['account'];
    if (location == null) {
      _handledAccountLocation = null;
      return;
    }
    final target = safeVisitorLocation(location);
    if (target == null || _handledAccountLocation == location) return;
    _handledAccountLocation = location;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          widget.router.state.uri.queryParameters['account'] != location)
        return;
      final authenticated = await _requestAccount(resumeLocation: target);
      if (!mounted) return;
      if (widget.router.state.uri.queryParameters['account'] == location) {
        widget.router.replace(authenticated ? target : '/pages');
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<bool> _requestAccount({String? resumeLocation}) {
    final owner = Supabase.instance.client.auth.currentUser?.id;
    if (_signedIn && (_accountRequest != null || _setupRetryOwner != owner))
      return Future.value(true);
    if (_accountRequest != null) return _accountRequest!;
    final completer = Completer<bool>();
    _accountRequest = completer.future;
    setState(() {
      _invitationSeen = true;
      _continuingGuestAction = true;
    });
    _preserveVisitorNavigation();
    _updateActivity();
    unawaited(() async {
      var authenticated = _signedIn;
      String? authenticatedOwner;
      try {
        await _preferences.markInvitationSeen();
        await _preferences.rememberLocation(
          resumeLocation ?? widget.router.state.uri.toString(),
        );
        if (!mounted) {
          authenticated = false;
          return;
        }
        final context =
            widget.router.routerDelegate.navigatorKey.currentContext;
        if (context == null || !context.mounted) {
          authenticated = false;
          return;
        }
        if (!authenticated) {
          authenticated =
              await showDialog<bool>(
                    context: context,
                    barrierColor: Colors.black.withValues(alpha: .68),
                    builder: (dialogContext) {
                      _dialogContext = dialogContext;
                      return AccountInvitationDialog(
                        onGoogleSignIn: () =>
                            widget.onGoogleSignIn(dialogContext),
                        onDismiss: () => Navigator.of(dialogContext).pop(false),
                      );
                    },
                  ) ==
                  true &&
              _signedIn;
        }
        _dialogContext = null;
        if (authenticated && mounted) {
          authenticatedOwner = Supabase.instance.client.auth.currentUser?.id;
          final completed = await CalendarPage.completeFirstAccountOnboarding(
            context,
          );
          authenticated =
              completed &&
              mounted &&
              authenticatedOwner != null &&
              Supabase.instance.client.auth.currentUser?.id ==
                  authenticatedOwner;
          _setupRetryOwner = authenticated ? null : authenticatedOwner;
        }
      } catch (_) {
        authenticated = false;
        _setupRetryOwner = Supabase.instance.client.auth.currentUser?.id;
        if (mounted)
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text(
                'Setup could not finish. Your draft is still here. Please retry.',
              ),
            ),
          );
      } finally {
        _dialogContext = null;
        await _preferences.clearLocation();
        _accountRequest = null;
        if (!completer.isCompleted) completer.complete(authenticated);
        if (mounted) {
          setState(() => _continuingGuestAction = false);
          _updateActivity();
        }
      }
    }());
    return completer.future;
  }

  void _preserveVisitorNavigation() {
    RestorationCoordinator.instance.suppressRestoreForUserNavigation(
      reason: 'visitor_account_continuation',
      surfaces: const [
        RestorationCoordinator.calendarOverlayStackSurface,
        RestorationCoordinator.calendarDayViewSurface,
        RestorationCoordinator.plannerSurface,
      ],
    );
  }

  @override
  void dispose() {
    _disposing = true;
    _timer?.cancel();
    _introFade.dispose();
    _auth?.cancel();
    _clock.stop();
    widget.router.routerDelegate.removeListener(_routeChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => VisitorPresentationScope(
    readyForPublicOverlays: _ready && !_intro && _accountRequest == null,
    onDailyRhythmVisibilityChanged: _setDailyRhythmVisible,
    child: AccountAccess(
      signedIn: _signedIn,
      accountId: Supabase.instance.client.auth.currentUser?.id,
      currentAccountId: () => Supabase.instance.client.auth.currentUser?.id,
      requestAccount: _requestAccount,
      deferAutomaticOnboarding: _continuingGuestAction,
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent || event is KeyRepeatEvent) _interact();
          return KeyEventResult.ignored;
        },
        child: Listener(
          onPointerDown: (_) => _interact(),
          onPointerMove: (event) {
            if (event.buttons != 0) _interact();
          },
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) _interact();
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (event) {
              if (event is ScrollUpdateNotification &&
                  event.dragDetails != null)
                _interact();
              return false;
            },
            child: Stack(
              children: [
                ExcludeSemantics(
                  excluding: !_ready || _intro,
                  child: IgnorePointer(
                    ignoring: !_ready || _intro,
                    child: widget.child,
                  ),
                ),
                if (!_ready)
                  const Positioned.fill(child: ColoredBox(color: Colors.black)),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !_intro,
                    child: FadeTransition(
                      key: const ValueKey('visitor-intro-dissolve'),
                      opacity: _introOpacity,
                      child: _intro
                          ? _VisitorIntro(onComplete: _finishIntro)
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _VisitorIntro extends StatefulWidget {
  const _VisitorIntro({required this.onComplete});
  final Future<void> Function() onComplete;
  @override
  State<_VisitorIntro> createState() => _VisitorIntroState();
}

class _VisitorIntroState extends State<_VisitorIntro> {
  final _timers = <Timer>[];
  bool _line1 = false, _line2 = false, _wordmark = false, _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.of(context).accessibleNavigation;
    if (reduced) {
      _line1 = _line2 = _wordmark = true;
    } else {
      _timers.add(
        Timer(const Duration(milliseconds: 700), () {
          if (mounted) setState(() => _line1 = true);
        }),
      );
      _timers.add(
        Timer(const Duration(milliseconds: 2200), () {
          if (mounted) setState(() => _line2 = true);
        }),
      );
      _timers.add(
        Timer(const Duration(milliseconds: 4200), () {
          if (mounted) setState(() => _wordmark = true);
        }),
      );
    }
    _timers.add(
      Timer(Duration(milliseconds: reduced ? 2800 : 6400), () {
        if (mounted) unawaited(widget.onComplete());
      }),
    );
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: Material(
      key: const ValueKey('visitor-intro'),
      color: HawIntroSlide.backgroundColor,
      child: HawIntroSlide(
        line1Visible: _line1,
        line2Visible: _line2,
        wordmarkVisible: _wordmark,
        reduceMotion:
            MediaQuery.disableAnimationsOf(context) ||
            MediaQuery.of(context).accessibleNavigation,
      ),
    ),
  );
}
