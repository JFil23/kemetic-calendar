import 'evening_threshold_flow.dart';
import 'follow_the_sky/domain/sky_catalog.dart';
import 'follow_the_sky/domain/sky_observing_night.dart';
import 'follow_the_sky/services/track_sky_enrollment_service.dart';
import 'maat_flow_catalog.dart';
import 'maat_flow_identity.dart';
import 'maat_flow_temporal_policy.dart';
import 'moon_return_astronomy.dart';
import 'the_course_flow.dart';
import 'the_decan_watch_enrollment.dart';
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
    TrackSkyTimeZone? scheduleTimeZone,
    SkyCatalog? skyCatalog,
    TrackSkyEnrollmentService? skyEnrollment,
    int eveningThresholdMinutes = kEveningThresholdDefaultMinutesAfterMidnight,
  }) {
    if (kArchivedCompatibilityMaatFlowKinds.contains(kind)) {
      throw UnsupportedError(
        'Archived Ma\u2019at flows are read-only and cannot be scheduled.',
      );
    }
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
        final timezone = _requireScheduleTimeZone(kind, scheduleTimeZone);
        final catalog = skyCatalog;
        final enrollment = skyEnrollment;
        if (catalog == null || enrollment == null) {
          throw StateError(
            'Sky catalog and enrollment authority are required for ${kind.name}.',
          );
        }
        final skyIanaTimeZone = timezone.ianaName;
        final nights = enrollment.upcomingNights(
          catalog: catalog,
          ianaTimeZone: skyIanaTimeZone,
          nowUtc: context.nowUtc,
        );
        if (nights.isEmpty) {
          throw StateError('No eligible sky event remains for ${kind.name}.');
        }
        return MaatFlowTemporalResolution(
          kind: kind,
          context: context,
          startDate: context.localDateForUtc(
            nights.first.primaryInstantUtc,
            ianaTimeZone: skyIanaTimeZone,
          ),
          skyNights: nights,
        );
      case MaatFlowTemporalPolicyKind.archivedReadOnly:
        throw StateError('Archived temporal policy reached for ${kind.name}.');
      case MaatFlowTemporalPolicyKind.eveningThreshold:
        final timezone = _requireScheduleTimeZone(kind, scheduleTimeZone);
        return _dateResolution(
          kind,
          context,
          defaultEveningThresholdStartDate(
            timezone,
            now: context.nowUtc,
            defaultMinutesAfterMidnight: eveningThresholdMinutes,
          ),
        );
      case MaatFlowTemporalPolicyKind.theCourse:
        final timezone = _requireScheduleTimeZone(kind, scheduleTimeZone);
        return _dateResolution(
          kind,
          context,
          defaultTheCourseStartDate(timezone, now: context.nowUtc),
        );
      case MaatFlowTemporalPolicyKind.moonReturn:
        final timezone = _requireScheduleTimeZone(kind, scheduleTimeZone);
        return _dateResolution(
          kind,
          context,
          moonReturnDefaultStartDate(timezone, now: context.nowUtc),
        );
      case MaatFlowTemporalPolicyKind.nextDecanWindow:
        final timezone = _requireScheduleTimeZone(kind, scheduleTimeZone);
        return _dateResolution(
          kind,
          context,
          defaultTheDecanWatchStartDate(timezone, now: context.nowUtc),
        );
    }
  }

  TrackSkyTimeZone _requireScheduleTimeZone(
    MaatFlowKind kind,
    TrackSkyTimeZone? scheduleTimeZone,
  ) {
    if (scheduleTimeZone != null) return scheduleTimeZone;
    throw StateError(
      'A specialist schedule timezone is required for ${kind.name}.',
    );
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
