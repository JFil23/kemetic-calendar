// Browser probe: production widgets and fonts, static data, no account access.
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/features/pages/pages_layout.dart';
import 'package:mobile/features/pages/pages_models.dart';
import 'package:mobile/features/profile/posted_flow_artifact.dart';

void main() => runApp(MaterialApp(theme: AppTheme.dark, home: const Probe()));

class Probe extends StatelessWidget {
  const Probe({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Rendering verification'),
        actions: [
          IconButton(
            tooltip: 'Load fallback glyphs',
            icon: const Icon(Icons.language),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Fallback glyphs'),
                content: const Text(
                  'Inter: Calendar Feed Planner\n'
                  '世界 مرحبا नमस्ते 🫠 🪷 𓇋 ḥꜣw',
                  style: TextStyle(fontFamily: AppFonts.ui, fontSize: 24),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Return to labels'),
                  ),
                ],
              ),
            ),
          ),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Pages'),
            Tab(text: 'Feed / fonts'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          PagesLayout(
            cards: [
              for (final destination in PagesDestination.values)
                ValueNotifier(
                  PagesCard(
                    destination,
                    state: PagesLoadState.ready,
                    meta: 'Visible serif reference',
                  ),
                ),
            ],
            onOpen: (_) {},
            onProfile: () {},
            onNewNote: () {},
            onSearchResult: (_) {},
            searchRecords: () => [],
            profileHandle: 'render-check',
          ),
          ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const PostedFlowArtifact(
                name: 'Measured Practice',
                color: 0xFF6F93A8,
                notes: 'The chosen Merkhet carries this flow.',
                appearance: FlowAppearance(signKind: FlowSignKind.palmCount),
              ),
              for (final weight in [
                FontWeight.w400,
                FontWeight.w500,
                FontWeight.w600,
                FontWeight.w700,
              ]) ...[
                Text(
                  'Inter ${weight.value}: Calendar Feed Planner 90 DAYS',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontWeight: weight,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'FLOW · PALM COUNT 1234567890',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontWeight: weight,
                    fontSize: 8,
                    height: 1,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Serif control: Calendar Feed Planner',
                style: TextStyle(fontFamily: 'GentiumPlus', fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
