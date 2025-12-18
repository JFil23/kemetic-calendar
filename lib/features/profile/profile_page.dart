// lib/features/profile/profile_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/profile_model.dart';
import '../../data/profile_repo.dart';
import '../../widgets/inbox_icon_with_badge.dart';
import 'edit_profile_page.dart';
import '../settings/settings_page.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final profile = await _repo.getProfile(widget.userId);
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
        _loading = false;
      });
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

          // Edit button (only for own profile)
          if (widget.isMyProfile) ...[
            const SizedBox(height: 32),
            _buildEditButton(),
          ],
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(
          label: 'Active Flows',
          value: profile.activeFlowsCount?.toString() ?? '0',
        ),
        Container(
          width: 1,
          height: 40,
          color: Colors.white.withOpacity(0.1),
        ),
        _buildStatItem(
          label: 'Flow Events',
          value: profile.totalFlowEventsCount?.toString() ?? '0',
        ),
      ],
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
}
