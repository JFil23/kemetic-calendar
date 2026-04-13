import 'package:flutter/material.dart';

import '../models/rhythm_models.dart';
import '../theme/rhythm_theme.dart';

class ContinuityCard extends StatelessWidget {
  const ContinuityCard({
    super.key,
    required this.snapshot,
  });

  final ContinuitySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: RhythmTheme.cardSurface(),
      padding: RhythmTheme.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: RhythmTheme.frostSurface(),
                child: Icon(snapshot.icon ?? Icons.auto_awesome_rounded, color: RhythmTheme.aurora),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(snapshot.title, style: RhythmTheme.heading.copyWith(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      '${snapshot.completed}/${snapshot.planned} days completed',
                      style: RhythmTheme.subheading,
                    ),
                  ],
                ),
              ),
              _PercentChip(percent: snapshot.percent),
            ],
          ),
          const SizedBox(height: 14),
          _ContinuityGrid(blocks: snapshot.blocks),
        ],
      ),
    );
  }
}

class _PercentChip extends StatelessWidget {
  const _PercentChip({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 1).toDouble();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: RhythmTheme.accentGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${(clamped * 100).round()}%',
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ContinuityGrid extends StatelessWidget {
  const _ContinuityGrid({required this.blocks});

  final List<ContinuityBlockState> blocks;

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) {
      return Text(
        'No schedule yet — add a pattern to start tracking.',
        style: RhythmTheme.subheading,
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: blocks.map(_block).toList(),
    );
  }

  Widget _block(ContinuityBlockState state) {
    final (color, border) = switch (state) {
      ContinuityBlockState.done => (RhythmTheme.aurora, RhythmTheme.aurora.withValues(alpha: 0.65)),
      ContinuityBlockState.partial => (RhythmTheme.ember, RhythmTheme.ember.withValues(alpha: 0.55)),
      ContinuityBlockState.skipped => (Colors.redAccent, Colors.redAccent.withValues(alpha: 0.6)),
      ContinuityBlockState.unscheduled => (Colors.white10, Colors.white12),
    };
    return Container(
      height: 28,
      width: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
    );
  }
}
