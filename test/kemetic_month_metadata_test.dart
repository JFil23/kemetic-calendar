import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';

void main() {
  group('Structural Integrity', () {
    test('Array perfectly aligned (id == index)', () {
      for (int id = 1; id <= 13; id++) {
        expect(kKemeticMonths[id].id, id,
            reason: 'Month at index $id has ID ${kKemeticMonths[id].id}');
      }
    });

    test('Exactly 14 elements (sentinel + 13 months)', () {
      expect(kKemeticMonths.length, 14);
    });

    test('All keys are unique, lowercase, no spaces', () {
      final keys = kKemeticMonths.skip(1).map((m) => m.key).toList();
      final uniqueKeys = keys.toSet();
      
      expect(keys.length, uniqueKeys.length, reason: 'Duplicate keys found');
      
      for (var key in keys) {
        expect(key, equals(key.toLowerCase()), reason: 'Key "$key" not lowercase');
        expect(key.contains(' '), false, reason: 'Key "$key" has spaces');
      }
    });

    test('CRITICAL: All aliases globally unique', () {
      final seen = <String, int>{};
      
      for (final m in kKemeticMonths.skip(1)) {
        for (final alias in m.searchAliases) {
          final normalized = normalizeForMatch(alias);
          
          if (seen.containsKey(normalized)) {
            fail('COLLISION: "$alias" → "$normalized" in Month ${m.id} and ${seen[normalized]}');
          }
          
          seen[normalized] = m.id;
        }
      }
      
      // Should have many unique entries
      expect(seen.length, greaterThan(50));
    });

    test('Alias map builds successfully', () {
      expect(aliasIndexSize(), greaterThan(50));
    });

    test('All fields non-empty', () {
      for (var m in kKemeticMonths.skip(1)) {
        expect(m.displayShort, isNotEmpty, reason: 'Month ${m.id} displayShort empty');
        expect(m.displayTransliteration, isNotEmpty, reason: 'Month ${m.id} transliteration empty');
        expect(m.hellenized, isNotEmpty, reason: 'Month ${m.id} hellenized empty');
        expect(m.searchAliases, isNotEmpty, reason: 'Month ${m.id} has no aliases');
      }
    });
  });

  group('Month 2 Fix - THE PRIMARY VALIDATION', () {
    test('Month 2 displays Mnḫt (NOT Pȝ ỉp.t)', () {
      final m2 = getMonthById(2);
      expect(m2.displayTransliteration, 'Mnḫt');
      expect(m2.displayFull, 'Paopi (Mnḫt)');
      expect(m2.displayShort, 'Paopi');
      expect(m2.transliterationFull, 'Menkhet');
      expect(m2.hellenized, 'Phaophi');
    });

    test('Month 2 display NEVER contains wrong notation', () {
      final m2 = getMonthById(2);
      expect(m2.displayFull.contains('Pȝ ỉp.t'), false);
      expect(m2.displayFull.contains('ỉpt'), false);
      expect(m2.displayTransliteration.contains('ỉpt'), false);
    });

    test('Month 11 correctly owns Pȝ ỉp.t notation', () {
      final m11 = getMonthById(11);
      expect(m11.displayTransliteration, 'ỉpt-ḥmt');
      expect(m11.searchAliases, contains('Pȝ ỉp.t'));
    });

    test('Pȝ ỉp.t resolves to Month 11 (not 2)', () {
      expect(monthIdFromAlias('Pȝ ỉp.t'), 11);
      expect(monthIdFromAlias('Pa ip.t'), 11);
      expect(monthIdFromAlias('Paipt'), 11);
    });

    test('All Paopi aliases resolve to Month 2', () {
      expect(monthIdFromAlias('Paopi'), 2);
      expect(monthIdFromAlias('Phaophi'), 2);
      expect(monthIdFromAlias('Menkhet'), 2);
      expect(monthIdFromAlias('Mnḫt'), 2);
      expect(monthIdFromAlias('Mnkht'), 2); // ASCII
    });
  });

  group('Normalization Strength', () {
    test('Handles diacritics', () {
      expect(monthIdFromAlias('Mnḫt'), 2);
      expect(monthIdFromAlias('Mnkht'), 2); // ASCII version
    });

    test('Collapses separators', () {
      expect(monthIdFromAlias('Menkhet'), 2);
      expect(monthIdFromAlias('Men-khet'), 2);
      expect(monthIdFromAlias('Men khet'), 2);
    });

    test('Case insensitive', () {
      expect(monthIdFromAlias('PAOPI'), 2);
      expect(monthIdFromAlias('paopi'), 2);
      expect(monthIdFromAlias('PaOpI'), 2);
    });

    test('Precomposed character handling', () {
      // These get ASCII-mapped in normalizeForMatch
      expect(normalizeForMatch('Ḥwt-Ḥr'), normalizeForMatch('Hwt-Hr'));
      expect(normalizeForMatch('Ḏḥwty'), normalizeForMatch('Djhwty'));
    });
    
    test('Removes parentheses and all non-alphanumerics', () {
      // CRITICAL: displayFull includes parentheses
      expect(monthIdFromAlias('Paopi (Mnḫt)'), 2);
      expect(monthIdFromAlias('Thoth (Ḏḥwty)'), 1);
      expect(monthIdFromAlias('Hathor (Ḥwt-Ḥr)'), 3);
    });
    
    test('Handles smart quotes and dashes', () {
      expect(normalizeForMatch('\u2018Paopi\u2019'), 'paopi');
      expect(normalizeForMatch('\u201CPaopi\u201D'), 'paopi');
      expect(normalizeForMatch('Pa\u2013opi'), 'paopi');
      expect(normalizeForMatch('Pa\u2014opi'), 'paopi');
    });
  });
  
  group('Performance Budget', () {
    test('Alias map builds quickly (<20ms for CI)', () {
      final sw = Stopwatch()..start();
      final rebuilt = rebuildAliasMapForTest();
      sw.stop();
      
      expect(rebuilt.length, greaterThan(50));
      expect(sw.elapsedMilliseconds, lessThan(20),
          reason: 'Alias map build took ${sw.elapsedMilliseconds}ms');
    });
  });

  group('Round-trip Integrity', () {
    test('All displayFull strings resolve back', () {
      for (var m in kKemeticMonths.skip(1)) {
        final resolved = monthIdFromAlias(m.displayFull);
        expect(resolved, m.id,
            reason: '${m.displayFull} failed round-trip');
      }
    });

    test('All displayShort strings resolve back', () {
      for (var m in kKemeticMonths.skip(1)) {
        final resolved = monthIdFromAlias(m.displayShort);
        expect(resolved, m.id);
      }
    });

    test('All hellenized names resolve back', () {
      for (var m in kKemeticMonths.skip(1)) {
        final resolved = monthIdFromAlias(m.hellenized);
        expect(resolved, m.id);
      }
    });
  });

  group('Search Quality', () {
    test('Exact match wins', () {
      final results = searchMonths('Paopi');
      expect(results.length, 1);
      expect(results.first.id, 2);
    });

    test('Prefix matches are prioritized', () {
      final results = searchMonths('Pa');
      expect(results, isNotEmpty);
      expect(results.first.id, isIn([2, 11])); // Paopi or Pa-Ipi
    });

    test('Results limited and deterministic', () {
      final r1 = searchMonths('a', maxResults: 3);
      final r2 = searchMonths('a', maxResults: 3);
      
      expect(r1.length, lessThanOrEqualTo(3));
      expect(r1.map((m) => m.id), equals(r2.map((m) => m.id)));
    });

    test('Results sorted by ID', () {
      final results = searchMonths('e'); // Should match many
      if (results.length > 1) {
        for (int i = 1; i < results.length; i++) {
          expect(results[i].id, greaterThan(results[i - 1].id));
        }
      }
    });
  });

  group('Season Helpers', () {
    test('Helper functions work correctly', () {
      expect(isAkhet(1), true);
      expect(isAkhet(2), true);
      expect(isPeret(5), true);
      expect(isShemu(9), true);
      expect(isEpagomenal(13), true);
    });

    test('Season name function', () {
      expect(getSeasonName(1), 'Akhet');
      expect(getSeasonName(5), 'Peret');
      expect(getSeasonName(9), 'Shemu');
    });
  });

  group('API Stability', () {
    test('getMonthById throws on invalid', () {
      expect(() => getMonthById(0), throwsRangeError);
      expect(() => getMonthById(14), throwsRangeError);
      expect(() => getMonthById(-1), throwsRangeError);
    });

    test('Legacy key redirect works', () {
      final m = getMonthByKey('rekhned jes'); // Old broken key
      expect(m?.id, 7);
    });
  });
}

