import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/user_events_repo.dart';

void main() {
  group('filing-backed user event row helpers', () {
    test('uses filed_flow_id as the canonical flow owner', () {
      final row = <String, dynamic>{
        'flow_local_id': 12,
        'filed_flow_id': 34,
        'item_kind': 'flow',
      };

      expect(canonicalFiledFlowIdForEventRow(row), 34);
      expect(filingRowIsFlowCalendarEvent(row), isTrue);
      expect(filingRowIsStandaloneCalendarEvent(row), isFalse);
    });

    test('recognizes filed flow rows when raw flow_local_id is missing', () {
      final row = <String, dynamic>{
        'flow_local_id': null,
        'filed_flow_id': 99,
        'item_kind': 'flow',
      };

      expect(canonicalFiledFlowIdForEventRow(row), 99);
      expect(filingRowIsFlowCalendarEvent(row), isTrue);
    });

    test('keeps reminder rows in standalone calendar hydration', () {
      final row = <String, dynamic>{
        'flow_local_id': 7,
        'filed_flow_id': 7,
        'item_kind': 'reminder',
      };

      expect(canonicalFiledFlowIdForEventRow(row), 7);
      expect(filingRowIsStandaloneCalendarEvent(row), isTrue);
      expect(filingRowIsFlowCalendarEvent(row), isFalse);
    });

    test('keeps normal note rows standalone', () {
      final row = <String, dynamic>{
        'flow_local_id': null,
        'filed_flow_id': null,
        'item_kind': 'note',
      };

      expect(canonicalFiledFlowIdForEventRow(row), isNull);
      expect(filingRowIsStandaloneCalendarEvent(row), isTrue);
      expect(filingRowIsFlowCalendarEvent(row), isFalse);
    });
  });

  group('flow lineage origin types', () {
    test('saved imports are preserved by app and database allowlists', () {
      final repoSource = File(
        'lib/data/user_events_repo.dart',
      ).readAsStringSync();
      final savedImportSource = File(
        'lib/features/calendar/calendar_flow_pages.dart',
      ).readAsStringSync();
      final migrationSource = File(
        '../supabase/migrations/20260616120000_allow_saved_import_flow_origin.sql',
      ).readAsStringSync();

      final allowedOrigins = _sourceBetween(
        repoSource,
        'const allowedOriginTypes = {',
        '};',
      );

      expect(savedImportSource, contains("originType: 'saved_import'"));
      expect(allowedOrigins, contains("'saved_import'"));
      expect(migrationSource, contains("'saved_import'"));
      expect(migrationSource, contains('flows_origin_type_check'));
    });

    test('share import status lookup accepts route-backed lineage', () {
      final repoSource = File(
        'lib/data/user_events_repo.dart',
      ).readAsStringSync();
      final lookupBody = _sourceBetween(
        repoSource,
        'Future<int?> getFlowIdByShareId(String shareId) async {',
        "debugPrint('[UserEventsRepo] Error getting flow by share_id: \$e');",
      );

      expect(lookupBody, contains(".from('flows')"));
      expect(lookupBody, contains(".eq('user_id', user.id)"));
      expect(
        lookupBody,
        contains(".or('share_id.eq.\$shareId,origin_share_id.eq.\$shareId')"),
      );
      expect(lookupBody, contains(".order('active', ascending: false)"));
      expect(lookupBody, contains(".order('is_saved', ascending: false)"));
    });
  });
}

String _sourceBetween(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  expect(start, isNonNegative, reason: 'missing start marker: $startMarker');
  final end = source.indexOf(endMarker, start + startMarker.length);
  expect(end, isNonNegative, reason: 'missing end marker: $endMarker');
  return source.substring(start, end);
}
