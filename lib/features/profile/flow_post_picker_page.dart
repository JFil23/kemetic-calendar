import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/services/app_haptics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/shared/glossy_text.dart';

import '../../core/navigation_fallback.dart';
import '../../data/flows_repo.dart';
import '../../data/profile_repo.dart';
import '../calendar/calendar_page.dart';
import 'flow_post_caption_sheet.dart';
import 'posted_flow_artifact.dart';

bool canUserPublishFlow(FlowRow flow, String? currentUserId) {
  final normalizedUserId = currentUserId?.trim();
  return normalizedUserId != null &&
      normalizedUserId.isNotEmpty &&
      flow.userId == normalizedUserId;
}

class FlowPostPickerPage extends StatefulWidget {
  const FlowPostPickerPage({super.key});

  @override
  State<FlowPostPickerPage> createState() => _FlowPostPickerPageState();
}

class _FlowPostPickerPageState extends State<FlowPostPickerPage> {
  final _flowsRepo = FlowsRepo(Supabase.instance.client);
  final _profileRepo = ProfileRepo(Supabase.instance.client);

  bool _posting = false;
  List<FlowRow> _filedFlows = const <FlowRow>[];

  @override
  void initState() {
    super.initState();
    _restoreCachedThenRefresh();
  }

  Future<void> _restoreCachedThenRefresh() async {
    final cached = await _flowsRepo.restoreCachedFiledFlows();
    if (mounted && cached != null) {
      setState(() => _filedFlows = cached);
    }
    await _load();
  }

  Future<void> _load() async {
    final flows = await _flowsRepo.refreshMyFiledFlows();
    if (!mounted) return;
    setState(() => _filedFlows = flows);
  }

  FlowRow? _flowById(int flowId) {
    for (final flow in _filedFlows) {
      if (flow.id == flowId) return flow;
    }
    return null;
  }

  Future<void> _postFlowById(int flowId) async {
    var flow = _flowById(flowId);
    if (flow == null) {
      final refreshed = await _flowsRepo.refreshMyFiledFlows();
      if (!mounted) return;
      setState(() => _filedFlows = refreshed);
      flow = _flowById(flowId);
    }

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (flow == null || !canUserPublishFlow(flow, currentUserId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only flows you own can be posted.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    await _postFlow(flow);
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

  Future<void> _postFlow(FlowRow flow) async {
    if (_posting) return;
    final caption = await showFlowPostCaptionSheet(
      context: context,
      actionLabel: 'Post flow',
      preview: PostedFlowArtifact(
        name: flow.name,
        color: flow.color,
        notes: flow.notes,
        startDate: flow.startDate,
        endDate: flow.endDate,
        appearance: flow.appearance,
      ),
    );
    if (caption == null || !mounted) return;
    final hapticResult = await AppHaptics.productiveAction(
      reason: 'profile_flow_post',
    );
    if (!mounted) return;
    _showDebugHapticsSnackBar(hapticResult);
    setState(() => _posting = true);
    final created = await _profileRepo.postFlow(flow.id, sharedNote: caption);
    if (!mounted) return;
    setState(() => _posting = false);

    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not post this flow.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Flow posted to your profile'),
        backgroundColor: KemeticGold.base,
      ),
    );
    popOrGo(context, '/profile/me', result: true);
  }

  @override
  Widget build(BuildContext context) {
    return CalendarPage.buildMyFlowsPostingPage(
      navigator: Navigator.of(context),
      parentRoute: '/profile/flow-post-picker',
      flowsRepo: _flowsRepo,
      onFlowSelected: _postFlowById,
    );
  }
}
