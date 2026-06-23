import 'dawn_house_rite_flow.dart';
import 'evening_threshold_rite_flow.dart';
import 'maat_decan_flow.dart';
import 'maat_flow_response_models.dart';
import 'the_days_outside_year_flow.dart';
import 'the_decan_watch_flow.dart';
import 'the_djed_flow.dart';
import 'the_kept_word_flow.dart';
import 'the_open_hand_flow.dart';
import 'the_offering_table_flow.dart';
import 'the_tending_flow.dart';
import 'the_wag_flow.dart';

const List<MaatFlowResponseSpec>
kPilotMaatFlowResponseSpecs = <MaatFlowResponseSpec>[
  MaatFlowResponseSpec(
    id: 'moon-return-set-down',
    flowKey: 'the-moon-return',
    eventKey: 'new',
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.text,
    label: 'What do you set down?',
    journalPolicy: MaatFlowJournalPolicy.mirror,
    journalLabel: 'Moon Return',
  ),
  MaatFlowResponseSpec(
    id: 'moon-return-filled',
    flowKey: 'the-moon-return',
    eventKey: 'full',
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.text,
    label: 'What has filled?',
    journalPolicy: MaatFlowJournalPolicy.mirror,
    journalLabel: 'Moon Return',
  ),
  MaatFlowResponseSpec(
    id: 'course-hour-action',
    flowKey: 'the-course',
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.text,
    label: 'What action fits this hour?',
    journalPolicy: MaatFlowJournalPolicy.mirror,
    journalLabel: 'The Course',
  ),
  MaatFlowResponseSpec(
    id: kDecanWatchResponseVisibilitySpecId,
    flowKey: kDecanWatchFlowKey,
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.choice,
    label: 'Visibility',
    options: <MaatFlowResponseOption>[
      MaatFlowResponseOption(
        id: kDecanWatchVisibilityOutside,
        label: 'Outside',
      ),
      MaatFlowResponseOption(id: kDecanWatchVisibilityInside, label: 'Inside'),
      MaatFlowResponseOption(
        id: kDecanWatchVisibilityClouded,
        label: 'Clouded',
      ),
      MaatFlowResponseOption(
        id: kDecanWatchVisibilityNotVisible,
        label: 'Not visible',
      ),
    ],
    journalPolicy: MaatFlowJournalPolicy.mirror,
    journalLabel: kDecanWatchTitle,
    journalGroupId: kDecanWatchResponseJournalGroupId,
    journalGroupLabel: kDecanWatchTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.decanWatch,
    journalRole: 'visibility',
  ),
  MaatFlowResponseSpec(
    id: kDecanWatchResponseSkyNoteSpecId,
    flowKey: kDecanWatchFlowKey,
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.multiline,
    label: 'What did the sky show?',
    journalPolicy: MaatFlowJournalPolicy.mirror,
    journalLabel: kDecanWatchTitle,
    journalGroupId: kDecanWatchResponseJournalGroupId,
    journalGroupLabel: kDecanWatchTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.decanWatch,
    journalRole: 'sky_note',
  ),
  MaatFlowResponseSpec(
    id: kDecanWatchResponseBearingSpecId,
    flowKey: kDecanWatchFlowKey,
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.multiline,
    label: 'What bearing do you carry into the next ten days?',
    journalPolicy: MaatFlowJournalPolicy.mirror,
    journalLabel: kDecanWatchTitle,
    journalGroupId: kDecanWatchResponseJournalGroupId,
    journalGroupLabel: kDecanWatchTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.decanWatch,
    journalRole: 'bearing',
  ),
  MaatFlowResponseSpec(
    id: 'dawn-house-order-act',
    flowKey: kDawnHouseRiteFlowKey,
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.text,
    label: 'One act of order today',
    journalPolicy: MaatFlowJournalPolicy.mirror,
    journalLabel: kDawnHouseRiteTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.dawnHouseRite,
  ),
  MaatFlowResponseSpec(
    id: 'closing-release-tonight',
    flowKey: kEveningThresholdRiteFlowKey,
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.multiline,
    label: 'What do you release tonight?',
    journalPolicy: MaatFlowJournalPolicy.mirror,
    journalLabel: kEveningThresholdRiteTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.closingRelease,
  ),
  MaatFlowResponseSpec(
    id: 'offering-table-fed',
    flowKey: kOfferingTableFlowKey,
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.chips,
    label: 'What was fed?',
    options: <MaatFlowResponseOption>[
      MaatFlowResponseOption(
        id: 'water',
        label: 'Water',
        journalLabel: 'water',
      ),
      MaatFlowResponseOption(id: 'food', label: 'Food', journalLabel: 'food'),
      MaatFlowResponseOption(id: 'rest', label: 'Rest', journalLabel: 'rest'),
      MaatFlowResponseOption(id: 'care', label: 'Care', journalLabel: 'care'),
      MaatFlowResponseOption(
        id: 'household',
        label: 'Household',
        journalLabel: 'household',
      ),
      MaatFlowResponseOption(id: 'land', label: 'Land', journalLabel: 'land'),
      MaatFlowResponseOption(
        id: 'return',
        label: 'Return',
        journalLabel: 'return',
      ),
    ],
    journalPolicy: MaatFlowJournalPolicy.mirror,
    journalLabel: kOfferingTableTitle,
    journalGroupId: 'offering-table-provision',
    journalGroupLabel: kOfferingTableTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.offeringTable,
    journalRole: 'fed',
  ),
  MaatFlowResponseSpec(
    id: 'offering-table-provided',
    flowKey: kOfferingTableFlowKey,
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.multiline,
    label: 'What did you provide today?',
    journalPolicy: MaatFlowJournalPolicy.mirror,
    journalLabel: kOfferingTableTitle,
    journalGroupId: 'offering-table-provision',
    journalGroupLabel: kOfferingTableTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.offeringTable,
    journalRole: 'provided',
  ),
  MaatFlowResponseSpec(
    id: 'days-outside-receipt',
    flowKey: kDaysOutsideTheYearFlowKey,
    eventKey: 'event-0',
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.multiline,
    label: 'What receipt do you carry from this threshold?',
    journalPolicy: MaatFlowJournalPolicy.mirror,
    journalLabel: kDaysOutsideTheYearTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.daysOutsideReceipt,
  ),
  MaatFlowResponseSpec(
    id: 'days-outside-receipt',
    flowKey: kDaysOutsideTheYearFlowKey,
    eventKey: 'event-1',
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.multiline,
    label: 'What receipt do you carry from this threshold?',
    journalPolicy: MaatFlowJournalPolicy.mirror,
    journalLabel: kDaysOutsideTheYearTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.daysOutsideReceipt,
  ),
  MaatFlowResponseSpec(
    id: 'days-outside-receipt',
    flowKey: kDaysOutsideTheYearFlowKey,
    eventKey: 'event-2',
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.multiline,
    label: 'What receipt do you carry from this threshold?',
    journalPolicy: MaatFlowJournalPolicy.mirror,
    journalLabel: kDaysOutsideTheYearTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.daysOutsideReceipt,
  ),
  MaatFlowResponseSpec(
    id: 'days-outside-receipt',
    flowKey: kDaysOutsideTheYearFlowKey,
    eventKey: 'event-3',
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.multiline,
    label: 'What receipt do you carry from this threshold?',
    journalPolicy: MaatFlowJournalPolicy.mirror,
    journalLabel: kDaysOutsideTheYearTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.daysOutsideReceipt,
  ),
  MaatFlowResponseSpec(
    id: 'days-outside-receipt',
    flowKey: kDaysOutsideTheYearFlowKey,
    eventKey: 'event-4',
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.multiline,
    label: 'What receipt do you carry from this threshold?',
    journalPolicy: MaatFlowJournalPolicy.mirror,
    journalLabel: kDaysOutsideTheYearTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.daysOutsideReceipt,
  ),
  MaatFlowResponseSpec(
    id: 'days-outside-receipt',
    flowKey: kDaysOutsideTheYearFlowKey,
    eventKey: 'event-5',
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.multiline,
    label: 'What receipt do you carry from this threshold?',
    journalPolicy: MaatFlowJournalPolicy.mirror,
    journalLabel: kDaysOutsideTheYearTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.daysOutsideReceipt,
  ),
  MaatFlowResponseSpec(
    id: 'wep-ronpet-year-intention',
    flowKey: kDaysOutsideTheYearFlowKey,
    eventKey: 'event-6',
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.multiline,
    label: 'What intention opens the year?',
    journalPolicy: MaatFlowJournalPolicy.mirror,
    journalLabel: 'Wep Ronpet',
    journalFormatter: MaatFlowResponseJournalFormatter.wepRonpetOpening,
  ),
  MaatFlowResponseSpec(
    id: 'open-hand-given',
    flowKey: kTheOpenHandFlowKey,
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.chips,
    label: 'What was given?',
    options: <MaatFlowResponseOption>[
      MaatFlowResponseOption(id: 'time', label: 'Time', journalLabel: 'time'),
      MaatFlowResponseOption(id: 'food', label: 'Food', journalLabel: 'food'),
      MaatFlowResponseOption(
        id: 'money',
        label: 'Money',
        journalLabel: 'money',
      ),
      MaatFlowResponseOption(
        id: 'skill',
        label: 'Skill',
        journalLabel: 'skill',
      ),
      MaatFlowResponseOption(
        id: 'attention',
        label: 'Attention',
        journalLabel: 'attention',
      ),
      MaatFlowResponseOption(
        id: 'labor',
        label: 'Labor',
        journalLabel: 'labor',
      ),
      MaatFlowResponseOption(
        id: 'protection',
        label: 'Protection',
        journalLabel: 'protection',
      ),
      MaatFlowResponseOption(
        id: 'connection',
        label: 'Connection',
        journalLabel: 'connection',
      ),
    ],
    journalPolicy: MaatFlowJournalPolicy.offer,
    journalLabel: kTheOpenHandTitle,
    journalGroupId: 'open-hand-provision',
    journalGroupLabel: kTheOpenHandTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.openHandProvision,
    journalRole: 'given',
    privacyClass: 'outward_provision',
  ),
  MaatFlowResponseSpec(
    id: 'open-hand-moved',
    flowKey: kTheOpenHandFlowKey,
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.multiline,
    label: 'What moved through your hand?',
    journalPolicy: MaatFlowJournalPolicy.offer,
    journalLabel: kTheOpenHandTitle,
    journalGroupId: 'open-hand-provision',
    journalGroupLabel: kTheOpenHandTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.openHandProvision,
    journalRole: 'moved',
    privacyClass: 'outward_provision',
  ),
  MaatFlowResponseSpec(
    id: 'djed-stood-upright',
    flowKey: kTheDjedFlowKey,
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.chips,
    label: 'What needed to stand upright?',
    options: <MaatFlowResponseOption>[
      MaatFlowResponseOption(id: 'body', label: 'Body', journalLabel: 'body'),
      MaatFlowResponseOption(
        id: 'house',
        label: 'House',
        journalLabel: 'house',
      ),
      MaatFlowResponseOption(id: 'work', label: 'Work', journalLabel: 'work'),
      MaatFlowResponseOption(id: 'word', label: 'Word', journalLabel: 'word'),
      MaatFlowResponseOption(
        id: 'family',
        label: 'Family',
        journalLabel: 'family',
      ),
      MaatFlowResponseOption(
        id: 'boundary',
        label: 'Boundary',
        journalLabel: 'boundary',
      ),
      MaatFlowResponseOption(
        id: 'practice',
        label: 'Practice',
        journalLabel: 'practice',
      ),
      MaatFlowResponseOption(id: 'rest', label: 'Rest', journalLabel: 'rest'),
    ],
    journalPolicy: MaatFlowJournalPolicy.offer,
    journalLabel: kTheDjedTitle,
    journalGroupId: 'djed-restoration',
    journalGroupLabel: kTheDjedTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.djedRestoration,
    journalRole: 'stood',
    privacyClass: 'sensitive_structure',
  ),
  MaatFlowResponseSpec(
    id: 'djed-restored',
    flowKey: kTheDjedFlowKey,
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.multiline,
    label: 'What did you raise or restore?',
    journalPolicy: MaatFlowJournalPolicy.offer,
    journalLabel: kTheDjedTitle,
    journalGroupId: 'djed-restoration',
    journalGroupLabel: kTheDjedTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.djedRestoration,
    journalRole: 'restored',
    privacyClass: 'sensitive_structure',
  ),
  MaatFlowResponseSpec(
    id: 'tending-care-specific',
    flowKey: kTheTendingFlowKey,
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.chips,
    label: 'What care became specific?',
    options: <MaatFlowResponseOption>[
      MaatFlowResponseOption(id: 'seen', label: 'Seen', journalLabel: 'seen'),
      MaatFlowResponseOption(id: 'fed', label: 'Fed', journalLabel: 'fed'),
      MaatFlowResponseOption(
        id: 'called',
        label: 'Called',
        journalLabel: 'called',
      ),
      MaatFlowResponseOption(
        id: 'protected',
        label: 'Protected',
        journalLabel: 'protected',
      ),
      MaatFlowResponseOption(
        id: 'cleaned',
        label: 'Cleaned',
        journalLabel: 'cleaned',
      ),
      MaatFlowResponseOption(
        id: 'repaired',
        label: 'Repaired',
        journalLabel: 'repaired',
      ),
      MaatFlowResponseOption(
        id: 'rested',
        label: 'Rested',
        journalLabel: 'rested',
      ),
      MaatFlowResponseOption(
        id: 'returned',
        label: 'Returned',
        journalLabel: 'returned',
      ),
    ],
    journalPolicy: MaatFlowJournalPolicy.offer,
    journalLabel: kTheTendingTitle,
    journalGroupId: 'tending-care',
    journalGroupLabel: kTheTendingTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.tendingCare,
    journalRole: 'care',
    privacyClass: 'care_private',
    offerJournalInclusionDefault: false,
  ),
  MaatFlowResponseSpec(
    id: 'tending-act-completed',
    flowKey: kTheTendingFlowKey,
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.multiline,
    label: 'What tending act did you complete?',
    journalPolicy: MaatFlowJournalPolicy.offer,
    journalLabel: kTheTendingTitle,
    journalGroupId: 'tending-care',
    journalGroupLabel: kTheTendingTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.tendingCare,
    journalRole: 'act',
    privacyClass: 'care_private',
    offerJournalInclusionDefault: false,
  ),
  MaatFlowResponseSpec(
    id: 'kept-word-status',
    flowKey: kKeptWordFlowKey,
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.choice,
    label: 'What happened with the word?',
    options: <MaatFlowResponseOption>[
      MaatFlowResponseOption(id: 'kept', label: 'Kept', journalLabel: 'kept'),
      MaatFlowResponseOption(
        id: 'repaired',
        label: 'Repaired',
        journalLabel: 'repaired',
      ),
      MaatFlowResponseOption(
        id: 'renegotiated',
        label: 'Renegotiated',
        journalLabel: 'renegotiated',
      ),
      MaatFlowResponseOption(
        id: 'released',
        label: 'Released',
        journalLabel: 'released',
      ),
      MaatFlowResponseOption(
        id: 'still_in_process',
        label: 'Still in process',
        journalLabel: 'still in process',
      ),
    ],
    journalPolicy: MaatFlowJournalPolicy.offer,
    journalLabel: kKeptWordTitle,
    journalGroupId: 'kept-word-agreement',
    journalGroupLabel: kKeptWordTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.keptWordAgreement,
    journalRole: 'status',
    privacyClass: 'agreement_private',
    offerJournalInclusionDefault: false,
  ),
  MaatFlowResponseSpec(
    id: 'kept-word-remembered',
    flowKey: kKeptWordFlowKey,
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.multiline,
    label: 'What word, repair, or conversation needs to be remembered?',
    journalPolicy: MaatFlowJournalPolicy.offer,
    journalLabel: kKeptWordTitle,
    journalGroupId: 'kept-word-agreement',
    journalGroupLabel: kKeptWordTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.keptWordAgreement,
    journalRole: 'remembered',
    privacyClass: 'agreement_private',
    offerJournalInclusionDefault: false,
  ),
  MaatFlowResponseSpec(
    id: 'wag-remembered',
    flowKey: kTheWagFlowKey,
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.chips,
    label: 'What was remembered?',
    options: <MaatFlowResponseOption>[
      MaatFlowResponseOption(
        id: 'water',
        label: 'Water',
        journalLabel: 'water',
      ),
      MaatFlowResponseOption(
        id: 'bread',
        label: 'Bread',
        journalLabel: 'bread',
      ),
      MaatFlowResponseOption(id: 'name', label: 'Name', journalLabel: 'name'),
      MaatFlowResponseOption(
        id: 'story',
        label: 'Story',
        journalLabel: 'story',
      ),
      MaatFlowResponseOption(id: 'gift', label: 'Gift', journalLabel: 'gift'),
      MaatFlowResponseOption(
        id: 'vigil',
        label: 'Vigil',
        journalLabel: 'vigil',
      ),
      MaatFlowResponseOption(
        id: 'feast',
        label: 'Feast',
        journalLabel: 'feast',
      ),
      MaatFlowResponseOption(
        id: 'legacy',
        label: 'Legacy',
        journalLabel: 'legacy',
      ),
      MaatFlowResponseOption(
        id: 'table',
        label: 'Table',
        journalLabel: 'table',
      ),
      MaatFlowResponseOption(
        id: 'return',
        label: 'Return',
        journalLabel: 'return',
      ),
    ],
    journalPolicy: MaatFlowJournalPolicy.offer,
    journalLabel: kTheWagTitle,
    journalGroupId: 'wag-memory',
    journalGroupLabel: kTheWagTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.wagMemory,
    journalRole: 'remembered',
    privacyClass: 'ancestor_memory_private',
    offerJournalInclusionDefault: false,
  ),
  MaatFlowResponseSpec(
    id: 'wag-carried',
    flowKey: kTheWagFlowKey,
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.multiline,
    label: 'What gift, memory, or legacy did you carry?',
    journalPolicy: MaatFlowJournalPolicy.offer,
    journalLabel: kTheWagTitle,
    journalGroupId: 'wag-memory',
    journalGroupLabel: kTheWagTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.wagMemory,
    journalRole: 'carried',
    privacyClass: 'ancestor_memory_private',
    offerJournalInclusionDefault: false,
  ),
  MaatFlowResponseSpec(
    id: 'khat-body-asked',
    flowKey: kKhatFlowKey,
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.chips,
    label: 'What did the body ask for?',
    options: <MaatFlowResponseOption>[
      MaatFlowResponseOption(
        id: 'water',
        label: 'Water',
        journalLabel: 'water',
      ),
      MaatFlowResponseOption(id: 'food', label: 'Food', journalLabel: 'food'),
      MaatFlowResponseOption(
        id: 'washing',
        label: 'Washing',
        journalLabel: 'washing',
      ),
      MaatFlowResponseOption(id: 'rest', label: 'Rest', journalLabel: 'rest'),
      MaatFlowResponseOption(
        id: 'movement',
        label: 'Movement',
        journalLabel: 'movement',
      ),
      MaatFlowResponseOption(
        id: 'stillness',
        label: 'Stillness',
        journalLabel: 'stillness',
      ),
      MaatFlowResponseOption(
        id: 'breath',
        label: 'Breath',
        journalLabel: 'breath',
      ),
      MaatFlowResponseOption(id: 'care', label: 'Care', journalLabel: 'care'),
      MaatFlowResponseOption(
        id: 'sleep',
        label: 'Sleep',
        journalLabel: 'sleep',
      ),
      MaatFlowResponseOption(
        id: 'repair',
        label: 'Repair',
        journalLabel: 'repair',
      ),
    ],
    journalPolicy: MaatFlowJournalPolicy.offer,
    journalLabel: kKhatTitle,
    journalGroupId: 'khat-body-care',
    journalGroupLabel: kKhatTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.khatBodyCare,
    journalRole: 'asked',
    privacyClass: 'body_care_private',
    offerJournalInclusionDefault: false,
  ),
  MaatFlowResponseSpec(
    id: 'khat-care-given',
    flowKey: kKhatFlowKey,
    surface: MaatFlowResponseSurface.calendarSheet,
    kind: MaatFlowResponseKind.multiline,
    label: 'What care did you give the body?',
    journalPolicy: MaatFlowJournalPolicy.offer,
    journalLabel: kKhatTitle,
    journalGroupId: 'khat-body-care',
    journalGroupLabel: kKhatTitle,
    journalFormatter: MaatFlowResponseJournalFormatter.khatBodyCare,
    journalRole: 'care',
    privacyClass: 'body_care_private',
    offerJournalInclusionDefault: false,
  ),
];

class MaatFlowResponseResolver {
  const MaatFlowResponseResolver({this.specs = const <MaatFlowResponseSpec>[]});

  final List<MaatFlowResponseSpec> specs;

  List<MaatFlowResponseSpec> resolve({
    required String flowKey,
    required MaatFlowResponseSurface surface,
    String? eventKey,
    String? sittingKey,
  }) {
    final normalizedFlowKey = flowKey.trim();
    if (normalizedFlowKey.isEmpty || specs.isEmpty) {
      return const <MaatFlowResponseSpec>[];
    }

    final normalizedEventKey = eventKey?.trim();
    final normalizedSittingKey = sittingKey?.trim();
    return specs
        .where((spec) {
          if (spec.flowKey != normalizedFlowKey) return false;
          if (!spec.supportsSurface(surface)) return false;
          if (!_optionalKeyMatches(spec.eventKey, normalizedEventKey)) {
            return false;
          }
          if (!_optionalKeyMatches(spec.sittingKey, normalizedSittingKey)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  bool supports({
    required String flowKey,
    required MaatFlowResponseSurface surface,
    String? eventKey,
    String? sittingKey,
  }) {
    return resolve(
      flowKey: flowKey,
      surface: surface,
      eventKey: eventKey,
      sittingKey: sittingKey,
    ).isNotEmpty;
  }
}

const MaatFlowResponseResolver kDefaultMaatFlowResponseResolver =
    MaatFlowResponseResolver(specs: kPilotMaatFlowResponseSpecs);

List<MaatFlowResponseSpec> resolveMaatFlowResponseSpecs({
  required String flowKey,
  required MaatFlowResponseSurface surface,
  String? eventKey,
  String? sittingKey,
  MaatFlowResponseResolver resolver = kDefaultMaatFlowResponseResolver,
}) {
  return resolver.resolve(
    flowKey: flowKey,
    surface: surface,
    eventKey: eventKey,
    sittingKey: sittingKey,
  );
}

bool _optionalKeyMatches(String? specKey, String? requestedKey) {
  final normalizedSpecKey = specKey?.trim();
  if (normalizedSpecKey == null || normalizedSpecKey.isEmpty) return true;
  return normalizedSpecKey == requestedKey;
}
