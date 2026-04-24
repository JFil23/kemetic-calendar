import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/profile_avatar_glyphs.dart';
import 'package:mobile/data/profile_model.dart';
import 'package:mobile/widgets/profile_avatar.dart';

void main() {
  group('profile avatar glyph helpers', () {
    test('normalizes glyph ids from json arrays', () {
      final ids = parseProfileAvatarGlyphIds(
        '["maat","unknown","ba","pure","sun"]',
      );

      expect(ids, ['maat', 'ba', 'pure', 'sun']);
    });

    test('preserves repeated helper signs in phrase order', () {
      final ids = parseProfileAvatarGlyphIds(
        '["i","to","i","w_helper","unknown"]',
      );

      expect(ids, ['i', 'to', 'i', 'w_helper']);
    });

    test('upgrades legacy launch presets to phrase glyph ids', () {
      expect(parseProfileAvatarGlyphIds('["maat","increase_me"]'), [
        'maat',
        'increase',
        'me',
      ]);
      expect(parseProfileAvatarGlyphIds('["receive_i","aset"]'), [
        'i',
        'receive',
        'aset',
      ]);
      expect(parseProfileAvatarGlyphIds('["ba","good"]'), ['ba', 'my', 'pure']);
    });

    test('returns glyph strings without transliteration text', () {
      expect(profileGlyphPhraseGlyphs(['i', 'receive', 'aset']), '𓇋 𓈙𓊃𓊪 𓊨');
      expect(
        profileGlyphPhraseGlyphs(['maat', 'increase', 'me']),
        '𓆄 𓎛𓄿𓅱 𓇋',
      );
      expect(profileGlyphPhraseGlyphs(['life', 'in', 'maat']), '𓋹 𓅓 𓆄');
    });

    test('restores english phrase labels for exact preset matches', () {
      expect(
        profileGlyphPhraseMeaning(['maat', 'increase', 'me']),
        'Maat increases me',
      );
      expect(
        profileGlyphPhraseMeaning(['i', 'receive', 'aset']),
        'I receive Aset',
      );
      expect(profileGlyphPhraseMeaning(['ba', 'my', 'pure']), 'My ba is pure');
    });

    test('parses avatar glyph ids from user profile json', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'display_name': 'Nebet',
        'avatar_glyphs': ['maat', 'increase', 'me'],
      });

      expect(profile.avatarGlyphIds, ['maat', 'increase', 'me']);
      expect(profile.hasGlyphAvatar, isTrue);
    });
  });

  group('ProfileAvatar widget', () {
    testWidgets('renders glyph phrase tokens when glyph ids are present', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ProfileAvatar(
                radius: 32,
                displayName: 'Maat User',
                avatarGlyphIds: ['i', 'receive', 'aset'],
              ),
            ),
          ),
        ),
      );

      expect(find.text('𓇋'), findsOneWidget);
      expect(find.text('𓈙𓊃𓊪'), findsOneWidget);
      expect(find.text('𓊨'), findsOneWidget);
    });

    testWidgets('falls back to initials when no image or glyph phrase exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ProfileAvatar(radius: 24, displayName: 'Aset House'),
            ),
          ),
        ),
      );

      expect(find.text('AH'), findsOneWidget);
    });
  });
}
