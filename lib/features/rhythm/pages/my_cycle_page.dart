import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobile/features/rhythm/rhythm_add_flow.dart';
import 'package:mobile/features/rhythm/rhythm_telemetry.dart';
import 'package:mobile/features/rhythm/rhythm_user_messages.dart';

import '../data/rhythm_repo.dart';
import '../models/rhythm_models.dart';
import '../theme/rhythm_theme.dart';
import 'rhythm_editors.dart';
import '../widgets/rhythm_row.dart';
import '../widgets/rhythm_section_card.dart';
import '../widgets/rhythm_states.dart';

class MyCyclePage extends StatefulWidget {
  const MyCyclePage({super.key});

  @override
  State<MyCyclePage> createState() => _MyCyclePageState();
}

class _MyCyclePageState extends State<MyCyclePage> {
  final RhythmRepo _repo = RhythmRepo(Supabase.instance.client);
  late Future<RhythmRepoResult<List<RhythmSection>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchMyCycle();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        RhythmTelemetry.trackScreen(Supabase.instance.client, 'my_cycle'),
      );
    });
  }

  void _refresh() {
    setState(() {
      _future = _repo.fetchMyCycle();
    });
  }

  Future<void> _openAddFlow() => openRhythmAddFlow(context, onSaved: _refresh);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cycle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddFlow,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: SafeArea(
        child: FutureBuilder<RhythmRepoResult<List<RhythmSection>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: RhythmLoadingShell(),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: RhythmErrorStateCard(
                  title: 'We lost the rhythm',
                  message: RhythmUserMessages.loadInterrupted,
                  onRetry: _refresh,
                ),
              );
            }

            final result = snapshot.data;

            if (result == null) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: RhythmErrorStateCard(
                  title: 'We lost the rhythm',
                  message:
                      'Something interrupted the flow. Try again in a breath.',
                  onRetry: _refresh,
                ),
              );
            }

            if (result.missingTables) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: RhythmErrorStateCard(
                  title: 'My Cycle isn’t ready yet.',
                  message:
                      'This environment is missing the rhythm tables. You can retry after migrations run.',
                  onRetry: _refresh,
                ),
              );
            }

            if (result.friendlyError != null) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: RhythmErrorStateCard(
                  title: 'We lost the rhythm',
                  message: RhythmUserMessages.loadFailedMyCycle,
                  onRetry: _refresh,
                ),
              );
            }

            final data = result.data;
            if (data.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: RhythmEmptyStateCard(
                  title: 'Welcome to My Cycle',
                  message:
                      'Start light. Choose a daily rhythm or craft your own anchor.',
                  primaryAction: ElevatedButton.icon(
                    onPressed: () => context.push('/rhythm/today'),
                    icon: const Icon(Icons.auto_fix_high_rounded),
                    label: const Text('Start with Rhythm of Day'),
                  ),
                  secondaryAction: OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await Navigator.of(context).push<bool>(
                        MaterialPageRoute<bool>(
                          builder: (_) => const CustomRhythmEditorPage(),
                        ),
                      );
                      if (ok == true && mounted) _refresh();
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add a custom item'),
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _HeroHeader(onAdd: _openAddFlow),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _ShortcutChip(
                      icon: Icons.brightness_5_rounded,
                      label: 'Planner',
                      onTap: () => context.push('/rhythm/today'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ...data.map(
                  (section) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: RhythmSectionCard(
                      title: section.title,
                      subtitle: section.subtitle,
                      child: Column(
                        children: [
                          for (int i = 0; i < section.items.length; i++) ...[
                            RhythmRow(item: section.items[i]),
                            if (i != section.items.length - 1)
                              const Divider(
                                height: 18,
                                thickness: 0.6,
                                color: Colors.white12,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('EEEE, MMM d');
    return Container(
      decoration: RhythmTheme.cardSurface(),
      padding: RhythmTheme.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Cycle', style: RhythmTheme.heading),
          const SizedBox(height: 6),
          Text(
            'Design the day that keeps you aligned, nourished, and steady.',
            style: RhythmTheme.subheading,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: RhythmTheme.frostSurface(),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatter.format(DateTime.now()),
                      style: RhythmTheme.subheading,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bring your rhythm into today or start something new.',
                      style: RhythmTheme.subheading.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(onPressed: onAdd, child: const Text('Add')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: RhythmTheme.frostSurface(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: RhythmTheme.aurora),
            const SizedBox(width: 10),
            Text(label, style: RhythmTheme.label),
          ],
        ),
      ),
    );
  }
}
