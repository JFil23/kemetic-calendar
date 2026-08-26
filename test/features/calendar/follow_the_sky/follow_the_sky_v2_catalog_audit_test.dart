import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Table-driven audit of `sky_catalog_v2.json` against locked inclusion rules.
void main() {
  late SkyCatalog catalog;

  setUpAll(() {
    tzdata.initializeTimeZones();
    final raw = File(
      'assets/follow_the_sky/sky_catalog_v2.json',
    ).readAsStringSync();
    catalog = SkyCatalogRepository.parseJsonString(raw);
  });

  String civilYmd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  DateTime? primaryUtc(SkyEvent e) {
    try {
      return e.primaryInstantUtc.toUtc();
    } catch (_) {
      return null;
    }
  }

  List<SkyEvent> ofKind(SkyEventKind kind) =>
      catalog.events.where((e) => e.kind == kind).toList();

  test('inventory summary (kind / function / visibility / provisional)', () {
    final byKind = <String, int>{};
    final byFn = <String, int>{};
    final byVis = <String, int>{};
    var provisional = 0;
    for (final e in catalog.events) {
      byKind[e.kind.wireName] = (byKind[e.kind.wireName] ?? 0) + 1;
      byFn[e.function.wireName] = (byFn[e.function.wireName] ?? 0) + 1;
      byVis[e.visibilityPolicy.wireName] =
          (byVis[e.visibilityPolicy.wireName] ?? 0) + 1;
      if (e.provisional) provisional += 1;
    }
    // Printed for the Cut 1 gate report — failures below are the real gate.
    // ignore: avoid_print
    print('CATALOG_AUDIT counts byKind=$byKind');
    // ignore: avoid_print
    print('CATALOG_AUDIT counts byFunction=$byFn');
    // ignore: avoid_print
    print('CATALOG_AUDIT counts byVisibility=$byVis');
    // ignore: avoid_print
    print(
      'CATALOG_AUDIT provisional=$provisional total=${catalog.events.length}',
    );

    expect(catalog.events.length, 70);
    expect(byKind['equinox'], 3);
    expect(byKind['solstice'], 3);
    expect(byKind['fullMoon'], 19);
    expect(byKind['lunarEclipse'], 5);
    expect(byKind['solarEclipse'], 3);
    expect(byKind['meteorShower'], 19);
    expect(byKind['planetOpposition'], 4);
    expect(byKind['planetElongation'], 10);
    expect(byKind['planetConjunction'], 4);
    expect(provisional, 1); // quadrantids-2028
  });

  test('locked seasonal anchors present with correct functions', () {
    const expected = <(String id, String ymd, SkyEventFunction fn)>[
      ('autumn-equinox-2026', '2026-09-23', SkyEventFunction.measure),
      ('winter-solstice-2026', '2026-12-21', SkyEventFunction.turn),
      ('spring-equinox-2027', '2027-03-20', SkyEventFunction.measure),
      ('summer-solstice-2027', '2027-06-21', SkyEventFunction.turn),
      ('autumn-equinox-2027', '2027-09-23', SkyEventFunction.measure),
      ('winter-solstice-2027', '2027-12-22', SkyEventFunction.turn),
    ];
    for (final row in expected) {
      final e = catalog.byId(row.$1);
      expect(e, isNotNull, reason: 'missing ${row.$1}');
      expect(civilYmd(e!.primaryInstantUtc.toUtc()), row.$2);
      expect(e.function, row.$3);
      expect(e.visibilityPolicy, SkyVisibilityPolicy.global);
      expect(e.instantUtc!.isUtc, isTrue);
    }
  });

  test('locked full moons — every one in coverage window', () {
    const lockedYmds = <String>[
      '2026-08-28',
      '2026-09-26',
      '2026-10-26',
      '2026-11-24',
      '2026-12-24',
      '2027-01-22',
      '2027-02-20',
      '2027-03-22',
      '2027-04-20',
      '2027-05-20',
      '2027-06-19',
      '2027-07-18',
      '2027-08-17',
      '2027-09-15',
      '2027-10-15',
      '2027-11-14',
      '2027-12-13',
      '2028-01-12',
      '2028-02-10',
    ];
    final moons = ofKind(SkyEventKind.fullMoon);
    expect(moons.length, lockedYmds.length);
    final present = moons
        .map((e) => civilYmd(e.primaryInstantUtc.toUtc()))
        .toSet();
    expect(present, lockedYmds.toSet());
    for (final e in moons) {
      expect(e.function, SkyEventFunction.reveal);
      expect(e.visibilityPolicy, SkyVisibilityPolicy.global);
      expect(e.name, 'Full Moon');
      expect(e.instantUtc, isNotNull);
      expect(e.instantUtc!.isUtc, isTrue);
    }
  });

  test('locked lunar eclipses merged into full moons', () {
    const rows = <(String id, String fullMoonId, bool specialNotify)>[
      ('lunar-eclipse-2026-08-28', 'full-moon-2026-08-28', true),
      ('lunar-eclipse-2027-02-20', 'full-moon-2027-02-20', true),
      ('lunar-eclipse-2027-07-18', 'full-moon-2027-07-18', false),
      ('lunar-eclipse-2027-08-17', 'full-moon-2027-08-17', true),
      ('lunar-eclipse-2028-01-12', 'full-moon-2028-01-12', true),
    ];
    for (final row in rows) {
      final e = catalog.byId(row.$1)!;
      expect(e.kind, SkyEventKind.lunarEclipse);
      expect(e.mergedIntoId, row.$2);
      expect(e.function, SkyEventFunction.reconsider);
      expect(e.specialNotification, row.$3);
      expect(catalog.materializableEvents.any((x) => x.id == e.id), isFalse);
    }
  });

  test('locked solar eclipses are location-gated', () {
    const ids = [
      'solar-eclipse-2027-02-06',
      'solar-eclipse-2027-08-02',
      'solar-eclipse-2028-01-26',
    ];
    for (final id in ids) {
      final e = catalog.byId(id)!;
      expect(e.kind, SkyEventKind.solarEclipse);
      expect(e.visibilityPolicy, SkyVisibilityPolicy.locationGated);
      expect(e.function, SkyEventFunction.reconsider);
      expect(e.instantUtc!.isUtc, isTrue);
    }
  });

  test('locked meteor inclusion set (ZHR≥10 / fireball / notable)', () {
    const requiredIds = <String>[
      'orionids-2026',
      'southern-taurids-2026',
      'northern-taurids-2026',
      'leonids-2026',
      'geminids-2026',
      'ursids-2026',
      'quadrantids-2027',
      'lyrids-2027',
      'eta-aquariids-2027',
      'southern-delta-aquariids-2027',
      'alpha-capricornids-2027',
      'perseids-2027',
      'orionids-2027',
      'southern-taurids-2027',
      'northern-taurids-2027',
      'leonids-2027',
      'geminids-2027',
      'ursids-2027',
      'quadrantids-2028',
    ];
    for (final id in requiredIds) {
      final e = catalog.byId(id);
      expect(e, isNotNull, reason: 'missing meteor $id');
      expect(e!.kind, SkyEventKind.meteorShower);
      expect(e.function, SkyEventFunction.attend);
      expect(e.visibilityPolicy, SkyVisibilityPolicy.global);
      expect(e.precision, SkyEventPrecision.approximate);
      expect(
        e.instantUtc != null || e.peakWindowUtc != null,
        isTrue,
        reason: '$id needs an authoritative UTC instant or window',
      );
      if (e.instantUtc != null) {
        expect(e.instantUtc!.isUtc, isTrue, reason: id);
      }
      if (e.peakWindowUtc != null) {
        expect(e.peakWindowUtc!.startUtc.isUtc, isTrue, reason: id);
        expect(e.peakWindowUtc!.endUtc.isUtc, isTrue, reason: id);
      }
    }
    expect(catalog.byId('quadrantids-2028')!.provisional, isTrue);
  });

  test('AstroPixels seasonal anchors lock exact authoritative UTC', () {
    const expected = <(String id, String utc, SkyEventFunction fn)>[
      ('autumn-equinox-2026', '2026-09-23T00:06:00Z', SkyEventFunction.measure),
      ('winter-solstice-2026', '2026-12-21T20:50:00Z', SkyEventFunction.turn),
      ('spring-equinox-2027', '2027-03-20T20:25:00Z', SkyEventFunction.measure),
      ('summer-solstice-2027', '2027-06-21T14:11:00Z', SkyEventFunction.turn),
      ('autumn-equinox-2027', '2027-09-23T06:02:00Z', SkyEventFunction.measure),
      ('winter-solstice-2027', '2027-12-22T02:43:00Z', SkyEventFunction.turn),
    ];
    for (final row in expected) {
      final e = catalog.byId(row.$1);
      expect(e, isNotNull, reason: 'missing ${row.$1}');
      expect(e!.instantUtc, DateTime.parse(row.$2), reason: row.$1);
      expect(e.function, row.$3);
      expect(e.visibilityPolicy, SkyVisibilityPolicy.global);
      expect(e.precision, SkyEventPrecision.phase);
      expect(e.source, 'AstroPixels');
      expect(e.instantUtc!.isUtc, isTrue);
    }
  });

  test('AstroPixels full moons lock all 19 exact authoritative UTCs', () {
    const expected = <String, String>{
      'full-moon-2026-08-28': '2026-08-28T04:18:00Z',
      'full-moon-2026-09-26': '2026-09-26T16:49:00Z',
      'full-moon-2026-10-26': '2026-10-26T04:12:00Z',
      'full-moon-2026-11-24': '2026-11-24T14:53:00Z',
      'full-moon-2026-12-24': '2026-12-24T01:28:00Z',
      'full-moon-2027-01-22': '2027-01-22T12:17:00Z',
      'full-moon-2027-02-20': '2027-02-20T23:23:00Z',
      'full-moon-2027-03-22': '2027-03-22T10:44:00Z',
      'full-moon-2027-04-20': '2027-04-20T22:27:00Z',
      'full-moon-2027-05-20': '2027-05-20T10:59:00Z',
      'full-moon-2027-06-19': '2027-06-19T00:44:00Z',
      'full-moon-2027-07-18': '2027-07-18T15:45:00Z',
      'full-moon-2027-08-17': '2027-08-17T07:29:00Z',
      'full-moon-2027-09-15': '2027-09-15T23:04:00Z',
      'full-moon-2027-10-15': '2027-10-15T13:47:00Z',
      'full-moon-2027-11-14': '2027-11-14T03:26:00Z',
      'full-moon-2027-12-13': '2027-12-13T16:09:00Z',
      'full-moon-2028-01-12': '2028-01-12T04:03:00Z',
      'full-moon-2028-02-10': '2028-02-10T15:04:00Z',
    };
    final moons = ofKind(SkyEventKind.fullMoon);
    expect(moons.length, expected.length);
    for (final row in expected.entries) {
      final e = catalog.byId(row.key)!;
      expect(e.instantUtc, DateTime.parse(row.value), reason: row.key);
      expect(e.function, SkyEventFunction.reveal);
      expect(e.visibilityPolicy, SkyVisibilityPolicy.global);
      expect(e.name, 'Full Moon');
      expect(e.precision, SkyEventPrecision.phase);
      expect(e.source, 'AstroPixels');
      expect(e.instantUtc, isNotNull);
      expect(e.instantUtc!.isUtc, isTrue);
    }
  });

  test('NASA greatest-eclipse UTCs stay distinct from Full Moon anchors', () {
    const rows =
        <(String id, String fullMoonId, String utc, bool specialNotify)>[
          (
            'lunar-eclipse-2026-08-28',
            'full-moon-2026-08-28',
            '2026-08-28T04:13:00Z',
            true,
          ),
          (
            'lunar-eclipse-2027-02-20',
            'full-moon-2027-02-20',
            '2027-02-20T23:13:00Z',
            true,
          ),
          (
            'lunar-eclipse-2027-07-18',
            'full-moon-2027-07-18',
            '2027-07-18T16:03:00Z',
            false,
          ),
          (
            'lunar-eclipse-2027-08-17',
            'full-moon-2027-08-17',
            '2027-08-17T07:14:00Z',
            true,
          ),
          (
            'lunar-eclipse-2028-01-12',
            'full-moon-2028-01-12',
            '2028-01-12T04:13:00Z',
            true,
          ),
        ];
    for (final row in rows) {
      final e = catalog.byId(row.$1)!;
      expect(e.kind, SkyEventKind.lunarEclipse);
      expect(e.mergedIntoId, row.$2);
      expect(e.instantUtc, DateTime.parse(row.$3), reason: row.$1);
      expect(e.function, SkyEventFunction.reconsider);
      expect(e.specialNotification, row.$4);
      expect(e.source, 'NASA Eclipse');
      expect(e.instantUtc, isNot(catalog.byId(row.$2)!.instantUtc));
      expect(catalog.materializableEvents.any((x) => x.id == e.id), isFalse);
    }
  });

  test('NASA solar greatest-eclipse UTCs are exact and location-gated', () {
    const expected = <String, String>{
      'solar-eclipse-2027-02-06': '2027-02-06T16:00:00Z',
      'solar-eclipse-2027-08-02': '2027-08-02T10:07:00Z',
      'solar-eclipse-2028-01-26': '2028-01-26T15:08:00Z',
    };
    for (final row in expected.entries) {
      final e = catalog.byId(row.key)!;
      expect(e.kind, SkyEventKind.solarEclipse);
      expect(e.instantUtc, DateTime.parse(row.value), reason: row.key);
      expect(e.visibilityPolicy, SkyVisibilityPolicy.locationGated);
      expect(e.function, SkyEventFunction.reconsider);
      expect(e.source, 'NASA Eclipse');
      expect(e.instantUtc!.isUtc, isTrue);
    }
  });

  test('IMO meteor maxima use authoritative instants or honest ranges', () {
    const rows =
        <
          (
            String id,
            String? instant,
            String? start,
            String? end,
            String source,
          )
        >[
          (
            'orionids-2026',
            null,
            '2026-10-21T00:00:00Z',
            '2026-10-21T23:59:59Z',
            'IMO',
          ),
          (
            'southern-taurids-2026',
            null,
            '2026-11-05T00:00:00Z',
            '2026-11-05T23:59:59Z',
            'IMO',
          ),
          (
            'northern-taurids-2026',
            null,
            '2026-11-12T00:00:00Z',
            '2026-11-12T23:59:59Z',
            'IMO',
          ),
          ('leonids-2026', '2026-11-17T23:45:00Z', null, null, 'IMO'),
          (
            'geminids-2026',
            '2026-12-14T14:00:00Z',
            '2026-12-13T21:00:00Z',
            '2026-12-14T18:00:00Z',
            'IMO',
          ),
          ('ursids-2026', '2026-12-22T22:00:00Z', null, null, 'IMO'),
          (
            'quadrantids-2027',
            '2027-01-04T03:25:00Z',
            '2027-01-04T00:55:00Z',
            '2027-01-04T05:55:00Z',
            'IMO',
          ),
          ('lyrids-2027', '2027-04-23T01:40:00Z', null, null, 'IMO'),
          ('eta-aquariids-2027', '2027-05-06T09:00:00Z', null, null, 'IMO'),
          (
            'southern-delta-aquariids-2027',
            null,
            '2027-07-31T00:00:00Z',
            '2027-07-31T23:59:59Z',
            'IMO',
          ),
          (
            'alpha-capricornids-2027',
            null,
            '2027-07-31T00:00:00Z',
            '2027-07-31T23:59:59Z',
            'IMO',
          ),
          (
            'perseids-2027',
            null,
            '2027-08-13T08:00:00Z',
            '2027-08-13T10:00:00Z',
            'IMO',
          ),
          (
            'orionids-2027',
            null,
            '2027-10-22T00:00:00Z',
            '2027-10-22T23:59:59Z',
            'IMO',
          ),
          (
            'southern-taurids-2027',
            null,
            '2027-11-06T00:00:00Z',
            '2027-11-06T23:59:59Z',
            'IMO',
          ),
          (
            'northern-taurids-2027',
            null,
            '2027-11-13T00:00:00Z',
            '2027-11-13T23:59:59Z',
            'IMO',
          ),
          ('leonids-2027', '2027-11-18T06:00:00Z', null, null, 'IMO'),
          ('geminids-2027', '2027-12-14T20:00:00Z', null, null, 'IMO'),
          ('ursids-2027', '2027-12-23T04:00:00Z', null, null, 'IMO'),
          (
            'quadrantids-2028',
            '2028-01-04T10:00:00Z',
            null,
            null,
            'AstroPixels',
          ),
        ];
    expect(ofKind(SkyEventKind.meteorShower), hasLength(rows.length));
    for (final row in rows) {
      final e = catalog.byId(row.$1);
      expect(e, isNotNull, reason: 'missing meteor ${row.$1}');
      expect(e!.kind, SkyEventKind.meteorShower);
      expect(e.function, SkyEventFunction.attend);
      expect(e.instantUtc, row.$2 == null ? isNull : DateTime.parse(row.$2!));
      expect(
        e.peakWindowUtc?.startUtc,
        row.$3 == null ? isNull : DateTime.parse(row.$3!),
      );
      expect(
        e.peakWindowUtc?.endUtc,
        row.$4 == null ? isNull : DateTime.parse(row.$4!),
      );
      expect(e.visibilityPolicy, SkyVisibilityPolicy.global);
      expect(e.precision, SkyEventPrecision.approximate);
      expect(e.source, row.$5);
      if (e.instantUtc != null && e.peakWindowUtc != null) {
        expect(e.instantUtc!.isBefore(e.peakWindowUtc!.startUtc), isFalse);
        expect(e.instantUtc!.isAfter(e.peakWindowUtc!.endUtc), isFalse);
      }
    }
    expect(catalog.byId('quadrantids-2028')!.provisional, isTrue);
  });

  test('2027 Leonid modeled encounters are separate from regular maximum', () {
    final leonids = catalog.byId('leonids-2027')!;
    expect(leonids.instantUtc, DateTime.parse('2027-11-18T06:00:00Z'));
    const windows = <(String start, String end)>[
      ('2027-11-17T22:00:00Z', '2027-11-17T22:00:00Z'),
      ('2027-11-18T20:02:00Z', '2027-11-18T20:02:00Z'),
      ('2027-11-19T12:23:00Z', '2027-11-19T12:23:00Z'),
      ('2027-11-20T04:18:00Z', '2027-11-20T04:25:00Z'),
      ('2027-11-20T10:10:00Z', '2027-11-20T10:10:00Z'),
    ];
    expect(leonids.enhancedWindows, hasLength(windows.length));
    for (var i = 0; i < windows.length; i++) {
      expect(
        leonids.enhancedWindows[i].startUtc,
        DateTime.parse(windows[i].$1),
      );
      expect(leonids.enhancedWindows[i].endUtc, DateTime.parse(windows[i].$2));
    }
  });

  test('locked planetary oppositions / elongations / ≤1.5° conjunctions', () {
    const oppositions = <String>[
      'saturn-opposition-2026-10-04',
      'jupiter-opposition-2027-02-11',
      'mars-opposition-2027-02-19',
      'saturn-opposition-2027-10-18',
    ];
    for (final id in oppositions) {
      final e = catalog.byId(id)!;
      expect(e.kind, SkyEventKind.planetOpposition);
      expect(e.function, SkyEventFunction.attend);
      expect(e.visibilityPolicy, SkyVisibilityPolicy.global);
      expect(e.precision, SkyEventPrecision.approximate);
    }

    const elongations = <String>[
      'mercury-elongation-2026-10-12',
      'mercury-elongation-2026-11-20',
      'venus-elongation-2027-01-03',
      'mercury-elongation-2027-02-03',
      'mercury-elongation-2027-03-17',
      'mercury-elongation-2027-05-28',
      'mercury-elongation-2027-07-15',
      'mercury-elongation-2027-09-24',
      'mercury-elongation-2027-11-04',
      'mercury-elongation-2028-01-17',
    ];
    for (final id in elongations) {
      final e = catalog.byId(id)!;
      expect(e.kind, SkyEventKind.planetElongation);
      expect(e.function, SkyEventFunction.attend);
      expect(e.visibilityPolicy, SkyVisibilityPolicy.global);
      expect(e.precision, SkyEventPrecision.approximate);
    }

    // Conjunctions: naked-eye ≤1.5° and location-gated.
    const conjunctions = <(String id, String maxSepNote)>[
      ('mars-jupiter-conjunction-2026-11-16', '1.2'),
      ('venus-saturn-conjunction-2027-05-07', '0.6'),
      ('venus-mars-conjunction-2027-11-25', '0.3'),
      ('mercury-mars-conjunction-2028-01-09', '0.7'),
    ];
    for (final row in conjunctions) {
      final e = catalog.byId(row.$1)!;
      expect(e.kind, SkyEventKind.planetConjunction);
      expect(e.visibilityPolicy, SkyVisibilityPolicy.locationGated);
      expect(e.function, SkyEventFunction.attend);
      expect(e.precision, SkyEventPrecision.approximate);
      expect(e.notes, contains(row.$2));
      final sep = RegExp(r'~([\d.]+)°').firstMatch(e.notes ?? '');
      expect(sep, isNotNull, reason: '${e.id} needs ~X° separation note');
      final deg = double.parse(sep!.group(1)!);
      expect(deg, lessThanOrEqualTo(1.5), reason: '${e.id} exceeds ≤1.5° rule');
    }
  });

  test('AstroPixels planetary source hours replace noon placeholders', () {
    const expected = <String, String>{
      'saturn-opposition-2026-10-04': '2026-10-04T12:00:00Z',
      'mercury-elongation-2026-10-12': '2026-10-12T10:00:00Z',
      'mars-jupiter-conjunction-2026-11-16': '2026-11-16T04:00:00Z',
      'mercury-elongation-2026-11-20': '2026-11-20T23:00:00Z',
      'venus-elongation-2027-01-03': '2027-01-03T19:00:00Z',
      'mercury-elongation-2027-02-03': '2027-02-03T06:00:00Z',
      'jupiter-opposition-2027-02-11': '2027-02-11T00:00:00Z',
      'mars-opposition-2027-02-19': '2027-02-19T15:00:00Z',
      'mercury-elongation-2027-03-17': '2027-03-17T07:00:00Z',
      'venus-saturn-conjunction-2027-05-07': '2027-05-07T16:00:00Z',
      'mercury-elongation-2027-05-28': '2027-05-28T10:00:00Z',
      'mercury-elongation-2027-07-15': '2027-07-15T19:00:00Z',
      'mercury-elongation-2027-09-24': '2027-09-24T22:00:00Z',
      'saturn-opposition-2027-10-18': '2027-10-18T00:00:00Z',
      'mercury-elongation-2027-11-04': '2027-11-04T09:00:00Z',
      'venus-mars-conjunction-2027-11-25': '2027-11-25T01:00:00Z',
      'mercury-mars-conjunction-2028-01-09': '2028-01-09T00:00:00Z',
      'mercury-elongation-2028-01-17': '2028-01-17T17:00:00Z',
    };
    for (final row in expected.entries) {
      final event = catalog.byId(row.key)!;
      expect(event.instantUtc, DateTime.parse(row.value), reason: row.key);
      expect(event.precision, SkyEventPrecision.approximate);
      expect(event.source, 'AstroPixels');
      expect(event.instantUtc!.minute, 0);
      expect(event.instantUtc!.second, 0);
    }
  });

  test('Pacific civil dates derive from source UTC, not placeholder noon', () {
    final pacific = tz.getLocation('America/Los_Angeles');
    const expected = <String, String>{
      'southern-taurids-2026': '2026-11-05',
      'quadrantids-2027': '2027-01-03',
      'lyrids-2027': '2027-04-22',
      'perseids-2027': '2027-08-13',
      'mars-jupiter-conjunction-2026-11-16': '2026-11-15',
      'jupiter-opposition-2027-02-11': '2027-02-10',
      'saturn-opposition-2027-10-18': '2027-10-17',
      'mercury-mars-conjunction-2028-01-09': '2028-01-08',
    };
    for (final row in expected.entries) {
      final local = tz.TZDateTime.from(
        catalog.byId(row.key)!.primaryInstantUtc,
        pacific,
      );
      expect(civilYmd(local), row.value, reason: row.key);
    }
  });

  test(
    'no duplicates; every event has correct system function; UTC not local',
    () {
      final ids = catalog.events.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);

      final failures = <String>[];
      for (final e in catalog.events) {
        final expected = SkyEventFunctionX.forKind(e.kind.wireName);
        if (e.function != expected) {
          failures.add(
            '${e.id}: function ${e.function.wireName} != ${expected.wireName}',
          );
        }
        final inst = primaryUtc(e);
        if (inst == null) {
          failures.add('${e.id}: missing UTC instant/window');
          continue;
        }
        if (!inst.isUtc) {
          failures.add('${e.id}: primary instant is not UTC');
        }
        // Guard against accidental local civil times stored without Z:
        // ISO from asset must parse as UTC (isUtc true after toUtc()).
        if (e.instantUtc != null) {
          final raw = e.toJson()['instantUtc'] as String;
          if (!raw.endsWith('Z') && !raw.contains('+00:00')) {
            failures.add('${e.id}: instantUtc not Zulu: $raw');
          }
        }
        // Forbidden inclusion classes
        final lower = '${e.id} ${e.name}'.toLowerCase();
        if (lower.contains('new moon') ||
            lower.contains('uranus') ||
            lower.contains('neptune') ||
            lower.contains('perigee') ||
            lower.contains('apogee')) {
          failures.add('${e.id}: forbidden inclusion class');
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    },
  );

  test('location-gated set is exactly solar eclipses + close conjunctions', () {
    final gated = catalog.events
        .where((e) => e.visibilityPolicy == SkyVisibilityPolicy.locationGated)
        .map((e) => e.id)
        .toSet();
    expect(gated, {
      'solar-eclipse-2027-02-06',
      'solar-eclipse-2027-08-02',
      'solar-eclipse-2028-01-26',
      'mars-jupiter-conjunction-2026-11-16',
      'venus-saturn-conjunction-2027-05-07',
      'venus-mars-conjunction-2027-11-25',
      'mercury-mars-conjunction-2028-01-09',
    });
  });
}
