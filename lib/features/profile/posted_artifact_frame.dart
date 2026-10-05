import 'package:flutter/material.dart';
import '../../core/theme/app_fonts.dart';

const Color _artifactBone = Color(0xFFF2ECE0);
const Color _artifactMuted = Color(0xFF9E9A94);
const Color _artifactPanel = Color(0xFF0D0B08);
const double _artifactHeight = 236;
const double _artifactHeroHeight = 150;
const double _artifactCopyHeight = 84;
const List<String> _artifactSerifFallback = <String>[
  'GentiumPlus',
  'Georgia',
  'serif',
];

/// Shared geometry and typography for the card inside a profile post.
class PostedArtifactFrame extends StatelessWidget {
  const PostedArtifactFrame({
    super.key,
    required this.artifactKey,
    required this.semanticLabel,
    required this.hero,
    required this.accent,
    required this.badgeLabel,
    required this.typeLabel,
    required this.title,
    required this.overview,
    this.readoutLabel,
  });

  static double heightFor(BuildContext context) =>
      _artifactHeight +
      _artifactCopyHeight *
          (MediaQuery.textScalerOf(context).scale(1).clamp(1, 3) - 1);
  static const double heroHeight = _artifactHeroHeight;
  final Key artifactKey;
  final String semanticLabel;
  final Widget hero;
  final Color accent;
  final String badgeLabel;
  final String typeLabel;
  final String title;
  final String overview;
  final String? readoutLabel;

  @override
  Widget build(BuildContext context) {
    final accentText = Color.lerp(accent, _artifactBone, 0.58)!;
    final radius = BorderRadius.circular(16);

    return Semantics(
      container: true,
      label: semanticLabel,
      child: SizedBox(
        height: heightFor(context),
        child: Container(
          key: artifactKey,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _artifactPanel,
            borderRadius: radius,
            border: Border.all(color: accent.withValues(alpha: 0.42)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: _artifactHeroHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    hero,
                    const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Color(0x05080806),
                              Color(0xE60D0B08),
                            ],
                            stops: <double>[0.38, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 11,
                      right: 11,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xA8090806),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.42),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          child: Text(
                            badgeLabel.toUpperCase(),
                            style: TextStyle(
                              color: accentText,
                              fontFamily: AppFonts.ui,
                              fontSize: 8,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 1.6,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (readoutLabel != null)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 10,
                        child: Text(
                          readoutLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accentText,
                            fontFamily: AppFonts.ui,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.53,
                            height: 1,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height:
                    _artifactCopyHeight *
                    MediaQuery.textScalerOf(context).scale(1).clamp(1, 3),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(15, 6, 15, 0),
                  child: ClipRect(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          typeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accent,
                            fontFamily: AppFonts.ui,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.68,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _artifactBone,
                            fontFamily: 'CormorantGaramond',
                            fontFamilyFallback: _artifactSerifFallback,
                            fontSize: 21,
                            fontWeight: FontWeight.w500,
                            height: 1.08,
                          ),
                        ),
                        if (overview.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(
                            overview,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _artifactMuted,
                              fontFamily: 'CormorantGaramond',
                              fontFamilyFallback: _artifactSerifFallback,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              fontStyle: FontStyle.italic,
                              height: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
