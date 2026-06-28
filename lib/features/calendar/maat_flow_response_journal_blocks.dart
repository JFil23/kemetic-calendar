import 'package:mobile/features/journal/journal_v2_document_model.dart';

import 'maat_flow_response_models.dart';

const String kMaatJournalResponseBlockIdPrefix = 'maat_response:';
const String kMaatJournalPlainTextSourceMetaKey =
    'maat_plain_user_text_sources';

class MaatJournalResponseBlock {
  const MaatJournalResponseBlock({
    required this.sourceId,
    required this.text,
    this.localDate,
  }) : assert(sourceId.length > 0);

  final String sourceId;
  final String text;
  final DateTime? localDate;

  String get blockId => maatJournalResponseBlockId(sourceId);
}

typedef MaatJournalResponseBlockWriter =
    Future<void> Function(MaatJournalResponseBlock block);

List<MaatJournalResponseBlock> buildMaatJournalResponseBlocksForPolicy({
  required Iterable<String> sourceIds,
  required Iterable<MaatFlowResponseJournalPreview> previews,
  required DateTime localDate,
  Set<String> includedOfferSourceIds = const <String>{},
}) {
  final previewsBySourceId = <String, MaatFlowResponseJournalPreview>{
    for (final preview in previews) preview.sourceId: preview,
  };
  return sourceIds
      .map((sourceId) {
        final preview = previewsBySourceId[sourceId];
        final text = _journalTextForPolicy(
          preview,
          includedOfferSourceIds: includedOfferSourceIds,
        );
        return MaatJournalResponseBlock(
          sourceId: sourceId,
          text: text,
          localDate: localDate,
        );
      })
      .toList(growable: false);
}

List<MaatJournalResponseBlock> buildMaatJournalPlainUserTextBlocks({
  required Iterable<String> sourceIds,
  required List<MaatFlowResponseSpec> specs,
  required Map<String, MaatFlowResponseValue> values,
  required DateTime localDate,
  required bool includeText,
  required String Function(MaatFlowResponseSpec spec) sourceIdForSpec,
  required String Function(MaatFlowResponseSpec spec, String groupId)
  sourceIdForGroup,
}) {
  final textBySourceId = <String, List<String>>{};
  if (includeText) {
    for (final spec in specs) {
      if (!spec.journalCarryMode.carriesPlainUserText) continue;
      if (!_isPlainUserTextResponseKind(spec.kind)) continue;
      final value = values[spec.id];
      final text = value?.text?.trim();
      if (text == null || text.isEmpty) continue;
      final groupId = spec.normalizedJournalGroupId;
      final sourceId = groupId == null
          ? sourceIdForSpec(spec)
          : sourceIdForGroup(spec, groupId);
      textBySourceId.putIfAbsent(sourceId, () => <String>[]).add(text);
    }
  }

  final orderedSourceIds = <String>[];
  final seen = <String>{};
  for (final sourceId in sourceIds) {
    final trimmed = sourceId.trim();
    if (trimmed.isEmpty || !seen.add(trimmed)) continue;
    orderedSourceIds.add(trimmed);
  }
  for (final sourceId in textBySourceId.keys) {
    final trimmed = sourceId.trim();
    if (trimmed.isEmpty || !seen.add(trimmed)) continue;
    orderedSourceIds.add(trimmed);
  }

  return orderedSourceIds
      .map(
        (sourceId) => MaatJournalResponseBlock(
          sourceId: sourceId,
          text: (textBySourceId[sourceId] ?? const <String>[])
              .map((text) => text.trim())
              .where((text) => text.isNotEmpty)
              .join('\n\n'),
          localDate: localDate,
        ),
      )
      .toList(growable: false);
}

bool _isPlainUserTextResponseKind(MaatFlowResponseKind kind) {
  switch (kind) {
    case MaatFlowResponseKind.text:
    case MaatFlowResponseKind.multiline:
    case MaatFlowResponseKind.statusNote:
      return true;
    case MaatFlowResponseKind.choice:
    case MaatFlowResponseKind.chips:
    case MaatFlowResponseKind.checkbox:
      return false;
  }
}

String _journalTextForPolicy(
  MaatFlowResponseJournalPreview? preview, {
  required Set<String> includedOfferSourceIds,
}) {
  if (preview == null) return '';
  switch (preview.policy) {
    case MaatFlowJournalPolicy.mirror:
    case MaatFlowJournalPolicy.redactedSummary:
      return preview.text;
    case MaatFlowJournalPolicy.offer:
      return includedOfferSourceIds.contains(preview.sourceId)
          ? preview.text
          : '';
    case MaatFlowJournalPolicy.localOnly:
      return '';
  }
}

String maatJournalResponseBlockId(String sourceId) {
  return '$kMaatJournalResponseBlockIdPrefix${Uri.encodeComponent(sourceId.trim())}';
}

String? maatJournalResponseSourceIdFromBlockId(String blockId) {
  if (!blockId.startsWith(kMaatJournalResponseBlockIdPrefix)) return null;
  final encoded = blockId.substring(kMaatJournalResponseBlockIdPrefix.length);
  if (encoded.trim().isEmpty) return null;
  return Uri.decodeComponent(encoded);
}

class MaatJournalResponseBlockUtils {
  const MaatJournalResponseBlockUtils._();

  static JournalDocument upsert(
    JournalDocument document,
    MaatJournalResponseBlock block,
  ) {
    final normalizedText = block.text.trim();
    if (normalizedText.isEmpty) {
      return remove(document, block.sourceId);
    }

    final nextBlock = ParagraphBlock(
      id: block.blockId,
      ops: <TextOp>[TextOp(insert: normalizedText)],
    );
    final blocks = List<JournalBlock>.from(document.blocks);
    final index = blocks.indexWhere(
      (candidate) => candidate.id == block.blockId,
    );
    if (index >= 0) {
      blocks[index] = nextBlock;
    } else {
      blocks.add(nextBlock);
    }

    return JournalDocument(
      version: document.version,
      blocks: blocks,
      meta: Map<String, dynamic>.from(document.meta),
    );
  }

  static JournalDocument remove(JournalDocument document, String sourceId) {
    final blockId = maatJournalResponseBlockId(sourceId);
    final blocks = document.blocks
        .where((block) => block.id != blockId)
        .toList(growable: false);
    if (blocks.length == document.blocks.length) return document;

    return JournalDocument(
      version: document.version,
      blocks: blocks,
      meta: Map<String, dynamic>.from(document.meta),
    );
  }

  static JournalDocument upsertPlainUserText(
    JournalDocument document,
    MaatJournalResponseBlock block,
  ) {
    final sourceId = block.sourceId.trim();
    if (sourceId.isEmpty) return document;

    final normalizedText = block.text.trim();
    if (normalizedText.isEmpty) {
      return removePlainUserText(document, sourceId);
    }

    final meta = Map<String, dynamic>.from(document.meta);
    final sources = _plainTextSourceMap(meta);
    final previousText = sources[sourceId]?.trim();
    final blocks = document.blocks
        .where(
          (candidate) => !_isLegacyGeneratedResponseBlock(candidate, sourceId),
        )
        .toList(growable: true);

    if (previousText != null && previousText.isNotEmpty) {
      final paragraphIndex = _editableParagraphIndex(blocks);
      if (paragraphIndex >= 0) {
        final paragraph = blocks[paragraphIndex] as ParagraphBlock;
        final replacement = _replacePlainTextInOps(
          paragraph.ops,
          previousText: previousText,
          nextText: normalizedText,
        );
        if (replacement.changed) {
          blocks[paragraphIndex] = ParagraphBlock(
            id: paragraph.id,
            ops: replacement.ops,
          );
          sources[sourceId] = normalizedText;
          _writePlainUserTextSources(meta, sources);
          return JournalDocument(
            version: document.version,
            blocks: blocks,
            meta: meta,
          );
        }
      }

      // The carried text was edited or moved in the Journal. Keep the source
      // marker so later flow saves do not append duplicates or overwrite prose.
      _writePlainUserTextSources(meta, sources);
      return JournalDocument(
        version: document.version,
        blocks: blocks,
        meta: meta,
      );
    }

    var paragraphIndex = _editableParagraphIndex(blocks);
    if (paragraphIndex < 0) {
      blocks.insert(
        0,
        ParagraphBlock(
          id: 'p-${DateTime.now().millisecondsSinceEpoch}',
          ops: const <TextOp>[TextOp(insert: '\n')],
        ),
      );
      paragraphIndex = 0;
    }

    final paragraph = blocks[paragraphIndex] as ParagraphBlock;
    final ops = _appendPlainTextToOps(paragraph.ops, normalizedText);
    blocks[paragraphIndex] = ParagraphBlock(id: paragraph.id, ops: ops);
    sources[sourceId] = normalizedText;
    _writePlainUserTextSources(meta, sources);

    return JournalDocument(
      version: document.version,
      blocks: blocks,
      meta: meta,
    );
  }

  static JournalDocument removePlainUserText(
    JournalDocument document,
    String sourceId,
  ) {
    final normalizedSourceId = sourceId.trim();
    if (normalizedSourceId.isEmpty) return document;

    final meta = Map<String, dynamic>.from(document.meta);
    final sources = _plainTextSourceMap(meta);
    final previousText = sources[normalizedSourceId]?.trim();
    final blocks = document.blocks
        .where(
          (candidate) =>
              !_isLegacyGeneratedResponseBlock(candidate, normalizedSourceId),
        )
        .toList(growable: true);

    if (previousText != null && previousText.isNotEmpty) {
      final paragraphIndex = _editableParagraphIndex(blocks);
      if (paragraphIndex >= 0) {
        final paragraph = blocks[paragraphIndex] as ParagraphBlock;
        final removal = _removePlainTextFromOps(paragraph.ops, previousText);
        if (removal.changed) {
          blocks[paragraphIndex] = ParagraphBlock(
            id: paragraph.id,
            ops: removal.ops,
          );
          sources.remove(normalizedSourceId);
        }
      }
    } else {
      sources.remove(normalizedSourceId);
    }

    _writePlainUserTextSources(meta, sources);

    return JournalDocument(
      version: document.version,
      blocks: blocks,
      meta: meta,
    );
  }

  static List<MaatJournalResponseBlock> extract(JournalDocument document) {
    final responseBlocks = <MaatJournalResponseBlock>[];
    for (final block in document.blocks) {
      final sourceId = maatJournalResponseSourceIdFromBlockId(block.id);
      if (sourceId == null) continue;
      if (block is! ParagraphBlock) continue;
      responseBlocks.add(
        MaatJournalResponseBlock(
          sourceId: sourceId,
          text: block.ops.map((op) => op.insert).join(),
        ),
      );
    }
    return responseBlocks;
  }

  static Map<String, String> extractPlainUserTextSources(
    JournalDocument document,
  ) {
    return Map<String, String>.unmodifiable(_plainTextSourceMap(document.meta));
  }
}

Map<String, String> _plainTextSourceMap(Map<String, dynamic> meta) {
  final raw = meta[kMaatJournalPlainTextSourceMetaKey];
  if (raw is! Map) return <String, String>{};
  return <String, String>{
    for (final entry in raw.entries)
      if (entry.key.toString().trim().isNotEmpty)
        entry.key.toString().trim(): entry.value?.toString() ?? '',
  };
}

void _writePlainUserTextSources(
  Map<String, dynamic> meta,
  Map<String, String> sources,
) {
  if (sources.isEmpty) {
    meta.remove(kMaatJournalPlainTextSourceMetaKey);
  } else {
    meta[kMaatJournalPlainTextSourceMetaKey] = sources;
  }
}

bool _isLegacyGeneratedResponseBlock(JournalBlock block, String sourceId) {
  if (block.id != maatJournalResponseBlockId(sourceId)) return false;
  if (block is! ParagraphBlock) return false;
  final text = block.ops.map((op) => op.insert).join();
  return _looksLikeLegacyGeneratedResponseText(text);
}

bool _looksLikeLegacyGeneratedResponseText(String text) {
  final normalized = text.trim();
  if (normalized.isEmpty || normalized.contains('\n')) return false;

  final separatorIndex = normalized.indexOf(': ');
  if (separatorIndex <= 1 || separatorIndex > 96) return false;

  final heading = normalized.substring(0, separatorIndex).trim();
  final body = normalized.substring(separatorIndex + 2).trim();
  if (heading.isEmpty || body.isEmpty) return false;
  if (!RegExp(r'[A-Za-z]').hasMatch(heading)) return false;

  return _legacyGeneratedBodyPrefixes.any(body.startsWith);
}

const List<String> _legacyGeneratedBodyPrefixes = <String>[
  'I began ',
  'I brought ',
  'I carry ',
  'I cooled ',
  'I created ',
  'I gave ',
  'I honored ',
  'I kept ',
  'I listened ',
  'I made ',
  'I named ',
  'I noticed ',
  'I observed ',
  'I open ',
  'I placed ',
  'I preserved ',
  'I provided ',
  'I put ',
  'I received ',
  'I release ',
  'I restored ',
  'I turned ',
  'Response recorded.',
];

int _editableParagraphIndex(List<JournalBlock> blocks) {
  return blocks.indexWhere(
    (block) =>
        block is ParagraphBlock &&
        maatJournalResponseSourceIdFromBlockId(block.id) == null,
  );
}

({List<TextOp> ops, bool changed}) _replacePlainTextInOps(
  List<TextOp> ops, {
  required String previousText,
  required String nextText,
}) {
  for (var i = 0; i < ops.length; i++) {
    final op = ops[i];
    if (_hasTrailingNonEmptyOps(ops, i)) continue;
    final index = _trailingPlainTextSegmentStart(op.insert, previousText);
    if (index == null) continue;
    final updated = op.insert.replaceRange(index, op.insert.length, nextText);
    return (
      ops: <TextOp>[
        ...ops.take(i),
        op.copyWith(insert: updated),
        ...ops.skip(i + 1),
      ],
      changed: true,
    );
  }
  return (ops: ops, changed: false);
}

bool _hasTrailingNonEmptyOps(List<TextOp> ops, int index) {
  return ops.skip(index + 1).any((op) => op.insert.trim().isNotEmpty);
}

int? _trailingPlainTextSegmentStart(String insert, String text) {
  if (!insert.endsWith(text)) return null;
  final index = insert.length - text.length;
  final prefix = insert.substring(0, index);
  if (prefix.isEmpty || prefix.trim().isEmpty || prefix.endsWith('\n')) {
    return index;
  }
  return null;
}

List<TextOp> _appendPlainTextToOps(List<TextOp> ops, String text) {
  final existingText = ops.map((op) => op.insert).join();
  if (existingText.trim().isEmpty) {
    return <TextOp>[TextOp(insert: text)];
  }
  final spacer = existingText.endsWith('\n') ? '\n' : '\n\n';
  return <TextOp>[...ops, TextOp(insert: '$spacer$text')];
}

({List<TextOp> ops, bool changed}) _removePlainTextFromOps(
  List<TextOp> ops,
  String text,
) {
  var changed = false;
  final nextOps = <TextOp>[];
  for (var i = 0; i < ops.length; i++) {
    final op = ops[i];
    final insert = op.insert;
    if (_hasTrailingNonEmptyOps(ops, i)) {
      nextOps.add(op);
      continue;
    }

    final index = _trailingPlainTextSegmentStart(insert, text);
    if (index == null) {
      nextOps.add(op);
      continue;
    }

    final prefix = insert.substring(0, index);
    if (prefix.trim().isEmpty) {
      changed = true;
      continue;
    }

    var updated = prefix.replaceFirst(RegExp(r'\n{1,2}$'), '');
    if (updated.isNotEmpty) {
      nextOps.add(op.copyWith(insert: updated));
    }
    changed = true;
  }

  return (
    ops: nextOps.isEmpty ? const <TextOp>[TextOp(insert: '\n')] : nextOps,
    changed: changed,
  );
}
