import 'dawn_house_rite_flow.dart';
import 'evening_threshold_flow.dart';
import 'evening_threshold_rite_flow.dart';
import 'follow_the_sky/domain/sky_catalog.dart';
import 'follow_the_sky/domain/sky_observing_night.dart';
import 'follow_the_sky/services/track_sky_enrollment_service.dart';
import 'maat_flow_catalog.dart';
import 'maat_flow_identity.dart';
import 'maat_flow_temporal_policy.dart';
import 'moon_return_astronomy.dart';
import 'the_course_flow.dart';
import 'the_days_outside_year_enrollment.dart';
import 'the_decan_watch_enrollment.dart';
import 'the_kept_word_flow.dart';
import 'the_tending_flow.dart';
import 'the_wag_enrollment.dart';
import 'the_weighing_flow.dart';
import 'track_sky_timezone.dart';

class MaatFlowTemporalResolution {
  const MaatFlowTemporalResolution({
    required this.kind,
    required this.context,
    required this.startDate,
    this.skyNights = const <SkyObservingNight>[],
  });

  final MaatFlowKind kind;
  final MaatFlowTemporalContext context;
  final DateTime startDate;
  final List<SkyObservingNight> skyNights;

  SkyObservingNight? get firstSkyNight =>
      skyNights.isEmpty ? null : skyNights.first;
}

/// The single dispatcher from a registered Flow's declared temporal policy to
/// its existing specialist calendar/astronomy implementation.
class MaatFlowTemporalResolver {
  const MaatFlowTemporalResolver();

  MaatFlowTemporalResolution resolve({
    required MaatFlowKind kind,
    required MaatFlowTemporalContext context,
    SkyCatalog? skyCatalog,
    TrackSkyEnrollmentService? skyEnrollment,
    int eveningThresholdMinutes = kEveningThresholdDefaultMinutesAfterMidnight,
    int eveningThresholdFallbackMinutes =
        kEveningThresholdDefaultFallbackMinutes,
  }) {
    final policy = maatFlowCatalogEntry(kind).temporalPolicy;
    switch (policy.kind) {
      case MaatFlowTemporalPolicyKind.relativeCalendarDays:
        final offset = policy.dayOffset;
        if (offset == null) {
          throw StateError(
            'Relative temporal policy for ${kind.name} has no offset.',
          );
        }
        return _dateResolution(kind, context, context.localDateAfter(offset));
      case MaatFlowTemporalPolicyKind.nextEligibleSkyEvent:
        final catalog = skyCatalog;
        final enrollment = skyEnrollment;
        if (catalog == null || enrollment == null) {
          throw StateError(
            'Sky catalog and enrollment authority are required for ${kind.name}.',
          );
        }
        final nights = enrollment.upcomingNights(
          catalog: catalog,
          ianaTimeZone: context.timezone.ianaName,
          nowUtc: context.nowUtc,
        );
        if (nights.isEmpty) {
          throw StateError('No eligible sky event remains for ${kind.name}.');
        }
        return MaatFlowTemporalResolution(
          kind: kind,
          context: context,
          startDate: context.localDateForUtc(nights.first.primaryInstantUtc),
          skyNights: nights,
        );
      case MaatFlowTemporalPolicyKind.dawnHouseRite:
        return _dateResolution(
          kind,
          context,
          defaultDawnHouseRiteStartDate(context.timezone, now: context.nowUtc),
        );
      case MaatFlowTemporalPolicyKind.eveningThreshold:
        return _dateResolution(
          kind,
          context,
          defaultEveningThresholdStartDate(
            context.timezone,
            now: context.nowUtc,
            defaultMinutesAfterMidnight: eveningThresholdMinutes,
          ),
        );
      case MaatFlowTemporalPolicyKind.eveningThresholdRite:
        return _dateResolution(
          kind,
          context,
          defaultEveningThresholdRiteStartDate(
            context.timezone,
            now: context.nowUtc,
            fallbackMinutesAfterMidnight: eveningThresholdFallbackMinutes,
          ),
        );
      case MaatFlowTemporalPolicyKind.theWeighing:
        return _dateResolution(
          kind,
          context,
          defaultTheWeighingStartDate(context.timezone, now: context.nowUtc),
        );
      case MaatFlowTemporalPolicyKind.theTending:
        return _dateResolution(
          kind,
          context,
          defaultTheTendingStartDate(context.timezone, now: context.nowUtc),
        );
      case MaatFlowTemporalPolicyKind.keptWord:
        return _dateResolution(
          kind,
          context,
          defaultKeptWordStartDate(context.timezone, now: context.nowUtc),
        );
      case MaatFlowTemporalPolicyKind.theCourse:
        return _dateResolution(
          kind,
          context,
          defaultTheCourseStartDate(context.timezone, now: context.nowUtc),
        );
      case MaatFlowTemporalPolicyKind.moonReturn:
        return _dateResolution(
          kind,
          context,
          moonReturnDefaultStartDate(context.timezone, now: context.nowUtc),
        );
      case MaatFlowTemporalPolicyKind.nextWepRonpetWindow:
        return _dateResolution(
          kind,
          context,
          defaultTheWagStartDate(context.timezone, now: context.nowUtc),
        );
      case MaatFlowTemporalPolicyKind.nextDecanWindow:
        return _dateResolution(
          kind,
          context,
          defaultTheDecanWatchStartDate(context.timezone, now: context.nowUtc),
        );
      case MaatFlowTemporalPolicyKind.nextDaysOutsideYearWindow:
        return _dateResolution(
          kind,
          context,
          defaultTheDaysOutsideYearStartDate(
            context.timezone,
            now: context.nowUtc,
          ),
        );
    }
  }

  MaatFlowTemporalResolution _dateResolution(
    MaatFlowKind kind,
    MaatFlowTemporalContext context,
    DateTime date,
  ) {
    return MaatFlowTemporalResolution(
      kind: kind,
      context: context,
      startDate: DateTime(date.year, date.month, date.day),
    );
  }
}
