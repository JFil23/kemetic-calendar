import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'anon-key-0123456789012345678901234567890123456789',
      );
    }
  });

  test(
    'calendar, detached, and canonical builders share one composition resolver',
    () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final calendarStart = source.indexOf(
        'Widget _buildMaatFlowDetailSurface(',
      );
      final detachedStart = source.indexOf(
        'static Widget _buildDetachedMaatFlowDetailSurface(',
      );
      final canonicalStart = source.indexOf(
        'static Widget? buildCanonicalMaatFlowDetail(',
      );
      expect(calendarStart, isNonNegative);
      expect(detachedStart, isNonNegative);
      expect(canonicalStart, isNonNegative);

      final calendarBody = source.substring(
        calendarStart,
        source.indexOf(
          'Map<String, Object?> _calendarSheetTraceState',
          calendarStart,
        ),
      );
      final detachedBody = source.substring(
        detachedStart,
        source.indexOf(
          'static Future<void> _completeDetachedMaatJoinWithDayView',
          detachedStart,
        ),
      );
      final canonicalBody = source.substring(
        canonicalStart,
        source.indexOf(
          'static ArchivedMaatFlowFixture _archivedMaatFlowFixtureFromSnapshot',
          canonicalStart,
        ),
      );
      expect(calendarBody, contains('resolveMaatFlowDetailComposition('));
      expect(calendarBody, contains('MaatFlowDetailRelation.owned'));
      expect(detachedBody, contains('resolveMaatFlowDetailComposition('));
      expect(detachedBody, contains('MaatFlowDetailRelation.owned'));
      expect(canonicalBody, contains('resolveMaatFlowDetailComposition('));
      expect(canonicalBody, contains('intendedInstance: intended'));
      expect(
        canonicalBody,
        isNot(contains('_activeFlowForMaatTemplate(')),
      );
      expect(
        File(
          'lib/features/calendar/the_djed/presentation/djed_detail_page.dart',
        ).readAsStringSync(),
        contains('CalendarPage.makeTodoFromOwnedDjedSitting('),
      );
    },
  );

  test('inbox invitation adapter does not look up a personal instance', () {
    final source = File(
      'lib/features/inbox/shared_flow_details_page.dart',
    ).readAsStringSync();
    expect(source, contains('MaatFlowDetailRelation.invited'));
    expect(source, contains('MaatFlowDetailRelation.owned'));
    expect(source, contains('intendedFlowId: data.flowId'));
    expect(source, isNot(contains('_activeFlowForMaatTemplate')));
  });

  testWidgets('invited Djed does not offer personal carry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarPage.buildCanonicalMaatFlowDetail(
          name: 'The Djed',
          notes: 'maat=the-djed',
          relation: MaatFlowDetailRelation.invited,
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(DjedDetailSurface), findsOneWidget);
    final carry = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey<String>('djed-carry')),
    );
    expect(carry.onPressed, isNull);
  });

  testWidgets('owned canonical Djed uses the intended instance, not a lookup', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarPage.buildCanonicalMaatFlowDetail(
          name: 'The Djed',
          notes: 'maat=the-djed',
          relation: MaatFlowDetailRelation.owned,
          intendedFlowId: 42,
          intendedStart: DateTime(2026, 9, 6),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('djed-carried')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('djed-carry')), findsNothing);
  });
}
