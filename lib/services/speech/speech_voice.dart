/// Approved voices with a bundled, offline pronunciation library.
class SpeechVoiceOption {
  const SpeechVoiceOption({
    required this.id,
    required this.name,
    required this.description,
    required this.previewAsset,
  });
  final String id;
  final String name;
  final String description;
  final String previewAsset;
  String get displayLabel => name;

  static const g = SpeechVoiceOption(
    id: 'haw-g',
    name: 'G · Sahidic man',
    description: 'A low male voice with a reconstructed Sahidic accent.',
    previewAsset: 'speech/previews/G.mp3',
  );
  static const h = SpeechVoiceOption(
    id: 'haw-h',
    name: 'H · Sahidic woman',
    description:
        'A full, calm female voice with a reconstructed Sahidic accent.',
    previewAsset: 'speech/previews/H.mp3',
  );
  static const values = [g, h];
  static SpeechVoiceOption resolve(String? id) =>
      values.where((voice) => voice.id == id).firstOrNull ?? g;
}
