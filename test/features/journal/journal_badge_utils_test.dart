import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
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

  test('event badge token preserves partial completion status', () {
    final token = EventBadgeToken.buildToken(
      id: 'badge-partial',
      title: 'Partial badge',
      color: Colors.amber,
      completionStatus: CompletionStatus.partial,
    );

    final parsed = EventBadgeToken.parse(token.replaceAll('⟦EVENT_BADGE', ''));

    expect(parsed, isNotNull);
    expect(parsed!.completionStatus, CompletionStatus.partial);
  });

  test('mergeBadges replaces existing badge with latest token for same id', () {
    final observed = EventBadgeToken.buildToken(
      id: 'stable-badge',
      title: 'Practice',
      color: Colors.amber,
      completionStatus: CompletionStatus.observed,
    );
    final partial = EventBadgeToken.buildToken(
      id: 'stable-badge',
      title: 'Practice',
      color: Colors.orange,
      completionStatus: CompletionStatus.partial,
    );
    final doc = JournalDocument(
      version: kJournalDocVersion,
      blocks: const [
        ParagraphBlock(
          id: 'p1',
          ops: [TextOp(insert: 'Body')],
        ),
      ],
      meta: {'badges': observed},
    );

    final merged = JournalBadgeUtils.mergeBadges(doc, [partial]);
    final tokens = JournalBadgeUtils.tokensFromDocument(merged);

    expect(tokens, hasLength(1));
    expect(tokens.single.id, 'stable-badge');
    expect(tokens.single.completionStatus, CompletionStatus.partial);
  });

  testWidgets('partial event badge renders a partial signifier', (
    tester,
  ) async {
    const token = EventBadgeToken(
      id: 'partial-widget',
      title: 'Partial practice',
      color: Colors.orange,
      completionStatus: CompletionStatus.partial,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EventBadgeWidget(token: token, expandable: false)),
      ),
    );

    expect(find.byIcon(Icons.adjust_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });
}
