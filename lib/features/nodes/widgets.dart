import 'package:flutter/material.dart';
import 'package:mobile/core/touch_targets.dart';
import '../../shared/glossy_text.dart';

class GlyphBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool showLabel;
  final bool showCloseIcon;

  const GlyphBackButton({
    super.key,
    required this.onTap,
    this.showLabel = true,
    this.showCloseIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final minTouchSize = useExpandedTouchTargets(context)
        ? kMinInteractiveDimension
        : 0.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minTouchSize,
          minHeight: minTouchSize,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showCloseIcon)
                KemeticGold.icon(Icons.close, size: 20)
              else
                ShaderMask(
                  shaderCallback: (Rect bounds) =>
                      KemeticGold.gloss.createShader(bounds),
                  blendMode: BlendMode.srcIn,
                  child: const Text(
                    '𓋴 𓄿 𓏏 𓂋',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontFamily: 'GentiumPlus',
                      fontFamilyFallback: [
                        'NotoSans',
                        'Roboto',
                        'Arial',
                        'sans-serif',
                      ],
                    ),
                  ),
                ),
              if (showLabel) ...[
                const SizedBox(height: 2),
                const Text(
                  'sꜣt',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontFamily: 'GentiumPlus',
                    fontFamilyFallback: [
                      'NotoSans',
                      'Roboto',
                      'Arial',
                      'sans-serif',
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
