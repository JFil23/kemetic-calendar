// lib/features/profile/profile_page.dart

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile/core/page_navigation_swipe.dart';
import 'package:mobile/core/touch_targets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/profile_avatar_glyphs.dart';
import '../../data/profile_model.dart';
import '../../data/profile_repo.dart';
import '../../data/flow_post_model.dart';
import '../../data/insight_post_model.dart';
import '../../data/profile_feed_item_model.dart';
import '../../utils/detail_sanitizer.dart';
import '../../utils/kemetic_date_format.dart';
import '../../services/app_haptics.dart';
import 'edit_profile_page.dart';
import 'profile_search_page.dart';
import 'flow_post_picker_page.dart';
import 'flow_post_detail_page.dart';
import 'insight_post_picker_page.dart';
import 'insight_post_detail_page.dart';
import '_post_glossy_helper.dart';
import 'follow_list_page.dart';
import '../calendar/calendar_page.dart';
import 'flow_post_engagement_row.dart';
import 'package:mobile/shared/glossy_text.dart';
import '../../widgets/inbox_icon_with_badge.dart';
import '../../widgets/profile_avatar.dart';
import 'profile_backdrop_timeline.dart';

const Color _profileGoldLight = Color(0xFFF7E09A);
const Color _profileGoldMid = Color(0xFFE8BE54);
const Color _profileGoldBase = Color(0xFFCA9221);
const Color _profileGoldDeep = Color(0xFF7A5310);
const Color _profileGoldText = Color(0xFFF1CF7A);
const Color _profileGregorianBlue = Color(0xFF4DA3FF);
const Color _profileGregorianBlueLight = Color(0xFFBFE0FF);
const int _profileFeedPageSize = 18;
const double _profileFeedColumnGap = 12;

const Gradient _profileGoldGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [
    _profileGoldBase,
    _profileGoldLight,
    _profileGoldMid,
    _profileGoldDeep,
  ],
  stops: [0.0, 0.42, 0.74, 1.0],
);

class ProfilePage extends StatefulWidget {
  final String userId;
  final bool isMyProfile;
  final bool openedFromCalendar;
  final bool openedFromCalendarSwipe;

  const ProfilePage({
    super.key,
    required this.userId,
    this.isMyProfile = false,
    this.openedFromCalendar = false,
    this.openedFromCalendarSwipe = false,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  static const double _feedRevealViewportThreshold = 0.74;
  static const double _feedPullToCloseThreshold = 96;
  final _repo = ProfileRepo(Supabase.instance.client);
  late final PageController _postPageController;
  late final PageController _insightPostPageController;
  late final ScrollController _profileScrollController;
  late final ScrollController _feedScrollController;
  late final AnimationController _feedBloomController;
  final GlobalKey _feedRevealHintKey = GlobalKey();
  UserProfile? _profile;
  bool _loading = true;
  bool _isFollowing = false;
  bool _followUpdating = false;
  List<FlowPost> _posts = const [];
  List<InsightPost> _insightPosts = const [];
  List<ProfileFeedItem> _feedItems = const [];
  bool _postsLoading = true;
  bool _insightPostsLoading = true;
  bool _feedRevealed = false;
  bool _feedLoading = false;
  bool _feedLoadingMore = false;
  bool _feedHasMore = true;
  bool _showGregorianFeedDates = false;
  bool _feedCloseInFlight = false;
  int _activePostIndex = 0;
  int _activeInsightPostIndex = 0;
  bool _calendarRevealNavigationInFlight = false;
  int _profileLoadSerial = 0;
  double _feedTopPullDistance = 0;

  bool get _isViewingOwnProfile {
    final currentId = Supabase.instance.client.auth.currentUser?.id;
    return widget.isMyProfile ||
        (currentId != null && currentId == widget.userId);
  }

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  bool _ownsPost(FlowPost post) {
    final currentUserId = _currentUserId;
    return currentUserId != null && currentUserId == post.userId;
  }

  bool _ownsInsightPost(InsightPost post) {
    final currentUserId = _currentUserId;
    return currentUserId != null && currentUserId == post.userId;
  }

  @override
  void initState() {
    super.initState();
    _postPageController = PageController(viewportFraction: 0.96);
    _insightPostPageController = PageController(viewportFraction: 0.96);
    _profileScrollController = ScrollController()
      ..addListener(_handleProfileScroll);
    _feedScrollController = ScrollController()..addListener(_maybeLoadMoreFeed);
    _feedBloomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _loadProfile();
  }

  @override
  void dispose() {
    _feedBloomController.dispose();
    _profileScrollController
      ..removeListener(_handleProfileScroll)
      ..dispose();
    _feedScrollController
      ..removeListener(_maybeLoadMoreFeed)
      ..dispose();
    _postPageController.dispose();
    _insightPostPageController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile({bool showSpinner = true}) async {
    final loadSerial = ++_profileLoadSerial;
    if (showSpinner) {
      setState(() => _loading = true);
    }

    final profileFuture = _repo.getProfile(widget.userId);
    final followFuture = _isViewingOwnProfile
        ? Future<bool>.value(false)
        : _repo.isFollowing(widget.userId);
    final postsFuture = _repo.getFlowPosts(widget.userId);
    final insightPostsFuture = _repo.getInsightPosts(widget.userId);
    final countsFuture = _repo.computeFlowCountsForUser(widget.userId);

    final profile = await profileFuture;
    final isFollowing = await followFuture;

    if (!mounted || loadSerial != _profileLoadSerial) return;
    setState(() {
      _profile = profile;
      _isFollowing = isFollowing;
      _loading = false;
    });

    if (profile == null) return;

    unawaited(() async {
      final counts = await countsFuture;
      if (!mounted || loadSerial != _profileLoadSerial) return;
      final current = _profile;
      if (current == null) return;
      setState(() {
        _profile = current.copyWith(
          activeFlowsCount: counts.$1,
          totalFlowEventsCount: counts.$2,
        );
      });
    }());

    unawaited(() async {
      final posts = await postsFuture;
      if (!mounted || loadSerial != _profileLoadSerial) return;
      _applyPosts(posts);
    }());

    unawaited(() async {
      final posts = await insightPostsFuture;
      if (!mounted || loadSerial != _profileLoadSerial) return;
      _applyInsightPosts(posts);
    }());
  }

  Future<void> _loadPosts() async {
    setState(() => _postsLoading = true);
    final posts = await _repo.getFlowPosts(widget.userId);
    if (!mounted) return;
    _applyPosts(posts);
  }

  void _applyPosts(List<FlowPost> posts) {
    final activeIndex = _clampPostIndex(posts.length);
    setState(() {
      _posts = posts;
      _postsLoading = false;
      _activePostIndex = activeIndex;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || posts.isEmpty || !_postPageController.hasClients) return;
      final currentPage = (_postPageController.page ?? activeIndex.toDouble())
          .round();
      if (currentPage != activeIndex) {
        _postPageController.jumpToPage(activeIndex);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeRevealFeedFromViewport();
    });
  }

  Future<void> _loadInsightPosts() async {
    setState(() => _insightPostsLoading = true);
    final posts = await _repo.getInsightPosts(widget.userId);
    if (!mounted) return;
    _applyInsightPosts(posts);
  }

  void _applyInsightPosts(List<InsightPost> posts) {
    final activeIndex = _clampInsightPostIndex(posts.length);
    setState(() {
      _insightPosts = posts;
      _insightPostsLoading = false;
      _activeInsightPostIndex = activeIndex;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || posts.isEmpty || !_insightPostPageController.hasClients) {
        return;
      }
      final currentPage =
          (_insightPostPageController.page ?? activeIndex.toDouble()).round();
      if (currentPage != activeIndex) {
        _insightPostPageController.jumpToPage(activeIndex);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeRevealFeedFromViewport();
    });
  }

  Future<void> _reloadPostedContent() async {
    await Future.wait<void>([_loadPosts(), _loadInsightPosts()]);
  }

  void _handleProfileScroll() {
    if (!_feedRevealed) {
      _maybeRevealFeedFromViewport();
    }
    if (_feedRevealed) {
      _maybeLoadMoreFeed();
    }
  }

  void _maybeRevealFeedFromViewport() {
    if (_feedRevealed) return;
    final revealContext = _feedRevealHintKey.currentContext;
    if (revealContext == null) return;
    final renderObject = revealContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final center = renderObject.localToGlobal(
      Offset(0, renderObject.size.height / 2),
    );
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final revealLine = viewportHeight * _feedRevealViewportThreshold;
    if (center.dy <= revealLine) {
      _revealFeed();
    }
  }

  Future<void> _revealFeed() async {
    if (_feedRevealed || _feedCloseInFlight) return;
    _feedTopPullDistance = 0;
    unawaited(AppHaptics.mediumImpact(reason: 'profile_feed_reveal'));
    setState(() => _feedRevealed = true);
    unawaited(_feedBloomController.forward(from: 0));
    await _loadFeedPage(reset: true);
  }

  Future<void> _closeFeed() async {
    if (!_feedRevealed || _feedCloseInFlight) return;
    _feedCloseInFlight = true;
    _feedTopPullDistance = 0;
    unawaited(AppHaptics.mediumImpact(reason: 'profile_feed_close'));
    await _feedBloomController.reverse(from: _feedBloomController.value);
    if (!mounted) return;
    _feedCloseInFlight = false;
    setState(() => _feedRevealed = false);
  }

  void _updateFeedPullDistance(double pullDistance) {
    final clampedPull = pullDistance.clamp(0.0, _feedPullToCloseThreshold);
    _feedTopPullDistance = math.max(_feedTopPullDistance, clampedPull);
  }

  void _maybeCloseFeedFromPull() {
    if (_feedTopPullDistance < _feedPullToCloseThreshold) return;
    if (_feedCloseInFlight) return;
    unawaited(_closeFeed());
  }

  bool _handleFeedScrollNotification(ScrollNotification notification) {
    if (!_feedRevealed || _feedCloseInFlight) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.depth != 0) return false;

    switch (notification) {
      case ScrollStartNotification():
        _feedTopPullDistance = 0;
        return false;
      case ScrollUpdateNotification():
        final pullDistance = math.max(
          0.0,
          notification.metrics.minScrollExtent - notification.metrics.pixels,
        );
        if (pullDistance > 0) {
          _updateFeedPullDistance(pullDistance);
          _maybeCloseFeedFromPull();
        }
        return false;
      case OverscrollNotification():
        final atTop =
            notification.metrics.pixels <=
            notification.metrics.minScrollExtent + 0.5;
        if (!atTop) return false;
        _updateFeedPullDistance(
          _feedTopPullDistance + notification.overscroll.abs(),
        );
        _maybeCloseFeedFromPull();
        return false;
      case ScrollEndNotification():
        if (_feedTopPullDistance >= _feedPullToCloseThreshold) {
          unawaited(_closeFeed());
        } else {
          _feedTopPullDistance = 0;
        }
        return false;
      default:
        return false;
    }
  }

  void _toggleFeedDateMode() {
    if (!mounted) return;
    setState(() {
      _showGregorianFeedDates = !_showGregorianFeedDates;
    });
  }

  Future<void> _loadFeedPage({bool reset = false}) async {
    if (_feedLoading || _feedLoadingMore) return;
    if (!reset && !_feedHasMore) return;

    final nextOffset = reset ? 0 : _feedItems.length;
    if (reset) {
      setState(() {
        _feedLoading = true;
        _feedHasMore = true;
      });
    } else {
      setState(() => _feedLoadingMore = true);
    }

    final loaded = await _repo.getProfileFeed(
      limit: _profileFeedPageSize,
      offset: nextOffset,
    );
    if (!mounted) return;

    final merged = reset
        ? <ProfileFeedItem>[]
        : List<ProfileFeedItem>.from(_feedItems);
    final seenIds = merged
        .map((item) => '${item.kind.name}:${item.id}')
        .toSet();
    for (final item in loaded) {
      final key = '${item.kind.name}:${item.id}';
      if (seenIds.add(key)) {
        merged.add(item);
      }
    }

    setState(() {
      _feedItems = merged;
      _feedLoading = false;
      _feedLoadingMore = false;
      _feedHasMore = loaded.length >= _profileFeedPageSize;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeLoadMoreFeed();
    });
  }

  void _maybeLoadMoreFeed() {
    if (!_feedRevealed || _feedLoading || _feedLoadingMore || !_feedHasMore) {
      return;
    }
    if (!_feedScrollController.hasClients) return;
    if (_feedScrollController.position.extentAfter > 720) return;
    unawaited(_loadFeedPage());
  }

  int _clampPostIndex(int length, [int? desired]) {
    if (length == 0) return 0;
    final target = desired ?? _activePostIndex;
    if (target < 0) return 0;
    if (target >= length) return length - 1;
    return target;
  }

  int _clampInsightPostIndex(int length, [int? desired]) {
    if (length == 0) return 0;
    final target = desired ?? _activeInsightPostIndex;
    if (target < 0) return 0;
    if (target >= length) return length - 1;
    return target;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _toggleFollow() async {
    if (_followUpdating || _isViewingOwnProfile) return;
    setState(() => _followUpdating = true);

    final success = _isFollowing
        ? await _repo.unfollowUser(widget.userId)
        : await _repo.followUser(widget.userId);

    if (!success) {
      _showError('Could not update follow status. Please try again.');
    } else {
      await _loadProfile(showSpinner: false);
    }

    if (mounted) {
      setState(() => _followUpdating = false);
    }
  }

  Future<void> _openCalendarMenu(BuildContext context) async {
    final calendarState = CalendarPage.globalKey.currentState;
    if (calendarState != null) {
      await calendarState.showActionsMenuFromOutside(
        context,
        includeNewNote: false,
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calendar actions are unavailable right now.'),
      ),
    );
  }

  Future<void> _openCalendarQuickAdd() async {
    final calendarState = CalendarPage.globalKey.currentState;
    if (calendarState != null) {
      await calendarState.openQuickAddFromOutside();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('New note is unavailable right now.')),
    );
  }

  Future<void> _openMyProfileAction() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showError('Please log in to view your profile.');
      return;
    }

    if (_isViewingOwnProfile) return;

    await _replaceWithProfile(userId);
  }

  @override
  Widget build(BuildContext context) {
    final canRevealCalendar =
        widget.openedFromCalendar && Navigator.of(context).canPop();
    final showBackdrop = !_loading && _profile != null;
    final title = _profile?.handle ?? 'Profile';
    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(
        key: ValueKey<Object>(
          _loading
              ? 'profile_loading'
              : _profile == null
              ? 'profile_missing'
              : _feedRevealed
              ? 'profile_feed_mode'
              : 'profile_mode',
        ),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_profileGoldMid),
                ),
              )
            : _profile == null
            ? _buildNoProfile()
            : _feedRevealed
            ? _buildFeedMode()
            : _buildProfile(),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      extendBodyBehindAppBar: showBackdrop,
      appBar: AppBar(
        backgroundColor: showBackdrop
            ? Colors.transparent
            : const Color(0xFF000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        automaticallyImplyLeading: false,
        leading: widget.openedFromCalendarSwipe
            ? null
            : IconButton(
                icon: _profileGoldIcon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
        title: _feedRevealed
            ? _buildFeedDateModeToggle()
            : Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
        actions: [
          IconButton(
            tooltip: 'New note',
            icon: _profileGoldIcon(Icons.add),
            onPressed: () {
              unawaited(_openCalendarQuickAdd());
            },
          ),
          IconButton(
            tooltip: 'Today',
            icon: _profileGoldIcon(Icons.today),
            onPressed: () => CalendarPage.openMainCalendarAtToday(context),
          ),
          Builder(
            builder: (btnCtx) => IconButton(
              tooltip: 'Menu',
              icon: InboxUnreadDotOverlay(child: _profileGoldIcon(Icons.apps)),
              onPressed: () => _openCalendarMenu(btnCtx),
            ),
          ),
          if (_feedRevealed)
            IconButton(
              tooltip: 'Profile',
              icon: _profileGoldIcon(Icons.person),
              onPressed: () {
                unawaited(_closeFeed());
              },
            )
          else if (!_isViewingOwnProfile)
            IconButton(
              tooltip: 'My Profile',
              icon: _profileGoldIcon(Icons.person),
              onPressed: _openMyProfileAction,
            ),
        ],
      ),
      body: Stack(
        children: [
          if (showBackdrop) ...[
            const Positioned.fill(child: _ProfileBackdrop()),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.45),
                        const Color(0xFF000000),
                      ],
                      stops: const [0.0, 0.22, 0.58, 0.8],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.paddingOf(context).top + kToolbarHeight + 24,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.72),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          body,
          if (canRevealCalendar) _buildCalendarRevealSwipeGate(),
        ],
      ),
    );
  }

  Widget _buildNoProfile() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 80,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Profile not found',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile() {
    final profile = _profile!;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final height = MediaQuery.sizeOf(context).height;
    final heroHeight = (height * 0.54).clamp(420.0, 560.0);
    final bio = profile.bio?.trim() ?? '';

    return SingleChildScrollView(
      controller: _profileScrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeroSection(profile, topInset: topInset, height: heroHeight),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (bio.isNotEmpty) ...[
                  Text(
                    bio,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontSize: 15,
                      height: 1.48,
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                _buildStats(profile),
                const SizedBox(height: 18),
                _buildActionCluster(),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.only(top: 18),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: _profileGoldMid.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  child: _buildPostsSection(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedMode() {
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return NotificationListener<ScrollNotification>(
      onNotification: _handleFeedScrollNotification,
      child: SingleChildScrollView(
        controller: _feedScrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(20, topInset + 18, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFeedHeader(),
            const SizedBox(height: 18),
            _buildFeedBloomPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(
    UserProfile profile, {
    required double topInset,
    required double height,
  }) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topInset + 20, 20, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              profile.effectiveName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w700,
                height: 1.02,
                shadows: [
                  Shadow(
                    color: Colors.black87,
                    blurRadius: 18,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),
            if (profile.handle != null &&
                profile.handle!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '@${profile.handle}',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (profile.avatarGlyphIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildGlyphSignature(profile),
            ],
          ],
        ),
      ),
    );
  }

  Widget _profileGoldTextWidget(
    String text, {
    required TextStyle style,
    int? maxLines,
    TextOverflow? overflow,
    bool? softWrap,
    TextAlign? textAlign,
  }) {
    return GlossyText(
      text: text,
      style: style,
      gradient: _profileGoldGradient,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      textAlign: textAlign,
    );
  }

  Widget _profileGoldIcon(IconData icon, {double? size}) {
    return GlossyIcon(icon: icon, gradient: _profileGoldGradient, size: size);
  }

  Widget _buildGlyphSignature(UserProfile profile) {
    final glyphs = profileGlyphPhraseGlyphs(profile.avatarGlyphIds);
    final meaning = profileGlyphPhraseMeaning(profile.avatarGlyphIds);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.46),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _profileGoldMid.withValues(alpha: 0.26)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              glyphs,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _profileGoldText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.1,
                fontFamily: 'GentiumPlus',
                fontFamilyFallback: [
                  'Noto Sans Egyptian Hieroglyphs',
                  'Apple Symbols',
                  'Segoe UI Symbol',
                  'Arial Unicode MS',
                  'NotoSans',
                ],
              ),
            ),
            if (meaning.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                meaning,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStats(UserProfile profile) {
    final stats = [
      (
        label: 'Followers',
        value: (profile.followersCount ?? 0).toString(),
        onTap: () => _openFollowList(profile, FollowListType.followers),
        enabled: true,
      ),
      (
        label: 'Following',
        value: (profile.followingCount ?? 0).toString(),
        onTap: () => _openFollowList(profile, FollowListType.following),
        enabled: true,
      ),
      (
        label: 'Active Flows',
        value: (profile.activeFlowsCount ?? 0).toString(),
        onTap: _onActiveFlowsTap,
        enabled: _isViewingOwnProfile,
      ),
      (
        label: 'Flow Events',
        value: (profile.totalFlowEventsCount ?? 0).toString(),
        onTap: null,
        enabled: true,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;
        final spacing = 10.0;
        final columns = compact ? 2 : 4;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final stat in stats)
              SizedBox(
                width: itemWidth,
                child: _buildStatItem(
                  label: stat.label,
                  value: stat.value,
                  onTap: stat.onTap,
                  enabled: stat.enabled,
                  compact: compact,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    VoidCallback? onTap,
    bool enabled = true,
    bool compact = false,
  }) {
    final numberColor = enabled
        ? _profileGoldText
        : _profileGoldBase.withValues(alpha: 0.6);
    final labelColor = enabled
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.35);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: enabled ? 0.34 : 0.22),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: enabled
                  ? _profileGoldMid.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Container(
            constraints: BoxConstraints(minHeight: compact ? 82 : 92),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: TextStyle(
                        color: numberColor,
                        fontSize: compact ? 25 : 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: compact ? 12 : 13,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Route<void> _profileRoute({
    required String userId,
    required bool isMyProfile,
  }) {
    if (!widget.openedFromCalendar) {
      return MaterialPageRoute<void>(
        builder: (_) => ProfilePage(userId: userId, isMyProfile: isMyProfile),
      );
    }

    return PageRouteBuilder<void>(
      pageBuilder: (_, animation, secondaryAnimation) => ProfilePage(
        userId: userId,
        isMyProfile: isMyProfile,
        openedFromCalendar: true,
      ),
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final offset = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(curved);
        return SlideTransition(position: offset, child: child);
      },
    );
  }

  Future<void> _replaceWithProfile(String userId) async {
    if (!mounted || userId == widget.userId) return;
    final myId = Supabase.instance.client.auth.currentUser?.id;
    await Navigator.of(context).pushReplacement(
      _profileRoute(
        userId: userId,
        isMyProfile: myId != null && userId == myId,
      ),
    );
  }

  Widget _buildCalendarRevealSwipeGate() {
    return PageNavigationEdgeSwipe(
      direction: PageNavigationSwipeDirection.leftToRight,
      enabled: !_calendarRevealNavigationInFlight,
      onCommit: () {
        unawaited(_returnToCalendarFromSwipe());
      },
    );
  }

  Future<void> _returnToCalendarFromSwipe() async {
    if (_calendarRevealNavigationInFlight || !mounted) return;

    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;

    _calendarRevealNavigationInFlight = true;
    try {
      await navigator.maybePop();
    } finally {
      _calendarRevealNavigationInFlight = false;
    }
  }

  Future<void> _openFollowList(UserProfile profile, FollowListType type) async {
    final selectedUserId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => FollowListPage(
          userId: profile.id,
          type: type,
          userHandle: profile.handle,
          userDisplayName: profile.effectiveName,
        ),
      ),
    );

    if (!mounted || selectedUserId == null || selectedUserId == widget.userId) {
      return;
    }

    await _replaceWithProfile(selectedUserId);
  }

  void _onActiveFlowsTap() {
    if (!_isViewingOwnProfile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only view your own active flows.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final calendarState = CalendarPage.globalKey.currentState;
    if (calendarState != null) {
      calendarState.openMyFlowsFromOutside();
      return;
    }

    // Fallback: push CalendarPage and ask it to open My Flows on launch.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CalendarPage(openMyFlowsOnLaunch: true),
      ),
    );
  }

  Widget _buildFollowButton() {
    final isFollowing = _isFollowing;
    return _buildActionButton(
      label: isFollowing ? 'Following' : 'Follow',
      icon: isFollowing
          ? Icons.check_circle_outline_rounded
          : Icons.person_add_alt_1_rounded,
      onPressed: _followUpdating ? null : _toggleFollow,
      filled: !isFollowing,
      busy: _followUpdating,
      backgroundColor: isFollowing ? const Color(0xFF0B0B0E) : _profileGoldBase,
      foregroundColor: isFollowing ? _profileGoldText : const Color(0xFF1C1204),
      borderColor: _profileGoldMid,
    );
  }

  Widget _buildEditButton() {
    return _buildActionButton(
      label: 'Edit Profile',
      icon: Icons.edit_outlined,
      onPressed: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditProfilePage(initialProfile: _profile!),
          ),
        );

        if (result == true) {
          await _loadProfile();
        }
      },
      filled: true,
      backgroundColor: _profileGoldBase,
      foregroundColor: const Color(0xFF1C1204),
      borderColor: _profileGoldMid,
    );
  }

  Widget _buildFindPeopleButton() {
    return _buildActionButton(
      label: 'Find People',
      icon: Icons.people_outline_rounded,
      onPressed: () async {
        final selectedUserId = await Navigator.of(context).push<String>(
          MaterialPageRoute(builder: (_) => const ProfileSearchPage()),
        );

        if (!mounted || selectedUserId == null) return;

        if (selectedUserId == widget.userId) {
          await _loadProfile(showSpinner: false);
          return;
        }

        await _replaceWithProfile(selectedUserId);
      },
      foregroundColor: _profileGoldText,
      borderColor: _profileGoldMid.withValues(alpha: 0.42),
    );
  }

  Widget _buildPostFlowButton() {
    return _buildActionButton(
      label: 'Post Flow',
      icon: Icons.upload_rounded,
      onPressed: _openPostPicker,
      foregroundColor: _profileGoldText,
      borderColor: _profileGoldMid.withValues(alpha: 0.42),
    );
  }

  Widget _buildPostInsightButton() {
    return _buildActionButton(
      label: 'Post Insight',
      icon: Icons.auto_stories_outlined,
      onPressed: _openInsightPostPicker,
      foregroundColor: _profileGoldText,
      borderColor: _profileGoldMid.withValues(alpha: 0.42),
    );
  }

  Widget _buildActionCluster() {
    final actions = _isViewingOwnProfile
        ? <Widget>[
            _buildEditButton(),
            _buildFindPeopleButton(),
            _buildPostFlowButton(),
            _buildPostInsightButton(),
          ]
        : <Widget>[_buildFollowButton()];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: actions,
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool filled = false,
    bool busy = false,
    Color foregroundColor = _profileGoldText,
    Color backgroundColor = const Color(0xFF0B0B0E),
    Color borderColor = _profileGoldMid,
  }) {
    final buttonHeight = useExpandedTouchTargets(context)
        ? kMinInteractiveDimension
        : 40.0;

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          )
        else
          Icon(icon, size: 17),
        const SizedBox(width: 8),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    );

    if (filled) {
      final radius = BorderRadius.circular(999);
      final interactive = Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: _profileGoldGradient,
            borderRadius: radius,
            border: Border.all(
              color: _profileGoldLight.withValues(alpha: 0.52),
            ),
            boxShadow: [
              BoxShadow(
                color: _profileGoldDeep.withValues(alpha: 0.34),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: DefaultTextStyle(
                style: TextStyle(color: foregroundColor),
                child: IconTheme(
                  data: IconThemeData(color: foregroundColor),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
      return withMinimumTouchTarget(
        context,
        interactive,
        alignment: Alignment.center,
        fallback: BoxConstraints(minHeight: buttonHeight),
      );
    }

    final radius = BorderRadius.circular(999);
    final interactive = Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: radius,
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: DefaultTextStyle(
              style: TextStyle(color: foregroundColor),
              child: IconTheme(
                data: IconThemeData(color: foregroundColor),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
    return withMinimumTouchTarget(
      context,
      interactive,
      alignment: Alignment.center,
      fallback: BoxConstraints(minHeight: buttonHeight),
    );
  }

  Widget _buildPostsSection() {
    final hasMultiplePosts = _posts.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Posted Flows',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (!_postsLoading && hasMultiplePosts)
              Text(
                '${_activePostIndex + 1} / ${_posts.length}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _buildPostedFlowPreview(),
        const SizedBox(height: 22),
        _buildPostedInsightsSection(),
        const SizedBox(height: 18),
        _buildFeedRevealHint(),
      ],
    );
  }

  Widget _buildPostedInsightsSection() {
    final hasMultiplePosts = _insightPosts.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Posted Insights',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (!_insightPostsLoading && hasMultiplePosts)
              Text(
                '${_activeInsightPostIndex + 1} / ${_insightPosts.length}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _buildPostedInsightPreview(),
      ],
    );
  }

  Widget _buildPostedFlowPreview() {
    if (_postsLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_profileGoldMid),
        ),
      );
    }

    if (_posts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C0F),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _profileGoldMid.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isViewingOwnProfile
                  ? 'Nothing posted yet'
                  : 'No posted flows yet',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isViewingOwnProfile
                  ? 'Post a flow to share it on your profile.'
                  : 'Check back later for posted flows.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final hasMultiplePosts = _posts.length > 1;
    if (!hasMultiplePosts) {
      return _buildPostCard(_posts.first, onTap: () => _openPostDetails(0));
    }

    final pagerHeight = _postPagerHeight(context);
    return Column(
      children: [
        SizedBox(
          height: pagerHeight,
          child: PageView.builder(
            controller: _postPageController,
            physics: const BouncingScrollPhysics(),
            itemCount: _posts.length,
            onPageChanged: (index) {
              setState(() {
                _activePostIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildPostCard(
                  _posts[index],
                  onTap: () => _openPostDetails(index),
                  inPager: true,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < _posts.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _activePostIndex == i ? 18 : 8,
                decoration: BoxDecoration(
                  color: _activePostIndex == i
                      ? _profileGoldMid
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
          ],
        ),
      ],
    );
  }

  double _postPagerHeight(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    double height;
    if (width < 360) {
      height = 336;
    } else if (width < 390) {
      height = 320;
    } else if (width < 430) {
      height = 304;
    } else {
      height = 286;
    }

    if (textScale > 1.05) height += 18;
    if (textScale > 1.15) height += 18;
    return height;
  }

  Widget _buildFeedDateModeToggle() {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleFeedDateMode,
        child: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: GlossyText(
            text: 'ḥꜣw',
            gradient: _showGregorianFeedDates ? whiteGloss : goldGloss,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              letterSpacing: 0,
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
          ),
        ),
      ),
    );
  }

  Widget _buildPostedInsightPreview() {
    if (_insightPostsLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_profileGoldMid),
        ),
      );
    }

    if (_insightPosts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C0F),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _profileGoldMid.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'No posted insights yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isViewingOwnProfile
                  ? 'Write an insight inside a node page, then post it here.'
                  : 'Check back later for posted insights.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final hasMultiplePosts = _insightPosts.length > 1;
    if (!hasMultiplePosts) {
      return _buildInsightPostCard(
        _insightPosts.first,
        onReadMore: () => _openInsightPost(_insightPosts.first),
      );
    }

    final pagerHeight = _postPagerHeight(context);
    return Column(
      children: [
        SizedBox(
          height: pagerHeight,
          child: PageView.builder(
            controller: _insightPostPageController,
            physics: const BouncingScrollPhysics(),
            itemCount: _insightPosts.length,
            onPageChanged: (index) {
              setState(() {
                _activeInsightPostIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final post = _insightPosts[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildInsightPostCard(
                  post,
                  onReadMore: () => _openInsightPost(post),
                  inPager: true,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < _insightPosts.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _activeInsightPostIndex == i ? 18 : 8,
                decoration: BoxDecoration(
                  color: _activeInsightPostIndex == i
                      ? _profileGoldMid
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeedRevealHint() {
    return GestureDetector(
      key: _feedRevealHintKey,
      onTap: () {
        unawaited(_revealFeed());
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Icon(
              Icons.keyboard_arrow_up_rounded,
              color: _profileGoldText.withValues(alpha: 0.8),
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              'Swipe up to reveal feed',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedHeader() {
    return AnimatedBuilder(
      animation: _feedBloomController,
      builder: (context, child) {
        final opacity = Curves.easeOutCubic.transform(
          _feedBloomController.value.clamp(0.0, 1.0),
        );
        final y = (1 - opacity) * 18;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(offset: Offset(0, y), child: child),
        );
      },
      child: Column(
        key: const ValueKey('feed_header'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _profileGoldTextWidget(
            'Community Feed',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Flows and insights from the people you follow, plus the wider field.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 13,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _profileGoldText.withValues(alpha: 0.8),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'Pull down at the top to return to profile',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.54),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedBloomPanel() {
    final opacityCurve = CurvedAnimation(
      parent: _feedBloomController,
      curve: const Interval(0.0, 0.78, curve: Curves.easeOutCubic),
    );
    final scaleCurve = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.92,
          end: 1.035,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 44,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.035,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 56,
      ),
    ]).animate(_feedBloomController);

    final panelChild = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -92,
          left: -28,
          right: -28,
          height: 220,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _feedBloomController,
              builder: (context, child) {
                final scale = 0.84 + (_feedBloomController.value * 0.44);
                return Transform.scale(scale: scale, child: child);
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.25,
                    colors: [
                      _profileGoldLight.withValues(alpha: 0.22),
                      _profileGoldMid.withValues(alpha: 0.14),
                      _profileGoldDeep.withValues(alpha: 0.09),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.34, 0.58, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.26),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _profileGoldMid.withValues(alpha: 0.26)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 24,
                spreadRadius: 1,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_feedLoading && _feedItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _profileGoldMid,
                      ),
                    ),
                  ),
                )
              else if (_feedItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      Icon(
                        Icons.auto_awesome_motion_rounded,
                        color: _profileGoldText.withValues(alpha: 0.72),
                        size: 28,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'No feed posts available yet',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'As more flows and insights get posted, they will surface here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.58),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              else
                _buildFeedGrid(_feedItems),
              if (_feedLoadingMore) ...[
                const SizedBox(height: 12),
                const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _profileGoldMid,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return AnimatedBuilder(
      animation: _feedBloomController,
      builder: (context, child) {
        final opacity = opacityCurve.value.clamp(0.0, 1.0);
        final y = (1 - opacity) * 28;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, y),
            child: Transform.scale(
              scale: scaleCurve.value,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
      child: panelChild,
    );
  }

  Widget _buildFeedGrid(List<ProfileFeedItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = (constraints.maxWidth - _profileFeedColumnGap) / 2;
        final (left, right) = _splitFeedItems(items, columnWidth);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildFeedColumn(left)),
            const SizedBox(width: _profileFeedColumnGap),
            Expanded(child: _buildFeedColumn(right)),
          ],
        );
      },
    );
  }

  Widget _buildFeedColumn(List<ProfileFeedItem> items) {
    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _buildFeedItemTile(items[i]),
          if (i != items.length - 1)
            const SizedBox(height: _profileFeedColumnGap),
        ],
      ],
    );
  }

  (List<ProfileFeedItem>, List<ProfileFeedItem>) _splitFeedItems(
    List<ProfileFeedItem> items,
    double columnWidth,
  ) {
    final left = <ProfileFeedItem>[];
    final right = <ProfileFeedItem>[];
    var leftHeight = 0.0;
    var rightHeight = 0.0;

    for (final item in items) {
      final estimatedHeight = _estimateFeedTileHeight(item, columnWidth);
      if (leftHeight <= rightHeight) {
        left.add(item);
        leftHeight += estimatedHeight + _profileFeedColumnGap;
      } else {
        right.add(item);
        rightHeight += estimatedHeight + _profileFeedColumnGap;
      }
    }

    return (left, right);
  }

  double _estimateFeedTileHeight(ProfileFeedItem item, double cardWidth) {
    if (item.kind == ProfileFeedItemKind.insight) {
      return _estimateInsightFeedTileHeight(item.insightPost!, cardWidth);
    }
    final post = item.flowPost!;
    final direction = Directionality.of(context);
    final title = cleanFlowTitle(post.name);
    final titlePainter = TextPainter(
      text: TextSpan(
        text: title.isEmpty ? 'Untitled Flow' : title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.08,
        ),
      ),
      maxLines: 6,
      textDirection: direction,
    )..layout(maxWidth: math.max(0, cardWidth - 28));
    return 214 + titlePainter.size.height;
  }

  double _estimateInsightFeedTileHeight(InsightPost post, double cardWidth) {
    final direction = Directionality.of(context);
    final headingPainter = TextPainter(
      text: TextSpan(
        text: post.nodeTitle,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.08,
        ),
      ),
      maxLines: 4,
      textDirection: direction,
    )..layout(maxWidth: math.max(0, cardWidth - 28));
    final bodyPainter = TextPainter(
      text: TextSpan(
        text: _insightPreviewText(post.bodyText),
        style: const TextStyle(fontSize: 14, height: 1.35),
      ),
      maxLines: 7,
      ellipsis: '…',
      textDirection: direction,
    )..layout(maxWidth: math.max(0, cardWidth - 28));
    return 248 + headingPainter.size.height + bodyPainter.size.height;
  }

  Widget _buildFeedItemTile(ProfileFeedItem item) {
    switch (item.kind) {
      case ProfileFeedItemKind.flow:
        return _buildFeedFlowTile(item.flowPost!);
      case ProfileFeedItemKind.insight:
        return _buildFeedInsightTile(item.insightPost!);
    }
  }

  Widget _buildFeedFlowTile(FlowPost post) {
    final accent = Color(0xFF000000 | (post.color & 0x00FFFFFF));
    final title = cleanFlowTitle(post.name);
    final label = _ownsPost(post)
        ? 'Your Flow'
        : post.isFollowingAuthor
        ? 'Following'
        : 'Community';
    final authorHandle = post.authorHandle?.trim();
    final authorDisplayName = post.authorDisplayName?.trim();
    final showHandle =
        authorHandle != null &&
        authorHandle.isNotEmpty &&
        authorDisplayName != null &&
        authorDisplayName.isNotEmpty &&
        authorHandle.toLowerCase() != authorDisplayName.toLowerCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _profileGoldMid.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              onTap: () => _openFeedPost(post),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: glossFromColor(post.color),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: TextStyle(
                              color: accent.withValues(alpha: 0.95),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ProfileAvatar(
                          displayName: post.authorLabel,
                          avatarUrl: post.authorAvatarUrl,
                          avatarGlyphIds: post.authorAvatarGlyphIds,
                          radius: 14,
                          foregroundColor: _profileGoldText,
                          backgroundColor: const Color(0xFF111115),
                          borderColor: _profileGoldMid.withValues(alpha: 0.24),
                          borderWidth: 1,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.authorLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (showHandle)
                                Text(
                                  '@$authorHandle',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.56),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _profileGoldTextWidget(
                      title.isEmpty ? 'Untitled Flow' : title,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 14,
                          color: _postDateIconColor(0.42),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Posted ${_formatPostDate(post.createdAt, compact: true)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _postDateTextColor(0.54),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.north_east_rounded,
                          size: 18,
                          color: _profileGoldText.withValues(alpha: 0.86),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: FlowPostEngagementRow(
                key: ValueKey('feed_${post.id}'),
                post: post,
                lazyComments: true,
                compact: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedInsightTile(InsightPost post) {
    final label = _ownsInsightPost(post)
        ? 'Your Insight'
        : post.isFollowingAuthor
        ? 'Following'
        : 'Community';
    final authorHandle = post.authorHandle?.trim();
    final authorDisplayName = post.authorDisplayName?.trim();
    final showHandle =
        authorHandle != null &&
        authorHandle.isNotEmpty &&
        authorDisplayName != null &&
        authorDisplayName.isNotEmpty &&
        authorHandle.toLowerCase() != authorDisplayName.toLowerCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _profileGoldMid.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _profileGoldBase.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _profileGoldMid.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: _profileGoldText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ProfileAvatar(
                    displayName: post.authorLabel,
                    avatarUrl: post.authorAvatarUrl,
                    avatarGlyphIds: post.authorAvatarGlyphIds,
                    radius: 14,
                    foregroundColor: _profileGoldText,
                    backgroundColor: const Color(0xFF111115),
                    borderColor: _profileGoldMid.withValues(alpha: 0.24),
                    borderWidth: 1,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (showHandle)
                          Text(
                            '@$authorHandle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.56),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((post.nodeGlyph?.trim().isNotEmpty ?? false))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        post.nodeGlyph!,
                        style: const TextStyle(
                          color: _profileGoldText,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Expanded(
                    child: _profileGoldTextWidget(
                      post.nodeTitle,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.08,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _insightPreviewText(post.bodyText),
                maxLines: 7,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Dated ${_formatPostDate(post.entryDate, compact: true)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _postDateTextColor(0.56),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Posted ${_formatPostDate(post.createdAt, compact: true)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _postDateTextColor(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _openInsightPost(post),
                  child: _profileGoldTextWidget(
                    'Read more',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostCard(
    FlowPost post, {
    required VoidCallback onTap,
    bool inPager = false,
  }) {
    final title = cleanFlowTitle(post.name);
    final overview = cleanFlowOverview(post.notes);
    final accent = Color(0xFF000000 | (post.color & 0x00FFFFFF));
    final headerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: glossFromColor(post.color),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Posted Flow',
                style: TextStyle(
                  color: accent.withValues(alpha: 0.95),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _profileGoldTextWidget(
          title.isEmpty ? 'Untitled Flow' : title,
          maxLines: inPager ? 4 : 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              Icons.schedule_outlined,
              size: 16,
              color: _postDateIconColor(0.42),
            ),
            const SizedBox(width: 8),
            Text(
              'Posted ${_formatPostDate(post.createdAt)}',
              style: TextStyle(
                color: _postDateTextColor(0.54),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (overview.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            overview,
            maxLines: inPager ? 4 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.22,
            ),
          ),
        ],
      ],
    );

    final fixedActions = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
          child: FlowPostEngagementRow(post: post),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_isViewingOwnProfile)
                TextButton.icon(
                  onPressed: () => _removePost(post.id),
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  label: const Text(
                    'Remove',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () => _savePost(post),
                  icon: _profileGoldIcon(Icons.bookmark_add_outlined),
                  label: _profileGoldTextWidget(
                    'Save Flow',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              TextButton(
                onPressed: onTap,
                child: _profileGoldTextWidget(
                  'Open',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final card = Container(
      margin: EdgeInsets.only(bottom: inPager ? 0 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _profileGoldMid.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: inPager ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (inPager)
              Expanded(
                child: InkWell(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  onTap: onTap,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                    child: headerContent,
                  ),
                ),
              )
            else
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                  child: headerContent,
                ),
              ),
            fixedActions,
          ],
        ),
      ),
    );
    if (!inPager) return card;
    return SizedBox.expand(child: card);
  }

  Widget _buildInsightPostCard(
    InsightPost post, {
    required VoidCallback onReadMore,
    bool inPager = false,
  }) {
    final headerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _profileGoldBase.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _profileGoldMid.withValues(alpha: 0.28)),
          ),
          child: Text(
            'Posted Insight',
            style: TextStyle(
              color: _profileGoldText.withValues(alpha: 0.96),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((post.nodeGlyph?.trim().isNotEmpty ?? false))
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  post.nodeGlyph!,
                  style: const TextStyle(
                    color: _profileGoldText,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Expanded(
              child: _profileGoldTextWidget(
                post.nodeTitle,
                maxLines: inPager ? 3 : 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Dated ${_formatPostDate(post.entryDate)}',
          style: TextStyle(
            color: _postDateTextColor(0.58),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _insightPreviewText(post.bodyText),
          maxLines: inPager ? 9 : 6,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Posted ${_formatPostDate(post.createdAt)}',
          style: TextStyle(
            color: _postDateTextColor(0.5),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    final fixedActions = Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (_isViewingOwnProfile)
              TextButton.icon(
                onPressed: () => _removeInsightPost(post.id),
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.redAccent,
                  size: 18,
                ),
                label: const Text(
                  'Remove',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            TextButton(
              onPressed: onReadMore,
              child: _profileGoldTextWidget(
                'Read more',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final card = Container(
      margin: EdgeInsets.only(bottom: inPager ? 0 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _profileGoldMid.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: inPager ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (inPager)
              Expanded(
                child: InkWell(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  onTap: onReadMore,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                    child: headerContent,
                  ),
                ),
              )
            else
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onReadMore,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                  child: headerContent,
                ),
              ),
            fixedActions,
          ],
        ),
      ),
    );
    if (!inPager) return card;
    return SizedBox.expand(child: card);
  }

  Future<void> _openFeedPost(FlowPost post) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            FlowPostDetailPage(post: post, isOwner: _ownsPost(post)),
      ),
    );
    if (changed == true) {
      await _reloadPostedContent();
      if (_feedRevealed) {
        await _loadFeedPage(reset: true);
      }
    }
  }

  Future<void> _openInsightPost(InsightPost post) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            InsightPostDetailPage(post: post, isOwner: _ownsInsightPost(post)),
      ),
    );
    if (changed == true) {
      await _loadInsightPosts();
      if (_feedRevealed) {
        await _loadFeedPage(reset: true);
      }
    }
  }

  bool get _useGregorianPostDates => _feedRevealed && _showGregorianFeedDates;

  Color _postDateTextColor(double alpha) {
    final base = _useGregorianPostDates
        ? _profileGregorianBlueLight
        : Colors.white;
    return base.withValues(alpha: alpha);
  }

  Color _postDateIconColor(double alpha) {
    final base = _useGregorianPostDates ? _profileGregorianBlue : Colors.white;
    return base.withValues(alpha: alpha);
  }

  String _formatPostDate(DateTime date, {bool compact = false}) {
    if (!_useGregorianPostDates) {
      return formatKemeticDate(date, includeGregorianYear: !compact);
    }

    final local = date.toLocal();
    const shortMonths = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = shortMonths[local.month - 1];
    if (compact) {
      return '$month ${local.day}';
    }
    return '$month ${local.day}, ${local.year}';
  }

  String _insightPreviewText(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? 'Untitled insight' : normalized;
  }

  Future<void> _openPostDetails(int initialIndex) async {
    final post = _posts[initialIndex];
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FlowPostDetailPage(
          post: post,
          posts: _posts,
          initialIndex: initialIndex,
          isOwner: _isViewingOwnProfile,
        ),
      ),
    );
    if (changed == true) {
      await _loadPosts();
    }
  }

  Future<void> _openPostPicker() async {
    final posted = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const FlowPostPickerPage()));
    if (posted == true) {
      await _loadPosts();
    }
  }

  Future<void> _openInsightPostPicker() async {
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const InsightPostPickerPage()),
    );
    if (posted == true) {
      await _loadInsightPosts();
    }
  }

  Future<void> _savePost(FlowPost post) async {
    final flowId = await _repo.saveFlowPostToMyFlows(post);
    if (!mounted) return;
    if (flowId == null) {
      _showError('Could not save this flow.');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Flow saved to your flows'),
        backgroundColor: _profileGoldBase,
      ),
    );
  }

  Future<void> _removePost(String postId) async {
    final ok = await _repo.deleteFlowPost(postId);
    if (!mounted) return;
    if (!ok) {
      _showError('Unable to remove post. Please try again.');
      return;
    }
    await _loadPosts();
  }

  Future<void> _removeInsightPost(String postId) async {
    final ok = await _repo.deleteInsightPost(postId);
    if (!mounted) return;
    if (!ok) {
      _showError('Unable to remove insight. Please try again.');
      return;
    }
    await _loadInsightPosts();
  }
}

class _ProfileBackdrop extends StatefulWidget {
  const _ProfileBackdrop();

  @override
  State<_ProfileBackdrop> createState() => _ProfileBackdropState();
}

class _ProfileBackdropState extends State<_ProfileBackdrop>
    with WidgetsBindingObserver {
  static const Alignment _heroImageAlignment = Alignment(-0.08, -1.0);
  static const double _heroImageOpacity = 0.9;
  static const int _backdropSourceWidth = 1672;

  final Set<String> _precachedAssets = <String>{};
  Timer? _tickTimer;
  DateTime _visibleNow = profileBackdropPhoneLocalNow();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleNextTick();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _primeAssets(ProfileBackdropBlend.forTime(_visibleNow));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tickTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    _refreshVisibleTime();
  }

  void _primeAssets(ProfileBackdropBlend blend) {
    final assetsToPrime = <String>[
      for (final assetPath in {blend.current.assetPath, blend.next.assetPath})
        if (_precachedAssets.add(assetPath)) assetPath,
    ];
    if (assetsToPrime.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final assetPath in assetsToPrime) {
        unawaited(precacheImage(_backdropImageProvider(assetPath), context));
      }
    });
  }

  ImageProvider<Object> _backdropImageProvider(String assetPath) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final devicePixelRatio = mediaQuery?.devicePixelRatio ?? 1.0;
    final logicalWidth = mediaQuery?.size.width ?? 1024.0;
    final targetWidth = math.min(
      _backdropSourceWidth,
      math.max(1, (logicalWidth * devicePixelRatio).round()),
    );
    return ResizeImage.resizeIfNeeded(targetWidth, null, AssetImage(assetPath));
  }

  void _refreshVisibleTime() {
    final now = profileBackdropPhoneLocalNow();
    _primeAssets(ProfileBackdropBlend.forTime(now));
    setState(() {
      _visibleNow = now;
    });
    _scheduleNextTick();
  }

  void _scheduleNextTick() {
    _tickTimer?.cancel();
    final now = profileBackdropPhoneLocalNow();
    _tickTimer = Timer(profileBackdropDelayUntilNextFrameChange(now), () {
      if (!mounted) return;
      _refreshVisibleTime();
    });
  }

  Widget _buildBackdropImage(String assetPath) {
    return Image(
      image: _backdropImageProvider(assetPath),
      fit: BoxFit.cover,
      alignment: _heroImageAlignment,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      errorBuilder: (context, error, stackTrace) =>
          const CustomPaint(painter: _ProfileBackdropPainter()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blend = ProfileBackdropBlend.forTime(_visibleNow);
    _primeAssets(blend);

    return RepaintBoundary(
      child: SizedBox.expand(
        child: Opacity(
          opacity: _heroImageOpacity,
          // These hourly plates are not pixel-registered enough for a live
          // crossfade; blending them creates doubled landmarks in-app.
          child: _buildBackdropImage(blend.current.assetPath),
        ),
      ),
    );
  }
}

class _ProfileBackdropPainter extends CustomPainter {
  const _ProfileBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF04070E), Color(0xFF070A10), Color(0xFF070707)],
          stops: [0.0, 0.6, 1.0],
        ).createShader(bounds),
    );

    _paintMilkyWay(canvas, size);
    _paintStars(canvas, size);
    _paintGround(canvas, size);
    _paintPyramid(canvas, size);
    _paintStructures(canvas, size);
  }

  void _paintMilkyWay(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.52, size.height * 0.24);
    final rect = Rect.fromCenter(
      center: center,
      width: size.width * 0.34,
      height: size.height * 0.98,
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.18);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0x90D5E5FF),
            const Color(0x5093A8D6),
            Colors.transparent,
          ],
          stops: const [0.0, 0.24, 1.0],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );
    final coreRect = Rect.fromCenter(
      center: center,
      width: size.width * 0.11,
      height: size.height * 1.04,
    );
    canvas.drawOval(
      coreRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0x88FAFCFF),
            const Color(0x44C5D2F0),
            Colors.transparent,
          ],
          stops: const [0.0, 0.3, 1.0],
        ).createShader(coreRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );
    canvas.restore();

    final random = math.Random(11);
    const bandStart = Offset(0.42, 0.0);
    const bandEnd = Offset(0.61, 0.74);
    for (var i = 0; i < 180; i++) {
      final t = random.nextDouble();
      final centerPoint = Offset(
        size.width * (bandStart.dx + ((bandEnd.dx - bandStart.dx) * t)),
        size.height * (bandStart.dy + ((bandEnd.dy - bandStart.dy) * t)),
      );
      final offset = Offset(
        (random.nextDouble() - 0.5) * size.width * 0.14,
        (random.nextDouble() - 0.5) * size.height * 0.04,
      );
      final radius = 0.6 + (random.nextDouble() * 1.7);
      final alpha = 0.08 + (random.nextDouble() * 0.16);
      canvas.drawCircle(
        centerPoint + offset,
        radius,
        Paint()..color = const Color(0xFFE6EEFF).withValues(alpha: alpha),
      );
    }
  }

  void _paintStars(Canvas canvas, Size size) {
    final random = math.Random(23);
    final bigStarPaint = Paint()
      ..color = const Color(0xFFF7FBFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (var i = 0; i < 420; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height * 0.72;
      final radius = random.nextDouble() < 0.08
          ? 1.8 + (random.nextDouble() * 1.6)
          : 0.45 + (random.nextDouble() * 1.2);
      final blueShift = random.nextDouble();
      final color = blueShift < 0.18
          ? const Color(0xFF8FB7FF)
          : const Color(0xFFF6F7FF);
      final alpha = 0.28 + (random.nextDouble() * 0.65);
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = color.withValues(alpha: alpha),
      );
      if (radius > 2.4) {
        canvas.drawCircle(Offset(x, y), radius + 1.4, bigStarPaint);
      }
    }
  }

  void _paintGround(Canvas canvas, Size size) {
    final horizonY = size.height * 0.73;
    final vanishingPoint = Offset(size.width * 0.62, size.height * 0.74);
    final groundPath = Path()
      ..moveTo(0, horizonY)
      ..lineTo(size.width, horizonY + (size.height * 0.03))
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      groundPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF24272D).withValues(alpha: 0.82),
            const Color(0xFF111214).withValues(alpha: 0.96),
            const Color(0xFF060606),
          ],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipPath(groundPath);
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..strokeWidth = 1.0;
    for (final x in <double>[
      -size.width * 0.05,
      size.width * 0.14,
      size.width * 0.29,
      size.width * 0.45,
      size.width * 0.68,
      size.width * 0.9,
    ]) {
      canvas.drawLine(Offset(x, size.height), vanishingPoint, linePaint);
    }
    for (var i = 0; i < 6; i++) {
      final y = horizonY + ((size.height * 0.04) * i * 1.4);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y + ((size.height * 0.02) * i * 0.2)),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.06)
          ..strokeWidth = 1.0,
      );
    }
    canvas.restore();
  }

  void _paintPyramid(Canvas canvas, Size size) {
    final apex = Offset(size.width * 0.17, size.height * 0.05);
    final ridgeBase = Offset(size.width * 0.28, size.height * 0.79);
    final litBase = Offset(size.width * 0.58, size.height * 0.76);
    final leftShadowBase = Offset(-size.width * 0.02, size.height * 0.87);
    final leftShadowTop = Offset(-size.width * 0.02, size.height * 0.24);

    final shadowFace = Path()
      ..moveTo(leftShadowTop.dx, leftShadowTop.dy)
      ..lineTo(apex.dx, apex.dy)
      ..lineTo(ridgeBase.dx, ridgeBase.dy)
      ..lineTo(leftShadowBase.dx, leftShadowBase.dy)
      ..close();
    canvas.drawPath(
      shadowFace,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            const Color(0xFF111418),
            const Color(0xFF090A0D),
            const Color(0xFF040404),
          ],
        ).createShader(Offset.zero & size),
    );

    final litFace = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(litBase.dx, litBase.dy)
      ..lineTo(ridgeBase.dx, ridgeBase.dy)
      ..close();
    canvas.drawPath(
      litFace,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFB8B6B1),
            const Color(0xFF7D7E80),
            const Color(0xFF4F5255),
          ],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipPath(litFace);
    final seamPaint = Paint()
      ..color = const Color(0xFF2B2D31).withValues(alpha: 0.34)
      ..strokeWidth = 0.9;
    for (var i = 0; i < 32; i++) {
      final y = (size.height * 0.12) + (i * size.height * 0.023);
      canvas.drawLine(
        Offset(size.width * 0.14, y),
        Offset(size.width * 0.61, y - (size.height * 0.018)),
        seamPaint,
      );
    }
    for (var i = 0; i < 7; i++) {
      final x = (size.width * 0.24) + (i * size.width * 0.045);
      canvas.drawLine(
        Offset(x, size.height * 0.15),
        Offset(x + (size.width * 0.02), size.height * 0.79),
        Paint()
          ..color = const Color(0xFF34373A).withValues(alpha: 0.12)
          ..strokeWidth = 0.8,
      );
    }
    canvas.restore();

    canvas.drawPath(
      litFace,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawLine(
      apex,
      ridgeBase,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.14)
        ..strokeWidth = 1.2,
    );
  }

  void _paintStructures(Canvas canvas, Size size) {
    final structurePaint = Paint()
      ..color = const Color(0xFF23262A).withValues(alpha: 0.82);
    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final temple = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.53,
        size.height * 0.68,
        size.width * 0.08,
        size.height * 0.12,
      ),
      const Radius.circular(1),
    );
    canvas.drawRRect(temple, structurePaint);
    canvas.drawRRect(temple, edgePaint);

    final rightMass = Path()
      ..moveTo(size.width * 0.72, size.height * 0.76)
      ..lineTo(size.width, size.height * 0.79)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.64, size.height)
      ..close();
    canvas.drawPath(
      rightMass,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF2A2E33).withValues(alpha: 0.55),
            const Color(0xFF0B0C0D),
          ],
        ).createShader(Offset.zero & size),
    );

    for (final rect in <Rect>[
      Rect.fromLTWH(
        size.width * 0.79,
        size.height * 0.73,
        size.width * 0.055,
        size.height * 0.045,
      ),
      Rect.fromLTWH(
        size.width * 0.89,
        size.height * 0.74,
        size.width * 0.07,
        size.height * 0.038,
      ),
    ]) {
      canvas.drawRect(
        rect,
        Paint()..color = const Color(0xFF27292C).withValues(alpha: 0.76),
      );
      canvas.drawRect(rect, edgePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProfileBackdropPainter oldDelegate) {
    return false;
  }
}
