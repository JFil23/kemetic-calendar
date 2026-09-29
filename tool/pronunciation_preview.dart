// Local asset audition harness. Run from RC with flutter run -d chrome
// --target tool/pronunciation_preview.dart. Never a release entry point.
import 'package:flutter/material.dart';
import 'package:mobile/features/calendar/pronunciation/pronunciation_catalog.dart';
import 'package:mobile/features/calendar/pronunciation/pronunciation_service.dart';
import 'package:mobile/widgets/pronounce_icon_button.dart';

void main() => runApp(const MaterialApp(home: PronunciationPreview()));

class PronunciationPreview extends StatefulWidget {
  const PronunciationPreview({super.key});
  @override
  State<PronunciationPreview> createState() => _PreviewState();
}

class _PreviewState extends State<PronunciationPreview> {
  String result = 'Replaceable first-pass recordings — Samantha';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pronunciation review')),
    body: Column(
      children: [
        Text(result),
        Expanded(
          child: ListView(
            children: [
              for (final row in PronunciationCatalog.records)
                ListTile(
                  title: Text(
                    '${row.writtenTransliteration ?? row.displayName} — ${row.meaning}',
                  ),
                  subtitle: Text('${row.key}: ${row.readerRespelling}'),
                  trailing: PronounceIconButton(
                    pronunciationKey: row.key,
                    color: Colors.amber,
                  ),
                  onTap: () async {
                    setState(() => result = 'Playing ${row.key}');
                    try {
                      await PronunciationService.instance.play(row.key);
                      if (mounted) {
                        setState(() => result = 'Completed ${row.key}');
                      }
                    } catch (error) {
                      if (mounted) {
                        setState(() => result = 'Playback failed: $error');
                      }
                    }
                  },
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
