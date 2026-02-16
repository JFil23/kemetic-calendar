import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/flows_repo.dart';
import '../../data/profile_repo.dart';
import '_post_glossy_helper.dart';

enum FlowPostTab { active, saved, maat }

class FlowPostPickerPage extends StatefulWidget {
  const FlowPostPickerPage({super.key});

  @override
  State<FlowPostPickerPage> createState() => _FlowPostPickerPageState();
}

class _FlowPostPickerPageState extends State<FlowPostPickerPage> {
  final _flowsRepo = FlowsRepo(Supabase.instance.client);
  final _profileRepo = ProfileRepo(Supabase.instance.client);

  FlowPostTab _tab = FlowPostTab.active;
  bool _loading = true;
  bool _posting = false;
  List<FlowRow> _flows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final flows = await _flowsRepo.listMyFlowsUnfiltered(limit: 400);
    if (!mounted) return;
    setState(() {
      _flows = flows;
      _loading = false;
    });
  }

  List<FlowRow> get _activeFlows =>
      _flows.where((f) => f.active && !f.isHidden).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  List<FlowRow> get _savedFlows =>
      _flows.where((f) => f.isSaved && !f.isHidden).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  List<FlowRow> get _maatFlows =>
      _flows
          .where((f) =>
              !f.isHidden &&
              (f.notes ?? '').toLowerCase().contains('maat='))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Future<void> _postFlow(int flowId) async {
    if (_posting) return;
    setState(() => _posting = true);
    final created = await _profileRepo.postFlow(flowId);
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
        backgroundColor: Color(0xFFD4AF37),
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final flows = switch (_tab) {
      FlowPostTab.active => _activeFlows,
      FlowPostTab.saved => _savedFlows,
      FlowPostTab.maat => _maatFlows,
    };

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0.5,
        title: const Text('Flow Studio', style: TextStyle(color: Colors.white)),
        actions: [
          if (_posting)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SegmentedButton<FlowPostTab>(
                    segments: const [
                      ButtonSegment(
                        value: FlowPostTab.active,
                        label: Text('Active Flows'),
                      ),
                      ButtonSegment(
                        value: FlowPostTab.saved,
                        label: Text('Saved Flows'),
                      ),
                      ButtonSegment(
                        value: FlowPostTab.maat,
                        label: Text("Ma'at Flows"),
                      ),
                    ],
                    selected: <FlowPostTab>{_tab},
                    onSelectionChanged: (v) {
                      if (v.isNotEmpty) {
                        setState(() => _tab = v.first);
                      }
                    },
                    style: ButtonStyle(
                      backgroundColor:
                          WidgetStateProperty.all(const Color(0xFF111111)),
                      foregroundColor: WidgetStateProperty.all(Colors.white),
                      side: WidgetStateProperty.all(
                        const BorderSide(color: Colors.white24),
                      ),
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: flows.isEmpty
                      ? _buildEmpty()
                      : ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: flows.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 12, color: Colors.white10),
                          itemBuilder: (ctx, i) {
                            final f = flows[i];
                            return ListTile(
                              onTap: () => _postFlow(f.id),
                              leading: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: glossFromColor(f.color),
                                ),
                              ),
                              title: Text(
                                f.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                f.isSaved
                                    ? 'Saved Flow'
                                    : (f.active ? 'Active' : 'Inactive'),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: Color(0xFFB0B0B0),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmpty() {
    final label = switch (_tab) {
      FlowPostTab.active => 'No active flows',
      FlowPostTab.saved => 'No saved flows',
      FlowPostTab.maat => "No Ma'at flows found",
    };
    final hint = switch (_tab) {
      FlowPostTab.active =>
          'Create a flow in Flow Studio to post it here.',
      FlowPostTab.saved =>
          'Save a flow first, then you can post it here.',
      FlowPostTab.maat =>
          "Start a Ma'at flow from Flow Studio, then post it here.",
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Gloss helper copied from Flow Studio styling
LinearGradient _glossFromColor(int color) {
  final base = Color(0xFF000000 | (color & 0x00FFFFFF));
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      base.withOpacity(0.9),
      base,
      base.withOpacity(0.8),
    ],
  );
}
