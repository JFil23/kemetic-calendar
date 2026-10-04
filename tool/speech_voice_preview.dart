// Local verification surface. Uses the production service without account calls.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/settings/speech_settings_card.dart';
import 'package:mobile/services/speech/speech_service.dart';
import 'package:mobile/services/speech/speech_asset_store.dart';

void main() =>
    runApp(MaterialApp(theme: AppTheme.dark, home: const _Preview()));

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  late final SpeechService speech;
  SpeechVoiceOption voice = SpeechVoiceOption.g;
  String? error;
  final offline = Uri.base.queryParameters['audio-offline'] == '1';
  @override
  void initState() {
    super.initState();
    speech = SpeechService(
      assets: offline
          ? BundledSpeechAssetStore(
              readAsset: (_) async => throw StateError(
                'Audio network disabled for offline verification',
              ),
            )
          : null,
    );
    unawaited(_load());
  }

  Future<void> _load() async {
    final saved = await speech.getPreferredVoice();
    if (mounted) setState(() => voice = saved);
    await speech.prepareLibrary();
  }

  Future<void> _play([String? text]) async {
    try {
      setState(() => error = null);
      if (speech.activeUtteranceId.value != null) {
        await speech.stop();
        return;
      }
      if (text == null) {
        await speech.preview(utteranceId: 'preview');
      } else {
        await speech.speak(text, utteranceId: text);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  void dispose() {
    unawaited(speech.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: AnimatedBuilder(
      animation: Listenable.merge([
        speech.activeUtteranceId,
        speech.libraryStatus,
        speech.libraryFailed,
      ]),
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          children: [
            SpeechSettingsCard(
              selectedVoice: voice,
              onChanged: (next) async {
                await speech.setPreferredVoice(next);
                if (mounted) setState(() => voice = next);
              },
              onPreview: _play,
              previewActive: speech.activeUtteranceId.value == 'preview',
              status: error ?? speech.libraryStatus.value,
              onRetry: speech.libraryFailed.value
                  ? speech.prepareLibrary
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              offline
                  ? 'Verification: audio network disabled'
                  : 'Local RC verification · elevenlabs.io',
              style: const TextStyle(color: Colors.white70),
            ),
            TextButton(
              onPressed: () => _play('Thoth, Jehuty'),
              child: const Text('Play month 1'),
            ),
            TextButton(
              onPressed: () => _play('Tepi-a Sebau'),
              child: const Text('Play decan 1'),
            ),
            Text(
              speech.activeUtteranceId.value == null
                  ? 'Playback idle'
                  : 'Playing saved recording',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    ),
  );
}
