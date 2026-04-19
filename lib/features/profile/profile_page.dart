// lib/features/profile/profile_page.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/profile_model.dart';
import '../../data/profile_repo.dart';
import '../../data/flow_post_model.dart';
import '../../utils/detail_sanitizer.dart';
import 'edit_profile_page.dart';
import 'profile_search_page.dart';
import 'flow_post_picker_page.dart';
import 'flow_post_detail_page.dart';
import '_post_glossy_helper.dart';
import 'follow_list_page.dart';
import '../calendar/calendar_page.dart';
import 'flow_post_engagement_row.dart';
import 'package:mobile/shared/glossy_text.dart';

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
  UserProfile? _profile;
  bool _loading = true;
  bool _isFollowing = false;
  bool _followUpdating = false;
  List<FlowPost> _posts = const [];
  bool _postsLoading = true;
  bool _calendarRevealNavigationInFlight = false;
  double _calendarRevealSwipeAccum = 0.0;

  bool get _isViewingOwnProfile {
    final currentId = Supabase.instance.client.auth.currentUser?.id;
    return widget.isMyProfile ||
        (currentId != null && currentId == widget.userId);
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
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
    setState(() {
      _posts = posts;
      _postsLoading = false;
    });
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
      await calendarState.showActionsMenuFromOutside(context);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calendar actions are unavailable right now.'),
      ),
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
          Builder(
            builder: (btnCtx) => IconButton(
              tooltip: 'Menu',
              icon: const GlossyIcon(icon: Icons.apps, gradient: goldGloss),
              onPressed: () => _openCalendarMenu(btnCtx),
            ),
          ),
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
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0D0D0F), // Dark surface
        border: Border.all(
          color: KemeticGold.base, // Gold border
          width: 2,
        ),
      ),
      child: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                profile.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildDefaultAvatar(profile),
              ),
            )
          : _buildDefaultAvatar(profile),
    );
  }

  Widget _buildDefaultAvatar(UserProfile profile) {
    return Center(
      child: Text(
        profile.effectiveName[0].toUpperCase(),
        style: const TextStyle(
          color: KemeticGold.base, // Gold
          fontSize: 40,
          fontWeight: FontWeight.bold,
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

    return Wrap(
      spacing: 24,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: stats
          .map(
            (stat) => _buildStatItem(
              label: stat.label,
              value: stat.value,
              onTap: stat.onTap,
              enabled: stat.enabled,
            ),
          )
          .toList(),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    VoidCallback? onTap,
    bool enabled = true,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: numberColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: labelColor, fontSize: 13)),
            ],
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
    final edgeWidth =
        ((MediaQuery.of(context).size.width * 0.08).clamp(36.0, 64.0) as num)
            .toDouble();

    return Positioned(
      top: 0,
      left: 0,
      bottom: 0,
      width: edgeWidth,
      child: _HorizontalEdgeSwipePad(
        onHorizontalDragStart: (_) {
          _calendarRevealSwipeAccum = 0.0;
        },
        onHorizontalDragUpdate: (details) {
          if (_calendarRevealNavigationInFlight) return;
          _calendarRevealSwipeAccum += details.delta.dx;
        },
        onHorizontalDragEnd: (details) {
          if (_calendarRevealNavigationInFlight) {
            _calendarRevealSwipeAccum = 0.0;
            return;
          }

          final vx = details.velocity.pixelsPerSecond.dx;
          final traveled = _calendarRevealSwipeAccum;
          final flingClose = vx > 750;
          final dragClose = traveled > 42;

          if (flingClose || dragClose) {
            unawaited(_returnToCalendarFromSwipe());
          }

          _calendarRevealSwipeAccum = 0.0;
        },
      ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Posted Flows',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ..._posts.map(_buildPostCard),
      ],
    );
  }

  Widget _buildPostCard(FlowPost post) {
    final title = cleanFlowTitle(post.name);
    final overview = cleanFlowOverview(post.notes);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openPostDetails(post),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: glossFromColor(post.color),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? 'Untitled Flow' : title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (overview.isNotEmpty)
                        Text(
                          overview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            height: 1.3,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        'Posted ${_formatDate(post.createdAt)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFB0B0B0)),
              ],
            ),
            const SizedBox(height: 12),
            FlowPostEngagementRow(post: post),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_isViewingOwnProfile)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        foregroundColor: Colors.redAccent,
                      ),
                      onPressed: () => _removePost(post.id),
                      child: const Text('Remove'),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KemeticGold.base,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => _savePost(post),
                      child: const Text('Save Flow'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  Future<void> _openPostDetails(FlowPost post) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            FlowPostDetailPage(post: post, isOwner: _isViewingOwnProfile),
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

class _HorizontalEdgeSwipePad extends StatelessWidget {
  const _HorizontalEdgeSwipePad({
    required this.onHorizontalDragStart,
    required this.onHorizontalDragUpdate,
    required this.onHorizontalDragEnd,
  });

  final GestureDragStartCallback? onHorizontalDragStart;
  final GestureDragUpdateCallback? onHorizontalDragUpdate;
  final GestureDragEndCallback? onHorizontalDragEnd;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: null,
        onHorizontalDragStart: onHorizontalDragStart,
        onHorizontalDragUpdate: onHorizontalDragUpdate,
        onHorizontalDragEnd: onHorizontalDragEnd,
        child: const SizedBox.expand(),
      ),
    );
  }
}
