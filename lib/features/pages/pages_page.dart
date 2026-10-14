import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart' show routeObserver;
import '../../core/navigation_fallback.dart';
import '../../data/profile_repo.dart';
import '../calendar/calendar_page.dart';
import '../inbox/inbox_activity_target.dart';
import '../../data/share_models.dart';
import 'pages_feed_rotation.dart';
import 'pages_controller.dart';
import 'pages_collections.dart';
import 'pages_collections_controller.dart';
import 'pages_layout.dart';
import 'pages_models.dart';
import 'guest_pages_content.dart';
import '../auth/account_access.dart';

class PagesPage extends StatefulWidget {
  const PagesPage({super.key});
  @override
  State<PagesPage> createState() => _PagesPageState();
}

class _PagesPageState extends State<PagesPage>
    with WidgetsBindingObserver, RouteAware {
  PagesController? _controller;
  PagesCollectionsController? _collections;
  late final _guestContent = GuestPagesContent(DateTime.now());
  PagesCollection? _guestSelection;
  bool _createIntentHandled = false;
  PageRoute? _route;
  StreamSubscription? _auth;
  DateTime? _backgroundedAt;
  bool _covered = false;
  Object? _openingOperation;
  bool get _opening => _openingOperation != null;
  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final client = Supabase.instance.client;
    if (client.auth.currentUser != null) {
      _collections = PagesCollectionsController(client);
      _controller = PagesController(
        client,
        onLocalBoundary: () {
          CalendarPage.publishPagesSnapshot();
          _collections?.refreshDate();
        },
      );
    }
    _auth = client.auth.onAuthStateChange.listen((event) {
      if (mounted && event.session?.user.id != _controller?.uid) {
        _controller?.dispose();
        _collections?.dispose();
        _collections = null;
        _controller = null;
        if (event.session != null) {
          _collections = PagesCollectionsController(client);
          _collections!.select(_guestSelection);
          _controller = PagesController(
            client,
            onLocalBoundary: () {
              CalendarPage.publishPagesSnapshot();
              _collections?.refreshDate();
            },
          );
        }
        setState(() {});
        _activate();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _activate();
    });
  }

  void _scheduleCreateIntent(Uri uri) {
    if (uri.queryParameters['create'] != 'note') {
      _createIntentHandled = false;
      return;
    }
    final owner = _controller?.uid;
    if (owner == null || _createIntentHandled) return;
    _createIntentHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || Supabase.instance.client.auth.currentUser?.id != owner)
        return;
      final router = GoRouter.of(context);
      if (router.state.uri.queryParameters['create'] != 'note') return;
      await CalendarPage.openQuickAddFromAnyContext(context);
      if (mounted &&
          router.state.uri.path == '/pages' &&
          router.state.uri.queryParameters['create'] == 'note')
        router.replace('/pages');
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
      _collections?.setVisible(!_covered && !_opening && _foreground);
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
    // Browser history can remove a pushed route without completing its Future.
    // Becoming the visible page ends that operation's ownership of the guard.
    _openingOperation = null;
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
      if (_controller == null) _guestContent.refresh(DateTime.now());
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
    _collections?.dispose();
    _guestContent.dispose();
    super.dispose();
  }

  Future<void> _present(Future<void> Function() action) async {
    if (_opening || _covered) return;
    final operation = Object();
    _openingOperation = operation;
    _activate();
    try {
      await action();
    } finally {
      if (mounted && identical(_openingOperation, operation)) {
        _openingOperation = null;
        _activate();
      }
    }
  }

  Future<void> _open(PagesCard card) async {
    final controller = _controller;
    if (controller != null &&
        Supabase.instance.client.auth.currentUser?.id != controller.uid) {
      return;
    }
    final destination = card.destination;
    if (destination == PagesDestination.calendar) {
      closeOrReturn(context, '/');
      return;
    }
    if (controller == null) {
      final location = switch (destination) {
        PagesDestination.calendar => '/',
        PagesDestination.studio => '/flows?mode=maatFlows',
        PagesDestination.library => '/nodes',
        PagesDestination.feed => '/profile/me?feed=1&commons=1',
        PagesDestination.planner => '/rhythm/today',
        PagesDestination.journal => '/journal',
        PagesDestination.inbox => '/inbox',
        PagesDestination.calendars => '/calendars',
      };
      await _present(() async {
        if (destination == PagesDestination.studio) {
          await openUtilityRoute<void>(context, location);
        } else {
          await openDetailRoute<void>(context, location);
        }
      });
      return;
    }
    await _present(() async {
      switch (destination) {
        case PagesDestination.calendar:
          break;
        case PagesDestination.feed:
          _controller?.didOpenFeed();
          final room = card.feedDisplay == PagesFeedDisplay.practice
              ? card.practice
              : null;
          await openDetailRoute<void>(
            context,
            room == null
                ? '/profile/me?feed=1&commons=1'
                : '/shared-practice/${Uri.encodeComponent(room.id)}',
          );
        case PagesDestination.library:
          await openDetailRoute<void>(
            context,
            card.libraryNodeId == null
                ? '/nodes'
                : '/nodes/${Uri.encodeComponent(card.libraryNodeId!)}',
          );
        case PagesDestination.planner:
          await openUtilityRoute<void>(context, '/rhythm/today');
        case PagesDestination.journal:
          await openUtilityRoute<void>(context, '/journal');
        case PagesDestination.inbox:
          final activity = card.inboxActivity;
          final share = card.inboxShare;
          if (activity != null) {
            await openUtilityRoute<void>(
              context,
              Uri(
                path: '/inbox',
                queryParameters: {'activity': inboxActivityIdentity(activity)},
              ).toString(),
            );
          } else if (share != null && share.kind == InboxShareKind.flow) {
            await openDetailRoute<void>(
              context,
              '/shared-flow/${Uri.encodeComponent(share.shareId)}',
              extra: {'share': share, 'fallbackLocation': '/pages'},
            );
          } else {
            await openUtilityRoute<void>(
              context,
              Uri(
                path: '/inbox',
                queryParameters: share == null
                    ? null
                    : {'update': share.shareId},
              ).toString(),
            );
          }
        case PagesDestination.calendars:
          await openUtilityRoute<void>(
            context,
            Uri(
              path: '/calendars',
              queryParameters: card.calendarId == null
                  ? null
                  : {'calendar': card.calendarId!},
            ).toString(),
          );
        case PagesDestination.studio:
          final event = card.event;
          final flow = card.flow;
          if (event != null &&
              flow != null &&
              event.flowId == flow.id &&
              (event.clientEventId.isNotEmpty || event.id.isNotEmpty)) {
            await openUtilityRoute<void>(
              context,
              Uri(
                path: '/flows',
                queryParameters: {
                  'flow': flow.id,
                  if (event.clientEventId.isNotEmpty)
                    'occurrence': event.clientEventId,
                  if (event.id.isNotEmpty) 'event': event.id,
                },
              ).toString(),
            );
          } else {
            await openUtilityRoute<void>(context, '/flows');
          }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleCreateIntent(GoRouterState.of(context).uri);
    final controller = _controller;
    if (controller == null) {
      return PagesLayout(
        cards: _guestContent.cards,
        onOpen: (card) => unawaited(_open(card)),
        profileHandle: 'ḥꜣw',
        profileActionLabel: 'Create account or sign in',
        onProfile: () => unawaited(
          _present(() async {
            if (await AccountAccess.require(context) && mounted)
              await openDetailRoute<void>(context, '/profile/me');
          }),
        ),
        onNewNote: () => unawaited(
          _present(() => CalendarPage.openQuickAddFromAnyContext(context)),
        ),
        searchRecords: _guestContent.searchRecords,
        onSearchResult: (record) => unawaited(
          _present(() => openDetailRoute<void>(context, record.location)),
        ),
        collectionState: PagesCollectionState(
          collection: _guestSelection,
          items: _guestSelection == PagesCollection.flows
              ? [
                  for (final flow in CalendarPage.publicMaatFlowCatalog())
                    PagesCollectionItem(
                      id: flow.key,
                      title: flow.title,
                      detail: 'Ma’at flow',
                      color: flow.color,
                    ),
                ]
              : const [],
        ),
        onCollectionItem: (item) => unawaited(
          _present(
            () => openUtilityRoute<void>(
              context,
              Uri(
                path: '/flows',
                queryParameters: {
                  'mode': 'maatTemplate',
                  'templateKey': item.id,
                },
              ).toString(),
            ),
          ),
        ),
        collectionEmptyMessage:
            'Create an account to keep your ${_guestSelection?.label.toLowerCase() ?? 'notes'} here.',
        onEmptyCollectionAction: () =>
            unawaited(AccountAccess.require(context)),
        onCollectionChanged: (selection) =>
            setState(() => _guestSelection = selection),
      );
    }
    final profile = ProfileRepo(
      Supabase.instance.client,
    ).getCachedProfileSync(controller.uid);
    return ValueListenableBuilder<PagesCollectionState>(
      valueListenable: _collections!,
      builder: (context, collection, _) => PagesLayout(
        collectionState: collection,
        onCollectionChanged: _collections!.select,
        onLoadMore: () => unawaited(_collections!.loadMore()),
        onRetry: () => unawaited(_collections!.retry()),
        onCollectionItem: (item) {
          if (item.event != null) {
            CalendarPage.openOwnedFiledItemFromAnyContext(context, item.event!);
          } else if (item.flowId != null) {
            unawaited(
              _present(() async {
                await openDetailRoute<void>(
                  context,
                  '/shared-flow/by-flow/${item.flowId!}',
                  extra: const {'fallbackLocation': '/pages'},
                );
              }),
            );
          }
        },
        cards: controller.cards,
        onOpen: (d) => unawaited(_open(d)),
        profileName: profile?.effectiveName ?? '',
        profileHandle: profile?.handle ?? '',
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
      ),
    );
  }
}
