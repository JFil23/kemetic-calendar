import 'package:flutter/material.dart';

// ---- Unified palette (one source of truth) ----
const Color goldLight = Color(0xFFFFE8A3);
const Color gold = Color(0xFFD4AF37);
const Color goldDeep = Color(0xFF8A6B16);

const Color silverLight = Color(0xFFF5F7FA);
const Color silver = Color(0xFFC8CCD2);
const Color silverDeep = Color(0xFF7A838C);

const Color blueLight = Color(0xFFBFE0FF);
const Color blue = Color(0xFF4DA3FF);
const Color blueDeep = Color(0xFF0B64C0);

// ---- Unified glossy gradients ----
const Gradient goldGloss = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [goldLight, gold, goldDeep],
  stops: [0.0, 0.55, 1.0],
);

const Gradient silverGloss = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [silverLight, silver, silverDeep],
  stops: [0.0, 0.55, 1.0],
);

const Gradient blueGloss = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [blueLight, blue, blueDeep],
  stops: [0.0, 0.55, 1.0],
);

const Gradient whiteGloss = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Colors.white, Colors.white, Colors.white],
);

// ---- Shared glossy text ----
class GlossyText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient gradient;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final TextAlign? textAlign;

  const GlossyText({
    super.key,
    required this.text,
    required this.style,
    required this.gradient,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final double fs = (style.fontSize ?? 16.0);
    final bool small = fs < 18.0;
    final bool unlimited = maxLines == null;

    final TextStyle masked = style.copyWith(
      color: const Color(0xFFFFFFFF),
      height: style.height,
      fontSize: (style.fontSize != null)
          ? style.fontSize!.roundToDouble()
          : null,
      letterSpacing: 0,
      fontFamily: style.fontFamily,
      fontFamilyFallback:
          style.fontFamilyFallback ??
          const ['NotoSans', 'Roboto', 'Arial', 'sans-serif'],
      shadows: small ? null : style.shadows,
    );

    return RepaintBoundary(
      child: ShaderMask(
        shaderCallback: (Rect r) => gradient.createShader(r),
        blendMode: BlendMode.srcIn,
        child: Text(
          text,
          style: masked,
          softWrap: softWrap ?? (unlimited ? true : false),
          maxLines: maxLines,
          overflow:
              overflow ??
              (unlimited ? TextOverflow.visible : TextOverflow.fade),
          textAlign: textAlign,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
        ),
      ),
    );
  }
}

// ---- Shared glossy icon ----
class GlossyIcon extends StatelessWidget {
  final IconData icon;
  final Gradient gradient;
  final double? size;

  const GlossyIcon({
    super.key,
    required this.icon,
    required this.gradient,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) => gradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Icon(icon, color: Colors.white, size: size),
    );
  }
}

const List<String> meduNeterFontFallback = [
  'Noto Sans Egyptian Hieroglyphs',
  'NotoSansEgyptianHieroglyphs',
  'NotoSans',
  'Roboto',
  'Arial',
  'sans-serif',
];

class MeduNeterGlyphs {
  const MeduNeterGlyphs._();

  static const String journal = '𓏞';
  static const String planner = '𓏥';
  static const String inbox = '𓏛';
  static const String calendars = '𓆳';
  static const String profile = '𓀀';
  static const String reflections = '𓋴𓇋𓄿';
  static const String library = '𓉐𓏛';
  static const String settings = '𓌀';
  static const String search = '𓁹';
  static const String flowStudio = '𓏞𓈖';
}

class GlossyGlyph extends StatelessWidget {
  final String glyph;
  final Gradient gradient;
  final double size;
  final TextStyle? style;

  const GlossyGlyph({
    super.key,
    required this.glyph,
    required this.gradient,
    this.size = 24,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      color: Colors.white,
      fontSize: size,
      fontWeight: FontWeight.w600,
      height: 1,
      letterSpacing: 0,
      fontFamily: 'GentiumPlus',
      fontFamilyFallback: meduNeterFontFallback,
    );

    return GlossyText(
      text: glyph,
      gradient: gradient,
      style: baseStyle.merge(style),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      textAlign: TextAlign.center,
    );
  }
}

// ---- Single source of truth for gold styling ----
class KemeticGold {
  static const Color light = goldLight;
  static const Color base = gold;
  static const Color deep = goldDeep;
  static const Gradient gloss = goldGloss;

  static GlossyText text(
    String text, {
    required TextStyle style,
    int? maxLines,
    TextOverflow? overflow,
    bool? softWrap,
    TextAlign? textAlign,
  }) {
    return GlossyText(
      text: text,
      style: style,
      gradient: gloss,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      textAlign: textAlign,
    );
  }

  static GlossyIcon icon(IconData icon, {double? size}) {
    return GlossyIcon(icon: icon, gradient: gloss, size: size);
  }

  static GlossyGlyph glyph(String glyph, {double? size, TextStyle? style}) {
    return GlossyGlyph(
      glyph: glyph,
      gradient: gloss,
      size: size ?? 24,
      style: style,
    );
  }
}
