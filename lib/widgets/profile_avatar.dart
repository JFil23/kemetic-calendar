import 'package:flutter/material.dart';

import '../data/profile_avatar_glyphs.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.avatarGlyphIds = const [],
    this.radius = 20,
    this.backgroundColor = const Color(0xFF0D0D0F),
    this.foregroundColor = const Color(0xFFFFC145),
    this.borderColor,
    this.borderWidth = 0,
    this.maxInitialCharacters = 2,
  });

  final String displayName;
  final String? avatarUrl;
  final List<String> avatarGlyphIds;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final double borderWidth;
  final int maxInitialCharacters;

  @override
  Widget build(BuildContext context) {
    final normalizedGlyphIds = normalizeProfileAvatarGlyphIds(avatarGlyphIds);
    final avatarDiameter = radius * 2;

    return Container(
      width: avatarDiameter,
      height: avatarDiameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: borderColor == null || borderWidth <= 0
            ? null
            : Border.all(color: borderColor!, width: borderWidth),
      ),
      child: ClipOval(
        child: normalizedGlyphIds.isNotEmpty
            ? _GlyphAvatarPhrase(
                glyphIds: normalizedGlyphIds,
                foregroundColor: foregroundColor,
                backgroundColor: backgroundColor,
              )
            : _buildImageOrFallback(),
      ),
    );
  }

  Widget _buildImageOrFallback() {
    final trimmedUrl = avatarUrl?.trim();
    if (trimmedUrl != null && trimmedUrl.isNotEmpty) {
      return Image.network(
        trimmedUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _InitialAvatar(
          displayName: displayName,
          foregroundColor: foregroundColor,
          backgroundColor: backgroundColor,
          maxCharacters: maxInitialCharacters,
        ),
      );
    }

    return _InitialAvatar(
      displayName: displayName,
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
      maxCharacters: maxInitialCharacters,
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({
    required this.displayName,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.maxCharacters,
  });

  final String displayName;
  final Color foregroundColor;
  final Color backgroundColor;
  final int maxCharacters;

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFromDisplayName(displayName, maxCharacters);
    return ColoredBox(
      color: backgroundColor,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            initials,
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
              fontSize: 32,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlyphAvatarPhrase extends StatelessWidget {
  const _GlyphAvatarPhrase({
    required this.glyphIds,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final List<String> glyphIds;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final tokens = glyphIds
        .map((id) => kProfileGlyphTileById[id])
        .whereType<ProfileGlyphTile>()
        .map((tile) => tile.glyph)
        .where((glyph) => glyph.trim().isNotEmpty)
        .take(kMaxProfileAvatarGlyphs)
        .toList(growable: false);

    return ColoredBox(
      color: backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest.shortestSide;
          final tokenFontSize = switch (tokens.length) {
            0 || 1 => size * 0.52,
            2 => size * 0.28,
            3 => size * 0.23,
            _ => size * 0.19,
          };

          final tokenStyle = TextStyle(
            color: foregroundColor,
            fontSize: tokenFontSize,
            fontWeight: FontWeight.w700,
            height: 0.95,
            fontFamily: 'GentiumPlus',
            fontFamilyFallback: const [
              'Noto Sans Egyptian Hieroglyphs',
              'Apple Symbols',
              'Segoe UI Symbol',
              'Arial Unicode MS',
              'NotoSans',
            ],
          );

          return Padding(
            padding: EdgeInsets.all(size * 0.16),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: tokens.length <= 1
                    ? Text(
                        tokens.isEmpty ? '?' : tokens.first,
                        style: tokenStyle,
                      )
                    : Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: size * 0.04,
                        runSpacing: size * 0.02,
                        children: [
                          for (final token in tokens)
                            Text(
                              token,
                              style: tokenStyle,
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String _initialsFromDisplayName(String rawName, int maxCharacters) {
  final name = rawName.trim();
  if (name.isEmpty) return 'U';

  final words = name.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
  final initials = words
      .take(maxCharacters)
      .map(_firstSymbol)
      .join()
      .toUpperCase();

  if (initials.isNotEmpty) return initials;
  return _firstSymbol(name).toUpperCase();
}

String _firstSymbol(String text) {
  final iterator = text.runes.iterator;
  if (!iterator.moveNext()) return '';
  return String.fromCharCode(iterator.current);
}
