import 'package:flutter/material.dart';

import '../../shared/candlelit_mahogany_background.dart';
import '../../widgets/global_side_drawer.dart';

class DecanReflectionTokens {
  const DecanReflectionTokens._();

  static const Color base = CandlelitMahoganyBackground.base;
  static const Color baseRaise = Color(0xFF120F08);
  static const Color ink = Color(0xFFE9E2D2);
  static const Color inkSoft = Color(0xFFC8C4BC);
  static const Color inkMid = Color(0xFF9E9A94);
  static const Color inkLo = Color(0xFF6A6660);
  static const Color gold = Color(0xFFD4AE43);
  static const Color goldDeep = Color(0xFFB8924A);
  static const Color brass = Color(0xFFB8A88A);
  static const Color brassGlow = Color(0xFFF5E8CB);
  static const Color thread = Color(0xFF2A2520);
  static const Color threadLit = Color(0xFF6E5C36);
  static const Color hairline = Color.fromRGBO(212, 174, 67, 0.10);

  static const String fontFamily = 'CormorantGaramond';
  static const List<String> fontFallback = <String>[
    'GentiumPlus',
    'Georgia',
    'serif',
  ];
  static const List<String> glyphFallback = <String>[
    'Noto Sans Egyptian Hieroglyphs',
    'GentiumPlus',
    'serif',
  ];

  static const List<FontFeature> oldstyleDateFeatures = <FontFeature>[
    FontFeature('onum'),
    FontFeature('liga'),
    FontFeature('calt'),
  ];

  static const double scrollBottomPadding = 104;
  static const double scrimHeight = 96;

  static const Gradient crownBloom = CandlelitMahoganyBackground.crownBloom;

  static const Gradient monthRule = LinearGradient(
    colors: <Color>[hairline, Colors.transparent],
  );

  static const Gradient mastheadRule = LinearGradient(
    colors: <Color>[hairline, Colors.transparent],
    stops: <double>[0, 0.7],
  );

  static const Gradient railGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Colors.transparent, thread, thread, Colors.transparent],
    stops: <double>[0, 0.08, 0.92, 1],
  );

  static const Gradient recordNodeFill = RadialGradient(
    center: Alignment(0, -0.2),
    radius: 0.72,
    colors: <Color>[brassGlow, goldDeep],
    stops: <double>[0, 0.7],
  );

  static const Gradient glyphFill = RadialGradient(
    center: Alignment(0, -0.3),
    radius: 0.76,
    colors: <Color>[Color.fromRGBO(245, 232, 203, 0.14), baseRaise],
    stops: <double>[0, 0.6],
  );

  static const Gradient glyphIcon = LinearGradient(colors: <Color>[gold, gold]);

  static const Gradient bottomScrim = CandlelitMahoganyBackground.bottomScrim;

  static const TextStyle navTitleStyle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    color: ink,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.5,
    letterSpacing: 0.3,
  );

  static const TextStyle monthLabelStyle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    color: Color.fromRGBO(212, 174, 67, 0.62),
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 4.48,
  );

  static const TextStyle dateStyle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    color: inkMid,
    fontSize: 14.5,
    letterSpacing: 0.58,
    fontFeatures: oldstyleDateFeatures,
  );

  static const TextStyle recordTitleStyle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    color: ink,
    fontSize: 25,
    fontWeight: FontWeight.w600,
    height: 1.42,
    letterSpacing: 0.2,
  );

  static const TextStyle openingTitleStyle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    color: inkSoft,
    fontSize: 23,
    fontWeight: FontWeight.w500,
    fontStyle: FontStyle.italic,
    height: 1.42,
  );

  static const TextStyle transliterationTitleStyle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    color: goldDeep,
    fontSize: 25,
    fontWeight: FontWeight.w600,
    fontStyle: FontStyle.italic,
    height: 1.42,
    letterSpacing: 0.2,
  );

  static const TextStyle previewStyle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    color: inkMid,
    fontSize: 17,
    height: 1.55,
  );

  static const TextStyle folioTitleStyle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    color: gold,
    fontSize: 34,
    fontWeight: FontWeight.w600,
    height: 1.34,
    letterSpacing: 0.3,
  );

  static const TextStyle folioTitleTransliterationStyle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    color: goldDeep,
    fontSize: 34,
    fontWeight: FontWeight.w600,
    fontStyle: FontStyle.italic,
    height: 1.34,
    letterSpacing: 0.3,
  );

  static const TextStyle folioSubtitleStyle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    color: inkLo,
    fontSize: 18,
    fontStyle: FontStyle.italic,
    height: 1.5,
    letterSpacing: 0.36,
  );

  static const TextStyle folioDateStyle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    color: inkMid,
    fontSize: 15,
    letterSpacing: 0.45,
    fontFeatures: oldstyleDateFeatures,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    color: ink,
    fontSize: 20,
    height: 1.66,
    letterSpacing: 0.1,
  );

  static const TextStyle riteEyebrowStyle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    color: Color.fromRGBO(184, 168, 138, 0.75),
    fontSize: 12,
    letterSpacing: 3.12,
  );

  static const TextStyle riteQuestionStyle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    color: inkSoft,
    fontSize: 21,
    fontStyle: FontStyle.italic,
    height: 1.55,
  );

  static const TextStyle bridgeStyle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    color: gold,
    fontSize: 16,
    letterSpacing: 0.32,
  );

  static const TextStyle emptyTitleStyle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    color: ink,
    fontSize: 25,
    fontWeight: FontWeight.w600,
    height: 1.42,
  );

  static const TextStyle emptyBodyStyle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallback,
    color: inkMid,
    fontSize: 17,
    height: 1.55,
  );
}

const GlobalMenuBubbleStyle decanReflectionGlobalMenuBubbleStyle =
    GlobalMenuBubbleStyle(
      size: 52,
      left: 18,
      bottom: 22,
      background: DecanReflectionTokens.glyphFill,
      borderColor: Color.fromRGBO(212, 174, 67, 0.18),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.55),
          blurRadius: 30,
          offset: Offset(0, 8),
        ),
      ],
      glyphGradient: DecanReflectionTokens.glyphIcon,
      glyphSize: 24,
    );

class DecanReflectionSkinScaffold extends StatelessWidget {
  const DecanReflectionSkinScaffold({
    super.key,
    required this.navBar,
    required this.child,
  });

  final Widget navBar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DecanReflectionTokens.base,
      body: CandlelitMahoganyBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              navBar,
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class DecanReflectionNavBar extends StatelessWidget {
  const DecanReflectionNavBar({
    super.key,
    required this.title,
    required this.onBack,
    this.right,
  });

  final String title;
  final VoidCallback onBack;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 48,
              child: Center(
                child: DecanReflectionNavIconButton(
                  tooltip: 'Back',
                  icon: Icons.chevron_left,
                  iconSize: 24,
                  onPressed: onBack,
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: DecanReflectionTokens.navTitleStyle,
              ),
            ),
            SizedBox(width: 48, child: Center(child: right)),
          ],
        ),
      ),
    );
  }
}

class DecanReflectionNavIconButton extends StatefulWidget {
  const DecanReflectionNavIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.iconSize = 22,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final double iconSize;

  @override
  State<DecanReflectionNavIconButton> createState() =>
      _DecanReflectionNavIconButtonState();
}

class _DecanReflectionNavIconButtonState
    extends State<DecanReflectionNavIconButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: _focused
              ? Border.all(color: DecanReflectionTokens.gold, width: 2)
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            onFocusChange: (focused) => setState(() => _focused = focused),
            onTap: widget.onPressed,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                widget.icon,
                size: widget.iconSize,
                color: DecanReflectionTokens.gold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DecanMonthHeader extends StatelessWidget {
  const DecanMonthHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 10),
      child: Row(
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: DecanReflectionTokens.monthLabelStyle,
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: SizedBox(
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: DecanReflectionTokens.monthRule,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DecanTrack extends StatelessWidget {
  const DecanTrack({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        const Positioned(
          left: 33,
          top: 6,
          bottom: 14,
          width: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: DecanReflectionTokens.railGradient,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Column(children: children),
        ),
      ],
    );
  }
}

enum DecanChronicleEntryType { record, opening }

class DecanChronicleEntry extends StatefulWidget {
  const DecanChronicleEntry({
    super.key,
    required this.type,
    required this.dateRange,
    required this.title,
    required this.preview,
    required this.onTap,
    this.addTopGap = false,
  });

  final DecanChronicleEntryType type;
  final String dateRange;
  final String title;
  final String preview;
  final VoidCallback onTap;
  final bool addTopGap;

  @override
  State<DecanChronicleEntry> createState() => _DecanChronicleEntryState();
}

class _DecanChronicleEntryState extends State<DecanChronicleEntry> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _active => _hovered || _pressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: widget.addTopGap ? 2 : 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: _focused
              ? Border.all(color: DecanReflectionTokens.gold, width: 2)
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            onTap: widget.onTap,
            onHover: (hovered) => setState(() => _hovered = hovered),
            onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
            onFocusChange: (focused) => setState(() => _focused = focused),
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: widget.type == DecanChronicleEntryType.record ? 3 : 5,
                  top: widget.type == DecanChronicleEntryType.record ? 23 : 25,
                  child: _DecanRecordNode(type: widget.type, active: _active),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 16, 26, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _EntryDateRow(
                        dateRange: widget.dateRange,
                        opening: widget.type == DecanChronicleEntryType.opening,
                      ),
                      const SizedBox(height: 3),
                      DecanTitleText(
                        title: widget.title,
                        opening: widget.type == DecanChronicleEntryType.opening,
                      ),
                      const SizedBox(height: 6),
                      DecanPreviewText(text: widget.preview),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryDateRow extends StatelessWidget {
  const _EntryDateRow({required this.dateRange, required this.opening});

  final String dateRange;
  final bool opening;

  @override
  Widget build(BuildContext context) {
    final parts = dateRange.split(' → ');
    return Row(
      children: <Widget>[
        Flexible(
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(text: parts.isEmpty ? dateRange : parts.first),
                if (parts.length > 1) ...<InlineSpan>[
                  const TextSpan(
                    text: '  →  ',
                    style: TextStyle(color: DecanReflectionTokens.inkLo),
                  ),
                  TextSpan(text: parts.sublist(1).join(' → ')),
                ],
                if (opening)
                  const TextSpan(
                    text: '    OPENING',
                    style: TextStyle(
                      color: Color.fromRGBO(184, 146, 74, 0.70),
                      fontSize: 11,
                      letterSpacing: 2.42,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DecanReflectionTokens.dateStyle,
          ),
        ),
      ],
    );
  }
}

class DecanTitleText extends StatelessWidget {
  const DecanTitleText({
    super.key,
    required this.title,
    this.opening = false,
    this.folio = false,
  });

  final String title;
  final bool opening;
  final bool folio;

  @override
  Widget build(BuildContext context) {
    if (opening) {
      return Text(title, style: DecanReflectionTokens.openingTitleStyle);
    }
    final base = folio
        ? DecanReflectionTokens.folioTitleStyle
        : DecanReflectionTokens.recordTitleStyle;
    final accent = folio
        ? DecanReflectionTokens.folioTitleTransliterationStyle
        : DecanReflectionTokens.transliterationTitleStyle;
    final split = _splitTitle(title);
    if (split == null) {
      return Text(title, style: base);
    }
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: '${split.before} — ', style: base),
          TextSpan(text: split.after, style: accent),
        ],
      ),
    );
  }
}

({String before, String after})? _splitTitle(String title) {
  final index = title.indexOf(' — ');
  if (index < 0) return null;
  final before = title.substring(0, index).trim();
  final after = title.substring(index + 3).trim();
  if (before.isEmpty || after.isEmpty) return null;
  return (before: before, after: after);
}

class DecanPreviewText extends StatelessWidget {
  const DecanPreviewText({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: <Widget>[
            Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.clip,
              style: DecanReflectionTokens.previewStyle,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              width: constraints.maxWidth * 0.62,
              height:
                  (DecanReflectionTokens.previewStyle.fontSize ?? 17) * 1.55,
              child: const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.transparent,
                        DecanReflectionTokens.base,
                      ],
                      stops: <double>[0, 0.82],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DecanRecordNode extends StatelessWidget {
  const _DecanRecordNode({required this.type, required this.active});

  final DecanChronicleEntryType type;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final isRecord = type == DecanChronicleEntryType.record;
    return AnimatedScale(
      scale: active ? 1.18 : 1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.ease,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.ease,
        width: isRecord ? 13 : 9,
        height: isRecord ? 13 : 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRecord ? null : DecanReflectionTokens.base,
          gradient: isRecord ? DecanReflectionTokens.recordNodeFill : null,
          border: Border.all(
            color: isRecord
                ? DecanReflectionTokens.goldDeep
                : DecanReflectionTokens.threadLit.withValues(alpha: 0.85),
            width: 1.5,
          ),
          boxShadow: <BoxShadow>[
            const BoxShadow(color: DecanReflectionTokens.base, spreadRadius: 4),
            if (active)
              const BoxShadow(
                color: Color.fromRGBO(212, 174, 67, 0.28),
                blurRadius: 14,
                spreadRadius: 2,
              ),
          ],
        ),
      ),
    );
  }
}

class DecanFolioMasthead extends StatelessWidget {
  const DecanFolioMasthead({
    super.key,
    required this.title,
    required this.dateRange,
    this.subtitle,
  });

  final String title;
  final String dateRange;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final cleanSubtitle = subtitle?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 22),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Positioned(
            top: -24,
            right: -12,
            child: IgnorePointer(
              child: Text(
                '𓇳',
                style: TextStyle(
                  fontFamily: 'Noto Sans Egyptian Hieroglyphs',
                  fontFamilyFallback: DecanReflectionTokens.glyphFallback,
                  color: Color.fromRGBO(212, 174, 67, 0.045),
                  fontSize: 140,
                  height: 1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DecanTitleText(title: title, folio: true),
              if (cleanSubtitle != null && cleanSubtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  cleanSubtitle,
                  style: DecanReflectionTokens.folioSubtitleStyle,
                ),
              ],
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    const TextSpan(
                      text: '✦  ',
                      style: TextStyle(
                        color: Color.fromRGBO(184, 146, 74, 0.80),
                      ),
                    ),
                    TextSpan(text: dateRange),
                  ],
                ),
                style: DecanReflectionTokens.folioDateStyle,
              ),
              const SizedBox(height: 20),
              const SizedBox(
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: DecanReflectionTokens.mastheadRule,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DecanRiteBlock extends StatelessWidget {
  const DecanRiteBlock({super.key, required this.question});

  final String question;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 26, 0, 8),
      padding: const EdgeInsets.fromLTRB(22, 18, 0, 18),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: DecanReflectionTokens.brass, width: 2),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Positioned(
            left: -24,
            top: -18,
            width: 2,
            height: 38,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    DecanReflectionTokens.brassGlow,
                    DecanReflectionTokens.brass,
                    Colors.transparent,
                  ],
                  stops: <double>[0, 0.6, 1],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'BEFORE THE NEXT DECAN OPENS',
                style: DecanReflectionTokens.riteEyebrowStyle,
              ),
              const SizedBox(height: 8),
              Text(question, style: DecanReflectionTokens.riteQuestionStyle),
            ],
          ),
        ],
      ),
    );
  }
}

class DecanBridgeAction extends StatelessWidget {
  const DecanBridgeAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tooltip,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = TextButton.icon(
      onPressed: onPressed,
      icon: icon == null
          ? const SizedBox.shrink()
          : Icon(icon, size: 16, color: DecanReflectionTokens.gold),
      label: Text(label),
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll<Color>(
          DecanReflectionTokens.gold,
        ),
        textStyle: const WidgetStatePropertyAll<TextStyle>(
          DecanReflectionTokens.bridgeStyle,
        ),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        ),
        minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 0)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        side: WidgetStateProperty.resolveWith<BorderSide>((states) {
          final focused =
              states.contains(WidgetState.focused) ||
              states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed);
          return BorderSide(
            color: focused
                ? const Color.fromRGBO(212, 174, 67, 0.32)
                : DecanReflectionTokens.hairline,
          );
        }),
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          final focused =
              states.contains(WidgetState.focused) ||
              states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed);
          return focused
              ? const Color.fromRGBO(212, 174, 67, 0.10)
              : const Color.fromRGBO(212, 174, 67, 0.05);
        }),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
