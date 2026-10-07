import '../../data/warm_state/warm_snapshot_store.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/shared/glossy_text.dart';

import '../../core/navigation_fallback.dart';
import '../../data/flow_post_model.dart';
import '../../data/profile_repo.dart';
import '../../data/account_operation_fence.dart';
import '../calendar/calendar_page.dart'
    show
        CalendarPage,
        FlowDetailActionPolicy,
        FlowDetailMenuAction,
        FlowDetailSource;
import '../inbox/shared_flow_details_page.dart';
import 'flow_post_engagement_row.dart';
import 'flow_post_share_actions.dart';
import '../calendar/calendar_invalidation.dart';

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
  final _repo = ProfileRepo(Supabase.instance.client);
  late List<FlowPost> _posts;
  late PageController _pageController;
  late int _activeIndex;
  bool _saving = false;
  bool _removing = false;
  bool _safetyActionRunning = false;
  final Map<String, int> _savedFlowIdsByPostId = <String, int>{};
  final Set<String> _saveLookupCompletePostIds = <String>{};
  final Map<String, Future<FlowPost?>> _fullPostFutures =
      <String, Future<FlowPost?>>{};

  FlowPost get _activePost => _posts[_activeIndex];
  bool get _showsPager => _posts.length > 1;
  bool _ownsPost(FlowPost post) =>
      widget.isOwner &&
      Supabase.instance.client.auth.currentUser?.id == post.userId;
  StreamSubscription<CalendarInvalidated>? _flowChangeSub;

  @override
  void initState() {
    super.initState();
    _posts = widget.posts != null && widget.posts!.isNotEmpty
        ? List<FlowPost>.unmodifiable(widget.posts!)
        : <FlowPost>[widget.post];
    final selected = _posts.indexWhere((post) => post.id == widget.post.id);
    _activeIndex = selected >= 0
        ? selected
        : widget.initialIndex.clamp(0, _posts.length - 1);
    _pageController = PageController(
      initialPage: _activeIndex,
      keepPage: false,
    );
    _refreshSavedStateFor(_activePost);
    _flowChangeSub = CalendarInvalidationBus.instance.stream.listen((event) {
      if (event.reason != CalendarInvalidationReason.flowStudioPersisted) {
        return;
      }
      for (final post in _posts.where(
        (post) => post.sourceFlowId == event.flowId,
      )) {
        unawaited(_refreshPost(post));
      }
    });
    // A complete navigation snapshot still needs a fresh read: another device
    // may have changed its source image since this card entered the warm view.
    unawaited(_refreshPost(_activePost));
    if (widget.openCommentsOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showFlowPostCommentsSheet(context: context, post: _activePost);
      });
    }
  }

  @override
  void didUpdateWidget(covariant FlowPostDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post || oldWidget.posts != widget.posts) {
      final selectedId = oldWidget.post.id != widget.post.id
          ? widget.post.id
          : _activePost.id;
      _posts = widget.posts != null && widget.posts!.isNotEmpty
          ? List<FlowPost>.of(widget.posts!)
          : [widget.post];
      final selected = _posts.indexWhere((post) => post.id == selectedId);
      _activeIndex = selected >= 0 ? selected : 0;
      _fullPostFutures.remove(widget.post.id);
      if (!_pageController.hasClients) {
        _pageController.dispose();
        _pageController = PageController(
          initialPage: _activeIndex,
          keepPage: false,
        );
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(_activeIndex);
          }
        });
      }
      _refreshSavedStateFor(_activePost);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _flowChangeSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshPost(FlowPost post) async {
    final account = AccountOperationFence(Supabase.instance.client);
    try {
      final updated = await _repo.getFlowPostById(post.id, strict: true);
      if (!mounted || !account.isCurrent || updated == null) return;
      setState(() {
        _posts = [
          for (final current in _posts)
            current.id == post.id ? updated : current,
        ];
        _fullPostFutures[post.id] = Future.value(updated);
      });
    } catch (_) {
      // Keep the acknowledged source detail visible if the social refresh fails.
    } finally {
      account.dispose();
    }
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

  bool _hasCompleteSnapshot(FlowPost post) {
    return post.payloadJson?['events'] is List;
  }

  Future<FlowPost?> _fullPostFor(FlowPost post) {
    if (_hasCompleteSnapshot(post)) return Future<FlowPost?>.value(post);
    return _fullPostFutures.putIfAbsent(
      post.id,
      () => _repo.getFlowPostById(post.id, strict: true),
    );
  }

  Widget _buildCanonicalDetail(FlowPost post) {
    if (_hasCompleteSnapshot(post)) {
      return _buildHydratedDetail(post);
    }
    return FutureBuilder<FlowPost?>(
      key: ValueKey(post.id),
      future: _fullPostFor(post),
      initialData: _repo.cachedFlowPostById(post.id),
      builder: (context, snapshot) {
        final confirmedGone =
            snapshot.error is WarmAccessDenied ||
            (snapshot.connectionState == ConnectionState.done &&
                !snapshot.hasError &&
                snapshot.data == null);
        final hydrated = confirmedGone
            ? null
            : snapshot.data ?? _repo.cachedFlowPostById(post.id);
        if (hydrated != null) return _buildHydratedDetail(hydrated);
        if (snapshot.connectionState == ConnectionState.done) {
          return const Center(child: Text('This flow is unavailable.'));
        }
        return const ColoredBox(
          color: Color(0xFF000000),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(KemeticGold.base),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHydratedDetail(FlowPost post) {
    return SharedFlowDetailsPage(
      key: ValueKey(post.id),
      payloadJson: _payloadFor(post),
      ownedSourceFlowId: _ownsPost(post) ? post.sourceFlowId : null,
      menuActions: _menuActionsFor(post),
      snapshotShareAction: FlowDetailMenuAction(
        id: 'share-post',
        label: 'Share Flow',
        icon: Icons.ios_share,
        onPressed: () => FlowPostShareActions.open(context, post),
      ),
      showImportFooter: false,
      actionPolicy: _actionPolicyFor(post),
      fallbackLocation: '/profile/${Uri.encodeComponent(post.userId)}',
    );
  }

  void _refreshSavedStateFor(FlowPost post) {
    if (_saveLookupCompletePostIds.contains(post.id)) return;
    _saveLookupCompletePostIds.add(post.id);
    unawaited(() async {
      final account = AccountOperationFence(Supabase.instance.client);
      try {
        final flowId = await _repo.getSavedFlowPostFlowId(post);
        if (!mounted || !account.isCurrent || flowId == null) return;
        setState(() => _savedFlowIdsByPostId[post.id] = flowId);
      } finally {
        account.dispose();
      }
    }());
  }

  FlowDetailActionPolicy _actionPolicyFor(FlowPost post) {
    final savedFlowId = _savedFlowIdsByPostId[post.id];
    if (_ownsPost(post)) {
      return CalendarPage.resolveCanonicalCustomFlowActionPolicy(
        source: FlowDetailSource.profilePost,
        isLocalFlow: false,
        isReadOnly: true,
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
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: _showsPager
                ? PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _posts.length,
                    onPageChanged: (index) {
                      setState(() => _activeIndex = index);
                      _refreshSavedStateFor(_posts[index]);
                      unawaited(_refreshPost(_posts[index]));
                    },
                    itemBuilder: (context, index) =>
                        _buildCanonicalDetail(_posts[index]),
                  )
                : _buildCanonicalDetail(post),
          ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(62, 10, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_showsPager)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int i = 0; i < _posts.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 7,
                              width: _activeIndex == i ? 18 : 7,
                              decoration: BoxDecoration(
                                color: _activeIndex == i
                                    ? KemeticGold.base
                                    : Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<FlowDetailMenuAction> _menuActionsFor(FlowPost post) {
    if (_ownsPost(post)) {
      return [
        FlowDetailMenuAction(
          id: 'remove-profile-post',
          label: _removing ? 'Removing...' : 'Remove from profile',
          icon: Icons.delete_outline,
          enabled: !_removing,
          onPressed: () => _removePost(post),
        ),
      ];
    }
    return [
      FlowDetailMenuAction(
        id: 'report-post',
        label: 'Report post',
        icon: Icons.flag_outlined,
        enabled: !_safetyActionRunning,
        onPressed: _reportPost,
      ),
      FlowDetailMenuAction(
        id: 'block-user',
        label: 'Block user',
        icon: Icons.block,
        enabled: !_safetyActionRunning,
        onPressed: _confirmBlockAuthor,
      ),
    ];
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
    final client = Supabase.instance.client;
    if (_removing ||
        !widget.isOwner ||
        client.auth.currentUser?.id != post.userId) {
      return;
    }
    final account = AccountOperationFence(client);
    setState(() => _removing = true);
    try {
      final ok = await _repo.deleteFlowPost(post.id);
      if (!mounted) return;
      setState(() => _removing = false);
      if (!account.isCurrent) return;
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
    } finally {
      account.dispose();
    }
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
