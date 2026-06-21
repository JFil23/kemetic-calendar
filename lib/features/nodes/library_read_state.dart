import 'package:flutter/foundation.dart';

const double kLibraryMeaningfulProgressPercent = 5;
const double kLibraryCompletionProgressPercent = 92;

enum LibraryChapterVisualState { unread, inProgress, current, completed }

@immutable
class LibraryNodeProgress {
  const LibraryNodeProgress({
    required this.nodeId,
    this.progressPercent = 0,
    this.lastScrollOffset = 0,
    this.openedAt,
    this.lastReadAt,
    this.completedAt,
    this.bookmarkedAt,
    this.bookmarkScrollOffset,
    this.createdAt,
    this.updatedAt,
  });

  final String nodeId;
  final double progressPercent;
  final double lastScrollOffset;
  final DateTime? openedAt;
  final DateTime? lastReadAt;
  final DateTime? completedAt;
  final DateTime? bookmarkedAt;
  final double? bookmarkScrollOffset;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get normalizedNodeId => normalizeLibraryNodeId(nodeId);

  double get normalizedProgressPercent =>
      progressPercent.clamp(0, 100).toDouble();

  bool get isCompleted => completedAt != null;

  bool get isBookmarked => bookmarkedAt != null;

  bool get isInProgress =>
      !isCompleted && (normalizedProgressPercent > 0 || lastScrollOffset > 0);

  bool get hasMeaningfulResumeProgress =>
      !isCompleted &&
      normalizedProgressPercent >= kLibraryMeaningfulProgressPercent;

  double? get resumeScrollOffset {
    if (isCompleted) return null;
    return bookmarkScrollOffset ?? lastScrollOffset;
  }

  DateTime get automaticResumeTime =>
      lastReadAt ??
      openedAt ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  DateTime get conflictTime =>
      updatedAt ??
      lastReadAt ??
      openedAt ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'nodeId': nodeId,
      'progressPercent': normalizedProgressPercent,
      'lastScrollOffset': lastScrollOffset,
      'openedAt': openedAt?.toIso8601String(),
      'lastReadAt': lastReadAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'bookmarkedAt': bookmarkedAt?.toIso8601String(),
      'bookmarkScrollOffset': bookmarkScrollOffset,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static LibraryNodeProgress? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final nodeId = _stringValue(raw['nodeId']);
    if (nodeId == null || normalizeLibraryNodeId(nodeId).isEmpty) return null;
    return LibraryNodeProgress(
      nodeId: nodeId,
      progressPercent: _doubleValue(raw['progressPercent']) ?? 0,
      lastScrollOffset: _doubleValue(raw['lastScrollOffset']) ?? 0,
      openedAt: _dateValue(raw['openedAt']),
      lastReadAt: _dateValue(raw['lastReadAt']),
      completedAt: _dateValue(raw['completedAt']),
      bookmarkedAt: _dateValue(raw['bookmarkedAt']),
      bookmarkScrollOffset: _doubleValue(raw['bookmarkScrollOffset']),
      createdAt: _dateValue(raw['createdAt']),
      updatedAt: _dateValue(raw['updatedAt']),
    );
  }
}

@immutable
class LibraryReadSnapshot {
  const LibraryReadSnapshot({
    this.progressByNodeId = const <String, LibraryNodeProgress>{},
  });

  final Map<String, LibraryNodeProgress> progressByNodeId;

  LibraryNodeProgress? progressFor(String nodeId) {
    return progressByNodeId[normalizeLibraryNodeId(nodeId)];
  }
}

LibraryChapterVisualState resolveLibraryChapterVisualState({
  required String nodeId,
  required List<String> canonicalNodeIds,
  LibraryReadSnapshot readSnapshot = const LibraryReadSnapshot(),
}) {
  final normalizedNodeId = normalizeLibraryNodeId(nodeId);
  final progress = readSnapshot.progressFor(normalizedNodeId);
  if (progress?.isCompleted ?? false) {
    return LibraryChapterVisualState.completed;
  }

  final currentNodeId = resolveCurrentLibraryNodeId(
    canonicalNodeIds: canonicalNodeIds,
    readSnapshot: readSnapshot,
  );
  if (currentNodeId != null && currentNodeId == normalizedNodeId) {
    return LibraryChapterVisualState.current;
  }

  if (progress?.isInProgress ?? false) {
    return LibraryChapterVisualState.inProgress;
  }

  return LibraryChapterVisualState.unread;
}

String? resolveCurrentLibraryNodeId({
  required List<String> canonicalNodeIds,
  LibraryReadSnapshot readSnapshot = const LibraryReadSnapshot(),
}) {
  final canonicalIds = canonicalNodeIds
      .map(normalizeLibraryNodeId)
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  if (canonicalIds.isEmpty) return null;

  final canonicalIdSet = canonicalIds.toSet();
  final bookmarkCandidates = readSnapshot.progressByNodeId.values.where(
    (progress) =>
        canonicalIdSet.contains(progress.normalizedNodeId) &&
        progress.isBookmarked &&
        !progress.isCompleted,
  );
  final bookmarked = _mostRecentBy(
    bookmarkCandidates,
    (progress) => progress.bookmarkedAt,
  );
  if (bookmarked != null) return bookmarked.normalizedNodeId;

  final resumeCandidates = readSnapshot.progressByNodeId.values.where(
    (progress) =>
        canonicalIdSet.contains(progress.normalizedNodeId) &&
        progress.hasMeaningfulResumeProgress,
  );
  final latestUnfinished = _mostRecentBy(
    resumeCandidates,
    (progress) => progress.automaticResumeTime,
  );
  return latestUnfinished?.normalizedNodeId;
}

String normalizeLibraryNodeId(String? raw) => raw?.trim().toLowerCase() ?? '';

Map<String, LibraryNodeProgress> mergeLibraryProgressMaps(
  Iterable<Map<String, LibraryNodeProgress>> sources,
) {
  final merged = <String, LibraryNodeProgress>{};
  for (final source in sources) {
    for (final progress in source.values) {
      final nodeId = progress.normalizedNodeId;
      if (nodeId.isEmpty) continue;
      final resolved = mergeLibraryNodeProgress(merged[nodeId], progress);
      if (resolved != null) {
        merged[nodeId] = resolved;
      }
    }
  }
  return merged;
}

LibraryNodeProgress? mergeLibraryNodeProgress(
  LibraryNodeProgress? left,
  LibraryNodeProgress? right,
) {
  if (left == null) return right;
  if (right == null) return left;

  final leftCompleted = left.isCompleted;
  final rightCompleted = right.isCompleted;
  if (leftCompleted != rightCompleted) {
    return leftCompleted ? left : right;
  }

  if (right.conflictTime.isAfter(left.conflictTime)) {
    return right;
  }
  return left;
}

LibraryNodeProgress? _mostRecentBy(
  Iterable<LibraryNodeProgress> progress,
  DateTime? Function(LibraryNodeProgress progress) readTime,
) {
  LibraryNodeProgress? best;
  DateTime? bestTime;
  for (final candidate in progress) {
    final candidateTime = readTime(candidate);
    if (candidateTime == null) continue;
    if (bestTime == null || candidateTime.isAfter(bestTime)) {
      best = candidate;
      bestTime = candidateTime;
    }
  }
  return best;
}

String? _stringValue(Object? raw) {
  if (raw is String) return raw;
  return null;
}

double? _doubleValue(Object? raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw);
  return null;
}

DateTime? _dateValue(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}
