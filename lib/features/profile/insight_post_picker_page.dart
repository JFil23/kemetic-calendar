import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/services/app_haptics.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/insight_entry_model.dart';
import '../../data/insight_entry_repo.dart';
import '../../data/insight_post_model.dart';
import '../../data/profile_repo.dart';
import '../../utils/kemetic_date_format.dart';

class InsightPostPickerPage extends StatefulWidget {
  const InsightPostPickerPage({super.key});

  @override
  State<InsightPostPickerPage> createState() => _InsightPostPickerPageState();
}

class _InsightPostPickerPageState extends State<InsightPostPickerPage> {
  final _entryRepo = InsightEntryRepo(Supabase.instance.client);
  final _profileRepo = ProfileRepo(Supabase.instance.client);

  bool _loading = true;
  String? _postingEntryId;
  List<InsightEntry> _entries = const [];
  Set<String> _postedEntryIds = const <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final entriesFuture = _entryRepo.fetchMyEntries(limit: 400);
    final Future<List<InsightPost>> postsFuture = currentUserId == null
        ? Future<List<InsightPost>>.value(const [])
        : _profileRepo.getInsightPosts(currentUserId);

    final entries = await entriesFuture;
    final postedPosts = await postsFuture;
    if (!mounted) return;

    final postedEntryIds = postedPosts
        .map((post) => post.insightEntryId)
        .toSet();

    setState(() {
      _entries = entries;
      _postedEntryIds = postedEntryIds;
      _loading = false;
    });
  }

  void _showDebugHapticsSnackBar(AppHapticResult result) {
    if (!kDebugMode || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Haptics: ${result.debugSummary}'),
          duration: const Duration(milliseconds: 900),
        ),
      );
  }

  Future<void> _postInsight(InsightEntry entry) async {
    if (_postingEntryId != null) return;

    final hapticResult = await AppHaptics.productiveAction(
      reason: 'profile_insight_post',
    );
    if (!mounted) return;
    _showDebugHapticsSnackBar(hapticResult);

    setState(() => _postingEntryId = entry.id);
    final created = await _profileRepo.postInsightEntry(entry.id);
    if (!mounted) return;
    setState(() => _postingEntryId = null);

    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not post this insight.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _postedEntryIds.contains(entry.id)
              ? 'Posted insight updated on your profile'
              : 'Insight posted to your profile',
        ),
        backgroundColor: KemeticGold.base,
      ),
    );
    Navigator.of(context).pop(true);
  }

  String _previewText(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? 'No text' : normalized;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0.5,
        title: const Text(
          'Insight Studio',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(KemeticGold.base),
              ),
            )
          : _entries.isEmpty
          ? _buildEmpty()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: _entries.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 12, color: Colors.white10),
              itemBuilder: (context, index) {
                final entry = _entries[index];
                final isPosted = _postedEntryIds.contains(entry.id);
                final isPosting = _postingEntryId == entry.id;

                return ListTile(
                  onTap: isPosting ? null : () => _postInsight(entry),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      entry.nodeGlyph?.trim().isNotEmpty == true
                          ? entry.nodeGlyph!
                          : (entry.nodeTitle.isNotEmpty
                                ? entry.nodeTitle[0].toUpperCase()
                                : '?'),
                      style: const TextStyle(
                        color: KemeticGold.base,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.nodeTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isPosted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: KemeticGold.base.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: KemeticGold.base.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Text(
                            'On Profile',
                            style: TextStyle(
                              color: KemeticGold.base,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatKemeticDate(entry.entryDate),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.56),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _previewText(entry.bodyText),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 13,
                            height: 1.32,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: isPosting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              KemeticGold.base,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.chevron_right,
                          color: Color(0xFFB0B0B0),
                        ),
                );
              },
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No insights yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Write an insight inside a node page first, then you can post it here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
