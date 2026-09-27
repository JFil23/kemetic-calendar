import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/features/pages/pages_models.dart';
import 'package:mobile/features/pages/pages_sheet_graphic.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_day_instrument.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_day_presentation.dart';
import 'package:mobile/features/calendar/the_kar/presentation/kar_event_block_visual.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_day_presentation.dart';
import 'package:mobile/features/calendar/presentation/user_flow_appearance_visual.dart';

void main() {
  testWidgets('each flow uses its sheet renderer and selected occurrence', (
    tester,
  ) async {
    Future<void> render(String key, Map<String, dynamic> behavior) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 124,
            height: 125,
            child: PagesSheetGraphic(
              flow: PagesFlow(
                id: key,
                name: key,
                appearance: FlowAppearance(),
                maatKey: key,
                occurrence: PagesUpcomingEvent(
                  flowId: key,
                  title: 'Selected event',
                  at: DateTime(2026, 9, 27),
                  behavior: behavior,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsNothing);
    }

    await render('the-offering-table', {'day': 11});
    expect(
      tester
          .widget<OfferingTableDayInstrument>(
            find.byType(OfferingTableDayInstrument),
          )
          .contract
          .day,
      11,
    );
    await render('the-djed', {
      'kind': 'maat_djed_v2_event',
      'djed_schema_version': 2,
      'event_number': 4,
    });
    final djed = tester.widget<DjedSittingStage>(find.byType(DjedSittingStage));
    expect(djed.fixture.sittingNumber, 4);
    expect(djed.fixture.supportName, isEmpty);
    await render('the-kar', {'kar_stage_index': 3});
    expect(
      tester
          .widget<KarDayShrineVisual>(find.byType(KarDayShrineVisual))
          .currentStage,
      3,
    );
    await render('the-reading-house', {});
    expect(find.byType(ReadingHouseRoomEmblem), findsOneWidget);
    expect(find.text('Amina'), findsNothing);
    await render('custom', {});
    final custom = tester.widget<UserFlowAppearanceHero>(
      find.byType(UserFlowAppearanceHero),
    );
    expect(custom.surface, UserFlowAppearanceSurface.daySheet);
    expect(custom.allowImageFetch, isFalse);
    await render('the-offering-table', {});
    expect(find.byType(OfferingTableDayInstrument), findsNothing);
  });
}
