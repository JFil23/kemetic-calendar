import 'dart:convert';

import 'composition_models.dart';

const String kCompositionEngineVersion = 'composition_engine_v2';

class CompositionEngine {
  const CompositionEngine({
    required this.phraseBankVersion,
    required this.phrases,
    required this.intents,
    required this.shape,
    this.engineVersion = kCompositionEngineVersion,
  });

  final String engineVersion;
  final String phraseBankVersion;
  final List<CompositionPhrase> phrases;
  final List<CompositionIntent> intents;
  final CompositionShape shape;

  CompositionOutput? compose({
    required CompositionFactSnapshot facts,
    required List<CompositionUsageRecord> usageHistory,
    required DateTime generatedAt,
    CompositionClaimPlan? claimPlan,
  }) {
    if (facts.signals.contains('zero_data')) {
      return null;
    }

    final intent = _selectIntent(claimPlan);
    if (intent == null) return null;

    final selected = <CompositionPhrase>[];
    final fallbackLevels = <String, int>{};
    final trace = <String>['intent:${intent.id}'];
    for (final position in shape.positions) {
      final result = _selectPhraseForPosition(
        facts: facts,
        claimPlan: claimPlan,
        intent: intent,
        position: position,
        selectedPhraseIds: selected.map((phrase) => phrase.id).toSet(),
        usageHistory: usageHistory,
        generatedAt: generatedAt,
      );
      if (result == null) {
        trace.add('${position.wireName}:omitted');
        continue;
      }
      selected.add(result.phrase);
      fallbackLevels[position.wireName] = result.fallbackLevel;
      trace.add(
        '${position.wireName}:${result.phrase.id}:l${result.fallbackLevel}',
      );
    }

    if (selected.isEmpty) return null;

    final text = _cleanReflectionText(
      selected.map((phrase) => _renderPhraseText(phrase.text, facts)).join(' '),
    );
    if (text.isEmpty) return null;
    if (text.length > shape.maxLength) return null;

    return CompositionOutput(
      text: text,
      engineVersion: engineVersion,
      phraseBankVersion: phraseBankVersion,
      surface: facts.surface,
      intentId: intent.id,
      shapeId: shape.id,
      phraseIds: selected.map((phrase) => phrase.id).toList(growable: false),
      signals: facts.signals,
      fallbackLevelsUsed: fallbackLevels,
      factFingerprint: facts.factFingerprint,
      factSummary: facts.factSummary,
      recommendation: facts.recommendation,
      trace: trace,
      generatedAt: generatedAt,
    );
  }

  CompositionIntent? _selectIntent(CompositionClaimPlan? claimPlan) {
    if (claimPlan == null) return null;
    final claimIds = claimPlan.claimIds.toSet();
    final matches =
        intents.where((intent) {
          if (intent.reflectionShape != claimPlan.reflectionShape) {
            return false;
          }
          if (!claimIds.containsAll(intent.requiredClaims)) return false;
          if (intent.avoidClaims.any(claimIds.contains)) return false;
          return true;
        }).toList()..sort((a, b) {
          final byPriority = b.priority.compareTo(a.priority);
          if (byPriority != 0) return byPriority;
          return a.id.compareTo(b.id);
        });
    return matches.isEmpty ? null : matches.first;
  }

  _PhraseSelection? _selectPhraseForPosition({
    required CompositionFactSnapshot facts,
    required CompositionClaimPlan? claimPlan,
    required CompositionIntent intent,
    required CompositionPosition position,
    required Set<String> selectedPhraseIds,
    required List<CompositionUsageRecord> usageHistory,
    required DateTime generatedAt,
  }) {
    for (var level = 0; level <= 4; level++) {
      final candidates = phrases.where((phrase) {
        if (phrase.position != position) return false;
        if (selectedPhraseIds.contains(phrase.id)) return false;
        if (!_supportsEvidence(phrase, facts)) return false;
        if (!facts.signals.containsAll(phrase.requiresSignals)) return false;
        if (phrase.avoidSignals.any(facts.signals.contains)) return false;
        if (!_supportsClaims(phrase, claimPlan)) return false;

        final flowKey = phrase.optionalFlowKey?.trim();
        if (level == 0 &&
            flowKey != null &&
            flowKey.isNotEmpty &&
            flowKey != facts.dominantFlowKey) {
          return false;
        }
        if (level > 0 && flowKey != null && flowKey.isNotEmpty) {
          return false;
        }

        if (level <= 2 && !phrase.useCases.contains(intent.useCase)) {
          return false;
        }
        if (level == 4 &&
            !phrase.useCases.contains('generic') &&
            !phrase.useCases.contains(intent.useCase)) {
          return false;
        }
        if (level <= 1 && phrase.tone != intent.preferredTone) return false;
        if (level == 0 && phrase.energy != intent.energy) return false;
        return true;
      }).toList();

      if (candidates.isEmpty) continue;
      candidates.sort(
        (a, b) => _comparePhrases(
          a,
          b,
          facts: facts,
          intent: intent,
          position: position,
          usageHistory: usageHistory,
          generatedAt: generatedAt,
        ),
      );
      return _PhraseSelection(candidates.first, level);
    }
    return null;
  }

  bool _supportsClaims(
    CompositionPhrase phrase,
    CompositionClaimPlan? claimPlan,
  ) {
    final claimIds =
        claimPlan?.claimIds.toSet() ?? const <CompositionClaimId>{};
    if (!claimIds.containsAll(phrase.requiresClaims)) return false;
    if (phrase.avoidClaims.any(claimIds.contains)) return false;
    return true;
  }

  bool _supportsEvidence(
    CompositionPhrase phrase,
    CompositionFactSnapshot facts,
  ) {
    if (phrase.privacyClass == CompositionPrivacyClass.sensitiveBlocked) {
      return false;
    }
    if (facts.signals.contains('low_data') &&
        phrase.claimStrength != CompositionClaimStrength.low) {
      return false;
    }
    return facts.evidenceCount >= phrase.minimumEvidence;
  }

  int _comparePhrases(
    CompositionPhrase a,
    CompositionPhrase b, {
    required CompositionFactSnapshot facts,
    required CompositionIntent intent,
    required CompositionPosition position,
    required List<CompositionUsageRecord> usageHistory,
    required DateTime generatedAt,
  }) {
    final aPenalty = _usagePenalty(a, usageHistory, generatedAt);
    final bPenalty = _usagePenalty(b, usageHistory, generatedAt);
    if (aPenalty != bPenalty) return aPenalty.compareTo(bPenalty);

    final aExactFlow = _isExactFlowPhrase(a, facts);
    final bExactFlow = _isExactFlowPhrase(b, facts);
    if (aExactFlow != bExactFlow) return aExactFlow ? -1 : 1;

    final byWeight = b.weight.compareTo(a.weight);
    if (byWeight != 0) return byWeight;

    final seed = _stableCanonicalString(<String, Object?>{
      'fingerprint': facts.factFingerprint,
      'surface': facts.surface,
      'intent': intent.id,
      'position': position.wireName,
      'engine': engineVersion,
      'bank': phraseBankVersion,
      'date': _formatDate(generatedAt),
    });
    final aScore = stableCompositionScore('$seed|${a.id}');
    final bScore = stableCompositionScore('$seed|${b.id}');
    if (aScore != bScore) return aScore.compareTo(bScore);
    return a.id.compareTo(b.id);
  }

  bool _isExactFlowPhrase(
    CompositionPhrase phrase,
    CompositionFactSnapshot facts,
  ) {
    final flowKey = phrase.optionalFlowKey?.trim();
    if (flowKey == null || flowKey.isEmpty) return false;
    return flowKey == facts.dominantFlowKey;
  }

  int _usagePenalty(
    CompositionPhrase phrase,
    List<CompositionUsageRecord> usageHistory,
    DateTime generatedAt,
  ) {
    var penalty = 0;
    final cutoff = DateTime(
      generatedAt.year,
      generatedAt.month,
      generatedAt.day,
    ).subtract(const Duration(days: 90));
    for (final record in usageHistory) {
      if (record.date.isBefore(cutoff)) continue;
      if (record.surface != 'decan_reflection') continue;
      if (record.phraseId == phrase.id) penalty += 100;
      final cooldownGroup = phrase.cooldownGroup;
      if (cooldownGroup != null && record.cooldownGroup == cooldownGroup) {
        penalty += 30;
      }
    }
    return penalty;
  }
}

String stableCompositionFingerprint(Map<String, Object?> value) {
  return stableCompositionScore(
    _stableCanonicalString(value),
  ).toRadixString(16);
}

int stableCompositionScore(String value) {
  var hash = 0x811c9dc5;
  for (final unit in utf8.encode(value)) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

String _stableCanonicalString(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return jsonEncode(value);
  }
  if (value is DateTime) {
    return jsonEncode(_formatDate(value));
  }
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    final normalized = <String, Object?>{};
    for (final key in keys) {
      normalized[key] = value[key];
    }
    return '{${normalized.entries.map((entry) => '${jsonEncode(entry.key)}:${_stableCanonicalString(entry.value)}').join(',')}}';
  }
  if (value is Iterable) {
    return '[${value.map(_stableCanonicalString).join(',')}]';
  }
  return jsonEncode(value.toString());
}

String _cleanReflectionText(String text) {
  var cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'\s+([,.!?;:])'),
    (match) => match.group(1) ?? '',
  );
  if (cleaned.isEmpty) return '';
  final last = cleaned[cleaned.length - 1];
  if (!'.!?'.contains(last)) cleaned = '$cleaned.';
  return cleaned;
}

String _renderPhraseText(String text, CompositionFactSnapshot facts) {
  return text.replaceAllMapped(RegExp(r'\{([a-zA-Z0-9_]+)\}'), (match) {
    final key = match.group(1);
    if (key == null || key.isEmpty) return '';
    final value =
        facts.templateValues[key] ?? facts.facts[key] ?? facts.factSummary[key];
    return value?.toString().trim() ?? '';
  });
}

String _formatDate(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  final yyyy = local.year.toString().padLeft(4, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}

class _PhraseSelection {
  const _PhraseSelection(this.phrase, this.fallbackLevel);

  final CompositionPhrase phrase;
  final int fallbackLevel;
}
