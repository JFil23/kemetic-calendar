import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String calendarPage;
  late String compositionEngine;
  late String decanReflectionRepo;
  late String decanReflectionComposer;
  late String decanReflectionPhraseBank;
  late String maatFlowFactCollector;
  late String maatFlowCrossFlowAnalyzer;
  late String maatFlowProfileCatalog;

  setUpAll(() {
    calendarPage = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    compositionEngine = File(
      'lib/core/composition/composition_engine.dart',
    ).readAsStringSync();
    decanReflectionRepo = File(
      'lib/data/decan_reflection_repo.dart',
    ).readAsStringSync();
    decanReflectionComposer = File(
      'lib/features/calendar/decan_reflection_composition/decan_reflection_composer.dart',
    ).readAsStringSync();
    decanReflectionPhraseBank = File(
      'lib/features/calendar/decan_reflection_composition/decan_reflection_phrase_bank.dart',
    ).readAsStringSync();
    maatFlowFactCollector = File(
      'lib/features/calendar/decan_reflection_composition/maat_flow_decan_fact_collector.dart',
    ).readAsStringSync();
    maatFlowCrossFlowAnalyzer = File(
      'lib/features/calendar/decan_reflection_composition/maat_flow_cross_flow_analyzer.dart',
    ).readAsStringSync();
    maatFlowProfileCatalog = File(
      'lib/features/calendar/decan_reflection_composition/maat_flow_profile_catalog.dart',
    ).readAsStringSync();
  });

  test('end-of-decan prompt generation is compositional and non-LLM', () {
    final loader = _sourceBetween(
      calendarPage,
      '  Future<void> _maybeLoadDecanReflectionPrompt({bool force = false}) async {',
      '  Future<void> _archiveReflectionPrompt([BuildContext? ctx]) async {',
    );

    expect(loader, contains('_maatFlowDecanFactCollector.collect('));
    expect(loader, contains('_decanReflectionComposer.compose('));
    expect(loader, contains('kDecanReflectionCompositionalRenderer'));
    expect(loader, contains("'used_llm': false"));
    expect(loader, isNot(contains('AIReflectionService')));
    expect(loader, isNot(contains('generateReflection(')));
    expect(loader, isNot(contains('_collectDecanBadges(')));
    expect(loader, isNot(contains('_buildReflectionFromBadges(')));
  });

  test('interacted prompts are frozen before saved or fresh prompts load', () {
    final loader = _sourceBetween(
      calendarPage,
      '  Future<void> _maybeLoadDecanReflectionPrompt({bool force = false}) async {',
      '  Future<void> _archiveReflectionPrompt([BuildContext? ctx]) async {',
    );

    final interactionGate = loader.indexOf(
      '_hasInteractedWithReflectionPrompt(window.start)',
    );
    final savedLookup = loader.indexOf('_decanReflectionRepo.findByWindow(');
    final freshFactCollection = loader.indexOf(
      '_maatFlowDecanFactCollector.collect(',
    );

    expect(interactionGate, isNonNegative);
    expect(savedLookup, isNonNegative);
    expect(freshFactCollection, isNonNegative);
    expect(interactionGate, lessThan(savedLookup));
    expect(interactionGate, lessThan(freshFactCollection));
  });

  test('CalendarPage no longer owns the AI reflection service', () {
    expect(
      calendarPage,
      isNot(contains("services/ai_reflection_service.dart")),
    );
    expect(calendarPage, isNot(contains('_aiReflectionService')));
  });

  test('recommendation routing consumes the claim plan, not raw signals', () {
    final compose = _sourceBetween(
      decanReflectionComposer,
      '  DecanReflectionComposition? compose({',
      '  static DecanReflectionRenderMetadata renderMetadataForOutput(',
    );
    final policy = _sourceBetween(
      decanReflectionComposer,
      '  static CompositionRecommendation _recommendationForClaimPlan(',
      '  static CompositionClaim? _claimById(',
    );

    expect(compose, contains('claimDeriver.derive(facts)'));
    expect(compose, contains('_withRecommendation(facts, claimPlan)'));
    expect(policy, contains('CompositionClaimPlan claimPlan'));
    expect(policy, contains('CompositionClaimId.supportBeforeExpansion'));
    expect(policy, contains('CompositionClaimId.librarySupportRecommended'));
    expect(policy, contains('CompositionClaimId.flowReady'));
    expect(policy, contains('CompositionClaimId.steadyPresence'));
    expect(policy, contains('CompositionClaimId.breadthNeedsCenter'));
    expect(policy, contains('CompositionClaimId.singleFlowDepth'));
    expect(policy, contains('CompositionClaimId.zeroEvidence'));
    expect(policy, isNot(contains('facts.signals.contains')));
    expect(policy, isNot(contains("'mostly_partial'")));
    expect(policy, isNot(contains("'many_skips'")));
    expect(policy, isNot(contains("'low_follow_through'")));
    expect(policy, isNot(contains("'broad_flow_spread'")));
    expect(policy, isNot(contains("'single_flow_depth'")));
  });

  test('phrase selection is claim-aware without removing signal guards', () {
    final compose = _sourceBetween(
      decanReflectionComposer,
      '  DecanReflectionComposition? compose({',
      '  static DecanReflectionRenderMetadata renderMetadataForOutput(',
    );
    final selection = _sourceBetween(
      compositionEngine,
      '  _PhraseSelection? _selectPhraseForPosition({',
      '  bool _supportsClaims(',
    );

    expect(compose, contains('claimPlan: claimPlan'));
    expect(selection, contains('if (!_supportsClaims(phrase, claimPlan))'));
    expect(decanReflectionPhraseBank, contains('requiresClaims:'));
    expect(decanReflectionPhraseBank, contains('requiresSignals:'));
    expect(decanReflectionPhraseBank, contains("'recommend_library'"));
    expect(decanReflectionPhraseBank, contains("'recommend_flow'"));
  });

  test('intent selection derives from claim shape instead of raw signals', () {
    final intentSelection = _sourceBetween(
      compositionEngine,
      '  CompositionIntent? _selectIntent(CompositionClaimPlan? claimPlan) {',
      '  _PhraseSelection? _selectPhraseForPosition({',
    );

    expect(intentSelection, contains('claimPlan.reflectionShape'));
    expect(intentSelection, contains('intent.requiredClaims'));
    expect(intentSelection, contains('intent.avoidClaims'));
    expect(intentSelection, isNot(contains('facts.signals')));
    expect(intentSelection, isNot(contains('intent.requiredSignals')));
    expect(intentSelection, isNot(contains('intent.avoidSignals')));
    expect(decanReflectionPhraseBank, contains('requiredSignals:'));
  });

  test('archived compositional generation preserves raw claim provenance', () {
    final saver = _sourceBetween(
      decanReflectionRepo,
      '  Future<void> saveCompositionalGeneration({',
      '  String _friendlyReadError(Object error) {',
    );

    expect(saver, contains('...renderMetadata.raw'));
    expect(saver, contains("'source_snapshot': sourceSnapshot"));
    expect(saver, contains("'metadata': renderMetadata.raw"));
    expect(saver, contains("'generated_text': reflection.reflectionText"));
  });

  test('cross-flow inference uses static catalog without live copy or LLM', () {
    final combined =
        '$maatFlowFactCollector\n$maatFlowCrossFlowAnalyzer\n$maatFlowProfileCatalog';

    expect(maatFlowFactCollector, contains('MaatFlowCrossFlowAnalyzer'));
    expect(combined, isNot(contains('calendar_page.dart')));
    expect(combined, isNot(contains('maat_decan_flow.dart')));
    expect(combined, isNot(contains('_flow.dart')));
    expect(combined, isNot(contains('AIReflectionService')));
    expect(combined, isNot(contains('generateReflection(')));
    expect(combined, isNot(contains('rootBundle')));
  });
}

String _sourceBetween(String source, String startNeedle, String endNeedle) {
  final start = source.indexOf(startNeedle);
  expect(start, isNonNegative, reason: startNeedle);
  final end = source.indexOf(endNeedle, start + startNeedle.length);
  expect(end, isNonNegative, reason: endNeedle);
  return source.substring(start, end);
}
