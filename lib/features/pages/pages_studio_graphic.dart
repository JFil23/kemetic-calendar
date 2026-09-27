import 'package:flutter/material.dart';
import '../../core/completion_status.dart';
import '../calendar/day_view.dart' show djedV2SupportFixtures;
import '../calendar/follow_the_sky/presentation/follow_sky_observation_presentation_model.dart';
import '../calendar/follow_the_sky/presentation/widgets/follow_sky_observation_presentation.dart';
import '../calendar/the_offering_table/presentation/offering_table_day_contract.dart';
import '../calendar/the_offering_table/presentation/offering_table_day_instrument.dart';
import '../calendar/the_offering_table/presentation/offering_table_day_state.dart';
import '../calendar/the_djed_v2_flow.dart';
import '../calendar/the_djed/presentation/djed_day_presentation.dart';
import '../calendar/the_djed/presentation/djed_sitting_behavior_surface.dart';
import '../calendar/the_kar/the_kar_flow.dart';
import '../calendar/the_kar/the_kar_models.dart';
import '../calendar/the_kar/presentation/kar_day_behavior_surface.dart';
import '../calendar/the_reading_house/reading_house_room_repository.dart';
import '../calendar/the_reading_house/reading_house_room_controller.dart';
import '../calendar/the_reading_house/presentation/reading_house_day_presentation.dart';
import '../calendar/the_reading_house/presentation/reading_house_day_behavior_surface.dart';
import '../calendar/presentation/user_flow_appearance_visual.dart';
import 'pages_arrangement.dart';
import 'pages_models.dart';

/// A bounded, immutable read snapshot. No graphic owns persistence or requests.
class PagesStudioSnapshot {
  const PagesStudioSnapshot({
    this.identity = '',
    this.sky,
    this.offeringDay,
    this.offeringStates = const {},
    this.kar,
    this.room,
    this.messages = const [],
    this.viewerId,
    this.completion = CompletionStatus.none,
  });
  final String identity;
  final FollowSkyObservationPresentationModel? sky;
  final int? offeringDay;
  final Map<int, OfferingTableDayViewState> offeringStates;
  final KarShrine? kar;
  final ReadingHouseRoomSummary? room;
  final List<ReadingHouseRoomMessage> messages;
  final String? viewerId;
  final CompletionStatus completion;
}

class PagesStudioGraphic extends StatelessWidget {
  const PagesStudioGraphic({
    super.key,
    required this.flow,
    required this.event,
    required this.snapshot,
  });
  final PagesFlow flow;
  final PagesUpcomingEvent? event;
  final PagesStudioSnapshot? snapshot;

  Widget _sheetGraphic(Widget graphic) => IgnorePointer(
    child: ExcludeFocus(child: SizedBox.expand(child: graphic)),
  );

  @override
  Widget build(BuildContext context) {
    final data = snapshot;
    final e = event;
    if (flow.maatKey == null) {
      return LayoutBuilder(
        builder: (context, box) => UserFlowAppearanceHero(
          appearance: flow.appearance,
          accent: Color(flow.color),
          localImageBytes: flow.imageBytes,
          surface: UserFlowAppearanceSurface.daySheet,
          height: box.maxHeight,
          borderRadius: BorderRadius.zero,
          completedOccurrences: flow.completed,
          totalOccurrences: flow.total,
          showSignLabel: false,
          showProgressFooter: false,
          allowImageFetch: false,
        ),
      );
    }
    if (data == null || e == null) return const SizedBox.shrink();
    if (data.sky != null) {
      return _sheetGraphic(
        FollowSkyObservationPresentation(model: data.sky!, graphicOnly: true),
      );
    }
    if (data.offeringDay != null) {
      final day = data.offeringDay!;
      return OfferingTableDayInstrument(
        contract: offeringTableDayViewContract(day),
        state: data.offeringStates[day]!,
        courseStates: data.offeringStates,
        now: DateTime.now(),
      );
    }
    final djed = djedV2EventForEvent(behaviorPayload: e.behavior);
    if (flow.maatKey == 'the-djed' && djed != null) {
      return _sheetGraphic(
        DjedSittingBehaviorSurface(
          flowId: int.parse(flow.id),
          event: djed,
          baseFixture: djedDayVisualFixtureForEvent(
            djed,
            supportName: e.behavior['support_name']?.toString(),
          ),
          onCompletionCommit: (_, _, _, _, _, _) async {},
          builder: (context, fixture, _) => DjedDayInstrument(
            fixture: fixture,
            supports: djedV2SupportFixtures(flow.notes, e.behavior),
            stageHeight: 230,
            graphicOnly: true,
          ),
        ),
      );
    }
    if (flow.maatKey == 'the-kar') {
      return _sheetGraphic(
        KarDayGraphic(
          netjer: karNetjerFromPayload(e.behavior),
          flowId: int.parse(flow.id),
          stageIndex: karStageIndexFromPayload(e.behavior),
          shrine: data.kar,
        ),
      );
    }
    if (flow.maatKey == 'the-reading-house') {
      return _sheetGraphic(
        ReadingHouseChatRoom(
          pane: true,
          fixture: readingHouseSnapshotVisualFixture(
            context: context,
            summary: data.room,
            messages: data.messages,
            status: ReadingHouseRoomStatus.ready,
            currentUserId: data.viewerId,
            solo: e.behavior['house_mode'] == 'solo',
          ),
        ),
      );
    }
    // A missing authored instrument is unavailable, never a detail-page hero.
    return const SizedBox.shrink();
  }
}
