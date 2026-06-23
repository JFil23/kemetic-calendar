import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/maat_flow_response_journal_blocks.dart';
import 'package:mobile/features/calendar/maat_flow_response_models.dart';
import 'package:mobile/features/calendar/maat_flow_response_resolver.dart';
import 'package:mobile/features/calendar/the_decan_watch_flow.dart';
import 'package:mobile/features/journal/journal_badge_utils.dart';
import 'package:mobile/features/journal/journal_event_badge.dart';
import 'package:mobile/features/journal/journal_v2_document_model.dart';

void main() {
  test('response enum wire names are stable', () {
    expect(MaatFlowResponseSurface.initialDetail.wireName, 'initial_detail');
    expect(MaatFlowResponseSurface.calendarSheet.wireName, 'calendar_sheet');
    expect(MaatFlowResponseSurface.both.wireName, 'both');
    expect(
      MaatFlowResponseSurface.both.includes(
        MaatFlowResponseSurface.calendarSheet,
      ),
      isTrue,
    );
    expect(
      MaatFlowResponseSurfaceX.fromWireName('initial'),
      MaatFlowResponseSurface.initialDetail,
    );

    expect(MaatFlowResponseKind.text.wireName, 'text');
    expect(MaatFlowResponseKind.multiline.wireName, 'multiline');
    expect(MaatFlowResponseKind.choice.wireName, 'choice');
    expect(MaatFlowResponseKind.chips.wireName, 'chips');
    expect(MaatFlowResponseKind.checkbox.wireName, 'checkbox');
    expect(MaatFlowResponseKind.statusNote.wireName, 'status_note');
    expect(
      MaatFlowResponseKindX.fromWireName('status-note'),
      MaatFlowResponseKind.statusNote,
    );

    expect(MaatFlowJournalPolicy.mirror.wireName, 'mirror');
    expect(MaatFlowJournalPolicy.offer.wireName, 'offer');
    expect(MaatFlowJournalPolicy.redactedSummary.wireName, 'redacted_summary');
    expect(MaatFlowJournalPolicy.localOnly.wireName, 'local_only');
    expect(
      MaatFlowJournalPolicyX.fromWireName('local-only'),
      MaatFlowJournalPolicy.localOnly,
    );

    expect(MaatFlowResponseJournalFormatter.standard.wireName, 'standard');
    expect(MaatFlowResponseJournalFormatter.decanWatch.wireName, 'decan_watch');
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('decan-watch'),
      MaatFlowResponseJournalFormatter.decanWatch,
    );
  });

  test('default resolver exposes only Phase 2B and 2C pilot flow specs', () {
    expect(kDefaultMaatFlowResponseResolver.specs, hasLength(6));

    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: 'the-moon-return',
        surface: MaatFlowResponseSurface.calendarSheet,
        eventKey: 'new',
      ).map((spec) => spec.id),
      <String>['moon-return-set-down'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: 'the-moon-return',
        surface: MaatFlowResponseSurface.calendarSheet,
        eventKey: 'full',
      ).map((spec) => spec.id),
      <String>['moon-return-filled'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: 'the-course',
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['course-hour-action'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kDecanWatchFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>[
        kDecanWatchResponseVisibilitySpecId,
        kDecanWatchResponseSkyNoteSpecId,
        kDecanWatchResponseBearingSpecId,
      ],
    );

    for (final flowKey in const <String>[
      'unknown-flow',
      'dawn-house-rite',
      'evening-threshold-rite',
      'evening_threshold',
      'the-weighing',
    ]) {
      expect(
        resolveMaatFlowResponseSpecs(
          flowKey: flowKey,
          surface: MaatFlowResponseSurface.calendarSheet,
        ),
        isEmpty,
        reason: flowKey,
      );
    }
  });

  test(
    'fixture resolver filters by flow, surface, event, and sitting keys',
    () {
      const spec = MaatFlowResponseSpec(
        id: 'sky-note',
        flowKey: 'fixture-flow',
        eventKey: 'day-1',
        sittingKey: 'evening',
        surface: MaatFlowResponseSurface.calendarSheet,
        kind: MaatFlowResponseKind.multiline,
        label: 'Sky note',
        journalPolicy: MaatFlowJournalPolicy.offer,
      );
      const bothSpec = MaatFlowResponseSpec(
        id: 'intention',
        flowKey: 'fixture-flow',
        surface: MaatFlowResponseSurface.both,
        kind: MaatFlowResponseKind.text,
        label: 'Intention',
      );
      const resolver = MaatFlowResponseResolver(
        specs: <MaatFlowResponseSpec>[spec, bothSpec],
      );

      expect(
        resolver.resolve(
          flowKey: 'fixture-flow',
          surface: MaatFlowResponseSurface.calendarSheet,
          eventKey: 'day-1',
          sittingKey: 'evening',
        ),
        <MaatFlowResponseSpec>[spec, bothSpec],
      );
      expect(
        resolver.resolve(
          flowKey: 'fixture-flow',
          surface: MaatFlowResponseSurface.initialDetail,
          eventKey: 'day-1',
          sittingKey: 'evening',
        ),
        <MaatFlowResponseSpec>[bothSpec],
      );
      expect(
        resolver.resolve(
          flowKey: 'fixture-flow',
          surface: MaatFlowResponseSurface.calendarSheet,
          eventKey: 'day-2',
          sittingKey: 'evening',
        ),
        <MaatFlowResponseSpec>[bothSpec],
      );
    },
  );

  test('response values format mirror, offer, and redacted previews', () {
    const choiceSpec = MaatFlowResponseSpec(
      id: 'visibility',
      flowKey: 'fixture-flow',
      surface: MaatFlowResponseSurface.calendarSheet,
      kind: MaatFlowResponseKind.choice,
      label: 'Visibility',
      journalLabel: 'The Decan Watch',
      journalPolicy: MaatFlowJournalPolicy.mirror,
      options: <MaatFlowResponseOption>[
        MaatFlowResponseOption(id: 'outside', label: 'Outside'),
        MaatFlowResponseOption(id: 'inside', label: 'Inside'),
      ],
    );
    final mirror = buildMaatFlowResponseJournalPreview(
      spec: choiceSpec,
      value: MaatFlowResponseValue.choice(
        specId: 'visibility',
        optionId: 'inside',
      ),
      clientEventId: 'cid-1',
    );

    expect(mirror, isNotNull);
    expect(mirror!.text, 'The Decan Watch: Inside');
    expect(mirror.policy, MaatFlowJournalPolicy.mirror);
    expect(mirror.writesByDefault, isTrue);
    expect(mirror.sourceId, 'maat_response:fixture-flow:cid:cid-1:visibility');

    const offerSpec = MaatFlowResponseSpec(
      id: 'one-act',
      flowKey: 'fixture-flow',
      surface: MaatFlowResponseSurface.calendarSheet,
      kind: MaatFlowResponseKind.text,
      label: 'One act',
      journalPolicy: MaatFlowJournalPolicy.offer,
    );
    final offer = buildMaatFlowResponseJournalPreview(
      spec: offerSpec,
      value: MaatFlowResponseValue.text(
        specId: 'one-act',
        text: 'Restore the shared table.',
      ),
    );
    expect(offer!.text, 'One act: Restore the shared table.');
    expect(offer.writesByDefault, isFalse);
    expect(offer.requiresUserChoice, isTrue);

    const redactedSpec = MaatFlowResponseSpec(
      id: 'private',
      flowKey: 'fixture-flow',
      surface: MaatFlowResponseSurface.calendarSheet,
      kind: MaatFlowResponseKind.multiline,
      label: 'Private accounting',
      journalPolicy: MaatFlowJournalPolicy.redactedSummary,
      redactedSummary: 'Private response recorded.',
    );
    final redacted = buildMaatFlowResponseJournalPreview(
      spec: redactedSpec,
      value: MaatFlowResponseValue.text(
        specId: 'private',
        text: 'Raw sensitive text.',
        multiline: true,
      ),
    );
    expect(redacted!.text, 'Private accounting: Private response recorded.');
    expect(redacted.text, isNot(contains('Raw sensitive text')));
  });

  test('Decan Watch response group formats one natural journal block', () {
    final specs = resolveMaatFlowResponseSpecs(
      flowKey: kDecanWatchFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );

    final previews = buildMaatFlowResponseJournalPreviews(
      specs: specs,
      values: <String, MaatFlowResponseValue>{
        kDecanWatchResponseVisibilitySpecId: MaatFlowResponseValue.choice(
          specId: kDecanWatchResponseVisibilitySpecId,
          optionId: kDecanWatchVisibilityOutside,
        ),
        kDecanWatchResponseSkyNoteSpecId: MaatFlowResponseValue.text(
          specId: kDecanWatchResponseSkyNoteSpecId,
          text: 'a clear western glow.',
          multiline: true,
        ),
        kDecanWatchResponseBearingSpecId: MaatFlowResponseValue.text(
          specId: kDecanWatchResponseBearingSpecId,
          text: 'steadiness.',
          multiline: true,
        ),
      },
      clientEventId: 'cid-decan-watch',
    );

    expect(previews, hasLength(1));
    expect(
      previews.single.sourceId,
      'maat_response:the-decan-watch:cid:cid-decan-watch:decan-watch-observation',
    );
    expect(
      previews.single.text,
      'The Decan Watch: I watched from outside. The sky showed a clear western glow. I carry steadiness into the next ten days.',
    );

    final bearingOnly = buildMaatFlowResponseJournalPreviews(
      specs: specs,
      values: <String, MaatFlowResponseValue>{
        kDecanWatchResponseBearingSpecId: MaatFlowResponseValue.text(
          specId: kDecanWatchResponseBearingSpecId,
          text: 'patience',
          multiline: true,
        ),
      },
    );

    expect(bearingOnly, hasLength(1));
    expect(
      bearingOnly.single.text,
      'The Decan Watch: I carry patience into the next ten days.',
    );
  });

  test(
    'local-only, empty, and skipped responses do not produce journal body',
    () {
      const localOnlySpec = MaatFlowResponseSpec(
        id: 'local',
        flowKey: 'fixture-flow',
        surface: MaatFlowResponseSurface.calendarSheet,
        kind: MaatFlowResponseKind.text,
        label: 'Local only',
        journalPolicy: MaatFlowJournalPolicy.localOnly,
      );
      expect(
        buildMaatFlowResponseJournalPreview(
          spec: localOnlySpec,
          value: MaatFlowResponseValue.text(specId: 'local', text: 'kept here'),
        ),
        isNull,
      );

      const mirrorSpec = MaatFlowResponseSpec(
        id: 'mirror',
        flowKey: 'fixture-flow',
        surface: MaatFlowResponseSurface.calendarSheet,
        kind: MaatFlowResponseKind.text,
        label: 'Mirror',
        journalPolicy: MaatFlowJournalPolicy.mirror,
      );
      expect(
        buildMaatFlowResponseJournalPreview(
          spec: mirrorSpec,
          value: MaatFlowResponseValue.text(specId: 'mirror', text: '   '),
        ),
        isNull,
      );
      expect(
        buildMaatFlowResponseJournalPreview(
          spec: mirrorSpec,
          value: MaatFlowResponseValue.text(specId: 'mirror', text: 'kept'),
          completionStatus: CompletionStatus.skipped,
        ),
        isNull,
      );
    },
  );

  test('journal response blocks update body text without touching badges', () {
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
          id: 'user-body',
          ops: <TextOp>[TextOp(insert: 'User text stays here.')],
        ),
      ],
      meta: <String, dynamic>{
        'badges': <String>[badge],
      },
    );

    final withResponse = MaatJournalResponseBlockUtils.upsert(
      document,
      const MaatJournalResponseBlock(
        sourceId: 'maat_response:fixture-flow:cid:event-1:one-act',
        text: 'One act: Restore the shared table.',
      ),
    );
    final replaced = MaatJournalResponseBlockUtils.upsert(
      withResponse,
      const MaatJournalResponseBlock(
        sourceId: 'maat_response:fixture-flow:cid:event-1:one-act',
        text: 'One act: Sweep the entry.',
      ),
    );

    expect(replaced.blocks, hasLength(2));
    expect(replaced.toPlainText(), contains('User text stays here.'));
    expect(replaced.toPlainText(), contains('One act: Sweep the entry.'));
    expect(replaced.toPlainText(), isNot(contains('Restore the shared table')));
    expect(JournalBadgeUtils.hasBadges(replaced.toPlainText()), isFalse);
    expect(JournalBadgeUtils.tokensFromDocument(replaced), hasLength(1));
    expect(
      JournalBadgeUtils.tokensFromDocument(replaced).single.id,
      'calendar:maat_flow:cid:event-1',
    );

    final extracted = MaatJournalResponseBlockUtils.extract(replaced);
    expect(extracted, hasLength(1));
    expect(
      extracted.single.sourceId,
      'maat_response:fixture-flow:cid:event-1:one-act',
    );
    expect(extracted.single.text, 'One act: Sweep the entry.');

    final removed = MaatJournalResponseBlockUtils.remove(
      replaced,
      'maat_response:fixture-flow:cid:event-1:one-act',
    );
    expect(removed.blocks, hasLength(1));
    expect(removed.toPlainText(), 'User text stays here.');
    expect(JournalBadgeUtils.tokensFromDocument(removed), hasLength(1));
  });

  test('Phase 2C wiring stays isolated to shared sheet panels and pilots', () {
    expect(
      kDefaultMaatFlowResponseResolver.specs
          .map((spec) => spec.flowKey)
          .toSet(),
      <String>{'the-moon-return', 'the-course', 'the-decan-watch'},
    );

    final dayView = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();
    expect(dayView, contains('resolveMaatFlowResponseSpecs('));
    expect(dayView, contains('MaatFlowResponseSurface.calendarSheet'));
    expect(dayView, contains('MaatFlowResponseSection('));
    expect(dayView, contains('journalPreviews: _responseJournalPreviews('));
    expect(dayView, contains('responseSpecs: responseSpecs'));

    final completion = File(
      'lib/features/calendar/calendar_completion.dart',
    ).readAsStringSync();
    expect(completion, contains('final Widget? leadingContent;'));

    final portraitGrid = File(
      'lib/features/calendar/calendar_grid_widgets.dart',
    ).readAsStringSync();
    expect(portraitGrid, contains('buildDayViewMaatFlowCompletionPanel('));
    expect(portraitGrid, contains('onWriteJournalResponse'));
    expect(portraitGrid, isNot(contains('resolveMaatFlowResponseSpecs(')));

    final landscape = File(
      'lib/features/calendar/landscape_month_view.dart',
    ).readAsStringSync();
    expect(landscape, contains('buildDayViewMaatFlowCompletionPanel('));
    expect(landscape, contains('onWriteJournalResponse'));
    expect(landscape, isNot(contains('resolveMaatFlowResponseSpecs(')));

    for (final path in const <String>[
      'lib/features/calendar/calendar_maat_flows.dart',
      'lib/features/calendar/evening_threshold_flow.dart',
      'lib/features/calendar/evening_threshold_rite_flow.dart',
      'lib/features/calendar/the_decan_watch_local_store.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('maat_flow_response_')), reason: path);
      expect(source, isNot(contains('MaatFlowResponse')), reason: path);
    }
  });
}
