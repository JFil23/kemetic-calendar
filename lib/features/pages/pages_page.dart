import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart' show routeObserver;
import '../../core/navigation_fallback.dart';
import '../../data/profile_repo.dart';
import '../calendar/calendar_page.dart';
import 'pages_controller.dart';
import 'pages_layout.dart';
import 'pages_models.dart';

class PagesPage extends StatefulWidget {
  const PagesPage({super.key});
  @override
  State<PagesPage> createState() => _PagesPageState();
}

class _PagesPageState extends State<PagesPage>
    with WidgetsBindingObserver, RouteAware {
  PagesController? _controller;
  PageRoute? _route;
  StreamSubscription? _auth;
  DateTime? _backgroundedAt;
  bool _covered = false, _opening = false;
  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final client = Supabase.instance.client;
    if (client.auth.currentUser != null) {
      _controller = PagesController(
        client,
        onLocalBoundary: CalendarPage.publishPagesSnapshot,
      );
    }
    _auth = client.auth.onAuthStateChange.listen((event) {
      if (mounted &&
          _controller != null &&
          event.session?.user.id != _controller!.uid) {
        _controller!.dispose();
        setState(() => _controller = null);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _activate();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _route) {
      if (_route != null) routeObserver.unsubscribe(this);
      _route = route;
      routeObserver.subscribe(this, route);
    }
  }

  void _activate({bool resumed = false}) {
    if (mounted) {
      _controller?.setVisible(
        !_covered && !_opening && _foreground,
        resumed: resumed,
      );
    }
  }

  @override
  void didPushNext() {
    _covered = true;
    _activate();
  }

  @override
  void didPopNext() {
    _covered = false;
    _activate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
    }
    if (state == AppLifecycleState.resumed && _backgroundedAt != null) {
      _controller?.resumeAfter(_backgroundedAt!);
      _backgroundedAt = null;
    }
    _activate(resumed: state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    unawaited(_auth?.cancel());
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _present(Future<void> Function() action) async {
    if (_opening) return;
    _opening = true;
    _activate();
    try {
      await action();
    } finally {
      if (mounted) {
        _opening = false;
        _activate();
      }
    }
  }

  Future<void> _open(PagesDestination destination) async {
    if (destination == PagesDestination.calendar) {
      closeOrReturn(context, '/');
      return;
    }
    await _present(() async {
      switch (destination) {
        case PagesDestination.calendar:
          break;
        case PagesDestination.feed:
          await openDetailRoute<void>(context, '/profile/me?feed=1');
        case PagesDestination.library:
          await openDetailRoute<void>(context, '/nodes');
        case PagesDestination.planner:
          await openUtilityRoute<void>(context, '/rhythm/today');
        case PagesDestination.journal:
          await openUtilityRoute<void>(context, '/journal');
        case PagesDestination.inbox:
          await openUtilityRoute<void>(context, '/inbox');
        case PagesDestination.calendars:
          await openUtilityRoute<void>(context, '/calendars');
        case PagesDestination.studio:
          await CalendarPage.openFlowStudioFromAnyContext(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Return to calendar'),
          ),
        ),
      );
    }
    final profile = ProfileRepo(
      Supabase.instance.client,
    ).getCachedProfileSync(controller.uid);
    return PagesLayout(
      cards: controller.cards,
      onOpen: (d) => unawaited(_open(d)),
      profileName: profile?.effectiveName ?? '',
      profileGlyphIds: profile?.avatarGlyphIds ?? const [],
      searchRecords: controller.searchRecords,
      onProfile: () => unawaited(
        _present(() async {
          await openDetailRoute<void>(context, '/profile/me');
        }),
      ),
      onNewNote: () => unawaited(
        _present(() => CalendarPage.openQuickAddFromAnyContext(context)),
      ),
      onSearchResult: (r) => unawaited(
        _present(() async {
          if ([
            '/rhythm/today',
            '/journal',
            '/calendars',
          ].contains(r.location)) {
            await openUtilityRoute<void>(context, r.location);
          } else {
            await openDetailRoute<void>(context, r.location);
          }
        }),
      ),
    );
  }
}
