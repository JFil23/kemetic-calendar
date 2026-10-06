import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../data/flow_appearance.dart';
import '../../../utils/detail_sanitizer.dart';
import '../../calendar/presentation/user_flow_appearance_visual.dart';
import '../../calendar/maat_flow_identity.dart';
import '../../calendar/presentation/maat_flow_discovery_view.dart';
import '../../profile/posted_artifact_frame.dart';

/// The same header treatment as a posted flow, with only its title in chat.
class FlowMessagePreview extends StatelessWidget {
  const FlowMessagePreview({
    super.key,
    required this.title,
    required this.appearance,
    required this.color,
    this.maatFlowKind,
    this.localImageBytes,
    this.allowImageFetch = true,
  });

  final String title;
  final FlowAppearance appearance;
  final int color;
  final MaatFlowKind? maatFlowKind;
  final Uint8List? localImageBytes;
  final bool allowImageFetch;

  @override
  Widget build(BuildContext context) {
    final cleaned = cleanFlowTitle(title);
    final label = cleaned.isEmpty ? 'Untitled Flow' : cleaned;
    final accent = Color(
      appearance.accentArgb ?? (0xFF000000 | (color & 0xFFFFFF)),
    );
    final builtInHeader = kCoreMaatFlowDiscoveryFixtures
        .where((card) => card.flowKey == maatFlowKind?.flowKey)
        .firstOrNull;
    final showBuiltInHeader =
        builtInHeader != null &&
        !appearance.hasImage &&
        localImageBytes == null;
    return Semantics(
      label: 'Flow: $label',
      child: Container(
        key: const ValueKey('flow-message-preview'),
        width: 280,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF0D0B08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.42)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showBuiltInHeader)
              SizedBox(
                height: PostedArtifactFrame.heroHeight,
                child: Image.asset(
                  builtInHeader.heroAsset,
                  key: const ValueKey('flow-message-built-in-hero'),
                  fit: BoxFit.cover,
                  alignment: builtInHeader.heroAlignment,
                  cacheWidth: (280 * MediaQuery.devicePixelRatioOf(context))
                      .ceil(),
                ),
              )
            else
              UserFlowAppearanceHero(
                appearance: appearance,
                accent: accent,
                height: PostedArtifactFrame.heroHeight,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                showSignVisual: false,
                showSignLabel: false,
                localImageBytes: localImageBytes,
                allowImageFetch: allowImageFetch,
                imageCacheWidth: (280 * MediaQuery.devicePixelRatioOf(context))
                    .ceil(),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 12, 15, 15),
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFF2ECE0),
                  fontFamily: 'CormorantGaramond',
                  fontFamilyFallback: ['GentiumPlus', 'Georgia', 'serif'],
                  fontSize: 21,
                  fontWeight: FontWeight.w500,
                  height: 1.08,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
