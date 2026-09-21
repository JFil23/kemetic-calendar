import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_appearance.dart';

void main() {
  test('flow appearance round-trips the versioned user-flow contract', () {
    const appearance = FlowAppearance(
      imageObjectPath: 'owner/flow-image.webp',
      signKind: FlowSignKind.shen,
      signLabel: 'Return',
      accentArgb: 0xFF6F93A8,
    );

    final json = appearance.toJsonOrNull();

    expect(json, isNotNull);
    expect(json!['version'], FlowAppearance.schemaVersion);
    expect(FlowAppearance.fromJson(json), appearance);
  });

  test('missing appearance preserves the legacy no-visual state', () {
    expect(FlowAppearance.fromJson(null), FlowAppearance.empty);
    expect(FlowAppearance.fromJson(const <String, Object?>{}).isEmpty, isTrue);
    expect(const FlowAppearance(accentArgb: 0xFF6F93A8).isEmpty, isTrue);
    expect(FlowAppearance.empty.toJsonOrNull(), isNull);
    expect(const FlowAppearance(accentArgb: 0xFF6F93A8).toJsonOrNull(), isNull);
  });

  test(
    'repositories preserve appearance unless the caller owns that field',
    () {
      final userEventsRepo = File(
        'lib/data/user_events_repo.dart',
      ).readAsStringSync();
      final flowsRepo = File('lib/data/flows_repo.dart').readAsStringSync();

      expect(userEventsRepo, contains('FlowAppearance? appearance'));
      expect(
        userEventsRepo,
        contains("if (appearance != null) {\n      payload['appearance']"),
      );
      expect(flowsRepo, contains('FlowAppearance? appearance'));
      expect(flowsRepo, contains("if (appearance != null) 'appearance':"));
    },
  );
}
