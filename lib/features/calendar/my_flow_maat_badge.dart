part of 'calendar_page.dart';

Widget? _buildMyFlowMaatBadge({
  required MaatFlowKind kind,
  required MaatFlowPalette palette,
  required Color accent,
}) {
  final template = _myFlowMaatTemplateFor(kind);
  if (template == null || template.glyph.trim().isEmpty) return null;

  return Semantics(
    label: 'Ma’at glyph badge',
    child: Container(
      key: ValueKey<String>('my_flow_maat_badge_${kind.flowKey}'),
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: accent.withValues(alpha: 0.28),
          width: MaatFlowListTokens.cardBorderWidth,
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.alphaBlend(
            accent.withValues(alpha: 0.08),
            const Color(0xFF070706),
          ),
          border: Border.all(
            color: accent.withValues(alpha: 0.34),
            width: MaatFlowListTokens.cardBorderWidth,
          ),
        ),
        child: CustomPaint(
          painter: _MaatFlowIconPainter(
            kind: template.kind,
            glyph: template.glyph,
            joined: true,
            completionProgress: null,
            listAccent: accent,
            detailPalette: null,
            paintBackground: false,
          ),
        ),
      ),
    ),
  );
}
