import 'package:flutter/material.dart';
import 'package:mobile/core/touch_targets.dart';
import 'package:mobile/services/speech/speech_service.dart';

/// Compact icon button for playing/stopping pronunciations.
class PronounceIconButton extends StatelessWidget {
  final String speakText;
  final String? utteranceId;
  final Color color;
  final double size;
  final bool isPhonetic;

  const PronounceIconButton({
    super.key,
    required this.speakText,
    this.utteranceId,
    required this.color,
    this.size = 22,
    this.isPhonetic = false,
  });

  @override
  Widget build(BuildContext context) {
    final speech = SpeechService.instance;
    final buttonUtteranceId = (utteranceId?.trim().isNotEmpty ?? false)
        ? utteranceId!.trim()
        : speakText;

    return AnimatedBuilder(
      animation: Listenable.merge([
        speech.isSpeaking,
        speech.activeUtteranceId,
      ]),
      builder: (context, child) {
        final isActive = speech.activeUtteranceId.value == buttonUtteranceId;
        return IconButton(
          tooltip: isActive ? 'Stop' : 'Play pronunciation',
          padding: expandedIconButtonPadding(
            context,
            iconSize: size,
            fallback: EdgeInsets.zero,
          ),
          constraints: expandedIconButtonConstraints(context),
          visualDensity: expandedVisualDensity(context),
          icon: Icon(
            isActive ? Icons.stop_circle_outlined : Icons.volume_up_rounded,
            color: color,
            size: size,
          ),
          onPressed: () async {
            try {
              if (isActive) {
                await speech.stop(utteranceId: buttonUtteranceId);
              } else {
                if (isPhonetic) {
                  await speech.speakPhonetic(
                    speakText,
                    utteranceId: buttonUtteranceId,
                  );
                } else {
                  await speech.speak(speakText, utteranceId: buttonUtteranceId);
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
