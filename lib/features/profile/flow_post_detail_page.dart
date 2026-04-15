import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/shared/glossy_text.dart';

import '../../data/flow_post_model.dart';
import '../../data/profile_repo.dart';
import '../inbox/shared_flow_details_page.dart';
import 'flow_post_engagement_row.dart';

class FlowPostDetailPage extends StatefulWidget {
  final FlowPost post;
  final bool isOwner;
  final bool openCommentsOnLoad;

  const FlowPostDetailPage({
    super.key,
    required this.post,
    required this.isOwner,
    this.openCommentsOnLoad = false,
  });

  @override
  State<FlowPostDetailPage> createState() => _FlowPostDetailPageState();
}

class _FlowPostDetailPageState extends State<FlowPostDetailPage> {
  static const double _footerReservedHeight = 164;

  final _repo = ProfileRepo(Supabase.instance.client);
  bool _saving = false;
  bool _removing = false;

  @override
  Widget build(BuildContext context) {
    final payload =
        widget.post.payloadJson ??
        {
          'name': widget.post.name,
          'color': widget.post.color,
          'notes': widget.post.notes,
          'rules': widget.post.rules,
          'events': <dynamic>[],
          'start_date': widget.post.startDate?.toIso8601String(),
          'end_date': widget.post.endDate?.toIso8601String(),
        };

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          Positioned.fill(
            bottom: _footerReservedHeight,
            child: SharedFlowDetailsPage(
              payloadJson: payload,
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
                      post: widget.post,
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
    final flowId = await _repo.saveFlowPostToMyFlows(widget.post);
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
    final ok = await _repo.deleteFlowPost(widget.post.id);
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
