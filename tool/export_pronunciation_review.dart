import 'dart:convert';
import 'dart:io';

import 'package:mobile/features/calendar/pronunciation/pronunciation_catalog.dart';

/// Reproducible view of the Dart catalog; never a second editable data source.
/// Run from the RC checkout: dart run tool/export_pronunciation_review.dart
/// `--json` prints catalog data for later rendering tools, without credentials.
void main(List<String> args) {
  final records = PronunciationCatalog.records;
  if (args.contains('--json')) {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'schema': 1,
        'records': [
          for (final row in records)
            {
              'key': row.key.value,
              'calendarIdentity': row.calendarIdentity,
              'writtenTransliteration': row.writtenTransliteration,
              'pronunciationInput': row.pronunciationInput,
              'displayName': row.displayName,
              'meaning': row.meaning,
              'egyptologicalSpokenForm': row.egyptologicalSpokenForm,
              'ipa': row.ipa,
              'readerRespelling': row.readerRespelling,
              'audioAsset': row.audioAsset,
              'sourceNotes': row.sourceNotes,
              'reviewIssues': row.reviewIssues,
              'textStatus': row.textStatus.name,
              'recordingStatus': row.recordingStatus.name,
              'inputHash': row.inputHash,
              'textFingerprint': row.textFingerprint,
              'pauseMilliseconds': row.pauseMilliseconds,
              'providerIpa': row.providerIpa,
              'providerAdaptationNote': row.providerAdaptationNote,
            },
        ],
      }),
    );
    return;
  }
  final output = StringBuffer('''# Pronunciation catalog review

Generated from `lib/features/calendar/pronunciation/pronunciation_catalog.dart`.
Edit the catalog and regenerate this view; this sheet is not runtime data.

54 records: ${records.where((r) => r.textStatus == TextStatus.textApproved).length} approved for implementation under the user's explicit source/spelling instruction.
All current visible spellings and glosses are retained. Scholarly discrepancies are
content-audit notes, not approval gates. The 54 offline recordings are replaceable
first-pass assets, not listening-approved final performances. The render recipe
freezes one English voice, 145 words/minute, and one 300 ms name-to-gloss pause.
A blank meaning is a name-only clip with no repeated alternative name.
IPA, stress, and syllables are editorial applications of Allen's convention,
not name-specific quotations or claims about exact ancient spoken vowels.

PDF pages are one-based file pages, not printed page numbers.

## Convention evidence

''');
  for (final rule in pronunciationConvention) {
    output.writeln('- $rule');
  }
  output.write('''

## All 54 records

| Key | Product spelling | Pronunciation input | Reader respelling | IPA | Existing English gloss |
| --- | --- | --- | --- | --- | --- |
''');
  for (final row in records) {
    output.writeln(
      '| ${row.key} | ${cell(row.writtenTransliteration ?? "(not present in product)")} | ${cell(row.pronunciationInput)} | ${cell(row.readerRespelling)} | ${cell(row.ipa)} | ${cell(row.meaning.isEmpty ? "(name only)" : row.meaning)} |',
    );
  }
  for (final row in records) {
    output.writeln('\n## ${row.key} — ${row.displayName}\n');
    output.writeln(
      'Text: **${row.textStatus.name}**. Recording: **${row.recordingStatus.name}**.',
    );
    output.writeln(
      '\nIdentity: `${jsonEncode(row.calendarIdentity)}`. Asset: `${row.audioAsset}`.',
    );
    output.writeln('\nSources and mapping:\n');
    for (final note in row.sourceNotes.where(
      (note) => !pronunciationConvention.contains(note),
    )) {
      output.writeln('- $note');
    }
    output.writeln('\nRemaining review issues (none block the authorized cutover):\n');
    for (final issue in row.reviewIssues) {
      output.writeln('- $issue');
    }
  }
  final destination = File('docs/pronunciation/catalog-review.md');
  if (args.contains('--check')) {
    if (!destination.existsSync() ||
        destination.readAsStringSync() != output.toString()) {
      stderr.writeln('Catalog review sheet is stale; regenerate it.');
      exitCode = 1;
    }
    return;
  }
  destination.parent.createSync(recursive: true);
  destination.writeAsStringSync(output.toString());
  stdout.writeln('Wrote ${destination.path} (${records.length} records).');
}

String cell(String value) => value.replaceAll('|', '\\|').replaceAll('\n', ' ');
