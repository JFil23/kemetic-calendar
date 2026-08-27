enum ObservingPlaceSource { device, manual }

extension ObservingPlaceSourceX on ObservingPlaceSource {
  String get wireName => switch (this) {
    ObservingPlaceSource.device => 'device',
    ObservingPlaceSource.manual => 'manual',
  };

  static ObservingPlaceSource parse(String? raw) {
    return raw == 'device'
        ? ObservingPlaceSource.device
        : ObservingPlaceSource.manual;
  }
}

/// A reusable Hꜣw observing location. Follow the Sky consumes this value but
/// does not own location permission or place selection.
class ObservingPlace {
  const ObservingPlace({
    required this.latitude,
    required this.longitude,
    required this.ianaTimeZone,
    required this.label,
    required this.source,
    this.elevationMeters,
  }) : assert(latitude >= -90 && latitude <= 90),
       assert(longitude >= -180 && longitude <= 180),
       assert(
         elevationMeters == null ||
             (elevationMeters >= -500 && elevationMeters <= 10000),
       ),
       assert(ianaTimeZone.length > 0),
       assert(label.length > 0);

  final double latitude;
  final double longitude;
  final String ianaTimeZone;
  final String label;
  final ObservingPlaceSource source;
  final double? elevationMeters;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'latitude': latitude,
    'longitude': longitude,
    'iana_time_zone': ianaTimeZone,
    'label': label,
    'source': source.wireName,
    if (elevationMeters != null) 'elevation_meters': elevationMeters,
  };

  factory ObservingPlace.fromJson(Map<String, dynamic> json) {
    return ObservingPlace(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      ianaTimeZone: json['iana_time_zone'] as String,
      label: json['label'] as String,
      source: ObservingPlaceSourceX.parse(json['source']?.toString()),
      elevationMeters: (json['elevation_meters'] as num?)?.toDouble(),
    );
  }
}
