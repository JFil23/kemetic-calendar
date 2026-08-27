import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/calendar_completion.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:mobile/features/calendar/maat_flow_response_journal_blocks.dart';
import 'package:mobile/features/journal/journal_badge_utils.dart';
import 'package:mobile/features/journal/journal_v2_document_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'reflection is ordinary Journal prose and manual Journal edits win',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final client = SupabaseClient('http://localhost', 'anon-key');
      var journal = JournalDocument.fromPlainText('Before the observation.');
      final projectedDates = <DateTime>[];
      const completionIdentity = 'cid:full-moon-occurrence';

      Future<void> writeReflection(MaatJournalResponseBlock block) async {
        projectedDates.add(block.localDate!);
        journal = MaatJournalResponseBlockUtils.upsertPlainUserText(
          journal,
          block,
        );
      }

      Future<void> writeCompletion(CompletionStatus status) async {
        final badgeId = calendarCompletionBadgeId(
          identity: completionIdentity,
          sourceType: CompletionSourceType.maatFlow,
        );
        if (status == CompletionStatus.none) {
          journal = JournalBadgeUtils.removeBadgesById(journal, <String>{
            badgeId,
          });
          return;
        }
        final token = buildCalendarCompletionBadgeToken(
          identity: completionIdentity,
          sourceType: CompletionSourceType.maatFlow,
          completionStatus: status,
          eventId: 'full-moon-occurrence',
          title: 'Full Moon + Partial Lunar Eclipse',
          start: DateTime(2026, 8, 27, 21, 12),
          end: DateTime(2026, 8, 28, 6, 51),
          color: const Color(0xFFD4AE43),
        );
        journal = JournalBadgeUtils.mergeBadges(journal, <String>[token]);
      }

      FollowSkyTurningController createController() {
        return FollowSkyTurningController(
          records: TurningRecordRepository(client, preferences: preferences),
          clientEventId: 'full-moon-occurrence',
          completionIdentity: completionIdentity,
          skyEventId: 'full-moon-2026-08-28',
          localDate: DateTime(2026, 8, 27),
          scheduledTimeSnapshot: DateTime(2026, 8, 27, 21, 12),
          intentionSnapshot: 'self confidence',
          onCommitCompletion: writeCompletion,
          onWriteJournalResponse: writeReflection,
        );
      }

      final firstSession = createController();
      await firstSession.initialize();
      firstSession.scheduleReflection('I stayed outside when clouds moved in.');
      await firstSession.flushReflection();

      expect(projectedDates, isNotEmpty);
      expect(projectedDates.last, DateTime(2026, 8, 27));
      expect(
        journal.toPlainText(),
        'Before the observation.\n\n'
        'I stayed outside when clouds moved in.',
      );
      expect(MaatJournalResponseBlockUtils.extract(journal), isEmpty);
      expect(
        MaatJournalResponseBlockUtils.extractPlainUserTextSources(journal),
        <String, String>{
          'follow-sky-turning:full-moon-occurrence':
              'I stayed outside when clouds moved in.',
        },
      );
      final paragraph = journal.blocks.whereType<ParagraphBlock>().single;
      expect(
        paragraph.id,
        isNot(startsWith(kMaatJournalResponseBlockIdPrefix)),
      );
      expect(paragraph.ops.every((op) => op.attrs == null), isTrue);

      await firstSession.toggleCompletion(CompletionStatus.observed);
      expect(
        JournalBadgeUtils.completionTokensFromDocument(journal),
        hasLength(1),
      );
      expect(
        JournalBadgeUtils.completionTokensFromDocument(
          journal,
        ).single.sourceType,
        CompletionSourceType.maatFlow,
      );
      expect(
        journal.toPlainText(),
        contains('I stayed outside when clouds moved in.'),
      );

      final editedParagraph = journal.blocks.whereType<ParagraphBlock>().single;
      journal = journal.copyWith(
        blocks: <JournalBlock>[
          ParagraphBlock(
            id: editedParagraph.id,
            ops: const <TextOp>[
              TextOp(
                insert:
                    'Words before. I stayed outside when clouds moved in, '
                    'and I felt steady. Words after.',
              ),
            ],
          ),
        ],
      );
      firstSession.scheduleReflection('A later event-side replacement.');
      await firstSession.flushReflection();
      firstSession.scheduleReflection('');
      await firstSession.flushReflection();

      expect(
        journal.toPlainText(),
        'Words before. I stayed outside when clouds moved in, '
        'and I felt steady. Words after.',
      );
      expect(journal.toPlainText(), isNot(contains('event-side replacement')));
      expect(
        JournalBadgeUtils.completionTokensFromDocument(journal),
        hasLength(1),
      );

      await firstSession.close();
      final reopened = createController();
      final restored = await reopened.initialize();
      expect(restored.reflectionText, isEmpty);
      expect(reopened.completion, CompletionStatus.observed);
      expect(
        journal.toPlainText(),
        'Words before. I stayed outside when clouds moved in, '
        'and I felt steady. Words after.',
      );
      expect(
        JournalBadgeUtils.completionTokensFromDocument(journal),
        hasLength(1),
      );

      final updated = await reopened.toggleCompletion(CompletionStatus.partial);
      expect(updated.status, CompletionStatus.partial);
      final badges = JournalBadgeUtils.completionTokensFromDocument(journal);
      expect(badges, hasLength(1));
      expect(badges.single.completionStatus, CompletionStatus.partial);
      expect(
        journal.toPlainText(),
        'Words before. I stayed outside when clouds moved in, '
        'and I felt steady. Words after.',
      );

      await reopened.close();
      client.dispose();
    },
  );

  test(
    'clearing untouched carried reflection removes only that prose',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final client = SupabaseClient('http://localhost', 'anon-key');
      var journal = JournalDocument.fromPlainText('Existing Journal text.');
      final controller = FollowSkyTurningController(
        records: TurningRecordRepository(client, preferences: preferences),
        clientEventId: 'untouched-occurrence',
        completionIdentity: 'cid:untouched-occurrence',
        skyEventId: 'full-moon-2026-08-28',
        localDate: DateTime(2026, 8, 27),
        scheduledTimeSnapshot: DateTime(2026, 8, 27, 21, 12),
        intentionSnapshot: null,
        onCommitCompletion: (_) async {},
        onWriteJournalResponse: (block) async {
          journal = MaatJournalResponseBlockUtils.upsertPlainUserText(
            journal,
            block,
          );
        },
      );

      controller.scheduleReflection('Temporary observation.');
      await controller.flushReflection();
      expect(
        journal.toPlainText(),
        'Existing Journal text.\n\nTemporary observation.',
      );

      controller.scheduleReflection('');
      await controller.flushReflection();
      expect(journal.toPlainText(), 'Existing Journal text.');
      expect(
        MaatJournalResponseBlockUtils.extractPlainUserTextSources(journal),
        isEmpty,
      );

      await controller.close();
      client.dispose();
    },
  );

  test(
    'isolated wiring accepts arbitrary prose and clears its test state',
    () async {
      const clientEventId = 'full-moon-rc-smoke';
      const arbitraryUserProse =
          'RC wiring check: '
          'the approved sky view held.';
      final preferences = await SharedPreferences.getInstance();
      final client = SupabaseClient('http://localhost', 'anon-key');
      expect(client.auth.currentUser, isNull);
      var journal = JournalDocument.fromPlainText(
        'What have I called done that is only begun?',
      );
      final controller = FollowSkyTurningController(
        records: TurningRecordRepository(client, preferences: preferences),
        clientEventId: clientEventId,
        completionIdentity: 'cid:$clientEventId',
        skyEventId: 'full-moon-2026-08-28',
        localDate: DateTime(2026, 8, 27),
        scheduledTimeSnapshot: DateTime(2026, 8, 27, 21, 12),
        intentionSnapshot: 'self confidence',
        onCommitCompletion: (_) async {},
        onWriteJournalResponse: (block) async {
          journal = MaatJournalResponseBlockUtils.upsertPlainUserText(
            journal,
            block,
          );
        },
      );

      await controller.initialize();
      controller.scheduleReflection(arbitraryUserProse);
      await controller.flushReflection();

      expect(controller.record?.reflectionText, arbitraryUserProse);
      expect(
        journal.toPlainText(),
        'What have I called done that is only begun?\n\n$arbitraryUserProse',
      );
      expect(
        MaatJournalResponseBlockUtils.extractPlainUserTextSources(journal),
        <String, String>{
          'follow-sky-turning:$clientEventId': arbitraryUserProse,
        },
      );

      await controller.close();
      await preferences.clear();
      expect(preferences.getKeys(), isEmpty);
      client.dispose();
    },
  );
}
