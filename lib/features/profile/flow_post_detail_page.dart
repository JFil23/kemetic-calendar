import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/flow_post_model.dart';
import '../../data/profile_repo.dart';
import '../inbox/shared_flow_details_page.dart';

class FlowPostDetailPage extends StatefulWidget {
  final FlowPost post;
  final bool isOwner;

  const FlowPostDetailPage({
    super.key,
    required this.post,
    required this.isOwner,
  });

  @override
  State<FlowPostDetailPage> createState() => _FlowPostDetailPageState();
}

class _FlowPostDetailPageState extends State<FlowPostDetailPage> {
  final _repo = ProfileRepo(Supabase.instance.client);
  bool _saving = false;
  bool _removing = false;

  @override
  Widget build(BuildContext context) {
    final payload = widget.post.payloadJson ??
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
          SharedFlowDetailsPage(
            payloadJson: payload,
            showImportFooter: false,
            showRemoveButton: widget.isOwner,
            onRemove: _remove,
          ),
          if (!widget.isOwner)
            SafeArea(
              minimum: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : const Text('Save Flow'),
                  ),
                ),
              ),
            ),
        ],
      ),
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
        backgroundColor: Color(0xFFD4AF37),
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
