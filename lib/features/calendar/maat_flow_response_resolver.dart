import 'maat_flow_response_models.dart';

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
    MaatFlowResponseResolver();

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
