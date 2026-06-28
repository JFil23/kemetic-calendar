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
import 'package:mobile/features/calendar/the_reading_house_flow.dart';
import 'package:mobile/features/calendar/the_tending_flow.dart';
import 'package:mobile/features/calendar/the_wag_flow.dart';
import 'package:mobile/features/calendar/the_weighing_flow.dart';
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
    expect(MaatFlowJournalCarryMode.none.wireName, 'none');
    expect(MaatFlowJournalCarryMode.userReflection.wireName, 'user_reflection');
    expect(
      MaatFlowJournalCarryModeX.fromWireName('reflection'),
      MaatFlowJournalCarryMode.userReflection,
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
      MaatFlowResponseJournalFormatter.firstArrangementOrder.wireName,
      'first_arrangement_order',
    );
    expect(
      MaatFlowResponseJournalFormatter.livingPatternPrinciple.wireName,
      'living_pattern_principle',
    );
    expect(
      MaatFlowResponseJournalFormatter.houseOfLifeKnowledge.wireName,
      'house_of_life_knowledge',
    );
    expect(MaatFlowResponseJournalFormatter.hotepPeace.wireName, 'hotep_peace');
    expect(
      MaatFlowResponseJournalFormatter.shoreExchange.wireName,
      'shore_exchange',
    );
    expect(
      MaatFlowResponseJournalFormatter.livingTextLine.wireName,
      'living_text_line',
    );
    expect(
      MaatFlowResponseJournalFormatter.clearingSpace.wireName,
      'clearing_space',
    );
    expect(
      MaatFlowResponseJournalFormatter.hetHeruJoy.wireName,
      'het_heru_joy',
    );
    expect(
      MaatFlowResponseJournalFormatter.fairHearingMeasure.wireName,
      'fair_hearing_measure',
    );
    expect(
      MaatFlowResponseJournalFormatter.boundaryStoneRestoration.wireName,
      'boundary_stone_restoration',
    );
    expect(
      MaatFlowResponseJournalFormatter.openMouthWord.wireName,
      'open_mouth_word',
    );
    expect(
      MaatFlowResponseJournalFormatter.autobiographyRecord.wireName,
      'autobiography_record',
    );
    expect(
      MaatFlowResponseJournalFormatter.trueNameAccount.wireName,
      'true_name_account',
    );
    expect(
      MaatFlowResponseJournalFormatter.livingRecordCarried.wireName,
      'living_record_carried',
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
      MaatFlowResponseJournalFormatterX.fromWireName('first-arrangement-order'),
      MaatFlowResponseJournalFormatter.firstArrangementOrder,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName(
        'living-pattern-principle',
      ),
      MaatFlowResponseJournalFormatter.livingPatternPrinciple,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('house-of-life-knowledge'),
      MaatFlowResponseJournalFormatter.houseOfLifeKnowledge,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('hotep-peace'),
      MaatFlowResponseJournalFormatter.hotepPeace,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('shore-exchange'),
      MaatFlowResponseJournalFormatter.shoreExchange,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('living-text-line'),
      MaatFlowResponseJournalFormatter.livingTextLine,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('clearing-space'),
      MaatFlowResponseJournalFormatter.clearingSpace,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('het-heru-joy'),
      MaatFlowResponseJournalFormatter.hetHeruJoy,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('fair-hearing-measure'),
      MaatFlowResponseJournalFormatter.fairHearingMeasure,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName(
        'boundary-stone-restoration',
      ),
      MaatFlowResponseJournalFormatter.boundaryStoneRestoration,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('open-mouth-word'),
      MaatFlowResponseJournalFormatter.openMouthWord,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('autobiography-record'),
      MaatFlowResponseJournalFormatter.autobiographyRecord,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('true-name-account'),
      MaatFlowResponseJournalFormatter.trueNameAccount,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('living-record-carried'),
      MaatFlowResponseJournalFormatter.livingRecordCarried,
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
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('oracle-sign'),
      MaatFlowResponseJournalFormatter.oracleSign,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('wandering-remainder'),
      MaatFlowResponseJournalFormatter.wanderingRemainder,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('follow-sky-witness'),
      MaatFlowResponseJournalFormatter.followSkyWitness,
    );
    expect(
      MaatFlowResponseJournalFormatterX.fromWireName('weighing-record'),
      MaatFlowResponseJournalFormatter.weighingRecord,
    );
  });

  test('default resolver exposes all 31 Ma_at response sheet specs', () {
    expect(kDefaultMaatFlowResponseResolver.specs, hasLength(70));

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
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kOracleFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>[
        'oracle-question-carried',
        'oracle-sign-shape',
        'oracle-received',
      ],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kWanderingFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['wandering-remains', 'wandering-found'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: 'track-the-sky',
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['follow-sky-shown', 'follow-sky-changed'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kTheWeighingFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['weighing-scale-revealed', 'weighing-record-witnessed'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kFirstArrangementFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['first-arrangement-ordered', 'first-arrangement-space-changed'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kLivingPatternFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['living-pattern-observed', 'living-pattern-principle'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kHouseOfLifeFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['house-of-life-clearer', 'house-of-life-learned'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kHotepFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['hotep-cooled', 'hotep-enough-tonight'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kTheShoreFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['shore-exchange-honest', 'shore-exchange-measured'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kLivingTextFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['living-text-added', 'living-text-applied'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kClearingFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['clearing-cleared', 'clearing-waited-response'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kHetHeruFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['het-heru-force-cooled', 'het-heru-joy-returned'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kFairHearingFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['fair-hearing-heard-before-deciding', 'fair-hearing-remembered'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kBoundaryStoneFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['boundary-stone-marker-restored', 'boundary-stone-restored'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kOpenMouthFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['open-mouth-word-disciplined', 'open-mouth-governed'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kTheAutobiographyFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['autobiography-record-clearer', 'autobiography-remembered'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kTrueNameFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['true-name-account-lost-power', 'true-name-accurate-account'],
    );
    expect(
      resolveMaatFlowResponseSpecs(
        flowKey: kLivingRecordFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      ).map((spec) => spec.id),
      <String>['living-record-made-living', 'living-record-carried-forward'],
    );

    for (final flowKey in const <String>[
      'unknown-flow',
      'evening_threshold',
      'unsupported-maat-flow',
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

  test('journal carry mode is explicit and reflection-aware', () {
    final eveningThreshold = resolveMaatFlowResponseSpecs(
      flowKey: kEveningThresholdRiteFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    ).single;
    final boundaryStoneSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kBoundaryStoneFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final boundaryMarker = boundaryStoneSpecs.singleWhere(
      (spec) => spec.id == 'boundary-stone-marker-restored',
    );
    final boundaryReflection = boundaryStoneSpecs.singleWhere(
      (spec) => spec.id == 'boundary-stone-restored',
    );

    expect(eveningThreshold.journalCarryMode, MaatFlowJournalCarryMode.none);
    expect(boundaryMarker.journalCarryMode, MaatFlowJournalCarryMode.none);
    expect(
      boundaryReflection.journalCarryMode,
      MaatFlowJournalCarryMode.userReflection,
    );
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
    final readingHouseSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kReadingHouseFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    expect(readingHouseSpecs.map((spec) => spec.id), <String>[
      kReadingHousePrivateReflectionSpecId,
      kReadingHouseShortNoteSpecId,
      kReadingHouseSitWithoutWritingSpecId,
      kReadingHousePositionSpecId,
    ]);
    expect(
      readingHouseSpecs.map((spec) => spec.journalPolicy).toSet(),
      <MaatFlowJournalPolicy>{MaatFlowJournalPolicy.localOnly},
    );
    expect(readingHouseSpecs.map((spec) => spec.privacyClass).toSet(), <String>{
      'app_record_private',
    });
    expect(
      readingHouseSpecs
          .singleWhere((spec) => spec.id == kReadingHousePositionSpecId)
          .requiredForObserved,
      isTrue,
    );

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

    final oracleSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kOracleFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    expect(oracleSpecs.map((spec) => spec.id), <String>[
      'oracle-question-carried',
      'oracle-sign-shape',
      'oracle-received',
    ]);
    expect(
      oracleSpecs.map((spec) => spec.journalPolicy).toSet(),
      <MaatFlowJournalPolicy>{MaatFlowJournalPolicy.offer},
    );
    expect(oracleSpecs.map((spec) => spec.privacyClass).toSet(), <String>{
      'dream_guidance_private',
    });
    expect(
      oracleSpecs.map((spec) => spec.offerJournalInclusionDefault).toSet(),
      <bool>{false},
    );

    final wanderingSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kWanderingFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    expect(wanderingSpecs.map((spec) => spec.id), <String>[
      'wandering-remains',
      'wandering-found',
    ]);
    expect(
      wanderingSpecs.map((spec) => spec.journalPolicy).toSet(),
      <MaatFlowJournalPolicy>{MaatFlowJournalPolicy.offer},
    );
    expect(wanderingSpecs.map((spec) => spec.privacyClass).toSet(), <String>{
      'grief_absence_private',
    });
    expect(
      wanderingSpecs.map((spec) => spec.offerJournalInclusionDefault).toSet(),
      <bool>{false},
    );

    final weighingSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kTheWeighingFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    expect(weighingSpecs.map((spec) => spec.id), <String>[
      'weighing-scale-revealed',
      'weighing-record-witnessed',
    ]);
    expect(
      weighingSpecs.map((spec) => spec.journalPolicy).toSet(),
      <MaatFlowJournalPolicy>{MaatFlowJournalPolicy.offer},
    );
    expect(weighingSpecs.map((spec) => spec.privacyClass).toSet(), <String>{
      'record_accounting_private',
    });
    expect(
      weighingSpecs.map((spec) => spec.offerJournalInclusionDefault).toSet(),
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

    final skySpecs = resolveMaatFlowResponseSpecs(
      flowKey: 'track-the-sky',
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final sky = buildMaatFlowResponseJournalPreviews(
      specs: skySpecs,
      values: <String, MaatFlowResponseValue>{
        'follow-sky-shown': MaatFlowResponseValue.chips(
          specId: 'follow-sky-shown',
          optionIds: <String>['horizon', 'change'],
        ),
        'follow-sky-changed': MaatFlowResponseValue.text(
          specId: 'follow-sky-changed',
          text: 'the western horizon change',
          multiline: true,
        ),
      },
      clientEventId: 'cid-follow-sky',
    );
    expect(sky, hasLength(1));
    expect(sky.single.policy, MaatFlowJournalPolicy.mirror);
    expect(
      sky.single.sourceId,
      'maat_response:track-the-sky:cid:cid-follow-sky:follow-sky-witness',
    );
    expect(
      sky.single.text,
      'Follow the Sky: I noticed horizon and change and kept the western horizon change.',
    );
  });

  test('Phase 4A decan previews read naturally', () {
    final firstArrangementSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kFirstArrangementFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final firstArrangement = buildMaatFlowResponseJournalPreviews(
      specs: firstArrangementSpecs,
      values: <String, MaatFlowResponseValue>{
        'first-arrangement-ordered': MaatFlowResponseValue.chips(
          specId: 'first-arrangement-ordered',
          optionIds: <String>['cleared', 'made_visible'],
        ),
        'first-arrangement-space-changed': MaatFlowResponseValue.text(
          specId: 'first-arrangement-space-changed',
          text: 'the entry shelf',
          multiline: true,
        ),
      },
      clientEventId: 'cid-first-arrangement',
    );
    expect(firstArrangement, hasLength(1));
    expect(firstArrangement.single.policy, MaatFlowJournalPolicy.mirror);
    expect(
      firstArrangement.single.sourceId,
      'maat_response:the-first-arrangement:cid:cid-first-arrangement:first-arrangement-order',
    );
    expect(
      firstArrangement.single.text,
      'The First Arrangement: I put cleared and made visible into order and made the entry shelf visible.',
    );

    final livingPatternSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kLivingPatternFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final livingPattern = buildMaatFlowResponseJournalPreviews(
      specs: livingPatternSpecs,
      values: <String, MaatFlowResponseValue>{
        'living-pattern-observed': MaatFlowResponseValue.chips(
          specId: 'living-pattern-observed',
          optionIds: <String>['growth', 'return'],
        ),
        'living-pattern-principle': MaatFlowResponseValue.text(
          specId: 'living-pattern-principle',
          text: 'patient timing',
          multiline: true,
        ),
      },
      clientEventId: 'cid-living-pattern',
    );
    expect(livingPattern, hasLength(1));
    expect(livingPattern.single.policy, MaatFlowJournalPolicy.mirror);
    expect(
      livingPattern.single.text,
      'The Living Pattern: I observed growth and return and carried patient timing into action.',
    );

    final houseOfLifeSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kHouseOfLifeFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final houseOfLife = buildMaatFlowResponseJournalPreviews(
      specs: houseOfLifeSpecs,
      values: <String, MaatFlowResponseValue>{
        'house-of-life-clearer': MaatFlowResponseValue.chips(
          specId: 'house-of-life-clearer',
          optionIds: <String>['question', 'source'],
        ),
        'house-of-life-learned': MaatFlowResponseValue.text(
          specId: 'house-of-life-learned',
          text: 'copying the source note',
          multiline: true,
        ),
      },
      clientEventId: 'cid-house-of-life',
    );
    expect(houseOfLife, hasLength(1));
    expect(houseOfLife.single.policy, MaatFlowJournalPolicy.mirror);
    expect(
      houseOfLife.single.text,
      'The House of Life: I made question and source clearer and preserved copying the source note.',
    );

    final hotepSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kHotepFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final hotep = buildMaatFlowResponseJournalPreviews(
      specs: hotepSpecs,
      values: <String, MaatFlowResponseValue>{
        'hotep-cooled': MaatFlowResponseValue.chips(
          specId: 'hotep-cooled',
          optionIds: <String>['given', 'settled'],
        ),
        'hotep-enough-tonight': MaatFlowResponseValue.text(
          specId: 'hotep-enough-tonight',
          text: 'private obligation details',
          multiline: true,
        ),
      },
      clientEventId: 'cid-hotep',
    );
    expect(hotep, hasLength(1));
    expect(hotep.single.policy, MaatFlowJournalPolicy.offer);
    expect(hotep.single.requiresUserChoice, isTrue);
    expect(hotep.single.includeInJournalByDefault, isFalse);
    expect(
      hotep.single.sourceId,
      'maat_response:hotep:cid:cid-hotep:hotep-peace',
    );
    expect(
      hotep.single.text,
      'Hotep: I named given and settled, let enough be enough, and let the heart cool.',
    );
    expect(hotep.single.text, isNot(contains('private obligation')));
  });

  test('Phase 4B through 4D decan previews keep offer summaries safe', () {
    final shoreSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kTheShoreFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final shore = buildMaatFlowResponseJournalPreviews(
      specs: shoreSpecs,
      values: <String, MaatFlowResponseValue>{
        'shore-exchange-honest': MaatFlowResponseValue.chips(
          specId: 'shore-exchange-honest',
          optionIds: <String>['offer', 'measure'],
        ),
        'shore-exchange-measured': MaatFlowResponseValue.text(
          specId: 'shore-exchange-measured',
          text: 'private invoice details',
          multiline: true,
        ),
      },
      clientEventId: 'cid-shore',
    );
    expect(shore, hasLength(1));
    expect(shore.single.policy, MaatFlowJournalPolicy.offer);
    expect(shore.single.requiresUserChoice, isTrue);
    expect(shore.single.includeInJournalByDefault, isFalse);
    expect(
      shore.single.sourceId,
      'maat_response:the-shore:cid:cid-shore:shore-exchange',
    );
    expect(
      shore.single.text,
      'The Shore: I brought offer and measure closer to honest measure.',
    );
    expect(shore.single.text, isNot(contains('private invoice')));

    final livingTextSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kLivingTextFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final livingText = buildMaatFlowResponseJournalPreviews(
      specs: livingTextSpecs,
      values: <String, MaatFlowResponseValue>{
        'living-text-added': MaatFlowResponseValue.chips(
          specId: 'living-text-added',
          optionIds: <String>['question', 'application'],
        ),
        'living-text-applied': MaatFlowResponseValue.text(
          specId: 'living-text-applied',
          text: 'copying a line into practice',
          multiline: true,
        ),
      },
      clientEventId: 'cid-living-text',
    );
    expect(livingText, hasLength(1));
    expect(livingText.single.policy, MaatFlowJournalPolicy.mirror);
    expect(
      livingText.single.text,
      'The Living Text: I received question and application from the text and added copying a line into practice back to life.',
    );

    final clearingSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kClearingFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final clearing = buildMaatFlowResponseJournalPreviews(
      specs: clearingSpecs,
      values: <String, MaatFlowResponseValue>{
        'clearing-cleared': MaatFlowResponseValue.chips(
          specId: 'clearing-cleared',
          optionIds: <String>['heat', 'pause'],
        ),
        'clearing-waited-response': MaatFlowResponseValue.text(
          specId: 'clearing-waited-response',
          text: 'private conflict details',
          multiline: true,
        ),
      },
      clientEventId: 'cid-clearing',
    );
    expect(clearing, hasLength(1));
    expect(clearing.single.policy, MaatFlowJournalPolicy.offer);
    expect(clearing.single.requiresUserChoice, isTrue);
    expect(clearing.single.includeInJournalByDefault, isFalse);
    expect(
      clearing.single.text,
      'The Clearing: I cleared heat and pause before response and acted from the cleared place.',
    );
    expect(clearing.single.text, isNot(contains('private conflict')));

    final hetHeruSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kHetHeruFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final hetHeru = buildMaatFlowResponseJournalPreviews(
      specs: hetHeruSpecs,
      values: <String, MaatFlowResponseValue>{
        'het-heru-force-cooled': MaatFlowResponseValue.chips(
          specId: 'het-heru-force-cooled',
          optionIds: <String>['music', 'joy'],
        ),
        'het-heru-joy-returned': MaatFlowResponseValue.text(
          specId: 'het-heru-joy-returned',
          text: 'private anger details',
          multiline: true,
        ),
      },
      clientEventId: 'cid-het-heru',
    );
    expect(hetHeru, hasLength(1));
    expect(hetHeru.single.policy, MaatFlowJournalPolicy.offer);
    expect(hetHeru.single.requiresUserChoice, isTrue);
    expect(hetHeru.single.includeInJournalByDefault, isFalse);
    expect(
      hetHeru.single.text,
      'Het-Heru: I cooled the hot force with music and joy and made room for beauty, joy, or rest.',
    );
    expect(hetHeru.single.text, isNot(contains('private anger')));

    final fairHearingSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kFairHearingFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final fairHearing = buildMaatFlowResponseJournalPreviews(
      specs: fairHearingSpecs,
      values: <String, MaatFlowResponseValue>{
        'fair-hearing-heard-before-deciding': MaatFlowResponseValue.chips(
          specId: 'fair-hearing-heard-before-deciding',
          optionIds: <String>['heard_fully', 'same_measure'],
        ),
        'fair-hearing-remembered': MaatFlowResponseValue.text(
          specId: 'fair-hearing-remembered',
          text: 'private decision details',
          multiline: true,
        ),
      },
      clientEventId: 'cid-fair-hearing',
    );
    expect(fairHearing, hasLength(1));
    expect(fairHearing.single.policy, MaatFlowJournalPolicy.offer);
    expect(fairHearing.single.requiresUserChoice, isTrue);
    expect(fairHearing.single.includeInJournalByDefault, isFalse);
    expect(
      fairHearing.single.text,
      'The Fair Hearing: I listened before deciding, marked heard fully and same measure, and kept the measure even.',
    );
    expect(fairHearing.single.text, isNot(contains('private decision')));

    final boundaryStoneSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kBoundaryStoneFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final boundaryStone = buildMaatFlowResponseJournalPreviews(
      specs: boundaryStoneSpecs,
      values: <String, MaatFlowResponseValue>{
        'boundary-stone-marker-restored': MaatFlowResponseValue.chips(
          specId: 'boundary-stone-marker-restored',
          optionIds: <String>['labor', 'ownership'],
        ),
        'boundary-stone-restored': MaatFlowResponseValue.text(
          specId: 'boundary-stone-restored',
          text: 'private resource dispute',
          multiline: true,
        ),
      },
      clientEventId: 'cid-boundary-stone',
    );
    expect(boundaryStone, hasLength(1));
    expect(boundaryStone.single.policy, MaatFlowJournalPolicy.offer);
    expect(boundaryStone.single.requiresUserChoice, isTrue);
    expect(boundaryStone.single.includeInJournalByDefault, isFalse);
    expect(
      boundaryStone.single.text,
      'The Boundary Stone: I restored labor and ownership to its rightful place.',
    );
    expect(boundaryStone.single.text, isNot(contains('private resource')));

    final openMouthSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kOpenMouthFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final openMouth = buildMaatFlowResponseJournalPreviews(
      specs: openMouthSpecs,
      values: <String, MaatFlowResponseValue>{
        'open-mouth-word-disciplined': MaatFlowResponseValue.chips(
          specId: 'open-mouth-word-disciplined',
          optionIds: <String>['silence', 'repair'],
        ),
        'open-mouth-governed': MaatFlowResponseValue.text(
          specId: 'open-mouth-governed',
          text: 'private conflict language',
          multiline: true,
        ),
      },
      clientEventId: 'cid-open-mouth',
    );
    expect(openMouth, hasLength(1));
    expect(openMouth.single.policy, MaatFlowJournalPolicy.offer);
    expect(openMouth.single.requiresUserChoice, isTrue);
    expect(openMouth.single.includeInJournalByDefault, isFalse);
    expect(
      openMouth.single.text,
      'The Open Mouth: I governed silence and repair and let speech serve Ma\'at.',
    );
    expect(openMouth.single.text, isNot(contains('private conflict')));

    final autobiographySpecs = resolveMaatFlowResponseSpecs(
      flowKey: kTheAutobiographyFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final autobiography = buildMaatFlowResponseJournalPreviews(
      specs: autobiographySpecs,
      values: <String, MaatFlowResponseValue>{
        'autobiography-record-clearer': MaatFlowResponseValue.chips(
          specId: 'autobiography-record-clearer',
          optionIds: <String>['capacity', 'evidence'],
        ),
        'autobiography-remembered': MaatFlowResponseValue.text(
          specId: 'autobiography-remembered',
          text: 'private identity claim and shame details',
          multiline: true,
        ),
      },
      clientEventId: 'cid-autobiography',
    );
    expect(autobiography, hasLength(1));
    expect(autobiography.single.policy, MaatFlowJournalPolicy.offer);
    expect(autobiography.single.requiresUserChoice, isTrue);
    expect(autobiography.single.includeInJournalByDefault, isFalse);
    expect(
      autobiography.single.text,
      'The Autobiography: I named capacity and evidence in my record with clearer evidence.',
    );
    expect(autobiography.single.text, isNot(contains('identity claim')));
    expect(autobiography.single.text, isNot(contains('shame')));

    final trueNameSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kTrueNameFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final trueName = buildMaatFlowResponseJournalPreviews(
      specs: trueNameSpecs,
      values: <String, MaatFlowResponseValue>{
        'true-name-account-lost-power': MaatFlowResponseValue.chips(
          specId: 'true-name-account-lost-power',
          optionIds: <String>['false_account', 'accurate_account'],
        ),
        'true-name-accurate-account': MaatFlowResponseValue.text(
          specId: 'true-name-accurate-account',
          text: 'private name and false story',
          multiline: true,
        ),
      },
      clientEventId: 'cid-true-name',
    );
    expect(trueName, hasLength(1));
    expect(trueName.single.policy, MaatFlowJournalPolicy.offer);
    expect(trueName.single.requiresUserChoice, isTrue);
    expect(trueName.single.includeInJournalByDefault, isFalse);
    expect(
      trueName.single.text,
      'The True Name: I measured false account and accurate account against the record and stood closer to the accurate name.',
    );
    expect(trueName.single.text, isNot(contains('private name')));
    expect(trueName.single.text, isNot(contains('false story')));

    final livingRecordSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kLivingRecordFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final livingRecord = buildMaatFlowResponseJournalPreviews(
      specs: livingRecordSpecs,
      values: <String, MaatFlowResponseValue>{
        'living-record-made-living': MaatFlowResponseValue.chips(
          specId: 'living-record-made-living',
          optionIds: <String>['day_card', 'journal'],
        ),
        'living-record-carried-forward': MaatFlowResponseValue.text(
          specId: 'living-record-carried-forward',
          text: 'private cross-app record details',
          multiline: true,
        ),
      },
      clientEventId: 'cid-living-record',
    );
    expect(livingRecord, hasLength(1));
    expect(livingRecord.single.policy, MaatFlowJournalPolicy.offer);
    expect(livingRecord.single.requiresUserChoice, isTrue);
    expect(livingRecord.single.includeInJournalByDefault, isFalse);
    expect(
      livingRecord.single.text,
      'The Living Record: I turned day card and journal into a record that can be carried forward.',
    );
    expect(livingRecord.single.text, isNot(contains('private cross-app')));
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

    final oracleSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kOracleFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final oracle = buildMaatFlowResponseJournalPreviews(
      specs: oracleSpecs,
      values: <String, MaatFlowResponseValue>{
        'oracle-question-carried': MaatFlowResponseValue.text(
          specId: 'oracle-question-carried',
          text: 'What did the private dream mean?',
        ),
        'oracle-sign-shape': MaatFlowResponseValue.chips(
          specId: 'oracle-sign-shape',
          optionIds: <String>['dream', 'image'],
        ),
        'oracle-received': MaatFlowResponseValue.text(
          specId: 'oracle-received',
          text: 'raw dream image with a private name',
          multiline: true,
        ),
      },
      clientEventId: 'cid-oracle',
    );
    expect(oracle, hasLength(1));
    expect(oracle.single.policy, MaatFlowJournalPolicy.offer);
    expect(oracle.single.requiresUserChoice, isTrue);
    expect(oracle.single.includeInJournalByDefault, isFalse);
    expect(
      oracle.single.sourceId,
      'maat_response:the-oracle:cid:cid-oracle:oracle-sign',
    );
    expect(
      oracle.single.text,
      'The Oracle: I received one sign through dream and image and will test it through grounded action.',
    );
    expect(oracle.single.text, isNot(contains('private dream')));
    expect(oracle.single.text, isNot(contains('private name')));

    final wanderingSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kWanderingFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final wandering = buildMaatFlowResponseJournalPreviews(
      specs: wanderingSpecs,
      values: <String, MaatFlowResponseValue>{
        'wandering-remains': MaatFlowResponseValue.chips(
          specId: 'wandering-remains',
          optionIds: <String>['loss', 'support'],
        ),
        'wandering-found': MaatFlowResponseValue.text(
          specId: 'wandering-found',
          text: 'raw grief language and a private name',
          multiline: true,
        ),
      },
      clientEventId: 'cid-wandering',
    );
    expect(wandering, hasLength(1));
    expect(wandering.single.policy, MaatFlowJournalPolicy.offer);
    expect(wandering.single.requiresUserChoice, isTrue);
    expect(wandering.single.includeInJournalByDefault, isFalse);
    expect(
      wandering.single.sourceId,
      'maat_response:the-wandering:cid:cid-wandering:wandering-remainder',
    );
    expect(
      wandering.single.text,
      'The Wandering: I honored loss and support and noticed one thing that remains.',
    );
    expect(wandering.single.text, isNot(contains('raw grief')));
    expect(wandering.single.text, isNot(contains('private name')));

    final weighingSpecs = resolveMaatFlowResponseSpecs(
      flowKey: kTheWeighingFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
    );
    final weighing = buildMaatFlowResponseJournalPreviews(
      specs: weighingSpecs,
      values: <String, MaatFlowResponseValue>{
        'weighing-scale-revealed': MaatFlowResponseValue.chips(
          specId: 'weighing-scale-revealed',
          optionIds: <String>['record', 'correction'],
        ),
        'weighing-record-witnessed': MaatFlowResponseValue.text(
          specId: 'weighing-record-witnessed',
          text: 'private ledger number and conflict detail',
          multiline: true,
        ),
      },
      clientEventId: 'cid-weighing',
    );
    expect(weighing, hasLength(1));
    expect(weighing.single.policy, MaatFlowJournalPolicy.offer);
    expect(weighing.single.requiresUserChoice, isTrue);
    expect(weighing.single.includeInJournalByDefault, isFalse);
    expect(
      weighing.single.sourceId,
      'maat_response:the-weighing:cid:cid-weighing:weighing-record',
    );
    expect(
      weighing.single.text,
      'The Weighing: I placed record and correction on the scale and named one correction.',
    );
    expect(weighing.single.text, isNot(contains('ledger number')));
    expect(weighing.single.text, isNot(contains('conflict detail')));
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

  test('Phase 4D wiring stays isolated to shared sheet panels and pilots', () {
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
        kReadingHouseFlowKey,
        kTheTendingFlowKey,
        kKeptWordFlowKey,
        kTheWagFlowKey,
        kKhatFlowKey,
        kOracleFlowKey,
        kWanderingFlowKey,
        'track-the-sky',
        kTheWeighingFlowKey,
        kFirstArrangementFlowKey,
        kLivingPatternFlowKey,
        kHouseOfLifeFlowKey,
        kHotepFlowKey,
        kTheShoreFlowKey,
        kLivingTextFlowKey,
        kClearingFlowKey,
        kHetHeruFlowKey,
        kFairHearingFlowKey,
        kBoundaryStoneFlowKey,
        kOpenMouthFlowKey,
        kTheAutobiographyFlowKey,
        kTrueNameFlowKey,
        kLivingRecordFlowKey,
      },
    );

    final dayView = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();
    expect(dayView, contains('resolveMaatFlowResponseSpecs('));
    expect(dayView, contains('MaatFlowResponseSurface.calendarSheet'));
    expect(dayView, contains('MaatFlowResponseSection('));
    expect(dayView, contains('buildMaatJournalPlainUserTextBlocks('));
    expect(dayView, isNot(contains('journalPreviews:')));
    expect(dayView, isNot(contains('_responseJournalPreviews')));
    expect(dayView, isNot(contains('Journal preview')));
    expect(dayView, isNot(contains('Add to journal')));
    expect(dayView, contains('responseSpecs: responseSpecs'));
    expect(dayView, contains('class _CalendarEventDetailSheetState'));
    expect(dayView, contains('_MaatFlowCompletionPanel('));

    final completion = File(
      'lib/features/calendar/calendar_completion.dart',
    ).readAsStringSync();
    expect(completion, contains('final Widget? leadingContent;'));

    final portraitGrid = File(
      'lib/features/calendar/calendar_grid_widgets.dart',
    ).readAsStringSync();
    expect(portraitGrid, contains('CalendarEventDetailSheet('));
    expect(portraitGrid, contains('onWriteJournalResponse'));
    expect(portraitGrid, isNot(contains('resolveMaatFlowResponseSpecs(')));

    final landscape = File(
      'lib/features/calendar/landscape_month_view.dart',
    ).readAsStringSync();
    expect(landscape, contains('CalendarEventDetailSheet('));
    expect(landscape, contains('onWriteJournalResponse'));
    expect(landscape, isNot(contains('resolveMaatFlowResponseSpecs(')));

    final detail = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();
    expect(detail, contains('resolveMaatFlowInitialPromptSpec('));
    expect(detail, contains('MaatFlowResponseSection('));
    expect(detail, isNot(contains('onWriteJournalResponse')));
    expect(detail, isNot(contains('buildMaatJournalResponseBlocksForPolicy')));

    for (final path in const <String>[
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
