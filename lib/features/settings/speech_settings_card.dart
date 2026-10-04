import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_fonts.dart';
import 'package:mobile/services/speech/speech_voice.dart';
import 'package:mobile/shared/glossy_text.dart';

/// Presentation shared by Settings and the visual/interaction specimens.
class SpeechSettingsCard extends StatelessWidget {
  const SpeechSettingsCard({
    super.key,
    required this.selectedVoice,
    required this.onChanged,
    required this.onPreview,
    this.busy = false,
    this.previewActive = false,
    this.status,
    this.onRetry,
  });
  final SpeechVoiceOption selectedVoice;
  final ValueChanged<SpeechVoiceOption> onChanged;
  final VoidCallback onPreview;
  final bool busy;
  final bool previewActive;
  final String? status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('speech-settings-card'),
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF0C0C0C),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF242424)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Speech',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Voice recordings · elevenlabs.io',
          style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose a voice for pronunciations throughout Hꜣw. Listen to a sample below.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey(selectedVoice.id),
          initialValue: selectedVoice.id,
          isExpanded: true,
          isDense: false,
          itemHeight: null,
          decoration: InputDecoration(
            labelText: 'Pronunciation voice',
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.black,
            enabledBorder: _border(const Color(0xFF303030)),
            focusedBorder: _border(KemeticGold.base),
            disabledBorder: _border(const Color(0xFF262626)),
          ),
          dropdownColor: const Color(0xFF101010),
          style: const TextStyle(color: Colors.white, fontFamily: AppFonts.ui),
          items: SpeechVoiceOption.values
              .map(
                (voice) =>
                    DropdownMenuItem(value: voice.id, child: Text(voice.name)),
              )
              .toList(),
          onChanged: busy
              ? null
              : (id) => onChanged(SpeechVoiceOption.resolve(id)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF3A3A3A)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: busy ? null : onPreview,
            child: Text(
              previewActive ? 'Stop voice preview' : 'Preview selected voice',
            ),
          ),
        ),
        _line(status ?? 'Using ${selectedVoice.name}.'),
        if (onRetry != null)
          TextButton(
            onPressed: busy ? null : onRetry,
            style: TextButton.styleFrom(foregroundColor: KemeticGold.base),
            child: const Text('Try again'),
          ),
        _line(selectedVoice.description),
        _line(
          'AI-generated voices. Saved month and decan pronunciations play offline.',
        ),
      ],
    ),
  );

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color),
  );
  Widget _line(String text) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Icon(Icons.circle, size: 6, color: Colors.white38),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
        ),
      ],
    ),
  );
}
