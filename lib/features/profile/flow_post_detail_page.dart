import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/shared/glossy_text.dart';

import '../../core/navigation_fallback.dart';
import '../../data/flow_post_model.dart';
import '../../data/profile_repo.dart';
import '../calendar/calendar_page.dart'
    show
        CalendarPage,
        FlowDetailActionKind,
        FlowDetailActionPolicy,
        FlowDetailSource;
import '../inbox/shared_flow_details_page.dart';
import 'flow_post_engagement_row.dart';

class FlowPostDetailPage extends StatefulWidget {
  final FlowPost post;
  final List<FlowPost>? posts;
  final int initialIndex;
  final bool isOwner;
  final bool openCommentsOnLoad;

  const FlowPostDetailPage({
    super.key,
    required this.post,
    this.posts,
    this.initialIndex = 0,
    required this.isOwner,
    this.openCommentsOnLoad = false,
  });

  @override
  State<FlowPostDetailPage> createState() => _FlowPostDetailPageState();
}

class _FlowPostDetailPageState extends State<FlowPostDetailPage> {
  static const double _baseFooterReservedHeight = 164;

  final _repo = ProfileRepo(Supabase.instance.client);
  late final List<FlowPost> _posts;
  late final PageController _pageController;
  late int _activeIndex;
  bool _saving = false;
  bool _removing = false;
  bool _safetyActionRunning = false;
  final Map<String, int> _savedFlowIdsByPostId = <String, int>{};
  final Set<String> _saveLookupCompletePostIds = <String>{};

  FlowPost get _activePost => _posts[_activeIndex];
  bool get _showsPager => _posts.length > 1;
  double get _footerReservedHeight =>
      _baseFooterReservedHeight + (_showsPager ? 34 : 0);

  @override
  void initState() {
    super.initState();
    _posts = widget.posts != null && widget.posts!.isNotEmpty
        ? List<FlowPost>.unmodifiable(widget.posts!)
        : <FlowPost>[widget.post];
    _activeIndex = widget.initialIndex.clamp(0, _posts.length - 1);
    _pageController = PageController(initialPage: _activeIndex);
    _refreshSavedStateFor(_activePost);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _payloadFor(FlowPost post) {
    return post.payloadJson ??
        {
          'name': post.name,
          'color': post.color,
          'notes': post.notes,
          'rules': post.rules,
          'events': <dynamic>[],
          'start_date': post.startDate?.toIso8601String(),
          'end_date': post.endDate?.toIso8601String(),
        };
  }

  void _refreshSavedStateFor(FlowPost post) {
    if (_saveLookupCompletePostIds.contains(post.id)) return;
    _saveLookupCompletePostIds.add(post.id);
    unawaited(() async {
      final flowId = await _repo.getSavedFlowPostFlowId(post);
      if (!mounted || flowId == null) return;
      setState(() => _savedFlowIdsByPostId[post.id] = flowId);
    }());
  }

  FlowDetailActionPolicy _actionPolicyFor(FlowPost post) {
    final savedFlowId = _savedFlowIdsByPostId[post.id];
    if (widget.isOwner) {
      return FlowDetailActionPolicy(
        source: FlowDetailSource.profilePost,
        kind: FlowDetailActionKind.manage,
        label: 'Remove from profile',
        busyLabel: 'Removing...',
        icon: Icons.delete_outline,
        busy: _removing,
        onPressed: () => _removePost(post),
      );
    }
    if (savedFlowId != null) {
      return CalendarPage.resolveCanonicalCustomFlowActionPolicy(
        source: FlowDetailSource.profilePost,
        isLocalFlow: true,
        isSaved: true,
        busy: _saving,
        onPressed: () => _openSavedFlow(savedFlowId, post),
      );
    }
    return CalendarPage.resolveCanonicalCustomFlowActionPolicy(
      source: FlowDetailSource.profilePost,
      isLocalFlow: false,
      isSaved: false,
      busy: _saving,
      onPressed: () => _savePost(post),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = _activePost;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          Positioned.fill(
            bottom: _footerReservedHeight,
            child: _showsPager
                ? PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _posts.length,
                    onPageChanged: (index) {
                      setState(() => _activeIndex = index);
                      _refreshSavedStateFor(_posts[index]);
                    },
                    itemBuilder: (context, index) {
                      return SharedFlowDetailsPage(
                        key: ValueKey(_posts[index].id),
                        payloadJson: _payloadFor(_posts[index]),
                        showImportFooter: false,
                        actionPolicy: _actionPolicyFor(_posts[index]),
                        fallbackLocation:
                            '/profile/${Uri.encodeComponent(_posts[index].userId)}',
                      );
                    },
                  )
                : SharedFlowDetailsPage(
                    payloadJson: _payloadFor(post),
                    showImportFooter: false,
                    actionPolicy: _actionPolicyFor(post),
                    fallbackLocation:
                        '/profile/${Uri.encodeComponent(post.userId)}',
                  ),
          ),
          SafeArea(
            minimum: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_showsPager) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < _posts.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: _activeIndex == i ? 18 : 8,
                            decoration: BoxDecoration(
                              color: _activeIndex == i
                                  ? KemeticGold.base
                                  : Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D0F),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: FlowPostEngagementRow(
                      key: ValueKey('detail_${post.id}'),
                      post: post,
                      autoOpenComments: widget.openCommentsOnLoad,
                    ),
                  ),
                  if (!widget.isOwner) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildSafetyMenu(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyMenu() {
    return PopupMenuButton<_FlowPostSafetyAction>(
      enabled: !_safetyActionRunning,
      tooltip: 'Post options',
      icon: const Icon(Icons.more_vert, color: Colors.white70),
      color: const Color(0xFF151515),
      onSelected: (action) {
        switch (action) {
          case _FlowPostSafetyAction.report:
            _reportPost();
            break;
          case _FlowPostSafetyAction.block:
            _confirmBlockAuthor();
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _FlowPostSafetyAction.report,
          child: Text('Report post'),
        ),
        PopupMenuItem(
          value: _FlowPostSafetyAction.block,
          child: Text('Block user'),
        ),
      ],
    );
  }

  Future<void> _savePost(FlowPost post) async {
    setState(() => _saving = true);
    final flowId = await _repo.saveFlowPostToMyFlows(post);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (flowId != null) _savedFlowIdsByPostId[post.id] = flowId;
    });
    if (flowId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save this flow.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Flow saved to your flows'),
        backgroundColor: KemeticGold.base,
      ),
    );
  }

  Future<void> _openSavedFlow(int flowId, FlowPost post) async {
    await CalendarPage.openFlowEditorFromAnyContext(
      context,
      flowId: flowId,
      fallbackLocation: '/profile/${Uri.encodeComponent(post.userId)}',
      source: 'profile_flow_post',
    );
  }

  Future<void> _removePost(FlowPost post) async {
    setState(() => _removing = true);
    final ok = await _repo.deleteFlowPost(post.id);
    if (!mounted) return;
    setState(() => _removing = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to remove this flow.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    popOrGo(
      context,
      '/profile/${Uri.encodeComponent(post.userId)}',
      result: true,
    );
  }

  Future<void> _reportPost() async {
    setState(() => _safetyActionRunning = true);
    final ok = await _repo.reportContent(
      contentType: 'flow_post',
      contentId: _activePost.id,
      reportedUserId: _activePost.userId,
      reason: 'user_report',
    );
    if (!mounted) return;
    setState(() => _safetyActionRunning = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Report sent.'
              : 'Could not send report. Please contact support.',
        ),
        backgroundColor: ok ? KemeticGold.base : Colors.red,
      ),
    );
  }

  Future<void> _confirmBlockAuthor() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D0F),
        title: const Text('Block user?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Their posts and comments will be hidden from your refreshed feeds.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Block user'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _blockAuthor();
  }

  Future<void> _blockAuthor() async {
    setState(() => _safetyActionRunning = true);
    final ok = await _repo.blockUser(_activePost.userId);
    if (!mounted) return;
    setState(() => _safetyActionRunning = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'User blocked.'
              : 'Could not block user. Please contact support.',
        ),
        backgroundColor: ok ? KemeticGold.base : Colors.red,
      ),
    );
    if (ok) {
      popOrGo(context, '/profile/me');
    }
  }
}

enum _FlowPostSafetyAction { report, block }
