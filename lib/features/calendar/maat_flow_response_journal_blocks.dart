import 'package:mobile/features/journal/journal_v2_document_model.dart';

const String kMaatJournalResponseBlockIdPrefix = 'maat_response:';

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
}
