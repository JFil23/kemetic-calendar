import 'package:flutter/material.dart';

class KemeticTextGuards {
  KemeticTextGuards._();

  static bool containsKemeticProtectedChars(String value) {
    return value.runes.any(isProtectedRune);
  }

  static bool containsEgyptianHieroglyphs(String value) {
    return value.runes.any(
      (rune) =>
          isEgyptianHieroglyphRune(rune) ||
          isEgyptianHieroglyphFormatControlRune(rune) ||
          isEgyptianHieroglyphExtendedARune(rune),
    );
  }

  static bool containsEgyptologicalLatin(String value) {
    return value.runes.any(isEgyptologicalLatinRune);
  }

  static bool isProtectedRune(int rune) {
    return isEgyptianHieroglyphRune(rune) ||
        isEgyptianHieroglyphFormatControlRune(rune) ||
        isEgyptianHieroglyphExtendedARune(rune) ||
        isEgyptologicalLatinRune(rune);
  }

  static bool isEgyptianHieroglyphRune(int rune) {
    return rune >= 0x13000 && rune <= 0x1342F;
  }

  static bool isEgyptianHieroglyphFormatControlRune(int rune) {
    return rune >= 0x13430 && rune <= 0x1345F;
  }

  static bool isEgyptianHieroglyphExtendedARune(int rune) {
    return rune >= 0x13460 && rune <= 0x143FF;
  }

  static bool isEgyptologicalLatinRune(int rune) {
    return (rune >= 0x1E00 && rune <= 0x1EFF) ||
        (rune >= 0xA720 && rune <= 0xA7FF) ||
        rune == 0x02BE ||
        rune == 0x02BF ||
        (rune >= 0x0300 && rune <= 0x036F);
  }
}

class KemeticTypography {
  KemeticTypography._();

  static const String kemeticLatinFontFamily = 'GentiumPlus';
  static const String meduNeterFontFamily = 'Noto Sans Egyptian Hieroglyphs';

  static const List<String> kemeticLatinFallback = [
    'GentiumPlus',
    'NotoSans',
    'Roboto',
    'Arial',
    'sans-serif',
  ];

  static const List<String> meduNeterFallback = [
    'Noto Sans Egyptian Hieroglyphs',
    'NotoSansEgyptianHieroglyphs',
    'GentiumPlus',
    'NotoSans',
    'Roboto',
    'Arial',
    'sans-serif',
  ];

  static TextStyle protect(
    TextStyle base,
    String value, {
    bool forceKemeticLatin = false,
    bool forceMeduNeter = false,
  }) {
    if (forceMeduNeter) {
      return base.copyWith(
        fontFamily: meduNeterFontFamily,
        fontFamilyFallback: meduNeterFallback,
      );
    }

    final hasProtected =
        forceKemeticLatin ||
        KemeticTextGuards.containsKemeticProtectedChars(value);
    if (!hasProtected) return base;

    final hasEgyptianHieroglyphs =
        KemeticTextGuards.containsEgyptianHieroglyphs(value);
    final hasEgyptologicalLatin =
        forceKemeticLatin ||
        KemeticTextGuards.containsEgyptologicalLatin(value);
    if (hasEgyptologicalLatin) {
      return base.copyWith(
        fontFamily: kemeticLatinFontFamily,
        fontFamilyFallback: _mergeFallbacks(
          hasEgyptianHieroglyphs ? meduNeterFallback : kemeticLatinFallback,
          base,
        ),
      );
    }

    if (hasEgyptianHieroglyphs) {
      return base.copyWith(
        fontFamilyFallback: _mergeFallbacks(meduNeterFallback, base),
      );
    }

    return base;
  }

  static TextStyle protectMeduNeter(TextStyle base) {
    return protect(base, '', forceMeduNeter: true);
  }

  static List<String> _mergeFallbacks(
    List<String> protectedFallbacks,
    TextStyle base,
  ) {
    final merged = <String>[];
    void add(String? family) {
      if (family == null || family.trim().isEmpty) return;
      if (!merged.contains(family)) merged.add(family);
    }

    for (final family in protectedFallbacks) {
      add(family);
    }
    add(base.fontFamily);
    for (final family in base.fontFamilyFallback ?? const <String>[]) {
      add(family);
    }
    return merged;
  }
}

class KemeticText extends StatelessWidget {
  const KemeticText(
    this.data, {
    super.key,
    required this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.strutStyle,
    this.textHeightBehavior,
    this.forceKemeticLatin = false,
  });

  final String data;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final StrutStyle? strutStyle;
  final TextHeightBehavior? textHeightBehavior;
  final bool forceKemeticLatin;

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      strutStyle: strutStyle,
      textHeightBehavior: textHeightBehavior,
      style: KemeticTypography.protect(
        style,
        data,
        forceKemeticLatin: forceKemeticLatin,
      ),
    );
  }
}

class MeduGlyphText extends StatelessWidget {
  const MeduGlyphText(
    this.glyph, {
    super.key,
    required this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.strutStyle,
    this.textHeightBehavior,
  });

  final String glyph;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final StrutStyle? strutStyle;
  final TextHeightBehavior? textHeightBehavior;

  @override
  Widget build(BuildContext context) {
    return Text(
      glyph,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      strutStyle: strutStyle,
      textHeightBehavior: textHeightBehavior,
      style: KemeticTypography.protectMeduNeter(style),
    );
  }
}

class KemeticExternalText {
  KemeticExternalText._();

  static const Map<int, String> _asciiByRune = {
    0x02BE: "'",
    0x02BF: "'",
    0x2018: "'",
    0x2019: "'",
    0x201C: '"',
    0x201D: '"',
    0x2013: '-',
    0x2014: '-',
    0x2026: '...',
    0x0160: 'Sh',
    0x0161: 'sh',
    0x1E0E: 'Dj',
    0x1E0F: 'dj',
    0x1E24: 'H',
    0x1E25: 'h',
    0x1E2A: 'Kh',
    0x1E2B: 'kh',
    0x1E6E: 'Tj',
    0x1E6F: 'tj',
    0x1E96: 'kh',
    0x1EC8: 'I',
    0x1EC9: 'i',
    0xA722: 'A',
    0xA723: 'A',
    0xA724: 'A',
    0xA725: 'a',
  };

  static String asciiSafe(String value) {
    var source = value
        .replaceAll('Ḥꜣw', 'HAw')
        .replaceAll('ḥꜣw', 'HAw')
        .replaceAll('Ma’at', "Ma'at")
        .replaceAll('Maʿat', "Ma'at");

    final buffer = StringBuffer();
    for (final rune in source.runes) {
      if (KemeticTextGuards.isEgyptianHieroglyphRune(rune) ||
          KemeticTextGuards.isEgyptianHieroglyphFormatControlRune(rune) ||
          KemeticTextGuards.isEgyptianHieroglyphExtendedARune(rune) ||
          (rune >= 0x0300 && rune <= 0x036F)) {
        continue;
      }
      final mapped = _asciiByRune[rune];
      if (mapped != null) {
        buffer.write(mapped);
        continue;
      }
      if (rune <= 0x7E) {
        buffer.writeCharCode(rune);
      } else if (_isWhitespace(rune)) {
        buffer.write(' ');
      }
    }

    source = buffer.toString();
    return source
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' *\n+ *'), '\n')
        .trim();
  }

  static bool _isWhitespace(int rune) {
    return rune == 0x00A0 ||
        rune == 0x1680 ||
        (rune >= 0x2000 && rune <= 0x200A) ||
        rune == 0x2028 ||
        rune == 0x2029 ||
        rune == 0x202F ||
        rune == 0x205F ||
        rune == 0x3000;
  }
}

class KemeticGlyphSpecimenDebugView extends StatelessWidget {
  const KemeticGlyphSpecimenDebugView({super.key});

  static const List<String> _specimens = [
    'ḥꜣw',
    'HAw',
    'Ma’at',
    "Ma'at",
    'ꜣ ꜥ ḥ Ḥ ḏ ṯ š ḫ ẖ',
    '𓆄 𓀀 𓉹 𓂀 𓁹 𓇳 𓊖',
    'Cosmic Order',
    'Ancient African Tree',
    'Rise of Kush and Kemet',
    'Book of Coming Forth by Day',
    'Declarations of Innocence',
  ];

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(color: Colors.white, fontSize: 16, height: 1.25);
    const title = TextStyle(
      color: Color(0xFFD4AF37),
      fontSize: 26,
      fontWeight: FontWeight.w700,
      height: 1.1,
      fontFamily: 'CormorantGaramond',
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final specimen in _specimens) ...[
              KemeticText(specimen, style: title),
              const SizedBox(height: 6),
              KemeticText(specimen, style: base),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
