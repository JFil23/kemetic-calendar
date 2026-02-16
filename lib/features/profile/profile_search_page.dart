import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/profile_repo.dart';

class ProfileSearchPage extends StatefulWidget {
  const ProfileSearchPage({super.key});

  @override
  State<ProfileSearchPage> createState() => _ProfileSearchPageState();
}

class _ProfileSearchPageState extends State<ProfileSearchPage> {
  final _repo = ProfileRepo(Supabase.instance.client);
  final _controller = TextEditingController();

  List<UserSearchResult> _results = [];
  bool _searching = false;
  String _query = '';
  Timer? _debounce;

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
    Navigator.of(context).pop(user.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFFD4AF37)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Find People',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchField(),
            const SizedBox(height: 20),
            if (_searching)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
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
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _controller,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search by @handle or display name',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
        suffixIcon: _query.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, color: Color(0xFFD4AF37)),
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
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
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
            color: Colors.white.withOpacity(0.8),
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tip: people must be discoverable to appear.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
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
            color: Colors.white.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildResultsList() {
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => Divider(
        color: Colors.white.withOpacity(0.05),
        height: 1,
      ),
      itemBuilder: (context, index) {
        final user = _results[index];
        final initials = (user.displayName?.isNotEmpty == true
                ? user.displayName![0]
                : user.handle?.isNotEmpty == true
                    ? user.handle![0]
                    : '?')
            .toUpperCase();
        final subtitle = user.displayName != null && user.displayName!.isNotEmpty
            ? '@${user.handle ?? 'user'}'
            : (user.handle != null ? '@${user.handle}' : null);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
            backgroundImage: user.avatarUrl != null
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null
                ? Text(
                    initials,
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontWeight: FontWeight.bold,
                    ),
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
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                )
              : null,
          trailing: const Icon(Icons.chevron_right, color: Color(0xFFD4AF37)),
          onTap: () => _selectUser(user),
        );
      },
    );
  }
}
