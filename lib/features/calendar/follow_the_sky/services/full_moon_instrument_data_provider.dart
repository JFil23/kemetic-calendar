import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/observing_place.dart';
import '../domain/sky_instrument_data.dart';
import '../domain/sky_observing_night.dart';
import 'instrument_family_resolver.dart';
import 'sky_instrument_data_provider.dart';

typedef FullMoonInstrumentInvocation =
    Future<({int status, Object? data})> Function(Map<String, dynamic> body);

class FullMoonInstrumentProvenanceMismatch implements Exception {
  const FullMoonInstrumentProvenanceMismatch({
    required this.catalogPhaseInstant,
    required this.computedPhaseInstant,
    required this.issues,
  });

  final DateTime catalogPhaseInstant;
  final DateTime computedPhaseInstant;
  final List<String> issues;

  @override
  String toString() => 'Full Moon catalog provenance mismatch';
}

/// Full-Moon-only astronomy provider. Every other family remains on the
/// catalog presentation provider until it receives its own audited slice.
class FullMoonInstrumentDataProvider implements SkyInstrumentDataProvider {
  FullMoonInstrumentDataProvider({
    SupabaseClient? client,
    SharedPreferences? preferences,
    FullMoonInstrumentInvocation? invoke,
    this.catalogFallback = const CatalogSkyInstrumentDataProvider(),
  }) : _preferences = preferences,
       _invoke =
           invoke ?? _clientInvocation(client ?? Supabase.instance.client);

  static const String calculationVersion = 'full-moon-local-v1';
  static const String _cachePrefix = 'haw:full_moon_instrument:v1:';
  final SharedPreferences? _preferences;
  final FullMoonInstrumentInvocation _invoke;
  final SkyInstrumentDataProvider catalogFallback;

  static FullMoonInstrumentInvocation _clientInvocation(SupabaseClient client) {
    return (body) async {
      try {
        final response = await client.functions.invoke(
          'resolve_full_moon_instrument',
          body: body,
        );
        return (status: response.status, data: response.data as Object?);
      } on FunctionException catch (error) {
        return (status: error.status, data: error.details as Object?);
      }
    };
  }

  @override
  Future<SkyInstrumentData> resolve({
    required SkyObservingNight night,
    required ObservingPlace? place,
  }) async {
    if (const InstrumentFamilyResolver().resolve(night) !=
            SkyInstrumentFamily.lunarPath ||
        place == null) {
      return catalogFallback.resolve(night: night, place: place);
    }

    final body = <String, dynamic>{
      'schemaVersion': 1,
      'skyEventId': night.skyEventId,
      if (night.companion != null) 'companionSkyEventId': night.companion!.id,
      'catalogPhaseInstantUtc': night.anchor.primaryInstantUtc
          .toUtc()
          .toIso8601String(),
      if (night.companion != null)
        'catalogEclipsePeakUtc': night.companion!.primaryInstantUtc
            .toUtc()
            .toIso8601String(),
      'latitude': place.latitude,
      'longitude': place.longitude,
      if (place.elevationMeters != null)
        'elevationMeters': place.elevationMeters,
    };
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final cacheKey = '$_cachePrefix${_stableHash(jsonEncode(body))}';
    final cached = preferences.getString(cacheKey);
    Map<String, dynamic>? response;
    if (cached != null) {
      try {
        response = Map<String, dynamic>.from(jsonDecode(cached) as Map);
      } on Object {
        await preferences.remove(cacheKey);
      }
    }

    if (response == null) {
      final invocation = await _invoke(body);
      final raw = invocation.data;
      if (raw is! Map) {
        throw StateError('Full Moon computation returned no result.');
      }
      response = Map<String, dynamic>.from(raw);
      if (response['status'] == 'anchor_mismatch') {
        throw _mismatchFrom(response);
      }
      if (invocation.status < 200 || invocation.status >= 300) {
        throw StateError('Full Moon computation is unavailable.');
      }
      await preferences.setString(cacheKey, jsonEncode(response));
    }

    return parseResult(response, night: night, place: place);
  }

  static LunarPathData parseResult(
    Map<String, dynamic> response, {
    required SkyObservingNight night,
    required ObservingPlace place,
  }) {
    if (response['schemaVersion'] != 1 ||
        response['skyEventId'] != night.skyEventId) {
      throw const FormatException('Unexpected Full Moon response identity.');
    }
    if (response['status'] == 'anchor_mismatch') {
      throw _mismatchFrom(response);
    }
    if (response['status'] != 'ok') {
      throw const FormatException('Unexpected Full Moon response status.');
    }

    tzdata.initializeTimeZones();
    final location = tz.getLocation(place.ianaTimeZone);
    DateTime local(Object? value) =>
        tz.TZDateTime.from(DateTime.parse(value! as String).toUtc(), location);
    double number(Map<dynamic, dynamic> value, String key) =>
        (value[key] as num).toDouble();

    final samples = (response['samples'] as List)
        .map((raw) {
          final item = Map<String, dynamic>.from(raw as Map);
          return SkyPositionSample(
            at: local(item['atUtc']),
            altitudeDegrees: number(item, 'altitudeDegrees'),
            azimuthDegrees: number(item, 'azimuthDegrees'),
          );
        })
        .toList(growable: false);
    final eclipseRaw = response['eclipse'];
    final eclipse = eclipseRaw is Map
        ? Map<String, dynamic>.from(eclipseRaw)
        : null;
    final contacts = (eclipse?['contacts'] as List? ?? const <dynamic>[])
        .map((raw) {
          final item = Map<String, dynamic>.from(raw as Map);
          return LunarEclipseContact(
            kind: LunarEclipseContactKindX.parse(item['kind'] as String),
            at: local(item['atUtc']),
            altitudeDegrees: number(item, 'altitudeDegrees'),
            azimuthDegrees: number(item, 'azimuthDegrees'),
            locallyVisible: item['locallyVisible'] as bool,
          );
        })
        .toList(growable: false);
    final provenance = Map<String, dynamic>.from(response['provenance'] as Map);
    final catalogPhase = local(response['catalogPhaseInstantUtc']);
    final computedPhase = local(response['computedPhaseInstantUtc']);
    final catalogEclipsePeak = eclipse == null
        ? null
        : local(eclipse['catalogPeakUtc']);
    final computedEclipsePeak = eclipse == null
        ? null
        : local(eclipse['computedPeakUtc']);
    final rise = local(response['riseUtc']);
    final transit = local(response['transitUtc']);
    final set = local(response['setUtc']);

    return LunarPathData(
      viewingWindowStart: rise,
      viewingWindowEnd: set,
      rise: rise,
      transit: transit,
      set: set,
      moonSamples: samples,
      eclipseContacts: contacts,
      // Catalog time remains the event identity.
      phaseInstant: catalogPhase,
      provenance: SkyInstrumentProvenance(
        source: night.companion == null
            ? night.anchor.source
            : '${night.anchor.source} + ${night.companion!.source}',
        sourceVersion: night.companion == null
            ? night.anchor.sourceVersion
            : '${night.anchor.sourceVersion} + ${night.companion!.sourceVersion}',
        calculationVersion: provenance['calculationSchemaVersion'] as String,
        astronomyEngineVersion: provenance['astronomyEngineVersion'] as String,
        catalogPhaseInstant: catalogPhase,
        computedPhaseInstant: computedPhase,
        catalogEclipsePeak: catalogEclipsePeak,
        computedEclipsePeak: computedEclipsePeak,
        elevationMeters: (provenance['elevationMeters'] as num).toDouble(),
        elevationAssumed: provenance['elevationAssumed'] as bool,
      ),
      visibility: SkyInstrumentVisibility(
        isLocal: true,
        isTimeFallback: false,
        summary:
            'Local sky for ${place.label}${provenance['elevationAssumed'] == true ? ' · sea-level elevation assumed' : ''}',
      ),
    );
  }

  static FullMoonInstrumentProvenanceMismatch _mismatchFrom(
    Map<String, dynamic> response,
  ) {
    final validation = Map<String, dynamic>.from(
      response['validation'] as Map? ?? const <String, dynamic>{},
    );
    return FullMoonInstrumentProvenanceMismatch(
      catalogPhaseInstant: DateTime.parse(
        response['catalogPhaseInstantUtc'] as String,
      ).toUtc(),
      computedPhaseInstant: DateTime.parse(
        response['computedPhaseInstantUtc'] as String,
      ).toUtc(),
      issues: (validation['issues'] as List? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }

  static String _stableHash(String input) {
    var hash = 0x811c9dc5;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash.toRadixString(16);
  }
}
