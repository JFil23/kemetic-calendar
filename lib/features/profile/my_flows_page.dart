import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/flows_repo.dart';
import '_post_glossy_helper.dart';

enum MyFlowTab { active, saved }

class MyFlowsPage extends StatefulWidget {
  const MyFlowsPage({super.key});

  @override
  State<MyFlowsPage> createState() => _MyFlowsPageState();
}

class _MyFlowsPageState extends State<MyFlowsPage> {
  final _repo = FlowsRepo(Supabase.instance.client);
  bool _loading = true;
  List<FlowRow> _flows = const [];
  MyFlowTab _tab = MyFlowTab.active;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final flows = await _repo.listMyFlowsUnfiltered();
    if (!mounted) return;
    setState(() {
      _flows = flows;
      _loading = false;
    });
  }

  List<FlowRow> get _activeFlows =>
      _flows
          .where(
            (f) =>
                f.active &&
                _isActiveByEndDate(f.endDate) &&
                !f.isHidden,
          )
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  List<FlowRow> get _savedFlows =>
      _flows
          .where((f) => f.isSaved && !f.isHidden)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  bool _isActiveByEndDate(DateTime? endDate) {
    if (endDate == null) return true;
    final endUtc = endDate.toUtc();
    final endDateOnly = DateTime.utc(endUtc.year, endUtc.month, endUtc.day);
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    return !endDateOnly.isBefore(today);
  }

  @override
  Widget build(BuildContext context) {
    final items = _tab == MyFlowTab.active ? _activeFlows : _savedFlows;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFFD4AF37)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Flows',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<MyFlowTab>(
                    segments: const [
                      ButtonSegment(
                        value: MyFlowTab.active,
                        label: Text('Active Flows'),
                      ),
                      ButtonSegment(
                        value: MyFlowTab.saved,
                        label: Text('Saved Flows'),
                      ),
                    ],
                    selected: <MyFlowTab>{_tab},
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
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFD4AF37),
                      ),
                    ),
                  )
                : _buildList(items),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<FlowRow> items) {
    if (items.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFFD4AF37),
        backgroundColor: Colors.black,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tab == MyFlowTab.active
                        ? 'No active flows'
                        : 'No saved flows',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tab == MyFlowTab.active
                        ? 'Start or un-hide a flow to see it listed here.'
                        : 'Save a flow to keep it for later.',
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
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFD4AF37),
      backgroundColor: Colors.black,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Colors.white10),
        itemBuilder: (context, index) {
          final flow = items[index];
          final subtitleParts = <String>[];
          if (flow.isSaved) subtitleParts.add('Saved');
          subtitleParts.add(flow.active ? 'Active' : 'Inactive');
          if (flow.startDate != null || flow.endDate != null) {
            subtitleParts.add(
              '${_formatDate(flow.startDate)} → ${_formatDate(flow.endDate)}',
            );
          }

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            leading: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: glossFromColor(flow.color),
              ),
            ),
            title: Text(
              flow.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              subtitleParts.join(' • '),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '--';
    final d = date.toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}
