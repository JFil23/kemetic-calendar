import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'pages_models.dart';
import '../calendar/presentation/user_flow_appearance_visual.dart';
import '../calendar/follow_the_sky/services/follow_sky_day_detail.dart';
import '../calendar/follow_the_sky/services/full_moon_instrument_data_provider.dart';
import '../calendar/follow_the_sky/presentation/follow_sky_observation_presentation_model.dart';
import '../calendar/follow_the_sky/presentation/follow_sky_view_time_policy.dart';
import '../calendar/follow_the_sky/presentation/widgets/follow_sky_instrument_surface.dart';
import '../calendar/the_offering_table_flow.dart';
import '../calendar/the_offering_table_local_store.dart';
import '../calendar/the_offering_table/presentation/offering_table_day_contract.dart';
import '../calendar/the_offering_table/presentation/offering_table_day_state.dart';
import '../calendar/the_offering_table/presentation/offering_table_day_instrument.dart';
import '../calendar/the_djed_v2_flow.dart';
import '../calendar/the_djed/presentation/djed_day_presentation.dart';
import '../calendar/the_kar/the_kar_flow.dart';
import '../calendar/the_kar/the_kar_models.dart';
import '../calendar/the_kar/presentation/kar_event_block_visual.dart';
import '../calendar/the_reading_house/presentation/reading_house_day_presentation.dart';

/// Passive excerpts of the actual sheet renderers. Never mounts a sheet host,
/// behavior controller, timer, subscription, remote provider or save callback.
class PagesSheetGraphic extends StatefulWidget {
  const PagesSheetGraphic({super.key, required this.flow});
  final PagesFlow flow;
  @override
  State<PagesSheetGraphic> createState() => _PagesSheetGraphicState();
}

class _PagesSheetGraphicState extends State<PagesSheetGraphic> {
  late Future<Widget> _graphic;
  FollowSkyViewTimeController? _skyController;

  @override
  void initState() {
    super.initState();
    _graphic = _resolve();
  }

  @override
  void didUpdateWidget(PagesSheetGraphic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flow != widget.flow) {
      _skyController?.dispose();
      _skyController = null;
      _graphic = _resolve();
    }
  }

  @override
  void dispose() {
    _skyController?.dispose();
    super.dispose();
  }

  Widget _stage(Widget child, {double width = 390, double height = 280}) =>
      FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(width: width, height: height, child: child),
      );

  Future<Widget> _resolve() async {
    final f = widget.flow, occurrence = widget.flow.occurrence;
    switch (f.maatKey) {
      case 'track-the-sky':
        final id = FollowSkyDayDetail.skyEventIdFromBehavior(
          occurrence?.behavior,
        );
        if (id == null) return const SizedBox();
        final catalog = await FollowSkyDayDetail.catalog();
        final model = await FollowSkyObservationPresentationModelFactory(
          instrumentProvider: FullMoonInstrumentDataProvider(readOnly: true),
        ).build(catalog: catalog, skyEventId: id);
        if (!mounted || widget.flow != f) return const SizedBox();
        final controller = FollowSkyViewTimeController(
          track: model.track,
          now: model.focusInstant,
        );
        _skyController = controller;
        // The sheet reserves its upper region for copy. Show the instrument
        // region at its original geometry, omitting the header copy.
        return _stage(
          ClipRect(
            child: Stack(
              children: [
                Positioned(
                  top: -80,
                  left: 0,
                  width: 300,
                  height: 380,
                  child: FollowSkyInstrumentSurface(
                    data: model.instrument,
                    peakMarker: model.peakMarker,
                    controller: controller,
                  ),
                ),
              ],
            ),
          ),
          width: 300,
          height: 300,
        );
      case 'the-offering-table':
        final day = offeringTableDayForEvent(
          title: occurrence?.title,
          behaviorPayload: occurrence?.behavior,
        );
        if (day == null) return const SizedBox();
        final localId = occurrence?.localFlowId;
        final saved = localId == null
            ? <String, dynamic>{}
            : await const OfferingTableLocalStore().loadDayViewState(
                localId,
                day.dayNumber,
              );
        return _stage(
          OfferingTableDayInstrument(
            contract: offeringTableDayViewContract(day.dayNumber),
            state: OfferingTableDayViewState.fromJson(saved),
            now: DateTime.now(),
          ),
        );
      case 'the-djed':
        final event = djedV2EventForEvent(
          behaviorPayload: occurrence?.behavior,
        );
        if (event == null) return const SizedBox();
        final configuration = djedV2ConfigurationFromNotes(f.notes);
        final supports = configuration == null
            ? kDjedSupportFixtures
            : [
                for (final support in configuration.supports)
                  DjedSupportFixture(
                    name: support.name,
                    condition: switch (support.initialCondition) {
                      DjedV2SupportCondition.holding =>
                        DjedSupportCondition.holding,
                      DjedV2SupportCondition.underPressure =>
                        DjedSupportCondition.underPressure,
                      DjedV2SupportCondition.wobbling =>
                        DjedSupportCondition.wobbling,
                    },
                  ),
              ];
        final base = djedDayVisualFixtureForEvent(event);
        final fixture = DjedDayVisualFixture(
          sittingNumber: base.sittingNumber,
          stage: base.stage,
          supportSlot: base.supportSlot,
          supportName: supports[base.supportSlot.clamp(1, 4) - 1].name,
        );
        return _stage(DjedSittingStage(fixture: fixture, supports: supports));
      case 'the-kar':
        if (occurrence == null) return const SizedBox();
        return _stage(
          KarDayShrineVisual(
            color: Color(karNetjerFromFlowNotes(f.notes).accentValue),
            currentStage: karStageIndexFromPayload(occurrence.behavior),
          ),
          width: 120,
          height: 190,
        );
      case 'the-reading-house':
        return _stage(
          const Center(child: ReadingHouseRoomEmblem(glyph: '◌')),
          width: 64,
          height: 64,
        );
      default:
        return LayoutBuilder(
          builder: (context, box) => UserFlowAppearanceHero(
            appearance: f.appearance,
            accent: Color(f.color),
            localImageBytes: f.imageBytes,
            allowImageFetch: false,
            surface: UserFlowAppearanceSurface.daySheet,
            completedOccurrences: f.completed,
            totalOccurrences: f.total,
            showSignLabel: false,
            height: box.maxHeight,
            borderRadius: BorderRadius.zero,
            signSize: math.max(
              1,
              math.min(72, math.min(box.maxWidth, box.maxHeight) - 8),
            ),
            imageCacheWidth:
                (box.maxWidth * MediaQuery.devicePixelRatioOf(context)).ceil(),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ColoredBox(
      color: const Color(0xff080706),
      child: FutureBuilder<Widget>(
        future: _graphic,
        builder: (context, snapshot) => snapshot.data ?? const SizedBox(),
      ),
    ),
  );
}
