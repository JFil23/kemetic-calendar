import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/dawn_house_rite_flow.dart';
import 'package:mobile/features/calendar/evening_threshold_rite_flow.dart';
import 'package:mobile/features/calendar/maat_decan_flow.dart';
import 'package:mobile/features/calendar/maat_flow_response_journal_blocks.dart';
import 'package:mobile/features/calendar/maat_flow_response_models.dart';
import 'package:mobile/features/calendar/maat_flow_response_resolver.dart';
import 'package:mobile/features/calendar/the_days_outside_year_flow.dart';
import 'package:mobile/features/calendar/the_decan_watch_flow.dart';
import 'package:mobile/features/calendar/the_djed_flow.dart';
import 'package:mobile/features/calendar/the_kept_word_flow.dart';
import 'package:mobile/features/calendar/the_open_hand_flow.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/the_tending_flow.dart';
import 'package:mobile/features/calendar/the_wag_flow.dart';
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
      MaatFlowResponseJournalFormatter.dawnHouseRite.wireName,
      'dawn_house_rite',
    );
    expect(
      MaatFlowResponseJournalFormatter.closingRelease.wireName,
      'closing_release',
    );
    expect(
      MaatFlowResponseJournalFormatter.offeringTable.wireName,
      'offering_table',
    );
    expect(
      MaatFlowResponseJournalFormatter.daysOutsideReceipt.wireName,
      'days_outside_receipt',
    );
    expect(
      MaatFlowResponseJournalFormatter.wepRonpetOpening.wireName,
      'wep_ronpet_opening',
    );
    expect(
      MaatFlowResponseJournalFormatter.openHandProvision.wireName,
      'open_hand_provision',
    );
    expect(
      MaatFlowResponseJournalFormatter.djedRestoration.wireName,
      'djed_restoration',
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('decan-watch'),
      MaatFlowResponseJournalFormatter.decanWatch,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('dawn-house-rite'),
      MaatFlowResponseJournalFormatter.dawnHouseRite,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('closing-release'),
      MaatFlowResponseJournalFormatter.closingRelease,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('offering-table'),
      MaatFlowResponseJournalFormatter.offeringTable,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('days-outside-receipt'),
      MaatFlowResponseJournalFormatter.daysOutsideReceipt,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('wep-ronpet-opening'),
      MaatFlowResponseJournalFormatter.wepRonpetOpening,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('open-hand-provision'),
      MaatFlowResponseJournalFormatter.openHandProvision,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('djed-restoration'),
      MaatFlowResponseJournalFormatter.djedRestoration,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('tending-care'),
      MaatFlowResponseJournalFormatter.tendingCare,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('kept-word-agreement'),
      MaatFlowResponseJournalFormatter.keptWordAgreement,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('wag-memory'),
      MaatFlowResponseJournalFormatter.wagMemory,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('khat-body-care'),
      MaatFlowResponseJournalFormatter.khatBodyCare,
    );
  });

  test('default resolver exposes only Phase 2B through 3E pilot specs', () {
    expect(kDefaultMaatFlowResponseResolver.specs, hasLength(29));

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
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kDawnHouseRiteFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['dawn-house-order-act'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kEveningThresholdRiteFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['closing-release-tonight'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kOfferingTableFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['offering-table-fed', 'offering-table-provided'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kDaysOutsideTheYearFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
        eventKey: 'event-1',
      ).map((spec) => spec.id),
      <String>['days-outside-receipt'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kDaysOutsideTheYearFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
        eventKey: 'event-6',
      ).map((spec) => spec.id),
      <String>['wep-ronpet-year-intention'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kDaysOutsideTheYearFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
        eventKey: 'event-7',
      ),
      isEmpty,
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kTheOpenHandFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['open-hand-given', 'open-hand-moved'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kTheDjedFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['djed-stood-upright', 'djed-restored'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kTheWagFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['wag-remembered', 'wag-carried'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kKhatFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['khat-body-asked', 'khat-care-given'],
    );

    for (final flowKey in const <String>[
      'unknown-flow',
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

  test('sensitive action flows use offer policy and privacy classes', () {
    final openHandSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kTheOpenHandFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    expect(
      openHandSpecs.map((spec) => spec.journalPolicy).toSet(),
      <MaatFlowJournalPolicy>{MaatFlowJournalPolicy.offer},
    );
    expect(openHandSpecs.map((spec) => spec.privacyClass).toSet(), <String>{
      'outward_provision',
    });

    final djedSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kTheDjedFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    expect(
      djedSpecs.map((spec) => spec.journalPolicy).toSet(),
      <MaatFlowJournalPolicy>{MaatFlowJournalPolicy.offer},
    );
    expect(djedSpecs.map((spec) => spec.privacyClass).toSet(), <String>{
      'sensitive_structure',
    });
    expect(
      djedSpecs.map((spec) => spec.offerJournalInclusionDefault).toSet(),
      <bool>{true},
    );

    final tendingSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kTheTendingFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    expect(tendingSpecs.map((spec) => spec.id), <String>[
      'tending-care-specific',
      'tending-act-completed',
    ]);
    expect(
      tendingSpecs.map((spec) => spec.journalPolicy).toSet(),
      <MaatFlowJournalPolicy>{MaatFlowJournalPolicy.offer},
    );
    expect(tendingSpecs.map((spec) => spec.privacyClass).toSet(), <String>{
      'care_private',
    });
    expect(
      tendingSpecs.map((spec) => spec.offerJournalInclusionDefault).toSet(),
      <bool>{false},
    );

    final keptWordSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kKeptWordFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    expect(keptWordSpecs.map((spec) => spec.id), <String>[
      'kept-word-status',
      'kept-word-remembered',
    ]);
    expect(
      keptWordSpecs.map((spec) => spec.journalPolicy).toSet(),
      <MaatFlowJournalPolicy>{MaatFlowJournalPolicy.offer},
    );
    expect(keptWordSpecs.map((spec) => spec.privacyClass).toSet(), <String>{
      'agreement_private',
    });
    expect(
      keptWordSpecs.map((spec) => spec.offerJournalInclusionDefault).toSet(),
      <bool>{false},
    );

    final wagSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kTheWagFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    expect(wagSpecs.map((spec) => spec.id), <String>[
      'wag-remembered',
      'wag-carried',
    ]);
    expect(
      wagSpecs.map((spec) => spec.journalPolicy).toSet(),
      <MaatFlowJournalPolicy>{MaatFlowJournalPolicy.offer},
    );
    expect(wagSpecs.map((spec) => spec.privacyClass).toSet(), <String>{
      'ancestor_memory_private',
    });
    expect(
      wagSpecs.map((spec) => spec.offerJournalInclusionDefault).toSet(),
      <bool>{false},
    );

    final khatSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kKhatFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    expect(khatSpecs.map((spec) => spec.id), <String>[
      'khat-body-asked',
      'khat-care-given',
    ]);
    expect(
      khatSpecs.map((spec) => spec.journalPolicy).toSet(),
      <MaatFlowJournalPolicy>{MaatFlowJournalPolicy.offer},
    );
    expect(khatSpecs.map((spec) => spec.privacyClass).toSet(), <String>{
      'body_care_private',
    });
    expect(
      khatSpecs.map((spec) => spec.offerJournalInclusionDefault).toSet(),
      <bool>{false},
    );
  });

  test('Dawn House and Closing journal formatters read naturally', () {
    final dawnSpec = resolveMaatFlowResponseSpecs(
      flowKey: kDawnHouseRiteFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    ).single;
    final dawn = buildMaatFlowResponseJournalPreview(
      spec: dawnSpec,
      value: MaatFlowResponseValue.text(
        specId: dawnSpec.id,
        text: 'clearing the table before the day began.',
      ),
    );

    expect(
      dawn!.text,
      'Dawn House Rite: I brought order by clearing the table before the day began.',
    );

    final closingSpec = resolveMaatFlowResponseSpecs(
      flowKey: kEveningThresholdRiteFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    ).single;
    final closing = buildMaatFlowResponseJournalPreview(
      spec: closingSpec,
      value: MaatFlowResponseValue.text(
        specId: closingSpec.id,
        text: 'the unfinished worry and leave it for tomorrow\'s light.',
        multiline: true,
      ),
    );

    expect(
      closing!.text,
      'The Closing: I release the unfinished worry and leave it for tomorrow\'s light.',
    );
  });

  test('Offering Table and Days Outside formatters read naturally', () {
    final offeringSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kOfferingTableFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final offering = buildMaatFlowResponseJournalPreviews(
      specs: offeringSpecs,
      values: <String, MaatFlowResponseValue>{
        'offering-table-fed': MaatFlowResponseValue.chips(
          specId: 'offering-table-fed',
          optionIds: <String>['rest'],
        ),
        'offering-table-provided': MaatFlowResponseValue.text(
          specId: 'offering-table-provided',
          text: 'closing the laptop early and letting the house settle.',
          multiline: true,
        ),
      },
      clientEventId: 'cid-offering',
    );

    expect(offering, hasLength(1));
    expect(
      offering.single.sourceId,
      'maat_response:the-offering-table:cid:cid-offering:offering-table-provision',
    );
    expect(
      offering.single.text,
      'The Offering Table: I fed rest by closing the laptop early and letting the house settle.',
    );

    final offeringChipsOnly = buildMaatFlowResponseJournalPreviews(
      specs: offeringSpecs,
      values: <String, MaatFlowResponseValue>{
        'offering-table-fed': MaatFlowResponseValue.chips(
          specId: 'offering-table-fed',
          optionIds: <String>['water', 'care'],
        ),
      },
    );
    expect(
      offeringChipsOnly.single.text,
      'The Offering Table: I provided water and care today.',
    );

    final daysSpec = resolveMaatFlowResponseSpecs(
      flowKey: kDaysOutsideTheYearFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
      eventKey: 'event-1',
    ).single;
    final days = buildMaatFlowResponseJournalPreview(
      spec: daysSpec,
      value: MaatFlowResponseValue.text(
        specId: daysSpec.id,
        text: 'I survived the old year with more clarity than I entered it.',
        multiline: true,
      ),
    );
    expect(
      days!.text,
      'The Days Outside the Year: I carry the receipt that I survived the old year with more clarity than I entered it.',
    );

    final wepSpec = resolveMaatFlowResponseSpecs(
      flowKey: kDaysOutsideTheYearFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
      eventKey: 'event-6',
    ).single;
    final wep = buildMaatFlowResponseJournalPreview(
      spec: wepSpec,
      value: MaatFlowResponseValue.text(
        specId: wepSpec.id,
        text: 'steadiness, clean speech, and finished work.',
        multiline: true,
      ),
    );
    expect(
      wep!.text,
      'Wep Ronpet: I open the year with steadiness, clean speech, and finished work.',
    );
  });

  test('sensitive offer previews read naturally', () {
    final openHandSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kTheOpenHandFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final openHand = buildMaatFlowResponseJournalPreviews(
      specs: openHandSpecs,
      values: <String, MaatFlowResponseValue>{
        'open-hand-given': MaatFlowResponseValue.chips(
          specId: 'open-hand-given',
          optionIds: <String>['time', 'attention'],
        ),
        'open-hand-moved': MaatFlowResponseValue.text(
          specId: 'open-hand-moved',
          text: 'where need was visible.',
          multiline: true,
        ),
      },
      clientEventId: 'cid-open-hand',
    );

    expect(openHand, hasLength(1));
    expect(openHand.single.policy, MaatFlowJournalPolicy.offer);
    expect(openHand.single.writesByDefault, isFalse);
    expect(openHand.single.requiresUserChoice, isTrue);
    expect(
      openHand.single.sourceId,
      'maat_response:the-open-hand:cid:cid-open-hand:open-hand-provision',
    );
    expect(
      openHand.single.text,
      'The Open Hand: I gave time and attention where need was visible.',
    );

    final openHandChipsOnly = buildMaatFlowResponseJournalPreviews(
      specs: openHandSpecs,
      values: <String, MaatFlowResponseValue>{
        'open-hand-given': MaatFlowResponseValue.chips(
          specId: 'open-hand-given',
          optionIds: <String>['labor'],
        ),
      },
    );
    expect(
      openHandChipsOnly.single.text,
      'The Open Hand: I gave labor where need was visible.',
    );

    final djedSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kTheDjedFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final djed = buildMaatFlowResponseJournalPreviews(
      specs: djedSpecs,
      values: <String, MaatFlowResponseValue>{
        'djed-stood-upright': MaatFlowResponseValue.chips(
          specId: 'djed-stood-upright',
          optionIds: <String>['body', 'boundary'],
        ),
        'djed-restored': MaatFlowResponseValue.text(
          specId: 'djed-restored',
          text: 'setting a load-bearing practice back in place.',
          multiline: true,
        ),
      },
      clientEventId: 'cid-djed',
    );

    expect(djed, hasLength(1));
    expect(djed.single.policy, MaatFlowJournalPolicy.offer);
    expect(djed.single.writesByDefault, isFalse);
    expect(djed.single.requiresUserChoice, isTrue);
    expect(
      djed.single.sourceId,
      'maat_response:the-djed:cid:cid-djed:djed-restoration',
    );
    expect(
      djed.single.text,
      'The Djed: I restored body and boundary by setting a load-bearing practice back in place and stood it upright again.',
    );
    expect(djed.single.includeInJournalByDefault, isTrue);

    final djedNounPhrase = buildMaatFlowResponseJournalPreviews(
      specs: djedSpecs,
      values: <String, MaatFlowResponseValue>{
        'djed-stood-upright': MaatFlowResponseValue.chips(
          specId: 'djed-stood-upright',
          optionIds: <String>['practice'],
        ),
        'djed-restored': MaatFlowResponseValue.text(
          specId: 'djed-restored',
          text: 'one load-bearing part of my life.',
          multiline: true,
        ),
      },
    );
    expect(
      djedNounPhrase.single.text,
      'The Djed: I restored practice by restoring one load-bearing part of my life and stood it upright again.',
    );

    final tendingSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kTheTendingFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final tending = buildMaatFlowResponseJournalPreviews(
      specs: tendingSpecs,
      values: <String, MaatFlowResponseValue>{
        'tending-care-specific': MaatFlowResponseValue.chips(
          specId: 'tending-care-specific',
          optionIds: <String>['seen', 'repaired'],
        ),
        'tending-act-completed': MaatFlowResponseValue.text(
          specId: 'tending-act-completed',
          text: 'calling before the day closed.',
          multiline: true,
        ),
      },
      clientEventId: 'cid-tending',
    );
    expect(tending, hasLength(1));
    expect(tending.single.policy, MaatFlowJournalPolicy.offer);
    expect(tending.single.requiresUserChoice, isTrue);
    expect(tending.single.includeInJournalByDefault, isFalse);
    expect(
      tending.single.sourceId,
      'maat_response:the-tending:cid:cid-tending:tending-care',
    );
    expect(
      tending.single.text,
      'The Tending: I made care specific through seen and repaired and completed calling before the day closed.',
    );

    final keptWordSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kKeptWordFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final keptWord = buildMaatFlowResponseJournalPreviews(
      specs: keptWordSpecs,
      values: <String, MaatFlowResponseValue>{
        'kept-word-status': MaatFlowResponseValue.choice(
          specId: 'kept-word-status',
          optionId: 'renegotiated',
        ),
        'kept-word-remembered': MaatFlowResponseValue.text(
          specId: 'kept-word-remembered',
          text: 'the repaired conversation belongs in memory.',
          multiline: true,
        ),
      },
      clientEventId: 'cid-kept-word',
    );
    expect(keptWord, hasLength(1));
    expect(keptWord.single.policy, MaatFlowJournalPolicy.offer);
    expect(keptWord.single.requiresUserChoice, isTrue);
    expect(keptWord.single.includeInJournalByDefault, isFalse);
    expect(
      keptWord.single.sourceId,
      'maat_response:the-kept-word:cid:cid-kept-word:kept-word-agreement',
    );
    expect(
      keptWord.single.text,
      'The Kept Word: I brought one agreement back into clearer order; the word is renegotiated, and I remember the repaired conversation belongs in memory.',
    );

    final wagSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kTheWagFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final wag = buildMaatFlowResponseJournalPreviews(
      specs: wagSpecs,
      values: <String, MaatFlowResponseValue>{
        'wag-remembered': MaatFlowResponseValue.chips(
          specId: 'wag-remembered',
          optionIds: <String>['table', 'legacy'],
        ),
        'wag-carried': MaatFlowResponseValue.text(
          specId: 'wag-carried',
          text: 'one remembered gift',
          multiline: true,
        ),
      },
      clientEventId: 'cid-wag',
    );
    expect(wag, hasLength(1));
    expect(wag.single.policy, MaatFlowJournalPolicy.offer);
    expect(wag.single.requiresUserChoice, isTrue);
    expect(wag.single.includeInJournalByDefault, isFalse);
    expect(wag.single.sourceId, 'maat_response:the-wag:cid:cid-wag:wag-memory');
    expect(
      wag.single.text,
      'The Wag: I kept table and legacy at the table and carried one remembered gift forward.',
    );

    final khatSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kKhatFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final khat = buildMaatFlowResponseJournalPreviews(
      specs: khatSpecs,
      values: <String, MaatFlowResponseValue>{
        'khat-body-asked': MaatFlowResponseValue.chips(
          specId: 'khat-body-asked',
          optionIds: <String>['water', 'rest'],
        ),
        'khat-care-given': MaatFlowResponseValue.text(
          specId: 'khat-care-given',
          text: 'one honest act of care',
          multiline: true,
        ),
      },
      clientEventId: 'cid-khat',
    );
    expect(khat, hasLength(1));
    expect(khat.single.policy, MaatFlowJournalPolicy.offer);
    expect(khat.single.requiresUserChoice, isTrue);
    expect(khat.single.includeInJournalByDefault, isFalse);
    expect(
      khat.single.sourceId,
      'maat_response:the-khat:cid:cid-khat:khat-body-care',
    );
    expect(
      khat.single.text,
      'The Khat: I listened to the body asking for water and rest and answered with one honest act of care.',
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

  test('Phase 3E wiring stays isolated to shared sheet panels and pilots', () {
    expect(
      kDefaultMaatFlowResponseResolver.specs
          .map((spec) => spec.flowKey)
          .toSet(),
      <String>{
        'the-moon-return',
        'the-course',
        'the-decan-watch',
        kDawnHouseRiteFlowKey,
        kEveningThresholdRiteFlowKey,
        kOfferingTableFlowKey,
        kDaysOutsideTheYearFlowKey,
        kTheOpenHandFlowKey,
        kTheDjedFlowKey,
        kTheTendingFlowKey,
        kKeptWordFlowKey,
        kTheWagFlowKey,
        kKhatFlowKey,
      },
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
