import 'journal_event_badge.dart';
import 'journal_v2_document_model.dart';

/// Helpers for extracting, deduping, and storing journal badges outside
/// of the main text stream.
class JournalBadgeUtils {
  static final RegExp badgeRegex = RegExp(r'⟦EVENT_BADGE[\s\S]*?⟧');

  static bool hasBadges(String text) => badgeRegex.hasMatch(text);

  static List<String> extractRawTokens(String text) {
    return badgeRegex
        .allMatches(text)
        .map((m) => text.substring(m.start, m.end))
        .toList();
  }

  static String stripBadges(String text) => text.replaceAll(badgeRegex, '');

  static EventBadgeToken? parseRawToken(String raw) {
    final trimmed = raw.trim();
    final content = trimmed.startsWith('⟦EVENT_BADGE')
        ? trimmed
              .replaceFirst('⟦EVENT_BADGE', '')
              .replaceFirst(RegExp(r'⟧$'), '')
              .trim()
        : trimmed;
    if (content.isEmpty) return null;
    return EventBadgeToken.parse(content);
  }

  static List<String> _coerceStringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e == null ? '' : e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? [] : [trimmed];
    }
    if (value is Map) {
      return value.values
          .map((e) => e == null ? '' : e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static List<String> dedupeRawTokens(Iterable<String> tokens) {
    final latestByKey = <String, String>{};

    for (final raw in tokens) {
      final token = parseRawToken(raw);
      final key = token?.id ?? raw.trim();
      if (key.isEmpty) continue;
      latestByKey.remove(key);
      latestByKey[key] = raw.trim();
    }

    return latestByKey.values.toList();
  }

  static JournalDocument mergeBadges(
    JournalDocument doc,
    Iterable<String> rawTokens,
  ) {
    final incoming = rawTokens.where((t) => t.trim().isNotEmpty).toList();
    if (incoming.isEmpty) return doc;

    final meta = Map<String, dynamic>.from(doc.meta);
    final existing = _coerceStringList(meta['badges']);
    final combined = [...existing, ...incoming];
    final deduped = dedupeRawTokens(combined);

    if (_listEquals(existing, deduped)) {
      return doc;
    }

    meta['badges'] = deduped;

    return JournalDocument(
      version: doc.version,
      blocks: List<JournalBlock>.from(doc.blocks),
      meta: meta,
    );
  }

  /// Move any inline badge tokens into document meta and strip them from text.
  static JournalDocument normalizeDocument(JournalDocument doc) {
    bool changed = false;
    final meta = Map<String, dynamic>.from(doc.meta);
    final existingRaw = _coerceStringList(meta['badges']);
    final collectedTokens = <String>[...existingRaw];
    final newBlocks = <JournalBlock>[];

    for (final block in doc.blocks) {
      if (block is ParagraphBlock) {
        final newOps = <TextOp>[];
        for (final op in block.ops) {
          final opTokens = extractRawTokens(op.insert);
          if (opTokens.isNotEmpty) {
            collectedTokens.addAll(opTokens);
            changed = true;
          }

          final cleaned = stripBadges(op.insert);
          if (cleaned != op.insert) {
            changed = true;
          }

          if (cleaned.isNotEmpty) {
            newOps.add(op.copyWith(insert: cleaned));
          }
        }

        newBlocks.add(
          ParagraphBlock(
            id: block.id,
            ops: newOps.isEmpty ? [TextOp(insert: '\n')] : newOps,
          ),
        );
      } else {
        newBlocks.add(block);
      }
    }

    final deduped = dedupeRawTokens(collectedTokens);
    if (deduped.isNotEmpty) {
      if (!_listEquals(existingRaw, deduped)) {
        changed = true;
      }
      meta['badges'] = deduped;
    } else if (meta.containsKey('badges')) {
      meta.remove('badges');
      changed = true;
    }

    if (!changed) {
      return doc;
    }

    return JournalDocument(version: doc.version, blocks: newBlocks, meta: meta);
  }

  /// Parse badge tokens from meta (preferred) or legacy inline text.
  static List<EventBadgeToken> tokensFromDocument(JournalDocument doc) {
    final tokens = <EventBadgeToken>[];
    final seen = <String>{};

    void addIfValid(String raw) {
      final parsed = parseRawToken(raw);
      if (parsed != null && seen.add(parsed.id)) {
        tokens.add(parsed);
      }
    }

    final metaBadges = _coerceStringList(doc.meta['badges']);
    for (final raw in metaBadges) {
      addIfValid(raw);
    }

    if (tokens.isEmpty) {
      for (final block in doc.blocks.whereType<ParagraphBlock>()) {
        for (final op in block.ops) {
          for (final raw in extractRawTokens(op.insert)) {
            addIfValid(raw);
          }
        }
      }
    }

    return tokens;
  }

  static List<EventBadgeToken> tokensFromPlainText(String text) {
    final tokens = <EventBadgeToken>[];
    final seen = <String>{};
    for (final raw in extractRawTokens(text)) {
      final parsed = parseRawToken(raw);
      if (parsed != null && seen.add(parsed.id)) {
        tokens.add(parsed);
      }
    }
    return tokens;
  }

  static List<EventBadgeToken> completionTokensFromDocument(
    JournalDocument doc,
  ) {
    return tokensFromDocument(
      doc,
    ).where((token) => token.isCompletionBadge).toList(growable: false);
  }

  static List<EventBadgeToken> completionTokensFromPlainText(String text) {
    return tokensFromPlainText(
      text,
    ).where((token) => token.isCompletionBadge).toList(growable: false);
  }

  static JournalDocument removeBadgesById(
    JournalDocument doc,
    Iterable<String> badgeIds,
  ) {
    final ids = badgeIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return doc;

    var changed = false;
    final normalized = normalizeDocument(doc);
    final meta = Map<String, dynamic>.from(normalized.meta);
    final existingRaw = _coerceStringList(meta['badges']);
    final keptRaw = <String>[];
    for (final raw in existingRaw) {
      final token = parseRawToken(raw);
      if (token != null && ids.contains(token.id)) {
        changed = true;
        continue;
      }
      keptRaw.add(raw);
    }

    if (keptRaw.isEmpty) {
      if (meta.containsKey('badges')) {
        meta.remove('badges');
        changed = true;
      }
    } else if (!_listEquals(existingRaw, keptRaw)) {
      meta['badges'] = keptRaw;
      changed = true;
    }

    final blocks = <JournalBlock>[];
    for (final block in normalized.blocks) {
      if (block is! ParagraphBlock) {
        blocks.add(block);
        continue;
      }

      final ops = <TextOp>[];
      for (final op in block.ops) {
        var insert = op.insert;
        for (final raw in extractRawTokens(op.insert)) {
          final token = parseRawToken(raw);
          if (token != null && ids.contains(token.id)) {
            insert = insert.replaceAll(raw, '');
            changed = true;
          }
        }
        ops.add(op.copyWith(insert: insert.isEmpty ? '\n' : insert));
      }
      blocks.add(block.copyWith(ops: ops));
    }

    if (!changed) return doc;
    return JournalDocument(
      version: normalized.version,
      blocks: blocks,
      meta: meta,
    );
  }

  static String stripBadgesFromPlainText(String text) => stripBadges(text);
}
