import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';

/// Table-driven audit of `sky_catalog_v2.json` against locked inclusion rules.
void main() {
  late SkyCatalog catalog;

  setUpAll(() {
    final raw =
        File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync();
    catalog = SkyCatalogRepository.parseJsonString(raw);
  });

  String ymd(DateTime utc) {
    final d = utc.toUtc();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

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
    print('CATALOG_AUDIT provisional=$provisional total=${catalog.events.length}');

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
      expect(ymd(e!.primaryInstantUtc), row.$2);
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
    final present = moons.map((e) => ymd(e.primaryInstantUtc)).toSet();
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
      // 2026 remainder
      'orionids-2026',
      'southern-taurids-2026',
      'northern-taurids-2026',
      'leonids-2026',
      'geminids-2026',
      'ursids-2026',
      // 2027
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
      // 2028 provisional
      'quadrantids-2028',
    ];
    for (final id in requiredIds) {
      final e = catalog.byId(id);
      expect(e, isNotNull, reason: 'missing meteor $id');
      expect(e!.kind, SkyEventKind.meteorShower);
      expect(e.function, SkyEventFunction.attend);
      expect(e.peakWindowUtc, isNotNull);
      expect(e.peakWindowUtc!.startUtc.isUtc, isTrue);
      expect(e.peakWindowUtc!.endUtc.isUtc, isTrue);
      expect(e.visibilityPolicy, SkyVisibilityPolicy.global);
    }
    expect(catalog.byId('quadrantids-2028')!.provisional, isTrue);
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

  test('no duplicates; every event has correct system function; UTC not local', () {
    final ids = catalog.events.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);

    final failures = <String>[];
    for (final e in catalog.events) {
      final expected = SkyEventFunctionX.forKind(e.kind.wireName);
      if (e.function != expected) {
        failures.add('${e.id}: function ${e.function.wireName} != ${expected.wireName}');
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
  });

  test('location-gated set is exactly solar eclipses + close conjunctions', () {
    final gated = catalog.events
        .where((e) => e.visibilityPolicy == SkyVisibilityPolicy.locationGated)
        .map((e) => e.id)
        .toSet();
    expect(
      gated,
      {
        'solar-eclipse-2027-02-06',
        'solar-eclipse-2027-08-02',
        'solar-eclipse-2028-01-26',
        'mars-jupiter-conjunction-2026-11-16',
        'venus-saturn-conjunction-2027-05-07',
        'venus-mars-conjunction-2027-11-25',
        'mercury-mars-conjunction-2028-01-09',
      },
    );
  });
}
