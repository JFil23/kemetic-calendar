import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/share_models.dart';
import '../../data/share_repo.dart';

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
  final _searchController = TextEditingController();
  
  List<ShareRecipient> _recipients = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  bool _sending = false;
  
  // Schedule preset
  String _schedulePreset = 'weekdays';
  SuggestedSchedule? _customSchedule;

  @override
  void dispose() {
    _searchController.dispose();
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
                  
                  // Schedule preset
                  Text(
                    'Suggested Schedule',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSchedulePresets(),
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
        hintText: 'Search by @handle or enter email/phone',
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
    );
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);

    // Check if it's an email or phone
    if (query.contains('@')) {
      // Email
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    if (RegExp(r'^\d+$').hasMatch(query)) {
      // Phone number
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    // Search for handles
    final results = await _repo.searchUsers(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    }
  }

  Widget _buildSearchResults() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: _searchResults.map((user) {
          final alreadyAdded = _recipients.any(
            (r) => r.type == ShareRecipientType.user && r.value == user['id'],
          );
          
          return ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A1A1A),
                border: Border.all(color: const Color(0xFFD4AF37)),
              ),
              child: user['avatar_url'] != null
                  ? ClipOval(
                      child: Image.network(user['avatar_url'], fit: BoxFit.cover),
                    )
                  : Center(
                      child: Text(
                        user['handle'][0].toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFD4AF37),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            title: Text(
              user['display_name'] ?? user['handle'],
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              '@${user['handle']}',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
            trailing: alreadyAdded
                ? Icon(Icons.check_circle, color: const Color(0xFFD4AF37))
                : IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFFD4AF37)),
                    onPressed: () => _addRecipient(ShareRecipient(
                      type: ShareRecipientType.user,
                      value: user['id'],
                    )),
                  ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecipientChip(ShareRecipient recipient) {
    String displayText = recipient.value;
    if (recipient.type == ShareRecipientType.user) {
      // Find display name from search results
      final user = _searchResults.firstWhere(
        (u) => u['id'] == recipient.value,
        orElse: () => {},
      );
      displayText = user['display_name'] ?? '@${user['handle'] ?? 'user'}';
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

  Widget _buildSchedulePresets() {
    return Column(
      children: [
        _buildPresetOption(
          'weekdays',
          'Weekdays',
          'Mon-Fri at 12:00 PM',
        ),
        const SizedBox(height: 8),
        _buildPresetOption(
          'everyother',
          'Every Other Day',
          'Starting tomorrow at 9:00 AM',
        ),
        const SizedBox(height: 8),
        _buildPresetOption(
          'custom',
          'Custom',
          'Set your own schedule',
        ),
      ],
    );
  }

  Widget _buildPresetOption(String value, String title, String subtitle) {
    final isSelected = _schedulePreset == value;
    
    return InkWell(
      onTap: () => setState(() => _schedulePreset = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.1) : const Color(0xFF0D0D0F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addRecipient(ShareRecipient recipient) {
    if (!_recipients.any((r) => r.value == recipient.value)) {
      setState(() => _recipients.add(recipient));
    }
  }

  void _removeRecipient(ShareRecipient recipient) {
    setState(() => _recipients.remove(recipient));
  }

  SuggestedSchedule _getScheduleFromPreset() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowStr = tomorrow.toIso8601String().split('T')[0];

    switch (_schedulePreset) {
      case 'weekdays':
        return SuggestedSchedule(
          startDate: tomorrowStr,
          weekdays: [1, 2, 3, 4, 5], // Mon-Fri
          everyOtherDay: false,
          perWeek: null,
          timesByWeekday: {
            '1': '12:00',
            '2': '12:00',
            '3': '12:00',
            '4': '12:00',
            '5': '12:00',
          },
        );
      case 'everyother':
        return SuggestedSchedule(
          startDate: tomorrowStr,
          weekdays: [0, 1, 2, 3, 4, 5, 6],
          everyOtherDay: true,
          perWeek: null,
          timesByWeekday: {'0': '09:00'},
        );
      case 'custom':
        return _customSchedule ?? SuggestedSchedule(
          startDate: tomorrowStr,
          weekdays: [1, 2, 3, 4, 5],
          everyOtherDay: false,
          perWeek: null,
          timesByWeekday: {'0': '12:00'},
        );
      default:
        return SuggestedSchedule(
          startDate: tomorrowStr,
          weekdays: [1, 2, 3, 4, 5],
          everyOtherDay: false,
          perWeek: null,
          timesByWeekday: {'0': '12:00'},
        );
    }
  }

  Future<void> _sendShares() async {
    setState(() => _sending = true);

    try {
      final schedule = _getScheduleFromPreset();
      final results = await _repo.shareFlow(
        flowId: widget.flowId,
        recipients: _recipients,
        suggestedSchedule: schedule,
      );

      if (!mounted) return;

      // Count successes
      final successCount = results.where((r) => r.status == 'sent').length;
      final failCount = results.length - successCount;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            successCount > 0
                ? 'Shared with $successCount ${successCount == 1 ? 'person' : 'people'}!'
                : 'Failed to share. Please try again.',
          ),
          backgroundColor: successCount > 0 ? const Color(0xFFD4AF37) : Colors.red,
        ),
      );

      if (successCount > 0) {
        Navigator.pop(context, true);
      }
    } catch (e) {
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
        setState(() => _sending = false);
      }
    }
  }
}
