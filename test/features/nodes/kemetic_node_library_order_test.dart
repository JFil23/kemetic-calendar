import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/nodes/kemetic_node_library.dart';

void main() {
  test('KemeticNodeLibrary exposes nodes in canonical read order', () {
    final ids = KemeticNodeLibrary.nodes.map((node) => node.id).toList();

    expect(ids, [
      'cosmic_order',
      'human_emergence',
      'ancient_african_tree',
      'green_sahara',
      'nile',
      'kemet',
      'rise_of_kush_and_kemet',
      'maat',
      'isfet',
      'regnal_year',
      'palermo_stone',
      'wadi_el_jarf_papyri',
      'imhotep',
      'house_of_life',
      'rekh_wer',
      'ptah',
      'memphite_theology',
      'shu',
      'nut',
      'ra',
      'khepri',
      'khnum',
      'djehuty',
      'ausar',
      'aset',
      'nebet_het',
      'heru',
      'set',
      'hawk',
      'jackal',
      'serpent',
      'hathor',
      'eye_of_ra',
      'sekhmet',
      'sopdet',
      'sah',
      'decans',
      'dendera',
      'esna_temple',
      'architrave',
      'abydos',
      'duat',
      'amduat',
      'horizon',
      'ka',
      'ba',
      'akh',
      'ren',
      'ib',
      'sheut',
      'shai',
      'natron',
      'false_door',
      'offering_formula',
      'hotep',
      'tomb_inscriptions',
      'pyramid_texts',
      'middle_kingdom_funerary',
      'coffin_texts',
      'book_of_the_dead',
      'declarations_of_innocence',
      'papyrus_chester_beatty_iv',
      'instruction_ptahhotep',
      'instruction_amenemope',
      'epagomenal_days',
      'wp_rnpt',
      'akhet',
      'peret',
      'shemu',
      'renenutet',
      'haw',
    ]);
  });

  test('KemeticNodeLibrary node ids are unique', () {
    final ids = KemeticNodeLibrary.nodes.map((node) => node.id).toList();

    expect(ids.toSet().length, ids.length);
  });

  test('KemeticNodeLibrary resolves every canonical node by id', () {
    for (final node in KemeticNodeLibrary.nodes) {
      expect(KemeticNodeLibrary.resolve(node.id), same(node));
    }
  });

  test('critical library sequencing invariants are preserved', () {
    final ids = KemeticNodeLibrary.nodes.map((node) => node.id).toList();
    int indexOf(String id) => ids.indexOf(id);

    expect(indexOf('nile'), lessThan(indexOf('kemet')));
    expect(indexOf('kemet'), lessThan(indexOf('rise_of_kush_and_kemet')));

    expect(
      indexOf('pyramid_texts'),
      lessThan(indexOf('middle_kingdom_funerary')),
    );
    expect(
      indexOf('middle_kingdom_funerary'),
      lessThan(indexOf('coffin_texts')),
    );
    expect(indexOf('coffin_texts'), lessThan(indexOf('book_of_the_dead')));
    expect(
      indexOf('book_of_the_dead'),
      lessThan(indexOf('declarations_of_innocence')),
    );

    expect(indexOf('horizon'), lessThan(indexOf('ka')));
    expect(indexOf('akhet'), greaterThan(indexOf('wp_rnpt')));
    expect(indexOf('akhet'), lessThan(indexOf('peret')));
    expect(indexOf('shemu'), lessThan(indexOf('renenutet')));
    expect(indexOf('renenutet'), lessThan(indexOf('haw')));
  });
}
