import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/maat_flow_response_journal_blocks.dart';
import 'package:mobile/features/calendar/maat_flow_response_models.dart';
import 'package:mobile/features/calendar/maat_flow_response_resolver.dart';
import 'package:mobile/features/journal/journal_badge_utils.dart';
import 'package:mobile/features/journal/journal_event_badge.dart';
import 'package:mobile/features/journal/journal_v2_document_model.dart';

void main() {
  test('mirror policy writes a journal response block', () {
    const spec = MaatFlowResponseSpec(
      id: 'mirror-note',
      flowKey: 'policy-fixture',
      surface: MaatFlowResponseSurface.calendarSheet,
      kind: MaatFlowResponseKind.text,
      label: 'Mirror Note',
      journalPolicy: MaatFlowJournalPolicy.mirror,
    );
    final preview = buildMaatFlowResponseJournalPreview(
      spec: spec,
      value: MaatFlowResponseValue.text(
        specId: spec.id,
        text: 'safe public text',
      ),
      clientEventId: 'event-1',
    )!;

    final blocks = buildMaatJournalResponseBlocksForPolicy(
      sourceIds: <String>[preview.sourceId],
      previews: <MaatFlowResponseJournalPreview>[preview],
      localDate: _date,
    );

    expect(preview.writesByDefault, isTrue);
    expect(preview.requiresUserChoice, isFalse);
    expect(blocks.single.text, 'Mirror Note: safe public text');
  });

  test('offer policy requires choice and can suppress journal body text', () {
    const spec = MaatFlowResponseSpec(
      id: 'offer-note',
      flowKey: 'policy-fixture',
      surface: MaatFlowResponseSurface.calendarSheet,
      kind: MaatFlowResponseKind.multiline,
      label: 'Offer Note',
      journalPolicy: MaatFlowJournalPolicy.offer,
    );
    final preview = buildMaatFlowResponseJournalPreview(
      spec: spec,
      value: MaatFlowResponseValue.text(
        specId: spec.id,
        text: 'specific private recipient detail',
        multiline: true,
      ),
      clientEventId: 'event-1',
    )!;

    final suppressedBlocks = buildMaatJournalResponseBlocksForPolicy(
      sourceIds: <String>[preview.sourceId],
      previews: <MaatFlowResponseJournalPreview>[preview],
      localDate: _date,
    );
    final includedBlocks = buildMaatJournalResponseBlocksForPolicy(
      sourceIds: <String>[preview.sourceId],
      previews: <MaatFlowResponseJournalPreview>[preview],
      localDate: _date,
      includedOfferSourceIds: <String>{preview.sourceId},
    );

    expect(preview.writesByDefault, isFalse);
    expect(preview.requiresUserChoice, isTrue);
    expect(suppressedBlocks.single.text, isEmpty);
    expect(
      includedBlocks.single.text,
      'Offer Note: specific private recipient detail',
    );
  });

  test('redacted summary never writes raw sensitive text', () {
    const spec = MaatFlowResponseSpec(
      id: 'private-note',
      flowKey: 'policy-fixture',
      surface: MaatFlowResponseSurface.calendarSheet,
      kind: MaatFlowResponseKind.multiline,
      label: 'Private Note',
      journalPolicy: MaatFlowJournalPolicy.redactedSummary,
      redactedSummary: 'Private response recorded.',
    );
    final preview = buildMaatFlowResponseJournalPreview(
      spec: spec,
      value: MaatFlowResponseValue.text(
        specId: spec.id,
        text: 'Raw name, conflict, health detail.',
        multiline: true,
      ),
      clientEventId: 'event-1',
    )!;
    final blocks = buildMaatJournalResponseBlocksForPolicy(
      sourceIds: <String>[preview.sourceId],
      previews: <MaatFlowResponseJournalPreview>[preview],
      localDate: _date,
    );

    expect(preview.writesByDefault, isTrue);
    expect(blocks.single.text, 'Private Note: Private response recorded.');
    expect(blocks.single.text, isNot(contains('Raw name')));
    expect(blocks.single.text, isNot(contains('conflict')));
    expect(blocks.single.text, isNot(contains('health')));
  });

  test('grouped redacted summary never falls through to raw field text', () {
    const specs = <MaatFlowResponseSpec>[
      MaatFlowResponseSpec(
        id: 'private-topic',
        flowKey: 'policy-fixture',
        surface: MaatFlowResponseSurface.calendarSheet,
        kind: MaatFlowResponseKind.text,
        label: 'Private Topic',
        journalGroupId: 'private-group',
        journalGroupLabel: 'Private Group',
        journalPolicy: MaatFlowJournalPolicy.redactedSummary,
        redactedSummary: 'Grouped private response recorded.',
      ),
      MaatFlowResponseSpec(
        id: 'private-detail',
        flowKey: 'policy-fixture',
        surface: MaatFlowResponseSurface.calendarSheet,
        kind: MaatFlowResponseKind.multiline,
        label: 'Private Detail',
        journalGroupId: 'private-group',
        journalGroupLabel: 'Private Group',
        journalPolicy: MaatFlowJournalPolicy.redactedSummary,
      ),
    ];
    final previews = buildMaatFlowResponseJournalPreviews(
      specs: specs,
      values: <String, MaatFlowResponseValue>{
        'private-topic': MaatFlowResponseValue.text(
          specId: 'private-topic',
          text: 'recipient name',
        ),
        'private-detail': MaatFlowResponseValue.text(
          specId: 'private-detail',
          text: 'raw conflict detail',
          multiline: true,
        ),
      },
      clientEventId: 'event-1',
    );

    expect(previews, hasLength(1));
    expect(
      previews.single.text,
      'Private Group: Grouped private response recorded.',
    );
    expect(previews.single.text, isNot(contains('recipient')));
    expect(previews.single.text, isNot(contains('conflict')));
  });

  test('local-only policy never writes a journal response block', () {
    const spec = MaatFlowResponseSpec(
      id: 'local-note',
      flowKey: 'policy-fixture',
      surface: MaatFlowResponseSurface.calendarSheet,
      kind: MaatFlowResponseKind.text,
      label: 'Local Note',
      journalPolicy: MaatFlowJournalPolicy.localOnly,
    );
    final sourceId = spec.sourceId(clientEventId: 'event-1');
    final preview = buildMaatFlowResponseJournalPreview(
      spec: spec,
      value: MaatFlowResponseValue.text(
        specId: spec.id,
        text: 'keep this local',
      ),
      clientEventId: 'event-1',
    );
    final blocks = buildMaatJournalResponseBlocksForPolicy(
      sourceIds: <String>[sourceId],
      previews: const <MaatFlowResponseJournalPreview>[],
      localDate: _date,
    );
    final document = MaatJournalResponseBlockUtils.upsert(
      _document('Manual body.'),
      blocks.single,
    );

    expect(preview, isNull);
    expect(blocks.single.text, isEmpty);
    expect(MaatJournalResponseBlockUtils.extract(document), isEmpty);
    expect(document.toPlainText(), 'Manual body.');
  });

  test(
    'same-status edits update existing response block instead of duplicate',
    () {
      final sourceId = buildMaatFlowResponseSourceId(
        flowKey: 'policy-fixture',
        responseSpecId: 'same-status',
        clientEventId: 'event-1',
      );
      final first = MaatJournalResponseBlockUtils.upsert(
        _document('Manual body.'),
        MaatJournalResponseBlock(
          sourceId: sourceId,
          text: 'Policy: first response.',
          localDate: _date,
        ),
      );
      final second = MaatJournalResponseBlockUtils.upsert(
        first,
        MaatJournalResponseBlock(
          sourceId: sourceId,
          text: 'Policy: updated response.',
          localDate: _date,
        ),
      );

      final blocks = MaatJournalResponseBlockUtils.extract(second);
      expect(blocks, hasLength(1));
      expect(blocks.single.text, 'Policy: updated response.');
      expect(second.toPlainText(), contains('Manual body.'));
      expect(second.toPlainText(), isNot(contains('first response')));
    },
  );

  test('empty response removes or avoids empty journal body blocks', () {
    const spec = MaatFlowResponseSpec(
      id: 'empty-note',
      flowKey: 'policy-fixture',
      surface: MaatFlowResponseSurface.calendarSheet,
      kind: MaatFlowResponseKind.text,
      label: 'Empty Note',
      journalPolicy: MaatFlowJournalPolicy.mirror,
    );
    final sourceId = spec.sourceId(clientEventId: 'event-1');
    final preview = buildMaatFlowResponseJournalPreview(
      spec: spec,
      value: MaatFlowResponseValue.text(specId: spec.id, text: '  '),
      clientEventId: 'event-1',
    );
    final blocks = buildMaatJournalResponseBlocksForPolicy(
      sourceIds: <String>[sourceId],
      previews: const <MaatFlowResponseJournalPreview>[],
      localDate: _date,
    );
    final document = MaatJournalResponseBlockUtils.upsert(
      _document('Manual body.'),
      blocks.single,
    );

    expect(preview, isNull);
    expect(blocks.single.text, isEmpty);
    expect(MaatJournalResponseBlockUtils.extract(document), isEmpty);
    expect(document.toPlainText(), 'Manual body.');
  });

  test('response blocks preserve manual body text and badge metadata', () {
    final badge = EventBadgeToken.buildToken(
      id: 'calendar:maat_flow:cid:event-1',
      eventId: 'event-1',
      title: 'Completion',
      color: Colors.amber,
      completionStatus: CompletionStatus.observed,
      sourceType: CompletionSourceType.maatFlow,
    );
    final document = JournalDocument(
      version: kJournalDocVersion,
      blocks: const <JournalBlock>[
        ParagraphBlock(
          id: 'manual-before',
          ops: <TextOp>[TextOp(insert: 'Manual before.')],
        ),
        ParagraphBlock(
          id: 'manual-after',
          ops: <TextOp>[TextOp(insert: 'Manual after.')],
        ),
      ],
      meta: <String, dynamic>{
        'badges': <String>[badge],
      },
    );
    final withResponse = MaatJournalResponseBlockUtils.upsert(
      document,
      const MaatJournalResponseBlock(
        sourceId: 'maat_response:policy-fixture:cid:event-1:response',
        text: 'Policy: response body.',
      ),
    );

    expect(withResponse.toPlainText(), contains('Manual before.'));
    expect(withResponse.toPlainText(), contains('Manual after.'));
    expect(withResponse.toPlainText(), contains('Policy: response body.'));
    expect(JournalBadgeUtils.hasBadges(withResponse.toPlainText()), isFalse);
    expect(JournalBadgeUtils.tokensFromDocument(withResponse), hasLength(1));
    expect(
      JournalBadgeUtils.tokensFromDocument(withResponse).single.id,
      'calendar:maat_flow:cid:event-1',
    );
  });

  test('unsupported flows remain no-op for response previews', () {
    final specs = resolveMaatFlowResponseSpecs(
      flowKey: 'unsupported-sensitive-flow',
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final previews = buildMaatFlowResponseJournalPreviews(
      specs: specs,
      values: const <String, MaatFlowResponseValue>{},
      completionStatus: CompletionStatus.observed,
    );

    expect(specs, isEmpty);
    expect(previews, isEmpty);
  });
}

final DateTime _date = DateTime(2026, 6, 23);

JournalDocument _document(String text) {
  return JournalDocument(
    version: kJournalDocVersion,
    blocks: <JournalBlock>[
      ParagraphBlock(
        id: 'manual-body',
        ops: <TextOp>[TextOp(insert: text)],
      ),
    ],
  );
}
