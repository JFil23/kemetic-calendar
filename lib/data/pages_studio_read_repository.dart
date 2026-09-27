import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/pages/pages_arrangement.dart';
import '../features/pages/pages_models.dart';
import '../features/pages/pages_studio_graphic.dart';
import '../features/calendar/calendar_completion.dart';
import '../features/calendar/follow_the_sky/services/follow_sky_day_detail.dart';
import '../features/calendar/follow_the_sky/services/full_moon_instrument_data_provider.dart';
import '../features/calendar/follow_the_sky/services/sky_instrument_data_provider.dart';
import '../features/calendar/follow_the_sky/presentation/follow_sky_observation_presentation_model.dart';
import '../features/calendar/the_offering_table_flow.dart';
import '../features/calendar/the_offering_table_local_store.dart';
import '../features/calendar/the_offering_table/presentation/offering_table_day_state.dart';
import '../features/calendar/the_kar/the_kar_flow.dart';
import '../features/calendar/the_kar/the_kar_models.dart';
import '../features/calendar/the_reading_house/reading_house_room_repository.dart';
import 'account_view_cache.dart';

/// Invoked through AccountViewCache only for the next selected occurrence.
/// Never opens a behavior repository that ensures rows, marks read, or watches.
String pagesStudioIdentity(PagesFlow flow, PagesUpcomingEvent event) =>
    jsonEncode([
      event.id,
      event.clientEventId,
      event.at.toIso8601String(),
      event.behavior,
      flow.id,
      flow.notes,
    ]);

Future<PagesStudioSnapshot> readPagesStudioSnapshot(
  SupabaseClient client,
  PagesFlow flow,
  PagesUpcomingEvent event,
  bool Function() mayFetch,
) async {
  void check() {
    if (!mayFetch()) throw const ViewReadCancelled();
  }

  check();
  final identity = pagesStudioIdentity(flow, event);
  final completion = await const CalendarCompletionLocalStore().load(
    calendarCompletionIdentity(
      eventId: event.id,
      clientEventId: event.clientEventId,
      fallback: '${event.flowId}:${event.at.toIso8601String()}',
    ),
  );
  check();
  if (flow.maatKey == 'track-the-sky') {
    final skyId = FollowSkyDayDetail.skyEventIdFromBehavior(event.behavior);
    if (skyId == null) throw StateError('Sky occurrence identity is missing');
    final catalog = await FollowSkyDayDetail.catalog();
    check();
    FollowSkyObservationPresentationModel sky;
    try {
      sky =
          await FollowSkyObservationPresentationModelFactory(
            instrumentProvider: FullMoonInstrumentDataProvider(
              client: client,
              persistCache: false,
              mayFetch: mayFetch,
            ),
          ).build(
            catalog: catalog,
            skyEventId: skyId,
            intention: event.behavior['intention']?.toString(),
          );
    } catch (_) {
      check();
      sky =
          await FollowSkyObservationPresentationModelFactory(
            instrumentProvider: const CatalogSkyInstrumentDataProvider(),
          ).build(
            catalog: catalog,
            skyEventId: skyId,
            intention: event.behavior['intention']?.toString(),
          );
    }
    return PagesStudioSnapshot(
      identity: identity,
      sky: sky,
      completion: completion.completionStatus,
    );
  }
  if (flow.maatKey == 'the-offering-table') {
    final day = offeringTableDayForEvent(
      title: event.title,
      behaviorPayload: event.behavior,
    )?.dayNumber;
    if (day == null) {
      throw StateError('Offering occurrence identity is missing');
    }
    final states = <int, OfferingTableDayViewState>{};
    for (final d in day == 30 ? List.generate(30, (i) => i + 1) : [day]) {
      states[d] = OfferingTableDayViewState.fromJson(
        await const OfferingTableLocalStore().loadDayViewState(
          int.parse(flow.id),
          d,
        ),
      );
      check();
    }
    return PagesStudioSnapshot(
      identity: identity,
      offeringDay: day,
      offeringStates: states,
      completion: completion.completionStatus,
    );
  }
  if (flow.maatKey == 'the-kar') {
    final row = await client
        .from('kar_shrines')
        .select()
        .eq('user_id', client.auth.currentUser!.id)
        .eq('netjer_key', karNetjerFromPayload(event.behavior).key)
        .maybeSingle();
    return PagesStudioSnapshot(
      identity: identity,
      kar: row == null ? null : KarShrine.fromRow(row),
      completion: completion.completionStatus,
    );
  }
  if (flow.maatKey == 'the-reading-house' &&
      event.behavior['house_mode'] != 'solo') {
    final row = await client
        .from('reading_house_room_summaries')
        .select()
        .eq('calendar_id', event.calendarId)
        .eq('flow_id', int.parse(flow.id))
        .maybeSingle();
    check();
    final messages = row == null
        ? <ReadingHouseRoomMessage>[]
        : await SupabaseReadingHouseRoomRepository(client).listMessages(
            identity: ReadingHouseRoomIdentity(
              calendarId: event.calendarId,
              flowId: int.parse(flow.id),
            ),
            limit: 50,
          );
    return PagesStudioSnapshot(
      identity: identity,
      room: row == null ? null : ReadingHouseRoomSummary.fromJson(row),
      messages: messages,
      viewerId: client.auth.currentUser?.id,
      completion: completion.completionStatus,
    );
  }
  return PagesStudioSnapshot(
    identity: identity,
    viewerId: client.auth.currentUser?.id,
    completion: completion.completionStatus,
  );
}
