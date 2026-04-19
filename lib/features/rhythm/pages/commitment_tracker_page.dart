import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/core/touch_targets.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobile/features/rhythm/rhythm_telemetry.dart';
import 'package:mobile/features/rhythm/rhythm_user_messages.dart';

import '../data/rhythm_repo.dart';
import '../models/rhythm_models.dart';
import '../theme/rhythm_theme.dart';
import '../widgets/continuity_card.dart';
import '../widgets/rhythm_section_card.dart';
import '../widgets/rhythm_states.dart';

class CommitmentTrackerPage extends StatefulWidget {
  const CommitmentTrackerPage({super.key});

  @override
  State<CommitmentTrackerPage> createState() => _CommitmentTrackerPageState();
}

class _CommitmentTrackerPageState extends State<CommitmentTrackerPage> {
  final RhythmRepo _repo = RhythmRepo(Supabase.instance.client);
  late Future<RhythmRepoResult<List<ContinuitySnapshot>>> _future;
  String _scope = 'Yearly';

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchContinuity(scope: _scope);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        RhythmTelemetry.trackScreen(
          Supabase.instance.client,
          'commitment_tracker',
        ),
      );
    });
  }

  void _reload() {
    setState(() {
      _future = _repo.fetchContinuity(scope: _scope);
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat.MMMM().format(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Commitment Tracker')),
      body: SafeArea(
        child: FutureBuilder<RhythmRepoResult<List<ContinuitySnapshot>>>(
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
                  title: 'Tracker resting',
                  message: RhythmUserMessages.loadInterrupted,
                  onRetry: _reload,
                ),
              );
            }

            final result = snapshot.data;
            if (result == null) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: RhythmErrorStateCard(
                  title: 'Tracker resting',
                  message: RhythmUserMessages.loadInterrupted,
                  onRetry: _reload,
                ),
              );
            }

            if (result.missingTables) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: RhythmErrorStateCard(
                  title: 'Commitment Tracker isn’t ready yet.',
                  message:
                      'This environment is missing the rhythm tables. You can retry after migrations run.',
                  onRetry: _reload,
                ),
              );
            }

            if (result.friendlyError != null) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: RhythmErrorStateCard(
                  title: 'Tracker resting',
                  message: RhythmUserMessages.loadFailedTracker,
                  onRetry: _reload,
                ),
              );
            }

            final data = result.data;
            if (data.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: RhythmEmptyStateCard(
                  title: 'No tracked items',
                  message:
                      'Add a Rhythm item and enable continuity to see it here.',
                  primaryAction: ElevatedButton.icon(
                    onPressed: () => context.push('/rhythm/today'),
                    icon: const Icon(Icons.wb_sunny_outlined),
                    label: const Text('Open Planner'),
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                RhythmSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Commitment Tracker', style: RhythmTheme.heading),
                      const SizedBox(height: 6),
                      Text(
                        'See your steadiness over time. Unscheduled days stay neutral.',
                        style: RhythmTheme.subheading,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _ScopeChip(
                            label: 'Weekly',
                            selected: _scope == 'Weekly',
                            onTap: () => setState(() {
                              _scope = 'Weekly';
                              _future = _repo.fetchContinuity(scope: _scope);
                            }),
                          ),
                          const SizedBox(width: 8),
                          _ScopeChip(
                            label: 'Monthly',
                            selected: _scope == 'Monthly',
                            onTap: () => setState(() {
                              _scope = 'Monthly';
                              _future = _repo.fetchContinuity(scope: _scope);
                            }),
                          ),
                          const SizedBox(width: 8),
                          _ScopeChip(
                            label: 'Yearly',
                            selected: _scope == 'Yearly',
                            onTap: () => setState(() {
                              _scope = 'Yearly';
                              _future = _repo.fetchContinuity(scope: _scope);
                            }),
                          ),
                          const Spacer(),
                          Text(monthLabel, style: RhythmTheme.subheading),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ...data.map(
                  (snapshot) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: ContinuityCard(snapshot: snapshot),
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

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: withMinimumTouchTarget(
        context,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? RhythmTheme.aurora.withValues(alpha: 0.16)
                : Colors.white12,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? RhythmTheme.aurora : Colors.white24,
            ),
          ),
          child: Text(
            label,
            style: RhythmTheme.label.copyWith(
              color: selected ? RhythmTheme.aurora : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
