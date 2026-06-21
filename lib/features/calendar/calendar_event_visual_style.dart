import 'package:flutter/material.dart';

import 'maat_flow_identity.dart';

enum CalendarEventGraphicKind {
  trackSky,
  dawnHouseRite,
  eveningThresholdRite,
  theWeighing,
}

enum CalendarTrackSkyCardKind {
  moon,
  lunarEclipse,
  solarEclipse,
  meteor,
  planet,
  solarSeason,
  genericSky,
}

class CalendarEventGraphicStyle {
  const CalendarEventGraphicStyle({
    required this.kind,
    required this.background,
    required this.flowLabelGradient,
    required this.borderColor,
    required this.accentColor,
    required this.accentSecondaryColor,
    required this.titleColor,
    required this.labelColor,
    required this.detailColor,
    required this.glowColor,
    this.trackSkyKind,
  });

  final CalendarEventGraphicKind kind;
  final CalendarTrackSkyCardKind? trackSkyKind;
  final Gradient background;
  final Gradient flowLabelGradient;
  final Color borderColor;
  final Color accentColor;
  final Color accentSecondaryColor;
  final Color titleColor;
  final Color labelColor;
  final Color detailColor;
  final Color glowColor;
}

class CalendarEventVisualStyle {
  const CalendarEventVisualStyle({
    required this.paletteKey,
    required this.source,
    required this.base,
    required this.wash,
    required this.washLeft,
    required this.washMid,
    required this.washEnd,
    required this.stripe,
    required this.border,
    required this.category,
    required this.title,
    required this.metaText,
    required this.supportText,
    required this.sectionLabelText,
    required this.bodyText,
    required this.metaFill,
    required this.metaBorder,
    required this.actionButtonFill,
    required this.actionButtonBorder,
    required this.actionButtonText,
    required this.actionIconFill,
    required this.actionIconGlyph,
    required this.completionPanelFill,
    required this.completionPanelBorder,
    required this.completionButtonFill,
    required this.completionButtonBorder,
    required this.completionButtonText,
    required this.completionButtonSelectedFill,
    required this.completionButtonSelectedBorder,
    required this.completionButtonSelectedText,
    this.graphic,
  });

  final String paletteKey;
  final CalendarEventGraphicStyle? graphic;
  final Color source;
  final Color base;
  final Color wash;
  final Color washLeft;
  final Color washMid;
  final Color washEnd;
  final Color stripe;
  final Color border;
  final Color category;
  final Color title;
  final Color metaText;
  final Color supportText;
  final Color sectionLabelText;
  final Color bodyText;
  final Color metaFill;
  final Color metaBorder;
  final Color actionButtonFill;
  final Color actionButtonBorder;
  final Color actionButtonText;
  final Color actionIconFill;
  final Color actionIconGlyph;
  final Color completionPanelFill;
  final Color completionPanelBorder;
  final Color completionButtonFill;
  final Color completionButtonBorder;
  final Color completionButtonText;
  final Color completionButtonSelectedFill;
  final Color completionButtonSelectedBorder;
  final Color completionButtonSelectedText;

  bool get isGraphicFlow => graphic != null;

  CalendarEventVisualStyle asDetailSurface() {
    Color matte(
      Color color, {
      double saturationScale = 0.90,
      double liftAmount = 0.07,
    }) {
      return _matteDetailColor(
        color,
        saturationScale: saturationScale,
        liftAmount: liftAmount,
      );
    }

    return CalendarEventVisualStyle(
      paletteKey: paletteKey,
      graphic: graphic,
      source: matte(source),
      base: matte(base, liftAmount: 0.045),
      wash: matte(wash),
      washLeft: matte(washLeft),
      washMid: matte(washMid, liftAmount: 0.060),
      washEnd: matte(washEnd, liftAmount: 0.045),
      stripe: matte(stripe),
      border: matte(border),
      category: matte(category),
      title: matte(title),
      metaText: matte(metaText),
      supportText: matte(supportText),
      sectionLabelText: matte(sectionLabelText),
      bodyText: matte(bodyText, saturationScale: 0.86, liftAmount: 0.080),
      metaFill: matte(metaFill, liftAmount: 0.060),
      metaBorder: matte(metaBorder),
      actionButtonFill: matte(actionButtonFill, liftAmount: 0.060),
      actionButtonBorder: matte(actionButtonBorder),
      actionButtonText: matte(actionButtonText),
      actionIconFill: matte(actionIconFill),
      actionIconGlyph: matte(actionIconGlyph),
      completionPanelFill: matte(completionPanelFill, liftAmount: 0.050),
      completionPanelBorder: matte(completionPanelBorder),
      completionButtonFill: matte(completionButtonFill, liftAmount: 0.045),
      completionButtonBorder: matte(completionButtonBorder),
      completionButtonText: matte(completionButtonText),
      completionButtonSelectedFill: matte(
        completionButtonSelectedFill,
        liftAmount: 0.060,
      ),
      completionButtonSelectedBorder: matte(completionButtonSelectedBorder),
      completionButtonSelectedText: matte(completionButtonSelectedText),
    );
  }
}

const Color _dayGold = Color(0xFFD4AE43);
const Color _dayViewInk = Color(0xFFF2E4C6);
const Color _dayViewSilver = Color(0xFF9B9182);
const Color _dayViewCopperAccent = Color(0xFFC06E4D);
const Color _dayViewWarmStone = Color(0xFFB8AA9A);

const Gradient _trackSkyFlowGoldGloss = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [
    Color(0xFFFFF1BF),
    Color(0xFFF8DA79),
    Color(0xFFFFF8D9),
    Color(0xFFF1CE67),
  ],
  stops: [0.0, 0.34, 0.66, 1.0],
);

const Gradient _dawnHouseRiteFlowGloss = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [
    Color(0xFFFFE8B8),
    Color(0xFFF3A55E),
    Color(0xFFFFF3D6),
    Color(0xFFE98E52),
  ],
  stops: [0.0, 0.34, 0.66, 1.0],
);

const Gradient _theWeighingFlowGloss = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [
    Color(0xFFF5E8CB),
    Color(0xFFB8A88A),
    Color(0xFFFFF8E8),
    Color(0xFF8D7C5F),
  ],
  stops: [0.0, 0.34, 0.66, 1.0],
);

const Gradient _eveningThresholdRiteFlowGloss = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [
    Color(0xFFF4EEFF),
    Color(0xFFB9C7FF),
    Color(0xFFFFE7A8),
    Color(0xFF7FE0D4),
  ],
  stops: [0.0, 0.38, 0.62, 1.0],
);

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

Color _readableFlowColor(Color color) {
  final luminance = color.computeLuminance();
  if (luminance < 0.18) {
    return _mix(color, Colors.white, 0.42);
  }
  if (luminance > 0.68) {
    return _mix(color, _dayGold, 0.22);
  }
  return color;
}

bool _isRedOrangeMaterialColor(Color color) {
  final hue = HSLColor.fromColor(color).hue;
  return hue <= 32 || hue >= 342;
}

bool _isBlueMaterialColor(Color color) {
  final hue = HSLColor.fromColor(color).hue;
  return hue >= 175 && hue <= 265;
}

bool _isGreenMaterialColor(Color color) {
  final hue = HSLColor.fromColor(color).hue;
  return hue > 72 && hue <= 165;
}

Color _softenedAccent(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withSaturation((hsl.saturation * 0.52).clamp(0.0, 0.50).toDouble())
      .withLightness(0.49)
      .toColor();
}

Color _materialFlowColor(Color color) {
  final readable = _readableFlowColor(color);
  final hue = HSLColor.fromColor(readable).hue;
  if (hue <= 28 || hue >= 342) return _dayViewCopperAccent;
  if (hue > 28 && hue <= 72) {
    return _mix(readable, const Color(0xFFC98A5B), 0.5);
  }
  return readable;
}

Color _matteDetailColor(
  Color color, {
  double saturationScale = 0.90,
  double liftAmount = 0.07,
}) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withSaturation(
        (hsl.saturation * saturationScale).clamp(0.0, 1.0).toDouble(),
      )
      .withLightness(
        (hsl.lightness + ((1.0 - hsl.lightness) * liftAmount))
            .clamp(0.0, 1.0)
            .toDouble(),
      )
      .toColor();
}

CalendarEventVisualStyle resolveCalendarEventVisualStyle({
  required Color eventColor,
  String? flowName,
  String? flowNotes,
  String? eventTitle,
  Map<String, dynamic>? behaviorPayload,
  bool isReminder = false,
  bool isNutrition = false,
}) {
  final graphic = _graphicStyleForEvent(
    flowName: flowName,
    flowNotes: flowNotes,
    eventTitle: eventTitle,
    behaviorPayload: behaviorPayload,
  );
  if (graphic != null) return _graphicVisualStyle(graphic);

  final rawSource = _readableFlowColor(
    isReminder
        ? const Color(0xFF5CAA5F)
        : isNutrition
        ? const Color(0xFF57A9D6)
        : eventColor,
  );
  final source = isReminder || isNutrition
      ? rawSource
      : _materialFlowColor(rawSource);
  final redOrange = _isRedOrangeMaterialColor(source);

  if (redOrange && !isReminder && !isNutrition) {
    const accent = Color(0xFFC2673F);
    return CalendarEventVisualStyle(
      paletteKey: 'generic:red-orange',
      source: accent,
      base: const Color(0xFF190C08),
      wash: const Color(0xFF542516),
      washLeft: const Color(0xFF542516),
      washMid: const Color(0xFF2F150D),
      washEnd: const Color(0xFF150A07),
      stripe: accent.withValues(alpha: 0.65),
      border: const Color(0xFFC4754C).withValues(alpha: 0.24),
      category: const Color(0xFFC0774B),
      title: const Color(0xFFDCA66E),
      metaText: const Color(0xFFB47A4D),
      supportText: const Color(0xFFA97855),
      sectionLabelText: const Color(0xFFA88749),
      bodyText: const Color(0xFFBDAEA2),
      metaFill: accent.withValues(alpha: 0.10),
      metaBorder: accent.withValues(alpha: 0.22),
      actionButtonFill: const Color(0xFF2B150E),
      actionButtonBorder: const Color(0xFFC06E4D).withValues(alpha: 0.32),
      actionButtonText: const Color(0xFFDCA66E),
      actionIconFill: const Color(0xFFC06E4D).withValues(alpha: 0.28),
      actionIconGlyph: const Color(0xFFE2AE78),
      completionPanelFill: const Color(0xFF130907),
      completionPanelBorder: const Color(0xFFC06E4D).withValues(alpha: 0.20),
      completionButtonFill: const Color(0xFF090604),
      completionButtonBorder: const Color(0xFF5A3A23).withValues(alpha: 0.54),
      completionButtonText: const Color(0xFFA98E66),
      completionButtonSelectedFill: const Color(0xFF311911),
      completionButtonSelectedBorder: const Color(
        0xFFC98A5B,
      ).withValues(alpha: 0.34),
      completionButtonSelectedText: const Color(0xFFDDAE76),
    );
  }

  final softened = _softenedAccent(source);
  final hue = HSLColor.fromColor(softened).hue;
  final isBlue = _isBlueMaterialColor(softened);
  final isGreen = _isGreenMaterialColor(softened);
  final isGold = hue > 32 && hue <= 72;
  final base = isBlue
      ? const Color(0xFF0F1723)
      : isGreen
      ? const Color(0xFF09170D)
      : isGold
      ? const Color(0xFF171108)
      : Color.alphaBlend(
          softened.withValues(alpha: 0.13),
          const Color(0xFF090604),
        );
  final title = isBlue
      ? _mix(softened, const Color(0xFF87C0EA), 0.58)
      : isGreen
      ? _mix(softened, const Color(0xFF9BD9A8), 0.46)
      : isGold
      ? _mix(softened, const Color(0xFFD7B45E), 0.47)
      : _mix(softened, const Color(0xFFE2C58C), 0.22);
  final category = _mix(softened, _dayViewInk, 0.14);
  final metaText = _mix(softened, _dayViewSilver, 0.28);
  final supportText = _mix(softened, const Color(0xFF9A7E64), 0.38);

  return CalendarEventVisualStyle(
    paletteKey: isReminder
        ? 'system:reminder'
        : isNutrition
        ? 'system:nutrition'
        : 'generic:${_paletteHueBucket(softened)}',
    source: softened,
    base: base,
    wash: softened,
    washLeft: softened,
    washMid: _mix(softened, base, 0.42),
    washEnd: base,
    stripe: softened.withValues(alpha: isReminder ? 0.62 : 0.66),
    border: softened.withValues(alpha: 0.24),
    category: category.withValues(alpha: 0.88),
    title: title,
    metaText: metaText.withValues(alpha: 0.88),
    supportText: supportText.withValues(alpha: 0.88),
    sectionLabelText: const Color(0xFFA88749),
    bodyText: const Color(0xFFBDAEA2),
    metaFill: softened.withValues(alpha: 0.10),
    metaBorder: softened.withValues(alpha: 0.22),
    actionButtonFill: Color.alphaBlend(
      softened.withValues(alpha: 0.11),
      const Color(0xFF090604),
    ),
    actionButtonBorder: softened.withValues(alpha: 0.29),
    actionButtonText: title.withValues(alpha: 0.96),
    actionIconFill: softened.withValues(alpha: 0.24),
    actionIconGlyph: title.withValues(alpha: 0.94),
    completionPanelFill: Color.alphaBlend(
      softened.withValues(alpha: 0.05),
      const Color(0xFF080604),
    ),
    completionPanelBorder: softened.withValues(alpha: 0.18),
    completionButtonFill: const Color(0xFF090604),
    completionButtonBorder: const Color(0xFF5A3A23).withValues(alpha: 0.54),
    completionButtonText: const Color(0xFFA98E66),
    completionButtonSelectedFill: Color.alphaBlend(
      softened.withValues(alpha: 0.17),
      const Color(0xFF060504),
    ),
    completionButtonSelectedBorder: softened.withValues(alpha: 0.34),
    completionButtonSelectedText: title.withValues(alpha: 0.93),
  );
}

String _paletteHueBucket(Color color) {
  final hue = HSLColor.fromColor(color).hue.round();
  final bucket = (hue / 15).round() * 15;
  return bucket.toString().padLeft(3, '0');
}

CalendarEventGraphicStyle? _graphicStyleForEvent({
  required String? flowName,
  required String? flowNotes,
  required String? eventTitle,
  required Map<String, dynamic>? behaviorPayload,
}) {
  final kind = resolveMaatFlowKind(
    flowName: flowName,
    flowNotes: flowNotes,
    behaviorPayload: behaviorPayload,
  );
  return switch (kind) {
    MaatFlowKind.trackSky => _trackSkyGraphicStyleForTitle(eventTitle ?? ''),
    MaatFlowKind.dawnHouseRite => _dawnHouseRiteGraphicStyle,
    MaatFlowKind.eveningThresholdRite => _eveningThresholdRiteGraphicStyle,
    MaatFlowKind.theWeighing => _theWeighingGraphicStyle,
    _ => null,
  };
}

CalendarEventVisualStyle _graphicVisualStyle(
  CalendarEventGraphicStyle graphic,
) {
  final base = switch (graphic.kind) {
    CalendarEventGraphicKind.trackSky => const Color(0xFF05070F),
    CalendarEventGraphicKind.dawnHouseRite => const Color(0xFF120D14),
    CalendarEventGraphicKind.eveningThresholdRite => const Color(0xFF030611),
    CalendarEventGraphicKind.theWeighing => const Color(0xFF111213),
  };
  final lowWash = switch (graphic.kind) {
    CalendarEventGraphicKind.trackSky => _mix(graphic.accentColor, base, 0.42),
    CalendarEventGraphicKind.dawnHouseRite => const Color(0xFF3A315D),
    CalendarEventGraphicKind.eveningThresholdRite => const Color(0xFF193248),
    CalendarEventGraphicKind.theWeighing => const Color(0xFF5D5241),
  };
  final body = _mix(graphic.detailColor, _dayViewWarmStone, 0.28);
  final support = _mix(graphic.detailColor, graphic.accentColor, 0.34);

  return CalendarEventVisualStyle(
    paletteKey:
        'graphic:${graphic.kind.name}'
        '${graphic.trackSkyKind == null ? '' : ':${graphic.trackSkyKind!.name}'}',
    graphic: graphic,
    source: graphic.accentColor,
    base: base,
    wash: graphic.accentColor,
    washLeft: lowWash,
    washMid: _mix(lowWash, base, 0.36),
    washEnd: base,
    stripe: graphic.accentColor.withValues(alpha: 0.66),
    border: graphic.borderColor.withValues(alpha: 0.52),
    category: graphic.labelColor.withValues(alpha: 0.88),
    title: graphic.titleColor,
    metaText: graphic.detailColor.withValues(alpha: 0.88),
    supportText: support.withValues(alpha: 0.86),
    sectionLabelText: graphic.accentColor.withValues(alpha: 0.82),
    bodyText: body.withValues(alpha: 0.93),
    metaFill: graphic.accentColor.withValues(alpha: 0.10),
    metaBorder: graphic.borderColor.withValues(alpha: 0.22),
    actionButtonFill: Color.alphaBlend(
      graphic.accentColor.withValues(alpha: 0.10),
      const Color(0xFF090604),
    ),
    actionButtonBorder: graphic.borderColor.withValues(alpha: 0.30),
    actionButtonText: graphic.titleColor.withValues(alpha: 0.94),
    actionIconFill: graphic.accentColor.withValues(alpha: 0.22),
    actionIconGlyph: graphic.titleColor.withValues(alpha: 0.92),
    completionPanelFill: Color.alphaBlend(
      graphic.accentColor.withValues(alpha: 0.045),
      const Color(0xFF080604),
    ),
    completionPanelBorder: graphic.borderColor.withValues(alpha: 0.18),
    completionButtonFill: const Color(0xFF090604),
    completionButtonBorder: graphic.accentColor.withValues(alpha: 0.25),
    completionButtonText: _mix(
      graphic.detailColor,
      const Color(0xFFA98E66),
      0.46,
    ).withValues(alpha: 0.86),
    completionButtonSelectedFill: Color.alphaBlend(
      graphic.accentColor.withValues(alpha: 0.16),
      const Color(0xFF060504),
    ),
    completionButtonSelectedBorder: graphic.borderColor.withValues(alpha: 0.34),
    completionButtonSelectedText: graphic.titleColor.withValues(alpha: 0.93),
  );
}

const CalendarEventGraphicStyle _dawnHouseRiteGraphicStyle =
    CalendarEventGraphicStyle(
      kind: CalendarEventGraphicKind.dawnHouseRite,
      background: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF12152C),
          Color(0xFF3A315D),
          Color(0xFFB56A6E),
          Color(0xFFF2B45F),
        ],
        stops: [0.0, 0.38, 0.76, 1.0],
      ),
      flowLabelGradient: _dawnHouseRiteFlowGloss,
      borderColor: Color(0xFFFFD08A),
      accentColor: Color(0xFFEFA25C),
      accentSecondaryColor: Color(0xFFFFF3D6),
      titleColor: Color(0xFFFFF6E3),
      labelColor: Color(0xFFFFE8B8),
      detailColor: Color(0xFFFFD8A8),
      glowColor: Color(0xFFFFB765),
    );

const CalendarEventGraphicStyle _theWeighingGraphicStyle =
    CalendarEventGraphicStyle(
      kind: CalendarEventGraphicKind.theWeighing,
      background: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF111213),
          Color(0xFF2C2A25),
          Color(0xFF5D5241),
          Color(0xFFB8A88A),
        ],
        stops: [0.0, 0.42, 0.78, 1.0],
      ),
      flowLabelGradient: _theWeighingFlowGloss,
      borderColor: Color(0xFFF5E8CB),
      accentColor: Color(0xFFB8A88A),
      accentSecondaryColor: Color(0xFFFFF8E8),
      titleColor: Color(0xFFFFF8E8),
      labelColor: Color(0xFFF5E8CB),
      detailColor: Color(0xFFCDBF9F),
      glowColor: Color(0xFFF5E8CB),
    );

const CalendarEventGraphicStyle _eveningThresholdRiteGraphicStyle =
    CalendarEventGraphicStyle(
      kind: CalendarEventGraphicKind.eveningThresholdRite,
      background: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF030611),
          Color(0xFF111634),
          Color(0xFF193248),
          Color(0xFF2B254E),
        ],
        stops: [0.0, 0.36, 0.7, 1.0],
      ),
      flowLabelGradient: _eveningThresholdRiteFlowGloss,
      borderColor: Color(0xFF7FE0D4),
      accentColor: Color(0xFF7FE0D4),
      accentSecondaryColor: Color(0xFFFFE4A3),
      titleColor: Color(0xFFF2F0FF),
      labelColor: Color(0xFFF4EEFF),
      detailColor: Color(0xFFDDEAFF),
      glowColor: Color(0xFF66D7CF),
    );

CalendarTrackSkyCardKind _trackSkyCardKindForTitle(String title) {
  if (title.contains('solar eclipse') || title.contains('ring of fire')) {
    return CalendarTrackSkyCardKind.solarEclipse;
  }
  if (title.contains('lunar eclipse') ||
      title.contains('blood moon') ||
      title.contains('penumbral') ||
      title.contains('partial lunar')) {
    return CalendarTrackSkyCardKind.lunarEclipse;
  }
  if (title.contains('moon')) return CalendarTrackSkyCardKind.moon;
  if (title.contains('lyrids') ||
      title.contains('aquariids') ||
      title.contains('perseids') ||
      title.contains('geminids') ||
      title.contains('quadrantids') ||
      title.contains('meteor')) {
    return CalendarTrackSkyCardKind.meteor;
  }
  if (title.contains('equinox') || title.contains('solstice')) {
    return CalendarTrackSkyCardKind.solarSeason;
  }
  if (title.contains('planet') ||
      title.contains('conjunction') ||
      title.contains('opposition') ||
      title.contains('elongation') ||
      title.contains('venus') ||
      title.contains('mars') ||
      title.contains('jupiter') ||
      title.contains('saturn') ||
      title.contains('mercury')) {
    return CalendarTrackSkyCardKind.planet;
  }
  return CalendarTrackSkyCardKind.genericSky;
}

Color _trackSkyMoonTint(String title) {
  if (title.contains('blood')) return const Color(0xFFC7655D);
  if (title.contains('blue moon')) return const Color(0xFFA8D6FF);
  if (title.contains('pink')) return const Color(0xFFF5B4D7);
  if (title.contains('flower')) return const Color(0xFFFFE3B0);
  if (title.contains('strawberry')) return const Color(0xFFF39AA6);
  if (title.contains('harvest')) return const Color(0xFFF5C46B);
  if (title.contains('hunter')) return const Color(0xFFCF925B);
  if (title.contains('snow') || title.contains('cold')) {
    return const Color(0xFFEAF5FF);
  }
  if (title.contains('wolf')) return const Color(0xFFD9E6FF);
  if (title.contains('beaver')) return const Color(0xFFD7B58F);
  if (title.contains('buck')) return const Color(0xFFE0BF8C);
  if (title.contains('sturgeon')) return const Color(0xFFE7EEF9);
  return const Color(0xFFF4E7CF);
}

Color _trackSkyMeteorTint(String title) {
  if (title.contains('perseids')) return const Color(0xFF9FCAFF);
  if (title.contains('geminids')) return const Color(0xFFA9F5EF);
  if (title.contains('lyrids')) return const Color(0xFFD7C3FF);
  if (title.contains('quadrantids')) return const Color(0xFFEAF5FF);
  if (title.contains('aquariids')) return const Color(0xFF8DEAF7);
  return const Color(0xFFB9D0FF);
}

Color _trackSkyPlanetTint(String title) {
  if (title.contains('mars')) return const Color(0xFFE17D5D);
  if (title.contains('venus')) return const Color(0xFFF6E2C0);
  if (title.contains('jupiter')) return const Color(0xFFF4C88D);
  if (title.contains('saturn')) return const Color(0xFFE8D27A);
  if (title.contains('mercury')) return const Color(0xFFD9E1F0);
  return const Color(0xFFBFD2FF);
}

Color _trackSkySolarTint(String title) {
  if (title.contains('winter')) return const Color(0xFFF1D4A3);
  if (title.contains('summer')) return const Color(0xFFF7B45A);
  if (title.contains('autumn')) return const Color(0xFFF19A62);
  if (title.contains('vernal') || title.contains('spring')) {
    return const Color(0xFFF8CDA0);
  }
  return const Color(0xFFF3C47E);
}

CalendarEventGraphicStyle _trackSkyGraphicStyleForTitle(String rawTitle) {
  final title = rawTitle.trim().toLowerCase();
  final kind = _trackSkyCardKindForTitle(title);
  switch (kind) {
    case CalendarTrackSkyCardKind.moon:
      final tint = _trackSkyMoonTint(title);
      return CalendarEventGraphicStyle(
        kind: CalendarEventGraphicKind.trackSky,
        trackSkyKind: kind,
        background: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF040813),
            Color.lerp(const Color(0xFF16245D), tint, 0.16)!,
            const Color(0xFF2A1F52),
          ],
        ),
        flowLabelGradient: _trackSkyFlowGoldGloss,
        borderColor: tint.withValues(alpha: 0.78),
        accentColor: tint,
        accentSecondaryColor: Colors.white,
        titleColor: const Color(0xFFF7FAFF),
        labelColor: const Color(0xFFE3EAFF),
        detailColor: const Color(0xFFD9E4FF),
        glowColor: tint.withValues(alpha: 0.56),
      );
    case CalendarTrackSkyCardKind.lunarEclipse:
      final tint = _trackSkyMoonTint(title);
      return CalendarEventGraphicStyle(
        kind: CalendarEventGraphicKind.trackSky,
        trackSkyKind: kind,
        background: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF05070F),
            Color.lerp(const Color(0xFF301126), tint, 0.34)!,
            const Color(0xFF120812),
          ],
        ),
        flowLabelGradient: _trackSkyFlowGoldGloss,
        borderColor: tint.withValues(alpha: 0.82),
        accentColor: tint,
        accentSecondaryColor: const Color(0xFFFFD7BF),
        titleColor: const Color(0xFFFFF6F1),
        labelColor: const Color(0xFFFFE8DD),
        detailColor: const Color(0xFFFFD9CC),
        glowColor: tint.withValues(alpha: 0.56),
      );
    case CalendarTrackSkyCardKind.solarEclipse:
      final tint = title.contains('ring of fire')
          ? const Color(0xFFFFA24B)
          : const Color(0xFFF4E6C1);
      return CalendarEventGraphicStyle(
        kind: CalendarEventGraphicKind.trackSky,
        trackSkyKind: kind,
        background: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF03050B), Color(0xFF171B2E), Color(0xFF090B14)],
        ),
        flowLabelGradient: _trackSkyFlowGoldGloss,
        borderColor: tint.withValues(alpha: 0.84),
        accentColor: tint,
        accentSecondaryColor: const Color(0xFFFFD26A),
        titleColor: const Color(0xFFFFF8EF),
        labelColor: const Color(0xFFFFEED5),
        detailColor: const Color(0xFFFFDCB0),
        glowColor: tint.withValues(alpha: 0.58),
      );
    case CalendarTrackSkyCardKind.meteor:
      final tint = _trackSkyMeteorTint(title);
      return CalendarEventGraphicStyle(
        kind: CalendarEventGraphicKind.trackSky,
        trackSkyKind: kind,
        background: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF050816),
            Color.lerp(const Color(0xFF1E1B54), tint, 0.2)!,
            const Color(0xFF0C1029),
          ],
        ),
        flowLabelGradient: _trackSkyFlowGoldGloss,
        borderColor: tint.withValues(alpha: 0.82),
        accentColor: tint,
        accentSecondaryColor: Colors.white,
        titleColor: const Color(0xFFF4F8FF),
        labelColor: const Color(0xFFDCE8FF),
        detailColor: const Color(0xFFCAE3FF),
        glowColor: tint.withValues(alpha: 0.55),
      );
    case CalendarTrackSkyCardKind.planet:
      final tint = _trackSkyPlanetTint(title);
      return CalendarEventGraphicStyle(
        kind: CalendarEventGraphicKind.trackSky,
        trackSkyKind: kind,
        background: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF050915),
            Color.lerp(const Color(0xFF13224B), tint, 0.18)!,
            const Color(0xFF161038),
          ],
        ),
        flowLabelGradient: _trackSkyFlowGoldGloss,
        borderColor: tint.withValues(alpha: 0.8),
        accentColor: tint,
        accentSecondaryColor: const Color(0xFFE9EFFF),
        titleColor: const Color(0xFFF8FAFF),
        labelColor: const Color(0xFFDDE6FF),
        detailColor: const Color(0xFFD7E2FF),
        glowColor: tint.withValues(alpha: 0.52),
      );
    case CalendarTrackSkyCardKind.solarSeason:
      final tint = _trackSkySolarTint(title);
      return CalendarEventGraphicStyle(
        kind: CalendarEventGraphicKind.trackSky,
        trackSkyKind: kind,
        background: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF071326),
            Color.lerp(const Color(0xFF5C2F57), tint, 0.26)!,
            Color.lerp(const Color(0xFFF18E5B), tint, 0.4)!,
          ],
          stops: const [0.0, 0.58, 1.0],
        ),
        flowLabelGradient: _trackSkyFlowGoldGloss,
        borderColor: tint.withValues(alpha: 0.84),
        accentColor: tint,
        accentSecondaryColor: const Color(0xFFFFE7B8),
        titleColor: const Color(0xFFFFFAF1),
        labelColor: const Color(0xFFFFEFD5),
        detailColor: const Color(0xFFFFE1B7),
        glowColor: tint.withValues(alpha: 0.56),
      );
    case CalendarTrackSkyCardKind.genericSky:
      return const CalendarEventGraphicStyle(
        kind: CalendarEventGraphicKind.trackSky,
        trackSkyKind: CalendarTrackSkyCardKind.genericSky,
        background: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF090D1E), Color(0xFF222A5B), Color(0xFF4B5EBB)],
        ),
        flowLabelGradient: _trackSkyFlowGoldGloss,
        borderColor: Color(0xFFA4B1FF),
        accentColor: Color(0xFFDCE6FF),
        accentSecondaryColor: Colors.white,
        titleColor: Color(0xFFF8FAFF),
        labelColor: Color(0xFFE0E8FF),
        detailColor: Color(0xFFD8E2FF),
        glowColor: Color(0x88A4B1FF),
      );
  }
}
