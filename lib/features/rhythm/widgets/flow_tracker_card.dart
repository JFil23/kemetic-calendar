import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/flow_progress_repo.dart';
import '../../../shared/glossy_text.dart';
import '../theme/rhythm_theme.dart';

class FlowTrackerCard extends StatelessWidget {
  const FlowTrackerCard({super.key, required this.summary, this.onTap});

  final FlowTrackerSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _flowAccent(summary.flow.color);
    final pastDays = summary.days.length;
    final trackerLabel = pastDays == 0
        ? 'No flow days have passed yet.'
        : '$pastDays scheduled day${pastDays == 1 ? '' : 's'} have passed.';
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  summary.flow.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TrackerMetaChip(
                    label: pastDays == 0
                        ? 'Upcoming'
                        : '${summary.flowLengthDays}-day Flow',
                    accent: accent,
                    emphasis: true,
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            trackerLabel,
            style: RhythmTheme.label.copyWith(
              color: Colors.white60,
              fontSize: 11.5,
              letterSpacing: 0.15,
            ),
          ),
          if (pastDays > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final day in summary.days)
                  _FlowProgressSquare(day: day, accent: accent),
              ],
            ),
          ],
        ],
      ),
    );
    return Material(
      color: Colors.transparent,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: content,
            ),
    );
  }
}

class _FlowProgressSquare extends StatelessWidget {
  const _FlowProgressSquare({required this.day, required this.accent});

  final FlowTrackerDayProgress day;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final fill = day.eventCoverageFraction;
    return SizedBox(
      width: 18,
      height: 18,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: fill > 0
                ? accent.withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.20),
            width: 1.1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Positioned.fill(child: Container(color: Colors.transparent)),
              if (fill > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: fill,
                    child: Container(color: accent.withValues(alpha: 0.95)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackerMetaChip extends StatelessWidget {
  const _TrackerMetaChip({
    required this.label,
    required this.accent,
    this.emphasis = false,
  });

  final String label;
  final Color accent;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final foreground = emphasis ? Colors.white : Colors.white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: emphasis ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent.withValues(alpha: emphasis ? 0.34 : 0.18),
        ),
      ),
      child: Text(
        label,
        style: RhythmTheme.label.copyWith(
          color: foreground,
          fontWeight: emphasis ? FontWeight.w700 : FontWeight.w600,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

Color _flowAccent(int rgbColor) => Color(0xFF000000 | (rgbColor & 0x00FFFFFF));

Future<void> showFlowCommandSheet(
  BuildContext context, {
  required FlowTrackerSummary summary,
  required VoidCallback onShare,
  required VoidCallback onOpenJournal,
  required VoidCallback onViewFullFlow,
  required VoidCallback onStartNewFlow,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.black,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      final currentDayLabel = summary.currentFlowDayIndex <= 0
          ? 'Flow begins soon'
          : 'Flow Day ${summary.currentFlowDayIndex} of ${summary.flowLengthDays}';
      final flowRange = _formatRange(summary);
      final reflectionLabel = summary.daysUntilDecanReflection == 0
          ? 'Day 10 of ${summary.currentDecanName} is here.'
          : 'Day 10 of ${summary.currentDecanName} arrives in ${summary.daysUntilDecanReflection} day${summary.daysUntilDecanReflection == 1 ? '' : 's'}.';
      final nextEvent = summary.nextEvent;
      final nextReflection = summary.nextReflection;
      final nextReflectionText =
          nextReflection?.detail ??
          nextReflection?.title ??
          'Seal the day in your journal.';

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              GlossyText(
                text: summary.flow.name,
                gradient: goldGloss,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                summary.vowText,
                style: RhythmTheme.subheading.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              _InfoRow(label: 'Current Flow Day', value: currentDayLabel),
              _InfoRow(label: 'Flow Range', value: flowRange),
              _InfoRow(
                label: 'Current Decan',
                value:
                    '${summary.currentDecanName} • Day ${summary.currentDecanDay}',
              ),
              _InfoRow(
                label: 'Days Completed',
                value:
                    '${summary.daysWithProgress}/${summary.flowLengthDays} • score ${summary.progressScore.toStringAsFixed(1)}',
              ),
              _InfoRow(
                label: 'Badge / Activity Logs',
                value:
                    '${summary.badgeCount} badge${summary.badgeCount == 1 ? '' : 's'} • ${summary.reflectionCount} reflection${summary.reflectionCount == 1 ? '' : 's'}',
              ),
              const SizedBox(height: 16),
              Text(
                'On Day 10 of ${summary.currentDecanName}, hꜣw will reflect back what you practiced, what you completed, and what kind of order you created.',
                style: RhythmTheme.subheading.copyWith(
                  color: Colors.white,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                summary.startedMidDecan
                    ? 'You entered this Flow on Day ${summary.startDecanDay} of ${summary.startDecanName}. $reflectionLabel Your Flow will continue after that.'
                    : reflectionLabel,
                style: RhythmTheme.label.copyWith(
                  color: Colors.white70,
                  height: 1.45,
                ),
              ),
              if (summary.hasRolledIntoNewDecan) ...[
                const SizedBox(height: 12),
                Text(
                  'A new decan has opened. Continue this Flow, or begin another 10-day rhythm aligned to the new decan.',
                  style: RhythmTheme.label.copyWith(
                    color: Colors.white70,
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (nextEvent != null)
                _InfoRow(
                  label: 'Next Event / Action',
                  value: _formatEvent(nextEvent),
                ),
              _InfoRow(
                label: 'Next Reflection Prompt',
                value: nextReflectionText,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onShare,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RhythmTheme.aurora,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Share Flow'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onOpenJournal,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Open Journal'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onViewFullFlow,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('View Full Flow'),
                ),
              ),
              if (summary.hasRolledIntoNewDecan) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Continue Current Flow'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onStartNewFlow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RhythmTheme.aurora,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Begin New Decan Flow'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onViewFullFlow,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Refine Current Flow'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Not Now',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: RhythmTheme.label.copyWith(color: Colors.white54)),
          const SizedBox(height: 4),
          Text(
            value,
            style: RhythmTheme.subheading.copyWith(
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatRange(FlowTrackerSummary summary) {
  final formatter = DateFormat('MMM d');
  final startText = formatter.format(summary.effectiveStartDate.toLocal());
  final endText = formatter.format(summary.effectiveEndDate.toLocal());
  return '$startText – $endText';
}

String _formatEvent(FlowTrackerEventPreview event) {
  final dateText = event.allDay
      ? DateFormat('MMM d').format(event.startsAtLocal)
      : DateFormat('MMM d • h:mm a').format(event.startsAtLocal);
  final detail = event.detail?.trim();
  if (detail == null || detail.isEmpty) {
    return '${event.title} • $dateText';
  }
  return '${event.title} • $dateText\n$detail';
}
