/// Civil timezone keys for Follow the Sky V2 (not V1 asset mapping).
enum FollowSkyTimeZone {
  pacific,
  mountain,
  central,
  eastern,
}

extension FollowSkyTimeZoneX on FollowSkyTimeZone {
  String get key {
    switch (this) {
      case FollowSkyTimeZone.pacific:
        return 'pacific';
      case FollowSkyTimeZone.mountain:
        return 'mountain';
      case FollowSkyTimeZone.central:
        return 'central';
      case FollowSkyTimeZone.eastern:
        return 'eastern';
    }
  }

  String get label {
    switch (this) {
      case FollowSkyTimeZone.pacific:
        return 'Pacific Time';
      case FollowSkyTimeZone.mountain:
        return 'Mountain Time';
      case FollowSkyTimeZone.central:
        return 'Central Time';
      case FollowSkyTimeZone.eastern:
        return 'Eastern Time';
    }
  }

  String get ianaName {
    switch (this) {
      case FollowSkyTimeZone.pacific:
        return 'America/Los_Angeles';
      case FollowSkyTimeZone.mountain:
        return 'America/Denver';
      case FollowSkyTimeZone.central:
        return 'America/Chicago';
      case FollowSkyTimeZone.eastern:
        return 'America/New_York';
    }
  }

  static FollowSkyTimeZone? tryParse(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'pacific':
      case 'pt':
        return FollowSkyTimeZone.pacific;
      case 'mountain':
      case 'mt':
        return FollowSkyTimeZone.mountain;
      case 'central':
      case 'ct':
        return FollowSkyTimeZone.central;
      case 'eastern':
      case 'et':
        return FollowSkyTimeZone.eastern;
      default:
        return null;
    }
  }
}
