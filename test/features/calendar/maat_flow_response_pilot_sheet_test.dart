import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/maat_flow_catalog.dart';
import 'package:mobile/features/calendar/maat_flow_identity.dart';
import 'package:mobile/features/calendar/maat_flow_response_resolver.dart';

void main() {
  test('archived flows expose no active response or authoring specs', () {
    for (final kind in kArchivedCompatibilityMaatFlowKinds) {
      expect(
        kPilotMaatFlowResponseSpecs.where(
          (spec) => spec.flowKey == kind.flowKey,
        ),
        isEmpty,
        reason: kind.flowKey,
      );
      expect(
        kInitialMaatFlowPromptSpecs.where(
          (spec) => spec.flowKey == kind.flowKey,
        ),
        isEmpty,
        reason: kind.flowKey,
      );
    }
  });
}
