// lib/features/profile/profile_page.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/core/page_navigation_swipe.dart';
import 'package:mobile/core/touch_targets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/profile_avatar_glyphs.dart';
import '../../data/profile_model.dart';
import '../../data/profile_repo.dart';
import '../../data/flow_post_model.dart';
import '../../utils/detail_sanitizer.dart';
import '../../widgets/profile_avatar.dart';
import 'edit_profile_page.dart';
import 'profile_search_page.dart';
import 'flow_post_picker_page.dart';
import 'flow_post_detail_page.dart';
import '_post_glossy_helper.dart';
import 'follow_list_page.dart';
import '../calendar/calendar_page.dart';
import 'flow_post_engagement_row.dart';
import 'package:mobile/shared/glossy_text.dart';
import '../../widgets/inbox_icon_with_badge.dart';

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

class _ProfilePageState extends State<ProfilePage> {
  final _repo = ProfileRepo(Supabase.instance.client);
  late final PageController _postPageController;
  UserProfile? _profile;
  bool _loading = true;
  bool _isFollowing = false;
  bool _followUpdating = false;
  List<FlowPost> _posts = const [];
  bool _postsLoading = true;
  int _activePostIndex = 0;
  bool _calendarRevealNavigationInFlight = false;

  bool get _isViewingOwnProfile {
    final currentId = Supabase.instance.client.auth.currentUser?.id;
    return widget.isMyProfile ||
        (currentId != null && currentId == widget.userId);
  }

  @override
  void initState() {
    super.initState();
    _postPageController = PageController(viewportFraction: 0.96);
    _loadProfile();
  }

  @override
  void dispose() {
    _postPageController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() => _loading = true);
    }

    final profileFuture = _repo.getProfile(widget.userId);
    final followFuture = _isViewingOwnProfile
        ? Future<bool>.value(false)
        : _repo.isFollowing(widget.userId);

    final profile = await profileFuture;
    final isFollowing = await followFuture;

    UserProfile? adjusted = profile;
    if (profile != null) {
      final counts = await _repo.computeFlowCountsForUser(widget.userId);
      adjusted = profile.copyWith(
        activeFlowsCount: counts.$1,
        totalFlowEventsCount: counts.$2,
      );
    }
    if (mounted) {
      setState(() {
        _profile = adjusted;
        _isFollowing = isFollowing;
        _loading = false;
      });
      _loadPosts();
    }
  }

  Future<void> _loadPosts() async {
    setState(() => _postsLoading = true);
    final posts = await _repo.getFlowPosts(widget.userId);
    if (!mounted) return;
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
  }

  int _clampPostIndex(int length, [int? desired]) {
    if (length == 0) return 0;
    final target = desired ?? _activePostIndex;
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
    final body = _loading
        ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(KemeticGold.base),
            ),
          )
        : _profile == null
        ? _buildNoProfile()
        : _buildProfile();

    return Scaffold(
      backgroundColor: const Color(0xFF000000), // True black
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.openedFromCalendarSwipe
            ? null
            : IconButton(
                icon: KemeticGold.icon(Icons.close), // Gold
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          _profile?.handle ?? 'Profile',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New note',
            icon: const GlossyIcon(icon: Icons.add, gradient: goldGloss),
            onPressed: () {
              unawaited(_openCalendarQuickAdd());
            },
          ),
          IconButton(
            tooltip: 'Today',
            icon: const GlossyIcon(icon: Icons.today, gradient: goldGloss),
            onPressed: () => CalendarPage.openMainCalendarAtToday(context),
          ),
          Builder(
            builder: (btnCtx) => IconButton(
              tooltip: 'Menu',
              icon: const InboxUnreadDotOverlay(
                child: GlossyIcon(icon: Icons.apps, gradient: goldGloss),
              ),
              onPressed: () => _openCalendarMenu(btnCtx),
            ),
          ),
          if (!_isViewingOwnProfile)
            IconButton(
              tooltip: 'My Profile',
              icon: const GlossyIcon(icon: Icons.person, gradient: goldGloss),
              onPressed: _openMyProfileAction,
            ),
        ],
      ),
      body: Stack(
        children: [
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar
          _buildAvatar(profile),
          const SizedBox(height: 24),

          // Display name / Handle
          Text(
            profile.effectiveName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (profile.handle != null) ...[
            const SizedBox(height: 4),
            Text(
              '@${profile.handle}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 15,
              ),
            ),
          ],
          if (profile.avatarGlyphIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              profileGlyphPhraseGlyphs(profile.avatarGlyphIds),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: KemeticGold.base,
                fontSize: 16,
                fontWeight: FontWeight.w600,
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
            const SizedBox(height: 4),
            Text(
              profileGlyphPhraseMeaning(profile.avatarGlyphIds),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ],

          // Bio
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              profile.bio!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],

          // Stats
          const SizedBox(height: 32),
          _buildStats(profile),

          if (!_isViewingOwnProfile) ...[
            const SizedBox(height: 24),
            _buildFollowButton(),
          ],

          // Edit/find buttons (only for own profile)
          if (_isViewingOwnProfile) ...[
            const SizedBox(height: 24),
            _buildEditButton(),
            const SizedBox(height: 12),
            _buildFindPeopleButton(),
            const SizedBox(height: 24),
            _buildPostFlowButton(),
          ],

          const SizedBox(height: 24),
          _buildPostsSection(),
        ],
      ),
    );
  }

  Widget _buildAvatar(UserProfile profile) {
    return ProfileAvatar(
      radius: 50,
      displayName: profile.effectiveName,
      avatarUrl: profile.avatarUrl,
      avatarGlyphIds: profile.avatarGlyphIds,
      borderColor: KemeticGold.base,
      borderWidth: 2,
      foregroundColor: KemeticGold.base,
      backgroundColor: const Color(0xFF0D0D0F),
      maxInitialCharacters: 1,
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
        final compact = constraints.maxWidth < 360;
        final spacing = compact ? 8.0 : 16.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < stats.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              Expanded(
                child: _buildStatItem(
                  label: stats[i].label,
                  value: stats[i].value,
                  onTap: stats[i].onTap,
                  enabled: stats[i].enabled,
                  compact: compact,
                ),
              ),
            ],
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
        ? KemeticGold.base
        : KemeticGold.base.withValues(alpha: 0.6);
    final labelColor = enabled
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.35);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: withMinimumTouchTarget(
          context,
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 0 : 4,
              vertical: 4,
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: TextStyle(
                        color: numberColor,
                        fontSize: compact ? 22 : 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: labelColor,
                        fontSize: compact ? 12 : 13,
                      ),
                    ),
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
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _followUpdating ? null : _toggleFollow,
        style: ElevatedButton.styleFrom(
          backgroundColor: isFollowing ? Colors.black : KemeticGold.base,
          foregroundColor: isFollowing ? Colors.white : const Color(0xFF000000),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: KemeticGold.base,
              width: isFollowing ? 1.5 : 0,
            ),
          ),
        ),
        child: _followUpdating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(KemeticGold.base),
                ),
              )
            : Text(
                isFollowing ? 'Unfollow' : 'Follow',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildEditButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          // Navigate to edit profile page
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditProfilePage(initialProfile: _profile!),
            ),
          );

          // Reload profile data if updated
          if (result == true) {
            await _loadProfile();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: KemeticGold.base, // Gold
          foregroundColor: const Color(0xFF000000), // Black text
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Edit Profile',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildFindPeopleButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
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
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: KemeticGold.base),
          foregroundColor: KemeticGold.base,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: KemeticGold.text(
          'Find People',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildPostFlowButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: KemeticGold.icon(Icons.upload),
        label: KemeticGold.text(
          'Post a Flow',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: KemeticGold.base),
          foregroundColor: KemeticGold.base,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _openPostPicker,
      ),
    );
  }

  Widget _buildPostsSection() {
    if (_postsLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(KemeticGold.base),
        ),
      );
    }

    if (_posts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isViewingOwnProfile ? 'Nothing posted yet' : 'No posted flows yet',
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
      );
    }

    final hasMultiplePosts = _posts.length > 1;
    final pagerHeight = _postPagerHeight(context);
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
            if (hasMultiplePosts)
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
        if (!hasMultiplePosts)
          _buildPostCard(_posts.first, onTap: () => _openPostDetails(0))
        else ...[
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
                        ? KemeticGold.base
                        : Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Swipe left or right to browse posted flows.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.54),
              fontSize: 12,
            ),
          ),
        ],
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
        KemeticGold.text(
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
              color: Colors.white.withValues(alpha: 0.42),
            ),
            const SizedBox(width: 8),
            Text(
              'Posted ${_formatDate(post.createdAt)}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.54),
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
                  icon: KemeticGold.icon(Icons.bookmark_add_outlined),
                  label: KemeticGold.text(
                    'Save Flow',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              TextButton(
                onPressed: onTap,
                child: KemeticGold.text(
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
        border: Border.all(color: KemeticGold.base.withValues(alpha: 0.42)),
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

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
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
        backgroundColor: KemeticGold.base,
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
}
