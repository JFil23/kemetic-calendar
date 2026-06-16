enum LibraryChapterVisualState { read, current, unread }

class LibraryReadSnapshot {
  const LibraryReadSnapshot({
    this.readNodeIds = const <String>{},
    this.currentNodeId,
  });

  final Set<String> readNodeIds;
  final String? currentNodeId;
}

LibraryChapterVisualState resolveLibraryChapterVisualState({
  required String nodeId,
  required List<String> canonicalNodeIds,
  LibraryReadSnapshot readSnapshot = const LibraryReadSnapshot(),
}) {
  final normalizedNodeId = _normalizeNodeId(nodeId);
  final readIds = readSnapshot.readNodeIds.map(_normalizeNodeId).toSet();
  if (readIds.contains(normalizedNodeId)) {
    return LibraryChapterVisualState.read;
  }

  final currentNodeId = resolveCurrentLibraryNodeId(
    canonicalNodeIds: canonicalNodeIds,
    readSnapshot: readSnapshot,
  );
  if (currentNodeId != null && currentNodeId == normalizedNodeId) {
    return LibraryChapterVisualState.current;
  }

  return LibraryChapterVisualState.unread;
}

String? resolveCurrentLibraryNodeId({
  required List<String> canonicalNodeIds,
  LibraryReadSnapshot readSnapshot = const LibraryReadSnapshot(),
}) {
  final canonicalIds = canonicalNodeIds
      .map(_normalizeNodeId)
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  if (canonicalIds.isEmpty) return null;

  final readIds = readSnapshot.readNodeIds.map(_normalizeNodeId).toSet();
  final requestedCurrent = _normalizeNodeId(readSnapshot.currentNodeId);
  if (requestedCurrent.isNotEmpty &&
      canonicalIds.contains(requestedCurrent) &&
      !readIds.contains(requestedCurrent)) {
    return requestedCurrent;
  }

  for (final id in canonicalIds) {
    if (!readIds.contains(id)) return id;
  }
  return null;
}

String _normalizeNodeId(String? raw) => raw?.trim().toLowerCase() ?? '';
