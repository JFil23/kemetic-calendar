import 'maat_flow_response_models.dart';

class MaatFlowResponseDraftStore {
  MaatFlowResponseDraftStore();

  final Map<String, Map<String, MaatFlowResponseValue>> _valuesByFlowKey =
      <String, Map<String, MaatFlowResponseValue>>{};

  Map<String, MaatFlowResponseValue> valuesForFlow(String flowKey) {
    final normalizedFlowKey = flowKey.trim();
    if (normalizedFlowKey.isEmpty) {
      return const <String, MaatFlowResponseValue>{};
    }
    final values = _valuesByFlowKey[normalizedFlowKey];
    if (values == null || values.isEmpty) {
      return const <String, MaatFlowResponseValue>{};
    }
    return Map<String, MaatFlowResponseValue>.unmodifiable(values);
  }

  Map<String, MaatFlowResponseValue> valuesForSpecs(
    List<MaatFlowResponseSpec> specs,
  ) {
    if (specs.isEmpty) {
      return const <String, MaatFlowResponseValue>{};
    }
    final values = valuesForFlow(specs.first.flowKey);
    if (values.isEmpty) {
      return const <String, MaatFlowResponseValue>{};
    }
    final specIds = specs.map((spec) => spec.id).toSet();
    return Map<String, MaatFlowResponseValue>.unmodifiable(
      Map<String, MaatFlowResponseValue>.from(values)
        ..removeWhere((specId, _) => !specIds.contains(specId)),
    );
  }

  Map<String, MaatFlowResponseValue> mergeValuesForSpecs({
    required List<MaatFlowResponseSpec> specs,
    required Map<String, MaatFlowResponseValue> baseValues,
  }) {
    final draftValues = valuesForSpecs(specs);
    if (draftValues.isEmpty) {
      return Map<String, MaatFlowResponseValue>.unmodifiable(baseValues);
    }
    return Map<String, MaatFlowResponseValue>.unmodifiable(
      <String, MaatFlowResponseValue>{...baseValues, ...draftValues},
    );
  }

  void rememberValue({
    required String flowKey,
    required MaatFlowResponseValue value,
  }) {
    final normalizedFlowKey = flowKey.trim();
    if (normalizedFlowKey.isEmpty) return;
    final values = _valuesByFlowKey.putIfAbsent(
      normalizedFlowKey,
      () => <String, MaatFlowResponseValue>{},
    );
    if (value.isEmpty) {
      values.remove(value.specId);
    } else {
      values[value.specId] = value;
    }
    if (values.isEmpty) {
      _valuesByFlowKey.remove(normalizedFlowKey);
    }
  }

  void rememberValues({
    required String flowKey,
    required Map<String, MaatFlowResponseValue> values,
  }) {
    for (final value in values.values) {
      rememberValue(flowKey: flowKey, value: value);
    }
  }

  void clearForTesting() {
    _valuesByFlowKey.clear();
  }
}

final MaatFlowResponseDraftStore kMaatFlowResponseDraftStore =
    MaatFlowResponseDraftStore();
