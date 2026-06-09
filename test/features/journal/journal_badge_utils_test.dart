import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_badge_style.dart';
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

  test('removeBadgesById removes only the matching completion badge', () {
    final completion = EventBadgeToken.buildToken(
      id: 'calendar:user_flow:cid:event-1',
      eventId: 'event-1',
      title: 'Practice',
      color: Colors.amber,
      description: 'Completion: observed.',
      completionStatus: CompletionStatus.observed,
      sourceType: CompletionSourceType.userFlow,
    );
    final ordinary = EventBadgeToken.buildToken(
      id: 'badge-note',
      title: 'Ordinary badge',
      color: Colors.blue,
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
        'badges': [ordinary, completion],
      },
    );

    final updated = JournalBadgeUtils.removeBadgesById(doc, {
      'calendar:user_flow:cid:event-1',
    });
    final tokens = JournalBadgeUtils.tokensFromDocument(updated);

    expect(tokens.map((token) => token.id), <String>['badge-note']);
  });

  test('completion badge identity falls back for legacy event tokens', () {
    final legacy = EventBadgeToken.buildToken(
      id: 'legacy-completion',
      eventId: 'legacy-client-event',
      title: 'Legacy completion',
      color: Colors.amber,
      description: 'Completion: skipped.',
      completionStatus: CompletionStatus.skipped,
    );

    final token = JournalBadgeUtils.parseRawToken(legacy)!;

    expect(token.isCompletionBadge, isTrue);
    expect(token.completionSourceIdentity, 'cid:legacy-client-event');
    expect(token.completionClientEventId, 'legacy-client-event');
  });

  testWidgets(
    'partial event badge renders source color with partial signifier',
    (tester) async {
      const sourceColor = Color(0xFF1AA7E8);
      const token = EventBadgeToken(
        id: 'partial-widget',
        title: 'Partial practice',
        color: sourceColor,
        completionStatus: CompletionStatus.partial,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EventBadgeWidget(token: token, expandable: false),
          ),
        ),
      );

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.incomplete_circle_rounded),
      );
      expect(icon.color, sourceColor.withValues(alpha: 0.95));
      expect(icon.color, isNot(const Color(0xFFFFC145)));
      expect(find.byIcon(Icons.task_alt_rounded), findsNothing);
    },
  );

  testWidgets('observed event badge renders source color with full signifier', (
    tester,
  ) async {
    const sourceColor = Color(0xFF1AA7E8);
    const token = EventBadgeToken(
      id: 'observed-widget',
      title: 'Observed practice',
      color: sourceColor,
      completionStatus: CompletionStatus.observed,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EventBadgeWidget(token: token, expandable: false)),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.task_alt_rounded));
    expect(icon.color, sourceColor.withValues(alpha: 0.95));
    expect(icon.color, isNot(const Color(0xFF4CAF50)));
    expect(find.byIcon(Icons.incomplete_circle_rounded), findsNothing);
  });

  testWidgets('skipped event badge renders muted status semantics', (
    tester,
  ) async {
    const token = EventBadgeToken(
      id: 'skipped-widget',
      title: 'Skipped practice',
      color: Color(0xFFFFC145),
      completionStatus: CompletionStatus.skipped,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EventBadgeWidget(token: token, expandable: false)),
      ),
    );

    final icon = tester.widget<Icon>(
      find.byIcon(Icons.remove_circle_outline_rounded),
    );
    expect(icon.color, kCompletionSkippedBadgeColor.withValues(alpha: 0.95));
    expect(icon.color, isNot(const Color(0xFFFFC145).withValues(alpha: 0.95)));
  });

  testWidgets('reflection event badge renders a journal signifier', (
    tester,
  ) async {
    const token = EventBadgeToken(
      id: 'reflection-widget',
      title: 'Reflection practice',
      color: Color(0xFF8FD7E8),
      completionStatus: CompletionStatus.none,
      reflectionStatus: ReflectionStatus.userWritten,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EventBadgeWidget(token: token, expandable: false)),
      ),
    );

    expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
    expect(find.byIcon(Icons.task_alt_rounded), findsNothing);
  });

  test(
    'reflection badge token preserves reflection status without observed status',
    () {
      final token = EventBadgeToken.buildToken(
        id: 'reflection-token',
        title: 'Reflection',
        color: const Color(0xFF8FD7E8),
        completionStatus: CompletionStatus.none,
        reflectionStatus: ReflectionStatus.userWritten,
      );

      final parsed = EventBadgeToken.parse(
        token.replaceAll('⟦EVENT_BADGE', ''),
      );

      expect(parsed, isNotNull);
      expect(parsed!.completionStatus, CompletionStatus.none);
      expect(parsed.reflectionStatus, ReflectionStatus.userWritten);
    },
  );
}
