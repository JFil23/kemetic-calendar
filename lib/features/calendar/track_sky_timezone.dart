/// Shared US civil timezone keys used across Ma'at flows.
/// Formerly lived in track_sky_flow.dart; extracted so Follow the Sky V1 can be deleted.
enum TrackSkyTimeZone { pacific, mountain, central, eastern }

extension TrackSkyTimeZoneX on TrackSkyTimeZone {
  String get key {
    switch (this) {
      case TrackSkyTimeZone.pacific:
        return 'pacific';
      case TrackSkyTimeZone.mountain:
        return 'mountain';
      case TrackSkyTimeZone.central:
        return 'central';
      case TrackSkyTimeZone.eastern:
        return 'eastern';
    }
  }

  String get label {
    switch (this) {
      case TrackSkyTimeZone.pacific:
        return 'Pacific Time';
      case TrackSkyTimeZone.mountain:
        return 'Mountain Time';
      case TrackSkyTimeZone.central:
        return 'Central Time';
      case TrackSkyTimeZone.eastern:
        return 'Eastern Time';
    }
  }

  String get shortLabel {
    switch (this) {
      case TrackSkyTimeZone.pacific:
        return 'PT';
      case TrackSkyTimeZone.mountain:
        return 'MT';
      case TrackSkyTimeZone.central:
        return 'CT';
      case TrackSkyTimeZone.eastern:
        return 'ET';
    }
  }

  String get ianaName {
    switch (this) {
      case TrackSkyTimeZone.pacific:
        return 'America/Los_Angeles';
      case TrackSkyTimeZone.mountain:
        return 'America/Denver';
      case TrackSkyTimeZone.central:
        return 'America/Chicago';
      case TrackSkyTimeZone.eastern:
        return 'America/New_York';
    }
  }

  static TrackSkyTimeZone? tryParse(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'pacific':
      case 'pt':
        return TrackSkyTimeZone.pacific;
      case 'mountain':
      case 'mt':
        return TrackSkyTimeZone.mountain;
      case 'central':
      case 'ct':
        return TrackSkyTimeZone.central;
      case 'eastern':
      case 'et':
        return TrackSkyTimeZone.eastern;
      default:
        return null;
    }
  }
}
