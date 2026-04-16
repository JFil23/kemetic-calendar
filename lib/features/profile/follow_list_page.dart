import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/shared/glossy_text.dart';

import '../../data/profile_repo.dart';

enum FollowListType { followers, following }

class FollowListPage extends StatefulWidget {
  const FollowListPage({
    super.key,
    required this.userId,
    required this.type,
    this.userHandle,
    this.userDisplayName,
  });

  final String userId;
  final FollowListType type;
  final String? userHandle;
  final String? userDisplayName;

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> {
  final _repo = ProfileRepo(Supabase.instance.client);
  bool _loading = true;
  List<UserSearchResult> _users = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = widget.type == FollowListType.followers
        ? await _repo.listFollowers(widget.userId)
        : await _repo.listFollowing(widget.userId);
    if (!mounted) return;
    setState(() {
      _users = results;
      _loading = false;
    });
  }

  String get _title {
    final base = widget.type == FollowListType.followers
        ? 'Followers'
        : 'Following';
    final handle = widget.userHandle;
    if (handle != null && handle.isNotEmpty) {
      return '$base · @$handle';
    }
    if (widget.userDisplayName != null &&
        widget.userDisplayName!.trim().isNotEmpty) {
      return '$base · ${widget.userDisplayName}';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: KemeticGold.icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(KemeticGold.base),
              ),
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_users.isEmpty) {
      return RefreshIndicator(
        color: KemeticGold.base,
        backgroundColor: Colors.black,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.type == FollowListType.followers
                        ? 'No followers yet'
                        : 'Not following anyone yet',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.type == FollowListType.followers
                        ? 'Once people follow this profile, they will appear here.'
                        : 'Follow someone to see them listed here.',
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

    return RefreshIndicator(
      color: KemeticGold.base,
      backgroundColor: Colors.black,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _users.length,
        separatorBuilder: (context, index) =>
            Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
        itemBuilder: (context, index) {
          final user = _users[index];
          final initials =
              (user.displayName?.isNotEmpty == true
                      ? user.displayName![0]
                      : user.handle?.isNotEmpty == true
                      ? user.handle![0]
                      : '?')
                  .toUpperCase();
          final subtitle =
              user.displayName != null && user.displayName!.isNotEmpty
              ? '@${user.handle ?? 'user'}'
              : (user.handle != null ? '@${user.handle}' : null);

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 20,
            ),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: KemeticGold.base.withValues(alpha: 0.2),
              backgroundImage: user.avatarUrl != null
                  ? NetworkImage(user.avatarUrl!)
                  : null,
              child: user.avatarUrl == null
                  ? KemeticGold.text(
                      initials,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            title: Text(
              user.displayName?.isNotEmpty == true
                  ? user.displayName!
                  : (user.handle != null ? '@${user.handle}' : 'User'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: subtitle != null
                ? Text(
                    subtitle,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                  )
                : null,
            trailing: KemeticGold.icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pop(user.userId),
          );
        },
      ),
    );
  }
}
