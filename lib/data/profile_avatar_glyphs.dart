import 'dart:convert';

import 'package:flutter/foundation.dart';

// Core concept signs stay ideographic/emblematic. Phrase tiles use compact
// glyph spellings keyed to English-facing phrases, and helper tiles expose a
// small connector/sound-sign set for bridging phrases.
enum ProfileGlyphCategory { essential, divinity, phrase, helper }

class ProfileGlyphTile {
  const ProfileGlyphTile({
    required this.id,
    required this.display,
    required this.glyph,
    required this.gardiner,
    required this.category,
    required this.avatarMeaning,
  });

  final String id;
  final String display;
  final String glyph;
  final String gardiner;
  final ProfileGlyphCategory category;
  final String avatarMeaning;
}

class ProfileGlyphPhrasePreset {
  const ProfileGlyphPhrasePreset({
    required this.id,
    required this.label,
    required this.glyphIds,
  });

  final String id;
  final String label;
  final List<String> glyphIds;
}

const int kMaxProfileAvatarGlyphs = 4;

const List<ProfileGlyphTile> kProfileGlyphTiles = [
  ProfileGlyphTile(
    id: 'life',
    display: 'Life',
    glyph: '𓋹',
    gardiner: 'S34',
    category: ProfileGlyphCategory.essential,
    avatarMeaning: 'life',
  ),
  ProfileGlyphTile(
    id: 'good',
    display: 'Good / Beautiful',
    glyph: '𓄤',
    gardiner: 'F35',
    category: ProfileGlyphCategory.essential,
    avatarMeaning: 'good, beautiful',
  ),
  ProfileGlyphTile(
    id: 'stable',
    display: 'Stable',
    glyph: '𓊽',
    gardiner: 'R11',
    category: ProfileGlyphCategory.essential,
    avatarMeaning: 'stability',
  ),
  ProfileGlyphTile(
    id: 'power',
    display: 'Power / Dominion',
    glyph: '𓌀',
    gardiner: 'S40',
    category: ProfileGlyphCategory.essential,
    avatarMeaning: 'power, dominion',
  ),
  ProfileGlyphTile(
    id: 'protection',
    display: 'Protection',
    glyph: '𓎃',
    gardiner: 'V17',
    category: ProfileGlyphCategory.essential,
    avatarMeaning: 'protection',
  ),
  ProfileGlyphTile(
    id: 'peace',
    display: 'Offering / Peace',
    glyph: '𓊵',
    gardiner: 'R4',
    category: ProfileGlyphCategory.essential,
    avatarMeaning: 'offering, peace',
  ),
  ProfileGlyphTile(
    id: 'heart',
    display: 'Heart',
    glyph: '𓄣',
    gardiner: 'F34',
    category: ProfileGlyphCategory.essential,
    avatarMeaning: 'heart, mind',
  ),
  ProfileGlyphTile(
    id: 'ka',
    display: 'Ka',
    glyph: '𓂓',
    gardiner: 'D28',
    category: ProfileGlyphCategory.essential,
    avatarMeaning: 'ka',
  ),
  ProfileGlyphTile(
    id: 'ba',
    display: 'Ba',
    glyph: '𓅽',
    gardiner: 'G29',
    category: ProfileGlyphCategory.essential,
    avatarMeaning: 'ba',
  ),
  ProfileGlyphTile(
    id: 'house',
    display: 'House',
    glyph: '𓉐',
    gardiner: 'O1',
    category: ProfileGlyphCategory.essential,
    avatarMeaning: 'house',
  ),
  ProfileGlyphTile(
    id: 'path',
    display: 'Road / Path',
    glyph: '𓈈',
    gardiner: 'N31',
    category: ProfileGlyphCategory.essential,
    avatarMeaning: 'road, path',
  ),
  ProfileGlyphTile(
    id: 'water',
    display: 'Water',
    glyph: '𓈗',
    gardiner: 'N35A',
    category: ProfileGlyphCategory.essential,
    avatarMeaning: 'water',
  ),
  ProfileGlyphTile(
    id: 'sky',
    display: 'Sky',
    glyph: '𓇯',
    gardiner: 'N1',
    category: ProfileGlyphCategory.essential,
    avatarMeaning: 'sky',
  ),
  ProfileGlyphTile(
    id: 'earth',
    display: 'Land / Earth',
    glyph: '𓇾',
    gardiner: 'N16',
    category: ProfileGlyphCategory.essential,
    avatarMeaning: 'land, earth',
  ),
  ProfileGlyphTile(
    id: 'sun',
    display: 'Sun / Ra',
    glyph: '𓇳',
    gardiner: 'N5',
    category: ProfileGlyphCategory.essential,
    avatarMeaning: 'sun, Ra',
  ),
  ProfileGlyphTile(
    id: 'horizon',
    display: 'Horizon',
    glyph: '𓈌',
    gardiner: 'N27',
    category: ProfileGlyphCategory.essential,
    avatarMeaning: 'horizon',
  ),
  ProfileGlyphTile(
    id: 'star',
    display: 'Star',
    glyph: '𓇼',
    gardiner: 'N14',
    category: ProfileGlyphCategory.essential,
    avatarMeaning: 'star',
  ),
  ProfileGlyphTile(
    id: 'gold',
    display: 'Gold',
    glyph: '𓋞',
    gardiner: 'S12',
    category: ProfileGlyphCategory.essential,
    avatarMeaning: 'gold',
  ),
  ProfileGlyphTile(
    id: 'maat',
    display: 'Maat',
    glyph: '𓆄',
    gardiner: 'H6',
    category: ProfileGlyphCategory.divinity,
    avatarMeaning: 'Maat emblem',
  ),
  ProfileGlyphTile(
    id: 'aset',
    display: 'Aset',
    glyph: '𓊨',
    gardiner: 'Q1',
    category: ProfileGlyphCategory.divinity,
    avatarMeaning: 'Aset / throne emblem',
  ),
  // Phrase tiles stay glyph-only in the UI. Faulkner supplies the lexical
  // spellings; Allen's writing-system guidance supports these mixed
  // emblem/phonogram groupings for short phrases.
  ProfileGlyphTile(
    id: 'i',
    display: 'I',
    glyph: '𓇋',
    gardiner: 'M17',
    category: ProfileGlyphCategory.phrase,
    avatarMeaning: 'first-person i-sign',
  ),
  ProfileGlyphTile(
    id: 'me',
    display: 'Me',
    glyph: '𓇋',
    gardiner: 'M17',
    category: ProfileGlyphCategory.phrase,
    avatarMeaning: 'first-person i-sign',
  ),
  ProfileGlyphTile(
    id: 'my',
    display: 'My',
    glyph: '𓇋',
    gardiner: 'M17',
    category: ProfileGlyphCategory.phrase,
    avatarMeaning: 'first-person i-sign',
  ),
  ProfileGlyphTile(
    id: 'receive',
    display: 'Receive',
    glyph: '𓈙𓊃𓊪',
    gardiner: 'N37+O34+Q3',
    category: ProfileGlyphCategory.phrase,
    avatarMeaning: 'take, accept, receive',
  ),
  ProfileGlyphTile(
    id: 'increase',
    display: 'Increase',
    glyph: '𓎛𓄿𓅱',
    gardiner: 'V28+G1+G43',
    category: ProfileGlyphCategory.phrase,
    avatarMeaning: 'increase, excess',
  ),
  ProfileGlyphTile(
    id: 'pure',
    display: 'Pure',
    glyph: '𓅱𓂝𓃀',
    gardiner: 'cluster',
    category: ProfileGlyphCategory.phrase,
    avatarMeaning: 'pure, purified',
  ),
  ProfileGlyphTile(
    id: 'in',
    display: 'In / With',
    glyph: '𓅓',
    gardiner: 'G17',
    category: ProfileGlyphCategory.helper,
    avatarMeaning: 'connector and sound helper',
  ),
  ProfileGlyphTile(
    id: 'to',
    display: 'To / For',
    glyph: '𓈖',
    gardiner: 'N35',
    category: ProfileGlyphCategory.helper,
    avatarMeaning: 'connector and sound helper',
  ),
  ProfileGlyphTile(
    id: 'toward',
    display: 'Toward / About',
    glyph: '𓂋',
    gardiner: 'D21',
    category: ProfileGlyphCategory.helper,
    avatarMeaning: 'connector and sound helper',
  ),
  ProfileGlyphTile(
    id: 'w_helper',
    display: 'W Helper',
    glyph: '𓅱',
    gardiner: 'G43',
    category: ProfileGlyphCategory.helper,
    avatarMeaning: 'sound helper',
  ),
  ProfileGlyphTile(
    id: 't_helper',
    display: 'T Helper',
    glyph: '𓏏',
    gardiner: 'X1',
    category: ProfileGlyphCategory.helper,
    avatarMeaning: 'sound helper',
  ),
  ProfileGlyphTile(
    id: 'k_helper',
    display: 'K Helper',
    glyph: '𓎡',
    gardiner: 'V31',
    category: ProfileGlyphCategory.helper,
    avatarMeaning: 'sound helper',
  ),
  ProfileGlyphTile(
    id: 'f_helper',
    display: 'F Helper',
    glyph: '𓆑',
    gardiner: 'I9',
    category: ProfileGlyphCategory.helper,
    avatarMeaning: 'sound helper',
  ),
];

final Map<String, ProfileGlyphTile> kProfileGlyphTileById = {
  for (final tile in kProfileGlyphTiles) tile.id: tile,
};

const Map<String, List<String>> kLegacyProfileGlyphPhraseUpgrades = {
  'maat|increase_me': ['maat', 'increase', 'me'],
  'maat|horizon|ka': ['maat', 'increase', 'me'],
  'receive_i|aset': ['i', 'receive', 'aset'],
  'heart|aset': ['i', 'receive', 'aset'],
  'ba|good': ['ba', 'my', 'pure'],
};

const List<ProfileGlyphPhrasePreset> kProfileGlyphPhrasePresets = [
  ProfileGlyphPhrasePreset(
    id: 'maat_increases_me',
    label: 'Maat increases me',
    glyphIds: ['maat', 'increase', 'me'],
  ),
  ProfileGlyphPhrasePreset(
    id: 'i_receive_aset',
    label: 'I receive Aset',
    glyphIds: ['i', 'receive', 'aset'],
  ),
  ProfileGlyphPhrasePreset(
    id: 'my_ba_is_pure',
    label: 'My ba is pure',
    glyphIds: ['ba', 'my', 'pure'],
  ),
];

List<ProfileGlyphTile> profileGlyphTilesForCategory(
  ProfileGlyphCategory category,
) {
  return kProfileGlyphTiles
      .where((tile) => tile.category == category)
      .toList(growable: false);
}

List<String> normalizeProfileAvatarGlyphIds(Iterable<String> rawIds) {
  final sanitizedInput = rawIds
      .map((raw) => raw.trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);

  final legacyUpgrade =
      kLegacyProfileGlyphPhraseUpgrades[sanitizedInput.join('|')];
  final sourceIds = legacyUpgrade ?? sanitizedInput;

  final normalized = <String>[];

  for (final id in sourceIds) {
    if (!kProfileGlyphTileById.containsKey(id)) continue;
    normalized.add(id);
    if (normalized.length >= kMaxProfileAvatarGlyphs) {
      break;
    }
  }

  return List<String>.unmodifiable(normalized);
}

List<String> parseProfileAvatarGlyphIds(dynamic raw) {
  if (raw == null) return const [];

  if (raw is List) {
    return normalizeProfileAvatarGlyphIds(raw.map((item) => '$item'));
  }

  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return normalizeProfileAvatarGlyphIds(decoded.map((item) => '$item'));
      }
    } catch (_) {
      return normalizeProfileAvatarGlyphIds(trimmed.split(','));
    }
  }

  return const [];
}

String profileGlyphPhraseGlyphs(Iterable<String> ids) {
  return normalizeProfileAvatarGlyphIds(ids)
      .map((id) => kProfileGlyphTileById[id]?.glyph)
      .whereType<String>()
      .where((glyph) => glyph.trim().isNotEmpty)
      .join(' ')
      .trim();
}

String profileGlyphPhraseMeaning(Iterable<String> ids) {
  final normalized = normalizeProfileAvatarGlyphIds(ids);
  if (normalized.isEmpty) return '';

  for (final preset in kProfileGlyphPhrasePresets) {
    if (listEquals(preset.glyphIds, normalized)) {
      return preset.label;
    }
  }

  return normalized
      .map((id) => kProfileGlyphTileById[id]?.display)
      .whereType<String>()
      .join(' · ');
}
