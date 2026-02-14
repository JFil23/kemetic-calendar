import 'package:flutter/material.dart';
import 'package:mobile/services/speech/speech_service.dart';

/// Compact icon button for playing/stopping pronunciations.
class PronounceIconButton extends StatelessWidget {
  final String speakText;
  final Color color;
  final double size;

  const PronounceIconButton({
    super.key,
    required this.speakText,
    required this.color,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SpeechService.instance.isSpeaking,
      builder: (_, speaking, __) {
        return IconButton(
          tooltip: speaking ? 'Stop' : 'Play pronunciation',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
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
                await SpeechService.instance.speak(speakText);
              }
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Speech not available on this device')),
                );
              }
            }
          },
        );
      },
    );
  }
}
