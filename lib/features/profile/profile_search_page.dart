import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/shared/glossy_text.dart';

import '../../core/navigation_fallback.dart';
import '../../data/profile_repo.dart';
import '../../features/inbox/conversation_user.dart';
import '../../repositories/dm_conversation_repo.dart';
import '../../widgets/keyboard_aware.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/responsive_content_rail.dart';

class ProfileSearchPage extends StatefulWidget {
  final bool returnFullResult;
  final String titleText;
  final String hintText;
  final String fallbackLocation;
  final String selectionMode;

  const ProfileSearchPage({
    super.key,
    this.returnFullResult = false,
    this.titleText = 'Find People',
    this.hintText = 'Search by @handle or display name',
    this.fallbackLocation = '/profile/me',
    this.selectionMode = 'profile',
  });

  @override
  State<ProfileSearchPage> createState() => _ProfileSearchPageState();
}

class _ProfileSearchPageState extends State<ProfileSearchPage> {
  final _repo = ProfileRepo(Supabase.instance.client);
  final _dmConversationRepo = DmConversationRepo(Supabase.instance.client);
  final _controller = TextEditingController();

  List<UserSearchResult> _results = [];
  final Map<String, UserSearchResult> _selectedUsersById =
      <String, UserSearchResult>{};
  bool _searching = false;
  bool _startingConversation = false;
  String _query = '';
  Timer? _debounce;

  bool get _isConversationMode => widget.selectionMode == 'conversation';

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String raw) {
    final value = raw.trim();
    setState(() {
      _query = value;
    });
    _debounce?.cancel();

    if (value.length < 2) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      final res = await _repo.searchUsers(value);
      if (!mounted) return;
      setState(() {
        _results = res;
        _searching = false;
      });
    });
  }

  void _selectUser(UserSearchResult user) {
    if (widget.returnFullResult || widget.selectionMode == 'picker') {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop(widget.returnFullResult ? user : user.userId);
        return;
      }
    }
    if (_isConversationMode) {
      _toggleSelectedUser(user);
      return;
    }
    unawaited(
      openDetailRoute<void>(
        context,
        '/profile/${Uri.encodeComponent(user.userId)}',
      ),
    );
  }

  void _toggleSelectedUser(UserSearchResult user) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId != null && currentUserId == user.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot message yourself')),
      );
      return;
    }

    final isSelected = _selectedUsersById.containsKey(user.userId);
    if (!isSelected && _selectedUsersById.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group chats are limited to 6 people')),
      );
      return;
    }

    setState(() {
      if (isSelected) {
        _selectedUsersById.remove(user.userId);
      } else {
        _selectedUsersById[user.userId] = user;
      }
    });
  }

  Future<void> _startConversation() async {
    if (_startingConversation || _selectedUsersById.isEmpty) return;
    final users = _selectedUsersById.values.toList(growable: false);
    if (users.length == 1) {
      final user = users.single;
      unawaited(
        openDetailRoute<void>(
          context,
          '/inbox/conversation/${Uri.encodeComponent(user.userId)}',
          extra: ConversationUser(
            id: user.userId,
            displayName: user.displayName,
            handle: user.handle,
            avatarUrl: user.avatarUrl,
            avatarGlyphIds: user.avatarGlyphIds,
          ),
        ),
      );
      return;
    }

    setState(() => _startingConversation = true);
    try {
      final conversationId = await _dmConversationRepo.createConversation(
        participantIds: users
            .map((user) => user.userId)
            .toList(growable: false),
      );
      if (!mounted) return;
      unawaited(
        openDetailRoute<void>(
          context,
          '/inbox/dm/${Uri.encodeComponent(conversationId)}',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingDmConversationError(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _startingConversation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bodyPadding = EdgeInsets.all(20);
    const fieldScrollPadding = keyboardManagedTextFieldScrollPadding;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: KemeticGold.icon(Icons.close),
          onPressed: () => popOrGo(context, widget.fallbackLocation),
        ),
        title: Text(
          widget.titleText,
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: _isConversationMode
            ? [
                TextButton(
                  onPressed: _selectedUsersById.isEmpty || _startingConversation
                      ? null
                      : () => unawaited(_startConversation()),
                  child: _startingConversation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              KemeticGold.base,
                            ),
                          ),
                        )
                      : const Text('Start'),
                ),
              ]
            : null,
      ),
      body: ResponsiveContentRail(
        maxWidth: 640,
        child: Padding(
          padding: bodyPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchField(scrollPadding: fieldScrollPadding),
              if (_isConversationMode && _selectedUsersById.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildSelectedPeopleChips(),
              ],
              const SizedBox(height: 20),
              if (_searching)
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(KemeticGold.base),
                  ),
                )
              else if (_results.isEmpty && _query.length < 2)
                _buildHint()
              else if (_results.isEmpty)
                _buildEmpty()
              else
                Expanded(child: _buildResultsList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedPeopleChips() {
    final users = _selectedUsersById.values.toList(growable: false);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final user in users)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: InputChip(
              label: Text(
                user.displayName?.isNotEmpty == true
                    ? user.displayName!
                    : (user.handle != null ? '@${user.handle}' : 'User'),
                overflow: TextOverflow.ellipsis,
              ),
              avatar: ProfileAvatar(
                radius: 12,
                displayName: user.name,
                avatarUrl: user.avatarUrl,
                avatarGlyphIds: user.avatarGlyphIds,
                backgroundColor: Colors.black,
                foregroundColor: KemeticGold.base,
              ),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => _toggleSelectedUser(user),
              backgroundColor: KemeticGold.base.withValues(alpha: 0.16),
              side: BorderSide(color: KemeticGold.base.withValues(alpha: 0.36)),
              labelStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              deleteIconColor: Colors.white70,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }

  Widget _buildSearchField({required EdgeInsets scrollPadding}) {
    return TextField(
      controller: _controller,
      autofocus: true,
      scrollPadding: scrollPadding,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        prefixIcon: Icon(
          Icons.search,
          color: Colors.white.withValues(alpha: 0.5),
        ),
        suffixIcon: _query.isNotEmpty
            ? IconButton(
                icon: KemeticGold.icon(Icons.close),
                onPressed: () {
                  _controller.clear();
                  _onQueryChanged('');
                },
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF0D0D0F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: KemeticGold.base),
        ),
      ),
      onChanged: _onQueryChanged,
      textInputAction: TextInputAction.search,
    );
  }

  Widget _buildHint() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Search for friends by @handle or name.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tip: people must be discoverable to appear.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'No people found yet',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Try another spelling or a shorter @handle.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildResultsList() {
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (context, index) =>
          Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
      itemBuilder: (context, index) {
        final user = _results[index];
        final isSelected =
            _isConversationMode && _selectedUsersById.containsKey(user.userId);
        final subtitle =
            user.displayName != null && user.displayName!.isNotEmpty
            ? '@${user.handle ?? 'user'}'
            : (user.handle != null ? '@${user.handle}' : null);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          leading: ProfileAvatar(
            radius: 20,
            displayName: user.name,
            avatarUrl: user.avatarUrl,
            avatarGlyphIds: user.avatarGlyphIds,
            backgroundColor: KemeticGold.base.withValues(alpha: 0.2),
            foregroundColor: KemeticGold.base,
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
          trailing: _isConversationMode
              ? Icon(
                  isSelected ? Icons.check_circle : Icons.add_circle_outline,
                  color: isSelected
                      ? KemeticGold.base
                      : Colors.white.withValues(alpha: 0.45),
                )
              : KemeticGold.icon(Icons.chevron_right),
          onTap: () => _selectUser(user),
        );
      },
    );
  }
}
