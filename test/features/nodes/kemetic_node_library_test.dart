import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/nodes/kemetic_node_library.dart';

void main() {
  // Immutable expectations from the user-approved editorial draft, not app output.
  final reference =
      jsonDecode(
            File(
              'test/fixtures/library/approved_library_rewrite.v3.json',
            ).readAsStringSync(),
          )['nodes']
          as Map<String, dynamic>;

  test('the complete supplied 61-article inventory is present', () {
    expect(reference.length, 61);
    expect(
      KemeticNodeLibrary.nodes.map((node) => node.id).toSet(),
      reference.keys.toSet(),
    );
  });
  for (final entry in reference.entries) {
    test('${entry.key} matches the complete supplied copy and metadata', () {
      final node = KemeticNodeLibrary.resolve(entry.key)!;
      final expected = entry.value;
      expect(
        sha256.convert(utf8.encode(node.body)).toString(),
        expected['body_sha256'],
      );
      expect(node.title, expected['title']);
      expect(node.glyph, expected['glyph']);
      expect(node.aliases, expected['aliases']);
      expect(node.isSystemOwned, isTrue);
      expect(node.body.startsWith(expected['opening_hook'] as String), isTrue);
      expect(
        node.body
            .split('\n\n')
            .where((b) => b.startsWith('## '))
            .map((b) => b.substring(3))
            .toList(),
        expected['section_headings'],
      );
      expect(
        node.body.split('\n\n').where((b) => b.startsWith('|')).toList(),
        expected['tables'],
      );
      for (final link in node.linkMap) {
        expect(node.body, contains(link.phrase));
        const letters = r'A-Za-z\u00C0-\u024F\u1E00-\u1EFF';
        expect(
          RegExp(
            '(?<![$letters])${RegExp.escape(link.phrase)}(?![$letters])',
          ).hasMatch(node.body),
          isTrue,
          reason: '${node.id}: ${link.phrase} must be a whole visible phrase',
        );
        expect(link.targetId.toLowerCase(), isNot(node.id.toLowerCase()));
        expect(KemeticNodeLibrary.resolve(link.targetId), isNotNull);
        expect(KemeticNodeLibrary.isRetired(link.targetId), isFalse);
      }
    });
  }

  test('haw displays in lowercase transliteration form', () {
    final node = KemeticNodeLibrary.resolve('haw');

    expect(node, isNotNull);
    expect(node!.title, 'ḥꜣw');
    expect(KemeticNodeLibrary.resolve('ḥꜣw')?.id, 'haw');
    expect(KemeticNodeLibrary.resolve('Ḥꜣw')?.id, 'haw');
    expect(node.aliases, contains('HAw'));
    expect(node.aliases, contains('Ḥꜣw'));
    expect(node.aliases, contains('ḥꜣw'));
    expect(node.displayAliases, contains('Haw'));
    expect(node.displayAliases, contains('Increase'));
    expect(node.displayAliases, isNot(contains('HAw')));
    expect(node.displayAliases, isNot(contains('Ḥꜣw')));
    expect(node.displayAliases, isNot(contains('ḥꜣw')));
  });

  test('library glyphs use pictorial medu neter signs', () {
    final glyphs = {
      for (final node in KemeticNodeLibrary.nodes) node.id: node.glyph,
    };
    final expectedGlyphs = <String, String>{
      'cosmic_order': '𓆄',
      'human_emergence': '𓀀',
      'ancient_african_tree': '𓆭𓀀',
      'green_sahara': '𓇅𓇾',
      'rise_of_kush_and_kemet': '𓈘𓊖',
      'serpent': '𓆙',
      'nile': '𓈘',
      'ptah': '𓊪𓏏𓎛',
      'djehuty': '𓅝',
      'shu': '𓇯𓇾',
      'declarations_of_innocence': '𓉹𓆄𓆄',
      'ausar': '𓊨𓁹',
      'aset': '𓊨',
      'heru': '𓅃',
      'isfet': '𓆙',
      'ra': '𓇳',
      'ka': '𓂓',
      'ba': '𓅽',
      'akh': '𓅜',
      'ren': '𓍷',
      'ib': '𓄣',
      'sheut': '𓋺',
      'imhotep': '𓉴',
      'sopdet': '𓇼',
      'coffin_texts': '𓏞',
      'papyrus_chester_beatty_iv': '𓏞',
      'kemet': '𓇾',
      'pyramid_texts': '𓉴𓏞',
      'hathor': '𓃒',
      'sah': '𓇼𓇼𓇼',
      'abydos': '𓊖',
      'decans': '𓇼𓇼𓇼',
      'duat': '𓇽',
      'house_of_life': '𓉐𓋹',
      'instruction_ptahhotep': '𓏞',
      'rekh_wer': '𓁹𓏞',
      'set': '𓃩',
      'shai': '𓀭',
      'haw': '𓇉𓄿𓅱𓏛𓏥',
      'offering_formula': '𓊵',
      'amduat': '𓇽',
      'instruction_amenemope': '𓏞',
      'eye_of_ra': '𓁹',
      'tomb_inscriptions': '𓏞',
      'middle_kingdom_funerary': '𓏞𓇽',
      'nebet_het': '𓎟𓉐',
      'khnum': '𓃝',
      'memphite_theology': '𓏞',
      'book_of_the_dead': '𓏞',
      'palermo_stone': '𓆳',
      'wadi_el_jarf_papyri': '𓏞',
      'false_door': '𓉿',
      'architrave': '𓉹',
      'wp_rnpt': '𓊃𓆳',
      'horizon': '𓈌',
      'akhet': '𓈗',
      'epagomenal_days': '𓏤𓏤𓏤𓏤𓏤',
      'regnal_year': '𓆳',
    };

    for (final entry in expectedGlyphs.entries) {
      expect(
        KemeticNodeLibrary.resolve(entry.key)?.glyph,
        entry.value,
        reason: entry.key,
      );
    }

    expect(
      glyphs.values.any(
        (glyph) =>
            glyph.contains('✦') || glyph.contains('✷') || glyph.contains('✵'),
      ),
      isFalse,
    );
  });

  test('all library jump link targets resolve', () {
    for (final node in KemeticNodeLibrary.nodes) {
      for (final link in node.linkMap) {
        expect(
          KemeticNodeLibrary.resolve(link.targetId),
          isNotNull,
          reason: '${node.id} links to missing node ${link.targetId}',
        );
      }
    }
  });

  test('candidate batch nodes were not kept as separate short nodes', () {
    expect(KemeticNodeLibrary.resolve('zep_tepi'), isNull);
    expect(KemeticNodeLibrary.resolve('stardust'), isNull);
    expect(KemeticNodeLibrary.resolve('supernova'), isNull);
    expect(KemeticNodeLibrary.resolve('first_maat'), isNull);
  });

  test('node ids remain unique', () {
    final ids = <String>{};

    for (final node in KemeticNodeLibrary.nodes) {
      expect(
        ids.add(node.id.toLowerCase()),
        isTrue,
        reason: 'Duplicate node id: ${node.id}',
      );
    }
  });
}
