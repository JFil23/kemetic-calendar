import 'package:mobile/features/calendar/calendar_geometry_snapshot.dart';
import 'package:mobile/features/calendar/calendar_section_index.dart';

/// Why a banner selection is being resolved.
enum CalendarBannerResolutionMode {
  initial,
  scrollingTowardFuture,
  scrollingTowardPast,

  /// A new geometry generation at an unchanged scroll offset.
  ///
  /// This mode never infers direction and never applies directional deadband.
  geometryOnlyAtUnchangedOffset,
}

/// Pure final-day-block handoff resolver.
///
/// The activation coordinate is the top edge inside the scroll viewport. The
/// fixed banner height is intentionally absent from this API so it cannot be
/// counted twice.
final class CalendarBannerResolver {
  CalendarBannerResolver({
    required this.deadband,
    this.index = const CalendarSectionIndex(),
  }) {
    if (!deadband.isFinite || deadband < 0) {
      throw RangeError.value(
        deadband,
        'deadband',
        'must be finite and non-negative',
      );
    }
  }

  final double deadband;
  final CalendarSectionIndex index;

  MonthRef? resolve({
    required CalendarGeometrySnapshot snapshot,
    required double activationCoordinate,
    required CalendarBannerResolutionMode mode,
    MonthRef? incumbent,
  }) {
    if (!activationCoordinate.isFinite) {
      throw ArgumentError.value(
        activationCoordinate,
        'activationCoordinate',
        'must be finite',
      );
    }

    if (mode == CalendarBannerResolutionMode.geometryOnlyAtUnchangedOffset &&
        incumbent != null &&
        snapshot.geometryFor(incumbent) != null) {
      // A layout generation is not user intent. Keep the mounted incumbent
      // stable until a real scroll sample arrives; do not manufacture a
      // direction from corrected pixels or apply directional hysteresis.
      return incumbent;
    }

    final physicalOwner = snapshot.ownerAt(activationCoordinate);
    final directOwner = _bannerOwnerAt(
      snapshot: snapshot,
      activationCoordinate: activationCoordinate,
      physicalOwner: physicalOwner,
    );
    if (directOwner == null) {
      final incumbentGeometry = incumbent == null
          ? null
          : snapshot.geometryFor(incumbent);
      return incumbentGeometry?.extent.contains(activationCoordinate) ?? false
          ? incumbent
          : null;
    }

    if (incumbent == null || directOwner == incumbent) return directOwner;

    if (mode == CalendarBannerResolutionMode.initial ||
        mode == CalendarBannerResolutionMode.geometryOnlyAtUnchangedOffset) {
      return directOwner;
    }

    if (deadband == 0) return directOwner;

    if (mode == CalendarBannerResolutionMode.scrollingTowardFuture &&
        index.successor(incumbent) == directOwner) {
      final incomingBoundary = _handoffBoundary(
        snapshot: snapshot,
        outgoing: incumbent,
        incoming: directOwner,
      );
      if (incomingBoundary == null) return directOwner;
      return activationCoordinate >= incomingBoundary + deadband
          ? directOwner
          : incumbent;
    }

    if (mode == CalendarBannerResolutionMode.scrollingTowardPast &&
        index.predecessor(incumbent) == directOwner) {
      final outgoingBoundary = _handoffBoundary(
        snapshot: snapshot,
        outgoing: directOwner,
        incoming: incumbent,
      );
      if (outgoingBoundary == null) return directOwner;
      return activationCoordinate <= outgoingBoundary - deadband
          ? directOwner
          : incumbent;
    }

    // A fling or programmatic jump may cross more than one section between
    // samples. Deadband only stabilizes one shared boundary; it must not retain
    // a stale month across a multi-section jump.
    return directOwner;
  }

  MonthRef? _bannerOwnerAt({
    required CalendarGeometrySnapshot snapshot,
    required double activationCoordinate,
    required MonthRef? physicalOwner,
  }) {
    if (physicalOwner == null) return null;
    final boundary = snapshot.geometryFor(physicalOwner)?.finalDayBlockLeading;
    return boundary != null && activationCoordinate >= boundary
        ? index.successor(physicalOwner)
        : physicalOwner;
  }

  double? _handoffBoundary({
    required CalendarGeometrySnapshot snapshot,
    required MonthRef outgoing,
    required MonthRef incoming,
  }) {
    if (index.successor(outgoing) != incoming) return null;
    return snapshot.geometryFor(outgoing)?.finalDayBlockLeading ??
        snapshot.geometryFor(incoming)?.extent.leading;
  }
}
