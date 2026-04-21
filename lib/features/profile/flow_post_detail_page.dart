import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/shared/glossy_text.dart';

import '../../data/flow_post_model.dart';
import '../../data/profile_repo.dart';
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
                    },
                    itemBuilder: (context, index) {
                      return SharedFlowDetailsPage(
                        key: ValueKey(_posts[index].id),
                        payloadJson: _payloadFor(_posts[index]),
                        showImportFooter: false,
                      );
                    },
                  )
                : SharedFlowDetailsPage(
                    payloadJson: _payloadFor(post),
                    showImportFooter: false,
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: widget.isOwner
                        ? _buildRemoveButton()
                        : _buildSaveButton(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saving ? null : _save,
      style: ElevatedButton.styleFrom(
        backgroundColor: KemeticGold.base,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: _saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            )
          : const Text('Save Flow'),
    );
  }

  Widget _buildRemoveButton() {
    return ElevatedButton(
      onPressed: _removing ? null : _remove,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
        foregroundColor: Colors.redAccent,
        side: const BorderSide(color: Colors.redAccent),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: _removing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
              ),
            )
          : const Text('Remove from profile'),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final flowId = await _repo.saveFlowPostToMyFlows(_activePost);
    if (!mounted) return;
    setState(() => _saving = false);
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

  Future<void> _remove() async {
    setState(() => _removing = true);
    final ok = await _repo.deleteFlowPost(_activePost.id);
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
    Navigator.of(context).pop(true);
  }
}
