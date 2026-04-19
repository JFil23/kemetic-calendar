import 'package:flutter/material.dart';
import 'package:mobile/core/touch_targets.dart';
import 'package:mobile/services/speech/speech_service.dart';

/// Compact icon button for playing/stopping pronunciations.
class PronounceIconButton extends StatelessWidget {
  final String speakText;
  final Color color;
  final double size;
  final bool isPhonetic;

  const PronounceIconButton({
    super.key,
    required this.speakText,
    required this.color,
    this.size = 22,
    this.isPhonetic = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SpeechService.instance.isSpeaking,
      builder: (context, speaking, child) {
        return IconButton(
          tooltip: speaking ? 'Stop' : 'Play pronunciation',
          padding: expandedIconButtonPadding(
            context,
            iconSize: size,
            fallback: EdgeInsets.zero,
          ),
          constraints: expandedIconButtonConstraints(context),
          visualDensity: expandedVisualDensity(context),
          icon: Icon(
            speaking ? Icons.stop_circle_outlined : Icons.volume_up_rounded,
            color: color,
            size: size,
          ),
          onPressed: () async {
            try {
              if (speaking) {
                await SpeechService.instance.stop();
              } else {
                if (isPhonetic) {
                  await SpeechService.instance.speakPhonetic(speakText);
                } else {
                  await SpeechService.instance.speak(speakText);
                }
              }
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Speech not available on this device'),
                  ),
                );
              }
            }
          },
        );
      },
    );
  }
}
