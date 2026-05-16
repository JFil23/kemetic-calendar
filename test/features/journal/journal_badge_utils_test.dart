import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/journal/journal_badge_utils.dart';
import 'package:mobile/features/journal/journal_event_badge.dart';
import 'package:mobile/features/journal/journal_v2_document_model.dart';

void main() {
  test('tokensFromDocument reads badge meta stored as a single string', () {
    final token = EventBadgeToken.buildToken(
      id: 'badge-1',
      title: 'Single badge',
      color: Colors.amber,
    );
    final doc = JournalDocument(
      version: kJournalDocVersion,
      blocks: const [
        ParagraphBlock(
          id: 'p1',
          ops: [TextOp(insert: 'Body')],
        ),
      ],
      meta: {'badges': token},
    );

    final tokens = JournalBadgeUtils.tokensFromDocument(doc);

    expect(tokens, hasLength(1));
    expect(tokens.single.id, 'badge-1');
    expect(tokens.single.title, 'Single badge');
  });

  test('tokensFromDocument reads badge meta stored as a simple map', () {
    final token = EventBadgeToken.buildToken(
      id: 'badge-2',
      title: 'Mapped badge',
      color: Colors.amber,
    );
    final doc = JournalDocument(
      version: kJournalDocVersion,
      blocks: const [
        ParagraphBlock(
          id: 'p1',
          ops: [TextOp(insert: 'Body')],
        ),
      ],
      meta: {
        'badges': {'badge-2': token},
      },
    );

    final tokens = JournalBadgeUtils.tokensFromDocument(doc);

    expect(tokens, hasLength(1));
    expect(tokens.single.id, 'badge-2');
    expect(tokens.single.title, 'Mapped badge');
  });
}
