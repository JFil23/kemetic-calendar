import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/user_events_repo.dart';
import 'package:mobile/features/calendar/flow_detail_event_focus.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_detail_page.dart';
import 'package:mobile/features/calendar/the_kar/the_kar.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_detail_page.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_preview_day_sheet.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_detail_page.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_sitting_editor.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

FlowEventRow occurrence(Map<String, dynamic> payload) => (
  id: 'selected-row',
  clientEventId: 'selected-occurrence',
  calendarId: null,
  calendarName: null,
  calendarColor: null,
  calendarIsPersonal: true,
  title: 'Selected event',
  detail: null,
  location: null,
  allDay: true,
  startsAtUtc: DateTime.utc(2026, 9, 9),
  endsAtUtc: null,
  flowLocalId: 42,
  category: null,
  actionId: null,
  behaviorPayload: payload,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    for (final name in ['messages', 'events']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('com.llfbandit.app_links/$name'),
            (_) async => null,
          );
    }
    await Supabase.initialize(
      url: 'https://example.supabase.test',
      anonKey: 'fixture',
    );
    await loadMaatFlowVisualTestFonts();
  });
  tearDownAll(() => Supabase.instance.dispose());

  Future<void> pumpFocused(
    WidgetTester tester,
    Widget detail,
    Map<String, dynamic> payload,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: FlowDetailEventFocus(event: occurrence(payload), child: detail),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('focus opens Djed sitting in its existing full detail', (
    tester,
  ) async {
    await pumpFocused(
      tester,
      DjedDetailSurface(startDate: DateTime(2026, 9, 9)),
      {'event_number': 3},
    );
    expect(find.byType(DjedDetailSurface), findsOneWidget);
    expect(
      find.byKey(const ValueKey('djed-detail-sitting-sheet-3')),
      findsOneWidget,
    );
    Navigator.of(
      tester.element(find.byKey(const ValueKey('djed-detail-sitting-sheet-3'))),
    ).pop();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('djed-detail-sitting-sheet-3')),
      findsNothing,
    );
  });

  testWidgets('focus opens Offering Table day in its existing full detail', (
    tester,
  ) async {
    await pumpFocused(
      tester,
      OfferingTableDetailSurface(
        timezone: TrackSkyTimeZone.pacific,
        initialStartDate: DateTime(2026, 9, 9),
        onJoin:
            ({
              required startDate,
              required timezone,
              required lens,
              required noCupMode,
            }) async => 42,
      ),
      {'day': 2},
    );
    expect(find.byType(OfferingTableDetailSurface), findsOneWidget);
    expect(
      tester
          .widget<OfferingTablePreviewDaySheet>(
            find.byType(OfferingTablePreviewDaySheet),
          )
          .occurrence
          .day
          .dayNumber,
      2,
    );
    expect(
      find.byKey(const ValueKey('offering-table-preview-sheet-host')),
      findsOneWidget,
    );
  });

  testWidgets('focus opens Reading House sitting using its existing action', (
    tester,
  ) async {
    await pumpFocused(
      tester,
      ReadingHouseDetailSurface(
        timezone: TrackSkyTimeZone.pacific,
        initialStartDate: DateTime(2026, 9, 9),
      ),
      {'event_number': 3},
    );
    expect(find.byType(ReadingHouseDetailSurface), findsOneWidget);
    expect(
      tester
          .widget<ReadingHouseSittingEditorSheet>(
            find.byType(ReadingHouseSittingEditorSheet),
          )
          .sitting
          .eventNumber,
      3,
    );
  });

  testWidgets(
    'focus opens the selected sky turning in its existing full detail',
    (tester) async {
      final catalog = SkyCatalogRepository.parseJsonString(
        File(
          'assets/follow_the_sky/sky_catalog_v2_graphics_v1.json',
        ).readAsStringSync(),
      );
      final now = DateTime.utc(2026, 8, 24, 12);
      final night = catalog.upcomingNights(nowUtc: now)[4];
      await pumpFocused(
        tester,
        FollowSkyDetailSurface(initialCatalog: catalog, now: now),
        TrackSkyEventOwnership.behaviorPayload(skyEventId: night.skyEventId),
      );
      expect(find.byType(FollowSkyDetailSurface), findsOneWidget);
      expect(
        find.byKey(const ValueKey('follow-sky-turning-intention')),
        findsOneWidget,
      );
      expect(find.text(night.displayName).hitTestable(), findsWidgets);
    },
  );

  testWidgets(
    'focus waits for the Kar repository then opens the exact cycle stage',
    (tester) async {
      final shrine =
          KarShrine(
            id: 'kar-user-djehuty',
            netjer: KarNetjer.djehuty,
            revision: 0,
            cycles: const [],
          ).beginCycle(
            cycleId: 'cycle-1',
            anchorDate: DateTime(2026, 9, 9),
            flowId: 42,
          );
      await pumpFocused(
        tester,
        KarDetailSurface(
          repository: MemoryKarRepository(initial: {KarNetjer.djehuty: shrine}),
          clock: () => DateTime(2026, 9, 9),
          onJoin:
              ({
                required netjer,
                required cycleId,
                required cycleSequence,
                required startDate,
              }) async => 42,
        ),
        {'kar_cycle_id': 'cycle-1', 'kar_stage_index': 2},
      );
      expect(find.byType(KarDetailSurface), findsOneWidget);
      final behavior = tester.widget<KarDetailSittingBehaviorSurface>(
        find.byType(KarDetailSittingBehaviorSurface),
      );
      expect(behavior.stageIndex, 2);
    },
  );
}
