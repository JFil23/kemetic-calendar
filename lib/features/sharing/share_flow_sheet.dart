import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import '../../data/share_models.dart';
import '../../data/share_repo.dart';
import '../../data/profile_repo.dart';

class ShareFlowSheet extends StatefulWidget {
  final int flowId;
  final String flowTitle;

  const ShareFlowSheet({
    Key? key,
    required this.flowId,
    required this.flowTitle,
  }) : super(key: key);

  @override
  State<ShareFlowSheet> createState() => _ShareFlowSheetState();
}

class _ShareFlowSheetState extends State<ShareFlowSheet> {
  final _repo = ShareRepo(Supabase.instance.client);
  final _profileRepo = ProfileRepo(Supabase.instance.client);
  final _searchController = TextEditingController();
  
  List<ShareRecipient> _recipients = [];
  String _searchQuery = '';
  List<UserSearchResult> _searchResults = [];
  bool _searching = false;
  bool _sending = false;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFFD4AF37)),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Share Flow',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.flowTitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _recipients.isEmpty || _sending ? null : _sendShares,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.grey.shade800,
                    disabledForegroundColor: Colors.grey.shade600,
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Text('Send'),
                ),
              ],
            ),
          ),
          
          const Divider(color: Color(0xFF1A1A1A), height: 1),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search field
                  _buildSearchField(),
                  
                  if (_searchResults.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSearchResults(),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Selected recipients
                  if (_recipients.isNotEmpty) ...[
                    Text(
                      'Recipients (${_recipients.length})',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._recipients.map((r) => _buildRecipientChip(r)),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search by @handle or enter email/phone (press Enter)',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
        filled: true,
        fillColor: const Color(0xFF0D0D0F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
        ),
      ),
      onChanged: _onSearchChanged,
      onSubmitted: _handleSubmit,  // ⭐ ADD THIS LINE
    );
  }

  Future<void> _onSearchChanged(String query) async {
    setState(() {
      _searchQuery = query;
      _searching = true;
    });

    // Cancel previous search
    _searchDebounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    // Check if it's an email
    if (_isValidEmail(query)) {
      print('[ShareFlowSheet] Detected email: $query');
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      // Email will be added when user presses Enter (handled by _handleSubmit)
      return;
    }

    // Check if it's a @handle search
    if (query.startsWith('@') && query.length >= 2) {
      print('[ShareFlowSheet] Searching for handle: $query');
      
      _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
        try {
          final results = await _profileRepo.searchUsersByHandle(query);
          
          if (mounted) {
            setState(() {
              _searchResults = results;
              _searching = false;
            });
          }
        } catch (e) {
          print('[ShareFlowSheet] Search error: $e');
          if (mounted) {
            setState(() {
              _searchResults = [];
              _searching = false;
            });
          }
        }
      });
    } else {
      // Not an email or handle - clear results
      setState(() {
        _searchResults = [];
        _searching = false;
      });
    }
  }

  // Add this helper method
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email);
  }

  void _handleSubmit(String query) {
    if (query.isEmpty) return;

    // Check if it's a valid email
    if (query.contains('@') && _isValidEmail(query)) {
      final recipient = ShareRecipient(
        type: ShareRecipientType.email,
        value: query.trim(),
      );
      _addRecipient(recipient);
      _searchController.clear();
      setState(() {
        _searchResults = [];
      });
      return;
    }

    // Check if it's a valid phone number
    final cleanedPhone = query.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (RegExp(r'^\+?\d{10,}$').hasMatch(cleanedPhone)) {
      final recipient = ShareRecipient(
        type: ShareRecipientType.phone,
        value: cleanedPhone,
      );
      _addRecipient(recipient);
      _searchController.clear();
      setState(() {
        _searchResults = [];
      });
      return;
    }

    // If it's a handle search result, ignore Enter key
    // (user should tap the result instead)
  }

  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final user = _searchResults[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFD4AF37),
              child: Text(
                user.handle[0].toUpperCase(),
                style: const TextStyle(color: Colors.black),
              ),
            ),
            title: Text(
              '@${user.handle}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: user.displayName != null
                ? Text(
                    user.displayName!,
                    style: TextStyle(color: Colors.grey[400]),
                  )
                : null,
            trailing: const Icon(Icons.add, color: Color(0xFFD4AF37)),
            onTap: () => _addUserToRecipients(user),
          );
        },
      ),
    );
  }

  Widget _buildRecipientChip(ShareRecipient recipient) {
    String displayText = recipient.value;
    if (recipient.type == ShareRecipientType.user) {
      // Find display name from search results
      UserSearchResult user;
      try {
        user = _searchResults.firstWhere(
          (u) => u.userId == recipient.value,
        );
      } catch (e) {
        // User not found in search results, create a default
        user = UserSearchResult(
          userId: recipient.value,
          handle: 'user',
          displayName: null,
        );
      }
      displayText = user.displayName ?? '@${user.handle}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(
            recipient.type == ShareRecipientType.user
                ? Icons.person
                : recipient.type == ShareRecipientType.email
                    ? Icons.email
                    : Icons.phone,
            color: const Color(0xFFD4AF37),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayText,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: () => _removeRecipient(recipient),
          ),
        ],
      ),
    );
  }

  void _addRecipient(ShareRecipient recipient) {
    if (!_recipients.any((r) => r.value == recipient.value)) {
      setState(() => _recipients.add(recipient));
    }
  }

  void _addUserToRecipients(UserSearchResult user) {
    // Check if already added
    if (_recipients.any((r) => r.type == ShareRecipientType.user && r.value == user.userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.name} already added')),
      );
      return;
    }

    setState(() {
      _recipients.add(user.toRecipient());
      _searchController.clear();
      _searchQuery = '';
      _searchResults = [];
    });

    print('[ShareFlowSheet] Added user: ${user.handle}');
  }

  void _removeRecipient(ShareRecipient recipient) {
    setState(() => _recipients.remove(recipient));
  }

  Future<void> _sendShares() async {
    print('[ShareFlowSheet] _sendShares() called');
    print('[ShareFlowSheet] Recipients: ${_recipients.length}');
    
    if (_recipients.isEmpty) {
      print('[ShareFlowSheet] No recipients, returning');
      return;
    }

    setState(() => _sending = true);
    print('[ShareFlowSheet] Set _sending = true');

    try {
      print('[ShareFlowSheet] Calling shareFlow...');
      final results = await _repo.shareFlow(
        flowId: widget.flowId,
        recipients: _recipients,
        suggestedSchedule: null,  // No schedule suggestion - Ma'at flows have their own
      );

      print('[ShareFlowSheet] shareFlow returned ${results.length} results');
      print('[ShareFlowSheet] Results: $results');

      if (!mounted) {
        print('[ShareFlowSheet] Widget not mounted, returning');
        return;
      }

      // Count successes - check for shareUrl instead of status
      final successCount = results.where((r) => r.shareUrl != null).length;
      final failCount = results.length - successCount;
      
      print('[ShareFlowSheet] Success count: $successCount');
      print('[ShareFlowSheet] Fail count: $failCount');

      if (successCount > 0) {
        print('[ShareFlowSheet] ✅ At least one share succeeded');
        
        // Collect share URLs for external shares
        final shareUrls = results
            .where((r) => r.shareUrl != null)
            .map((r) => r.shareUrl!)
            .toList();
        
        print('[ShareFlowSheet] Share URLs: ${shareUrls.length}');
        print('[ShareFlowSheet] URLs: $shareUrls');
        
        // Show success snackbar FIRST
        if (mounted) {
          print('[ShareFlowSheet] Showing success snackbar...');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Shared with $successCount person(s)!'),
              backgroundColor: const Color(0xFFD4AF37),
            ),
          );
        }
        
        // Open system share dialog and WAIT for it to complete
        if (shareUrls.isNotEmpty && mounted) {
          print('[ShareFlowSheet] Opening system share dialog with ${shareUrls.length} URLs...');
          
          await Share.share(
            shareUrls.join('\n\n'),
            subject: 'Check out this Ma\'at flow!',
          );
          
          print('[ShareFlowSheet] System share dialog completed');
        } else {
          print('[ShareFlowSheet] No share URLs or not mounted, skipping dialog');
        }
        
        // THEN close the sheet AFTER share dialog completes
        if (mounted) {
          print('[ShareFlowSheet] Closing sheet...');
          Navigator.pop(context, true);
        }
      } else {
        print('[ShareFlowSheet] ❌ No successful shares');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to share. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('[ShareFlowSheet] ❌ ERROR: $e');
      print('[ShareFlowSheet] Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        print('[ShareFlowSheet] Setting _sending = false');
        setState(() => _sending = false);
      }
    }
  }
}
