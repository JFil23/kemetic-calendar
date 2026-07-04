// lib/features/inbox/inbox_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/navigation_fallback.dart';
import '../../core/push_intent_bus.dart';
import '../../data/share_models.dart';
import '../../data/shared_calendar_models.dart';
import '../../data/share_repo.dart';
import '../../data/shared_calendars_repo.dart';
import '../../data/user_events_repo.dart';
import '../../repositories/dm_conversation_repo.dart';
import '../../repositories/inbox_repo.dart';
import 'conversation_user.dart';
import 'dm_conversation_models.dart';
import '../../data/profile_repo.dart';
import '../../utils/detail_sanitizer.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:mobile/shared/kemetic_text.dart';
import '../../services/restoration_coordinator.dart';
import '../../services/session_resume_service.dart';
import '../../widgets/kemetic_app_bar_action.dart';
import '../../widgets/kemetic_heart_icon.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/responsive_content_rail.dart';
import '../calendar/calendar_page.dart' show CalendarPage;
import '../calendars/shared_calendars_sheet.dart';
import 'inbox_threading.dart';

void _logInboxImport(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

class InboxPage extends StatefulWidget {
  const InboxPage({super.key, this.initialSharedCalendarId});

  final String? initialSharedCalendarId;

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  static const String _resumeKind = 'inbox_conversation';
  static const String _invitesOverlayKind = 'inbox.invites';
  static const _mahoganyTop = Color(0xFF161109);
  static const _mahogany = Color(0xFF120F08);
  static const _mahoganyDeep = Color(0xFF0D0B07);
  static const _bg = _mahoganyDeep;
  static const _gold = KemeticGold.base;
  static const _goldGlow = Color(0xFFF5E8CB);
  static const _silverMid = Color(0xFF9E9A94);
  static const _silverLo = Color(0xFF6A6660);
  static const _coinDark = Color(0xFF352D12);
  static const _spine = Color(0x1AD4AF37);
  static const _serifFont = 'CormorantGaramond';
  static const List<String> _serifFallback = <String>[
    'Georgia',
    'Times New Roman',
    'serif',
  ];
  static const Color _summaryGoldLight = Color(0xFFF7E09A);
  static const Color _summaryGoldMid = Color(0xFFE8BE54);
  static const Color _summaryGoldBase = Color(0xFFCA9221);
  static const Color _summaryGoldDeep = Color(0xFF7A5310);
  static const Color _summaryGoldInk = Color(0xFF1C1204);
  static const double _summaryGlyphAvatarWidth = 66;
  static const double _summaryGlyphAvatarHeight = 66;
  static const String _inviteResponseGlyph = '𓂝';
  static const String _eventInviteGlyph = '𓆳';
  static const Gradient _summaryGoldGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[
      _summaryGoldBase,
      _summaryGoldLight,
      _summaryGoldMid,
      _summaryGoldDeep,
    ],
    stops: <double>[0.0, 0.42, 0.74, 1.0],
  );
  static const List<String> _meduFontFallback =
      KemeticTypography.meduNeterFallback;

  late final InboxRepo _inboxRepo;
  late final DmConversationRepo _dmConversationRepo;
  late final ShareRepo _shareRepo;
  late final SharedCalendarsRepo _sharedCalendarsRepo;
  StreamSubscription<List<InboxShareItem>>? _inboxItemsSub;
  StreamSubscription<List<DmConversationSummary>>? _dmConversationsSub;
  StreamSubscription<InboxUnreadState>? _unreadStateSub;
  StreamSubscription<List<SharedCalendarSentInvite>>? _sentCalendarInvitesSub;
  StreamSubscription<List<SharedCalendarInvite>>? _incomingCalendarInvitesSub;
  Map<String, List<InboxShareItem>> _latestThreads = const {};
  List<InboxShareItem> _latestEventInvites = const [];
  List<InboxShareItem> _latestCalendarNotifications = const [];
  List<SharedCalendarSentInvite> _latestSentCalendarInvites = const [];
  List<SharedCalendarInvite> _latestIncomingCalendarInvites = const [];
  List<DmConversationSummary> _latestDmConversations = const [];
  List<_UnifiedInboxItem> _unified = const [];
  final Set<String> _optimisticReadShareIds = <String>{};
  bool _loading = true;
  InboxActivityItem? _latestFollow;
  InboxActivityItem? _latestEngagement;
  List<InboxActivityItem> _activity = const [];
  InboxUnreadState _unreadState = const InboxUnreadState();
  bool _resumeConversationChecked = false;
  bool _invitesSheetRestoreChecked = false;
  bool _invitesSheetOpenOrOpening = false;
  String? _openedInitialSharedCalendarId;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _shareRepo = ShareRepo(client);
    _sharedCalendarsRepo = SharedCalendarsRepo(client);
    _unreadState = _shareRepo.currentUnreadState;
    _inboxRepo = InboxRepo(client);
    _dmConversationRepo = DmConversationRepo(client);
    unawaited(_restoreCachedUnified());
    _inboxItemsSub = _inboxRepo.watchInbox().listen((items) {
      _applyInboxItems(items);
      if (mounted) {
        setState(() {
          _unified = _buildUnifiedItems();
          _loading = false;
        });
      }
    });
    _dmConversationsSub = _dmConversationRepo
        .watchConversationSummaries()
        .listen((conversations) {
          _latestDmConversations = conversations;
          if (mounted) {
            setState(() {
              _unified = _buildUnifiedItems();
              _loading = false;
            });
          }
        });
    _unreadStateSub = _shareRepo.watchUnreadState().listen((state) {
      if (!mounted) {
        _unreadState = state;
        return;
      }
      setState(() => _unreadState = state);
    });
    _sentCalendarInvitesSub = _sharedCalendarsRepo
        .watchSentPendingInvites()
        .listen((invites) {
          _latestSentCalendarInvites = invites;
          if (mounted) {
            setState(() {
              _unified = _buildUnifiedItems();
              _loading = false;
            });
          }
        });
    _incomingCalendarInvitesSub = _sharedCalendarsRepo
        .watchPendingInvites()
        .listen((invites) {
          _latestIncomingCalendarInvites = invites;
          if (mounted) {
            setState(() {
              _unified = _buildUnifiedItems();
              _loading = false;
            });
          }
        });
    _refreshUnified(showLoading: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_resumeConversationIfNeeded());
      unawaited(_restoreInvitesSheetIfNeeded());
      unawaited(_openInitialSharedCalendarIfNeeded());
    });
  }

  @override
  void didUpdateWidget(covariant InboxPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSharedCalendarId != widget.initialSharedCalendarId) {
      final calendarId = widget.initialSharedCalendarId?.trim();
      if (calendarId == null || calendarId.isEmpty) {
        _openedInitialSharedCalendarId = null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_openInitialSharedCalendarIfNeeded());
      });
    }
  }

  Future<void> _handleRefresh() async {
    await _refreshUnified();
  }

  Future<void> _refreshUnified({bool showLoading = true}) async {
    if (showLoading && _unified.isEmpty && mounted) {
      setState(() => _loading = true);
    }
    final activity = await _shareRepo.getRecentActivity(limit: 50);
    _applyActivity(activity);
    try {
      _latestDmConversations = await _dmConversationRepo
          .getConversationSummaries();
    } catch (e) {
      _logInboxImport('[InboxPage] Failed to refresh DM conversations: $e');
    }

    if (!mounted) return;
    setState(() {
      _unified = _buildUnifiedItems();
      _loading = false;
    });
  }

  Future<void> _restoreCachedUnified() async {
    final results = await Future.wait<dynamic>([
      _shareRepo.restoreCachedInboxItems(),
      _shareRepo.restoreCachedRecentActivity(limit: 50),
      _sharedCalendarsRepo.restoreCachedSentPendingInvites(),
      _sharedCalendarsRepo.restoreCachedPendingInvites(),
    ]);
    if (!mounted) return;

    final inboxItems = results[0] as List<InboxShareItem>?;
    final activity = results[1] as List<InboxActivityItem>?;
    final sentInvites = results[2] as List<SharedCalendarSentInvite>?;
    final incomingInvites = results[3] as List<SharedCalendarInvite>?;
    final hasCachedData =
        inboxItems != null ||
        activity != null ||
        sentInvites != null ||
        incomingInvites != null;
    if (!hasCachedData) return;

    if (inboxItems != null) {
      _applyInboxItems(inboxItems);
    }
    if (activity != null) {
      _applyActivity(activity);
    }
    if (sentInvites != null) {
      _latestSentCalendarInvites = sentInvites;
    }
    if (incomingInvites != null) {
      _latestIncomingCalendarInvites = incomingInvites;
    }

    setState(() {
      _unified = _buildUnifiedItems();
      _loading = false;
    });
  }

  void _applyInboxItems(List<InboxShareItem> items) {
    final currentUserId = _inboxRepo.currentUserId;
    _latestThreads = currentUserId == null
        ? const <String, List<InboxShareItem>>{}
        : directMessageConversationThreadsFromItems(items, currentUserId);
    _reconcileOptimisticReadState();

    _latestEventInvites = currentUserId == null
        ? const <InboxShareItem>[]
        : eventInviteItemsForInvitesSheet(items, currentUserId);
    _latestCalendarNotifications = currentUserId == null
        ? const <InboxShareItem>[]
        : (items
              .where(
                (item) =>
                    item.isCalendar &&
                    !item.isDeleted &&
                    item.recipientId == currentUserId,
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
    _markOpenedInitialCalendarNotificationsViewedIfNeeded();
  }

  void _applyActivity(List<InboxActivityItem> activity) {
    InboxActivityItem? firstMatch(bool Function(InboxActivityItem) test) {
      for (final item in activity) {
        if (test(item)) return item;
      }
      return null;
    }

    _activity = activity;
    _latestFollow = firstMatch((a) => a.type == InboxActivityType.follow);
    _latestEngagement = firstMatch(
      (a) =>
          a.type == InboxActivityType.like ||
          a.type == InboxActivityType.comment,
    );
  }

  @override
  void dispose() {
    _inboxItemsSub?.cancel();
    _dmConversationsSub?.cancel();
    _unreadStateSub?.cancel();
    _sentCalendarInvitesSub?.cancel();
    _incomingCalendarInvitesSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _mahoganyDeep,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 82,
        titleSpacing: 0,
        flexibleSpace: const _InboxMahoganySurface(showCornice: true),
        title: Padding(
          padding: const EdgeInsets.fromLTRB(26, 18, 26, 4),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Close inbox',
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: KemeticGold.icon(Icons.close, size: 27),
                    onPressed: () => popOrGo(context, '/'),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Inbox',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _goldGlow,
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    letterSpacing: 0.5,
                    fontFamily: _serifFont,
                    fontFamilyFallback: _serifFallback,
                    shadows: [
                      Shadow(
                        color: _goldGlow.withValues(alpha: 0.18),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: KemeticAppBarAction(
                    tooltip: 'Search people',
                    icon: const KemeticAppBarSearchIcon(),
                    width: 48,
                    iconBoxSize: 42,
                    onPressed: _openUserSearch,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _InboxMahoganySurface(
        child: Stack(
          children: [
            Positioned.fill(
              child: ResponsiveContentRail(maxWidth: 760, child: _buildBody()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUserSearch() async {
    await openDetailRoute<void>(
      context,
      '/profile-search'
      '?select=conversation'
      '&title=${Uri.encodeComponent('New Message')}'
      '&hint=${Uri.encodeComponent('Search people to message')}'
      '&fallback=${Uri.encodeComponent('/inbox')}',
    );
    if (!mounted) return;
    unawaited(_refreshUnified(showLoading: false));
  }

  Future<void> _resumeConversationIfNeeded() async {
    if (!mounted || _resumeConversationChecked) return;
    _resumeConversationChecked = true;
    if (RestorationCoordinator.instance.restoreReason ==
        RestorationRestoreReason.userNavigation) {
      return;
    }
    if (!RestorationCoordinator.instance.claimRestoreSurface(_resumeKind)) {
      return;
    }

    final entry = await SessionResumeService.consumeResumeEntry(
      kind: _resumeKind,
      baseRoute: '/inbox',
    );
    if (!mounted || entry == null) return;

    final payload = entry.payload;
    final otherUserId = payload['otherUserId'] as String?;
    if (otherUserId == null || otherUserId.isEmpty) return;

    _openConversation(
      otherUserId: otherUserId,
      otherProfile: ConversationUser(
        id: otherUserId,
        displayName: payload['displayName'] as String?,
        handle: payload['handle'] as String?,
        avatarUrl: payload['avatarUrl'] as String?,
        avatarGlyphIds:
            (payload['avatarGlyphIds'] as List<dynamic>? ?? const [])
                .map((item) => '$item')
                .toList(growable: false),
      ),
      initialDraftText: payload['draftText'] as String?,
    );
  }

  Future<void> _openInitialSharedCalendarIfNeeded() async {
    final calendarId = widget.initialSharedCalendarId?.trim();
    if (!mounted || calendarId == null || calendarId.isEmpty) return;
    if (_openedInitialSharedCalendarId == calendarId) return;

    _openedInitialSharedCalendarId = calendarId;
    _markOpenedInitialCalendarNotificationsViewedIfNeeded();
    await _openSharedCalendarById(calendarId);
    if (!mounted) return;
    if (!RestorationCoordinator
            .instance
            .shouldPreserveOverlayForLifecycleClose &&
        widget.initialSharedCalendarId?.trim() == calendarId &&
        _sameRouteLocation(
          _currentRouteLocation(),
          sharedCalendarInboxRouteLocation(calendarId),
        )) {
      _openedInitialSharedCalendarId = null;
      context.go('/inbox');
    }
  }

  static bool _sameRouteLocation(String a, String b) {
    final aUri = Uri.tryParse(a.trim());
    final bUri = Uri.tryParse(b.trim());
    if (aUri == null || bUri == null) return a.trim() == b.trim();
    return aUri.path == bUri.path && aUri.query == bUri.query;
  }

  String _currentRouteLocation() {
    try {
      final location = GoRouterState.of(context).uri.toString().trim();
      if (location.isNotEmpty) return location;
    } catch (_) {
      // Tests can mount Inbox without a GoRouter state.
    }
    return '/inbox';
  }

  static Map<String, dynamic>? _restorableInvitesOverlayFromStack(
    List<Map<String, dynamic>> stack,
  ) {
    for (final entry in stack.reversed) {
      if ((entry['kind'] as String?)?.trim() == _invitesOverlayKind) {
        final parentRoute = (entry['parentRoute'] as String?)?.trim();
        if (parentRoute == null || parentRoute.isEmpty) continue;
        final parentUri = Uri.tryParse(parentRoute);
        if (parentUri == null || parentUri.path != '/inbox') continue;
        return Map<String, dynamic>.from(entry);
      }
    }
    return null;
  }

  static String _invitesOverlayRestoreSurfaceKey(Map<String, dynamic> overlay) {
    final parentRoute = (overlay['parentRoute'] as String?)?.trim() ?? '/inbox';
    return '${RestorationCoordinator.calendarOverlayStackSurface}|'
        '$_invitesOverlayKind|$parentRoute|${overlay['updatedAtMs']}';
  }

  Future<void> _saveInvitesSheetRestorationState({
    required String parentRoute,
  }) async {
    final normalizedParentRoute = parentRoute.trim().isEmpty
        ? '/inbox'
        : parentRoute.trim();
    await RestorationCoordinator.instance.recordOverlayStackPageState(
      <Map<String, dynamic>>[
        <String, dynamic>{
          'kind': _invitesOverlayKind,
          'parentRoute': normalizedParentRoute,
          'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        },
      ],
      reason: 'inbox_invites_overlay',
    );
    unawaited(RestorationCoordinator.instance.flush());
  }

  Future<void> _clearInvitesSheetRestorationState() async {
    final stack = await RestorationCoordinator.instance.readOverlayStack();
    final next = stack
        .where((entry) => entry['kind'] != _invitesOverlayKind)
        .toList(growable: false);
    await RestorationCoordinator.instance.saveOverlayStack(next);
  }

  Future<void> _restoreInvitesSheetIfNeeded() async {
    if (!mounted || _invitesSheetRestoreChecked) return;
    _invitesSheetRestoreChecked = true;
    final snapshot = await RestorationCoordinator.instance.readBestSnapshot(
      includeRemote: Supabase.instance.client.auth.currentSession != null,
    );
    final overlay = _restorableInvitesOverlayFromStack(
      snapshot.snapshot?.overlayStack ?? const <Map<String, dynamic>>[],
    );
    if (!mounted || overlay == null) return;

    final parentRoute = (overlay['parentRoute'] as String?)?.trim();
    if (parentRoute == null ||
        parentRoute.isEmpty ||
        !_sameRouteLocation(_currentRouteLocation(), parentRoute)) {
      return;
    }

    final restoreKey = _invitesOverlayRestoreSurfaceKey(overlay);
    if (!RestorationCoordinator.instance.claimRestoreSurface(restoreKey)) {
      return;
    }
    await _openCalendarInboxSheet(parentRouteOverride: parentRoute);
  }

  void _markOpenedInitialCalendarNotificationsViewedIfNeeded() {
    final calendarId = _openedInitialSharedCalendarId;
    if (calendarId == null || calendarId.isEmpty) return;
    final matching = _latestCalendarNotifications
        .where(
          (item) =>
              item.isCalendarEventNotification && item.calendarId == calendarId,
        )
        .toList(growable: false);
    if (matching.isEmpty) return;
    unawaited(_markItemsViewed(matching));
  }

  void _openConversation({
    required String otherUserId,
    required ConversationUser otherProfile,
    String? initialDraftText,
  }) {
    unawaited(
      openDetailRoute<void>(
        context,
        '/inbox/conversation/${Uri.encodeComponent(otherUserId)}',
        extra: <String, Object?>{
          'profile': otherProfile,
          if (initialDraftText != null) 'initialDraftText': initialDraftText,
        },
      ),
    );
  }

  Future<void> _openSharedCalendarById(String calendarId) async {
    final normalized = calendarId.trim();
    if (normalized.isEmpty || !mounted) return;
    await SharedCalendarsSheet.show(
      context,
      repo: _sharedCalendarsRepo,
      initialExpandedCalendarIds: <String>[normalized],
      onEventTapRequested:
          (calendar, filedEvent, {calendarEvents = const []}) =>
              CalendarPage.openFiledCalendarEventFromAnyContext(
                context,
                calendar: calendar,
                filedEvent: filedEvent,
                calendarEvents: calendarEvents,
              ),
    );
  }

  Widget _buildBody() {
    const listBottomPadding = 16.0;
    final listChildren = <Widget>[
      _buildSectionLabel('Activity'),
      for (var i = 0; i < _summaryTileCount; i++) _buildSummaryTile(i),
      _buildSectionLabel('Messages', topMargin: 30),
      for (final item in _unified)
        if (item.kind == _UnifiedKind.message)
          _buildConversationBar(
            context: context,
            otherUserId: item.otherUserId!,
            otherProfile: item.otherProfile!,
            lastItem: item.items!.last,
            hasUnread: item.hasUnread ?? false,
            items: item.items!,
          )
        else if (item.kind == _UnifiedKind.calendarNotification)
          _buildSharedCalendarThreadRow(item.calendarThread!)
        else if (item.kind == _UnifiedKind.dmConversation)
          _buildDmConversationBar(item.dmConversation!),
    ];

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: _gold,
      child: _loading
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                0,
                30,
                0,
                130 + listBottomPadding,
              ),
              children: const [
                SizedBox(height: 220),
                Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_gold),
                  ),
                ),
              ],
            )
          : (_unified.isEmpty && !_hasSummaries
                ? _buildEmptyState()
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      0,
                      30,
                      0,
                      130 + listBottomPadding,
                    ),
                    children: listChildren,
                  )),
    );
  }

  Widget _buildSectionLabel(String label, {double topMargin = 6}) {
    Widget rule({required bool mirrored}) {
      return Container(
        width: 48,
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: mirrored
                ? const [_spine, Colors.transparent]
                : const [Colors.transparent, _spine],
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(top: topMargin, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          rule(mirrored: true),
          const SizedBox(width: 10),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _silverLo,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 3,
              fontFamily: _serifFont,
              fontFamilyFallback: _serifFallback,
            ),
          ),
          const SizedBox(width: 10),
          rule(mirrored: false),
        ],
      ),
    );
  }

  Widget _buildInboxRow({
    required Widget leading,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback? onTap,
    bool activity = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        highlightColor: _gold.withValues(alpha: 0.045),
        splashColor: _gold.withValues(alpha: 0.045),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
          child: Row(
            children: [
              SizedBox(width: 84, child: Center(child: leading)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: activity
                              ? const Color(0xFFFBF3DF)
                              : Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w600,
                          height: 1.12,
                          letterSpacing: activity ? 1.2 : 1,
                          fontFamily: _serifFont,
                          fontFamilyFallback: _serifFallback,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _silverMid,
                            fontSize: 17.5,
                            height: 1.3,
                            fontFamily: _serifFont,
                            fontFamilyFallback: _serifFallback,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(width: 64, child: Center(child: trailing)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChevronTrail(bool showUnread) {
    return SizedBox(
      width: 48,
      height: 66,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            '›',
            style: TextStyle(
              color: _silverLo,
              fontSize: 26,
              height: 1,
              fontFamily: _serifFont,
              fontFamilyFallback: _serifFallback,
            ),
          ),
          if (showUnread)
            const Positioned(right: 6, top: 20, child: _InboxUnreadDot()),
        ],
      ),
    );
  }

  ConversationUser _resolveOtherProfile(
    InboxShareItem item,
    String currentUserId,
  ) {
    final isMine = item.senderId == currentUserId;

    if (!isMine) {
      // Item was sent TO me, so sender is the "other" person
      return ConversationUser(
        id: item.senderId,
        displayName: item.senderName,
        handle: item.senderHandle,
        avatarUrl: item.senderAvatar,
      );
    } else {
      // Item was sent BY me, so recipient is the "other" person
      // TODO: Once backend adds recipient profile fields, use those
      return ConversationUser(
        id: item.recipientId,
        displayName: item.recipientDisplayName ?? 'User',
        handle: item.recipientHandle ?? 'user',
        avatarUrl: item.recipientAvatarUrl,
      );
    }
  }

  List<_UnifiedInboxItem> _buildUnifiedItems() {
    final currentUserId = _inboxRepo.currentUserId;
    if (currentUserId == null) return const [];

    final messageItems = <_UnifiedInboxItem>[];
    _latestThreads.forEach((otherId, items) {
      if (items.isEmpty) return;
      final last = items.last;
      final otherProfile = _resolveOtherProfile(last, currentUserId);
      final hasUnread = items.any(
        (item) =>
            item.recipientId == currentUserId &&
            item.isUnread &&
            !_optimisticReadShareIds.contains(item.shareId),
      );
      messageItems.add(
        _UnifiedInboxItem.message(
          createdAt: last.createdAt,
          otherUserId: otherId,
          otherProfile: otherProfile,
          items: items,
          hasUnread: hasUnread,
        ),
      );
    });

    final calendarItems =
        sharedCalendarInboxThreadsFromNotifications(
              _latestCalendarNotifications,
              optimisticReadShareIds: _optimisticReadShareIds,
            )
            .map(
              (thread) => _UnifiedInboxItem.calendarNotification(
                createdAt: thread.createdAt,
                calendarThread: thread,
              ),
            )
            .toList(growable: false);

    final dmConversationItems = _latestDmConversations
        .where((summary) => summary.archivedAt == null)
        .map(
          (summary) => _UnifiedInboxItem.dmConversation(
            createdAt: summary.lastCreatedAt ?? summary.updatedAt,
            dmConversation: summary,
          ),
        )
        .toList(growable: false);

    return [...calendarItems, ...messageItems, ...dmConversationItems]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void _reconcileOptimisticReadState() {
    final currentUserId = _inboxRepo.currentUserId;
    if (currentUserId == null || _optimisticReadShareIds.isEmpty) return;

    final stillPending = <String>{};
    void collectUnread(Iterable<InboxShareItem> items) {
      for (final item in items) {
        final isIncoming = item.recipientId == currentUserId;
        if (isIncoming && item.isUnread) {
          stillPending.add(item.shareId);
        }
      }
    }

    for (final thread in _latestThreads.values) {
      collectUnread(thread);
    }
    collectUnread(_latestEventInvites);
    collectUnread(_latestCalendarNotifications);
    _optimisticReadShareIds.retainAll(stillPending);
  }

  Future<void> _markItemsViewed(Iterable<InboxShareItem> items) async {
    final currentUserId = _inboxRepo.currentUserId;
    if (currentUserId == null) return;

    final unreadItems = items.where((item) {
      final isIncoming = item.recipientId == currentUserId;
      return isIncoming &&
          item.viewedAt == null &&
          !_optimisticReadShareIds.contains(item.shareId);
    }).toList();
    if (unreadItems.isEmpty) return;

    final optimisticIds = unreadItems.map((item) => item.shareId).toSet();
    if (mounted) {
      setState(() {
        _optimisticReadShareIds.addAll(optimisticIds);
        _unified = _buildUnifiedItems();
      });
    } else {
      _optimisticReadShareIds.addAll(optimisticIds);
    }

    final results = await Future.wait(
      unreadItems.map((item) => _shareRepo.markInboxItemViewed(item)),
    );

    final failedIds = <String>{};
    for (var i = 0; i < unreadItems.length; i++) {
      if (!results[i]) {
        failedIds.add(unreadItems[i].shareId);
      }
    }

    if (failedIds.isEmpty || !mounted) return;
    setState(() {
      _optimisticReadShareIds.removeAll(failedIds);
      _unified = _buildUnifiedItems();
    });
  }

  bool _isUnreadInboxItem(InboxShareItem item) {
    return item.isUnread && !_optimisticReadShareIds.contains(item.shareId);
  }

  Widget _buildConversationBar({
    required BuildContext context,
    required String otherUserId,
    required ConversationUser otherProfile,
    required InboxShareItem lastItem,
    required bool hasUnread,
    required List<InboxShareItem> items,
  }) {
    return Dismissible(
      key: Key('conversation_$otherUserId'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF0D0D0F),
                title: const Text(
                  'Delete Conversation?',
                  style: TextStyle(color: Colors.white),
                ),
                content: Text(
                  'This will remove all shared flows/messages with '
                  '${otherProfile.displayName ?? otherProfile.handle ?? 'this user'} '
                  'from your inbox. It will not affect them.',
                  style: const TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) async {
        final shareRepo = ShareRepo(Supabase.instance.client);
        final currentUserId = _inboxRepo.currentUserId;
        if (currentUserId == null) return;

        // Get the latest snapshot of messages in this conversation
        final items = await _inboxRepo.watchConversationWith(otherUserId).first;

        for (final item in items) {
          final isMine = item.senderId == currentUserId;
          final isFlow = item.isFlow;
          final shareId = item.shareId;

          bool ok;
          if (isMine) {
            ok = await shareRepo.unsendShare(shareId, isFlow: isFlow);
          } else {
            ok = await shareRepo.deleteInboxItem(shareId, isFlow: isFlow);
          }

          if (!ok && kDebugMode) {
            debugPrint(
              '[InboxPage] Failed to ${isMine ? 'unsend' : 'delete'} shareId=$shareId',
            );
          }
        }
      },
      child: _buildInboxRow(
        leading: _buildMessageAvatar(otherProfile),
        title: otherProfile.displayName ?? otherProfile.handle ?? 'User',
        subtitle: lastItem.isTextMessage
            ? (lastItem.messageText ?? 'Message')
            : _conversationPreviewText(lastItem),
        trailing: _buildProfileTrail(
          showUnread: hasUnread,
          onPressed: () => _openProfile(otherUserId),
        ),
        onTap: () {
          // Mark unread incoming items as viewed when opening the thread
          _markConversationRead(items);

          _openConversation(
            otherUserId: otherUserId,
            otherProfile: otherProfile,
          );
        },
      ),
    );
  }

  Widget _buildDmConversationBar(DmConversationSummary summary) {
    final currentUserId = _inboxRepo.currentUserId;
    final preview = summary.previewFor(currentUserId);
    final lastAt = summary.lastCreatedAt ?? summary.updatedAt;
    final subtitle = lastAt.millisecondsSinceEpoch > 0
        ? '$preview • ${_formatInboxTimestamp(lastAt)}'
        : preview;

    return _buildInboxRow(
      leading: _buildDmConversationAvatar(summary, currentUserId),
      title: summary.titleFor(currentUserId),
      subtitle: subtitle,
      trailing: _buildChevronTrail(summary.hasUnread),
      onTap: () {
        unawaited(_dmConversationRepo.markRead(summary.id));
        unawaited(
          openDetailRoute<void>(
            context,
            '/inbox/dm/${Uri.encodeComponent(summary.id)}',
          ),
        );
      },
    );
  }

  Widget _buildDmConversationAvatar(
    DmConversationSummary summary,
    String? currentUserId,
  ) {
    final users = summary.members
        .map((member) => member.user)
        .where((user) => user.id != currentUserId)
        .toList(growable: false);
    if (users.length == 1) return _buildMessageAvatar(users.single);

    final visibleUsers = users.take(3).toList(growable: false);
    if (visibleUsers.isEmpty) {
      return _buildSummaryGlyphAvatar(glyph: '𓀀𓁐', fontSize: 20);
    }

    const avatarSize = 38.0;
    const positions = <Offset>[Offset(0, 3), Offset(26, 3), Offset(13, 25)];

    return SizedBox(
      width: 66,
      height: 66,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visibleUsers.length; i++)
            Positioned(
              left: positions[i].dx,
              top: positions[i].dy,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _mahoganyDeep,
                  border: Border.all(color: _gold.withValues(alpha: 0.25)),
                ),
                child: ClipOval(
                  child: ProfileAvatar(
                    radius: avatarSize / 2,
                    displayName:
                        visibleUsers[i].displayName ??
                        visibleUsers[i].handle ??
                        'User',
                    avatarUrl: visibleUsers[i].avatarUrl,
                    avatarGlyphIds: visibleUsers[i].avatarGlyphIds,
                    backgroundColor: Colors.transparent,
                    foregroundColor: _gold,
                    maxInitialCharacters: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageAvatar(ConversationUser profile) {
    final displayName = profile.displayName ?? profile.handle ?? 'User';

    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.2, -0.36),
          colors: [Color(0xFF48400F), _coinDark],
          stops: [0.0, 0.7],
        ),
        border: Border.all(color: _gold.withValues(alpha: 0.22)),
      ),
      child: ClipOval(
        child: ProfileAvatar(
          radius: 33,
          displayName: displayName,
          avatarUrl: profile.avatarUrl,
          avatarGlyphIds: profile.avatarGlyphIds,
          backgroundColor: Colors.transparent,
          foregroundColor: _gold,
          maxInitialCharacters: 1,
        ),
      ),
    );
  }

  Widget _buildProfileTrail({
    required bool showUnread,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 48,
      height: 66,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            tooltip: 'View profile',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            icon: const Text(
              '𓁷',
              style: TextStyle(
                color: _gold,
                fontSize: 23,
                height: 1,
                fontFamily: 'Noto Sans Egyptian Hieroglyphs',
                fontFamilyFallback: _meduFontFallback,
              ),
            ),
            onPressed: onPressed,
          ),
          if (showUnread)
            const Positioned(
              right: 3,
              top: 20,
              child: _InboxUnreadDot(color: _gold, size: 8),
            ),
        ],
      ),
    );
  }

  Future<void> _markConversationRead(List<InboxShareItem> items) async {
    await _markItemsViewed(items);
  }

  Widget _buildInvitesSheetGlyphIcon({
    required String glyph,
    required String semanticLabel,
    required Color color,
    required Color backgroundColor,
    double size = 44,
    double fontSize = 25,
    Border? border,
    BorderRadius? borderRadius,
    Offset glyphOffset = Offset.zero,
    bool circular = false,
  }) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: circular ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circular
                ? null
                : (borderRadius ?? BorderRadius.circular(14)),
            border: border,
          ),
          child: Transform.translate(
            offset: glyphOffset,
            child: Text(
              glyph,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                height: 1,
                fontWeight: FontWeight.w700,
                fontFamily: 'Noto Sans Egyptian Hieroglyphs',
                fontFamilyFallback: _meduFontFallback,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventInviteRow(
    InboxShareItem invite, {
    BuildContext? closeContext,
  }) {
    final payload = invite.eventPayload;
    final senderName = invite.senderName?.trim().isNotEmpty == true
        ? invite.senderName!.trim()
        : (invite.senderHandle?.trim().isNotEmpty == true
              ? '@${invite.senderHandle!.trim()}'
              : 'Someone');
    final whenText = _eventInviteWhenText(invite);
    final statusLabel = _eventInviteStatusLabel(invite);
    final statusColor = _eventInviteStatusColor(invite);
    final isUnread = _isUnreadInboxItem(invite);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: _buildInvitesSheetGlyphIcon(
        glyph: _eventInviteGlyph,
        semanticLabel: 'Event RSVP',
        color: statusColor,
        backgroundColor: statusColor.withValues(alpha: 0.14),
        size: 40,
        fontSize: 24,
        circular: true,
      ),
      title: Text(
        payload?.title ?? invite.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        whenText.isEmpty ? 'From $senderName' : 'From $senderName • $whenText',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 14,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (isUnread) ...[
            const SizedBox(height: 8),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: _gold,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
      onTap: () async {
        if (closeContext != null) {
          Navigator.of(closeContext).pop();
        }
        await _openEventInvite(invite);
      },
    );
  }

  Widget _buildSharedCalendarThreadRow(SharedCalendarInboxThread thread) {
    final accent = thread.calendarColorValue != null
        ? Color(thread.calendarColorValue!)
        : _gold;
    final subtitle =
        '${thread.preview} • ${_formatInboxTimestamp(thread.createdAt)}';

    return _buildInboxRow(
      leading: _buildCalendarThreadAvatar(accent),
      title: thread.title,
      subtitle: subtitle,
      trailing: _buildCalendarThreadTrail(thread, accent),
      onTap: () => _openSharedCalendarThread(thread),
    );
  }

  Widget _buildCalendarThreadAvatar(Color accent) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.14),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Center(
        child: Text(
          MeduNeterGlyphs.calendars,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: accent,
            fontSize: 26,
            height: 1,
            fontWeight: FontWeight.w700,
            fontFamily: 'GentiumPlus',
            fontFamilyFallback: _meduFontFallback,
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarThreadTrail(
    SharedCalendarInboxThread thread,
    Color accent,
  ) {
    return SizedBox(
      width: 48,
      height: 66,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              thread.unreadCount > 1 ? '${thread.unreadCount}' : 'Calendar',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: _serifFont,
                fontFamilyFallback: _serifFallback,
              ),
            ),
          ),
          if (thread.hasUnread)
            const Positioned(
              right: 2,
              top: 20,
              child: _InboxUnreadDot(color: _gold, size: 8),
            ),
        ],
      ),
    );
  }

  String _conversationPreviewText(InboxShareItem item) {
    if (!item.isEvent) return item.title;
    final status = item.responseStatus;
    if (status == EventInviteResponseStatus.noResponse) {
      return item.title;
    }
    return '${item.title} • ${status.label}';
  }

  String _eventInviteWhenText(InboxShareItem invite) {
    final payload = invite.eventPayload;
    final when = payload?.startsAt ?? invite.eventDate;
    if (when == null) return '';

    final local = when.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    if (payload?.allDay ?? false) {
      return '$month/$day • All day';
    }

    final minute = local.minute.toString().padLeft(2, '0');
    final hour24 = local.hour;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    return '$month/$day • $hour12:$minute $period';
  }

  String _eventInviteStatusLabel(InboxShareItem invite) {
    return eventInviteStatusLabel(invite);
  }

  String _formatInboxTimestamp(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (!diff.isNegative && diff.inMinutes < 1) return 'Now';
    if (!diff.isNegative && diff.inHours < 1) return '${diff.inMinutes}m';
    if (!diff.isNegative && diff.inDays < 1) return '${diff.inHours}h';

    final sameYear = local.year == now.year;
    final sameWeek = !diff.isNegative && diff.inDays < 7;
    if (sameWeek) {
      const weekdays = <String>[
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ];
      return weekdays[local.weekday - 1];
    }
    if (sameYear) return '${local.month}/${local.day}';
    return '${local.month}/${local.day}/${local.year}';
  }

  Color _eventInviteStatusColor(InboxShareItem invite) {
    switch (invite.responseStatus) {
      case EventInviteResponseStatus.accepted:
        return Colors.greenAccent;
      case EventInviteResponseStatus.declined:
        return Colors.redAccent;
      case EventInviteResponseStatus.maybe:
        return Colors.orangeAccent;
      case EventInviteResponseStatus.noResponse:
        return Colors.white70;
    }
  }

  void _openProfile(String userId) {
    unawaited(
      openDetailRoute<void>(context, '/profile/${Uri.encodeComponent(userId)}'),
    );
  }

  Future<void> _openActivity(InboxActivityItem activity) async {
    if (activity.type == InboxActivityType.follow) {
      final actorId = activity.actorId;
      if (actorId != null) {
        _openProfile(actorId);
      }
      return;
    }

    final flowPostId = activity.flowPostId;
    if (flowPostId == null) {
      _showActivityOpenError();
      return;
    }

    final post = await ProfileRepo(
      Supabase.instance.client,
    ).getFlowPostById(flowPostId);
    if (!mounted) return;
    if (post == null) {
      _showActivityOpenError();
      return;
    }

    unawaited(
      openDetailRoute<void>(
        context,
        '/flow-post/${Uri.encodeComponent(flowPostId)}'
        '${activity.type == InboxActivityType.comment ? '?comments=1' : ''}',
        extra: post,
      ),
    );
  }

  void _showActivityOpenError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open this movement notification.'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Widget _buildActivityRow(
    InboxActivityItem activity, {
    BuildContext? closeContext,
  }) {
    Widget leadingIcon;
    Color color;
    String title;
    String subtitle;

    switch (activity.type) {
      case InboxActivityType.like:
        color = Colors.redAccent;
        leadingIcon = const KemeticHeartIcon(size: 24, color: Colors.redAccent);
        title =
            '${activity.actorName ?? activity.actorHandle ?? 'Someone'} liked your flow';
        subtitle = activity.flowName ?? '';
        break;
      case InboxActivityType.comment:
        color = KemeticGold.base;
        leadingIcon = const Icon(
          Icons.chat_bubble_outline,
          color: KemeticGold.base,
        );
        title =
            '${activity.actorName ?? activity.actorHandle ?? 'Someone'} commented on your flow';
        subtitle = activity.commentPreview ?? activity.flowName ?? '';
        break;
      case InboxActivityType.follow:
        color = Colors.blueAccent;
        leadingIcon = const Icon(Icons.person_add, color: Colors.blueAccent);
        title =
            '${activity.actorName ?? activity.actorHandle ?? 'Someone'} started following you';
        subtitle = '';
        break;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: leadingIcon,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            )
          : null,
      onTap: () async {
        if (closeContext != null) {
          Navigator.of(closeContext).pop();
        }
        await _openActivity(activity);
      },
    );
  }

  bool get _hasSummaries => true;
  bool get _hasCalendarSummary => true;
  int get _summaryTileCount => 3;

  DateTime _latestTimestampForActivity(Iterable<InboxActivityItem> items) {
    return items
        .map((item) => item.createdAt.toUtc())
        .reduce((latest, next) => next.isAfter(latest) ? next : latest);
  }

  List<InboxShareItem> get _calendarSectionNotifications =>
      _latestCalendarNotifications
          .where(
            (item) =>
                item.isCalendarInviteNotification ||
                item.isCalendarInviteResponseNotification,
          )
          .toList(growable: false);

  List<SharedCalendarInvite> get _incomingCalendarInvitesWithoutNotification {
    final notifiedCalendarIds = _calendarSectionNotifications
        .where((item) => item.isCalendarInviteNotification)
        .map((item) => item.payloadId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    return _latestIncomingCalendarInvites
        .where((invite) => !notifiedCalendarIds.contains(invite.calendarId))
        .toList(growable: false);
  }

  bool get _hasUnreadCalendar =>
      _calendarSectionNotifications.any(_isUnreadInboxItem) ||
      _latestEventInvites.any(_isUnreadInboxItem) ||
      _incomingCalendarInvitesWithoutNotification.isNotEmpty;

  Widget _buildSummaryTile(int index) {
    final tiles = <Widget>[
      _buildCommunitySummaryTile(),
      _buildMovementSummaryTile(),
      if (_hasCalendarSummary) _buildCalendarSummaryTile(),
    ];
    return tiles[index];
  }

  Widget _buildCommunitySummaryTile() {
    final a = _latestFollow;
    final subtitleText = a == null
        ? 'Followers and profile activity'
        : '${a.actorName ?? a.actorHandle ?? 'Someone'} started following you';
    return _buildInboxRow(
      activity: true,
      leading: _buildSummaryGlyphAvatar(glyph: '𓀀𓁐', fontSize: 20),
      title: 'People',
      subtitle: subtitleText,
      trailing: _buildChevronTrail(_unreadState.hasUnreadCommunity),
      onTap: _openFollowersSheet,
    );
  }

  Widget _buildMovementSummaryTile() {
    final a = _latestEngagement;
    final subtitleText = a == null
        ? 'Flow comments and likes'
        : () {
            final who = a.actorName ?? a.actorHandle ?? 'Someone';
            final preview = a.type == InboxActivityType.comment
                ? (a.commentPreview ?? a.flowName ?? '')
                : (a.flowName ?? '');
            final summary = a.type == InboxActivityType.comment
                ? '$who commented on your flow'
                : '$who liked your flow';
            return preview.isNotEmpty ? '$summary - $preview' : summary;
          }();

    return _buildInboxRow(
      activity: true,
      leading: _buildSummaryGlyphAvatar(glyph: '𓂋𓀁', fontSize: 20),
      title: 'Discussions',
      subtitle: subtitleText,
      trailing: _buildChevronTrail(_unreadState.hasUnreadMovement),
      onTap: _openEngagementSheet,
    );
  }

  Widget _buildSummaryGlyphAvatar({
    String? glyph,
    Widget? child,
    double fontSize = 20,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 8,
      vertical: 6,
    ),
  }) {
    return SizedBox(
      width: _summaryGlyphAvatarWidth,
      height: _summaryGlyphAvatarHeight,
      child: Center(
        child: SizedBox(
          width: _summaryGlyphAvatarWidth,
          height: _summaryGlyphAvatarHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: _summaryGoldGradient,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _summaryGoldLight.withValues(alpha: 0.52),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _summaryGoldDeep.withValues(alpha: 0.34),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Padding(
                padding: padding,
                child:
                    child ??
                    MeduGlyphText(
                      glyph!,
                      textAlign: TextAlign.center,
                      style: _summaryGlyphTextStyle(fontSize),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _summaryGlyphTextStyle(double fontSize, {double height = 0.95}) {
    return TextStyle(
      color: _summaryGoldInk,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: height,
      fontFamily: 'GentiumPlus',
      fontFamilyFallback: _meduFontFallback,
    );
  }

  Widget _buildInvitesSummaryGlyphAvatar() {
    return _buildSummaryGlyphAvatar(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MeduGlyphText(
                '𓂝',
                style: _summaryGlyphTextStyle(9.5, height: 0.8),
              ),
              Transform.translate(
                offset: const Offset(0, -1),
                child: MeduGlyphText(
                  '𓈙',
                  style: _summaryGlyphTextStyle(9.5, height: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(width: 2),
          MeduGlyphText('𓀀', style: _summaryGlyphTextStyle(13, height: 0.9)),
        ],
      ),
    );
  }

  Widget _buildCalendarSummaryTile() {
    final latestNotification = _calendarSectionNotifications.isEmpty
        ? null
        : _calendarSectionNotifications.reduce(
            (left, right) =>
                right.createdAt.isAfter(left.createdAt) ? right : left,
          );
    final latestEventInvite = _latestEventInvites.isEmpty
        ? null
        : _latestEventInvites.reduce(
            (left, right) =>
                right.createdAt.isAfter(left.createdAt) ? right : left,
          );
    final latestSentInvite = _latestSentCalendarInvites.isEmpty
        ? null
        : _latestSentCalendarInvites.reduce(
            (left, right) =>
                right.invitedAt.isAfter(left.invitedAt) ? right : left,
          );
    final incomingInvites = _incomingCalendarInvitesWithoutNotification;
    final latestIncomingInvite = incomingInvites.isEmpty
        ? null
        : incomingInvites.reduce(
            (left, right) =>
                right.invitedAt.isAfter(left.invitedAt) ? right : left,
          );

    final useSentInvite =
        latestSentInvite != null &&
        (latestNotification == null ||
            latestSentInvite.invitedAt.isAfter(latestNotification.createdAt)) &&
        (latestIncomingInvite == null ||
            latestSentInvite.invitedAt.isAfter(
              latestIncomingInvite.invitedAt,
            )) &&
        (latestEventInvite == null ||
            latestSentInvite.invitedAt.isAfter(latestEventInvite.createdAt));
    final useIncomingInvite =
        latestIncomingInvite != null &&
        !useSentInvite &&
        (latestNotification == null ||
            latestIncomingInvite.invitedAt.isAfter(
              latestNotification.createdAt,
            )) &&
        (latestEventInvite == null ||
            latestIncomingInvite.invitedAt.isAfter(
              latestEventInvite.createdAt,
            ));
    final useEventInvite =
        latestEventInvite != null &&
        !useSentInvite &&
        !useIncomingInvite &&
        (latestNotification == null ||
            latestEventInvite.createdAt.isAfter(latestNotification.createdAt));

    final subtitle = useSentInvite
        ? '${latestSentInvite.calendarName} - waiting on ${latestSentInvite.inviteeLabel}'
        : (useIncomingInvite
              ? '${latestIncomingInvite.inviterLabel} invited you to ${latestIncomingInvite.calendarName}'
              : (useEventInvite
                    ? _eventInviteSummarySubtitle(latestEventInvite)
                    : _calendarSummarySubtitleForNotification(
                        latestNotification,
                      )));

    return _buildInboxRow(
      activity: true,
      leading: _buildInvitesSummaryGlyphAvatar(),
      title: 'Invites',
      subtitle: subtitle,
      trailing: _buildChevronTrail(_hasUnreadCalendar),
      onTap: _openCalendarInboxSheet,
    );
  }

  String _calendarSummarySubtitleForNotification(InboxShareItem? notification) {
    if (notification == null) {
      return 'Calendar invites and responses';
    }

    final calendarName = notification.calendarName ?? notification.title;
    final senderName = notification.senderName?.trim().isNotEmpty == true
        ? notification.senderName!.trim()
        : (notification.senderHandle?.trim().isNotEmpty == true
              ? '@${notification.senderHandle!.trim()}'
              : 'Someone');
    final status = (notification.calendarInviteStatus ?? '').trim();
    if (notification.isCalendarInviteResponseNotification) {
      final verb = status == 'declined' ? 'declined' : 'accepted';
      return '$senderName $verb your invitation to $calendarName';
    }
    if (status == 'accepted') {
      return 'You accepted $calendarName';
    }
    if (status == 'declined') {
      return 'You declined $calendarName';
    }
    return '$senderName invited you to $calendarName';
  }

  String _eventInviteSummarySubtitle(InboxShareItem invite) {
    final title = invite.eventPayload?.title ?? invite.title;
    final senderName = invite.senderName?.trim().isNotEmpty == true
        ? invite.senderName!.trim()
        : (invite.senderHandle?.trim().isNotEmpty == true
              ? '@${invite.senderHandle!.trim()}'
              : 'Someone');
    final status = invite.responseStatus;
    if (status == EventInviteResponseStatus.noResponse) {
      return '$senderName invited you to $title';
    }
    return '$title - ${_eventInviteStatusLabel(invite)}';
  }

  void _openFollowersSheet() {
    final followers =
        _activity.where((a) => a.type == InboxActivityType.follow).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (followers.isNotEmpty) {
      unawaited(
        _shareRepo.markActivitySeen(
          InboxActivityBucket.community,
          seenAt: _latestTimestampForActivity(followers),
        ),
      );
    }
    unawaited(_showActivitySheet(title: 'Community', items: followers));
  }

  void _openEngagementSheet() {
    final engagement =
        _activity
            .where(
              (a) =>
                  a.type == InboxActivityType.like ||
                  a.type == InboxActivityType.comment,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (engagement.isNotEmpty) {
      unawaited(
        _shareRepo.markActivitySeen(
          InboxActivityBucket.movement,
          seenAt: _latestTimestampForActivity(engagement),
        ),
      );
    }
    unawaited(_showActivitySheet(title: 'Movement', items: engagement));
  }

  Future<void> _showActivitySheet({
    required String title,
    required List<InboxActivityItem> items,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: _bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Nothing here yet.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final a = items[index];
                        return _buildActivityRow(a, closeContext: context);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCalendarInboxSheet({String? parentRouteOverride}) async {
    if (_invitesSheetOpenOrOpening) return;
    final parentRoute = parentRouteOverride ?? _currentRouteLocation();
    final unreadInviteItems = [
      ..._calendarSectionNotifications,
      ..._latestEventInvites,
    ].where(_isUnreadInboxItem).toList(growable: false);
    if (unreadInviteItems.isNotEmpty) {
      unawaited(_markItemsViewed(unreadInviteItems));
    }

    _invitesSheetOpenOrOpening = true;
    await _saveInvitesSheetRestorationState(parentRoute: parentRoute);
    try {
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        backgroundColor: _bg,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (sheetContext) {
          final inviteNotifications = _calendarSectionNotifications.toList();
          final eventInvites = _latestEventInvites.toList();
          final inviteResponseItems = <InboxShareItem>[
            ...eventInvites,
            ...inviteNotifications,
          ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final sentInvites = _latestSentCalendarInvites.toList()
            ..sort((a, b) => b.invitedAt.compareTo(a.invitedAt));
          final incomingInvites =
              _incomingCalendarInvitesWithoutNotification.toList()
                ..sort((a, b) => b.invitedAt.compareTo(a.invitedAt));

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const Text(
                    'Invites',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (sentInvites.isEmpty &&
                      inviteResponseItems.isEmpty &&
                      incomingInvites.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Calendar invites and responses will appear here.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          if (incomingInvites.isNotEmpty) ...[
                            _calendarSheetSectionTitle('Invites for you'),
                            const SizedBox(height: 8),
                            for (final invite in incomingInvites)
                              _buildIncomingCalendarInviteRow(
                                invite,
                                closeContext: sheetContext,
                              ),
                          ],
                          if (sentInvites.isNotEmpty) ...[
                            if (incomingInvites.isNotEmpty)
                              const SizedBox(height: 12),
                            _calendarSheetSectionTitle('Pending from you'),
                            const SizedBox(height: 8),
                            for (final invite in sentInvites)
                              _buildSentCalendarInviteRow(
                                invite,
                                closeContext: sheetContext,
                              ),
                          ],
                          if (inviteResponseItems.isNotEmpty) ...[
                            if (sentInvites.isNotEmpty ||
                                incomingInvites.isNotEmpty)
                              const SizedBox(height: 12),
                            _calendarSheetSectionTitle('Invites & responses'),
                            const SizedBox(height: 8),
                            for (final item in inviteResponseItems)
                              item.isEvent
                                  ? _buildEventInviteRow(
                                      item,
                                      closeContext: sheetContext,
                                    )
                                  : _buildCalendarInviteNotificationRow(
                                      item,
                                      closeContext: sheetContext,
                                    ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      try {
        final preserveForLifecycle =
            !mounted ||
            RestorationCoordinator
                .instance
                .shouldPreserveOverlayForLifecycleClose;
        if (!preserveForLifecycle) {
          await _clearInvitesSheetRestorationState();
        }
      } finally {
        _invitesSheetOpenOrOpening = false;
      }
    }
  }

  Widget _calendarSheetSectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildIncomingCalendarInviteRow(
    SharedCalendarInvite invite, {
    BuildContext? closeContext,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: invite.color.withValues(alpha: 0.14),
          border: Border.all(color: invite.color.withValues(alpha: 0.32)),
        ),
        child: Icon(Icons.person_add_alt_1_rounded, color: invite.color),
      ),
      title: Text(
        invite.calendarName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        '${invite.inviterLabel} invited you to join this calendar',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 14,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: invite.color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Pending',
          style: TextStyle(
            color: invite.color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      onTap: () async {
        if (closeContext != null) {
          Navigator.of(closeContext).pop();
        }
        await SharedCalendarsSheet.show(
          context,
          repo: _sharedCalendarsRepo,
          onEventTapRequested:
              (calendar, filedEvent, {calendarEvents = const []}) =>
                  CalendarPage.openFiledCalendarEventFromAnyContext(
                    context,
                    calendar: calendar,
                    filedEvent: filedEvent,
                    calendarEvents: calendarEvents,
                  ),
        );
      },
    );
  }

  Widget _buildSentCalendarInviteRow(
    SharedCalendarSentInvite invite, {
    BuildContext? closeContext,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: ProfileAvatar(
        radius: 22,
        displayName: invite.inviteeLabel,
        avatarUrl: invite.inviteeAvatarUrl,
        backgroundColor: invite.color.withValues(alpha: 0.16),
        foregroundColor: invite.color,
      ),
      title: Text(
        invite.calendarName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        'Waiting on ${invite.inviteeLabel}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 14,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: invite.color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Pending',
          style: TextStyle(
            color: invite.color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      onTap: () async {
        if (closeContext != null) {
          Navigator.of(closeContext).pop();
        }
        await SharedCalendarsSheet.show(
          context,
          repo: _sharedCalendarsRepo,
          onEventTapRequested:
              (calendar, filedEvent, {calendarEvents = const []}) =>
                  CalendarPage.openFiledCalendarEventFromAnyContext(
                    context,
                    calendar: calendar,
                    filedEvent: filedEvent,
                    calendarEvents: calendarEvents,
                  ),
        );
      },
    );
  }

  Widget _buildCalendarInviteNotificationRow(
    InboxShareItem notification, {
    BuildContext? closeContext,
  }) {
    final senderName = notification.senderName?.trim().isNotEmpty == true
        ? notification.senderName!.trim()
        : (notification.senderHandle?.trim().isNotEmpty == true
              ? '@${notification.senderHandle!.trim()}'
              : 'Someone');
    final accent = notification.calendarColorValue != null
        ? Color(notification.calendarColorValue!)
        : _gold;
    final calendarName = notification.calendarName ?? notification.title;
    final status = (notification.calendarInviteStatus ?? '').trim();
    final statusColor = status == 'accepted'
        ? Colors.greenAccent
        : (status == 'declined' ? Colors.redAccent : accent);
    final statusLabel = status == 'accepted'
        ? 'Accepted'
        : (status == 'declined' ? 'Declined' : 'Pending');
    final responseVerb = status == 'declined' ? 'declined' : 'accepted';
    final subtitle = notification.isCalendarInviteResponseNotification
        ? '$senderName $responseVerb your invitation to $calendarName'
        : (status == 'accepted'
              ? 'You accepted this invitation.'
              : (status == 'declined'
                    ? 'You declined this invitation.'
                    : '$senderName invited you to join $calendarName'));
    final isUnread = _isUnreadInboxItem(notification);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: notification.isCalendarInviteResponseNotification
          ? _buildInvitesSheetGlyphIcon(
              glyph: _inviteResponseGlyph,
              semanticLabel: 'Invite response',
              color: accent,
              backgroundColor: accent.withValues(alpha: 0.14),
              border: Border.all(color: accent.withValues(alpha: 0.32)),
              glyphOffset: const Offset(0, -2),
            )
          : Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: accent.withValues(alpha: 0.14),
                border: Border.all(color: accent.withValues(alpha: 0.32)),
              ),
              child: Icon(Icons.person_add_alt_1_rounded, color: accent),
            ),
      title: Text(
        calendarName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 14,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (isUnread) ...[
            const SizedBox(height: 8),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: _gold,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
      onTap: () async {
        if (closeContext != null) {
          Navigator.of(closeContext).pop();
        }
        await _openCalendarNotification(notification);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No shares yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Shared flows, messages, invites, and calendar updates will appear here',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCalendarNotification(InboxShareItem notification) async {
    await _markItemsViewed([notification]);
    if (!mounted) return;

    if (notification.isCalendarInviteNotification ||
        notification.isCalendarInviteResponseNotification) {
      await SharedCalendarsSheet.show(
        context,
        repo: _sharedCalendarsRepo,
        onEventTapRequested:
            (calendar, filedEvent, {calendarEvents = const []}) =>
                CalendarPage.openFiledCalendarEventFromAnyContext(
                  context,
                  calendar: calendar,
                  filedEvent: filedEvent,
                  calendarEvents: calendarEvents,
                ),
      );
      return;
    }

    final calendarId = notification.calendarId;
    if (notification.isCalendarEventNotification &&
        calendarId != null &&
        calendarId.isNotEmpty) {
      context.go(sharedCalendarInboxRouteLocation(calendarId));
      return;
    }

    final clientEventId = notification.calendarClientEventId;
    if (clientEventId != null && clientEventId.isNotEmpty) {
      context.go('/');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        emitCalendarPushOpenClientEventId(clientEventId);
      });
    }
  }

  Future<void> _openEventInvite(InboxShareItem invite) async {
    await _markItemsViewed([invite]);
    if (!mounted) return;
    unawaited(
      openDetailRoute<void>(
        context,
        '/event-invite/${Uri.encodeComponent(invite.shareId)}',
        extra: invite,
      ),
    );
  }

  Future<void> _openSharedCalendarThread(
    SharedCalendarInboxThread thread,
  ) async {
    await _markItemsViewed(thread.notifications);
    if (!mounted) return;

    final calendarId = thread.calendarId;
    if (calendarId == null || calendarId.isEmpty) {
      await _openCalendarNotification(thread.lastNotification);
      return;
    }

    context.go(sharedCalendarInboxRouteLocation(calendarId));
  }
}

class _InboxMahoganySurface extends StatelessWidget {
  const _InboxMahoganySurface({this.child, this.showCornice = false});

  final Widget? child;
  final bool showCornice;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _InboxPageState._mahoganyTop,
            _InboxPageState._mahogany,
            _InboxPageState._mahoganyDeep,
          ],
          stops: [0.0, 0.30, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -1.16),
                radius: 1.18,
                colors: [
                  Color(0x12F5E8CB),
                  Color(0x04D4AF37),
                  Colors.transparent,
                ],
                stops: [0.0, 0.38, 0.60],
              ),
            ),
          ),
          if (showCornice)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color(0x59F5E8CB),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SizedBox(height: 1),
              ),
            ),
          if (child != null) Positioned.fill(child: child!),
        ],
      ),
    );
  }
}

class _InboxUnreadDot extends StatelessWidget {
  const _InboxUnreadDot({this.color = Colors.redAccent, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

enum _UnifiedKind { message, calendarNotification, dmConversation }

class _UnifiedInboxItem {
  _UnifiedInboxItem.message({
    required this.createdAt,
    required this.otherUserId,
    required this.otherProfile,
    required this.items,
    required this.hasUnread,
  }) : kind = _UnifiedKind.message,
       calendarNotification = null,
       calendarThread = null,
       dmConversation = null;

  _UnifiedInboxItem.calendarNotification({
    required this.createdAt,
    required this.calendarThread,
  }) : kind = _UnifiedKind.calendarNotification,
       otherUserId = null,
       otherProfile = null,
       items = null,
       hasUnread = null,
       calendarNotification = null,
       dmConversation = null;

  _UnifiedInboxItem.dmConversation({
    required this.createdAt,
    required this.dmConversation,
  }) : kind = _UnifiedKind.dmConversation,
       otherUserId = null,
       otherProfile = null,
       items = null,
       hasUnread = null,
       calendarNotification = null,
       calendarThread = null;

  final _UnifiedKind kind;
  final DateTime createdAt;

  // Message thread fields
  final String? otherUserId;
  final ConversationUser? otherProfile;
  final List<InboxShareItem>? items;
  final bool? hasUnread;
  final InboxShareItem? calendarNotification;
  final SharedCalendarInboxThread? calendarThread;
  final DmConversationSummary? dmConversation;
}

// Legacy code below - keeping for FlowPreviewCard compatibility
// Preview Card Widget
class FlowPreviewCard extends StatefulWidget {
  final InboxShareItem item;
  final Map<String, bool> importStatusCache;
  final VoidCallback onImportComplete;

  const FlowPreviewCard({
    super.key,
    required this.item,
    required this.importStatusCache,
    required this.onImportComplete,
  });

  @override
  State<FlowPreviewCard> createState() => _FlowPreviewCardState();
}

class _FlowPreviewCardState extends State<FlowPreviewCard> {
  static const _bg = Color(0xFF000000);
  static const _cardBg = Color(0xFF0D0D0F);
  static const _gold = KemeticGold.base;
  static const _silver = Color(0xFFB0B0B0);

  final _inboxRepo = InboxRepo(Supabase.instance.client);
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Flow Preview',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: _silver),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: _silver, height: 1),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 20 + bottomPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender info
                  _buildSenderInfo(),
                  const SizedBox(height: 24),

                  // Flow title and details
                  _buildFlowDetails(),
                  const SizedBox(height: 24),

                  // Suggested schedule (if present)
                  if (widget.item.suggestedSchedule != null) ...[
                    _buildScheduleSection(),
                    const SizedBox(height: 24),
                  ],

                  // Action buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSenderInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: _gold.withValues(alpha: 0.2),
            backgroundImage: widget.item.senderAvatar != null
                ? NetworkImage(widget.item.senderAvatar!)
                : null,
            child: widget.item.senderAvatar == null
                ? Text(
                    (widget.item.senderName ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.senderName ?? 'Unknown User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${widget.item.senderHandle ?? 'unknown'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shared ${widget.item.isFlow ? 'Flow' : 'Event'}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.item.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleSection() {
    final schedule = widget.item.suggestedSchedule!;
    final weekdayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suggested Schedule',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Start date
              if (schedule.startDate.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Starts: ${schedule.startDate}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Weekdays
              if (schedule.weekdays.isNotEmpty) ...[
                Text(
                  'Days:',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: schedule.weekdays.map((day) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _gold.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        weekdayNames[day],
                        style: const TextStyle(
                          color: _gold,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Times
              if (schedule.timesByWeekday.isNotEmpty) ...[
                Text(
                  'Times:',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                ...schedule.timesByWeekday.entries.map((entry) {
                  final dayName = weekdayNames[int.parse(entry.key)];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 50,
                          child: Text(
                            dayName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            entry.value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              unawaited(
                openDetailRoute<void>(
                  context,
                  '/shared-flow/${Uri.encodeComponent(widget.item.shareId)}',
                  extra: widget.item,
                ),
              );
              messenger?.hideCurrentSnackBar();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: KemeticGold.base,
              foregroundColor: Colors.black,
            ),
            child: const Text('View Full Details'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: _buildImportButton(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Close',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImportButton() {
    return FutureBuilder<int?>(
      future: UserEventsRepo(
        Supabase.instance.client,
      ).getFlowIdByShareId(widget.item.shareId),
      builder: (context, snapshot) {
        final flowId = snapshot.data;
        final isImported = flowId != null; // Flow exists in user's flows
        final isFlowImportable = widget.item.isFlow;

        return ElevatedButton(
          onPressed: _isImporting || isImported || !isFlowImportable
              ? null
              : _handleImport,
          style: ElevatedButton.styleFrom(
            backgroundColor: isImported
                ? const Color(0xFF4A4A4A) // Visible medium grey
                : KemeticGold.base,
            foregroundColor: isImported
                ? const Color(0xFFAAAAAA) // Light grey text
                : Colors.black,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isImporting
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              : Text(
                  isImported
                      ? 'Already Imported'
                      : (isFlowImportable
                            ? 'Import Flow to Calendar'
                            : 'Event Import Unavailable'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        );
      },
    );
  }

  Future<void> _handleImport() async {
    setState(() => _isImporting = true);

    try {
      if (!widget.item.isFlow) {
        throw Exception('Event import is not available in this build');
      }

      int? flowId;
      flowId = await _importFlow(widget.item);

      _logInboxImport(
        '[InboxPage] ✓ Successfully imported flow $flowId and linked to share ${widget.item.shareId}',
      );

      if (!mounted) return;

      // Step 4: Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.item.title} imported successfully!'),
          backgroundColor: KemeticGold.base,
          duration: const Duration(seconds: 2),
        ),
      );

      // Close the preview modal
      Navigator.pop(context); // Close preview

      // Notify parent to refresh
      widget.onImportComplete();

      // ✅ NEW: Close inbox and return the flowId to calendar
      Navigator.pop(context, flowId);
    } catch (e) {
      _logInboxImport('[InboxPage] ✗ Import failed: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to import: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<int> _importFlow(InboxShareItem item) async {
    _logInboxImport('[InboxPage] Starting import for: ${item.title}');
    return _inboxRepo.importSharedFlow(share: item);
  }
}

class InboxFlowDetailsPage extends StatelessWidget {
  final InboxShareItem item;

  const InboxFlowDetailsPage({super.key, required this.item});

  List<TextSpan> _buildTextSpans(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(https?://\S+)', multiLine: true);
    int start = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: const TextStyle(
            decoration: TextDecoration.underline,
            color: Color(0xFF4DA3FF),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
        ),
      );
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final payload = item.payloadJson ?? <String, dynamic>{};
    final rawName = (payload['name'] as String?) ?? item.title;
    final name = cleanFlowTitle(rawName);
    final overview = cleanFlowOverview(
      (payload['notes'] as String?) ?? (payload['overview'] as String?),
      decodedOverview: payload['overview'] as String?,
    );
    final active = (payload['active'] as bool?) ?? true;
    final colorInt = (payload['color'] as int?) ?? 0xFFD4AF37;
    final color = Color(colorInt);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(name.isEmpty ? 'Flow' : name),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                active ? 'Active' : 'Inactive',
                style: TextStyle(
                  fontSize: 12,
                  color: active
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFB0B0B0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (overview.isNotEmpty) ...[
            const Text(
              'Overview',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFDDDDDD),
                  height: 1.4,
                ),
                children: _buildTextSpans(overview),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // TODO: extend with schedule / rules if you want parity with Flow Studio
        ],
      ),
    );
  }
}
