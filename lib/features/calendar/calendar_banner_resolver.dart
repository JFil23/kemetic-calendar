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

/// Pure leading-edge month resolver.
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

    final directOwner = snapshot.ownerAt(activationCoordinate);
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

    final incumbentGeometry = snapshot.geometryFor(incumbent);
    if (incumbentGeometry == null || deadband == 0) return directOwner;

    if (mode == CalendarBannerResolutionMode.scrollingTowardFuture &&
        index.successor(incumbent) == directOwner) {
      final incomingBoundary = snapshot
          .geometryFor(directOwner)!
          .extent
          .leading;
      return activationCoordinate >= incomingBoundary + deadband
          ? directOwner
          : incumbent;
    }

    if (mode == CalendarBannerResolutionMode.scrollingTowardPast &&
        index.predecessor(incumbent) == directOwner) {
      final incumbentBoundary = incumbentGeometry.extent.leading;
      return activationCoordinate <= incumbentBoundary - deadband
          ? directOwner
          : incumbent;
    }

    // A fling or programmatic jump may cross more than one section between
    // samples. Deadband only stabilizes one shared boundary; it must not retain
    // a stale month across a multi-section jump.
    return directOwner;
  }
}
