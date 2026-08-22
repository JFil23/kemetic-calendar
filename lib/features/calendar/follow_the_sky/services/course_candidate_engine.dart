import '../domain/track_sky_course.dart';
import 'track_sky_course_source_identity.dart';

/// Input activity for deterministic course candidates.
class CourseActivitySignal {
  const CourseActivitySignal({
    required this.label,
    required this.sourceType,
    required this.sourceId,
    required this.occurrenceCount,
    required this.recentMinutes,
    required this.previousMinutes,
    this.isHidden = false,
    this.isSystemOrMaat = false,
    this.isActive = true,
  });

  final String label;
  final TrackSkyCourseSourceType sourceType;
  final String sourceId;
  final int occurrenceCount;
  final int recentMinutes;
  final int previousMinutes;
  final bool isHidden;
  final bool isSystemOrMaat;
  final bool isActive;
}

/// Pure Dart: calendar/flow activity → 0–4 candidates. No persistence. No AI.
class CourseCandidateEngine {
  const CourseCandidateEngine({
    this.maxCandidates = 4,
    this.minStrongCandidates = 2,
    this.minFlowOccurrences = 2,
    this.minEventTitleOccurrences = 3,
  });

  final int maxCandidates;
  final int minStrongCandidates;
  final int minFlowOccurrences;
  final int minEventTitleOccurrences;

  List<TrackSkyCourseCandidate> suggest(
    List<CourseActivitySignal> signals, {
    DateTime? now,
  }) {
    final qualified = <TrackSkyCourseCandidate>[];

    for (final signal in signals) {
      if (!signal.isActive || signal.isHidden || signal.isSystemOrMaat) {
        continue;
      }
      final label = signal.label.trim();
      if (label.isEmpty) continue;

      final minOcc = signal.sourceType == TrackSkyCourseSourceType.flow
          ? minFlowOccurrences
          : minEventTitleOccurrences;
      if (signal.occurrenceCount < minOcc) continue;

      final driftScore = _driftScore(
        previousMinutes: signal.previousMinutes,
        recentMinutes: signal.recentMinutes,
      );
      final commitmentBoost =
          (signal.recentMinutes / 60.0) + (signal.occurrenceCount * 2.0);
      final rankScore = commitmentBoost + (driftScore * 10.0);

      qualified.add(
        TrackSkyCourseCandidate(
          label: label,
          sourceType: signal.sourceType,
          sourceId: signal.sourceId,
          recentMinutes: signal.recentMinutes,
          previousMinutes: signal.previousMinutes,
          occurrenceCount: signal.occurrenceCount,
          driftScore: driftScore,
          rankScore: rankScore,
        ),
      );
    }

    if (qualified.length < minStrongCandidates) {
      return const [];
    }

    qualified.sort((a, b) {
      final byRank = b.rankScore.compareTo(a.rankScore);
      if (byRank != 0) return byRank;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });

    // Dedupe by normalized label, keep highest rank.
    final seen = <String>{};
    final out = <TrackSkyCourseCandidate>[];
    for (final c in qualified) {
      final key = TrackSkyCourseSourceIdentity.normalizeLabel(c.label);
      if (!seen.add(key)) continue;
      out.add(c);
      if (out.length >= maxCandidates) break;
    }
    return out;
  }

  /// ≥60m in previous 14d and ≥25% less in current 14d → positive drift boost.
  double _driftScore({
    required int previousMinutes,
    required int recentMinutes,
  }) {
    if (previousMinutes < 60) return 0;
    final drop = (previousMinutes - recentMinutes) / previousMinutes;
    if (drop >= 0.25) return drop;
    return 0;
  }
}
