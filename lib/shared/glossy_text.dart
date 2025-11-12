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

  const GlossyText({
    super.key,
    required this.text,
    required this.style,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final double fs = (style.fontSize ?? 16.0);
    final bool small = fs < 18.0;

    final TextStyle masked = style.copyWith(
      color: const Color(0xFFFFFFFF),
      height: style.height,
      fontSize: (style.fontSize != null) ? style.fontSize!.roundToDouble() : null,
      letterSpacing: 0,
      fontFamily: style.fontFamily,
      fontFamilyFallback: style.fontFamilyFallback ?? const ['NotoSans', 'Roboto', 'Arial', 'sans-serif'],
      shadows: small ? null : style.shadows,
    );

    return RepaintBoundary(
      child: ShaderMask(
        shaderCallback: (Rect r) => gradient.createShader(r),
        blendMode: BlendMode.srcIn,
        child: Text(
          text,
          style: masked,
          softWrap: false,
          maxLines: 1,
          overflow: TextOverflow.fade,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
        ),
      ),
    );
  }
}




