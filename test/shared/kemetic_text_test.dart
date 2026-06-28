import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/nodes/kemetic_node_library.dart';
import 'package:mobile/shared/kemetic_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('protected Kemetic characters are detected', () {
    expect(KemeticTextGuards.containsKemeticProtectedChars('Ḥꜣw'), isTrue);
    expect(KemeticTextGuards.containsKemeticProtectedChars('ḥꜣw'), isTrue);
    expect(KemeticTextGuards.containsKemeticProtectedChars('Ma’at'), isFalse);
    expect(KemeticTextGuards.containsKemeticProtectedChars('Maʿat'), isTrue);
    expect(KemeticTextGuards.containsKemeticProtectedChars('𓆄'), isTrue);
    expect(
      KemeticTextGuards.containsKemeticProtectedChars(
        String.fromCharCode(0x13430),
      ),
      isTrue,
    );
  });

  test('protected transliteration switches away from decorative fonts', () {
    const decorative = TextStyle(fontFamily: 'CormorantGaramond');

    final protected = KemeticTypography.protect(decorative, 'Ḥꜣw');
    final ordinary = KemeticTypography.protect(decorative, 'Cosmic Order');

    expect(protected.fontFamily, KemeticTypography.kemeticLatinFontFamily);
    expect(
      protected.fontFamilyFallback,
      contains(KemeticTypography.kemeticLatinFontFamily),
    );
    expect(ordinary.fontFamily, 'CormorantGaramond');
  });

  test('medu neter glyphs receive hieroglyph font fallback', () {
    final protected = KemeticTypography.protect(
      const TextStyle(fontFamily: 'CormorantGaramond'),
      '𓆄',
    );

    expect(
      protected.fontFamilyFallback,
      contains(KemeticTypography.meduNeterFontFamily),
    );
  });

  test('mixed transliteration and glyph text keeps both protected stacks', () {
    final protected = KemeticTypography.protect(
      const TextStyle(fontFamily: 'CormorantGaramond'),
      'Ḥꜣw 𓆄',
    );

    expect(protected.fontFamily, KemeticTypography.kemeticLatinFontFamily);
    expect(
      protected.fontFamilyFallback,
      contains(KemeticTypography.meduNeterFontFamily),
    );
  });

  test('external text converts protected forms safely', () {
    expect(KemeticExternalText.asciiSafe('Ḥꜣw'), 'HAw');
    expect(KemeticExternalText.asciiSafe('ḥꜣw'), 'HAw');
    expect(KemeticExternalText.asciiSafe('Ma’at'), "Ma'at");
    expect(KemeticExternalText.asciiSafe('𓆄 Ma’at'), "Ma'at");
    expect(KemeticExternalText.asciiSafe('sꜣḥ'), 'sAh');
  });

  testWidgets('glyph specimen renders without widget exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: KemeticGlyphSpecimenDebugView()),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Ḥꜣw'), findsWidgets);
    expect(find.text('𓆄 𓀀 𓉹 𓂀 𓁹 𓇳 𓊖'), findsWidgets);
  });

  test('library node text can pass through protected render styles', () {
    const base = TextStyle(fontFamily: 'CormorantGaramond');
    for (final node in KemeticNodeLibrary.nodes) {
      expect(KemeticTypography.protect(base, node.title), isA<TextStyle>());
      expect(KemeticTypography.protect(base, node.body), isA<TextStyle>());
      expect(
        KemeticTypography.protectMeduNeter(base),
        isA<TextStyle>(),
        reason: 'glyph for ${node.id}: ${node.glyph}',
      );
    }
  });
}
