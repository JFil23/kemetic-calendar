import 'package:flutter/foundation.dart';

import 'maat_flow_identity.dart';

enum MaatEventBlockHeightAuthority { scheduleDuration, fixedOneHour }

@immutable
class MaatEventBlockLayoutSpec {
  const MaatEventBlockLayoutSpec._({required this.heightAuthority});

  static const double standardOneHourHeight = 60;

  static const MaatEventBlockLayoutSpec scheduleDuration =
      MaatEventBlockLayoutSpec._(
        heightAuthority: MaatEventBlockHeightAuthority.scheduleDuration,
      );

  static const MaatEventBlockLayoutSpec fixedOneHour =
      MaatEventBlockLayoutSpec._(
        heightAuthority: MaatEventBlockHeightAuthority.fixedOneHour,
      );

  final MaatEventBlockHeightAuthority heightAuthority;

  double? get fixedVisualHeight =>
      heightAuthority == MaatEventBlockHeightAuthority.fixedOneHour
      ? standardOneHourHeight
      : null;

  static MaatEventBlockLayoutSpec forFlow(MaatFlowKind? kind) {
    return switch (kind) {
      MaatFlowKind.offeringTable ||
      MaatFlowKind.theDjed ||
      MaatFlowKind.readingHouse ||
      MaatFlowKind.theKar => fixedOneHour,
      // Follow the Sky is authored by the astronomical occurrence duration.
      MaatFlowKind.trackSky => scheduleDuration,
      _ => scheduleDuration,
    };
  }
}
