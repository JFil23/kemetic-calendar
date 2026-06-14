part of 'calendar_page.dart';

class _MyFlowCard extends StatelessWidget {
  const _MyFlowCard({
    required this.spec,
    required this.isActive,
    required this.onTap,
  });

  final _MyFlowCardDisplaySpec spec;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _MyFlowCardPalette.fromColor(spec.flowColor);
    final maatKind = spec.maatKind;
    final maatPalette = spec.maatPalette;
    final maatBadge = maatKind != null && maatPalette != null
        ? _buildMyFlowMaatBadge(
            kind: maatKind,
            palette: maatPalette,
            accent: palette.accent,
          )
        : null;

    return _SavedFlowVisualTreatment(
      isActive: isActive,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: palette.accent.withValues(alpha: 0.06),
          highlightColor: palette.accent.withValues(alpha: 0.035),
          child: Container(
            key: ValueKey<String>('my_flow_card_${spec.name}'),
            constraints: const BoxConstraints(minHeight: 132),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.cardBorder, width: 0.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: palette.cardBase)),
                  Positioned.fill(
                    child: _MyFlowCardColorWash(palette: palette),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 18, 22),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        maatBadge ?? _buildPersonalInitialBadge(palette),
                        const SizedBox(width: 20),
                        Expanded(child: _buildBody(palette)),
                        const SizedBox(width: 6),
                        SizedBox(width: 68, child: _buildProgress(palette)),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 22,
                    right: 18,
                    child: Icon(
                      Icons.chevron_right,
                      color: palette.chevronColor,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(_MyFlowCardPalette palette) {
    final category = spec.categoryLabel?.trim();
    final hasCategory = category != null && category.isNotEmpty;
    final hasDateRange = spec.dateRange.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasCategory) ...[
          Text(
            category.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.categoryColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 3.0,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 5),
        ],
        Text(
          spec.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          style: TextStyle(
            color: palette.nameColor,
            fontFamily: MaatFlowListTokens.fontFamily,
            fontFamilyFallback: MaatFlowListTokens.fontFallback,
            fontSize: 22,
            fontWeight: FontWeight.w500,
            height: 1.10,
          ),
        ),
        if (hasDateRange) ...[
          const SizedBox(height: 7),
          Text(
            spec.dateRange,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8A7754),
              fontFamily: MaatFlowListTokens.fontFamily,
              fontFamilyFallback: MaatFlowListTokens.fontFallback,
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.25,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgress(_MyFlowCardPalette palette) {
    final value = isActive && spec.totalCount > 0
        ? '${spec.completedCount} of ${spec.totalCount}'
        : '\u2014';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isActive ? 'ACTIVE' : 'SAVED',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF4A3E22),
            fontSize: 9,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.0,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.progressColor,
            fontFamily: MaatFlowListTokens.fontFamily,
            fontFamilyFallback: MaatFlowListTokens.fontFallback,
            fontSize: 16,
            fontStyle: FontStyle.italic,
            height: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInitialBadge(_MyFlowCardPalette palette) {
    final trimmed = spec.name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.characters.first.toUpperCase();

    return Semantics(
      label: 'Flow initial badge',
      child: Container(
        key: ValueKey<String>('my_flow_initial_badge_${spec.name}'),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: palette.iconBorder, width: 0.5),
        ),
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.iconBg,
            border: Border.all(
              color: palette.iconBorder.withValues(alpha: 0.70),
              width: 0.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            maxLines: 1,
            style: TextStyle(
              color: palette.iconColor,
              fontFamily: MaatFlowListTokens.fontFamily,
              fontFamilyFallback: MaatFlowListTokens.fontFallback,
              fontSize: 24,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _MyFlowCardColorWash extends StatelessWidget {
  const _MyFlowCardColorWash({required this.palette});

  final _MyFlowCardPalette palette;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    palette.leftWash,
                    palette.accent.withValues(alpha: 0.045),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.36, 0.70],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.025),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.48],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedFlowVisualTreatment extends StatelessWidget {
  const _SavedFlowVisualTreatment({
    required this.isActive,
    required this.child,
  });

  final bool isActive;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
