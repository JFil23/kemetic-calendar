import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import '../../data/share_models.dart';
import '../../data/share_repo.dart';
import '../../data/profile_repo.dart';
import '../inbox/inbox_conversation_page.dart';
import '../inbox/conversation_user.dart';
import 'package:mobile/shared/glossy_text.dart';

class ShareFlowSheet extends StatefulWidget {
  final int? flowId;
  final String flowTitle;
  final String? noteShareText; // When present, share a note instead of a flow
  final String? eventId; // When present, call create_event_share

  const ShareFlowSheet({
    super.key,
    required this.flowId,
    required this.flowTitle,
    this.noteShareText,
    this.eventId,
  });

  @override
  State<ShareFlowSheet> createState() => _ShareFlowSheetState();
}

class _ShareFlowSheetState extends State<ShareFlowSheet> {
  final _repo = ShareRepo(Supabase.instance.client);
  final _profileRepo = ProfileRepo(Supabase.instance.client);
  final _searchController = TextEditingController();

  final List<ShareRecipient> _recipients = [];
  // ✅ NEW: keep rich info for user recipients keyed by userId
  final Map<String, UserSearchResult> _recipientUsersById = {};
  List<EventInviteeStatus> _existingInvitees = const [];
  String _searchQuery = '';
  List<UserSearchResult> _searchResults = [];
  bool _searching = false;
  bool _sending = false;
  bool _loadingInvitees = false;
  Timer? _searchDebounce;

  bool get _isEventShare => widget.eventId != null;
  bool get _isTextShare =>
      widget.flowId == null && widget.noteShareText != null && !_isEventShare;
  bool get _isFlowShare => widget.flowId != null;
  bool get _supportsExternalRecipients => !_isEventShare;
  String get _sheetTitle {
    if (_isEventShare) return 'Invite People';
    if (_isTextShare) return 'Share Note';
    return 'Share Flow';
  }

  String get _sendLabel => _isEventShare ? 'Invite' : 'Send';

  bool get _showNoUserResults {
    final query = _searchQuery.trim();
    return query.length >= 2 &&
        !_searching &&
        _searchResults.isEmpty &&
        (_isEventShare ||
            (!_isValidEmail(query) && !_looksLikePhoneNumber(query)));
  }

  @override
  void initState() {
    super.initState();
    if (_isEventShare) {
      _loadExistingInvitees();
    }
  }

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
                  icon: KemeticGold.icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _sheetTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.flowTitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      ((_isFlowShare || _isEventShare) &&
                              _recipients.isEmpty) ||
                          _sending
                      ? null
                      : _sendShares,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KemeticGold.base,
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black,
                            ),
                          ),
                        )
                      : Text(_sendLabel),
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
                  if (_isEventShare) ...[
                    _buildEventModeInfo(),
                    const SizedBox(height: 16),
                  ],
                  // Search field
                  _buildSearchField(),

                  if (_searchResults.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSearchResults(),
                  ] else if (_showNoUserResults) ...[
                    const SizedBox(height: 16),
                    Text(
                      _isEventShare
                          ? 'No app users found for "$_searchQuery".'
                          : 'No users found for "$_searchQuery". You can still press Enter to add an email or phone number.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  if (_isEventShare) ...[
                    _buildExistingInviteesSection(),
                    const SizedBox(height: 24),
                  ],

                  // Selected recipients
                  if (_recipients.isNotEmpty) ...[
                    Text(
                      _isEventShare
                          ? 'New Invitees (${_recipients.length})'
                          : 'Recipients (${_recipients.length})',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
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
        hintText: _isEventShare
            ? 'Search app users by @handle or name'
            : 'Search by @handle or enter email/phone (press Enter)',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        prefixIcon: Icon(
          Icons.search,
          color: Colors.white.withValues(alpha: 0.5),
        ),
        suffixIcon: _searching
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(KemeticGold.base),
                  ),
                ),
              )
            : _searchQuery.isEmpty
            ? null
            : IconButton(
                onPressed: _clearSearch,
                icon: Icon(
                  Icons.close,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
        filled: true,
        fillColor: const Color(0xFF0D0D0F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: KemeticGold.base),
        ),
      ),
      onChanged: _onSearchChanged,
      onSubmitted: _handleSubmit,
    );
  }

  Widget _buildEventModeInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            color: KemeticGold.base,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Invite people inside the app. Search by handle or display name, then they will see this event with Yes, No, and Maybe actions instead of receiving an email.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingInviteesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Invite Status',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingInvitees)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(KemeticGold.base),
              ),
            ),
          )
        else if (_existingInvitees.isEmpty)
          Text(
            'No invitees yet.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.56),
              fontSize: 13,
            ),
          )
        else
          ..._existingInvitees.map(_buildExistingInviteeRow),
      ],
    );
  }

  Widget _buildExistingInviteeRow(EventInviteeStatus invitee) {
    Color statusColor;
    switch (invitee.responseStatus) {
      case EventInviteResponseStatus.accepted:
        statusColor = Colors.greenAccent;
        break;
      case EventInviteResponseStatus.declined:
        statusColor = Colors.redAccent;
        break;
      case EventInviteResponseStatus.maybe:
        statusColor = Colors.orangeAccent;
        break;
      case EventInviteResponseStatus.noResponse:
        statusColor = Colors.white70;
        break;
    }

    final displayName = invitee.displayName?.trim().isNotEmpty == true
        ? invitee.displayName!.trim()
        : (invitee.handle?.trim().isNotEmpty == true
              ? '@${invitee.handle!.trim()}'
              : 'User');

    final meta = invitee.responseStatus.isPending
        ? (invitee.viewedAt != null ? 'Opened' : 'Waiting')
        : invitee.responseStatus.label;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: statusColor.withValues(alpha: 0.18),
            child: Text(
              displayName.characters.take(1).toString().toUpperCase(),
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              displayName,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: statusColor.withValues(alpha: 0.28)),
            ),
            child: Text(
              meta,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSearchChanged(String query) async {
    final trimmedQuery = query.trim();

    // Cancel previous search
    _searchDebounce?.cancel();

    // Show nothing / clear if too short
    if (trimmedQuery.length < 2) {
      setState(() {
        _searchQuery = trimmedQuery;
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    // 1️⃣ If it looks like an email, don't hit user search — wait for user to press Enter
    if (_supportsExternalRecipients && _isValidEmail(trimmedQuery)) {
      debugPrint('[ShareFlowSheet] Detected email: $trimmedQuery');
      setState(() {
        _searchQuery = trimmedQuery;
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    // 2️⃣ Search for users (by handle or display_name)
    setState(() {
      _searchQuery = trimmedQuery;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 250), () async {
      setState(() {
        _searching = true;
      });

      try {
        final results = await _profileRepo.searchUsers(trimmedQuery);
        if (!mounted) return;

        setState(() {
          _searchResults = results;
          _searching = false;
        });
      } catch (e) {
        debugPrint('[ShareFlowSheet] Search error: $e');
        if (!mounted) return;

        setState(() {
          _searchResults = [];
          _searching = false;
        });
      }
    });
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email);
  }

  bool _looksLikePhoneNumber(String value) {
    final cleanedPhone = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return RegExp(r'^\+?\d{10,}$').hasMatch(cleanedPhone);
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchResults = [];
      _searching = false;
    });
  }

  void _handleSubmit(String query) {
    if (query.isEmpty) return;
    if (!_supportsExternalRecipients) return;

    // Check if it's a valid email
    if (query.contains('@') && _isValidEmail(query)) {
      final recipient = ShareRecipient(
        type: ShareRecipientType.email,
        value: query.trim(),
      );
      _addRecipient(recipient);
      _searchController.clear();
      setState(() {
        _searchQuery = '';
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    // Check if it's a valid phone number
    final cleanedPhone = query.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (_looksLikePhoneNumber(query)) {
      final recipient = ShareRecipient(
        type: ShareRecipientType.phone,
        value: cleanedPhone,
      );
      _addRecipient(recipient);
      _searchController.clear();
      setState(() {
        _searchQuery = '';
        _searchResults = [];
        _searching = false;
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
        border: Border.all(color: KemeticGold.base.withValues(alpha: 0.3)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final user = _searchResults[index];
          final displayChar =
              (user.displayName?.isNotEmpty == true
                      ? user.displayName![0]
                      : user.handle?.isNotEmpty == true
                      ? user.handle![0]
                      : '?')
                  .toUpperCase();
          final displayText = user.handle != null
              ? '@${user.handle}'
              : user.displayName ?? 'User';

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: KemeticGold.base,
              child: Text(
                displayChar,
                style: const TextStyle(color: Colors.black),
              ),
            ),
            title: Text(
              displayText,
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
            trailing: KemeticGold.icon(Icons.add),
            onTap: () => _addUserToRecipients(user),
          );
        },
      ),
    );
  }

  Widget _buildRecipientChip(ShareRecipient recipient) {
    String displayText = recipient.value;
    if (recipient.type == ShareRecipientType.user) {
      // ✅ Use stored map instead of search results
      final user = _recipientUsersById[recipient.value];

      if (user != null) {
        displayText = user.displayName?.trim().isNotEmpty == true
            ? user.displayName!
            : (user.handle != null && user.handle!.isNotEmpty
                  ? '@${user.handle}'
                  : 'User');
      } else {
        // Fallback if somehow missing
        displayText = 'User';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(
            recipient.type == ShareRecipientType.user
                ? Icons.person
                : recipient.type == ShareRecipientType.email
                ? Icons.email
                : Icons.phone,
            color: KemeticGold.base,
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
    if (_recipients.any(
      (r) => r.type == ShareRecipientType.user && r.value == user.userId,
    )) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${user.name} already added')));
      return;
    }

    if (_isEventShare &&
        _existingInvitees.any(
          (invitee) => invitee.recipientId == user.userId,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.name} is already invited')),
      );
      return;
    }

    setState(() {
      _recipients.add(user.toRecipient());
      // ✅ NEW: store full profile keyed by userId
      _recipientUsersById[user.userId] = user;
      _searchController.clear();
      _searchQuery = '';
      _searchResults = [];
    });

    debugPrint('[ShareFlowSheet] Added user: ${user.handle}');
  }

  void _removeRecipient(ShareRecipient recipient) {
    setState(() {
      _recipients.remove(recipient);
      // ✅ Also remove from map if it's a user recipient
      if (recipient.type == ShareRecipientType.user) {
        _recipientUsersById.remove(recipient.value);
      }
    });
  }

  /// Helper: get the first user recipient (no firstOrNull dependency)
  ShareRecipient? _firstUserRecipientOrNull() {
    for (final r in _recipients) {
      if (r.type == ShareRecipientType.user) {
        return r;
      }
    }
    return null;
  }

  Future<void> _loadExistingInvitees() async {
    if (!_isEventShare || widget.eventId == null) return;
    setState(() => _loadingInvitees = true);
    final invitees = await _repo.getEventInvitees(eventId: widget.eventId!);
    if (!mounted) return;
    setState(() {
      _existingInvitees = invitees;
      _loadingInvitees = false;
    });
  }

  Future<void> _sendShares() async {
    debugPrint('[ShareFlowSheet] _sendShares() called');
    debugPrint('[ShareFlowSheet] Recipients: ${_recipients.length}');

    if (_isEventShare) {
      final userRecipients = _recipients
          .where((recipient) => recipient.type == ShareRecipientType.user)
          .toList(growable: false);
      if (userRecipients.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one person'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _sending = true);
      try {
        final results = await _repo.shareEvent(
          eventId: widget.eventId!,
          recipients: userRecipients,
          payloadJson: null,
        );
        if (!mounted) return;

        final successCount = results.where((r) => r.isSuccess).length;
        final failCount = results.length - successCount;

        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                failCount == 0
                    ? 'Invites sent inside the app'
                    : 'Sent $successCount invite${successCount == 1 ? '' : 's'}, $failCount failed',
              ),
              backgroundColor: failCount == 0
                  ? KemeticGold.base
                  : Colors.orange,
            ),
          );
        } else {
          final errorMessages = results
              .where((r) => r.error != null)
              .map((r) => r.error!)
              .toSet()
              .join(', ');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMessages.isEmpty
                    ? 'Could not send invites'
                    : 'Could not send invites: $errorMessages',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        Navigator.pop(context, failCount == 0);
      } finally {
        if (mounted) {
          setState(() => _sending = false);
        }
      }
      return;
    }

    if (_isTextShare) {
      final text = widget.noteShareText?.trim() ?? '';
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nothing to share'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      await Share.share(text);
      if (mounted) Navigator.pop(context, true);
      return;
    }

    if (_recipients.isEmpty) {
      debugPrint('[ShareFlowSheet] No recipients, returning');
      return;
    }

    setState(() => _sending = true);
    debugPrint('[ShareFlowSheet] Set _sending = true');

    try {
      debugPrint('[ShareFlowSheet] Calling shareFlow...');
      final results = await _repo.shareFlow(
        flowId: widget.flowId!,
        recipients: _recipients,
        suggestedSchedule:
            null, // No schedule suggestion - Ma'at flows have their own
      );

      debugPrint(
        '[ShareFlowSheet] shareFlow returned ${results.length} results',
      );
      debugPrint('[ShareFlowSheet] Results: $results');

      if (!mounted) {
        debugPrint('[ShareFlowSheet] Widget not mounted, returning');
        return;
      }

      // Count successes based on status and error
      final successCount = results
          .where(
            (r) =>
                (r.status == 'sent' ||
                    r.status == 'viewed' ||
                    r.status == 'imported') &&
                r.error == null,
          )
          .length;
      final failCount = results
          .where((r) => r.error != null || r.status == null)
          .length;

      if (kDebugMode) {
        debugPrint('[ShareFlowSheet] Results breakdown:');
        for (final r in results) {
          debugPrint(
            '[ShareFlowSheet]   - shareId=${r.shareId}, status=${r.status}, error=${r.error}',
          );
        }
        debugPrint('[ShareFlowSheet] Success count: $successCount');
        debugPrint('[ShareFlowSheet] Fail count: $failCount');
      }

      if (successCount > 0 && failCount == 0) {
        if (kDebugMode) {
          debugPrint('[ShareFlowSheet] ✅ All shares succeeded');
        }

        // Show success snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Flow shared successfully'),
              backgroundColor: KemeticGold.base,
            ),
          );
        }

        // ✅ NEW: Try to navigate straight into the DM thread
        final firstUserRecipient = _firstUserRecipientOrNull();

        if (firstUserRecipient != null) {
          final userId = firstUserRecipient.value;
          final user = _recipientUsersById[userId];

          if (user != null && mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => InboxConversationPage(
                  otherUserId: userId,
                  otherProfile: ConversationUser(
                    id: userId,
                    displayName: user.displayName,
                    handle: user.handle,
                    avatarUrl: user.avatarUrl,
                  ),
                ),
              ),
            );
            return; // 🔑 Don't also pop the sheet
          }
        }

        // Fallback: close sheet like before if no user recipient or profile not found
        if (mounted) {
          Navigator.pop(context, true);
        }
        return; // Exit early on full success
      } else if (successCount > 0 && failCount > 0) {
        if (kDebugMode) {
          debugPrint(
            '[ShareFlowSheet] ⚠️ Partial success: $successCount succeeded, $failCount failed',
          );
        }
        // Show partial success snackbar with error details
        final errorMessages = results
            .where((r) => r.error != null)
            .map((r) => r.error!)
            .toSet()
            .join(', ');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Shared with $successCount, failed for $failCount${errorMessages.isNotEmpty ? ': $errorMessages' : ''}',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        // Don't close sheet on partial failure - let user see what happened
      } else {
        if (kDebugMode) {
          debugPrint('[ShareFlowSheet] ❌ All shares failed');
        }
        // Show failure snackbar with error details
        final errorMessages = results
            .where((r) => r.error != null)
            .map((r) => r.error!)
            .toSet()
            .join(', ');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Unable to share flow${errorMessages.isNotEmpty ? ': $errorMessages' : ' — please try again.'}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[ShareFlowSheet] ❌ ERROR: $e');
      debugPrint('[ShareFlowSheet] Stack trace: $stackTrace');

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
        debugPrint('[ShareFlowSheet] Setting _sending = false');
        setState(() => _sending = false);
      }
    }
  }
}
