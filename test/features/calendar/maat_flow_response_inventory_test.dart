import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/dawn_house_rite_flow.dart';
import 'package:mobile/features/calendar/evening_threshold_flow.dart';
import 'package:mobile/features/calendar/evening_threshold_rite_flow.dart';
import 'package:mobile/features/calendar/maat_decan_flow.dart';
import 'package:mobile/features/calendar/maat_flow_identity.dart';
import 'package:mobile/features/calendar/maat_flow_response_models.dart';
import 'package:mobile/features/calendar/maat_flow_response_resolver.dart';
import 'package:mobile/features/calendar/moon_return_flow.dart';
import 'package:mobile/features/calendar/the_course_flow.dart';
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

const String _trackSkyFlowKey = 'track-the-sky';
const String _trackSkyTitle = 'Follow the Sky';

class _InventoryFlow {
  const _InventoryFlow({
    required this.key,
    required this.title,
    required this.category,
    required this.phase,
  });

  final String key;
  final String title;
  final String category;
  final String phase;
}

// Phase 3H inventory lock:
// Response-enabled core/seasonal/ritual flows: 15
// Response-enabled decan flows: 17
// Remaining queued decan flows: 0
// Legacy custom flow excluded from response rollout: evening_threshold
const List<_InventoryFlow> _responseEnabledCoreFlows = <_InventoryFlow>[
  _InventoryFlow(
    key: _trackSkyFlowKey,
    title: _trackSkyTitle,
    category: 'response-enabled core',
    phase: 'Phase 3G',
  ),
  _InventoryFlow(
    key: kDawnHouseRiteFlowKey,
    title: kDawnHouseRiteTitle,
    category: 'response-enabled core',
    phase: 'Phase 2D',
  ),
  _InventoryFlow(
    key: kEveningThresholdRiteFlowKey,
    title: kEveningThresholdRiteTitle,
    category: 'response-enabled core',
    phase: 'Phase 2D',
  ),
  _InventoryFlow(
    key: kTheWeighingFlowKey,
    title: kTheWeighingTitle,
    category: 'response-enabled core',
    phase: 'Phase 3G',
  ),
  _InventoryFlow(
    key: kOfferingTableFlowKey,
    title: kOfferingTableTitle,
    category: 'response-enabled core',
    phase: 'Phase 3A',
  ),
  _InventoryFlow(
    key: kTheTendingFlowKey,
    title: kTheTendingTitle,
    category: 'response-enabled core',
    phase: 'Phase 3D',
  ),
  _InventoryFlow(
    key: kKeptWordFlowKey,
    title: kKeptWordTitle,
    category: 'response-enabled core',
    phase: 'Phase 3D',
  ),
  _InventoryFlow(
    key: kTheCourseFlowKey,
    title: kTheCourseTitle,
    category: 'response-enabled core',
    phase: 'Phase 2B',
  ),
  _InventoryFlow(
    key: kMoonReturnFlowKey,
    title: kMoonReturnTitle,
    category: 'response-enabled core',
    phase: 'Phase 2B',
  ),
  _InventoryFlow(
    key: kTheWagFlowKey,
    title: kTheWagTitle,
    category: 'response-enabled core',
    phase: 'Phase 3E',
  ),
  _InventoryFlow(
    key: kDecanWatchFlowKey,
    title: kDecanWatchTitle,
    category: 'response-enabled core',
    phase: 'Phase 2C',
  ),
  _InventoryFlow(
    key: kDaysOutsideTheYearFlowKey,
    title: kDaysOutsideTheYearTitle,
    category: 'response-enabled core',
    phase: 'Phase 3A',
  ),
  _InventoryFlow(
    key: kTheOpenHandFlowKey,
    title: kTheOpenHandTitle,
    category: 'response-enabled core',
    phase: 'Phase 3B',
  ),
  _InventoryFlow(
    key: kTheDjedFlowKey,
    title: kTheDjedTitle,
    category: 'response-enabled core',
    phase: 'Phase 3B',
  ),
  _InventoryFlow(
    key: kReadingHouseFlowKey,
    title: kReadingHouseTitle,
    category: 'response-enabled core',
    phase: 'Reading House Phase 3B',
  ),
];

const List<_InventoryFlow> _responseEnabledDecanFlows = <_InventoryFlow>[
  _InventoryFlow(
    key: kFirstArrangementFlowKey,
    title: kFirstArrangementTitle,
    category: 'response-enabled decan',
    phase: 'Phase 4A',
  ),
  _InventoryFlow(
    key: kLivingPatternFlowKey,
    title: kLivingPatternTitle,
    category: 'response-enabled decan',
    phase: 'Phase 4A',
  ),
  _InventoryFlow(
    key: kHouseOfLifeFlowKey,
    title: kHouseOfLifeTitle,
    category: 'response-enabled decan',
    phase: 'Phase 4A',
  ),
  _InventoryFlow(
    key: kHotepFlowKey,
    title: kHotepTitle,
    category: 'response-enabled decan',
    phase: 'Phase 4A',
  ),
  _InventoryFlow(
    key: kTheShoreFlowKey,
    title: kTheShoreTitle,
    category: 'response-enabled decan',
    phase: 'Phase 4B',
  ),
  _InventoryFlow(
    key: kLivingTextFlowKey,
    title: kLivingTextTitle,
    category: 'response-enabled decan',
    phase: 'Phase 4B',
  ),
  _InventoryFlow(
    key: kClearingFlowKey,
    title: kClearingTitle,
    category: 'response-enabled decan',
    phase: 'Phase 4B',
  ),
  _InventoryFlow(
    key: kHetHeruFlowKey,
    title: kHetHeruTitle,
    category: 'response-enabled decan',
    phase: 'Phase 4B',
  ),
  _InventoryFlow(
    key: kWanderingFlowKey,
    title: kWanderingTitle,
    category: 'response-enabled decan',
    phase: 'Phase 3F',
  ),
  _InventoryFlow(
    key: kKhatFlowKey,
    title: kKhatTitle,
    category: 'response-enabled decan',
    phase: 'Phase 3E',
  ),
  _InventoryFlow(
    key: kOracleFlowKey,
    title: kOracleTitle,
    category: 'response-enabled decan',
    phase: 'Phase 3F',
  ),
  _InventoryFlow(
    key: kFairHearingFlowKey,
    title: kFairHearingTitle,
    category: 'response-enabled decan',
    phase: 'Phase 4C',
  ),
  _InventoryFlow(
    key: kBoundaryStoneFlowKey,
    title: kBoundaryStoneTitle,
    category: 'response-enabled decan',
    phase: 'Phase 4C',
  ),
  _InventoryFlow(
    key: kOpenMouthFlowKey,
    title: kOpenMouthTitle,
    category: 'response-enabled decan',
    phase: 'Phase 4C',
  ),
  _InventoryFlow(
    key: kTheAutobiographyFlowKey,
    title: kTheAutobiographyTitle,
    category: 'response-enabled decan',
    phase: 'Phase 4D',
  ),
  _InventoryFlow(
    key: kTrueNameFlowKey,
    title: kTrueNameTitle,
    category: 'response-enabled decan',
    phase: 'Phase 4D',
  ),
  _InventoryFlow(
    key: kLivingRecordFlowKey,
    title: kLivingRecordTitle,
    category: 'response-enabled decan',
    phase: 'Phase 4D',
  ),
];

const List<_InventoryFlow> _remainingPrivacySensitiveDecanFlows =
    <_InventoryFlow>[];

const List<_InventoryFlow> _remainingLowerRiskDecanFlows = <_InventoryFlow>[];

void main() {
  group('Maat response flow inventory', () {
    test('registered Maat response inventory is fully accounted', () {
      final registeredTemplateKeys = MaatFlowKind.values
          .where((kind) => kind != MaatFlowKind.eveningThreshold)
          .map((kind) => kind.flowKey)
          .toSet();

      final inventoryKeys = _allInventoryFlows.map((flow) => flow.key).toSet();

      expect(registeredTemplateKeys, hasLength(32));
      expect(inventoryKeys, registeredTemplateKeys);
      expect(_allInventoryFlows, hasLength(32));
      expect(_responseEnabledCoreFlows, hasLength(15));
      expect(_responseEnabledDecanFlows, hasLength(17));
      expect(_remainingDecanFlows, isEmpty);
      expect(_remainingPrivacySensitiveDecanFlows, isEmpty);
      expect(_remainingLowerRiskDecanFlows, isEmpty);
      expect(_categoryCounts, <String, int>{
        'response-enabled core': 15,
        'response-enabled decan': 17,
      });
      expect(registeredTemplateKeys, isNot(contains(kEveningThresholdFlowKey)));
    });

    test('enabled inventory matches current response resolver coverage', () {
      final enabledInventoryKeys = _enabledInventoryFlows
          .map((flow) => flow.key)
          .toSet();
      final resolverEnabledKeys = kDefaultMaatFlowResponseResolver.specs
          .map((spec) => spec.flowKey)
          .toSet();

      expect(resolverEnabledKeys, enabledInventoryKeys);
      expect(resolverEnabledKeys, hasLength(32));

      for (final flow in _remainingDecanFlows) {
        expect(
          resolveMaatFlowResponseSpecs(
            flowKey: flow.key,
            surface: MaatFlowResponseSurface.calendarSheet,
          ),
          isEmpty,
          reason: '${flow.title} remains queued for ${flow.phase}.',
        );
      }
      expect(
        resolveMaatFlowResponseSpecs(
          flowKey: kEveningThresholdFlowKey,
          surface: MaatFlowResponseSurface.calendarSheet,
        ),
        isEmpty,
        reason: 'The original Evening Threshold remains custom-status-only.',
      );
    });

    test('remaining decan flows stay assigned to named expansion phases', () {
      expect(_phaseKeys('Phase 4A'), isEmpty);
      expect(_phaseKeys('Phase 4B'), isEmpty);
      expect(_phaseKeys('Phase 4C'), isEmpty);
      expect(_phaseKeys('Phase 4D'), isEmpty);
    });
  });
}

List<_InventoryFlow> get _enabledInventoryFlows => <_InventoryFlow>[
  ..._responseEnabledCoreFlows,
  ..._responseEnabledDecanFlows,
];

List<_InventoryFlow> get _remainingDecanFlows => <_InventoryFlow>[
  ..._remainingPrivacySensitiveDecanFlows,
  ..._remainingLowerRiskDecanFlows,
];

List<_InventoryFlow> get _allInventoryFlows => <_InventoryFlow>[
  ..._enabledInventoryFlows,
  ..._remainingDecanFlows,
];

List<String> _phaseKeys(String phase) {
  return _remainingDecanFlows
      .where((flow) => flow.phase == phase)
      .map((flow) => flow.key)
      .toList(growable: false);
}

Map<String, int> get _categoryCounts {
  final counts = <String, int>{};
  for (final flow in _allInventoryFlows) {
    counts.update(flow.category, (value) => value + 1, ifAbsent: () => 1);
  }
  return counts;
}
