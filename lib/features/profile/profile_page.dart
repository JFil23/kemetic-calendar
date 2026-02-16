// lib/features/profile/profile_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/profile_model.dart';
import '../../data/profile_repo.dart';
import '../../data/flow_post_model.dart';
import '../../widgets/inbox_icon_with_badge.dart';
import 'edit_profile_page.dart';
import 'profile_search_page.dart';
import '../settings/settings_page.dart';
import 'flow_post_picker_page.dart';
import 'flow_post_detail_page.dart';
import '_post_glossy_helper.dart';

class ProfilePage extends StatefulWidget {
  final String userId;
  final bool isMyProfile;

  const ProfilePage({
    Key? key,
    required this.userId,
    this.isMyProfile = false,
  }) : super(key: key);

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

  bool get _isViewingOwnProfile {
    final currentId = Supabase.instance.client.auth.currentUser?.id;
    return widget.isMyProfile || (currentId != null && currentId == widget.userId);
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
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000), // True black
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFFD4AF37)), // Gold
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
          InboxIconWithBadge(),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings, color: Color(0xFFD4AF37)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
              ),
            )
          : _profile == null
              ? _buildNoProfile()
              : _buildProfile(),
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
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Profile not found',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
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
                color: Colors.white.withOpacity(0.6),
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
          color: const Color(0xFFD4AF37), // Gold border
          width: 2,
        ),
      ),
      child: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                profile.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildDefaultAvatar(profile),
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
          color: Color(0xFFD4AF37), // Gold
          fontSize: 40,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStats(UserProfile profile) {
    final stats = [
      (
        'Followers',
        (profile.followersCount ?? 0).toString(),
      ),
      (
        'Following',
        (profile.followingCount ?? 0).toString(),
      ),
      (
        'Active Flows',
        (profile.activeFlowsCount ?? 0).toString(),
      ),
      (
        'Flow Events',
        (profile.totalFlowEventsCount ?? 0).toString(),
      ),
    ];

    return Wrap(
      spacing: 24,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: stats
          .map((stat) => _buildStatItem(label: stat.$1, value: stat.$2))
          .toList(),
    );
  }

  Widget _buildStatItem({required String label, required String value}) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFD4AF37), // Gold
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildFollowButton() {
    final isFollowing = _isFollowing;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _followUpdating ? null : _toggleFollow,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isFollowing ? Colors.black : const Color(0xFFD4AF37),
          foregroundColor:
              isFollowing ? Colors.white : const Color(0xFF000000),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: const Color(0xFFD4AF37),
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
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
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
              builder: (context) => EditProfilePage(
                initialProfile: _profile!,
              ),
            ),
          );
          
          // Reload profile data if updated
          if (result == true) {
            await _loadProfile();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD4AF37), // Gold
          foregroundColor: const Color(0xFF000000), // Black text
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Edit Profile',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
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
            MaterialPageRoute(
              builder: (_) => const ProfileSearchPage(),
            ),
          );

          if (!mounted || selectedUserId == null) return;

          if (selectedUserId == widget.userId) {
            await _loadProfile(showSpinner: false);
            return;
          }

          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfilePage(userId: selectedUserId),
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFD4AF37)),
          foregroundColor: const Color(0xFFD4AF37),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Find People',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPostFlowButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.upload, color: Color(0xFFD4AF37)),
        label: const Text(
          'Post a Flow',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFD4AF37)),
          foregroundColor: const Color(0xFFD4AF37),
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
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
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
              color: Colors.white.withOpacity(0.6),
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
    final color = Color(0xFF000000 | (post.color & 0x00FFFFFF));
    final overview = _extractOverview(post.notes);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                        post.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (overview != null && overview.isNotEmpty)
                        Text(
                          overview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            height: 1.3,
                          ),
                        )
                      else if (post.notes != null && post.notes!.isNotEmpty)
                        Text(
                          post.notes!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            height: 1.3,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        'Posted ${_formatDate(post.createdAt)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
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
                        backgroundColor: const Color(0xFFD4AF37),
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

  String? _extractOverview(String? notes) {
    if (notes == null || notes.isEmpty) return null;
    final parts = notes.split(';');
    for (final p in parts) {
      if (p.startsWith('ov=')) {
        final raw = p.substring(3);
        try {
          return Uri.decodeComponent(raw);
        } catch (_) {
          return raw;
        }
      }
    }
    return null;
  }

  Future<void> _openPostDetails(FlowPost post) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FlowPostDetailPage(
          post: post,
          isOwner: _isViewingOwnProfile,
        ),
      ),
    );
    if (changed == true) {
      await _loadPosts();
    }
  }

  Future<void> _openPostPicker() async {
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const FlowPostPickerPage()),
    );
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
        backgroundColor: Color(0xFFD4AF37),
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
