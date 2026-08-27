import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared template join policy runs before calendar lookup or writes', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final method = _slice(
      source,
      'static Future<int> _addMaatFlowInstanceHeadless({',
      'static Future<int> _addMaatFlowInstanceHeadlessWithCompletion({',
    );

    expect(
      method.indexOf('isMaatFlowNewJoinAllowed(template.key)'),
      lessThan(method.indexOf('_loadHeadlessPersonalCalendarId()')),
    );
    expect(
      method.indexOf('isMaatFlowNewJoinAllowed(template.key)'),
      lessThan(method.indexOf('FlowJoinService()')),
    );
  });

  test('universal shared and AI imports gate before the first flow write', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final method = _slice(
      source,
      'static Future<({int flowId, bool didStageEvents})?> '
          'importFlowFromShare(',
      'static Future<({int flowId, bool didStageEvents})?>\n  '
          'importGeneratedFlowFromAnyContext(',
    );

    _expectGateBeforeWrite(method);
  });

  test('saved-flow activation gates before creating the active copy', () {
    final source = File(
      'lib/features/calendar/calendar_flow_pages.dart',
    ).readAsStringSync();
    final method = _slice(
      source,
      'Future<({int flowId, bool didStageEvents})> _importSavedFlow(',
      'Future<void> _handleImportSaved(',
    );

    _expectGateBeforeWrite(method);
  });

  test('inbox direct import gates before creating a new flow', () {
    final source = File('lib/repositories/inbox_repo.dart').readAsStringSync();
    final method = _slice(
      source,
      'Future<int> importSharedFlow({',
      'Future<void> _scheduleImportedFlow(',
    );

    _expectGateBeforeWrite(method);
    expect(
      method.indexOf('if (existingFlowId != null)'),
      lessThan(method.indexOf('ensureNewFlowCreationAllowedByMaatCatalog(')),
      reason: 'Already-owned flows remain manageable.',
    );
  });

  test('profile save gates before creating a new saved template', () {
    final source = File('lib/data/profile_repo.dart').readAsStringSync();
    final method = _slice(
      source,
      'Future<int?> saveFlowPostToMyFlows(',
      'Future<void> _copyFlowPostEvents(',
    );

    _expectGateBeforeWrite(method);
    expect(
      method.indexOf('if (existingFlowId != null)'),
      lessThan(method.indexOf('ensureNewFlowCreationAllowedByMaatCatalog(')),
      reason: 'Already-owned saved flows remain openable.',
    );
  });

  test('accepted flow invite gates only new copies before upsert', () {
    final source = File('lib/data/share_repo.dart').readAsStringSync();
    final method = _slice(
      source,
      'Future<void> _upsertImportedFlowFromInvite({',
      'int? _sourceFlowIdFromPayload(',
    );

    _expectGateBeforeWrite(method);
    expect(method, contains('if (existingFlowId == null)'));
  });
}

void _expectGateBeforeWrite(String method) {
  final gate = method.indexOf('ensureNewFlowCreationAllowedByMaatCatalog(');
  final write = method.indexOf('upsertFlow(');
  expect(gate, greaterThanOrEqualTo(0));
  expect(write, greaterThanOrEqualTo(0));
  expect(gate, lessThan(write));
}

String _slice(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker, start + startMarker.length);
  expect(start, greaterThanOrEqualTo(0), reason: startMarker);
  expect(end, greaterThan(start), reason: endMarker);
  return source.substring(start, end);
}
