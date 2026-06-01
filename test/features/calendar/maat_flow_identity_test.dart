import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/dawn_house_rite_flow.dart';
import 'package:mobile/features/calendar/maat_decan_flow.dart';
import 'package:mobile/features/calendar/maat_flow_identity.dart';
import 'package:mobile/features/calendar/moon_return_flow.dart';
import 'package:mobile/features/calendar/the_course_flow.dart';
import 'package:mobile/features/calendar/the_decan_watch_flow.dart';
import 'package:mobile/features/calendar/the_djed_flow.dart';
import 'package:mobile/features/calendar/the_kept_word_flow.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/the_open_hand_flow.dart';
import 'package:mobile/features/calendar/the_tending_flow.dart';
import 'package:mobile/features/calendar/the_wag_flow.dart';
import 'package:mobile/features/calendar/the_weighing_flow.dart';

void main() {
  group('resolveMaatFlowKind', () {
    test('resolves all registered flow keys from encoded flow notes', () {
      for (final kind in MaatFlowKind.values) {
        expect(
          resolveMaatFlowKind(
            flowNotes: 'mode=kemetic;ov=Example;maat=${kind.flowKey}',
          ),
          kind,
        );
      }
    });

    test('does not match partial maat tokens', () {
      expect(
        resolveMaatFlowKind(flowNotes: 'mode=kemetic;maat=the-wagons'),
        isNull,
      );
      expect(
        resolveMaatFlowKind(
          flowNotes: 'mode=kemetic;maat=the-days-outside-the-yearbook',
        ),
        isNull,
      );
    });

    test('resolves all registered flow keys from behavior payloads', () {
      for (final kind in MaatFlowKind.values) {
        expect(
          resolveMaatFlowKind(
            behaviorPayload: <String, dynamic>{'flow_key': kind.flowKey},
          ),
          kind,
        );
      }
    });

    test('resolves known behavior kind values', () {
      expect(
        resolveMaatFlowKind(
          behaviorPayload: const <String, dynamic>{
            'kind': 'maat_moon_return_full',
          },
        ),
        MaatFlowKind.moonReturn,
      );
      expect(
        resolveMaatFlowKind(
          behaviorPayload: const <String, dynamic>{
            'kind': 'maat_days_outside_year',
          },
        ),
        MaatFlowKind.daysOutsideTheYear,
      );
      expect(
        resolveMaatFlowKind(
          behaviorPayload: const <String, dynamic>{
            'kind': 'maat_open_hand_event',
          },
        ),
        MaatFlowKind.theOpenHand,
      );
      expect(
        resolveMaatFlowKind(
          behaviorPayload: const <String, dynamic>{
            'kind': 'maat_open_mouth_event',
          },
        ),
        MaatFlowKind.openMouth,
      );
      expect(
        resolveMaatFlowKind(
          behaviorPayload: const <String, dynamic>{
            'kind': 'maat_living_record_event',
          },
        ),
        MaatFlowKind.livingRecord,
      );
      expect(
        resolveMaatFlowKind(
          behaviorPayload: const <String, dynamic>{
            'kind': 'maat_het_heru_event',
          },
        ),
        MaatFlowKind.hetHeru,
      );
      expect(
        resolveMaatFlowKind(
          behaviorPayload: const <String, dynamic>{'kind': 'maat_shore_event'},
        ),
        MaatFlowKind.theShore,
      );
      expect(
        resolveMaatFlowKind(
          behaviorPayload: const <String, dynamic>{
            'kind': 'maat_living_text_event',
          },
        ),
        MaatFlowKind.livingText,
      );
      expect(
        resolveMaatFlowKind(
          behaviorPayload: const <String, dynamic>{
            'kind': 'maat_clearing_event',
          },
        ),
        MaatFlowKind.clearing,
      );
      expect(
        resolveMaatFlowKind(
          behaviorPayload: const <String, dynamic>{
            'kind': 'maat_wandering_event',
          },
        ),
        MaatFlowKind.wandering,
      );
      expect(
        resolveMaatFlowKind(
          behaviorPayload: const <String, dynamic>{'kind': 'maat_khat_event'},
        ),
        MaatFlowKind.khat,
      );
      expect(
        resolveMaatFlowKind(
          behaviorPayload: const <String, dynamic>{'kind': 'maat_oracle_event'},
        ),
        MaatFlowKind.oracle,
      );
    });

    test('resolves action ids for migrated Ma’at families', () {
      expect(
        resolveMaatFlowKind(actionId: 'the-moon-return-new-2026-05-27'),
        MaatFlowKind.moonReturn,
      );
      expect(
        resolveMaatFlowKind(actionId: 'the-wag-event-01'),
        MaatFlowKind.theWag,
      );
      expect(
        resolveMaatFlowKind(actionId: 'the-days-outside-year-event-03'),
        MaatFlowKind.daysOutsideTheYear,
      );
      expect(
        resolveMaatFlowKind(actionId: 'the-decan-watch-2026-05-27'),
        MaatFlowKind.decanWatch,
      );
      expect(
        resolveMaatFlowKind(actionId: 'the-open-hand-event-02'),
        MaatFlowKind.theOpenHand,
      );
      expect(
        resolveMaatFlowKind(actionId: 'the-djed-event-02'),
        MaatFlowKind.theDjed,
      );
      expect(
        resolveMaatFlowKind(actionId: 'the-fair-hearing-event-02'),
        MaatFlowKind.fairHearing,
      );
      expect(
        resolveMaatFlowKind(actionId: 'the-house-of-life-event-02'),
        MaatFlowKind.houseOfLife,
      );
      expect(
        resolveMaatFlowKind(actionId: 'the-boundary-stone-event-02'),
        MaatFlowKind.boundaryStone,
      );
      expect(
        resolveMaatFlowKind(actionId: 'hotep-event-02'),
        MaatFlowKind.hotep,
      );
      expect(
        resolveMaatFlowKind(actionId: 'the-open-mouth-event-02'),
        MaatFlowKind.openMouth,
      );
      expect(
        resolveMaatFlowKind(actionId: 'the-living-record-event-02'),
        MaatFlowKind.livingRecord,
      );
      expect(
        resolveMaatFlowKind(actionId: 'het-heru-event-02'),
        MaatFlowKind.hetHeru,
      );
      expect(
        resolveMaatFlowKind(actionId: 'the-shore-event-02'),
        MaatFlowKind.theShore,
      );
      expect(
        resolveMaatFlowKind(actionId: 'the-autobiography-event-02'),
        MaatFlowKind.theAutobiography,
      );
      expect(
        resolveMaatFlowKind(actionId: 'the-first-arrangement-event-02'),
        MaatFlowKind.firstArrangement,
      );
      expect(
        resolveMaatFlowKind(actionId: 'the-living-pattern-event-02'),
        MaatFlowKind.livingPattern,
      );
      expect(
        resolveMaatFlowKind(actionId: 'the-true-name-event-02'),
        MaatFlowKind.trueName,
      );
      expect(
        resolveMaatFlowKind(actionId: 'the-living-text-event-02'),
        MaatFlowKind.livingText,
      );
      expect(
        resolveMaatFlowKind(actionId: 'the-clearing-event-02'),
        MaatFlowKind.clearing,
      );
      expect(
        resolveMaatFlowKind(actionId: 'the-wandering-event-02'),
        MaatFlowKind.wandering,
      );
      expect(
        resolveMaatFlowKind(actionId: 'the-khat-event-02'),
        MaatFlowKind.khat,
      );
      expect(
        resolveMaatFlowKind(actionId: 'the-oracle-event-02'),
        MaatFlowKind.oracle,
      );
    });

    test('resolves legacy flow-name fallbacks exactly', () {
      expect(
        resolveMaatFlowKind(flowName: 'Follow the sky'),
        MaatFlowKind.trackSky,
      );
      expect(
        resolveMaatFlowKind(flowName: '  The Moon Return  '),
        MaatFlowKind.moonReturn,
      );
      expect(
        resolveMaatFlowKind(flowName: kFairHearingTitle),
        MaatFlowKind.fairHearing,
      );
      expect(
        resolveMaatFlowKind(flowName: kHouseOfLifeTitle),
        MaatFlowKind.houseOfLife,
      );
      expect(
        resolveMaatFlowKind(flowName: kBoundaryStoneTitle),
        MaatFlowKind.boundaryStone,
      );
      expect(resolveMaatFlowKind(flowName: kHotepTitle), MaatFlowKind.hotep);
      expect(
        resolveMaatFlowKind(flowName: kOpenMouthTitle),
        MaatFlowKind.openMouth,
      );
      expect(
        resolveMaatFlowKind(flowName: kLivingRecordTitle),
        MaatFlowKind.livingRecord,
      );
      expect(
        resolveMaatFlowKind(flowName: kHetHeruTitle),
        MaatFlowKind.hetHeru,
      );
      expect(
        resolveMaatFlowKind(flowName: kTheShoreTitle),
        MaatFlowKind.theShore,
      );
      expect(
        resolveMaatFlowKind(flowName: kTheAutobiographyTitle),
        MaatFlowKind.theAutobiography,
      );
      expect(
        resolveMaatFlowKind(flowName: kFirstArrangementTitle),
        MaatFlowKind.firstArrangement,
      );
      expect(
        resolveMaatFlowKind(flowName: kLivingPatternTitle),
        MaatFlowKind.livingPattern,
      );
      expect(
        resolveMaatFlowKind(flowName: kTrueNameTitle),
        MaatFlowKind.trueName,
      );
      expect(
        resolveMaatFlowKind(flowName: kLivingTextTitle),
        MaatFlowKind.livingText,
      );
      expect(
        resolveMaatFlowKind(flowName: kClearingTitle),
        MaatFlowKind.clearing,
      );
      expect(
        resolveMaatFlowKind(flowName: kWanderingTitle),
        MaatFlowKind.wandering,
      );
      expect(resolveMaatFlowKind(flowName: kKhatTitle), MaatFlowKind.khat);
      expect(resolveMaatFlowKind(flowName: kOracleTitle), MaatFlowKind.oracle);
      expect(resolveMaatFlowKind(flowName: 'The Moon Returned'), isNull);
    });
  });

  group('existing flow reference helpers', () {
    test('delegate identity decisions to the centralized resolver', () {
      expect(
        isMoonReturnFlowReference(
          flowNotes: 'mode=kemetic;maat=the-moon-return',
        ),
        isTrue,
      );
      expect(isWagFlowReference(actionId: 'the-wag-event-01'), isTrue);
      expect(
        isDecanWatchFlowReference(
          behaviorPayload: const <String, dynamic>{'kind': 'maat_decan_watch'},
        ),
        isTrue,
      );
      expect(
        isOpenHandFlowReference(flowNotes: 'mode=kemetic;maat=the-open-hand'),
        isTrue,
      );
      expect(isDjedFlowReference(actionId: 'the-djed-event-01'), isTrue);
    });

    test('preserve non-enrollment flow helpers', () {
      expect(
        isDawnHouseRiteFlowReference(actionId: 'dawn-house-rite-day-01'),
        isTrue,
      );
      expect(
        isTheWeighingFlowReference(actionId: 'the-weighing-event-01'),
        isTrue,
      );
      expect(
        isOfferingTableFlowReference(actionId: 'the-offering-table-day-01'),
        isTrue,
      );
      expect(
        isTheTendingFlowReference(actionId: 'the-tending-event-01'),
        isTrue,
      );
      expect(
        isKeptWordFlowReference(actionId: 'the-kept-word-event-01'),
        isTrue,
      );
      expect(isCourseFlowReference(actionId: 'the-course-event-01'), isTrue);
    });
  });
}
