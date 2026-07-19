import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/dawn_house_rite_flow.dart';
import 'package:mobile/features/calendar/evening_threshold_rite_flow.dart';
import 'package:mobile/features/calendar/maat_decan_flow.dart';
import 'package:mobile/features/calendar/moon_return_astronomy.dart';
import 'package:mobile/features/calendar/moon_return_flow.dart';
import 'package:mobile/features/calendar/the_course_flow.dart';
import 'package:mobile/features/calendar/the_days_outside_year_flow.dart';
import 'package:mobile/features/calendar/the_decan_watch_flow.dart';
import 'package:mobile/features/calendar/the_decan_watch_scheduler.dart';
import 'package:mobile/features/calendar/the_djed_flow.dart';
import 'package:mobile/features/calendar/the_kept_word_flow.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/the_open_hand_flow.dart';
import 'package:mobile/features/calendar/the_tending_flow.dart';
import 'package:mobile/features/calendar/the_wag_flow.dart';
import 'package:mobile/features/calendar/the_weighing_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';

void main() {
  test('predefined Ma’at Flow event notes contain no disclaimer copy', () {
    final banned = RegExp(
      r'(modern reconstruction|not medical|not legal|privacy notification|'
      r'notifications carry only|push notifications|notification preview|'
      r'historically attested|directly attested|not 1:1|interpretive|'
      r'educational purposes|terms and conditions)',
      caseSensitive: false,
    );

    final details = <({String flow, String event, String detail})>[
      (
        flow: 'Follow the sky',
        event: 'sample',
        detail: const TrackSkyEvent(
          category: 'Solar Events',
          title: 'Horizon Watch',
          exactLabel: 'May 1, 2026, 8:00 PM PDT',
          scientificBreakdown: 'Scientific note.',
          whatToSee: 'A silver line will appear above the ridge.',
          bestViewing:
              'Step outside before dusk and give the western edge a minute.',
          significance: 'Return makes measure possible.',
          notes: 'Future.',
          schedule: TrackSkyEventSchedule(
            dateIso: '2026-05-01',
            startTime24: '20:00',
            endTime24: '21:00',
            allDay: false,
          ),
        ).detailText,
      ),
      for (final day in kDawnHouseRiteDays)
        (
          flow: kDawnHouseRiteFlowKey,
          event: 'day-${day.dayNumber}',
          detail: dawnHouseRiteDetailText(
            day,
            discreet: false,
            lens: DawnHouseRiteLens.neutral,
          ),
        ),
      for (final day in kEveningThresholdRiteDays)
        (
          flow: kEveningThresholdRiteFlowKey,
          event: 'day-${day.dayNumber}',
          detail: eveningThresholdRiteDetailText(
            day,
            discreet: false,
            lens: EveningThresholdRiteLens.neutral,
          ),
        ),
      for (final event in kTheWeighingEvents)
        (
          flow: kTheWeighingFlowKey,
          event: 'event-${event.eventNumber}',
          detail: theWeighingDetailText(event, lens: TheWeighingLens.neutral),
        ),
      for (final day in kOfferingTableDays)
        (
          flow: kOfferingTableFlowKey,
          event: 'day-${day.dayNumber}',
          detail: offeringTableDetailText(
            day,
            lens: OfferingTableLens.neutral,
            noCupMode: false,
          ),
        ),
      for (final event in kTheTendingEvents)
        (
          flow: kTheTendingFlowKey,
          event: 'event-${event.eventNumber}',
          detail: theTendingDetailText(event, lens: TheTendingLens.neutral),
        ),
      for (final event in kKeptWordEvents)
        (
          flow: kKeptWordFlowKey,
          event: 'event-${event.eventNumber}',
          detail: keptWordDetailText(event, lens: KeptWordLens.neutral),
        ),
      for (final event in kTheCourseEvents)
        (
          flow: kTheCourseFlowKey,
          event: 'event-${event.eventNumber}',
          detail: courseDetailText(event, lens: CourseLens.neutral),
        ),
      for (final occurrence in moonReturnOccurrencesForWindow(
        window: moonReturnEnrollmentWindowForStartDate(
          DateTime(2026, 8, 10),
          TrackSkyTimeZone.pacific,
          now: DateTime.utc(2026, 8, 1, 12),
        )!,
        horizonMonths: 2,
      ))
        (
          flow: kMoonReturnFlowKey,
          event: occurrence.phaseDateIso,
          detail: moonReturnDetailText(
            occurrence,
            lens: MoonReturnLens.neutral,
          ),
        ),
      for (final event in kWagEvents)
        (
          flow: kTheWagFlowKey,
          event: 'event-${event.eventNumber}',
          detail: wagDetailText(event, lens: WagLens.neutral),
        ),
      (
        flow: kDecanWatchFlowKey,
        event: 'sample',
        detail: decanWatchDetailText(
          decanWatchOccurrenceFor(
            kYear: 1,
            kMonth: 1,
            decanStartDay: 1,
            timezone: TrackSkyTimeZone.pacific,
          ),
          lens: DecanWatchLens.neutral,
        ),
      ),
      for (final event in kDaysOutsideEvents)
        (
          flow: kDaysOutsideTheYearFlowKey,
          event: 'event-${event.eventNumber}',
          detail: daysOutsideDetailText(
            event,
            closingKYear: 2,
            variant: DaysOutsideCopyVariant.standard,
          ),
        ),
      for (final event in kOpenHandEvents)
        (
          flow: kTheOpenHandFlowKey,
          event: 'event-${event.eventNumber}',
          detail: openHandDetailText(event, lens: OpenHandLens.neutral),
        ),
      for (final event in kDjedEvents)
        (
          flow: kTheDjedFlowKey,
          event: 'event-${event.eventNumber}',
          detail: djedDetailText(event, lens: DjedLens.neutral),
        ),
      for (final definition in kMaatDecanFlowDefinitions)
        for (final event in definition.events)
          (
            flow: definition.key,
            event: 'event-${event.eventNumber}',
            detail: maatDecanFlowDetailText(definition, event),
          ),
    ];

    final autobiographyEvent8 = details.singleWhere(
      (entry) =>
          entry.flow == kTheAutobiographyFlowKey && entry.event == 'event-8',
    );
    expect(
      autobiographyEvent8.detail,
      allOf(
        contains(
          'Choose one line that can be shared without exposing names, private details, or sensitive content.',
        ),
        contains(
          'Share the line only with someone who witnessed, shaped, or belongs to that part of the account.',
        ),
        contains(
          'If no safe person can receive it, keep the line private and record why it is not shared.',
        ),
        contains(
          'Use the feed only for a generic line with names and private details removed.',
        ),
      ),
      reason: 'Autobiography event 8 should keep privacy-safe sharing gates.',
    );

    for (final entry in details) {
      expect(
        banned.hasMatch(entry.detail),
        isFalse,
        reason: '${entry.flow} / ${entry.event} contains disclaimer text',
      );
    }
  });
}
